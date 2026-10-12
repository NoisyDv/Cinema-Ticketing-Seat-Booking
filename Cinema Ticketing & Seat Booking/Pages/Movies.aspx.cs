using System;
using Cinema_Ticketing___Seat_Booking.Data;

namespace Cinema_Ticketing___Seat_Booking.Pages
{
    public partial class Movies : System.Web.UI.Page
    {
        private readonly MovieRepository _repo = new MovieRepository();

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                BindGenres();
                BindMovies();
            }
        }

        protected void btnSearch_Click(object sender, EventArgs e)
        {
            BindMovies();
        }

        // แปลงค่า poster_url จาก DB (เช่น "Posters/Avatar.webp")
        // ให้เป็น URL ที่เบราว์เซอร์ขอได้จริง + encode ช่องว่าง/อักขระพิเศษ
        // (logic กลางอยู่ที่ Data/PosterHelper ใช้ร่วมกับหน้าอื่น)
        protected string ResolvePosterUrl(string posterUrl)
        {
            return PosterHelper.ResolvePosterUrl(this, posterUrl);
        }

        private void BindGenres()
        {
            ddlGenre.Items.Clear();
            ddlGenre.Items.Add("ทั้งหมด");
            foreach (var g in _repo.GetGenres())
                ddlGenre.Items.Add(g);
        }

        private void BindMovies()
        {
            string genre = ddlGenre.SelectedValue == "ทั้งหมด" ? null : ddlGenre.SelectedValue;
            bool fromDb;
            string status;
            var movies = _repo.GetMovies(genre, txtSearch.Text, out fromDb, out status);

            rptMovies.DataSource = movies;
            rptMovies.DataBind();

            lblStatus.Text = status;
            pnlStatus.CssClass = fromDb ? "status ok" : "status warn";
            lblCount.Text = string.Format("พบ {0} เรื่อง", movies.Count);
            pnlEmpty.Visible = movies.Count == 0;
        }
    }
}
