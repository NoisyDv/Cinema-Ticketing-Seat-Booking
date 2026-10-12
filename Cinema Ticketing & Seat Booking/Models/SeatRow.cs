using System.Collections.Generic;

namespace Cinema_Ticketing___Seat_Booking.Models
{
    // แถวที่นั่ง 1 แถวในผังโรง (เช่น แถว A มี A1-A10)
    public class SeatRow
    {
        public string RowLabel { get; set; }
        public List<SeatItem> Seats { get; set; }

        public SeatRow()
        {
            Seats = new List<SeatItem>();
        }
    }

    // ที่นั่ง 1 ที่ พร้อมสถานะสำหรับแสดงผล
    public class SeatItem
    {
        public int SeatId { get; set; }
        public string Label { get; set; }
        public bool IsPremium { get; set; }
        public decimal Price { get; set; }
        public bool IsTaken { get; set; }
        public bool Selected { get; set; }

        public string CssClass
        {
            get
            {
                string c = "seat";
                if (IsPremium) c += " premium";
                if (IsTaken) c += " taken";
                return c;
            }
        }

        public string DisabledAttr
        {
            get { return IsTaken ? "disabled" : ""; }
        }

        public string CheckedAttr
        {
            get { return (Selected && !IsTaken) ? "checked" : ""; }
        }
    }
}
