namespace Cinema_Ticketing___Seat_Booking.Models
{
    // แถวรายงาน 1 เรื่องจาก vw_BoxOfficeOccupancyReport (Database/logic.sql)
    public class BoxOfficeRow
    {
        public int Rank { get; set; }
        public int MovieId { get; set; }
        public string MovieTitle { get; set; }
        public string Genre { get; set; }
        public int TotalShowtimes { get; set; }
        public int TicketsSold { get; set; }
        public decimal TotalRevenue { get; set; }
        public decimal OccupancyRate { get; set; }

        public string DisplayRevenue
        {
            get { return TotalRevenue.ToString("N2"); }
        }

        public string DisplayOccupancy
        {
            get { return OccupancyRate.ToString("N2"); }
        }

        // ความกว้างแท่งกราฟ (กันเกิน 0-100)
        public int BarWidth
        {
            get
            {
                if (OccupancyRate <= 0) return 0;
                if (OccupancyRate >= 100) return 100;
                return (int)OccupancyRate;
            }
        }
    }
}
