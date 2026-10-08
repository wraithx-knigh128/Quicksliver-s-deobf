/* Bio Generator — segment-based composer (not a fixed sentence list), so results vary in shape as well as wording. */
CH.page('bio', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon, pick = CH.pick, fresh = CH.fresh, chance = CH.chance;
  var HARD = 190; // Discord "About Me" limit

  /* ---------------- Unicode text styles ---------------- */
  var U = (function () {
    function range(upper, lower, digits, ex) {
      return function (ch) {
        var c = ch.codePointAt(0);
        if (ex && ex[ch]) return ex[ch];
        if (c >= 65 && c <= 90 && upper) return String.fromCodePoint(upper + c - 65);
        if (c >= 97 && c <= 122 && lower) return String.fromCodePoint(lower + c - 97);
        if (c >= 48 && c <= 57 && digits) return String.fromCodePoint(digits + c - 48);
        return ch;
      };
    }
    var script = { B: 'ℬ', E: 'ℰ', F: 'ℱ', H: 'ℋ', I: 'ℐ', L: 'ℒ', M: 'ℳ', R: 'ℛ', e: 'ℯ', g: 'ℊ', o: 'ℴ' };
    var frak = { C: 'ℭ', H: 'ℌ', I: 'ℑ', R: 'ℜ', Z: 'ℨ' };
    var dbl = { C: 'ℂ', H: 'ℍ', N: 'ℕ', P: 'ℙ', Q: 'ℚ', R: 'ℝ', Z: 'ℤ' };
    var ital = { h: 'ℎ' };
    var small = { a: 'ᴀ', b: 'ʙ', c: 'ᴄ', d: 'ᴅ', e: 'ᴇ', f: 'ꜰ', g: 'ɢ', h: 'ʜ', i: 'ɪ', j: 'ᴊ', k: 'ᴋ', l: 'ʟ', m: 'ᴍ', n: 'ɴ', o: 'ᴏ', p: 'ᴘ', q: 'ǫ', r: 'ʀ', s: 'ꜱ', t: 'ᴛ', u: 'ᴜ', v: 'ᴠ', w: 'ᴡ', x: 'x', y: 'ʏ', z: 'ᴢ' };
    var circ = function (ch) {
      var c = ch.codePointAt(0);
      if (c >= 65 && c <= 90) return String.fromCodePoint(0x24B6 + c - 65);
      if (c >= 97 && c <= 122) return String.fromCodePoint(0x24D0 + c - 97);
      if (c >= 49 && c <= 57) return String.fromCodePoint(0x2460 + c - 49);
      if (c === 48) return '⓪';
      return ch;
    };
    var wide = function (ch) {
      var c = ch.codePointAt(0);
      if (c >= 33 && c <= 126) return String.fromCodePoint(0xFF01 + c - 33);
      return ch;
    };
    return {
      normal: null,
      sansBold: range(0x1D5D4, 0x1D5EE, 0x1D7EC),
      bold: range(0x1D400, 0x1D41A, 0x1D7CE),
      italic: range(0x1D434, 0x1D44E, 0, ital),
      boldItalic: range(0x1D468, 0x1D482, 0),
      script: range(0x1D49C, 0x1D4B6, 0, script),
      boldScript: range(0x1D4D0, 0x1D4EA, 0),
      fraktur: range(0x1D504, 0x1D51E, 0, frak),
      double: range(0x1D538, 0x1D552, 0x1D7D8, dbl),
      mono: range(0x1D670, 0x1D68A, 0x1D7F6),
      smallcaps: function (ch) { return small[ch] || ch; },
      circled: circ,
      wide: wide
    };
  })();
  var FONTS = [
    ['normal', 'Normal'], ['sansBold', '𝗕𝗼𝗹𝗱 sans'], ['bold', '𝐁𝐨𝐥𝐝 serif'], ['italic', '𝐼𝑡𝑎𝑙𝑖𝑐'], ['boldItalic', '𝑩𝒐𝒍𝒅 𝑰𝒕𝒂𝒍𝒊𝒄'], ['script', '𝒮𝒸𝓇𝒾𝓅𝓉'], ['boldScript', '𝓑𝓸𝓵𝓭 𝓢𝓬𝓻𝓲𝓹𝓽'],
    ['fraktur', '𝔉𝔯𝔞𝔨𝔱𝔲𝔯'], ['double', '𝔻𝕠𝕦𝕓𝕝𝕖-𝕤𝕥𝕣𝕦𝕔𝕜'], ['mono', '𝙼𝚘𝚗𝚘𝚜𝚙𝚊𝚌𝚎'], ['smallcaps', 'ꜱᴍᴀʟʟ ᴄᴀᴘꜱ'], ['circled', 'Ⓒⓘⓡⓒⓛⓔⓓ'], ['wide', 'Ｆｕｌｌ ｗｉｄｔｈ']
  ];
  function styleText(t, font) {
    var f = U[font]; if (!f) return t;
    // keep Discord markup, mentions and URLs untouched
    return t.split(/(<[^>]+>|https?:\/\/\S+|:\w+:)/g).map(function (part, i) { return i % 2 ? part : Array.from(part).map(f).join(''); }).join('');
  }

  /* ---------------- Content pools ---------------- */
  var S = {
    clean: { label: 'Clean', ex: 'calm · simple · tidy', tone: 'plain', sym: ['·', '—', '•'],
      id: ['Here for good conversations.', 'Easygoing, curious, usually online.', 'Simple tastes, good music.', 'Quiet energy, loud playlists.', 'Just here to enjoy the ride.', 'Low drama, high vibes.', 'Polite, funny, occasionally late to reply.', 'Making room for the good stuff.'],
      st: ['Replies vary, kindness doesn’t.', 'Say hi — I’m friendly.', 'Coffee first, then talk.', 'Tidy desk, messy playlists.', 'Happy to chat about almost anything.', 'Collecting small good moments.', 'Slow mornings, late-night chats.'],
      cl: ['Nice to meet you.', 'Come say hi.', 'Be kind, stay curious.', 'Good to see you here.'] },
    minimal: { label: 'Minimal', ex: 'hi. · here. · quiet.', tone: 'plain', lc: true, sym: ['—', '·', '/'],
      id: ['Hi.', 'Here.', 'Quiet.', 'Online-ish.', 'Just me.', 'Present, mostly.', 'Less, but better.', 'Existing.'],
      st: ['No essay.', 'Ask if curious.', 'Short on words.', 'Nothing to prove.', 'Say less.', 'Keep it simple.', 'That’s the whole bio.'],
      cl: ['That’s all.', 'Hi again.', 'Moving on.', 'Fin.'] },
    professional: { label: 'Professional', ex: 'open to collabs', tone: 'pro', sym: ['|', '·', '—'],
      id: ['Open to collaboration and good conversation.', 'Building things that last.', 'Focused on craft, open to feedback.', 'Here to learn, share and connect.', 'Available for projects and partnerships.', 'Clear communicator, careful reviewer.', 'Details matter.'],
      st: ['Replies within a day, usually sooner.', 'DMs open for business inquiries.', 'Reliable, direct and easy to work with.', 'Always up for a thoughtful discussion.', 'Clarity over cleverness.', 'Flexible on timezones, firm on deadlines.'],
      cl: ['Let’s connect.', 'Reach out anytime.', 'Happy to help.', 'Inquiries welcome.'] },
    gamer: { label: 'Gamer', ex: 'one more match', tone: 'edge', sym: ['🎮', '⚔', '◈', '»'],
      id: ['Playing something I’ll regret at 3am.', 'One more match. Famous last words.', 'Controller in hand, snacks in reach.', 'Queue up, I’m ready.', 'Lag blames me, I blame lag.', 'Pixels, loot and questionable decisions.', 'Respawn is a lifestyle.', 'Unranked in life, grinding anyway.'],
      st: ['Add me for co-op, not drama.', 'Will carry if bribed with snacks.', 'Sleep is just a loading screen.', 'Win some, learn some, rage-quit never.', 'Probably in a lobby right now.', 'Backlog: infinite. Time: not.', 'Tryhard on weekdays, chaos on weekends.'],
      cl: ['GG.', 'See you in the lobby.', 'Let’s run it.', 'Ready up.', 'Press start.'] },
    developer: { label: 'Developer', ex: 'git commit -m "wip"', tone: 'plain', sym: ['</>', '>', '//', '$'],
      id: ['Turning coffee into code.', 'git commit -m "fixed it (probably)"', 'It works on my machine.', 'Debugging life one log at a time.', 'Writes code, breaks prod, fixes prod.', 'Semicolons optional, bugs mandatory.', 'Ctrl+Z is my love language.', 'Reads the docs after it breaks.'],
      st: ['Open to pairing and code review.', 'Currently arguing with a regex.', 'Tabs vs spaces: staying neutral.', 'Side projects, mostly unfinished.', 'Ask me about my terminal setup.', 'TODO: touch grass.', 'Deploys on Fridays. Fearless.'],
      cl: ['// thanks for reading', 'return "hello";', 'exit(0);', 'echo "hi";', 'ping me'] },
    anime: { label: 'Anime', ex: 'training arc ✦', tone: 'fun', sym: ['✦', '☆', '⟡', '彡'],
      id: ['Protagonist energy, side-quest schedule.', 'Watching “just one more episode”.', 'Plot armor sold separately.', 'Powered by ramen and opening themes.', 'Training arc in progress.', 'Slice of life, mostly.', 'Filler arc is my personality.', 'Isekai’d into this server.'],
      st: ['Ask me for recs, I have a list.', 'Subbed over dubbed (don’t @ me).', 'Rewatching a comfort show again.', 'Manga backlog: yes.', 'Opening skippers will be judged.', 'Cried at episode 12. Again.', 'Tier lists welcome, arguments encouraged.'],
      cl: ['Ganbatte!', 'Nakama welcome.', 'Mata ne!', 'Let’s go watch something.'] },
    mysterious: { label: 'Mysterious', ex: 'you weren’t supposed…', tone: 'edge', lc: true, sym: ['☾', '✧', '⟡', '▪'],
      id: ['You weren’t supposed to find this.', 'Some stories are better unread.', 'Not all who lurk are lost.', 'Appears when least expected.', 'Questions answered with questions.', 'The signal fades at midnight.', 'I know something you don’t.', 'Shadows keep my secrets.'],
      st: ['Ask, and maybe I’ll answer.', 'Always watching, rarely speaking.', 'Names are overrated.', 'Curiosity has a price.', 'The quiet ones know the most.', 'Nothing here. Look closer.', 'Timezone: unknown.'],
      cl: ['…', 'Or maybe not.', 'Until later.', 'Hush.', 'We’ll see.'] },
    funny: { label: 'Funny', ex: 'loading personality…', tone: 'fun', sym: ['😂', '✌', '~', '¯\\_(ツ)_/¯'],
      id: ['Professional overthinker, amateur everything else.', 'Fueled by memes and poor decisions.', 'My bio is longer than my attention span.', 'Certified bad at replying.', 'Sarcasm is my cardio.', 'I’m not lazy, I’m in power-saving mode.', 'Dad jokes pending approval.', 'Loading personality… please wait.'],
      st: ['Send memes, not emails.', 'Will argue about pineapple on pizza.', 'Currently procrastinating on something important.', 'Free hugs, paid opinions.', 'Fluent in sarcasm and bad puns.', 'Still waiting for my villain origin story.', 'Read the terms and conditions. (Lie.)'],
      cl: ['Please don’t quote me.', 'No refunds.', 'This is fine.', 'Ok bye.', 'Terms apply.'] },
    chill: { label: 'Chill', ex: 'lo-fi on, worries off', tone: 'soft', lc: true, sym: ['☁', '🍃', '~', '·'],
      id: ['Go with the flow.', 'Lo-fi on, worries off.', 'Sunday mood, every day.', 'Here for the vibes.', 'Unbothered, moisturized, well-rested.', 'Taking it slow.', 'No rush, no stress.', 'Tea, blankets, good company.'],
      st: ['Drop by, grab a seat.', 'Easy to talk to, easier to laugh with.', 'Sleeps in, shows up kind.', 'Slow replies, big heart.', 'Let’s just hang.', 'Good vibes only (and snacks).', 'Chasing calm, not clout.'],
      cl: ['Stay cozy.', 'Take it easy.', 'Peace.', 'Catch you later.'] },
    competitive: { label: 'Competitive', ex: 'clutch or kick', tone: 'edge', sym: ['⚡', '▲', '»', '◆'],
      id: ['Here to win. Politely.', 'Rank is temporary, grind is forever.', 'Practice makes podium.', 'Always reviewing the VOD.', 'Every loss is a lesson with extra steps.', 'Scrim schedule beats social schedule.', 'Aim high, play smart.', 'Clutch or kick? Clutch.'],
      st: ['Looking for serious teammates.', 'Comms on, ego off.', 'Climbing the ladder, one round at a time.', 'I don’t tilt, I recalibrate.', 'Duo, trio or full stack, let’s queue.', 'Warm-up first, talk later.', 'Always up for scrims.'],
      cl: ['Run it back.', 'GL HF.', 'No excuses.', 'Eyes on the prize.'] },
    aesthetic: { label: 'Aesthetic', ex: '˚₊‧ soft light', tone: 'soft', lc: true, sym: ['˚₊‧', '✿', '⋆˙⟡', '☁'],
      id: ['Soft light, softer playlists.', 'Collecting pretty moments.', 'Golden hour in human form.', 'Lavender skies and vinyl sounds.', 'Dreamy by default.', 'Candlelight, rain and old poems.', 'Pastel thoughts, midnight heart.', 'Living in a film still.'],
      st: ['Journaling under fairy lights.', 'Chasing sunsets and good playlists.', 'Romanticizing the little things.', 'Cozy corners and cloudy days.', 'Made of stardust and iced coffee.', 'Always mid-daydream.'],
      cl: ['Stay soft.', 'Be gentle.', 'Dream on.', 'Hold on to the light.'] },
    dark: { label: 'Dark', ex: 'embrace the night', tone: 'edge', lc: true, sym: ['☠', '⛧', '🖤', '†'],
      id: ['Embrace the night.', 'Born under a black moon.', 'Silence is my favorite sound.', 'Light is overrated.', 'Cold coffee, colder stare.', 'Something wicked this way comes.', 'Darkness feels like home.', 'Night shift by choice.'],
      st: ['Edgy by design, kind in secret.', 'I thrive after midnight.', 'Crows, candles and loud guitars.', 'Not here to be liked.', 'Gloom is a personal brand.', 'Less sunshine, more storm.', 'Dark mode, always.'],
      cl: ['…or don’t.', 'Stay in the dark.', 'Nevermore.', 'Night falls.'] },
    friendly: { label: 'Friendly', ex: 'open DMs, bad jokes', tone: 'plain', sym: ['💛', '✨', '☺', '🌼'],
      id: ['Hi, glad you stopped by!', 'Friendly face, open DMs.', 'Always up for a chat.', 'Making friends one message at a time.', 'Warm heart, bad jokes.', 'Here to make friends and have fun.', 'Everyone’s welcome at my table.', 'Say hello — I really don’t bite.'],
      st: ['Always happy to help out.', 'Compliments are free, take one.', 'Looking for people to chat and game with.', 'Good conversations are my favorite.', 'I’ll remember your birthday.', 'Introvert with extrovert moments.'],
      cl: ['Hope your day is great!', 'Say hi!', 'Come hang out.', 'Nice to meet you!'] },
    creator: { label: 'Creator', ex: 'new project loading', tone: 'plain', sym: ['🎬', '✎', '◆', '▶'],
      id: ['Making things on the internet.', 'Creator, tinkerer, coffee drinker.', 'New project loading.', 'Sharing what I make, learning what I don’t.', 'Pixels, ideas and deadlines.', 'Content by day, ideas by night.', 'Building a little corner of the web.', 'Always working on something new.'],
      st: ['Feedback welcome, kindness required.', 'Commissions and collabs: DMs open.', 'New uploads on the way.', 'Behind the scenes lives here.', 'Support is the best motivation.', 'Here for creativity and community.'],
      cl: ['Thanks for the support.', 'Let’s create something.', 'Stay creative.', 'Links in my profile.'] },
    custom: { label: 'Custom', ex: 'uses your words', tone: 'plain', sym: ['·', '—', '•', '✦'],
      id: ['{vibe}', 'All about {kw}.', '{kw}, mostly.', 'Here for {kw}.', 'Big on {kw}.'],
      st: ['Ask me about {kw}.', 'Obsessed with {kw}.', '{kw} on my mind.', 'Never far from {kw}.'],
      cl: ['That’s me.', 'Say hi.', 'Hello.', 'Nice to meet you.'] }
  };
  var STYLE_ORDER = ['clean', 'minimal', 'professional', 'gamer', 'developer', 'anime', 'mysterious', 'funny', 'chill', 'competitive', 'aesthetic', 'dark', 'friendly', 'creator', 'custom'];

  var FRAMES = {
    plain: { int: ['into {x}', '{x}, mostly', 'big on {x}', 'currently: {x}', '{x} and quiet time'], game: ['playing {x}', '{x} on repeat', 'lately: {x}', '{x} when I can'], anime: ['watching {x}', 'fan of {x}', '{x} rewatcher'], kw: ['{x}', 'all about {x}'] },
    pro: { int: ['Interests: {x}', 'Focus areas: {x}', 'Into {x}'], game: ['Off hours: {x}', 'Plays {x}'], anime: ['Watches {x}', 'Fan of {x}'], kw: ['{x}', 'Focus: {x}'] },
    edge: { int: ['{x} or nothing', 'obsessed with {x}', '{x} addict'], game: ['main: {x}', 'grinding {x}', '{x} until sunrise'], anime: ['{x} comfort arc', 'rewatching {x}', '{x} lore nerd'], kw: ['{x}', 'mind on {x}'] },
    fun: { int: ['{x} enthusiast (unpaid)', '{x} > everything', 'too into {x}'], game: ['{x} (send help)', '{x} till my eyes hurt', 'lost in {x}'], anime: ['{x} rewatch #47', '{x} stan', '{x} brainrot'], kw: ['{x}', 'certified {x} person'] },
    soft: { int: ['{x} & quiet mornings', 'soft spot for {x}', '{x} and cloudy days'], game: ['{x} on a rainy day', 'cozy runs of {x}', '{x} with snacks'], anime: ['{x} comfort rewatch', '{x} and tea', 'in love with {x}'], kw: ['{x}', 'lost in {x}'] }
  };
  var MOODS = { calm: ['calm waters', 'unbothered', 'slow and steady'], hyped: ['running on caffeine', 'hyped', 'one energy drink deep'], moody: ['moody', '3am thoughts', 'brooding'], playful: ['playful', 'mischief managed', 'chaotic good'], focused: ['locked in', 'focused', 'in the zone'], dreamy: ['dreamy', 'head in the clouds', 'daydreaming'], sarcastic: ['sarcasm included', 'dry humor loading', 'sarcastic'], warm: ['warm-hearted', 'cozy', 'soft-spoken'], mysterious: ['quietly mysterious', 'unreadable', 'cryptic'], tired: ['running on 4 hours of sleep', 'sleepy', 'low battery'] };
  var PERS = { introvert: ['introvert (battery low)', 'quiet until we click', 'homebody'], extrovert: ['social butterfly', 'talks to everyone', 'life of the lobby'], ambivert: ['ambivert (depends on the day)', 'half social, half hermit'], chaotic: ['chaotic good', 'organized chaos', 'plan? what plan'], calm: ['calm under pressure', 'steady', 'grounded'], loyal: ['loyal to a fault', 'ride-or-die', 'keeps promises'], curious: ['perpetually curious', 'asks too many questions', 'learning something weird'], dry: ['dry humor', 'deadpan', 'fluent in sarcasm'], perfectionist: ['perfectionist', 'detail obsessed', 'one more tweak'], laidback: ['laid-back', 'easygoing', 'no rush'] };
  var LENGTHS = { short: { max: 70, seg: [1, 2], label: 'Short' }, medium: { max: 130, seg: [2, 3], label: 'Medium' }, long: { max: HARD, seg: [3, 5], label: 'Long' } };
  var SUGGEST = { gamer: /\b(game|gaming|gamer|fps|esports?|stream|twitch|console|pc master)/i, developer: /\b(code|coder|dev|developer|program|hacker|software|linux|python|javascript)/i, anime: /\b(anime|manga|otaku|weeb|cosplay)/i, aesthetic: /\b(aesthetic|soft|dreamy|pastel|cottagecore)/i, dark: /\b(dark|goth|emo|edgy|night)/i, funny: /\b(funny|meme|joke|humou?r|sarcas)/i, competitive: /\b(compet|ranked|esports?|scrim|grind)/i, professional: /\b(business|professional|freelanc|career|work)/i, creator: /\b(creator|artist|youtuber|streamer|music|design)/i, chill: /\b(chill|calm|relax|lofi|lo-fi)/i, mysterious: /\b(myster|enigma|secret|cryptic)/i, friendly: /\b(friendly|nice|kind|sweet|wholesome)/i, minimal: /\b(minimal|simple|short)/i };

  /* ---------------- Composer ---------------- */
  function fill(t, v) { return t.replace(/\{(\w+)\}/g, function (m, k) { return v[k] != null ? v[k] : m; }); }
  function lowerFirst(s) { return s ? s.charAt(0).toLowerCase() + s.slice(1) : s; }

  function segments(o, st) {
    var T = S[o.style], tone = T.tone, F = FRAMES[tone], segs = [], kwList = o.keywords;
    var vars = { kw: kwList.length ? CH.list(kwList, 2, ' & ') : 'good things', vibe: o.vibe ? CH.cap(o.vibe.trim().replace(/[.!?]*$/, '.')) : 'Just here to hang out.' };
    var low = function (s) { return T.lc ? s.toLowerCase() : s; };
    function line(pool, key) { return low(fill(fresh('bio:' + o.style + ':' + key, pool), vars)); }
    var has = function (arr) { return arr && arr.length; };
    // user phrases are untouchable and highest priority
    o.phrases.forEach(function (p) { segs.push({ t: p, pr: 0, k: 'phrase', raw: true }); });
    if (o.style === 'custom' && !o.vibe && !has(kwList) && !o.phrases.length) vars.kw = 'good vibes';
    segs.push({ t: line(T.id, 'id'), pr: 1, k: 'id' });
    if (o.pronouns) segs.push({ t: o.pronouns, pr: 1.2, k: 'pron', raw: true });
    if (has(o.interests)) segs.push({ t: fillSlot(F.int, 'int:' + tone, CH.list(o.interests, 3, ' & '), low), pr: 2, k: 'int' });
    if (has(o.games)) segs.push({ t: fillSlot(F.game, 'game:' + tone, CH.list(o.games, 3, ' & '), low), pr: 2, k: 'game' });
    if (has(o.anime)) segs.push({ t: fillSlot(F.anime, 'anime:' + tone, CH.list(o.anime, 2, ' & '), low), pr: 2, k: 'anime' });
    if (has(kwList) && o.style !== 'custom') segs.push({ t: fillSlot(F.kw, 'kw:' + tone, CH.list(kwList, 3, ' / '), low), pr: 2.4, k: 'kw' });
    segs.push({ t: line(T.st, 'st'), pr: 3, k: 'st', sentence: true });
    if (o.mood && MOODS[o.mood]) segs.push({ t: low(fresh('bio:mood:' + o.mood, MOODS[o.mood])), pr: 4, k: 'mood' });
    if (o.personality && PERS[o.personality]) segs.push({ t: low(fresh('bio:pers:' + o.personality, PERS[o.personality])), pr: 4.2, k: 'pers' });
    segs.push({ t: line(T.cl, 'cl'), pr: 5, k: 'cl', sentence: true });
    return segs;
  }
  function fillSlot(pool, key, x, low) { return low(fresh('bio:' + key, pool).replace('{x}', '\u0000')).replace('\u0000', x); }

  function assemble(chosen, o, layout, symLevel) {
    var T = S[o.style], sy = T.sym, sep;
    var seps = { clean: [' · ', ' | ', ' — '], dev: [' | ', ' // ', ' · '] };
    var sepPool = o.style === 'developer' ? seps.dev : [' · ', ' | ', ' • ', ' — '];
    sep = symLevel === 'none' ? ' · ' : (symLevel === 'subtle' ? pick(sy.length ? [' ' + sy[0] + ' ', ' · '] : [' · ']) : pick(sepPool));
    if (symLevel === 'none') sep = pick([' · ', ' | ', ' / ']);
    var texts = chosen.map(function (s) { return s.t; });
    // joined with separators, sentence-final periods look noisy — keep them only where lines stand alone
    if (layout === 'inline' || layout === 'headline') texts = texts.map(function (t) { return /[^.]\.$/.test(t) ? t.slice(0, -1) : t; });
    var out;
    if (layout === 'stack') out = texts.join('\n');
    else if (layout === 'headline') out = texts[0] + (texts.length > 1 ? '\n' + texts.slice(1).join(sep) : '');
    else if (layout === 'prose') out = texts.reduce(function (a, t, i) { return i ? a + (/[.!?…]$/.test(texts[i - 1]) ? ' ' : ' · ') + t : t; }, '');
    else out = texts.join(sep);
    if (symLevel === 'decorative' && sy.length) {
      var a = pick(sy), b = chance(.6) ? a : pick(sy), lines = out.split('\n');
      lines[0] = a + ' ' + lines[0] + (chance(.7) ? ' ' + b : ''); out = lines.join('\n');
    } else if (symLevel === 'heavy' && sy.length) {
      var s1 = pick(sy); out = out.split('\n').map(function (l, i) { return (i % 2 ? pick(sy) : s1) + ' ' + l; }).join('\n');
      if (chance(.5)) out += ' ' + s1;
    }
    return out;
  }

  function buildOnce(o, L, base) {
    var n = CH.range(L.seg[0], L.seg[1]);
    var must = base.filter(function (s) { return s.k === 'phrase'; });
    var rest = base.filter(function (s) { return s.k !== 'phrase'; })
      .map(function (s) { return { s: s, w: s.pr + Math.random() * 1.6 }; })
      .sort(function (a, b) { return a.w - b.w; }).map(function (x) { return x.s; });
    var chosen = must.concat(rest).slice(0, Math.max(n, Math.min(must.length, 3)));
    if (!chosen.some(function (s) { return s.k === 'id' || s.k === 'phrase'; })) chosen[chosen.length - 1] = base.filter(function (s) { return s.k === 'id'; })[0];
    // flow: identity/pronouns first, closer last, the middle shuffled
    var head = chosen.filter(function (s) { return s.k === 'id' || s.k === 'phrase' || s.k === 'pron'; });
    var tail = chosen.filter(function (s) { return s.k === 'cl'; });
    var mid = CH.shuffle(chosen.filter(function (s) { return head.indexOf(s) < 0 && tail.indexOf(s) < 0; }));
    if (chance(.3) && head.length > 1) head = CH.shuffle(head);
    var order = head.concat(mid, tail);
    var layouts = chosen.length === 1 ? ['inline'] : (o.length === 'short' ? ['inline', 'inline', 'stack'] : o.length === 'medium' ? ['inline', 'headline', 'stack', 'prose'] : ['stack', 'headline', 'stack', 'inline']);
    var layout = pick(layouts), sym = o.symbols, text = assemble(order, o, layout, sym), guard = 0;
    // fit: drop the least important segment until it fits
    while (text.length > L.max && order.length > 1 && guard++ < 6) {
      var drop = order.filter(function (s) { return s.k !== 'phrase' && s.k !== 'id'; }).sort(function (a, b) { return b.pr - a.pr; })[0] || order[order.length - 1];
      order = order.filter(function (s) { return s !== drop; }); text = assemble(order, o, layout, sym);
    }
    if (text.length > L.max && sym !== 'none') text = assemble(order, o, layout, 'none');
    if (text.length > L.max) {
      var cut = text.slice(0, L.max - 1), sp = cut.lastIndexOf(' ');
      text = (sp > L.max * .6 ? cut.slice(0, sp) : cut).replace(/[\s,;:·|—-]+$/, '') + '…';
    }
    return text;
  }
  function composeOne(o) {
    var L = LENGTHS[o.length], base = segments(o), best = '';
    for (var attempt = 0; attempt < 6; attempt++) {
      var text = buildOnce(o, L, base);
      if (text.length > best.length) best = text;
      if (o.length === 'short' || text.length >= L.max * .5) { best = text; break; }
    }
    return finish(best, o);
  }
  function finish(text, o) {
    if (o.font === 'normal') return text;
    var styled;
    if (o.scope === 'all') styled = styleText(text, o.font);
    else { var nl = text.indexOf('\n'); var first = nl > 0 ? text.slice(0, nl) : text; styled = styleText(first, o.font) + (nl > 0 ? text.slice(nl) : ''); }
    if (styled.length > HARD) { styled = styleText(text.split('\n')[0], o.font) + text.slice(text.split('\n')[0].length); if (styled.length > HARD) return text; }
    return styled;
  }

  function generate(o, count) {
    var seen = {}, out = [], tries = 0;
    while (out.length < count && tries++ < count * 12) {
      var t = composeOne(o); if (!t || seen[t]) continue; seen[t] = 1; out.push({ text: t, label: S[o.style].label + ' · ' + LENGTHS[o.length].label, data: { style: o.style } });
    }
    return out;
  }

  /* ---------------- UI ---------------- */
  var saved = CH.Store.get('form:bio', {});
  var form = Object.assign({ vibe: '', style: 'clean', length: 'medium', interests: '', games: '', anime: '', keywords: '', phrases: '', mood: '', personality: '', pronouns: '', symbols: 'subtle', font: 'normal', scope: 'accent' }, saved);
  function persist() { CH.Store.set('form:bio', form); }

  root.appendChild(ui.pageHead({ icon: 'user', title: 'Bio Generator', desc: 'Pick a style, add a few details, get several different bios. Everything fits Discord’s ' + HARD + '-character About Me limit.' }));

  var vibe = ui.field({ label: 'What kind of person do you want to sound like?', type: 'textarea', rows: 2, value: form.vibe, placeholder: 'e.g. a night-owl streamer who loves horror games and bad puns', hint: 'Optional. Used by the Custom style, and to suggest a style for you.', onInput: function (v) { form.vibe = v; suggest(); persist(); } });
  var suggestBox = el('div', { class: 'hint', 'aria-live': 'polite' });
  function suggest() {
    CH.clear(suggestBox);
    var hit = Object.keys(SUGGEST).filter(function (k) { return SUGGEST[k].test(form.vibe); })[0];
    if (hit && hit !== form.style && form.vibe.length > 3) {
      var b = el('button', { type: 'button', class: 'btn btn-sm btn-ghost' }, 'Use ' + S[hit].label); b.addEventListener('click', function () { form.style = hit; styleChips.set(hit); persist(); suggest(); });
      suggestBox.appendChild(el('span', null, 'Sounds like ', el('strong', null, S[hit].label), '. ')); suggestBox.appendChild(b);
    }
  }
  var styleChips = ui.chips({ label: 'Style', ex: true, value: form.style, options: STYLE_ORDER.map(function (k) { return { value: k, label: S[k].label, ex: S[k].ex }; }), onChange: function (v) { form.style = v; persist(); suggest(); } });
  var lenSeg = ui.seg({ label: 'Length', value: form.length, options: [{ value: 'short', label: 'Short ≤70' }, { value: 'medium', label: 'Medium ≤130' }, { value: 'long', label: 'Long ≤190' }], onChange: function (v) { form.length = v; persist(); } });
  function tf(key, label, ph, type, hint) { return ui.field({ label: label, type: type || 'text', rows: 2, value: form[key], placeholder: ph, hint: hint, onInput: function (v) { form[key] = v; persist(); } }); }
  var moodF = ui.field({ label: 'Mood', type: 'select', value: form.mood, options: [{ value: '', label: 'Any' }].concat(Object.keys(MOODS).map(function (k) { return { value: k, label: CH.cap(k) }; })), onInput: function (v) { form.mood = v; persist(); } });
  var persF = ui.field({ label: 'Personality', type: 'select', value: form.personality, options: [{ value: '', label: 'Any' }, { value: 'introvert', label: 'Introvert' }, { value: 'extrovert', label: 'Extrovert' }, { value: 'ambivert', label: 'Ambivert' }, { value: 'chaotic', label: 'Chaotic' }, { value: 'calm', label: 'Calm' }, { value: 'loyal', label: 'Loyal' }, { value: 'curious', label: 'Curious' }, { value: 'dry', label: 'Dry humor' }, { value: 'perfectionist', label: 'Perfectionist' }, { value: 'laidback', label: 'Laid-back' }], onInput: function (v) { form.personality = v; persist(); } });
  var symSeg = ui.seg({ label: 'Symbols', value: form.symbols, options: [{ value: 'none', label: 'None' }, { value: 'subtle', label: 'Subtle' }, { value: 'decorative', label: 'Decorative' }, { value: 'heavy', label: 'Heavy' }], onChange: function (v) { form.symbols = v; persist(); } });
  var fontF = ui.field({ label: 'Unicode text style', type: 'select', value: form.font, options: FONTS.map(function (f) { return { value: f[0], label: f[1] }; }), onInput: function (v) { form.font = v; persist(); } });
  var scopeSeg = ui.seg({ label: 'Apply font to', value: form.scope, options: [{ value: 'accent', label: 'First line only' }, { value: 'all', label: 'Whole bio' }], onChange: function (v) { form.scope = v; persist(); } });

  var formCard = el('div', { class: 'card card-pad tool-form' },
    el('div', { class: 'form-section' }, el('h3', null, 'Vibe'), vibe.el, suggestBox),
    el('div', { class: 'form-section' }, el('h3', null, 'Style'), styleChips.el),
    el('div', { class: 'form-section' }, el('h3', null, 'Length'), lenSeg.el),
    el('div', { class: 'form-section' }, el('h3', null, 'About you'),
      tf('interests', 'Interests', 'music, drawing, late-night walks', 'text', 'Comma-separated.').el,
      el('div', { class: 'form-grid' }, tf('games', 'Favorite games', 'Valorant, Hades').el, tf('anime', 'Favorite anime', 'Frieren, Mob Psycho').el),
      tf('keywords', 'Keywords', 'night owl, ramen, synthwave').el,
      tf('phrases', 'Custom phrases', 'One per line — used word for word', 'textarea').el,
      el('div', { class: 'form-grid' }, moodF.el, persF.el),
      tf('pronouns', 'Pronouns', 'she/her · he/him · they/them').el),
    el('div', { class: 'form-section' }, el('h3', null, 'Decoration'), symSeg.el, fontF.el, scopeSeg.el,
      el('div', { class: 'hint' }, 'Fancy Unicode fonts can be hard for screen readers and some devices to display. They’re best kept short.')),
    el('div', { class: 'sticky-actions' }, ui.btn('Generate bios', { kind: 'primary', icon: 'sparkle', onclick: run })));

  var results = ui.results({
    type: 'bio', label: 'Bio', limit: HARD, titleOf: function (it) { return it.text.split('\n')[0]; },
    regen: function (it) { return generate(read(), 1)[0] || it; }
  });
  var head = el('div', { class: 'results-head' }, el('h2', null, 'Your bios'), ui.btn('Generate again', { icon: 'refresh', sm: true, onclick: run }));
  var out = el('div', null, head, results.el);
  root.appendChild(el('div', { class: 'tool-layout' }, formCard, el('div', { class: 'card card-pad' }, out)));

  function read() {
    var list = CH.csv;
    var vibeItems = form.vibe.indexOf(',') > 0 ? form.vibe.split(',').map(function (x) { return x.trim(); }).filter(function (x) { return x && x.length <= 24; }) : [];
    return {
      style: form.style, length: form.length, vibe: form.vibe.trim().split('\n')[0].slice(0, 90),
      interests: list(form.interests), games: list(form.games), anime: list(form.anime),
      keywords: list(form.keywords).concat(form.style === 'custom' ? vibeItems : []),
      phrases: form.phrases.split('\n').map(function (x) { return x.trim(); }).filter(Boolean).map(function (x) { return x.slice(0, 100); }),
      mood: form.mood, personality: form.personality, pronouns: form.pronouns.trim().slice(0, 24), symbols: form.symbols, font: form.font, scope: form.scope
    };
  }
  function run() { results.set(generate(read(), 6)); }
  suggest(); run();
});
