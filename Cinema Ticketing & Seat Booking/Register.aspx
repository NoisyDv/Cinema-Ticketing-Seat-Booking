<%@ Page Title="สมัครสมาชิก" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Register.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.Register" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <div class="form-narrow card">
        <h1>สมัครสมาชิก</h1>
        <asp:ValidationSummary ID="vsReg" runat="server" ValidationGroup="reg" CssClass="alert err" HeaderText="กรุณาแก้ไขข้อมูลต่อไปนี้" />

        <asp:Label ID="lblName" runat="server" AssociatedControlID="txtName" Text="ชื่อ-นามสกุล"></asp:Label>
        <asp:TextBox ID="txtName" runat="server" MaxLength="150" autocomplete="name"></asp:TextBox>
        <asp:RequiredFieldValidator ID="rfvName" runat="server" ControlToValidate="txtName" ValidationGroup="reg" Display="Dynamic" CssClass="field-err" ErrorMessage="กรุณากรอกชื่อ-นามสกุล" Text="กรุณากรอกชื่อ-นามสกุล"></asp:RequiredFieldValidator>
        <asp:RegularExpressionValidator ID="revName" runat="server" ControlToValidate="txtName" ValidationGroup="reg" Display="Dynamic" CssClass="field-err" ValidationExpression="^.{2,150}$" ErrorMessage="ชื่อต้องยาว 2-150 ตัวอักษร" Text="ชื่อต้องยาว 2-150 ตัวอักษร"></asp:RegularExpressionValidator>

        <asp:Label ID="lblEmail" runat="server" AssociatedControlID="txtEmail" Text="อีเมล"></asp:Label>
        <asp:TextBox ID="txtEmail" runat="server" TextMode="Email" MaxLength="255" autocomplete="email"></asp:TextBox>
        <asp:RequiredFieldValidator ID="rfvEmail" runat="server" ControlToValidate="txtEmail" ValidationGroup="reg" Display="Dynamic" CssClass="field-err" ErrorMessage="กรุณากรอกอีเมล" Text="กรุณากรอกอีเมล"></asp:RequiredFieldValidator>
        <asp:RegularExpressionValidator ID="revEmail" runat="server" ControlToValidate="txtEmail" ValidationGroup="reg" Display="Dynamic" CssClass="field-err" ValidationExpression="^[^\s@]+@[^\s@]+\.[^\s@]+$" ErrorMessage="รูปแบบอีเมลไม่ถูกต้อง" Text="รูปแบบอีเมลไม่ถูกต้อง"></asp:RegularExpressionValidator>

        <asp:Label ID="lblPhone" runat="server" AssociatedControlID="txtPhone" Text="เบอร์โทรศัพท์ (ตัวเลข 9-15 หลัก)"></asp:Label>
        <asp:TextBox ID="txtPhone" runat="server" TextMode="Phone" MaxLength="15" autocomplete="tel"></asp:TextBox>
        <asp:RequiredFieldValidator ID="rfvPhone" runat="server" ControlToValidate="txtPhone" ValidationGroup="reg" Display="Dynamic" CssClass="field-err" ErrorMessage="กรุณากรอกเบอร์โทรศัพท์" Text="กรุณากรอกเบอร์โทรศัพท์"></asp:RequiredFieldValidator>
        <asp:RegularExpressionValidator ID="revPhone" runat="server" ControlToValidate="txtPhone" ValidationGroup="reg" Display="Dynamic" CssClass="field-err" ValidationExpression="^[0-9]{9,15}$" ErrorMessage="เบอร์โทรต้องเป็นตัวเลข 9-15 หลัก" Text="เบอร์โทรต้องเป็นตัวเลข 9-15 หลัก"></asp:RegularExpressionValidator>

        <asp:Label ID="lblPassword" runat="server" AssociatedControlID="txtPassword" Text="รหัสผ่าน (อย่างน้อย 8 ตัว มีทั้งตัวอักษรและตัวเลข)"></asp:Label>
        <asp:TextBox ID="txtPassword" runat="server" TextMode="Password" MaxLength="64" autocomplete="new-password"></asp:TextBox>
        <asp:RequiredFieldValidator ID="rfvPassword" runat="server" ControlToValidate="txtPassword" ValidationGroup="reg" Display="Dynamic" CssClass="field-err" ErrorMessage="กรุณากรอกรหัสผ่าน" Text="กรุณากรอกรหัสผ่าน"></asp:RequiredFieldValidator>
        <asp:RegularExpressionValidator ID="revPassword" runat="server" ControlToValidate="txtPassword" ValidationGroup="reg" Display="Dynamic" CssClass="field-err" ValidationExpression="^(?=.*[A-Za-z])(?=.*[0-9]).{8,64}$" ErrorMessage="รหัสผ่านต้องยาว 8-64 ตัว และมีทั้งตัวอักษรและตัวเลข" Text="รหัสผ่านต้องยาว 8-64 ตัว และมีทั้งตัวอักษรและตัวเลข"></asp:RegularExpressionValidator>

        <asp:Label ID="lblConfirm" runat="server" AssociatedControlID="txtConfirm" Text="ยืนยันรหัสผ่าน"></asp:Label>
        <asp:TextBox ID="txtConfirm" runat="server" TextMode="Password" MaxLength="64" autocomplete="new-password"></asp:TextBox>
        <asp:CompareValidator ID="cvConfirm" runat="server" ControlToValidate="txtConfirm" ControlToCompare="txtPassword" ValidationGroup="reg" Display="Dynamic" CssClass="field-err" ErrorMessage="รหัสผ่านทั้งสองช่องไม่ตรงกัน" Text="รหัสผ่านทั้งสองช่องไม่ตรงกัน"></asp:CompareValidator>

        <p><asp:Button ID="btnRegister" runat="server" Text="สมัครสมาชิก" CssClass="btn block" ValidationGroup="reg" OnClick="btnRegister_Click" /></p>
        <p class="meta">มีบัญชีแล้ว? <asp:HyperLink ID="lnkLogin" runat="server" NavigateUrl="~/Login.aspx">เข้าสู่ระบบ</asp:HyperLink></p>
    </div>
</asp:Content>
