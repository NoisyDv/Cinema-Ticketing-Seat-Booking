using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web;
using System.Web.UI.WebControls;
using Cinema_Ticketing___Seat_Booking.Data;
using Cinema_Ticketing___Seat_Booking.Models;

namespace Cinema_Ticketing___Seat_Booking.Pages
{
    public partial class AdminShowtimes : System.Web.UI.Page
    {
        private readonly MovieRepository _repo = new MovieRepository();

        protected void Page_Load(object sender, EventArgs e)
        {
            AdminAuth.RequireAdmin(this);
            if (!IsPostBack)
            {
                LoadDropdowns();
                BindList();
            }
        }

        protected void lnkLogout_Click(object sender, EventArgs e)
        {
            AdminAuth.SignOut(this);
            Response.Redirect("~/Pages/Movies.aspx", false);
        }

        protected void btnSearch_Click(object sender, EventArgs e)
        {
            BindList();
        }

        protected void btnCreate_Click(object sender, EventArgs e)
        {
            int movieId;
            int hallId;
            DateTime start;
            DateTime end;
            decimal price;
            if (!int.TryParse(ddlMovie.SelectedValue, out movieId) || movieId <= 0
                || !int.TryParse(ddlHall.SelectedValue, out hallId) || hallId <= 0)
            {
                ShowMsg("กรุณาเลือกหนังและโรง", true);
                return;
            }
            if (!Validation.TryParseDateTime(txtStart.Text, out start) || !Validation.TryParseDateTime(txtEnd.Text, out end))
            {
                ShowMsg("กรุณากรอกวันเวลาเริ่มและจบให้ถูกต้อง", true);
                return;
            }
            if (!decimal.TryParse((txtPrice.Text ?? "").Trim(),
                    NumberStyles.Number, CultureInfo.InvariantCulture, out price))
            {
                ShowMsg("กรุณากรอกราคาเป็นตัวเลข เช่น 150.00", true);
                return;
            }

            try
            {
                int newId = _repo.AdminCreateShowtime(movieId, hallId, start, end, price);
                LoadDropdowns();
                BindList();
                ShowMsg("เพิ่มรอบฉาย #" + newId + " สำเร็จ", false);
            }
            catch (InvalidOperationException ex)
            {
                ShowMsg(MapCreateError(ex.Message), true);
            }
            catch
            {
                ShowMsg("เพิ่มรอบฉายไม่สำเร็จ กรุณาลองใหม่", true);
            }
        }

        protected void btnCancelShow_Command(object sender, CommandEventArgs e)
        {
            int showtimeId;
            if (!int.TryParse(Convert.ToString(e.CommandArgument), out showtimeId) || showtimeId <= 0)
            {
                ShowMsg("รหัสรอบฉายไม่ถูกต้อง", true);
                return;
            }

            try
            {
                _repo.AdminCancelShowtime(showtimeId);
                BindList();
                ShowMsg("ยกเลิกรอบฉาย #" + showtimeId + " สำเร็จ", false);
            }
            catch (InvalidOperationException ex)
            {
                BindList();
                ShowMsg(MapCancelError(ex.Message), true);
            }
            catch
            {
                ShowMsg("ยกเลิกรอบฉายไม่สำเร็จ กรุณาลองใหม่", true);
            }
        }

        private void LoadDropdowns()
        {
            string keepMovie = ddlMovie.SelectedValue;
            string keepHall = ddlHall.SelectedValue;
            ddlMovie.Items.Clear();
            ddlHall.Items.Clear();
            try
            {
                bool fromDb;
                string statusMsg;
                foreach (Movie m in _repo.GetMovies(null, null, out fromDb, out statusMsg))
                    ddlMovie.Items.Add(new ListItem(m.Title + " (" + m.Genre + ")", m.MovieId.ToString()));
                foreach (HallOption h in _repo.AdminGetHalls())
                    ddlHall.Items.Add(new ListItem(h.HallName, h.HallId.ToString()));
            }
            catch
            {
                pnlCreate.Visible = false;
                ShowMsg("โหลดรายการหนัง/โรงไม่ได้ กรุณาลองใหม่", true);
                return;
            }
            if (ddlMovie.Items.FindByValue(keepMovie) != null)
                ddlMovie.SelectedValue = keepMovie;
            if (ddlHall.Items.FindByValue(keepHall) != null)
                ddlHall.SelectedValue = keepHall;
        }

        private void BindList()
        {
            string status = ddlStatus.SelectedValue;
            if (string.IsNullOrEmpty(status)) status = null;

            List<AdminShowtime> list;
            try
            {
                list = _repo.AdminGetShowtimes(status, null);
            }
            catch
            {
                ShowMsg("โหลดรอบฉายไม่ได้ กรุณาลองใหม่", true);
                return;
            }

            rptShowtimes.DataSource = list;
            rptShowtimes.DataBind();
            pnlList.Visible = true;
            pnlEmpty.Visible = list.Count == 0;
        }

        private static string MapCreateError(string code)
        {
            if (code == "BAD_TIME") return "เวลาจบต้องหลังเวลาเริ่ม";
            if (code == "PAST_TIME") return "เวลาเริ่มต้องเป็นอนาคต";
            if (code == "BAD_PRICE") return "ราคาต้องไม่ติดลบ";
            if (code == "OVERLAP") return "เวลาชนกับรอบอื่นในโรงเดียวกัน";
            if (code == "BAD_REF") return "หนังหรือโรงไม่ถูกต้อง";
            return "เพิ่มรอบฉายไม่สำเร็จ กรุณาลองใหม่";
        }

        private static string MapCancelError(string message)
        {
            if (message == "NOT_FOUND") return "ไม่พบรอบฉายนี้";
            if (message == "BAD_STATUS") return "รอบนี้ไม่ได้อยู่ในสถานะเปิดจองแล้ว";
            if (message == "STARTED") return "รอบฉายไปแล้ว ยกเลิกไม่ได้";
            if (message != null && message.StartsWith("HAS_BOOKINGS:"))
                return "ยังมีผู้จองค้างอยู่ " + message.Substring(13) + " รายการ ยกเลิกไม่ได้";
            return "ยกเลิกรอบฉายไม่สำเร็จ กรุณาลองใหม่";
        }

        private void ShowMsg(string message, bool isError)
        {
            lblMsg.Text = HttpUtility.HtmlEncode(message);
            pnlMsg.CssClass = isError ? "status warn" : "status ok";
            pnlMsg.Visible = true;
        }
    }
}
