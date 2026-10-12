using System;
using System.Collections.Generic;
using System.Web;
using Cinema_Ticketing___Seat_Booking.Data;
using Cinema_Ticketing___Seat_Booking.Models;

namespace Cinema_Ticketing___Seat_Booking.Pages
{
    public partial class Dashboard : System.Web.UI.Page
    {
        private readonly MovieRepository _repo = new MovieRepository();

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
                LoadReport();
        }

        private void LoadReport()
        {
            List<BoxOfficeRow> rows;
            try
            {
                rows = _repo.GetBoxOfficeReport();
            }
            catch
            {
                ShowError("โหลดรายงานไม่ได้ กรุณาตรวจว่ารัน Database/logic.sql แล้วลองใหม่");
                return;
            }

            decimal revenue = 0m;
            long tickets = 0;
            long shows = 0;
            foreach (BoxOfficeRow r in rows)
            {
                revenue += r.TotalRevenue;
                tickets += r.TicketsSold;
                shows += r.TotalShowtimes;
            }

            litRevenue.Text = HttpUtility.HtmlEncode(revenue.ToString("N2"));
            litTickets.Text = HttpUtility.HtmlEncode(tickets.ToString("N0"));
            litShows.Text = HttpUtility.HtmlEncode(shows.ToString("N0"));

            rptReport.DataSource = rows;
            rptReport.DataBind();
            pnlReport.Visible = true;
        }

        private void ShowError(string message)
        {
            lblError.Text = HttpUtility.HtmlEncode(message);
            pnlError.Visible = true;
        }
    }
}
