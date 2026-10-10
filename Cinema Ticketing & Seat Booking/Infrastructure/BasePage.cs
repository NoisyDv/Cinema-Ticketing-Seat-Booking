using System;
using System.Collections.Generic;
using System.Web;
using System.Web.UI;

namespace Cinema_Ticketing___Seat_Booking
{
    /// <summary>ข้อความแจ้งผู้ใช้ (แสดงโดย Site.Master ทั้งกรณีเปลี่ยนหน้าและอยู่หน้าเดิม)</summary>
    public static class Flash
    {
        const string Key = "flash_messages";

        public static void Ok(string message) { Add(false, message); }
        public static void Error(string message) { Add(true, message); }

        static void Add(bool isError, string message)
        {
            HttpSessionState_Safe.Add(Key, new KeyValuePair<bool, string>(isError, message));
        }

        public static List<KeyValuePair<bool, string>> TakeAll()
        {
            List<KeyValuePair<bool, string>> l = HttpSessionState_Safe.Get(Key);
            if (l != null) HttpContext.Current.Session.Remove(Key);
            return l ?? new List<KeyValuePair<bool, string>>();
        }

        static class HttpSessionState_Safe
        {
            public static void Add(string key, KeyValuePair<bool, string> item)
            {
                List<KeyValuePair<bool, string>> l = Get(key);
                if (l == null) { l = new List<KeyValuePair<bool, string>>(); HttpContext.Current.Session[key] = l; }
                l.Add(item);
            }
            public static List<KeyValuePair<bool, string>> Get(string key)
            {
                return HttpContext.Current.Session[key] as List<KeyValuePair<bool, string>>;
            }
        }
    }

    /// <summary>หน้าพื้นฐานของทุกหน้า: ป้องกัน CSRF ของ ViewState และตรวจสิทธิ์ (login / admin)</summary>
    public class BasePage : Page
    {
        protected virtual bool RequiresLogin { get { return false; } }
        protected virtual bool RequiresAdmin { get { return false; } }

        protected UserSession CurrentUser { get { return Auth.Current; } }

        protected override void OnInit(EventArgs e)
        {
            // ผูก ViewState กับ session ของผู้ใช้ (Global.asax เขียนค่าลง session ตั้งแต่เริ่มเพื่อให้ SessionID คงที่)
            if (Session != null) ViewStateUserKey = Session.SessionID;

            if (RequiresLogin || RequiresAdmin)
            {
                UserSession u = Auth.Current;
                if (u == null)
                {
                    Response.Redirect("~/Login.aspx?returnUrl=" + Server.UrlEncode(Request.RawUrl), true);
                    return;
                }
                if (RequiresAdmin && !u.IsAdmin)
                {
                    Response.StatusCode = 403;
                    Flash.Error("หน้านี้สำหรับผู้ดูแลระบบเท่านั้น");
                    Response.Redirect("~/Default.aspx", true);
                    return;
                }
            }
            base.OnInit(e);
        }

        /// <summary>แปลงค่า query string เป็นจำนวนเต็ม (ไม่ใช่ตัวเลข/ติดลบ = null)</summary>
        protected int? QueryInt(string name)
        {
            int v;
            return int.TryParse(Request.QueryString[name], out v) && v > 0 ? (int?)v : null;
        }

        /// <summary>แสดงข้อความของ BusinessException; ข้อผิดพลาดอื่นให้ปล่อยขึ้นไปที่ Error.aspx</summary>
        protected void ShowError(BusinessException ex) { Flash.Error(ex.Message); }
    }

    /// <summary>หน้าที่ต้องล็อกอิน</summary>
    public class AuthPage : BasePage
    {
        protected override bool RequiresLogin { get { return true; } }
    }

    /// <summary>หน้าผู้ดูแลระบบ (ต้องล็อกอินและ user_role = admin)</summary>
    public class AdminPage : BasePage
    {
        protected override bool RequiresAdmin { get { return true; } }
    }
}
