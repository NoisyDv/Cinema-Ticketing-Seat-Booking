# บทที่ 1 (ร่าง): ขอบเขตระบบและ Business Rules

> ร่างจากโค้ดจริงในโปรเจกต์ ทุกกฎอ้างชื่อ constraint / stored procedure / trigger ที่มีอยู่จริง ทีมควรอ่านโค้ดตามที่อ้างอิง แล้วเรียบเรียงด้วยสำนวนของตนเอง

## 1.1 ภาพรวมและขอบเขตระบบ

ระบบจองตั๋วภาพยนตร์และผังที่นั่ง (Cinema Ticketing & Seat Booking) รองรับการทำงานของโรงภาพยนตร์ดังนี้

**อยู่ในขอบเขต**
- ลูกค้าสมัครสมาชิก เข้าสู่ระบบ ดูหนังที่เปิดจอง เลือกรอบฉาย เลือกที่นั่งจากผังที่นั่งจริง (สูงสุด 3 ที่ต่อการจอง) ถือที่นั่ง 15 นาที ชำระเงิน (ใส่โค้ดโปรโมชันได้) รับตั๋ว ดูประวัติการจอง และยกเลิกการถือที่นั่ง
- ผู้ดูแลระบบ (admin) จัดการภาพยนตร์ รอบฉาย โปรโมชัน (เพิ่ม/ดู/แก้ไข/ลบ) และดูรายงานรายได้และอัตราการครองที่นั่งต่อภาพยนตร์
- ฐานข้อมูลบังคับกฎสำคัญเองด้วย constraint, stored procedure, trigger และ view โดยไม่พึ่งการตรวจฝั่งเว็บอย่างเดียว

**อยู่นอกขอบเขต** (ระบบนี้ไม่ได้ทำ)
- เชื่อมต่อเกตเวย์ชำระเงินจริง (การชำระเงินเป็นการบันทึกผลในฐานข้อมูล)
- ระบบคืนเงิน/ยกเลิกการจองที่ชำระแล้วผ่านหน้าเว็บ (ในข้อมูลตัวอย่างมี payment_status = `refunded` เพื่อแสดงสถานะนี้เท่านั้น)
- ราคาตามประเภทที่นั่ง (premium มีสีต่างกันแต่ราคาเท่ากับรอบฉาย) การจองเป็นกลุ่มเกิน 3 ที่นั่ง ส่งตั๋วทางอีเมล/QR จริง
- การปรับสถานะรอบฉายเป็น `completed` อัตโนมัติเมื่อเวลาผ่านไป (ต้องแก้ด้วยมือหรือเพิ่ม job)

## 1.2 Business Rules

| # | กฎทางธุรกิจ | บังคับโดย (ในโค้ดจริง) |
|---|---|---|
| BR1 | รอบฉายในโรงเดียวกันต้องไม่ทับซ้อนเวลา (รอบ cancelled ไม่นับ) เงื่อนไขชนคือ `new_start < existing_end AND new_end > existing_start` รอบที่จบพอดีกับที่อีกรอบเริ่มไม่ถือว่าชน และเวลาจบต้องหลังเวลาเริ่ม | `trg_PreventShowtimeOverlap` (AFTER INSERT, UPDATE รองรับหลายแถว, ROLLBACK + THROW 50030), `chk_showtimes_time` |
| BR2 | ที่นั่งหนึ่งที่ในรอบฉายหนึ่งรอบ มีผู้จอง/ถือได้ครั้งละหนึ่งคน และต้องเป็นที่นั่งของโรงที่ฉายรอบนั้น | `sp_ValidateBookingRequest` (error 50004, 50005) ล็อกแถว `showtimes` ด้วย `UPDLOCK, HOLDLOCK` จึงจองซ้ำพร้อมกันไม่ได้, `vw_TakenSeats`, `uq_seats_position`, `uq_tickets_booking_seat` |
| BR3 | หนึ่งการจองเลือกที่นั่งได้ 1–3 ที่ และห้ามเลือกที่นั่งซ้ำกันเอง | `sp_ValidateBookingRequest` (error 50008, 50006), `sp_BookMovieSeats` / `sp_HoldSeats` มีพารามิเตอร์ที่นั่งสูงสุด 3 ตัว, ตรวจซ้ำที่ `Showtimes.aspx.cs` |
| BR4 | การถือที่นั่งมีอายุ 15 นาที ถ้าไม่ชำระเงินทันเวลา การจองเป็น `expired` ตั๋วเป็น `cancelled` และที่นั่งกลับมาว่าง | `bookings.expires_at`, `chk_bookings_expiry`, `trg_ReleaseExpiredSeatLocks`, `sp_ReleaseExpiredHolds`, `vw_TakenSeats` (ไม่นับ pending ที่หมดเวลา) |
| BR5 | โค้ดโปรโมชันใช้ได้เมื่อสถานะ active และวันนี้อยู่ในช่วง start_date–end_date ส่วนลดแบบเปอร์เซ็นต์ไม่เกิน 100 | `fn_GetValidPromotion`, `chk_promotions_date`, `chk_promotions_percentage`, `sp_ValidateBookingRequest` / `sp_ConfirmPayment` (error 50003) |
| BR6 | ยอดรวมของการจอง = ราคาตั๋วรวม − ส่วนลด และไม่ติดลบ ยอดที่ชำระต้องเท่ากับยอดของการจอง | `fn_CalculateBookingTotal` (จุดเดียวที่คำนวณ), `chk_bookings_amount`, `sp_ConfirmPayment`, ตรวจด้วย `sanity_checks.sql` ข้อ S16, S17 |
| BR7 | จองได้เฉพาะรอบที่เปิดจอง (`scheduled`) และยังไม่เริ่มฉาย | `sp_ValidateBookingRequest` (error 50001, 50007) |
| BR8 | การจองและชำระเงินต้องสำเร็จทั้งชุดหรือล้มทั้งชุด (Atomicity) | `BEGIN TRANSACTION ... COMMIT / ROLLBACK` ใน `sp_BookMovieSeats`, `sp_HoldSeats`, `sp_ConfirmPayment`, `sp_CancelHold` |
| BR9 | ชำระเงินได้เฉพาะเจ้าของการจอง เฉพาะการจองสถานะ pending ที่ยังไม่หมดเวลา และชำระได้ครั้งเดียว | `sp_ConfirmPayment` (error 50010, 50011, 50012), `uq_payments_booking` |
| BR10 | อีเมลลูกค้าห้ามซ้ำ รหัสผ่านเก็บเป็นแฮช PBKDF2 + salt เท่านั้น และผู้ใช้มีบทบาท customer หรือ admin | `uq_customers_email`, `chk_customers_user_role`, `sp_RegisterCustomer` (50020), `PasswordHasher.cs`, `BasePage.cs` (ตรวจสิทธิ์ admin) |
| BR11 | ห้ามย้ายโรงของรอบฉายที่มีการจองที่ยัง active อยู่ (ที่นั่งที่จองผูกกับโรงเดิม) | `Repo.UpdateShowtime` (ตรวจในชั้นเว็บ ไม่ใช่ constraint ฐานข้อมูล) |

> หมายเหตุสำหรับทีม: BR11 บังคับที่ชั้นแอปพลิเคชัน ไม่ใช่ที่ฐานข้อมูล ควรระบุให้ตรงตามจริงในรายงาน
