-- =========================================================
-- sanity_checks.sql  (อ่านอย่างเดียว รันซ้ำได้)
-- รันหลัง schema.sql -> data.sql -> logic.sql  ผลลัพธ์: 1 แถวต่อ 1 การตรวจ
--   violations = 0  -> PASS      violations > 0 -> FAIL (ดูรายละเอียดด้วยการรันซับคิวรีของข้อนั้น)
-- ข้อที่ขึ้นต้น "I" เป็นการตรวจเชิงข้อมูล (informational) อาจเปลี่ยนไปเองเมื่อเวลาผ่านไป
--   เพราะระบบไม่มี job ปรับสถานะรอบฉายเป็น completed อัตโนมัติ
-- =========================================================
SET NOCOUNT ON;

SELECT check_name, violations, CASE WHEN violations = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM (
    -- ---- S01-S09: จำนวนแถว (ตารางหลัก >= 500, ตารางประกอบ 20-50) ----
    SELECT 'S01 movies >= 500' AS check_name, CASE WHEN COUNT(*) >= 500 THEN 0 ELSE 1 END AS violations FROM movies
    UNION ALL SELECT 'S02 customers >= 500', CASE WHEN COUNT(*) >= 500 THEN 0 ELSE 1 END FROM customers
    UNION ALL SELECT 'S03 showtimes >= 500', CASE WHEN COUNT(*) >= 500 THEN 0 ELSE 1 END FROM showtimes
    UNION ALL SELECT 'S04 bookings >= 500', CASE WHEN COUNT(*) >= 500 THEN 0 ELSE 1 END FROM bookings
    UNION ALL SELECT 'S05 tickets >= 500', CASE WHEN COUNT(*) >= 500 THEN 0 ELSE 1 END FROM tickets
    UNION ALL SELECT 'S06 payments >= 500', CASE WHEN COUNT(*) >= 500 THEN 0 ELSE 1 END FROM payments
    UNION ALL SELECT 'S07 seats >= 500', CASE WHEN COUNT(*) >= 500 THEN 0 ELSE 1 END FROM seats
    UNION ALL SELECT 'S08 cinema_halls 20-50', CASE WHEN COUNT(*) BETWEEN 20 AND 50 THEN 0 ELSE 1 END FROM cinema_halls
    UNION ALL SELECT 'S09 promotions 20-50', CASE WHEN COUNT(*) BETWEEN 20 AND 50 THEN 0 ELSE 1 END FROM promotions

    -- ---- งานที่ 1: รอบฉายต้องไม่ทับซ้อนในโรงเดียวกัน (ไม่นับ cancelled) ----
    UNION ALL SELECT 'S10 showtime overlap pairs', COUNT(*)
    FROM showtimes a
    INNER JOIN showtimes b ON a.hall_id = b.hall_id AND a.showtime_id < b.showtime_id
    WHERE a.status <> 'cancelled' AND b.status <> 'cancelled'
      AND a.start_time < b.end_time AND a.end_time > b.start_time

    -- ---- Referential Integrity (ไม่มีแถวลูกที่ไม่มีแม่) ----
    UNION ALL SELECT 'S11 orphan FKs (all 9 relations)', COUNT(*) FROM (
        SELECT s.seat_id AS id FROM seats s LEFT JOIN cinema_halls h ON h.hall_id = s.hall_id WHERE h.hall_id IS NULL
        UNION ALL SELECT s.showtime_id FROM showtimes s LEFT JOIN movies m ON m.movie_id = s.movie_id WHERE m.movie_id IS NULL
        UNION ALL SELECT s.showtime_id FROM showtimes s LEFT JOIN cinema_halls h ON h.hall_id = s.hall_id WHERE h.hall_id IS NULL
        UNION ALL SELECT b.booking_id FROM bookings b LEFT JOIN customers c ON c.customer_id = b.customer_id WHERE c.customer_id IS NULL
        UNION ALL SELECT b.booking_id FROM bookings b LEFT JOIN showtimes s ON s.showtime_id = b.showtime_id WHERE s.showtime_id IS NULL
        UNION ALL SELECT b.booking_id FROM bookings b LEFT JOIN promotions p ON p.promotion_id = b.promotion_id WHERE b.promotion_id IS NOT NULL AND p.promotion_id IS NULL
        UNION ALL SELECT t.ticket_id FROM tickets t LEFT JOIN bookings b ON b.booking_id = t.booking_id WHERE b.booking_id IS NULL
        UNION ALL SELECT t.ticket_id FROM tickets t LEFT JOIN seats s ON s.seat_id = t.seat_id WHERE s.seat_id IS NULL
        UNION ALL SELECT p.payment_id FROM payments p LEFT JOIN bookings b ON b.booking_id = p.booking_id WHERE b.booking_id IS NULL
    ) x

    -- ---- ความสอดคล้องของข้อมูล ----
    UNION ALL SELECT 'S12 ticket seat not in showtime hall', COUNT(*)
    FROM tickets t
    INNER JOIN bookings b ON b.booking_id = t.booking_id
    INNER JOIN showtimes s ON s.showtime_id = b.showtime_id
    INNER JOIN seats se ON se.seat_id = t.seat_id
    WHERE se.hall_id <> s.hall_id

    UNION ALL SELECT 'S13 seat double-booked (active)', COUNT(*) FROM (
        SELECT b.showtime_id, t.seat_id
        FROM tickets t INNER JOIN bookings b ON b.booking_id = t.booking_id
        WHERE t.ticket_status IN ('reserved', 'issued') AND b.booking_status IN ('pending', 'confirmed')
        GROUP BY b.showtime_id, t.seat_id HAVING COUNT(*) > 1
    ) x

    UNION ALL SELECT 'S14 booking before customer created', COUNT(*)
    FROM bookings b INNER JOIN customers c ON c.customer_id = b.customer_id
    WHERE b.booking_time < c.created_at

    UNION ALL SELECT 'S15 booking made after show started', COUNT(*)
    FROM bookings b INNER JOIN showtimes s ON s.showtime_id = b.showtime_id
    WHERE b.booking_time >= s.start_time

    UNION ALL SELECT 'S16 total_amount <> tickets - discount', COUNT(*)
    FROM bookings b
    INNER JOIN (SELECT booking_id, SUM(ticket_price) AS subtotal FROM tickets GROUP BY booking_id) a ON a.booking_id = b.booking_id
    LEFT JOIN promotions p ON p.promotion_id = b.promotion_id
    WHERE ABS(dbo.fn_CalculateBookingTotal(a.subtotal, p.discount_type, p.discount_value) - b.total_amount) > 0.001

    UNION ALL SELECT 'S17 payment amount <> booking total', COUNT(*)
    FROM payments p INNER JOIN bookings b ON b.booking_id = p.booking_id
    WHERE ABS(p.amount - b.total_amount) > 0.001

    UNION ALL SELECT 'S18 booking/payment status mismatch', COUNT(*) FROM (
        SELECT b.booking_id FROM bookings b LEFT JOIN payments p ON p.booking_id = b.booking_id
        WHERE (b.booking_status = 'confirmed' AND (p.payment_status IS NULL OR p.payment_status <> 'paid'))
           OR (p.payment_status = 'paid' AND b.booking_status <> 'confirmed')
           OR (p.payment_status = 'refunded' AND b.booking_status <> 'cancelled')
           OR (p.payment_status = 'failed' AND b.booking_status <> 'expired')
           OR (p.payment_status = 'pending' AND b.booking_status <> 'pending')
    ) x

    UNION ALL SELECT 'S19 booking/ticket status mismatch', COUNT(*)
    FROM tickets t INNER JOIN bookings b ON b.booking_id = t.booking_id
    WHERE (b.booking_status = 'confirmed' AND t.ticket_status <> 'issued')
       OR (b.booking_status = 'pending'   AND t.ticket_status <> 'reserved')
       OR (b.booking_status IN ('expired', 'cancelled') AND t.ticket_status <> 'cancelled')

    UNION ALL SELECT 'S20 booking without 1-3 tickets', COUNT(*) FROM (
        SELECT b.booking_id FROM bookings b LEFT JOIN tickets t ON t.booking_id = b.booking_id
        GROUP BY b.booking_id HAVING COUNT(t.ticket_id) NOT BETWEEN 1 AND 3
    ) x

    UNION ALL SELECT 'S21 promotion not valid on booking date', COUNT(*)
    FROM bookings b INNER JOIN promotions p ON p.promotion_id = b.promotion_id
    WHERE CAST(b.booking_time AS DATE) < p.start_date OR CAST(b.booking_time AS DATE) > p.end_date

    UNION ALL SELECT 'S22 showtime before movie release', COUNT(*)
    FROM showtimes s INNER JOIN movies m ON m.movie_id = s.movie_id
    WHERE CAST(s.start_time AS DATE) < m.release_date

    UNION ALL SELECT 'S23 hall capacity <> seat count', COUNT(*) FROM (
        SELECT h.hall_id FROM cinema_halls h LEFT JOIN seats s ON s.hall_id = h.hall_id
        GROUP BY h.hall_id, h.capacity HAVING COUNT(s.seat_id) <> h.capacity
    ) x

    UNION ALL SELECT 'S24 invalid email format / duplicate', COUNT(*) FROM (
        SELECT customer_id FROM customers WHERE email NOT LIKE '%_@_%._%' OR email LIKE '% %'
        UNION ALL SELECT MIN(customer_id) FROM customers GROUP BY LOWER(email) HAVING COUNT(*) > 1
    ) x

    UNION ALL SELECT 'S25 hold window <> 15 minutes', COUNT(*)
    FROM bookings WHERE DATEDIFF(MINUTE, booking_time, expires_at) <> 15

    UNION ALL SELECT 'S26 admin account has password', CASE WHEN EXISTS (SELECT 1 FROM customers WHERE user_role = 'admin' AND password_hash IS NOT NULL) THEN 0 ELSE 1 END

    -- ---- I: ข้อมูลเชิงสถานะ (informational) ----
    UNION ALL SELECT 'I01 pending hold past expiry', COUNT(*) FROM bookings WHERE booking_status = 'pending' AND expires_at < SYSDATETIME()
    UNION ALL SELECT 'I02 completed showtime not yet ended', COUNT(*) FROM showtimes WHERE status = 'completed' AND end_time > SYSDATETIME()
    UNION ALL SELECT 'I03 scheduled showtime in inactive hall', COUNT(*)
    FROM showtimes s INNER JOIN cinema_halls h ON h.hall_id = s.hall_id WHERE s.status = 'scheduled' AND h.status = 'inactive'
) checks
ORDER BY check_name;
