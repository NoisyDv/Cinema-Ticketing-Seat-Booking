<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Dashboard.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.Pages.Dashboard" %>
<!DOCTYPE html>
<html lang="th">
<head runat="server">
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>รายงาน Box Office | Cinema Ticketing</title>
<link href="https://fonts.googleapis.com/css2?family=Prompt:wght@500;700&family=IBM+Plex+Sans+Thai:wght@400;500&display=swap" rel="stylesheet" />
<link href="../Content/movies.css" rel="stylesheet" />
<script src="../Scripts/theme.js"></script>
</head>
<body>
<form id="form1" runat="server">
  <div class="topbar">
    <div class="brand"><a href="Movies.aspx">🎬 Cinema Ticketing</a></div>
    <div style="display:flex;gap:10px;align-items:center;">
      <div class="meta">รายงาน Box Office</div>
      <button id="themeBtn" type="button" class="theme-btn" aria-pressed="false" title="สลับธีมสว่าง / มืด">🌙</button>
    </div>
  </div>

  <div class="wrap">
    <h1>รายงาน Box Office</h1>
    <p class="meta">รายได้และอัตราการครองที่นั่งรายหนัง (เฉพาะรอบที่ฉายจริง ไม่นับรอบยกเลิก)</p>

    <asp:Panel ID="pnlError" runat="server" CssClass="status warn" Visible="false">
      <asp:Label ID="lblError" runat="server" />
    </asp:Panel>

    <asp:Panel ID="pnlReport" runat="server" Visible="false">
      <div class="statcards">
        <div class="stat"><div class="num"><asp:Literal ID="litRevenue" runat="server" /></div><div class="lbl">รายได้รวม (บาท)</div></div>
        <div class="stat"><div class="num"><asp:Literal ID="litTickets" runat="server" /></div><div class="lbl">ตั๋วที่ขายได้ (ใบ)</div></div>
        <div class="stat"><div class="num"><asp:Literal ID="litShows" runat="server" /></div><div class="lbl">รอบฉายทั้งหมด (รอบ)</div></div>
      </div>

      <div class="tablewrap">
        <asp:Repeater ID="rptReport" runat="server">
          <HeaderTemplate><table class="shows"><thead><tr><th>อันดับ</th><th>หนัง</th><th>ประเภท</th><th>รอบ</th><th>ตั๋วขาย</th><th>รายได้ (บาท)</th><th>ครองที่นั่ง</th></tr></thead><tbody></HeaderTemplate>
          <ItemTemplate><tr><td><%# Eval("Rank") %></td><td><%#: Eval("MovieTitle") %></td><td><%#: Eval("Genre") %></td><td><%# Eval("TotalShowtimes") %></td><td><%# Eval("TicketsSold") %></td><td><%#: Eval("DisplayRevenue") %></td><td><div class="meter"><b style='width:<%# Eval("BarWidth") %>%;'></b></div> <%#: Eval("DisplayOccupancy") %>%</td></tr></ItemTemplate>
          <FooterTemplate></tbody></table></FooterTemplate>
        </asp:Repeater>
      </div>
    </asp:Panel>

    <p><a class="backlink" href="Movies.aspx">← กลับไปหน้ารายการ</a></p>
  </div>
</form>
</body>
</html>
