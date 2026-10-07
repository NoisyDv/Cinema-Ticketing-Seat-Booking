-- =========================================================
-- logic.sql
-- ไฟล์นี้ประกอบด้วย 3 ส่วนหลักตามเกณฑ์ของโครงงาน:
--   1. Stored Procedure  : sp_BookMovieSeats
--   2. Trigger           : trg_ReleaseExpiredSeatLocks
--   3. Reporting View    : vw_BoxOfficeOccupancyReport
--
-- หัวข้อที่ 7: ระบบจองตั๋วภาพยนตร์และผังที่นั่ง
-- DBMS: Microsoft SQL Server
-- =========================================================


-- =========================================================
-- 1. Stored Procedure: sp_BookMovieSeats
-- ---------------------------------------------------------
-- หน้าที่:
--   - รับข้อมูลลูกค้า + รอบฉาย + ที่นั่งที่ต้องการจอง
--   - ตรวจสอบว่าที่นั่งว่างจริงหรือไม่
--   - สร้างรายการจอง (booking) สถานะ pending ก่อน
--   - คำนวณราคาและส่วนลด (ถ้ามีโปรโมชัน)
--   - บันทึกตั๋วและข้อมูลการชำระเงิน
--   - ถ้าทุกอย่างสำเร็จ → ยืนยันการจอง (confirmed) และ COMMIT
--   - ถ้ามีปัญหา (ที่นั่งถูกจองแล้ว / ข้อมูลผิด) → ROLLBACK ทั้งหมด
--
-- ใช้ Transaction เพื่อให้ได้คุณสมบัติ ACID
-- =========================================================
CREATE OR ALTER PROCEDURE sp_BookMovieSeats
    @customer_id     INT,                  -- รหัสลูกค้า
    @showtime_id     INT,                  -- รหัสรอบฉาย
    @seat_id_1       INT,                  -- ที่นั่งใบที่ 1 (บังคับ)
    @seat_id_2       INT = NULL,           -- ที่นั่งใบที่ 2 (ไม่บังคับ)
    @seat_id_3       INT = NULL,           -- ที่นั่งใบที่ 3 (ไม่บังคับ)
    @promotion_code  VARCHAR(50) = NULL,   -- รหัสโปรโมชัน (ไม่บังคับ)
    @payment_method  VARCHAR(20) = 'online' -- ช่องทางชำระเงิน
AS
BEGIN
    SET NOCOUNT ON;

    -- ตัวแปรที่ใช้ในขั้นตอนการจอง
    DECLARE @booking_id INT;
    DECLARE @promotion_id INT = NULL;
    DECLARE @ticket_price DECIMAL(10,2);
    DECLARE @discount_type VARCHAR(20);
    DECLARE @discount_value DECIMAL(10,2);
    DECLARE @total_amount DECIMAL(10,2) = 0;
    DECLARE @hall_id INT;
    DECLARE @seat_count INT = 1;
    DECLARE @error_message NVARCHAR(400);

    BEGIN TRY
        BEGIN TRANSACTION;   -- เริ่มต้น Transaction

        -- -------------------------------------------------
        -- ขั้นตอนที่ 1: ตรวจสอบข้อมูลพื้นฐาน
        -- -------------------------------------------------

        -- ตรวจสอบว่ารอบฉายมีอยู่และยังเปิดให้จอง
        IF NOT EXISTS (
            SELECT 1 FROM showtimes
            WHERE showtime_id = @showtime_id
              AND status = 'scheduled'
        )
        BEGIN
            SET @error_message = N'รอบฉายนี้ไม่มีอยู่หรือไม่เปิดให้จอง';
            THROW 50001, @error_message, 1;
        END;

        -- ตรวจสอบว่าลูกค้ามีอยู่จริง
        IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = @customer_id)
        BEGIN
            SET @error_message = N'ไม่พบข้อมูลลูกค้า';
            THROW 50002, @error_message, 1;
        END;

        -- ดึงราคาตั๋วและรหัสโรงจากรอบฉาย
        SELECT @ticket_price = ticket_price,
               @hall_id = hall_id
        FROM showtimes
        WHERE showtime_id = @showtime_id;

        -- -------------------------------------------------
        -- ขั้นตอนที่ 2: ตรวจสอบโปรโมชัน (ถ้ามี)
        -- -------------------------------------------------
        IF @promotion_code IS NOT NULL
        BEGIN
            SELECT @promotion_id = promotion_id,
                   @discount_type = discount_type,
                   @discount_value = discount_value
            FROM promotions
            WHERE promotion_code = @promotion_code
              AND status = 'active'
              AND CAST(GETDATE() AS DATE) BETWEEN start_date AND end_date;

            IF @promotion_id IS NULL
            BEGIN
                SET @error_message = N'รหัสโปรโมชันไม่ถูกต้องหรือหมดอายุ';
                THROW 50003, @error_message, 1;
            END;
        END;

        -- -------------------------------------------------
        -- ขั้นตอนที่ 3: ตรวจสอบที่นั่งว่าง
        -- (ที่นั่งต้องอยู่ในโรงเดียวกับรอบฉาย และยังไม่ถูกจอง)
        -- -------------------------------------------------

        -- ตรวจสอบที่นั่งใบที่ 1
        IF NOT EXISTS (
            SELECT 1 FROM seats
            WHERE seat_id = @seat_id_1 AND hall_id = @hall_id
        )
        BEGIN
            SET @error_message = N'ที่นั่งที่ 1 ไม่ได้อยู่ในโรงของรอบฉายนี้';
            THROW 50004, @error_message, 1;
        END;

        IF EXISTS (
            SELECT 1
            FROM tickets t
            INNER JOIN bookings b ON t.booking_id = b.booking_id
            WHERE t.seat_id = @seat_id_1
              AND b.showtime_id = @showtime_id
              AND t.ticket_status IN ('reserved', 'issued')
              AND b.booking_status IN ('pending', 'confirmed')
        )
        BEGIN
            SET @error_message = N'ที่นั่งที่ 1 ถูกจองไปแล้ว';
            THROW 50005, @error_message, 1;
        END;

        SET @total_amount = @ticket_price;

        -- ตรวจสอบที่นั่งใบที่ 2 (ถ้ามี)
        IF @seat_id_2 IS NOT NULL
        BEGIN
            SET @seat_count = @seat_count + 1;

            IF NOT EXISTS (
                SELECT 1 FROM seats
                WHERE seat_id = @seat_id_2 AND hall_id = @hall_id
            )
            BEGIN
                SET @error_message = N'ที่นั่งที่ 2 ไม่ได้อยู่ในโรงของรอบฉายนี้';
                THROW 50004, @error_message, 1;
            END;

            IF EXISTS (
                SELECT 1
                FROM tickets t
                INNER JOIN bookings b ON t.booking_id = b.booking_id
                WHERE t.seat_id = @seat_id_2
                  AND b.showtime_id = @showtime_id
                  AND t.ticket_status IN ('reserved', 'issued')
                  AND b.booking_status IN ('pending', 'confirmed')
            )
            BEGIN
                SET @error_message = N'ที่นั่งที่ 2 ถูกจองไปแล้ว';
                THROW 50005, @error_message, 1;
            END;

            SET @total_amount = @total_amount + @ticket_price;
        END;

        -- ตรวจสอบที่นั่งใบที่ 3 (ถ้ามี)
        IF @seat_id_3 IS NOT NULL
        BEGIN
            SET @seat_count = @seat_count + 1;

            IF NOT EXISTS (
                SELECT 1 FROM seats
                WHERE seat_id = @seat_id_3 AND hall_id = @hall_id
            )
            BEGIN
                SET @error_message = N'ที่นั่งที่ 3 ไม่ได้อยู่ในโรงของรอบฉายนี้';
                THROW 50004, @error_message, 1;
            END;

            IF EXISTS (
                SELECT 1
                FROM tickets t
                INNER JOIN bookings b ON t.booking_id = b.booking_id
                WHERE t.seat_id = @seat_id_3
                  AND b.showtime_id = @showtime_id
                  AND t.ticket_status IN ('reserved', 'issued')
                  AND b.booking_status IN ('pending', 'confirmed')
            )
            BEGIN
                SET @error_message = N'ที่นั่งที่ 3 ถูกจองไปแล้ว';
                THROW 50005, @error_message, 1;
            END;

            SET @total_amount = @total_amount + @ticket_price;
        END;

        -- -------------------------------------------------
        -- ขั้นตอนที่ 4: คำนวณส่วนลด (ถ้ามีโปรโมชัน)
        -- -------------------------------------------------
        IF @promotion_id IS NOT NULL
        BEGIN
            IF @discount_type = 'percentage'
                SET @total_amount = @total_amount * (1 - (@discount_value / 100.0));
            ELSE
                SET @total_amount = @total_amount - @discount_value;

            -- ป้องกันไม่ให้ยอดติดลบ
            IF @total_amount < 0
                SET @total_amount = 0;
        END;

        -- -------------------------------------------------
        -- ขั้นตอนที่ 5: สร้างรายการจอง (สถานะ pending ก่อน)
        -- -------------------------------------------------
        INSERT INTO bookings (
            customer_id,
            showtime_id,
            promotion_id,
            booking_time,
            expires_at,
            booking_status,
            total_amount
        )
        VALUES (
            @customer_id,
            @showtime_id,
            @promotion_id,
            SYSDATETIME(),
            DATEADD(MINUTE, 15, SYSDATETIME()),   -- ถือครองที่นั่ง 15 นาที
            'pending',
            @total_amount
        );

        SET @booking_id = SCOPE_IDENTITY();

        -- -------------------------------------------------
        -- ขั้นตอนที่ 6: สร้างตั๋ว (สถานะ reserved)
        -- -------------------------------------------------
        INSERT INTO tickets (booking_id, seat_id, ticket_price, ticket_status)
        VALUES (@booking_id, @seat_id_1, @ticket_price, 'reserved');

        IF @seat_id_2 IS NOT NULL
            INSERT INTO tickets (booking_id, seat_id, ticket_price, ticket_status)
            VALUES (@booking_id, @seat_id_2, @ticket_price, 'reserved');

        IF @seat_id_3 IS NOT NULL
            INSERT INTO tickets (booking_id, seat_id, ticket_price, ticket_status)
            VALUES (@booking_id, @seat_id_3, @ticket_price, 'reserved');

        -- -------------------------------------------------
        -- ขั้นตอนที่ 7: บันทึกการชำระเงินและยืนยันการจอง
        -- -------------------------------------------------
        INSERT INTO payments (
            booking_id,
            amount,
            payment_method,
            payment_status,
            paid_at
        )
        VALUES (
            @booking_id,
            @total_amount,
            @payment_method,
            'paid',
            SYSDATETIME()
        );

        -- อัปเดตสถานะการจองเป็น confirmed และตั๋วเป็น issued
        UPDATE bookings
        SET booking_status = 'confirmed'
        WHERE booking_id = @booking_id;

        UPDATE tickets
        SET ticket_status = 'issued'
        WHERE booking_id = @booking_id;

        -- ทุกอย่างสำเร็จ → บันทึกถาวร
        COMMIT TRANSACTION;

        -- ส่งผลลัพธ์กลับไปให้ผู้เรียกใช้
        SELECT
            @booking_id AS booking_id,
            @total_amount AS total_amount,
            @seat_count AS number_of_seats,
            N'จองสำเร็จ' AS message;

    END TRY
    BEGIN CATCH
        -- เกิดข้อผิดพลาด → ยกเลิกทั้งหมด
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- ส่งข้อความ error กลับไป
        SELECT
            ERROR_NUMBER() AS error_number,
            ERROR_MESSAGE() AS error_message;
    END CATCH
END;
GO


-- =========================================================
-- 2. Trigger: trg_ReleaseExpiredSeatLocks
-- ---------------------------------------------------------
-- หน้าที่:
--   - ทำงานอัตโนมัติเมื่อมีการ INSERT หรือ UPDATE ตาราง bookings
--   - ค้นหาการจองที่สถานะเป็น 'pending' และหมดเวลาถือครองแล้ว
--   - เปลี่ยนสถานะการจองเป็น 'expired'
--   - เปลี่ยนสถานะตั๋วที่เกี่ยวข้องเป็น 'cancelled'
--
-- ทำให้ที่นั่งถูกปล่อยกลับมาให้คนอื่นจองได้
-- =========================================================
CREATE OR ALTER TRIGGER trg_ReleaseExpiredSeatLocks
ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- อัปเดตการจองที่หมดเวลาถือครอง
    UPDATE b
    SET booking_status = 'expired'
    FROM bookings b
    WHERE b.booking_status = 'pending'
      AND b.expires_at < SYSDATETIME();

    -- ยกเลิกตั๋วของการจองที่เพิ่งหมดเวลา
    UPDATE t
    SET ticket_status = 'cancelled'
    FROM tickets t
    INNER JOIN bookings b ON t.booking_id = b.booking_id
    WHERE b.booking_status = 'expired'
      AND t.ticket_status = 'reserved';
END;
GO


-- =========================================================
-- 3. Reporting View: vw_BoxOfficeOccupancyReport
-- ---------------------------------------------------------
-- หน้าที่:
--   - สรุปข้อมูลสำหรับผู้บริหาร
--   - แสดงรายได้รวมของแต่ละภาพยนตร์
--   - แสดงอัตราการครองที่นั่ง (Occupancy Rate %)
-- =========================================================
CREATE OR ALTER VIEW vw_BoxOfficeOccupancyReport
AS
SELECT
    m.movie_id,
    m.title AS movie_title,
    m.genre,

    -- จำนวนรอบฉายทั้งหมดของหนังเรื่องนี้
    COUNT(DISTINCT s.showtime_id) AS total_showtimes,

    -- จำนวนตั๋วที่ขายได้จริง (สถานะ issued)
    COUNT(CASE WHEN t.ticket_status = 'issued' THEN 1 END) AS tickets_sold,

    -- รายได้รวมจากตั๋วที่ขายได้
    ISNULL(SUM(CASE WHEN t.ticket_status = 'issued' THEN t.ticket_price END), 0) AS total_revenue,

    -- ความจุรวมของทุกโรงที่ใช้ฉายหนังเรื่องนี้
    (
        SELECT SUM(ch.capacity)
        FROM showtimes s2
        INNER JOIN cinema_halls ch ON s2.hall_id = ch.hall_id
        WHERE s2.movie_id = m.movie_id
          AND s2.status IN ('scheduled', 'completed')
    ) AS total_capacity,

    -- อัตราการครองที่นั่ง (%) = (ตั๋วที่ขายได้ / ความจุรวม) * 100
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
GROUP BY
    m.movie_id,
    m.title,
    m.genre;
GO


-- =========================================================
-- ตัวอย่างการเรียกใช้ (สำหรับทดสอบ)
-- =========================================================
/*
-- ตัวอย่างที่ 1: จองที่นั่ง 1 ที่ (ไม่มีโปรโมชัน)
EXEC sp_BookMovieSeats
    @customer_id = 1,
    @showtime_id = 1,
    @seat_id_1 = 1,
    @payment_method = 'online';

-- ตัวอย่างที่ 2: จองที่นั่ง 2 ที่ พร้อมใช้โปรโมชัน
EXEC sp_BookMovieSeats
    @customer_id = 2,
    @showtime_id = 1,
    @seat_id_1 = 5,
    @seat_id_2 = 6,
    @promotion_code = 'PROMO001',
    @payment_method = 'card';

-- ดูรายงานรายได้และอัตราการครองที่นั่ง
SELECT * FROM vw_BoxOfficeOccupancyReport
ORDER BY total_revenue DESC;
*/
