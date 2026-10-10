using System;
using System.Diagnostics;
using System.Web;

namespace Cinema_Ticketing___Seat_Booking
{
    public class Global : HttpApplication
    {
        protected void Session_Start(object sender, EventArgs e)
        {
            // เขียนค่าลง session ทันที เพื่อให้ SessionID ถูกบันทึกและคงที่ (จำเป็นต่อ ViewStateUserKey ของผู้ใช้ที่ยังไม่ล็อกอิน)
            Session["init"] = 1;
        }

        protected void Application_Error(object sender, EventArgs e)
        {
            // บันทึกข้อผิดพลาดไว้ฝั่งเซิร์ฟเวอร์ ส่วนผู้ใช้จะเห็นหน้า Error.aspx (customErrors) ไม่เห็น stack trace
            Exception ex = Server.GetLastError();
            if (ex != null) Trace.TraceError(ex.ToString());
        }
    }
}
