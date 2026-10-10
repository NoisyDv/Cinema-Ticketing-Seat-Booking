# -*- coding: utf-8 -*-
"""สร้าง docs/report/data_dictionary.md จาก database/schema.sql (ชื่อคอลัมน์/ชนิด/ข้อจำกัดอ่านจากสคีมาจริง คำอธิบายเขียนไว้ในไฟล์นี้)"""
import os, re
HERE = os.path.dirname(os.path.abspath(__file__))
schema = open(os.path.join(HERE, "..", "database", "schema.sql"), encoding="utf-8").read()

DESC = {
 "movies": ("ภาพยนตร์ที่ระบบมีข้อมูล (รวมเรื่องที่ไม่ได้ฉายแล้ว)", {
   "movie_id": "รหัสภาพยนตร์ (สร้างอัตโนมัติ)", "title": "ชื่อภาพยนตร์", "description": "เรื่องย่อ", "duration": "ความยาว (นาที)",
   "genre": "ประเภทภาพยนตร์ (ค่าเดียวต่อเรื่อง)", "release_date": "วันเข้าฉาย", "status": "active = เปิดใช้งาน / inactive = ปิดใช้งาน", "poster_url": "ลิงก์รูปโปสเตอร์ (ไม่บังคับ)"}),
 "cinema_halls": ("โรงภาพยนตร์ในโรงหนัง", {
   "hall_id": "รหัสโรง", "hall_name": "ชื่อโรง (ไม่ซ้ำ)", "capacity": "จำนวนที่นั่งทั้งหมดของโรง", "status": "active = ใช้งาน / inactive = ปิดปรับปรุง"}),
 "seats": ("ที่นั่งแต่ละที่นั่งของแต่ละโรง", {
   "seat_id": "รหัสที่นั่ง", "hall_id": "โรงที่ที่นั่งนี้อยู่", "row_label": "ตัวอักษรแถว เช่น A, B", "seat_number": "หมายเลขที่นั่งในแถว", "seat_type": "standard = มาตรฐาน / premium = พรีเมียม (2 แถวหลังสุด)"}),
 "showtimes": ("รอบฉาย = หนัง 1 เรื่อง ในโรง 1 โรง ช่วงเวลาหนึ่ง", {
   "showtime_id": "รหัสรอบฉาย", "movie_id": "ภาพยนตร์ที่ฉาย", "hall_id": "โรงที่ฉาย", "start_time": "เวลาเริ่มฉาย", "end_time": "เวลาจบ (ต้องหลังเวลาเริ่ม)",
   "ticket_price": "ราคาตั๋วต่อที่นั่งของรอบนี้", "status": "scheduled = เปิดจอง / completed = ฉายแล้ว / cancelled = ยกเลิก"}),
 "customers": ("ลูกค้า/ผู้ใช้ระบบ (รวมบัญชีผู้ดูแลระบบ)", {
   "customer_id": "รหัสลูกค้า", "name": "ชื่อ-นามสกุล", "email": "อีเมล (ไม่ซ้ำ ใช้ล็อกอิน)", "phone": "เบอร์โทรศัพท์ (ตัวเลข)", "created_at": "เวลาสมัครสมาชิก",
   "password_hash": "ค่าแฮช PBKDF2-SHA256 + salt (ไม่เก็บรหัสผ่านจริง) NULL = ยังล็อกอินไม่ได้", "user_role": "customer = ลูกค้า / admin = ผู้ดูแลระบบ", "last_login_at": "เวลาล็อกอินล่าสุด"}),
 "promotions": ("โค้ดส่วนลด", {
   "promotion_id": "รหัสโปรโมชัน", "promotion_code": "โค้ดที่ลูกค้ากรอก (ไม่ซ้ำ)", "discount_type": "percentage = เปอร์เซ็นต์ / fixed = จำนวนเงินคงที่",
   "discount_value": "มูลค่าส่วนลด (percentage ต้องไม่เกิน 100)", "start_date": "วันเริ่มใช้", "end_date": "วันสิ้นสุด (ไม่ก่อนวันเริ่ม)", "status": "active / inactive"}),
 "bookings": ("การจอง 1 ครั้ง (ถือที่นั่งแล้วชำระเงิน)", {
   "booking_id": "รหัสการจอง", "customer_id": "ผู้จอง", "showtime_id": "รอบฉายที่จอง", "promotion_id": "โปรโมชันที่ใช้ (NULL = ไม่ใช้)", "booking_time": "เวลาที่จอง/ถือที่นั่ง",
   "expires_at": "เวลาหมดอายุการถือที่นั่ง (ปกติ +15 นาที)", "booking_status": "pending = ถือที่นั่งรอชำระ / confirmed = ชำระแล้ว / expired = หมดเวลา / cancelled = ยกเลิก", "total_amount": "ยอดรวมหลังส่วนลด"}),
 "tickets": ("ตั๋วแต่ละใบ = 1 ที่นั่งในการจอง (ตารางเชื่อม bookings กับ seats)", {
   "ticket_id": "รหัสตั๋ว", "booking_id": "การจองที่ตั๋วนี้อยู่", "seat_id": "ที่นั่งของตั๋ว", "ticket_price": "ราคาตั๋ว ณ เวลาที่จอง (สำเนาราคาของรอบฉาย)", "ticket_status": "reserved = ถือไว้ / issued = ออกตั๋วแล้ว / cancelled = ยกเลิก"}),
 "payments": ("การชำระเงินของการจอง (1 การจองมีได้ 1 รายการ)", {
   "payment_id": "รหัสการชำระเงิน", "booking_id": "การจองที่ชำระ (ไม่ซ้ำ)", "amount": "จำนวนเงินที่ชำระ", "payment_method": "cash / card / online",
   "payment_status": "pending / paid / failed / refunded", "paid_at": "เวลาที่ชำระสำเร็จ (NULL ถ้ายังไม่สำเร็จ)"}),
}
ORDER = ["movies", "cinema_halls", "seats", "showtimes", "customers", "promotions", "bookings", "tickets", "payments"]

def parse_table(name):
    m = re.search(r"CREATE TABLE %s \((.*?)\n    \);" % name, schema, re.S)
    body = m.group(1)
    lines = [re.sub(r"--.*$", "", l).rstrip() for l in body.split("\n")]
    items, cur = [], None
    for l in lines:
        if not l.strip(): continue
        if re.match(r"^\s{8}(CONSTRAINT|\w+\s+(INT|NVARCHAR|VARCHAR|DECIMAL|DATETIME2|DATE)\b)", l) or cur is None:
            if cur is not None: items.append(cur)
            cur = l.strip()
        else:
            cur += " " + l.strip()
    items.append(cur)
    cols, cons = [], []
    for it in items:
        it = it.rstrip(",")
        if it.startswith("CONSTRAINT"): cons.append(it)
        else:
            m2 = re.match(r"(\w+)\s+(\w+(?:\([\w,]+\))?)\s*(.*)", it); cols.append((m2.group(1), m2.group(2), m2.group(3)))
    return cols, cons

out = ["# พจนานุกรมข้อมูล (Data Dictionary) — ร่างแรก\n",
       "> สร้างอัตโนมัติจาก `database/schema.sql` โดย `tools/make_data_dictionary.py` (ชื่อคอลัมน์ ชนิดข้อมูล และข้อจำกัดอ่านจากสคีมาจริง) ส่วนคำอธิบายเป็นร่างที่ทีมควรตรวจและปรับถ้อยคำก่อนใส่รายงาน\n",
       "ระบบมี **9 ตาราง** ชื่อตารางและคอลัมน์เป็นภาษาอังกฤษ snake_case รูปพหูพจน์\n"]
for t in ORDER:
    cols, cons = parse_table(t)
    tdesc, cdesc = DESC[t]
    out.append("\n## ตาราง `%s`\n\n%s\n\n| คอลัมน์ | ชนิดข้อมูล | ข้อจำกัด | คำอธิบาย |\n|---|---|---|---|" % (t, tdesc))
    for c, typ, rest in cols:
        cs = []
        if "PRIMARY KEY" in rest: cs.append("PK, IDENTITY(1,1)")
        cs.append("NOT NULL" if "NOT NULL" in rest or "PRIMARY KEY" in rest else "NULL")
        dm = re.search(r"DEFAULT\s+([^\s,)]+(?:\(\))?)", rest)
        if dm: cs.append("DEFAULT " + dm.group(1))
        for con in cons:
            if re.search(r"\b%s\b" % c, con):
                nm = re.match(r"CONSTRAINT (\w+)", con).group(1)
                if "FOREIGN KEY" in con and ("(%s)" % c) in con:
                    ref = re.search(r"REFERENCES (\w+)\((\w+)\)", con); act = re.findall(r"ON (DELETE|UPDATE) (CASCADE|NO ACTION|SET NULL)", con)
                    cs.append("FK → %s(%s) [%s]" % (ref.group(1), ref.group(2), ", ".join("%s %s" % a for a in act)))
                elif "UNIQUE" in con: cs.append("UNIQUE (%s)" % nm)
                elif "CHECK" in con: cs.append("CHECK (%s)" % nm)
        # ลบรายการซ้ำ
        seen = []; [seen.append(x) for x in cs if x not in seen]
        out.append("| `%s` | %s | %s | %s |" % (c, typ, "<br>".join(seen), cdesc.get(c, "")))
    multi = []
    for con in cons:
        nm = re.match(r"CONSTRAINT (\w+)", con).group(1)
        expr = con[len("CONSTRAINT " + nm):]
        if "FOREIGN KEY" in expr: continue
        if sum(1 for c, _, _ in cols if re.search(r"\b%s\b" % c, expr)) >= 2:
            kind = "UNIQUE" if "UNIQUE" in expr else "CHECK"
            multi.append("`%s` (%s: %s)" % (nm, kind, re.sub(r"^\s*(UNIQUE|CHECK)\s*", "", expr).strip()))
    out.append("\n**ข้อจำกัดที่เกี่ยวกับหลายคอลัมน์:** " + ("; ".join(multi) if multi else "(ไม่มี)"))
open(os.path.join(HERE, "..", "docs", "report", "data_dictionary.md"), "w", encoding="utf-8").write("\n".join(out) + "\n")
print("ok")
