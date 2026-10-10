<%@ Page Title="จัดการรอบฉาย" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Showtimes.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.AdminPages.Showtimes" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <h1>จัดการรอบฉาย</h1>
    <p class="meta">ระบบจะไม่อนุญาตให้รอบฉายทับซ้อนเวลากันในโรงเดียวกัน (ตรวจโดย trigger ในฐานข้อมูล) รอบที่ยกเลิกไม่นับ</p>

    <asp:Panel ID="pnlForm" runat="server" Visible="false" CssClass="card">
        <h2><asp:Literal ID="litFormTitle" runat="server"></asp:Literal></h2>
        <asp:HiddenField ID="hfId" runat="server" />
        <asp:ValidationSummary ID="vsShow" runat="server" ValidationGroup="show" CssClass="alert err" HeaderText="กรุณาแก้ไขข้อมูลต่อไปนี้" />
        <div class="two">
            <div>
                <asp:Label ID="lblMovie" runat="server" AssociatedControlID="ddlMovie" Text="ภาพยนตร์"></asp:Label>
                <asp:DropDownList ID="ddlMovie" runat="server" DataTextField="title" DataValueField="movie_id"></asp:DropDownList>
                <asp:Label ID="lblHall" runat="server" AssociatedControlID="ddlHall" Text="โรงภาพยนตร์"></asp:Label>
                <asp:DropDownList ID="ddlHall" runat="server" DataTextField="hall_name" DataValueField="hall_id"></asp:DropDownList>
                <asp:Label ID="lblStatus" runat="server" AssociatedControlID="ddlStatus" Text="สถานะ"></asp:Label>
                <asp:DropDownList ID="ddlStatus" runat="server">
                    <asp:ListItem Value="scheduled" Text="เปิดจอง (scheduled)"></asp:ListItem>
                    <asp:ListItem Value="completed" Text="ฉายแล้ว (completed)"></asp:ListItem>
                    <asp:ListItem Value="cancelled" Text="ยกเลิก (cancelled)"></asp:ListItem>
                </asp:DropDownList>
            </div>
            <div>
                <asp:Label ID="lblStart" runat="server" AssociatedControlID="txtStart" Text="เวลาเริ่มฉาย"></asp:Label>
                <asp:TextBox ID="txtStart" runat="server" TextMode="DateTimeLocal"></asp:TextBox>
                <asp:RequiredFieldValidator ID="rfvStart" runat="server" ControlToValidate="txtStart" ValidationGroup="show" Display="Dynamic" CssClass="field-err" ErrorMessage="กรุณาระบุเวลาเริ่มฉาย" Text="กรุณาระบุเวลาเริ่มฉาย"></asp:RequiredFieldValidator>

                <asp:Label ID="lblEnd" runat="server" AssociatedControlID="txtEnd" Text="เวลาจบ (เว้นว่าง = ความยาวหนัง + 15 นาที)"></asp:Label>
                <asp:TextBox ID="txtEnd" runat="server" TextMode="DateTimeLocal"></asp:TextBox>

                <asp:Label ID="lblPrice" runat="server" AssociatedControlID="txtPrice" Text="ราคาตั๋ว (บาท)"></asp:Label>
                <asp:TextBox ID="txtPrice" runat="server" MaxLength="9"></asp:TextBox>
                <asp:RequiredFieldValidator ID="rfvPrice" runat="server" ControlToValidate="txtPrice" ValidationGroup="show" Display="Dynamic" CssClass="field-err" ErrorMessage="กรุณากรอกราคาตั๋ว" Text="กรุณากรอกราคาตั๋ว"></asp:RequiredFieldValidator>
                <asp:RegularExpressionValidator ID="revPrice" runat="server" ControlToValidate="txtPrice" ValidationGroup="show" Display="Dynamic" CssClass="field-err" ValidationExpression="^[0-9]{1,5}(\.[0-9]{1,2})?$" ErrorMessage="ราคาต้องเป็นตัวเลข 0-99999 (ทศนิยมไม่เกิน 2 ตำแหน่ง)" Text="ราคาต้องเป็นตัวเลข 0-99999 (ทศนิยมไม่เกิน 2 ตำแหน่ง)"></asp:RegularExpressionValidator>
            </div>
        </div>
        <p>
            <asp:Button ID="btnSave" runat="server" Text="บันทึก" CssClass="btn" ValidationGroup="show" OnClick="btnSave_Click" />
            <asp:Button ID="btnCancelEdit" runat="server" Text="ยกเลิก" CssClass="btn ghost" CausesValidation="false" OnClick="btnCancelEdit_Click" />
        </p>
    </asp:Panel>

    <div class="toolbar">
        <div><asp:Label ID="lblFilter" runat="server" AssociatedControlID="ddlFilter" Text="กรองสถานะ"></asp:Label>
            <asp:DropDownList ID="ddlFilter" runat="server" AutoPostBack="true" OnSelectedIndexChanged="ddlFilter_SelectedIndexChanged">
                <asp:ListItem Value="" Text="ทั้งหมด"></asp:ListItem>
                <asp:ListItem Value="scheduled" Text="เปิดจอง"></asp:ListItem>
                <asp:ListItem Value="completed" Text="ฉายแล้ว"></asp:ListItem>
                <asp:ListItem Value="cancelled" Text="ยกเลิก"></asp:ListItem>
            </asp:DropDownList></div>
        <div style="flex:0 0 auto"><asp:Button ID="btnNew" runat="server" Text="+ เพิ่มรอบฉาย" CssClass="btn" CausesValidation="false" OnClick="btnNew_Click" /></div>
    </div>

    <div class="wrap">
        <asp:GridView ID="gv" runat="server" AutoGenerateColumns="false" AllowPaging="true" PageSize="15" GridLines="None"
            OnPageIndexChanging="gv_PageIndexChanging" OnRowCommand="gv_RowCommand" EmptyDataText="ไม่พบข้อมูล" DataKeyNames="showtime_id">
            <PagerStyle CssClass="pager" />
            <Columns>
                <asp:BoundField DataField="showtime_id" HeaderText="#" />
                <asp:TemplateField HeaderText="ภาพยนตร์"><ItemTemplate><%# Fmt.Html(Eval("title")) %></ItemTemplate></asp:TemplateField>
                <asp:BoundField DataField="hall_name" HeaderText="โรง" />
                <asp:TemplateField HeaderText="เวลา"><ItemTemplate><%# Fmt.ShortDay(Eval("start_time")) %> <%# Fmt.Time(Eval("start_time")) %> – <%# Fmt.Time(Eval("end_time")) %></ItemTemplate></asp:TemplateField>
                <asp:TemplateField HeaderText="ราคา"><ItemTemplate><%# Fmt.Baht(Eval("ticket_price")) %></ItemTemplate></asp:TemplateField>
                <asp:TemplateField HeaderText="การจอง"><ItemTemplate><%# Eval("active_bookings") %></ItemTemplate></asp:TemplateField>
                <asp:TemplateField HeaderText="สถานะ"><ItemTemplate><span class='badge <%# Eval("status").ToString() == "scheduled" ? "b-ok" : "b-off" %>'><%# Fmt.ShowStatusText(Eval("status")) %></span></ItemTemplate></asp:TemplateField>
                <asp:TemplateField>
                    <ItemTemplate>
                        <span class="actions">
                            <asp:LinkButton ID="lnkEdit" runat="server" CssClass="btn sm ghost" CommandName="do_edit" CommandArgument='<%# Eval("showtime_id") %>' CausesValidation="false">แก้ไข</asp:LinkButton>
                            <asp:LinkButton ID="lnkDelete" runat="server" CssClass="btn sm danger" CommandName="do_delete" CommandArgument='<%# Eval("showtime_id") %>' CausesValidation="false" data-confirm="ยืนยันลบรอบฉายนี้? (ลบไม่ได้ถ้ามีการจองอยู่ ให้ยกเลิกรอบแทน)">ลบ</asp:LinkButton>
                        </span>
                    </ItemTemplate>
                </asp:TemplateField>
            </Columns>
        </asp:GridView>
    </div>
</asp:Content>
