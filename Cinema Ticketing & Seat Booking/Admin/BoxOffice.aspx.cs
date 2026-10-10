using System;
using System.Data;
using System.Globalization;
using System.Web.UI.WebControls;

namespace Cinema_Ticketing___Seat_Booking.AdminPages
{
    public partial class BoxOffice : AdminPage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (IsPostBack) return;
            try
            {
                ddlGenre.Items.Add(new ListItem("ทุกประเภท", ""));
                foreach (DataRow r in Repo.GetGenres().Rows) ddlGenre.Items.Add(Convert.ToString(r["genre"]));
                BindReport();
            }
            catch (BusinessException ex) { ShowError(ex); }
        }

        protected string Pct(object v)
        {
            decimal d = v == null || v == DBNull.Value ? 0m : Convert.ToDecimal(v);
            if (d < 0) d = 0; if (d > 100) d = 100;
            return d.ToString("0.##", CultureInfo.InvariantCulture);
        }

        void BindReport()
        {
            int top;
            if (!int.TryParse(ddlTop.SelectedValue, out top) || top < 1 || top > 500) top = 50;
            DataTable dt = Repo.BoxOffice(ddlGenre.SelectedValue, chkSold.Checked, top);
            rptReport.DataSource = dt;
            rptReport.DataBind();
            pnlEmpty.Visible = dt.Rows.Count == 0;
            rptReport.Visible = dt.Rows.Count > 0;

            long tickets = 0; decimal revenue = 0;
            foreach (DataRow r in dt.Rows) { tickets += Convert.ToInt64(r["tickets_sold"]); revenue += Convert.ToDecimal(r["total_revenue"]); }
            litCount.Text = dt.Rows.Count.ToString();
            litTickets.Text = tickets.ToString("N0", CultureInfo.InvariantCulture);
            litRevenue.Text = Fmt.Baht(revenue);
        }

        protected void btnApply_Click(object sender, EventArgs e)
        {
            try { BindReport(); }
            catch (BusinessException ex) { ShowError(ex); }
        }
    }
}
