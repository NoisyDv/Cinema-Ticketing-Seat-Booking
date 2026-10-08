-- =========================================================
-- logic.sql  (refactored)
-- ไฟล์นี้ประกอบด้วย 3 ส่วนหลักตามเกณฑ์ของโครงงาน:
--   1. Stored Procedure  : sp_BookMovieSeats
--   2. Trigger           : trg_ReleaseExpiredSeatLocks
--   3. Reporting View    : vw_BoxOfficeOccupancyReport
--
-- หัวข้อที่ 7: ระบบจองตั๋วภาพยนตร์และผังที่นั่ง
-- DBMS: Microsoft SQL Server 2016 SP1 ขึ้นไป (ใช้ CREATE OR ALTER, STRING_SPLIT, THROW)
--
-- รันไฟล์นี้หลังจากสร้างตารางตาม schema.sql แล้ว
-- =========================================================


-- =========================================================
-- 1. Stored Procedure: sp_BookMovieSeats
-- ---------------------------------------------------------
-- หน้าที่:
--   - รับลูกค้า + รอบฉาย + ที่นั่งที่ต้องการจอง (ส่งเป็นสตริงคั่นด้วย comma)
--   - ตรวจสอบรอบฉาย / ลูกค้า / โปรโมชัน / ที่นั่ง
--   - คำนวณราคาต่อที่นั่ง (premium บวกเพิ่ม) และส่วนลด
--   - สร้าง booking (pending) -> tickets (reserved) -> payment (paid)
--     แล้วยืนยันเป็น confirmed / issued
--   - ถ้ามีปัญหา ROLLBACK ทั้งหมดแล้วส่ง error กลับด้วย THROW
--
-- การป้องกันที่นั่งซ้ำ (ที่ schema ไม่ได้กันไว้ที่ตาราง):
--   ล็อกแถวของรอบฉายด้วย UPDLOCK ตั้งแต่ต้น transaction
--   ทำให้การจองรอบเดียวกันที่เข้ามาพร้อมกันต้องต่อคิว
--   ไม่เกิดกรณี "ตรวจว่าว่าง" ทั้งคู่แล้วจองซ้ำทั้งคู่
--
-- ตัวอย่าง @seat_ids: '5'   '5,6'   '12,13,14,15'
-- =========================================================
CREATE OR ALTER PROCEDURE sp_BookMovieSeats
    @customer_id     INT,                       -- รหัสลูกค้า
    @showtime_id     INT,                       -- รหัสรอบฉาย
    @seat_ids        VARCHAR(500),              -- รหัสที่นั่ง คั่นด้วย comma
    @promotion_code  VARCHAR(50) = NULL,        -- รหัสโปรโมชัน (ไม่บังคับ)
    @payment_method  VARCHAR(20) = 'online'     -- cash / card / online
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;   -- error ใด ๆ ใน transaction ให้ rollback ทันที

    -- ----- ค่าคงที่ของระบบ -----
    DECLARE @hold_minutes      INT           = 15;   -- เวลาถือครองที่นั่งระหว่างรอชำระเงิน
    DECLARE @premium_surcharge DECIMAL(10,2) = 50;   -- ค่าที่นั่ง premium เพิ่มจากราคามาตรฐาน
    DECLARE @max_seats         INT           = 10;   -- จำนวนที่นั่งสูงสุดต่อการจอง 1 ครั้ง

    -- ----- ตัวแปรทำงาน -----
    DECLARE @now             DATETIME2(0) = SYSDATETIME();
    DECLARE @today           DATE         = CAST(@now AS DATE);
    DECLARE @hall_id         INT;
    DECLARE @standard_price  DECIMAL(10,2);
    DECLARE @start_time      DATETIME;
    DECLARE @showtime_status VARCHAR(20);
    DECLARE @promotion_id    INT = NULL;
    DECLARE @discount_type   VARCHAR(20);
    DECLARE @discount_value  DECIMAL(10,2);
    DECLARE @seat_count      INT;
    DECLARE @subtotal        DECIMAL(10,2);
    DECLARE @total_amount    DECIMAL(10,2);
    DECLARE @booking_id      INT;

    -- ที่นั่งที่ผู้ใช้เลือก (PRIMARY KEY กันรหัสที่นั่งซ้ำในคำสั่งเดียว)
    DECLARE @seats TABLE (
        seat_id      INT PRIMARY KEY,
        ticket_price DECIMAL(10,2) NULL
    );

    BEGIN TRY
        -- -------------------------------------------------
        -- ขั้นตอนที่ 1: ตรวจสอบพารามิเตอร์ (ยังไม่แตะฐานข้อมูล)
        -- -------------------------------------------------
        IF @seat_ids IS NULL OR LTRIM(RTRIM(@seat_ids)) = ''
            THROW 50006, N'กรุณาระบุที่นั่งอย่างน้อย 1 ที่', 1;

        IF EXISTS (
            SELECT 1 FROM STRING_SPLIT(@seat_ids, ',')
            WHERE LTRIM(RTRIM(value)) <> ''
              AND TRY_CAST(LTRIM(RTRIM(value)) AS INT) IS NULL
                 )
            THROW 50006, N'รูปแบบรหัสที่นั่งไม่ถูกต้อง (ต้องเป็นตัวเลขคั่นด้วย comma)', 1;

        INSERT INTO @seats (seat_id)
        SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(value)) AS INT)
        FROM STRING_SPLIT(@seat_ids, ',')
        WHERE LTRIM(RTRIM(value)) <> '';

        SELECT @seat_count = COUNT(*) FROM @seats;

        IF @seat_count = 0 OR @seat_count > @max_seats
            THROW 50006, N'จำนวนที่นั่งต้องอยู่ระหว่าง 1 ถึง 10 ที่ต่อการจอง', 1;

        IF @payment_method IS NULL OR @payment_method NOT IN ('cash', 'card', 'online')
            THROW 50007, N'ช่องทางชำระเงินต้องเป็น cash, card หรือ online', 1;

        -- -------------------------------------------------
        -- ขั้นตอนที่ 2: เริ่ม Transaction และล็อกรอบฉาย
        -- -------------------------------------------------
        BEGIN TRANSACTION;

        -- UPDLOCK: ใครจองรอบเดียวกันพร้อมกันต้องรอจน transaction นี้จบ
        SELECT @hall_id         = hall_id,
               @standard_price  = standard_price,
               @start_time      = start_time,
               @showtime_status = status
        FROM showtimes WITH (UPDLOCK, ROWLOCK)
        WHERE showtime_id = @showtime_id;

        IF @hall_id IS NULL OR @showtime_status <> 'scheduled'
            THROW 50001, N'รอบฉายนี้ไม่มีอยู่หรือไม่เปิดให้จอง', 1;

        IF @start_time <= @now
            THROW 50001, N'รอบฉายนี้เริ่มฉายไปแล้ว ไม่สามารถจองได้', 1;

        IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = @customer_id)
            THROW 50002, N'ไม่พบข้อมูลลูกค้า', 1;

        -- -------------------------------------------------
        -- ขั้นตอนที่ 3: ตรวจสอบโปรโมชัน (ถ้ามี)
        -- -------------------------------------------------
        IF @promotion_code IS NOT NULL
        BEGIN
            SELECT @promotion_id   = promotion_id,
                   @discount_type  = discount_type,
                   @discount_value = discount_value
            FROM promotions
            WHERE promotion_code = @promotion_code
              AND status = 'active'
              AND @today BETWEEN start_date AND end_date;

            IF @promotion_id IS NULL
                THROW 50003, N'รหัสโปรโมชันไม่ถูกต้องหรือหมดอายุ', 1;
        END;

        -- -------------------------------------------------
        -- ขั้นตอนที่ 4: ตรวจสอบที่นั่ง
        -- -------------------------------------------------

        -- 4.1 ที่นั่งทุกที่ต้องอยู่ในโรงของรอบฉายนี้
        IF EXISTS (
            SELECT 1
            FROM @seats x
            LEFT JOIN seats s ON s.seat_id = x.seat_id AND s.hall_id = @hall_id
            WHERE s.seat_id IS NULL
        )
            THROW 50004, N'มีที่นั่งที่ไม่ได้อยู่ในโรงของรอบฉายนี้', 1;

        -- 4.2 ที่นั่งต้องว่าง
        --     ถือว่าไม่ว่างเมื่อ booking เป็น confirmed
        --     หรือเป็น pending ที่ยังไม่หมดเวลาถือครอง
        --     (pending ที่หมดเวลาแล้วถือว่าว่าง แม้ trigger จะยังไม่ได้ปล่อย)
        IF EXISTS (
            SELECT 1
            FROM tickets t
            INNER JOIN bookings b ON b.booking_id = t.booking_id
            INNER JOIN @seats x   ON x.seat_id    = t.seat_id
            WHERE b.showtime_id = @showtime_id
              AND t.ticket_status IN ('reserved', 'issued')
              AND (   b.booking_status = 'confirmed'
                   OR (b.booking_status = 'pending' AND b.expires_at > @now))
        )
            THROW 50005, N'มีที่นั่งที่ถูกจองไปแล้ว', 1;

        -- -------------------------------------------------
        -- ขั้นตอนที่ 5: คำนวณราคาต่อที่นั่งและยอดรวม
        -- ราคาตั๋ว = ราคามาตรฐานของรอบฉาย (+ ค่า premium)
        -- ticket_price เก็บราคาก่อนส่วนลด ส่วนลดหักที่ยอดรวมของ booking
        -- -------------------------------------------------
        UPDATE x
        SET ticket_price = @standard_price
                         + CASE WHEN s.seat_type = 'premium' THEN @premium_surcharge ELSE 0 END
        FROM @seats x
        INNER JOIN seats s ON s.seat_id = x.seat_id;

        SELECT @subtotal = SUM(ticket_price) FROM @seats;
        SET @total_amount = @subtotal;

        IF @promotion_id IS NOT NULL
            SET @total_amount = CASE @discount_type
                                    WHEN 'percentage'
                                        THEN ROUND(@subtotal * (1 - @discount_value / 100.0), 2)
                                    ELSE @subtotal - @discount_value
                                END;

        IF @total_amount < 0
            SET @total_amount = 0;   -- ส่วนลดแบบ fixed ต้องไม่ทำให้ยอดติดลบ

        -- -------------------------------------------------
        -- ขั้นตอนที่ 6: สร้าง booking (pending) และตั๋ว (reserved)
        -- -------------------------------------------------
        INSERT INTO bookings (
            customer_id, showtime_id, promotion_id,
            booking_time, expires_at, booking_status, total_amount
        )
        VALUES (
            @customer_id, @showtime_id, @promotion_id,
            @now, DATEADD(MINUTE, @hold_minutes, @now), 'pending', @total_amount
        );

        SET @booking_id = SCOPE_IDENTITY();

        INSERT INTO tickets (booking_id, seat_id, ticket_price, ticket_status)
        SELECT @booking_id, seat_id, ticket_price, 'reserved'
        FROM @seats;

        -- -------------------------------------------------
        -- ขั้นตอนที่ 7: บันทึกการชำระเงินและยืนยันการจอง
        -- -------------------------------------------------
        INSERT INTO payments (booking_id, amount, payment_method, payment_status, paid_at)
        VALUES (@booking_id, @total_amount, @payment_method, 'paid', @now);

        UPDATE bookings SET booking_status = 'confirmed' WHERE booking_id = @booking_id;
        UPDATE tickets  SET ticket_status  = 'issued'    WHERE booking_id = @booking_id;

        COMMIT TRANSACTION;

        SELECT
            @booking_id   AS booking_id,
            @total_amount AS total_amount,
            @seat_count   AS number_of_seats,
            N'จองสำเร็จ'    AS message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;   -- ส่ง error เดิมกลับให้ผู้เรียก เพื่อให้รู้ว่าการจองล้มเหลว
    END CATCH
END;
GO


-- =========================================================
-- 2. Trigger: trg_ReleaseExpiredSeatLocks
-- ---------------------------------------------------------
-- หน้าที่:
--   - ทำงานเมื่อมีการ INSERT หรือ UPDATE ตาราง bookings
--   - booking ที่เป็น 'pending' และเลย expires_at -> 'expired'
--   - ตั๋วของ booking ที่เพิ่งหมดอายุ หรือถูกเปลี่ยนเป็น
--     expired / cancelled -> 'cancelled'
--   - payment ที่ค้าง pending ของ booking ที่หมดอายุ -> 'failed'
--
-- ใช้ OUTPUT เก็บเฉพาะ booking ที่เพิ่งหมดอายุ แล้วแก้ตั๋ว/การชำระเงิน
-- เฉพาะกลุ่มนั้น แทนการไล่แก้ทั้งตาราง tickets
-- =========================================================
CREATE OR ALTER TRIGGER trg_ReleaseExpiredSeatLocks
ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- กัน trigger เรียกตัวเองซ้ำ (จาก UPDATE bookings ด้านล่าง)
    IF TRIGGER_NESTLEVEL(@@PROCID) > 1
        RETURN;

    DECLARE @released TABLE (booking_id INT PRIMARY KEY);

    -- 1) booking ที่หมดเวลาถือครอง -> expired
    UPDATE bookings
    SET booking_status = 'expired'
    OUTPUT inserted.booking_id INTO @released (booking_id)
    WHERE booking_status = 'pending'
      AND expires_at < SYSDATETIME();

    -- 2) ตั๋วของ booking ที่เพิ่งหมดอายุ หรือที่แถวที่ถูกแก้ไขอยู่ตอนนี้เป็น expired/cancelled
    UPDATE t
    SET ticket_status = 'cancelled'
    FROM tickets t
    WHERE t.ticket_status <> 'cancelled'
      AND t.booking_id IN (
            SELECT booking_id FROM @released
            UNION
            SELECT booking_id FROM inserted
            WHERE booking_status IN ('expired', 'cancelled')
      );

    -- 3) การชำระเงินที่ยังค้างของ booking ที่หมดอายุ -> failed
    UPDATE p
    SET payment_status = 'failed'
    FROM payments p
    INNER JOIN @released r ON r.booking_id = p.booking_id
    WHERE p.payment_status = 'pending';
END;
GO


-- =========================================================
-- 3. Reporting View: vw_BoxOfficeOccupancyReport
-- ---------------------------------------------------------
-- หน้าที่:
--   - สรุปข้อมูลสำหรับผู้บริหารรายภาพยนตร์
--   - total_revenue     = ยอดที่ชำระสำเร็จจริง (payments.paid) หลังหักโปรโมชัน
--                         และไม่รวมรายการ refunded
--   - occupancy_rate_%  = ตั๋วที่ออกแล้ว / ที่นั่งทั้งหมดของรอบที่นับ x 100
--
-- นับเฉพาะรอบฉายสถานะ scheduled และ completed
-- (รอบ cancelled ไม่ถูกนับทั้งจำนวนรอบ ตั๋ว รายได้ และความจุ)
-- =========================================================
CREATE OR ALTER VIEW vw_BoxOfficeOccupancyReport
AS
WITH showtime_stats AS (
    SELECT
        s.showtime_id,
        s.movie_id,
        ch.capacity,
        ISNULL(tk.tickets_sold, 0) AS tickets_sold,
        ISNULL(pay.revenue, 0)     AS revenue
    FROM showtimes s
    INNER JOIN cinema_halls ch ON ch.hall_id = s.hall_id
    OUTER APPLY (
        SELECT COUNT(*) AS tickets_sold
        FROM bookings b
        INNER JOIN tickets t ON t.booking_id = b.booking_id
        WHERE b.showtime_id = s.showtime_id
          AND b.booking_status = 'confirmed'
          AND t.ticket_status = 'issued'
    ) tk
    OUTER APPLY (
        SELECT SUM(p.amount) AS revenue
        FROM bookings b
        INNER JOIN payments p ON p.booking_id = b.booking_id
        WHERE b.showtime_id = s.showtime_id
          AND b.booking_status = 'confirmed'
          AND p.payment_status = 'paid'
    ) pay
    WHERE s.status IN ('scheduled', 'completed')
)
SELECT
    m.movie_id,
    m.title AS movie_title,
    m.genre,
    COUNT(ss.showtime_id)             AS total_showtimes,
    ISNULL(SUM(ss.tickets_sold), 0)   AS tickets_sold,
    ISNULL(SUM(ss.revenue), 0)        AS total_revenue,
    ISNULL(SUM(ss.capacity), 0)       AS total_capacity,
    CAST(
        CASE WHEN SUM(ss.capacity) > 0
             THEN SUM(ss.tickets_sold) * 100.0 / SUM(ss.capacity)
             ELSE 0
        END AS DECIMAL(5,2)
    ) AS occupancy_rate_percent
FROM movies m
LEFT JOIN showtime_stats ss ON ss.movie_id = m.movie_id
GROUP BY m.movie_id, m.title, m.genre;
GO


-- =========================================================
-- ตัวอย่างการเรียกใช้ (สำหรับทดสอบ)
-- =========================================================
/*
-- หา showtime ที่ยังเปิดจอง และโรงของมัน
SELECT TOP 5 showtime_id, hall_id, start_time
FROM showtimes
WHERE status = 'scheduled' AND start_time > SYSDATETIME()
ORDER BY start_time;

-- ดูที่นั่งของโรงนั้น (แทน 1 ด้วย hall_id ที่ได้)
SELECT TOP 10 seat_id, row_label, seat_number, seat_type
FROM seats WHERE hall_id = 1 ORDER BY seat_id;

-- ตัวอย่างที่ 1: จอง 1 ที่ ไม่มีโปรโมชัน
EXEC sp_BookMovieSeats
    @customer_id = 1, @showtime_id = 1, @seat_ids = '1',
    @payment_method = 'online';

-- ตัวอย่างที่ 2: จอง 3 ที่ พร้อมโปรโมชัน
EXEC sp_BookMovieSeats
    @customer_id = 2, @showtime_id = 1, @seat_ids = '5,6,7',
    @promotion_code = 'PROMO001', @payment_method = 'card';

-- ตัวอย่างที่ 3: จองซ้ำที่นั่งเดิม ต้องได้ error 50005
EXEC sp_BookMovieSeats
    @customer_id = 3, @showtime_id = 1, @seat_ids = '1';

-- รายงานรายได้และอัตราการครองที่นั่ง
SELECT * FROM vw_BoxOfficeOccupancyReport
ORDER BY total_revenue DESC;
*/