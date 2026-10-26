# loader

`main.lua` is the recovered source of the script (QuickSilver's static output; nothing was run to get it).
`loader.lua` is the same program held in one long string and started with `loadstring`, so it can be fetched and run as a single file:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/wraithx-knigh128/Quicksliver-s-deobf/ccr-71f2ead1-kocfgx/loader/loader.lua"))()
```

The plain source can be fetched the same way:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/wraithx-knigh128/Quicksliver-s-deobf/ccr-71f2ead1-kocfgx/loader/main.lua"))()
```

The branch name in the address is the branch these files were pushed to; after they are merged, `main` takes its place.

`loader.lua` is `return (loadstring or load)([==[ <main.lua> ]==], "=RideAPet")(...)`: the string uses level-2 long brackets, and `main.lua`
holds no `]==]`, so it ends where it should. The source uses Luau syntax (`+=`), so it needs Luau's `loadstring` (an executor or Roblox), not stock Lua 5.1.
