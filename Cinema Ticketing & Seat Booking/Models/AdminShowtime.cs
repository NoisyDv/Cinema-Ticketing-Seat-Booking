namespace Cinema_Ticketing___Seat_Booking.Models
{
    // รอบฉาย 1 แถวสำหรับจอแอดมิน (รวมสถานะ + จำนวน booking ที่ยังค้าง)
    public class AdminShowtime
    {
        public int ShowtimeId { get; set; }
        public string MovieTitle { get; set; }
        public string HallName { get; set; }
        public System.DateTime StartTime { get; set; }
        public System.DateTime EndTime { get; set; }
        public decimal StandardPrice { get; set; }
        public string Status { get; set; }
        public int ActiveBookings { get; set; }

        public string DisplayStart
        {
            get { return StartTime.ToString("dd MMM yyyy HH:mm"); }
        }

        public string DisplayEnd
        {
            get { return EndTime.ToString("HH:mm"); }
        }

        // ยกเลิกได้เฉพาะรอบ scheduled ที่ยังไม่เริ่ม และไม่มี booking ค้าง
        public bool CanCancel
        {
            get
            {
                return Status == "scheduled"
                    && StartTime > System.DateTime.Now
                    && ActiveBookings == 0;
            }
        }

        public string StatusClass
        {
            get
            {
                if (Status == "scheduled") return "pill ok";
                if (Status == "completed") return "pill wait";
                return "pill off";
            }
        }
    }
}
