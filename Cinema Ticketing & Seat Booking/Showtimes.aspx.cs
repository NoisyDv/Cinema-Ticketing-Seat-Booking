using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace Cinema_Ticketing___Seat_Booking
{
    public partial class Showtimes : BasePage
    {
        int movieId;
        int? showtimeId;

        protected void Page_Load(object sender, EventArgs e)
        {
            int? m = QueryInt("movie");
            if (!m.HasValue) { Missing(); return; }
            movieId = m.Value;
            showtimeId = QueryInt("showtime");
            try
            {
                Repo.ReleaseExpiredHolds();
                DataRow movie = Repo.GetMovie(movieId);
                if (movie == null) { Missing(); return; }

                litTitle.Text = Server.HtmlEncode(Convert.ToString(movie["title"]));
                litMeta.Text = Server.HtmlEncode(Convert.ToString(movie["genre"]) + " • " + Fmt.Duration(movie["duration"]));
                litDesc.Text = Server.HtmlEncode(movie["description"] == DBNull.Value ? "" : Convert.ToString(movie["description"]));
                BindShowtimes();
            }
            catch (BusinessException ex)
            {
                ShowError(ex);
                pnlSeats.Visible = false;
            }
        }

        void Missing()
        {
            pnlMissing.Visible = true;
            pnlMovie.Visible = false;
        }

        DataTable shows;

        void BindShowtimes()
        {
            shows = Repo.GetUpcomingShowtimes(movieId);
            pnlNoShows.Visible = shows.Rows.Count == 0;
            pnlSeats.Visible = false;
            if (shows.Rows.Count == 0) return;

            // รอบที่เลือก: ตาม query string ถ้าไม่ถูกต้องใช้รอบแรก
            DataRow selected = null;
            foreach (DataRow r in shows.Rows)
                if (showtimeId.HasValue && Convert.ToInt32(r["showtime_id"]) == showtimeId.Value) selected = r;
            if (selected == null) selected = shows.Rows[0];
            showtimeId = Convert.ToInt32(selected["showtime_id"]);

            StringBuilder sb = new StringBuilder();
            string lastDay = null;
            foreach (DataRow r in shows.Rows)
            {
                string day = Fmt.Day(r["start_time"]);
                if (day != lastDay) { sb.Append("<div class=\"day-label\">" + Server.HtmlEncode(day) + "</div>"); lastDay = day; }
                int id = Convert.ToInt32(r["showtime_id"]);
                int free = Convert.ToInt32(r["capacity"]) - Convert.ToInt32(r["taken_seats"]);
                string url = ResolveUrl("~/Showtimes.aspx") + "?movie=" + movieId + "&showtime=" + id;
                sb.Append("<a class=\"time\" href=\"" + Server.HtmlEncode(url) + "\"" + (id == showtimeId.Value ? " aria-current=\"true\"" : "") + ">"
                    + "<b>" + Fmt.Time(r["start_time"]) + "</b><small>" + Server.HtmlEncode(Convert.ToString(r["hall_name"])) + " · " + Fmt.Baht(r["ticket_price"]) + " · ว่าง " + free + "</small></a>");
            }
            litTimes.Text = sb.ToString();

            litShowInfo.Text = Server.HtmlEncode(Fmt.Day(selected["start_time"]) + " " + Fmt.Time(selected["start_time"]) + " · " + Convert.ToString(selected["hall_name"]));
            pnlSeats.Visible = true;
            btnHold.Attributes["data-guest"] = Auth.Current == null ? "1" : "0";
            btnHold.Text = Auth.Current == null ? "เข้าสู่ระบบเพื่อจองที่นั่ง" : "ถือที่นั่งและไปชำระเงิน";
            RenderSeatMap(Convert.ToInt32(selected["showtime_id"]), Convert.ToDecimal(selected["ticket_price"]));
        }

        void RenderSeatMap(int stId, decimal price)
        {
            DataTable seats = Repo.GetSeatMap(stId);
            HashSet<int> chosen = PostedSeats();
            // จำนวนที่นั่งต่อแถว (ใช้แทรกทางเดินกลาง)
            Dictionary<string, int> perRow = new Dictionary<string, int>();
            foreach (DataRow r in seats.Rows)
            {
                string rl = Convert.ToString(r["row_label"]);
                perRow[rl] = (perRow.ContainsKey(rl) ? perRow[rl] : 0) + 1;
            }
            StringBuilder sb = new StringBuilder();
            sb.Append("<div class=\"map\"><div class=\"rows\" id=\"seatMap\" data-max=\"3\" data-price=\"" + price.ToString("0.##", System.Globalization.CultureInfo.InvariantCulture) + "\">");
            string current = null;
            foreach (DataRow r in seats.Rows)
            {
                string rl = Convert.ToString(r["row_label"]);
                if (rl != current)
                {
                    if (current != null) sb.Append("</div>");
                    sb.Append("<div class=\"row\"><span class=\"rl\">" + Server.HtmlEncode(rl) + "</span>");
                    current = rl;
                }
                int seatId = Convert.ToInt32(r["seat_id"]), num = Convert.ToInt32(r["seat_number"]);
                bool taken = Convert.ToInt32(r["is_taken"]) == 1;
                bool premium = Convert.ToString(r["seat_type"]) == "premium";
                string label = rl + num;
                if (num == perRow[rl] / 2 + 1) sb.Append("<span class=\"gap\"></span>");
                sb.Append("<label class=\"seat" + (premium ? " p" : "") + (taken ? " t" : "") + "\" title=\"" + Server.HtmlEncode(label + (premium ? " พรีเมียม" : " มาตรฐาน") + (taken ? " (ไม่ว่าง)" : "")) + "\">"
                    + "<input type=\"checkbox\" name=\"seat\" value=\"" + seatId + "\" data-label=\"" + Server.HtmlEncode(label) + "\" data-taken=\"" + (taken ? "1" : "0") + "\""
                    + (taken ? " disabled=\"disabled\"" : "") + (chosen.Contains(seatId) && !taken ? " checked=\"checked\"" : "")
                    + " aria-label=\"ที่นั่ง " + Server.HtmlEncode(label) + (taken ? " ไม่ว่าง" : "") + "\" /><span>" + num + "</span></label>");
            }
            if (current != null) sb.Append("</div>");
            sb.Append("</div></div>");
            litSeatMap.Text = sb.ToString();
        }

        /// <summary>ที่นั่งที่ผู้ใช้ติ๊กไว้ในคำขอนี้ (ใช้คงค่าที่เลือกเมื่อจองไม่สำเร็จ) ตัดค่าที่ไม่ใช่ตัวเลขทิ้ง</summary>
        HashSet<int> PostedSeats()
        {
            HashSet<int> set = new HashSet<int>();
            string[] raw = Request.Form.GetValues("seat");
            if (raw != null)
                foreach (string s in raw)
                {
                    int v;
                    if (int.TryParse(s, out v) && v > 0) set.Add(v);
                }
            return set;
        }

        protected void btnHold_Click(object sender, EventArgs e)
        {
            UserSession u = Auth.Current;
            if (u == null)
            {
                Response.Redirect("~/Login.aspx?returnUrl=" + Server.UrlEncode(Request.RawUrl), true);
                return;
            }
            if (!showtimeId.HasValue) { Flash.Error("กรุณาเลือกรอบฉาย"); return; }

            // อ่านและตรวจที่นั่งจากฟอร์มฝั่งเซิร์ฟเวอร์ (ไม่เชื่อ JavaScript): 1-3 ที่ ไม่ซ้ำ เป็นจำนวนเต็มบวก
            string[] raw = Request.Form.GetValues("seat");
            List<int> ids = new List<int>();
            if (raw != null)
                foreach (string s in raw)
                {
                    int v;
                    if (!int.TryParse(s, out v) || v <= 0) { Flash.Error("ข้อมูลที่นั่งไม่ถูกต้อง"); return; }
                    if (!ids.Contains(v)) ids.Add(v);
                }
            if (ids.Count == 0) { Flash.Error("กรุณาเลือกที่นั่งอย่างน้อย 1 ที่"); return; }
            if (ids.Count > 3) { Flash.Error("เลือกที่นั่งได้สูงสุด 3 ที่ต่อการจอง"); return; }

            try
            {
                DataRow res = Repo.HoldSeats(u.CustomerId, showtimeId.Value, ids);
                Flash.Ok("ถือที่นั่งสำเร็จ กรุณาชำระเงินภายใน 15 นาที");
                Response.Redirect("~/Pay.aspx?booking=" + Convert.ToInt32(res["booking_id"]), false);
                Context.ApplicationInstance.CompleteRequest();
            }
            catch (BusinessException ex)
            {
                // กรณีสองคนจองที่เดียวกันพร้อมกัน (50005) หรืออื่น ๆ: แสดงข้อความ แล้ววาดผังใหม่จากข้อมูลล่าสุด
                ShowError(ex);
                try { BindShowtimes(); } catch (BusinessException) { }
            }
        }
    }
}
