# How to make a UI like the "Animation Hub" screenshot

## What it is
The screenshot is a script-hub style menu: a **sidebar of tabs with icons**, a **content area with collapsible
sections**, **cards** (title, description, click icon), a **toggle switch**, and **minimise / maximise / close**
buttons, all over a background picture. That look is typical of Roblox UI libraries such as **WindUI**
(Footagesus) - its docs list tabs, sections, toggles, buttons, sliders, dropdowns, colour pickers, keybinds, icons and
themes (Dark, Light, Rose, Plant, Indigo, Sky, Violet, Amber...). I can't prove which library the screenshot uses -
Fluent, Rayfield and Luna Interface Suite look similar. Roblox's own docs and the DevForum cover the same building blocks.

- WindUI docs: https://www.mintlify.com/Footagesus/WindUI  (repo: github.com/Footagesus/WindUI)
- Roblox UI appearance modifiers (UICorner / UIStroke / UIGradient / CanvasGroup): https://create.roblox.com/docs/en-us/ui/appearance-modifiers
- DevForum "How To Make Simple & Modern UI": https://devforum.roblox.com/t/how-to-make-simple-modern-ui/1937876 (marked outdated - check property names)

## Where to build it
1. **Your own game: Roblox Studio** (free, on PC). Put a LocalScript in `StarterPlayer > StarterPlayerScripts`
   (or build the ScreenGui by hand under `StarterGui`), press Play to test, publish, and open the game on your phone
   from the normal Roblox app. `examples/mini_ui.lua` is a complete small menu you can paste into a LocalScript.
2. **A library:** libraries like WindUI are loaded with a `loadstring(game:HttpGet("<url to the library's main.lua>"))()`
   line and then you call their functions (CreateWindow, Tab, Section, Toggle...). Read the library's own docs for the
   exact calls. They are written for executor script hubs; using them inside someone else's game breaks Roblox's
   rules, inside your own game it is fine to copy the style but ship your own code.

## The recipe (every piece is a normal Roblox Instance)
```
ScreenGui                         ZIndexBehavior = Sibling, IgnoreGuiInset = true, ResetOnSpawn = false
 CanvasGroup  "Window"            fades / scales as ONE piece (GroupTransparency, UIScale)
   UICorner (14-18)  UIGradient (background)  UIStroke + UIGradient (the coloured rim)
   ImageLabel (background picture, ScaleType = Crop)  + a dark Frame "veil" over it
   Frame "TopBar"   title, subtitle, minimise / maximise / close TextButtons
   ScrollingFrame "Sidebar"   UIListLayout + UIPadding
     TextButton per tab: icon tile, label, 3px accent bar that grows when active
   Frame "Content"   one CanvasGroup per tab -> ScrollingFrame -> UIListLayout
     Section header (TextButton with a rotating arrow) -> body Frame (UIListLayout, AutomaticSize = Y)
     Card:  Frame + UICorner + UIStroke, title TextLabel, description TextLabel, button
     Toggle: row Frame, label, track Frame (UICorner), knob Frame that tweens left/right
```
Make it *glossy*: put a white Frame over each panel with a UIGradient whose Transparency goes from ~0.8 at the top to 1
(NumberSequence), add a thin white UIStroke at 85-90% transparency, and sweep a second, narrow white gradient across a
card on hover by tweening `UIGradient.Offset` from (-1, 0) to (1, 0). Rotate the rim gradient slowly
(`UIGradient.Rotation` each frame) for a "shiny" border.

Make it *smooth*: every state change is a `TweenService` tween (0.15-0.4 s, `Quint` or `Back`): hover colours,
switch knob, tab fade/slide, window pop. Never snap a value that the eye can see.

Make it *phone friendly*: size the window from `workspace.CurrentCamera.ViewportSize`, keep hit areas >= 36 px,
use a floating button to open it (phones have no keyboard), and never rely on hover.

## Colour: bright, not dull (what changed and why)
The first version was close to black: the window averaged a relative luminance of **0.03**. Fluent's themes (a popular script-hub
library) are the reference that showed the difference - they use saturated MID-tone gradients, `Text = (240,240,240)`,
`SubText = (170,170,170)` and cards that are the accent colour at ~87 % transparency, e.g. Rose `AcrylicGradient`
(190,60,135) -> (165,50,70), Amethyst (85,57,139) -> (40,25,65).
This project now picks each theme's surfaces by luminance instead of by eye: Back 0.075, Panel 0.115, Item 0.165, Hover 0.235,
window gradient 0.30 -> 0.105 (the window averages ~0.16, five times brighter), white text on Item/Panel and the soft sub-text on
Panel all stay above WCAG 4.5 : 1. Text that sits ON the bright accent / white buttons uses a separate dark `Theme.Ink`.
`tests/check_palette.py` parses the theme table and fails if a theme gets dark or unreadable again (the old palette fails it).
A **Brightness** slider (0.8 - 1.2, Effects tab, press Apply theme) scales the surfaces; the accents are left alone.

## References (design examples to open yourself)
These are real, widely used script-hub UI libraries. I did not load any of them into this project (a third-party loadstring runs
its code with your executor's full power); they are listed so you can see screenshots and copy ideas.
- WindUI - https://github.com/Footagesus/WindUI  (themes swappable at runtime, docs at footagesus.github.io/treehub-web/docs/windui)
- Fluent - https://github.com/dawid-scripts/Fluent  (acrylic look; `src/Themes/*.lua` hold every colour: Dark, Darker, Light, Aqua, Amethyst, Rose)
- Rayfield - https://github.com/sirius-menu/rayfield  (docs: docs.sirius.menu/rayfield, theme list under configuration/themes)
- Orion, Luna - older / alternative libraries with the same building blocks.
Common traits worth copying: rounded cards (UICorner 8-14), a 1 px translucent stroke, a coloured rim gradient on the window,
tinted translucent cards instead of opaque grey, one saturated accent, white title text, a left tab column with icons.

## Tools used to check this project
- `luau-compile` / `luau-analyze` / `luau-ast` (https://github.com/luau-lang/luau/releases) compile and parse the script with
  Roblox's own language implementation.
- `tools/validate_api.py` checks every class, property, enum and event against Roblox's published API dump.
