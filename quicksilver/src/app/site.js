// Which screen is shown: the one-page Deobfuscate site (the default) or the expert workbench (html.in-work, css/site.css). Prompt XXVIII made
// the Deobfuscate page the product; the workbench with every individual tool is one quiet link away. The choice lasts for this tab only
// (sessionStorage), so a new visit always starts on Deobfuscate. `data-expert` buttons name a workbench section; main.js opens its tab on
// `qs:go`. This file has no other job and no animation loop.

const root = document.documentElement;
const keep = (on) => { try { if (on) sessionStorage.setItem('qs.expert', '1'); else sessionStorage.removeItem('qs.expert'); } catch { /* storage blocked */ } };

export function enterExpert(section = 'work') {
  root.classList.add('in-work');
  keep(true);
  document.dispatchEvent(new CustomEvent('qs:go', { detail: { section } }));
  window.scrollTo(0, 0);
}

export function showSite() {
  root.classList.remove('in-work');
  keep(false);
  document.dispatchEvent(new CustomEvent('qs:site'));
  const run = document.getElementById('deob-run');
  if (run) run.focus({ preventScroll: true });
}

document.addEventListener('click', (e) => {
  const go = e.target.closest('[data-expert]');
  if (go) { e.preventDefault(); enterExpert(go.dataset.expert); return; }
  if (e.target.closest('#back-site') || e.target.closest('#brand')) { e.preventDefault(); showSite(); }
});
// a link straight to a workbench section (#work, #vm, #loader, ?tab=…) opens it once the workbench is ready
const hash = location.hash.slice(1);
if (['work', 'vm', 'loader', 'expert'].includes(hash)) window.addEventListener('load', () => document.dispatchEvent(new CustomEvent('qs:go', { detail: { section: hash === 'expert' ? 'work' : hash } })), { once: true });
