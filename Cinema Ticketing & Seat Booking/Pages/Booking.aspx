<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Booking.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.Pages.Booking" %>
<!DOCTYPE html>
<html lang="th">
<head runat="server">
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>จองที่นั่ง | Cinema Ticketing</title>
<link href="https://fonts.googleapis.com/css2?family=Prompt:wght@500;700&family=IBM+Plex+Sans+Thai:wght@400;500&display=swap" rel="stylesheet" />
<link href="../Content/movies.css" rel="stylesheet" />
<script src="../Scripts/theme.js"></script>
</head>
<body>
<form id="form1" runat="server">
  <div class="topbar">
    <div class="brand"><a href="Movies.aspx">🎬 Cinema Ticketing</a></div>
    <div style="display:flex;gap:10px;align-items:center;">
      <div class="meta">จองที่นั่ง</div>
      <button id="themeBtn" type="button" class="theme-btn" aria-pressed="false" title="สลับธีมสว่าง / มืด">🌙</button>
    </div>
  </div>

  <div class="wrap">
    <asp:Panel ID="pnlError" runat="server" CssClass="status warn" Visible="false">
      <asp:Label ID="lblError" runat="server" />
    </asp:Panel>

    <asp:Panel ID="pnlForm" runat="server" Visible="false">
      <a id="lnkBack" runat="server" class="backlink" href="Movies.aspx">← กลับไปรอบฉาย</a>
      <div class="card infocard">
        <h1><asp:Literal ID="litMovie" runat="server" /></h1>
        <div class="meta"><asp:Literal ID="litShowInfo" runat="server" /></div>
      </div>

      <div class="bookgrid">
        <section class="card pad">
          <h2>เลือกที่นั่ง (สูงสุด 10 ที่)</h2>
          <div class="screen"></div>
          <div class="cap">หน้าจอ</div>
          <asp:Repeater ID="rptRows" runat="server" OnItemDataBound="rptRows_ItemDataBound">
            <ItemTemplate>
              <div class="seatrow">
                <span class="rowlabel"><%# Eval("RowLabel") %></span>
                <asp:Repeater ID="rptSeats" runat="server">
                  <ItemTemplate>
                    <label class='<%# Eval("CssClass") %>'>
                      <input type="checkbox" name="seat" value='<%# Eval("SeatId") %>'
                             data-price='<%# Eval("Price") %>'
                             <%# Eval("DisabledAttr") %> <%# Eval("CheckedAttr") %> />
                      <span><%# Eval("Label") %></span>
                    </label>
                  </ItemTemplate>
                </asp:Repeater>
              </div>
            </ItemTemplate>
          </asp:Repeater>
          <div class="legend">
            <span><i class="sw free"></i>ว่าง</span>
            <span><i class="sw premium"></i>Premium +50 บาท</span>
            <span><i class="sw picked"></i>ที่คุณเลือก</span>
            <span><i class="sw taken"></i>ไม่ว่าง</span>
          </div>
          <p class="est"><span id="estText">ยังไม่เลือกที่นั่ง (สูงสุด 10 ที่)</span></p>
        </section>

        <section class="card pad">
          <h2>ข้อมูลการจอง</h2>
          <label class="field">ชื่อ-นามสกุล
            <asp:TextBox ID="txtName" runat="server" MaxLength="150" placeholder="เช่น สมชาย ใจดี" />
          </label>
          <label class="field">อีเมล (ใช้ยืนยันตัวตน)
            <asp:TextBox ID="txtEmail" runat="server" TextMode="Email" MaxLength="255" placeholder="เช่น somchai@email.com" />
          </label>
          <label class="field">เบอร์โทร
            <asp:TextBox ID="txtPhone" runat="server" MaxLength="20" placeholder="เช่น 0812345678" />
          </label>
          <label class="field">โค้ดส่วนลด (ถ้ามี)
            <asp:TextBox ID="txtPromo" runat="server" MaxLength="50" placeholder="เช่น PROMO003" />
          </label>
          <label class="field">ชำระเงิน
            <asp:DropDownList ID="ddlPay" runat="server">
              <asp:ListItem Value="online" Text="ออนไลน์" Selected="True" />
              <asp:ListItem Value="card" Text="บัตร" />
              <asp:ListItem Value="cash" Text="เงินสด" />
            </asp:DropDownList>
          </label>
          <asp:Button ID="btnConfirm" runat="server" Text="ยืนยันการจอง" CssClass="btn wide" OnClick="btnConfirm_Click" />
          <p class="meta">ที่นั่งที่เลือกจะถูกกันไว้ทันทีหลังชำระเงินสำเร็จ</p>
        </section>
      </div>
    </asp:Panel>

    <asp:Panel ID="pnlSuccess" runat="server" CssClass="status ok big" Visible="false">
      <h2>จองสำเร็จ</h2>
      <p><asp:Literal ID="litSuccess" runat="server" /></p>
      <p><a class="btn" href="Movies.aspx">จองเรื่องอื่นต่อ</a>
      <a class="btn ghostbtn" href="History.aspx">ดูประวัติการจอง</a></p>
    </asp:Panel>
  </div>
</form>
<script src="../Scripts/booking.js"></script>
</body>
</html>
