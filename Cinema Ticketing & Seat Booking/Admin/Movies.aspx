<%@ Page Title="จัดการภาพยนตร์" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Movies.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.AdminPages.Movies" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <h1>จัดการภาพยนตร์</h1>

    <asp:Panel ID="pnlForm" runat="server" Visible="false" CssClass="card">
        <h2><asp:Literal ID="litFormTitle" runat="server"></asp:Literal></h2>
        <asp:HiddenField ID="hfId" runat="server" />
        <asp:ValidationSummary ID="vsMovie" runat="server" ValidationGroup="movie" CssClass="alert err" HeaderText="กรุณาแก้ไขข้อมูลต่อไปนี้" />
        <div class="two">
            <div>
                <asp:Label ID="lblTitle" runat="server" AssociatedControlID="txtTitle" Text="ชื่อภาพยนตร์"></asp:Label>
                <asp:TextBox ID="txtTitle" runat="server" MaxLength="200"></asp:TextBox>
                <asp:RequiredFieldValidator ID="rfvTitle" runat="server" ControlToValidate="txtTitle" ValidationGroup="movie" Display="Dynamic" CssClass="field-err" ErrorMessage="กรุณากรอกชื่อภาพยนตร์" Text="กรุณากรอกชื่อภาพยนตร์"></asp:RequiredFieldValidator>

                <asp:Label ID="lblDesc" runat="server" AssociatedControlID="txtDesc" Text="เรื่องย่อ"></asp:Label>
                <asp:TextBox ID="txtDesc" runat="server" TextMode="MultiLine" Rows="4" MaxLength="2000"></asp:TextBox>
                <asp:RegularExpressionValidator ID="revDesc" runat="server" ControlToValidate="txtDesc" ValidationGroup="movie" Display="Dynamic" CssClass="field-err" ValidationExpression="^[\s\S]{0,2000}$" ErrorMessage="เรื่องย่อยาวได้ไม่เกิน 2000 ตัวอักษร" Text="เรื่องย่อยาวได้ไม่เกิน 2000 ตัวอักษร"></asp:RegularExpressionValidator>

                <asp:Label ID="lblPoster" runat="server" AssociatedControlID="txtPoster" Text="ลิงก์รูปโปสเตอร์ (ไม่บังคับ)"></asp:Label>
                <asp:TextBox ID="txtPoster" runat="server" TextMode="Url" MaxLength="500"></asp:TextBox>
                <asp:RegularExpressionValidator ID="revPoster" runat="server" ControlToValidate="txtPoster" ValidationGroup="movie" Display="Dynamic" CssClass="field-err" ValidationExpression="^https?://\S{3,490}$" ErrorMessage="ลิงก์ต้องขึ้นต้นด้วย http:// หรือ https://" Text="ลิงก์ต้องขึ้นต้นด้วย http:// หรือ https://"></asp:RegularExpressionValidator>
            </div>
            <div>
                <asp:Label ID="lblDuration" runat="server" AssociatedControlID="txtDuration" Text="ความยาว (นาที)"></asp:Label>
                <asp:TextBox ID="txtDuration" runat="server" TextMode="Number" MaxLength="3"></asp:TextBox>
                <asp:RequiredFieldValidator ID="rfvDuration" runat="server" ControlToValidate="txtDuration" ValidationGroup="movie" Display="Dynamic" CssClass="field-err" ErrorMessage="กรุณากรอกความยาว" Text="กรุณากรอกความยาว"></asp:RequiredFieldValidator>
                <asp:RangeValidator ID="rvDuration" runat="server" ControlToValidate="txtDuration" ValidationGroup="movie" Display="Dynamic" CssClass="field-err" Type="Integer" MinimumValue="1" MaximumValue="600" ErrorMessage="ความยาวต้องอยู่ระหว่าง 1-600 นาที" Text="ความยาวต้องอยู่ระหว่าง 1-600 นาที"></asp:RangeValidator>

                <asp:Label ID="lblGenre" runat="server" AssociatedControlID="ddlGenre" Text="ประเภท"></asp:Label>
                <asp:DropDownList ID="ddlGenre" runat="server"></asp:DropDownList>

                <asp:Label ID="lblRelease" runat="server" AssociatedControlID="txtRelease" Text="วันเข้าฉาย"></asp:Label>
                <asp:TextBox ID="txtRelease" runat="server" TextMode="Date"></asp:TextBox>
                <asp:RequiredFieldValidator ID="rfvRelease" runat="server" ControlToValidate="txtRelease" ValidationGroup="movie" Display="Dynamic" CssClass="field-err" ErrorMessage="กรุณาเลือกวันเข้าฉาย" Text="กรุณาเลือกวันเข้าฉาย"></asp:RequiredFieldValidator>

                <asp:Label ID="lblStatus" runat="server" AssociatedControlID="ddlStatus" Text="สถานะ"></asp:Label>
                <asp:DropDownList ID="ddlStatus" runat="server">
                    <asp:ListItem Value="active" Text="เปิดใช้งาน"></asp:ListItem>
                    <asp:ListItem Value="inactive" Text="ปิดใช้งาน"></asp:ListItem>
                </asp:DropDownList>
            </div>
        </div>
        <p>
            <asp:Button ID="btnSave" runat="server" Text="บันทึก" CssClass="btn" ValidationGroup="movie" OnClick="btnSave_Click" />
            <asp:Button ID="btnCancelEdit" runat="server" Text="ยกเลิก" CssClass="btn ghost" CausesValidation="false" OnClick="btnCancelEdit_Click" />
        </p>
    </asp:Panel>

    <div class="toolbar">
        <div><asp:Label ID="lblSearch" runat="server" AssociatedControlID="txtSearch" Text="ค้นหาชื่อหนัง"></asp:Label>
            <asp:TextBox ID="txtSearch" runat="server" MaxLength="100"></asp:TextBox></div>
        <div><asp:Label ID="lblFilter" runat="server" AssociatedControlID="ddlFilter" Text="สถานะ"></asp:Label>
            <asp:DropDownList ID="ddlFilter" runat="server">
                <asp:ListItem Value="" Text="ทั้งหมด"></asp:ListItem>
                <asp:ListItem Value="active" Text="เปิดใช้งาน"></asp:ListItem>
                <asp:ListItem Value="inactive" Text="ปิดใช้งาน"></asp:ListItem>
            </asp:DropDownList></div>
        <div style="flex:0 0 auto">
            <asp:Button ID="btnSearch" runat="server" Text="ค้นหา" CssClass="btn ghost" CausesValidation="false" OnClick="btnSearch_Click" />
            <asp:Button ID="btnNew" runat="server" Text="+ เพิ่มภาพยนตร์" CssClass="btn" CausesValidation="false" OnClick="btnNew_Click" />
        </div>
    </div>

    <div class="wrap">
        <asp:GridView ID="gv" runat="server" AutoGenerateColumns="false" AllowPaging="true" PageSize="15" GridLines="None"
            OnPageIndexChanging="gv_PageIndexChanging" OnRowCommand="gv_RowCommand" EmptyDataText="ไม่พบข้อมูล" DataKeyNames="movie_id">
            <PagerStyle CssClass="pager" />
            <Columns>
                <asp:BoundField DataField="movie_id" HeaderText="#" />
                <asp:TemplateField HeaderText="ชื่อเรื่อง"><ItemTemplate><%# Fmt.Html(Eval("title")) %></ItemTemplate></asp:TemplateField>
                <asp:BoundField DataField="genre" HeaderText="ประเภท" />
                <asp:TemplateField HeaderText="ความยาว"><ItemTemplate><%# Eval("duration") %> นาที</ItemTemplate></asp:TemplateField>
                <asp:TemplateField HeaderText="เข้าฉาย"><ItemTemplate><%# Fmt.Day(Eval("release_date")) %></ItemTemplate></asp:TemplateField>
                <asp:TemplateField HeaderText="สถานะ"><ItemTemplate><span class='badge <%# Eval("status").ToString() == "active" ? "b-ok" : "b-off" %>'><%# Fmt.ShowStatusText(Eval("status")) %></span></ItemTemplate></asp:TemplateField>
                <asp:TemplateField>
                    <ItemTemplate>
                        <span class="actions">
                            <asp:LinkButton ID="lnkEdit" runat="server" CssClass="btn sm ghost" CommandName="do_edit" CommandArgument='<%# Eval("movie_id") %>' CausesValidation="false">แก้ไข</asp:LinkButton>
                            <asp:LinkButton ID="lnkDelete" runat="server" CssClass="btn sm danger" CommandName="do_delete" CommandArgument='<%# Eval("movie_id") %>' CausesValidation="false" data-confirm="ยืนยันลบภาพยนตร์เรื่องนี้? (ลบไม่ได้ถ้ามีรอบฉายอ้างอิงอยู่)">ลบ</asp:LinkButton>
                        </span>
                    </ItemTemplate>
                </asp:TemplateField>
            </Columns>
        </asp:GridView>
    </div>
</asp:Content>
