using System;

namespace Cinema_Ticketing___Seat_Booking.Models
{
    // ตรงกับตาราง movies ใน Database/schema.sql
    // poster_url เก็บแบบ relative path เช่น "Posters/Avatar.webp"
    // ซึ่ง map กับโฟลเดอร์ <webapp>/Posters/ โดยตรง
    public class Movie
    {
        public int MovieId { get; set; }
        public string Title { get; set; }
        public string Description { get; set; }
        public int Duration { get; set; }
        public string Genre { get; set; }
        public DateTime ReleaseDate { get; set; }
        public string Status { get; set; }
        public string PosterUrl { get; set; }

        public string DisplayDuration
        {
            get
            {
                if (Duration <= 0) return "-";
                return string.Format("{0} ชม. {1} นาที", Duration / 60, Duration % 60);
            }
        }
    }
}
