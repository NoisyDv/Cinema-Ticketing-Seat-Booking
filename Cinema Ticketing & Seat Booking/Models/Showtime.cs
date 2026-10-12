using System;

namespace Cinema_Ticketing___Seat_Booking.Models
{
    // ตรงกับตาราง showtimes + cinema_halls (อ่านอย่างเดียว)
    // SeatsLeft = capacity - ที่นั่งที่ถูกถืออยู่ (นิยามเดียวกับ sp_BookMovieSeats)
    public class Showtime
    {
        public int ShowtimeId { get; set; }
        public int MovieId { get; set; }
        public string HallName { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public decimal StandardPrice { get; set; }
        public int SeatsLeft { get; set; }

        public string DisplayStart
        {
            get { return StartTime.ToString("dd MMM yyyy HH:mm"); }
        }

        public string DisplayEnd
        {
            get { return EndTime.ToString("HH:mm"); }
        }

        public string DisplayPrice
        {
            get { return StandardPrice.ToString("N2"); }
        }

        public string DisplaySeatsLeft
        {
            get { return SeatsLeft <= 0 ? "เต็ม" : SeatsLeft.ToString(); }
        }
    }
}
