# Cinema Ticketing & Seat Booking

เว็บจองตั๋วหนังอย่างง่าย (ASP.NET WebForms, .NET Framework 4.7.2) +
ฐานข้อมูล SQL Server + โปสเตอร์ 30 เรื่อง

## โครงสร้างโฟลเดอร์

```text
/                                          (repo root)
├── Database/                              สคริปต์ SQL ทั้งหมด
│   ├── schema.sql                         สร้างตาราง + index (รันก่อน)
│   ├── data.sql                           mock data incl. poster_url (รันที่ 2)
│   ├── logic.sql                          procedure/trigger/view (รันที่ 3)
│   ├── queries.sql                        query ตัวอย่าง 10 ข้อ (อ้างอิง)
│   ├── generate_mock_data.py              สคริปต์ปั่น data.sql
│   └── README.md                          วิธีรัน SQL + ผูกกับเว็บ
│
├── Posters/  → ย้ายแล้ว ไม่อยู่ที่ root อีกต่อไป
│   ที่ตั้งจริง: `Cinema Ticketing & Seat Booking/Posters/` (เว็บเสิร์ฟที่ `~/Posters/...`)
│
└── Cinema Ticketing & Seat Booking/       เว็บแอป (IIS root)
    ├── Pages/
    │   ├── Movies.aspx (+.cs)            หน้าแกลเลอรีโปสเตอร์ (หน้าหลักของงานนี้)
    │   ├── MovieDetails.aspx (+.cs)      รายละเอียดหนัง + รอบฉาย
    │   ├── Booking.aspx (+.cs)           ผังที่นั่ง + ฟอร์มจอง (เรียก sp_BookMovieSeats)
    │   ├── History.aspx (+.cs)           ประวัติการจอง ค้นหาด้วยอีเมล
    │   └── Dashboard.aspx (+.cs)         รายงาน Box Office รายหนัง
    ├── Models/                           คลาสตรงกับตาราง (Movie, Showtime, SeatRow, BookingInfo, BoxOfficeRow)
    ├── Data/
    │   ├── Db.cs                         อ่าน MoviesConnectionString + เปิด connection
    │   ├── MovieRepository.cs            ดึงข้อมูลจาก DB, fallback เป็น seed จาก data.sql
    │   ├── PosterHelper.cs               แปลง poster_url เป็น URL รูป
    │   └── Validation.cs                 ตรวจรูปแบบอีเมล
    ├── Scripts/
    │   ├── theme.js                      สลับธีมสว่าง/มืด (จำค่าผ่าน localStorage)
    │   └── booking.js                    ประมาณราคาระหว่างเลือกที่นั่ง
    ├── Content/
    │   └── movies.css                    สไตล์ทั้งหมดของเว็บ
    ├── Posters/                          โปสเตอร์ที่เว็บเสิร์ฟจริง (~/Posters/...)
    ├── App_Start/RouteConfig.cs          เปิด Friendly URLs (ลิงก์แบบไม่มี .aspx)
    └── Web.config                        มี MoviesConnectionString → แก้ให้ตรงเครื่อง
```

## วิธีรันเว็บ (5 นาที)

1. เปิด `Cinema Ticketing & Seat Booking.slnx` ด้วย Visual Studio
2. ใน SSMS รัน `Database/schema.sql` → `Database/data.sql` → `Database/logic.sql`
   (ดูรายละเอียดใน `Database/README.md`)
3. แก้ `Cinema Ticketing & Seat Booking/Web.config` ให้ `MoviesConnectionString`
   ชี้ SQL Server ของคุณ เช่น:
   `Data Source=.\SQLEXPRESS;Initial Catalog=CinemaDB;Integrated Security=True;TrustServerCertificate=True`
4. ตั้ง Start Page เป็น `Pages/Movies.aspx` แล้วกด F5 (IIS Express)
   - ต่อ DB ได้: แบนเนอร์เขียว "เชื่อมต่อ SQL Server สำเร็จ"
   - ต่อไม่ได้: แบนเนอร์ส้ม "ใช้ข้อมูลสำรองจาก data.sql" — โปสเตอร์ยังขึ้นครบ 30 เรื่อง

## หน้าเว็บทำอะไรได้

- `Pages/Movies.aspx` — แสดงโปสเตอร์ทุกเรื่องที่ `status='active'`
  (รูปจาก `poster_url` → `Posters/`), ค้นหาชื่อ/ประเภท + กรองตาม genre
- `Pages/MovieDetails.aspx?movie_id=N` — รายละเอียดหนัง + รอบฉายอนาคต
  (`showtimes` + `cinema_halls` + ที่นั่งว่างจาก `bookings`/`tickets`)
- `Pages/Booking.aspx?showtime_id=N` — ผังที่นั่ง + ฟอร์มจอง เรียก
  `sp_BookMovieSeats` (ลูกค้าอ้างอิงด้วยอีเมล, สมัครอัตโนมัติถ้ายังไม่มี)
- `Pages/History.aspx` — ประวัติการจอง + ตั๋ว ค้นหาด้วยอีเมล (เรียงล่าสุดก่อน)
- `Pages/Dashboard.aspx` — รายงาน Box Office รายหนัง (`vw_BoxOfficeOccupancyReport` + จัดอันดับ)
