using System;
using System.Globalization;
using System.Web;

namespace Cinema_Ticketing___Seat_Booking
{
    /// <summary>ตัวช่วยจัดรูปแบบการแสดงผล (ภาษาไทย / ปี พ.ศ. ตามวัฒนธรรม th-TH)</summary>
    public static class Fmt
    {
        static readonly CultureInfo Th = new CultureInfo("th-TH");
        static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

        public static string Html(object s) { return HttpUtility.HtmlEncode(Convert.ToString(s)); }

        public static string Baht(object v)
        {
            if (v == null || v == DBNull.Value) return "-";
            decimal d = Convert.ToDecimal(v);
            return "฿" + (d == Math.Floor(d) ? d.ToString("N0", Inv) : d.ToString("N2", Inv));
        }

        public static string Day(object v)      { return v == null || v == DBNull.Value ? "-" : Convert.ToDateTime(v).ToString("ddd d MMM yyyy", Th); }
        public static string ShortDay(object v) { return v == null || v == DBNull.Value ? "-" : Convert.ToDateTime(v).ToString("ddd d MMM", Th); }
        public static string Time(object v)     { return v == null || v == DBNull.Value ? "-" : Convert.ToDateTime(v).ToString("HH:mm", Inv) + " น."; }
        public static string DateTimeText(object v)
        {
            return v == null || v == DBNull.Value ? "-" : Convert.ToDateTime(v).ToString("d MMM yyyy HH:mm", Th) + " น.";
        }

        public static string Duration(object minutes)
        {
            int m = Convert.ToInt32(minutes);
            return (m / 60) + " ชม. " + (m % 60) + " นาที";
        }

        /// <summary>ค่าสำหรับ input type=datetime-local / date (ต้องเป็นรูปแบบสากลเสมอ ไม่ใช้ พ.ศ.)</summary>
        public static string ForDateTimeInput(DateTime d) { return d.ToString("yyyy-MM-ddTHH:mm", Inv); }
        public static string ForDateInput(DateTime d) { return d.ToString("yyyy-MM-dd", Inv); }

        public static bool TryParseDateTimeInput(string s, out DateTime d)
        {
            return DateTime.TryParseExact((s ?? "").Trim(), new[] { "yyyy-MM-ddTHH:mm", "yyyy-MM-ddTHH:mm:ss" }, Inv, DateTimeStyles.None, out d);
        }
        public static bool TryParseDateInput(string s, out DateTime d)
        {
            return DateTime.TryParseExact((s ?? "").Trim(), "yyyy-MM-dd", Inv, DateTimeStyles.None, out d);
        }

        public static string GenreColor(object genre)
        {
            switch (Convert.ToString(genre))
            {
                case "Action": return "#c2410c";
                case "Drama": return "#7c3aed";
                case "Comedy": return "#b45309";
                case "Sci-Fi": return "#0e7490";
                case "Horror": return "#9f1239";
                case "Animation": return "#15803d";
                case "Romance": return "#be185d";
                case "Thriller": return "#334155";
                case "Fantasy": return "#6d28d9";
                case "Documentary": return "#0f766e";
                default: return "#475569";
            }
        }

        public static string Initial(object title)
        {
            string t = (Convert.ToString(title) ?? "").Trim();
            return t.Length == 0 ? "?" : t.Substring(0, 1).ToUpperInvariant();
        }

        public static string BookingStatusText(object s)
        {
            switch (Convert.ToString(s))
            {
                case "pending": return "รอชำระเงิน";
                case "confirmed": return "ชำระแล้ว";
                case "expired": return "หมดเวลา";
                case "cancelled": return "ยกเลิก";
                default: return Convert.ToString(s);
            }
        }
        public static string BookingStatusClass(object s)
        {
            switch (Convert.ToString(s))
            {
                case "pending": return "b-warn";
                case "confirmed": return "b-ok";
                default: return "b-off";
            }
        }
        public static string ShowStatusText(object s)
        {
            switch (Convert.ToString(s))
            {
                case "scheduled": return "เปิดจอง";
                case "completed": return "ฉายแล้ว";
                case "cancelled": return "ยกเลิก";
                case "active": return "เปิดใช้งาน";
                case "inactive": return "ปิดใช้งาน";
                default: return Convert.ToString(s);
            }
        }
        public static string PayMethodText(object s)
        {
            switch (Convert.ToString(s))
            {
                case "online": return "ออนไลน์ (พร้อมเพย์/QR)";
                case "card": return "บัตรเครดิต/เดบิต";
                case "cash": return "เงินสด";
                default: return Convert.ToString(s);
            }
        }
    }
}
