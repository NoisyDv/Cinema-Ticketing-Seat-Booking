using System;
using System.Globalization;
using System.Net.Mail;

namespace Cinema_Ticketing___Seat_Booking.Data
{
    // ตัวช่วยตรวจข้อมูลจากฟอร์ม ใช้ร่วมกันทุกหน้า
    public static class Validation
    {
        public static bool IsEmail(string email)
        {
            if (string.IsNullOrWhiteSpace(email) || email.Length > 255)
                return false;
            try
            {
                MailAddress m = new MailAddress(email.Trim());
                return string.Equals(m.Address, email.Trim(), StringComparison.Ordinal);
            }
            catch
            {
                return false;
            }
        }

        // ค่าจาก input แบบ date: "yyyy-MM-dd"
        public static bool TryParseDate(string text, out DateTime value)
        {
            text = (text ?? "").Trim();
            if (DateTime.TryParseExact(text, "yyyy-MM-dd",
                    CultureInfo.InvariantCulture, DateTimeStyles.None, out value))
                return true;
            return DateTime.TryParse(text, out value);
        }

        // ค่าจาก input แบบ datetime-local: "yyyy-MM-ddTHH:mm"
        public static bool TryParseDateTime(string text, out DateTime value)
        {
            text = (text ?? "").Trim();
            if (DateTime.TryParseExact(text, "yyyy-MM-dd'T'HH:mm",
                    CultureInfo.InvariantCulture, DateTimeStyles.None, out value))
                return true;
            return DateTime.TryParse(text, out value);
        }
    }
}
