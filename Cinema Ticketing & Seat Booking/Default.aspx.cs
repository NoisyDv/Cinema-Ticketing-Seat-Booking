using System;
using System.Data;
using System.Text;

namespace Cinema_Ticketing___Seat_Booking
{
    public partial class _Default : BasePage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            try
            {
                Repo.ReleaseExpiredHolds();
                DataTable genres = Repo.GetGenresNowShowing();
                string genre = Request.QueryString["genre"];
                bool valid = false;
                StringBuilder sb = new StringBuilder();
                foreach (DataRow r in genres.Rows) if (Convert.ToString(r["genre"]) == genre) valid = true;
                if (!valid) genre = null;

                sb.Append(Chip("ทั้งหมด", null, genre == null));
                foreach (DataRow r in genres.Rows)
                {
                    string g = Convert.ToString(r["genre"]);
                    sb.Append(Chip(g, g, g == genre));
                }
                litGenres.Text = sb.ToString();

                DataTable movies = Repo.GetNowShowing(genre);
                rptMovies.DataSource = movies;
                rptMovies.DataBind();
                pnlEmpty.Visible = movies.Rows.Count == 0;
            }
            catch (BusinessException ex)
            {
                ShowError(ex);
                pnlEmpty.Visible = true;
            }
        }

        string Chip(string label, string genre, bool pressed)
        {
            string url = ResolveUrl("~/Default.aspx") + (genre == null ? "" : "?genre=" + Server.UrlEncode(genre));
            return "<a class=\"chip\" aria-pressed=\"" + (pressed ? "true" : "false") + "\" href=\"" + Server.HtmlEncode(url) + "\">" + Server.HtmlEncode(label) + "</a> ";
        }
    }
}
