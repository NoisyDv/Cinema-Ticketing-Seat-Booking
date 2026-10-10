# -*- coding: utf-8 -*-
"""
สร้าง database/data.sql (ข้อมูลจำลอง) แบบกำหนดผลซ้ำได้ (seed คงที่)

หลักการสำคัญ
  * วันที่ทั้งหมดเป็น "ค่าเทียบกับวันที่รันสคริปต์" (DATEADD จาก @today) ไม่ฝังวันที่ตายตัว
    - รอบฉายอยู่ช่วง -5..-1 วัน (completed) และ +1..+10 วัน (scheduled) เทียบวันที่รัน
    - ทุกการจอง/ชำระเงินเกิดก่อน "วันนี้ 00:00" เสมอ จึงไม่มี pending ค้างและไม่ผิดกฎเวลา
  * รอบฉายถูกวางด้วยตัวตรวจ "ไม่ซ้อนเวลาในโรงเดียวกัน" ตั้งแต่ตอนสร้าง (ตรงกับ trg_PreventShowtimeOverlap)
  * ที่นั่งไม่ซ้ำข้ามการจองที่ active, ที่นั่งอยู่ในโรงเดียวกับรอบฉาย
  * booking_time >= customers.created_at, total_amount = ตั๋ว - ส่วนลด (สูตรเดียวกับ fn_CalculateBookingTotal)
  * ไม่คัดลอกแถวซ้ำ: ทุกแถวมาจากการสุ่มด้วยกฎ ไม่ใช่การ copy

ใช้งาน:  python tools/generate_data.py            (เขียน database/data.sql)
"""
import math, os, random, sys
from datetime import datetime, date, time, timedelta
from decimal import Decimal, ROUND_HALF_UP

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mock_pools as P
from hash_password import make_hash

SEED = 2569
BASE_OCC = 0.032          # ค่าเฉลี่ยอัตราการครองที่นั่งพื้นฐาน (ปรับจำนวนการจองรวม)
N_MOVIES, N_NOW_SHOWING, N_CUSTOMERS, N_SHOWTIMES = 500, 45, 500, 500
PAST_DAYS, FUTURE_DAYS = list(range(-5, 0)), list(range(1, 11))
HOLD_SECONDS = 900
ADMIN_PASSWORD, DEMO_PASSWORD = "Admin@2569", "Demo@2569"
INACTIVE_HALL = 12       # โรงปิดปรับปรุง (ไม่มีรอบฉาย)

D = Decimal
def money(x): return D(x).quantize(D("0.01"), rounding=ROUND_HALF_UP)

def apply_promo(subtotal, ptype, pvalue):
    """สูตรเดียวกับ dbo.fn_CalculateBookingTotal"""
    t = subtotal
    if ptype == "percentage":
        t = (subtotal * (D(1) - (D(pvalue) / D(100)))).quantize(D("0.01"), rounding=ROUND_HALF_UP)
    elif ptype == "fixed":
        t = subtotal - D(pvalue)
    return max(t, D("0.00"))

def build(today=None):
    rng = random.Random(SEED)
    today = today or datetime.combine(date.today(), time())
    ds = {"today": today}

    # ---------- โรงและที่นั่ง ----------
    halls, seats, grid = [], [], {}
    for hid in range(1, 21):
        rows, per = (8, 10) if hid <= 5 else ((10, 12) if hid <= 15 else (12, 15))
        halls.append(dict(id=hid, name="Hall %d" % hid, cap=rows * per, status="inactive" if hid == INACTIVE_HALL else "active", rows=rows, per=per))
        for r in range(rows):
            for n in range(1, per + 1):
                sid = len(seats) + 1
                seats.append((sid, hid, chr(65 + r), n, "premium" if r >= rows - 2 else "standard"))
                grid[(hid, r, n)] = sid
    ds["halls"], ds["seats"] = halls, seats

    # ---------- หนัง ----------
    pairs, used = [], set()
    for g, cnt in P.GENRES:
        n_th = round(cnt * 0.3)
        for i in range(cnt):
            # ชื่อไทยก่อน (ถ้าชุดคำไทยของประเภทนั้นหมด ใช้ชื่ออังกฤษแทน)
            for pools in ((P.TH[g], P.EN[g]) if i < n_th else (P.EN[g],)):
                for _ in range(300):
                    pat, slots = rng.choice(pools)
                    fill = {k: rng.choice(v) for k, v in slots.items()} if isinstance(slots, dict) else None
                    t = pat.format(**fill) if fill else pat.format(x=rng.choice(slots))
                    if t not in used:
                        used.add(t); pairs.append((g, t)); break
                else:
                    continue
                break
            else:
                raise RuntimeError("title pool exhausted: " + g)
    rng.shuffle(pairs)
    now_ids = set(rng.sample(range(1, N_MOVIES + 1), N_NOW_SHOWING))
    movies = []
    for i, (g, t) in enumerate(pairs, 1):
        subj, sit, tail = P.SYN[g]
        sj = rng.choice(subj)
        desc = "เรื่องราวของ%s%s%s %s" % (sj, " ซึ่ง" if "ที่" in sj else "ที่", rng.choice(sit), rng.choice(tail))
        lo, hi = P.DURATION[g]
        if i in now_ids:
            rel, st = -rng.randint(10, 60), "active"
        else:
            rel, st = -rng.randint(90, 1600), ("active" if rng.random() < 0.15 else "inactive")
        movies.append(dict(id=i, title=t, desc=desc, dur=rng.randint(lo, hi), genre=g, rel=rel, status=st))
    ds["movies"] = movies
    now_list = sorted(now_ids); rng.shuffle(now_list)
    rank = {mid: r for r, mid in enumerate(now_list)}
    mweight = {mid: 1.0 / ((r + 1) ** 0.55) for mid, r in rank.items()}

    # ---------- ลูกค้า ----------
    customers, names_used, emails_used, phones_used = [], set(), set(), set()
    customers.append(dict(id=1, name="ผู้ดูแลระบบ", email="admin@cinema.example", phone="0800000001",
                          created=-730 * 86400, pw=make_hash(ADMIN_PASSWORD, salt=bytes(range(16))), role="admin"))
    customers.append(dict(id=2, name="ผู้ใช้ทดสอบ", email="demo@cinema.example", phone="0800000002",
                          created=-400 * 86400, pw=make_hash(DEMO_PASSWORD, salt=bytes(range(16, 32))), role="customer"))
    dom, dw = [d for d, _ in P.DOMAINS], [w for _, w in P.DOMAINS]
    while len(customers) < N_CUSTOMERS + 2:
        (fth, fen), (lth, len_) = rng.choice(P.FIRST), rng.choice(P.LAST)
        if (fth, lth) in names_used: continue
        names_used.add((fth, lth))
        style = rng.randint(0, 3)
        local = [fen + "." + len_, fen + len_[0] + str(rng.randint(1, 99)), fen[0] + len_ + str(rng.randint(1, 999)), fen + "_" + len_][style]
        email = "%s@%s" % (local, rng.choices(dom, dw)[0])
        if email in emails_used: continue
        emails_used.add(email)
        while True:
            phone = rng.choice(["06", "08", "09"]) + "".join(str(rng.randint(0, 9)) for _ in range(8))
            if phone not in phones_used and phone not in ("0800000001", "0800000002"): break
        phones_used.add(phone)
        recent = rng.random() < 0.10
        created = -(rng.randint(1, 18) if recent else rng.randint(25, 700)) * 86400 - rng.randint(0, 86399)
        customers.append(dict(id=len(customers) + 1, name=fth + " " + lth, email=email, phone=phone, created=created, pw=None, role="customer"))
    ds["customers"] = customers

    # ---------- โปรโมชัน ----------
    promos = [dict(id=i + 1, code=c, type=t, value=D(v), s=s, e=e, status=st) for i, (c, t, v, s, e, st) in enumerate(P.PROMOS)]
    ds["promotions"] = promos

    # ---------- รอบฉาย (วางโดยตรวจไม่ซ้อนเวลา) ----------
    days = PAST_DAYS + FUTURE_DAYS
    dayw = [1.5 if (today + timedelta(days=d)).weekday() >= 5 else 1.0 for d in days]
    per_day = [round(N_SHOWTIMES * w / sum(dayw)) for w in dayw]
    per_day[-1] += N_SHOWTIMES - sum(per_day)
    active_halls = [h for h in halls if h["status"] == "active"]
    hw = [1.0 + h["cap"] / 180.0 for h in active_halls]
    busy = {h["id"]: [] for h in halls}
    slots = list(range(600, 1321, 15)); sw = [1.8 if s >= 1020 else 1.0 for s in slots]
    mids = now_list; mw = [mweight[m] for m in mids]
    mov = {m["id"]: m for m in movies}
    showtimes = []
    for d, n in zip(days, per_day):
        weekend = (today + timedelta(days=d)).weekday() >= 5
        placed = 0
        while placed < n:
            for _ in range(500):
                h = rng.choices(active_halls, hw)[0]
                mid = rng.choices(mids, mw)[0]
                start = d * 1440 + rng.choices(slots, sw)[0]
                dur = -(-(mov[mid]["dur"] + 15) // 5) * 5          # + โฆษณา/ตัวอย่าง 15 นาที ปัดขึ้น 5 นาที
                end = start + dur
                if any(start < e + 10 and end + 10 > s for s, e in busy[h["id"]]): continue   # เว้น 10 นาทีทำความสะอาด
                busy[h["id"]].append((start, end))
                price = {80: 150, 120: 190, 180: 240}[h["cap"]] + (30 if (start % 1440) >= 1020 else 0) + (20 if weekend else 0)
                st = ("cancelled" if rng.random() < 0.03 else "completed") if d < 0 else ("cancelled" if rng.random() < 0.03 else "scheduled")
                showtimes.append(dict(id=0, movie=mid, hall=h["id"], start=start, dur=dur, price=money(price), status=st, day=d))
                placed += 1; break
            else:
                raise RuntimeError("cannot place showtime")
    showtimes.sort(key=lambda s: (s["start"], s["hall"]))
    for i, s in enumerate(showtimes, 1): s["id"] = i
    ds["showtimes"] = showtimes

    # ---------- การจอง ----------
    cust = {c["id"]: c for c in customers}
    cw = [(0.0 if c["role"] == "admin" else (3.0 if c["id"] == 2 else rng.lognormvariate(0, 0.9))) for c in customers]
    taken = {s["id"]: set() for s in showtimes}
    hall = {h["id"]: h for h in halls}

    def pick_seats(sh, k, avoid):
        h = hall[sh["hall"]]; rows, per = h["rows"], h["per"]
        r0 = 0.6 * (rows - 1)
        for _ in range(40):
            r = min(rows - 1, max(0, int(round(rng.gauss(r0, rows * 0.22)))))
            c = rng.randint(1, per - k + 1)
            ids = [grid[(h["id"], r, c + j)] for j in range(k)]
            if not any(i in avoid for i in ids): return ids
        free = [sid for (hid, r, n), sid in grid.items() if hid == h["id"] and sid not in avoid]
        return rng.sample(free, k) if len(free) >= k else None

    def pick_time(sh):
        S = sh["start"] * 60
        if sh["day"] < 0:
            lead = rng.choices([rng.randint(1800, 86400), rng.randint(86400, 4 * 86400), rng.randint(4 * 86400, 14 * 86400)], [5, 3, 2])[0]
            return S - lead
        lo = max(S - 14 * 86400, -14 * 86400)
        return rng.randint(lo, -60)

    def pick_customer(bt):
        for _ in range(200):
            c = rng.choices(customers, cw)[0]
            if c["created"] <= bt - 60: return c
        raise RuntimeError("no customer")

    def pick_promo(bt):
        if rng.random() > 0.22: return None
        bd = math.floor(bt / 86400)
        ok = [p for p in promos if p["status"] == "active" and p["s"] <= bd <= p["e"]]
        return rng.choice(ok) if ok else None

    raw = []   # (bt, showtime, customer, promo, seats, status)
    for sh in showtimes:
        if sh["status"] == "cancelled": continue
        h = hall[sh["hall"]]
        r = rank[sh["movie"]]
        f = 2.2 - 1.6 * (r / (N_NOW_SHOWING - 1))
        hour = (sh["start"] % 1440) // 60
        tf = 0.6 if hour < 13 else (0.9 if hour < 17 else 1.3)
        wf = 1.25 if (today + timedelta(days=sh["day"])).weekday() >= 5 else 1.0
        lf = 1.0 if sh["day"] < 0 else max(0.45, 1.0 - 0.06 * (sh["day"] - 1))
        mean = BASE_OCC * f * tf * wf * lf
        occ = rng.uniform(0.55, 0.95) if rng.random() < 0.03 * f else min(0.95, max(0.01, mean * rng.lognormvariate(0, 0.7)))
        target = int(round(h["cap"] * occ)); got = 0
        while got < target:
            k = min(rng.choices([1, 2, 3], [35, 45, 20])[0], target - got) or 1
            seats_ = pick_seats(sh, k, taken[sh["id"]])
            if not seats_: break
            bt = pick_time(sh); c = pick_customer(bt)
            taken[sh["id"]].update(seats_); got += k
            raw.append((bt, sh, c, pick_promo(bt), seats_, "confirmed"))
    n_conf = len(raw)
    confirmed_shows = [r[1] for r in raw]
    for status, share in (("cancelled", 0.07), ("expired", 0.06)):
        for _ in range(int(n_conf * share)):
            sh = rng.choice(confirmed_shows); k = rng.choices([1, 2, 3], [35, 45, 20])[0]
            seats_ = pick_seats(sh, k, taken[sh["id"]])
            if not seats_: continue
            bt = pick_time(sh); c = pick_customer(bt)
            raw.append((bt, sh, c, pick_promo(bt), seats_, status))
    raw.sort(key=lambda r: (r[0], r[1]["id"]))

    bookings, tickets, payments = [], [], []
    for bid, (bt, sh, c, promo, seats_, status) in enumerate(raw, 1):
        sub = sh["price"] * len(seats_)
        total = apply_promo(sub, promo["type"], promo["value"]) if promo else sub
        bookings.append(dict(id=bid, cust=c["id"], show=sh["id"], promo=promo["id"] if promo else None, bt=bt, status=status, total=total))
        tstat = "issued" if status == "confirmed" else "cancelled"
        for sid in seats_: tickets.append((bid, sid, sh["price"], tstat))
        if status == "confirmed":
            payments.append((bid, total, rng.choices(["online", "card", "cash"], [55, 30, 15])[0], "paid", bt + rng.randint(60, 840)))
        elif status == "expired" and rng.random() < 0.40:
            payments.append((bid, total, rng.choice(["online", "card"]), "failed", None))
        elif status == "cancelled" and rng.random() < 0.35:
            payments.append((bid, total, rng.choice(["online", "card"]), "refunded", bt + rng.randint(60, 600)))
    ds["bookings"], ds["tickets"], ds["payments"] = bookings, tickets, payments
    return ds

# ------------------------------------------------------------------ เขียน SQL
def q(s): return "N'" + s.replace("'", "''") + "'"
def a(s): return "'" + s.replace("'", "''") + "'"

def chunks(rows, n=500):
    for i in range(0, len(rows), n): yield rows[i:i + n]

def guard(body):
    return ("IF OBJECT_ID('tempdb..#seed_skip') IS NULL AND @@TRANCOUNT > 0\nBEGIN\n    DECLARE @today DATETIME2 = (SELECT today FROM #seed_ctx);\n" + body + "END;\nGO\n\n")

def write_sql(ds, path):
    o = []
    o.append("""-- =========================================================
-- data.sql  (สร้างโดย tools/generate_data.py - seed %d แก้ไฟล์นี้ด้วยมือไม่ได้ ให้แก้ตัวสร้างแล้วรันใหม่)
-- ข้อมูลจำลองสำหรับระบบจองตั๋วภาพยนตร์และผังที่นั่ง  |  DBMS: Microsoft SQL Server
-- รันหลัง schema.sql (ฐานข้อมูลที่ยังไม่มีข้อมูล) และก่อน logic.sql
-- รันซ้ำได้: ถ้าตาราง movies มีข้อมูลแล้ว สคริปต์จะข้ามทั้งหมดโดยไม่แก้ไขอะไร
-- ทั้งชุดอยู่ใน Transaction เดียว ถ้าล้มเหลวจะ ROLLBACK ทั้งหมด
-- วันที่เป็นค่าเทียบกับวันที่รันสคริปต์ (@today = 00:00 ของวันนี้):
--   รอบฉาย -5..-1 วัน = completed, +1..+10 วัน = scheduled, ทุกการจองเกิดก่อน @today
-- ลูกค้า id 1 = admin, id 2 = ผู้ใช้ทดสอบ (มีรหัสผ่านแฮช), ที่เหลือ password_hash เป็น NULL (ล็อกอินไม่ได้)
-- อีเมลทั้งหมดใช้โดเมนสำรองสำหรับตัวอย่าง (example.*) จึงไม่ตรงกับกล่องจดหมายของคนจริง
-- ต้องรันด้วย UTF-8 (SSMS เปิดไฟล์ได้เลย / sqlcmd ใช้ -f 65001)
-- =========================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID('tempdb..#seed_ctx') IS NOT NULL DROP TABLE #seed_ctx;
IF OBJECT_ID('tempdb..#seed_skip') IS NOT NULL DROP TABLE #seed_skip;
CREATE TABLE #seed_ctx (today DATETIME2 NOT NULL);
INSERT INTO #seed_ctx VALUES (CAST(CAST(SYSDATETIME() AS DATE) AS DATETIME2));
IF EXISTS (SELECT 1 FROM movies) OR EXISTS (SELECT 1 FROM cinema_halls)
BEGIN
    CREATE TABLE #seed_skip (x INT);
    PRINT N'พบข้อมูลอยู่แล้ว - ข้าม data.sql (ถ้าต้องการสร้างใหม่ ให้ลบข้อมูลหรือสร้างฐานข้อมูลใหม่)';
END
ELSE
    BEGIN TRANSACTION;
GO

""" % SEED)
    # halls
    rows = ["(%d, %s, %d, %s)" % (h["id"], a(h["name"]), h["cap"], a(h["status"])) for h in ds["halls"]]
    o.append(guard("    SET IDENTITY_INSERT cinema_halls ON;\n    INSERT INTO cinema_halls (hall_id, hall_name, capacity, status)\n    SELECT * FROM (VALUES\n        " + ",\n        ".join(rows) + "\n    ) AS v(hall_id, hall_name, capacity, status);\n    SET IDENTITY_INSERT cinema_halls OFF;\n"))
    # seats
    for ch in chunks(ds["seats"], 1000):
        rows = ["(%d,%d,%s,%d,%s)" % (s[0], s[1], a(s[2]), s[3], a(s[4])) for s in ch]
        o.append(guard("    SET IDENTITY_INSERT seats ON;\n    INSERT INTO seats (seat_id, hall_id, row_label, seat_number, seat_type)\n    SELECT * FROM (VALUES\n        " + ",\n        ".join(rows) + "\n    ) AS v(seat_id, hall_id, row_label, seat_number, seat_type);\n    SET IDENTITY_INSERT seats OFF;\n"))
    # movies
    for ch in chunks(ds["movies"], 250):
        rows = ["(%d,%s,%s,%d,%s,%d,%s)" % (m["id"], q(m["title"]), q(m["desc"]), m["dur"], a(m["genre"]), m["rel"], a(m["status"])) for m in ch]
        o.append(guard("    SET IDENTITY_INSERT movies ON;\n    INSERT INTO movies (movie_id, title, description, duration, genre, release_date, status)\n    SELECT v.movie_id, v.title, v.description, v.duration, v.genre, DATEADD(DAY, v.rel, CAST(@today AS DATE)), v.status\n    FROM (VALUES\n        " + ",\n        ".join(rows) + "\n    ) AS v(movie_id, title, description, duration, genre, rel, status);\n    SET IDENTITY_INSERT movies OFF;\n"))
    # customers
    for ch in chunks(ds["customers"], 300):
        rows = ["(%d,%s,%s,%s,%d,%s,%s)" % (c["id"], q(c["name"]), a(c["email"]), a(c["phone"]), c["created"], a(c["pw"]) if c["pw"] else "NULL", a(c["role"])) for c in ch]
        o.append(guard("    SET IDENTITY_INSERT customers ON;\n    INSERT INTO customers (customer_id, name, email, phone, created_at, password_hash, user_role)\n    SELECT v.customer_id, v.name, v.email, v.phone, DATEADD(SECOND, v.created, @today), v.password_hash, v.user_role\n    FROM (VALUES\n        " + ",\n        ".join(rows) + "\n    ) AS v(customer_id, name, email, phone, created, password_hash, user_role);\n    SET IDENTITY_INSERT customers OFF;\n"))
    # promotions
    rows = ["(%d,%s,%s,%s,%d,%d,%s)" % (p["id"], a(p["code"]), a(p["type"]), p["value"], p["s"], p["e"], a(p["status"])) for p in ds["promotions"]]
    o.append(guard("    SET IDENTITY_INSERT promotions ON;\n    INSERT INTO promotions (promotion_id, promotion_code, discount_type, discount_value, start_date, end_date, status)\n    SELECT v.promotion_id, v.promotion_code, v.discount_type, v.discount_value, DATEADD(DAY, v.s, CAST(@today AS DATE)), DATEADD(DAY, v.e, CAST(@today AS DATE)), v.status\n    FROM (VALUES\n        " + ",\n        ".join(rows) + "\n    ) AS v(promotion_id, promotion_code, discount_type, discount_value, s, e, status);\n    SET IDENTITY_INSERT promotions OFF;\n"))
    # showtimes
    for ch in chunks(ds["showtimes"], 500):
        rows = ["(%d,%d,%d,%d,%d,%s,%s)" % (s["id"], s["movie"], s["hall"], s["start"], s["dur"], s["price"], a(s["status"])) for s in ch]
        o.append(guard("    SET IDENTITY_INSERT showtimes ON;\n    INSERT INTO showtimes (showtime_id, movie_id, hall_id, start_time, end_time, ticket_price, status)\n    SELECT v.showtime_id, v.movie_id, v.hall_id, DATEADD(MINUTE, v.start_min, @today), DATEADD(MINUTE, v.start_min + v.dur_min, @today), v.ticket_price, v.status\n    FROM (VALUES\n        " + ",\n        ".join(rows) + "\n    ) AS v(showtime_id, movie_id, hall_id, start_min, dur_min, ticket_price, status);\n    SET IDENTITY_INSERT showtimes OFF;\n"))
    # bookings
    for ch in chunks(ds["bookings"], 500):
        rows = ["(%d,%d,%d,%s,%d,%s,%s)" % (b["id"], b["cust"], b["show"], b["promo"] if b["promo"] else "NULL", b["bt"], a(b["status"]), b["total"]) for b in ch]
        o.append(guard("    SET IDENTITY_INSERT bookings ON;\n    INSERT INTO bookings (booking_id, customer_id, showtime_id, promotion_id, booking_time, expires_at, booking_status, total_amount)\n    SELECT v.booking_id, v.customer_id, v.showtime_id, v.promotion_id, DATEADD(SECOND, v.bt, @today), DATEADD(SECOND, v.bt + %d, @today), v.booking_status, v.total_amount\n    FROM (VALUES\n        " % HOLD_SECONDS + ",\n        ".join(rows) + "\n    ) AS v(booking_id, customer_id, showtime_id, promotion_id, bt, booking_status, total_amount);\n    SET IDENTITY_INSERT bookings OFF;\n"))
    # tickets
    for ch in chunks(ds["tickets"], 1000):
        rows = ["(%d,%d,%s,%s)" % (t[0], t[1], t[2], a(t[3])) for t in ch]
        o.append(guard("    INSERT INTO tickets (booking_id, seat_id, ticket_price, ticket_status)\n    VALUES\n        " + ",\n        ".join(rows) + ";\n"))
    # payments
    for ch in chunks(ds["payments"], 500):
        rows = ["(%d,%s,%s,%s,%s)" % (p[0], p[1], a(p[2]), a(p[3]), p[4] if p[4] is not None else "NULL") for p in ch]
        o.append(guard("    INSERT INTO payments (booking_id, amount, payment_method, payment_status, paid_at)\n    SELECT v.booking_id, v.amount, v.payment_method, v.payment_status, DATEADD(SECOND, v.paid, @today)\n    FROM (VALUES\n        " + ",\n        ".join(rows) + "\n    ) AS v(booking_id, amount, payment_method, payment_status, paid);\n"))
    o.append("""IF OBJECT_ID('tempdb..#seed_skip') IS NULL
BEGIN
    IF @@TRANCOUNT > 0
    BEGIN
        COMMIT TRANSACTION;
        PRINT N'data.sql เสร็จสมบูรณ์ - ตรวจผลด้วย sanity_checks.sql';
    END
    ELSE
        PRINT N'data.sql ล้มเหลว (ถูก ROLLBACK ทั้งหมด) ดูข้อความ error ด้านบน';
END;
GO
""")
    with open(path, "w", encoding="utf-8") as f: f.write("".join(o))

def summary(ds):
    conf = [b for b in ds["bookings"] if b["status"] == "confirmed"]
    return {k: len(ds[k]) for k in ("halls", "seats", "movies", "customers", "promotions", "showtimes", "bookings", "tickets", "payments")} | {"confirmed_bookings": len(conf)}

if __name__ == "__main__":
    ds = build()
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "database", "data.sql")
    write_sql(ds, out)
    print(summary(ds)); print("wrote", os.path.normpath(out), os.path.getsize(out) // 1024, "KB")
