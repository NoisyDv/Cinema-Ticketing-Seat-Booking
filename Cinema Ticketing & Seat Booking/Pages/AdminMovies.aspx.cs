using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.UI.WebControls;
using Cinema_Ticketing___Seat_Booking.Data;
using Cinema_Ticketing___Seat_Booking.Models;

namespace Cinema_Ticketing___Seat_Booking.Pages
{
    public partial class AdminMovies : System.Web.UI.Page
    {
        private readonly MovieRepository _repo = new MovieRepository();

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!AdminAuth.RequireAdmin(this)) return;
            if (!IsPostBack)
                BindList();
        }

        protected void lnkLogout_Click(object sender, EventArgs e)
        {
            AdminAuth.SignOut(this);
            Response.Redirect("~/Pages/Movies.aspx", false);
        }

        protected void btnAddMovie_Click(object sender, EventArgs e)
        {
            string title = txtTitle.Text == null ? "" : txtTitle.Text.Trim();
            string genre = txtGenre.Text == null ? "" : txtGenre.Text.Trim();
            string desc = txtDesc.Text == null ? "" : txtDesc.Text.Trim();
            int duration;
            DateTime release;
            if (title.Length == 0 || title.Length > 200)
            {
                ShowMsg("กรุณากรอกชื่อเรื่อง (ไม่เกิน 200 ตัวอักษร)", true);
                return;
            }
            if (genre.Length == 0 || genre.Length > 50)
            {
                ShowMsg("กรุณากรอกประเภท (ไม่เกิน 50 ตัวอักษร)", true);
                return;
            }
            if (!int.TryParse((txtDuration.Text ?? "").Trim(), out duration) || duration <= 0)
            {
                ShowMsg("กรุณากรอกความยาวเป็นจำนวนเต็มนาทีที่มากกว่า 0", true);
                return;
            }
            if (!Validation.TryParseDate(txtRelease.Text, out release))
            {
                ShowMsg("กรุณากรอกวันเข้าฉายให้ถูกต้อง", true);
                return;
            }
            string status = ddlStatus.SelectedValue;
            if (status != "active" && status != "inactive")
            {
                ShowMsg("สถานะไม่ถูกต้อง", true);
                return;
            }

            // ตรวจไฟล์โปสเตอร์ (ไม่บังคับแนบ)
            string ext = null;
            if (fuPoster.HasFile)
            {
                ext = System.IO.Path.GetExtension(fuPoster.FileName).ToLowerInvariant();
                if (ext != ".webp" && ext != ".jpg" && ext != ".jpeg" && ext != ".png")
                {
                    ShowMsg("ไฟล์โปสเตอร์ต้องเป็น .webp / .jpg / .png เท่านั้น", true);
                    return;
                }
                if (fuPoster.PostedFile.ContentLength > 5 * 1024 * 1024)
                {
                    ShowMsg("ไฟล์โปสเตอร์ต้องไม่เกิน 5MB", true);
                    return;
                }
            }

            // ตั้งชื่อไฟล์เอง (กันชื่อซ้ำ + กัน path traversal) แล้วค่อย insert
            string posterPath = null;
            if (ext != null)
                posterPath = "Posters/movie_" + Guid.NewGuid().ToString("N").Substring(0, 8) + ext;

            int newId;
            try
            {
                newId = _repo.AdminAddMovie(title, desc.Length == 0 ? null : desc,
                    duration, genre, release, status, posterPath);
            }
            catch (InvalidOperationException)
            {
                ShowMsg("ข้อมูลหนังไม่ถูกต้อง กรุณาตรวจสอบแล้วลองใหม่", true);
                return;
            }
            catch
            {
                ShowMsg("เพิ่มหนังไม่สำเร็จ กรุณาลองใหม่", true);
                return;
            }

            if (posterPath != null)
            {
                try
                {
                    fuPoster.SaveAs(Server.MapPath("~/" + posterPath));
                }
                catch
                {
                    // เซฟไฟล์ไม่สำเร็จ: ลบแถวหนังที่เพิ่งสร้างทิ้ง ไม่ให้มีแถวค้างไร้รูป
                    DeleteMovieRow(newId);
                    ShowMsg("บันทึกไฟล์โปสเตอร์ไม่สำเร็จ กรุณาลองใหม่", true);
                    return;
                }
            }

            ClearForm();
            BindList();
            ShowMsg("เพิ่มหนัง #" + newId + " สำเร็จ", false);
        }

        // ลบแถวหนัง (ใช้ชดเชยเฉพาะตอนสร้างไม่สมบูรณ์ ไม่มีปุ่มลบให้ผู้ใช้)
        private static void DeleteMovieRow(int movieId)
        {
            try
            {
                using (SqlConnection conn = Db.Open())
                using (SqlCommand cmd = new SqlCommand(
                    "DELETE FROM movies WHERE movie_id = @id", conn))
                {
                    cmd.Parameters.Add("@id", SqlDbType.Int).Value = movieId;
                    cmd.ExecuteNonQuery();
                }
            }
            catch
            {
                // กลืนไว้: อย่างน้อยผู้ใช้เห็นข้อความหลักแล้ว
            }
        }

        private void ClearForm()
        {
            txtTitle.Text = "";
            txtGenre.Text = "";
            txtDuration.Text = "";
            txtRelease.Text = "";
            txtDesc.Text = "";
            ddlStatus.SelectedIndex = 0;
        }

        protected void btnToggle_Command(object sender, CommandEventArgs e)
        {
            int movieId;
            if (!int.TryParse(Convert.ToString(e.CommandArgument), out movieId) || movieId <= 0)
            {
                ShowMsg("รหัสหนังไม่ถูกต้อง", true);
                return;
            }

            try
            {
                _repo.AdminToggleMovie(movieId);
                BindList();
                ShowMsg("เปลี่ยนสถานะหนัง #" + movieId + " สำเร็จ", false);
            }
            catch
            {
                ShowMsg("เปลี่ยนสถานะไม่สำเร็จ กรุณาลองใหม่", true);
            }
        }

        private void BindList()
        {
            List<Movie> list;
            try
            {
                list = _repo.AdminGetMovies();
            }
            catch
            {
                ShowMsg("โหลดรายชื่อหนังไม่ได้ กรุณาลองใหม่", true);
                return;
            }

            rptMovies.DataSource = list;
            rptMovies.DataBind();
            pnlList.Visible = true;
            pnlEmpty.Visible = list.Count == 0;
        }

        private void ShowMsg(string message, bool isError)
        {
            lblMsg.Text = HttpUtility.HtmlEncode(message);
            pnlMsg.CssClass = isError ? "status warn" : "status ok";
            pnlMsg.Visible = true;
        }
    }
}
