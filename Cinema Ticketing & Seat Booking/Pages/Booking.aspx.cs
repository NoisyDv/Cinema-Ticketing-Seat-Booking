using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Cinema_Ticketing___Seat_Booking.Data;
using Cinema_Ticketing___Seat_Booking.Models;

namespace Cinema_Ticketing___Seat_Booking.Pages
{
    public partial class Booking : System.Web.UI.Page
    {
        // ต้องตรงกับ Database/logic.sql (sp_BookMovieSeats):
        // premium +50 บาท/ที่, สูงสุด 10 ที่/การจอง, วิธีจ่าย cash/card/online
        private const decimal PremiumSurcharge = 50m;
        private const int MaxSeats = 10;

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                int id;
                if (!int.TryParse(Request.QueryString["showtime_id"], out id) || id <= 0)
                {
                    ShowError("ระบุรอบฉายไม่ถูกต้อง");
                    return;
                }
                LoadShowtime(id, null);
            }
        }

        private int ShowtimeId
        {
            get
            {
                int id;
                int.TryParse(Request.QueryString["showtime_id"], out id);
                return id;
            }
        }

        protected void rptRows_ItemDataBound(object sender, RepeaterItemEventArgs e)
        {
            if (e.Item.ItemType != ListItemType.Item
                && e.Item.ItemType != ListItemType.AlternatingItem)
                return;
            SeatRow row = (SeatRow)e.Item.DataItem;
            Repeater inner = (Repeater)e.Item.FindControl("rptSeats");
            inner.DataSource = row.Seats;
            inner.DataBind();
        }

        // โหลดหัวรอบฉาย + ผังที่นั่ง (preselected = ที่นั่งที่ผู้ใช้ติ๊กไว้ก่อน postback ล้มเหลว)
        // คืน true ถ้าพร้อมให้จอง, false ถ้าแสดง error แล้ว
        private bool LoadShowtime(int showtimeId, HashSet<string> preselected)
        {
            const string stSql = @"
SELECT s.showtime_id, s.start_time, s.end_time, s.standard_price, s.status,
       m.movie_id, m.title, ch.hall_id, ch.hall_name
FROM showtimes s
INNER JOIN movies m ON m.movie_id = s.movie_id
INNER JOIN cinema_halls ch ON ch.hall_id = s.hall_id
WHERE s.showtime_id = @id;";

            // ที่นั่งที่ "ไม่ว่างจริง": confirmed/issued + pending ที่ยังไม่หมดเวลา/reserved
            // (นิยามเดียวกับ sp_BookMovieSeats ขั้นตอนที่ 4.2)
            const string takenSql = @"
SELECT t.seat_id
FROM tickets t
INNER JOIN bookings b ON b.booking_id = t.booking_id
WHERE b.showtime_id = @id
  AND t.ticket_status IN ('reserved', 'issued')
  AND (b.booking_status = 'confirmed'
       OR (b.booking_status = 'pending' AND b.expires_at > SYSDATETIME()));";

            const string seatSql = @"
SELECT seat_id, row_label, seat_number, seat_type
FROM seats
WHERE hall_id = @hall
ORDER BY row_label, seat_number;";

            try
            {
                using (SqlConnection conn = Db.Open())
                {
                    int hallId;
                    decimal stdPrice;
                    int movieId;
                    string title;
                    string hallName;
                    DateTime start;
                    DateTime end;

                    using (SqlCommand cmd = new SqlCommand(stSql, conn))
                    {
                        cmd.Parameters.Add("@id", SqlDbType.Int).Value = showtimeId;
                        using (SqlDataReader rd = cmd.ExecuteReader())
                        {
                            if (!rd.Read())
                            {
                                ShowError("ไม่พบรอบฉายนี้");
                                return false;
                            }
                            if (rd.GetString(4) != "scheduled" || rd.GetDateTime(1) <= DateTime.Now)
                            {
                                ShowError("รอบฉายนี้ไม่เปิดให้จองแล้ว");
                                return false;
                            }
                            start = rd.GetDateTime(1);
                            end = rd.GetDateTime(2);
                            stdPrice = rd.GetDecimal(3);
                            movieId = rd.GetInt32(5);
                            title = rd.GetString(6);
                            hallId = rd.GetInt32(7);
                            hallName = rd.GetString(8);
                        }
                    }

                    HashSet<int> taken = new HashSet<int>();
                    using (SqlCommand cmd = new SqlCommand(takenSql, conn))
                    {
                        cmd.Parameters.Add("@id", SqlDbType.Int).Value = showtimeId;
                        using (SqlDataReader rd = cmd.ExecuteReader())
                        {
                            while (rd.Read())
                                taken.Add(rd.GetInt32(0));
                        }
                    }

                    List<SeatRow> rows = new List<SeatRow>();
                    using (SqlCommand cmd = new SqlCommand(seatSql, conn))
                    {
                        cmd.Parameters.Add("@hall", SqlDbType.Int).Value = hallId;
                        using (SqlDataReader rd = cmd.ExecuteReader())
                        {
                            SeatRow current = null;
                            string lastRow = null;
                            while (rd.Read())
                            {
                                string rowLabel = rd.GetString(1);
                                if (lastRow == null || !string.Equals(lastRow, rowLabel, StringComparison.Ordinal))
                                {
                                    current = new SeatRow();
                                    current.RowLabel = rowLabel;
                                    rows.Add(current);
                                    lastRow = rowLabel;
                                }
                                int seatId = rd.GetInt32(0);
                                bool premium = string.Equals(rd.GetString(3), "premium", StringComparison.OrdinalIgnoreCase);
                                bool isTaken = taken.Contains(seatId);
                                SeatItem item = new SeatItem();
                                item.SeatId = seatId;
                                item.Label = rowLabel + rd.GetInt32(2).ToString();
                                item.IsPremium = premium;
                                item.Price = stdPrice + (premium ? PremiumSurcharge : 0m);
                                item.IsTaken = isTaken;
                                item.Selected = !isTaken && preselected != null && preselected.Contains(seatId.ToString());
                                current.Seats.Add(item);
                            }
                        }
                    }

                    litMovie.Text = HttpUtility.HtmlEncode(title);
                    litShowInfo.Text = HttpUtility.HtmlEncode(
                        hallName + " | " + start.ToString("dd MMM yyyy HH:mm")
                        + " - " + end.ToString("HH:mm")
                        + " | เริ่มต้น " + stdPrice.ToString("N2") + " บาท");
                    lnkBack.HRef = "MovieDetails.aspx?movie_id=" + movieId;
                    rptRows.DataSource = rows;
                    rptRows.DataBind();
                    pnlForm.Visible = true;
                    return true;
                }
            }
            catch
            {
                ShowError("โหลดข้อมูลไม่ได้ กรุณาลองใหม่อีกครั้ง");
                return false;
            }
        }

        protected void btnConfirm_Click(object sender, EventArgs e)
        {
            pnlError.Visible = false;
            int showtimeId = ShowtimeId;
            if (showtimeId <= 0)
            {
                ShowError("ระบุรอบฉายไม่ถูกต้อง");
                return;
            }

            string[] raw = Request.Form.GetValues("seat");
            if (raw == null) raw = new string[0];
            List<int> picked = new List<int>();
            foreach (string s in raw)
            {
                int id;
                if (int.TryParse(s, out id) && !picked.Contains(id))
                    picked.Add(id);
            }
            HashSet<string> pickedStr = new HashSet<string>(raw);

            if (picked.Count == 0 || picked.Count > MaxSeats)
            {
                ShowError("กรุณาเลือกที่นั่ง 1-10 ที่");
                LoadShowtime(showtimeId, pickedStr);
                return;
            }

            string name = txtName.Text == null ? "" : txtName.Text.Trim();
            string email = txtEmail.Text == null ? "" : txtEmail.Text.Trim();
            string phone = txtPhone.Text == null ? "" : txtPhone.Text.Trim();
            if (name.Length == 0)
            {
                ShowError("กรุณากรอกชื่อ-นามสกุล");
                LoadShowtime(showtimeId, pickedStr);
                return;
            }
            if (!Validation.IsEmail(email))
            {
                ShowError("กรุณากรอกอีเมลให้ถูกต้อง");
                LoadShowtime(showtimeId, pickedStr);
                return;
            }
            if (phone.Length == 0 || phone.Length > 20)
            {
                ShowError("กรุณากรอกเบอร์โทร (ไม่เกิน 20 ตัวอักษร)");
                LoadShowtime(showtimeId, pickedStr);
                return;
            }
            string promo = txtPromo.Text == null ? "" : txtPromo.Text.Trim();
            if (promo.Length == 0) promo = null;
            string pay = ddlPay.SelectedValue;
            if (pay != "online" && pay != "card" && pay != "cash")
            {
                ShowError("ช่องทางชำระเงินไม่ถูกต้อง");
                LoadShowtime(showtimeId, pickedStr);
                return;
            }

            try
            {
                using (SqlConnection conn = Db.Open())
                {
                    int customerId = FindOrCreateCustomer(conn, name, email, phone);

                    using (SqlCommand cmd = new SqlCommand("sp_BookMovieSeats", conn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.Add("@customer_id", SqlDbType.Int).Value = customerId;
                        cmd.Parameters.Add("@showtime_id", SqlDbType.Int).Value = showtimeId;
                        cmd.Parameters.Add("@seat_ids", SqlDbType.VarChar, 500).Value = string.Join(",", picked);
                        cmd.Parameters.Add("@promotion_code", SqlDbType.VarChar, 50).Value =
                            (object)promo ?? DBNull.Value;
                        cmd.Parameters.Add("@payment_method", SqlDbType.VarChar, 20).Value = pay;

                        using (SqlDataReader rd = cmd.ExecuteReader())
                        {
                            if (!rd.Read())
                                throw new InvalidOperationException("empty proc result");
                            int bookingId = Convert.ToInt32(rd["booking_id"]);
                            decimal total = Convert.ToDecimal(rd["total_amount"]);
                            ShowSuccess(bookingId, picked.Count, total);
                        }
                    }
                }
            }
            catch (SqlException ex)
            {
                if (ex.Number >= 50001 && ex.Number <= 50007)
                    ShowError(MapBookingError(ex.Number));
                else
                    ShowError("จองไม่สำเร็จ กรุณาลองใหม่อีกครั้ง");
                LoadShowtime(showtimeId, pickedStr);
            }
            catch
            {
                ShowError("จองไม่สำเร็จ กรุณาลองใหม่อีกครั้ง");
                LoadShowtime(showtimeId, pickedStr);
            }
        }

        // หาลูกค้าจากอีเมล ถ้ายังไม่มีให้สมัครใหม่ (ใช้ตาราง customers เดิม ไม่ต้องมี proc เพิ่ม)
        private static int FindOrCreateCustomer(SqlConnection conn, string name, string email, string phone)
        {
            using (SqlCommand cmd = new SqlCommand(
                "SELECT customer_id FROM customers WHERE email = @email", conn))
            {
                cmd.Parameters.Add("@email", SqlDbType.VarChar, 255).Value = email;
                object found = cmd.ExecuteScalar();
                if (found != null && found != DBNull.Value)
                    return Convert.ToInt32(found);
            }

            if (name.Length > 150) name = name.Substring(0, 150);
            try
            {
                using (SqlCommand cmd = new SqlCommand(
                    "INSERT INTO customers (name, email, phone) VALUES (@n, @e, @p);" +
                    " SELECT CAST(SCOPE_IDENTITY() AS INT);", conn))
                {
                    cmd.Parameters.Add("@n", SqlDbType.NVarChar, 150).Value = name;
                    cmd.Parameters.Add("@e", SqlDbType.VarChar, 255).Value = email;
                    cmd.Parameters.Add("@p", SqlDbType.VarChar, 20).Value = phone;
                    return Convert.ToInt32(cmd.ExecuteScalar());
                }
            }
            catch (SqlException ex)
            {
                // อีเมลซ้ำจากการสมัครพร้อมกัน ให้ดึงรหัสเดิมมาใช้
                if (ex.Number == 2627 || ex.Number == 2601)
                {
                    using (SqlCommand cmd = new SqlCommand(
                        "SELECT customer_id FROM customers WHERE email = @email", conn))
                    {
                        cmd.Parameters.Add("@email", SqlDbType.VarChar, 255).Value = email;
                        return Convert.ToInt32(cmd.ExecuteScalar());
                    }
                }
                throw;
            }
        }

        private static string MapBookingError(int number)
        {
            switch (number)
            {
                case 50001: return "รอบฉายนี้ไม่เปิดให้จองหรือเริ่มฉายไปแล้ว";
                case 50002: return "ไม่พบข้อมูลลูกค้า";
                case 50003: return "รหัสโปรโมชันไม่ถูกต้องหรือหมดอายุ";
                case 50004: return "มีที่นั่งที่ไม่ได้อยู่ในโรงของรอบฉายนี้";
                case 50005: return "มีที่นั่งที่ถูกจองไปแล้ว กรุณาเลือกที่นั่งใหม่";
                case 50006: return "จำนวนที่นั่งต้องอยู่ระหว่าง 1-10 ที่";
                case 50007: return "ช่องทางชำระเงินไม่ถูกต้อง";
                default: return "จองไม่สำเร็จ กรุณาลองใหม่อีกครั้ง";
            }
        }

        private void ShowError(string message)
        {
            lblError.Text = HttpUtility.HtmlEncode(message);
            pnlError.Visible = true;
        }

        private void ShowSuccess(int bookingId, int seatCount, decimal total)
        {
            pnlForm.Visible = false;
            pnlError.Visible = false;
            litSuccess.Text = HttpUtility.HtmlEncode(
                "รหัสการจอง #" + bookingId + " | " + seatCount
                + " ที่นั่ง | ยอดชำระ " + total.ToString("N2") + " บาท (ชำระเงินแล้ว)");
            pnlSuccess.Visible = true;
        }
    }
}
