# Cinema Ticketing & Seat Booking

โครงงานวิชาระบบฐานข้อมูล หัวข้อที่ 7: ระบบจองตั๋วภาพยนตร์และผังที่นั่ง
เว็บ ASP.NET WebForms (.NET Framework 4.7.2) + SQL Server (ฐานข้อมูล `CinemaDB`) + โปสเตอร์หนัง 30 เรื่อง

## ต้องมีอะไรก่อนเริ่ม

- SQL Server เวอร์ชัน 2016 ขึ้นไป (Express ได้) — service ต้องทำงานอยู่ (สคริปต์ใช้ `STRING_SPLIT`)
- SQL Server Management Studio (SSMS)
- Visual Studio ที่เปิดไฟล์ `.slnx` ได้ (พร้อม IIS Express)

## เริ่มใช้งานใน 5 นาที

1. **สร้างฐานข้อมูล** — เปิด SSMS แล้วรันสคริปต์ตามลำดับนี้
   `Database/schema.sql` → `Database/data.sql` → `Database/logic.sql`
   - `schema.sql` สร้างฐานข้อมูล `CinemaDB` ให้เองอัตโนมัติ
   - `Database/queries.sql` ไม่ต้องรัน เป็นโจทย์ตัวอย่าง 10 ข้อ (ดูรายละเอียดใน `Database/README.md`)

2. **ตรวจ connection string** — `MoviesConnectionString` ใน `Cinema Ticketing & Seat Booking/Web.config`
   ค่าเริ่มต้นคือ `Data Source=.\SQLEXPRESS;Initial Catalog=CinemaDB;...`
   ถ้า SQL Server ของเครื่องคุณใช้ instance ชื่ออื่น ให้แก้ค่านี้ให้ตรง

3. **รันเว็บ** — เปิด `Cinema Ticketing & Seat Booking.slnx` ด้วย Visual Studio แล้วกด `F5` (IIS Express)
   Default document ตั้งไว้ที่ `Pages/Movies.aspx` เรียบร้อยแล้ว

4. **เช็คสถานะ DB จากแบนเนอร์หน้าแรก**
   เขียว = ต่อ DB สำเร็จ · ส้ม = ต่อไม่ได้ ระบบจะใช้ข้อมูลสำรอง 30 เรื่องในโค้ดแทน (เดโมต่อได้)

## เดโมตามโฟลว์นี้

| # | หน้า | สิ่งที่จะเห็น |
|---|---|---|
| 1 | `Movies` | แกลเลอรีโปสเตอร์ ค้นหา/กรองแนว → กดเข้าเรื่องที่สนใจ |
| 2 | `MovieDetails` | รอบฉาย + จำนวนที่นั่งว่าง → กดจอง |
| 3 | `Booking` | ผังที่นั่ง (เลือกได้สูงสุด 10 ที่) + ฟอร์มชื่อ/อีเมล/เบอร์ + โค้ดส่วนลด (ถ้ามี) → ยืนยันการจอง (อีเมลใหม่จะสมัครลูกค้าให้อัตโนมัติ) |
| 4 | `History` | ใส่อีเมลเดิม → ดูตั๋วที่จองไว้ → ทดลองกดยกเลิก (ปุ่มจะแสดงเฉพาะรอบที่ยังไม่เริ่มฉาย และคืนเงินตามยอดที่จ่ายจริง) |
| 5 | `Dashboard` | รายได้ + อัตราเต็มโรงรายหนัง จาก Reporting View `vw_BoxOfficeOccupancyReport` |
| 6 | โซนแอดมิน | เปิด `Pages/AdminLogin.aspx` ใส่รหัสจาก `Web.config` (`AdminPasscode`) → จัดการหนัง/รอบฉาย/โปรโมชัน |

หน้าแอดมินทุกหน้าอยู่หลัง Session Guard — เปิด URL ตรง ๆ โดยไม่ผ่านด่านรหัสจะเข้าไม่ได้

## โครงสร้างโปรเจกต์

```text
/  (repo root)
├── README.md                              ไฟล์นี้ (ภาพรวม + วิธีรัน)
├── Requirement.txt                        โจทย์วิชา (อยู่ใน .gitignore)
├── Cinema Ticketing & Seat Booking.slnx   solution สำหรับเปิดด้วย Visual Studio
│
├── Database/                              สคริปต์ SQL ทั้งหมด (รันตามลำดับใน Quick Start)
│   ├── schema.sql      สร้าง CinemaDB + 9 ตาราง + constraints + FK + indexes
│   ├── data.sql        mock data 9 ตาราง (หนังจริง 30 เรื่อง + โปสเตอร์) — แก้ด้วยมือ
│   ├── logic.sql       stored procedures 2 ตัว + trigger 1 ตัว + reporting view 1 ตัว
│   ├── queries.sql     query ซับซ้อน 10 ข้อ (JOIN / HAVING / subquery / window)
│   └── README.md       วิธีรัน SQL + การเชื่อมกับเว็บ + ค่า poster_url
│
├── packages/                              NuGet cache (ignore, restore อัตโนมัติ)
│
└── Cinema Ticketing & Seat Booking/       เว็บแอป (IIS root)
    ├── Pages/            หน้าเว็บทั้งหมด (standalone ไม่พึ่ง Master Page)
    │   ├── Movies.aspx           แกลเลอรีโปสเตอร์ = หน้าแรก
    │   ├── MovieDetails.aspx     รายละเอียดหนัง + รอบฉาย (มี offline fallback)
    │   ├── Booking.aspx          ผังที่นั่ง + ฟอร์มจอง (จำกัดไม่เกิน 10 ที่)
    │   ├── History.aspx          ประวัติการจอง + ยกเลิก
    │   ├── Dashboard.aspx        รายงาน Box Office
    │   ├── AdminLogin.aspx       ด่านรหัสแอดมิน
    │   ├── AdminShowtimes.aspx   เพิ่ม/ยกเลิกรอบฉาย (มี guard แอดมิน)
    │   ├── AdminPromos.aspx      เพิ่ม/เปิด-ปิดโปรโมชัน (มี guard แอดมิน)
    │   └── AdminMovies.aspx      เปิด-ปิด/เพิ่มหนัง + อัปโหลดโปสเตอร์ (มี guard แอดมิน)
    ├── Data/             ชั้นติดต่อ DB — query ทั้งหมดอยู่ที่นี่ที่เดียว
    │   ├── Db.cs                 อ่าน connection string + เปิด connection
    │   ├── MovieRepository.cs    query ทุกตัวของระบบ (หนัง/รอบ/จอง/ประวัติ/รายงาน/แอดมิน)
    │   ├── PosterHelper.cs       แปลง poster_url เป็น URL รูปจริง (ใช้ร่วมทุกหน้า)
    │   ├── Validation.cs         ตรวจอีเมล + แปลงวันเวลาจากฟอร์ม (ใช้ร่วมทุกหน้า)
    │   └── AdminAuth.cs          ด่านรหัสแอดมิน (Session + Guard ยุติ request ที่ไม่ได้รับสิทธิ์)
    ├── Models/           คลาสรับผลลัพธ์จาก query (Movie, Showtime, SeatRow, BookingInfo, ...)
    ├── Scripts/          theme.js (สลับธีมสว่าง/มืด) · booking.js (จำกัด 10 ที่ + ประมาณราคา)
    ├── Content/          movies.css (สไตล์ทั้งหมด มี light/dark ผ่าน CSS variables)
    ├── Posters/          ไฟล์รูปที่เว็บเสิร์ฟจริง (~/Posters/...)
    ├── App_Start/        RouteConfig — เปิด Friendly URLs (ลิงก์แบบไม่มี .aspx)
    ├── Global.asax(.cs)  เรียก RouteConfig ตอนแอปสตาร์ท
    ├── Web.config        connection string (CinemaDB) + AdminPasscode + Default Document + MIME .webp + บังคับ UTF-8
    └── packages.config   รายการ NuGet ที่ใช้จริง (FriendlyUrls / Compiler / Infra)
```

## แต่ละหน้าใช้ตารางไหน

| หน้า | อ่าน | เขียน |
|---|---|---|
| Movies / MovieDetails | `movies`, `showtimes`, `cinema_halls`, `seats`, `bookings`, `tickets` | — |
| Booking | `seats`, `showtimes`, `promotions`, `customers` | `customers` (สมัครอัตโนมัติ) + `bookings`/`tickets`/`payments` ผ่าน `sp_BookMovieSeats` |
| History | `bookings`, `tickets`, `seats`, `payments`, `movies`, `showtimes` | ยกเลิกผ่าน `sp_CancelBooking` |
| Dashboard | `vw_BoxOfficeOccupancyReport` | — |
| Admin (4 หน้า) | `movies`, `showtimes`, `promotions`, `cinema_halls` | เพิ่ม/ยกเลิกรอบ, เพิ่ม/เปิด-ปิดโปรโมชัน, เปิด-ปิด/เพิ่มหนัง (ใช้ SQL ตรง ไม่ผ่าน stored procedure) |

## อ็อบเจกต์ DB หลัก (อยู่ใน `Database/logic.sql` ทั้งหมด)

- `sp_BookMovieSeats` — จอง + ชำระเงินในครั้งเดียว (ล็อกกันที่นั่งซ้ำ คิดราคา premium/โปรโมชัน และ rollback ครบถ้วนเมื่อ error)
- `sp_CancelBooking` — ยกเลิกได้เฉพาะการจองของตัวเอง และเฉพาะรอบที่ยังไม่เริ่มฉาย (คืนสถานะ booking/ticket + คืนเงิน)
- `trg_ReleaseExpiredSeatLocks` — ปล่อยที่นั่งที่ล็อกรอจ่ายจนหมดเวลา พร้อมยกเลิกตั๋ว/การชำระเงินที่ค้างให้อัตโนมัติ
- `vw_BoxOfficeOccupancyReport` — รายได้ + อัตราเต็มโรงรายหนัง (นับรอบ `scheduled` และ `completed` ไม่นับรอบที่ยกเลิก)

## ข้อมูลตัวอย่าง (`Database/data.sql`)

หนัง 30 · โรง 20 · ที่นั่ง 1,449 · โปรโมชัน 25 · ลูกค้า 600 · รอบฉาย 700 · การจอง 800 · ตั๋ว 1,808 · การชำระเงิน 689 แถว

## ข้อตกลงที่ต้องรู้ก่อนแก้โค้ด

- ไฟล์ `.aspx`, `.cs` และ `.sql` ที่มีข้อความไทยถูกบันทึกเป็น **UTF-8 with BOM** ทั้งหมด (กันตัวอักษรเพี้ยนบน IIS และใน SSMS) — ถ้าเพิ่มไฟล์ใหม่ที่มีภาษาไทย ต้องทำแบบเดียวกัน
- SQL ทั้ง 4 ไฟล์ผูกกับ `CinemaDB` ให้อัตโนมัติ (`schema.sql` มี `CREATE DATABASE CinemaDB` และทุกไฟล์มี `USE CinemaDB; GO` ด้านบน)
- `data.sql` เป็นข้อมูลที่แต่งด้วยมือ — **ห้ามรันสคริปต์ปั่นข้อมูลทับ** (สคริปต์ต้นฉบับลบออกจาก repo แล้ว เหตุผลอยู่ใน `Database/README.md`)
- มีแค่ 4 ไฟล์ SQL: ตรรกะการจองอยู่ใน stored procedure ส่วนตรรกะฝั่งแอดมินอยู่ใน C#
- รหัสแอดมินเก็บใน `Web.config` (`AdminPasscode`) เป็นด่านกันคนซน มี Response Guard กันการยิงคำสั่งเข้ามาโดยไม่มีสิทธิ์

## แก้ปัญหาที่เจอบ่อย

| อาการ | จุดตรวจ |
|---|---|
| แบนเนอร์หน้าแรกเป็นสีส้ม (ต่อ DB ไม่ได้) | SQL Server service ทำงานอยู่ไหม และ `MoviesConnectionString` ชี้ instance ถูกไหม |
| ข้อความไทยกลายเป็นตัวอักษรเพี้ยน | ไฟล์ต้องบันทึกเป็น UTF-8 with BOM (ไฟล์เดิมมีครบแล้ว ถ้าเพิ่มใหม่ต้องเช็ค) |
| รูปโปสเตอร์ไม่ขึ้น | ไฟล์ต้องอยู่ใน `Cinema Ticketing & Seat Booking/Posters/` และชื่อใน DB ต้องตรงกับชื่อไฟล์ (ถ้าหาไฟล์ไม่เจอ ระบบจะโชว์ไอคอนเว็บแทนให้อัตโนมัติ) |
