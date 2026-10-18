using System;
using System.Configuration;
using System.Web;
using System.Web.UI;

namespace Cinema_Ticketing___Seat_Booking.Data
{
    // ด่านแอดมินแบบรหัสเดียว (ไม่ใช่ระบบ login/role):
    // กรอกรหัสถูกครั้งเดียว -> จำใน Session -> ทุกหน้าแอดมินตรวจก่อนโหลด
    // หน้าที่: กันคนซน/กดพลาด ไม่ได้กันแฮกเกอร์ (ดูหมายเหตุใน README)
    public static class AdminAuth
    {
        private const string SessionKey = "IsAdmin";
        private const string ConfigKey = "AdminPasscode";

        public static bool IsAdmin(Page page)
        {
            if (page == null || page.Session == null)
                return false;
            object flag = page.Session[SessionKey];
            return flag is bool && (bool)flag;
        }

        // เรียกบรรทัดแรกของ Page_Load ทุกหน้าแอดมิน
        public static bool RequireAdmin(Page page)
        {
            if (!IsAdmin(page))
            {
                page.Response.Redirect("~/Pages/AdminLogin.aspx", false);
                HttpContext.Current.ApplicationInstance.CompleteRequest();
                try { page.Response.End(); } catch (System.Threading.ThreadAbortException) { }
                return false;
            }
            return true;
        }

        public static bool CheckPasscode(string input)
        {
            string expected = ConfigurationManager.AppSettings[ConfigKey];
            return !string.IsNullOrEmpty(expected)
                && string.Equals((input ?? "").Trim(), expected, StringComparison.Ordinal);
        }

        public static void SignIn(Page page)
        {
            page.Session[SessionKey] = true;
        }

        public static void SignOut(Page page)
        {
            if (page.Session != null)
                page.Session.Remove(SessionKey);
        }
    }
}
