using System;
using System.Collections.Generic;
using System.Data;

namespace Cinema_Ticketing___Seat_Booking
{
    /// <summary>
    /// ชั้นข้อมูล (DAL) ระดับงาน: ทุกเมธอดใช้ Db.* ที่ใช้ SqlParameter + using เสมอ
    /// การจอง/ชำระเงินเรียก Stored Procedure (กฎอยู่ในฐานข้อมูล) ส่วนอ่านข้อมูลใช้ SELECT แบบมีพารามิเตอร์
    /// </summary>
    public static class Repo
    {
        // ====================== ล็อกอิน / สมัครสมาชิก ======================
        public static DataRow GetLoginInfo(string email)
        {
            DataTable dt = Db.Proc("dbo.sp_GetLoginInfo", Db.VarChar("@email", email, 255));
            return dt.Rows.Count == 0 ? null : dt.Rows[0];
        }

        public static int Register(string name, string email, string phone, string passwordHash)
        {
            DataTable dt = Db.ProcChecked("dbo.sp_RegisterCustomer",
                Db.NVarChar("@name", name, 150), Db.VarChar("@email", email, 255),
                Db.VarChar("@phone", phone, 20), Db.VarChar("@password_hash", passwordHash, 255));
            return Convert.ToInt32(dt.Rows[0]["customer_id"]);
        }

        public static void RecordLogin(int customerId)
        {
            Db.Proc("dbo.sp_RecordLogin", Db.Int("@customer_id", customerId));
        }

        // ====================== หนังและรอบฉาย ======================
        public static void ReleaseExpiredHolds() { Db.Proc("dbo.sp_ReleaseExpiredHolds"); }

        public static DataTable GetGenresNowShowing()
        {
            return Db.Query(@"SELECT DISTINCT m.genre FROM movies m
                              WHERE m.status = 'active'
                                AND EXISTS (SELECT 1 FROM showtimes s WHERE s.movie_id = m.movie_id AND s.status = 'scheduled' AND s.start_time > SYSDATETIME())
                              ORDER BY m.genre");
        }

        public static DataTable GetNowShowing(string genre)
        {
            return Db.Query(@"SELECT m.movie_id, m.title, m.description, m.duration, m.genre, m.release_date,
                                     MIN(s.start_time) AS next_start, COUNT(*) AS upcoming_showtimes, MIN(s.ticket_price) AS min_price
                              FROM movies m
                              INNER JOIN showtimes s ON s.movie_id = m.movie_id AND s.status = 'scheduled' AND s.start_time > SYSDATETIME()
                              WHERE m.status = 'active' AND (@genre IS NULL OR m.genre = @genre)
                              GROUP BY m.movie_id, m.title, m.description, m.duration, m.genre, m.release_date
                              ORDER BY MIN(s.start_time), m.title",
                Db.VarChar("@genre", string.IsNullOrEmpty(genre) ? null : genre, 50));
        }

        public static DataRow GetMovie(int movieId)
        {
            DataTable dt = Db.Query("SELECT movie_id, title, description, duration, genre, release_date, status, poster_url FROM movies WHERE movie_id = @id",
                Db.Int("@id", movieId));
            return dt.Rows.Count == 0 ? null : dt.Rows[0];
        }

        public static DataTable GetUpcomingShowtimes(int movieId)
        {
            return Db.Query(@"SELECT s.showtime_id, s.start_time, s.end_time, s.ticket_price, h.hall_name, h.capacity,
                                     (SELECT COUNT(*) FROM vw_TakenSeats v WHERE v.showtime_id = s.showtime_id) AS taken_seats
                              FROM showtimes s
                              INNER JOIN cinema_halls h ON h.hall_id = s.hall_id
                              WHERE s.movie_id = @m AND s.status = 'scheduled' AND s.start_time > SYSDATETIME()
                              ORDER BY s.start_time", Db.Int("@m", movieId));
        }

        public static DataTable GetSeatMap(int showtimeId)
        {
            return Db.Query(@"SELECT se.seat_id, se.row_label, se.seat_number, se.seat_type,
                                     CASE WHEN EXISTS (SELECT 1 FROM vw_TakenSeats v WHERE v.showtime_id = s.showtime_id AND v.seat_id = se.seat_id)
                                          THEN 1 ELSE 0 END AS is_taken
                              FROM showtimes s
                              INNER JOIN seats se ON se.hall_id = s.hall_id
                              WHERE s.showtime_id = @id
                              ORDER BY se.row_label, se.seat_number", Db.Int("@id", showtimeId));
        }

        // ====================== จอง / ชำระเงิน ======================
        /// <summary>ถือที่นั่ง 1-3 ที่ (sp_HoldSeats) คืนแถวผลลัพธ์: booking_id, total_amount, expires_at, seconds_left</summary>
        public static DataRow HoldSeats(int customerId, int showtimeId, IList<int> seatIds)
        {
            if (seatIds == null || seatIds.Count < 1 || seatIds.Count > 3)
                throw new BusinessException("กรุณาเลือกที่นั่ง 1-3 ที่");
            DataTable dt = Db.ProcChecked("dbo.sp_HoldSeats",
                Db.Int("@customer_id", customerId), Db.Int("@showtime_id", showtimeId),
                Db.Int("@seat_id_1", seatIds[0]),
                Db.Int("@seat_id_2", seatIds.Count > 1 ? (int?)seatIds[1] : null),
                Db.Int("@seat_id_3", seatIds.Count > 2 ? (int?)seatIds[2] : null),
                Db.VarChar("@promotion_code", null, 50));
            return dt.Rows[0];
        }

        public static DataRow ConfirmPayment(int bookingId, int customerId, string method, string promoCode)
        {
            DataTable dt = Db.ProcChecked("dbo.sp_ConfirmPayment",
                Db.Int("@booking_id", bookingId), Db.Int("@customer_id", customerId),
                Db.VarChar("@payment_method", method, 20),
                Db.VarChar("@promotion_code", string.IsNullOrEmpty(promoCode) ? null : promoCode, 50));
            return dt.Rows[0];
        }

        public static bool CancelHold(int bookingId, int customerId)
        {
            DataTable dt = Db.ProcChecked("dbo.sp_CancelHold", Db.Int("@booking_id", bookingId), Db.Int("@customer_id", customerId));
            return Convert.ToInt32(dt.Rows[0]["released_bookings"]) > 0;
        }

        /// <summary>ตรวจโค้ดโปรโมชันและคำนวณยอดใหม่ (ใช้ฟังก์ชันในฐานข้อมูลตัวเดียวกับที่ sp_ConfirmPayment ใช้) คืน null ถ้าใช้ไม่ได้</summary>
        public static DataRow PreviewPromotion(int bookingId, string code)
        {
            DataTable dt = Db.Query(@"SELECT p.promotion_code, p.discount_type, p.discount_value,
                                             dbo.fn_CalculateBookingTotal(
                                                (SELECT SUM(t.ticket_price) FROM tickets t WHERE t.booking_id = @b AND t.ticket_status = 'reserved'),
                                                p.discount_type, p.discount_value) AS new_total
                                      FROM dbo.fn_GetValidPromotion(@code) p",
                Db.Int("@b", bookingId), Db.VarChar("@code", code, 50));
            return dt.Rows.Count == 0 ? null : dt.Rows[0];
        }

        public static DataRow GetBooking(int bookingId)
        {
            DataTable dt = Db.Query(@"SELECT b.booking_id, b.customer_id, b.booking_status, b.total_amount, b.booking_time, b.expires_at,
                                             DATEDIFF(SECOND, SYSDATETIME(), b.expires_at) AS seconds_left,
                                             m.movie_id, m.title, m.genre, s.showtime_id, s.start_time, s.end_time, s.ticket_price, h.hall_name,
                                             p.promotion_code, c.name AS customer_name,
                                             (SELECT SUM(t.ticket_price) FROM tickets t WHERE t.booking_id = b.booking_id) AS subtotal,
                                             (SELECT TOP (1) pay.payment_method FROM payments pay WHERE pay.booking_id = b.booking_id) AS payment_method,
                                             (SELECT TOP (1) pay.paid_at FROM payments pay WHERE pay.booking_id = b.booking_id) AS paid_at
                                      FROM bookings b
                                      INNER JOIN showtimes s ON s.showtime_id = b.showtime_id
                                      INNER JOIN movies m ON m.movie_id = s.movie_id
                                      INNER JOIN cinema_halls h ON h.hall_id = s.hall_id
                                      INNER JOIN customers c ON c.customer_id = b.customer_id
                                      LEFT JOIN promotions p ON p.promotion_id = b.promotion_id
                                      WHERE b.booking_id = @id", Db.Int("@id", bookingId));
            return dt.Rows.Count == 0 ? null : dt.Rows[0];
        }

        public static DataTable GetBookingTickets(int bookingId)
        {
            return Db.Query(@"SELECT t.ticket_id, t.ticket_price, t.ticket_status, se.row_label, se.seat_number, se.seat_type,
                                     se.row_label + CAST(se.seat_number AS VARCHAR(5)) AS seat_label
                              FROM tickets t INNER JOIN seats se ON se.seat_id = t.seat_id
                              WHERE t.booking_id = @id ORDER BY se.row_label, se.seat_number", Db.Int("@id", bookingId));
        }

        /// <summary>ประวัติการจองของลูกค้า (ล่าสุดก่อน) พร้อมรายชื่อที่นั่งรวมเป็นข้อความ</summary>
        public static DataTable GetMyBookings(int customerId)
        {
            DataTable bk = Db.Query(@"SELECT TOP (200) b.booking_id, b.booking_status, b.total_amount, b.booking_time, b.expires_at,
                                             DATEDIFF(SECOND, SYSDATETIME(), b.expires_at) AS seconds_left,
                                             m.title, s.start_time, h.hall_name, p.promotion_code
                                      FROM bookings b
                                      INNER JOIN showtimes s ON s.showtime_id = b.showtime_id
                                      INNER JOIN movies m ON m.movie_id = s.movie_id
                                      INNER JOIN cinema_halls h ON h.hall_id = s.hall_id
                                      LEFT JOIN promotions p ON p.promotion_id = b.promotion_id
                                      WHERE b.customer_id = @c
                                      ORDER BY b.booking_time DESC, b.booking_id DESC", Db.Int("@c", customerId));
            DataTable seats = Db.Query(@"SELECT t.booking_id, se.row_label + CAST(se.seat_number AS VARCHAR(5)) AS seat
                                         FROM tickets t
                                         INNER JOIN seats se ON se.seat_id = t.seat_id
                                         INNER JOIN bookings b ON b.booking_id = t.booking_id
                                         WHERE b.customer_id = @c
                                         ORDER BY t.booking_id, se.row_label, se.seat_number", Db.Int("@c", customerId));
            Dictionary<int, List<string>> map = new Dictionary<int, List<string>>();
            foreach (DataRow r in seats.Rows)
            {
                int id = Convert.ToInt32(r["booking_id"]);
                if (!map.ContainsKey(id)) map[id] = new List<string>();
                map[id].Add(Convert.ToString(r["seat"]));
            }
            bk.Columns.Add("seats", typeof(string));
            foreach (DataRow r in bk.Rows)
            {
                List<string> l;
                r["seats"] = map.TryGetValue(Convert.ToInt32(r["booking_id"]), out l) ? string.Join(", ", l) : "";
            }
            return bk;
        }


        public static DataRow GetShowtimeRow(int id)
        {
            DataTable dt = Db.Query("SELECT showtime_id, movie_id, hall_id, start_time, end_time, ticket_price, status FROM showtimes WHERE showtime_id = @id", Db.Int("@id", id));
            return dt.Rows.Count == 0 ? null : dt.Rows[0];
        }

        public static DataRow GetPromotionRow(int id)
        {
            DataTable dt = Db.Query("SELECT promotion_id, promotion_code, discount_type, discount_value, start_date, end_date, status FROM promotions WHERE promotion_id = @id", Db.Int("@id", id));
            return dt.Rows.Count == 0 ? null : dt.Rows[0];
        }

        // ====================== ผู้ดูแลระบบ: หนัง ======================
        public static DataTable AdminListMovies(string search, string status)
        {
            string like = string.IsNullOrWhiteSpace(search) ? null : "%" + Validation.EscapeLike(search.Trim()) + "%";
            return Db.Query(@"SELECT TOP (500) movie_id, title, genre, duration, release_date, status
                              FROM movies
                              WHERE (@q IS NULL OR title LIKE @q) AND (@st IS NULL OR status = @st)
                              ORDER BY movie_id DESC",
                Db.NVarChar("@q", like, 220), Db.VarChar("@st", string.IsNullOrEmpty(status) ? null : status, 20));
        }

        public static int InsertMovie(string title, string description, int duration, string genre, DateTime release, string status, string posterUrl)
        {
            object id = Db.Scalar(@"INSERT INTO movies (title, description, duration, genre, release_date, status, poster_url)
                                    VALUES (@title, @desc, @dur, @genre, @rel, @st, @poster);
                                    SELECT CAST(SCOPE_IDENTITY() AS INT);",
                Db.NVarChar("@title", title, 200), Db.NVarCharMax("@desc", description), Db.Int("@dur", duration),
                Db.VarChar("@genre", genre, 50), Db.Date("@rel", release), Db.VarChar("@st", status, 20), Db.VarChar("@poster", posterUrl, 500));
            return Convert.ToInt32(id);
        }

        public static void UpdateMovie(int id, string title, string description, int duration, string genre, DateTime release, string status, string posterUrl)
        {
            int n = Db.Execute(@"UPDATE movies SET title = @title, description = @desc, duration = @dur, genre = @genre,
                                        release_date = @rel, status = @st, poster_url = @poster
                                 WHERE movie_id = @id",
                Db.NVarChar("@title", title, 200), Db.NVarCharMax("@desc", description), Db.Int("@dur", duration),
                Db.VarChar("@genre", genre, 50), Db.Date("@rel", release), Db.VarChar("@st", status, 20), Db.VarChar("@poster", posterUrl, 500), Db.Int("@id", id));
            if (n == 0) throw new BusinessException("ไม่พบภาพยนตร์ที่ต้องการแก้ไข (อาจถูกลบไปแล้ว)");
        }

        public static void DeleteMovie(int id)
        {
            int n = Db.Execute("DELETE FROM movies WHERE movie_id = @id", Db.Int("@id", id));
            if (n == 0) throw new BusinessException("ไม่พบภาพยนตร์ที่ต้องการลบ (อาจถูกลบไปแล้ว)");
        }

        // ====================== ผู้ดูแลระบบ: รอบฉาย ======================
        public static DataTable AdminListShowtimes(string status)
        {
            return Db.Query(@"SELECT TOP (300) s.showtime_id, s.movie_id, s.hall_id, m.title, h.hall_name, s.start_time, s.end_time, s.ticket_price, s.status,
                                     (SELECT COUNT(*) FROM bookings b WHERE b.showtime_id = s.showtime_id AND b.booking_status IN ('pending', 'confirmed')) AS active_bookings
                              FROM showtimes s
                              INNER JOIN movies m ON m.movie_id = s.movie_id
                              INNER JOIN cinema_halls h ON h.hall_id = s.hall_id
                              WHERE (@st IS NULL OR s.status = @st)
                              ORDER BY s.start_time DESC, s.showtime_id DESC",
                Db.VarChar("@st", string.IsNullOrEmpty(status) ? null : status, 20));
        }

        /// <summary>หนังที่เปิดใช้งาน (และหนังของรอบที่กำลังแก้ไขแม้ปิดใช้งานแล้ว) สำหรับ dropdown</summary>
        public static DataTable ListMoviesForSelect(int? includeId)
        {
            return Db.Query("SELECT movie_id, title, duration FROM movies WHERE status = 'active' OR movie_id = @inc ORDER BY title", Db.Int("@inc", includeId));
        }

        public static DataTable ListHallsForSelect(int? includeId)
        {
            return Db.Query("SELECT hall_id, hall_name, capacity FROM cinema_halls WHERE status = 'active' OR hall_id = @inc ORDER BY hall_id", Db.Int("@inc", includeId));
        }

        public static int InsertShowtime(int movieId, int hallId, DateTime start, DateTime end, decimal price, string status)
        {
            object id = Db.Scalar(@"INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, ticket_price, status)
                                    VALUES (@m, @h, @s, @e, @p, @st);
                                    SELECT CAST(SCOPE_IDENTITY() AS INT);",
                Db.Int("@m", movieId), Db.Int("@h", hallId), Db.DateTime2("@s", start), Db.DateTime2("@e", end), Db.Dec("@p", price), Db.VarChar("@st", status, 20));
            return Convert.ToInt32(id);
        }

        public static void UpdateShowtime(int id, int movieId, int hallId, DateTime start, DateTime end, decimal price, string status)
        {
            // ที่นั่งที่จองไว้ผูกกับโรงเดิม จึงห้ามย้ายโรงของรอบที่มีการจองที่ยัง active อยู่
            object oldHall = Db.Scalar("SELECT hall_id FROM showtimes WHERE showtime_id = @id", Db.Int("@id", id));
            if (oldHall == null) throw new BusinessException("ไม่พบรอบฉายที่ต้องการแก้ไข (อาจถูกลบไปแล้ว)");
            if (Convert.ToInt32(oldHall) != hallId)
            {
                int active = Convert.ToInt32(Db.Scalar("SELECT COUNT(*) FROM bookings WHERE showtime_id = @id AND booking_status IN ('pending', 'confirmed')", Db.Int("@id", id)));
                if (active > 0) throw new BusinessException("ไม่สามารถเปลี่ยนโรงของรอบที่มีการจองอยู่แล้ว (" + active + " รายการ) ให้ยกเลิกรอบนี้แล้วสร้างรอบใหม่แทน");
            }
            Db.Execute(@"UPDATE showtimes SET movie_id = @m, hall_id = @h, start_time = @s, end_time = @e, ticket_price = @p, status = @st
                         WHERE showtime_id = @id",
                Db.Int("@m", movieId), Db.Int("@h", hallId), Db.DateTime2("@s", start), Db.DateTime2("@e", end), Db.Dec("@p", price), Db.VarChar("@st", status, 20), Db.Int("@id", id));
        }

        public static void DeleteShowtime(int id)
        {
            int n = Db.Execute("DELETE FROM showtimes WHERE showtime_id = @id", Db.Int("@id", id));
            if (n == 0) throw new BusinessException("ไม่พบรอบฉายที่ต้องการลบ (อาจถูกลบไปแล้ว)");
        }

        // ====================== ผู้ดูแลระบบ: โปรโมชัน ======================
        public static DataTable AdminListPromotions()
        {
            return Db.Query(@"SELECT promotion_id, promotion_code, discount_type, discount_value, start_date, end_date, status,
                                     (SELECT COUNT(*) FROM bookings b WHERE b.promotion_id = p.promotion_id) AS times_used
                              FROM promotions p ORDER BY promotion_id DESC");
        }

        public static int InsertPromotion(string code, string type, decimal value, DateTime start, DateTime end, string status)
        {
            object id = Db.Scalar(@"INSERT INTO promotions (promotion_code, discount_type, discount_value, start_date, end_date, status)
                                    VALUES (@c, @t, @v, @s, @e, @st);
                                    SELECT CAST(SCOPE_IDENTITY() AS INT);",
                Db.VarChar("@c", code, 50), Db.VarChar("@t", type, 20), Db.Dec("@v", value), Db.Date("@s", start), Db.Date("@e", end), Db.VarChar("@st", status, 20));
            return Convert.ToInt32(id);
        }

        public static void UpdatePromotion(int id, string code, string type, decimal value, DateTime start, DateTime end, string status)
        {
            int n = Db.Execute(@"UPDATE promotions SET promotion_code = @c, discount_type = @t, discount_value = @v, start_date = @s, end_date = @e, status = @st
                                 WHERE promotion_id = @id",
                Db.VarChar("@c", code, 50), Db.VarChar("@t", type, 20), Db.Dec("@v", value), Db.Date("@s", start), Db.Date("@e", end), Db.VarChar("@st", status, 20), Db.Int("@id", id));
            if (n == 0) throw new BusinessException("ไม่พบโปรโมชันที่ต้องการแก้ไข (อาจถูกลบไปแล้ว)");
        }

        /// <summary>ลบโปรโมชัน: การจองเดิมที่เคยใช้โค้ดนี้จะถูกตั้ง promotion_id เป็น NULL (ON DELETE SET NULL) ยอดเงินในการจองไม่เปลี่ยน</summary>
        public static void DeletePromotion(int id)
        {
            int n = Db.Execute("DELETE FROM promotions WHERE promotion_id = @id", Db.Int("@id", id));
            if (n == 0) throw new BusinessException("ไม่พบโปรโมชันที่ต้องการลบ (อาจถูกลบไปแล้ว)");
        }

        // ====================== ผู้ดูแลระบบ: รายงาน ======================
        public static DataTable GetGenres()
        {
            return Db.Query("SELECT DISTINCT genre FROM movies ORDER BY genre");
        }

        public static DataTable BoxOffice(string genre, bool onlySold, int top)
        {
            return Db.Query(@"SELECT TOP (@n) movie_id, movie_title, genre, total_showtimes, tickets_sold, total_revenue, total_capacity, occupancy_rate_percent
                              FROM vw_BoxOfficeOccupancyReport
                              WHERE (@g IS NULL OR genre = @g) AND (@only = 0 OR tickets_sold > 0)
                              ORDER BY total_revenue DESC, movie_title",
                Db.Int("@n", top), Db.VarChar("@g", string.IsNullOrEmpty(genre) ? null : genre, 50), Db.Int("@only", onlySold ? 1 : 0));
        }

        public static DataRow DashboardStats()
        {
            DataTable dt = Db.Query(@"SELECT
                (SELECT COUNT(*) FROM movies WHERE status = 'active') AS active_movies,
                (SELECT COUNT(*) FROM showtimes WHERE status = 'scheduled' AND start_time > SYSDATETIME()) AS upcoming_showtimes,
                (SELECT COUNT(*) FROM tickets WHERE ticket_status = 'issued') AS tickets_sold,
                (SELECT ISNULL(SUM(ticket_price), 0) FROM tickets WHERE ticket_status = 'issued') AS revenue,
                (SELECT COUNT(*) FROM bookings WHERE booking_status = 'pending' AND expires_at >= SYSDATETIME()) AS open_holds");
            return dt.Rows[0];
        }
    }
}
