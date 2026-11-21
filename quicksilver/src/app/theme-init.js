// Runs before the stylesheet paints so the page never flashes the wrong theme. Classic script on purpose
// (the strict CSP forbids inline scripts; modules load too late for this).
(function () {
  var saved = '';
  try { saved = localStorage.getItem('qs.theme') || ''; } catch (e) { /* storage blocked: follow the system */ }
  // v1.8: the sunset identity is a dark design, so dark is the default; a person who chose light keeps it (the theme button stores the choice)
  var light = saved === 'light';
  document.documentElement.setAttribute('data-theme', light ? 'light' : 'dark');
})();

// Prompt XXVII: which screen opens first. The landing screen greets a first visit; someone who has entered the workspace before, or who came
// with a link to a tab (?tab=… or #work), goes straight to the workspace — decided here, before the first paint, so the landing never flashes.
(function () {
  var entered = '';
  try { entered = localStorage.getItem('qs.entered') || ''; } catch (e) { /* storage blocked: show the landing */ }
  var direct = /[?&]tab=/.test(location.search) || /^#(work|vm|loader)$/.test(location.hash);
  if (entered === '1' || direct) document.documentElement.classList.add('in-work');
})();
