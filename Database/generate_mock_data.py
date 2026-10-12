"""
สร้าง Mock Data สำหรับระบบจองตั๋วภาพยนตร์ (SQL Server)

วิธีใช้
  1) รันสคริปต์นี้ -> ได้ไฟล์ mock_data.sql
  2) เปิดใน SSMS แล้วกด Execute (ต้องสร้างตารางด้วย schema ไว้ก่อน และตารางต้องยังว่าง)
  หรือใส่ CONN_STR ด้านล่างเพื่อให้สคริปต์ insert เข้า DB ตรง ๆ

ข้อควรระวัง
  - สคริปต์พึ่งพา IDENTITY เริ่มที่ 1 -> ใช้กับตารางที่ว่างและสร้างใหม่เท่านั้น
    (ถ้าเคยมีข้อมูลแล้วลบ ให้ DBCC CHECKIDENT('ชื่อตาราง', RESEED, 0) ก่อน)
  - คอลัมน์ใน schema เป็น VARCHAR (ไม่ใช่ NVARCHAR) ถ้าใช้ LOCALE = "th_TH"
    ฐานข้อมูลต้องใช้ collation ภาษาไทย (เช่น Thai_100_CI_AS) ไม่งั้นตัวอักษรไทยจะกลายเป็น ?
"""
import math
import random
from collections import defaultdict
from datetime import date, datetime, time, timedelta

from faker import Faker

# ----------------------------- ตั้งค่า -----------------------------
SEED = 42
LOCALE = "en_US"            # เปลี่ยนเป็น "th_TH" ได้ (ดูข้อควรระวังด้านบน)
OUTPUT = "data.sql"
CONN_STR = ""               # เช่น "DRIVER={ODBC Driver 17 for SQL Server};SERVER=localhost;DATABASE=CinemaDB;Trusted_Connection=yes;TrustServerCertificate=yes;"

N_MOVIES = 30
N_HALLS = 20
N_PROMOS = 25
N_CUSTOMERS = 600
N_SHOWTIMES = 700
N_BOOKINGS = 800

NOW = datetime(2026, 10, 8, 15, 0, 0)   # "เวลาปัจจุบัน" ของข้อมูลจำลอง (ตรึงไว้ให้ผลซ้ำได้)
HOLD_MINUTES = 15
PREMIUM_SURCHARGE = 50

random.seed(SEED)
Faker.seed(SEED)
fake = Faker(LOCALE)

# ----------------------------- helper -----------------------------
def lit(v):
    if v is None:
        return "NULL"
    if isinstance(v, datetime):          # ต้องเช็คก่อน date
        return "'" + v.strftime("%Y%m%d %H:%M:%S") + "'"
    if isinstance(v, date):
        return "'" + v.strftime("%Y%m%d") + "'"
    if isinstance(v, str):
        return "N'" + v.replace("'", "''") + "'"
    if isinstance(v, float):
        return f"{v:.2f}"
    return str(v)


STATEMENTS = []


def emit(table, cols, rows, chunk=500):
    for i in range(0, len(rows), chunk):
        part = rows[i:i + chunk]
        values = ",\n".join("(" + ", ".join(lit(x) for x in r) + ")" for r in part)
        STATEMENTS.append(f"INSERT INTO {table} ({', '.join(cols)}) VALUES\n{values};")


def rand_dt(lo, hi):
    return lo + timedelta(seconds=random.randint(0, int((hi - lo).total_seconds())))


# ----------------------------- movies -----------------------------
TITLES = [
    "Midnight Harbor", "The Last Lantern", "Echoes of Tomorrow", "Paper Moon Rising",
    "Neon Streets", "The Silent Orchard", "Crimson Tide Hotel", "Wandering Stars",
    "Glass Mountain", "The Clockmaker's Daughter", "Shadow of the Reef", "Summer Static",
    "Iron Valley", "Lost in Lisbon", "The Quiet Signal", "Golden Hour Heist",
    "Rain Over Bangkok", "Paper Kites", "Beyond the Salt Flats", "The Velvet Room",
    "Orbit of Strangers", "Harvest Moon Murders", "Thunder Road Home", "The Blue Door",
    "Fragments of Light", "Stray Dogs of Spring", "Under the Banyan Tree", "Night Train to Nowhere",
    "The Lighthouse Letters", "Velocity Zero",
]
GENRES = ["Action", "Comedy", "Drama", "Horror", "Sci-Fi", "Romance", "Thriller", "Animation", "Fantasy", "Documentary"]

movies = []
for i in range(N_MOVIES):
    movies.append({
        "id": i + 1,
        "title": TITLES[i % len(TITLES)],
        "desc": fake.paragraph(nb_sentences=3),
        "duration": random.randint(85, 175),
        "genre": random.choice(GENRES),
        "release": date(2026, 1, 1) + timedelta(days=random.randint(0, 240)),
        "status": "inactive" if i >= N_MOVIES - 3 else "active",
    })
emit("movies", ["title", "description", "duration", "genre", "release_date", "status"],
     [(m["title"], m["desc"], m["duration"], m["genre"], m["release"], m["status"]) for m in movies])
active_movies = [m for m in movies if m["status"] == "active"]

# ----------------------------- cinema_halls + seats -----------------------------
halls, seats_by_hall, seat_rows = [], {}, []
seat_id = 0
for h in range(1, N_HALLS + 1):
    n_rows, per_row = random.randint(6, 10), random.randint(8, 12)
    status = "inactive" if h > N_HALLS - 2 else "active"
    halls.append({"id": h, "name": f"Hall {h:02d}", "cap": n_rows * per_row, "status": status})
    seats_by_hall[h] = []
    for r in range(n_rows):
        label = chr(ord("A") + r)
        stype = "premium" if r >= n_rows - 2 else "standard"
        for n in range(1, per_row + 1):
            seat_id += 1
            seat_rows.append((h, label, n, stype))
            seats_by_hall[h].append((seat_id, stype))
emit("cinema_halls", ["hall_name", "capacity", "status"], [(h["name"], h["cap"], h["status"]) for h in halls])
emit("seats", ["hall_id", "row_label", "seat_number", "seat_type"], seat_rows)
active_halls = [h["id"] for h in halls if h["status"] == "active"]

# ----------------------------- promotions -----------------------------
promos = []
for i in range(1, N_PROMOS + 1):
    dtype = random.choice(["percentage", "fixed"])
    value = float(random.choice([5, 10, 15, 20, 25, 30])) if dtype == "percentage" else float(random.choice([20, 30, 50, 80, 100]))
    start = date(2026, 8, 1) + timedelta(days=random.randint(0, 60))
    end = start + timedelta(days=random.randint(30, 120))
    promos.append({
        "id": i, "code": f"PROMO{i:03d}", "type": dtype, "value": value,
        "start": start, "end": end,
        "status": "inactive" if i % 6 == 0 else "active",
    })
emit("promotions", ["promotion_code", "discount_type", "discount_value", "start_date", "end_date", "status"],
     [(p["code"], p["type"], p["value"], p["start"], p["end"], p["status"]) for p in promos])

# ----------------------------- customers -----------------------------
customers = []
for i in range(1, N_CUSTOMERS + 1):
    customers.append((
        fake.name(),
        f"customer{i:04d}@example.com",
        "0" + random.choice("689") + "".join(random.choices("0123456789", k=8)),
        rand_dt(datetime(2025, 1, 1), NOW - timedelta(days=1)).replace(microsecond=0),
    ))
emit("customers", ["name", "email", "phone", "created_at"], customers)

# ----------------------------- showtimes (ไม่ให้เวลาทับกันในโรงเดียวกัน) -----------------------------
slots = []
for h in active_halls:
    for d in range(91):
        day = date(2026, 9, 1) + timedelta(days=d)
        midnight = datetime.combine(day, time(0, 0))
        cur = datetime.combine(day, time(10, 0))
        while cur < datetime.combine(day, time(22, 0)):
            m = random.choice(active_movies)
            end = cur + timedelta(minutes=m["duration"])
            slots.append((cur, end, h, m))
            nxt = end + timedelta(minutes=30)                      # เวลาเตรียมโรง
            minutes = math.ceil((nxt - midnight).total_seconds() / 60 / 15) * 15
            cur = midnight + timedelta(minutes=minutes)

chosen = sorted(random.sample(slots, N_SHOWTIMES), key=lambda s: (s[0], s[2]))
showtimes = []
for i, (start, end, h, m) in enumerate(chosen, 1):
    if random.random() < 0.03:
        status = "cancelled"
    elif end < NOW:
        status = "completed"
    else:
        status = "scheduled"
    showtimes.append({"id": i, "movie": m["id"], "hall": h, "start": start, "end": end,
                      "price": float(random.choice([120, 150, 180, 200, 220])), "status": status})
emit("showtimes", ["movie_id", "hall_id", "start_time", "end_time", "standard_price", "status"],
     [(s["movie"], s["hall"], s["start"], s["end"], s["price"], s["status"]) for s in showtimes])
bookable = [s for s in showtimes if s["status"] != "cancelled"]

# ----------------------------- bookings / tickets / payments -----------------------------
occupied = defaultdict(set)          # showtime_id -> {seat_id} ที่ถูกจองอยู่จริง (pending/confirmed)
bookings, tickets, payments = [], [], []

while len(bookings) < N_BOOKINGS:
    st = random.choice(bookable)
    status = random.choices(["confirmed", "pending", "expired", "cancelled"], [65, 5, 15, 15])[0]

    if status == "pending":
        if st["start"] <= NOW + timedelta(hours=1):
            continue
        btime = NOW - timedelta(minutes=random.randint(1, 10))   # ยังอยู่ในช่วงถือครอง 15 นาที
    else:
        lo = max(st["start"] - timedelta(days=14), NOW - timedelta(days=60))
        hi = min(st["start"] - timedelta(hours=1), NOW)
        if hi <= lo:
            continue
        btime = rand_dt(lo, hi)
    btime = btime.replace(microsecond=0)
    expires = btime + timedelta(minutes=HOLD_MINUTES)

    k = random.choices([1, 2, 3, 4], [25, 40, 20, 15])[0]
    pool = seats_by_hall[st["hall"]]
    if status in ("pending", "confirmed"):
        free = [s for s in pool if s[0] not in occupied[st["id"]]]
        if len(free) < k:
            continue
        picked = random.sample(free, k)
        occupied[st["id"]].update(s[0] for s in picked)
    else:
        picked = random.sample(pool, k)

    prices = [st["price"] + (PREMIUM_SURCHARGE if s[1] == "premium" else 0) for s in picked]
    subtotal = sum(prices)

    promo = None
    if random.random() < 0.30:
        cands = [p for p in promos if p["status"] == "active" and p["start"] <= btime.date() <= p["end"]]
        if cands:
            promo = random.choice(cands)
    total = subtotal
    if promo:
        total = subtotal * (1 - promo["value"] / 100) if promo["type"] == "percentage" else max(0.0, subtotal - promo["value"])
    total = round(total, 2)

    bid = len(bookings) + 1
    bookings.append((random.randint(1, N_CUSTOMERS), st["id"], promo["id"] if promo else None,
                     btime, expires, status, total))

    t_status = {"confirmed": "issued", "pending": "reserved"}.get(status, "cancelled")
    for s, p in zip(picked, prices):
        tickets.append((bid, s[0], float(p), t_status))

    method = random.choice(["cash", "card", "online"])
    if status == "confirmed":
        payments.append((bid, total, method, "paid", btime + timedelta(minutes=random.randint(1, 10))))
    elif status == "pending":
        payments.append((bid, total, method, "pending", None))
    elif status == "expired" and random.random() < 0.5:
        payments.append((bid, total, method, "failed", None))
    elif status == "cancelled" and random.random() < 0.5:
        payments.append((bid, total, method, "refunded", btime + timedelta(minutes=random.randint(1, 10))))

emit("bookings", ["customer_id", "showtime_id", "promotion_id", "booking_time", "expires_at", "booking_status", "total_amount"], bookings)
emit("tickets", ["booking_id", "seat_id", "ticket_price", "ticket_status"], tickets)
emit("payments", ["booking_id", "amount", "payment_method", "payment_status", "paid_at"], payments)

# ----------------------------- เขียนไฟล์ / insert -----------------------------
with open(OUTPUT, "w", encoding="utf-8-sig") as f:      # utf-8-sig ให้ SSMS อ่านภาษาไทยถูก
    f.write("\n\n".join(STATEMENTS) + "\n")

counts = {
    "movies": len(movies), "cinema_halls": len(halls), "seats": len(seat_rows),
    "promotions": len(promos), "customers": len(customers), "showtimes": len(showtimes),
    "bookings": len(bookings), "tickets": len(tickets), "payments": len(payments),
}
print("สร้างไฟล์", OUTPUT, "เรียบร้อย")
for t, n in counts.items():
    print(f"  {t:<14}{n:>6}")

if CONN_STR:
    import pyodbc
    conn = pyodbc.connect(CONN_STR)
    cur = conn.cursor()
    for s in STATEMENTS:
        cur.execute(s)
    conn.commit()
    conn.close()
    print("insert เข้า database เรียบร้อย")
