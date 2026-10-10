<%@ Page Title="ผู้ดูแลระบบ" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Default.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.AdminPages.AdminHome" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <h1>ผู้ดูแลระบบ</h1>
    <div class="stats">
        <div class="card stat"><span class="meta">หนังที่เปิดใช้งาน</span><b><asp:Literal ID="litMovies" runat="server">-</asp:Literal></b></div>
        <div class="card stat"><span class="meta">รอบฉายที่เปิดจอง (ต่อจากนี้)</span><b><asp:Literal ID="litShows" runat="server">-</asp:Literal></b></div>
        <div class="card stat"><span class="meta">ตั๋วที่ขายแล้ว</span><b><asp:Literal ID="litTickets" runat="server">-</asp:Literal></b></div>
        <div class="card stat"><span class="meta">รายได้รวม</span><b><asp:Literal ID="litRevenue" runat="server">-</asp:Literal></b></div>
        <div class="card stat"><span class="meta">ที่นั่งที่กำลังถือ</span><b><asp:Literal ID="litHolds" runat="server">-</asp:Literal></b></div>
    </div>
    <div class="grid">
        <a class="card" href="<%= ResolveUrl("~/Admin/Movies.aspx") %>"><h3>🎬 จัดการภาพยนตร์</h3><p class="meta">เพิ่ม ดู แก้ไข ลบ</p></a>
        <a class="card" href="<%= ResolveUrl("~/Admin/Showtimes.aspx") %>"><h3>🕒 จัดการรอบฉาย</h3><p class="meta">ระบบตรวจรอบทับซ้อนในโรงเดียวกันให้อัตโนมัติ</p></a>
        <a class="card" href="<%= ResolveUrl("~/Admin/Promotions.aspx") %>"><h3>🏷️ จัดการโปรโมชัน</h3><p class="meta">โค้ดส่วนลดแบบเปอร์เซ็นต์/จำนวนเงิน</p></a>
        <a class="card" href="<%= ResolveUrl("~/Admin/BoxOffice.aspx") %>"><h3>📈 รายงาน Box Office</h3><p class="meta">รายได้และอัตราการครองที่นั่งต่อภาพยนตร์</p></a>
    </div>
</asp:Content>
