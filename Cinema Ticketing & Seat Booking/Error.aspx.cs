using System;

namespace Cinema_Ticketing___Seat_Booking
{
    public partial class ErrorPage : BasePage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            Response.StatusCode = 500;
            Response.TrySkipIisCustomErrors = true;
        }
    }
}
