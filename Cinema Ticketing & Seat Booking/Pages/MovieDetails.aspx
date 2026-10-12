<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="MovieDetails.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.Pages.MovieDetails" %>
<!DOCTYPE html>
<html lang="th">
<head runat="server">
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>รายละเอียดหนัง | Cinema Ticketing</title>
<link href="https://fonts.googleapis.com/css2?family=Prompt:wght@500;700&family=IBM+Plex+Sans+Thai:wght@400;500&display=swap" rel="stylesheet" />
<link href="../Content/movies.css" rel="stylesheet" />
<script src="../Scripts/theme.js"></script>
</head>
<body>
<form id="form1" runat="server">
  <div class="topbar">
    <div class="brand"><a href="Movies.aspx">🎬 Cinema Ticketing</a></div>
    <div style="display:flex;gap:10px;align-items:center;">
      <div class="meta">รายละเอียดหนัง + รอบฉาย</div>
      <button id="themeBtn" type="button" class="theme-btn" aria-pressed="false" title="สลับธีมสว่าง / มืด">🌙</button>
    </div>
  </div>

  <div class="wrap">
    <asp:Panel ID="pnlError" runat="server" CssClass="status warn" Visible="false">
      <asp:Label ID="lblError" runat="server" />
    </asp:Panel>

    <asp:Panel ID="pnlMovie" runat="server" Visible="false">
      <a class="backlink" href="Movies.aspx">← กลับไปหน้ารายการ</a>
      <div class="detail">
        <div class="poster"><asp:Image ID="imgPoster" runat="server" AlternateText="โปสเตอร์" /></div>
        <div class="info">
          <h1><asp:Literal ID="litTitle" runat="server" /></h1>
          <div class="chips"><asp:Literal ID="litBadges" runat="server" /></div>
          <div class="meta"><asp:Literal ID="litMeta" runat="server" /></div>
          <p class="desc"><asp:Literal ID="litDescription" runat="server" /></p>
        </div>
      </div>

      <h2>รอบฉายที่จองได้</h2>
      <asp:Panel ID="pnlEmpty" runat="server" CssClass="empty" Visible="false">
        ยังไม่มีรอบฉายที่เปิดจองสำหรับเรื่องนี้ ลองกลับมาดูใหม่ภายหลัง
      </asp:Panel>
      <asp:Panel ID="pnlShows" runat="server" Visible="false">
        <div class="tablewrap">
          <asp:Repeater ID="rptShowtimes" runat="server">
            <HeaderTemplate><table class="shows"><thead><tr><th>วันเวลาเริ่ม</th><th>จบ</th><th>โรง</th><th>ราคาเริ่มต้น (บาท)</th><th>ที่นั่งว่าง</th><th></th></tr></thead><tbody></HeaderTemplate>
            <ItemTemplate><tr><td><%# Eval("DisplayStart") %></td><td><%# Eval("DisplayEnd") %></td><td><%#: Eval("HallName") %></td><td><%#: Eval("DisplayPrice") %></td><td><%#: Eval("DisplaySeatsLeft") %></td><td><a class="golink" href='<%# "Booking.aspx?showtime_id=" + Eval("ShowtimeId") %>'>จอง</a></td></tr></ItemTemplate>
            <FooterTemplate></tbody></table></FooterTemplate>
          </asp:Repeater>
        </div>
      </asp:Panel>
    </asp:Panel>
  </div>
</form>
</body>
</html>
