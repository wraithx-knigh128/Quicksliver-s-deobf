// Classic (non-module) script: if the module graph never starts, say why instead of showing a dead page.
// The usual cause is opening index.html straight from disk; browsers refuse ES modules and workers on file://.
(function () {
  var notice = function (html) {
    var el = document.getElementById('boot-error');
    if (!el) return;
    el.innerHTML = html;
    el.hidden = false;
  };
  if (location.protocol === 'file:') {
    notice('<h2>This page has to be served over HTTP</h2><p>Browsers do not run ES modules or web workers from <code>file://</code>. From the <code>quicksilver</code> folder run <code>npx serve .</code> (or <code>python3 -m http.server</code>) and open the address it prints. Deployed on Vercel it works as is.</p>');
    return;
  }
  setTimeout(function () {
    if (!window.__qsReady) notice('<h2>QuickSilver did not start</h2><p>The application scripts did not load. Check the browser console for the first error; a content blocker or an outdated browser (ES2022 modules are required) are the usual causes.</p>');
  }, 4000);
})();
