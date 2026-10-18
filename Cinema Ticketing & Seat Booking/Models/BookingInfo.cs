using System.Collections.Generic;

namespace Cinema_Ticketing___Seat_Booking.Models
{
    // การจอง 1 ครั้ง พร้อมที่นั่งทุกใบและการชำระเงิน (หน้าประวัติการจอง)
    public class BookingInfo
    {
        public int BookingId { get; set; }
        public string MovieTitle { get; set; }
        public System.DateTime ShowTime { get; set; }
        public string HallName { get; set; }
        public List<string> Seats { get; set; }
        public decimal TotalAmount { get; set; }
        public string BookingStatus { get; set; }
        public string PaymentMethod { get; set; }
        public string PaymentStatus { get; set; }

        public BookingInfo()
        {
            Seats = new List<string>();
        }

        public string DisplayShowTime
        {
            get { return ShowTime.ToString("dd MMM yyyy HH:mm"); }
        }

        public string DisplaySeats
        {
            get { return Seats.Count == 0 ? "-" : string.Join(", ", Seats.ToArray()); }
        }

        public string DisplayTotal
        {
            get { return TotalAmount.ToString("N2"); }
        }

        // คลาสสีของสถานะ (ใช้กับ CSS .pill)
        public string StatusClass
        {
            get
            {
                if (BookingStatus == "confirmed") return "pill ok";
                if (BookingStatus == "pending") return "pill wait";
                return "pill off";
            }
        }

        // ยกเลิกได้เฉพาะการจองที่ยังค้าง/ยืนยันแล้ว และรอบฉายยังไม่เริ่ม (ตรงกับ sp_CancelBooking)
        public bool IsCancellable
        {
            get
            {
                return (BookingStatus == "pending" || BookingStatus == "confirmed")
                    && ShowTime > System.DateTime.Now;
            }
        }
    }
}
