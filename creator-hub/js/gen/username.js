/* CordX — username engine (shared by the Username Generator page and the home-page prompt). */
(function () {
  'use strict';
  var CH = window.CH, pick = CH.pick, chance = CH.chance, range = CH.range;

  var KINDS = [
    { id: 'gamer', label: 'Gamer', ex: 'VoidRush · NightVex' }, { id: 'discord', label: 'Discord', ex: 'pixel_orbit · moon.drift' },
    { id: 'clean', label: 'Clean', ex: 'Nova · Veyro · Aeris' }, { id: 'og', label: 'OG-style', ex: 'kai · zed · vox' },
    { id: 'short', label: 'Short', ex: 'Ryn · Kex · Zyl' }, { id: 'competitive', label: 'Competitive', ex: 'AceTempo · FlickPrime' },
    { id: 'funny', label: 'Funny', ex: 'SirToast · LagGoblin' }, { id: 'dark', label: 'Dark', ex: 'HollowReign · GrimVeil' },
    { id: 'mysterious', label: 'Mysterious', ex: 'Cipher · quiet_signal' }, { id: 'anime', label: 'Anime', ex: 'Kazuro · Tsukiyo' },
    { id: 'developer', label: 'Developer', ex: 'NullByte · CodeVanta' }, { id: 'creator', label: 'Creator', ex: 'FrameAtelier · InkWave' },
    { id: 'minimal', label: 'Minimal', ex: 'ash · onyx · mono' }, { id: 'aesthetic', label: 'Aesthetic', ex: 'velvet.moon · dewdrop' },
    { id: 'random', label: 'Random', ex: 'surprise me' }, { id: 'custom', label: 'Custom', ex: 'built from your words' }
  ];
  var KIND_BY = {}; KINDS.forEach(function (k) { KIND_BY[k.id] = k; });
  var RANDOM_POOL = KINDS.map(function (k) { return k.id; }).filter(function (k) { return k !== 'random' && k !== 'custom'; });

  var W = function (s) { return s.split(' '); };
  var THEME = {
    space: W('nova orbit comet nebula pulsar quasar astro cosmo lunar solar vector zenith apex eclipse stellar vega lyra orion helix photon void aether'),
    fire: W('ember blaze cinder ash inferno flare pyro scorch magma kindle phoenix spark char'),
    ice: W('frost glacier rime sleet boreal crystal tundra floe shiver snow hail polar'),
    nature: W('fern moss willow cedar thorn river grove petal wild meadow ivy bloom oak canyon'),
    mythic: W('rune oracle wyrm titan aegis myth saga valkyr sphinx hydra atlas nyx odin relic'),
    cyber: W('neon glitch pixel vector circuit byte synth chrome ion proxy nano cyber volt grid'),
    ocean: W('tide reef abyss coral kraken marlin drift current brine wave pearl tidal lagoon'),
    shadow: W('shade umbra noct gloom raven wraith ghost hollow dusk veil phantom shroud night'),
    royal: W('crown regal sovereign noble duke lance throne sigil aurum ivory crest herald'),
    retro: W('vhs arcade joystick cassette disco boombox tape synth pong neon vinyl retro pixel')
  };
  var POOLS = {
    gamerA: W('void night toxic rapid iron nitro ghost hyper neon frost rogue apex savage turbo omega blitz venom crimson storm zero shadow chaos rift lunar solar feral vivid sonic cobalt razor lethal'),
    gamerB: W('rush vex strike fang clutch reaper blade viper wolf hawk forge rage surge snipe rift hunter shot drift slayer fury pulse breaker raid knight edge talon storm jinx wraith'),
    compA: W('ace prime tactical clutch elite apex flick tempo zone peek sharp cold clean calm rapid swift ultra max lock'),
    compB: W('tempo prime edge flick zone peek aim ace lock core push rotate angle cap line hold trade entry'),
    darkA: W('hollow grim shade raven wraith gloom nether crypt abyss ashen bleak dread void sable obsidian cursed omen eclipse'),
    darkB: W('reign veil reaper whisper shroud thorn crow fang soul grave moon ash sorrow howl bane hex'),
    mystA: W('cipher enigma lacuna vesper sable arcane umbra whisper wisp echo nameless unknown quiet silent lost hidden faint'),
    mystB: W('signal veil door key static tide hour thread mirror letter room shore code ghost'),
    mystSolo: W('cipher enigma lacuna vesper umbra arcana noctis aether sable wisp lumen solace'),
    devA: W('null void stack heap git bit byte hash root sudo async regex kernel proxy bash cache lambda token vector daemon pixel cron socket rust node code dev hex bin sys cmd'),
    devB: W('byte ptr flow forge vault stack loop shell node patch build commit compile trace crash fault pipe port fork hook vanta mancer wright smith ninja wizard monk'),
    devFun: W('segfault stackoverflow nullpointer off_by_one found_404 git_blame ctrl_alt_defeat sudo_sandwich tab_enjoyer merge_conflict infinite_loop'),
    creA: W('studio craft frame pixel canvas motion lens reel ink tone hue draft muse loop sketch prism grain'),
    creB: W('works lab atelier forge co wave house collective crate bloom room club'),
    funX: W('toast lag noodle sock pickle waffle potato cheese bagel meme nap snack tax cactus pigeon spoon crouton gravy llama crumb bean'),
    funT: ['sir{x}', 'captain{x}', '{x}enjoyer', 'not{x}', 'professional{x}', '{x}lord', '{x}goblin', '{x}merchant', '{x}bandit', 'mc{x}', 'lord{x}', '{x}wizard', 'just{x}', '{x}gremlin', '{x}dealer', 'definitely{x}'],
    funFix: W('ctrl_alt_delight error_not_found buffering lagging_legend low_battery please_hold tab_enjoyer reply_later send_snacks'),
    aesA: W('velvet pastel moonmilk lilac dewdrop honeyed lavender petal starlit sunbeam opal haze soft cloud bloom amber dawn muse whisper sorbet pearl'),
    aesB: W('moon bloom haze light dream glow tide sky rain dusk honey mist'),
    ogWords: W('kai zed vox lux ash rue onyx jade fox ivy ray sol ion eon ryn kit nox ayo zen oak orb tau fen hex jin kip lei max neo opal pax quill rex sky tux umi vee wren xen yew zap dax eli ezra finn gus hugo ike jax kade levi milo nico omar pike rhys sage tate uri vale wyatt xan yuri zane aero arc blip cove dew elm flux glen haze isle jolt knot lark mint nook onyx pico quip rook silk tide vibe wisp'),
    minWords: W('ash orb hue mono onyx vale lumen echo flux mist pine slate dune moss reed salt iris halo ore'),
    jpSyl: W('ka ki ku ke ko sa shi su se so ta chi tsu te to na ni nu ne no ha hi fu he ho ma mi mu me mo ya yu yo ra ri ru re ro wa'),
    jpWords: W('kage sora tsuki kitsune ryu neko hoshi yami kaze mizu hikari ronin ken rei yuki hana kurai aoi aka'),
    jpEnd: W('mi ra ki ro ya ko ta zu no ren')
  };
  var BLOCK = /nig|fag|rape|nazi|hitler|porn|cum|dick|cock|slut|whore|cunt|shit|fuck|kkk|tits|anal|sex|pedo|molest|retard|bitch|penis|vagina/;
  var recent = [];

  function cap(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; }
  function pron(s) { return s.length >= 2 && /[aeiouy]/.test(s) && !/[^aeiouy]{4}/.test(s) && !/[aeiouy]{4}/.test(s) && !/(.)\1\1/.test(s) && !/(q[^u]|[bcdfghjklmnpqrstvwxz]x|jj|vv|ww|zz.|yy|kq|wq)/.test(s); }
  function patternWord(pat, C, V) { return pat.split('').map(function (ch) { return ch === 'C' ? pick(C) : ch === 'V' ? pick(V) : ch; }).join(''); }

  var SHORT_C = W('k z x v r n m l d t j y s b f h p'), SHORT_V = W('a e i o u y a e o');
  var ONS2 = W('br cr dr fr gr kr pr tr bl cl fl gl pl sl sk sn sp st sw tw th sh ch wr');
  var CODA1 = W('n r x l m s t k d z p'), CODA_S = W('n x l m r s k z n x'), CODA2 = W('nk nd st rk rn lt lk ld mp ft ct nt sk');
  var CL_FIRST = W('no ve ae ly ka ze ri so mi ta el ar ky ne va lu xe or an ia ai se ro li ma vi');
  var CL_MID = ['v', 'r', 'l', 'n', 's', 'm', 'k', 'z', 'd', 'th', 'x', 'y', '', '', 'l', 'r'];
  var CL_END = W('a o e is os ix yn en ia ar el on ys ae us ex ira ora ena aia');
  function inventClean() {
    for (var i = 0; i < 80; i++) {
      var w = pick(CL_FIRST) + pick(CL_MID) + pick(CL_END);
      if (pron(w) && w.length >= 4 && w.length <= 7 && !/(.)\1/.test(w)) return w;
    }
    return 'nova';
  }
  function inventShort(og) {
    for (var i = 0; i < 80; i++) {
      var ons = chance(.05) ? pick(ONS2) : (chance(.15) ? '' : pick(og ? W('b c d f g h j k l m n p r s t v w z') : SHORT_C));
      var v = pick(og ? W('a e i o u') : SHORT_V);
      var cod = chance(.04) ? pick(CODA2) : (chance(.22) ? '' : pick(og ? W('n r x l m s t k d z') : CODA_S));
      var w = ons + v + cod;
      if (pron(w) && w.length >= 3 && w.length <= 5) return w;
    }
    return og ? 'kai' : 'ryn';
  }
  function inventAnime() {
    if (chance(.3)) return pick(POOLS.jpWords) + (chance(.6) ? pick(POOLS.jpEnd) : '');
    var n = range(2, 3), s = ''; for (var i = 0; i < n; i++) s += pick(POOLS.jpSyl); return s;
  }

  /* user stems → pronounceable forms */
  function cleanStem(s) { return String(s || '').normalize ? String(s).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]/g, '') : String(s).toLowerCase().replace(/[^a-z0-9]/g, ''); }
  function soften(stem, short) {
    var base = stem.length > 6 ? stem.slice(0, CH.range(4, 5)) : stem, maxL = short ? 5 : 8, minL = short ? 3 : 4, cands = [];
    if (base.length >= minL && base.length <= maxL && pron(base)) cands.push(base, base);
    var vowelEnd = /[aeiouy]$/.test(base);
    var ends = vowelEnd ? ['n', 'r', 'x', 'l', 's'] : (short ? ['a', 'o', 'e', 'y'] : ['a', 'o', 'e', 'ia', 'is', 'en', 'ix', 'yn', 'ar', 'el', 'on', 'us']);
    for (var i = 0; i < 6; i++) cands.push(base + pick(ends));
    if (!vowelEnd) cands.push(base.slice(0, -1) + pick(['a', 'o', 'ia']));
    cands = cands.filter(function (w) { return pron(w) && w.length >= minL && w.length <= maxL; });
    return cands.length ? pick(cands) : base.slice(0, maxL);
  }
  function trimVowels(s) { var t = s.charAt(0) + s.slice(1).replace(/[aeiou]/g, ''); return t.length >= 3 ? t : s; }
  function mutateStem(s) {
    var m = [function (x) { return x; }, function (x) { return x; }, trimVowels, function (x) { return x + pick(['x', 'z', 'ix', 'yn', 'is', 'on', 'ar', 'el', 'io']); }, function (x) { return x.length <= 4 ? pick(['x', 'z', 'v', 'k']) + x : x; },
      function (x) { return x.slice(0, Math.max(3, Math.min(5, x.length))); }];
    return pick(m)(s);
  }
  function blend(a, b) {
    for (var i = 0; i < 12; i++) { var w = a.slice(0, range(2, Math.max(2, Math.min(4, a.length)))) + b.slice(range(1, Math.max(1, Math.min(3, b.length - 1)))); if (pron(w) && w.length >= 4 && w.length <= 9) return w; }
    return a;
  }

  /* ---------------- generators ---------------- */
  function compound(c, A, B, form) {
    var a = pick(A), b = pick(B);
    if (c.themeWords.length && chance(.45)) { if (chance(.5)) a = pick(c.themeWords); else b = pick(c.themeWords); }
    if (c.stems.length && chance(c.stemP)) { var st = mutateStem(pick(c.stems)); if (chance(.5)) a = st; else b = st; }
    if (a === b) b = pick(B);
    return { parts: [a, b], form: form };
  }
  function singleWithStem(c, base, short) {
    if (c.stems.length && chance(c.stemP)) { var st = pick(c.stems); return short ? soften(st, true) : (c.themeWords.length && chance(.4) ? blend(st, pick(c.themeWords)) : soften(st, false)); }
    if (c.themeWords.length && chance(.35)) return soften(pick(c.themeWords), short);
    return base();
  }
  var GEN = {
    gamer: function (c) { return compound(c, POOLS.gamerA, POOLS.gamerB, 'pascal'); },
    competitive: function (c) { return compound(c, POOLS.compA, POOLS.compB, 'pascal'); },
    dark: function (c) { return compound(c, POOLS.darkA, POOLS.darkB, 'pascal'); },
    mysterious: function (c) {
      if (chance(.35)) return { parts: [singleWithStem(c, function () { return pick(POOLS.mystSolo); }, false)], form: 'title' };
      return compound(c, POOLS.mystA, POOLS.mystB, chance(.5) ? 'snake' : 'pascal');
    },
    developer: function (c) {
      if (chance(.18) && !c.stems.length) return { parts: pick(POOLS.devFun).split('_'), form: 'snake' };
      var r = compound(c, POOLS.devA, POOLS.devB, pick(['pascal', 'pascal', 'camel', 'snake'])); return r;
    },
    creator: function (c) { return compound(c, POOLS.creA, POOLS.creB, pick(['pascal', 'pascal', 'lower'])); },
    funny: function (c) {
      if (chance(.2) && !c.stems.length) return { parts: pick(POOLS.funFix).split('_'), form: 'snake' };
      var x = c.stems.length && chance(c.stemP) ? mutateStem(pick(c.stems)) : (c.themeWords.length && chance(.3) ? pick(c.themeWords) : pick(POOLS.funX));
      var t = pick(POOLS.funT), m = /^(.*)\{x\}(.*)$/.exec(t); return { parts: [m[1], x, m[2]].filter(Boolean), form: 'pascal' };
    },
    aesthetic: function (c) {
      var r = compound(c, POOLS.aesA, POOLS.aesB, 'lower'); if (chance(.5)) r.sep = pick(['.', '_', '']); return r;
    },
    discord: function (c) {
      var A = POOLS.gamerA.concat(POOLS.aesA, POOLS.mystA, POOLS.creA), B = POOLS.aesB.concat(POOLS.mystB, POOLS.devB.slice(0, 8), POOLS.creB.slice(0, 6));
      var r = compound(c, A, B, 'lower'); r.sep = pick(['_', '.', '_']); return r;
    },
    clean: function (c) { return { parts: [singleWithStem(c, inventClean, false)], form: 'title' }; },
    og: function (c) { return { parts: [c.stems.length && chance(c.stemP) ? soften(pick(c.stems), true) : (chance(.6) ? pick(POOLS.ogWords) : inventShort(true))], form: 'lower', noNumber: true }; },
    short: function (c) { return { parts: [singleWithStem(c, function () { return inventShort(false); }, true)], form: 'title' }; },
    minimal: function (c) { return { parts: [c.stems.length && chance(c.stemP) ? soften(pick(c.stems), true) : (chance(.65) ? pick(POOLS.minWords) : inventShort(false))], form: 'lower' }; },
    anime: function (c) {
      if (c.stems.length && chance(c.stemP)) { var s = pick(c.stems); return { parts: [blend(s, inventAnime())], form: 'title' }; }
      return { parts: [inventAnime()], form: 'title' };
    },
    custom: function (c) {
      var all = c.stems.concat(c.themeWords); if (!all.length) return GEN[pick(RANDOM_POOL)](c);
      var s = c.stems.length ? pick(c.stems) : pick(c.themeWords), t = c.themeWords.length ? pick(c.themeWords) : pick(POOLS.gamerA.concat(POOLS.aesA, POOLS.mystA));
      var forms = [
        function () { return { parts: [s, t], form: 'pascal' }; }, function () { return { parts: [t, s], form: 'pascal' }; },
        function () { return { parts: [mutateStem(s)], form: 'title' }; }, function () { return { parts: [pick(POOLS.gamerA.concat(POOLS.darkA, POOLS.aesA)), s], form: 'pascal' }; },
        function () { return { parts: [s, pick(POOLS.gamerB.concat(POOLS.darkB, POOLS.aesB, POOLS.devB.slice(0, 10)))], form: 'pascal' }; },
        function () { return { parts: [soften(s, false)], form: 'title' }; }, function () { return { parts: [s, pick(['official', 'real', 'hq', 'tv', 'plays', 'x'])], form: chance(.5) ? 'snake' : 'pascal' }; }
      ];
      return pick(forms)();
    }
  };

  /* ---------------- formatting ---------------- */
  var LEET = { a: '4', e: '3', i: '1', o: '0', s: '5', t: '7' };
  var DECOR = [['✦ ', ' ✦'], ['꒰ ', ' ꒱'], ['˚₊ ', ' ₊˚'], ['「', '」'], ['★ ', ' ★'], ['⟡ ', ' ⟡'], ['⛧ ', ' ⛧'], ['« ', ' »']];
  function format(r, c) {
    var form = c.caseMode === 'auto' ? r.form : c.caseMode, parts = r.parts.slice();
    var sep = form === 'snake' ? '_' : form === 'dot' ? '.' : (r.sep != null ? r.sep : '');
    if (!sep && parts.length > 1 && c.seps.length && chance(.55)) sep = pick(c.seps);
    var d;
    if (form === 'pascal') d = parts.map(cap).join(sep);
    else if (form === 'camel') d = parts.map(function (p, i) { return i ? cap(p) : p; }).join(sep);
    else if (form === 'title') d = cap(parts.join(sep));
    else d = parts.join(sep).toLowerCase();
    // numbers
    var num = '';
    if (c.numMode !== 'none' && !r.noNumber) {
      var add = c.numMode === 'always' || (c.numMode === 'auto' && c.numbers.length && chance(.55)) || (c.numMode === 'auto' && !c.numbers.length && /gamer|competitive|discord|dark|funny/.test(c.kind) && chance(.18));
      if (add) num = c.numbers.length ? pick(c.numbers) : String(range(1, 99));
    }
    if (c.numMode === 'leet' && parts.length > 1) {
      var chars = d.split(''), swaps = 0; for (var i = 1; i < chars.length; i++) { var l = LEET[chars[i].toLowerCase()]; if (l && swaps < Math.ceil(chars.length / 3) && chance(.45)) { chars[i] = l; swaps++; } } d = chars.join('');
    }
    if (num) d += (sep && form !== 'pascal' && form !== 'title' ? sep : '') + num;
    var handle = d.toLowerCase().replace(/[^a-z0-9_.]/g, '').replace(/\.{2,}/g, '.');
    var display = d;
    if (!c.valid) { var dec = c.decor && chance(.7) ? pick(DECOR) : null; if (c.chars.length && chance(.5)) { var ch = pick(c.chars); dec = [ch + ' ', ' ' + ch]; } if (dec) display = dec[0] + d + dec[1]; }
    return { handle: handle, display: display, kind: c.kind };
  }
  function check(h) {
    if (h.length < 2 || h.length > 32) return 'Handles must be 2–32 characters.';
    if (!/^[a-z0-9_.]+$/.test(h)) return 'Only a–z, 0–9, underscores and periods are allowed.';
    if (/\.\./.test(h)) return 'No two periods in a row.';
    if (/^(everyone|here)$/.test(h) || /discord|clyde/.test(h)) return 'Contains a word Discord reserves.';
    return '';
  }

  function generate(form, count) {
    var kindSel = form.kind, themeWords = form.theme && THEME[form.theme] ? THEME[form.theme] : [];
    var stemSrc = [form.name, form.nickname, form.word].concat(CH.csv(form.interests).map(function (x) { return x.split(/\s+/); }).reduce(function (a, b) { return a.concat(b); }, []));
    var stems = stemSrc.map(cleanStem).filter(function (s) { return s.length >= 2 && s.length <= 14 && !/^\d+$/.test(s); });
    var chars = Array.from(String(form.chars || '').replace(/\s+/g, ''));
    var seps = chars.filter(function (x) { return x === '_' || x === '.'; });
    var base = { stems: stems, themeWords: themeWords, stemP: kindSel === 'custom' ? .9 : (stems.length ? .55 : 0), numbers: CH.csv(form.numbers).map(function (n) { return n.replace(/[^0-9a-z]/gi, ''); }).filter(Boolean), numMode: form.numMode, seps: form.valid ? seps : chars.filter(function (x) { return !/[a-z0-9]/i.test(x); }).slice(0, 4), chars: form.valid ? [] : chars.filter(function (x) { return !/[a-z0-9_.]/i.test(x); }), caseMode: form.caseMode, valid: form.valid, decor: form.decor };
    var out = [], seen = {}, tries = 0, min = form.min, max = form.max, relax = 0;
    while (out.length < count && tries < count * 90) {
      tries++; if (tries > count * 45) relax = 1;
      var kind = kindSel === 'random' ? pick(RANDOM_POOL) : kindSel;
      var c = Object.assign({ kind: kind }, base);
      var r = GEN[kind](c), f = format(r, c);
      var key = f.handle; if (!key || seen[key] || recent.indexOf(key) >= 0 || BLOCK.test(key)) continue;
      if (form.valid && check(key)) continue;
      var len = (form.valid ? f.handle : f.display).length;
      if (!relax && (len < min || len > max)) continue; if (relax && (len < 2 || len > 32)) continue;
      seen[key] = 1; out.push({ text: form.valid ? f.handle : f.display, label: kindSel === 'random' ? KIND_BY[kind].label : null, data: { handle: f.handle, display: f.display, kind: kind } });
    }
    out.forEach(function (o) { recent.push(o.data.handle); }); if (recent.length > 80) recent.splice(0, recent.length - 80);
    return out;
  }


  CH.usernameGen = { KINDS: KINDS, KIND_BY: KIND_BY, THEME: THEME, RANDOM_POOL: RANDOM_POOL, generate: generate, check: check };
})();
