using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.UI.WebControls;
using Cinema_Ticketing___Seat_Booking.Data;
using Cinema_Ticketing___Seat_Booking.Models;

namespace Cinema_Ticketing___Seat_Booking.Pages
{
    public partial class History : System.Web.UI.Page
    {
        private readonly MovieRepository _repo = new MovieRepository();

        protected void Page_Load(object sender, EventArgs e)
        {
        }

        protected void btnSearch_Click(object sender, EventArgs e)
        {
            pnlError.Visible = false;

            string email = txtEmail.Text == null ? "" : txtEmail.Text.Trim();
            if (!Validation.IsEmail(email))
            {
                ShowMsg("กรุณากรอกอีเมลให้ถูกต้อง", true);
                return;
            }

            ViewState["HistEmail"] = email;
            BindList(email);
        }

        protected void btnCancel_Command(object sender, CommandEventArgs e)
        {
            pnlError.Visible = false;
            int bookingId;
            if (!int.TryParse(Convert.ToString(e.CommandArgument), out bookingId) || bookingId <= 0)
            {
                ShowMsg("รหัสการจองไม่ถูกต้อง", true);
                return;
            }

            string email = ViewState["HistEmail"] as string;
            if (string.IsNullOrEmpty(email))
                email = txtEmail.Text == null ? "" : txtEmail.Text.Trim();
            if (!Validation.IsEmail(email))
            {
                ShowMsg("กรุณาค้นหาด้วยอีเมลก่อนกดยกเลิก", true);
                return;
            }

            try
            {
                decimal refund = _repo.CancelBooking(email, bookingId);
                BindList(email);
                string msg = "ยกเลิกการจอง #" + bookingId + " สำเร็จ";
                if (refund > 0)
                    msg += " คืนเงิน " + refund.ToString("N2") + " บาท";
                ShowMsg(msg, false);
            }
            catch (SqlException ex)
            {
                if (ex.Number == 50010)
                    ShowMsg("ไม่พบการจองนี้ หรือไม่ใช่เจ้าของการจอง", true);
                else if (ex.Number == 50011)
                    ShowMsg("การจองนี้ยกเลิกไม่ได้ (อาจถูกยกเลิกไปแล้วหรือรอบฉายเริ่มแล้ว)", true);
                else
                    ShowMsg("ยกเลิกไม่สำเร็จ กรุณาลองใหม่อีกครั้ง", true);
                BindList(email);
            }
            catch
            {
                ShowMsg("ยกเลิกไม่สำเร็จ กรุณาลองใหม่อีกครั้ง", true);
            }
        }

        // ดึงรายการใหม่ทุกครั้งหลังค้นหา/ยกเลิก
        private void BindList(string email)
        {
            pnlList.Visible = false;
            pnlEmpty.Visible = false;
            lblCount.Visible = false;

            List<BookingInfo> list;
            try
            {
                list = _repo.GetBookingsByEmail(email);
            }
            catch
            {
                ShowMsg("ค้นหาไม่สำเร็จ กรุณาลองใหม่อีกครั้ง", true);
                return;
            }

            if (list.Count == 0)
            {
                lblEmpty.Text = HttpUtility.HtmlEncode(
                    "ไม่พบประวัติการจองของ " + email);
                pnlEmpty.Visible = true;
                return;
            }

            rptBookings.DataSource = list;
            rptBookings.DataBind();
            pnlList.Visible = true;
            lblCount.Text = HttpUtility.HtmlEncode("พบ " + list.Count + " การจอง");
            lblCount.Visible = true;
        }

        private void ShowMsg(string message, bool isError)
        {
            lblError.Text = HttpUtility.HtmlEncode(message);
            pnlError.CssClass = isError ? "status warn" : "status ok";
            pnlError.Visible = true;
        }
    }
}
