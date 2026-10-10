using System;

namespace Cinema_Ticketing___Seat_Booking
{
    public partial class Register : BasePage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack && Auth.Current != null) Response.Redirect("~/Default.aspx", true);
        }

        protected void btnRegister_Click(object sender, EventArgs e)
        {
            if (!Page.IsValid) return;

            string name = Validation.Trim(txtName.Text);
            string email = Validation.Trim(txtEmail.Text).ToLowerInvariant();
            string phone = Validation.Trim(txtPhone.Text);
            string password = txtPassword.Text ?? "";

            // ตรวจซ้ำฝั่งเซิร์ฟเวอร์ (กรณีปิด JavaScript หรือส่งคำขอตรง)
            if (name.Length < 2 || name.Length > 150) { Flash.Error("ชื่อต้องยาว 2-150 ตัวอักษร"); return; }
            if (!Validation.IsEmail(email)) { Flash.Error("รูปแบบอีเมลไม่ถูกต้อง"); return; }
            if (!Validation.IsPhone(phone)) { Flash.Error("เบอร์โทรต้องเป็นตัวเลข 9-15 หลัก"); return; }
            if (!Validation.IsStrongPassword(password)) { Flash.Error("รหัสผ่านต้องยาว 8-64 ตัว และมีทั้งตัวอักษรและตัวเลข"); return; }
            if (password != txtConfirm.Text) { Flash.Error("รหัสผ่านทั้งสองช่องไม่ตรงกัน"); return; }

            try
            {
                // แฮช PBKDF2 ฝั่ง C# แล้วส่งเฉพาะค่าแฮชไปฐานข้อมูล (ฐานข้อมูลไม่เคยเห็นรหัสผ่านจริง)
                Repo.Register(name, email, phone, PasswordHasher.Hash(password));
                Response.Redirect("~/Login.aspx?registered=1", false);
                Context.ApplicationInstance.CompleteRequest();
            }
            catch (BusinessException ex)
            {
                ShowError(ex);
            }
        }
    }
}
