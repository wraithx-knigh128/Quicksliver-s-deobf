-- Minimal Roblox-style module loader for Lune.
-- Builds fake `script` objects whose .Parent / child indexing mirrors the Rojo tree,
-- so shared modules can `require(script.Parent.X)` exactly as they do in Roblox.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Loader = {}

local cache = {}
local nodes = {}
local known = {} -- path -> "file" | "dir"
local sources = {}

local makeNode

local function scan(dir: string)
	known[dir] = "dir"
	for _, name in fs.readDir(dir) do
		local full = dir .. "/" .. name
		if fs.isDir(full) then
			scan(full)
		elseif string.sub(name, -5) == ".luau" then
			local base = string.sub(full, 1, -6)
			known[base] = known[base] or "file"
			sources[full] = fs.readFile(full)
		end
	end
end

local function childExists(path: string): boolean
	return known[path] ~= nil
end

makeNode = function(path: string, name: string, parent)
	if nodes[path] then
		return nodes[path]
	end
	local node = { Name = name, Parent = parent, __path = path }
	setmetatable(node, {
		__index = function(t, k)
			local childPath = path .. "/" .. tostring(k)
			if childExists(childPath) then
				local c = makeNode(childPath, k, t)
				rawset(t, k, c)
				return c
			end
			error(string.format("%s is not a valid member of %s", tostring(k), path), 2)
		end,
		__tostring = function()
			return path
		end,
	})
	nodes[path] = node
	return node
end

local function vrequire(node)
	local path = rawget(node, "__path")
	if cache[path] ~= nil then
		return cache[path]
	end
	local file = path .. ".luau"
	if sources[file] == nil and sources[path .. "/init.luau"] ~= nil then
		file = path .. "/init.luau"
	end
	local src = sources[file]
	assert(src, "module not found: " .. file)
	local env = {}
	for k, v in Loader.extra do
		env[k] = v
	end
	env.script = node
	env.require = vrequire
	local fn = luau.load(src, { debugName = file, environment = env })
	local result = fn()
	cache[path] = result
	return result
end

Loader.globals = getfenv(1)

-- Expose extra globals (e.g. Roblox datatypes from @lune/roblox) to loaded modules.
Loader.extra = {}
function Loader.addGlobals(extra)
	for k, v in extra do
		Loader.extra[k] = v
	end
end

function Loader.root(dir: string)
	-- returns a node representing a folder, e.g. "src/shared"
	scan(dir)
	local parts = string.split(dir, "/")
	return makeNode(dir, parts[#parts], nil)
end

Loader.require = vrequire

return Loader
