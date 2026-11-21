// Runs before the stylesheet paints so the page never flashes the wrong theme. Classic script on purpose
// (the strict CSP forbids inline scripts; modules load too late for this).
(function () {
  var saved = '';
  try { saved = localStorage.getItem('qs.theme') || ''; } catch (e) { /* storage blocked: follow the system */ }
  // v1.8: the sunset identity is a dark design, so dark is the default; a person who chose light keeps it (the theme button stores the choice)
  var light = saved === 'light';
  document.documentElement.setAttribute('data-theme', light ? 'light' : 'dark');
})();

// Prompt XXVIII: which screen opens first. The one-page Deobfuscate site is the default; the expert workbench opens first only when this tab
// was last in it (sessionStorage, set by src/app/site.js) or the address names a workbench tab (?tab=… or #work / #vm / #loader / #expert) —
// decided here, before the first paint, so the wrong screen never flashes.
(function () {
  var expert = '';
  try { expert = sessionStorage.getItem('qs.expert') || ''; } catch (e) { /* storage blocked: the site */ }
  var direct = /[?&]tab=/.test(location.search) || /^#(work|vm|loader|expert)$/.test(location.hash);
  if (expert === '1' || direct) document.documentElement.classList.add('in-work');
})();
