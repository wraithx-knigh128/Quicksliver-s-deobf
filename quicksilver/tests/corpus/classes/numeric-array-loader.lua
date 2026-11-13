-- written for this project's tests: a program stored as an array of numbers, decoded when it runs and handed to loadstring through a local alias
local _X = {10917, 11111, 10238, 10723, 11305, 3933, 3351, 10141, 9850, 10529, 10529, 10820, 3157, 9947, 11111, 10820, 10626, 3157, 11305, 10141, 9850, 3157, 10917, 9462, 11790, 10529, 10820, 9462, 9753, 3351, 4030}
local function _d(t) local s = {} for i = 1, #t do s[#s + 1] = string.char(math.floor((t[i] - 53) / 97 + 0.0000001)) end return table.concat(s) end
local _L = (loadstring or load)
local f = _L(_d(_X))
if type(f) == 'function' then local P = setmetatable({}, {__call = function(_, ...) return f(...) end}) P() end
