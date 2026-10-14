namespace Cinema_Ticketing___Seat_Booking.Models
{
    // ตรงกับตาราง promotions (อ่าน + เปิด/ปิดสถานะ)
    public class Promotion
    {
        public int PromotionId { get; set; }
        public string Code { get; set; }
        public string DiscountType { get; set; }
        public decimal DiscountValue { get; set; }
        public System.DateTime StartDate { get; set; }
        public System.DateTime EndDate { get; set; }
        public string Status { get; set; }

        public string DisplayDiscount
        {
            get
            {
                if (DiscountType == "percentage")
                    return DiscountValue.ToString("N0") + "%";
                return DiscountValue.ToString("N2") + " บาท";
            }
        }

        public string DisplayPeriod
        {
            get
            {
                return StartDate.ToString("dd MMM yyyy") + " - " + EndDate.ToString("dd MMM yyyy");
            }
        }

        public string StatusClass
        {
            get { return Status == "active" ? "pill ok" : "pill off"; }
        }
    }
}
