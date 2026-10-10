using System;
using System.Data;
using System.Web.UI.WebControls;

namespace Cinema_Ticketing___Seat_Booking.AdminPages
{
    public partial class Movies : AdminPage
    {
        static readonly string[] Genres = { "Action", "Animation", "Comedy", "Documentary", "Drama", "Fantasy", "Horror", "Romance", "Sci-Fi", "Thriller" };

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                ddlGenre.DataSource = Genres;
                ddlGenre.DataBind();
                BindGrid();
            }
        }

        void BindGrid()
        {
            try
            {
                gv.DataSource = Repo.AdminListMovies(txtSearch.Text, ddlFilter.SelectedValue);
                gv.DataBind();
            }
            catch (BusinessException ex) { ShowError(ex); }
        }

        protected void btnSearch_Click(object sender, EventArgs e) { gv.PageIndex = 0; BindGrid(); }

        protected void gv_PageIndexChanging(object sender, GridViewPageEventArgs e) { gv.PageIndex = e.NewPageIndex; BindGrid(); }

        void ShowForm(bool isNew)
        {
            pnlForm.Visible = true;
            litFormTitle.Text = isNew ? "เพิ่มภาพยนตร์" : "แก้ไขภาพยนตร์";
        }

        void ClearForm()
        {
            hfId.Value = "";
            txtTitle.Text = ""; txtDesc.Text = ""; txtPoster.Text = ""; txtDuration.Text = "";
            txtRelease.Text = Fmt.ForDateInput(DateTime.Today);
            ddlGenre.SelectedIndex = 0; ddlStatus.SelectedValue = "active";
        }

        protected void btnNew_Click(object sender, EventArgs e) { ClearForm(); ShowForm(true); }

        protected void btnCancelEdit_Click(object sender, EventArgs e) { pnlForm.Visible = false; }

        protected void gv_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            int id;
            if (!int.TryParse(Convert.ToString(e.CommandArgument), out id) || id <= 0) return;
            try
            {
                if (e.CommandName == "do_edit")
                {
                    DataRow m = Repo.GetMovie(id);
                    if (m == null) { Flash.Error("ไม่พบภาพยนตร์ที่ต้องการแก้ไข"); BindGrid(); return; }
                    hfId.Value = id.ToString();
                    txtTitle.Text = Convert.ToString(m["title"]);
                    txtDesc.Text = m["description"] == DBNull.Value ? "" : Convert.ToString(m["description"]);
                    txtPoster.Text = m["poster_url"] == DBNull.Value ? "" : Convert.ToString(m["poster_url"]);
                    txtDuration.Text = Convert.ToString(m["duration"]);
                    txtRelease.Text = Fmt.ForDateInput(Convert.ToDateTime(m["release_date"]));
                    string g = Convert.ToString(m["genre"]);
                    if (ddlGenre.Items.FindByValue(g) == null) ddlGenre.Items.Add(g);
                    ddlGenre.SelectedValue = g;
                    ddlStatus.SelectedValue = Convert.ToString(m["status"]);
                    ShowForm(false);
                }
                else if (e.CommandName == "do_delete")
                {
                    Repo.DeleteMovie(id);
                    Flash.Ok("ลบภาพยนตร์เรียบร้อยแล้ว");
                    if (hfId.Value == id.ToString()) pnlForm.Visible = false;
                    BindGrid();
                }
            }
            catch (BusinessException ex) { ShowError(ex); }
        }

        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (!Page.IsValid) { pnlForm.Visible = true; return; }

            // ตรวจซ้ำฝั่งเซิร์ฟเวอร์
            string title = Validation.Trim(txtTitle.Text);
            string desc = Validation.Trim(txtDesc.Text);
            string poster = Validation.Trim(txtPoster.Text);
            int duration; DateTime release;
            string status = ddlStatus.SelectedValue;
            string genre = ddlGenre.SelectedValue;
            string err = null;
            if (title.Length == 0 || title.Length > 200) err = "ชื่อภาพยนตร์ต้องยาว 1-200 ตัวอักษร";
            else if (desc.Length > 2000) err = "เรื่องย่อยาวได้ไม่เกิน 2000 ตัวอักษร";
            else if (!int.TryParse(txtDuration.Text, out duration) || duration < 1 || duration > 600) err = "ความยาวต้องเป็นจำนวนเต็ม 1-600 นาที";
            else if (!Fmt.TryParseDateInput(txtRelease.Text, out release)) err = "วันเข้าฉายไม่ถูกต้อง";
            else if (poster.Length > 0 && !Validation.IsHttpUrl(poster)) err = "ลิงก์โปสเตอร์ต้องเป็น http/https";
            else if (status != "active" && status != "inactive") err = "สถานะไม่ถูกต้อง";
            if (err != null) { Flash.Error(err); pnlForm.Visible = true; return; }

            duration = int.Parse(txtDuration.Text);
            Fmt.TryParseDateInput(txtRelease.Text, out release);
            try
            {
                int id;
                if (int.TryParse(hfId.Value, out id) && id > 0)
                {
                    Repo.UpdateMovie(id, title, desc.Length == 0 ? null : desc, duration, genre, release, status, poster.Length == 0 ? null : poster);
                    Flash.Ok("แก้ไขภาพยนตร์เรียบร้อยแล้ว");
                }
                else
                {
                    Repo.InsertMovie(title, desc.Length == 0 ? null : desc, duration, genre, release, status, poster.Length == 0 ? null : poster);
                    Flash.Ok("เพิ่มภาพยนตร์เรียบร้อยแล้ว");
                }
                pnlForm.Visible = false;
                BindGrid();
            }
            catch (BusinessException ex) { ShowError(ex); pnlForm.Visible = true; }
        }
    }
}
