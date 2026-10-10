# พจนานุกรมข้อมูล (Data Dictionary) — ร่างแรก

> สร้างอัตโนมัติจาก `database/schema.sql` โดย `tools/make_data_dictionary.py` (ชื่อคอลัมน์ ชนิดข้อมูล และข้อจำกัดอ่านจากสคีมาจริง) ส่วนคำอธิบายเป็นร่างที่ทีมควรตรวจและปรับถ้อยคำก่อนใส่รายงาน

ระบบมี **9 ตาราง** ชื่อตารางและคอลัมน์เป็นภาษาอังกฤษ snake_case รูปพหูพจน์


## ตาราง `movies`

ภาพยนตร์ที่ระบบมีข้อมูล (รวมเรื่องที่ไม่ได้ฉายแล้ว)

| คอลัมน์ | ชนิดข้อมูล | ข้อจำกัด | คำอธิบาย |
|---|---|---|---|
| `movie_id` | INT | PK, IDENTITY(1,1)<br>NOT NULL | รหัสภาพยนตร์ (สร้างอัตโนมัติ) |
| `title` | NVARCHAR(200) | NOT NULL | ชื่อภาพยนตร์ |
| `description` | NVARCHAR(MAX) | NULL | เรื่องย่อ |
| `duration` | INT | NOT NULL<br>CHECK (chk_movies_duration) | ความยาว (นาที) |
| `genre` | VARCHAR(50) | NOT NULL | ประเภทภาพยนตร์ (ค่าเดียวต่อเรื่อง) |
| `release_date` | DATE | NOT NULL | วันเข้าฉาย |
| `status` | VARCHAR(20) | NOT NULL<br>CHECK (chk_movies_status) | active = เปิดใช้งาน / inactive = ปิดใช้งาน |
| `poster_url` | VARCHAR(500) | NULL | ลิงก์รูปโปสเตอร์ (ไม่บังคับ) |

**ข้อจำกัดที่เกี่ยวกับหลายคอลัมน์:** (ไม่มี)

## ตาราง `cinema_halls`

โรงภาพยนตร์ในโรงหนัง

| คอลัมน์ | ชนิดข้อมูล | ข้อจำกัด | คำอธิบาย |
|---|---|---|---|
| `hall_id` | INT | PK, IDENTITY(1,1)<br>NOT NULL | รหัสโรง |
| `hall_name` | VARCHAR(100) | NOT NULL<br>UNIQUE (uq_cinema_halls_name) | ชื่อโรง (ไม่ซ้ำ) |
| `capacity` | INT | NOT NULL<br>CHECK (chk_cinema_halls_capacity) | จำนวนที่นั่งทั้งหมดของโรง |
| `status` | VARCHAR(20) | NOT NULL<br>CHECK (chk_cinema_halls_status) | active = ใช้งาน / inactive = ปิดปรับปรุง |

**ข้อจำกัดที่เกี่ยวกับหลายคอลัมน์:** (ไม่มี)

## ตาราง `seats`

ที่นั่งแต่ละที่นั่งของแต่ละโรง

| คอลัมน์ | ชนิดข้อมูล | ข้อจำกัด | คำอธิบาย |
|---|---|---|---|
| `seat_id` | INT | PK, IDENTITY(1,1)<br>NOT NULL | รหัสที่นั่ง |
| `hall_id` | INT | NOT NULL<br>FK → cinema_halls(hall_id) [DELETE NO ACTION, UPDATE NO ACTION]<br>UNIQUE (uq_seats_position) | โรงที่ที่นั่งนี้อยู่ |
| `row_label` | VARCHAR(10) | NOT NULL<br>UNIQUE (uq_seats_position) | ตัวอักษรแถว เช่น A, B |
| `seat_number` | INT | NOT NULL<br>UNIQUE (uq_seats_position)<br>CHECK (chk_seats_number) | หมายเลขที่นั่งในแถว |
| `seat_type` | VARCHAR(20) | NOT NULL<br>CHECK (chk_seats_type) | standard = มาตรฐาน / premium = พรีเมียม (2 แถวหลังสุด) |

**ข้อจำกัดที่เกี่ยวกับหลายคอลัมน์:** `uq_seats_position` (UNIQUE: (hall_id, row_label, seat_number))

## ตาราง `showtimes`

รอบฉาย = หนัง 1 เรื่อง ในโรง 1 โรง ช่วงเวลาหนึ่ง

| คอลัมน์ | ชนิดข้อมูล | ข้อจำกัด | คำอธิบาย |
|---|---|---|---|
| `showtime_id` | INT | PK, IDENTITY(1,1)<br>NOT NULL | รหัสรอบฉาย |
| `movie_id` | INT | NOT NULL<br>FK → movies(movie_id) [DELETE NO ACTION, UPDATE CASCADE] | ภาพยนตร์ที่ฉาย |
| `hall_id` | INT | NOT NULL<br>FK → cinema_halls(hall_id) [DELETE NO ACTION, UPDATE CASCADE] | โรงที่ฉาย |
| `start_time` | DATETIME2 | NOT NULL<br>CHECK (chk_showtimes_time) | เวลาเริ่มฉาย |
| `end_time` | DATETIME2 | NOT NULL<br>CHECK (chk_showtimes_time) | เวลาจบ (ต้องหลังเวลาเริ่ม) |
| `ticket_price` | DECIMAL(10,2) | NOT NULL<br>CHECK (chk_showtimes_price) | ราคาตั๋วต่อที่นั่งของรอบนี้ |
| `status` | VARCHAR(20) | NOT NULL<br>CHECK (chk_showtimes_status) | scheduled = เปิดจอง / completed = ฉายแล้ว / cancelled = ยกเลิก |

**ข้อจำกัดที่เกี่ยวกับหลายคอลัมน์:** `chk_showtimes_time` (CHECK: (end_time > start_time))

## ตาราง `customers`

ลูกค้า/ผู้ใช้ระบบ (รวมบัญชีผู้ดูแลระบบ)

| คอลัมน์ | ชนิดข้อมูล | ข้อจำกัด | คำอธิบาย |
|---|---|---|---|
| `customer_id` | INT | PK, IDENTITY(1,1)<br>NOT NULL | รหัสลูกค้า |
| `name` | NVARCHAR(150) | NOT NULL | ชื่อ-นามสกุล |
| `email` | VARCHAR(255) | NOT NULL<br>UNIQUE (uq_customers_email) | อีเมล (ไม่ซ้ำ ใช้ล็อกอิน) |
| `phone` | VARCHAR(20) | NOT NULL | เบอร์โทรศัพท์ (ตัวเลข) |
| `created_at` | DATETIME2 | NOT NULL<br>DEFAULT SYSDATETIME( | เวลาสมัครสมาชิก |
| `password_hash` | VARCHAR(255) | NULL | ค่าแฮช PBKDF2-SHA256 + salt (ไม่เก็บรหัสผ่านจริง) NULL = ยังล็อกอินไม่ได้ |
| `user_role` | VARCHAR(20) | NOT NULL<br>DEFAULT 'customer'<br>CHECK (chk_customers_user_role) | customer = ลูกค้า / admin = ผู้ดูแลระบบ |
| `last_login_at` | DATETIME2 | NULL | เวลาล็อกอินล่าสุด |

**ข้อจำกัดที่เกี่ยวกับหลายคอลัมน์:** (ไม่มี)

## ตาราง `promotions`

โค้ดส่วนลด

| คอลัมน์ | ชนิดข้อมูล | ข้อจำกัด | คำอธิบาย |
|---|---|---|---|
| `promotion_id` | INT | PK, IDENTITY(1,1)<br>NOT NULL | รหัสโปรโมชัน |
| `promotion_code` | VARCHAR(50) | NOT NULL<br>UNIQUE (uq_promotions_code) | โค้ดที่ลูกค้ากรอก (ไม่ซ้ำ) |
| `discount_type` | VARCHAR(20) | NOT NULL<br>CHECK (chk_promotions_discount_type)<br>CHECK (chk_promotions_percentage) | percentage = เปอร์เซ็นต์ / fixed = จำนวนเงินคงที่ |
| `discount_value` | DECIMAL(10,2) | NOT NULL<br>CHECK (chk_promotions_discount_value)<br>CHECK (chk_promotions_percentage) | มูลค่าส่วนลด (percentage ต้องไม่เกิน 100) |
| `start_date` | DATE | NOT NULL<br>CHECK (chk_promotions_date) | วันเริ่มใช้ |
| `end_date` | DATE | NOT NULL<br>CHECK (chk_promotions_date) | วันสิ้นสุด (ไม่ก่อนวันเริ่ม) |
| `status` | VARCHAR(20) | NOT NULL<br>CHECK (chk_promotions_status) | active / inactive |

**ข้อจำกัดที่เกี่ยวกับหลายคอลัมน์:** `chk_promotions_percentage` (CHECK: (discount_type <> 'percentage' OR discount_value <= 100)); `chk_promotions_date` (CHECK: (end_date >= start_date))

## ตาราง `bookings`

การจอง 1 ครั้ง (ถือที่นั่งแล้วชำระเงิน)

| คอลัมน์ | ชนิดข้อมูล | ข้อจำกัด | คำอธิบาย |
|---|---|---|---|
| `booking_id` | INT | PK, IDENTITY(1,1)<br>NOT NULL | รหัสการจอง |
| `customer_id` | INT | NOT NULL<br>FK → customers(customer_id) [DELETE NO ACTION, UPDATE CASCADE] | ผู้จอง |
| `showtime_id` | INT | NOT NULL<br>FK → showtimes(showtime_id) [DELETE NO ACTION, UPDATE CASCADE] | รอบฉายที่จอง |
| `promotion_id` | INT | NULL<br>FK → promotions(promotion_id) [DELETE SET NULL, UPDATE CASCADE] | โปรโมชันที่ใช้ (NULL = ไม่ใช้) |
| `booking_time` | DATETIME2 | NOT NULL<br>DEFAULT SYSDATETIME(<br>CHECK (chk_bookings_expiry) | เวลาที่จอง/ถือที่นั่ง |
| `expires_at` | DATETIME2 | NOT NULL<br>CHECK (chk_bookings_expiry) | เวลาหมดอายุการถือที่นั่ง (ปกติ +15 นาที) |
| `booking_status` | VARCHAR(20) | NOT NULL<br>CHECK (chk_bookings_status) | pending = ถือที่นั่งรอชำระ / confirmed = ชำระแล้ว / expired = หมดเวลา / cancelled = ยกเลิก |
| `total_amount` | DECIMAL(10,2) | NOT NULL<br>CHECK (chk_bookings_amount) | ยอดรวมหลังส่วนลด |

**ข้อจำกัดที่เกี่ยวกับหลายคอลัมน์:** `chk_bookings_expiry` (CHECK: (expires_at > booking_time))

## ตาราง `tickets`

ตั๋วแต่ละใบ = 1 ที่นั่งในการจอง (ตารางเชื่อม bookings กับ seats)

| คอลัมน์ | ชนิดข้อมูล | ข้อจำกัด | คำอธิบาย |
|---|---|---|---|
| `ticket_id` | INT | PK, IDENTITY(1,1)<br>NOT NULL | รหัสตั๋ว |
| `booking_id` | INT | NOT NULL<br>FK → bookings(booking_id) [DELETE CASCADE, UPDATE CASCADE]<br>UNIQUE (uq_tickets_booking_seat) | การจองที่ตั๋วนี้อยู่ |
| `seat_id` | INT | NOT NULL<br>FK → seats(seat_id) [DELETE NO ACTION, UPDATE CASCADE]<br>UNIQUE (uq_tickets_booking_seat) | ที่นั่งของตั๋ว |
| `ticket_price` | DECIMAL(10,2) | NOT NULL<br>CHECK (chk_tickets_price) | ราคาตั๋ว ณ เวลาที่จอง (สำเนาราคาของรอบฉาย) |
| `ticket_status` | VARCHAR(20) | NOT NULL<br>CHECK (chk_tickets_status) | reserved = ถือไว้ / issued = ออกตั๋วแล้ว / cancelled = ยกเลิก |

**ข้อจำกัดที่เกี่ยวกับหลายคอลัมน์:** `uq_tickets_booking_seat` (UNIQUE: (booking_id, seat_id))

## ตาราง `payments`

การชำระเงินของการจอง (1 การจองมีได้ 1 รายการ)

| คอลัมน์ | ชนิดข้อมูล | ข้อจำกัด | คำอธิบาย |
|---|---|---|---|
| `payment_id` | INT | PK, IDENTITY(1,1)<br>NOT NULL | รหัสการชำระเงิน |
| `booking_id` | INT | NOT NULL<br>FK → bookings(booking_id) [DELETE CASCADE, UPDATE CASCADE]<br>UNIQUE (uq_payments_booking) | การจองที่ชำระ (ไม่ซ้ำ) |
| `amount` | DECIMAL(10,2) | NOT NULL<br>CHECK (chk_payments_amount) | จำนวนเงินที่ชำระ |
| `payment_method` | VARCHAR(20) | NOT NULL<br>CHECK (chk_payments_method) | cash / card / online |
| `payment_status` | VARCHAR(20) | NOT NULL<br>CHECK (chk_payments_status) | pending / paid / failed / refunded |
| `paid_at` | DATETIME2 | NULL | เวลาที่ชำระสำเร็จ (NULL ถ้ายังไม่สำเร็จ) |

**ข้อจำกัดที่เกี่ยวกับหลายคอลัมน์:** (ไม่มี)
