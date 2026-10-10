using System;
using System.Text.RegularExpressions;

namespace Cinema_Ticketing___Seat_Booking
{
    /// <summary>กฎตรวจสอบข้อมูลฝั่งเซิร์ฟเวอร์ (ใช้ pattern เดียวกับ RegularExpressionValidator ฝั่งไคลเอนต์ในหน้า .aspx)</summary>
    public static class Validation
    {
        public const string EmailPattern = @"^[^\s@]+@[^\s@]+\.[^\s@]+$";
        public const string PhonePattern = @"^[0-9]{9,15}$";
        public const string PasswordPattern = @"^(?=.*[A-Za-z])(?=.*[0-9]).{8,64}$";
        public const string PromoCodePattern = @"^[A-Za-z0-9_\-]{3,50}$";

        public static bool IsEmail(string s) { return s != null && s.Length <= 255 && Regex.IsMatch(s, EmailPattern); }
        public static bool IsPhone(string s) { return s != null && Regex.IsMatch(s, PhonePattern); }
        public static bool IsStrongPassword(string s) { return s != null && Regex.IsMatch(s, PasswordPattern); }
        public static bool IsPromoCode(string s) { return s != null && Regex.IsMatch(s, PromoCodePattern); }
        public static bool IsHttpUrl(string s)
        {
            Uri u;
            return s != null && s.Length <= 500 && Uri.TryCreate(s, UriKind.Absolute, out u) && (u.Scheme == Uri.UriSchemeHttp || u.Scheme == Uri.UriSchemeHttps);
        }

        public static string Trim(string s) { return (s ?? "").Trim(); }

        /// <summary>escape อักขระพิเศษของ LIKE (% _ [) เพื่อให้ค้นหาตามตัวอักษรจริง</summary>
        public static string EscapeLike(string s)
        {
            return (s ?? "").Replace("[", "[[]").Replace("%", "[%]").Replace("_", "[_]");
        }
    }
}
