-- =========================================================
-- migration.sql
-- รันหลัง schema.sql, data.sql และ logic.sql (รันซ้ำได้ปลอดภัย)
-- เพิ่ม: 1) poster_url  2) ระบบล็อกอิน  3) กรองการถือครองที่นั่งที่หมดเวลา
--        4) แยกการจองเป็น "ถือที่นั่ง" (sp_HoldSeats) กับ "ยืนยันชำระเงิน" (sp_ConfirmPayment)
-- DBMS: Microsoft SQL Server
-- =========================================================

-- ---------------------------------------------------------
-- 1. movies.poster_url : ลิงก์รูปโปสเตอร์ (ว่างได้ ฝั่งเว็บใช้บล็อกสีแทนเมื่อไม่มีรูป)
-- ---------------------------------------------------------
IF COL_LENGTH('movies', 'poster_url') IS NULL
    ALTER TABLE movies ADD poster_url VARCHAR(500) NULL;
GO

-- ---------------------------------------------------------
-- 2. customers : เพิ่มคอลัมน์สำหรับล็อกอิน
--    password_hash เก็บค่าที่แฮชจากฝั่ง C# (PBKDF2 + salt) ห้ามเก็บรหัสผ่านจริง
--    ลูกค้าเดิมจากไฟล์ data.sql จะมี password_hash เป็น NULL จนกว่าจะตั้งรหัสผ่าน
-- ---------------------------------------------------------
IF COL_LENGTH('customers', 'password_hash') IS NULL
    ALTER TABLE customers ADD password_hash VARCHAR(255) NULL;

IF COL_LENGTH('customers', 'user_role') IS NULL
    ALTER TABLE customers ADD user_role VARCHAR(20) NOT NULL
        CONSTRAINT df_customers_user_role DEFAULT 'customer';

IF COL_LENGTH('customers', 'last_login_at') IS NULL
    ALTER TABLE customers ADD last_login_at DATETIME2 NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'chk_customers_user_role')
    ALTER TABLE customers
        ADD CONSTRAINT chk_customers_user_role CHECK (user_role IN ('customer', 'admin'));
GO

-- สมัครสมาชิก (รับ password_hash ที่แฮชแล้วจาก C#)
CREATE OR ALTER PROCEDURE sp_RegisterCustomer
    @name           VARCHAR(150),
    @email          VARCHAR(255),
    @phone          VARCHAR(20),
    @password_hash  VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM customers WHERE email = @email)
            THROW 50020, N'อีเมลนี้ถูกใช้สมัครแล้ว', 1;

        INSERT INTO customers (name, email, phone, password_hash)
        VALUES (@name, @email, @phone, @password_hash);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS customer_id, N'สมัครสมาชิกสำเร็จ' AS message;
    END TRY
    BEGIN CATCH
        SELECT ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
    END CATCH
END;
GO

-- ดึงข้อมูลสำหรับตรวจรหัสผ่านฝั่ง C# (ไม่ตรวจรหัสผ่านใน SQL)
CREATE OR ALTER PROCEDURE sp_GetLoginInfo
    @email VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT customer_id, name, password_hash, user_role
    FROM customers
    WHERE email = @email;
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

-- ตั้งแอดมินคนแรก (แก้อีเมลก่อนรัน หลังสมัครสมาชิกแล้ว):
-- UPDATE customers SET user_role = 'admin' WHERE email = 'your-admin@example.com';

-- ---------------------------------------------------------
-- 3. ที่นั่งที่ "ไม่ว่างจริง"
--    นับเฉพาะ confirmed และ pending ที่ยังไม่หมดเวลา
--    pending ที่ expires_at เลยเวลาแล้ว ถือว่าว่าง แม้ trigger ยังไม่ทำงาน
--    ใช้กับผังที่นั่งในเว็บ: SELECT seat_id FROM vw_TakenSeats WHERE showtime_id = @id
-- ---------------------------------------------------------
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

-- ปล่อยที่นั่งที่หมดเวลา (เรียกจาก procedure อื่น หรือตั้ง SQL Agent job ทุก 1 นาที)
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

-- ---------------------------------------------------------
-- 4a. ขั้นที่ 1: ถือที่นั่ง (สถานะ pending, ถือ 15 นาที, ยังไม่มีการชำระเงิน)
--     โปรโมชันถูกล็อกตั้งแต่ขั้นนี้ ยอดรวมจึงคงที่ตอนชำระเงิน
--     ล็อกแถวรอบฉาย (UPDLOCK, HOLDLOCK) เพื่อกันสองคนจองที่นั่งเดียวกันพร้อมกัน
-- ---------------------------------------------------------
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

    DECLARE @booking_id INT, @promotion_id INT = NULL, @hall_id INT;
    DECLARE @ticket_price DECIMAL(10,2), @discount_type VARCHAR(20), @discount_value DECIMAL(10,2);
    DECLARE @subtotal DECIMAL(10,2), @total_amount DECIMAL(10,2);
    DECLARE @seat_count INT, @requested INT;
    DECLARE @expires_at DATETIME2 = DATEADD(MINUTE, 15, SYSDATETIME());
    DECLARE @seats TABLE (seat_id INT PRIMARY KEY);

    INSERT INTO @seats (seat_id)
    SELECT DISTINCT v FROM (VALUES (@seat_id_1), (@seat_id_2), (@seat_id_3)) x(v) WHERE v IS NOT NULL;

    SET @seat_count = (SELECT COUNT(*) FROM @seats);
    SET @requested  = 1 + IIF(@seat_id_2 IS NULL, 0, 1) + IIF(@seat_id_3 IS NULL, 0, 1);

    BEGIN TRY
        EXEC sp_ReleaseExpiredHolds;   -- เคลียร์ที่หมดเวลาก่อนตรวจที่นั่งว่าง

        BEGIN TRANSACTION;

        SELECT @ticket_price = ticket_price, @hall_id = hall_id
        FROM showtimes WITH (UPDLOCK, HOLDLOCK)
        WHERE showtime_id = @showtime_id AND status = 'scheduled';

        IF @hall_id IS NULL
            THROW 50001, N'รอบฉายนี้ไม่มีอยู่หรือไม่เปิดให้จอง', 1;

        IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = @customer_id)
            THROW 50002, N'ไม่พบข้อมูลลูกค้า', 1;

        IF @seat_count <> @requested
            THROW 50006, N'เลือกที่นั่งซ้ำกัน', 1;

        IF (SELECT COUNT(*) FROM seats s INNER JOIN @seats x ON x.seat_id = s.seat_id
            WHERE s.hall_id = @hall_id) <> @seat_count
            THROW 50004, N'มีที่นั่งที่ไม่ได้อยู่ในโรงของรอบฉายนี้', 1;

        IF EXISTS (SELECT 1 FROM vw_TakenSeats v INNER JOIN @seats x ON x.seat_id = v.seat_id
                   WHERE v.showtime_id = @showtime_id)
            THROW 50005, N'มีที่นั่งที่ถูกจองหรือมีคนถือไว้แล้ว', 1;

        IF @promotion_code IS NOT NULL
        BEGIN
            SELECT @promotion_id = promotion_id, @discount_type = discount_type, @discount_value = discount_value
            FROM promotions
            WHERE promotion_code = @promotion_code AND status = 'active'
              AND CAST(GETDATE() AS DATE) BETWEEN start_date AND end_date;

            IF @promotion_id IS NULL
                THROW 50003, N'รหัสโปรโมชันไม่ถูกต้องหรือหมดอายุ', 1;
        END;

        SET @subtotal = @ticket_price * @seat_count;
        SET @total_amount = @subtotal;
        IF @promotion_id IS NOT NULL
        BEGIN
            IF @discount_type = 'percentage'
                SET @total_amount = ROUND(@subtotal * (1 - (@discount_value / 100.0)), 2);
            ELSE
                SET @total_amount = @subtotal - @discount_value;
            IF @total_amount < 0 SET @total_amount = 0;
        END;

        INSERT INTO bookings (customer_id, showtime_id, promotion_id, booking_time, expires_at, booking_status, total_amount)
        VALUES (@customer_id, @showtime_id, @promotion_id, SYSDATETIME(), @expires_at, 'pending', @total_amount);

        SET @booking_id = SCOPE_IDENTITY();

        INSERT INTO tickets (booking_id, seat_id, ticket_price, ticket_status)
        SELECT @booking_id, seat_id, @ticket_price, 'reserved' FROM @seats;

        COMMIT TRANSACTION;

        SELECT @booking_id AS booking_id, @total_amount AS total_amount, @seat_count AS number_of_seats,
               @expires_at AS expires_at, N'ถือที่นั่งสำเร็จ กรุณาชำระเงินก่อนหมดเวลา' AS message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
    END CATCH
END;
GO

-- ---------------------------------------------------------
-- 4b. ขั้นที่ 2: ยืนยันชำระเงิน (pending -> confirmed, reserved -> issued)
--     ตรวจว่าเป็นเจ้าของการจอง และยังไม่หมดเวลา
-- ---------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_ConfirmPayment
    @booking_id      INT,
    @customer_id     INT,
    @payment_method  VARCHAR(20) = 'online'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @status VARCHAR(20), @expires_at DATETIME2, @total DECIMAL(10,2), @paid_at DATETIME2;

    BEGIN TRY
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

-- ---------------------------------------------------------
-- 4c. ยกเลิกการถือที่นั่งก่อนชำระเงิน (ปล่อยที่นั่งทันที)
-- ---------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_CancelHold
    @booking_id   INT,
    @customer_id  INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @rows INT;

    BEGIN TRANSACTION;

    UPDATE t SET ticket_status = 'cancelled'
    FROM tickets t
    INNER JOIN bookings b ON b.booking_id = t.booking_id
    WHERE b.booking_id = @booking_id AND b.customer_id = @customer_id
      AND b.booking_status = 'pending' AND t.ticket_status = 'reserved';

    UPDATE bookings SET booking_status = 'cancelled'
    WHERE booking_id = @booking_id AND customer_id = @customer_id AND booking_status = 'pending';

    SET @rows = @@ROWCOUNT;
    COMMIT TRANSACTION;

    SELECT @rows AS released_bookings;   -- 0 = ไม่พบ หรือไม่ได้อยู่ในสถานะ pending
END;
GO

-- หมายเหตุ: sp_BookMovieSeats เดิมยังอยู่ (จอง+จ่ายขั้นตอนเดียว) เว็บใหม่ควรเรียก
--           sp_HoldSeats -> sp_ConfirmPayment แทน
