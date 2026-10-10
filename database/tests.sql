-- =========================================================
-- tests.sql  ชุดทดสอบ (รันหลัง schema.sql -> data.sql -> logic.sql)
-- ครอบคลุม: (ก) trg_PreventShowtimeOverlap กรณีผ่าน/ไม่ผ่าน  (ข) กฎของ SP/Trigger/View ที่เกี่ยวข้องกับการจอง
-- วิธีรัน: เปิดใน SSMS แล้ว Execute ทั้งไฟล์ ผลสรุปอยู่ใน result set สุดท้าย (PASS/FAIL ต่อ 1 เคส)
--   (ระหว่างรันจะมี result set ของ SP เกิดขึ้นหลายอัน เป็นเรื่องปกติ ให้ดูอันสุดท้าย)
-- ความปลอดภัยของข้อมูล: สร้างข้อมูลทดสอบชื่อ [TEST] / test.*@tests.example / TEST_* และ "ลบทิ้งทั้งหมด" ตอนจบ
--   ใช้วันที่ปี 2099 สำหรับรอบฉายเพื่อไม่ชนกับข้อมูลจริง ไม่แตะข้อมูลเดิมในตาราง
--   แต่ละเคสแยกเป็นคนละ batch (GO) เพราะ trigger ที่ ROLLBACK อาจทำให้ batch นั้นจบทันที
-- สถานะ: เขียนและตรวจตรรกะด้วยการจำลองนอก SQL Server แล้ว แต่ "ยังไม่ได้รันบน SQL Server จริง"
-- =========================================================
SET NOCOUNT ON;
IF OBJECT_ID('tempdb..#results') IS NOT NULL DROP TABLE #results;
IF OBJECT_ID('tempdb..#ctx') IS NOT NULL DROP TABLE #ctx;
CREATE TABLE #results (id INT IDENTITY(1,1), test_name NVARCHAR(200), expected NVARCHAR(200), actual NVARCHAR(400), result VARCHAR(4));
CREATE TABLE #ctx (k VARCHAR(20) PRIMARY KEY, v VARCHAR(50));
GO
-- ---------------------------------------------------------
-- SETUP: ล้างข้อมูลทดสอบเก่า (ถ้ามี) แล้วสร้างหนัง/โรง/ที่นั่ง/ลูกค้า/โปรโมชัน/รอบฉายสำหรับ SP
-- ---------------------------------------------------------
    DELETE FROM payments WHERE booking_id IN (SELECT booking_id FROM bookings WHERE customer_id IN (SELECT customer_id FROM customers WHERE email LIKE 'test.%@tests.example'));
    DELETE FROM bookings WHERE customer_id IN (SELECT customer_id FROM customers WHERE email LIKE 'test.%@tests.example');
    DELETE FROM showtimes WHERE movie_id IN (SELECT movie_id FROM movies WHERE title LIKE N'[[]TEST]%');
    DELETE FROM seats WHERE hall_id IN (SELECT hall_id FROM cinema_halls WHERE hall_name LIKE '[[]TEST]%');
    DELETE FROM cinema_halls WHERE hall_name LIKE '[[]TEST]%';
    DELETE FROM movies WHERE title LIKE N'[[]TEST]%';
    DELETE FROM promotions WHERE promotion_code LIKE 'TEST[_]%';
    DELETE FROM customers WHERE email LIKE 'test.%@tests.example';
DECLARE @movie INT, @hall_a INT, @hall_b INT, @cust1 INT, @cust2 INT, @st_sp INT;
DECLARE @today DATE = CAST(SYSDATETIME() AS DATE);

INSERT INTO movies (title, description, duration, genre, release_date, status)
VALUES (N'[TEST] หนังสำหรับทดสอบ', N'ข้อมูลทดสอบ', 120, 'Test', @today, 'active');
SET @movie = SCOPE_IDENTITY();

INSERT INTO cinema_halls (hall_name, capacity, status) VALUES ('[TEST] Hall A', 15, 'active');
SET @hall_a = SCOPE_IDENTITY();
INSERT INTO cinema_halls (hall_name, capacity, status) VALUES ('[TEST] Hall B', 3, 'active');
SET @hall_b = SCOPE_IDENTITY();

INSERT INTO seats (hall_id, row_label, seat_number, seat_type)
SELECT @hall_a, 'A', n, 'standard'
FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13),(14),(15)) x(n);
INSERT INTO seats (hall_id, row_label, seat_number, seat_type)
SELECT @hall_b, 'B', n, 'standard' FROM (VALUES (1),(2),(3)) x(n);

INSERT INTO customers (name, email, phone) VALUES (N'[TEST] ลูกค้า 1', 'test.one@tests.example', '0800000091');
SET @cust1 = SCOPE_IDENTITY();
INSERT INTO customers (name, email, phone) VALUES (N'[TEST] ลูกค้า 2', 'test.two@tests.example', '0800000092');
SET @cust2 = SCOPE_IDENTITY();

INSERT INTO promotions (promotion_code, discount_type, discount_value, start_date, end_date, status) VALUES
 ('TEST_PCT10',     'percentage', 10, DATEADD(DAY, -1, @today), DATEADD(DAY, 1, @today), 'active'),
 ('TEST_FIX50',     'fixed',      50, DATEADD(DAY, -1, @today), DATEADD(DAY, 1, @today), 'active'),
 ('TEST_EXPIRED',   'fixed',      50, DATEADD(DAY, -10, @today), DATEADD(DAY, -1, @today), 'active'),
 ('TEST_INACTIVE',  'fixed',      50, DATEADD(DAY, -1, @today), DATEADD(DAY, 1, @today), 'inactive');

INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, ticket_price, status)
VALUES (@movie, @hall_a, '2099-02-01T14:00:00', '2099-02-01T16:00:00', 200, 'scheduled');
SET @st_sp = SCOPE_IDENTITY();

INSERT INTO #ctx (k, v) VALUES ('movie', @movie), ('hall_a', @hall_a), ('hall_b', @hall_b),
       ('cust1', @cust1), ('cust2', @cust2), ('st_sp', @st_sp);
GO
-- #################  กลุ่ม A: trg_PreventShowtimeOverlap  #################
-- ---------------------------------------------------------
-- A01 [ผ่าน] แทรกรอบแรก 10:00-12:00 โรง A
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, ticket_price, status)
    VALUES (@movie, @hall_a, DATEADD(MINUTE, 600, @d), DATEADD(MINUTE, 720, @d), 200, 'scheduled');
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A01 insert first showtime (hall A 10:00-12:00)', N'no error', N'no error', 'PASS');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A01 insert first showtime (hall A 10:00-12:00)', N'no error', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()), 'FAIL');
END CATCH;
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM showtimes WHERE hall_id = @hall_a AND start_time = DATEADD(MINUTE, 600, @d) AND end_time = DATEADD(MINUTE, 720, @d)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'A01 row exists', N'1', @a, CASE WHEN @a = N'1' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- A02 [ไม่ผ่าน] ซ้อนบางส่วนท้ายรอบเดิม 11:00-13:00
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, ticket_price, status)
    VALUES (@movie, @hall_a, DATEADD(MINUTE, 660, @d), DATEADD(MINUTE, 780, @d), 200, 'scheduled');
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A02 partial overlap (11:00-13:00)', N'error 50030', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A02 partial overlap (11:00-13:00)', N'error 50030', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50030 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM showtimes WHERE hall_id = @hall_a AND start_time = DATEADD(MINUTE, 660, @d) AND end_time = DATEADD(MINUTE, 780, @d)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'A02 row not inserted', N'0', @a, CASE WHEN @a = N'0' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- A03 [ไม่ผ่าน] ซ้อนบางส่วนหัวรอบเดิม 09:00-10:30
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, ticket_price, status)
    VALUES (@movie, @hall_a, DATEADD(MINUTE, 540, @d), DATEADD(MINUTE, 630, @d), 200, 'scheduled');
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A03 partial overlap (09:00-10:30)', N'error 50030', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A03 partial overlap (09:00-10:30)', N'error 50030', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50030 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM showtimes WHERE hall_id = @hall_a AND start_time = DATEADD(MINUTE, 540, @d) AND end_time = DATEADD(MINUTE, 630, @d)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'A03 row not inserted', N'0', @a, CASE WHEN @a = N'0' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- A04 [ไม่ผ่าน] อยู่ภายในรอบเดิม 10:30-11:30
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, ticket_price, status)
    VALUES (@movie, @hall_a, DATEADD(MINUTE, 630, @d), DATEADD(MINUTE, 690, @d), 200, 'scheduled');
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A04 contained in existing (10:30-11:30)', N'error 50030', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A04 contained in existing (10:30-11:30)', N'error 50030', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50030 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
GO
-- ---------------------------------------------------------
-- A05 [ไม่ผ่าน] ครอบรอบเดิม 09:00-13:00
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, ticket_price, status)
    VALUES (@movie, @hall_a, DATEADD(MINUTE, 540, @d), DATEADD(MINUTE, 780, @d), 200, 'scheduled');
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A05 contains existing (09:00-13:00)', N'error 50030', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A05 contains existing (09:00-13:00)', N'error 50030', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50030 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
GO
-- ---------------------------------------------------------
-- A06 [ผ่าน] ต่อท้ายพอดี 12:00-14:00 (end = start ไม่นับว่าชน)
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, ticket_price, status)
    VALUES (@movie, @hall_a, DATEADD(MINUTE, 720, @d), DATEADD(MINUTE, 840, @d), 200, 'scheduled');
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A06 back-to-back after (12:00-14:00)', N'no error', N'no error', 'PASS');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A06 back-to-back after (12:00-14:00)', N'no error', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()), 'FAIL');
END CATCH;
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM showtimes WHERE hall_id = @hall_a AND start_time = DATEADD(MINUTE, 720, @d) AND end_time = DATEADD(MINUTE, 840, @d)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'A06 row exists', N'1', @a, CASE WHEN @a = N'1' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- A07 [ผ่าน] ต่อหัวพอดี 08:00-10:00
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, ticket_price, status)
    VALUES (@movie, @hall_a, DATEADD(MINUTE, 480, @d), DATEADD(MINUTE, 600, @d), 200, 'scheduled');
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A07 back-to-back before (08:00-10:00)', N'no error', N'no error', 'PASS');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A07 back-to-back before (08:00-10:00)', N'no error', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()), 'FAIL');
END CATCH;
GO
-- ---------------------------------------------------------
-- A08 [ผ่าน] เวลาเดียวกันแต่คนละโรง
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, ticket_price, status)
    VALUES (@movie, @hall_b, DATEADD(MINUTE, 600, @d), DATEADD(MINUTE, 720, @d), 200, 'scheduled');
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A08 same time different hall', N'no error', N'no error', 'PASS');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A08 same time different hall', N'no error', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()), 'FAIL');
END CATCH;
GO
-- ---------------------------------------------------------
-- A09 [ผ่าน] รอบ cancelled ซ้อนเวลาได้
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, ticket_price, status)
    VALUES (@movie, @hall_a, DATEADD(MINUTE, 600, @d), DATEADD(MINUTE, 720, @d), 200, 'cancelled');
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A09 cancelled overlap allowed', N'no error', N'no error', 'PASS');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A09 cancelled overlap allowed', N'no error', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()), 'FAIL');
END CATCH;
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM showtimes WHERE hall_id = @hall_a AND start_time = DATEADD(MINUTE, 600, @d) AND end_time = DATEADD(MINUTE, 720, @d) AND status = 'cancelled') AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'A09 cancelled row exists', N'1', @a, CASE WHEN @a = N'1' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- A10 [ไม่ผ่าน] แทรกหลายแถวที่ชนกันเอง (15:00-17:00 กับ 16:00-18:00) ต้องไม่เข้าเลยสักแถว
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, ticket_price, status)
    VALUES (@movie, @hall_a, DATEADD(HOUR, 15, @d), DATEADD(HOUR, 17, @d), 200, 'scheduled'),
           (@movie, @hall_a, DATEADD(HOUR, 16, @d), DATEADD(HOUR, 18, @d), 200, 'scheduled');
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A10 multi-row insert overlapping each other', N'error 50030', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A10 multi-row insert overlapping each other', N'error 50030', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50030 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM showtimes WHERE hall_id = @hall_a AND start_time >= DATEADD(HOUR, 15, @d) AND start_time < DATEADD(HOUR, 18, @d)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'A10 none of the rows inserted', N'0', @a, CASE WHEN @a = N'0' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- A11 [ไม่ผ่าน] แทรกหลายแถว แถวแรกถูกต้อง แถวสองชนกับรอบเดิม -> ทั้งชุดถูกยกเลิก
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, ticket_price, status)
    VALUES (@movie, @hall_a, DATEADD(HOUR, 20, @d), DATEADD(HOUR, 22, @d), 200, 'scheduled'),
           (@movie, @hall_a, DATEADD(MINUTE, 690, @d), DATEADD(MINUTE, 750, @d), 200, 'scheduled');
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A11 multi-row insert, one conflicting with existing', N'error 50030', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A11 multi-row insert, one conflicting with existing', N'error 50030', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50030 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM showtimes WHERE hall_id = @hall_a AND start_time = DATEADD(MINUTE, 1200, @d) AND end_time = DATEADD(MINUTE, 1320, @d)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'A11 valid row also rolled back', N'0', @a, CASE WHEN @a = N'0' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- A12 [ไม่ผ่าน] UPDATE เลื่อนรอบ 12:00-14:00 ไปชน (11:00-13:00) และข้อมูลเดิมต้องไม่เปลี่ยน
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    UPDATE showtimes SET start_time = DATEADD(HOUR, 11, @d), end_time = DATEADD(HOUR, 13, @d)
    WHERE hall_id = @hall_a AND start_time = DATEADD(HOUR, 12, @d) AND status = 'scheduled';
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A12 update moves showtime into conflict', N'error 50030', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A12 update moves showtime into conflict', N'error 50030', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50030 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM showtimes WHERE hall_id = @hall_a AND start_time = DATEADD(MINUTE, 720, @d) AND end_time = DATEADD(MINUTE, 840, @d)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'A12 original row unchanged', N'1', @a, CASE WHEN @a = N'1' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- A13 [ผ่าน] UPDATE เลื่อนรอบ 12:00-14:00 ไปช่วงว่าง 20:00-22:00
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    UPDATE showtimes SET start_time = DATEADD(HOUR, 20, @d), end_time = DATEADD(HOUR, 22, @d)
    WHERE hall_id = @hall_a AND start_time = DATEADD(HOUR, 12, @d) AND status = 'scheduled';
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A13 update moves showtime to free slot', N'no error', N'no error', 'PASS');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A13 update moves showtime to free slot', N'no error', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()), 'FAIL');
END CATCH;
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM showtimes WHERE hall_id = @hall_a AND start_time = DATEADD(MINUTE, 1200, @d) AND end_time = DATEADD(MINUTE, 1320, @d)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'A13 row moved', N'1', @a, CASE WHEN @a = N'1' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- A14 [ไม่ผ่าน] เปลี่ยนรอบ cancelled (10:00-12:00) กลับเป็น scheduled ทั้งที่ชนกับรอบ active
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    UPDATE showtimes SET status = 'scheduled'
    WHERE hall_id = @hall_a AND start_time = DATEADD(HOUR, 10, @d) AND status = 'cancelled';
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A14 reviving a cancelled showtime that overlaps', N'error 50030', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A14 reviving a cancelled showtime that overlaps', N'error 50030', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50030 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM showtimes WHERE hall_id = @hall_a AND start_time = DATEADD(MINUTE, 600, @d) AND end_time = DATEADD(MINUTE, 720, @d) AND status = 'cancelled') AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'A14 still cancelled', N'1', @a, CASE WHEN @a = N'1' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- A15 [ผ่าน] UPDATE ราคาอย่างเดียว (ไม่แตะเวลา/โรง/สถานะ)
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    UPDATE showtimes SET ticket_price = 250 WHERE hall_id = @hall_a AND start_time = DATEADD(HOUR, 8, @d) AND status = 'scheduled';
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A15 update price only', N'no error', N'no error', 'PASS');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A15 update price only', N'no error', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()), 'FAIL');
END CATCH;
DECLARE @a NVARCHAR(200) = CAST((SELECT ticket_price FROM showtimes WHERE hall_id = @hall_a AND start_time = DATEADD(HOUR, 8, @d)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'A15 price changed', N'250.00', @a, CASE WHEN @a = N'250.00' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- A16 [ผ่าน] ยกเลิกรอบเดิม (10:00-12:00 scheduled อยู่ไม่มี จึงยกเลิก 08:00-10:00) แล้วแทรกรอบใหม่ทับช่วงนั้นได้
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    UPDATE showtimes SET status = 'cancelled' WHERE hall_id = @hall_a AND start_time = DATEADD(HOUR, 8, @d) AND status = 'scheduled';
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A16 cancel a showtime', N'no error', N'no error', 'PASS');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A16 cancel a showtime', N'no error', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()), 'FAIL');
END CATCH;
BEGIN TRY
    INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, ticket_price, status)
    VALUES (@movie, @hall_a, DATEADD(MINUTE, 480, @d), DATEADD(MINUTE, 600, @d), 200, 'scheduled');
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'A16 insert into the cancelled slot', N'no error', N'no error', 'PASS');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'A16 insert into the cancelled slot', N'no error', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()), 'FAIL');
END CATCH;
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM showtimes WHERE hall_id = @hall_a AND start_time = DATEADD(MINUTE, 480, @d) AND end_time = DATEADD(MINUTE, 600, @d) AND status = 'scheduled') AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'A16 new row exists', N'1', @a, CASE WHEN @a = N'1' THEN 'PASS' ELSE 'FAIL' END);
GO
-- #################  กลุ่ม B: กฎการจอง / SP / Trigger / View  #################
-- ---------------------------------------------------------
-- B01 ถือที่นั่ง A1,A2 (ลูกค้า 1) -> pending, ตั๋ว reserved 2 ใบ, ยอด 400
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

    DECLARE @sv1 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 1), @sv2 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 2);
    EXEC sp_HoldSeats @customer_id = @cust1, @showtime_id = @st_sp, @seat_id_1 = @sv1, @seat_id_2 = @sv2, @promotion_code = NULL;
DECLARE @a NVARCHAR(200) = CAST((SELECT booking_status FROM bookings WHERE booking_id = (SELECT TOP (1) booking_id FROM bookings WHERE customer_id = @cust1 AND showtime_id = @st_sp ORDER BY booking_id DESC)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B01 booking pending', N'pending', @a, CASE WHEN @a = N'pending' THEN 'PASS' ELSE 'FAIL' END);
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM tickets WHERE ticket_status = 'reserved' AND booking_id = (SELECT TOP (1) booking_id FROM bookings WHERE customer_id = @cust1 AND showtime_id = @st_sp ORDER BY booking_id DESC)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B01 two reserved tickets', N'2', @a, CASE WHEN @a = N'2' THEN 'PASS' ELSE 'FAIL' END);
DECLARE @a NVARCHAR(200) = CAST((SELECT total_amount FROM bookings WHERE booking_id = (SELECT TOP (1) booking_id FROM bookings WHERE customer_id = @cust1 AND showtime_id = @st_sp ORDER BY booking_id DESC)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B01 total 400', N'400.00', @a, CASE WHEN @a = N'400.00' THEN 'PASS' ELSE 'FAIL' END);
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM payments WHERE booking_id = (SELECT TOP (1) booking_id FROM bookings WHERE customer_id = @cust1 AND showtime_id = @st_sp ORDER BY booking_id DESC)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B01 no payment yet', N'0', @a, CASE WHEN @a = N'0' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- B02 [ไม่ผ่าน] ที่นั่ง A1 ถูกถือแล้ว ลูกค้า 2 จองซ้ำไม่ได้ (error 50005)
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    DECLARE @p DECIMAL(10,2), @c INT, @pid INT, @t DECIMAL(10,2);
    BEGIN TRANSACTION;
    DECLARE @sv3 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 1);
    EXEC sp_ValidateBookingRequest @cust2, @st_sp, @sv3, @promotion_code = NULL, @ticket_price = @p OUTPUT, @seat_count = @c OUTPUT, @promotion_id = @pid OUTPUT, @total_amount = @t OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'B02 seat already held', N'error 50005', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'B02 seat already held', N'error 50005', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50005 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
GO
-- ---------------------------------------------------------
-- B03 [ไม่ผ่าน] ที่นั่งของโรง B ในรอบของโรง A (error 50004)
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    DECLARE @p DECIMAL(10,2), @c INT, @pid INT, @t DECIMAL(10,2);
    BEGIN TRANSACTION;
    DECLARE @sv4 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_b AND row_label = 'B' AND seat_number = 1);
    EXEC sp_ValidateBookingRequest @cust2, @st_sp, @sv4, @promotion_code = NULL, @ticket_price = @p OUTPUT, @seat_count = @c OUTPUT, @promotion_id = @pid OUTPUT, @total_amount = @t OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'B03 seat from another hall', N'error 50004', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'B03 seat from another hall', N'error 50004', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50004 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
GO
-- ---------------------------------------------------------
-- B04 [ไม่ผ่าน] เลือกที่นั่งซ้ำกันเอง A5,A5 (error 50006)
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    DECLARE @p DECIMAL(10,2), @c INT, @pid INT, @t DECIMAL(10,2);
    BEGIN TRANSACTION;
    DECLARE @sv5 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 5), @sv6 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 5);
    EXEC sp_ValidateBookingRequest @cust2, @st_sp, @sv5, @sv6, @promotion_code = NULL, @ticket_price = @p OUTPUT, @seat_count = @c OUTPUT, @promotion_id = @pid OUTPUT, @total_amount = @t OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'B04 duplicate seat in request', N'error 50006', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'B04 duplicate seat in request', N'error 50006', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50006 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
GO
-- ---------------------------------------------------------
-- B05 [ไม่ผ่าน] ไม่พบลูกค้า (error 50002)
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    DECLARE @p DECIMAL(10,2), @c INT, @pid INT, @t DECIMAL(10,2);
    BEGIN TRANSACTION;
    DECLARE @sv7 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 5);
    EXEC sp_ValidateBookingRequest -1, @st_sp, @sv7, @promotion_code = NULL, @ticket_price = @p OUTPUT, @seat_count = @c OUTPUT, @promotion_id = @pid OUTPUT, @total_amount = @t OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'B05 unknown customer', N'error 50002', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'B05 unknown customer', N'error 50002', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50002 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
GO
-- ---------------------------------------------------------
-- B06 [ไม่ผ่าน] โปรโมชันหมดอายุ (error 50003)
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    DECLARE @p DECIMAL(10,2), @c INT, @pid INT, @t DECIMAL(10,2);
    BEGIN TRANSACTION;
    DECLARE @sv8 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 5);
    EXEC sp_ValidateBookingRequest @cust2, @st_sp, @sv8, @promotion_code = 'TEST_EXPIRED', @ticket_price = @p OUTPUT, @seat_count = @c OUTPUT, @promotion_id = @pid OUTPUT, @total_amount = @t OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'B06 expired promotion', N'error 50003', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'B06 expired promotion', N'error 50003', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50003 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
GO
-- ---------------------------------------------------------
-- B07 [ไม่ผ่าน] โปรโมชัน inactive (error 50003)
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    DECLARE @p DECIMAL(10,2), @c INT, @pid INT, @t DECIMAL(10,2);
    BEGIN TRANSACTION;
    DECLARE @sv9 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 5);
    EXEC sp_ValidateBookingRequest @cust2, @st_sp, @sv9, @promotion_code = 'TEST_INACTIVE', @ticket_price = @p OUTPUT, @seat_count = @c OUTPUT, @promotion_id = @pid OUTPUT, @total_amount = @t OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'B07 inactive promotion', N'error 50003', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'B07 inactive promotion', N'error 50003', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50003 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
GO
-- ---------------------------------------------------------
-- B08 [ไม่ผ่าน] เรียก sp_ValidateBookingRequest นอก Transaction (error 50099)
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

BEGIN TRY
    DECLARE @p DECIMAL(10,2), @c INT, @pid INT, @t DECIMAL(10,2);
    DECLARE @sv10 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 5);
    EXEC sp_ValidateBookingRequest @cust2, @st_sp, @sv10, @ticket_price = @p OUTPUT, @seat_count = @c OUTPUT, @promotion_id = @pid OUTPUT, @total_amount = @t OUTPUT;
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'B08 validate outside transaction', N'error 50099', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'B08 validate outside transaction', N'error 50099', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50099 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
GO
-- ---------------------------------------------------------
-- B09 ถือที่นั่ง A6 พร้อมโค้ด TEST_PCT10 -> ยอด 180 และผูก promotion
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

    DECLARE @sv11 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 6);
    EXEC sp_HoldSeats @customer_id = @cust2, @showtime_id = @st_sp, @seat_id_1 = @sv11, @promotion_code = 'TEST_PCT10';
DECLARE @a NVARCHAR(200) = CAST((SELECT total_amount FROM bookings WHERE booking_id = (SELECT TOP (1) booking_id FROM bookings WHERE customer_id = @cust2 AND showtime_id = @st_sp ORDER BY booking_id DESC)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B09 total 180', N'180.00', @a, CASE WHEN @a = N'180.00' THEN 'PASS' ELSE 'FAIL' END);
DECLARE @a NVARCHAR(200) = CAST((SELECT p.promotion_code FROM bookings b JOIN promotions p ON p.promotion_id = b.promotion_id WHERE b.booking_id = (SELECT TOP (1) booking_id FROM bookings WHERE customer_id = @cust2 AND showtime_id = @st_sp ORDER BY booking_id DESC)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B09 promotion linked', N'TEST_PCT10', @a, CASE WHEN @a = N'TEST_PCT10' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- B10 ชำระเงินการจองของลูกค้า 1 พร้อมโค้ด TEST_FIX50 ตอนชำระ -> ยอด 350, confirmed, ตั๋ว issued, payment paid
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

    DECLARE @b INT = (SELECT TOP (1) booking_id FROM bookings WHERE customer_id = @cust1 AND showtime_id = @st_sp ORDER BY booking_id DESC);
    EXEC sp_ConfirmPayment @booking_id = @b, @customer_id = @cust1, @payment_method = 'card', @promotion_code = 'TEST_FIX50';
DECLARE @a NVARCHAR(200) = CAST((SELECT booking_status FROM bookings WHERE booking_id = @b) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B10 booking confirmed', N'confirmed', @a, CASE WHEN @a = N'confirmed' THEN 'PASS' ELSE 'FAIL' END);
DECLARE @a NVARCHAR(200) = CAST((SELECT total_amount FROM bookings WHERE booking_id = @b) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B10 total 350', N'350.00', @a, CASE WHEN @a = N'350.00' THEN 'PASS' ELSE 'FAIL' END);
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM tickets WHERE booking_id = @b AND ticket_status = 'issued') AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B10 tickets issued', N'2', @a, CASE WHEN @a = N'2' THEN 'PASS' ELSE 'FAIL' END);
DECLARE @a NVARCHAR(200) = CAST((SELECT CONCAT(amount, '/', payment_status) FROM payments WHERE booking_id = @b) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B10 payment amount 350 paid', N'350.00/paid', @a, CASE WHEN @a = N'350.00/paid' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- B11 [ไม่ผ่าน] ชำระซ้ำการจองที่ confirmed แล้ว -> ไม่เกิดรายการชำระเงินที่สอง
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

    DECLARE @b INT = (SELECT TOP (1) booking_id FROM bookings WHERE customer_id = @cust1 AND showtime_id = @st_sp ORDER BY booking_id DESC);
    EXEC sp_ConfirmPayment @booking_id = @b, @customer_id = @cust1;
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM payments WHERE booking_id = @b) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B11 still one payment', N'1', @a, CASE WHEN @a = N'1' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- B12 [ไม่ผ่าน] ลูกค้า 1 พยายามชำระการจองของลูกค้า 2 -> ยังเป็น pending
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

    DECLARE @b INT = (SELECT TOP (1) booking_id FROM bookings WHERE customer_id = @cust2 AND showtime_id = @st_sp ORDER BY booking_id DESC);
    EXEC sp_ConfirmPayment @booking_id = @b, @customer_id = @cust1;
DECLARE @a NVARCHAR(200) = CAST((SELECT booking_status FROM bookings WHERE booking_id = @b) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B12 booking still pending', N'pending', @a, CASE WHEN @a = N'pending' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- B13 ยกเลิกการถือ (ลูกค้า 2) -> cancelled, ตั๋ว cancelled และที่นั่ง A6 กลับมาว่าง
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

    DECLARE @b INT = (SELECT TOP (1) booking_id FROM bookings WHERE customer_id = @cust2 AND showtime_id = @st_sp ORDER BY booking_id DESC);
    EXEC sp_CancelHold @booking_id = @b, @customer_id = @cust2;
DECLARE @a NVARCHAR(200) = CAST((SELECT booking_status FROM bookings WHERE booking_id = @b) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B13 booking cancelled', N'cancelled', @a, CASE WHEN @a = N'cancelled' THEN 'PASS' ELSE 'FAIL' END);
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM tickets WHERE booking_id = @b AND ticket_status = 'cancelled') AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B13 tickets cancelled', N'1', @a, CASE WHEN @a = N'1' THEN 'PASS' ELSE 'FAIL' END);
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM vw_TakenSeats WHERE showtime_id = @st_sp AND seat_id = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 6)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B13 seat A6 free again', N'0', @a, CASE WHEN @a = N'0' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- B14 หมดเวลาถือ: ถือ A9 แล้วเลื่อนเวลาย้อนหลัง 30 นาที -> trigger เปลี่ยนเป็น expired และปล่อยตั๋ว
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

    DECLARE @sv12 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 9);
    EXEC sp_HoldSeats @customer_id = @cust1, @showtime_id = @st_sp, @seat_id_1 = @sv12, @promotion_code = NULL;
    DECLARE @b INT = (SELECT TOP (1) booking_id FROM bookings WHERE customer_id = @cust1 AND showtime_id = @st_sp ORDER BY booking_id DESC);
    UPDATE bookings SET booking_time = DATEADD(MINUTE, -30, booking_time), expires_at = DATEADD(MINUTE, -15, expires_at) WHERE booking_id = @b;
DECLARE @a NVARCHAR(200) = CAST((SELECT booking_status FROM bookings WHERE booking_id = @b) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B14 booking expired by trigger', N'expired', @a, CASE WHEN @a = N'expired' THEN 'PASS' ELSE 'FAIL' END);
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM tickets WHERE booking_id = @b AND ticket_status = 'cancelled') AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B14 ticket cancelled by trigger', N'1', @a, CASE WHEN @a = N'1' THEN 'PASS' ELSE 'FAIL' END);
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM vw_TakenSeats WHERE showtime_id = @st_sp AND seat_id = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 9)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B14 seat A9 free again', N'0', @a, CASE WHEN @a = N'0' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- B15 ชำระเงินการจองที่หมดเวลาแล้ว -> ไม่มี payment และยัง expired
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

    DECLARE @b INT = (SELECT TOP (1) booking_id FROM bookings WHERE customer_id = @cust1 AND booking_status = 'expired' ORDER BY booking_id DESC);
    EXEC sp_ConfirmPayment @booking_id = @b, @customer_id = @cust1;
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM payments WHERE booking_id = @b) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B15 no payment row', N'0', @a, CASE WHEN @a = N'0' THEN 'PASS' ELSE 'FAIL' END);
DECLARE @a NVARCHAR(200) = CAST((SELECT booking_status FROM bookings WHERE booking_id = @b) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B15 still expired', N'expired', @a, CASE WHEN @a = N'expired' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- B16 trigger กวาด hold ที่หมดเวลาของคนอื่นเมื่อมี DML อื่นบน bookings (ปิด trigger ชั่วคราวเพื่อเตรียมสถานการณ์)
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

    DECLARE @sv13 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 10);
    EXEC sp_HoldSeats @customer_id = @cust2, @showtime_id = @st_sp, @seat_id_1 = @sv13, @promotion_code = NULL;
    DECLARE @b INT = (SELECT TOP (1) booking_id FROM bookings WHERE customer_id = @cust2 AND showtime_id = @st_sp ORDER BY booking_id DESC);
    DECLARE @other INT = (SELECT TOP (1) booking_id FROM bookings WHERE customer_id = @cust1 ORDER BY booking_id);
    ALTER TABLE bookings DISABLE TRIGGER trg_ReleaseExpiredSeatLocks;
    UPDATE bookings SET booking_time = DATEADD(MINUTE, -30, booking_time), expires_at = DATEADD(MINUTE, -15, expires_at) WHERE booking_id = @b;
    ALTER TABLE bookings ENABLE TRIGGER trg_ReleaseExpiredSeatLocks;
DECLARE @a NVARCHAR(200) = CAST((SELECT booking_status FROM bookings WHERE booking_id = @b) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B16 precondition still pending', N'pending', @a, CASE WHEN @a = N'pending' THEN 'PASS' ELSE 'FAIL' END);
    UPDATE bookings SET total_amount = total_amount WHERE booking_id = @other;
DECLARE @a NVARCHAR(200) = CAST((SELECT booking_status FROM bookings WHERE booking_id = @b) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B16 swept by unrelated DML', N'expired', @a, CASE WHEN @a = N'expired' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- B17 sp_BookMovieSeats (ขั้นตอนเดียว) จอง A11,A12 โค้ด TEST_PCT10 -> confirmed ยอด 360, payment paid
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

    DECLARE @sv14 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 11), @sv15 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 12);
    EXEC sp_BookMovieSeats @customer_id = @cust2, @showtime_id = @st_sp, @seat_id_1 = @sv14, @seat_id_2 = @sv15, @promotion_code = 'TEST_PCT10', @payment_method = 'online';
    DECLARE @b INT = (SELECT TOP (1) booking_id FROM bookings WHERE customer_id = @cust2 AND booking_status = 'confirmed' ORDER BY booking_id DESC);
DECLARE @a NVARCHAR(200) = CAST((SELECT CONCAT(booking_status, '/', total_amount) FROM bookings WHERE booking_id = @b) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B17 confirmed total 360', N'confirmed/360.00', @a, CASE WHEN @a = N'confirmed/360.00' THEN 'PASS' ELSE 'FAIL' END);
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM tickets WHERE booking_id = @b AND ticket_status = 'issued') AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B17 two issued tickets', N'2', @a, CASE WHEN @a = N'2' THEN 'PASS' ELSE 'FAIL' END);
DECLARE @a NVARCHAR(200) = CAST((SELECT CONCAT(amount, '/', payment_status) FROM payments WHERE booking_id = @b) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B17 payment paid 360', N'360.00/paid', @a, CASE WHEN @a = N'360.00/paid' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- B18 sp_BookMovieSeats ที่นั่งซ้ำ (A11) -> ไม่เกิดการจองใหม่
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

    DECLARE @before INT = (SELECT COUNT(*) FROM bookings WHERE showtime_id = @st_sp);
    DECLARE @sv16 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 11);
    EXEC sp_BookMovieSeats @customer_id = @cust1, @showtime_id = @st_sp, @seat_id_1 = @sv16;
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) - @before FROM bookings WHERE showtime_id = @st_sp) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B18 booking count unchanged', N'0', @a, CASE WHEN @a = N'0' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- B19 sp_BookMovieSeats ช่องทางชำระเงินไม่ถูกต้อง -> ไม่เกิดการจองใหม่
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

    DECLARE @before INT = (SELECT COUNT(*) FROM bookings WHERE showtime_id = @st_sp);
    DECLARE @sv17 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 13);
    EXEC sp_BookMovieSeats @customer_id = @cust1, @showtime_id = @st_sp, @seat_id_1 = @sv17, @payment_method = 'bitcoin';
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) - @before FROM bookings WHERE showtime_id = @st_sp) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B19 booking count unchanged', N'0', @a, CASE WHEN @a = N'0' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- B20 [ไม่ผ่าน] รอบฉายที่เริ่มไปแล้วจองไม่ได้ (error 50007)
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

    INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, ticket_price, status) VALUES (@movie, @hall_a, '2000-01-01T10:00:00', '2000-01-01T12:00:00', 200, 'scheduled');
    DECLARE @old INT = SCOPE_IDENTITY();
BEGIN TRY
    DECLARE @p DECIMAL(10,2), @c INT, @pid INT, @t DECIMAL(10,2);
    BEGIN TRANSACTION;
    DECLARE @sv18 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 14);
    EXEC sp_ValidateBookingRequest @cust2, @old, @sv18, @promotion_code = NULL, @ticket_price = @p OUTPUT, @seat_count = @c OUTPUT, @promotion_id = @pid OUTPUT, @total_amount = @t OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'B20 showtime already started', N'error 50007', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'B20 showtime already started', N'error 50007', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50007 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
GO
-- ---------------------------------------------------------
-- B21 [ไม่ผ่าน] รอบฉาย cancelled จองไม่ได้ (error 50001)
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

    DECLARE @c INT = (SELECT TOP (1) showtime_id FROM showtimes WHERE hall_id = @hall_a AND status = 'cancelled');
BEGIN TRY
    DECLARE @p DECIMAL(10,2), @c INT, @pid INT, @t DECIMAL(10,2);
    BEGIN TRANSACTION;
    DECLARE @sv19 INT = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 14);
    EXEC sp_ValidateBookingRequest @cust2, @c, @sv19, @promotion_code = NULL, @ticket_price = @p OUTPUT, @seat_count = @c OUTPUT, @promotion_id = @pid OUTPUT, @total_amount = @t OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result) VALUES (N'B21 cancelled showtime', N'error 50001', N'no error raised', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO #results (test_name, expected, actual, result)
    VALUES (N'B21 cancelled showtime', N'error 50001', CONCAT(N'error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
            CASE WHEN ERROR_NUMBER() = 50001 THEN 'PASS' ELSE 'FAIL' END);
END CATCH;
GO
-- ---------------------------------------------------------
-- B22 vw_BoxOfficeOccupancyReport ของหนังทดสอบ: ตั๋วที่ขาย 4 ใบ รายได้ 800
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

DECLARE @a NVARCHAR(200) = CAST((SELECT tickets_sold FROM vw_BoxOfficeOccupancyReport WHERE movie_id = @movie) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B22 tickets_sold = 4', N'4', @a, CASE WHEN @a = N'4' THEN 'PASS' ELSE 'FAIL' END);
DECLARE @a NVARCHAR(200) = CAST((SELECT total_revenue FROM vw_BoxOfficeOccupancyReport WHERE movie_id = @movie) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B22 total_revenue = 800', N'800.00', @a, CASE WHEN @a = N'800.00' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- B23 vw_TakenSeats แสดงที่นั่ง confirmed (A1) ของรอบ
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM vw_TakenSeats WHERE showtime_id = @st_sp AND seat_id = (SELECT seat_id FROM seats WHERE hall_id = @hall_a AND row_label = 'A' AND seat_number = 1)) AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B23 A1 is taken', N'1', @a, CASE WHEN @a = N'1' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- B24 sp_RegisterCustomer: สมัครสำเร็จ, อีเมลซ้ำถูกปฏิเสธ (error 50020 ผ่าน result set)
-- ---------------------------------------------------------
DECLARE @movie INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'movie'),
        @hall_a INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_a'),
        @hall_b INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'hall_b'),
        @cust1 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust1'),
        @cust2 INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'cust2'),
        @st_sp INT = (SELECT CAST(v AS INT) FROM #ctx WHERE k = 'st_sp'),
        @d DATETIME2 = '2099-01-01T00:00:00';   -- วันทดสอบรอบฉายทับซ้อน (อนาคตไกล ไม่ชนข้อมูลจริง)

    EXEC sp_RegisterCustomer @name = N'[TEST] สมัครใหม่', @email = 'test.reg@tests.example', @phone = '0800000093', @password_hash = 'pbkdf2-sha256$100000$AAAAAAAAAAAAAAAAAAAAAA==$BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=';
    EXEC sp_RegisterCustomer @name = N'[TEST] สมัครซ้ำ', @email = 'TEST.REG@tests.example', @phone = '0800000094', @password_hash = 'pbkdf2-sha256$100000$AAAAAAAAAAAAAAAAAAAAAA==$BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=';
DECLARE @a NVARCHAR(200) = CAST((SELECT COUNT(*) FROM customers WHERE email = 'test.reg@tests.example') AS NVARCHAR(200));
INSERT INTO #results (test_name, expected, actual, result)
VALUES (N'B24 exactly one account for the email', N'1', @a, CASE WHEN @a = N'1' THEN 'PASS' ELSE 'FAIL' END);
GO
-- ---------------------------------------------------------
-- CLEANUP: ลบข้อมูลทดสอบทั้งหมด
-- ---------------------------------------------------------
    ALTER TABLE bookings ENABLE TRIGGER trg_ReleaseExpiredSeatLocks;   -- เผื่อเคส B16 ล้มกลางทางแล้วค้างสถานะปิด trigger
    DELETE FROM payments WHERE booking_id IN (SELECT booking_id FROM bookings WHERE customer_id IN (SELECT customer_id FROM customers WHERE email LIKE 'test.%@tests.example'));
    DELETE FROM bookings WHERE customer_id IN (SELECT customer_id FROM customers WHERE email LIKE 'test.%@tests.example');
    DELETE FROM showtimes WHERE movie_id IN (SELECT movie_id FROM movies WHERE title LIKE N'[[]TEST]%');
    DELETE FROM seats WHERE hall_id IN (SELECT hall_id FROM cinema_halls WHERE hall_name LIKE '[[]TEST]%');
    DELETE FROM cinema_halls WHERE hall_name LIKE '[[]TEST]%';
    DELETE FROM movies WHERE title LIKE N'[[]TEST]%';
    DELETE FROM promotions WHERE promotion_code LIKE 'TEST[_]%';
    DELETE FROM customers WHERE email LIKE 'test.%@tests.example';
GO
-- ---------------------------------------------------------
-- REPORT: ผลสรุป (result set สุดท้าย)  ถ้าจำนวนเคสน้อยกว่าที่คาดไว้ แปลว่ามี batch ถูกยกเลิกกลางทาง
-- ---------------------------------------------------------
SELECT test_name, expected, actual, result FROM #results ORDER BY id;
SELECT COUNT(*) AS executed_checks, 69 AS expected_checks,
       SUM(CASE WHEN result = 'PASS' THEN 1 ELSE 0 END) AS passed,
       SUM(CASE WHEN result = 'FAIL' THEN 1 ELSE 0 END) AS failed,
       CASE WHEN COUNT(*) = 69 AND SUM(CASE WHEN result = 'FAIL' THEN 1 ELSE 0 END) = 0 THEN 'ALL PASS' ELSE 'CHECK FAILURES' END AS overall
FROM #results;
GO
