// ================================================================
// iris-demo.js — interactive hero demo
// State machine: idle → countdown → breaking → toast → idle
// ================================================================

const REDUCED = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

// ── CDN deps (loaded async; both are progressive enhancement) ───
let motionAnimate = null;
let getSvgPath    = null;

(async () => {
  try {
    const m = await import('motion');
    motionAnimate = m.animate;
  } catch { /* CSS transitions as fallback */ }

  try {
    const s = await import('figma-squircle');
    getSvgPath = s.getSvgPath;
  } catch { /* border-radius as fallback */ }

  applySquircle();
})();

// ── DOM refs ────────────────────────────────────────────────────
const $ = id => document.getElementById(id);
const screenWrap   = $('demo-screen-wrap');
const irisBtn      = $('demo-iris-btn');
const dropdown     = $('demo-dropdown');
const ddTime       = $('demo-dd-time');
const ringFill     = $('demo-ring-fill');
const countdown    = $('demo-countdown');
const breakOverlay = $('demo-break-overlay');
const brFill       = $('demo-br-fill');
const toast        = $('demo-toast');
const hintEl       = $('demo-hint');
const clockEl      = $('demo-clock');

// ── Clock ────────────────────────────────────────────────────────
function tickClock() {
  if (!clockEl) return;
  clockEl.textContent = new Date().toLocaleTimeString('en-US', {
    hour: 'numeric', minute: '2-digit'
  });
}
tickClock();
setInterval(tickClock, 10_000);

// ── Squircle clip-path ───────────────────────────────────────────
function applySquircle() {
  if (!screenWrap) return;
  const { width, height } = screenWrap.getBoundingClientRect();
  if (!width) return;

  if (getSvgPath) {
    try {
      const p = getSvgPath({ width, height, cornerRadius: 10, cornerSmoothing: 0.65 });
      screenWrap.style.clipPath  = `path('${p}')`;
      screenWrap.style.borderRadius = '';
      return;
    } catch { /* fall through */ }
  }
  screenWrap.style.clipPath = '';
  screenWrap.style.borderRadius = '10px';
}

const resizeObs = new ResizeObserver(() => applySquircle());
if (screenWrap) resizeObs.observe(screenWrap);

// ── Event emitter for other page elements ────────────────────────
export const emitter = new EventTarget();

// ── State machine ────────────────────────────────────────────────
let state = 'idle';
const _timers = [];

function _after(ms, fn) { _timers.push(setTimeout(fn, ms)); }
function _cancelAll() { _timers.splice(0).forEach(clearTimeout); }

function setState(next) {
  state = next;
  emitter.dispatchEvent(new CustomEvent('iris:state', { detail: next }));
}

// ── Ring helpers ─────────────────────────────────────────────────
const RING_C = 2 * Math.PI * 22;   // dropdown ring r=22
const BR_C   = 2 * Math.PI * 46;   // break ring r=46

function setRingProgress(frac) {
  // frac 0 = full circle, 1 = empty
  if (ringFill) ringFill.style.strokeDashoffset = RING_C * frac;
}

// ── Hint pulse (stops on first interaction) ───────────────────────
let _hintAlive = true;
let _hintTid   = null;

function _pulseHint() {
  if (!_hintAlive || REDUCED) return;
  hintEl?.classList.add('pulsing');
  setTimeout(() => hintEl?.classList.remove('pulsing'), 1000);
  _hintTid = setTimeout(_pulseHint, 4000);
}

function _killHint() {
  if (!_hintAlive) return;
  _hintAlive = false;
  clearTimeout(_hintTid);
  if (hintEl) {
    hintEl.style.transition = 'opacity 0.5s ease';
    hintEl.style.opacity = '0';
    hintEl.setAttribute('aria-hidden', 'true');
  }
}

hintEl?.addEventListener('mouseenter', _killHint, { once: true });
hintEl?.addEventListener('focus',      _killHint, { once: true });
_hintTid = setTimeout(_pulseHint, 4000);

// ── Button press via Web Animations API ──────────────────────────
function _pressAnim(el) {
  if (REDUCED) return;
  el.animate(
    [{ transform: 'scale(1)' }, { transform: 'scale(0.94)' }],
    { duration: 210, easing: 'cubic-bezier(0.22,1,0.36,1)', fill: 'forwards' }
  ).onfinish = () => {
    el.animate(
      [{ transform: 'scale(0.94)' }, { transform: 'scale(1)' }],
      { duration: 540, easing: 'cubic-bezier(0.2,1.08,0.34,1)' }
    );
  };
}

// ── Dropdown open / close with spring ────────────────────────────
function _openDropdown() {
  dropdown.hidden = false;
  irisBtn.setAttribute('aria-expanded', 'true');
  if (REDUCED || !motionAnimate) {
    dropdown.style.opacity = '1';
    dropdown.style.transform = 'none';
    return;
  }
  motionAnimate(
    dropdown,
    { opacity: [0, 1], transform: ['scale(0.88) translateY(-8px)', 'scale(1) translateY(0px)'] },
    { type: 'spring', stiffness: 150, damping: 20, mass: 1 }
  );
}

function _closeDropdown(then) {
  irisBtn.setAttribute('aria-expanded', 'false');
  if (REDUCED || !motionAnimate) {
    dropdown.hidden = true;
    dropdown.style.opacity = '';
    dropdown.style.transform = '';
    then?.();
    return;
  }
  const anim = motionAnimate(
    dropdown,
    { opacity: [1, 0], transform: ['scale(1) translateY(0px)', 'scale(0.88) translateY(-8px)'] },
    { duration: 0.12, easing: 'ease-in' }
  );
  (anim.finished ?? Promise.resolve()).then(() => {
    dropdown.hidden = true;
    dropdown.style.opacity = '';
    dropdown.style.transform = '';
    then?.();
  });
}

// ── Break overlay ─────────────────────────────────────────────────
function _showBreak() {
  breakOverlay.hidden = false;

  if (REDUCED) {
    breakOverlay.classList.add('iris-active');
    if (brFill) brFill.style.strokeDashoffset = BR_C;
    return;
  }
  requestAnimationFrame(() => breakOverlay.classList.add('iris-active'));

  // Drain the break ring over 4 s (demo-compressed from 20 s)
  if (brFill) {
    if (motionAnimate) {
      motionAnimate(brFill, { strokeDashoffset: [0, BR_C] }, { duration: 4, easing: 'linear' });
    } else {
      brFill.style.transition = 'stroke-dashoffset 4s linear';
      requestAnimationFrame(() => { brFill.style.strokeDashoffset = BR_C; });
    }
  }
}

function _hideBreak(then) {
  breakOverlay.classList.remove('iris-active');
  // Reset the ring immediately (off-screen while fading)
  if (brFill) {
    brFill.style.transition = 'none';
    brFill.style.strokeDashoffset = '0';
    if (motionAnimate) motionAnimate(brFill, { strokeDashoffset: [0, 0] }, { duration: 0 });
  }
  setTimeout(() => {
    breakOverlay.hidden = true;
    then?.();
  }, REDUCED ? 0 : 420);
}

// ── Toast ─────────────────────────────────────────────────────────
function _showToast() {
  toast.classList.add('visible');
  _after(2000, () => toast.classList.remove('visible'));
}

// ── Full reset ────────────────────────────────────────────────────
function _reset() {
  _cancelAll();
  _closeDropdown();
  breakOverlay.classList.remove('iris-active');
  breakOverlay.hidden = true;
  toast.classList.remove('visible');
  countdown.textContent = '20:00';
  if (brFill) { brFill.style.transition = 'none'; brFill.style.strokeDashoffset = '0'; }
  setState('idle');
}

// ── Demo sequence ─────────────────────────────────────────────────
function startDemo() {
  _cancelAll();
  _killHint();

  // Reset UI before starting
  countdown.textContent = '0:04';
  ddTime.textContent = '0:04';
  setRingProgress(0);
  if (brFill) { brFill.style.transition = 'none'; brFill.style.strokeDashoffset = '0'; }
  breakOverlay.classList.remove('iris-active');
  breakOverlay.hidden = true;
  toast.classList.remove('visible');
  dropdown.style.opacity = '';
  dropdown.style.transform = '';

  setState('countdown');
  _pressAnim(irisBtn);
  _openDropdown();

  // t=1000 → 3000: countdown ticks 0:03, 0:02, 0:01
  [3, 2, 1].forEach((n, i) => {
    _after(1000 * (i + 1), () => {
      const label = `0:0${n}`;
      countdown.textContent = label;
      ddTime.textContent = label;
      setRingProgress((3 - n) / 3);
    });
  });

  // t=4000: close dropdown, start break
  _after(4000, () => {
    _closeDropdown(() => {
      countdown.textContent = '20:00';
      setState('breaking');
      _showBreak();
    });
  });

  // t=8000: end break, show toast
  _after(8000, () => {
    _hideBreak(() => {
      setState('toast');
      _showToast();
      setState('idle');
    });
  });
}

// ── Event bindings ────────────────────────────────────────────────
irisBtn?.addEventListener('click', () => {
  if (state === 'idle') { startDemo(); }
  else { _reset(); }
});

irisBtn?.addEventListener('keydown', e => {
  if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); irisBtn.click(); }
});

breakOverlay?.addEventListener('click', () => {
  if (state !== 'breaking') return;
  _cancelAll();
  _hideBreak(() => { _showToast(); setState('idle'); });
});
