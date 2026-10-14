using System;
using System.Web;
using Cinema_Ticketing___Seat_Booking.Data;

namespace Cinema_Ticketing___Seat_Booking.Pages
{
    public partial class AdminLogin : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack && AdminAuth.IsAdmin(this))
                Response.Redirect("~/Pages/AdminShowtimes.aspx", false);
        }

        protected void btnLogin_Click(object sender, EventArgs e)
        {
            if (AdminAuth.CheckPasscode(txtPasscode.Text))
            {
                AdminAuth.SignIn(this);
                Response.Redirect("~/Pages/AdminShowtimes.aspx", false);
            }
            else
            {
                lblError.Text = HttpUtility.HtmlEncode("รหัสไม่ถูกต้อง");
                pnlError.Visible = true;
            }
        }
    }
}
