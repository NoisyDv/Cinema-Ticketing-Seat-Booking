<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Movies.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.Pages.Movies" %>
<!DOCTYPE html>
<html lang="th">
<head runat="server">
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>หนังที่กำลังฉาย | Cinema Ticketing</title>
<link href="https://fonts.googleapis.com/css2?family=Prompt:wght@500;700&family=IBM+Plex+Sans+Thai:wght@400;500&display=swap" rel="stylesheet" />
<link href="../Content/movies.css" rel="stylesheet" />
<script src="../Scripts/theme.js"></script>
</head>
<body>
<form id="form1" runat="server">
  <div class="topbar">
    <div class="brand"><a href="Movies.aspx">🎬 Cinema Ticketing</a></div>
    <div style="display:flex;gap:10px;align-items:center;">
      <div class="meta">หนังที่กำลังฉาย (เชื่อม DB + โฟลเดอร์ Posters)</div>
      <a class="golink" href="History.aspx">ประวัติการจอง</a>
      <a class="golink" href="Dashboard.aspx">รายงาน</a>
      <button id="themeBtn" type="button" class="theme-btn" aria-pressed="false" title="สลับธีมสว่าง / มืด">🌙</button>
    </div>
  </div>

  <div class="wrap">
    <h1>วันนี้ดูอะไรดี</h1>
    <p class="meta">ข้อมูลจากตาราง <b>movies</b> (Database/schema.sql + data.sql) รูปจากโฟลเดอร์ <b>Posters/</b></p>

    <asp:Panel ID="pnlStatus" runat="server" CssClass="status">
      <asp:Label ID="lblStatus" runat="server" />
    </asp:Panel>

    <div class="filters">
      <asp:TextBox ID="txtSearch" runat="server" placeholder="ค้นหาชื่อหนังหรือประเภท..." />
      <asp:DropDownList ID="ddlGenre" runat="server" />
      <asp:Button ID="btnSearch" runat="server" Text="ค้นหา" CssClass="btn" OnClick="btnSearch_Click" />
    </div>

    <asp:Label ID="lblCount" runat="server" CssClass="count" />

    <asp:Panel ID="pnlEmpty" runat="server" CssClass="empty" Visible="false">
      ไม่พบหนังตามเงื่อนไข ลองเปลี่ยนคำค้นหรือประเภท
    </asp:Panel>

    <div class="grid">
      <asp:Repeater ID="rptMovies" runat="server">
        <ItemTemplate>
          <article class="card">
            <a class="posterlink" href='<%# "MovieDetails.aspx?movie_id=" + Eval("MovieId") %>'>
              <img src="<%# ResolvePosterUrl((string)Eval("PosterUrl")) %>"
                   alt="<%# "โปสเตอร์ " + Eval("Title") %>"
                   loading="lazy"
                   onerror="this.style.display='none'" />
            </a>
            <div class="body">
              <span class="chip"><%# Eval("Genre") %></span>
              <h2><%# Eval("Title") %></h2>
              <div class="meta"><%# Eval("DisplayDuration") %> • ฉาย <%# ((DateTime)Eval("ReleaseDate")).ToString("dd MMM yyyy") %></div>
              <div class="desc"><%# Eval("Description") %></div>
              <a class="golink" href='<%# "MovieDetails.aspx?movie_id=" + Eval("MovieId") %>'>ดูรอบฉาย →</a>
            </div>
          </article>
        </ItemTemplate>
      </asp:Repeater>
    </div>

    <p class="footer">
      วิธีใช้ SQL: รัน Database/schema.sql → data.sql → logic.sql ใน SSMS แล้วแก้ connection string
      <b>MoviesConnectionString</b> ใน Web.config ให้ตรงเครื่องของคุณ (ดู Database/README.md)
    </p>
  </div>
</form>
</body>
</html>
