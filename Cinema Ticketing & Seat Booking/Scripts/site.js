/* สคริปต์ร่วมของทุกหน้า: สลับธีม, เลือกที่นั่ง (สูงสุด 3), นับถอยหลังตามเวลาเซิร์ฟเวอร์, ยืนยันก่อนทำรายการ */
(function () {
  "use strict";
  var root = document.documentElement;

  // ---------- ธีมมืด/สว่าง (จำค่าไว้ใน localStorage) ----------
  var themeBtn = document.getElementById("themeToggle");
  function currentTheme() {
    var t = root.getAttribute("data-theme");
    if (t) return t;
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }
  if (themeBtn) {
    themeBtn.addEventListener("click", function () {
      var next = currentTheme() === "dark" ? "light" : "dark";
      root.setAttribute("data-theme", next);
      try { localStorage.setItem("theme", next); } catch (e) {}
      themeBtn.setAttribute("aria-pressed", next === "dark");
    });
    themeBtn.setAttribute("aria-pressed", currentTheme() === "dark");
  }

  // ---------- เลือกที่นั่ง ----------
  var seatBox = document.getElementById("seatMap");
  if (seatBox) {
    var max = parseInt(seatBox.getAttribute("data-max") || "3", 10);
    var price = parseFloat(seatBox.getAttribute("data-price") || "0");
    var inputs = seatBox.querySelectorAll("input[name=seat]");
    var list = document.getElementById("selList"), total = document.getElementById("selTotal"), hold = document.getElementById("btnHold");
    var update = function () {
      var picked = [];
      inputs.forEach(function (i) { if (i.checked) picked.push(i.getAttribute("data-label")); });
      inputs.forEach(function (i) { if (!i.checked && i.getAttribute("data-taken") !== "1") i.disabled = picked.length >= max; });
      if (list) list.textContent = picked.length ? picked.join(", ") : "ยังไม่ได้เลือก";
      if (total) total.textContent = "฿" + (picked.length * price).toLocaleString("en-US");
      if (hold) hold.disabled = picked.length === 0 && hold.getAttribute("data-guest") !== "1";
    };
    inputs.forEach(function (i) { i.addEventListener("change", update); });
    update();
  }

  // ---------- นับถอยหลัง: เริ่มจากวินาทีที่เซิร์ฟเวอร์ส่งมา ไม่อ่านนาฬิกาเครื่องผู้ใช้ ----------
  var timers = document.querySelectorAll(".js-countdown");
  if (timers.length) {
    var t0 = performance.now();
    var pad = function (n) { return (n < 10 ? "0" : "") + n; };
    var tick = function () {
      var elapsed = (performance.now() - t0) / 1000;
      timers.forEach(function (el) {
        var left = Math.max(0, Math.ceil(parseInt(el.getAttribute("data-seconds"), 10) - elapsed));
        el.textContent = pad(Math.floor(left / 60)) + ":" + pad(left % 60);
        if (left === 0 && !el.getAttribute("data-done")) {
          el.setAttribute("data-done", "1");
          var scope = el.closest("[data-expire-scope]") || document;
          scope.querySelectorAll("[data-expire-hide]").forEach(function (x) { x.hidden = true; });
          scope.querySelectorAll("[data-expire-show]").forEach(function (x) { x.hidden = false; });
        }
      });
    };
    tick(); setInterval(tick, 1000);
  }

  // ---------- ยืนยันก่อนทำรายการ (ลบ/ยกเลิก) ----------
  document.addEventListener("click", function (e) {
    var el = e.target.closest("[data-confirm]");
    if (el && !window.confirm(el.getAttribute("data-confirm"))) { e.preventDefault(); e.stopPropagation(); }
  }, true);

  // ---------- กันกดส่งฟอร์มซ้ำ (เช่น ชำระเงิน 2 ครั้ง) ----------
  var form = document.getElementById("form1");
  if (form) {
    form.addEventListener("submit", function (e) {
      if (e.defaultPrevented) return;               // validator ฝั่งไคลเอนต์ไม่ผ่าน
      if (form.getAttribute("data-submitted") === "1") { e.preventDefault(); return; }
      form.setAttribute("data-submitted", "1");
      setTimeout(function () { form.removeAttribute("data-submitted"); }, 6000);
    });
  }
})();
