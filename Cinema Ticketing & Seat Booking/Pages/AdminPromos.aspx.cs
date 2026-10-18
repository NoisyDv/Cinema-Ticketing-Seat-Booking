using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web;
using System.Web.UI.WebControls;
using Cinema_Ticketing___Seat_Booking.Data;
using Cinema_Ticketing___Seat_Booking.Models;

namespace Cinema_Ticketing___Seat_Booking.Pages
{
    public partial class AdminPromos : System.Web.UI.Page
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

        protected void btnCreate_Click(object sender, EventArgs e)
        {
            string code = txtCode.Text == null ? "" : txtCode.Text.Trim();
            string type = ddlType.SelectedValue;
            decimal value;
            DateTime start;
            DateTime end;
            if (!decimal.TryParse((txtValue.Text ?? "").Trim(),
                    NumberStyles.Number, CultureInfo.InvariantCulture, out value))
            {
                ShowMsg("กรุณากรอกค่าส่วนลดเป็นตัวเลข", true);
                return;
            }
            if (!Validation.TryParseDate(txtStart.Text, out start) || !Validation.TryParseDate(txtEnd.Text, out end))
            {
                ShowMsg("กรุณากรอกวันเริ่มและวันหมดเขตให้ถูกต้อง", true);
                return;
            }

            try
            {
                int newId = _repo.AdminCreatePromo(code, type, value, start, end);
                BindList();
                ShowMsg("เพิ่มโปรโมชัน #" + newId + " สำเร็จ", false);
            }
            catch (InvalidOperationException ex)
            {
                ShowMsg(MapCreateError(ex.Message), true);
            }
            catch
            {
                ShowMsg("เพิ่มโปรโมชันไม่สำเร็จ กรุณาลองใหม่", true);
            }
        }

        protected void btnToggle_Command(object sender, CommandEventArgs e)
        {
            int promoId;
            if (!int.TryParse(Convert.ToString(e.CommandArgument), out promoId) || promoId <= 0)
            {
                ShowMsg("รหัสโปรโมชันไม่ถูกต้อง", true);
                return;
            }

            try
            {
                _repo.AdminTogglePromo(promoId);
                BindList();
                ShowMsg("เปลี่ยนสถานะโปรโมชัน #" + promoId + " สำเร็จ", false);
            }
            catch
            {
                ShowMsg("เปลี่ยนสถานะไม่สำเร็จ กรุณาลองใหม่", true);
            }
        }

        private void BindList()
        {
            List<Promotion> list;
            try
            {
                list = _repo.AdminGetPromos();
            }
            catch
            {
                ShowMsg("โหลดโปรโมชันไม่ได้ กรุณาลองใหม่", true);
                return;
            }

            rptPromos.DataSource = list;
            rptPromos.DataBind();
            pnlList.Visible = true;
            pnlEmpty.Visible = list.Count == 0;
        }

        private static string MapCreateError(string code)
        {
            if (code == "BAD_CODE") return "กรุณากรอกรหัสโปรโมชัน (ไม่เกิน 50 ตัวอักษร)";
            if (code == "BAD_TYPE") return "ประเภทส่วนลดไม่ถูกต้อง";
            if (code == "BAD_VALUE") return "ค่าส่วนลดไม่ถูกต้อง (เปอร์เซ็นต์ 0-100, จำนวนเงินห้ามติดลบ)";
            if (code == "BAD_DATE") return "วันหมดเขตต้องไม่ก่อนวันเริ่ม";
            if (code == "DUP_CODE") return "รหัสนี้มีอยู่แล้ว";
            return "เพิ่มโปรโมชันไม่สำเร็จ กรุณาลองใหม่";
        }

        private void ShowMsg(string message, bool isError)
        {
            lblMsg.Text = HttpUtility.HtmlEncode(message);
            pnlMsg.CssClass = isError ? "status warn" : "status ok";
            pnlMsg.Visible = true;
        }
    }
}
