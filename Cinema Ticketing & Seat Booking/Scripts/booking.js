/* ประมาณราคาระหว่างเลือกที่นั่ง (ยอดจริงคิดใน sp_BookMovieSeats รวมโปรโมชัน) */
(function () {
    function fmt(n) {
        return n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }
    function upd() {
        var boxes = document.querySelectorAll('input[name="seat"]:not(:disabled)');
        var sum = 0, count = 0, i;
        for (i = 0; i < boxes.length; i++) {
            if (boxes[i].checked) {
                count++;
                sum += parseFloat(boxes[i].getAttribute('data-price')) || 0;
            }
        }
        var el = document.getElementById('estText');
        if (!el) { return; }
        if (count === 0) {
            el.textContent = 'ยังไม่เลือกที่นั่ง (สูงสุด 10 ที่)';
        } else {
            el.textContent = 'เลือก ' + count + ' ที่ • ประมาณ ' + fmt(sum) + ' บาท (ยังไม่หักโปรโมชัน)';
        }
    }
    document.addEventListener('change', function (e) {
        if (e.target && e.target.name === 'seat') { upd(); }
    });
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', upd);
    } else {
        upd();
    }
})();
