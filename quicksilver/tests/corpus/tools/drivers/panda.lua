-- Driver for Panda-Repositories/Prometheus-Modified ("Panda Obfuscator", a Prometheus derivative under the Prometheus licence) inside run_isolated.py.
-- It makes the call the tool's own cli.lua makes, without the command line: a preset from src/presets.lua, with the seed fixed so the output is
-- reproducible. Nothing of the tool is modified; the tool's code runs only inside the isolated Lua state.
package.path = "src/?.lua;src/?/init.lua;" .. package.path
rawset(_G, "arg", {})
local Prometheus = require("prometheus")
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local preset = Prometheus.Presets[OPTIONS.preset or "Medium"]
assert(preset, "no such preset: " .. tostring(OPTIONS.preset))
local cfg = {}
for k, v in pairs(preset) do cfg[k] = v end
cfg.Seed = tonumber(OPTIONS.seed or 1337)
local pipeline = Prometheus.Pipeline:fromConfig(cfg)
return pipeline:apply(INPUT, "sample")
