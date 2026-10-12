using System;
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
    }
}
