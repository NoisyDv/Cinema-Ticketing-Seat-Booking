<%@ Page Title="การจองของฉัน" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="MyBookings.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.MyBookings" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <h1>การจองของฉัน</h1>
    <p class="meta">ประวัติการจองล่าสุด (สูงสุด 200 รายการ) — รายการที่รอชำระเงินจะมีเวลานับถอยหลังตามเวลาของเซิร์ฟเวอร์</p>
    <asp:Panel ID="pnlEmpty" runat="server" Visible="false" CssClass="card">
        <p class="meta">ยังไม่มีประวัติการจอง</p>
        <a class="btn" href="<%= ResolveUrl("~/Default.aspx") %>">เลือกหนังที่จะดู</a>
    </asp:Panel>
    <div class="wrap">
        <asp:Repeater ID="rptBookings" runat="server" OnItemCommand="rptBookings_ItemCommand">
            <HeaderTemplate>
                <table>
                    <thead><tr><th>รหัส</th><th>หนัง</th><th>รอบฉาย</th><th>ที่นั่ง</th><th class="num">ยอดรวม</th><th>สถานะ</th><th></th></tr></thead>
                    <tbody>
            </HeaderTemplate>
            <ItemTemplate>
                <tr data-expire-scope="1">
                    <td>BK<%# Eval("booking_id", "{0:D6}") %></td>
                    <td><b><%# Fmt.Html(Eval("title")) %></b><div class="meta">จองเมื่อ <%# Fmt.DateTimeText(Eval("booking_time")) %></div></td>
                    <td><%# Fmt.ShortDay(Eval("start_time")) %> <%# Fmt.Time(Eval("start_time")) %><div class="meta"><%# Fmt.Html(Eval("hall_name")) %></div></td>
                    <td><%# Fmt.Html(Eval("seats")) %></td>
                    <td class="num"><%# Fmt.Baht(Eval("total_amount")) %><div class="meta"><%# Fmt.Html(Eval("promotion_code")) %></div></td>
                    <td>
                        <span class='badge <%# Fmt.BookingStatusClass(Eval("booking_status")) %>'><%# Fmt.BookingStatusText(Eval("booking_status")) %></span>
                        <%# IsOpenHold(Container.DataItem) ? "<div class=\"meta\" data-expire-hide=\"1\">เหลือ <span class=\"timer js-countdown\" data-seconds=\"" + Eval("seconds_left") + "\">--:--</span></div><div class=\"meta err\" data-expire-show=\"1\" hidden=\"hidden\">หมดเวลาแล้ว</div>" : "" %>
                    </td>
                    <td class="actions">
                        <a class="btn sm" data-expire-hide="1" href='<%# ResolveUrl("~/Pay.aspx?booking=") + Eval("booking_id") %>' <%# IsOpenHold(Container.DataItem) ? "" : "hidden=\"hidden\"" %>>ชำระเงิน</a>
                        <asp:LinkButton ID="btnCancelHold" runat="server" CssClass="btn danger sm" CommandName="cancel_hold" CommandArgument='<%# Eval("booking_id") %>' CausesValidation="false" Visible='<%# IsOpenHold(Container.DataItem) %>' data-confirm="ยืนยันยกเลิกการถือที่นั่งนี้?">ยกเลิก</asp:LinkButton>
                        <a class="btn sm ghost" href='<%# ResolveUrl("~/Ticket.aspx?booking=") + Eval("booking_id") %>' <%# Eval("booking_status").ToString() == "confirmed" ? "" : "hidden=\"hidden\"" %>>ดูตั๋ว</a>
                    </td>
                </tr>
            </ItemTemplate>
            <FooterTemplate>
                    </tbody>
                </table>
            </FooterTemplate>
        </asp:Repeater>
    </div>
</asp:Content>
