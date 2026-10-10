using System;
using System.Data;

namespace Cinema_Ticketing___Seat_Booking.AdminPages
{
    public partial class AdminHome : AdminPage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            try
            {
                Repo.ReleaseExpiredHolds();
                DataRow r = Repo.DashboardStats();
                litMovies.Text = Convert.ToString(r["active_movies"]);
                litShows.Text = Convert.ToString(r["upcoming_showtimes"]);
                litTickets.Text = Convert.ToInt32(r["tickets_sold"]).ToString("N0");
                litRevenue.Text = Fmt.Baht(r["revenue"]);
                litHolds.Text = Convert.ToString(r["open_holds"]);
            }
            catch (BusinessException ex) { ShowError(ex); }
        }
    }
}
