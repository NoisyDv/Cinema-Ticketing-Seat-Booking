<%@ Page Title="ตั๋วของคุณ" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Ticket.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.Ticket" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <ol class="steps noprint" aria-label="ขั้นตอนการจอง">
        <li class="done">✓ 1 เลือกหนัง</li><li class="done">✓ 2 เลือกรอบและที่นั่ง</li><li class="done">✓ 3 ชำระเงิน</li><li class="on" aria-current="step">4 รับตั๋ว</li>
    </ol>
    <asp:Panel ID="pnlMissing" runat="server" Visible="false" CssClass="card">
        <h2>ไม่พบตั๋วนี้</h2>
        <p class="meta">การจองอาจไม่ใช่ของคุณ หรือยังไม่ได้ชำระเงิน</p>
        <a class="btn" href="<%= ResolveUrl("~/MyBookings.aspx") %>">ไปที่การจองของฉัน</a>
    </asp:Panel>
    <asp:Panel ID="pnlTickets" runat="server" Visible="false">
        <h1>🎟️ ตั๋วของคุณ</h1>
        <p class="meta">รหัสการจอง <b><asp:Literal ID="litCode" runat="server"></asp:Literal></b> · ชำระเมื่อ <asp:Literal ID="litPaid" runat="server"></asp:Literal> · <asp:Literal ID="litMethod" runat="server"></asp:Literal> · ยอดชำระ <b><asp:Literal ID="litTotal" runat="server"></asp:Literal></b></p>
        <asp:Repeater ID="rptTickets" runat="server">
            <ItemTemplate>
                <div class="ticket">
                    <div class="l">
                        <h3><%# Fmt.Html(MovieTitle) %></h3>
                        <div class="meta"><%# Fmt.Html(ShowText) %> · <%# Fmt.Html(HallName) %></div>
                        <div class="big-seat">ที่นั่ง <%# Fmt.Html(Eval("seat_label")) %></div>
                        <div class="meta"><%# Eval("seat_type").ToString() == "premium" ? "พรีเมียม" : "มาตรฐาน" %> · <%# Fmt.Baht(Eval("ticket_price")) %></div>
                    </div>
                    <div class="r">
                        <div class="qr" role="img" aria-label="ลวดลายตัวอย่างแทนคิวอาร์โค้ด"></div>
                        <small class="meta">#<%# Eval("ticket_id") %></small>
                    </div>
                </div>
            </ItemTemplate>
        </asp:Repeater>
        <p class="noprint">
            <button type="button" class="btn ghost" onclick="window.print()">พิมพ์ตั๋ว</button>
            <a class="btn" href="<%= ResolveUrl("~/MyBookings.aspx") %>">การจองของฉัน</a>
        </p>
    </asp:Panel>
</asp:Content>
