using System;
using System.Data;

namespace Cinema_Ticketing___Seat_Booking
{
    public partial class Login : BasePage
    {
        const int MaxFailures = 5;

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                if (Auth.Current != null) { Response.Redirect("~/Default.aspx", true); return; }
                if (Request.QueryString["out"] == "1") Flash.Ok("ออกจากระบบแล้ว");
                if (Request.QueryString["registered"] == "1") Flash.Ok("สมัครสมาชิกสำเร็จ กรุณาเข้าสู่ระบบ");
            }
        }

        protected void btnLogin_Click(object sender, EventArgs e)
        {
            if (!Page.IsValid) return;

            string email = Validation.Trim(txtEmail.Text).ToLowerInvariant();
            string password = txtPassword.Text ?? "";

            // ตรวจซ้ำฝั่งเซิร์ฟเวอร์ (ไม่เชื่อ validator ฝั่งไคลเอนต์)
            if (!Validation.IsEmail(email) || password.Length == 0 || password.Length > 64)
            {
                Flash.Error("อีเมลหรือรหัสผ่านไม่ถูกต้อง");
                return;
            }

            // ชะลอการเดารหัส: ผิดเกิน 5 ครั้งใน session เดียวกัน ต้องรอ 60 วินาที
            DateTime? lockedUntil = Session["login_lock"] as DateTime?;
            if (lockedUntil.HasValue && lockedUntil.Value > DateTime.UtcNow)
            {
                Flash.Error("พยายามเข้าสู่ระบบผิดหลายครั้ง กรุณารอสักครู่แล้วลองใหม่");
                return;
            }

            try
            {
                DataRow row = Repo.GetLoginInfo(email);
                bool ok = false;
                if (row == null || row["password_hash"] == DBNull.Value)
                    PasswordHasher.DummyVerify();
                else
                    ok = PasswordHasher.Verify(password, Convert.ToString(row["password_hash"]));

                if (!ok)
                {
                    int fails = (Session["login_fail"] as int? ?? 0) + 1;
                    Session["login_fail"] = fails;
                    if (fails >= MaxFailures) { Session["login_lock"] = DateTime.UtcNow.AddSeconds(60); Session["login_fail"] = 0; }
                    Flash.Error("อีเมลหรือรหัสผ่านไม่ถูกต้อง");
                    return;
                }

                int id = Convert.ToInt32(row["customer_id"]);
                Auth.SignIn(new UserSession { CustomerId = id, Name = Convert.ToString(row["name"]), Role = Convert.ToString(row["user_role"]) });
                Repo.RecordLogin(id);
                string dest = Auth.SafeLocalUrl(Request.QueryString["returnUrl"], "~/Default.aspx");
                Response.Redirect(dest, false);
                Context.ApplicationInstance.CompleteRequest();
            }
            catch (BusinessException ex)
            {
                ShowError(ex);
            }
        }
    }
}
