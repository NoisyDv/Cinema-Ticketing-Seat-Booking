-- =========================================================
-- schema.sql
-- ระบบจองตั๋วภาพยนตร์และผังที่นั่ง (Cinema Ticketing & Seat Booking)
-- หัวข้อที่ 7 - รายวิชาระบบฐานข้อมูล 2569
-- DBMS: Microsoft SQL Server
-- จำนวนตาราง: 9 ตาราง (อยู่ในเกณฑ์ 8-10 ตาราง)
-- มาตรฐานการตั้งชื่อ: snake_case
-- =========================================================

-- =========================================================
-- ตาราง: movies
-- เก็บข้อมูลภาพยนตร์ที่มีในระบบ
-- =========================================================
CREATE TABLE movies (
    movie_id      INT IDENTITY(1,1) PRIMARY KEY,
    title         VARCHAR(200)  NOT NULL,
    description   TEXT          NULL,
    duration      INT           NOT NULL,          -- หน่วยเป็นนาที
    genre         VARCHAR(50)   NOT NULL,
    release_date  DATE          NOT NULL,
    status        VARCHAR(20)   NOT NULL,

    -- ระยะเวลาฉายต้องมากกว่า 0
    CONSTRAINT chk_movies_duration
        CHECK (duration > 0),

    -- สถานะได้เฉพาะ active หรือ inactive
    CONSTRAINT chk_movies_status
        CHECK (status IN ('active', 'inactive'))
);

-- =========================================================
-- ตาราง: cinema_halls
-- เก็บข้อมูลโรงภาพยนตร์
-- =========================================================
CREATE TABLE cinema_halls (
    hall_id    INT IDENTITY(1,1) PRIMARY KEY,
    hall_name  VARCHAR(100)  NOT NULL,
    capacity   INT           NOT NULL,
    status     VARCHAR(20)   NOT NULL,

    -- ชื่อโรงต้องไม่ซ้ำ
    CONSTRAINT uq_cinema_halls_name
        UNIQUE (hall_name),

    -- ความจุต้องมากกว่า 0
    CONSTRAINT chk_cinema_halls_capacity
        CHECK (capacity > 0),

    -- สถานะได้เฉพาะ active หรือ inactive
    CONSTRAINT chk_cinema_halls_status
        CHECK (status IN ('active', 'inactive'))
);

-- =========================================================
-- ตาราง: seats
-- เก็บข้อมูลที่นั่งของแต่ละโรงภาพยนตร์
-- =========================================================
CREATE TABLE seats (
    seat_id      INT IDENTITY(1,1) PRIMARY KEY,
    hall_id      INT           NOT NULL,
    row_label    VARCHAR(10)   NOT NULL,
    seat_number  INT           NOT NULL,
    seat_type    VARCHAR(20)   NOT NULL,

    CONSTRAINT fk_seats_hall
        FOREIGN KEY (hall_id)
        REFERENCES cinema_halls(hall_id)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,

    -- ตำแหน่งที่นั่งต้องไม่ซ้ำภายในโรงเดียวกัน
    CONSTRAINT uq_seats_position
        UNIQUE (hall_id, row_label, seat_number),

    -- หมายเลขที่นั่งต้องมากกว่า 0
    CONSTRAINT chk_seats_number
        CHECK (seat_number > 0),

    -- ประเภทที่นั่งได้เฉพาะ standard หรือ premium
    CONSTRAINT chk_seats_type
        CHECK (seat_type IN ('standard', 'premium'))
);

-- =========================================================
-- ตาราง: showtimes
-- เก็บรอบฉายภาพยนตร์ในแต่ละโรง
-- =========================================================
CREATE TABLE showtimes (
    showtime_id   INT IDENTITY(1,1) PRIMARY KEY,
    movie_id      INT            NOT NULL,
    hall_id       INT            NOT NULL,
    start_time    DATETIME2      NOT NULL,
    end_time      DATETIME2      NOT NULL,
    ticket_price  DECIMAL(10,2)  NOT NULL,
    status        VARCHAR(20)    NOT NULL,

    CONSTRAINT fk_showtimes_movie
        FOREIGN KEY (movie_id)
        REFERENCES movies(movie_id)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,

    CONSTRAINT fk_showtimes_hall
        FOREIGN KEY (hall_id)
        REFERENCES cinema_halls(hall_id)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,

    -- เวลาสิ้นสุดต้องหลังเวลาเริ่มฉาย
    CONSTRAINT chk_showtimes_time
        CHECK (end_time > start_time),

    -- ราคาตั๋วต้องไม่ติดลบ
    CONSTRAINT chk_showtimes_price
        CHECK (ticket_price >= 0),

    -- สถานะรอบฉายที่อนุญาต
    CONSTRAINT chk_showtimes_status
        CHECK (status IN ('scheduled', 'cancelled', 'completed'))
);

-- =========================================================
-- ตาราง: customers
-- เก็บข้อมูลลูกค้าที่ใช้ระบบ
-- =========================================================
CREATE TABLE customers (
    customer_id  INT IDENTITY(1,1) PRIMARY KEY,
    name         VARCHAR(150)  NOT NULL,
    email        VARCHAR(255)  NOT NULL,
    phone        VARCHAR(20)   NOT NULL,
    created_at   DATETIME2     NOT NULL
        CONSTRAINT df_customers_created_at DEFAULT SYSDATETIME(),

    -- emailต้องไม่ซ้ำ
    CONSTRAINT uq_customers_email
        UNIQUE (email)
);

-- =========================================================
-- ตาราง: promotions
-- เก็บข้อมูลโปรโมชันส่วนลดสำหรับการจอง
-- =========================================================
CREATE TABLE promotions (
    promotion_id    INT IDENTITY(1,1) PRIMARY KEY,
    promotion_code  VARCHAR(50)    NOT NULL,
    discount_type   VARCHAR(20)    NOT NULL,
    discount_value  DECIMAL(10,2)  NOT NULL,
    start_date      DATE           NOT NULL,
    end_date        DATE           NOT NULL,
    status          VARCHAR(20)    NOT NULL,

    -- รหัสโปรโมชันต้องไม่ซ้ำ
    CONSTRAINT uq_promotions_code
        UNIQUE (promotion_code),

    -- ประเภทส่วนลดได้เฉพาะ percentage หรือ fixed
    CONSTRAINT chk_promotions_discount_type
        CHECK (discount_type IN ('percentage', 'fixed')),

    -- ค่าส่วนลดต้องไม่ติดลบ
    CONSTRAINT chk_promotions_discount_value
        CHECK (discount_value >= 0),

    -- วันสิ้นสุดต้องไม่ก่อนวันเริ่มต้น
    CONSTRAINT chk_promotions_date
        CHECK (end_date >= start_date),

    -- สถานะโปรโมชันที่อนุญาต
    CONSTRAINT chk_promotions_status
        CHECK (status IN ('active', 'inactive'))
);

-- =========================================================
-- ตาราง: bookings
-- เก็บรายการจองที่นั่งของลูกค้า
-- ความหมายของ booking_status:
--   pending   = ล็อกที่นั่งชั่วคราว รอชำระเงิน
--   confirmed = ชำระเงินสำเร็จแล้ว
--   expired   = หมดเวลาถือครอง (Trigger จะปล่อยที่นั่ง)
--   cancelled = ยกเลิกโดยผู้ใช้
-- =========================================================
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

    CONSTRAINT fk_bookings_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,

    CONSTRAINT fk_bookings_showtime
        FOREIGN KEY (showtime_id)
        REFERENCES showtimes(showtime_id)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,

    CONSTRAINT fk_bookings_promotion
        FOREIGN KEY (promotion_id)
        REFERENCES promotions(promotion_id)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    -- เวลาหมดอายุต้องหลังเวลาจอง
    CONSTRAINT chk_bookings_expiry
        CHECK (expires_at > booking_time),

    -- ยอดรวมต้องไม่ติดลบ
    CONSTRAINT chk_bookings_amount
        CHECK (total_amount >= 0),

    -- สถานะการจองที่อนุญาต
    CONSTRAINT chk_bookings_status
        CHECK (booking_status IN (
            'pending',
            'confirmed',
            'expired',
            'cancelled'
        ))
);

-- =========================================================
-- ตาราง: tickets
-- เก็บตั๋วภาพยนตร์แต่ละใบและที่นั่งที่จอง
-- หมายเหตุ: การป้องกันที่นั่งซ้ำข้าม booking (showtime + seat)
--          จะถูกควบคุมใน Stored Procedure (sp_BookMovieSeats)
-- =========================================================
CREATE TABLE tickets (
    ticket_id      INT IDENTITY(1,1) PRIMARY KEY,
    booking_id     INT            NOT NULL,
    seat_id        INT            NOT NULL,
    ticket_price   DECIMAL(10,2)  NOT NULL,   -- ราคา ณ เวลาที่จอง (snapshot)
    ticket_status  VARCHAR(20)    NOT NULL,

    CONSTRAINT fk_tickets_booking
        FOREIGN KEY (booking_id)
        REFERENCES bookings(booking_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_tickets_seat
        FOREIGN KEY (seat_id)
        REFERENCES seats(seat_id)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,

    -- ที่นั่งเดียวกันต้องไม่ซ้ำภายใน booking เดียว
    CONSTRAINT uq_tickets_booking_seat
        UNIQUE (booking_id, seat_id),

    -- ราคาตั๋วต้องไม่ติดลบ
    CONSTRAINT chk_tickets_price
        CHECK (ticket_price >= 0),

    -- สถานะตั๋วที่อนุญาต
    CONSTRAINT chk_tickets_status
        CHECK (ticket_status IN (
            'reserved',   -- ล็อกชั่วคราว (รอชำระเงิน)
            'issued',     -- ออกตั๋วแล้ว (ชำระเงินสำเร็จ)
            'cancelled'
        ))
);

-- =========================================================
-- ตาราง: payments
-- เก็บข้อมูลการชำระเงินของการจอง
-- =========================================================
CREATE TABLE payments (
    payment_id      INT IDENTITY(1,1) PRIMARY KEY,
    booking_id      INT            NOT NULL,
    amount          DECIMAL(10,2)  NOT NULL,
    payment_method  VARCHAR(20)    NOT NULL,
    payment_status  VARCHAR(20)    NOT NULL,
    paid_at         DATETIME2      NULL,

    CONSTRAINT fk_payments_booking
        FOREIGN KEY (booking_id)
        REFERENCES bookings(booking_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    -- หนึ่ง booking มีได้เพียงหนึ่งรายการชำระเงิน
    CONSTRAINT uq_payments_booking
        UNIQUE (booking_id),

    -- จำนวนเงินต้องไม่ติดลบ
    CONSTRAINT chk_payments_amount
        CHECK (amount >= 0),

    -- ช่องทางชำระเงินที่อนุญาต
    CONSTRAINT chk_payments_method
        CHECK (payment_method IN ('cash', 'card', 'online')),

    -- สถานะการชำระเงินที่อนุญาต
    CONSTRAINT chk_payments_status
        CHECK (payment_status IN (
            'pending',
            'paid',
            'failed',
            'refunded'
        ))
);

-- =========================================================
-- Indexes เพื่อเพิ่มประสิทธิภาพการค้นหา
-- (ตามเกณฑ์ของโครงงานที่กำหนดให้มี Indexes)
-- =========================================================

-- ใช้บ่อยในขั้นตอนจองและรายงาน
CREATE INDEX ix_showtimes_movie_start
    ON showtimes (movie_id, start_time);

CREATE INDEX ix_showtimes_hall_start
    ON showtimes (hall_id, start_time);

CREATE INDEX ix_showtimes_status
    ON showtimes (status);

-- ค้นหาที่นั่งตามโรง
CREATE INDEX ix_seats_hall
    ON seats (hall_id);

-- ค้นหาการจอง
CREATE INDEX ix_bookings_customer
    ON bookings (customer_id);

CREATE INDEX ix_bookings_showtime
    ON bookings (showtime_id);

-- ใช้กับ Trigger ปล่อยที่นั่งที่หมดเวลา
CREATE INDEX ix_bookings_status_expires
    ON bookings (booking_status, expires_at);

-- ค้นหาตั๋ว
CREATE INDEX ix_tickets_booking
    ON tickets (booking_id);

CREATE INDEX ix_tickets_seat
    ON tickets (seat_id);

CREATE INDEX ix_tickets_status
    ON tickets (ticket_status);

-- ค้นหาสถานะการชำระเงิน
CREATE INDEX ix_payments_status
    ON payments (payment_status);
