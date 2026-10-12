<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="History.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.Pages.History" %>
<!DOCTYPE html>
<html lang="th">
<head runat="server">
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>ประวัติการจอง | Cinema Ticketing</title>
<link href="https://fonts.googleapis.com/css2?family=Prompt:wght@500;700&family=IBM+Plex+Sans+Thai:wght@400;500&display=swap" rel="stylesheet" />
<link href="../Content/movies.css" rel="stylesheet" />
<script src="../Scripts/theme.js"></script>
</head>
<body>
<form id="form1" runat="server">
  <div class="topbar">
    <div class="brand"><a href="Movies.aspx">🎬 Cinema Ticketing</a></div>
    <div style="display:flex;gap:10px;align-items:center;">
      <div class="meta">ประวัติการจอง</div>
      <button id="themeBtn" type="button" class="theme-btn" aria-pressed="false" title="สลับธีมสว่าง / มืด">🌙</button>
    </div>
  </div>

  <div class="wrap">
    <h1>ประวัติการจอง</h1>
    <p class="meta">กรอกอีเมลที่ใช้จองเพื่อดูตั๋วทั้งหมด (เรียงล่าสุดก่อน)</p>

    <asp:Panel ID="pnlError" runat="server" CssClass="status warn" Visible="false">
      <asp:Label ID="lblError" runat="server" />
    </asp:Panel>

    <div class="filters">
      <asp:TextBox ID="txtEmail" runat="server" TextMode="Email" MaxLength="255" placeholder="เช่น somchai@email.com" />
      <asp:Button ID="btnSearch" runat="server" Text="ค้นหา" CssClass="btn" OnClick="btnSearch_Click" />
    </div>

    <asp:Label ID="lblCount" runat="server" CssClass="count" Visible="false" />

    <asp:Panel ID="pnlEmpty" runat="server" CssClass="empty" Visible="false">
      <asp:Label ID="lblEmpty" runat="server" />
    </asp:Panel>

    <asp:Panel ID="pnlList" runat="server" Visible="false">
      <div class="tablewrap">
        <asp:Repeater ID="rptBookings" runat="server">
          <HeaderTemplate><table class="shows"><thead><tr><th>รหัสจอง</th><th>หนัง</th><th>รอบฉาย</th><th>โรง</th><th>ที่นั่ง</th><th>ยอดรวม (บาท)</th><th>ชำระเงิน</th><th>สถานะ</th></tr></thead><tbody></HeaderTemplate>
          <ItemTemplate><tr><td><%# Eval("BookingId") %></td><td><%#: Eval("MovieTitle") %></td><td><%# Eval("DisplayShowTime") %></td><td><%#: Eval("HallName") %></td><td><%#: Eval("DisplaySeats") %></td><td><%#: Eval("DisplayTotal") %></td><td><%#: Eval("PaymentMethod") %> (<%#: Eval("PaymentStatus") %>)</td><td><span class='<%# Eval("StatusClass") %>'><%#: Eval("BookingStatus") %></span></td></tr></ItemTemplate>
          <FooterTemplate></tbody></table></FooterTemplate>
        </asp:Repeater>
      </div>
    </asp:Panel>

    <p><a class="backlink" href="Movies.aspx">← กลับไปหน้ารายการ</a></p>
  </div>
</form>
</body>
</html>
