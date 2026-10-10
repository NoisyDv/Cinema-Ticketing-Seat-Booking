-- =========================================================
-- logic.sql  (รันซ้ำได้ - ใช้ CREATE OR ALTER ทั้งหมด)
-- รันหลัง schema.sql และ data.sql
-- DBMS: Microsoft SQL Server
--
-- ไฟล์นี้รวม migration.sql เดิมไว้ครบแล้ว (ไม่ต้องรัน migration.sql แยก)
--
-- วัตถุที่โจทย์กำหนด (ห้ามเปลี่ยนชื่อ):
--   sp_BookMovieSeats, trg_ReleaseExpiredSeatLocks, vw_BoxOfficeOccupancyReport
-- วัตถุเพิ่มเติม:
--   fn_CalculateBookingTotal, fn_GetValidPromotion      (กฎส่วนลดจุดเดียว)
--   vw_TakenSeats, sp_ReleaseExpiredHolds               (ที่นั่งไม่ว่าง / ปล่อยที่นั่งหมดเวลา)
--   sp_ValidateBookingRequest                           (กฎตรวจการจองจุดเดียว ใช้ร่วมกัน)
--   sp_HoldSeats, sp_ConfirmPayment, sp_CancelHold      (การจองแบบ 2 ขั้นตอน ใช้โดยเว็บ)
--   sp_RegisterCustomer, sp_GetLoginInfo, sp_RecordLogin(ระบบล็อกอิน)
--   trg_PreventShowtimeOverlap                          (กันรอบฉายทับซ้อน)
--
-- ใครเรียกตัวไหน:
--   * sp_BookMovieSeats  = จอง+ชำระเงินในขั้นตอนเดียว (หน้าเคาน์เตอร์ / ทดสอบ / ตามโจทย์)
--   * sp_HoldSeats -> sp_ConfirmPayment = จองสองขั้นตอน (เว็บใช้ เพราะต้องมีนับถอยหลังระหว่างถือที่นั่ง)
--   ทั้งสองแบบเรียก sp_ValidateBookingRequest ตัวเดียวกัน กฎจึงไม่ซ้ำซ้อนและไม่ขัดกัน
--
-- รหัส error ที่ procedure ส่งกลับ (error_number):
--   50001 รอบฉายไม่พบ/ไม่เปิดจอง  50002 ไม่พบลูกค้า  50003 โปรโมชันไม่ถูกต้อง/หมดอายุ
--   50004 ที่นั่งไม่อยู่ในโรงของรอบฉาย  50005 ที่นั่งถูกจอง/ถือไว้แล้ว  50006 เลือกที่นั่งซ้ำ
--   50007 รอบฉายเริ่มแล้ว  50008 ต้องเลือกที่นั่งอย่างน้อย 1 ที่  50010 ไม่พบการจอง
--   50011 หมดเวลาถือที่นั่ง  50012 สถานะไม่ใช่รอชำระ  50013 ช่องทางชำระเงินไม่ถูกต้อง
--   50020 อีเมลซ้ำ  50021 ข้อมูลสมัครไม่ถูกต้อง  50030 รอบฉายทับซ้อน (trigger)  50099 เรียกนอก Transaction
-- =========================================================
SET NOCOUNT ON;
GO

-- =========================================================
-- ฟังก์ชัน: fn_CalculateBookingTotal  คำนวณยอดหลังส่วนลด (จุดเดียวที่คำนวณส่วนลด)
-- =========================================================
CREATE OR ALTER FUNCTION dbo.fn_CalculateBookingTotal
(
    @subtotal        DECIMAL(10,2),
    @discount_type   VARCHAR(20),     -- NULL = ไม่มีโปรโมชัน
    @discount_value  DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @total DECIMAL(10,2) = @subtotal;

    IF @discount_type = 'percentage'
        SET @total = ROUND(@subtotal * (1 - (@discount_value / 100.0)), 2);
    ELSE IF @discount_type = 'fixed'
        SET @total = @subtotal - @discount_value;

    IF @total < 0 SET @total = 0;     -- ยอดห้ามติดลบ
    RETURN @total;
END;
GO

-- =========================================================
-- ฟังก์ชัน: fn_GetValidPromotion  คืนโปรโมชันที่ใช้ได้ ณ วันนี้ (active และอยู่ในช่วงวัน)
-- =========================================================
CREATE OR ALTER FUNCTION dbo.fn_GetValidPromotion (@promotion_code VARCHAR(50))
RETURNS TABLE
AS
RETURN
(
    SELECT promotion_id, promotion_code, discount_type, discount_value
    FROM promotions
    WHERE promotion_code = @promotion_code
      AND status = 'active'
      AND CAST(SYSDATETIME() AS DATE) BETWEEN start_date AND end_date
);
GO

-- =========================================================
-- วิว: vw_TakenSeats  ที่นั่งที่ "ไม่ว่างจริง" ของแต่ละรอบ
-- นับ confirmed และ pending ที่ยังไม่หมดเวลา (pending ที่หมดเวลาถือว่าว่าง แม้ trigger ยังไม่ทำงาน)
-- ใช้กับผังที่นั่งในเว็บและกับ sp_ValidateBookingRequest
-- =========================================================
CREATE OR ALTER VIEW vw_TakenSeats
AS
SELECT b.showtime_id, t.seat_id, b.booking_status, b.expires_at
FROM tickets t
INNER JOIN bookings b ON b.booking_id = t.booking_id
WHERE t.ticket_status IN ('reserved', 'issued')
  AND (
        b.booking_status = 'confirmed'
        OR (b.booking_status = 'pending' AND b.expires_at >= SYSDATETIME())
      );
GO

-- =========================================================
-- sp_ReleaseExpiredHolds  ปล่อยที่นั่งที่หมดเวลา (เรียกก่อนจอง/ชำระเงิน หรือตั้ง SQL Agent job)
-- =========================================================
CREATE OR ALTER PROCEDURE sp_ReleaseExpiredHolds
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @now DATETIME2 = SYSDATETIME();

    UPDATE t SET ticket_status = 'cancelled'
    FROM tickets t
    INNER JOIN bookings b ON b.booking_id = t.booking_id
    WHERE b.booking_status = 'pending'
      AND b.expires_at < @now
      AND t.ticket_status = 'reserved';

    UPDATE bookings SET booking_status = 'expired'
    WHERE booking_status = 'pending' AND expires_at < @now;
END;
GO

-- =========================================================
-- sp_ValidateBookingRequest  (ตัวช่วยภายใน - ต้องเรียกภายใน Transaction)
-- กฎการจองทั้งหมดอยู่ที่นี่ที่เดียว:
--   1) รอบฉายมีอยู่ เปิดจอง (scheduled) และยังไม่เริ่มฉาย   -> 50001 / 50007
--   2) ลูกค้ามีอยู่จริง                                      -> 50002
--   3) เลือก 1-3 ที่นั่ง ไม่ซ้ำกันเอง                         -> 50008 / 50006
--   4) ที่นั่งอยู่ในโรงเดียวกับรอบฉาย                         -> 50004
--   5) ที่นั่งยังว่าง (ดูจาก vw_TakenSeats)                    -> 50005
--   6) โปรโมชัน (ถ้ามี) ใช้ได้ ณ วันนี้                        -> 50003
-- กันจองซ้ำพร้อมกัน: ล็อกแถวรอบฉายด้วย UPDLOCK+HOLDLOCK จนจบ Transaction
-- ผู้เรียกรายอื่นที่จองรอบเดียวกันจะรอจนอีกฝั่ง COMMIT/ROLLBACK แล้วเห็นผลล่าสุดเสมอ
-- =========================================================
CREATE OR ALTER PROCEDURE sp_ValidateBookingRequest
    @customer_id     INT,
    @showtime_id     INT,
    @seat_id_1       INT,
    @seat_id_2       INT = NULL,
    @seat_id_3       INT = NULL,
    @promotion_code  VARCHAR(50) = NULL,
    @ticket_price    DECIMAL(10,2) OUTPUT,
    @seat_count      INT OUTPUT,
    @promotion_id    INT OUTPUT,
    @total_amount    DECIMAL(10,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @hall_id INT, @start_time DATETIME2, @showtime_status VARCHAR(20);
    DECLARE @discount_type VARCHAR(20), @discount_value DECIMAL(10,2);
    DECLARE @requested INT;
    DECLARE @seats TABLE (seat_id INT PRIMARY KEY);

    IF @@TRANCOUNT = 0
        THROW 50099, N'sp_ValidateBookingRequest ต้องถูกเรียกภายใน Transaction', 1;

    SET @promotion_id = NULL;

    -- 1) รอบฉาย (ล็อกแถวไว้จนจบ Transaction)
    SELECT @hall_id = s.hall_id,
           @ticket_price = s.ticket_price,
           @start_time = s.start_time,
           @showtime_status = s.status
    FROM showtimes s WITH (UPDLOCK, HOLDLOCK)
    WHERE s.showtime_id = @showtime_id;

    IF @hall_id IS NULL OR @showtime_status <> 'scheduled'
        THROW 50001, N'รอบฉายนี้ไม่มีอยู่หรือไม่เปิดให้จอง', 1;

    IF @start_time <= SYSDATETIME()
        THROW 50007, N'รอบฉายนี้เริ่มฉายไปแล้ว ไม่สามารถจองได้', 1;

    -- 2) ลูกค้า
    IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = @customer_id)
        THROW 50002, N'ไม่พบข้อมูลลูกค้า', 1;

    -- 3) จำนวนและความไม่ซ้ำของที่นั่ง
    IF @seat_id_1 IS NULL
        THROW 50008, N'กรุณาเลือกที่นั่งอย่างน้อย 1 ที่', 1;

    INSERT INTO @seats (seat_id)
    SELECT DISTINCT v FROM (VALUES (@seat_id_1), (@seat_id_2), (@seat_id_3)) x(v) WHERE v IS NOT NULL;

    SET @seat_count = (SELECT COUNT(*) FROM @seats);
    SET @requested  = 1 + IIF(@seat_id_2 IS NULL, 0, 1) + IIF(@seat_id_3 IS NULL, 0, 1);

    IF @seat_count <> @requested
        THROW 50006, N'เลือกที่นั่งซ้ำกัน', 1;

    -- 4) ที่นั่งต้องอยู่ในโรงของรอบฉายนี้
    IF (SELECT COUNT(*) FROM seats s INNER JOIN @seats x ON x.seat_id = s.seat_id
        WHERE s.hall_id = @hall_id) <> @seat_count
        THROW 50004, N'มีที่นั่งที่ไม่ได้อยู่ในโรงของรอบฉายนี้', 1;

    -- 5) ที่นั่งต้องยังว่าง
    IF EXISTS (SELECT 1 FROM vw_TakenSeats v INNER JOIN @seats x ON x.seat_id = v.seat_id
               WHERE v.showtime_id = @showtime_id)
        THROW 50005, N'มีที่นั่งที่ถูกจองหรือมีคนถือไว้แล้ว', 1;

    -- 6) โปรโมชัน
    IF @promotion_code IS NOT NULL
    BEGIN
        SELECT @promotion_id = promotion_id,
               @discount_type = discount_type,
               @discount_value = discount_value
        FROM dbo.fn_GetValidPromotion(@promotion_code);

        IF @promotion_id IS NULL
            THROW 50003, N'รหัสโปรโมชันไม่ถูกต้องหรือหมดอายุ', 1;
    END;

    SET @total_amount = dbo.fn_CalculateBookingTotal(@ticket_price * @seat_count, @discount_type, @discount_value);
END;
GO

-- =========================================================
-- 1. Stored Procedure ตามโจทย์: sp_BookMovieSeats  (จอง + ชำระเงินในขั้นตอนเดียว)
-- ---------------------------------------------------------
-- ขั้นตอน:
--   1) ตรวจช่องทางชำระเงิน แล้วปล่อยที่นั่งที่หมดเวลาแล้ว
--   2) BEGIN TRANSACTION
--   3) sp_ValidateBookingRequest ตรวจรอบฉาย/ลูกค้า/ที่นั่ง/โปรโมชัน และคำนวณยอด
--   4) INSERT bookings (pending, ถือ 15 นาที) -> tickets (reserved) -> payments (paid)
--   5) UPDATE bookings = confirmed, tickets = issued
--   6) COMMIT  (ถ้ามีข้อผิดพลาดใด ๆ -> ROLLBACK ทั้งหมด แล้วส่ง error_number/error_message กลับ)
-- เว็บไม่เรียกตัวนี้ (ใช้ sp_HoldSeats + sp_ConfirmPayment แทน)
-- =========================================================
CREATE OR ALTER PROCEDURE sp_BookMovieSeats
    @customer_id     INT,
    @showtime_id     INT,
    @seat_id_1       INT,
    @seat_id_2       INT = NULL,
    @seat_id_3       INT = NULL,
    @promotion_code  VARCHAR(50) = NULL,
    @payment_method  VARCHAR(20) = 'online'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_id INT, @promotion_id INT, @seat_count INT;
    DECLARE @ticket_price DECIMAL(10,2), @total_amount DECIMAL(10,2);

    BEGIN TRY
        IF @payment_method IS NULL OR @payment_method NOT IN ('cash', 'card', 'online')
            THROW 50013, N'ช่องทางชำระเงินไม่ถูกต้อง', 1;

        EXEC sp_ReleaseExpiredHolds;

        BEGIN TRANSACTION;

        EXEC sp_ValidateBookingRequest
            @customer_id, @showtime_id, @seat_id_1, @seat_id_2, @seat_id_3, @promotion_code,
            @ticket_price OUTPUT, @seat_count OUTPUT, @promotion_id OUTPUT, @total_amount OUTPUT;

        INSERT INTO bookings (customer_id, showtime_id, promotion_id, booking_time, expires_at, booking_status, total_amount)
        VALUES (@customer_id, @showtime_id, @promotion_id, SYSDATETIME(),
                DATEADD(MINUTE, 15, SYSDATETIME()), 'pending', @total_amount);

        SET @booking_id = SCOPE_IDENTITY();

        INSERT INTO tickets (booking_id, seat_id, ticket_price, ticket_status)
        SELECT @booking_id, v, @ticket_price, 'reserved'
        FROM (VALUES (@seat_id_1), (@seat_id_2), (@seat_id_3)) x(v) WHERE v IS NOT NULL;

        INSERT INTO payments (booking_id, amount, payment_method, payment_status, paid_at)
        VALUES (@booking_id, @total_amount, @payment_method, 'paid', SYSDATETIME());

        UPDATE bookings SET booking_status = 'confirmed' WHERE booking_id = @booking_id;
        UPDATE tickets  SET ticket_status  = 'issued'    WHERE booking_id = @booking_id;

        COMMIT TRANSACTION;

        SELECT @booking_id AS booking_id, @total_amount AS total_amount,
               @seat_count AS number_of_seats, N'จองสำเร็จ' AS message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
    END CATCH
END;
GO

-- =========================================================
-- sp_HoldSeats  ขั้นที่ 1 ของเว็บ: ถือที่นั่ง 15 นาที (pending/reserved) ยังไม่มีการชำระเงิน
-- ส่งกลับ booking_id, total_amount, number_of_seats, expires_at, seconds_left (นับจากเวลาเซิร์ฟเวอร์)
-- =========================================================
CREATE OR ALTER PROCEDURE sp_HoldSeats
    @customer_id     INT,
    @showtime_id     INT,
    @seat_id_1       INT,
    @seat_id_2       INT = NULL,
    @seat_id_3       INT = NULL,
    @promotion_code  VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_id INT, @promotion_id INT, @seat_count INT;
    DECLARE @ticket_price DECIMAL(10,2), @total_amount DECIMAL(10,2);
    DECLARE @now DATETIME2, @expires_at DATETIME2;

    BEGIN TRY
        EXEC sp_ReleaseExpiredHolds;

        BEGIN TRANSACTION;

        EXEC sp_ValidateBookingRequest
            @customer_id, @showtime_id, @seat_id_1, @seat_id_2, @seat_id_3, @promotion_code,
            @ticket_price OUTPUT, @seat_count OUTPUT, @promotion_id OUTPUT, @total_amount OUTPUT;

        SET @now = SYSDATETIME();
        SET @expires_at = DATEADD(MINUTE, 15, @now);

        INSERT INTO bookings (customer_id, showtime_id, promotion_id, booking_time, expires_at, booking_status, total_amount)
        VALUES (@customer_id, @showtime_id, @promotion_id, @now, @expires_at, 'pending', @total_amount);

        SET @booking_id = SCOPE_IDENTITY();

        INSERT INTO tickets (booking_id, seat_id, ticket_price, ticket_status)
        SELECT @booking_id, v, @ticket_price, 'reserved'
        FROM (VALUES (@seat_id_1), (@seat_id_2), (@seat_id_3)) x(v) WHERE v IS NOT NULL;

        COMMIT TRANSACTION;

        SELECT @booking_id AS booking_id, @total_amount AS total_amount, @seat_count AS number_of_seats,
               @expires_at AS expires_at, DATEDIFF(SECOND, SYSDATETIME(), @expires_at) AS seconds_left,
               N'ถือที่นั่งสำเร็จ กรุณาชำระเงินก่อนหมดเวลา' AS message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
    END CATCH
END;
GO

-- =========================================================
-- sp_ConfirmPayment  ขั้นที่ 2 ของเว็บ: ยืนยันชำระเงิน (pending -> confirmed, reserved -> issued)
-- ตรวจว่าเป็นเจ้าของการจองและยังไม่หมดเวลา
-- @promotion_code (ถ้าส่งมา) จะตรวจและคำนวณยอดใหม่จากตั๋วที่ถือไว้ก่อนบันทึกชำระเงิน
-- =========================================================
CREATE OR ALTER PROCEDURE sp_ConfirmPayment
    @booking_id      INT,
    @customer_id     INT,
    @payment_method  VARCHAR(20) = 'online',
    @promotion_code  VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @status VARCHAR(20), @expires_at DATETIME2, @total DECIMAL(10,2), @paid_at DATETIME2;
    DECLARE @promotion_id INT, @discount_type VARCHAR(20), @discount_value DECIMAL(10,2), @subtotal DECIMAL(10,2);

    BEGIN TRY
        IF @payment_method IS NULL OR @payment_method NOT IN ('cash', 'card', 'online')
            THROW 50013, N'ช่องทางชำระเงินไม่ถูกต้อง', 1;

        EXEC sp_ReleaseExpiredHolds;

        BEGIN TRANSACTION;

        SELECT @status = booking_status, @expires_at = expires_at, @total = total_amount
        FROM bookings WITH (UPDLOCK, HOLDLOCK)
        WHERE booking_id = @booking_id AND customer_id = @customer_id;

        IF @status IS NULL
            THROW 50010, N'ไม่พบการจองนี้', 1;

        IF @status = 'expired' OR (@status = 'pending' AND @expires_at < SYSDATETIME())
            THROW 50011, N'หมดเวลาถือครองที่นั่งแล้ว กรุณาเลือกที่นั่งใหม่', 1;

        IF @status <> 'pending'
            THROW 50012, N'การจองนี้ไม่อยู่ในสถานะรอชำระเงิน', 1;

        IF @promotion_code IS NOT NULL
        BEGIN
            SELECT @promotion_id = promotion_id, @discount_type = discount_type, @discount_value = discount_value
            FROM dbo.fn_GetValidPromotion(@promotion_code);

            IF @promotion_id IS NULL
                THROW 50003, N'รหัสโปรโมชันไม่ถูกต้องหรือหมดอายุ', 1;

            SELECT @subtotal = SUM(ticket_price) FROM tickets
            WHERE booking_id = @booking_id AND ticket_status = 'reserved';

            SET @total = dbo.fn_CalculateBookingTotal(@subtotal, @discount_type, @discount_value);

            UPDATE bookings SET promotion_id = @promotion_id, total_amount = @total
            WHERE booking_id = @booking_id;
        END;

        SET @paid_at = SYSDATETIME();

        INSERT INTO payments (booking_id, amount, payment_method, payment_status, paid_at)
        VALUES (@booking_id, @total, @payment_method, 'paid', @paid_at);

        UPDATE bookings SET booking_status = 'confirmed' WHERE booking_id = @booking_id;
        UPDATE tickets SET ticket_status = 'issued'
        WHERE booking_id = @booking_id AND ticket_status = 'reserved';

        COMMIT TRANSACTION;

        SELECT @booking_id AS booking_id, @total AS total_amount, @paid_at AS paid_at,
               N'ชำระเงินสำเร็จ ออกตั๋วแล้ว' AS message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
    END CATCH
END;
GO

-- =========================================================
-- sp_CancelHold  ยกเลิกการถือที่นั่งก่อนชำระเงิน (ปล่อยที่นั่งทันที)
-- ส่งกลับ released_bookings: 1 = ยกเลิกแล้ว, 0 = ไม่พบ/ไม่ใช่ของผู้ใช้/ไม่ได้อยู่ในสถานะ pending
-- =========================================================
CREATE OR ALTER PROCEDURE sp_CancelHold
    @booking_id   INT,
    @customer_id  INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @released TABLE (booking_id INT PRIMARY KEY);

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE t SET ticket_status = 'cancelled'
        FROM tickets t
        INNER JOIN bookings b ON b.booking_id = t.booking_id
        WHERE b.booking_id = @booking_id AND b.customer_id = @customer_id
          AND b.booking_status = 'pending' AND t.ticket_status = 'reserved';

        UPDATE bookings SET booking_status = 'cancelled'
        OUTPUT inserted.booking_id INTO @released (booking_id)
        WHERE booking_id = @booking_id AND customer_id = @customer_id AND booking_status = 'pending';

        COMMIT TRANSACTION;

        SELECT COUNT(*) AS released_bookings FROM @released;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
    END CATCH
END;
GO

-- =========================================================
-- ระบบล็อกอิน (รหัสผ่านแฮช PBKDF2 ฝั่ง C# เท่านั้น - SQL ไม่เคยเห็นรหัสผ่านจริง)
-- =========================================================
CREATE OR ALTER PROCEDURE sp_RegisterCustomer
    @name           NVARCHAR(150),
    @email          VARCHAR(255),
    @phone          VARCHAR(20),
    @password_hash  VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @name  = LTRIM(RTRIM(@name));
        SET @email = LOWER(LTRIM(RTRIM(@email)));
        SET @phone = LTRIM(RTRIM(@phone));

        IF LEN(ISNULL(@name, N'')) < 2
            THROW 50021, N'กรุณากรอกชื่อ-นามสกุล', 1;
        IF @email IS NULL OR @email NOT LIKE '%_@_%._%' OR CHARINDEX(' ', @email) > 0
            THROW 50021, N'รูปแบบอีเมลไม่ถูกต้อง', 1;
        IF @phone IS NULL OR @phone LIKE '%[^0-9]%' OR LEN(@phone) NOT BETWEEN 9 AND 15
            THROW 50021, N'เบอร์โทรต้องเป็นตัวเลข 9-15 หลัก', 1;
        IF @password_hash IS NULL OR LEN(@password_hash) < 20
            THROW 50021, N'ข้อมูลรหัสผ่านไม่ถูกต้อง', 1;

        IF EXISTS (SELECT 1 FROM customers WHERE email = @email)
            THROW 50020, N'อีเมลนี้ถูกใช้สมัครแล้ว', 1;

        INSERT INTO customers (name, email, phone, password_hash)
        VALUES (@name, @email, @phone, @password_hash);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS customer_id, N'สมัครสมาชิกสำเร็จ' AS message;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627)     -- สมัครอีเมลเดียวกันพร้อมกัน (ชน UNIQUE)
            SELECT 50020 AS error_number, N'อีเมลนี้ถูกใช้สมัครแล้ว' AS error_message;
        ELSE
            SELECT ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE sp_GetLoginInfo
    @email VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT customer_id, name, password_hash, user_role
    FROM customers
    WHERE email = LOWER(LTRIM(RTRIM(@email)));
END;
GO

CREATE OR ALTER PROCEDURE sp_RecordLogin
    @customer_id INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE customers SET last_login_at = SYSDATETIME() WHERE customer_id = @customer_id;
END;
GO

-- =========================================================
-- 2. Trigger ตามโจทย์: trg_ReleaseExpiredSeatLocks
-- ---------------------------------------------------------
-- หน้าที่ (พฤติกรรมเดิมคงไว้): เมื่อมี INSERT/UPDATE bookings
--   - การจอง pending ที่หมดเวลาถือครอง (ทั้งตาราง) -> 'expired'
--   - ตั๋ว reserved ของการจองเหล่านั้น -> 'cancelled'
-- ปรับปรุง (ผลลัพธ์เท่าเดิม แต่ทำงานน้อยลง):
--   - เดิมขั้นที่ 2 สแกนการจอง expired ทั้งตารางทุกครั้ง (โตขึ้นเรื่อย ๆ)
--     ตอนนี้ใช้ OUTPUT เก็บเฉพาะ booking_id ที่เพิ่งเปลี่ยนเป็น expired ในรอบนี้
--     บวกแถวใน inserted ที่สถานะเป็น expired อยู่แล้ว มาตั้งตั๋วเป็น cancelled
--   - ขั้นที่ 1 ใช้ ix_bookings_status_expires (booking_status, expires_at) จึงแตะเฉพาะ pending
--   - กันเรียกซ้ำซ้อนด้วย TRIGGER_NESTLEVEL
-- =========================================================
CREATE OR ALTER TRIGGER trg_ReleaseExpiredSeatLocks
ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRIGGER_NESTLEVEL(@@PROCID) > 1 RETURN;

    DECLARE @now DATETIME2 = SYSDATETIME();
    DECLARE @released TABLE (booking_id INT PRIMARY KEY);

    UPDATE bookings SET booking_status = 'expired'
    OUTPUT inserted.booking_id INTO @released (booking_id)
    WHERE booking_status = 'pending' AND expires_at < @now;

    UPDATE t SET ticket_status = 'cancelled'
    FROM tickets t
    WHERE t.ticket_status = 'reserved'
      AND (
            EXISTS (SELECT 1 FROM @released r WHERE r.booking_id = t.booking_id)
         OR EXISTS (SELECT 1 FROM inserted i WHERE i.booking_id = t.booking_id AND i.booking_status = 'expired')
      );
END;
GO

-- =========================================================
-- Trigger: trg_PreventShowtimeOverlap  (งานที่ 1)
-- ห้ามรอบฉายใหม่/ที่แก้ไข ซ้อนเวลากับรอบอื่นในโรงเดียวกัน (ไม่นับรอบ cancelled)
-- เงื่อนไขชน:  new_start < existing_end  AND  new_end > existing_start
-- (รอบที่จบเวลาเดียวกับที่อีกรอบเริ่มพอดี ไม่นับว่าชน)
-- รองรับหลายแถวในคำสั่งเดียว: AFTER trigger เห็นแถวใหม่ทั้งหมดในตาราง จึงตรวจชนกับรอบเดิม
--   และชนกันเองภายในชุดที่เพิ่งแทรก/แก้ไขได้ในคราวเดียว
-- ชนแล้ว: ROLLBACK + THROW 50030 ข้อความภาษาไทยบอกโรง เวลา และรอบที่ชน
-- =========================================================
CREATE OR ALTER TRIGGER trg_PreventShowtimeOverlap
ON showtimes
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- UPDATE ที่ไม่แตะคอลัมน์ที่เกี่ยวข้อง ไม่ต้องตรวจ (ถ้าเป็น INSERT UPDATE() เป็นจริงทุกคอลัมน์)
    IF NOT (UPDATE(hall_id) OR UPDATE(start_time) OR UPDATE(end_time) OR UPDATE(status))
        RETURN;

    DECLARE @msg NVARCHAR(500);

    SELECT TOP (1) @msg =
           N'รอบฉายทับซ้อนกับรอบอื่นในโรงเดียวกัน (' + h.hall_name + N'): รอบที่บันทึก '
         + CONVERT(NVARCHAR(16), i.start_time, 120) + N' ถึง ' + CONVERT(NVARCHAR(16), i.end_time, 120)
         + N' ชนกับรอบ #' + CAST(s.showtime_id AS NVARCHAR(10)) + N' ('
         + CONVERT(NVARCHAR(16), s.start_time, 120) + N' ถึง ' + CONVERT(NVARCHAR(16), s.end_time, 120)
         + N') กรุณาเลือกเวลาหรือโรงอื่น'
    FROM inserted i
    INNER JOIN showtimes s
            ON s.hall_id = i.hall_id
           AND s.showtime_id <> i.showtime_id
           AND s.status <> 'cancelled'
           AND i.start_time < s.end_time
           AND i.end_time   > s.start_time
    INNER JOIN cinema_halls h ON h.hall_id = i.hall_id
    WHERE i.status <> 'cancelled'
    ORDER BY i.showtime_id, s.start_time;

    IF @msg IS NOT NULL
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50030, @msg, 1;
    END;
END;
GO

-- =========================================================
-- 3. Reporting View ตามโจทย์: vw_BoxOfficeOccupancyReport
-- สรุปรายได้รวมของแต่ละภาพยนตร์ และอัตราการครองที่นั่ง (Occupancy Rate %)
-- (นิยามเดิมไม่เปลี่ยน)
-- =========================================================
CREATE OR ALTER VIEW vw_BoxOfficeOccupancyReport
AS
SELECT
    m.movie_id,
    m.title AS movie_title,
    m.genre,
    COUNT(DISTINCT s.showtime_id) AS total_showtimes,
    COUNT(CASE WHEN t.ticket_status = 'issued' THEN 1 END) AS tickets_sold,
    ISNULL(SUM(CASE WHEN t.ticket_status = 'issued' THEN t.ticket_price END), 0) AS total_revenue,
    (
        SELECT SUM(ch.capacity)
        FROM showtimes s2
        INNER JOIN cinema_halls ch ON s2.hall_id = ch.hall_id
        WHERE s2.movie_id = m.movie_id
          AND s2.status IN ('scheduled', 'completed')
    ) AS total_capacity,
    CASE
        WHEN (
            SELECT SUM(ch.capacity)
            FROM showtimes s2
            INNER JOIN cinema_halls ch ON s2.hall_id = ch.hall_id
            WHERE s2.movie_id = m.movie_id
              AND s2.status IN ('scheduled', 'completed')
        ) > 0
        THEN CAST(
            COUNT(CASE WHEN t.ticket_status = 'issued' THEN 1 END) * 100.0 /
            (
                SELECT SUM(ch.capacity)
                FROM showtimes s2
                INNER JOIN cinema_halls ch ON s2.hall_id = ch.hall_id
                WHERE s2.movie_id = m.movie_id
                  AND s2.status IN ('scheduled', 'completed')
            )
        AS DECIMAL(5,2))
        ELSE 0
    END AS occupancy_rate_percent
FROM movies m
LEFT JOIN showtimes s ON m.movie_id = s.movie_id
LEFT JOIN bookings b ON s.showtime_id = b.showtime_id
LEFT JOIN tickets t ON b.booking_id = t.booking_id
GROUP BY m.movie_id, m.title, m.genre;
GO

PRINT N'logic.sql เสร็จสมบูรณ์';
GO
