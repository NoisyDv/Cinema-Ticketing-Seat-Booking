using System;
using System.Collections.Generic;
using System.Web;
using Cinema_Ticketing___Seat_Booking.Data;
using Cinema_Ticketing___Seat_Booking.Models;

namespace Cinema_Ticketing___Seat_Booking.Pages
{
    public partial class MovieDetails : System.Web.UI.Page
    {
        private readonly MovieRepository _repo = new MovieRepository();

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
                LoadData();
        }

        private void LoadData()
        {
            int movieId;
            if (!int.TryParse(Request.QueryString["movie_id"], out movieId) || movieId <= 0)
            {
                ShowError("ระบุรหัสหนังไม่ถูกต้อง");
                return;
            }

            Movie movie;
            List<Showtime> shows = new List<Showtime>();
            try
            {
                movie = _repo.GetMovie(movieId);
                if (movie != null)
                {
                    try { shows = _repo.GetShowtimes(movieId); }
                    catch { shows = new List<Showtime>(); }
                }
            }
            catch
            {
                ShowError("โหลดข้อมูลไม่ได้ กรุณาลองใหม่อีกครั้ง");
                return;
            }

            if (movie == null)
            {
                ShowError("ไม่พบหนังเรื่องนี้");
                return;
            }

            Page.Title = movie.Title + " | Cinema Ticketing";
            litTitle.Text = HttpUtility.HtmlEncode(movie.Title);
            litBadges.Text = string.Format(
                "<span class=\"chip\">{0}</span> <span class=\"chip\">{1}</span>",
                HttpUtility.HtmlEncode(movie.Genre),
                HttpUtility.HtmlEncode(movie.DisplayDuration));
            litMeta.Text = HttpUtility.HtmlEncode(
                "ฉาย " + movie.ReleaseDate.ToString("dd MMM yyyy"));
            litDescription.Text = HttpUtility.HtmlEncode(
                string.IsNullOrWhiteSpace(movie.Description) ? "ไม่มีรายละเอียด" : movie.Description);
            imgPoster.ImageUrl = PosterHelper.ResolvePosterUrl(this, movie.PosterUrl);
            imgPoster.AlternateText = "โปสเตอร์ " + movie.Title;

            rptShowtimes.DataSource = shows;
            rptShowtimes.DataBind();
            pnlShows.Visible = shows.Count > 0;
            pnlEmpty.Visible = shows.Count == 0;
            pnlMovie.Visible = true;
        }

        private void ShowError(string message)
        {
            pnlMovie.Visible = false;
            lblError.Text = HttpUtility.HtmlEncode(message);
            pnlError.Visible = true;
        }
    }
}
