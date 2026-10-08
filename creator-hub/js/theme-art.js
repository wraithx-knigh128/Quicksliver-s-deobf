/* CordX — original sticker art for the character interfaces.
   Everything here is hand-built SVG (no photographs, no official artwork). Each character is parametric:
   a pose changes the head turn, tilt, expression and props, so one drawing yields many "angles".
   If CORDX.characterImages[theme] lists your own licensed images, those are used instead. */
(function () {
  'use strict';
  var CH = window.CH, CORDX = window.CORDX, uid = 0;

  var PAL = {
    optic: { skin: ['#f6cdaa', '#e9a981', '#c47a5a'], hair: '#5a3826', hairHi: '#946040', suit: '#181c2a', suitHi: '#2c3450', collar: '#a31528', glow: '#ff2d44' },
    speed: { skin: ['#f8dccb', '#edbea6', '#cd8e78'], hair: '#d3d6dc', hairHi: '#ffffff', hairLo: '#8d93a0', suit: '#171920', suitHi: '#2d313c', plate: '#c3c8d3', glow: '#9cc0ff' },
    claw: { skin: ['#f0c09d', '#dc9a75', '#b66a4a'], hair: '#1b1618', hairHi: '#4a3c42', suit: '#d4d7cf', suitLo: '#9a9d95', metal: '#e8eef5', glow: '#ffc21a' },
    wraith: { skin: ['#e9d6ff', '#c9a8f0', '#8f6fc4'], hair: '#14122a', hairHi: '#6b5cff', suit: '#14102a', suitHi: '#2c2468', glow: '#38e8ff' }
  };

  function figure(theme, p) {
    var C = PAL[theme] || PAL.wraith, n = ++uid, id = function (s) { return s + n; };
    var yaw = p.yaw || 0, pitch = p.pitch || 0, tilt = p.tilt || 0, fx = yaw * 14, fy = -pitch * 8, sx = 1 - Math.abs(yaw) * .1;
    var s = '<svg viewBox="0 0 300 340" xmlns="http://www.w3.org/2000/svg" focusable="false" aria-hidden="true">';
    s += '<defs>' +
      '<linearGradient id="' + id('sk') + '" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="' + C.skin[0] + '"/><stop offset=".6" stop-color="' + C.skin[1] + '"/><stop offset="1" stop-color="' + C.skin[2] + '"/></linearGradient>' +
      '<linearGradient id="' + id('su') + '" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="' + C.suitHi + '"/><stop offset="1" stop-color="' + C.suit + '"/></linearGradient>' +
      '<linearGradient id="' + id('vg') + '" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".5"/></linearGradient>' +
      '<radialGradient id="' + id('gl') + '"><stop offset="0" stop-color="' + C.glow + '" stop-opacity=".85"/><stop offset="1" stop-color="' + C.glow + '" stop-opacity="0"/></radialGradient>' +
      '<linearGradient id="' + id('mt') + '" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#8f9aa8"/><stop offset=".4" stop-color="#ffffff"/><stop offset="1" stop-color="#7b8694"/></linearGradient>' +
      '<linearGradient id="' + id('lz') + '" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffe3a8"/><stop offset=".55" stop-color="#e79a38"/><stop offset="1" stop-color="#8a4a12"/></linearGradient>' +
      '<clipPath id="' + id('cp') + '"><path d="M-50 -30C-50 -86 50 -86 50 -30L50 16C48 52 30 80 9 86L-9 86C-30 80 -48 52 -50 16Z"/></clipPath></defs>';
    if (p.fire || theme === 'optic') s += '<circle cx="' + (150 + fx * 1.2) + '" cy="124" r="120" fill="url(#' + id('gl') + ')" opacity="' + (p.fire ? .9 : .35) + '"/>';

    /* torso */
    s += '<path d="M14 340V268C14 238 66 224 108 218H192C234 224 286 238 286 268V340Z" fill="url(#' + id('su') + ')"/>';
    if (theme === 'optic') {
      s += '<path d="M104 218L150 292L196 218Z" fill="#0d0f18"/><path d="M96 214Q150 246 204 214L196 232Q150 262 104 232Z" fill="' + C.collar + '"/>' +
        '<path d="M150 292V340" stroke="#0a0c14" stroke-width="3"/><path d="M60 250L50 340M240 250L250 340" stroke="' + C.suitHi + '" stroke-width="3" opacity=".6"/>';
    } else if (theme === 'speed') {
      s += '<path d="M96 214L128 214L150 256L172 214L204 214L214 244L150 300L86 244Z" fill="' + C.plate + '"/><path d="M96 214L128 214L136 232L104 240Z" fill="#fff" opacity=".7"/>' +
        '<path d="M30 276C70 262 90 270 100 300M270 276C230 262 210 270 200 300" stroke="' + C.plate + '" stroke-width="7" fill="none" stroke-linecap="round"/>' +
        '<path d="M120 300L150 330L180 300" stroke="#0b0c10" stroke-width="3" fill="none"/>';
    } else if (theme === 'claw') {
      s += '<path d="M14 340V268C14 238 66 224 108 218H192C234 224 286 238 286 268V340Z" fill="url(#' + id('sk') + ')"/>' +
        '<path d="M70 340V250L108 226L130 244L150 270L170 244L192 226L230 250V340Z" fill="' + C.suit + '"/><path d="M130 244L150 270L170 244" fill="none" stroke="' + C.suitLo + '" stroke-width="3"/>' +
        '<path d="M96 230L84 340M204 230L216 340" stroke="' + C.suitLo + '" stroke-width="3" opacity=".6"/><circle cx="150" cy="292" r="5" fill="' + C.suitLo + '"/>';
    } else {
      s += '<path d="M100 218L150 280L200 218" fill="none" stroke="' + C.suitHi + '" stroke-width="6"/>';
    }

    s += '<path d="M14 268C14 238 66 224 108 218H192C234 224 286 238 286 268" fill="none" stroke="' + C.glow + '" stroke-width="3" opacity=".55"/><path d="M14 340V268C14 238 66 224 108 218H192C234 224 286 238 286 268V340Z" fill="url(#' + id('vg') + ')"/>';
    /* neck */
    s += '<path d="M122 190L120 236Q150 252 180 236L178 190Z" fill="' + C.skin[2] + '"/><path d="M122 196Q150 222 178 196L178 214Q150 236 122 214Z" fill="#000" opacity=".28"/>';

    /* head */
    s += '<g transform="translate(150 126) rotate(' + tilt + ')">';
    // back hair
    if (theme === 'speed') s += '<path d="M-64 -4C-82 -92 74 -104 68 -2L60 36L42 -6L-42 -6L-58 40Z" fill="' + C.hairLo + '"/>';
    if (theme === 'claw') s += '<path d="M-56 -20C-62 -96 -8 -112 22 -102L62 -74C74 -58 64 -30 56 -22L40 -50L-40 -50Z" fill="' + C.hair + '"/>';
    // ears
    s += '<ellipse cx="-52" cy="6" rx="9" ry="15" fill="url(#' + id('sk') + ')"/><ellipse cx="52" cy="6" rx="9" ry="15" fill="url(#' + id('sk') + ')"/>';
    // face
    s += '<path d="M-50 -30C-50 -86 50 -86 50 -30L50 16C48 52 30 80 9 86L-9 86C-30 80 -48 52 -50 16Z" fill="url(#' + id('sk') + ')"/>';
    s += '<g clip-path="url(#' + id('cp') + ')"><rect x="-60" y="-100" width="120" height="200" fill="#000" opacity=".0"/><ellipse cx="' + (28 + fx) + '" cy="20" rx="40" ry="90" fill="#5a2a1a" opacity=".16"/>';
    if (theme === 'claw') s += '<path d="M-48 20C-40 56 -18 80 0 82C18 80 40 56 48 20L40 22C30 50 14 62 0 62C-14 62 -30 50 -40 22Z" fill="#241a1c" opacity=".34"/>';
    s += '</g>';
    // lighting: cheekbone + brow highlights, jaw shadow, coloured rim light on the shadow side
    s += '<g clip-path="url(#' + id('cp') + ')" opacity=".9"><ellipse cx="' + (-24 + fx * .6) + '" cy="22" rx="14" ry="9" fill="#fff" opacity=".16"/><ellipse cx="' + (-12 + fx * .5) + '" cy="-52" rx="22" ry="9" fill="#fff" opacity=".14"/>' +
      '<path d="M-50 40C-30 70 -10 82 0 86C20 82 44 56 50 30L50 90L-50 90Z" fill="#2a120c" opacity=".2"/>' +
      '<path d="M49 -28L50 16C48 52 30 80 9 86" fill="none" stroke="' + C.glow + '" stroke-width="5" opacity=".6"/></g>';
    // features
    s += '<g transform="translate(' + fx + ' ' + fy + ') scale(' + sx + ' 1)">';
    var brow = theme === 'wraith' ? C.hairHi : C.hair, angry = p.expr === 'shout' || p.expr === 'smirk' ? 6 : 0;
    var hasEyes = theme !== 'optic';
    s += '<path d="M-36 ' + (-14 + angry) + 'Q-22 -22 -8 ' + (-12 - angry) + '" stroke="' + brow + '" stroke-width="6" fill="none" stroke-linecap="round"/><path d="M36 ' + (-14 + angry) + 'Q22 -22 8 ' + (-12 - angry) + '" stroke="' + brow + '" stroke-width="6" fill="none" stroke-linecap="round"/>';
    if (hasEyes && theme !== 'speed') {
      s += '<ellipse cx="-22" cy="2" rx="10" ry="6.5" fill="#fff"/><ellipse cx="22" cy="2" rx="10" ry="6.5" fill="#fff"/><circle cx="' + (-22 + yaw * 4) + '" cy="' + (2 - pitch * 2) + '" r="4.6" fill="#2a1d18"/><circle cx="' + (22 + yaw * 4) + '" cy="' + (2 - pitch * 2) + '" r="4.6" fill="#2a1d18"/>';
    }
    s += '<path d="M0 8L-6 38Q0 44 8 38" stroke="' + C.skin[2] + '" stroke-width="3.5" fill="none" stroke-linecap="round" opacity=".9"/>';
    var m = p.expr;
    if (m === 'shout') s += '<path d="M-16 56Q0 74 16 56Q0 62 -16 56Z" fill="#4a1218"/><path d="M-12 57Q0 60 12 57L10 61Q0 63 -10 61Z" fill="#fff"/>';
    else if (m === 'wow') s += '<ellipse cx="0" cy="60" rx="9" ry="11" fill="#4a1218"/>';
    else if (m === 'smirk') s += '<path d="M-14 60Q4 68 18 54" stroke="#6b2a2a" stroke-width="4" fill="none" stroke-linecap="round"/>';
    else s += '<path d="M-14 59Q0 63 14 59" stroke="#6b2a2a" stroke-width="4" fill="none" stroke-linecap="round"/>';
    s += '</g>';

    // front hair + accessories
    if (theme === 'optic') {
      s += '<path d="M-56 -26C-60 -100 42 -108 60 -50C42 -68 14 -60 -8 -42C-24 -32 -42 -30 -56 -26Z" fill="' + C.hair + '"/><path d="M-30 -74C-6 -92 28 -88 44 -66" stroke="' + C.hairHi + '" stroke-width="5" fill="none" stroke-linecap="round" opacity=".8"/><path d="M-40 -50C-20 -70 10 -72 30 -58M-46 -38C-30 -54 -6 -56 12 -46M0 -80C16 -80 30 -72 40 -60" stroke="#000" stroke-width="2" fill="none" opacity=".3"/>';
      s += '<g transform="translate(' + fx + ' ' + fy + ')"><rect x="-58" y="-12" width="116" height="28" rx="13" fill="#140a0d" stroke="#3a1018" stroke-width="3"/>' +
        '<rect x="-48" y="-5" width="96" height="12" rx="6" fill="' + C.glow + '"/><rect x="-46" y="-4" width="92" height="4" rx="2" fill="#ffd0d4" opacity=".85"/>' +
        '<circle cx="0" cy="1" r="42" fill="url(#' + id('gl') + ')" opacity="' + (p.fire ? 1 : .6) + '"/><path d="M-58 2L-66 -4M58 2L66 -4" stroke="#140a0d" stroke-width="6" stroke-linecap="round"/></g>';
    } else if (theme === 'speed') {
      s += '<path d="M-58 -34L-44 -86L-26 -54L-6 -94L10 -56L32 -90L42 -52L62 -66L54 -28C22 -50 -22 -50 -58 -34Z" fill="' + C.hair + '"/><path d="M-30 -62L-20 -78M6 -66L14 -84M34 -62L44 -76" stroke="' + C.hairHi + '" stroke-width="4" stroke-linecap="round"/>';
      var gy = p.up ? -46 : 0;
      s += '<g transform="translate(' + fx + ' ' + (fy + gy) + ')"><path d="M-62 -4Q0 -22 62 -4L62 10Q0 -8 -62 10Z" fill="#23252c"/>' +
        '<rect x="-52" y="-14" width="48" height="30" rx="14" fill="url(#' + id('lz') + ')" stroke="#c9ced8" stroke-width="5"/><rect x="4" y="-14" width="48" height="30" rx="14" fill="url(#' + id('lz') + ')" stroke="#c9ced8" stroke-width="5"/>' +
        '<path d="M-44 -6Q-30 -12 -14 -6" stroke="#fff" stroke-width="3" fill="none" opacity=".75" stroke-linecap="round"/><path d="M12 -6Q26 -12 42 -6" stroke="#fff" stroke-width="3" fill="none" opacity=".75" stroke-linecap="round"/></g>';
    } else if (theme === 'claw') {
      s += '<path d="M-56 -22C-60 -86 -6 -104 22 -96L60 -72C70 -58 62 -34 54 -26C40 -52 12 -58 -10 -46C-30 -36 -44 -30 -56 -22Z" fill="' + C.hair + '"/>' +
        '<path d="M-48 -30L-92 -112L-26 -76Z" fill="' + C.hair + '"/><path d="M48 -30L92 -112L26 -76Z" fill="' + C.hair + '"/><path d="M-26 -78C-4 -92 22 -88 40 -70" stroke="' + C.hairHi + '" stroke-width="5" fill="none" stroke-linecap="round"/>';
    } else {
      s += '<path d="M-54 -26C-56 -94 40 -104 58 -52C40 -68 12 -60 -10 -44C-26 -34 -42 -30 -54 -26Z" fill="' + C.hair + '"/><path d="M-28 -74C-4 -90 26 -86 44 -64" stroke="' + C.hairHi + '" stroke-width="5" fill="none" stroke-linecap="round"/>';
    }
    s += '</g>';

    /* props */
    if (theme === 'claw' && p.claws) {
      s += '<g transform="translate(236 322) rotate(6)"><path d="M-26 -10L-18 -150L-6 -10Z M-4 -10L6 -170L16 -10Z M18 -10L30 -150L38 -10Z" fill="url(#' + id('mt') + ')" stroke="#5c6672" stroke-width="1.5"/>' +
        '<rect x="-34" y="-14" width="82" height="34" rx="14" fill="url(#' + id('sk') + ')"/><path d="M-14 -10V20M8 -10V20M28 -10V20" stroke="#b66a4a" stroke-width="2"/></g>';
    }
    if (theme === 'speed' && p.bolt) s += '<path d="M232 36L204 92H222L206 140L248 78H228L244 36Z" fill="#fff" stroke="' + C.glow + '" stroke-width="3" stroke-linejoin="round"/>';
    return s + '</svg>';
  }

  var POSES = {
    optic: [{ yaw: 0, tilt: 0, expr: 'calm' }, { yaw: .8, tilt: -6, expr: 'smirk' }, { yaw: -.7, tilt: 7, expr: 'shout', fire: true }, { yaw: .25, pitch: .8, tilt: -4, expr: 'wow' }],
    speed: [{ yaw: -.2, tilt: -4, expr: 'wow', bolt: true }, { yaw: .85, tilt: 6, expr: 'smirk' }, { yaw: 0, tilt: 0, expr: 'calm', up: true }, { yaw: -.8, pitch: .5, tilt: -8, expr: 'shout', bolt: true }],
    claw: [{ yaw: 0, tilt: 0, expr: 'smirk' }, { yaw: -.8, tilt: 5, expr: 'calm' }, { yaw: .7, tilt: -7, expr: 'shout', claws: true }, { yaw: .2, pitch: .6, tilt: 3, expr: 'wow', claws: true }],
    wraith: [{ yaw: 0, tilt: 0, expr: 'smirk' }, { yaw: .8, tilt: -5, expr: 'calm' }, { yaw: -.7, tilt: 6, expr: 'wow' }, { yaw: .3, pitch: .6, tilt: -3, expr: 'shout' }]
  };

  /** Returns an element for pose index i (wraps). Uses your own images when configured. */
  function character(theme, i) {
    var imgs = (CORDX.characterImages && CORDX.characterImages[theme]) || [], d = CH.el('div', { class: 'stk-art' });
    if (imgs.length) { d.appendChild(CH.el('img', { src: imgs[i % imgs.length], alt: '', loading: 'lazy', decoding: 'async' })); return d; }
    var list = POSES[theme] || POSES.wraith; d.innerHTML = figure(theme, list[i % list.length]); return d;
  }
  function count(theme) { var imgs = (CORDX.characterImages && CORDX.characterImages[theme]) || []; return imgs.length || (POSES[theme] || POSES.wraith).length; }

  /* emblem stickers (original geometry) */
  function badge(theme, kind) {
    var C = PAL[theme] || PAL.wraith, d = CH.el('div', { class: 'stk-art emblem' }), g = C.glow, body;
    var ring = '<circle cx="60" cy="60" r="54" fill="#0c0e15" stroke="' + g + '" stroke-width="5"/><circle cx="60" cy="60" r="44" fill="none" stroke="' + g + '" stroke-width="1.5" stroke-dasharray="3 5" opacity=".7"/>';
    if (kind === 'visor') body = '<rect x="26" y="48" width="68" height="24" rx="12" fill="#150b0e" stroke="' + g + '" stroke-width="3"/><rect x="34" y="55" width="52" height="9" rx="4.5" fill="' + g + '"/><path d="M94 60H112" stroke="' + g + '" stroke-width="5" stroke-linecap="round" opacity=".8"/>';
    else if (kind === 'bolt') body = '<path d="M68 22L38 66H58L50 98L84 50H64Z" fill="#fff" stroke="' + g + '" stroke-width="3" stroke-linejoin="round"/>';
    else if (kind === 'claws') body = '<path d="M34 24L48 98M56 20L68 100M78 24L90 98" stroke="' + g + '" stroke-width="8" stroke-linecap="round"/><path d="M34 24L48 98M56 20L68 100M78 24L90 98" stroke="#fff" stroke-width="2.5" stroke-linecap="round" opacity=".7"/>';
    else if (kind === 'x') body = '<path d="M36 36L84 84M84 36L36 84" stroke="' + g + '" stroke-width="12" stroke-linecap="round"/><path d="M36 36L84 84M84 36L36 84" stroke="#fff" stroke-width="3" stroke-linecap="round" opacity=".6"/>';
    else body = '<path d="M60 22L68 52L98 60L68 68L60 98L52 68L22 60L52 52Z" fill="#fff" stroke="' + g + '" stroke-width="3" stroke-linejoin="round"/>';
    d.innerHTML = '<svg viewBox="0 0 120 120" aria-hidden="true" focusable="false">' + ring + body + '</svg>';
    return d;
  }
  var BADGE_FOR = { optic: ['visor', 'x', 'spark'], speed: ['bolt', 'x', 'spark'], claw: ['claws', 'x', 'spark'], wraith: ['spark', 'x', 'bolt'] };

  CH.art = { character: character, count: count, badge: badge, badgeFor: BADGE_FOR };
})();
