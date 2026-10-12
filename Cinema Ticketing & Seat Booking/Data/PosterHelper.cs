using System;
using System.Web;
using System.Web.UI;

namespace Cinema_Ticketing___Seat_Booking.Data
{
    // รวมวิธีแปลง poster_url จาก DB (เช่น "Posters/Avatar.webp")
    // ให้เป็น URL ที่เบราว์เซอร์ขอได้จริง ใช้ร่วมกันทุกหน้า
    public static class PosterHelper
    {
        private const string Fallback = "~/favicon.ico";

        public static string ResolvePosterUrl(Page page, string posterUrl)
        {
            if (page == null) throw new ArgumentNullException("page");
            if (string.IsNullOrWhiteSpace(posterUrl))
                return page.ResolveUrl(Fallback);

            string relative = posterUrl.Replace('\\', '/').TrimStart('/', '~', ' ');
            if (!relative.StartsWith("Posters/", StringComparison.OrdinalIgnoreCase))
                relative = "Posters/" + relative;

            string physical;
            try
            {
                physical = page.Server.MapPath("~/" + relative);
            }
            catch
            {
                physical = null;
            }

            if (physical != null && !System.IO.File.Exists(physical))
                return page.ResolveUrl(Fallback); // กันรูปแตกถ้าไฟล์หาย

            // UrlPathEncode ไม่ encode apostrophe (') ต้องแทนเป็น %27 เอง
            // ไม่งั้นไฟล์อย่าง Philosopher's_Stone.webp จะทำ attribute src ขาด
            return page.ResolveUrl("~/" + HttpUtility.UrlPathEncode(relative).Replace("'", "%27"));
        }
    }
}
