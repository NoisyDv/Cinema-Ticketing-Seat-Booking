# Cinema Ticketing & Seat Booking
ระบบจองตั๋วภาพยนตร์และผังที่นั่ง — หัวข้อที่ 7 วิชาระบบฐานข้อมูล 2569
ฐานข้อมูล **Microsoft SQL Server (T-SQL)** + เว็บ **ASP.NET Web Forms (.NET Framework 4.7.2)**

## 1. ภาพรวมระบบ
- **ลูกค้า:** สมัคร/เข้าสู่ระบบ → เลือกหนังและรอบฉาย → เลือกที่นั่งจากผังจริง (สูงสุด 3 ที่) → ถือที่นั่ง 15 นาที (นับถอยหลังตามเวลาเซิร์ฟเวอร์) → ชำระเงิน/ใส่โค้ดโปรโมชัน → รับตั๋ว → ดูประวัติ/ยกเลิกการถือที่นั่ง
- **ผู้ดูแลระบบ:** จัดการหนัง รอบฉาย โปรโมชัน (เพิ่ม/ดู/แก้ไข/ลบ) และดูรายงาน Box Office
- **ฐานข้อมูล:** 9 ตาราง, `sp_BookMovieSeats` (Transaction), `trg_ReleaseExpiredSeatLocks`, `vw_BoxOfficeOccupancyReport`, `trg_PreventShowtimeOverlap` (กันรอบฉายทับซ้อน), query 10 ข้อ, ชุดทดสอบ และ sanity checks

## 2. โครงสร้างโฟลเดอร์
```
README.md
Cinema Ticketing & Seat Booking.slnx
database/        schema.sql  data.sql  logic.sql  queries.sql  tests.sql  sanity_checks.sql  run_all.cmd
tools/           generate_data.py (สร้าง data.sql)  verify_data.py  hash_password.py  gen_designer.py  make_data_dictionary.py
docs/report/     chapter1_scope_business_rules.md  chapter2_outline_fds.md  chapter3_design.md  data_dictionary.md
docs/ux-prototype/Weblogin.html   (ต้นแบบหน้าล็อกอินเดิม เก็บไว้อ้างอิง ไม่ได้ใช้ในเว็บ)
Cinema Ticketing & Seat Booking/   โปรเจกต์เว็บ (Data/ Security/ Infrastructure/ Admin/ Content/ Scripts/)
```

## 3. ข้อกำหนดเบื้องต้น
- Windows + **Visual Studio 2019/2022** (workload *ASP.NET and web development*, .NET Framework 4.7.2 targeting pack) — โปรเจกต์ไม่ใช้ NuGet ไม่ต้อง restore
- **SQL Server** (2016 SP1 ขึ้นไป) อย่างใดอย่างหนึ่ง: LocalDB (มากับ Visual Studio), SQL Server Express หรือ Developer
- เครื่องมือ `sqlcmd` หรือ SQL Server Management Studio (SSMS)
- (ไม่บังคับ) Python 3.9+ สำหรับสร้างข้อมูลใหม่ใน `tools/`

## 4. ลำดับการรัน SQL
ลำดับบังคับ: **`schema.sql` → `data.sql` → `logic.sql` → `queries.sql`** (แล้วรัน `sanity_checks.sql` และ `tests.sql` เพื่อตรวจสอบ) ทุกไฟล์รันซ้ำได้ (idempotent) และ **ต้องรันบนฐานข้อมูลที่สร้างไว้แล้ว** (สคริปต์ไม่ได้สร้างฐานข้อมูลให้)

**วิธีที่ 1 — สคริปต์เดียว (Windows):**
```
cd database
run_all.cmd                              :: LocalDB  (สร้างฐาน CinemaTicketingDb ให้เอง)
run_all.cmd .\SQLEXPRESS                 :: SQL Server Express
run_all.cmd (localdb)\MSSQLLocalDB tests :: รันแล้วต่อด้วย sanity_checks.sql และ tests.sql
```
**วิธีที่ 2 — SSMS:** สร้างฐาน `CinemaTicketingDb` → เปิดแต่ละไฟล์ตามลำดับแล้ว Execute (ไฟล์เป็น UTF-8 มี BOM SSMS อ่านภาษาไทยได้ถูกต้อง)
**ถ้าใช้ sqlcmd เอง** ต้องใส่ `-f 65001` (UTF-8) และ `-I` (QUOTED_IDENTIFIER ON) เช่น `sqlcmd -S . -E -d CinemaTicketingDb -b -I -f 65001 -i schema.sql`

หมายเหตุ: `data.sql` จะ **ข้ามทั้งไฟล์** ถ้า `movies` หรือ `cinema_halls` มีข้อมูลอยู่แล้ว (ป้องกันข้อมูลซ้ำ) และวันที่ในข้อมูลเป็นค่าเทียบกับ "วันที่รันสคริปต์" (รอบฉาย −5..+10 วัน) จึงควรรันใกล้วันที่ใช้งาน/ตรวจงาน `migration.sql` เดิมถูกรวมเข้า `schema.sql`/`logic.sql` แล้ว **ไม่ต้องรัน**

## 5. ตั้งค่า connection string
แก้ใน `Cinema Ticketing & Seat Booking/Web.config` ชื่อ `CinemaDb` ค่าเริ่มต้นคือ LocalDB:
```
Data Source=(LocalDB)\MSSQLLocalDB;Initial Catalog=CinemaTicketingDb;Integrated Security=True;...
```
- SQL Server Express: `Data Source=.\SQLEXPRESS;Initial Catalog=CinemaTicketingDb;Integrated Security=True;`
- SQL Authentication: `Data Source=localhost;Initial Catalog=CinemaTicketingDb;User ID=...;Password=...;`

## 6. วิธีรันเว็บ
1. เปิด `Cinema Ticketing & Seat Booking.slnx` (หรือ `.csproj`) ด้วย Visual Studio  2. กด **F5** (IIS Express)  3. ถ้าเห็นหน้า "เกิดข้อผิดพลาด" ให้ตั้ง `<customErrors mode="Off" />` ใน Web.config ชั่วคราวเพื่อดูสาเหตุ

## 7. บัญชีทดสอบ (เก็บเฉพาะค่าแฮช PBKDF2 ในฐานข้อมูล)
| บทบาท | อีเมล | รหัสผ่าน |
|---|---|---|
| ผู้ดูแลระบบ (admin) | `admin@cinema.example` | `Admin@2569` |
| ลูกค้า (customer) | `demo@cinema.example` | `Demo@2569` |

ลูกค้าตัวอย่างอื่น ๆ (500 ราย) ไม่มีรหัสผ่าน ล็อกอินไม่ได้ ให้สมัครสมาชิกใหม่จากหน้า Register

## 8. การทดสอบ
- `database/sanity_checks.sql` — ตรวจจำนวนแถว รอบฉายไม่ทับซ้อน FK ไม่กำพร้า ที่นั่งไม่ซ้ำ ยอดเงินตรงกัน ฯลฯ (ทุกข้อควรเป็น PASS)
- `database/tests.sql` — กรณีผ่าน/ไม่ผ่านของ trigger กันรอบทับซ้อนและกฎของ SP/Trigger/View ใช้ข้อมูลปี 2099 และลบข้อมูลทดสอบทิ้งเองตอนจบ
- **ทดสอบการจองซ้ำพร้อมกันด้วยมือ (2 หน้าต่าง SSMS):** (ก) หน้าต่าง 1: `BEGIN TRAN; EXEC sp_ValidateBookingRequest ...` ที่นั่ง X ของรอบ R แล้ว *ยังไม่ COMMIT* (ข) หน้าต่าง 2: `EXEC sp_HoldSeats ...` ที่นั่ง X รอบ R จะต้อง **รอ** (ค) หน้าต่าง 1: เปลี่ยนเป็นจองจริงแล้ว COMMIT → หน้าต่าง 2 ต้องได้ error 50005

## 9. ปัญหาที่พบบ่อย
| อาการ | สาเหตุ / วิธีแก้ |
|---|---|
| ภาษาไทยในฐานข้อมูลเป็น `????` | รันด้วย sqlcmd โดยไม่ใส่ `-f 65001` หรือเปิดไฟล์ด้วย encoding ผิด ให้ใช้ `run_all.cmd` หรือ SSMS |
| `Cannot open database "CinemaTicketingDb"` | ยังไม่ได้สร้างฐานข้อมูล/รัน SQL หรือ connection string ไม่ตรง |
| LocalDB ต่อไม่ได้ | `sqllocaldb start MSSQLLocalDB` หรือเปลี่ยนเป็น SQL Express ใน Web.config |
| `INSERT failed because ... QUOTED_IDENTIFIER` | รัน sqlcmd โดยไม่ใส่ `-I` |
| `data.sql` แล้วไม่มีข้อมูลเพิ่ม | ข้ามเพราะมีข้อมูลอยู่แล้ว (ตั้งใจ) ลบข้อมูล/สร้างฐานใหม่ถ้าต้องการเริ่มใหม่ |
| หน้าเว็บไม่มีหนังให้เลือก | รอบฉายในข้อมูลตัวอย่างอยู่ในช่วง +1..+10 วันจากวันรัน data.sql ถ้าผ่านไปนานให้สร้างฐานใหม่ หรือเพิ่มรอบในหน้า Admin |
| ล็อกอินไม่ได้ | ใช้บัญชีในหัวข้อ 7; ผิดเกิน 5 ครั้งต้องรอ 60 วินาที |
| ชำระเงินแล้วขึ้น "หมดเวลาถือที่นั่ง" | ถือที่นั่งได้ 15 นาที หมดแล้วที่นั่งถูกปล่อยโดยตั้งใจ ให้เลือกที่นั่งใหม่ |
| สร้างข้อมูลจำลองใหม่ | `python tools/generate_data.py` แล้วตรวจด้วย `python tools/verify_data.py` |

## 10. ข้อจำกัดที่ทราบ
- ไม่มี job เปลี่ยนสถานะรอบฉายเป็น `completed` เมื่อฉายจบ (sanity ข้อ I02 อาจแจ้งเตือนเมื่อเวลาผ่านไป)
- ไม่มีเกตเวย์ชำระเงินจริง ไม่มีระบบคืนเงินผ่านหน้าเว็บ ลวดลาย QR บนตั๋วเป็นภาพตัวอย่าง
- Session เก็บใน memory (InProc) รีสตาร์ตแอปแล้วต้องล็อกอินใหม่
- ตัวสร้างรหัส session ไม่ได้สร้างใหม่ตอนล็อกอิน (ใช้ ViewStateUserKey, HttpOnly cookie และจำกัดการเดารหัสในระดับ session)
