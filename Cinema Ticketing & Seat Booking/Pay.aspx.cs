using System;
using System.Data;

namespace Cinema_Ticketing___Seat_Booking
{
    public partial class Pay : AuthPage
    {
        int bookingId;
        protected int SecondsLeft = 0;

        protected void Page_Load(object sender, EventArgs e)
        {
            int? id = QueryInt("booking");
            if (!id.HasValue) { pnlMissing.Visible = true; return; }
            bookingId = id.Value;
            if (!IsPostBack) LoadBooking(null);
        }

        /// <summary>โหลดการจอง: แสดงฟอร์มชำระเงินเมื่อ pending และยังไม่หมดเวลา มิฉะนั้นแสดงสถานะที่เหมาะสม</summary>
        void LoadBooking(DataRow previewPromo)
        {
            pnlPay.Visible = false; pnlClosed.Visible = false; pnlMissing.Visible = false;
            try
            {
                Repo.ReleaseExpiredHolds();
                DataRow b = Repo.GetBooking(bookingId);
                // เป็นเจ้าของการจองเท่านั้น (admin ก็ชำระแทนผู้อื่นไม่ได้)
                if (b == null || Convert.ToInt32(b["customer_id"]) != CurrentUser.CustomerId) { pnlMissing.Visible = true; return; }

                string status = Convert.ToString(b["booking_status"]);
                int left = Convert.ToInt32(b["seconds_left"]);
                if (status == "confirmed") { Response.Redirect("~/Ticket.aspx?booking=" + bookingId, true); return; }
                if (status != "pending" || left <= 0)
                {
                    pnlClosed.Visible = true;
                    litClosedTitle.Text = status == "cancelled" ? "การจองนี้ถูกยกเลิกแล้ว" : "หมดเวลาถือที่นั่งแล้ว";
                    litClosedText.Text = status == "cancelled" ? "ที่นั่งถูกปล่อยแล้ว หากต้องการดูหนังเรื่องนี้ กรุณาเลือกที่นั่งใหม่" : "ที่นั่งถูกปล่อยให้ผู้อื่นแล้ว กรุณาเลือกที่นั่งใหม่";
                    return;
                }

                SecondsLeft = left;
                litMovie.Text = Server.HtmlEncode(Convert.ToString(b["title"]));
                litShow.Text = Server.HtmlEncode(Fmt.Day(b["start_time"]) + " " + Fmt.Time(b["start_time"]));
                litHall.Text = Server.HtmlEncode(Convert.ToString(b["hall_name"]));
                DataTable tickets = Repo.GetBookingTickets(bookingId);
                string[] labels = new string[tickets.Rows.Count];
                for (int i = 0; i < labels.Length; i++) labels[i] = Convert.ToString(tickets.Rows[i]["seat_label"]);
                litSeats.Text = Server.HtmlEncode(string.Join(", ", labels));

                decimal subtotal = Convert.ToDecimal(b["subtotal"]);
                decimal total = Convert.ToDecimal(b["total_amount"]);
                if (previewPromo != null) total = Convert.ToDecimal(previewPromo["new_total"]);
                litSubtotal.Text = Fmt.Baht(subtotal);
                litDiscount.Text = subtotal - total > 0 ? "−" + Fmt.Baht(subtotal - total) : "-";
                litTotal.Text = Fmt.Baht(total);
                pnlPay.Visible = true;
            }
            catch (BusinessException ex)
            {
                ShowError(ex);
                pnlMissing.Visible = true;
            }
        }

        protected void btnCheckPromo_Click(object sender, EventArgs e)
        {
            if (!Page.IsValid) { LoadBooking(null); return; }
            string code = Validation.Trim(txtPromo.Text);
            DataRow preview = null;
            lblPromoMsg.Text = "";
            if (code.Length > 0)
            {
                if (!Validation.IsPromoCode(code)) { lblPromoMsg.Text = "รูปแบบโค้ดไม่ถูกต้อง"; lblPromoMsg.CssClass = "msg err"; }
                else
                {
                    try
                    {
                        preview = Repo.PreviewPromotion(bookingId, code);
                        if (preview == null) { lblPromoMsg.Text = "โค้ดไม่ถูกต้อง หมดอายุ หรือยังไม่เริ่มใช้งาน"; lblPromoMsg.CssClass = "msg err"; }
                        else { lblPromoMsg.Text = "ใช้โค้ด " + Server.HtmlEncode(code.ToUpperInvariant()) + " ได้ — ยอดใหม่แสดงที่ด้านขวา"; lblPromoMsg.CssClass = "msg ok"; }
                    }
                    catch (BusinessException ex) { ShowError(ex); }
                }
            }
            LoadBooking(preview);
        }

        protected void btnPay_Click(object sender, EventArgs e)
        {
            if (!Page.IsValid) { LoadBooking(null); return; }

            string method = rblMethod.SelectedValue;
            string code = Validation.Trim(txtPromo.Text);
            if (method != "online" && method != "card" && method != "cash") { Flash.Error("ช่องทางชำระเงินไม่ถูกต้อง"); LoadBooking(null); return; }
            if (code.Length > 0 && !Validation.IsPromoCode(code)) { Flash.Error("รูปแบบโค้ดโปรโมชันไม่ถูกต้อง"); LoadBooking(null); return; }

            try
            {
                Repo.ConfirmPayment(bookingId, CurrentUser.CustomerId, method, code.Length == 0 ? null : code);
                Flash.Ok("ชำระเงินสำเร็จ ออกตั๋วเรียบร้อยแล้ว");
                Response.Redirect("~/Ticket.aspx?booking=" + bookingId, false);
                Context.ApplicationInstance.CompleteRequest();
            }
            catch (BusinessException ex)
            {
                // เช่น 50011 หมดเวลา, 50003 โปรโมชันหมดอายุ, 50012 ชำระไปแล้ว: แสดงข้อความและโหลดสถานะล่าสุด
                ShowError(ex);
                LoadBooking(null);
            }
        }

        protected void btnCancel_Click(object sender, EventArgs e)
        {
            try
            {
                bool released = Repo.CancelHold(bookingId, CurrentUser.CustomerId);
                Flash.Ok(released ? "ยกเลิกการถือที่นั่งแล้ว ที่นั่งถูกปล่อยเรียบร้อย" : "ไม่พบรายการที่ยกเลิกได้ (อาจหมดเวลาหรือชำระไปแล้ว)");
                Response.Redirect("~/MyBookings.aspx", false);
                Context.ApplicationInstance.CompleteRequest();
            }
            catch (BusinessException ex)
            {
                ShowError(ex);
                LoadBooking(null);
            }
        }
    }
}
