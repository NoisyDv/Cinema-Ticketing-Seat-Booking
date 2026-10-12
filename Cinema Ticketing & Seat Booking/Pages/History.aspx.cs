using System;
using System.Collections.Generic;
using System.Web;
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
            pnlList.Visible = false;
            pnlEmpty.Visible = false;
            lblCount.Visible = false;

            string email = txtEmail.Text == null ? "" : txtEmail.Text.Trim();
            if (!Validation.IsEmail(email))
            {
                ShowError("กรุณากรอกอีเมลให้ถูกต้อง");
                return;
            }

            List<BookingInfo> list;
            try
            {
                list = _repo.GetBookingsByEmail(email);
            }
            catch
            {
                ShowError("ค้นหาไม่สำเร็จ กรุณาลองใหม่อีกครั้ง");
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
            lblCount.Text = HttpUtility.HtmlEncode(
                "พบ " + list.Count + " การจอง");
            lblCount.Visible = true;
        }

        private void ShowError(string message)
        {
            lblError.Text = HttpUtility.HtmlEncode(message);
            pnlError.Visible = true;
        }
    }
}
