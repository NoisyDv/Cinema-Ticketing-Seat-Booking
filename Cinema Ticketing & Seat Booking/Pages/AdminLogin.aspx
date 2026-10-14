<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="AdminLogin.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.Pages.AdminLogin" %>
<!DOCTYPE html>
<html lang="th">
<head runat="server">
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>แอดมิน | Cinema Ticketing</title>
<link href="https://fonts.googleapis.com/css2?family=Prompt:wght@500;700&family=IBM+Plex+Sans+Thai:wght@400;500&display=swap" rel="stylesheet" />
<link href="../Content/movies.css" rel="stylesheet" />
<script src="../Scripts/theme.js"></script>
</head>
<body>
<form id="form1" runat="server">
  <div class="topbar">
    <div class="brand"><a href="Movies.aspx">🎬 Cinema Ticketing</a></div>
    <div style="display:flex;gap:10px;align-items:center;">
      <div class="meta">แอดมิน</div>
      <button id="themeBtn" type="button" class="theme-btn" aria-pressed="false" title="สลับธีมสว่าง / มืด">🌙</button>
    </div>
  </div>

  <div class="wrap narrow">
    <h1>สำหรับแอดมิน</h1>
    <p class="meta">กรอกรหัสด่านแอดมิน (รหัสเดียวใช้ร่วมกันทั้งทีม ดูค่าได้ใน <b>Web.config</b> หัวข้อ <b>AdminPasscode</b>)</p>

    <asp:Panel ID="pnlError" runat="server" CssClass="status warn" Visible="false">
      <asp:Label ID="lblError" runat="server" />
    </asp:Panel>

    <div class="card pad">
      <label class="field">รหัสแอดมิน
        <asp:TextBox ID="txtPasscode" runat="server" TextMode="Password" MaxLength="100" autocomplete="off" />
      </label>
      <asp:Button ID="btnLogin" runat="server" Text="เข้าสู่ระบบ" CssClass="btn wide" OnClick="btnLogin_Click" />
    </div>
    <p><a class="backlink" href="Movies.aspx">← กลับไปหน้ารายการ</a></p>
  </div>
</form>
</body>
</html>
