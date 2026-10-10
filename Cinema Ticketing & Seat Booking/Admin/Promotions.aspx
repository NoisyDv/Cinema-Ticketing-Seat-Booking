<%@ Page Title="จัดการโปรโมชัน" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Promotions.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.AdminPages.Promotions" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <h1>จัดการโปรโมชัน</h1>

    <asp:Panel ID="pnlForm" runat="server" Visible="false" CssClass="card">
        <h2><asp:Literal ID="litFormTitle" runat="server"></asp:Literal></h2>
        <asp:HiddenField ID="hfId" runat="server" />
        <asp:ValidationSummary ID="vsPromo" runat="server" ValidationGroup="promo" CssClass="alert err" HeaderText="กรุณาแก้ไขข้อมูลต่อไปนี้" />
        <div class="two">
            <div>
                <asp:Label ID="lblCode" runat="server" AssociatedControlID="txtCode" Text="โค้ดโปรโมชัน (A-Z 0-9 _ -)"></asp:Label>
                <asp:TextBox ID="txtCode" runat="server" MaxLength="50"></asp:TextBox>
                <asp:RequiredFieldValidator ID="rfvCode" runat="server" ControlToValidate="txtCode" ValidationGroup="promo" Display="Dynamic" CssClass="field-err" ErrorMessage="กรุณากรอกโค้ด" Text="กรุณากรอกโค้ด"></asp:RequiredFieldValidator>
                <asp:RegularExpressionValidator ID="revCode" runat="server" ControlToValidate="txtCode" ValidationGroup="promo" Display="Dynamic" CssClass="field-err" ValidationExpression="^[A-Za-z0-9_\-]{3,50}$" ErrorMessage="โค้ดต้องเป็น A-Z 0-9 _ - ยาว 3-50 ตัว" Text="โค้ดต้องเป็น A-Z 0-9 _ - ยาว 3-50 ตัว"></asp:RegularExpressionValidator>

                <asp:Label ID="lblType" runat="server" AssociatedControlID="ddlType" Text="ประเภทส่วนลด"></asp:Label>
                <asp:DropDownList ID="ddlType" runat="server">
                    <asp:ListItem Value="percentage" Text="เปอร์เซ็นต์ (%)"></asp:ListItem>
                    <asp:ListItem Value="fixed" Text="จำนวนเงิน (บาท)"></asp:ListItem>
                </asp:DropDownList>

                <asp:Label ID="lblValue" runat="server" AssociatedControlID="txtValue" Text="มูลค่าส่วนลด"></asp:Label>
                <asp:TextBox ID="txtValue" runat="server" MaxLength="9"></asp:TextBox>
                <asp:RequiredFieldValidator ID="rfvValue" runat="server" ControlToValidate="txtValue" ValidationGroup="promo" Display="Dynamic" CssClass="field-err" ErrorMessage="กรุณากรอกมูลค่าส่วนลด" Text="กรุณากรอกมูลค่าส่วนลด"></asp:RequiredFieldValidator>
                <asp:RegularExpressionValidator ID="revValue" runat="server" ControlToValidate="txtValue" ValidationGroup="promo" Display="Dynamic" CssClass="field-err" ValidationExpression="^[0-9]{1,6}(\.[0-9]{1,2})?$" ErrorMessage="มูลค่าต้องเป็นตัวเลข (ทศนิยมไม่เกิน 2 ตำแหน่ง)" Text="มูลค่าต้องเป็นตัวเลข (ทศนิยมไม่เกิน 2 ตำแหน่ง)"></asp:RegularExpressionValidator>
            </div>
            <div>
                <asp:Label ID="lblStart" runat="server" AssociatedControlID="txtStart" Text="วันเริ่มใช้"></asp:Label>
                <asp:TextBox ID="txtStart" runat="server" TextMode="Date"></asp:TextBox>
                <asp:RequiredFieldValidator ID="rfvStart" runat="server" ControlToValidate="txtStart" ValidationGroup="promo" Display="Dynamic" CssClass="field-err" ErrorMessage="กรุณาเลือกวันเริ่มใช้" Text="กรุณาเลือกวันเริ่มใช้"></asp:RequiredFieldValidator>

                <asp:Label ID="lblEnd" runat="server" AssociatedControlID="txtEnd" Text="วันสิ้นสุด"></asp:Label>
                <asp:TextBox ID="txtEnd" runat="server" TextMode="Date"></asp:TextBox>
                <asp:RequiredFieldValidator ID="rfvEnd" runat="server" ControlToValidate="txtEnd" ValidationGroup="promo" Display="Dynamic" CssClass="field-err" ErrorMessage="กรุณาเลือกวันสิ้นสุด" Text="กรุณาเลือกวันสิ้นสุด"></asp:RequiredFieldValidator>

                <asp:Label ID="lblStatus" runat="server" AssociatedControlID="ddlStatus" Text="สถานะ"></asp:Label>
                <asp:DropDownList ID="ddlStatus" runat="server">
                    <asp:ListItem Value="active" Text="เปิดใช้งาน"></asp:ListItem>
                    <asp:ListItem Value="inactive" Text="ปิดใช้งาน"></asp:ListItem>
                </asp:DropDownList>
            </div>
        </div>
        <p>
            <asp:Button ID="btnSave" runat="server" Text="บันทึก" CssClass="btn" ValidationGroup="promo" OnClick="btnSave_Click" />
            <asp:Button ID="btnCancelEdit" runat="server" Text="ยกเลิก" CssClass="btn ghost" CausesValidation="false" OnClick="btnCancelEdit_Click" />
        </p>
    </asp:Panel>

    <div class="toolbar"><div style="flex:0 0 auto"><asp:Button ID="btnNew" runat="server" Text="+ เพิ่มโปรโมชัน" CssClass="btn" CausesValidation="false" OnClick="btnNew_Click" /></div></div>

    <div class="wrap">
        <asp:GridView ID="gv" runat="server" AutoGenerateColumns="false" AllowPaging="true" PageSize="15" GridLines="None"
            OnPageIndexChanging="gv_PageIndexChanging" OnRowCommand="gv_RowCommand" EmptyDataText="ไม่พบข้อมูล" DataKeyNames="promotion_id">
            <PagerStyle CssClass="pager" />
            <Columns>
                <asp:BoundField DataField="promotion_id" HeaderText="#" />
                <asp:BoundField DataField="promotion_code" HeaderText="โค้ด" />
                <asp:TemplateField HeaderText="ส่วนลด"><ItemTemplate><%# DiscountText(Eval("discount_type"), Eval("discount_value")) %></ItemTemplate></asp:TemplateField>
                <asp:TemplateField HeaderText="ช่วงเวลา"><ItemTemplate><%# Fmt.Day(Eval("start_date")) %> – <%# Fmt.Day(Eval("end_date")) %></ItemTemplate></asp:TemplateField>
                <asp:TemplateField HeaderText="ใช้แล้ว"><ItemTemplate><%# Eval("times_used") %> ครั้ง</ItemTemplate></asp:TemplateField>
                <asp:TemplateField HeaderText="สถานะ"><ItemTemplate><span class='badge <%# Eval("status").ToString() == "active" ? "b-ok" : "b-off" %>'><%# Fmt.ShowStatusText(Eval("status")) %></span></ItemTemplate></asp:TemplateField>
                <asp:TemplateField>
                    <ItemTemplate>
                        <span class="actions">
                            <asp:LinkButton ID="lnkEdit" runat="server" CssClass="btn sm ghost" CommandName="do_edit" CommandArgument='<%# Eval("promotion_id") %>' CausesValidation="false">แก้ไข</asp:LinkButton>
                            <asp:LinkButton ID="lnkDelete" runat="server" CssClass="btn sm danger" CommandName="do_delete" CommandArgument='<%# Eval("promotion_id") %>' CausesValidation="false" data-confirm="ยืนยันลบโปรโมชันนี้? การจองเดิมที่เคยใช้โค้ดนี้จะไม่แสดงโค้ดอีกต่อไป (ยอดเงินไม่เปลี่ยน)">ลบ</asp:LinkButton>
                        </span>
                    </ItemTemplate>
                </asp:TemplateField>
            </Columns>
        </asp:GridView>
    </div>
</asp:Content>
