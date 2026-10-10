using System;
using System.Data;

namespace Cinema_Ticketing___Seat_Booking
{
    public partial class Ticket : AuthPage
    {
        protected string MovieTitle = "", ShowText = "", HallName = "";

        protected void Page_Load(object sender, EventArgs e)
        {
            int? id = QueryInt("booking");
            if (!id.HasValue) { pnlMissing.Visible = true; return; }
            try
            {
                DataRow b = Repo.GetBooking(id.Value);
                // เจ้าของการจองหรือผู้ดูแลระบบเท่านั้น และต้องชำระแล้ว
                bool allowed = b != null && (Convert.ToInt32(b["customer_id"]) == CurrentUser.CustomerId || CurrentUser.IsAdmin);
                if (!allowed || Convert.ToString(b["booking_status"]) != "confirmed") { pnlMissing.Visible = true; return; }

                MovieTitle = Convert.ToString(b["title"]);
                ShowText = Fmt.Day(b["start_time"]) + " " + Fmt.Time(b["start_time"]);
                HallName = Convert.ToString(b["hall_name"]);
                litCode.Text = "BK" + id.Value.ToString("D6");
                litPaid.Text = Server.HtmlEncode(Fmt.DateTimeText(b["paid_at"]));
                litMethod.Text = Server.HtmlEncode(Fmt.PayMethodText(b["payment_method"]));
                litTotal.Text = Fmt.Baht(b["total_amount"]);

                DataTable all = Repo.GetBookingTickets(id.Value);
                DataView issued = new DataView(all, "ticket_status = 'issued'", "row_label, seat_number", DataViewRowState.CurrentRows);
                rptTickets.DataSource = issued;
                rptTickets.DataBind();
                pnlTickets.Visible = true;
            }
            catch (BusinessException ex)
            {
                ShowError(ex);
                pnlMissing.Visible = true;
            }
        }
    }
}
