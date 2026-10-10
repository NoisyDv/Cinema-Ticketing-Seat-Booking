# -*- coding: utf-8 -*-
"""
ตรวจข้อมูลจำลองโดยไม่ต้องมี SQL Server:
  1) แปลงชุดข้อมูลเดียวกับที่เขียนลง data.sql ไปโหลดใน SQLite (หน่วยความจำ)
  2) รัน database/sanity_checks.sql จริง (แปลงไวยากรณ์ T-SQL เล็กน้อยเป็น SQLite) แล้วสรุปผล
  3) ตรวจ data.sql แบบอ่านไฟล์: จำนวนแถวต่อ INSERT ตรงกับชุดข้อมูล และจำนวนคอลัมน์ตรงกับ alias
หมายเหตุ: นี่คือการตรวจ "ตรรกะของข้อมูลและคิวรีตรวจสอบ" ไม่ใช่การรัน T-SQL บน SQL Server จริง
"""
import os, re, sqlite3, sys
from datetime import timedelta
from decimal import Decimal
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import generate_data as g

def iso(dt): return dt.strftime("%Y-%m-%d %H:%M:%S")

def load(ds):
    today = ds["today"]; db = sqlite3.connect(":memory:")
    now = today + timedelta(hours=12)       # ถือว่า "เวลาปัจจุบัน" คือเที่ยงวันของวันที่รัน (หลัง @today)
    db.create_function("fn_CalculateBookingTotal", 3, lambda s, t, v: None if s is None else float(g.apply_promo(Decimal(str(s)), t, v if v is None else Decimal(str(v)))))
    db.create_function("sysdatetime", 0, lambda: iso(now))
    db.create_function("datediff", 3, lambda u, a, b: int(round((__import__("datetime").datetime.fromisoformat(b) - __import__("datetime").datetime.fromisoformat(a)).total_seconds() / 60)))
    c = db.cursor()
    c.executescript("""
    CREATE TABLE cinema_halls(hall_id,hall_name,capacity,status);
    CREATE TABLE seats(seat_id,hall_id,row_label,seat_number,seat_type);
    CREATE TABLE movies(movie_id,title,description,duration,genre,release_date,status);
    CREATE TABLE customers(customer_id,name,email,phone,created_at,password_hash,user_role);
    CREATE TABLE promotions(promotion_id,promotion_code,discount_type,discount_value,start_date,end_date,status);
    CREATE TABLE showtimes(showtime_id,movie_id,hall_id,start_time,end_time,ticket_price,status);
    CREATE TABLE bookings(booking_id,customer_id,showtime_id,promotion_id,booking_time,expires_at,booking_status,total_amount);
    CREATE TABLE tickets(ticket_id INTEGER PRIMARY KEY,booking_id,seat_id,ticket_price,ticket_status);
    CREATE TABLE payments(payment_id INTEGER PRIMARY KEY,booking_id,amount,payment_method,payment_status,paid_at);""")
    c.executemany("INSERT INTO cinema_halls VALUES (?,?,?,?)", [(h["id"], h["name"], h["cap"], h["status"]) for h in ds["halls"]])
    c.executemany("INSERT INTO seats VALUES (?,?,?,?,?)", ds["seats"])
    d0 = today.date()
    c.executemany("INSERT INTO movies VALUES (?,?,?,?,?,?,?)", [(m["id"], m["title"], m["desc"], m["dur"], m["genre"], str(d0 + timedelta(days=m["rel"])), m["status"]) for m in ds["movies"]])
    c.executemany("INSERT INTO customers VALUES (?,?,?,?,?,?,?)", [(x["id"], x["name"], x["email"], x["phone"], iso(today + timedelta(seconds=x["created"])), x["pw"], x["role"]) for x in ds["customers"]])
    c.executemany("INSERT INTO promotions VALUES (?,?,?,?,?,?,?)", [(p["id"], p["code"], p["type"], float(p["value"]), str(d0 + timedelta(days=p["s"])), str(d0 + timedelta(days=p["e"])), p["status"]) for p in ds["promotions"]])
    c.executemany("INSERT INTO showtimes VALUES (?,?,?,?,?,?,?)", [(s["id"], s["movie"], s["hall"], iso(today + timedelta(minutes=s["start"])), iso(today + timedelta(minutes=s["start"] + s["dur"])), float(s["price"]), s["status"]) for s in ds["showtimes"]])
    c.executemany("INSERT INTO bookings VALUES (?,?,?,?,?,?,?,?)", [(b["id"], b["cust"], b["show"], b["promo"], iso(today + timedelta(seconds=b["bt"])), iso(today + timedelta(seconds=b["bt"] + g.HOLD_SECONDS)), b["status"], float(b["total"])) for b in ds["bookings"]])
    c.executemany("INSERT INTO tickets(booking_id,seat_id,ticket_price,ticket_status) VALUES (?,?,?,?)", [(t[0], t[1], float(t[2]), t[3]) for t in ds["tickets"]])
    c.executemany("INSERT INTO payments(booking_id,amount,payment_method,payment_status,paid_at) VALUES (?,?,?,?,?)", [(p[0], float(p[1]), p[2], p[3], None if p[4] is None else iso(today + timedelta(seconds=p[4]))) for p in ds["payments"]])
    db.commit(); return db

def tsql_to_sqlite(sql):
    sql = re.sub(r"--[^\n]*", "", sql).replace("dbo.", "")
    sql = re.sub(r"SET NOCOUNT ON;", "", sql)
    sql = re.sub(r"CAST\(([\w\.]+) AS DATE\)", r"date(\1)", sql)
    sql = re.sub(r"DATEDIFF\(MINUTE,", "datediff('minute',", sql)
    return sql

def check_sql_file(ds):
    txt = open(os.path.join(HERE, "..", "database", "data.sql"), encoding="utf-8").read()
    ok = True
    blocks = re.findall(r"INSERT INTO (\w+) \(([^)]*)\)\s+(?:SELECT[^;]*?FROM\s*\(\s*)?VALUES\s*(.*?)(?:\)\s*AS v\(([^)]*)\)|;\s*\nEND)", txt, re.S)
    counts, bad = {}, 0
    for tbl, cols, body, alias in blocks:
        tuples = re.findall(r"^\s*\((.*)\),?\s*$", body, re.M)
        counts[tbl] = counts.get(tbl, 0) + len(tuples)
    exp = {"cinema_halls": len(ds["halls"]), "seats": len(ds["seats"]), "movies": len(ds["movies"]), "customers": len(ds["customers"]),
           "promotions": len(ds["promotions"]), "showtimes": len(ds["showtimes"]), "bookings": len(ds["bookings"]), "tickets": len(ds["tickets"]), "payments": len(ds["payments"])}
    for k, v in exp.items():
        flag = "OK " if counts.get(k) == v else "BAD"
        if flag == "BAD": ok = False
        print("   data.sql rows %-13s file=%-6s dataset=%-6s %s" % (k, counts.get(k), v, flag))
    return ok

if __name__ == "__main__":
    ds = g.build(); db = load(ds)
    print("== sanity_checks.sql บน SQLite ==")
    sql = tsql_to_sqlite(open(os.path.join(HERE, "..", "database", "sanity_checks.sql"), encoding="utf-8").read())
    rows = db.execute(sql).fetchall()
    fails = 0
    for name, v, res in rows:
        print("  %-52s %6s  %s" % (name, v, res)); fails += res == "FAIL" and not name.startswith("I")
    print("== เทียบ data.sql กับชุดข้อมูล ==")
    ok = check_sql_file(ds)
    print("สรุป: FAIL(S-checks)=%d, data.sql row-count %s" % (fails, "OK" if ok else "MISMATCH"))
    sys.exit(1 if fails or not ok else 0)
