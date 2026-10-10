<%@ Page Title="เลือกรอบและที่นั่ง" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Showtimes.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.Showtimes" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <ol class="steps" aria-label="ขั้นตอนการจอง">
        <li class="done">✓ 1 เลือกหนัง</li><li class="on" aria-current="step">2 เลือกรอบและที่นั่ง</li><li>3 ชำระเงิน</li><li>4 รับตั๋ว</li>
    </ol>
    <a class="btn ghost sm" href="<%= ResolveUrl("~/Default.aspx") %>">← เลือกหนังอื่น</a>

    <asp:Panel ID="pnlMissing" runat="server" Visible="false" CssClass="card">
        <h2>ไม่พบภาพยนตร์ที่ต้องการ</h2>
        <p class="meta">ลิงก์อาจไม่ถูกต้อง กรุณากลับไปเลือกหนังจากหน้าแรก</p>
    </asp:Panel>

    <asp:Panel ID="pnlMovie" runat="server">
        <h1><asp:Literal ID="litTitle" runat="server"></asp:Literal></h1>
        <p class="meta"><asp:Literal ID="litMeta" runat="server"></asp:Literal></p>
        <p><asp:Literal ID="litDesc" runat="server"></asp:Literal></p>

        <h2>รอบฉาย</h2>
        <div class="times"><asp:Literal ID="litTimes" runat="server"></asp:Literal></div>
        <asp:Panel ID="pnlNoShows" runat="server" Visible="false" CssClass="card">
            <p class="meta">ยังไม่มีรอบฉายที่เปิดจองสำหรับเรื่องนี้</p>
        </asp:Panel>

        <asp:Panel ID="pnlSeats" runat="server" Visible="false">
            <h2>เลือกที่นั่ง <span class="meta">(<asp:Literal ID="litShowInfo" runat="server"></asp:Literal>)</span></h2>
            <div class="screen" aria-hidden="true"></div>
            <div class="cap">หน้าจอ</div>
            <asp:Literal ID="litSeatMap" runat="server"></asp:Literal>
            <div class="legend">
                <span><i style="background:var(--std)"></i>มาตรฐาน</span>
                <span><i style="background:var(--pre)"></i>พรีเมียม (2 แถวหลัง)</span>
                <span><i style="background:var(--sel)"></i>ที่คุณเลือก</span>
                <span><i style="background:var(--taken)"></i>ไม่ว่าง</span>
            </div>
            <div class="bar">
                <div>
                    <div class="meta">ที่นั่ง: <b id="selList">ยังไม่ได้เลือก</b> (เลือกได้สูงสุด 3 ที่)</div>
                    <div>ราคารวมก่อนส่วนลด: <b id="selTotal">฿0</b></div>
                </div>
                <asp:Button ID="btnHold" runat="server" Text="ถือที่นั่งและไปชำระเงิน" CssClass="btn" OnClick="btnHold_Click" CausesValidation="false" />
            </div>
            <p class="meta">เมื่อกดถือที่นั่ง ระบบจะกันที่นั่งให้ 15 นาที โดยนับเวลาจากเซิร์ฟเวอร์ ถ้าไม่ชำระเงินทันเวลาที่นั่งจะถูกปล่อยอัตโนมัติ</p>
        </asp:Panel>
    </asp:Panel>
</asp:Content>
