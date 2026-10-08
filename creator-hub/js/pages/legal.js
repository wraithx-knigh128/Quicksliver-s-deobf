/* Terms & Policies */
CH.page('legal', function (root) {
  var el = CH.el, ui = CH.ui, icon = CH.icon;
  var year = new Date().getFullYear();

  root.appendChild(ui.pageHead({ icon: 'file', title: '© Terms & Policies', badge: 'Last updated Oct ' + year, desc: 'The rules of the road for CordX by Wraith: how you may use it, how your data is handled, and who owns what.' }));
  root.appendChild(ui.callout('warn', el('strong', null, 'Plain-language summary, not legal advice. '), 'These policies describe how this free tool works. If you rely on CordX commercially, have your own counsel review them.'));

  var sections = [
    ['terms', 'Terms of use', [
      'By using CordX you agree to these terms. If you don’t agree, please don’t use the site.',
      'CordX is a free, client-side toolkit for Discord community owners and creators. It is provided “as is”, without warranties of any kind. We don’t guarantee that generated text, names, rules, roles or layouts are accurate, original, available (for example, that a username is not taken) or suitable for your community.',
      'You are responsible for what you post. Anything you send to Discord — through a webhook, a bot or by copy-paste — must follow Discord’s Terms of Service and Community Guidelines and applicable law. Don’t use CordX to harass, spam, deceive, scam, impersonate others or evade moderation.',
      'Don’t attempt to disrupt or reverse-engineer the service in ways that harm others. You may fork or adapt the source only as permitted by the licence in the repository.',
      'To the maximum extent permitted by law, Wraith is not liable for indirect or consequential loss arising from your use of CordX, including content you publish with it.'
    ]],
    ['privacy', 'Privacy', [
      'CordX has no accounts, analytics or advertising cookies. Settings, drafts, form memory and saved items are kept in your browser’s localStorage (keys beginning “ch:”). Clearing site data, or using Settings → Erase everything, removes them.',
      'Generators run entirely in your browser; the text you type is not uploaded to us. Network requests are limited to: the web-font stylesheet, images and custom emoji you choose to preview (fetched directly from their hosts or Discord’s CDN), and a webhook POST to Discord only when you press “Send message”. Webhook URLs are held in memory and never stored.',
      'The host serving this site (for example, a CDN or hosting provider) may keep standard server logs such as IP address and user agent for security and operations.',
      'Children: Discord requires users to meet its minimum age. CordX is not directed at children under that age.'
    ]],
    ['ip', 'Copyright & licence', [
      '© ' + year + ' CordX by Wraith. All rights reserved except where the repository’s licence says otherwise. The site design, code, copy and original illustrations are the work of Wraith.',
      'Text you generate is yours to use. Because it is assembled from word banks and patterns, similar output may be produced for other people; we make no claim of exclusivity.',
      'Images you paste into the embed builder, or add through the optional character-image setting, remain the property of their owners. Only use images you have the right to use.'
    ]],
    ['tm', 'Trademarks & fan content', [
      'Discord is a trademark of Discord Inc. X-Men, Cyclops, Quicksilver, Wolverine and related names and characters are trademarks and copyrights of Marvel and their respective owners. CordX is an independent fan project and is not affiliated with, sponsored or endorsed by Discord Inc., Marvel or The Walt Disney Company.',
      'The “Optic”, “Speed” and “Claw” interfaces are fan tributes: original colour schemes, effects and illustrations inspired by those characters. No film stills, photographs or official artwork are included. If a rights holder asks us to change or remove something, we will.',
      'Bot names in the directory belong to their owners and are listed for information only.'
    ]],
    ['cred', 'Credits', [
      'Design, code and illustrations: Wraith. Typefaces: Inter, Sora, Anton, Fredoka and Instrument Serif via Google Fonts (SIL Open Font Licence). Icons are original line icons.',
      'Questions or takedown requests: open an issue on the project’s repository.'
    ]]
  ];

  var toc = el('nav', { class: 'card card-pad', 'aria-label': 'Contents' }, el('div', { class: 'label', style: { marginBottom: '8px' } }, 'On this page'),
    el('div', { class: 'tags' }, sections.map(function (s) {
      var a = el('a', { class: 'tag', href: '#/legal' }, s[1]); a.addEventListener('click', function (e) { e.preventDefault(); var t = document.getElementById('lg-' + s[0]); if (t) t.scrollIntoView({ behavior: 'smooth', block: 'start' }); }); return a;
    })));
  root.appendChild(toc);
  sections.forEach(function (s) {
    root.appendChild(el('section', { class: 'section', id: 'lg-' + s[0], style: { scrollMarginTop: '80px' } },
      el('div', { class: 'section-head' }, el('h2', null, s[1])),
      el('div', { class: 'prose' }, s[2].map(function (p) { return el('p', null, p); }))));
  });
  root.appendChild(el('p', { class: 'hint', style: { marginTop: '34px' } }, '© ' + year + ' CordX by Wraith. All rights reserved.'));
});
