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

## Tools used to check this project
- `luau-compile` / `luau-analyze` / `luau-ast` (https://github.com/luau-lang/luau/releases) compile and parse the script with
  Roblox's own language implementation.
- `tools/validate_api.py` checks every class, property, enum and event against Roblox's published API dump.
