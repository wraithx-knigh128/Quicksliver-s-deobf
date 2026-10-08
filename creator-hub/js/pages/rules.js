/* Server Rules Generator — a bank of rules with three wordings each (friendly / neutral / firm),
   filtered by server type and strictness, plus a configurable moderation & staff policy. */
CH.page('rules', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon, pick = CH.pick, fresh = CH.fresh, chance = CH.chance;

  var TYPES = [
    { value: 'gaming', label: 'Gaming' }, { value: 'community', label: 'Community' }, { value: 'friends', label: 'Friends' }, { value: 'anime', label: 'Anime' }, { value: 'creator', label: 'Creator' },
    { value: 'education', label: 'Education' }, { value: 'support', label: 'Support' }, { value: 'professional', label: 'Professional' }, { value: 'marketplace', label: 'Marketplace' }, { value: 'other', label: 'Other' }
  ];
  var ALL = null;
  // r(id, emoji, title, priority, types|null, friendly, neutral, firm)   priority: 0 = essential, 1 = important, 2 = common, 3 = only for stricter servers
  function r(id, e, t, pri, types, f, n, s) { return { id: id, e: e, t: t, pri: pri, types: types, f: f, n: n, s: s }; }
  var RULES = [
    r('respect', '🤝', 'Be respectful', 0, ALL, 'Treat everyone the way you’d want to be treated. Disagreements are fine — personal attacks, harassment and bullying are not.', 'Treat all members with respect. Harassment, bullying, personal attacks and targeted insults are prohibited.', 'No harassment, bullying, personal attacks or targeted insults. Violations are actioned immediately.'),
    r('hate', '🚫', 'No hate or discrimination', 0, ALL, 'Hate speech has no home here. That covers slurs and attacks on anyone for their race, ethnicity, gender, sexuality, religion, disability or similar.', 'Hate speech and discrimination based on race, ethnicity, nationality, gender, sexuality, religion, disability or similar characteristics are prohibited, including slurs and “jokes”.', 'Zero tolerance for hate speech, slurs or discrimination of any kind — including as a joke. Expect an immediate ban.'),
    r('nsfw', '🔞', 'Keep it safe for work', 0, ALL, 'This is a safe-for-work space. Please keep explicit, graphic or shocking content out of every channel.', 'NSFW, sexually explicit, gory or otherwise graphic content is not permitted in any channel.', 'No NSFW, gore or shock content anywhere — including avatars, nicknames and statuses. Instant ban.'),
    r('privacy', '🔒', 'Protect privacy', 0, ALL, 'Don’t share anyone’s personal info — yours or theirs. No doxxing, and no leaking private chats or photos without consent.', 'Sharing personal information about others (doxxing) or private conversations without consent is prohibited.', 'No doxxing, and no sharing personal info, private messages or images without consent. Permanent ban.'),
    r('illegal', '⚠️', 'Nothing illegal or harmful', 0, ALL, 'No scams, phishing, malware, piracy or anything illegal. If it could hurt someone or get this server in trouble, leave it out.', 'Content or links that are illegal, fraudulent or harmful — including phishing, malware, scams and pirated material — are prohibited.', 'No scams, phishing, malware, piracy or other illegal content. Immediate permanent ban and a report to Discord where appropriate.'),
    r('selfharm', '💙', 'Look after each other', 1, ['community', 'friends', 'support', 'creator', 'anime'], 'If someone’s struggling, be kind and point them toward proper help. Don’t encourage or glorify self-harm, and tell a mod if you’re worried about someone.', 'Content that encourages or glorifies self-harm or suicide is prohibited. If you are concerned about a member, contact staff.', 'No encouragement or glorification of self-harm or suicide. Staff may remove content and take action immediately.'),
    r('boundaries', '🫶', 'Respect boundaries', 1, ['friends'], 'Respect each other’s boundaries and privacy. What’s said here stays here — no screenshots or sharing without consent.', 'Respect each member’s boundaries. Do not screenshot or share private conversations without consent.', 'No screenshots or sharing of conversations without consent. Repeat violations result in removal.'),
    r('inclusive', '🌈', 'Include everyone', 2, ['friends', 'community', 'creator', 'anime'], 'Everyone’s welcome. Don’t gatekeep, leave people out or make anyone feel like an outsider.', 'Maintain an inclusive environment. Exclusion, gatekeeping and in-group hostility are not tolerated.', 'No gatekeeping or exclusionary behavior. Violations are addressed immediately.'),
    r('integrity', '📚', 'Academic honesty', 0, ['education'], 'Learning is the point — use help to understand, not to copy. Don’t share answers to graded work.', 'Sharing answers to graded assessments, or assisting with academic dishonesty, is prohibited.', 'No cheating, plagiarism or sharing of graded answers. Violations result in an immediate ban.'),
    r('credentials', '🔑', 'Never share credentials', 0, ['support', 'marketplace', 'professional'], 'Never post passwords, tokens, API keys or payment details — in the server or in DMs. Staff will never ask for them.', 'Do not post passwords, access tokens, API keys or payment information. Staff will never request them.', 'Sharing credentials or payment info is prohibited. Anyone who asks for them will be banned.'),
    r('confidential', '💼', 'Professional conduct', 0, ['professional'], 'Keep conversations professional and respect confidentiality — don’t share other people’s work, clients or private discussions.', 'Maintain professional conduct. Confidential information, client details and private discussions must not be shared outside the server.', 'Professional conduct only. Breaches of confidentiality result in immediate removal.'),
    r('prohibited', '⛔', 'No prohibited goods', 0, ['marketplace'], 'Nothing stolen, hacked, counterfeit or against Discord’s rules. If you wouldn’t want it traced back to you, don’t list it.', 'Listing stolen, counterfeit, hacked or otherwise prohibited goods and services is prohibited.', 'No stolen, counterfeit or illegal goods or services. Permanent ban and report.'),
    r('trade', '🛒', 'Trade safely', 0, ['marketplace'], 'Trade at your own risk: use the middleman service for big deals, state clear prices, and never send first to someone you don’t know.', 'All trades are conducted at users’ own risk. Use an official middleman for high-value transactions and state clear terms.', 'Scamming results in a permanent ban. Use a middleman for high-value deals and never take trades off-server with unverified users.'),
    r('postformat', '📝', 'Post in the right format', 1, ['marketplace'], 'Use the post template: what you’re buying or selling, the price and the payment method. One post per item, bumped no more than once a day.', 'Listings must follow the template (item, price, payment method). Duplicate listings and excessive bumping are prohibited.', 'Use the post template. Duplicate posts, bumping and fake listings are removed.'),
    r('cheating', '🎮', 'No cheating or exploits', 1, ['gaming'], 'Play fair — no hacks, cheats or knowingly abusing exploits, and don’t share them here.', 'Cheating, hacking, boosting and abusing game exploits — and sharing the tools to do so — are prohibited.', 'No cheats, hacks, boosting or exploit sharing. Permanent ban.'),
    r('toxic', '🏆', 'Good sportsmanship', 1, ['gaming'], 'Win gracefully, lose gracefully. Trash talk is fine while everyone’s laughing; it isn’t when someone isn’t.', 'Toxic behavior — including targeted trash talk, rage-baiting, griefing and smurfing in community events — is not allowed.', 'No toxicity, griefing or flaming. Repeated toxicity results in removal from events and the server.'),
    r('spoilers', '🙈', 'Tag your spoilers', 2, ['anime', 'community', 'friends'], 'Hide spoilers behind ||spoiler tags|| and say what they’re for (“ch. 120”), so nobody gets surprised.', 'Use spoiler tags for plot details of recent releases and label the title and episode or chapter.', 'Untagged spoilers are removed. Tag spoilers and include the title. Repeat violations result in a timeout.'),
    r('credit', '🎨', 'Credit creators', 1, ['anime', 'creator'], 'Credit artists and creators when you share their work, and don’t repost or edit it without permission.', 'Share creative work only with proper credit. Reposting, tracing or claiming others’ work as your own is prohibited.', 'No art theft, tracing or uncredited reposts. Offenders are removed.'),
    r('promo', '📣', 'Self-promotion rules', 1, ['creator'], 'Love your work! Share it in the promo channel only, give back to the community too, and no unsolicited DMs.', 'Self-promotion is permitted only in designated channels. Unsolicited DMs and repeated posting are prohibited.', 'Promote only in the designated channel, no more than once per week. Unsolicited DM promotion results in a ban.'),
    r('feedback', '💬', 'Give constructive feedback', 2, ['creator', 'education'], 'Critique the work, not the person. Be specific, be kind, and ask before giving feedback in someone’s showcase thread.', 'Feedback must be constructive and respectful. Personal criticism of creators is prohibited.', 'Only constructive, respectful feedback. Insults disguised as critique result in a timeout.'),
    r('askwell', '❓', 'Ask good questions', 1, ['education', 'support'], 'Help us help you: describe the problem, what you’ve tried, and include errors or screenshots. Please be patient waiting for an answer.', 'Questions should include relevant detail, what has been attempted and any error messages. Do not repost or demand immediate answers.', 'Provide full details when asking for help. Repeated low-effort or duplicate questions are removed.'),
    r('patience', '⏳', 'Be patient with helpers', 2, ['support'], 'Helpers are volunteers. Please don’t ping or DM them for help — post in the help channel and wait.', 'Do not ping or direct-message helpers or staff for support. Use the designated support channels.', 'No pinging or DMing staff for help. Use the support channels or a ticket.'),
    r('solicit', '📨', 'No unsolicited offers', 1, ['professional'], 'No cold pitches in DMs or job spam. Use the opportunities channel for offers.', 'Unsolicited recruiting, sales pitches and job offers are restricted to the designated channel.', 'No cold DMs, solicitation or recruitment outside the designated channel. Repeat offenders are banned.'),
    r('voice', '🎙️', 'Voice etiquette', 2, ['gaming', 'community', 'friends', 'anime', 'creator', 'education'], 'In voice, be considerate: no earrape, soundboard spam or mic spam. Use push-to-talk if your room is noisy.', 'Voice channel etiquette applies: no disruptive noise, soundboard abuse, voice changers used to harass, or recording others without consent.', 'No earrape, soundboard spam, harassment over voice or recording others without permission. Offenders are removed from voice immediately.'),
    r('politics', '🗳️', 'Keep heated topics out', 3, ALL, 'Politics and religion get heated fast, so we keep them out of the main channels.', 'Political and religious debates are not permitted in public channels.', 'No political or religious discussion. Content is removed and repeated posting results in a mute.'),
    r('spam', '✉️', 'No spam', 1, ALL, 'Don’t flood chat — no repeated messages, walls of caps, emoji floods or random pings. Give conversations room to breathe.', 'Spam is prohibited. This includes repeated messages, excessive capitals, emoji or mentions, and message flooding.', 'No spam, flooding, excessive caps/emoji or mass mentions. Repeat offenses result in a timeout.'),
    r('ads', '📢', 'No unsolicited advertising', 1, ['gaming', 'community', 'friends', 'anime', 'education', 'support', 'professional', 'other'], 'Please don’t advertise servers, channels or products without asking staff first — and no DM ads.', 'Unsolicited advertising, server invites and DM promotion are not allowed without staff approval.', 'No advertising, invite links or DM promotion. Violators are banned without warning.'),
    r('channels', '🗂️', 'Use the right channels', 1, ALL, 'Keep things on topic and use each channel for what it’s meant for — it makes everything easier to find.', 'Use each channel for its intended purpose and keep discussions on topic.', 'Stay on topic. Off-topic posts are removed, and repeated misuse results in a timeout.'),
    r('language', '🌐', 'Keep it readable', 2, ALL, 'Please keep public chat in {lang} so everyone can join in.', 'Public channels are conducted in {lang}.', '{lang} only in public channels. Other languages belong in designated channels.'),
    r('mentions', '🔔', 'Be careful with pings', 2, ALL, 'Only ping people when it’s genuinely needed. Mass pings, and pinging staff for non-urgent things, will earn a gentle talking-to.', 'Do not mass-mention users or roles, or ping staff for non-urgent matters.', 'No unnecessary pings of members, roles or staff. Mass pings result in an immediate timeout.'),
    r('drama', '🧯', 'Leave drama at the door', 2, ALL, 'Keep arguments and callouts out of public chat. Take it to DMs, or ask a mod to step in.', 'Personal disputes should be handled privately or through staff, not in public channels.', 'No public drama, callouts or witch-hunts. Take issues to staff.'),
    r('impersonation', '🎭', 'No impersonation', 2, ALL, 'Be yourself. Please don’t pretend to be staff, other members or public figures.', 'Impersonating staff, members, bots or public figures is prohibited.', 'No impersonation of staff, members or bots. Instant ban.'),
    r('altban', '🔁', 'No ban evasion', 3, ALL, 'If you’ve been banned, please respect the decision rather than coming back on another account.', 'Ban evasion, including through alternate accounts, is prohibited.', 'Ban evasion results in an immediate permanent ban on every linked account.'),
    r('names', '🏷️', 'Readable names & avatars', 3, ALL, 'Pick a name and avatar others can read and mention, without offensive content — no zalgo or blank names.', 'Usernames, nicknames and avatars must be readable, mentionable and free of offensive content.', 'Offensive, unreadable or disruptive names and avatars will be changed by staff; refusal results in removal.'),
    r('bots', '🤖', 'Bots in the right place', 3, ['gaming', 'community', 'anime', 'friends'], 'Run bot commands in the bot channel to keep chat clean.', 'Bot commands are restricted to designated bot channels.', 'Bot commands outside designated channels are removed; repeated misuse results in a timeout.'),
    r('ai', '🧠', 'Label AI-generated work', 3, ['creator', 'anime'], 'If your art, writing or music is AI-generated or AI-assisted, say so when you share it.', 'AI-generated or AI-assisted work must be clearly labelled as such.', 'Unlabelled AI-generated work is removed. Repeat violations result in a ban.'),
    r('tos', '📜', 'Follow Discord’s rules', 0, ALL, 'Follow Discord’s Terms of Service and Community Guidelines, and make sure you meet Discord’s minimum age.', 'All members must comply with Discord’s Terms of Service and Community Guidelines, including the minimum age requirement.', 'Discord’s Terms of Service and Community Guidelines apply here. Members under Discord’s minimum age will be removed.'),
    r('staff', '🛡️', 'Listen to staff', 1, ALL, 'Our mods are volunteers doing their best. If staff ask you to stop something, please do — and bring concerns to them privately.', 'Follow reasonable instructions from staff. If you disagree with a decision, raise it privately rather than arguing in public channels.', 'Staff instructions must be followed. Appeal through the proper process — do not argue publicly.')
  ];

  var QUIPS = ['Simple as that.', 'Thanks, you legend.', 'Your future self will thank you.', 'It’s not that hard, we believe in you.', 'Be the good kind of memorable.', 'We’re all adults here. Mostly.'];
  var INTRO = {
    friendly: ['Welcome to {server}! These rules keep it a place everyone enjoys.', 'Hey, and welcome to {server}! A few ground rules so we all have a good time.', 'Glad you’re here. Here’s how we keep {server} friendly and fun.'],
    playful: ['Welcome to {server}! Read the rules, or the mods will gently judge you. 🫡', 'Rules time! Short, sweet and mandatory in {server}.', 'Before the fun begins in {server}, the boring-but-important part:'],
    neutral: ['Welcome to {server}. Please read and follow these rules.', 'These rules apply to all members of {server}.', 'Please review the server rules below before participating.'],
    formal: ['By participating in {server}, you agree to abide by the following rules.', 'The following rules govern conduct within {server}. Ignorance of the rules is not an excuse.', 'All members of {server} are expected to read and comply with these rules.'],
    firm: ['Read these rules. Breaking them has consequences.', '{server} has rules. They are enforced.', 'Rules for {server}. No exceptions.']
  };
  var OUTRO = {
    friendly: ['Thanks for helping make {server} a great place! 💛', 'Questions? Just ask a mod — we’re friendly.', 'Have fun, be kind, and enjoy your stay!'],
    playful: ['Now go have fun. Responsibly. 🎉', 'That’s it! Welcome aboard, adventurer.', 'Break the rules and we’ll break out the banhammer. (Gently. Usually.)'],
    neutral: ['Thank you for helping keep {server} a good place.', 'Contact a staff member if anything is unclear.', 'By staying in the server you agree to these rules.'],
    formal: ['Continued participation constitutes acceptance of these rules.', 'These rules may be amended at any time; members will be notified of significant changes.', 'Direct any questions regarding these rules to server staff.'],
    firm: ['Ignorance is not an excuse.', 'Staff decisions are final.', 'If you can’t follow these, you can’t stay.']
  };
  var LADDER = {
    1: 'We’d rather talk things through. Minor issues get a friendly nudge first; repeated problems lead to a timeout, then removal.',
    2: 'Minor issues get a warning. Repeated or more serious problems lead to a timeout, a kick and then a ban.',
    3: 'Standard ladder: warning → timeout → kick → ban. The severity of the issue decides where you start.',
    4: 'Rules are enforced consistently: one warning for minor issues, then a timeout, then a ban. Serious issues skip steps.',
    5: 'Warnings are not guaranteed. Staff may timeout, kick or ban immediately at their discretion.'
  };

  /* ---------------- generation ---------------- */
  function variantKey(tone) { return tone === 'friendly' || tone === 'playful' ? 'f' : tone === 'firm' ? 's' : 'n'; }
  function generate(f) {
    var type = f.type === 'other' ? 'community' : f.type, tone = f.tone, server = f.server.trim() || 'our server', lang = f.language.trim() || 'English';
    var maxPri = f.strict <= 1 ? 1 : f.strict === 2 ? 2 : f.strict === 3 ? 2 : 3;
    var pool = RULES.filter(function (x) { return !x.types || x.types.indexOf(type) >= 0; });
    var want = Math.min(f.count, pool.length);
    var scored = pool.map(function (x) { return { x: x, w: x.pri + (x.pri > maxPri && f.strict < 4 ? 2.2 : 0) + (x.types && x.types.length <= 2 ? -.4 : 0) + Math.random() * 1.1 }; }).sort(function (a, b) { return a.w - b.w; });
    var chosen = scored.slice(0, want).map(function (s) { return s.x; });
    chosen.sort(function (a, b) { return RULES.indexOf(a) - RULES.indexOf(b); });
    var vk = variantKey(tone);
    var rules = chosen.map(function (x) {
      var text = x[vk].replace(/\{lang\}/g, lang);
      if (tone === 'playful' && chance(.4)) text += ' ' + pick(QUIPS);
      return { id: x.id, e: x.e, t: x.t, text: text };
    });
    var contact = f.contact.trim() || 'message a moderator or open a ticket';
    var mod = [];
    if (f.pol.ladder) mod.push({ t: 'Warnings & consequences', text: LADDER[f.strict] });
    if (f.pol.zero) mod.push({ t: 'Immediate bans', text: 'Some things mean an instant permanent ban with no warning: hate speech, doxxing, threats, illegal content and anything that sexualizes minors.' });
    if (f.pol.appeals) mod.push({ t: 'Appeals', text: 'Think a decision was wrong? ' + CH.cap(contact) + '. We review appeals fairly' + (f.pol.impartial ? ' and, where possible, with a different staff member' : '') + '.' });
    if (f.pol.report) mod.push({ t: 'Reporting problems', text: 'To report an issue, ' + contact + '. Please include message links or screenshots where you can.' });
    if (f.pol.nomini) mod.push({ t: 'No mini-modding', text: 'Don’t confront rule-breakers yourself — report them and let staff handle it.' });
    if (f.pol.impartial) mod.push({ t: 'Staff follow the rules too', text: 'These rules apply to everyone, staff included. If you see staff misconduct, report it to the owner or an admin.' });
    if (f.pol.logs) mod.push({ t: 'Transparency', text: 'Moderation actions are logged privately by staff so decisions stay consistent and reviewable.' });
    if (f.pol.final) mod.push({ t: 'Final say', text: 'Staff have the final say. Rules are applied in spirit as well as letter, and may change — significant updates will be announced.' });
    var tk = tone;
    return { server: server, intro: fill(fresh('rules:intro:' + tk, INTRO[tk]), server), outro: fill(fresh('rules:outro:' + tk, OUTRO[tk]), server), rules: rules, mod: mod, tone: tone, pool: pool.length, want: want };
  }
  function fill(t, server) { return t.replace(/\{server\}/g, server); }

  /* ---------------- formatting ---------------- */
  var KEYCAP = ['1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟'];
  function num(i, style, emoji, rule) {
    var n = i + 1;
    if (style === 'emoji' && n <= 10) return KEYCAP[i];
    return n + '.';
  }
  function fmtDiscord(m, o) {
    var out = [], style = o.style, em = o.emoji;
    out.push('# ' + (em ? '📜 ' : '') + 'Server Rules' + (m.server !== 'our server' ? ' — ' + m.server : ''));
    out.push(m.intro, '');
    m.rules.forEach(function (x, i) {
      var title = (em ? x.e + ' ' : '') + x.t, n = num(i, style, em);
      if (style === 'heading') out.push('## ' + n + ' ' + title, x.text, '');
      else if (style === 'compact') out.push(n + ' **' + title + '** — ' + x.text, '');
      else out.push('**' + n + ' ' + title + '**', x.text, '');
    });
    if (m.mod.length) {
      out.push('## ' + (em ? '⚖️ ' : '') + 'Moderation & consequences');
      m.mod.forEach(function (x) { out.push('- **' + x.t + ':** ' + x.text); });
      out.push('');
    }
    out.push('-# ' + m.outro);
    return out.join('\n').replace(/\n{3,}/g, '\n\n');
  }
  function fmtPlain(m, o) {
    var out = [('SERVER RULES' + (m.server !== 'our server' ? ' — ' + m.server.toUpperCase() : '')), m.intro, ''];
    m.rules.forEach(function (x, i) { out.push((i + 1) + '. ' + x.t + (o.emoji ? ' ' + x.e : '') + '\n   ' + x.text, ''); });
    if (m.mod.length) { out.push('MODERATION & CONSEQUENCES'); m.mod.forEach(function (x) { out.push('- ' + x.t + ': ' + x.text); }); out.push(''); }
    out.push(m.outro);
    return out.join('\n');
  }
  function toPayload(m, o) {
    var fields = m.rules.map(function (x, i) { return { name: ((i + 1) + '. ' + (o.emoji ? x.e + ' ' : '') + x.t).slice(0, 256), value: x.text.slice(0, 1024) }; });
    if (m.mod.length) fields.push({ name: (o.emoji ? '⚖️ ' : '') + 'Moderation & consequences', value: m.mod.map(function (x) { return '**' + x.t + ':** ' + x.text; }).join('\n').slice(0, 1024) });
    return { embeds: [{ title: (o.emoji ? '📜 ' : '') + 'Server Rules', description: m.intro, color: 0x5865F2, fields: fields.slice(0, 25), footer: { text: m.outro.slice(0, 2048) } }] };
  }
  function split(text, limit) {
    if (text.length <= limit) return [text];
    var parts = [], cur = '';
    text.split('\n\n').forEach(function (blk) {
      if ((cur + '\n\n' + blk).length > limit && cur) { parts.push(cur); cur = blk; } else cur = cur ? cur + '\n\n' + blk : blk;
    });
    if (cur) parts.push(cur);
    return parts;
  }

  /* ---------------- UI ---------------- */
  var form = Object.assign({ type: 'community', strict: 3, count: 8, tone: 'friendly', server: '', language: 'English', contact: '', emoji: true, style: 'heading', pol: { ladder: true, zero: true, appeals: true, report: true, nomini: false, impartial: true, logs: false, final: true } }, CH.Store.get('form:rules', {}));
  form.pol = Object.assign({ ladder: true, zero: true, appeals: true, report: true, nomini: false, impartial: true, logs: false, final: true }, form.pol);
  function persist() { CH.Store.set('form:rules', form); }

  root.appendChild(ui.pageHead({ icon: 'shield', title: 'Server Rules Generator', desc: 'Choose your server type, strictness and tone. Get a clean rule set and a moderation policy you can paste straight into Discord.' }));

  var typeChips = ui.chips({ label: 'Server type', value: form.type, options: TYPES, onChange: function (v) { form.type = v; persist(); } });
  var strictLabels = ['Relaxed', 'Easygoing', 'Balanced', 'Strict', 'Zero tolerance'];
  var strictR = ui.range({ label: 'Strictness', min: 1, max: 5, value: form.strict, fmt: function (v) { return strictLabels[v - 1]; }, hint: 'Controls how many “strict-only” rules appear and how consequences are phrased.', onInput: function (v) { form.strict = v; persist(); } });
  var countR = ui.range({ label: 'Number of rules', min: 3, max: 20, value: form.count, onInput: function (v) { form.count = v; persist(); } });
  var toneChips = ui.chips({ label: 'Tone', sm: true, value: form.tone, options: [{ value: 'friendly', label: 'Friendly' }, { value: 'neutral', label: 'Neutral' }, { value: 'formal', label: 'Formal' }, { value: 'firm', label: 'Firm' }, { value: 'playful', label: 'Playful' }], onChange: function (v) { form.tone = v; persist(); } });
  function tf(key, label, ph, hint) { return ui.field({ label: label, value: form[key], placeholder: ph, hint: hint, onInput: function (v) { form[key] = v; persist(); } }); }
  var POL = [['ladder', 'Warning ladder (warn → timeout → kick → ban)'], ['zero', 'Instant bans for severe violations'], ['appeals', 'Appeals process'], ['report', 'How to report problems'], ['nomini', 'No mini-modding'], ['impartial', 'Staff follow the rules too'], ['logs', 'Moderation actions are logged'], ['final', 'Staff have the final say']];
  var polSw = POL.map(function (p) { return ui.switch({ label: p[1], checked: form.pol[p[0]], onChange: function (v) { form.pol[p[0]] = v; persist(); } }); });
  var styleF = ui.field({ label: 'Layout', type: 'select', value: form.style, options: [{ value: 'heading', label: 'Headings (## 1. Title)' }, { value: 'bold', label: 'Bold titles' }, { value: 'compact', label: 'Compact (1. Title — text)' }, { value: 'emoji', label: 'Emoji numbers (1️⃣)' }], onInput: function (v) { form.style = v; persist(); paint(); } });
  var emojiSw = ui.switch({ label: 'Use emoji', checked: form.emoji, onChange: function (v) { form.emoji = v; persist(); paint(); } });

  var formCard = el('div', { class: 'card card-pad tool-form' },
    el('div', { class: 'form-section' }, el('h3', null, 'What kind of server is it?'), typeChips.el),
    el('div', { class: 'form-section' }, el('h3', null, 'Style'), strictR.el, countR.el, el('div', { class: 'field' }, el('div', { class: 'label' }, 'Tone'), toneChips.el)),
    el('div', { class: 'form-section' }, el('h3', null, 'Details'), el('div', { class: 'form-grid' }, tf('server', 'Server name', 'Nebula Lounge').el, tf('language', 'Chat language', 'English').el),
      tf('contact', 'How members reach staff', 'open a ticket in #support', 'Finishes the sentence “To report an issue, …”.').el),
    el('div', { class: 'form-section' }, el('h3', null, 'Staff & moderation policy'), el('div', { class: 'stack-sm' }, polSw.map(function (s) { return s.el; }))),
    el('div', { class: 'form-section' }, el('h3', null, 'Output'), styleF.el, emojiSw.el),
    el('div', { class: 'sticky-actions' }, ui.btn('Generate rules', { kind: 'primary', icon: 'sparkle', onclick: run })));

  var model = null, tab = 'discord';
  var area = el('textarea', { class: 'textarea mono', rows: 18, spellcheck: 'false', 'aria-label': 'Generated rules (editable)', style: { minHeight: '320px', fontSize: '13px' } });
  var previewBox = el('div', { class: 'preview-stage', hidden: true, style: { borderRadius: '12px', border: '1px solid var(--line)' } });
  var info = el('div', { class: 'hint', 'aria-live': 'polite' });
  var parts = el('div', { class: 'stack-sm' });
  var tabs = ui.tabs({ label: 'Output format', value: tab, items: [{ id: 'discord', label: 'Discord message' }, { id: 'plain', label: 'Plain text' }, { id: 'embed', label: 'Embed JSON' }, { id: 'preview', label: 'Preview' }], onChange: function (v) { tab = v; paint(); } });
  area.addEventListener('input', function () { updInfo(); if (tab === 'preview') drawPreview(); });

  function currentText() { return area.value; }
  function paint() {
    if (!model) return;
    var o = { style: form.style, emoji: form.emoji };
    previewBox.hidden = tab !== 'preview'; area.hidden = tab === 'preview';
    if (tab === 'discord') area.value = fmtDiscord(model, o);
    else if (tab === 'plain') area.value = fmtPlain(model, o);
    else if (tab === 'embed') area.value = JSON.stringify(toPayload(model, o), null, 2);
    else { area.value = fmtDiscord(model, o); drawPreview(); }
    updInfo();
  }
  function drawPreview() { CH.clear(previewBox); previewBox.appendChild(CH.preview.message({ content: area.value, username: model.server === 'our server' ? 'Rules' : model.server }, { theme: 'dark' })); }
  function updInfo() {
    var t = area.value, msg = [t.length + ' characters'];
    if (tab === 'discord' || tab === 'preview') {
      var p = split(t, 2000);
      msg.push(p.length > 1 ? 'Over Discord’s 2,000-character message limit — split below into ' + p.length + ' messages.' : 'Fits in one Discord message.');
      CH.clear(parts);
      if (p.length > 1) p.forEach(function (chunk, i) { parts.appendChild(el('div', { class: 'row' }, ui.btn('Copy part ' + (i + 1) + ' (' + chunk.length + ')', { sm: true, icon: 'copy', onclick: function () { CH.copy(chunk); } }))); });
    } else CH.clear(parts);
    if (tab === 'embed') { try { var j = JSON.parse(t), fl = j.embeds[0].fields.length; msg.push(fl + ' fields (Discord allows 25)'); } catch (e) { msg.push('JSON edited — may be invalid'); } }
    info.textContent = msg.join(' · ');
  }
  function bodyFor() { return tab === 'embed' ? fmtDiscord(model, { style: form.style, emoji: form.emoji }) : area.value; }

  var actions = el('div', { class: 'row' },
    ui.btn('Copy', { icon: 'copy', kind: 'primary', sm: true, onclick: function () { CH.copy(area.hidden ? fmtDiscord(model, { style: form.style, emoji: form.emoji }) : area.value); } }),
    ui.btn('Regenerate', { icon: 'refresh', sm: true, onclick: run }),
    ui.btn('Save', { icon: 'save', sm: true, onclick: function () { var body = fmtDiscord(model, { style: form.style, emoji: form.emoji }); var r = CH.Saved.add({ type: 'rules', title: 'Rules — ' + model.server + ' (' + model.rules.length + ')', body: body, data: { payload: toPayload(model, { emoji: form.emoji }) } }); CH.toast(r.dupe ? 'Already in Saved Creations' : 'Saved to your library'); } }),
    ui.btn('Open in Embed Builder', { icon: 'embed', sm: true, onclick: function () { CH.handoff.set('embed', toPayload(model, { emoji: form.emoji })); location.hash = '#/embeds'; } }),
    ui.btn('Download', { icon: 'download', sm: true, kind: 'ghost', onclick: function () { CH.download('server-rules.md', fmtDiscord(model, { style: form.style, emoji: form.emoji }) + '\n', 'text/markdown'); } }));

  var note = ui.callout('info', el('strong', null, 'Tip: '), 'Discord’s Community features let you add a rules screen that new members must accept. Paste these rules there or in a read-only #rules channel. Rules guidance here is a starting point, not legal advice — adapt it to your community.');
  var metaNote = el('div', { class: 'hint' });
  var right = el('div', { class: 'card card-pad stack' }, el('div', { class: 'results-head', style: { marginBottom: 0 } }, el('h2', null, 'Your rules'), actions), tabs.el, area, previewBox, info, parts, metaNote, note);
  root.appendChild(el('div', { class: 'tool-layout' }, formCard, right));

  function run() {
    model = generate(form);
    metaNote.textContent = model.rules.length < form.count ? 'Only ' + model.pool + ' rules apply to this server type, so that’s all you get — tighter rule sets are easier to enforce.' : '';
    paint();
  }
  run();
});
