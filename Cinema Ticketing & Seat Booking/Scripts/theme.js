/* Shared light/dark theme for standalone pages.
   Remembers the choice in localStorage ('cinema-theme');
   first visit follows the OS setting. */
(function () {
    try {
        var t = localStorage.getItem('cinema-theme');
        if (!t) {
            t = (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) ? 'dark' : 'light';
        }
        document.documentElement.setAttribute('data-theme', t);
    } catch (e) { /* private mode etc: stay on default light theme */ }
})();
document.addEventListener('DOMContentLoaded', function () {
    var b = document.getElementById('themeBtn');
    if (!b) { return; }
    function paint() {
        var t = document.documentElement.getAttribute('data-theme') || 'light';
        var dark = (t === 'dark');
        b.textContent = dark ? '\u2600\uFE0F' : '\uD83C\uDF19';
        b.setAttribute('aria-pressed', dark ? 'true' : 'false');
    }
    b.addEventListener('click', function () {
        var next = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
        document.documentElement.setAttribute('data-theme', next);
        try { localStorage.setItem('cinema-theme', next); } catch (e) {}
        paint();
    });
    paint();
});
