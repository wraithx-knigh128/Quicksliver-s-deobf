/* Home */
CH.page('home', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon;
  var tools = CH.routes.filter(function (r) { return r.tool; });

  function toolCard(r) {
    return el('a', { class: 'card tool-card tilt spot reveal', href: '#/' + r.id },
      el('div', { class: 'tc-ic' }, icon(r.icon)),
      el('div', null, el('h3', null, r.title), el('p', null, r.desc)),
      el('span', { class: 'tc-go' }, 'Open', icon('arrowRight')));
  }

  /* ----- Hero ----- */
  var demo = CH.preview.message({
    username: 'Nebula Bot',
    embeds: [{
      title: 'Welcome to Nebula Lounge',
      description: 'Grab your roles in **#roles**, say hi in <#1100000000000000001> and skim the [rules](https://example.com) before you dive in.\n-# Updated every Friday',
      color: 0x7c6cff,
      fields: [{ name: 'Members', value: '1,204', inline: true }, { name: 'Next event', value: 'Fri · 8 PM', inline: true }, { name: 'Vibe', value: 'Chill', inline: true }],
      footer: { text: 'Nebula Lounge' }, timestamp: new Date().toISOString()
    }],
    components: [{ type: 1, components: [{ type: 2, style: 5, label: 'Rules', url: 'https://example.com' }, { type: 2, style: 5, label: 'Roles', url: 'https://example.com' }] }]
  }, { compact: true });

  var scene = el('div', { class: 'scene', 'aria-hidden': 'true' }, el('div', { class: 'scene-in' },
    el('div', { class: 'orb' }),
    el('div', { class: 'sc sc-a' }, demo),
    el('div', { class: 'sc sc-b' }, el('span', { class: 'lbl' }, 'Username'), el('div', { class: 'nm grad-text' }, 'kestrel.vox'), el('div', { class: 'hint', style: { marginTop: '6px' } }, '9 chars · valid handle')),
    el('div', { class: 'sc sc-c' }, el('span', { class: 'lbl' }, 'Bio · 74/190'), el('div', { class: 'bio' }, 'night shift energy · lo-fi on loop\nrhythm games, ramen, 3am ideas'))));

  var hero = el('section', { class: 'hero' },
    el('div', { class: 'aurora', 'aria-hidden': 'true' }),
    el('div', null,
      el('span', { class: 'eyebrow' }, el('i'), 'Free · private · runs in your browser'),
      el('h1', null, 'Build the ', el('span', { class: 'grad-text' }, 'Discord server'), ' people remember.'),
      el('p', { class: 'lead' }, 'A creator toolkit for Discord: a live embed builder, bios, usernames, rules, announcements, roles and channel layouts — fast, accurate about what Discord supports, and nothing leaves your device.'),
      el('div', { class: 'hero-cta' },
        ui.btn('Open Embed Builder', { href: '#/embeds', kind: 'primary', lg: true, icon: 'embed' }),
        ui.btn('Browse all tools', { href: '#/tools', lg: true, icon: 'grid' })),
      el('div', { class: 'kpis' },
        el('div', { class: 'kpi' }, el('b', null, String(tools.length)), el('span', null, 'tools & generators')),
        el('div', { class: 'kpi' }, el('b', null, '0'), el('span', null, 'accounts or trackers')),
        el('div', { class: 'kpi' }, el('b', null, '100%'), el('span', null, 'processed locally')))),
    scene);

  /* ----- Tool grid ----- */
  var featured = ['embeds', 'bio', 'username', 'rules', 'announcements', 'roles', 'channels', 'templates'].map(function (id) { return CH.routeById[id]; });
  var toolsSec = el('section', { class: 'section' },
    el('div', { class: 'section-head reveal' }, el('div', null, el('h2', null, 'Everything for your server'), el('p', null, 'Pick a tool, tweak a few options, copy the result. Save anything to your library.')),
      ui.btn('All tools', { href: '#/tools', sm: true, kind: 'ghost', icon: 'arrowRight' })),
    el('div', { class: 'grid g4' }, featured.map(toolCard)));

  /* ----- Principles ----- */
  function pr(ic, t, d) { return el('div', { class: 'card card-pad reveal' }, el('div', { class: 'tc-ic', style: { marginBottom: '12px', width: '40px', height: '40px', borderRadius: '12px', display: 'grid', placeItems: 'center', background: 'rgba(var(--accent-rgb),.16)', color: 'var(--accent-2)' } }, icon(ic)), el('h3', { class: 'card-title' }, t), el('p', { class: 'card-sub', style: { marginTop: '6px', fontSize: '14px', lineHeight: '1.55' } }, d)); }
  var principles = el('section', { class: 'section' },
    el('div', { class: 'section-head reveal' }, el('div', null, el('h2', null, 'Built with care'))),
    el('div', { class: 'grid g3' },
      pr('check', 'Honest about Discord', 'Every limit — 6,000 characters per message, who can send embeds, what buttons need a bot — is explained, not glossed over.'),
      pr('lock', 'Private by default', 'No sign-up, no analytics, no uploads. Saved creations live in this browser and can be exported or wiped any time.'),
      pr('sparkle', 'Fast everywhere', 'Tools load on demand, effects scale to your device, and reduced-motion is respected. Phones get the lightweight version automatically.')));

  /* ----- Steps ----- */
  var steps = el('section', { class: 'section' },
    el('div', { class: 'section-head reveal' }, el('h2', null, 'How it works')),
    el('div', { class: 'grid g3 steps' },
      el('div', { class: 'card step reveal' }, el('h3', null, 'Choose a tool'), el('p', null, 'Use the sidebar or press ' + (/Mac/.test(navigator.platform) ? '⌘K' : 'Ctrl K') + ' to search every tool, template and bot.')),
      el('div', { class: 'card step reveal' }, el('h3', null, 'Shape the output'), el('p', null, 'Style, tone, length, keywords — generators give several variations, and every result is editable.')),
      el('div', { class: 'card step reveal' }, el('h3', null, 'Copy, export or save'), el('p', null, 'One click to copy. Embeds export as webhook JSON, discord.js, discord.py or cURL.'))));

  /* ----- Recent saves ----- */
  var recent = CH.Saved.all().slice(0, 3), recentSec = null;
  if (recent.length) {
    recentSec = el('section', { class: 'section' },
      el('div', { class: 'section-head reveal' }, el('h2', null, 'Pick up where you left off'), ui.btn('Open library', { href: '#/saved', sm: true, kind: 'ghost', icon: 'arrowRight' })),
      el('div', { class: 'grid g3' }, recent.map(function (s) {
        return el('a', { class: 'card card-pad reveal spot', href: '#/saved' }, el('span', { class: 'tag' }, s.type), el('p', { style: { marginTop: '10px', color: 'var(--text-2)', fontSize: '14px', display: '-webkit-box', WebkitLineClamp: '3', WebkitBoxOrient: 'vertical', overflow: 'hidden', whiteSpace: 'pre-wrap' } }, s.body.slice(0, 160)));
      })));
  }

  var cta = el('section', { class: 'section' },
    el('div', { class: 'cta-band reveal' },
      el('div', null, el('h2', null, 'Starting a new server?'), el('p', null, 'Generate a channel layout, a role hierarchy and a rules set in a few minutes, then drop in a welcome embed.')),
      el('div', { class: 'row' }, ui.btn('Channel layout', { href: '#/channels', kind: 'primary', icon: 'hash' }), ui.btn('Server ideas', { href: '#/ideas', icon: 'bulb' }))));

  root.appendChild(hero); root.appendChild(toolsSec); root.appendChild(principles); root.appendChild(steps);
  if (recentSec) root.appendChild(recentSec);
  root.appendChild(cta);
});
