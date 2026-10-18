using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using Cinema_Ticketing___Seat_Booking.Models;

namespace Cinema_Ticketing___Seat_Booking.Data
{
    // อ่านหนังจาก SQL Server ก่อน (ตาราง movies ใน Database/schema.sql)
    // ถ้าต่อ DB ไม่ได้ จะ fallback เป็นข้อมูลสำรองที่ถอดมาจาก Database/data.sql
    // เพื่อให้หน้าเว็บยังแสดงโปสเตอร์ใน /Posters ได้เสมอ
    //
    // SQL ที่ใช้ตรงกับแนวคิดใน Database/queries.sql:
    //   - กรอง status = 'active', ค้นหาตาม title/genre, เรียงตาม title
    public class MovieRepository
    {
        // ชุดสำรอง: คัดลอกจาก Database/data.sql (INSERT INTO movies 30 แถว)
        private static readonly List<Movie> Seed = new List<Movie>
        {
            new Movie { MovieId = 1, Title = "Avatar", Description = "A paraplegic marine is sent to the moon Pandora and is torn between following orders and protecting the Na'vi people.", Duration = 162, Genre = "Sci-Fi", ReleaseDate = new DateTime(2009, 12, 18), Status = "active", PosterUrl = "Posters/Avatar.webp" },
            new Movie { MovieId = 2, Title = "Avengers: Endgame", Description = "The surviving Avengers assemble once more to undo the damage caused by Thanos.", Duration = 181, Genre = "Action", ReleaseDate = new DateTime(2019, 04, 26), Status = "active", PosterUrl = "Posters/Avengers_Endgame.webp" },
            new Movie { MovieId = 3, Title = "Deadpool & Wolverine", Description = "Deadpool is pulled into a multiverse mission and must team up with a reluctant Wolverine.", Duration = 128, Genre = "Action", ReleaseDate = new DateTime(2024, 07, 26), Status = "active", PosterUrl = "Posters/Deadpool_Wolverine.webp" },
            new Movie { MovieId = 4, Title = "Digger", Description = "A wealthy tycoon scrambles to convince the world he is its savior while a catastrophe he set in motion threatens everything.", Duration = 129, Genre = "Comedy", ReleaseDate = new DateTime(2026, 10, 02), Status = "active", PosterUrl = "Posters/Digger.webp" },
            new Movie { MovieId = 5, Title = "Everything Everywhere All at Once", Description = "A laundromat owner is swept into a multiverse adventure where she alone can save reality.", Duration = 139, Genre = "Sci-Fi", ReleaseDate = new DateTime(2022, 03, 25), Status = "active", PosterUrl = "Posters/Everything Everywhere_All_at_Once.webp" },
            new Movie { MovieId = 6, Title = "Finding Nemo", Description = "An overprotective clownfish crosses the ocean to rescue his son with the help of a forgetful blue tang.", Duration = 100, Genre = "Animation", ReleaseDate = new DateTime(2003, 05, 30), Status = "active", PosterUrl = "Posters/Finding_Nemo.webp" },
            new Movie { MovieId = 7, Title = "Forrest Gump", Description = "A kind-hearted man with a low IQ unwittingly takes part in several defining events of American history.", Duration = 142, Genre = "Drama", ReleaseDate = new DateTime(1994, 07, 06), Status = "active", PosterUrl = "Posters/Forrest_Gump.webp" },
            new Movie { MovieId = 8, Title = "Frozen", Description = "A fearless princess sets out to find her sister, whose icy powers have trapped their kingdom in eternal winter.", Duration = 102, Genre = "Animation", ReleaseDate = new DateTime(2013, 11, 27), Status = "active", PosterUrl = "Posters/Frozen.webp" },
            new Movie { MovieId = 9, Title = "Godzilla", Description = "Humanity faces ancient giant monsters as Godzilla rises to restore the balance of nature.", Duration = 123, Genre = "Action", ReleaseDate = new DateTime(2014, 05, 16), Status = "active", PosterUrl = "Posters/Godzilla.webp" },
            new Movie { MovieId = 10, Title = "Harry Potter and the Philosopher's Stone", Description = "An orphaned boy discovers he is a wizard and begins his first year at Hogwarts School of Witchcraft and Wizardry.", Duration = 152, Genre = "Fantasy", ReleaseDate = new DateTime(2001, 11, 16), Status = "active", PosterUrl = "Posters/Harry_Potter_and_the_Philosopher's_Stone.webp" },
            new Movie { MovieId = 11, Title = "Inception", Description = "A thief who steals secrets through dreams is offered a chance at redemption by planting an idea in a target's mind.", Duration = 148, Genre = "Sci-Fi", ReleaseDate = new DateTime(2010, 07, 16), Status = "active", PosterUrl = "Posters/Inception.webp" },
            new Movie { MovieId = 12, Title = "Inside Out", Description = "The emotions inside a young girl's mind struggle to guide her through a difficult move to a new city.", Duration = 95, Genre = "Animation", ReleaseDate = new DateTime(2015, 06, 19), Status = "active", PosterUrl = "Posters/Inside_Out.webp" },
            new Movie { MovieId = 13, Title = "Interstellar", Description = "Explorers travel through a wormhole in search of a new home for humanity as Earth faces collapse.", Duration = 169, Genre = "Sci-Fi", ReleaseDate = new DateTime(2014, 11, 07), Status = "active", PosterUrl = "Posters/Interstellar.webp" },
            new Movie { MovieId = 14, Title = "Joker", Description = "A struggling comedian in Gotham City descends into madness and becomes a symbol of chaos.", Duration = 122, Genre = "Drama", ReleaseDate = new DateTime(2019, 10, 04), Status = "active", PosterUrl = "Posters/Joker.webp" },
            new Movie { MovieId = 15, Title = "Jurassic Park", Description = "A theme park of cloned dinosaurs turns deadly when its security systems fail.", Duration = 127, Genre = "Sci-Fi", ReleaseDate = new DateTime(1993, 06, 11), Status = "active", PosterUrl = "Posters/Jurassic_Park.webp" },
            new Movie { MovieId = 16, Title = "Mad Max: Fury Road", Description = "In a desert wasteland, Max joins Furiosa in a high-speed escape from a tyrannical warlord.", Duration = 120, Genre = "Action", ReleaseDate = new DateTime(2015, 05, 15), Status = "active", PosterUrl = "Posters/Mad_Max_Fury_Road.webp" },
            new Movie { MovieId = 17, Title = "The Matrix", Description = "A hacker learns that reality is a simulation and joins a rebellion against its machine controllers.", Duration = 136, Genre = "Sci-Fi", ReleaseDate = new DateTime(1999, 03, 31), Status = "active", PosterUrl = "Posters/Matrix.webp" },
            new Movie { MovieId = 18, Title = "Parasite", Description = "A poor family schemes its way into the lives of a wealthy household with unexpected consequences.", Duration = 132, Genre = "Thriller", ReleaseDate = new DateTime(2019, 05, 30), Status = "active", PosterUrl = "Posters/Parasite.webp" },
            new Movie { MovieId = 19, Title = "Skyfall", Description = "Bond's loyalty to M is tested when her past comes back to haunt MI6.", Duration = 143, Genre = "Action", ReleaseDate = new DateTime(2012, 10, 26), Status = "active", PosterUrl = "Posters/Skyfall.webp" },
            new Movie { MovieId = 20, Title = "Spirited Away", Description = "A young girl wanders into a world of spirits and must work in a bathhouse to free her parents.", Duration = 125, Genre = "Animation", ReleaseDate = new DateTime(2001, 07, 20), Status = "active", PosterUrl = "Posters/Spirited_Away.webp" },
            new Movie { MovieId = 21, Title = "Star Wars", Description = "A farm boy joins a rebel alliance to rescue a princess and stop the Empire's ultimate weapon.", Duration = 121, Genre = "Sci-Fi", ReleaseDate = new DateTime(1977, 05, 25), Status = "active", PosterUrl = "Posters/Star_Wars.jpg" },
            new Movie { MovieId = 22, Title = "The Dark Knight", Description = "Batman faces the Joker, a criminal mastermind who pushes Gotham to the edge.", Duration = 152, Genre = "Action", ReleaseDate = new DateTime(2008, 07, 18), Status = "active", PosterUrl = "Posters/The_Dark_Knight.webp" },
            new Movie { MovieId = 23, Title = "The Godfather", Description = "The aging patriarch of a crime dynasty transfers control of his empire to his reluctant son.", Duration = 175, Genre = "Drama", ReleaseDate = new DateTime(1972, 03, 24), Status = "active", PosterUrl = "Posters/The_Godfather.webp" },
            new Movie { MovieId = 24, Title = "The Hunger Games", Description = "A teenager volunteers to take her sister's place in a televised fight to the death.", Duration = 142, Genre = "Sci-Fi", ReleaseDate = new DateTime(2012, 03, 23), Status = "active", PosterUrl = "Posters/The_Hunger_Games.webp" },
            new Movie { MovieId = 25, Title = "The Lion King", Description = "A young lion prince flees his kingdom after his father's death, then returns to claim his place.", Duration = 88, Genre = "Animation", ReleaseDate = new DateTime(1994, 06, 24), Status = "active", PosterUrl = "Posters/The_Lion_King.webp" },
            new Movie { MovieId = 26, Title = "The Lord of the Rings: The Fellowship of the Ring", Description = "A hobbit and a fellowship of allies set out to destroy the One Ring and defeat the Dark Lord Sauron.", Duration = 178, Genre = "Fantasy", ReleaseDate = new DateTime(2001, 12, 19), Status = "active", PosterUrl = "Posters/The_Lord_of_the_Ring_The_Fellowship_of_the_Ring.webp" },
            new Movie { MovieId = 27, Title = "The Shawshank Redemption", Description = "Two imprisoned men bond over the years, finding solace and eventual redemption through acts of decency.", Duration = 142, Genre = "Drama", ReleaseDate = new DateTime(1994, 09, 23), Status = "active", PosterUrl = "Posters/The_Shawshank_Redemption.webp" },
            new Movie { MovieId = 28, Title = "Titanic", Description = "A young aristocrat and a penniless artist fall in love aboard the ill-fated RMS Titanic.", Duration = 194, Genre = "Romance", ReleaseDate = new DateTime(1997, 12, 19), Status = "active", PosterUrl = "Posters/Titanic.webp" },
            new Movie { MovieId = 29, Title = "Toy Story", Description = "A cowboy doll feels threatened when a new space ranger toy becomes his owner's favorite.", Duration = 81, Genre = "Animation", ReleaseDate = new DateTime(1995, 11, 22), Status = "active", PosterUrl = "Posters/Toy_Story.webp" },
            new Movie { MovieId = 30, Title = "Up", Description = "An elderly widower ties thousands of balloons to his house and sets off for South America with an unexpected stowaway.", Duration = 96, Genre = "Animation", ReleaseDate = new DateTime(2009, 05, 29), Status = "active", PosterUrl = "Posters/Up.webp" },
        };

        public List<Movie> GetMovies(string genre, string keyword, out bool fromDatabase, out string statusMessage)
        {
            genre = string.IsNullOrWhiteSpace(genre) || genre == "ทั้งหมด" ? null : genre.Trim();
            keyword = string.IsNullOrWhiteSpace(keyword) ? null : keyword.Trim();

            try
            {
                var list = QueryDatabase(genre, keyword);
                fromDatabase = true;
                statusMessage = string.Format("เชื่อมต่อ SQL Server สำเร็จ แสดง {0} เรื่องจากตาราง movies", list.Count);
                return list;
            }
            catch (Exception ex)
            {
                fromDatabase = false;
                var q = Seed.AsEnumerable();
                if (genre != null)
                    q = q.Where(m => string.Equals(m.Genre, genre, StringComparison.OrdinalIgnoreCase));
                if (keyword != null)
                    q = q.Where(m => m.Title.IndexOf(keyword, StringComparison.OrdinalIgnoreCase) >= 0
                                  || m.Genre.IndexOf(keyword, StringComparison.OrdinalIgnoreCase) >= 0);
                var list = q.OrderBy(m => m.Title).ToList();
                statusMessage = "ต่อฐานข้อมูลไม่ได้ จึงใช้ข้อมูลสำรองจาก Database/data.sql (" + FirstLine(ex.Message) + ")";
                return list;
            }
        }

        public List<string> GetGenres()
        {
            try
            {
                using (var conn = Db.Open())
                using (var cmd = new SqlCommand(
                    "SELECT DISTINCT genre FROM movies WHERE status = 'active' ORDER BY genre", conn))
                using (var rd = cmd.ExecuteReader())
                {
                    var genres = new List<string>();
                    while (rd.Read()) genres.Add(rd.GetString(0));
                    if (genres.Count > 0) return genres;
                }
            }
            catch
            {
                // ตกไปใช้ seed ด้านล่าง
            }
            return Seed.Select(m => m.Genre).Distinct().OrderBy(g => g).ToList();
        }

        private static List<Movie> QueryDatabase(string genre, string keyword)
        {
            const string sql = @"
SELECT movie_id, title, description, duration, genre, release_date, status, poster_url
FROM movies
WHERE status = 'active'
  AND (@genre IS NULL OR genre = @genre)
  AND (@kw IS NULL OR title LIKE '%' + @kw + '%' OR genre LIKE '%' + @kw + '%')
ORDER BY title;";

            var result = new List<Movie>();
            using (var conn = Db.Open())
            using (var cmd = new SqlCommand(sql, conn))
            {
                cmd.CommandTimeout = 5;
                cmd.Parameters.Add("@genre", SqlDbType.VarChar, 50).Value = (object)genre ?? DBNull.Value;
                cmd.Parameters.Add("@kw", SqlDbType.NVarChar, 200).Value = (object)keyword ?? DBNull.Value;
                using (var rd = cmd.ExecuteReader())
                {
                    while (rd.Read())
                    {
                        result.Add(ReadMovie(rd));
                    }
                }
            }
            return result;
        }

        // ดึงหนังเรื่องเดียวที่ยังฉายอยู่ (status = 'active') ไม่เจอคืน null (fallback เป็น Seed หากต่อ DB ไม่ได้)
        public Movie GetMovie(int movieId)
        {
            const string sql = @"
SELECT movie_id, title, description, duration, genre, release_date, status, poster_url
FROM movies
WHERE movie_id = @id AND status = 'active';";

            try
            {
                using (var conn = Db.Open())
                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.CommandTimeout = 5;
                    cmd.Parameters.Add("@id", SqlDbType.Int).Value = movieId;
                    using (var rd = cmd.ExecuteReader())
                    {
                        if (!rd.Read()) return null;
                        return ReadMovie(rd);
                    }
                }
            }
            catch
            {
                return Seed.FirstOrDefault(m => m.MovieId == movieId && m.Status == "active");
            }
        }

        // ดึงรอบฉายอนาคตที่ยังจองได้ของหนังเรื่องหนึ่ง พร้อมจำนวนที่นั่งว่าง
        // นิยาม "ที่นั่งที่ถูกถืออยู่" ตรงกับ sp_BookMovieSeats ใน Database/logic.sql:
        //   booking confirmed + ตั๋ว issued หรือ booking pending ที่ยังไม่หมดเวลา + ตั๋ว reserved
        public List<Showtime> GetShowtimes(int movieId)
        {
            const string sql = @"
SELECT s.showtime_id, s.movie_id, s.start_time, s.end_time, s.standard_price,
       ch.hall_name, ch.capacity,
       (ch.capacity - ISNULL(tk.taken, 0)) AS seats_left
FROM showtimes s
INNER JOIN cinema_halls ch ON ch.hall_id = s.hall_id
OUTER APPLY (
    SELECT COUNT(*) AS taken
    FROM tickets t
    INNER JOIN bookings b ON b.booking_id = t.booking_id
    WHERE b.showtime_id = s.showtime_id
      AND t.ticket_status IN ('reserved', 'issued')
      AND (b.booking_status = 'confirmed'
           OR (b.booking_status = 'pending' AND b.expires_at > SYSDATETIME()))
) tk
WHERE s.movie_id = @id
  AND s.status = 'scheduled'
  AND s.start_time > SYSDATETIME()
ORDER BY s.start_time;";

            var result = new List<Showtime>();
            using (var conn = Db.Open())
            using (var cmd = new SqlCommand(sql, conn))
            {
                cmd.CommandTimeout = 5;
                cmd.Parameters.Add("@id", SqlDbType.Int).Value = movieId;
                using (var rd = cmd.ExecuteReader())
                {
                    while (rd.Read())
                    {
                        result.Add(new Showtime
                        {
                            ShowtimeId = rd.GetInt32(0),
                            MovieId = rd.GetInt32(1),
                            StartTime = rd.GetDateTime(2),
                            EndTime = rd.GetDateTime(3),
                            StandardPrice = rd.GetDecimal(4),
                            HallName = rd.GetString(5),
                            SeatsLeft = rd.GetInt32(7)
                        });
                    }
                }
            }
            return result;
        }

        // ดึงประวัติการจองของลูกค้าคนหนึ่งจากอีเมล (เรียงล่าสุดก่อน)
        // แนวคิดตรงกับ Database/queries.sql ข้อ 1 (รายละเอียดการจอง) + ข้อ 10 (ล่าสุดของแต่ละคน)
        public List<BookingInfo> GetBookingsByEmail(string email)
        {
            const string bookingSql = @"
SELECT b.booking_id, m.title, s.start_time, ch.hall_name,
       b.total_amount, b.booking_status, b.booking_time,
       p.payment_method, p.payment_status
FROM bookings b
INNER JOIN customers c ON c.customer_id = b.customer_id
INNER JOIN showtimes s ON s.showtime_id = b.showtime_id
INNER JOIN movies m ON m.movie_id = s.movie_id
INNER JOIN cinema_halls ch ON ch.hall_id = s.hall_id
LEFT JOIN payments p ON p.booking_id = b.booking_id
WHERE c.email = @email
ORDER BY b.booking_time DESC;";

            const string ticketSql = @"
SELECT b.booking_id, se.row_label, se.seat_number
FROM tickets t
INNER JOIN seats se ON se.seat_id = t.seat_id
INNER JOIN bookings b ON b.booking_id = t.booking_id
INNER JOIN customers c ON c.customer_id = b.customer_id
WHERE c.email = @email
ORDER BY t.ticket_id;";

            List<BookingInfo> result = new List<BookingInfo>();
            Dictionary<int, BookingInfo> byId = new Dictionary<int, BookingInfo>();
            using (SqlConnection conn = Db.Open())
            {
                using (SqlCommand cmd = new SqlCommand(bookingSql, conn))
                {
                    cmd.CommandTimeout = 5;
                    cmd.Parameters.Add("@email", SqlDbType.VarChar, 255).Value = email;
                    using (SqlDataReader rd = cmd.ExecuteReader())
                    {
                        while (rd.Read())
                        {
                            BookingInfo info = new BookingInfo();
                            info.BookingId = rd.GetInt32(0);
                            info.MovieTitle = rd.GetString(1);
                            info.ShowTime = rd.GetDateTime(2);
                            info.HallName = rd.GetString(3);
                            info.TotalAmount = rd.GetDecimal(4);
                            info.BookingStatus = rd.GetString(5);
                            info.PaymentMethod = rd.IsDBNull(7) ? "-" : rd.GetString(7);
                            info.PaymentStatus = rd.IsDBNull(8) ? "-" : rd.GetString(8);
                            result.Add(info);
                            byId[info.BookingId] = info;
                        }
                    }
                }

                if (result.Count == 0) return result;

                using (SqlCommand cmd = new SqlCommand(ticketSql, conn))
                {
                    cmd.CommandTimeout = 5;
                    cmd.Parameters.Add("@email", SqlDbType.VarChar, 255).Value = email;
                    using (SqlDataReader rd = cmd.ExecuteReader())
                    {
                        while (rd.Read())
                        {
                            int bookingId = rd.GetInt32(0);
                            BookingInfo info;
                            if (byId.TryGetValue(bookingId, out info))
                                info.Seats.Add(rd.GetString(1) + rd.GetInt32(2).ToString());
                        }
                    }
                }
            }
            return result;
        }

        // ดึงรายงาน Box Office รายหนังจาก view (Database/logic.sql)
        // จัดอันดับด้วย RANK() ตามรายได้ แนวเดียวกับ Database/queries.sql ข้อ 9
        public List<BoxOfficeRow> GetBoxOfficeReport()
        {
            const string sql = @"
SELECT movie_id, movie_title, genre, total_showtimes, tickets_sold,
       total_revenue, occupancy_rate_percent,
       RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
FROM vw_BoxOfficeOccupancyReport
ORDER BY total_revenue DESC;";

            List<BoxOfficeRow> result = new List<BoxOfficeRow>();
            using (SqlConnection conn = Db.Open())
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.CommandTimeout = 10;
                using (SqlDataReader rd = cmd.ExecuteReader())
                {
                    while (rd.Read())
                    {
                        BoxOfficeRow row = new BoxOfficeRow();
                        row.MovieId = rd.GetInt32(0);
                        row.MovieTitle = rd.GetString(1);
                        row.Genre = rd.IsDBNull(2) ? "-" : rd.GetString(2);
                        row.TotalShowtimes = rd.GetInt32(3);
                        row.TicketsSold = rd.GetInt32(4);
                        row.TotalRevenue = rd.GetDecimal(5);
                        row.OccupancyRate = rd.GetDecimal(6);
                        row.Rank = System.Convert.ToInt32(rd[7]);
                        result.Add(row);
                    }
                }
            }
            return result;
        }

        // ยกเลิกการจองของลูกค้า (ตรวจเจ้าของด้วยอีเมล) คืนยอดเงินที่ได้คืน
        // logic  اصلیอยู่ใน sp_CancelBooking (Database/logic.sql) ที่นี่แค่เรียกใช้
        public decimal CancelBooking(string email, int bookingId)
        {
            using (SqlConnection conn = Db.Open())
            {
                int customerId;
                using (SqlCommand cmd = new SqlCommand(
                    "SELECT customer_id FROM customers WHERE email = @email", conn))
                {
                    cmd.Parameters.Add("@email", SqlDbType.VarChar, 255).Value = email;
                    object found = cmd.ExecuteScalar();
                    if (found == null || found == DBNull.Value)
                        throw new InvalidOperationException("customer not found");
                    customerId = Convert.ToInt32(found);
                }

                using (SqlCommand cmd = new SqlCommand("sp_CancelBooking", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add("@booking_id", SqlDbType.Int).Value = bookingId;
                    cmd.Parameters.Add("@customer_id", SqlDbType.Int).Value = customerId;
                    using (SqlDataReader rd = cmd.ExecuteReader())
                    {
                        if (!rd.Read())
                            throw new InvalidOperationException("empty proc result");
                        return Convert.ToDecimal(rd["refund_amount"]);
                    }
                }
            }
        }

        // ---------- ส่วนแอดมิน (ไม่มีระบบ login/role ใช้ด่านรหัสแทน ดู Data/AdminAuth) ----------

        // ดึงรอบฉายทั้งหมด กรองตามสถานะได้ (scheduled/completed/cancelled หรือทั้งหมด)
        public List<AdminShowtime> AdminGetShowtimes(string status, int? movieId)
        {
            const string sql = @"
SELECT s.showtime_id, m.title, ch.hall_name, s.start_time, s.end_time,
       s.standard_price, s.status,
       (SELECT COUNT(*)
        FROM bookings b
        WHERE b.showtime_id = s.showtime_id
          AND (b.booking_status = 'confirmed'
               OR (b.booking_status = 'pending' AND b.expires_at > SYSDATETIME()))
       ) AS active_n
FROM showtimes s
INNER JOIN movies m ON m.movie_id = s.movie_id
INNER JOIN cinema_halls ch ON ch.hall_id = s.hall_id
WHERE (@status IS NULL OR s.status = @status)
  AND (@movie IS NULL OR s.movie_id = @movie)
ORDER BY s.start_time;";

            List<AdminShowtime> result = new List<AdminShowtime>();
            using (SqlConnection conn = Db.Open())
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.CommandTimeout = 10;
                cmd.Parameters.Add("@status", SqlDbType.VarChar, 20).Value =
                    (object)status ?? DBNull.Value;
                cmd.Parameters.Add("@movie", SqlDbType.Int).Value =
                    (object)movieId ?? DBNull.Value;
                using (SqlDataReader rd = cmd.ExecuteReader())
                {
                    while (rd.Read())
                    {
                        AdminShowtime row = new AdminShowtime();
                        row.ShowtimeId = rd.GetInt32(0);
                        row.MovieTitle = rd.GetString(1);
                        row.HallName = rd.GetString(2);
                        row.StartTime = rd.GetDateTime(3);
                        row.EndTime = rd.GetDateTime(4);
                        row.StandardPrice = rd.GetDecimal(5);
                        row.Status = rd.GetString(6);
                        row.ActiveBookings = rd.GetInt32(7);
                        result.Add(row);
                    }
                }
            }
            return result;
        }

        // เพิ่มรอบฉาย (กันรอบชนกันในโรงเดียวกัน รอบที่ cancelled แล้วไม่นับ)
        // คืน showtime_id ที่สร้าง
        public int AdminCreateShowtime(int movieId, int hallId, DateTime start, DateTime end, decimal price)
        {
            if (end <= start)
                throw new InvalidOperationException("BAD_TIME");
            if (start <= DateTime.Now)
                throw new InvalidOperationException("PAST_TIME");
            if (price < 0)
                throw new InvalidOperationException("BAD_PRICE");

            const string overlapSql = @"
SELECT COUNT(*)
FROM showtimes WITH (UPDLOCK, HOLDLOCK)
WHERE hall_id = @hall
  AND status IN ('scheduled', 'completed')
  AND @start < end_time AND @end > start_time;";

            const string insertSql = @"
INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, standard_price, status)
VALUES (@movie, @hall, @start, @end, @price, 'scheduled');
SELECT CAST(SCOPE_IDENTITY() AS INT);";

            using (SqlConnection conn = Db.Open())
            using (SqlTransaction tx = conn.BeginTransaction())
            {
                int overlap;
                using (SqlCommand cmd = new SqlCommand(overlapSql, conn, tx))
                {
                    cmd.Parameters.Add("@hall", SqlDbType.Int).Value = hallId;
                    cmd.Parameters.Add("@start", SqlDbType.DateTime).Value = start;
                    cmd.Parameters.Add("@end", SqlDbType.DateTime).Value = end;
                    overlap = (int)cmd.ExecuteScalar();
                }
                if (overlap > 0)
                {
                    tx.Rollback();
                    throw new InvalidOperationException("OVERLAP");
                }

                try
                {
                    int newId;
                    using (SqlCommand cmd = new SqlCommand(insertSql, conn, tx))
                    {
                        cmd.Parameters.Add("@movie", SqlDbType.Int).Value = movieId;
                        cmd.Parameters.Add("@hall", SqlDbType.Int).Value = hallId;
                        cmd.Parameters.Add("@start", SqlDbType.DateTime).Value = start;
                        cmd.Parameters.Add("@end", SqlDbType.DateTime).Value = end;
                        SqlParameter priceParam = cmd.Parameters.Add("@price", SqlDbType.Decimal);
                        priceParam.Precision = 10;
                        priceParam.Scale = 2;
                        priceParam.Value = price;
                        newId = (int)cmd.ExecuteScalar();
                    }
                    tx.Commit();
                    return newId;
                }
                catch (SqlException ex)
                {
                    tx.Rollback();
                    if (ex.Number == 547)
                        throw new InvalidOperationException("BAD_REF");
                    throw;
                }
            }
        }

        // ยกเลิกรอบฉาย ได้เฉพาะรอบ scheduled ที่ยังไม่เริ่ม และไม่มี booking ค้าง
        public void AdminCancelShowtime(int showtimeId)
        {
            const string cancelSql = @"
UPDATE showtimes SET status = 'cancelled'
WHERE showtime_id = @id
  AND status = 'scheduled'
  AND start_time > SYSDATETIME()
  AND NOT EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.showtime_id = showtimes.showtime_id
        AND (b.booking_status = 'confirmed'
             OR (b.booking_status = 'pending' AND b.expires_at > SYSDATETIME())));";

            const string diagSql = @"
SELECT s.status, s.start_time,
       (SELECT COUNT(*)
        FROM bookings b
        WHERE b.showtime_id = s.showtime_id
          AND (b.booking_status = 'confirmed'
               OR (b.booking_status = 'pending' AND b.expires_at > SYSDATETIME()))) AS active_n
FROM showtimes s
WHERE s.showtime_id = @id;";

            using (SqlConnection conn = Db.Open())
            {
                using (SqlCommand cmd = new SqlCommand(cancelSql, conn))
                {
                    cmd.Parameters.Add("@id", SqlDbType.Int).Value = showtimeId;
                    if (cmd.ExecuteNonQuery() > 0) return;
                }
                using (SqlCommand cmd = new SqlCommand(diagSql, conn))
                {
                    cmd.Parameters.Add("@id", SqlDbType.Int).Value = showtimeId;
                    using (SqlDataReader rd = cmd.ExecuteReader())
                    {
                        if (!rd.Read())
                            throw new InvalidOperationException("NOT_FOUND");
                        string status = rd.GetString(0);
                        DateTime start = rd.GetDateTime(1);
                        int active = rd.GetInt32(2);
                        if (status != "scheduled")
                            throw new InvalidOperationException("BAD_STATUS");
                        if (start <= DateTime.Now)
                            throw new InvalidOperationException("STARTED");
                        if (active > 0)
                            throw new InvalidOperationException("HAS_BOOKINGS:" + active);
                        throw new InvalidOperationException("UNKNOWN");
                    }
                }
            }
        }

        // ดึงโปรโมชันทั้งหมด
        public List<Promotion> AdminGetPromos()
        {
            const string sql = @"
SELECT promotion_id, promotion_code, discount_type, discount_value,
       start_date, end_date, status
FROM promotions
ORDER BY end_date DESC, status;";

            List<Promotion> result = new List<Promotion>();
            using (SqlConnection conn = Db.Open())
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.CommandTimeout = 5;
                using (SqlDataReader rd = cmd.ExecuteReader())
                {
                    while (rd.Read())
                    {
                        Promotion p = new Promotion();
                        p.PromotionId = rd.GetInt32(0);
                        p.Code = rd.GetString(1);
                        p.DiscountType = rd.GetString(2);
                        p.DiscountValue = rd.GetDecimal(3);
                        p.StartDate = rd.GetDateTime(4);
                        p.EndDate = rd.GetDateTime(5);
                        p.Status = rd.GetString(6);
                        result.Add(p);
                    }
                }
            }
            return result;
        }

        // เพิ่มโปรโมชัน (ตรวจตาม CHECK ใน schema: percentage 0-100, fixed >= 0, end >= start)
        public int AdminCreatePromo(string code, string discountType, decimal value, DateTime start, DateTime end)
        {
            if (string.IsNullOrWhiteSpace(code) || code.Trim().Length > 50)
                throw new InvalidOperationException("BAD_CODE");
            if (discountType != "percentage" && discountType != "fixed")
                throw new InvalidOperationException("BAD_TYPE");
            if (discountType == "percentage" && (value < 0 || value > 100))
                throw new InvalidOperationException("BAD_VALUE");
            if (discountType == "fixed" && value < 0)
                throw new InvalidOperationException("BAD_VALUE");
            if (end < start)
                throw new InvalidOperationException("BAD_DATE");

            const string sql = @"
INSERT INTO promotions (promotion_code, discount_type, discount_value, start_date, end_date, status)
VALUES (@code, @type, @value, @start, @end, 'active');
SELECT CAST(SCOPE_IDENTITY() AS INT);";

            try
            {
                using (SqlConnection conn = Db.Open())
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.Add("@code", SqlDbType.VarChar, 50).Value = code.Trim().ToUpperInvariant();
                    cmd.Parameters.Add("@type", SqlDbType.VarChar, 20).Value = discountType;
                    SqlParameter valueParam = cmd.Parameters.Add("@value", SqlDbType.Decimal);
                    valueParam.Precision = 10;
                    valueParam.Scale = 2;
                    valueParam.Value = value;
                    cmd.Parameters.Add("@start", SqlDbType.Date).Value = start.Date;
                    cmd.Parameters.Add("@end", SqlDbType.Date).Value = end.Date;
                    return (int)cmd.ExecuteScalar();
                }
            }
            catch (SqlException ex)
            {
                if (ex.Number == 2627 || ex.Number == 2601)
                    throw new InvalidOperationException("DUP_CODE");
                throw;
            }
        }

        // สลับสถานะโปรโมชัน active/inactive
        public void AdminTogglePromo(int promotionId)
        {
            const string sql = @"
UPDATE promotions
SET status = CASE WHEN status = 'active' THEN 'inactive' ELSE 'active' END
WHERE promotion_id = @id;";

            using (SqlConnection conn = Db.Open())
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.Parameters.Add("@id", SqlDbType.Int).Value = promotionId;
                if (cmd.ExecuteNonQuery() == 0)
                    throw new InvalidOperationException("NOT_FOUND");
            }
        }

        // ดึงหนังทุกเรื่อง (รวม inactive) สำหรับจอแอดมิน
        public List<Movie> AdminGetMovies()
        {
            const string sql = @"
SELECT movie_id, title, description, duration, genre, release_date, status, poster_url
FROM movies
ORDER BY title;";

            List<Movie> result = new List<Movie>();
            using (SqlConnection conn = Db.Open())
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.CommandTimeout = 5;
                using (SqlDataReader rd = cmd.ExecuteReader())
                {
                    while (rd.Read())
                        result.Add(ReadMovie(rd));
                }
            }
            return result;
        }

        // เพิ่มหนังใหม่ (posterPath เป็น null ได้ถ้าไม่แนบไฟล์)
        // คืน movie_id ที่สร้าง
        public int AdminAddMovie(string title, string description, int duration,
            string genre, DateTime releaseDate, string status, string posterPath)
        {
            if (string.IsNullOrWhiteSpace(title) || title.Trim().Length > 200)
                throw new InvalidOperationException("BAD_TITLE");
            if (duration <= 0)
                throw new InvalidOperationException("BAD_DURATION");
            if (string.IsNullOrWhiteSpace(genre) || genre.Trim().Length > 50)
                throw new InvalidOperationException("BAD_GENRE");
            if (status != "active" && status != "inactive")
                throw new InvalidOperationException("BAD_STATUS");

            const string sql = @"
INSERT INTO movies (title, description, duration, genre, release_date, status, poster_url)
VALUES (@title, @desc, @duration, @genre, @release, @status, @poster);
SELECT CAST(SCOPE_IDENTITY() AS INT);";

            using (SqlConnection conn = Db.Open())
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.Parameters.Add("@title", SqlDbType.NVarChar, 200).Value = title.Trim();
                cmd.Parameters.Add("@desc", SqlDbType.NVarChar, -1).Value =
                    (object)description ?? DBNull.Value;
                cmd.Parameters.Add("@duration", SqlDbType.Int).Value = duration;
                cmd.Parameters.Add("@genre", SqlDbType.NVarChar, 50).Value = genre.Trim();
                cmd.Parameters.Add("@release", SqlDbType.Date).Value = releaseDate.Date;
                cmd.Parameters.Add("@status", SqlDbType.VarChar, 20).Value = status;
                cmd.Parameters.Add("@poster", SqlDbType.VarChar, 500).Value =
                    (object)posterPath ?? DBNull.Value;
                return (int)cmd.ExecuteScalar();
            }
        }

        // สลับสถานะหนัง active/inactive
        public void AdminToggleMovie(int movieId)
        {
            const string sql = @"
UPDATE movies
SET status = CASE WHEN status = 'active' THEN 'inactive' ELSE 'active' END
WHERE movie_id = @id;";

            using (SqlConnection conn = Db.Open())
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.Parameters.Add("@id", SqlDbType.Int).Value = movieId;
                if (cmd.ExecuteNonQuery() == 0)
                    throw new InvalidOperationException("NOT_FOUND");
            }
        }

        // ดึงโรงที่ active สำหรับ dropdown
        public List<HallOption> AdminGetHalls()
        {
            const string sql = @"
SELECT hall_id, hall_name
FROM cinema_halls
WHERE status = 'active'
ORDER BY hall_name;";

            List<HallOption> result = new List<HallOption>();
            using (SqlConnection conn = Db.Open())
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                using (SqlDataReader rd = cmd.ExecuteReader())
                {
                    while (rd.Read())
                    {
                        HallOption h = new HallOption();
                        h.HallId = rd.GetInt32(0);
                        h.HallName = rd.GetString(1);
                        result.Add(h);
                    }
                }
            }
            return result;
        }

        private static Movie ReadMovie(SqlDataReader rd)
        {
            return new Movie
            {
                MovieId = rd.GetInt32(0),
                Title = rd.GetString(1),
                Description = rd.IsDBNull(2) ? "" : rd.GetString(2),
                Duration = rd.GetInt32(3),
                Genre = rd.GetString(4),
                ReleaseDate = rd.GetDateTime(5),
                Status = rd.GetString(6),
                PosterUrl = rd.IsDBNull(7) ? null : rd.GetString(7)
            };
        }

        private static string FirstLine(string message)
        {
            if (string.IsNullOrEmpty(message)) return "unknown error";
            int i = message.IndexOfAny(new[] { '\r', '\n' });
            string line = i < 0 ? message : message.Substring(0, i);
            return line.Length > 160 ? line.Substring(0, 160) + "..." : line;
        }
    }
}
