<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="AdminMovies.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.Pages.AdminMovies" %>
<!DOCTYPE html>
<html lang="th">
<head runat="server">
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>จัดการหนัง | Cinema Ticketing</title>
<link href="https://fonts.googleapis.com/css2?family=Prompt:wght@500;700&family=IBM+Plex+Sans+Thai:wght@400;500&display=swap" rel="stylesheet" />
<link href="../Content/movies.css" rel="stylesheet" />
<script src="../Scripts/theme.js"></script>
</head>
<body>
<form id="form1" runat="server">
  <div class="topbar">
    <div class="brand"><a href="Movies.aspx">🎬 Cinema Ticketing</a></div>
    <div style="display:flex;gap:10px;align-items:center;">
      <a class="golink" href="AdminShowtimes.aspx">รอบฉาย</a>
      <a class="golink" href="AdminPromos.aspx">โปรโมชัน</a>
      <a class="golink" href="AdminMovies.aspx">หนัง</a>
      <asp:LinkButton ID="lnkLogout" runat="server" CssClass="golink" OnClick="lnkLogout_Click">ออก</asp:LinkButton>
      <button id="themeBtn" type="button" class="theme-btn" aria-pressed="false" title="สลับธีมสว่าง / มืด">🌙</button>
    </div>
  </div>

  <div class="wrap">
    <h1>จัดการหนัง</h1>
    <p class="meta">เปิด/ปิดการฉาย (หนังที่ปิดจะไม่ขึ้นหน้ารายการ และจองรอบของมันไม่ได้)</p>

    <asp:Panel ID="pnlMsg" runat="server" CssClass="status ok" Visible="false">
      <asp:Label ID="lblMsg" runat="server" />
    </asp:Panel>

    <div class="card pad">
      <h2>เพิ่มหนังใหม่</h2>
      <div class="formgrid">
        <label class="field">ชื่อเรื่อง
          <asp:TextBox ID="txtTitle" runat="server" MaxLength="200" />
        </label>
        <label class="field">ประเภท
          <asp:TextBox ID="txtGenre" runat="server" MaxLength="50" placeholder="เช่น Action" />
        </label>
        <label class="field">ความยาว (นาที)
          <asp:TextBox ID="txtDuration" runat="server" MaxLength="5" placeholder="เช่น 120" />
        </label>
        <label class="field">วันเข้าฉาย
          <asp:TextBox ID="txtRelease" runat="server" TextMode="Date" />
        </label>
        <label class="field">เรื่องย่อ
          <asp:TextBox ID="txtDesc" runat="server" TextMode="MultiLine" Rows="3" />
        </label>
        <label class="field">สถานะ
          <asp:DropDownList ID="ddlStatus" runat="server">
            <asp:ListItem Value="active" Text="ฉายอยู่" Selected="True" />
            <asp:ListItem Value="inactive" Text="ปิด" />
          </asp:DropDownList>
        </label>
        <label class="field">ไฟล์โปสเตอร์ (ไม่บังคับ: .webp/.jpg/.png ไม่เกิน 5MB)
          <asp:FileUpload ID="fuPoster" runat="server" />
        </label>
        <div class="field btncell">
          <asp:Button ID="btnAddMovie" runat="server" Text="เพิ่มหนัง" CssClass="btn" OnClick="btnAddMovie_Click" />
        </div>
      </div>
      <p class="meta">ถ้าไม่แนบไฟล์จะใช้รูปสำรองแทน ไฟล์จะถูกเก็บในโฟลเดอร์ <b>Posters/</b> แล้วผูกกับหนังอัตโนมัติ</p>
    </div>

    <asp:Panel ID="pnlEmpty" runat="server" CssClass="empty" Visible="false">
      ยังไม่มีหนังในระบบ
    </asp:Panel>

    <asp:Panel ID="pnlList" runat="server" Visible="false">
      <div class="tablewrap">
        <asp:Repeater ID="rptMovies" runat="server">
          <HeaderTemplate><table class="shows"><thead><tr><th>เรื่อง</th><th>ประเภท</th><th>ความยาว</th><th>วันเข้าฉาย</th><th>สถานะ</th><th>จัดการ</th></tr></thead><tbody></HeaderTemplate>
          <ItemTemplate><tr><td><%#: Eval("Title") %></td><td><%#: Eval("Genre") %></td><td><%#: Eval("DisplayDuration") %></td><td><%# ((DateTime)Eval("ReleaseDate")).ToString("dd MMM yyyy") %></td><td><span class='<%# ((string)Eval("Status") == "active") ? "pill ok" : "pill off" %>'><%#: Eval("Status") %></span></td><td><asp:Button ID="btnToggle" runat="server" Text="เปิด/ปิด" CssClass="btn small" CommandArgument='<%# Eval("MovieId") %>' OnCommand="btnToggle_Command" /></td></tr></ItemTemplate>
          <FooterTemplate></tbody></table></FooterTemplate>
        </asp:Repeater>
      </div>
    </asp:Panel>
  </div>
</form>
</body>
</html>
