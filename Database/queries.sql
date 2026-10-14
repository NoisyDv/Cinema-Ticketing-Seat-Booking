-- =========================================================
-- queries.sql  (revised v2)
-- Complex SQL Queries จำนวน 10 ข้อ
-- หัวข้อที่ 7: ระบบจองตั๋วภาพยนตร์และผังที่นั่ง
-- DBMS: Microsoft SQL Server
--
-- ครอบคลุมตามเกณฑ์:
--   - Multi-table JOIN (≥ 3 ตาราง)        : 2 ข้อ  (Query 1-2)
--   - GROUP BY + HAVING                   : 3 ข้อ  (Query 3-5)
--   - Subquery / Correlated / EXISTS      : 3 ข้อ  (Query 6-8)
--   - Window Function                     : 2 ข้อ  (Query 9-10)
--
-- นิยามรายได้ที่ใช้ร่วมกันทุก query (ตรงกับ vw_BoxOfficeOccupancyReport):
--   รายได้ = payments.amount ที่ payment_status = 'paid'
--            ของ booking ที่ booking_status = 'confirmed'
--   (เป็นยอดหลังหักโปรโมชันแล้ว)
--   หนึ่ง booking มีได้หนึ่ง payment (UNIQUE) จึง SUM ได้โดยไม่เกิดการนับซ้ำ
--   แต่ถ้า JOIN กับ tickets ต้องสรุปจำนวนตั๋วต่อ booking ก่อน
--
-- นิยามที่นั่งไม่ว่างที่ใช้ร่วมกัน (ตรงกับ sp_BookMovieSeats):
--   ตั๋ว reserved/issued ของ booking ที่ confirmed
--   หรือ pending ที่ expires_at ยังไม่ถึงเวลาปัจจุบัน
-- =========================================================


-- =========================================================
-- Query 1: Multi-table JOIN (9 ตาราง)
-- ประเภท: Multi-table JOIN
-- ใช้ที่: หน้าประวัติการจอง / ใบยืนยันการจองของลูกค้า
-- คำอธิบาย:
--   แสดงรายละเอียดตั๋วทุกใบของการจองที่ชำระเงินแล้ว
--   ลูกค้า หนัง รอบฉาย โรง ที่นั่ง ราคา โปรโมชันที่ใช้ และช่องทางชำระเงิน
--   promotions ใช้ LEFT JOIN เพราะ booking ไม่จำเป็นต้องมีโปรโมชัน
-- ตารางที่ใช้: bookings, customers, showtimes, movies, cinema_halls,
--              tickets, seats, payments, promotions
-- =========================================================
SELECT
    b.booking_id,
    c.name              AS customer_name,
    c.email             AS customer_email,
    m.title             AS movie_title,
    s.start_time        AS show_time,
    ch.hall_name,
    se.row_label + CAST(se.seat_number AS VARCHAR(5)) AS seat,
    se.seat_type,
    t.ticket_price,
    pr.promotion_code,
    pay.payment_method,
    b.total_amount
FROM bookings b
INNER JOIN customers c      ON b.customer_id  = c.customer_id
INNER JOIN showtimes s      ON b.showtime_id  = s.showtime_id
INNER JOIN movies m         ON s.movie_id     = m.movie_id
INNER JOIN cinema_halls ch  ON s.hall_id      = ch.hall_id
INNER JOIN tickets t        ON b.booking_id   = t.booking_id
INNER JOIN seats se         ON t.seat_id      = se.seat_id
INNER JOIN payments pay     ON b.booking_id   = pay.booking_id
LEFT  JOIN promotions pr    ON b.promotion_id = pr.promotion_id
WHERE b.booking_status  = 'confirmed'
  AND t.ticket_status   = 'issued'
  AND pay.payment_status = 'paid'
  -- ถ้าใช้เป็นหน้าของลูกค้าคนเดียว ให้เพิ่ม: AND b.customer_id = @customer_id
ORDER BY b.booking_time DESC, b.booking_id, se.row_label, se.seat_number;


-- =========================================================
-- Query 2: Multi-table JOIN + CASE (ผังที่นั่งของรอบฉาย)
-- ประเภท: Multi-table JOIN
-- ใช้ที่: หน้าเลือกที่นั่ง (ฟังก์ชันหลักของเว็บ)
-- คำอธิบาย:
--   แสดงที่นั่งทุกที่ของโรงที่ฉายรอบนี้ พร้อมสถานะ
--     available = ว่าง
--     held      = ถูกล็อกชั่วคราวรอชำระเงิน (pending ที่ยังไม่หมดเวลา)
--     sold      = ขายแล้ว (confirmed)
--   ใช้ LEFT JOIN เพื่อให้ที่นั่งว่างยังแสดงอยู่ และใช้เงื่อนไขเดียวกับ
--   ขั้นตอน 4.2 ของ sp_BookMovieSeats
-- ตารางที่ใช้: showtimes, movies, cinema_halls, seats, tickets, bookings
-- =========================================================
DECLARE @showtime_id INT = 1;   -- เปลี่ยนเป็นรอบฉายที่ต้องการดู

SELECT
    m.title            AS movie_title,
    ch.hall_name,
    s.start_time,
    se.seat_id,
    se.row_label,
    se.seat_number,
    se.seat_type,
    CASE
        WHEN occ.booking_status = 'confirmed' THEN 'sold'
        WHEN occ.booking_status = 'pending'   THEN 'held'
        ELSE 'available'
    END AS seat_status
FROM showtimes s
INNER JOIN movies m        ON s.movie_id = m.movie_id
INNER JOIN cinema_halls ch ON s.hall_id  = ch.hall_id
INNER JOIN seats se        ON se.hall_id = s.hall_id
LEFT JOIN (
    SELECT t.seat_id, b.booking_status
    FROM tickets t
    INNER JOIN bookings b ON b.booking_id = t.booking_id
    WHERE b.showtime_id   = @showtime_id
      AND t.ticket_status IN ('reserved', 'issued')
      AND (   b.booking_status = 'confirmed'
           OR (b.booking_status = 'pending' AND b.expires_at > SYSDATETIME()))
) occ ON occ.seat_id = se.seat_id
WHERE s.showtime_id = @showtime_id
ORDER BY se.row_label, se.seat_number;


-- =========================================================
-- Query 3: GROUP BY + HAVING
-- ประเภท: GROUP BY + HAVING
-- ใช้ที่: รายงานหนังยอดนิยมของผู้บริหาร
-- คำอธิบาย:
--   หาภาพยนตร์ที่ขายตั๋วได้ตั้งแต่ 5 ใบขึ้นไป พร้อมรายได้จริง
--   สรุปจำนวนตั๋วต่อ booking ก่อน (derived table) แล้วค่อยรวมยอดชำระ
--   เพื่อไม่ให้ payments.amount ถูกนับซ้ำตามจำนวนตั๋ว
--   (ปรับเกณฑ์ >= 5 ตามปริมาณข้อมูลทดสอบ)
-- =========================================================
SELECT
    m.movie_id,
    m.title,
    m.genre,
    SUM(bt.ticket_count) AS tickets_sold,
    SUM(pay.amount)      AS total_revenue
FROM movies m
INNER JOIN showtimes s ON m.movie_id    = s.movie_id
INNER JOIN bookings b  ON s.showtime_id = b.showtime_id
                      AND b.booking_status = 'confirmed'
INNER JOIN payments pay ON b.booking_id = pay.booking_id
                       AND pay.payment_status = 'paid'
INNER JOIN (
    SELECT booking_id, COUNT(*) AS ticket_count
    FROM tickets
    WHERE ticket_status = 'issued'
    GROUP BY booking_id
) bt ON bt.booking_id = b.booking_id
GROUP BY m.movie_id, m.title, m.genre
HAVING SUM(bt.ticket_count) >= 5
ORDER BY tickets_sold DESC;


-- =========================================================
-- Query 4: GROUP BY + HAVING (เปรียบเทียบสัดส่วน)
-- ประเภท: GROUP BY + HAVING
-- ใช้ที่: หน้าจัดการรอบฉายของผู้ดูแลระบบ
-- คำอธิบาย:
--   หารอบฉายที่มีอัตราการครองที่นั่งตั้งแต่ 50% ขึ้นไป
--   ความจุนับจากจำนวนที่นั่งจริงในตาราง seats (ไม่ใช้ cinema_halls.capacity)
--   นับเฉพาะรอบ scheduled และ completed
--   (ปรับเกณฑ์ 50 ตามปริมาณข้อมูลทดสอบ)
-- =========================================================
SELECT
    s.showtime_id,
    m.title            AS movie_title,
    ch.hall_name,
    s.start_time,
    hs.seat_total,
    COUNT(t.ticket_id) AS tickets_sold,
    CAST(COUNT(t.ticket_id) * 100.0 / hs.seat_total AS DECIMAL(5,2)) AS occupancy_percent
FROM showtimes s
INNER JOIN movies m        ON s.movie_id = m.movie_id
INNER JOIN cinema_halls ch ON s.hall_id  = ch.hall_id
INNER JOIN (
    SELECT hall_id, COUNT(*) AS seat_total
    FROM seats
    GROUP BY hall_id
) hs ON hs.hall_id = s.hall_id
LEFT JOIN bookings b ON s.showtime_id = b.showtime_id
                    AND b.booking_status = 'confirmed'
LEFT JOIN tickets t  ON b.booking_id = t.booking_id
                    AND t.ticket_status = 'issued'
WHERE s.status IN ('scheduled', 'completed')
GROUP BY s.showtime_id, m.title, ch.hall_name, s.start_time, hs.seat_total
HAVING COUNT(t.ticket_id) * 100.0 / hs.seat_total >= 50
ORDER BY occupancy_percent DESC;


-- =========================================================
-- Query 5: GROUP BY + HAVING (ใช้ CTE ช่วยสรุปยอดก่อน)
-- ประเภท: GROUP BY + HAVING
-- ใช้ที่: รายงานประสิทธิภาพโปรโมชัน (ฝ่ายการตลาด)
-- คำอธิบาย:
--   สรุปผลของแต่ละโปรโมชันที่ถูกใช้ตั้งแต่ 2 ครั้งขึ้นไป: ใช้กี่ครั้ง
--   ยอดก่อนหักส่วนลด ส่วนลดที่ให้ไป และรายได้สุทธิ
--   ใช้ CTE สรุปยอดตั๋วต่อ booking ก่อน แล้วกรองด้วย HAVING
--   (โปรที่ไม่เคยถูกใช้เลยจะไม่ปรากฏในรายงานนี้)
-- ตารางที่ใช้: promotions, bookings, payments, tickets
-- =========================================================
WITH booking_subtotal AS (
    SELECT booking_id, SUM(ticket_price) AS subtotal
    FROM tickets
    WHERE ticket_status = 'issued'
    GROUP BY booking_id
)
SELECT
    p.promotion_id,
    p.promotion_code,
    p.discount_type,
    p.discount_value,
    COUNT(b.booking_id)                     AS times_used,
    ISNULL(SUM(bs.subtotal), 0)             AS gross_sales,
    ISNULL(SUM(bs.subtotal - pay.amount), 0) AS discount_given,
    ISNULL(SUM(pay.amount), 0)              AS net_revenue
FROM promotions p
LEFT JOIN bookings b          ON b.promotion_id = p.promotion_id
                             AND b.booking_status = 'confirmed'
LEFT JOIN payments pay        ON pay.booking_id = b.booking_id
                             AND pay.payment_status = 'paid'
LEFT JOIN booking_subtotal bs ON bs.booking_id = b.booking_id
GROUP BY p.promotion_id, p.promotion_code, p.discount_type, p.discount_value
HAVING COUNT(b.booking_id) >= 2
ORDER BY times_used DESC, net_revenue DESC;


-- =========================================================
-- Query 6: Correlated Subquery
-- ประเภท: Correlated Subquery
-- ใช้ที่: หน้ารายชื่อลูกค้าของผู้ดูแลระบบ (สรุปพฤติกรรมรายบุคคล)
-- คำอธิบาย:
--   แสดงลูกค้า "ทุกคน" พร้อมจำนวนครั้งที่จองสำเร็จ ยอดใช้จ่ายรวม
--   และเวลาจองล่าสุด ลูกค้าที่ยังไม่เคยจองแสดงเป็น 0 / NULL
--   (ใช้ Correlated Subquery ที่อ้างอิง c.customer_id ของแถวนอก)
-- =========================================================
SELECT
    c.customer_id,
    c.name,
    c.email,
    (
        SELECT COUNT(*)
        FROM bookings b1
        WHERE b1.customer_id = c.customer_id
          AND b1.booking_status = 'confirmed'
    ) AS total_confirmed_bookings,
    (
        SELECT ISNULL(SUM(pay.amount), 0)
        FROM bookings b2
        INNER JOIN payments pay ON pay.booking_id = b2.booking_id
        WHERE b2.customer_id = c.customer_id
          AND b2.booking_status = 'confirmed'
          AND pay.payment_status = 'paid'
    ) AS total_spent,
    (
        SELECT MAX(b3.booking_time)
        FROM bookings b3
        WHERE b3.customer_id = c.customer_id
          AND b3.booking_status = 'confirmed'
    ) AS last_booking_time
FROM customers c
ORDER BY total_spent DESC, c.name;


-- =========================================================
-- Query 7: NOT EXISTS
-- ประเภท: Subquery (NOT EXISTS)
-- ใช้ที่: ผู้ดูแลระบบเลือกรอบฉายไปโปรโมท
-- คำอธิบาย:
--   หารอบฉายที่ยังไม่เริ่มฉายและยังไม่มีที่นั่งถูกจองหรือถูกล็อกเลย
--   ใช้ NOT EXISTS (ปลอดภัยกว่า NOT IN เมื่อมี NULL) และใช้นิยามที่นั่ง
--   ไม่ว่างเดียวกับ procedure จึงไม่ถือว่ารอบที่มี pending hold เป็นรอบว่าง
-- =========================================================
SELECT
    s.showtime_id,
    m.title AS movie_title,
    ch.hall_name,
    s.start_time,
    s.standard_price
FROM showtimes s
INNER JOIN movies m        ON s.movie_id = m.movie_id
INNER JOIN cinema_halls ch ON s.hall_id  = ch.hall_id
WHERE s.status = 'scheduled'
  AND s.start_time > SYSDATETIME()
  AND NOT EXISTS (
      SELECT 1
      FROM bookings b
      INNER JOIN tickets t ON t.booking_id = b.booking_id
      WHERE b.showtime_id = s.showtime_id
        AND t.ticket_status IN ('reserved', 'issued')
        AND (   b.booking_status = 'confirmed'
             OR (b.booking_status = 'pending' AND b.expires_at > SYSDATETIME()))
  )
ORDER BY s.start_time;


-- =========================================================
-- Query 8: EXISTS + Correlated Subquery (รอบฉายที่เวลาทับกัน)
-- ประเภท: Subquery (EXISTS + Correlated)
-- ใช้ที่: ผู้ดูแลระบบตรวจความถูกต้องของตารางฉาย
-- คำอธิบาย:
--   หารอบฉายที่มีรอบอื่นทับกันในโรงเดียวกัน (schema มีแค่ end_time > start_time
--   ไม่มี constraint กันเวลาทับ จึงใช้ query นี้ตรวจกฎ "รอบในโรงเดียวกันห้ามทับกัน")
--   เงื่อนไขทับกัน: o.start < s.end และ s.start < o.end
--   ใช้ EXISTS กรองเฉพาะรอบที่ทับจริง และ correlated subquery นับจำนวนรอบที่ทับ
--   ผลลัพธ์ควรว่างเมื่อข้อมูลถูกต้อง
-- =========================================================
SELECT
    ch.hall_name,
    s.showtime_id,
    m.title          AS movie_title,
    s.start_time,
    s.end_time,
    (SELECT COUNT(*)
     FROM showtimes o
     WHERE o.hall_id = s.hall_id
       AND o.showtime_id <> s.showtime_id
       AND o.status <> 'cancelled'
       AND o.start_time < s.end_time
       AND s.start_time < o.end_time) AS overlap_count
FROM showtimes s
INNER JOIN cinema_halls ch ON ch.hall_id = s.hall_id
INNER JOIN movies m        ON m.movie_id = s.movie_id
WHERE s.status <> 'cancelled'
  AND EXISTS (
      SELECT 1
      FROM showtimes o2
      WHERE o2.hall_id = s.hall_id
        AND o2.showtime_id <> s.showtime_id
        AND o2.status <> 'cancelled'
        AND o2.start_time < s.end_time
        AND s.start_time < o2.end_time
  )
ORDER BY ch.hall_name, s.start_time;


-- =========================================================
-- Query 9: Window Function (RANK + SUM/AVG OVER)
-- ประเภท: Window Function
-- ใช้ที่: รายงาน Top Movies
-- คำอธิบาย:
--   จัดอันดับหนังตามรายได้จริง พร้อมสัดส่วนรายได้ของแต่ละเรื่องต่อรายได้รวม
--   และเปรียบเทียบกับค่าเฉลี่ยของหนังทุกเรื่อง (รวมหนังที่ยังขายไม่ได้)
--   ใช้ CTE สรุปรายได้ต่อหนังก่อน แล้วใช้ window function ที่ชั้นนอก
-- =========================================================
WITH movie_revenue AS (
    SELECT
        m.movie_id,
        m.title,
        m.genre,
        ISNULL(SUM(pay.amount), 0) AS total_revenue
    FROM movies m
    LEFT JOIN showtimes s   ON m.movie_id    = s.movie_id
    LEFT JOIN bookings b    ON s.showtime_id = b.showtime_id
                           AND b.booking_status = 'confirmed'
    LEFT JOIN payments pay  ON b.booking_id  = pay.booking_id
                           AND pay.payment_status = 'paid'
    GROUP BY m.movie_id, m.title, m.genre
)
SELECT
    movie_id,
    title,
    genre,
    total_revenue,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
    CAST(CASE WHEN SUM(total_revenue) OVER () > 0
              THEN total_revenue * 100.0 / SUM(total_revenue) OVER ()
              ELSE 0
         END AS DECIMAL(5,2)) AS revenue_share_percent,
    CAST(AVG(total_revenue) OVER () AS DECIMAL(12,2)) AS average_revenue_all_movies,
    CASE WHEN total_revenue > AVG(total_revenue) OVER ()
         THEN N'above average'
         ELSE N'average or below'
    END AS vs_average
FROM movie_revenue
ORDER BY revenue_rank, title;


-- =========================================================
-- Query 10: Window Function (ROW_NUMBER + PARTITION BY)
-- ประเภท: Window Function
-- ใช้ที่: รายงานฝั่งผู้ดูแล "การจองล่าสุดของลูกค้าแต่ละคน"
-- คำอธิบาย:
--   แสดงการจองล่าสุด 3 รายการของลูกค้าแต่ละคนพร้อมกัน
--   ใช้ ROW_NUMBER แบ่งกลุ่มตามลูกค้า (PARTITION BY)
--   เพิ่ม booking_id DESC เป็น tiebreaker กรณีเวลาจองเท่ากัน
--   (หน้าเว็บของลูกค้าคนเดียวใช้ TOP 3 ก็พอ ส่วน query นี้เหมาะกับดูทุกคนในครั้งเดียว)
-- =========================================================
SELECT
    customer_id,
    customer_name,
    booking_id,
    movie_title,
    show_time,
    total_amount,
    booking_status,
    booking_sequence
FROM (
    SELECT
        c.customer_id,
        c.name AS customer_name,
        b.booking_id,
        m.title AS movie_title,
        s.start_time AS show_time,
        b.total_amount,
        b.booking_status,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_id
            ORDER BY b.booking_time DESC, b.booking_id DESC
        ) AS booking_sequence
    FROM customers c
    INNER JOIN bookings b  ON c.customer_id = b.customer_id
    INNER JOIN showtimes s ON b.showtime_id = s.showtime_id
    INNER JOIN movies m    ON s.movie_id    = m.movie_id
) AS ranked_bookings
WHERE booking_sequence <= 3   -- เอาเฉพาะ 3 รายการล่าสุดของแต่ละคน
ORDER BY customer_id, booking_sequence;