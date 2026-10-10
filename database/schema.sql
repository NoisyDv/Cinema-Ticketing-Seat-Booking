-- =========================================================
-- schema.sql  (รันซ้ำได้ - idempotent)
-- ระบบจองตั๋วภาพยนตร์และผังที่นั่ง (Cinema Ticketing & Seat Booking)
-- หัวข้อที่ 7 - รายวิชาระบบฐานข้อมูล 2569
-- DBMS: Microsoft SQL Server (T-SQL)  ต้องการ SQL Server 2016 SP1 ขึ้นไป
-- จำนวนตาราง: 9 ตาราง (อยู่ในเกณฑ์ 8-10 ตาราง)
-- มาตรฐานการตั้งชื่อ: snake_case, ตารางเป็นรูปพหูพจน์
--
-- ลำดับการรันทั้งชุด:  schema.sql -> data.sql -> logic.sql -> queries.sql
-- (tests.sql และ sanity_checks.sql รันหลังสุดเมื่อต้องการตรวจสอบ)
--
-- ไฟล์นี้รวมคอลัมน์ที่เคยอยู่ใน migration.sql แล้ว:
--   movies.poster_url, customers.password_hash / user_role / last_login_at
-- ส่วน "UPGRADE" ท้ายไฟล์ใช้กับฐานข้อมูลเก่าที่สร้างจากสคีมาเดิม
-- =========================================================
SET NOCOUNT ON;
GO

-- =========================================================
-- ตาราง: movies  เก็บข้อมูลภาพยนตร์
-- (title/description ใช้ NVARCHAR เพื่อเก็บภาษาไทยได้ถูกต้องทุก collation)
-- =========================================================
IF OBJECT_ID(N'movies', N'U') IS NULL
BEGIN
    CREATE TABLE movies (
        movie_id      INT IDENTITY(1,1) PRIMARY KEY,
        title         NVARCHAR(200)  NOT NULL,
        description   NVARCHAR(MAX)  NULL,
        duration      INT            NOT NULL,          -- หน่วยเป็นนาที
        genre         VARCHAR(50)    NOT NULL,
        release_date  DATE           NOT NULL,
        status        VARCHAR(20)    NOT NULL,
        poster_url    VARCHAR(500)   NULL,              -- ว่างได้ เว็บใช้บล็อกสีแทนเมื่อไม่มีรูป

        CONSTRAINT chk_movies_duration CHECK (duration > 0),
        CONSTRAINT chk_movies_status   CHECK (status IN ('active', 'inactive'))
    );
END;
GO

-- =========================================================
-- ตาราง: cinema_halls  เก็บข้อมูลโรงภาพยนตร์
-- =========================================================
IF OBJECT_ID(N'cinema_halls', N'U') IS NULL
BEGIN
    CREATE TABLE cinema_halls (
        hall_id    INT IDENTITY(1,1) PRIMARY KEY,
        hall_name  VARCHAR(100)  NOT NULL,
        capacity   INT           NOT NULL,
        status     VARCHAR(20)   NOT NULL,

        CONSTRAINT uq_cinema_halls_name      UNIQUE (hall_name),
        CONSTRAINT chk_cinema_halls_capacity CHECK (capacity > 0),
        CONSTRAINT chk_cinema_halls_status   CHECK (status IN ('active', 'inactive'))
    );
END;
GO

-- =========================================================
-- ตาราง: seats  เก็บที่นั่งของแต่ละโรง
-- =========================================================
IF OBJECT_ID(N'seats', N'U') IS NULL
BEGIN
    CREATE TABLE seats (
        seat_id      INT IDENTITY(1,1) PRIMARY KEY,
        hall_id      INT           NOT NULL,
        row_label    VARCHAR(10)   NOT NULL,
        seat_number  INT           NOT NULL,
        seat_type    VARCHAR(20)   NOT NULL,

        CONSTRAINT fk_seats_hall FOREIGN KEY (hall_id)
            REFERENCES cinema_halls(hall_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT uq_seats_position UNIQUE (hall_id, row_label, seat_number),
        CONSTRAINT chk_seats_number  CHECK (seat_number > 0),
        CONSTRAINT chk_seats_type    CHECK (seat_type IN ('standard', 'premium'))
    );
END;
GO

-- =========================================================
-- ตาราง: showtimes  เก็บรอบฉาย
-- หมายเหตุ: การห้ามรอบฉายทับซ้อนในโรงเดียวกัน ควบคุมโดย trg_PreventShowtimeOverlap (logic.sql)
-- =========================================================
IF OBJECT_ID(N'showtimes', N'U') IS NULL
BEGIN
    CREATE TABLE showtimes (
        showtime_id   INT IDENTITY(1,1) PRIMARY KEY,
        movie_id      INT            NOT NULL,
        hall_id       INT            NOT NULL,
        start_time    DATETIME2      NOT NULL,
        end_time      DATETIME2      NOT NULL,
        ticket_price  DECIMAL(10,2)  NOT NULL,
        status        VARCHAR(20)    NOT NULL,

        CONSTRAINT fk_showtimes_movie FOREIGN KEY (movie_id)
            REFERENCES movies(movie_id) ON DELETE NO ACTION ON UPDATE CASCADE,
        CONSTRAINT fk_showtimes_hall FOREIGN KEY (hall_id)
            REFERENCES cinema_halls(hall_id) ON DELETE NO ACTION ON UPDATE CASCADE,
        CONSTRAINT chk_showtimes_time   CHECK (end_time > start_time),
        CONSTRAINT chk_showtimes_price  CHECK (ticket_price >= 0),
        CONSTRAINT chk_showtimes_status CHECK (status IN ('scheduled', 'cancelled', 'completed'))
    );
END;
GO

-- =========================================================
-- ตาราง: customers  เก็บข้อมูลลูกค้า/ผู้ใช้ระบบ (รวมบัญชี admin)
-- password_hash เก็บค่าแฮช PBKDF2 + salt ที่สร้างจากฝั่ง C# เท่านั้น (ห้ามเก็บรหัสผ่านจริง)
-- password_hash เป็น NULL = ยังไม่มีรหัสผ่าน (ล็อกอินไม่ได้)
-- =========================================================
IF OBJECT_ID(N'customers', N'U') IS NULL
BEGIN
    CREATE TABLE customers (
        customer_id    INT IDENTITY(1,1) PRIMARY KEY,
        name           NVARCHAR(150) NOT NULL,
        email          VARCHAR(255)  NOT NULL,
        phone          VARCHAR(20)   NOT NULL,
        created_at     DATETIME2     NOT NULL
            CONSTRAINT df_customers_created_at DEFAULT SYSDATETIME(),
        password_hash  VARCHAR(255)  NULL,
        user_role      VARCHAR(20)   NOT NULL
            CONSTRAINT df_customers_user_role DEFAULT 'customer',
        last_login_at  DATETIME2     NULL,

        CONSTRAINT uq_customers_email   UNIQUE (email),
        CONSTRAINT chk_customers_user_role CHECK (user_role IN ('customer', 'admin'))
    );
END;
GO

-- =========================================================
-- ตาราง: promotions  โปรโมชันส่วนลด
-- =========================================================
IF OBJECT_ID(N'promotions', N'U') IS NULL
BEGIN
    CREATE TABLE promotions (
        promotion_id    INT IDENTITY(1,1) PRIMARY KEY,
        promotion_code  VARCHAR(50)    NOT NULL,
        discount_type   VARCHAR(20)    NOT NULL,
        discount_value  DECIMAL(10,2)  NOT NULL,
        start_date      DATE           NOT NULL,
        end_date        DATE           NOT NULL,
        status          VARCHAR(20)    NOT NULL,

        CONSTRAINT uq_promotions_code          UNIQUE (promotion_code),
        CONSTRAINT chk_promotions_discount_type CHECK (discount_type IN ('percentage', 'fixed')),
        CONSTRAINT chk_promotions_discount_value CHECK (discount_value >= 0),
        -- ส่วนลดแบบเปอร์เซ็นต์ต้องไม่เกิน 100
        CONSTRAINT chk_promotions_percentage   CHECK (discount_type <> 'percentage' OR discount_value <= 100),
        CONSTRAINT chk_promotions_date         CHECK (end_date >= start_date),
        CONSTRAINT chk_promotions_status       CHECK (status IN ('active', 'inactive'))
    );
END;
GO

-- =========================================================
-- ตาราง: bookings
-- booking_status: pending=ถือที่นั่งรอชำระ | confirmed=ชำระแล้ว | expired=หมดเวลา | cancelled=ยกเลิก
-- =========================================================
IF OBJECT_ID(N'bookings', N'U') IS NULL
BEGIN
    CREATE TABLE bookings (
        booking_id      INT IDENTITY(1,1) PRIMARY KEY,
        customer_id     INT            NOT NULL,
        showtime_id     INT            NOT NULL,
        promotion_id    INT            NULL,
        booking_time    DATETIME2      NOT NULL
            CONSTRAINT df_bookings_booking_time DEFAULT SYSDATETIME(),
        expires_at      DATETIME2      NOT NULL,   -- เวลาหมดอายุการถือครองที่นั่ง
        booking_status  VARCHAR(20)    NOT NULL,
        total_amount    DECIMAL(10,2)  NOT NULL,

        CONSTRAINT fk_bookings_customer FOREIGN KEY (customer_id)
            REFERENCES customers(customer_id) ON DELETE NO ACTION ON UPDATE CASCADE,
        CONSTRAINT fk_bookings_showtime FOREIGN KEY (showtime_id)
            REFERENCES showtimes(showtime_id) ON DELETE NO ACTION ON UPDATE CASCADE,
        CONSTRAINT fk_bookings_promotion FOREIGN KEY (promotion_id)
            REFERENCES promotions(promotion_id) ON DELETE SET NULL ON UPDATE CASCADE,

        CONSTRAINT chk_bookings_expiry CHECK (expires_at > booking_time),
        CONSTRAINT chk_bookings_amount CHECK (total_amount >= 0),
        CONSTRAINT chk_bookings_status CHECK (booking_status IN ('pending', 'confirmed', 'expired', 'cancelled'))
    );
END;
GO

-- =========================================================
-- ตาราง: tickets  ตั๋วแต่ละใบ/ที่นั่ง
-- การกันที่นั่งซ้ำข้าม booking ควบคุมใน sp_ValidateBookingRequest (ล็อกแถว showtimes ขณะตรวจ)
-- =========================================================
IF OBJECT_ID(N'tickets', N'U') IS NULL
BEGIN
    CREATE TABLE tickets (
        ticket_id      INT IDENTITY(1,1) PRIMARY KEY,
        booking_id     INT            NOT NULL,
        seat_id        INT            NOT NULL,
        ticket_price   DECIMAL(10,2)  NOT NULL,   -- ราคา ณ เวลาที่จอง (snapshot)
        ticket_status  VARCHAR(20)    NOT NULL,

        CONSTRAINT fk_tickets_booking FOREIGN KEY (booking_id)
            REFERENCES bookings(booking_id) ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT fk_tickets_seat FOREIGN KEY (seat_id)
            REFERENCES seats(seat_id) ON DELETE NO ACTION ON UPDATE CASCADE,
        CONSTRAINT uq_tickets_booking_seat UNIQUE (booking_id, seat_id),
        CONSTRAINT chk_tickets_price  CHECK (ticket_price >= 0),
        CONSTRAINT chk_tickets_status CHECK (ticket_status IN ('reserved', 'issued', 'cancelled'))
    );
END;
GO

-- =========================================================
-- ตาราง: payments  การชำระเงิน (1 booking : 1 payment)
-- =========================================================
IF OBJECT_ID(N'payments', N'U') IS NULL
BEGIN
    CREATE TABLE payments (
        payment_id      INT IDENTITY(1,1) PRIMARY KEY,
        booking_id      INT            NOT NULL,
        amount          DECIMAL(10,2)  NOT NULL,
        payment_method  VARCHAR(20)    NOT NULL,
        payment_status  VARCHAR(20)    NOT NULL,
        paid_at         DATETIME2      NULL,

        CONSTRAINT fk_payments_booking FOREIGN KEY (booking_id)
            REFERENCES bookings(booking_id) ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT uq_payments_booking  UNIQUE (booking_id),
        CONSTRAINT chk_payments_amount  CHECK (amount >= 0),
        CONSTRAINT chk_payments_method  CHECK (payment_method IN ('cash', 'card', 'online')),
        CONSTRAINT chk_payments_status  CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded'))
    );
END;
GO

-- =========================================================
-- UPGRADE: สำหรับฐานข้อมูลเก่าที่สร้างจากสคีมาก่อนรวม migration (ฐานใหม่จะข้ามทั้งหมด)
-- =========================================================
IF COL_LENGTH('movies', 'poster_url') IS NULL
    ALTER TABLE movies ADD poster_url VARCHAR(500) NULL;
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
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'chk_promotions_percentage')
    ALTER TABLE promotions
        ADD CONSTRAINT chk_promotions_percentage CHECK (discount_type <> 'percentage' OR discount_value <= 100);
GO

-- เปลี่ยนชนิดข้อมูลเป็น NVARCHAR เพื่อรองรับภาษาไทย (ถ้ายังเป็น varchar/text)
IF EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID(N'movies') AND c.name = N'title' AND t.name = N'varchar')
    ALTER TABLE movies ALTER COLUMN title NVARCHAR(200) NOT NULL;
IF EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID(N'movies') AND c.name = N'description' AND t.name IN (N'text', N'varchar'))
    ALTER TABLE movies ALTER COLUMN description NVARCHAR(MAX) NULL;
IF EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID(N'customers') AND c.name = N'name' AND t.name = N'varchar')
    ALTER TABLE customers ALTER COLUMN name NVARCHAR(150) NOT NULL;
GO

-- =========================================================
-- INDEXES  (เหตุผลการออกแบบแต่ละตัวอยู่ใน docs/report/chapter3_design.md)
-- =========================================================

-- ลบ index เดิมที่ซ้ำซ้อน/ไม่มี query ใช้ (ถ้ามี)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_showtimes_hall_start' AND object_id = OBJECT_ID('showtimes'))
    DROP INDEX ix_showtimes_hall_start ON showtimes;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_showtimes_status' AND object_id = OBJECT_ID('showtimes'))
    DROP INDEX ix_showtimes_status ON showtimes;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_seats_hall' AND object_id = OBJECT_ID('seats'))
    DROP INDEX ix_seats_hall ON seats;                 -- ซ้ำกับ uq_seats_position (hall_id นำหน้า)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_bookings_customer' AND object_id = OBJECT_ID('bookings'))
    DROP INDEX ix_bookings_customer ON bookings;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_bookings_showtime' AND object_id = OBJECT_ID('bookings'))
    DROP INDEX ix_bookings_showtime ON bookings;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_tickets_booking' AND object_id = OBJECT_ID('tickets'))
    DROP INDEX ix_tickets_booking ON tickets;          -- ซ้ำกับ uq_tickets_booking_seat
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_tickets_status' AND object_id = OBJECT_ID('tickets'))
    DROP INDEX ix_tickets_status ON tickets;           -- selectivity ต่ำ (3 ค่า)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_payments_status' AND object_id = OBJECT_ID('payments'))
    DROP INDEX ix_payments_status ON payments;         -- ไม่มี query ใดกรองด้วย payment_status
GO

-- showtimes
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_showtimes_movie_start' AND object_id = OBJECT_ID('showtimes'))
    CREATE INDEX ix_showtimes_movie_start ON showtimes (movie_id, start_time);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_showtimes_hall_time' AND object_id = OBJECT_ID('showtimes'))
    CREATE INDEX ix_showtimes_hall_time ON showtimes (hall_id, start_time) INCLUDE (end_time, status);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_showtimes_status_start' AND object_id = OBJECT_ID('showtimes'))
    CREATE INDEX ix_showtimes_status_start ON showtimes (status, start_time);

-- bookings
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_bookings_customer_time' AND object_id = OBJECT_ID('bookings'))
    CREATE INDEX ix_bookings_customer_time ON bookings (customer_id, booking_time DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_bookings_showtime_status' AND object_id = OBJECT_ID('bookings'))
    CREATE INDEX ix_bookings_showtime_status ON bookings (showtime_id, booking_status) INCLUDE (expires_at);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_bookings_status_expires' AND object_id = OBJECT_ID('bookings'))
    CREATE INDEX ix_bookings_status_expires ON bookings (booking_status, expires_at);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_bookings_promotion' AND object_id = OBJECT_ID('bookings'))
    CREATE INDEX ix_bookings_promotion ON bookings (promotion_id);

-- tickets
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_tickets_booking_status' AND object_id = OBJECT_ID('tickets'))
    CREATE INDEX ix_tickets_booking_status ON tickets (booking_id, ticket_status) INCLUDE (seat_id, ticket_price);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_tickets_seat' AND object_id = OBJECT_ID('tickets'))
    CREATE INDEX ix_tickets_seat ON tickets (seat_id);
GO

PRINT N'schema.sql เสร็จสมบูรณ์ (9 ตาราง)';
GO
