-- A minimal, faithful stand-in for a Roblox executor environment, for running Voltfuscator outputs (runtime "Luau/Executor") on a real Luau
-- interpreter in the project's oracle. It provides only what the outputs check: Instance-typed game / workspace / RunService with the right
-- ClassName, Parent and GetService answers, typeof, Instance.new, a client-side RunService, getgenv and an executor name. Nothing here reaches
-- outside the interpreter.
local INSTANCE = setmetatable({}, { __mode = "k" })
local function instance(className, props)
  local o = props or {}
  o.ClassName = className
  INSTANCE[o] = true
  return o
end
local game = instance("DataModel", {})
local workspace = instance("Workspace", { Parent = game })
local runService = instance("RunService", {})
function runService.IsStudio(self) return false end
function runService.IsClient(self) return true end
function runService.IsServer(self) return false end
local services = { Workspace = workspace, RunService = runService }
function game.GetService(self, name) return services[name] end
local rawtypeof = typeof
local G = getfenv and getfenv() or _G
G.typeof = function(v) if INSTANCE[v] then return "Instance" end return rawtypeof and rawtypeof(v) or type(v) end
G.Instance = { new = function(className) return instance(className, {}) end }
G.game = game
G.workspace = workspace
local genv = {}
G.getgenv = function() return genv end
G.identifyexecutor = function() return "QuickSilver", "1.0" end
G.getexecutorname = G.identifyexecutor
