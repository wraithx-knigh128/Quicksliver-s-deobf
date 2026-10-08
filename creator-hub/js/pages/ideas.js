/* Server Ideas — curated concepts plus an "idea roulette" that mixes niche × format × hook × twist. */
CH.page('ideas', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon, pick = CH.pick, fresh = CH.fresh;

  var IDEAS = [
    { t: 'Ranked Ladder Lounge', c: 'Gaming', pitch: 'One competitive game, with players grouped by rank, weekly scrims and a culture of improving together.', ch: ['rank-check', 'scrim-finder', 'vod-review', 'patch-notes', 'Voice: Scrim 1 & 2'], ev: ['Weekly scrims', 'Monthly mini-tournament', 'VOD review night'], g: 'Share a free scrim calendar and partner with streamers who play the game.' },
    { t: 'Cozy Co-op Corner', c: 'Gaming', pitch: 'Relaxed multiplayer and co-op nights for people who’d rather laugh than climb a ladder.', ch: ['game-of-the-week', 'looking-for-group', 'screenshots', 'chill-voice'], ev: ['Co-op game night', 'Pick-the-game polls', 'Screenshot contest'], g: 'Lean into the no-pressure promise in your invite description.' },
    { t: 'Focus Hall', c: 'Study', pitch: 'Quiet voice rooms for body-doubling, with timers and daily goals that make working alone feel less lonely.', ch: ['today-i-will', 'wins', 'resources', 'Voice: Focus 1–3', 'Voice: Break Room'], ev: ['Pomodoro marathons', 'Exam-season sprints', 'Weekly reflection'], g: 'Post study-with-me clips and let members invite their study partners.' },
    { t: 'Language Exchange Café', c: 'Education', pitch: 'Pair learners with native speakers. Each language gets a channel, a role and a weekly conversation hour.', ch: ['introductions', 'spanish', 'japanese', 'language-help', 'Voice: Conversation Hour'], ev: ['Weekly speaking hour', 'Word-of-the-week', 'Writing exchange'], g: 'Cross-post to language-learning communities and offer tutor roles.' },
    { t: 'Seasonal Anime Club', c: 'Anime', pitch: 'Follow the season together with weekly episode threads, spoiler-safe lanes and end-of-season rankings.', ch: ['this-season', 'episode-threads', 'spoilers', 'recommendations', 'Voice: Watch Party'], ev: ['Weekly watch party', 'Opening/ending tier list', 'Season finale vote'], g: 'Release episode-discussion threads on a fixed schedule so people return weekly.' },
    { t: 'Indie Dev Guild', c: 'Creator', pitch: 'Solo and small-team developers swapping devlogs, playtests, art and music.', ch: ['devlogs', 'playtest-swap', 'art-requests', 'jam-announcements', 'code-help'], ev: ['Monthly game jam', 'Playtest Fridays', 'Postmortem talks'], g: 'Run a public jam with a theme vote — participants invite their teams.' },
    { t: 'Book Club Burrow', c: 'Community', pitch: 'A monthly pick, spoiler-safe discussion and the occasional author Q&A.', ch: ['this-months-book', 'spoilers', 'next-up-vote', 'reviews', 'Voice: Discussion Night'], ev: ['Monthly discussion', 'Reading sprints', 'Genre swap'], g: 'Let members vote on the pick — voters turn into regulars.' },
    { t: 'Art Critique Circle', c: 'Creator', pitch: 'Structured, kind feedback for artists, with weekly prompts and portfolio reviews.', ch: ['weekly-prompt', 'critique-forum', 'wip', 'portfolio-review', 'resources'], ev: ['Weekly prompt', 'Live drawing hour', 'Portfolio review night'], g: 'Highlight member of the week on your socials, with credit and a link.' },
    { t: 'Beginner Fitness Crew', c: 'Lifestyle', pitch: 'Friendly accountability for people starting out: check-ins, buddies and small weekly challenges. (General encouragement, not medical advice.)', ch: ['daily-check-in', 'buddy-finder', 'weekly-challenge', 'recipes', 'progress-pics'], ev: ['Weekly challenge', 'Monthly goals recap', 'Q&A with a coach'], g: 'Short check-in streaks create habits — and habits create regulars.' },
    { t: 'Local Meetup Hub', c: 'Community', pitch: 'A city or region server for planning real-world meetups, with channels per neighbourhood or interest.', ch: ['introductions', 'meetup-planning', 'recommendations', 'neighbourhoods', 'safety-tips'], ev: ['Monthly meetup', 'Coffee mornings', 'Newcomer welcome'], g: 'Partner with local venues and community boards for cross-promotion.' },
    { t: 'Creator Fanbase HQ', c: 'Creator', pitch: 'A home for a creator’s fans with early access, clip sharing and community events.', ch: ['new-uploads', 'clips', 'fan-content', 'q-and-a', 'supporters-only'], ev: ['Watch-along premieres', 'Community game night', 'Fan art spotlight'], g: 'Pin the invite in video descriptions and mention events during streams.' },
    { t: 'Trading Post', c: 'Marketplace', pitch: 'A vetted buy-and-sell space with a vouch system, middleman requests and strict post templates.', ch: ['how-to-trade', 'selling', 'buying', 'vouches', 'scam-reports'], ev: ['Weekly featured seller', 'Price-check Fridays'], g: 'Trust is the product — publish your safety rules and enforce them visibly.' },
    { t: 'Bot & Mod Lab', c: 'Dev', pitch: 'People building Discord bots and tools help each other with code, deployment and best practices.', ch: ['show-your-bot', 'code-help', 'api-news', 'resources', 'hack-night-voice'], ev: ['Hack night', 'Code review swap', 'Beginner workshop'], g: 'Answer questions quickly in public communities and link back.' },
    { t: 'Music Production Collective', c: 'Creator', pitch: 'Producers share works in progress, swap samples and match up for collabs.', ch: ['wip-feedback', 'sample-swap', 'collab-board', 'gear-talk', 'Voice: Listening Room'], ev: ['Monthly beat battle', 'Remix challenge', 'Listening party'], g: 'Compile members’ best tracks into a monthly playlist and share it.' }
  ];
  var NICHE = ['retro gaming', 'indie game devs', 'lo-fi music producers', 'language learners', 'sci-fi readers', 'budget home cooks', 'night-shift workers', 'digital artists', 'speedrunners', 'plant parents', 'tabletop RPG groups', 'study-with-me students', 'Linux tinkerers', 'film photography fans', 'anime watchers', 'amateur astronomers', 'thrifters and resellers'];
  var FORMAT = [['weekly challenges', ['weekly-challenge', 'submissions', 'results']], ['a ranked ladder', ['ladder', 'match-results', 'rules-and-seasons']], ['daily check-ins', ['daily-check-in', 'streaks', 'wins']], ['a monthly showcase', ['showcase', 'feedback', 'archive']], ['a mentor and mentee program', ['mentor-match', 'questions', 'office-hours']], ['co-working voice rooms', ['goals', 'Voice: Co-work 1–3', 'breaks']], ['a collab matchmaking board', ['collab-board', 'introductions', 'projects']], ['themed event nights', ['event-calendar', 'themes', 'recap']]];
  var HOOK = ['a public leaderboard', 'a free resource library', 'guest speakers once a month', 'member spotlights', 'seasonal tournaments', 'badge roles for milestones', 'a shared community playlist'];
  var TWIST = ['made for complete beginners', 'with a cozy, no-pressure vibe', 'run entirely by its members', 'that keeps one simple rule: be kind', 'with a tiny, invite-only core', 'anchored by one weekly ritual'];
  var STEPS = ['Write a three-line pitch and put it in your invite description.', 'Start with only 6–8 channels; add more when people ask.', 'Invite 10 friends or fans before you promote anywhere.', 'Run the first event in week one, even with five people.', 'Ask every new member what they came for and note the answers.'];

  var cat = 'All';
  root.appendChild(ui.pageHead({ icon: 'bulb', title: 'Server Ideas', desc: 'Concepts with channel plans, event ideas and growth hooks — or spin the roulette for something unexpected.' }));

  /* roulette */
  var roulette = ui.results({
    type: 'idea', label: 'Idea', titleOf: function (it) { return it.text.slice(0, 60); },
    regen: function () { return spin(); },
    extra: function (it) { return null; }
  });
  function spin() {
    var n = fresh('idea:n', NICHE), f = fresh('idea:f', FORMAT), h = fresh('idea:h', HOOK), tw = fresh('idea:t', TWIST);
    var text = 'A server for ' + n + ', built around ' + f[0] + ' and ' + h + ' — ' + tw + '.\n\nChannels to start with: ' + f[1].map(function (c) { return c.indexOf('Voice:') === 0 ? c : '#' + c; }).join(', ') + '.\nFirst step: ' + pick(STEPS);
    return { text: text, data: {} };
  }
  function roll() { roulette.set([spin(), spin(), spin()]); }
  root.appendChild(el('div', { class: 'card card-pad stack' },
    el('div', { class: 'results-head', style: { marginBottom: 0 } }, el('div', null, el('h2', null, 'Idea roulette'), el('p', { class: 'hint' }, 'Random combinations of niche, format, hook and twist.')), ui.btn('Spin again', { icon: 'dice', kind: 'primary', sm: true, onclick: roll })),
    roulette.el));
  roll();

  /* curated */
  var cats = ['All'].concat(Array.from(new Set(IDEAS.map(function (i) { return i.c; }))));
  var chips = ui.chips({ label: 'Category', sm: true, value: 'All', options: cats, onChange: function (v) { cat = v; paint(); } });
  var grid = el('div', { class: 'grid g-auto', style: { marginTop: '16px' } });
  root.appendChild(el('section', { class: 'section' }, el('div', { class: 'section-head' }, el('div', null, el('h2', null, 'Concepts worth building'), el('p', null, 'Each comes with a starter channel list, event ideas and a way to attract the first members.'))), chips.el, grid));

  function paint() {
    CH.clear(grid);
    IDEAS.filter(function (i) { return cat === 'All' || i.c === cat; }).forEach(function (i) {
      var body = i.t + ' (' + i.c + ')\n' + i.pitch + '\n\nChannels: ' + i.ch.join(', ') + '\nEvents: ' + i.ev.join('; ') + '\nGrowth: ' + i.g;
      var save = el('button', { type: 'button', class: 'btn btn-sm btn-ghost' }, icon('bookmark'), el('span', null, 'Save'));
      save.addEventListener('click', function () { var r = CH.Saved.add({ type: 'idea', title: i.t, body: body }); CH.toast(r.dupe ? 'Already saved' : 'Saved to your library'); });
      var copy = el('button', { type: 'button', class: 'btn btn-sm btn-ghost' }, icon('copy'), el('span', null, 'Copy'));
      copy.addEventListener('click', function () { CH.copy(body); });
      grid.appendChild(el('article', { class: 'card card-pad item-card tilt spot' },
        el('div', { class: 'row-between' }, el('h3', null, i.t), el('span', { class: 'tag' }, i.c)),
        el('p', null, i.pitch),
        el('div', null, el('div', { class: 'label' }, 'Starter channels'), el('div', { class: 'tags', style: { marginTop: '6px' } }, i.ch.map(function (c) { return el('span', { class: 'tag' }, c.indexOf('Voice:') === 0 ? c : '#' + c); }))),
        el('div', null, el('div', { class: 'label' }, 'Events'), el('ul', { style: { marginTop: '6px' } }, i.ev.map(function (e) { return el('li', null, e); }))),
        el('div', { class: 'meta-line' }, 'Growth: ' + i.g),
        el('div', { class: 'foot' }, copy, save, ui.btn('Channel layout', { href: '#/channels', sm: true, kind: 'ghost', icon: 'hash' }))));
    });
  }
  paint();
});
