-- =========================================================
-- logic.sql  (refactored + อธิบายตัวแปร/ฟังก์ชัน)
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
-- คำศัพท์ที่เจอบ่อยในไฟล์นี้ (อ่านก่อนจะเข้าใจโค้ดง่ายขึ้น)
-- ---------------------------------------------------------
--   @ชื่อ          = ตัวแปร (variable) หรือ parameter ของ procedure
--   @@ชื่อ         = ตัวแปรระบบของ SQL Server (ที่ SQL Server สร้างให้เอง)
--   DECLARE        = ประกาศตัวแปร (ระบุชื่อ ชนิดข้อมูล ค่าเริ่มต้น)
--   SET @x = ...   = กำหนดค่าให้ตัวแปร
--   SELECT @x = col FROM ... = ดึงค่าจากตารางมาเก็บในตัวแปร
--                    (ถ้าไม่เจอแถวเลย ตัวแปรจะยังเป็นค่าเดิม เช่น NULL)
--   NULL           = "ไม่มีค่า" ใช้ IS NULL / IS NOT NULL เช็ก ห้ามใช้ = NULL
--   alias          = ชื่อย่อของตารางหลัง FROM/JOIN เพื่อพิมพ์สั้นลง เช่น
--                    seats s, bookings b, tickets t, payments p,
--                    showtimes s, cinema_halls ch, movies m
--   N'ข้อความ'      = สตริงแบบ Unicode (ใส่ N นำหน้าเพื่อให้ภาษาไทยไม่เพี้ยน)
--
-- รหัส error ที่ procedure ใช้ (THROW ได้เลข 50000 ขึ้นไป เป็นเลขที่เรากำหนดเอง)
--   50001 รอบฉายไม่พร้อมจอง (ไม่มี / ไม่ใช่ scheduled / เริ่มฉายไปแล้ว)
--   50002 ไม่พบลูกค้า
--   50003 โปรโมชันไม่ถูกต้องหรือหมดอายุ
--   50004 มีที่นั่งที่ไม่ได้อยู่ในโรงของรอบฉายนี้
--   50005 มีที่นั่งที่ถูกจองไปแล้ว
--   50006 พารามิเตอร์ที่นั่งไม่ถูกต้อง (ว่าง / ไม่ใช่ตัวเลข / จำนวนเกิน)
--   50007 ช่องทางชำระเงินไม่ถูกต้อง
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
    -- ===== Parameter (ค่าที่ผู้เรียกต้องส่งเข้ามา) =====
    @customer_id     INT,                       -- รหัสลูกค้า ต้องตรงกับ customers.customer_id
    @showtime_id     INT,                       -- รหัสรอบฉาย ต้องตรงกับ showtimes.showtime_id (รหัสโรงดึงจากรอบนี้เอง จึงไม่ต้องส่ง hall_id)
    @seat_ids        VARCHAR(500),              -- รหัสที่นั่ง คั่นด้วย comma เช่น '5,6,7' (แยกเป็นรายที่นั่งในขั้นตอนที่ 1)
    @promotion_code  VARCHAR(50) = NULL,        -- รหัสโปรโมชัน (ไม่บังคับ) ถ้าไม่ส่งมา = NULL = ไม่ใช้ส่วนลด
    @payment_method  VARCHAR(20) = 'online'     -- รูปแบบการชำระเงิน cash / card / online (ถ้าไม่ส่งมาใช้ 'online')
AS
BEGIN
    -- SET NOCOUNT ON: ปิดข้อความ "(n rows affected)" ที่ SQL Server ส่งหลังทุกคำสั่ง
    --                 ลดข้อมูลที่ส่งกลับ และกันโปรแกรมที่เรียกสับสนกับผลลัพธ์จริง
    SET NOCOUNT ON;
    -- SET XACT_ABORT ON: ถ้ามี error ร้ายแรงระหว่าง transaction ให้ยกเลิก (rollback) ทั้งหมดอัตโนมัติ
    --                    ไม่ปล่อยให้ transaction ค้างครึ่งทาง
    SET XACT_ABORT ON;   -- error ใด ๆ ใน transaction ให้ rollback ทันที

    -- ----- ค่าคงที่ของระบบ (ตั้งไว้ที่เดียว แก้ที่นี่ที่เดียวถ้านโยบายเปลี่ยน) -----
    DECLARE @hold_minutes      INT           = 15;   -- เวลาถือครองที่นั่งระหว่างรอชำระเงินให้สูงสุด 15 นาที (ใช้คำนวณ expires_at)
    DECLARE @premium_surcharge DECIMAL(10,2) = 50;   -- ค่าที่นั่ง premium เพิ่มจากราคามาตรฐาน 50 บาท (ต่อที่นั่ง)
    DECLARE @max_seats         INT           = 10;   -- จำนวนที่นั่งสูงสุดต่อการจอง 1 ครั้ง

    -- ----- ตัวแปรทำงาน (เก็บค่าชั่วคราวระหว่างที่ procedure ทำงาน) -----
    -- SYSDATETIME(): ฟังก์ชันคืนวันเวลาปัจจุบันของเครื่อง SQL Server (ละเอียดระดับ nanosecond)
    -- DATETIME2(0): ชนิดข้อมูลวันเวลาแบบไม่เก็บเศษวินาที
    DECLARE @now             DATETIME2(0) = SYSDATETIME();      -- "เวลาตอนนี้" ดึงครั้งเดียวแล้วใช้ตลอด เพื่อให้ booking_time / expires_at / paid_at ตรงกันพอดี
    -- CAST(x AS DATE): แปลงชนิดข้อมูล ที่นี่คือตัดส่วนเวลาทิ้ง เหลือแค่วันที่
    DECLARE @today           DATE         = CAST(@now AS DATE); -- วันนี้ (ไม่มีเวลา) ใช้เทียบกับ start_date / end_date ของโปรโมชัน
    DECLARE @hall_id         INT;            -- รหัสโรงของรอบฉายนี้ (ดึงจาก showtimes) ใช้ตรวจว่าที่นั่งอยู่ในโรงเดียวกัน
    DECLARE @standard_price  DECIMAL(10,2);  -- ราคาตั๋วมาตรฐานของรอบฉาย (showtimes.standard_price) ก่อนบวก premium / ก่อนหักส่วนลด
    DECLARE @start_time      DATETIME;       -- เวลาเริ่มฉายของรอบ ใช้เช็กว่ารอบเริ่มไปแล้วหรือยัง
    DECLARE @showtime_status VARCHAR(20);    -- สถานะรอบฉาย (scheduled / cancelled / completed) จองได้เฉพาะ scheduled
    DECLARE @promotion_id    INT = NULL;     -- รหัสโปรโมชันที่ใช้ได้จริง ถ้ายังเป็น NULL หลังค้นหา = ไม่เจอโปรโมชัน / ไม่ได้ใช้
    DECLARE @discount_type   VARCHAR(20);    -- ประเภทส่วนลดของโปรโมชัน: percentage (เป็น %) หรือ fixed (หักเป็นบาท)
    DECLARE @discount_value  DECIMAL(10,2);  -- ค่าส่วนลด ความหมายขึ้นกับ @discount_type (เช่น 10 = 10% หรือ 10 บาท)
    DECLARE @seat_count      INT;            -- จำนวนที่นั่งที่จอง (หลังตัดเลขซ้ำ) ใช้ตรวจจำนวนสูงสุดและแสดงในผลลัพธ์
    DECLARE @subtotal        DECIMAL(10,2);  -- ยอดรวมราคาตั๋วทุกใบ "ก่อนหักส่วนลด"
    DECLARE @total_amount    DECIMAL(10,2);  -- ยอดสุทธิ "หลังหักส่วนลด" เป็นค่าที่บันทึกลง bookings และ payments
    DECLARE @booking_id      INT;            -- รหัสการจองที่เพิ่งสร้าง ใช้ผูก tickets และ payments เข้ากับการจองนี้

    -- ที่นั่งที่ผู้ใช้เลือก (PRIMARY KEY กันรหัสที่นั่งซ้ำในคำสั่งเดียว)
    -- @seats เป็น "ตัวแปรชนิดตาราง" (table variable) คือตารางชั่วคราวที่อยู่ในหน่วยความจำ
    -- และหายไปเองเมื่อ procedure จบ ใช้พักรายการที่นั่งเพื่อ JOIN กับตารางจริงได้
    DECLARE @seats TABLE (
        seat_id      INT PRIMARY KEY,           -- รหัสที่นั่งที่ผู้ใช้เลือก (PRIMARY KEY = ห้ามซ้ำ)
        ticket_price DECIMAL(10,2) NULL         -- ราคาตั๋วของที่นั่งนี้ (ยังว่างไว้ก่อน คำนวณทีหลังในขั้นตอนที่ 5)
    );

    -- BEGIN TRY ... END TRY: ลองทำคำสั่งข้างใน ถ้าเกิด error จะกระโดดไปทำ BEGIN CATCH ทันที
    BEGIN TRY
        -- -------------------------------------------------
        -- ขั้นตอนที่ 1: ตรวจสอบพารามิเตอร์ (ยังไม่แตะฐานข้อมูล)
        -- -------------------------------------------------
        -- LTRIM / RTRIM: ตัดช่องว่างซ้าย / ขวาของสตริง (ซ้อนกันเพื่อตัดทั้งสองข้าง)
        -- THROW เลข, ข้อความ, state: ยกเลิกการทำงานแล้วแจ้ง error (เลขต้อง >= 50000, state ใส่ 1 เสมอได้)
        IF @seat_ids IS NULL OR LTRIM(RTRIM(@seat_ids)) = ''
            THROW 50006, N'กรุณาระบุที่นั่งอย่างน้อย 1 ที่', 1;

        -- STRING_SPLIT(สตริง, ตัวคั่น): แยกสตริงตามตัวคั่น คืนเป็นตารางที่มีคอลัมน์เดียวชื่อ value
        --                              เช่น '5,6,7' -> แถว '5' '6' '7'
        -- TRY_CAST(x AS INT): แปลงเป็นตัวเลข ถ้าแปลงไม่ได้คืน NULL (ไม่ error เหมือน CAST)
        --                     ที่นี่ใช้ตรวจว่าทุกชิ้นที่แยกได้เป็นตัวเลขจริง
        IF EXISTS (
            SELECT 1 FROM STRING_SPLIT(@seat_ids, ',')
            WHERE LTRIM(RTRIM(value)) <> ''
              AND TRY_CAST(LTRIM(RTRIM(value)) AS INT) IS NULL
                 )
            THROW 50006, N'รูปแบบรหัสที่นั่งไม่ถูกต้อง (ต้องเป็นตัวเลขคั่นด้วย comma)', 1;

        -- แยกสตริงที่นั่งใส่ @seats ทีละแถว
        -- DISTINCT: ตัดเลขซ้ำออก เช่น '5,5,6' เหลือ 5 กับ 6
        INSERT INTO @seats (seat_id)
        SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(value)) AS INT)
        FROM STRING_SPLIT(@seat_ids, ',')
        WHERE LTRIM(RTRIM(value)) <> '';

        -- COUNT(*): นับจำนวนแถว เก็บใน @seat_count
        SELECT @seat_count = COUNT(*) FROM @seats;

        IF @seat_count = 0 OR @seat_count > @max_seats
            THROW 50006, N'จำนวนที่นั่งต้องอยู่ระหว่าง 1 ถึง 10 ที่ต่อการจอง', 1;

        IF @payment_method IS NULL OR @payment_method NOT IN ('cash', 'card', 'online')
            THROW 50007, N'ช่องทางชำระเงินต้องเป็น cash, card หรือ online', 1;

        -- -------------------------------------------------
        -- ขั้นตอนที่ 2: เริ่ม Transaction และล็อกรอบฉาย
        -- -------------------------------------------------
        -- BEGIN TRANSACTION: เริ่มกลุ่มคำสั่งที่ต้อง "สำเร็จทั้งหมดหรือยกเลิกทั้งหมด" (ACID)
        --                    ถ้าไปไม่ถึง COMMIT การเปลี่ยนแปลงทั้งหมดจะถูกย้อนกลับ
        BEGIN TRANSACTION;

        -- UPDLOCK: ใครจองรอบเดียวกันพร้อมกันต้องรอจน transaction นี้จบ
        -- WITH (UPDLOCK, ROWLOCK): ล็อกแถวของรอบฉายนี้แถวเดียว (ROWLOCK) ในโหมดที่
        --   คนอื่น "อ่านได้แต่ขอล็อกเพื่อแก้ไขไม่ได้" (UPDLOCK) จึงเกิดการต่อคิวจองรอบเดียวกัน
        -- ดึงข้อมูลรอบฉายลงตัวแปรทั้ง 4 ตัวในคำสั่งเดียว
        SELECT @hall_id         = hall_id,
               @standard_price  = standard_price,
               @start_time      = start_time,
               @showtime_status = status
        FROM showtimes WITH (UPDLOCK, ROWLOCK)
        WHERE showtime_id = @showtime_id;

        -- ถ้าไม่เจอรอบฉาย @hall_id จะเป็น NULL จึงใช้เช็กว่ารอบมีอยู่จริงไหม
        IF @hall_id IS NULL OR @showtime_status <> 'scheduled'
            THROW 50001, N'รอบฉายนี้ไม่มีอยู่หรือไม่เปิดให้จอง', 1;

        IF @start_time <= @now
            THROW 50001, N'รอบฉายนี้เริ่มฉายไปแล้ว ไม่สามารถจองได้', 1;

        -- EXISTS (SELECT 1 ...): คืน true ถ้า subquery เจออย่างน้อย 1 แถว (SELECT 1 แค่ให้มีแถว ไม่สนค่า)
        IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = @customer_id)
            THROW 50002, N'ไม่พบข้อมูลลูกค้า', 1;

        -- -------------------------------------------------
        -- ขั้นตอนที่ 3: ตรวจสอบโปรโมชัน (ถ้ามี)
        -- -------------------------------------------------
        IF @promotion_code IS NOT NULL
        BEGIN
            -- ค้นโปรโมชันที่รหัสตรง สถานะ active และ "วันนี้" อยู่ในช่วง start_date ถึง end_date
            -- (BETWEEN a AND b รวมทั้งวันที่ a และ b)
            SELECT @promotion_id   = promotion_id,
                   @discount_type  = discount_type,
                   @discount_value = discount_value
            FROM promotions
            WHERE promotion_code = @promotion_code
              AND status = 'active'
              AND @today BETWEEN start_date AND end_date;

            -- ถ้าไม่เจอ @promotion_id จะยังเป็น NULL แปลว่ารหัสผิด / ปิดใช้งาน / หมดอายุ
            IF @promotion_id IS NULL
                THROW 50003, N'รหัสโปรโมชันไม่ถูกต้องหรือหมดอายุ', 1;
        END;

        -- -------------------------------------------------
        -- ขั้นตอนที่ 4: ตรวจสอบที่นั่ง
        -- -------------------------------------------------

        -- 4.1 ที่นั่งทุกที่ต้องอยู่ในโรงของรอบฉายนี้
        -- LEFT JOIN: เอาทุกแถวจาก @seats (ที่ผู้ใช้เลือก) แล้วจับคู่กับ seats จริงของโรงนี้
        -- ถ้าที่นั่งไหนจับคู่ไม่ได้ s.seat_id จะเป็น NULL แปลว่ารหัสนั้นไม่มีอยู่ หรืออยู่คนละโรง
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
        -- INNER JOIN: เอาเฉพาะแถวที่จับคู่ได้ทั้งสองฝั่ง
        -- ที่นี่หาตั๋วในรอบนี้ ที่ที่นั่งตรงกับที่ผู้ใช้เลือก และการจองยังมีผลอยู่
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
        -- UPDATE x ... FROM @seats x JOIN seats s: อัปเดตราคาในตาราง @seats โดยดูประเภทที่นั่งจากตาราง seats
        -- CASE WHEN เงื่อนไข THEN ค่า1 ELSE ค่า2 END: เลือกค่าตามเงื่อนไข (เหมือน if/else)
        --   ที่นี่ premium บวกค่า premium ส่วนที่นั่ง standard บวก 0
        UPDATE x
        SET ticket_price = @standard_price
                         + CASE WHEN s.seat_type = 'premium' THEN @premium_surcharge ELSE 0 END
        FROM @seats x
        INNER JOIN seats s ON s.seat_id = x.seat_id;

        -- SUM(): รวมค่าของคอลัมน์ทุกแถว ได้ยอดรวมตั๋วก่อนลด แล้วตั้งเป็นยอดสุทธิเริ่มต้น
        SELECT @subtotal = SUM(ticket_price) FROM @seats;
        SET @total_amount = @subtotal;

        -- ถ้ามีโปรโมชัน คำนวณส่วนลดตามประเภท:
        --   percentage: ยอด x (1 - ส่วนลด/100)  เช่น ลด 10% = ยอด x 0.9
        --               (หารด้วย 100.0 ไม่ใช่ 100 เพื่อไม่ให้ปัดเป็นเลขจำนวนเต็ม)
        --   fixed     : ยอด - ส่วนลด (เป็นบาท)
        -- ROUND(x, 2): ปัดทศนิยม 2 ตำแหน่ง (เพราะเป็นเงิน)
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
        -- DATEADD(หน่วย, จำนวน, วันเวลา): บวกเวลา ที่นี่คือ @now + 15 นาที เป็นเวลาหมดอายุการถือครอง
        INSERT INTO bookings (
            customer_id, showtime_id, promotion_id,
            booking_time, expires_at, booking_status, total_amount
        )
        VALUES (
            @customer_id, @showtime_id, @promotion_id,
            @now, DATEADD(MINUTE, @hold_minutes, @now), 'pending', @total_amount
        );

        -- SCOPE_IDENTITY(): คืนค่า IDENTITY (เลขรันอัตโนมัติ) ตัวล่าสุดที่เพิ่งสร้างใน scope นี้
        --                   ที่นี่ก็คือ booking_id ของแถวที่เพิ่ง INSERT ด้านบน
        --                   (ปลอดภัยกว่า @@IDENTITY เพราะไม่ปนกับ trigger หรือ session อื่น)
        SET @booking_id = SCOPE_IDENTITY();

        -- INSERT ... SELECT: เพิ่มตั๋วทุกที่นั่งใน @seats ทีเดียว ทุกใบใช้ booking_id เดียวกัน
        INSERT INTO tickets (booking_id, seat_id, ticket_price, ticket_status)
        SELECT @booking_id, seat_id, ticket_price, 'reserved'
        FROM @seats;

        -- -------------------------------------------------
        -- ขั้นตอนที่ 7: บันทึกการชำระเงินและยืนยันการจอง
        -- -------------------------------------------------
        INSERT INTO payments (booking_id, amount, payment_method, payment_status, paid_at)
        VALUES (@booking_id, @total_amount, @payment_method, 'paid', @now);

        -- เปลี่ยนสถานะเป็น confirmed (การจอง) และ issued (ตั๋ว) หลังชำระเงินสำเร็จ
        UPDATE bookings SET booking_status = 'confirmed' WHERE booking_id = @booking_id;
        UPDATE tickets  SET ticket_status  = 'issued'    WHERE booking_id = @booking_id;

        -- COMMIT TRANSACTION: ยืนยันการเปลี่ยนแปลงทั้งหมดให้เป็นถาวร
        COMMIT TRANSACTION;

        -- ส่งผลลัพธ์กลับให้ผู้เรียก (AS คือตั้งชื่อคอลัมน์ผลลัพธ์)
        SELECT
            @booking_id   AS booking_id,
            @total_amount AS total_amount,
            @seat_count   AS number_of_seats,
            N'จองสำเร็จ'    AS message;
    END TRY
    -- BEGIN CATCH: ทำงานเมื่อมี error เกิดขึ้นในบล็อก TRY (รวมถึง THROW ที่เราโยนเอง)
    BEGIN CATCH
        -- XACT_STATE(): สถานะ transaction ปัจจุบัน
        --   0 = ไม่มี transaction ค้าง, 1 = มีและ commit ได้, -1 = มีแต่ต้อง rollback เท่านั้น
        -- ถ้าไม่เป็น 0 แปลว่ามี transaction ค้าง จึงต้อง ROLLBACK (ย้อนกลับการเปลี่ยนแปลงทั้งหมด)
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        -- THROW; (ไม่ใส่อะไรต่อท้าย): ส่ง error เดิมต่อไปให้ผู้เรียกเห็น ทั้งเลขและข้อความ
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
--
-- Trigger คือโค้ดที่ SQL Server เรียกให้อัตโนมัติเมื่อตารางเปลี่ยน (ไม่ต้องมีใครสั่ง EXEC)
-- AFTER INSERT, UPDATE = ทำงาน "หลังจาก" การเพิ่มหรือแก้ข้อมูลใน bookings เสร็จแล้ว
-- =========================================================
CREATE OR ALTER TRIGGER trg_ReleaseExpiredSeatLocks
ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;   -- ปิดข้อความ "(n rows affected)" เหมือนใน procedure

    -- กัน trigger เรียกตัวเองซ้ำ (จาก UPDATE bookings ด้านล่าง)
    -- @@PROCID: ตัวแปรระบบ เก็บรหัสภายใน (object id) ของ trigger ที่กำลังทำงานอยู่
    -- TRIGGER_NESTLEVEL(@@PROCID): บอกว่า trigger นี้ถูกเรียกซ้อนกันกี่ชั้น (1 = ครั้งแรก)
    --   ถ้า > 1 แปลว่าถูกเรียกซ้ำเพราะ UPDATE ในตัวเอง ให้ออกทันที (RETURN)
    --   เป็นตัวกันเหนียว เพราะปกติ SQL Server ปิดการเรียก trigger ซ้อนตัวเองไว้อยู่แล้ว
    IF TRIGGER_NESTLEVEL(@@PROCID) > 1
        RETURN;

    -- ตัวแปรชนิดตาราง เก็บรหัส booking ที่ "เพิ่งถูกเปลี่ยนเป็น expired ในรอบนี้" ไว้ใช้ในขั้นต่อไป
    DECLARE @released TABLE (booking_id INT PRIMARY KEY);

    -- 1) booking ที่หมดเวลาถือครอง -> expired
    -- OUTPUT inserted.booking_id INTO @released: ระหว่าง UPDATE ให้เก็บ booking_id ของ
    --   "ทุกแถวที่ถูกแก้" ลง @released (inserted ในที่นี้คือค่าใหม่หลังแก้)
    UPDATE bookings
    SET booking_status = 'expired'
    OUTPUT inserted.booking_id INTO @released (booking_id)
    WHERE booking_status = 'pending'
      AND expires_at < SYSDATETIME();

    -- 2) ตั๋วของ booking ที่เพิ่งหมดอายุ หรือที่แถวที่ถูกแก้ไขอยู่ตอนนี้เป็น expired/cancelled
    -- inserted (ตารางพิเศษใน trigger): ตารางชั่วคราวที่ SQL Server สร้างให้ เก็บแถวใน bookings
    --   ที่เพิ่งถูก INSERT หรือ UPDATE ที่ทำให้ trigger นี้ทำงาน (ค่าหลังแก้)
    -- UNION: รวมรหัสจากสองแหล่ง (ที่เพิ่งหมดอายุ + ที่ถูกสั่งเป็น expired/cancelled) และตัดซ้ำ
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
--
-- View คือ "ตารางเสมือน" ที่เก็บแค่คำสั่ง SELECT ไม่เก็บข้อมูลเอง
-- ทุกครั้งที่ SELECT * FROM vw_... ระบบจะคำนวณจากข้อมูลล่าสุดใหม่เสมอ
-- =========================================================
CREATE OR ALTER VIEW vw_BoxOfficeOccupancyReport
AS
-- WITH ชื่อ AS (...): CTE (Common Table Expression) คือตารางชั่วคราวที่ตั้งชื่อไว้ใช้ในคำสั่งเดียว
--   showtime_stats สรุป "ต่อ 1 รอบฉาย" ว่ามีความจุเท่าไร ขายตั๋วได้กี่ใบ ได้เงินเท่าไร
--   แล้วค่อยรวมต่อหนังในคำสั่ง SELECT ด้านล่าง (แยกขั้นเพื่อกันตัวเลขนับซ้ำเวลา JOIN หลายตาราง)
WITH showtime_stats AS (
    SELECT
        s.showtime_id,                            -- รหัสรอบฉาย
        s.movie_id,                               -- หนังที่ฉายในรอบนี้ (ไว้รวมต่อหนัง)
        ch.capacity,                              -- ความจุที่นั่งของโรงที่ฉายรอบนี้
        -- ISNULL(x, 0): ถ้า x เป็น NULL ให้ใช้ 0 แทน (รอบที่ยังไม่มีใครซื้อจะได้ 0 แทนที่จะเป็น NULL)
        ISNULL(tk.tickets_sold, 0) AS tickets_sold,   -- จำนวนตั๋วที่ขายได้ในรอบนี้
        ISNULL(pay.revenue, 0)     AS revenue         -- รายได้ที่ชำระสำเร็จในรอบนี้
    FROM showtimes s
    INNER JOIN cinema_halls ch ON ch.hall_id = s.hall_id
    -- OUTER APPLY: รัน subquery "ต่อแถวของ showtimes แต่ละรอบ" (อ้าง s.showtime_id ได้)
    --   ถ้า subquery ไม่ได้ผล ก็ยังคงแถวของรอบนั้นไว้ (ค่าเป็น NULL) ต่างจาก CROSS APPLY ที่ตัดแถวทิ้ง
    -- tk: นับตั๋วที่ออกแล้ว (issued) ของการจองที่ confirmed ในรอบนี้
    OUTER APPLY (
        SELECT COUNT(*) AS tickets_sold
        FROM bookings b
        INNER JOIN tickets t ON t.booking_id = b.booking_id
        WHERE b.showtime_id = s.showtime_id
          AND b.booking_status = 'confirmed'
          AND t.ticket_status = 'issued'
    ) tk
    -- pay: รวมเงินที่ชำระสำเร็จ (paid) ของการจองที่ confirmed ในรอบนี้
    --   แยกจากตั๋วคนละ subquery เพื่อไม่ให้ยอดเงินถูกคูณซ้ำตามจำนวนตั๋ว
    OUTER APPLY (
        SELECT SUM(p.amount) AS revenue
        FROM bookings b
        INNER JOIN payments p ON p.booking_id = b.booking_id
        WHERE b.showtime_id = s.showtime_id
          AND b.booking_status = 'confirmed'
          AND p.payment_status = 'paid'
    ) pay
    WHERE s.status IN ('scheduled', 'completed')   -- ไม่นับรอบที่ถูกยกเลิก (cancelled)
)
SELECT
    m.movie_id,
    m.title AS movie_title,
    m.genre,
    -- COUNT(ss.showtime_id): นับจำนวนรอบฉาย (นับเฉพาะแถวที่มีค่า จึงได้ 0 สำหรับหนังที่ไม่มีรอบ)
    COUNT(ss.showtime_id)             AS total_showtimes,
    -- SUM(...): รวมต่อหนัง / ISNULL กันกรณีหนังไม่มีรอบเลย (SUM ของว่างเป็น NULL)
    ISNULL(SUM(ss.tickets_sold), 0)   AS tickets_sold,       -- ตั๋วที่ขายได้ทั้งหมดของหนังเรื่องนี้
    ISNULL(SUM(ss.revenue), 0)        AS total_revenue,      -- รายได้รวมของหนังเรื่องนี้
    ISNULL(SUM(ss.capacity), 0)       AS total_capacity,     -- ที่นั่งทั้งหมดของทุกรอบที่นับ (ตัวหารของ occupancy)
    -- อัตราการครองที่นั่ง % = ตั๋วที่ขายได้ / ที่นั่งทั้งหมด x 100
    --   CASE WHEN SUM(capacity) > 0: กันการหารด้วยศูนย์ (หนังที่ไม่มีรอบจะได้ 0)
    --   * 100.0 (มีจุดทศนิยม): บังคับให้คำนวณแบบทศนิยม ไม่งั้นการหารเลขจำนวนเต็มจะปัดทิ้งเป็น 0
    --   CAST(... AS DECIMAL(5,2)): ปัดเป็นทศนิยม 2 ตำแหน่ง เช่น 37.50
    CAST(
        CASE WHEN SUM(ss.capacity) > 0
             THEN SUM(ss.tickets_sold) * 100.0 / SUM(ss.capacity)
             ELSE 0
        END AS DECIMAL(5,2)
    ) AS occupancy_rate_percent
FROM movies m
-- LEFT JOIN: เอาหนังทุกเรื่องจาก movies แม้ยังไม่มีรอบฉายเลย (ฝั่ง ss จะเป็น NULL)
LEFT JOIN showtime_stats ss ON ss.movie_id = m.movie_id
-- GROUP BY: รวมแถวของรอบฉายให้เหลือ 1 แถวต่อหนัง (คอลัมน์ที่ไม่ได้ใช้ SUM/COUNT ต้องอยู่ใน GROUP BY)
GROUP BY m.movie_id, m.title, m.genre;
GO


-- =========================================================
-- ตัวอย่างการเรียกใช้ (สำหรับทดสอบ)
-- อยู่ใน /* ... */ จึงไม่ถูกรันตอนรันทั้งไฟล์ ให้คัดลอกไปรันทีละส่วน
-- =========================================================
/*
-- หา showtime ที่ยังเปิดจอง และโรงของมัน
-- (TOP 5 = เอาแค่ 5 แถวแรก, ORDER BY start_time = เรียงจากรอบที่ใกล้ที่สุด)
SELECT TOP 5 showtime_id, hall_id, start_time
FROM showtimes
WHERE status = 'scheduled' AND start_time > SYSDATETIME()
ORDER BY start_time;

-- ดูที่นั่งของโรงนั้น (แทน 1 ด้วย hall_id ที่ได้)
SELECT TOP 10 seat_id, row_label, seat_number, seat_type
FROM seats WHERE hall_id = 1 ORDER BY seat_id;

-- ตัวอย่างที่ 1: จอง 1 ที่ ไม่มีโปรโมชัน
-- (แก้ @showtime_id และ @seat_ids ให้เป็นรอบที่ยังไม่ฉาย และที่นั่งของโรงนั้นจริง)
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