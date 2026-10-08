/* CordX by Wraith — site configuration (loaded before everything else).
   Edit this file to customise themes, or to use your own licensed character images. */
window.CORDX = {
  brand: 'CordX', maker: 'Wraith', year: 2026,

  /* Character stickers are original vector illustrations by default.
     If you own the rights to your own images, list them here and they replace the illustrations
     (e.g. optic: ['assets/characters/optic-1.png', 'assets/characters/optic-2.png']).
     Please don't publish images you don't have the right to use. */
  characterImages: { optic: [], speed: [], claw: [] },

  /* The "interfaces". Each one changes colours, the 3D lettering material, the sticker character
     and the cursor effect. Names with "-inspired" are fan tributes, not official products. */
  themes: {
    wraith: { label: 'Wraith', tag: 'Neon violet · sparkle trail', fx: 'sparkle', phrases: ['STAY SHARP', 'NO LAG', 'BUILD IT LOUD', 'DROP THE EMBED', 'MAKE IT YOURS', 'GHOST MODE'] },
    optic: { label: 'Optic', alias: 'Cyclops-inspired', tag: 'Ruby visor · red laser', fx: 'laser', phrases: ['EYES UP', 'RED ALERT', 'FIRE AT WILL', 'HOLD THE LINE', 'LOCKED ON', 'STEADY…'] },
    speed: { label: 'Speed', alias: 'Quicksilver-inspired', tag: 'Silver blur · speed streaks', fx: 'streak', phrases: ['BLINK & MISS', 'ALREADY THERE', 'FASTER THAN LAG', 'ZERO WAIT', 'CATCH ME', 'TIME: SLOWED'] },
    claw: { label: 'Claw', alias: 'Wolverine-inspired', tag: 'Adamantium · claw slashes', fx: 'slash', phrases: ['CUT THROUGH', 'RAZOR SHARP', 'HEALS FAST', 'STILL STANDING', 'NO BRAKES', 'SHARP TONGUE'] }
  },
  themeOrder: ['wraith', 'optic', 'speed', 'claw']
};
