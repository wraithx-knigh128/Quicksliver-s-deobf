// The two screens of QuickSilver v1.8: the landing screen and the workspace. Switching is a class on <html> (css/scene.css): the landing
// fades out, the scene behind it stops moving and dims, the workspace is shown. `data-go` buttons (landing and title bar) name a section:
//   work → the deobfuscator, vm → the VM Reverser, loader → Loader & GitHub, compat → the obfuscator list.
// main.js listens for `qs:go` and opens the tab; this file has no other job and no animation loop.

const root = document.documentElement;
const remember = () => { try { localStorage.setItem('qs.entered', '1'); } catch { /* storage blocked */ } };

export function enter(section = 'work') {
  root.classList.add('in-work');
  remember();
  document.dispatchEvent(new CustomEvent('qs:go', { detail: { section } }));
  const landing = document.getElementById('landing');
  if (landing) landing.setAttribute('aria-hidden', 'true');
}

export function showLanding() {
  root.classList.remove('in-work');
  const landing = document.getElementById('landing');
  if (landing) { landing.removeAttribute('aria-hidden'); const first = landing.querySelector('.btn-hero.primary'); if (first) first.focus({ preventScroll: true }); }
}

document.addEventListener('click', (e) => {
  const go = e.target.closest('[data-go]');
  if (go) { e.preventDefault(); enter(go.dataset.go); return; }
  if (e.target.closest('#brand')) { e.preventDefault(); showLanding(); }
});
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !root.classList.contains('in-work') && !document.querySelector('.modal-back')) enter('work');
});
if (root.classList.contains('in-work')) document.getElementById('landing')?.setAttribute('aria-hidden', 'true');
// a link straight to a section (#vm, #loader) opens it once the workspace is ready
const hash = location.hash.slice(1);
if (['work', 'vm', 'loader'].includes(hash)) window.addEventListener('load', () => document.dispatchEvent(new CustomEvent('qs:go', { detail: { section: hash } })), { once: true });
