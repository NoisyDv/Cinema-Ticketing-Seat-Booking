<%@ Page Title="เข้าสู่ระบบ" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Login.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.Login" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <div class="form-narrow card">
        <h1>เข้าสู่ระบบ</h1>
        <asp:ValidationSummary ID="vsLogin" runat="server" ValidationGroup="login" CssClass="alert err" HeaderText="กรุณาแก้ไขข้อมูลต่อไปนี้" />

        <asp:Label ID="lblEmail" runat="server" AssociatedControlID="txtEmail" Text="อีเมล"></asp:Label>
        <asp:TextBox ID="txtEmail" runat="server" TextMode="Email" MaxLength="255" autocomplete="username"></asp:TextBox>
        <asp:RequiredFieldValidator ID="rfvEmail" runat="server" ControlToValidate="txtEmail" ValidationGroup="login" Display="Dynamic" CssClass="field-err" ErrorMessage="กรุณากรอกอีเมล" Text="กรุณากรอกอีเมล"></asp:RequiredFieldValidator>
        <asp:RegularExpressionValidator ID="revEmail" runat="server" ControlToValidate="txtEmail" ValidationGroup="login" Display="Dynamic" CssClass="field-err" ValidationExpression="^[^\s@]+@[^\s@]+\.[^\s@]+$" ErrorMessage="รูปแบบอีเมลไม่ถูกต้อง" Text="รูปแบบอีเมลไม่ถูกต้อง"></asp:RegularExpressionValidator>

        <asp:Label ID="lblPassword" runat="server" AssociatedControlID="txtPassword" Text="รหัสผ่าน"></asp:Label>
        <asp:TextBox ID="txtPassword" runat="server" TextMode="Password" MaxLength="64" autocomplete="current-password"></asp:TextBox>
        <asp:RequiredFieldValidator ID="rfvPassword" runat="server" ControlToValidate="txtPassword" ValidationGroup="login" Display="Dynamic" CssClass="field-err" ErrorMessage="กรุณากรอกรหัสผ่าน" Text="กรุณากรอกรหัสผ่าน"></asp:RequiredFieldValidator>

        <p><asp:Button ID="btnLogin" runat="server" Text="เข้าสู่ระบบ" CssClass="btn block" ValidationGroup="login" OnClick="btnLogin_Click" /></p>
        <p class="meta">ยังไม่มีบัญชี? <asp:HyperLink ID="lnkReg" runat="server" NavigateUrl="~/Register.aspx">สมัครสมาชิก</asp:HyperLink></p>
    </div>
</asp:Content>
