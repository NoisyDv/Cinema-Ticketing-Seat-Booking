# Database — ไฟล์ SQL ของระบบจองตั๋วหนัง

รันตามลำดับนี้ใน SQL Server Management Studio (SSMS):

| ลำดับ | ไฟล์ | หน้าที่ |
|---|---|---|
| 1 | `schema.sql` | สร้างตาราง 9 ตาราง (`movies`, `cinema_halls`, `seats`, `showtimes`, `customers`, `promotions`, `bookings`, `tickets`, `payments`) + index |
| 2 | `data.sql` | ใส่ mock data (หนัง 30 เรื่อง, โรง 20 โรง, ที่นั่ง, โปรโมชัน, ลูกค้า, รอบฉาย, การจอง) |
| 3 | `logic.sql` | สร้าง `sp_BookMovieSeats` (จอง/ล็อก/จ่าย), trigger `trg_ReleaseExpiredSeatLocks`, view `vw_BoxOfficeOccupancyReport` |
| 4 | `queries.sql` | query ตัวอย่าง 10 ข้อ (ไม่ต้องรันทั้งหมด — เปิดดูเป็นข้อ ๆ ได้) |

## การเชื่อมกับเว็บไซต์

- เว็บ (`Cinema Ticketing & Seat Booking/`) ต่อ DB ผ่าน connection string
  `MoviesConnectionString` ใน `Web.config`
- หน้า `Pages/Movies.aspx` ใช้คำสั่งเดียวกับแนวคิดใน `queries.sql`:
  `SELECT ... FROM movies WHERE status='active' ... ORDER BY title`
- ถ้าต่อ DB ไม่ได้ เว็บจะ fallback เป็นข้อมูล 30 เรื่องที่ถอดมาจาก `data.sql`
  (ดู `Data/MovieRepository.cs` รายการ `Seed`) เพื่อให้โปสเตอร์ยังแสดงได้

## ค่า poster_url

- ใน `data.sql` เก็บแบบ relative path เช่น `Posters/Avatar.webp`
- ไฟล์จริงอยู่-tuning: `Cinema Ticketing & Seat Booking/Posters/` (เว็บเสิร์ฟที่ `~/Posters/...`)
- ชื่อไฟล์มีเคสพิเศษ 2 แบบที่โค้ดรองรับแล้ว:
  - ช่องว่าง: `Posters/Everything Everywhere_All_at_Once.webp` (encode เป็น `%20`)
  - อัญประกาศเดี่ยว: `Posters/Harry_Potter_and_the_Philosopher's_Stone.webp`
  - นามสกุล `.jpg` หนึ่งไฟล์: `Posters/Star_Wars.jpg`

## สร้าง data.sql ใหม่

```bash
python Database/generate_mock_data.py
```

จะได้ `data.sql` ใหม่ (ค่า default เขียนทับไฟล์ชื่อ `data.sql` ที่ working dir — ย้ายมาแทนไฟล์ใน `Database/` เอง)
