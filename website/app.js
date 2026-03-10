/* ── Animated countdown in hero ─────────────────────────────────────────── */
(function () {
  const timerEl = document.getElementById('timer-demo');
  const countEl = document.getElementById('count-demo');
  const ringEl  = document.getElementById('ring-demo');

  let secs = 18 * 60 + 42;   // hero countdown
  let rest  = 20;             // overlay countdown

  // Tick the menu-bar timer every second
  setInterval(() => {
    secs = (secs - 1 + 1200) % 1200;
    const m = String(Math.floor(secs / 60)).padStart(2, '0');
    const s = String(secs % 60).padStart(2, '0');
    if (timerEl) timerEl.textContent = `${m}:${s}`;
  }, 1000);

  // Tick the overlay ring every second
  setInterval(() => {
    rest = rest <= 0 ? 20 : rest - 1;
    if (countEl) countEl.textContent = rest;
    if (ringEl) {
      const circ = 2 * Math.PI * 52;   // r=52
      const offset = circ * (1 - rest / 20);
      ringEl.style.strokeDashoffset = offset;
    }
  }, 1000);
})();

/* ── Scroll-reveal ──────────────────────────────────────────────────────── */
(function () {
  const els = document.querySelectorAll(
    '.feature-card, .step, .stat, .download-card, .hero h1, .hero-sub, .hero-btns'
  );
  els.forEach(el => el.classList.add('reveal'));

  const observer = new IntersectionObserver(
    entries => entries.forEach(e => { if (e.isIntersecting) e.target.classList.add('visible'); }),
    { threshold: 0.12 }
  );
  els.forEach(el => observer.observe(el));
})();

/* ── Navbar scroll shadow ───────────────────────────────────────────────── */
window.addEventListener('scroll', () => {
  document.getElementById('nav').style.background =
    window.scrollY > 20
      ? 'rgba(8,8,8,0.97)'
      : 'rgba(8,8,8,0.85)';
});

/* ── Auto-detect OS for download button highlight ───────────────────────── */
(function () {
  const ua  = navigator.userAgent.toLowerCase();
  const mac = ua.includes('mac');
  const win = ua.includes('win');
  const macBtn = document.getElementById('mac-btn');
  const winBtn = document.getElementById('win-btn');

  if (mac && macBtn) {
    macBtn.style.boxShadow = '0 0 0 3px rgba(255,107,53,.5)';
    macBtn.closest('.download-card').style.borderColor = 'rgba(255,107,53,.5)';
  }
  if (win && winBtn) {
    winBtn.style.boxShadow = '0 0 0 3px rgba(255,107,53,.5)';
    winBtn.closest('.download-card').style.borderColor = 'rgba(255,107,53,.5)';
  }
})();
