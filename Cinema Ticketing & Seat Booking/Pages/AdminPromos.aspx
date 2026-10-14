<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="AdminPromos.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.Pages.AdminPromos" %>
<!DOCTYPE html>
<html lang="th">
<head runat="server">
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>จัดการโปรโมชัน | Cinema Ticketing</title>
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
    <h1>จัดการโปรโมชัน</h1>

    <asp:Panel ID="pnlMsg" runat="server" CssClass="status ok" Visible="false">
      <asp:Label ID="lblMsg" runat="server" />
    </asp:Panel>

    <div class="card pad">
      <h2>เพิ่มโปรโมชันใหม่</h2>
      <div class="formgrid">
        <label class="field">รหัสโปรโมชัน
          <asp:TextBox ID="txtCode" runat="server" MaxLength="50" placeholder="เช่น NEWYEAR50" />
        </label>
        <label class="field">ประเภทส่วนลด
          <asp:DropDownList ID="ddlType" runat="server">
            <asp:ListItem Value="percentage" Text="เปอร์เซ็นต์ (%)" Selected="True" />
            <asp:ListItem Value="fixed" Text="จำนวนเงิน (บาท)" />
          </asp:DropDownList>
        </label>
        <label class="field">ค่าส่วนลด
          <asp:TextBox ID="txtValue" runat="server" MaxLength="10" placeholder="เช่น 10 หรือ 50" />
        </label>
        <label class="field">เริ่มใช้
          <asp:TextBox ID="txtStart" runat="server" TextMode="Date" />
        </label>
        <label class="field">หมดเขต
          <asp:TextBox ID="txtEnd" runat="server" TextMode="Date" />
        </label>
        <div class="field btncell">
          <asp:Button ID="btnCreate" runat="server" Text="เพิ่มโปรโมชัน" CssClass="btn" OnClick="btnCreate_Click" />
        </div>
      </div>
      <p class="meta">แบบเปอร์เซ็นต์ใส่ 0-100 แบบจำนวนเงินห้ามติดลบ วันหมดเขตต้องไม่ก่อนวันเริ่ม รหัสห้ามซ้ำ</p>
    </div>

    <asp:Panel ID="pnlEmpty" runat="server" CssClass="empty" Visible="false">
      ยังไม่มีโปรโมชันในระบบ
    </asp:Panel>

    <asp:Panel ID="pnlList" runat="server" Visible="false">
      <div class="tablewrap">
        <asp:Repeater ID="rptPromos" runat="server">
          <HeaderTemplate><table class="shows"><thead><tr><th>รหัส</th><th>ส่วนลด</th><th>ช่วงเวลา</th><th>สถานะ</th><th>จัดการ</th></tr></thead><tbody></HeaderTemplate>
          <ItemTemplate><tr><td><%#: Eval("Code") %></td><td><%#: Eval("DisplayDiscount") %></td><td><%#: Eval("DisplayPeriod") %></td><td><span class='<%# Eval("StatusClass") %>'><%#: Eval("Status") %></span></td><td><asp:Button ID="btnToggle" runat="server" Text="เปิด/ปิด" CssClass="btn small" CommandArgument='<%# Eval("PromotionId") %>' OnCommand="btnToggle_Command" /></td></tr></ItemTemplate>
          <FooterTemplate></tbody></table></FooterTemplate>
        </asp:Repeater>
      </div>
    </asp:Panel>
  </div>
</form>
</body>
</html>
