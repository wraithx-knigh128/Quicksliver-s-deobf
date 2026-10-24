// Runs before the stylesheet paints so the page never flashes the wrong theme. Classic script on purpose
// (the strict CSP forbids inline scripts; modules load too late for this).
(function () {
  var saved = '';
  try { saved = localStorage.getItem('qs.theme') || ''; } catch (e) { /* storage blocked: follow the system */ }
  var light = saved === 'light' || (saved !== 'dark' && window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches);
  document.documentElement.setAttribute('data-theme', light ? 'light' : 'dark');
})();
