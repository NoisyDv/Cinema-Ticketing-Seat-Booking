using System;
using System.Security.Cryptography;

namespace Cinema_Ticketing___Seat_Booking
{
    /// <summary>
    /// แฮชรหัสผ่านด้วย PBKDF2 (HMAC-SHA256) + salt สุ่ม 16 ไบต์ต่อผู้ใช้
    /// รูปแบบที่เก็บใน customers.password_hash:  pbkdf2-sha256$iterations$saltBase64$hashBase64
    /// (รูปแบบเดียวกับ tools/hash_password.py ที่ใช้สร้างบัญชีทดสอบ)
    /// </summary>
    public static class PasswordHasher
    {
        const string Prefix = "pbkdf2-sha256";
        public const int Iterations = 100000;
        const int SaltBytes = 16, HashBytes = 32;

        public static string Hash(string password)
        {
            byte[] salt = new byte[SaltBytes];
            using (RandomNumberGenerator rng = RandomNumberGenerator.Create()) rng.GetBytes(salt);
            byte[] hash = Derive(password, salt, Iterations, HashBytes);
            return Prefix + "$" + Iterations + "$" + Convert.ToBase64String(salt) + "$" + Convert.ToBase64String(hash);
        }

        public static bool Verify(string password, string stored)
        {
            if (string.IsNullOrEmpty(password) || string.IsNullOrEmpty(stored)) return false;
            string[] p = stored.Split('$');
            int iterations;
            if (p.Length != 4 || p[0] != Prefix || !int.TryParse(p[1], out iterations) || iterations < 1000 || iterations > 5000000) return false;
            try
            {
                byte[] salt = Convert.FromBase64String(p[2]);
                byte[] expected = Convert.FromBase64String(p[3]);
                byte[] actual = Derive(password, salt, iterations, expected.Length);
                return ConstantTimeEquals(expected, actual);
            }
            catch (FormatException) { return false; }
        }

        /// <summary>ใช้เมื่อไม่พบอีเมล เพื่อให้เวลาตอบสนองใกล้เคียงกรณีรหัสผ่านผิด (ลดการเดาว่าอีเมลมีในระบบหรือไม่)</summary>
        public static void DummyVerify()
        {
            Derive("dummy-password", new byte[SaltBytes], Iterations, HashBytes);
        }

        static byte[] Derive(string password, byte[] salt, int iterations, int length)
        {
            using (Rfc2898DeriveBytes kdf = new Rfc2898DeriveBytes(password, salt, iterations, HashAlgorithmName.SHA256))
                return kdf.GetBytes(length);
        }

        static bool ConstantTimeEquals(byte[] a, byte[] b)
        {
            if (a.Length != b.Length) return false;
            int diff = 0;
            for (int i = 0; i < a.Length; i++) diff |= a[i] ^ b[i];
            return diff == 0;
        }
    }
}
