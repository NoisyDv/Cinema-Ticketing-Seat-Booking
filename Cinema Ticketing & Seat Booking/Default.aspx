<%@ Page Title="หนังที่กำลังฉาย" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Default.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking._Default" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <ol class="steps" aria-label="ขั้นตอนการจอง">
        <li class="on" aria-current="step">1 เลือกหนัง</li><li>2 เลือกรอบและที่นั่ง</li><li>3 ชำระเงิน</li><li>4 รับตั๋ว</li>
    </ol>
    <h1>วันนี้ดูอะไรดี</h1>
    <p class="meta">เลือกหนังที่กำลังเปิดจอง แล้วเลือกรอบและที่นั่งในหน้าถัดไป</p>

    <div class="times" role="group" aria-label="กรองตามประเภท">
        <asp:Literal ID="litGenres" runat="server"></asp:Literal>
    </div>

    <div class="grid">
        <asp:Repeater ID="rptMovies" runat="server">
            <ItemTemplate>
                <article class="card">
                    <div class="poster" style='background:<%# Fmt.GenreColor(Eval("genre")) %>'><%# Fmt.Html(Fmt.Initial(Eval("title"))) %></div>
                    <h3><%# Fmt.Html(Eval("title")) %></h3>
                    <div class="meta"><%# Fmt.Html(Eval("genre")) %> • <%# Fmt.Duration(Eval("duration")) %></div>
                    <div class="meta">รอบถัดไป <%# Fmt.ShortDay(Eval("next_start")) %> <%# Fmt.Time(Eval("next_start")) %> · <%# Eval("upcoming_showtimes") %> รอบ · เริ่ม <%# Fmt.Baht(Eval("min_price")) %></div>
                    <a class="btn block" style="margin-top:12px" href='<%# ResolveUrl("~/Showtimes.aspx?movie=") + Eval("movie_id") %>'>ดูรอบฉาย</a>
                </article>
            </ItemTemplate>
        </asp:Repeater>
    </div>
    <asp:Panel ID="pnlEmpty" runat="server" Visible="false" CssClass="card">
        <p class="meta">ไม่พบหนังในประเภทนี้ ลองเลือกประเภทอื่น</p>
    </asp:Panel>
</asp:Content>
