<%@ Page Title="ชำระเงิน" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Pay.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.Pay" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <ol class="steps" aria-label="ขั้นตอนการจอง">
        <li class="done">✓ 1 เลือกหนัง</li><li class="done">✓ 2 เลือกรอบและที่นั่ง</li><li class="on" aria-current="step">3 ชำระเงิน</li><li>4 รับตั๋ว</li>
    </ol>

    <asp:Panel ID="pnlMissing" runat="server" Visible="false" CssClass="card">
        <h2>ไม่พบการจองนี้</h2>
        <p class="meta">การจองอาจไม่ใช่ของคุณหรือถูกลบไปแล้ว</p>
        <a class="btn" href="<%= ResolveUrl("~/MyBookings.aspx") %>">ไปที่การจองของฉัน</a>
    </asp:Panel>

    <asp:Panel ID="pnlClosed" runat="server" Visible="false" CssClass="card">
        <h2><asp:Literal ID="litClosedTitle" runat="server"></asp:Literal></h2>
        <p class="meta"><asp:Literal ID="litClosedText" runat="server"></asp:Literal></p>
        <a class="btn" href="<%= ResolveUrl("~/Default.aspx") %>">เลือกหนังใหม่</a>
        <a class="btn ghost" href="<%= ResolveUrl("~/MyBookings.aspx") %>">การจองของฉัน</a>
    </asp:Panel>

    <asp:Panel ID="pnlPay" runat="server" Visible="false">
        <div data-expire-scope="1">
            <div class="alert" data-expire-show="1" hidden="hidden" id="expiredBox">
                <b>หมดเวลาถือที่นั่งแล้ว</b> ที่นั่งถูกปล่อยให้ผู้อื่นแล้ว กรุณาเลือกที่นั่งใหม่
                <a class="btn sm" href="<%= ResolveUrl("~/Default.aspx") %>">เลือกหนังใหม่</a>
            </div>
            <div class="two" data-expire-hide="1">
                <div class="card">
                    <h2>ชำระเงิน</h2>
                    <p>เหลือเวลาถือที่นั่ง <span class="timer js-countdown" id="countdown" data-seconds='<%= SecondsLeft %>'>--:--</span> นาที</p>
                    <asp:ValidationSummary ID="vsPay" runat="server" ValidationGroup="pay" CssClass="alert err" HeaderText="กรุณาแก้ไขข้อมูลต่อไปนี้" />

                    <div class="lbl">ช่องทางชำระเงิน</div>
                    <asp:RadioButtonList ID="rblMethod" runat="server" RepeatLayout="Flow" RepeatDirection="Horizontal" CssClass="pay-methods">
                        <asp:ListItem Value="online" Selected="True" Text="ออนไลน์ (พร้อมเพย์/QR)"></asp:ListItem>
                        <asp:ListItem Value="card" Text="บัตรเครดิต/เดบิต"></asp:ListItem>
                        <asp:ListItem Value="cash" Text="เงินสดที่เคาน์เตอร์"></asp:ListItem>
                    </asp:RadioButtonList>

                    <asp:Label ID="lblPromo" runat="server" AssociatedControlID="txtPromo" Text="โค้ดโปรโมชัน (ถ้ามี)"></asp:Label>
                    <asp:TextBox ID="txtPromo" runat="server" MaxLength="50" placeholder="เช่น WELCOME50"></asp:TextBox>
                    <asp:RegularExpressionValidator ID="revPromo" runat="server" ControlToValidate="txtPromo" ValidationGroup="pay" Display="Dynamic" CssClass="field-err" ValidationExpression="^[A-Za-z0-9_\-]{3,50}$" ErrorMessage="โค้ดต้องเป็นตัวอักษร/ตัวเลข 3-50 ตัว" Text="โค้ดต้องเป็นตัวอักษร/ตัวเลข 3-50 ตัว"></asp:RegularExpressionValidator>
                    <p><asp:Button ID="btnCheckPromo" runat="server" Text="ตรวจสอบโค้ด" CssClass="btn ghost sm" ValidationGroup="pay" OnClick="btnCheckPromo_Click" />
                       <asp:Label ID="lblPromoMsg" runat="server" CssClass="msg"></asp:Label></p>

                    <p>
                        <asp:Button ID="btnPay" runat="server" Text="ยืนยันชำระเงิน" CssClass="btn" ValidationGroup="pay" OnClick="btnPay_Click" />
                        <asp:Button ID="btnCancel" runat="server" Text="ยกเลิกการถือที่นั่ง" CssClass="btn danger" CausesValidation="false" OnClick="btnCancel_Click" data-confirm="ยืนยันยกเลิกการถือที่นั่ง? ที่นั่งจะถูกปล่อยทันที" />
                    </p>
                </div>
                <div class="card">
                    <h2>สรุปการจอง</h2>
                    <div class="sum"><span>หนัง</span><b><asp:Literal ID="litMovie" runat="server"></asp:Literal></b></div>
                    <div class="sum"><span>รอบฉาย</span><span><asp:Literal ID="litShow" runat="server"></asp:Literal></span></div>
                    <div class="sum"><span>โรง</span><span><asp:Literal ID="litHall" runat="server"></asp:Literal></span></div>
                    <div class="sum"><span>ที่นั่ง</span><b><asp:Literal ID="litSeats" runat="server"></asp:Literal></b></div>
                    <div class="sum"><span>ราคาก่อนส่วนลด</span><span><asp:Literal ID="litSubtotal" runat="server"></asp:Literal></span></div>
                    <div class="sum"><span>ส่วนลด</span><span><asp:Literal ID="litDiscount" runat="server"></asp:Literal></span></div>
                    <div class="sum total"><span>ยอดชำระ</span><span><asp:Literal ID="litTotal" runat="server"></asp:Literal></span></div>
                </div>
            </div>
        </div>
    </asp:Panel>
</asp:Content>
