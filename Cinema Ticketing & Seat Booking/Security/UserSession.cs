using System;
using System.Web;

namespace Cinema_Ticketing___Seat_Booking
{
    [Serializable]
    public sealed class UserSession
    {
        public int CustomerId { get; set; }
        public string Name { get; set; }
        public string Role { get; set; }
        public bool IsAdmin { get { return Role == "admin"; } }
    }

    /// <summary>จัดการ session ของผู้ใช้ที่ล็อกอิน (เก็บใน Session["user"]) และสิทธิ์ customer/admin</summary>
    public static class Auth
    {
        const string Key = "user";

        public static UserSession Current
        {
            get { return HttpContext.Current != null && HttpContext.Current.Session != null ? HttpContext.Current.Session[Key] as UserSession : null; }
        }

        public static void SignIn(UserSession u)
        {
            HttpContext.Current.Session.Clear();
            HttpContext.Current.Session[Key] = u;
        }

        public static void SignOut()
        {
            HttpContext ctx = HttpContext.Current;
            ctx.Session.Clear();
            ctx.Session.Abandon();
            HttpCookie c = new HttpCookie("ASP.NET_SessionId", "") { Expires = DateTime.Now.AddDays(-1), HttpOnly = true };
            ctx.Response.Cookies.Add(c);
        }

        /// <summary>อนุญาตเฉพาะ URL ภายในเว็บ (กัน open redirect จาก returnUrl)</summary>
        public static string SafeLocalUrl(string url, string fallback)
        {
            if (string.IsNullOrWhiteSpace(url)) return fallback;
            if ((url.StartsWith("~/") || (url.StartsWith("/") && !url.StartsWith("//") && !url.StartsWith("/\\"))) && url.IndexOf(':') < 0 && url.IndexOf('\\') < 0)
                return url;
            return fallback;
        }
    }
}
