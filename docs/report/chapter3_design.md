# บทที่ 3 (ร่าง): การออกแบบฐานข้อมูลเชิงกายภาพ, Index, Stored Procedure / Trigger / View / Transaction

> ร่างจากโค้ดจริง (`database/schema.sql`, `database/logic.sql`, `database/queries.sql`) ทีมควรอ่านโค้ดประกอบและเรียบเรียงเอง
> **ข้อจำกัด:** การวิเคราะห์ Index ด้านล่างได้จากการอ่านเงื่อนไขของคิวรีจริง ไม่ได้ตรวจ Execution Plan บน SQL Server ทีมควรเปิด Actual Execution Plan ใน SSMS เพื่อยืนยันก่อนใส่ในรายงาน

## 3.1 เหตุผลการออกแบบ Index

PK, UNIQUE และ FK ที่มี UNIQUE index อยู่แล้วไม่นับซ้ำ (เช่น `uq_customers_email` รองรับการล็อกอินด้วยอีเมล, `uq_promotions_code` รองรับการค้นโค้ด, `uq_seats_position` รองรับการดึงที่นั่งของโรง)

| Index | คอลัมน์ | รองรับงาน/คิวรีจริง | เหตุผล |
|---|---|---|---|
| `ix_showtimes_movie_start` | `showtimes(movie_id, start_time)` | หน้า "เลือกรอบฉาย" (`Repo.GetUpcomingShowtimes`), JOIN ใน Query 2, 3, 5, 6, 9 และวิว `vw_BoxOfficeOccupancyReport` | กรองด้วยหนังแล้วเรียงตามเวลา ใช้ Seek ได้เลยโดยไม่ต้อง Sort |
| `ix_showtimes_hall_time` | `showtimes(hall_id, start_time) INCLUDE (end_time, status)` | `trg_PreventShowtimeOverlap` ตรวจรอบทับซ้อนในโรงเดียวกัน | trigger ค้นด้วย `hall_id` และช่วงเวลา จึงต้องการ `end_time`/`status` ครบใน index (Covering) ไม่ต้อง Key Lookup |
| `ix_showtimes_status_start` | `showtimes(status, start_time)` | Query 8 (`status = 'scheduled'`), หน้าจัดการรอบฉายที่กรองสถานะ | แทน index เดิมที่มีเฉพาะ `status` (selectivity ต่ำเพียง 3 ค่า) โดยเพิ่ม `start_time` ให้ใช้เรียงผลได้ |
| `ix_bookings_customer_time` | `bookings(customer_id, booking_time DESC)` | "การจองของฉัน" (`Repo.GetMyBookings`), Query 4, 7, 10 (PARTITION BY ลูกค้า เรียงตามเวลาล่าสุด) | ค้นตามลูกค้าและได้ลำดับเวลาล่าสุดก่อนทันที |
| `ix_bookings_showtime_status` | `bookings(showtime_id, booking_status) INCLUDE (expires_at)` | `vw_TakenSeats` (ผังที่นั่ง), Query 1, 2, 5, 8 ที่กรอง `confirmed` | ผังที่นั่งต้องหาการจองที่ active ของรอบนั้นเร็ว และใช้ `expires_at` ตรวจ pending ที่หมดเวลา |
| `ix_bookings_status_expires` | `bookings(booking_status, expires_at)` | `trg_ReleaseExpiredSeatLocks`, `sp_ReleaseExpiredHolds` | ทั้งคู่หา `pending` ที่ `expires_at` เลยเวลา ใช้ Range Seek แตะเฉพาะแถว pending ซึ่งมีน้อย |
| `ix_bookings_promotion` | `bookings(promotion_id)` | FK `ON DELETE SET NULL` เมื่อลบโปรโมชัน, นับจำนวนครั้งที่ใช้โค้ด (หน้า admin) | SQL Server ไม่สร้าง index ให้ FK อัตโนมัติ ถ้าไม่มีต้องสแกนทั้งตารางตอนลบโปรโมชัน |
| `ix_tickets_booking_status` | `tickets(booking_id, ticket_status) INCLUDE (seat_id, ticket_price)` | Query 1, 3, 5, 6, 9, `vw_BoxOfficeOccupancyReport`, `vw_TakenSeats`, ตั๋วของการจอง | คิวรีรายงานกรอง `issued` และรวม `ticket_price` ได้จาก index อย่างเดียว (Covering) |
| `ix_tickets_seat` | `tickets(seat_id)` | ตรวจ FK ไปที่ `seats` และประวัติของที่นั่ง | รองรับการแก้/ลบที่นั่งโดยไม่ต้องสแกนตั๋วทั้งหมด |

**Index เดิมที่ถอดออก (ซ้ำซ้อนหรือไม่มีคิวรีใช้):**

| Index เดิม | เหตุผลที่ถอด |
|---|---|
| `ix_seats_hall (hall_id)` | ซ้ำกับ `uq_seats_position (hall_id, row_label, seat_number)` ซึ่งนำด้วย `hall_id` อยู่แล้ว |
| `ix_tickets_booking (booking_id)` | ซ้ำกับ `uq_tickets_booking_seat (booking_id, seat_id)` และถูกแทนด้วย `ix_tickets_booking_status` |
| `ix_tickets_status`, `ix_payments_status`, `ix_showtimes_status` | คอลัมน์สถานะมีค่าไม่กี่ค่า (selectivity ต่ำ) และไม่มีคิวรีใดกรองด้วยคอลัมน์นั้นลำพัง |
| `ix_showtimes_hall_start`, `ix_bookings_customer`, `ix_bookings_showtime` | ถูกแทนด้วยเวอร์ชันที่มี INCLUDE / คอลัมน์เรียงลำดับตามคิวรีจริง (ชื่อใหม่ในตารางด้านบน) |

**ไม่ทำ:** filtered index (`WHERE booking_status='pending'`) เพราะต้องใช้ `SET QUOTED_IDENTIFIER ON` ในทุกการเชื่อมต่อที่แก้ตาราง ซึ่ง `sqlcmd` ค่าเริ่มต้นเป็น OFF จึงเสี่ยงต่อ error 1934

## 3.2 การรวม migration และการแบ่งหน้าที่ของ SP

**ตัดสินใจรวม `migration.sql` เข้า `schema.sql` / `logic.sql` แล้วเลิกใช้ไฟล์แยก** เพราะ (1) ส่งงานเป็นฐานข้อมูลใหม่ ลำดับ schema → data → logic → queries ตรงไปตรงมา (2) แยก migration ทำให้ data.sql ต้องรอคอลัมน์ที่ยังไม่มี และผู้ตรวจต้องจำลำดับรันเพิ่ม (3) ส่วน "UPGRADE" ท้าย `schema.sql` ใช้ `IF COL_LENGTH ... IS NULL ALTER TABLE` จึงยังอัปเกรดฐานเก่าได้

| Procedure | ใช้โดย | หน้าที่ |
|---|---|---|
| `sp_BookMovieSeats` | โจทย์ / หน้าเคาน์เตอร์ / ทดสอบ | จอง + ชำระเงินในขั้นตอนเดียว |
| `sp_HoldSeats` → `sp_ConfirmPayment` | **เว็บ** | จองสองขั้นตอน เพราะต้องมีหน้าชำระเงินพร้อมนับถอยหลังระหว่างถือที่นั่ง |
| `sp_ValidateBookingRequest` | ทั้งสองแบบ | กฎการจองทั้งหมดอยู่ที่นี่ที่เดียว กฎจึงไม่ซ้ำซ้อนหรือขัดกัน |
| `sp_CancelHold`, `sp_ReleaseExpiredHolds` | เว็บ | ยกเลิก/ปล่อยการถือที่นั่ง |

## 3.3 คำอธิบายขั้นตอน

### sp_BookMovieSeats (Transaction)
1. ตรวจช่องทางชำระเงิน (`cash/card/online`) → ปล่อยที่นั่งที่หมดเวลา (`sp_ReleaseExpiredHolds`)
2. `BEGIN TRANSACTION`
3. `sp_ValidateBookingRequest`: ล็อกแถวรอบฉายด้วย `UPDLOCK, HOLDLOCK` แล้วตรวจรอบฉาย (scheduled และยังไม่เริ่ม), ลูกค้า, ที่นั่ง 1–3 ที่ไม่ซ้ำ, ที่นั่งอยู่ในโรงเดียวกัน, ที่นั่งว่าง (`vw_TakenSeats`), โปรโมชัน และคำนวณยอดด้วย `fn_CalculateBookingTotal`
4. `INSERT bookings` (pending, หมดอายุใน 15 นาที) → `tickets` (reserved) → `payments` (paid)
5. `UPDATE bookings = confirmed`, `tickets = issued`
6. `COMMIT` ถ้ามี error ใด ๆ → `CATCH` → `ROLLBACK` แล้วคืน `error_number`, `error_message`

**ทำไมกันจองซ้ำพร้อมกันได้:** ผู้จองรอบเดียวกันต้องผ่านการล็อก `UPDLOCK + HOLDLOCK` ที่แถวรอบฉายเดียวกัน จึงถูกบังคับให้ทำทีละคน (Serializable ระดับแถวรอบฉาย) คนที่สองจะรอจนคนแรก COMMIT แล้วเห็นว่าที่นั่งไม่ว่างและได้ error 50005 ส่วนรอบฉายต่างกันไม่ขวางกัน *(ยังไม่ได้ทดสอบกับ 2 session จริงบน SQL Server — ดูขั้นตอนทดสอบใน README)*

### sp_HoldSeats / sp_ConfirmPayment
- `sp_HoldSeats`: ขั้น 1–3 เหมือนด้านบน แล้ว `INSERT bookings` (pending) + `tickets` (reserved) คืน `expires_at` และ `seconds_left` จากเวลาเซิร์ฟเวอร์
- `sp_ConfirmPayment`: ล็อกแถวการจอง ตรวจเจ้าของ/หมดเวลา/สถานะ, ถ้ามีโค้ดโปรโมชันจะตรวจและคำนวณยอดใหม่ แล้ว `INSERT payments` → `confirmed` / `issued`

### trg_ReleaseExpiredSeatLocks
หลัง INSERT/UPDATE บน `bookings`: เปลี่ยนการจอง pending ที่หมดเวลา (ทั้งตาราง) เป็น `expired` โดยเก็บ `booking_id` ที่เปลี่ยนไว้ด้วย `OUTPUT INTO` แล้วตั้งตั๋ว reserved ของรายการเหล่านั้น (และของแถวที่เพิ่งแก้เป็น expired) เป็น `cancelled`
**ที่ปรับ:** เดิมขั้นที่ 2 สแกนการจอง `expired` ทั้งตารางทุกครั้ง ตอนนี้แตะเฉพาะแถวที่เกี่ยวข้อง ผลลัพธ์ที่ผู้ใช้เห็นเท่าเดิม **ที่ตั้งใจไม่เปลี่ยน:** ยังกวาด pending ที่หมดเวลาของทุกคน (ไม่จำกัดเฉพาะรอบฉายของแถวที่แก้) เพราะต้องคงพฤติกรรมเดิม และขั้นนี้ใช้ index `ix_bookings_status_expires` จึงแตะเฉพาะแถว pending

### trg_PreventShowtimeOverlap
AFTER INSERT, UPDATE บน `showtimes` รองรับหลายแถว: ข้ามถ้า UPDATE ไม่แตะ `hall_id/start_time/end_time/status`; JOIN `inserted` กับ `showtimes` โรงเดียวกัน รอบอื่น ไม่ใช่ cancelled ด้วยเงื่อนไข `i.start_time < s.end_time AND i.end_time > s.start_time`; ถ้าพบ → `ROLLBACK` + `THROW 50030` พร้อมข้อความไทยบอกโรง เวลา และรอบที่ชน

### vw_BoxOfficeOccupancyReport
รวมรายได้และจำนวนตั๋วที่ออกแล้ว (`issued`) ต่อภาพยนตร์ และอัตราการครองที่นั่ง = ตั๋วที่ขาย × 100 ÷ ที่นั่งรวมของรอบที่ `scheduled/completed` (นิยามเดิมคงไว้ ไม่แก้)

## 3.4 รหัส error ของ procedure/trigger

| รหัส | ความหมาย | รหัส | ความหมาย |
|---|---|---|---|
| 50001 | รอบฉายไม่พบ/ไม่เปิดจอง | 50011 | หมดเวลาถือที่นั่ง |
| 50002 | ไม่พบลูกค้า | 50012 | สถานะไม่ใช่รอชำระ |
| 50003 | โปรโมชันไม่ถูกต้อง/หมดอายุ | 50013 | ช่องทางชำระเงินไม่ถูกต้อง |
| 50004 | ที่นั่งไม่อยู่ในโรงของรอบฉาย | 50020 | อีเมลซ้ำ |
| 50005 | ที่นั่งถูกจอง/ถือไว้แล้ว | 50021 | ข้อมูลสมัครไม่ถูกต้อง |
| 50006 | เลือกที่นั่งซ้ำ | 50030 | รอบฉายทับซ้อน (trigger) |
| 50007 | รอบฉายเริ่มแล้ว | 50099 | เรียกตัวช่วยนอก Transaction |
| 50008 | ต้องเลือกที่นั่งอย่างน้อย 1 ที่ | | |
| 50010 | ไม่พบการจอง | | |

ฝั่งเว็บ (`Db.cs`) แปลง error 50000–59999 เป็น `BusinessException` แสดงข้อความตรง ๆ ส่วน error อื่น (เช่น 547 FK, 2627 UNIQUE) แปลงเป็นข้อความทั่วไป ไม่เปิดเผยรายละเอียดภายใน

## 3.5 ข้อมูลทดสอบและการตรวจสอบ
- `tools/generate_data.py` สร้าง `data.sql` (seed คงที่): หนัง 500, ลูกค้า 502, รอบฉาย 500, การจองกว่า 3,000, ตั๋วกว่า 6,000, ที่นั่ง 2,500, โรง 20, โปรโมชัน 30 โดยวางรอบฉายด้วยตัวตรวจไม่ซ้อนเวลา
- `database/sanity_checks.sql` 26 ข้อ + 3 ข้อเชิงข้อมูล; `database/tests.sql` ทดสอบ trigger รอบทับซ้อน 16 สถานการณ์ และกฎของ SP/Trigger/View อีก 24 สถานการณ์ (รวม 69 ข้อตรวจ)
- **บันทึกข้อบกพร่องของข้อมูลชุดเดิม (ใช้เป็นเหตุผลในรายงาน):** ตัวสร้างข้อมูลเดิมทำให้รอบฉายชนกัน 424 คู่ (รอบที่ i, i+180, i+360 อยู่โรง/วัน/ชั่วโมงเดียวกัน) และการจอง confirmed ที่นั่งซ้ำรอบเดียวกัน 84 คู่ (การจอง i และ i+500) ซึ่งตัวสร้างใหม่แก้แล้ว
