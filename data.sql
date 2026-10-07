-- =========================================================
-- data.sql
-- ข้อมูลจำลอง (Mock Data) สำหรับระบบจองตั๋วภาพยนตร์และผังที่นั่ง
-- หัวข้อที่ 7 - รายวิชาระบบฐานข้อมูล 2569
-- DBMS: Microsoft SQL Server
-- วิธีใช้: รันไฟล์นี้หลังจากรัน schema.sql บนฐานข้อมูลเปล่า
-- =========================================================

SET NOCOUNT ON;   -- ไม่แสดงจำนวนแถวที่ได้รับผลกระทบ เพื่อให้ผลลัพธ์อ่านง่าย

-- =========================================================
-- 1. ตาราง movies : สร้างข้อมูลภาพยนตร์ 500 เรื่อง
-- =========================================================
DECLARE @i INT = 1;

WHILE @i <= 500
BEGIN
    INSERT INTO movies (title, description, duration, genre, release_date, status)
    VALUES (
        'Movie ' + CAST(@i AS VARCHAR(10)),
        'Description for movie number ' + CAST(@i AS VARCHAR(10)),
        90 + (@i % 91),                                 -- ความยาวภาพยนตร์ 90-180 นาที
        CASE (@i % 6)
            WHEN 0 THEN 'Action'
            WHEN 1 THEN 'Drama'
            WHEN 2 THEN 'Comedy'
            WHEN 3 THEN 'Sci-Fi'
            WHEN 4 THEN 'Horror'
            ELSE 'Animation'
        END,
        DATEADD(DAY, -(@i % 730), CAST(GETDATE() AS DATE)),  -- วันเข้าฉายย้อนหลังประมาณ 2 ปี
        CASE WHEN @i % 12 = 0 THEN 'inactive' ELSE 'active' END
    );
    SET @i = @i + 1;
END;

-- =========================================================
-- 2. ตาราง cinema_halls : สร้างโรงภาพยนตร์ 20 โรง
--    ความจุแตกต่างกัน (เล็ก / มาตรฐาน / ใหญ่)
-- =========================================================
SET @i = 1;
WHILE @i <= 20
BEGIN
    INSERT INTO cinema_halls (hall_name, capacity, status)
    VALUES (
        'Hall ' + CAST(@i AS VARCHAR(10)),
        CASE
            WHEN @i <= 5  THEN 80          -- โรงเล็ก
            WHEN @i <= 15 THEN 120         -- โรงมาตรฐาน
            ELSE 180                       -- โรงใหญ่
        END,
        'active'
    );
    SET @i = @i + 1;
END;

-- =========================================================
-- 3. ตาราง seats : สร้างที่นั่งตามความจุจริงของแต่ละโรง
-- =========================================================
DECLARE @hall_id INT = 1;
DECLARE @cap INT;                  -- ความจุของโรงปัจจุบัน
DECLARE @seat_no INT;
DECLARE @seats_per_row INT = 20;   -- จำนวนที่นั่งต่อแถว

WHILE @hall_id <= 20
BEGIN
    -- ดึงความจุของโรงนี้มาใช้
    SELECT @cap = capacity FROM cinema_halls WHERE hall_id = @hall_id;
    SET @seat_no = 1;

    WHILE @seat_no <= @cap
    BEGIN
        INSERT INTO seats (hall_id, row_label, seat_number, seat_type)
        VALUES (
            @hall_id,
            CHAR(65 + ((@seat_no - 1) / @seats_per_row)),   -- ชื่อแถว A, B, C, ...
            ((@seat_no - 1) % @seats_per_row) + 1,           -- หมายเลขที่นั่งในแถว
            CASE
                WHEN @seat_no > (@cap * 0.8) THEN 'premium'  -- 20% ท้ายสุดเป็นที่นั่งพรีเมียม
                ELSE 'standard'
            END
        );
        SET @seat_no = @seat_no + 1;
    END;

    SET @hall_id = @hall_id + 1;
END;

-- =========================================================
-- 4. ตาราง customers : สร้างลูกค้า 500 คน
-- =========================================================
SET @i = 1;
WHILE @i <= 500
BEGIN
    INSERT INTO customers (name, email, phone)
    VALUES (
        'Customer ' + CAST(@i AS VARCHAR(10)),
        'customer' + CAST(@i AS VARCHAR(10)) + '@example.com',
        '08' + RIGHT('00000000' + CAST(@i AS VARCHAR(10)), 8)
    );
    SET @i = @i + 1;
END;

-- =========================================================
-- 5. ตาราง promotions : สร้างโปรโมชัน 30 รายการ
-- =========================================================
SET @i = 1;
WHILE @i <= 30
BEGIN
    INSERT INTO promotions (
        promotion_code, discount_type, discount_value,
        start_date, end_date, status
    )
    VALUES (
        'PROMO' + RIGHT('000' + CAST(@i AS VARCHAR(10)), 3),
        CASE WHEN @i % 2 = 0 THEN 'percentage' ELSE 'fixed' END,
        CASE WHEN @i % 2 = 0 THEN 5 + (@i % 16) ELSE 20 + (@i % 10) * 10 END,
        DATEADD(DAY, -60, CAST(GETDATE() AS DATE)),   -- เริ่มต้นย้อนหลัง 60 วัน
        DATEADD(DAY, 180, CAST(GETDATE() AS DATE)),   -- สิ้นสุดอีก 180 วันข้างหน้า
        CASE WHEN @i % 10 = 0 THEN 'inactive' ELSE 'active' END
    );
    SET @i = @i + 1;
END;

-- =========================================================
-- 6. ตาราง showtimes : สร้างรอบฉาย 500 รอบ
-- =========================================================
SET @i = 1;
WHILE @i <= 500
BEGIN
    DECLARE @start DATETIME2 = DATEADD(
        HOUR,
        (@i % 12) + 10,                                    -- เวลาเริ่มประมาณ 10:00 - 21:00
        DATEADD(DAY, (@i % 45), CAST(CAST(GETDATE() AS DATE) AS DATETIME2))
    );

    INSERT INTO showtimes (
        movie_id, hall_id, start_time, end_time, ticket_price, status
    )
    VALUES (
        ((@i - 1) % 500) + 1,                              -- อ้างอิงหนัง 1-500
        ((@i - 1) % 20) + 1,                               -- อ้างอิงโรง 1-20
        @start,
        DATEADD(MINUTE, 100 + (@i % 50), @start),          -- ความยาวรอบฉายประมาณ 100-150 นาที
        CAST(120 + ((@i - 1) % 5) * 30 AS DECIMAL(10,2)),  -- ราคา 120 / 150 / 180 / 210 / 240 บาท
        CASE
            WHEN @i % 25 = 0 THEN 'cancelled'
            WHEN @i % 18 = 0 THEN 'completed'
            ELSE 'scheduled'
        END
    );
    SET @i = @i + 1;
END;

-- =========================================================
-- 7. ตาราง bookings + tickets + payments
--    สร้างการจอง 600 รายการ
--    - บางรายการจอง 1 ที่นั่ง บางรายการจอง 2-3 ที่นั่ง
--    - ที่นั่งที่เลือกจะอยู่ในโรงเดียวกับรอบฉายเสมอ
--    - expires_at จะอยู่หลัง booking_time เสมอ (ไม่ผิด CHECK)
-- =========================================================

DECLARE @booking_id INT;
DECLARE @cust_id INT;
DECLARE @st_id INT;
DECLARE @hall_of_show INT;
DECLARE @base_price DECIMAL(10,2);
DECLARE @promo INT;
DECLARE @b_status VARCHAR(20);
DECLARE @b_time DATETIME2;
DECLARE @exp_time DATETIME2;
DECLARE @num_tickets INT;
DECLARE @t INT;
DECLARE @seat_offset INT;
DECLARE @chosen_seat INT;
DECLARE @total DECIMAL(10,2);
DECLARE @pay_status VARCHAR(20);
DECLARE @pay_method VARCHAR(20);

SET @i = 1;

WHILE @i <= 600
BEGIN
    SET @cust_id     = ((@i - 1) % 500) + 1;
    SET @st_id       = ((@i - 1) % 500) + 1;
    SET @promo       = CASE WHEN @i % 4 = 0 THEN NULL ELSE ((@i - 1) % 30) + 1 END;
    SET @b_time      = DATEADD(MINUTE, -(@i % 2000), SYSDATETIME());
    SET @exp_time    = DATEADD(MINUTE, 15, @b_time);          -- ถือครองที่นั่ง 15 นาที

    -- กำหนดสถานะการจอง
    SET @b_status = CASE
        WHEN @i % 20 = 0 THEN 'expired'
        WHEN @i % 15 = 0 THEN 'cancelled'
        WHEN @i % 10 = 0 THEN 'pending'
        ELSE 'confirmed'
    END;

    -- ดึงข้อมูลโรงและราคาตั๋วของรอบฉายนี้
    SELECT @hall_of_show = hall_id,
           @base_price   = ticket_price
    FROM showtimes
    WHERE showtime_id = @st_id;

    -- จำนวนตั๋วใน booking นี้ (1 ถึง 3 ใบ)
    SET @num_tickets = (@i % 3) + 1;
    SET @total = @base_price * @num_tickets;

    -- ถ้ามีโปรโมชันและสถานะเป็น confirmed ให้ลด 10% (เพื่อการทดสอบ)
    IF @promo IS NOT NULL AND @b_status = 'confirmed'
    BEGIN
        SET @total = @total * 0.90;
    END;

    -- บันทึกการจอง
    INSERT INTO bookings (
        customer_id, showtime_id, promotion_id,
        booking_time, expires_at, booking_status, total_amount
    )
    VALUES (
        @cust_id, @st_id, @promo,
        @b_time, @exp_time, @b_status, @total
    );

    SET @booking_id = SCOPE_IDENTITY();   -- ดึง booking_id ที่เพิ่งสร้าง

    -- สร้างตั๋ว (เลือกที่นั่งจากโรงเดียวกับรอบฉาย)
    SET @t = 1;
    SET @seat_offset = ((@i - 1) * 3) % 50;

    WHILE @t <= @num_tickets
    BEGIN
        -- เลือกที่นั่งที่อยู่ในโรงเดียวกับรอบฉาย
        SELECT @chosen_seat = seat_id
        FROM seats
        WHERE hall_id = @hall_of_show
        ORDER BY seat_id
        OFFSET (@seat_offset + @t - 1) ROWS
        FETCH NEXT 1 ROWS ONLY;

        -- กรณีหาไม่เจอ ให้เลือกที่นั่งแรกของโรงนั้นแทน
        IF @chosen_seat IS NULL
        BEGIN
            SELECT TOP 1 @chosen_seat = seat_id
            FROM seats
            WHERE hall_id = @hall_of_show
            ORDER BY seat_id;
        END;

        INSERT INTO tickets (booking_id, seat_id, ticket_price, ticket_status)
        VALUES (
            @booking_id,
            @chosen_seat,
            @base_price,
            CASE
                WHEN @b_status = 'confirmed' THEN 'issued'
                WHEN @b_status = 'pending'   THEN 'reserved'
                ELSE 'cancelled'
            END
        );

        SET @t = @t + 1;
    END;

    -- บันทึกการชำระเงิน (หนึ่งรายการต่อหนึ่ง booking)
    SET @pay_status = CASE
        WHEN @b_status = 'confirmed' THEN 'paid'
        WHEN @b_status = 'pending'   THEN 'pending'
        WHEN @b_status = 'cancelled' THEN 'refunded'
        ELSE 'failed'
    END;

    SET @pay_method = CASE (@i % 3)
        WHEN 0 THEN 'cash'
        WHEN 1 THEN 'card'
        ELSE 'online'
    END;

    INSERT INTO payments (
        booking_id, amount, payment_method, payment_status, paid_at
    )
    VALUES (
        @booking_id,
        @total,
        @pay_method,
        @pay_status,
        CASE WHEN @pay_status = 'paid' THEN DATEADD(MINUTE, 5, @b_time) ELSE NULL END
    );

    SET @i = @i + 1;
END;

-- =========================================================
-- ตรวจสอบผลลัพธ์หลังใส่ข้อมูล
-- =========================================================
PRINT '========== จำนวนข้อมูลในแต่ละตาราง ==========';
SELECT 'movies'        AS table_name, COUNT(*) AS record_count FROM movies
UNION ALL SELECT 'cinema_halls', COUNT(*) FROM cinema_halls
UNION ALL SELECT 'seats',        COUNT(*) FROM seats
UNION ALL SELECT 'customers',    COUNT(*) FROM customers
UNION ALL SELECT 'promotions',   COUNT(*) FROM promotions
UNION ALL SELECT 'showtimes',    COUNT(*) FROM showtimes
UNION ALL SELECT 'bookings',     COUNT(*) FROM bookings
UNION ALL SELECT 'tickets',      COUNT(*) FROM tickets
UNION ALL SELECT 'payments',     COUNT(*) FROM payments
ORDER BY table_name;

PRINT '========== ตรวจสอบจำนวนที่นั่งจริงของแต่ละโรง ==========';
SELECT h.hall_id, h.hall_name, h.capacity, COUNT(s.seat_id) AS actual_seats
FROM cinema_halls h
LEFT JOIN seats s ON s.hall_id = h.hall_id
GROUP BY h.hall_id, h.hall_name, h.capacity
ORDER BY h.hall_id;

PRINT '========== ตรวจสอบจำนวนตั๋วต่อหนึ่งการจอง (ควรเป็น 1-3 ใบ) ==========';
SELECT ticket_count, COUNT(*) AS num_bookings
FROM (
    SELECT booking_id, COUNT(*) AS ticket_count
    FROM tickets
    GROUP BY booking_id
) t
GROUP BY ticket_count
ORDER BY ticket_count;

