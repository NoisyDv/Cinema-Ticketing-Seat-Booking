<%@ Page Title="รายงาน Box Office" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="BoxOffice.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.AdminPages.BoxOffice" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <h1>รายงาน Box Office</h1>
    <p class="meta">ข้อมูลจากวิว <code>vw_BoxOfficeOccupancyReport</code> — รายได้นับเฉพาะตั๋วที่ออกแล้ว (issued) อัตราการครองที่นั่ง = ตั๋วที่ขาย ÷ ที่นั่งรวมของรอบที่เปิด/ฉายแล้ว</p>
    <div class="toolbar">
        <div><asp:Label ID="lblGenre" runat="server" AssociatedControlID="ddlGenre" Text="ประเภท"></asp:Label>
            <asp:DropDownList ID="ddlGenre" runat="server"></asp:DropDownList></div>
        <div><asp:Label ID="lblTop" runat="server" AssociatedControlID="ddlTop" Text="แสดงสูงสุด"></asp:Label>
            <asp:DropDownList ID="ddlTop" runat="server">
                <asp:ListItem Value="20" Text="20 อันดับ"></asp:ListItem>
                <asp:ListItem Value="50" Selected="True" Text="50 อันดับ"></asp:ListItem>
                <asp:ListItem Value="100" Text="100 อันดับ"></asp:ListItem>
                <asp:ListItem Value="500" Text="ทั้งหมด (สูงสุด 500)"></asp:ListItem>
            </asp:DropDownList></div>
        <div style="flex:0 0 auto"><label><asp:CheckBox ID="chkSold" runat="server" Checked="true" /> เฉพาะเรื่องที่มีตั๋วขายแล้ว</label></div>
        <div style="flex:0 0 auto"><asp:Button ID="btnApply" runat="server" Text="แสดงรายงาน" CssClass="btn" CausesValidation="false" OnClick="btnApply_Click" /></div>
    </div>
    <div class="stats">
        <div class="card stat"><span class="meta">จำนวนเรื่องในรายงาน</span><b><asp:Literal ID="litCount" runat="server">0</asp:Literal></b></div>
        <div class="card stat"><span class="meta">ตั๋วที่ขาย</span><b><asp:Literal ID="litTickets" runat="server">0</asp:Literal></b></div>
        <div class="card stat"><span class="meta">รายได้รวม</span><b><asp:Literal ID="litRevenue" runat="server">฿0</asp:Literal></b></div>
    </div>
    <asp:Panel ID="pnlEmpty" runat="server" Visible="false" CssClass="card"><p class="meta">ไม่พบข้อมูลตามเงื่อนไขที่เลือก</p></asp:Panel>
    <div class="wrap">
        <asp:Repeater ID="rptReport" runat="server">
            <HeaderTemplate>
                <table>
                    <thead><tr><th>#</th><th>ภาพยนตร์</th><th>ประเภท</th><th class="num">รอบฉาย</th><th class="num">ตั๋วที่ขาย</th><th class="num">รายได้</th><th>การครองที่นั่ง</th></tr></thead>
                    <tbody>
            </HeaderTemplate>
            <ItemTemplate>
                <tr>
                    <td><%# Container.ItemIndex + 1 %></td>
                    <td><b><%# Fmt.Html(Eval("movie_title")) %></b></td>
                    <td><%# Fmt.Html(Eval("genre")) %></td>
                    <td class="num"><%# Eval("total_showtimes") %></td>
                    <td class="num"><%# Eval("tickets_sold") %></td>
                    <td class="num"><%# Fmt.Baht(Eval("total_revenue")) %></td>
                    <td><div class="meter" role="img" aria-label='ครองที่นั่ง <%# Pct(Eval("occupancy_rate_percent")) %> เปอร์เซ็นต์'><b style='width:<%# Pct(Eval("occupancy_rate_percent")) %>%'></b></div>
                        <span class="meta"><%# Pct(Eval("occupancy_rate_percent")) %>%</span></td>
                </tr>
            </ItemTemplate>
            <FooterTemplate></tbody></table></FooterTemplate>
        </asp:Repeater>
    </div>
</asp:Content>
