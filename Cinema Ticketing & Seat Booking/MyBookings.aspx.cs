using System;
using System.Data;
using System.Web.UI.WebControls;

namespace Cinema_Ticketing___Seat_Booking
{
    public partial class MyBookings : AuthPage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack) BindData();
        }

        void BindData()
        {
            try
            {
                Repo.ReleaseExpiredHolds();
                DataTable dt = Repo.GetMyBookings(CurrentUser.CustomerId);
                rptBookings.DataSource = dt;
                rptBookings.DataBind();
                pnlEmpty.Visible = dt.Rows.Count == 0;
                rptBookings.Visible = dt.Rows.Count > 0;
            }
            catch (BusinessException ex)
            {
                ShowError(ex);
                pnlEmpty.Visible = true;
            }
        }

        /// <summary>รอชำระเงินและยังไม่หมดเวลา (นับจากเวลาเซิร์ฟเวอร์ที่ SQL คำนวณมา)</summary>
        protected bool IsOpenHold(object dataItem)
        {
            DataRowView r = (DataRowView)dataItem;
            return Convert.ToString(r["booking_status"]) == "pending" && Convert.ToInt32(r["seconds_left"]) > 0;
        }

        protected void rptBookings_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName != "cancel_hold") return;
            int id;
            if (!int.TryParse(Convert.ToString(e.CommandArgument), out id) || id <= 0) return;
            try
            {
                // sp_CancelHold ตรวจเจ้าของการจองและสถานะ pending ในฐานข้อมูลอีกชั้น
                bool released = Repo.CancelHold(id, CurrentUser.CustomerId);
                if (released) Flash.Ok("ยกเลิกการถือที่นั่งแล้ว ที่นั่งถูกปล่อยเรียบร้อย");
                else Flash.Error("ไม่สามารถยกเลิกได้ (อาจหมดเวลา ชำระแล้ว หรือไม่ใช่การจองของคุณ)");
            }
            catch (BusinessException ex) { ShowError(ex); }
            BindData();
        }
    }
}
