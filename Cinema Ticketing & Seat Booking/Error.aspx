<%@ Page Title="เกิดข้อผิดพลาด" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Error.aspx.cs" Inherits="Cinema_Ticketing___Seat_Booking.ErrorPage" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <div class="form-narrow card">
        <h1>เกิดข้อผิดพลาด</h1>
        <p>ขออภัย ระบบไม่สามารถทำรายการได้ในขณะนี้ กรุณาลองใหม่อีกครั้ง หากยังพบปัญหา ให้แจ้งผู้ดูแลระบบ</p>
        <p class="meta">รายละเอียดทางเทคนิคถูกบันทึกไว้ฝั่งเซิร์ฟเวอร์แล้ว</p>
        <a class="btn" href="<%= ResolveUrl("~/Default.aspx") %>">กลับหน้าแรก</a>
    </div>
</asp:Content>
