<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="AdminShowtimes.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.Pages.AdminShowtimes" %>
<!DOCTYPE html>
<html lang="th">
<head runat="server">
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>จัดการรอบฉาย | Cinema Ticketing</title>
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
    <h1>จัดการรอบฉาย</h1>

    <asp:Panel ID="pnlMsg" runat="server" CssClass="status ok" Visible="false">
      <asp:Label ID="lblMsg" runat="server" />
    </asp:Panel>

    <div class="card pad">
      <h2>เพิ่มรอบฉายใหม่</h2>
      <asp:Panel ID="pnlCreate" runat="server">
      <div class="formgrid">
        <label class="field">หนัง (เฉพาะเรื่องที่ฉายอยู่)
          <asp:DropDownList ID="ddlMovie" runat="server" />
        </label>
        <label class="field">โรง (เฉพาะโรงที่เปิด)
          <asp:DropDownList ID="ddlHall" runat="server" />
        </label>
        <label class="field">เริ่มฉาย
          <asp:TextBox ID="txtStart" runat="server" TextMode="DateTimeLocal" />
        </label>
        <label class="field">จบ
          <asp:TextBox ID="txtEnd" runat="server" TextMode="DateTimeLocal" />
        </label>
        <label class="field">ราคาตั๋วมาตรฐาน (บาท)
          <asp:TextBox ID="txtPrice" runat="server" MaxLength="10" placeholder="เช่น 150.00" />
        </label>
        <div class="field btncell">
          <asp:Button ID="btnCreate" runat="server" Text="เพิ่มรอบฉาย" CssClass="btn" OnClick="btnCreate_Click" />
        </div>
      </div>
      </asp:Panel>
      <p class="meta">รอบชนกันในโรงเดียวกันเพิ่มไม่ได้ (รอบที่ยกเลิกแล้วไม่นับ) เวลาจบต้องหลังเวลาเริ่ม</p>
    </div>

    <div class="filters">
      <asp:DropDownList ID="ddlStatus" runat="server">
        <asp:ListItem Value="scheduled" Text="รอบที่เปิดจอง" Selected="True" />
        <asp:ListItem Value="completed" Text="รอบที่ฉายจบแล้ว" />
        <asp:ListItem Value="cancelled" Text="รอบที่ยกเลิก" />
        <asp:ListItem Value="" Text="ทุกสถานะ" />
      </asp:DropDownList>
      <asp:Button ID="btnSearch" runat="server" Text="ค้นหา" CssClass="btn" OnClick="btnSearch_Click" />
    </div>

    <asp:Panel ID="pnlEmpty" runat="server" CssClass="empty" Visible="false">
      ไม่พบรอบฉายตามเงื่อนไข
    </asp:Panel>

    <asp:Panel ID="pnlList" runat="server" Visible="false">
      <div class="tablewrap">
        <asp:Repeater ID="rptShowtimes" runat="server">
          <HeaderTemplate><table class="shows"><thead><tr><th>รหัส</th><th>หนัง</th><th>โรง</th><th>เริ่ม</th><th>จบ</th><th>ราคา</th><th>จองค้าง</th><th>สถานะ</th><th>จัดการ</th></tr></thead><tbody></HeaderTemplate>
          <ItemTemplate><tr><td><%# Eval("ShowtimeId") %></td><td><%#: Eval("MovieTitle") %></td><td><%#: Eval("HallName") %></td><td><%# Eval("DisplayStart") %></td><td><%# Eval("DisplayEnd") %></td><td><%#: Eval("StandardPrice") %></td><td><%# Eval("ActiveBookings") %></td><td><span class='<%# Eval("StatusClass") %>'><%#: Eval("Status") %></span></td><td><asp:Button ID="btnCancelShow" runat="server" Text="ยกเลิกรอบ" CssClass="btn small danger" CommandArgument='<%# Eval("ShowtimeId") %>' Visible='<%# Eval("CanCancel") %>' OnCommand="btnCancelShow_Command" OnClientClick="return confirm('ยกเลิกรอบฉายนี้? (ทำได้เฉพาะรอบที่ยังไม่มีผู้จอง)');" /></td></tr></ItemTemplate>
          <FooterTemplate></tbody></table></FooterTemplate>
        </asp:Repeater>
      </div>
    </asp:Panel>
  </div>
</form>
</body>
</html>
