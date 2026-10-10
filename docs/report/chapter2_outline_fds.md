# บทที่ 2 (โครงร่างและรายการ FD): EER, Functional Dependencies, Normalization, Relational Schema

> **ข้อควรระวัง:** โจทย์ห้ามคัดลอกคำอธิบาย Normalization จาก AI โดยไม่เข้าใจ เอกสารนี้ให้เฉพาะ **โครงร่าง** และ **รายการ FD ที่อ่านได้จากสคีมาจริง** เพื่อให้สมาชิกกลุ่มนำไปเขียน พิสูจน์ และวาดแผนภาพเอง ทุกข้อที่ทำเครื่องหมาย ⚠️ คือจุดที่ทีมต้องตรวจสอบและตัดสินใจเอง

## 2.1 โครงร่าง EER (สิ่งที่ต้องวาดเอง)

**เอนทิตี (9):** `movies`, `cinema_halls`, `seats`, `showtimes`, `customers`, `promotions`, `bookings`, `tickets`, `payments`

**ความสัมพันธ์ที่อ่านได้จาก FOREIGN KEY** (ทีมต้องกำหนด cardinality / participation ตามความหมายธุรกิจเอง และตรวจกับ constraint ว่าตรงกันหรือไม่)

| ความสัมพันธ์ | จาก FK | ข้อสังเกตที่ต้องตัดสินใจ |
|---|---|---|
| cinema_halls — seats | `seats.hall_id` | ⚠️ seats เป็น weak entity ที่มี identifying relationship หรือไม่? (PK จริงคือ `seat_id` แต่มี `uq_seats_position (hall_id, row_label, seat_number)`) |
| movies — showtimes — cinema_halls | `showtimes.movie_id`, `showtimes.hall_id` | ⚠️ ควรวาด showtimes เป็นเอนทิตี หรือเป็นความสัมพันธ์ M:N ระหว่าง movies กับ cinema_halls ที่มี attribute |
| customers — bookings | `bookings.customer_id` | 1:N |
| showtimes — bookings | `bookings.showtime_id` | 1:N |
| promotions — bookings | `bookings.promotion_id` (NULL ได้, `ON DELETE SET NULL`) | ⚠️ participation ฝั่ง bookings เป็น partial |
| bookings — seats ผ่าน tickets | `tickets.booking_id`, `tickets.seat_id` | ⚠️ tickets เป็นเอนทิตีหรือเป็นความสัมพันธ์ M:N ที่แปลงแล้ว (มี attribute `ticket_price`, `ticket_status`) |
| bookings — payments | `payments.booking_id` + `uq_payments_booking` | 1:1 (ฝั่ง payments เป็น partial) ⚠️ ทำไมแยกเป็นตารางต่างหากแทนที่จะรวมกับ bookings |

**สิ่งที่ต้องทำเอง:** วาด EER (ระบุ PK/FK, cardinality, participation, weak entity ถ้ามี), อธิบายเหตุผลการเลือกตัวแทนความสัมพันธ์, แปลง EER เป็น Relational Schema และตรวจว่าตรงกับ `database/schema.sql`

## 2.2 Functional Dependencies ที่พบจากสคีมา

(ใช้สัญลักษณ์ A → B; ตรวจแต่ละข้อว่าตรงกับความหมายธุรกิจ)

**movies:** `movie_id → title, description, duration, genre, release_date, status, poster_url`
**cinema_halls:** `hall_id → hall_name, capacity, status`; `hall_name → hall_id` (UNIQUE `uq_cinema_halls_name`)
**seats:** `seat_id → hall_id, row_label, seat_number, seat_type`; `(hall_id, row_label, seat_number) → seat_id, seat_type` (UNIQUE `uq_seats_position`)
**showtimes:** `showtime_id → movie_id, hall_id, start_time, end_time, ticket_price, status` ⚠️ มี FD `(hall_id, start_time) → showtime_id` ในทางธุรกิจ (ห้ามทับซ้อน) แต่ไม่ได้ประกาศเป็น UNIQUE เพราะกฎจริงเป็นเรื่องช่วงเวลา (ใช้ trigger)
**customers:** `customer_id → name, email, phone, created_at, password_hash, user_role, last_login_at`; `email → customer_id` (UNIQUE `uq_customers_email`)
**promotions:** `promotion_id → promotion_code, discount_type, discount_value, start_date, end_date, status`; `promotion_code → promotion_id` (UNIQUE)
**bookings:** `booking_id → customer_id, showtime_id, promotion_id, booking_time, expires_at, booking_status, total_amount`
**tickets:** `ticket_id → booking_id, seat_id, ticket_price, ticket_status`; `(booking_id, seat_id) → ticket_id` (UNIQUE `uq_tickets_booking_seat`)
**payments:** `payment_id → booking_id, amount, payment_method, payment_status, paid_at`; `booking_id → payment_id` (UNIQUE `uq_payments_booking`)

## 2.3 จุดที่ต้องวิเคราะห์เรื่อง Normalization (ทีมต้องพิสูจน์เอง)

⚠️ ตรวจแต่ละจุดว่าละเมิด 1NF / 2NF / 3NF / BCNF หรือไม่ และถ้าตั้งใจให้มีความซ้ำซ้อน ให้เขียนเหตุผลเชิงออกแบบ

1. `tickets.ticket_price` มีค่าตรงกับ `showtimes.ticket_price` ตอนจอง — เป็น FD แบบข้ามตาราง หรือเป็นการเก็บค่า ณ เวลาที่จอง (ราคารอบอาจถูกแก้ภายหลัง)?
2. `bookings.total_amount` เป็นค่าที่คำนวณได้จาก `tickets` และ `promotions` — attribute แบบ derived; ทำไมจึงเก็บไว้?
3. `cinema_halls.capacity` ควรเท่ากับจำนวนแถวของ `seats` ในโรงนั้น (`sanity_checks.sql` ข้อ S23 ตรวจให้) — ซ้ำซ้อนหรือไม่?
4. `movies.genre` เก็บ 1 ค่าต่อเรื่อง — เกี่ยวข้องกับ 1NF/การออกแบบอย่างไร ถ้าหนังหนึ่งเรื่องมีหลายประเภท?
5. `payments.amount` กับ `bookings.total_amount` (S17) — ซ้ำซ้อนหรือจำเป็น?
6. `bookings.booking_status` กับ `tickets.ticket_status` / `payments.payment_status` มีความสัมพันธ์เชิงสถานะ (S18, S19) — เป็น FD หรือกฎธุรกิจ?
7. ตาราง `showtimes`: มี candidate key อื่นนอกจาก `showtime_id` หรือไม่ และสถานะ BCNF เป็นอย่างไร?

**สิ่งที่ต้องทำเอง:** เลือกตารางอย่างน้อยบางตารางมาแสดงขั้นตอนตรวจ 1NF→3NF/BCNF พร้อมหา candidate keys ด้วยการคำนวณ closure ของตนเอง
