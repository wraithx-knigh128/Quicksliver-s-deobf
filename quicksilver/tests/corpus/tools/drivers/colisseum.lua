-- Driver for Colisseum (https://github.com/de-TourLLC/colisseum, AGPL-3.0) inside run_isolated.py.
--
-- Colisseum's cli.lua reads and writes real files, shells out to make directories and checks GitHub for updates. None of that is wanted here.
-- This calls the library entry point the CLI itself calls (`Obfuscator.obfuscate`) on the in-memory input. Nothing of Colisseum is modified.
-- A fixed seed makes the build reproducible; presets are easy, medium, hard, full, total, fortress.
local Obfuscator = require("src.obfuscator")
return Obfuscator.obfuscate(INPUT, {
  preset = OPTIONS.preset or "easy",
  target = OPTIONS.target or "lua",
  seed = OPTIONS.seed or 1337,
  bloat = OPTIONS.bloat,
})
