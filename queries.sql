-- =========================================================
-- queries.sql
-- Complex SQL Queries จำนวน 10 ข้อ
-- หัวข้อที่ 7: ระบบจองตั๋วภาพยนตร์และผังที่นั่ง
-- DBMS: Microsoft SQL Server
--
-- ครอบคลุมตามเกณฑ์:
--   - Multi-table JOIN (≥ 3 ตาราง)     : 2 ข้อ  (Query 1-2)
--   - GROUP BY + HAVING               : 3 ข้อ  (Query 3-5)
--   - Subquery / Correlated Subquery  : 3 ข้อ  (Query 6-8)
--   - Window Function                 : 2 ข้อ  (Query 9-10)
-- =========================================================


-- =========================================================
-- Query 1: Multi-table JOIN (6 ตาราง)
-- ประเภท: Multi-table JOIN
-- คำอธิบาย:
--   แสดงรายละเอียดการจองตั๋วแบบละเอียด
--   ใช้ดูว่าลูกค้าคนไหน จองหนังเรื่องอะไร รอบไหน ที่นั่งไหน
--   และมียอดชำระเท่าไร (ใช้ในหน้าประวัติการจองของลูกค้า)
-- =========================================================
SELECT
    b.booking_id,
    c.name              AS customer_name,
    c.email             AS customer_email,
    m.title             AS movie_title,
    s.start_time        AS show_time,
    ch.hall_name,
    se.row_label + CAST(se.seat_number AS VARCHAR(5)) AS seat,
    t.ticket_price,
    b.booking_status,
    b.total_amount
FROM bookings b
INNER JOIN customers c      ON b.customer_id = c.customer_id
INNER JOIN showtimes s      ON b.showtime_id = s.showtime_id
INNER JOIN movies m         ON s.movie_id = m.movie_id
INNER JOIN cinema_halls ch  ON s.hall_id = ch.hall_id
INNER JOIN tickets t        ON b.booking_id = t.booking_id
INNER JOIN seats se         ON t.seat_id = se.seat_id
WHERE b.booking_status = 'confirmed'
ORDER BY b.booking_time DESC;


-- =========================================================
-- Query 2: Multi-table JOIN (3 ตารางขึ้นไป)
-- ประเภท: Multi-table JOIN
-- คำอธิบาย:
--   แสดงรายการรอบฉายพร้อมชื่อหนัง ชื่อโรง และจำนวนตั๋วที่ขายได้แล้ว
--   ใช้ในหน้าจัดการรอบฉายของผู้ดูแลระบบ
-- =========================================================
SELECT
    s.showtime_id,
    m.title             AS movie_title,
    m.genre,
    ch.hall_name,
    s.start_time,
    s.end_time,
    s.standard_price,
    s.status            AS showtime_status,
    COUNT(t.ticket_id)  AS tickets_sold
FROM showtimes s
INNER JOIN movies m         ON s.movie_id = m.movie_id
INNER JOIN cinema_halls ch  ON s.hall_id = ch.hall_id
LEFT JOIN bookings b        ON s.showtime_id = b.showtime_id
                           AND b.booking_status = 'confirmed'
LEFT JOIN tickets t         ON b.booking_id = t.booking_id
                           AND t.ticket_status = 'issued'
GROUP BY
    s.showtime_id, m.title, m.genre, ch.hall_name,
    s.start_time, s.end_time, s.standard_price, s.status
ORDER BY s.start_time;


-- =========================================================
-- Query 3: GROUP BY + HAVING
-- ประเภท: GROUP BY + HAVING
-- คำอธิบาย:
--   หาภาพยนตร์ที่มียอดขายตั๋วตั้งแต่ 5 ใบขึ้นไป
--   ใช้สำหรับรายงานหนังยอดนิยม
-- =========================================================
SELECT
    m.movie_id,
    m.title,
    m.genre,
    COUNT(t.ticket_id) AS tickets_sold,
    SUM(t.ticket_price) AS total_revenue
FROM movies m
INNER JOIN showtimes s ON m.movie_id = s.movie_id
INNER JOIN bookings b  ON s.showtime_id = b.showtime_id
INNER JOIN tickets t   ON b.booking_id = t.booking_id
WHERE t.ticket_status = 'issued'
GROUP BY m.movie_id, m.title, m.genre
HAVING COUNT(t.ticket_id) >= 5
ORDER BY tickets_sold DESC;


-- =========================================================
-- Query 4: GROUP BY + HAVING
-- ประเภท: GROUP BY + HAVING
-- คำอธิบาย:
--   หาลูกค้าที่เคยจองสำเร็จตั้งแต่ 2 ครั้งขึ้นไป
--   ใช้สำหรับจัดกลุ่มลูกค้าประจำ (Loyal Customers)
-- =========================================================
SELECT
    c.customer_id,
    c.name,
    c.email,
    COUNT(b.booking_id) AS total_bookings,
    SUM(b.total_amount) AS total_spent
FROM customers c
INNER JOIN bookings b ON c.customer_id = b.customer_id
WHERE b.booking_status = 'confirmed'
GROUP BY c.customer_id, c.name, c.email
HAVING COUNT(b.booking_id) >= 2
ORDER BY total_spent DESC;


-- =========================================================
-- Query 5: GROUP BY + HAVING
-- ประเภท: GROUP BY + HAVING
-- คำอธิบาย:
--   หารอบฉายที่มีอัตราการขายตั๋วสูง (ขายได้ตั้งแต่ 3 ใบขึ้นไป)
--   ใช้เพื่อวิเคราะห์ว่ารอบไหนขายดี
-- =========================================================
SELECT
    s.showtime_id,
    m.title AS movie_title,
    ch.hall_name,
    s.start_time,
    COUNT(t.ticket_id) AS tickets_sold,
    ch.capacity,
    CAST(COUNT(t.ticket_id) * 100.0 / ch.capacity AS DECIMAL(5,2)) AS occupancy_percent
FROM showtimes s
INNER JOIN movies m        ON s.movie_id = m.movie_id
INNER JOIN cinema_halls ch ON s.hall_id = ch.hall_id
LEFT JOIN bookings b       ON s.showtime_id = b.showtime_id
                          AND b.booking_status = 'confirmed'
LEFT JOIN tickets t        ON b.booking_id = t.booking_id
                          AND t.ticket_status = 'issued'
GROUP BY
    s.showtime_id, m.title, ch.hall_name,
    s.start_time, ch.capacity
HAVING COUNT(t.ticket_id) >= 3
ORDER BY occupancy_percent DESC;


-- =========================================================
-- Query 6: Subquery
-- ประเภท: Subquery
-- คำอธิบาย:
--   หาภาพยนตร์ที่มีรายได้สูงกว่าค่าเฉลี่ยรายได้ของหนังทั้งหมด
--   ใช้สำหรับรายงานหนังที่ทำรายได้ดีกว่าค่าเฉลี่ย
-- =========================================================
SELECT
    m.movie_id,
    m.title,
    m.genre,
    SUM(t.ticket_price) AS total_revenue
FROM movies m
INNER JOIN showtimes s ON m.movie_id = s.movie_id
INNER JOIN bookings b  ON s.showtime_id = b.showtime_id
INNER JOIN tickets t   ON b.booking_id = t.booking_id
WHERE t.ticket_status = 'issued'
GROUP BY m.movie_id, m.title, m.genre
HAVING SUM(t.ticket_price) > (
    -- Subquery: คำนวณรายได้เฉลี่ยของหนังทุกเรื่อง
    SELECT AVG(movie_revenue)
    FROM (
        SELECT SUM(t2.ticket_price) AS movie_revenue
        FROM movies m2
        INNER JOIN showtimes s2 ON m2.movie_id = s2.movie_id
        INNER JOIN bookings b2  ON s2.showtime_id = b2.showtime_id
        INNER JOIN tickets t2   ON b2.booking_id = t2.booking_id
        WHERE t2.ticket_status = 'issued'
        GROUP BY m2.movie_id
    ) AS avg_table
)
ORDER BY total_revenue DESC;


-- =========================================================
-- Query 7: Correlated Subquery
-- ประเภท: Correlated Subquery
-- คำอธิบาย:
--   แสดงลูกค้าแต่ละคน พร้อมจำนวนครั้งที่จองสำเร็จ และยอดจองสูงสุด
--   ใช้ในหน้ารายชื่อลูกค้าเพื่อดูสรุปพฤติกรรมรายบุคคล
-- =========================================================
SELECT
    c.customer_id,
    c.name,
    c.email,
    (
        SELECT COUNT(*)
        FROM bookings b
        WHERE b.customer_id = c.customer_id
          AND b.booking_status = 'confirmed'
    ) AS total_confirmed_bookings,
    (
        SELECT MAX(b2.total_amount)
        FROM bookings b2
        WHERE b2.customer_id = c.customer_id
          AND b2.booking_status = 'confirmed'
    ) AS highest_booking_amount
FROM customers c
WHERE EXISTS (
    SELECT 1
    FROM bookings b3
    WHERE b3.customer_id = c.customer_id
      AND b3.booking_status = 'confirmed'
)
ORDER BY total_confirmed_bookings DESC;


-- =========================================================
-- Query 8: Subquery
-- ประเภท: Subquery
-- คำอธิบาย:
--   หารอบฉายที่ยังไม่มีใครจองเลย (ไม่มีตั๋วที่ออกแล้ว)
--   ใช้สำหรับโปรโมทรอบฉายที่ยังว่างอยู่
-- =========================================================
SELECT
    s.showtime_id,
    m.title AS movie_title,
    ch.hall_name,
    s.start_time,
    s.standard_price,
    s.status
FROM showtimes s
INNER JOIN movies m        ON s.movie_id = m.movie_id
INNER JOIN cinema_halls ch ON s.hall_id = ch.hall_id
WHERE s.status = 'scheduled'
  AND s.showtime_id NOT IN (
      -- Subquery: รายการ showtime_id ที่มีคนจองแล้ว
      SELECT DISTINCT b.showtime_id
      FROM bookings b
      INNER JOIN tickets t ON b.booking_id = t.booking_id
      WHERE b.booking_status = 'confirmed'
        AND t.ticket_status = 'issued'
  )
ORDER BY s.start_time;


-- =========================================================
-- Query 9: Window Function (RANK)
-- ประเภท: Window Function
-- คำอธิบาย:
--   จัดอันดับภาพยนตร์ตามรายได้รวม (ใช้ RANK)
--   ใช้ในรายงาน Top Movies ประจำช่วงเวลา
-- =========================================================
SELECT
    movie_id,
    movie_title,
    genre,
    total_revenue,
    tickets_sold,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
FROM (
    SELECT
        m.movie_id,
        m.title AS movie_title,
        m.genre,
        ISNULL(SUM(CASE WHEN t.ticket_status = 'issued' THEN t.ticket_price END), 0) AS total_revenue,
        COUNT(CASE WHEN t.ticket_status = 'issued' THEN 1 END) AS tickets_sold
    FROM movies m
    LEFT JOIN showtimes s ON m.movie_id = s.movie_id
    LEFT JOIN bookings b  ON s.showtime_id = b.showtime_id
    LEFT JOIN tickets t   ON b.booking_id = t.booking_id
    GROUP BY m.movie_id, m.title, m.genre
) AS movie_stats
ORDER BY revenue_rank;


-- =========================================================
-- Query 10: Window Function (ROW_NUMBER + PARTITION BY)
-- ประเภท: Window Function
-- คำอธิบาย:
--   แสดงประวัติการจองของลูกค้า โดยเรียงลำดับการจองล่าสุดของแต่ละคน
--   ใช้ ROW_NUMBER แบ่งกลุ่มตามลูกค้า (PARTITION BY)
--   เหมาะสำหรับหน้า "การจองล่าสุดของฉัน"
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
            ORDER BY b.booking_time DESC
        ) AS booking_sequence
    FROM customers c
    INNER JOIN bookings b  ON c.customer_id = b.customer_id
    INNER JOIN showtimes s ON b.showtime_id = s.showtime_id
    INNER JOIN movies m    ON s.movie_id = m.movie_id
) AS ranked_bookings
WHERE booking_sequence <= 3   -- เอาเฉพาะ 3 รายการล่าสุดของแต่ละคน
ORDER BY customer_id, booking_sequence;