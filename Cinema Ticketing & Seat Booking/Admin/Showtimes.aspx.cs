using System;
using System.Data;
using System.Globalization;
using System.Web.UI.WebControls;

namespace Cinema_Ticketing___Seat_Booking.AdminPages
{
    public partial class Showtimes : AdminPage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack) BindGrid();
        }

        void BindGrid()
        {
            try
            {
                gv.DataSource = Repo.AdminListShowtimes(ddlFilter.SelectedValue);
                gv.DataBind();
            }
            catch (BusinessException ex) { ShowError(ex); }
        }

        protected void ddlFilter_SelectedIndexChanged(object sender, EventArgs e) { gv.PageIndex = 0; BindGrid(); }
        protected void gv_PageIndexChanging(object sender, GridViewPageEventArgs e) { gv.PageIndex = e.NewPageIndex; BindGrid(); }

        void BindSelects(int? movieId, int? hallId)
        {
            ddlMovie.DataSource = Repo.ListMoviesForSelect(movieId);
            ddlMovie.DataBind();
            ddlHall.DataSource = Repo.ListHallsForSelect(hallId);
            ddlHall.DataBind();
        }

        protected void btnNew_Click(object sender, EventArgs e)
        {
            try
            {
                BindSelects(null, null);
                hfId.Value = "";
                DateTime d = DateTime.Today.AddDays(1).AddHours(10);
                txtStart.Text = Fmt.ForDateTimeInput(d);
                txtEnd.Text = "";
                txtPrice.Text = "200";
                ddlStatus.SelectedValue = "scheduled";
                litFormTitle.Text = "เพิ่มรอบฉาย";
                pnlForm.Visible = true;
            }
            catch (BusinessException ex) { ShowError(ex); }
        }

        protected void btnCancelEdit_Click(object sender, EventArgs e) { pnlForm.Visible = false; }

        protected void gv_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            int id;
            if (!int.TryParse(Convert.ToString(e.CommandArgument), out id) || id <= 0) return;
            try
            {
                if (e.CommandName == "do_edit")
                {
                    DataRow s = Repo.GetShowtimeRow(id);
                    if (s == null) { Flash.Error("ไม่พบรอบฉายที่ต้องการแก้ไข"); BindGrid(); return; }
                    int movieId = Convert.ToInt32(s["movie_id"]), hallId = Convert.ToInt32(s["hall_id"]);
                    BindSelects(movieId, hallId);
                    hfId.Value = id.ToString();
                    ddlMovie.SelectedValue = movieId.ToString();
                    ddlHall.SelectedValue = hallId.ToString();
                    txtStart.Text = Fmt.ForDateTimeInput(Convert.ToDateTime(s["start_time"]));
                    txtEnd.Text = Fmt.ForDateTimeInput(Convert.ToDateTime(s["end_time"]));
                    txtPrice.Text = Convert.ToDecimal(s["ticket_price"]).ToString("0.##", CultureInfo.InvariantCulture);
                    ddlStatus.SelectedValue = Convert.ToString(s["status"]);
                    litFormTitle.Text = "แก้ไขรอบฉาย #" + id;
                    pnlForm.Visible = true;
                }
                else if (e.CommandName == "do_delete")
                {
                    Repo.DeleteShowtime(id);
                    Flash.Ok("ลบรอบฉายเรียบร้อยแล้ว");
                    if (hfId.Value == id.ToString()) pnlForm.Visible = false;
                    BindGrid();
                }
            }
            catch (BusinessException ex) { ShowError(ex); }
        }

        protected void btnSave_Click(object sender, EventArgs e)
        {
            pnlForm.Visible = true;
            if (!Page.IsValid) return;

            int movieId, hallId; DateTime start, end; decimal price;
            string status = ddlStatus.SelectedValue;
            if (!int.TryParse(ddlMovie.SelectedValue, out movieId) || !int.TryParse(ddlHall.SelectedValue, out hallId)) { Flash.Error("กรุณาเลือกภาพยนตร์และโรง"); return; }
            if (!Fmt.TryParseDateTimeInput(txtStart.Text, out start)) { Flash.Error("เวลาเริ่มฉายไม่ถูกต้อง"); return; }
            if (!decimal.TryParse(txtPrice.Text.Trim(), NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out price) || price < 0 || price > 99999) { Flash.Error("ราคาตั๋วไม่ถูกต้อง"); return; }
            if (status != "scheduled" && status != "completed" && status != "cancelled") { Flash.Error("สถานะไม่ถูกต้อง"); return; }

            try
            {
                if (string.IsNullOrWhiteSpace(txtEnd.Text))
                {
                    DataRow m = Repo.GetMovie(movieId);
                    if (m == null) { Flash.Error("ไม่พบภาพยนตร์ที่เลือก"); return; }
                    end = start.AddMinutes(Convert.ToInt32(m["duration"]) + 15);
                }
                else if (!Fmt.TryParseDateTimeInput(txtEnd.Text, out end)) { Flash.Error("เวลาจบไม่ถูกต้อง"); return; }

                if (end <= start) { Flash.Error("เวลาจบต้องหลังเวลาเริ่มฉาย"); return; }
                if ((end - start).TotalHours > 12) { Flash.Error("รอบฉายยาวเกิน 12 ชั่วโมง กรุณาตรวจสอบเวลา"); return; }

                int id;
                if (int.TryParse(hfId.Value, out id) && id > 0)
                {
                    Repo.UpdateShowtime(id, movieId, hallId, start, end, price, status);
                    Flash.Ok("แก้ไขรอบฉายเรียบร้อยแล้ว");
                }
                else
                {
                    Repo.InsertShowtime(movieId, hallId, start, end, price, status);
                    Flash.Ok("เพิ่มรอบฉายเรียบร้อยแล้ว");
                }
                pnlForm.Visible = false;
                BindGrid();
            }
            catch (BusinessException ex)
            {
                // รวมกรณีรอบทับซ้อน (50030) ที่ trigger ส่งข้อความภาษาไทยมาให้
                ShowError(ex);
            }
        }
    }
}
