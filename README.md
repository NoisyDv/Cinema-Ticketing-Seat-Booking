# Cinema Ticketing & Seat Booking

โครงงานวิชาระบบฐานข้อมูล หัวข้อที่ 7: ระบบจองตั๋วภาพยนตร์และผังที่นั่ง
เว็บ ASP.NET WebForms (.NET Framework 4.7.2) + SQL Server + โปสเตอร์ 30 เรื่อง

## เริ่มใช้งานตามลำดับ (5 นาที)

1. ใน SSMS เปิดและรันสคริปต์ตามลำดับ: `Database/schema.sql` → `Database/data.sql` → `Database/logic.sql`
   (สคริปต์ `schema.sql` จะสร้างฐานข้อมูล `CinemaDB` ให้โดยอัตโนมัติ ส่วน `queries.sql` ไม่ต้องรัน เป็นโจทย์ตัวอย่าง 10 ข้อ ดูรายละเอียดใน `Database/README.md`)
2. ตรวจสอบ connection string `MoviesConnectionString` ใน `Cinema Ticketing & Seat Booking/Web.config`
   โดยค่าเริ่มต้นตั้งไว้เป็น `Data Source=.\SQLEXPRESS;Initial Catalog=CinemaDB;...` หากชื่อ SQL Server ของคุณต่างออกไป ให้ปรับให้ตรงกับเครื่องตัวเอง
   *(หมายเหตุ: อย่าลืมตรวจสอบว่า SQL Server Service บนเครื่องทำงานอยู่)*
3. เปิด `Cinema Ticketing & Seat Booking.slnx` ด้วย Visual Studio แล้วกด F5 (IIS Express)
   (ระบบตั้ง Default Document ไว้ที่ `Pages/Movies.aspx` เรียบร้อยแล้ว)
4. หน้าแรกมีแบนเนอร์บอกสถานะ DB: เขียว = ต่อสำเร็จ, ส้ม = ใช้ข้อมูลสำรองในโค้ด

## ลองเดโมตามโฟลว์นี้

1. `Movies` — ดูโปสเตอร์ ค้นหา/กรองแนว กดเข้าเรื่องที่สนใจ
2. `MovieDetails` — ดูรอบฉาย + ที่นั่งว่าง กดจอง
3. `Booking` — ติ๊กที่นั่ง (สูงสุด 10 ที่) กรอกชื่อ/อีเมล/เบอร์ (+โค้ดส่วนลดถ้ามี) กดยืนยัน
   (อีเมลใหม่จะสมัครลูกค้าให้อัตโนมัติ)
4. `History` — ใส่อีเมลเดิมดูตั๋ว + ทดลองกดยกเลิก (ปุ่มยกเลิกจะแสดงเฉพาะรอบที่ยังไม่เริ่มฉาย และคืนเงินตามยอดที่จ่ายจริง)
5. `Dashboard` — ดูรายได้และอัตราเต็มโรงรายหนัง (ดึงจาก Reporting View `vw_BoxOfficeOccupancyReport`)
6. โซนแอดมิน — เปิด `Pages/AdminLogin.aspx` ใส่รหัสจาก `Web.config`
   (`AdminPasscode`) แล้วจัดการรอบฉาย/โปรโมชัน/หนังได้ (มี Session Guard ป้องกันการเข้าถึงโดยไม่ผ่านด่านรหัส)

## โครงสร้างไฟล์ (อ่านตรงนี้ที่เดียวจบ)

```text
/                                          (repo root)
├── README.md                             ไฟล์นี้ (ภาพรวม + วิธีรัน)
├── Requirement.txt                       โจทย์วิชา (ไม่เข้า git, อยู่ใน .gitignore แล้ว)
├── Cinema Ticketing & Seat Booking.slnx  solution เปิดด้วย Visual Studio
├── Database/                             สคริปต์ SQL ทั้งหมด (รันตามลำดับข้อ 1)
│   ├── schema.sql                        สร้างฐานข้อมูล CinemaDB + 9 ตาราง (NVARCHAR) + constraints + FK + indexes
│   ├── data.sql                          mock data (หนังจริง 30 เรื่อง + โปสเตอร์) — ดูแลด้วยมือ ห้ามปั่นทับ
│   ├── logic.sql                         sp_BookMovieSeats + sp_CancelBooking + trigger + view
│   ├── queries.sql                       query ซับซ้อน 10 ข้อ (JOIN/HAVING/Subquery/Window) คั่นด้วย GO แต่ละข้อ
│   └── README.md                         วิธีรัน SQL + ผูกกับเว็บ + ค่า poster_url
├── packages/                             NuGet cache (ignore, restore อัตโนมัติ)
└── Cinema Ticketing & Seat Booking/      เว็บแอป (IIS root)
    ├── Pages/                            ทุกหน้าเว็บ (standalone ไม่พึ่ง Master Page)
    │   ├── Movies.aspx                   แกลเลอรีโปสเตอร์ = หน้าแรก
    │   ├── MovieDetails.aspx             รายละเอียดหนัง + ตารางรอบฉาย (มี offline fallback)
    │   ├── Booking.aspx                  ผังที่นั่ง + ฟอร์มจอง (จำกัดเลือกไม่เกิน 10 ที่)
    │   ├── History.aspx                  ประวัติ + ยกเลิกการจอง
    │   ├── Dashboard.aspx                รายงาน Box Office
    │   ├── AdminLogin.aspx               ด่านรหัสแอดมิน
    │   ├── AdminShowtimes.aspx           เพิ่ม/ยกเลิกรอบฉาย (มี guard ตรวจสิทธิ์แอดมิน)
    │   ├── AdminPromos.aspx              เพิ่ม/เปิด-ปิดโปรโมชัน (มี guard ตรวจสิทธิ์แอดมิน)
    │   └── AdminMovies.aspx              เปิด-ปิด/เพิ่มหนัง + แนบไฟล์โปสเตอร์ (มี guard ตรวจสิทธิ์แอดมิน)
    ├── Data/                             ชั้นติดต่อ DB (ทุก query อยู่ที่นี่ ที่เดียว)
    │   ├── Db.cs                         อ่าน connection string + เปิด connection
    │   ├── MovieRepository.cs            query หนัง/รอบ/จอง/ประวัติ/รายงาน/แอดมินทั้งหมด
    │   ├── PosterHelper.cs               แปลง poster_url เป็น URL รูป (กลาง ใช้ทุกหน้า)
    │   ├── Validation.cs                 ตรวจอีเมล + แปลงวันเวลาจากฟอร์ม (กลาง)
    │   └── AdminAuth.cs                  ด่านรหัสแอดมิน (session flag + request termination guard)
    ├── Models/                           คลาสตรงกับผล query (Movie, Showtime, SeatRow,
    │                                     BookingInfo, BoxOfficeRow, Promotion,
    │                                     AdminShowtime, HallOption)
    ├── Scripts/
    │   ├── theme.js                      สลับธีมสว่าง/มืด จำค่าผ่าน localStorage (กลาง)
    │   └── booking.js                    จำกัดเลือกไม่เกิน 10 ที่ + ประมาณราคาระหว่างติ๊กที่นั่ง
    ├── Content/
    │   └── movies.css                    สไตล์ทั้งหมดของเว็บ (light/dark ผ่าน CSS variables)
    ├── Posters/                          ไฟล์รูปที่เว็บเสิร์ฟจริง (~/Posters/...)
    ├── App_Start/RouteConfig.cs          เปิด Friendly URLs (ลิงก์แบบไม่มี .aspx)
    ├── Global.asax(.cs)                  เรียก RouteConfig ตอนแอปสตาร์ท
    ├── Web.config                        connection string (CinemaDB) + AdminPasscode + Default Document + MIME .webp + บังคับ UTF-8
    └── packages.config                   รายการ NuGet ที่ใช้จริง (เหลือแค่ FriendlyUrls/Compiler/Infra)
```

## หน้าเว็บใช้ DB ส่วนไหนบ้าง

| หน้า | อ่าน | เขียน |
|---|---|---|
| Movies / MovieDetails | `movies`, `showtimes`, `cinema_halls`, `seats`, `bookings`, `tickets` | — |
| Booking | `seats`, `showtimes`, `promotions`, `customers` | `customers` (สมัครอัตโนมัติ), `bookings`/`tickets`/`payments` ผ่าน `sp_BookMovieSeats` |
| History | `bookings`, `tickets`, `seats`, `payments`, `movies`, `showtimes` | ยกเลิกผ่าน `sp_CancelBooking` |
| Dashboard | `vw_BoxOfficeOccupancyReport` | — |
| Admin (4 หน้า) | `movies`, `showtimes`, `promotions`, `cinema_halls` | เพิ่ม/ยกเลิกรอบ, เพิ่ม/เปิด-ปิดโปร, เปิด-ปิด/เพิ่มหนัง (SQL ตรง ไม่มี proc) |

## อ็อบเจกต์ DB หลัก (อยู่ `Database/logic.sql` หมด)

* `sp_BookMovieSeats` — จอง+จ่ายในครั้งเดียว (กันที่นั่งซ้ำด้วย lock, คิดราคา premium/โปรโมชัน, ผิดพลาด rollback)
* `sp_CancelBooking` — ยกเลิกเฉพาะของตัวเอง คืนสถานะ booking/ticket + คืนเงิน payment (ยกเลิกได้เฉพาะรอบที่ยังไม่เริ่มฉาย)
* `trg_ReleaseExpiredSeatLocks` — ปล่อยที่นั่ง hold ที่หมดเวลา + ยกเลิกตั๋ว/จ่ายที่ค้างอัตโนมัติ
* `vw_BoxOfficeOccupancyReport` — รายได้ + อัตราเต็มโรงรายหนัง (นับเฉพาะรอบที่ฉายจริง)

## ข้อตกลงที่ต้องรู้ก่อนแตะโค้ด

* **ไฟล์ `.aspx`/`.cs` และ `.sql` ที่มีภาษาไทยทุกไฟล์มี UTF-8 with BOM กำกับไว้แล้ว** เพื่อป้องกันตัวอักษรเพี้ยนตอนรันบน IIS หรือตอนเปิดสคริปต์ใน SSMS
* **สคริปต์ SQL ทั้ง 4 ไฟล์ผูกกับ `CinemaDB` อัตโนมัติ** (มี `CREATE DATABASE CinemaDB` ใน `schema.sql` และมี `USE CinemaDB; GO` กำกับบนสุดของทุกไฟล์)
* **`data.sql` ดูแลด้วยมือ** ห้ามรันสคริปต์ปั่นทับ (สคริปต์ต้นฉบับลบออกจาก repo แล้ว เหตุผลอยู่ใน `Database/README.md`)
* **มีแค่ 4 ไฟล์ SQL** (`schema/data/logic/queries`) — logic ฝั่งจองอยู่ใน proc, logic ฝั่งแอดมินอยู่ใน C# ตามนี้ ไม่ต้องเพิ่มไฟล์ SQL
* รหัสแอดมินอยู่ใน `Web.config` (`AdminPasscode`) เป็นด่านกันคนซน พร้อม Response Guard ป้องกันการยิงคำสั่งเข้ามาโดยไม่มีสิทธิ์
