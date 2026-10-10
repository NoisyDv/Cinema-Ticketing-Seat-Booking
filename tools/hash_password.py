# -*- coding: utf-8 -*-
"""สร้าง/ตรวจ password_hash รูปแบบเดียวกับ Security/PasswordHasher.cs

รูปแบบ:  pbkdf2-sha256$<iterations>$<salt base64>$<hash base64>
  - PBKDF2 (HMAC-SHA256), salt 16 ไบต์, ผลลัพธ์ 32 ไบต์
ใช้ได้จากบรรทัดคำสั่ง:  python hash_password.py "รหัสผ่านที่ต้องการ"
"""
import base64, hashlib, hmac, os, sys

ITERATIONS = 100000

def make_hash(password, salt=None, iterations=ITERATIONS):
    salt = salt if salt is not None else os.urandom(16)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations, 32)
    return "pbkdf2-sha256$%d$%s$%s" % (iterations, base64.b64encode(salt).decode(), base64.b64encode(dk).decode())

def verify(password, stored):
    algo, it, salt, h = stored.split("$")
    dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), base64.b64decode(salt), int(it), 32)
    return hmac.compare_digest(dk, base64.b64decode(h))

if __name__ == "__main__":
    print(make_hash(sys.argv[1]))
