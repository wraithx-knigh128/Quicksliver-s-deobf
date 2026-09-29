const $ = (id) => document.getElementById(id);
const input = $('u'), btn = $('go'), chainEl = $('chain'), summaryEl = $('summary'), bannerEl = $('banner');

function esc(s) { return String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
function codeClass(s) { if (!s) return ''; return 'code' + String(s)[0]; }

async function resolve() {
  const url = input.value.trim();
  if (!url) return;
  btn.disabled = true; btn.textContent = 'Resolving…';
  chainEl.innerHTML = ''; summaryEl.style.display = 'none'; bannerEl.innerHTML = '';
  try {
    const r = await fetch('/api/resolve', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url })
    });
    const data = await r.json();
    if (!r.ok) { render_error(data.error || ('HTTP ' + r.status)); return; }
    render(data);
  } catch (e) {
    render_error('Request failed: ' + e.message);
  } finally {
    btn.disabled = false; btn.textContent = 'Resolve';
  }
}

function render_error(msg) {
  bannerEl.innerHTML = '<div class="banner stopped">' + esc(msg) + '</div>';
}

function render(d) {
  // summary
  const statusPill = d.completed
    ? '<span class="status-pill ok">Reached final URL</span>'
    : '<span class="status-pill stopped">Stopped early</span>';
  summaryEl.style.display = 'flex';
  summaryEl.innerHTML =
    '<div class="kv"><span>Result</span><b>' + statusPill + '</b></div>' +
    '<div class="kv"><span>Hops</span><b>' + d.hopCount + '</b></div>' +
    '<div class="kv" style="flex:1"><span>Final URL</span><b>' + esc(d.finalUrl) + '</b></div>';

  if (d.stopReason) {
    bannerEl.innerHTML = '<div class="banner stopped">' + esc(d.stopReason) + '</div>';
  } else if (d.completed) {
    bannerEl.innerHTML = '<div class="banner ok">Redirect chain fully resolved to the final URL.</div>';
  }

  // chain
  chainEl.innerHTML = d.hops.map((h, i) => {
    let meta = [];
    if (h.status) meta.push('<span class="' + codeClass(h.status) + '">' + h.status + (h.statusMessage ? ' ' + esc(h.statusMessage) : '') + '</span>');
    if (h.ip) meta.push('IP ' + esc(h.ip));
    if (h.server) meta.push('server: ' + esc(h.server));
    if (h.contentType) meta.push(esc(h.contentType.split(';')[0]));
    if (h.setCookie) meta.push(h.setCookie + ' cookie(s) set');
    if (typeof h.elapsedMs === 'number') meta.push(h.elapsedMs + ' ms');
    if (h.location) meta.push('→ ' + esc(h.location));

    let flagsHtml = '';
    if (h.flags && h.flags.length) {
      flagsHtml = '<div class="flags">' + h.flags.map(f =>
        '<div class="flag ' + esc(f.type) + '"><span class="t">⚠ ' + esc(f.label) + '</span>' +
        (f.target ? ' <span class="tgt">' + esc(f.target) + '</span>' : '') +
        ' — requires user action; not automated</div>'
      ).join('') + '</div>';
    }
    const errHtml = h.error ? '<div class="err">✕ ' + esc(h.error) + '</div>' : '';

    return '<li>' +
      '<div class="hopnum">' + (i + 1) + '</div>' +
      '<div class="hopurl">' + esc(h.url) + '</div>' +
      (meta.length ? '<div class="hopmeta">' + meta.map(m => '<span>' + m + '</span>').join('') + '</div>' : '') +
      flagsHtml + errHtml +
    '</li>';
  }).join('');
}

btn.addEventListener('click', resolve);
input.addEventListener('keydown', (e) => { if (e.key === 'Enter') resolve(); });
