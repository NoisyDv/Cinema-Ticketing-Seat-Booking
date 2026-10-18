
USE CinemaDB;
GO

-- =========================================================
-- 1. Stored Procedure: sp_BookMovieSeats
-- ---------------------------------------------------------
-- มี 3 รูปแบบการเรียก:
--
--   A) จองและจ่ายทันที   (@pay_now = 1, ค่าเริ่มต้น)
--        booking pending -> tickets reserved -> payment paid
--        -> booking confirmed -> tickets issued   (ใน transaction เดียว)
--
--   B) ล็อกที่นั่งก่อน   (@pay_now = 0)
--        สร้าง booking pending + tickets reserved แล้ว COMMIT
--        ที่นั่งถูกถือไว้ @hold_minutes นาที รอชำระเงิน
--        ถ้าไม่จ่ายทัน trg_ReleaseExpiredSeatLocks จะปล่อยที่นั่ง
--
--   C) ชำระเงินภายหลัง   (@confirm_booking_id = รหัส booking ที่ค้าง pending)
--        ตรวจว่ายัง pending และยังไม่หมดเวลา แล้วสร้าง payment
--        -> booking confirmed -> tickets issued
--
-- การป้องกันที่นั่งซ้ำ:
--   ล็อกแถวของรอบฉายด้วย UPDLOCK ตั้งแต่ต้น transaction (ทั้งรูปแบบ A, B, C)
--   ทำให้ทุกการเขียนของรอบเดียวกันต่อคิว ไม่เกิดกรณี
--   "ตรวจว่าว่าง" ทั้งคู่แล้วจองซ้ำทั้งคู่
--   (กันได้เฉพาะการจองที่ผ่าน procedure นี้)
--
-- ตัวอย่าง @seat_ids: '5'   '5,6'   '12,13,14,15'
--
-- รหัส error (THROW ได้เลข 50000 ขึ้นไป เป็นเลขที่เรากำหนดเอง)
--   50001 รอบฉายไม่พร้อมจอง (ไม่มี / ไม่ใช่ scheduled / เริ่มฉายแล้ว
--         / โรงหรือหนังเป็น inactive)
--   50002 ไม่พบลูกค้า
--   50003 โปรโมชันไม่ถูกต้องหรือหมดอายุ
--   50004 มีที่นั่งที่ไม่ได้อยู่ในโรงของรอบฉายนี้
--   50005 มีที่นั่งที่ถูกจองไปแล้ว
--   50006 พารามิเตอร์ที่นั่งไม่ถูกต้อง (ว่าง / ไม่ใช่ตัวเลข / จำนวนเกิน)
--   50007 ช่องทางชำระเงินไม่ถูกต้อง
--   50008 ไม่พบ booking หรือ booking ไม่ได้อยู่ในสถานะ pending
--   50009 booking หมดเวลาถือครองที่นั่งแล้ว
--   50010 ไม่พบการจอง หรือไม่ใช่เจ้าของการจอง (sp_CancelBooking)
--   50011 การจองยกเลิกไม่ได้: ถูกยกเลิก/หมดเวลาไปแล้ว หรือรอบฉายเริ่มไปแล้ว (sp_CancelBooking)
-- =========================================================

CREATE OR ALTER PROCEDURE sp_BookMovieSeats
    @customer_id        INT          = NULL,       -- รหัสลูกค้า (รูปแบบ A, B)
    @showtime_id        INT          = NULL,       -- รหัสรอบฉาย (รูปแบบ A, B)
    @seat_ids           VARCHAR(500) = NULL,       -- รหัสที่นั่ง คั่นด้วย comma (รูปแบบ A, B)
    @promotion_code     VARCHAR(50)  = NULL,       -- รหัสโปรโมชัน (ไม่บังคับ)
    @payment_method     VARCHAR(20)  = 'online',   -- cash / card / online
    @pay_now            BIT          = 1,          -- 1 = จ่ายทันที, 0 = แค่ล็อกที่นั่ง
    @confirm_booking_id INT          = NULL        -- ใส่เพื่อชำระเงิน booking ที่ค้าง pending (รูปแบบ C)
AS
BEGIN
    SET NOCOUNT ON;     -- ไม่ส่งจำนวนแถวที่ได้รับผลกลับไปยัง client
    SET XACT_ABORT ON;  -- error ใด ๆ ใน transaction ให้ rollback ทันที

    -- ----- ค่าคงที่ของระบบ -----
    DECLARE @hold_minutes      INT           = 15;   -- เวลาถือครองที่นั่งระหว่างรอชำระเงิน
    DECLARE @premium_surcharge DECIMAL(10,2) = 50;   -- ค่าที่นั่ง premium เพิ่มจากราคามาตรฐาน
    DECLARE @max_seats         INT           = 10;   -- จำนวนที่นั่งสูงสุดต่อการจอง 1 ครั้ง

    -- ----- ตัวแปรทำงาน -----
    DECLARE @now             DATETIME2(0);           -- กำหนดค่าหลังล็อกรอบฉายแล้ว
    DECLARE @today           DATE;
    DECLARE @msg             NVARCHAR(200);
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
    DECLARE @expires_at      DATETIME;
    DECLARE @booking_status  VARCHAR(20);

    -- ที่นั่งที่ผู้ใช้เลือก (PRIMARY KEY กันรหัสที่นั่งซ้ำในคำสั่งเดียว)
    DECLARE @seats TABLE (
        seat_id      INT PRIMARY KEY,
        ticket_price DECIMAL(10,2) NULL
    );

    BEGIN TRY

        -- =================================================
        -- รูปแบบ C: ชำระเงิน booking ที่ล็อกที่นั่งไว้แล้ว
        -- =================================================
        IF @confirm_booking_id IS NOT NULL
        BEGIN
            IF @payment_method IS NULL OR @payment_method NOT IN ('cash', 'card', 'online')
                THROW 50007, N'ช่องทางชำระเงินต้องเป็น cash, card หรือ online', 1;

            -- อ่านรหัสรอบฉายของ booking นี้ (ค่านี้ไม่เปลี่ยนหลังสร้าง booking)
            SELECT @showtime_id = showtime_id
            FROM bookings
            WHERE booking_id = @confirm_booking_id;

            IF @showtime_id IS NULL
                THROW 50008, N'ไม่พบการจองนี้ หรือไม่ได้อยู่ในสถานะรอชำระเงิน', 1;

            BEGIN TRANSACTION;

            -- ล็อกรอบฉายก่อน แล้วค่อยล็อก booking (ลำดับเดียวกับรูปแบบ A, B กัน deadlock)
            SELECT @hall_id = hall_id
            FROM showtimes WITH (UPDLOCK, ROWLOCK)
            WHERE showtime_id = @showtime_id;

            SELECT @booking_status = booking_status,
                   @expires_at     = expires_at,
                   @total_amount   = total_amount
            FROM bookings WITH (UPDLOCK, ROWLOCK)
            WHERE booking_id = @confirm_booking_id;

            SET @now = SYSDATETIME();

            IF @booking_status IS NULL OR @booking_status <> 'pending'
                THROW 50008, N'ไม่พบการจองนี้ หรือไม่ได้อยู่ในสถานะรอชำระเงิน', 1;

            IF @expires_at <= @now
                THROW 50009, N'การจองนี้หมดเวลาถือครองที่นั่งแล้ว กรุณาจองใหม่', 1;

            INSERT INTO payments (booking_id, amount, payment_method, payment_status, paid_at)
            VALUES (@confirm_booking_id, @total_amount, @payment_method, 'paid', @now);

            UPDATE bookings SET booking_status = 'confirmed' WHERE booking_id = @confirm_booking_id;
            UPDATE tickets  SET ticket_status  = 'issued'
            WHERE booking_id = @confirm_booking_id AND ticket_status = 'reserved';

            COMMIT TRANSACTION;

            SELECT
                @confirm_booking_id AS booking_id,
                @total_amount       AS total_amount,
                N'ชำระเงินสำเร็จ'      AS message;
            RETURN;
        END;

        -- =================================================
        -- รูปแบบ A, B: สร้างการจองใหม่
        -- =================================================

        -- ขั้นตอนที่ 1: ตรวจสอบพารามิเตอร์ (ยังไม่แตะฐานข้อมูล)
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
        BEGIN
            SET @msg = CONCAT(N'จำนวนที่นั่งต้องอยู่ระหว่าง 1 ถึง ', @max_seats, N' ที่ต่อการจอง');
            THROW 50006, @msg, 1;
        END;

        -- ตรวจช่องทางชำระเงินเฉพาะตอนจะจ่ายจริง
        IF @pay_now = 1
           AND (@payment_method IS NULL OR @payment_method NOT IN ('cash', 'card', 'online'))
            THROW 50007, N'ช่องทางชำระเงินต้องเป็น cash, card หรือ online', 1;

        -- ขั้นตอนที่ 2: เริ่ม Transaction และล็อกรอบฉาย
        BEGIN TRANSACTION;

        -- UPDLOCK: ใครจองรอบเดียวกันพร้อมกันต้องรอจน transaction นี้จบ
        -- JOIN เพื่อให้ได้เฉพาะรอบที่โรงและหนังเป็น active (BR15)
        SELECT @hall_id         = s.hall_id,
               @standard_price  = s.standard_price,
               @start_time      = s.start_time,
               @showtime_status = s.status
        FROM showtimes AS s WITH (UPDLOCK, ROWLOCK)
        INNER JOIN cinema_halls h ON h.hall_id  = s.hall_id  AND h.status = 'active'
        INNER JOIN movies       m ON m.movie_id = s.movie_id AND m.status = 'active'
        WHERE s.showtime_id = @showtime_id;

        -- อ่านเวลาหลังได้ล็อกแล้ว เพื่อไม่ให้ใช้เวลาเก่าตอนที่รอคิวอยู่
        SET @now   = SYSDATETIME();
        SET @today = CAST(@now AS DATE);

        IF @hall_id IS NULL OR @showtime_status <> 'scheduled'
            THROW 50001, N'รอบฉายนี้ไม่มีอยู่ ไม่เปิดให้จอง หรือโรง/ภาพยนตร์ปิดใช้งาน', 1;

        IF @start_time <= @now
            THROW 50001, N'รอบฉายนี้เริ่มฉายไปแล้ว ไม่สามารถจองได้', 1;

        IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = @customer_id)
            THROW 50002, N'ไม่พบข้อมูลลูกค้า', 1;

        -- ขั้นตอนที่ 3: ตรวจสอบโปรโมชัน (ถ้ามี)
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

        -- ขั้นตอนที่ 4: ตรวจสอบที่นั่ง
        -- 4.1 ที่นั่งทุกที่ต้องอยู่ในโรงของรอบฉายนี้
        IF EXISTS (
            SELECT 1
            FROM @seats x
            LEFT JOIN seats s ON s.seat_id = x.seat_id AND s.hall_id = @hall_id
            WHERE s.seat_id IS NULL
        )
            THROW 50004, N'มีที่นั่งที่ไม่ได้อยู่ในโรงของรอบฉายนี้', 1;

        -- 4.2 ที่นั่งต้องว่าง
        --     ไม่ว่างเมื่อ booking เป็น confirmed
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

        -- ขั้นตอนที่ 5: คำนวณราคา
        -- ticket_price เก็บราคาก่อนส่วนลด ส่วนลดหักที่ยอดรวมของ booking
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

        -- ขั้นตอนที่ 6: สร้าง booking (pending) และตั๋ว (reserved)
        SET @expires_at = DATEADD(MINUTE, @hold_minutes, @now);

        INSERT INTO bookings (
            customer_id, showtime_id, promotion_id,
            booking_time, expires_at, booking_status, total_amount
        )
        VALUES (
            @customer_id, @showtime_id, @promotion_id,
            @now, @expires_at, 'pending', @total_amount
        );

        SET @booking_id = SCOPE_IDENTITY();

        INSERT INTO tickets (booking_id, seat_id, ticket_price, ticket_status)
        SELECT @booking_id, seat_id, ticket_price, 'reserved'
        FROM @seats;

        -- ขั้นตอนที่ 7: ถ้าจ่ายทันที ให้บันทึกชำระเงินและยืนยัน
        --               ถ้าไม่ ให้ค้างเป็น pending/reserved ตาม Hold Timeout
        IF @pay_now = 1
        BEGIN
            INSERT INTO payments (booking_id, amount, payment_method, payment_status, paid_at)
            VALUES (@booking_id, @total_amount, @payment_method, 'paid', @now);

            UPDATE bookings SET booking_status = 'confirmed' WHERE booking_id = @booking_id;
            UPDATE tickets  SET ticket_status  = 'issued'    WHERE booking_id = @booking_id;
        END;

        COMMIT TRANSACTION;

        SELECT
            @booking_id   AS booking_id,
            @total_amount AS total_amount,
            @seat_count   AS number_of_seats,
            CASE WHEN @pay_now = 1 THEN NULL ELSE @expires_at END AS pay_before,
            CASE WHEN @pay_now = 1
                 THEN N'จองสำเร็จ'
                 ELSE N'ล็อกที่นั่งสำเร็จ กรุณาชำระเงินก่อนเวลาที่กำหนด'
            END AS message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;   -- ส่ง error เดิมกลับให้ผู้เรียก เพื่อให้รู้ว่าการจองล้มเหลว
    END CATCH
END;
GO


-- =========================================================
-- 2. Stored Procedure: sp_CancelBooking
-- ---------------------------------------------------------
-- หน้าที่:
--   - ยกเลิกการจองของลูกค้า (เฉพาะเจ้าของ) ทั้งแบบ pending และ confirmed
--   - คืนสถานะใน transaction เดียว:
--       bookings -> cancelled, tickets -> cancelled,
--       payments ที่ paid -> refunded (ที่ค้าง pending -> failed)
--   - ที่นั่งว่างทันทีหลัง COMMIT (trigger ข้อ 3 ช่วยไล่ปิดตั๋วซ้ำให้อีกชั้น)
--
-- เงื่อนไข (ไม่ผ่านจะ ROLLBACK แล้ว THROW):
--   - booking ต้องมีอยู่และเป็นของ @customer_id (ไม่งั้น 50010)
--     (ใช้ error เดียวกันทั้งสองกรณี เพื่อไม่ให้เดารหัสการจองของคนอื่นได้)
--   - booking ต้องยัง pending/confirmed (ไม่งั้น 50011)
--   - รอบฉายต้องยังไม่เริ่ม (ไม่งั้น 50011 กันยอดรายได้ในรายงานย้อนหลังเพี้ยน)
--
-- การป้องกันยกเลิกซ้ำพร้อมกัน:
--   ล็อกแถว booking ด้วย UPDLOCK ตั้งแต่ต้น transaction
--   ใครมาทีหลังจะเห็นสถานะ cancelled แล้วได้ 50011
--
-- ตัวอย่าง: EXEC sp_CancelBooking @booking_id = 12, @customer_id = 3;
--
-- รหัส error ที่ procedure นี้ใช้ (ดูรายการรวมที่หัวข้อที่ 1):
--   50010 ไม่พบการจอง หรือไม่ใช่เจ้าของการจอง
--   50011 การจองยกเลิกไม่ได้ (ยกเลิก/หมดเวลาไปแล้ว หรือรอบฉายเริ่มไปแล้ว)
-- =========================================================
CREATE OR ALTER PROCEDURE sp_CancelBooking
    @booking_id   INT,   -- รหัสการจองที่จะยกเลิก
    @customer_id  INT    -- รหัสเจ้าของการจอง (กันคนอื่นมายกเลิกแทน)
AS
BEGIN
    SET NOCOUNT ON;     -- ไม่ส่งจำนวนแถวที่ได้รับผลกลับไปยัง client
    SET XACT_ABORT ON;  -- error ใด ๆ ใน transaction ให้ rollback ทันที

    -- ----- ตัวแปรทำงาน -----
    DECLARE @status      VARCHAR(20);
    DECLARE @owner_id    INT;
    DECLARE @start_time  DATETIME;
    DECLARE @refund      DECIMAL(10,2);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ขั้นตอนที่ 1: ล็อกและตรวจ booking
        -- UPDLOCK: กันกดยกเลิก booking เดียวกันพร้อมกัน
        SELECT @status   = booking_status,
               @owner_id = customer_id
        FROM bookings WITH (UPDLOCK, ROWLOCK)
        WHERE booking_id = @booking_id;

        IF @customer_id IS NULL OR @status IS NULL OR @owner_id <> @customer_id
            THROW 50010, N'ไม่พบการจองนี้ หรือไม่ใช่เจ้าของการจอง', 1;

        IF @status NOT IN ('pending', 'confirmed')
            THROW 50011, N'การจองนี้ถูกยกเลิกหรือหมดเวลาไปแล้ว', 1;

        -- ขั้นตอนที่ 2: ตรวจว่ารอบฉายยังไม่เริ่ม
        SELECT @start_time = s.start_time
        FROM bookings b
        INNER JOIN showtimes s ON s.showtime_id = b.showtime_id
        WHERE b.booking_id = @booking_id;

        IF @start_time <= SYSDATETIME()
            THROW 50011, N'รอบฉายนี้เริ่มไปแล้ว ไม่สามารถยกเลิกได้', 1;

        -- ขั้นตอนที่ 3: คืนสถานะทุกตารางใน transaction เดียว
        -- 3.1 ยกเลิก booking (trigger จะช่วยไล่ปิดตั๋วซ้ำให้อีกชั้น)
        UPDATE bookings SET booking_status = 'cancelled' WHERE booking_id = @booking_id;

        -- 3.2 ยกเลิกตั๋วทุกใบของการจองนี้
        UPDATE tickets SET ticket_status = 'cancelled'
        WHERE booking_id = @booking_id AND ticket_status <> 'cancelled';

        -- 3.3 คืนเงิน: ที่จ่ายแล้ว -> refunded, ที่ค้าง pending -> failed
        --     (booking แบบล็อกที่นั่งไว้แต่ยังไม่จ่าย จะไม่มีแถว payments เลย)
        UPDATE payments SET payment_status = 'refunded'
        WHERE booking_id = @booking_id AND payment_status = 'paid';

        UPDATE payments SET payment_status = 'failed'
        WHERE booking_id = @booking_id AND payment_status = 'pending';

        SELECT @refund = ISNULL(SUM(amount), 0)
        FROM payments
        WHERE booking_id = @booking_id AND payment_status = 'refunded';

        COMMIT TRANSACTION;

        SELECT
            @booking_id AS booking_id,
            @refund     AS refund_amount,
            N'ยกเลิกการจองสำเร็จ' AS message;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;   -- ส่ง error เดิมกลับให้ผู้เรียก เพื่อให้รู้ว่าการยกเลิกล้มเหลว
    END CATCH
END;
GO


-- =========================================================
-- 3. Trigger: trg_ReleaseExpiredSeatLocks
-- ---------------------------------------------------------
-- หน้าที่:
--   - ทำงานเมื่อมีการ INSERT หรือ UPDATE ตาราง bookings
--   - booking ที่เป็น 'pending' และถึงหรือเลย expires_at -> 'expired'
--   - ตั๋วของ booking ที่เพิ่งหมดอายุ หรือถูกเปลี่ยนเป็น
--     expired / cancelled -> 'cancelled' (ที่นั่งว่างอีกครั้ง)
--   - payment ที่ค้าง pending ของ booking ที่หมดอายุ -> 'failed'
--
-- ข้อจำกัดที่ควรอธิบายในรายงาน:
--   trigger ของ SQL Server ไม่ทำงานตามเวลาเอง จะทำงานเมื่อมีการเขียน bookings
--   แต่ความถูกต้องไม่ขึ้นกับ trigger เพราะ procedure ถือว่า pending ที่หมดเวลา
--   เป็นที่นั่งว่างอยู่แล้ว และ view นับเฉพาะ booking ที่ confirmed
--   (ถ้าต้องการให้กวาดตามเวลาจริง ใช้ SQL Server Agent job ร่วมด้วย)
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
    --    ใช้ <= ให้ตรงกับ procedure (expires_at > now ถึงจะยังถือครองอยู่)
    UPDATE bookings
    SET booking_status = 'expired'
    OUTPUT inserted.booking_id INTO @released (booking_id)
    WHERE booking_status = 'pending'
      AND expires_at <= SYSDATETIME();

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
-- 4. Reporting View: vw_BoxOfficeOccupancyReport
-- ---------------------------------------------------------
-- หน้าที่:
--   - สรุปข้อมูลสำหรับผู้บริหารรายภาพยนตร์
--   - total_revenue     = ยอดที่ชำระสำเร็จจริง (payments.paid) หลังหักโปรโมชัน
--                         เฉพาะ booking ที่ confirmed (ไม่รวม refunded)
--   - total_capacity    = จำนวนที่นั่งจริงในตาราง seats ของโรงที่ใช้ฉาย
--                         (ไม่พึ่ง cinema_halls.capacity ที่อาจไม่ตรงกับผังที่นั่ง)
--   - occupancy_rate_%  = ตั๋วที่ออกแล้ว / ที่นั่งทั้งหมดของรอบที่นับ x 100
--
-- นับเฉพาะรอบฉายสถานะ scheduled และ completed
-- (รอบ cancelled ไม่ถูกนับทั้งจำนวนรอบ ตั๋ว รายได้ และความจุ)
-- หมายเหตุ: รอบ scheduled ที่ยังไม่ถึงเวลาฉายก็ถูกนับ ทำให้อัตราครองที่นั่ง
--           รวมการขายล่วงหน้า (เป็นการตัดสินใจเชิงธุรกิจที่ระบุไว้ในรายงาน)
-- =========================================================
CREATE OR ALTER VIEW vw_BoxOfficeOccupancyReport
AS
WITH showtime_stats AS (
    SELECT
        s.showtime_id,
        s.movie_id,
        hs.seat_total              AS capacity,
        ISNULL(tk.tickets_sold, 0) AS tickets_sold,
        ISNULL(pay.revenue, 0)     AS revenue
    FROM showtimes s
    OUTER APPLY (
        SELECT COUNT(*) AS seat_total
        FROM seats se
        WHERE se.hall_id = s.hall_id
    ) hs
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

-- A) จองและจ่ายทันที
EXEC sp_BookMovieSeats
    @customer_id = 1, @showtime_id = 1, @seat_ids = '1',
    @payment_method = 'online';

-- A) จอง 3 ที่ พร้อมโปรโมชัน
EXEC sp_BookMovieSeats
    @customer_id = 2, @showtime_id = 1, @seat_ids = '5,6,7',
    @promotion_code = 'PROMO001', @payment_method = 'card';

-- ที่นั่งซ้ำ ต้องได้ error 50005
EXEC sp_BookMovieSeats
    @customer_id = 3, @showtime_id = 1, @seat_ids = '1';

-- B) ล็อกที่นั่งก่อน (ยังไม่จ่าย) จะได้ booking_id และเวลา pay_before
EXEC sp_BookMovieSeats
    @customer_id = 3, @showtime_id = 1, @seat_ids = '20,21', @pay_now = 0;

-- ลองจองที่นั่งที่ถูกล็อกอยู่ ต้องได้ error 50005
EXEC sp_BookMovieSeats
    @customer_id = 1, @showtime_id = 1, @seat_ids = '20';

-- C) ชำระเงินของ booking ที่ล็อกไว้ (แทน 10 ด้วย booking_id ที่ได้จากข้อ B)
EXEC sp_BookMovieSeats @confirm_booking_id = 10, @payment_method = 'card';

-- ทดสอบ trigger: ล็อกที่นั่งแล้วจำลองว่าหมดเวลา
--   (ต้องเลื่อน booking_time ด้วย เพราะ CHECK ต้องมี expires_at > booking_time)
EXEC sp_BookMovieSeats
    @customer_id = 2, @showtime_id = 1, @seat_ids = '30', @pay_now = 0;

UPDATE bookings
SET booking_time = DATEADD(MINUTE, -20, booking_time),
    expires_at   = DATEADD(MINUTE, -5,  SYSDATETIME())
WHERE booking_id = 11;     -- แทนด้วย booking_id ที่ได้ ตัว trigger จะทำงานทันที

SELECT booking_id, booking_status FROM bookings WHERE booking_id = 11;     -- expired
SELECT ticket_id, ticket_status   FROM tickets  WHERE booking_id = 11;     -- cancelled

-- ที่นั่ง 30 ว่างอีกครั้ง จองซ้ำได้
EXEC sp_BookMovieSeats
    @customer_id = 1, @showtime_id = 1, @seat_ids = '30';

-- ชำระ booking ที่หมดเวลาแล้ว ต้องได้ error 50008 (เพราะเป็น expired แล้ว)
EXEC sp_BookMovieSeats @confirm_booking_id = 11, @payment_method = 'cash';

-- D) ยกเลิกการจอง (แทน 12/3 ด้วย booking_id/customer_id จริง)
--    จองแบบจ่ายทันทีก่อน 1 booking แล้วค่อยยกเลิก
EXEC sp_BookMovieSeats
    @customer_id = 3, @showtime_id = 1, @seat_ids = '40,41';

EXEC sp_CancelBooking @booking_id = 12, @customer_id = 3;

-- ตรวจว่า booking/tickets/payments เปลี่ยนสถานะครบ
SELECT booking_status FROM bookings WHERE booking_id = 12;       -- cancelled
SELECT DISTINCT ticket_status FROM tickets WHERE booking_id = 12; -- cancelled
SELECT payment_status FROM payments WHERE booking_id = 12;       -- refunded

-- ที่นั่งว่างอีกครั้ง จองซ้ำได้
EXEC sp_BookMovieSeats
    @customer_id = 1, @showtime_id = 1, @seat_ids = '40';

-- ยกเลิกซ้ำ ต้องได้ error 50011
EXEC sp_CancelBooking @booking_id = 12, @customer_id = 3;

-- ยกเลิกของคนอื่น ต้องได้ error 50010
EXEC sp_CancelBooking @booking_id = 12, @customer_id = 1;

-- รายงานรายได้และอัตราการครองที่นั่ง
SELECT * FROM vw_BoxOfficeOccupancyReport
ORDER BY total_revenue DESC;
*/