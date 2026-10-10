using System;
using System.Data;
using System.Globalization;
using System.Web.UI.WebControls;

namespace Cinema_Ticketing___Seat_Booking.AdminPages
{
    public partial class Promotions : AdminPage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack) BindGrid();
        }

        void BindGrid()
        {
            try
            {
                gv.DataSource = Repo.AdminListPromotions();
                gv.DataBind();
            }
            catch (BusinessException ex) { ShowError(ex); }
        }

        protected string DiscountText(object type, object value)
        {
            decimal v = Convert.ToDecimal(value);
            return Convert.ToString(type) == "percentage" ? v.ToString("0.##", CultureInfo.InvariantCulture) + "%" : Fmt.Baht(v);
        }

        protected void gv_PageIndexChanging(object sender, GridViewPageEventArgs e) { gv.PageIndex = e.NewPageIndex; BindGrid(); }

        protected void btnNew_Click(object sender, EventArgs e)
        {
            hfId.Value = "";
            txtCode.Text = ""; txtValue.Text = "";
            txtStart.Text = Fmt.ForDateInput(DateTime.Today);
            txtEnd.Text = Fmt.ForDateInput(DateTime.Today.AddMonths(1));
            ddlType.SelectedValue = "percentage"; ddlStatus.SelectedValue = "active";
            litFormTitle.Text = "เพิ่มโปรโมชัน";
            pnlForm.Visible = true;
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
                    DataRow p = Repo.GetPromotionRow(id);
                    if (p == null) { Flash.Error("ไม่พบโปรโมชันที่ต้องการแก้ไข"); BindGrid(); return; }
                    hfId.Value = id.ToString();
                    txtCode.Text = Convert.ToString(p["promotion_code"]);
                    ddlType.SelectedValue = Convert.ToString(p["discount_type"]);
                    txtValue.Text = Convert.ToDecimal(p["discount_value"]).ToString("0.##", CultureInfo.InvariantCulture);
                    txtStart.Text = Fmt.ForDateInput(Convert.ToDateTime(p["start_date"]));
                    txtEnd.Text = Fmt.ForDateInput(Convert.ToDateTime(p["end_date"]));
                    ddlStatus.SelectedValue = Convert.ToString(p["status"]);
                    litFormTitle.Text = "แก้ไขโปรโมชัน #" + id;
                    pnlForm.Visible = true;
                }
                else if (e.CommandName == "do_delete")
                {
                    Repo.DeletePromotion(id);
                    Flash.Ok("ลบโปรโมชันเรียบร้อยแล้ว");
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

            string code = Validation.Trim(txtCode.Text).ToUpperInvariant();
            string type = ddlType.SelectedValue, status = ddlStatus.SelectedValue;
            decimal value; DateTime start, end;
            if (!Validation.IsPromoCode(code)) { Flash.Error("โค้ดต้องเป็น A-Z 0-9 _ - ยาว 3-50 ตัว"); return; }
            if (type != "percentage" && type != "fixed") { Flash.Error("ประเภทส่วนลดไม่ถูกต้อง"); return; }
            if (!decimal.TryParse(txtValue.Text.Trim(), NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out value) || value <= 0) { Flash.Error("มูลค่าส่วนลดต้องมากกว่า 0"); return; }
            if (type == "percentage" && value > 100) { Flash.Error("ส่วนลดแบบเปอร์เซ็นต์ต้องไม่เกิน 100"); return; }
            if (!Fmt.TryParseDateInput(txtStart.Text, out start) || !Fmt.TryParseDateInput(txtEnd.Text, out end)) { Flash.Error("รูปแบบวันที่ไม่ถูกต้อง"); return; }
            if (end < start) { Flash.Error("วันสิ้นสุดต้องไม่ก่อนวันเริ่มใช้"); return; }
            if (status != "active" && status != "inactive") { Flash.Error("สถานะไม่ถูกต้อง"); return; }

            try
            {
                int id;
                if (int.TryParse(hfId.Value, out id) && id > 0)
                {
                    Repo.UpdatePromotion(id, code, type, value, start, end, status);
                    Flash.Ok("แก้ไขโปรโมชันเรียบร้อยแล้ว");
                }
                else
                {
                    Repo.InsertPromotion(code, type, value, start, end, status);
                    Flash.Ok("เพิ่มโปรโมชันเรียบร้อยแล้ว");
                }
                pnlForm.Visible = false;
                BindGrid();
            }
            catch (BusinessException ex)
            {
                // โค้ดซ้ำ (UNIQUE) จะได้ข้อความ "ข้อมูลนี้ซ้ำกับที่มีอยู่แล้ว"
                ShowError(ex);
            }
        }
    }
}
