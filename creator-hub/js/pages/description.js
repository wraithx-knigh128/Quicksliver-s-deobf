/* Server Description Generator */
CH.page('description', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon, pick = CH.pick, fresh = CH.fresh, chance = CH.chance;

  var TYPES = {
    gaming: { label: 'Gaming', e: '🎮', topic: 'gamers' }, community: { label: 'Community', e: '💬', topic: 'good people' }, friends: { label: 'Friends', e: '🫶', topic: 'close friends' },
    anime: { label: 'Anime', e: '🌸', topic: 'anime fans' }, creator: { label: 'Creator', e: '🎬', topic: 'creators and their fans' }, education: { label: 'Education', e: '📚', topic: 'curious learners' },
    support: { label: 'Support', e: '🛟', topic: 'people who need a hand' }, professional: { label: 'Professional', e: '💼', topic: 'working professionals' }, marketplace: { label: 'Marketplace', e: '🛒', topic: 'buyers and sellers' }, other: { label: 'Other', e: '✨', topic: 'like-minded people' }
  };
  var VIBES = ['welcoming', 'active', 'chill', 'competitive', 'cozy', 'fun', 'professional', 'supportive', 'creative', 'beginner-friendly'];
  var FEATS = { events: 'events', giveaways: 'giveaways', voice: 'voice hangouts', art: 'art sharing', lfg: 'LFG channels', help: 'help channels', memes: 'memes', bots: 'bots & mini-games', study: 'study sessions', collabs: 'collabs' };
  var TONES = {
    casual: {
      id: ['{name} is a {vibe} home for {topic}.', 'A {vibe} place for {topic} to hang out.', '{topic} welcome — this is {name}.', 'Your corner of Discord for {topic}.', 'Where {topic} meet up: {name}.'],
      vibe: ['Expect {vibes} vibes.', 'We’re {vibes} — and proud of it.', 'Think {vibes}, with zero pressure.'],
      feat: ['We run {features}.', 'You’ll find {features}.', 'Regulars enjoy {features}.'],
      aud: ['Made for {audience}.', 'Open to {audience}.', 'Great for {audience}.'],
      cta: ['Hop in and say hi.', 'Come hang out.', 'Pull up a chair.']
    },
    professional: {
      id: ['{name} is a {vibe} community for {topic}.', 'A {vibe} space for {topic} to learn, share and connect.', '{name} brings together {topic} in a {vibe} environment.'],
      vibe: ['The atmosphere is {vibes}.', 'We value a {vibes} culture.'],
      feat: ['Members enjoy {features}.', 'Our offerings include {features}.'],
      aud: ['Designed for {audience}.', 'Suitable for {audience}.'],
      cta: ['Join us today.', 'New members are welcome.', 'Come and take part.']
    },
    hype: {
      id: ['{name}: the {vibe} spot for {topic}!', '{topic}, assemble! {name} is where it happens.', 'Welcome to {name} — {topic} love it here!'],
      vibe: ['Non-stop {vibes} energy.', '{vibes} to the max.'],
      feat: ['Packed with {features}!', '{features} — all week long.'],
      aud: ['Built for {audience}.', 'Made for {audience}!'],
      cta: ['Jump in!', 'Join the fun!', 'Your seat is waiting.']
    },
    cozy: {
      id: ['{name} is a {vibe} little corner for {topic}.', 'A {vibe}, no-pressure place for {topic}.', 'Grab a drink and settle in — {name} is for {topic}.'],
      vibe: ['Think {vibes}, always.', 'A {vibes} kind of place.'],
      feat: ['We share {features}.', 'Along the way: {features}.'],
      aud: ['Everyone’s welcome, especially {audience}.', 'Made with {audience} in mind.'],
      cta: ['Come sit with us.', 'There’s always room for one more.', 'Say hi — we’ll save you a seat.']
    },
    minimal: {
      id: ['{topic}.', '{name} — {topic}.', 'For {topic}.'], vibe: ['{vibes}.'], feat: ['{features}.'], aud: ['For {audience}.'], cta: ['Join.', 'Come in.']
    }
  };
  var LENGTHS = { short: { max: 120, label: 'Short ≤120' }, medium: { max: 300, label: 'Medium ≤300' }, long: { max: 800, label: 'Long ≤800' } };

  function sc(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; }
  function fill(t, v) { return sc(t.replace(/\{(\w+)\}/g, function (m, k) { return v[k] != null ? v[k] : ''; }).replace(/\s+/g, ' ').replace(/\s+([!?.,—:])/g, '$1').trim()); }

  function build(f) {
    var ty = TYPES[f.type], T = TONES[f.tone], L = LENGTHS[f.length];
    var topic = f.topic.trim().replace(/[.!]+$/, '') || ty.topic;
    var vibes = f.vibes.length ? f.vibes : [], feats = f.feats.map(function (k) { return FEATS[k]; });
    var v = { name: f.name.trim() || 'This server', topic: topic, vibe: vibes[0] || 'friendly', vibes: CH.list(vibes, 3, ' & '), features: CH.list(feats, 4, ' and '), audience: f.audience.trim().replace(/[.!]+$/, '') };
    var segs = [{ k: 'id', pr: 0, t: fill(fresh('desc:id:' + f.tone, T.id), v) }];
    if (vibes.length) segs.push({ k: 'vibe', pr: 2, t: fill(fresh('desc:vibe:' + f.tone, T.vibe), v) });
    if (feats.length) segs.push({ k: 'feat', pr: 1, t: fill(fresh('desc:feat:' + f.tone, T.feat), v) });
    if (v.audience) segs.push({ k: 'aud', pr: 3, t: fill(fresh('desc:aud:' + f.tone, T.aud), v) });
    var cta = f.cta.trim() || fresh('desc:cta:' + f.tone, T.cta);
    segs.push({ k: 'cta', pr: 4, t: sc(cta) });

    if (f.length === 'long' && f.markdown) return longForm(f, ty, segs, v, feats, vibes, cta, L.max);
    // choose a subset in random order of importance, then fit to the limit
    var chosen = segs.slice(), emoji = f.emoji ? ty.e + ' ' : '';
    function text(list) { return emoji + list.map(function (s) { return s.t; }).join(' '); }
    var guard = 0;
    if (f.length === 'short') chosen = chosen.filter(function (s) { return s.k === 'id' || (s.k === 'feat' && chance(.5)) || (s.k === 'cta' && chance(.4)) || (s.k === 'vibe' && chance(.3)); });
    while (text(chosen).length > L.max && chosen.length > 1 && guard++ < 8) {
      var drop = chosen.filter(function (s) { return s.k !== 'id'; }).sort(function (a, b) { return b.pr - a.pr; })[0]; chosen = chosen.filter(function (s) { return s !== drop; });
    }
    var out = text(chosen);
    if (out.length > L.max) { var cut = out.slice(0, L.max - 1), sp = cut.lastIndexOf(' '); out = (sp > L.max * .6 ? cut.slice(0, sp) : cut).replace(/[\s,;:—-]+$/, '') + '…'; }
    return { text: out, label: ty.label + ' · ' + CH.cap(f.tone) + ' · ' + L.label };
  }
  function longForm(f, ty, segs, v, feats, vibes, cta, max) {
    var by = {}; segs.forEach(function (s) { by[s.k] = s; });
    var out = ['## ' + (f.emoji ? ty.e + ' ' : '') + 'Welcome to ' + v.name, '', by.id.t];
    if (by.vibe) out.push(by.vibe.t);
    if (feats.length) { out.push('', '### What you’ll find'); feats.forEach(function (x) { out.push('- ' + sc(x)); }); }
    if (by.aud) out.push('', '### Who it’s for', by.aud.t);
    out.push('', '**' + sc(cta.replace(/[.!]*$/, '')) + '.**');
    var text = out.join('\n');
    var guard = 0; while (text.length > max && out.length > 4 && guard++ < 8) { out.splice(out.length - 3, 1); text = out.join('\n'); }
    return { text: text.slice(0, max), label: ty.label + ' · ' + CH.cap(f.tone) + ' · Long' };
  }

  /* ---------------- UI ---------------- */
  var form = Object.assign({ name: '', type: 'gaming', topic: '', audience: '', vibes: ['welcoming', 'active'], feats: ['events', 'voice'], cta: '', tone: 'casual', length: 'short', emoji: false, markdown: true }, CH.Store.get('form:desc', {}));
  function persist() { CH.Store.set('form:desc', form); }

  root.appendChild(ui.pageHead({ icon: 'text', title: 'Server Description Generator', desc: 'Short blurbs for Discord Discovery, medium ones for listing sites, and long ones for your about channel.' }));
  root.appendChild(ui.callout('info', el('strong', null, 'About limits: '), 'Discord keeps the Community server description short (around 120 characters at the time of writing). Check Server Settings → Overview for the current limit. Medium and long versions are for listing sites, your invite page or an #about channel.'));
  root.appendChild(el('div', { style: { height: '16px' } }));

  function tf(key, label, ph, hint, type) { return ui.field({ label: label, type: type || 'text', value: form[key], placeholder: ph, hint: hint, onInput: function (v) { form[key] = v; persist(); } }); }
  var typeChips = ui.chips({ label: 'Server type', value: form.type, options: Object.keys(TYPES).map(function (k) { return { value: k, label: TYPES[k].label }; }), onChange: function (v) { form.type = v; persist(); } });
  var vibeChips = ui.chips({ label: 'Vibe', multi: true, sm: true, value: form.vibes, options: VIBES, onChange: function (v) { form.vibes = v; persist(); } });
  var featChips = ui.chips({ label: 'What you offer', multi: true, sm: true, value: form.feats, options: Object.keys(FEATS).map(function (k) { return { value: k, label: CH.cap(FEATS[k]) }; }), onChange: function (v) { form.feats = v; persist(); } });
  var toneChips = ui.chips({ label: 'Tone', sm: true, value: form.tone, options: [{ value: 'casual', label: 'Casual' }, { value: 'professional', label: 'Professional' }, { value: 'hype', label: 'Hype' }, { value: 'cozy', label: 'Cozy' }, { value: 'minimal', label: 'Minimal' }], onChange: function (v) { form.tone = v; persist(); } });
  var lenSeg = ui.seg({ label: 'Length', value: form.length, options: Object.keys(LENGTHS).map(function (k) { return { value: k, label: LENGTHS[k].label }; }), onChange: function (v) { form.length = v; persist(); mdSw.el.style.display = v === 'long' ? '' : 'none'; results.set(results.items()); } });
  var emojiSw = ui.switch({ label: 'Use an emoji', checked: form.emoji, onChange: function (v) { form.emoji = v; persist(); } });
  var mdSw = ui.switch({ label: 'Use Discord headings & bullets (long only)', checked: form.markdown, onChange: function (v) { form.markdown = v; persist(); } });
  mdSw.el.style.display = form.length === 'long' ? '' : 'none';

  var formCard = el('div', { class: 'card card-pad tool-form' },
    el('div', { class: 'form-section' }, el('h3', null, 'Your server'), el('div', { class: 'form-grid' }, tf('name', 'Server name', 'Nebula Lounge').el, el('div')), el('div', { class: 'field' }, el('div', { class: 'label' }, 'Type'), typeChips.el),
      tf('topic', 'Who or what is it for?', 'ranked Valorant players', 'A short noun phrase — it’s dropped into sentences like “A chill home for …”.').el,
      tf('audience', 'Audience (optional)', 'beginners and returning players', 'Also a noun phrase.').el),
    el('div', { class: 'form-section' }, el('h3', null, 'Personality'), el('div', { class: 'field' }, el('div', { class: 'label' }, 'Vibe'), vibeChips.el), el('div', { class: 'field' }, el('div', { class: 'label' }, 'What you offer'), featChips.el),
      tf('cta', 'Call to action (optional)', 'Come say hi!').el),
    el('div', { class: 'form-section' }, el('h3', null, 'Voice & length'), el('div', { class: 'field' }, el('div', { class: 'label' }, 'Tone'), toneChips.el), lenSeg.el, emojiSw.el, mdSw.el),
    el('div', { class: 'sticky-actions' }, ui.btn('Generate descriptions', { kind: 'primary', icon: 'sparkle', onclick: run })));

  var results = ui.results({
    type: 'description', label: null, limit: null, titleOf: function (it) { return it.text.replace(/[#*\n]+/g, ' ').trim(); },
    regen: function () { return build(form); },
    metaOf: function (it) { var max = LENGTHS[form.length].max, n = it.text.length; return [el('span', { class: 'counter ' + (n > max ? 'bad' : n > max * .93 ? 'warn' : '') }, n + '/' + max + ' chars')]; }
  });
  root.appendChild(el('div', { class: 'tool-layout' }, formCard, el('div', { class: 'card card-pad' }, el('div', { class: 'results-head' }, el('h2', null, 'Your descriptions'), ui.btn('Generate again', { icon: 'refresh', sm: true, onclick: run })), results.el)));

  function run() {
    var out = [], seen = {}, tries = 0;
    while (out.length < 5 && tries++ < 40) { var b = build(form); if (!seen[b.text]) { seen[b.text] = 1; out.push(b); } }
    results.set(out);
  }
  run();
});
