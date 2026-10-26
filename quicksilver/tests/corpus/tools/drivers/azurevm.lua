-- Driver for AzureVM (https://github.com/LionHub-Pino/AzureVM, MIT) inside run_isolated.py.
--
-- The tool's CLI (azure_obf.lua) reads and writes files, takes its seed from /dev/urandom and prints a banner. This builds the same pipeline it builds
-- (a preset from src/presets.lua through Pipeline:fromConfig) on the in-memory input, with a fixed seed. Nothing of AzureVM is modified.
package.path = "src/?.lua;src/?/init.lua;" .. package.path
local presets = require("presets")
require("prometheus.azure_vm")
local Pipeline = require("prometheus.pipeline")
local config = presets[OPTIONS.preset or "Luraph"]
if not config then error("unknown preset " .. tostring(OPTIONS.preset)) end
local pipeline = Pipeline:fromConfig(config)
pipeline.Seed = tonumber(OPTIONS.seed or 1337)
pipeline.seed = pipeline.Seed
return pipeline:apply(INPUT)
