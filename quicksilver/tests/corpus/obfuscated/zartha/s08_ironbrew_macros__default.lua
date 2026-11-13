return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\026\051", "2839")),(decrypt("\028\051", "2843")),(decrypt("\118\010\096\114\011\121\096\009\011\117\117\120\096\121\125\014\122\125", "636")),(decrypt("\040", "2337")),(decrypt("\021\063", "2464")),(decrypt("\025\057", "2280")),(decrypt("\089\087\104\089\089\090", "900")),(decrypt("\014\012\013\008", "1053")),(decrypt("\029\062", "1598")),(decrypt("\088\108\080\107\104\091", "2037")),(decrypt("\007\009\001\003", "859")),(decrypt("\124\106\087\091\015\084\094\010\109\082\084\107", "2270")),(decrypt("\016\021\060", "827")),(decrypt("\026\029\061", "2461")),(decrypt("\114\008\097\117\119\114\119\112\114\116\009\099\120\122\015\124\121", "2175")),(decrypt("\011\082\089\086\104\081\092\108", "1192")),(decrypt("\016\051", "981")),(decrypt("\114\008\100\115\010\126\100\013\015\114\116\121\100\013\119\012", "2127")),(decrypt("\084\089\082\086\091", "302")),(decrypt("\100\113\013\005\126\125\014\000\121\011\015", "2748")),(decrypt("\022\026\063", "2045")),(decrypt("\082\095\091\097\090", "990")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
	for i,v in pairs(targetTable) do
		if v == value then
			return i
		end
	end
	
	return nil
end,Env["bit32"] and Env["bit32"]["bxor"] or function(a, b)
		local r, p = 0, 1
		for _ = 1, 8 do
			if a % 2 ~= b % 2 then r = r + p end
			a, b, p = (a - a % 2) / 2, (b - b % 2) / 2, p * 2
		end
		return r
	end

		-- VM function
		return (function()
			local Stack,Temp,Upvalues,Constants,ProtosConstants,vmEnv,pointer,top = {},{},{},{},{},{},1,0

			local Checks,ConstantsDecode = (function() -- Env log detection
	local function ooptest(...)
		local a = true and #{ -- troll
			...
		}
		return a
	end
	local _, err = pcall(function() 
		Env[__newindex](1) 
	end)
	local Tamper = false
	Env[__index] = function() 
		Tamper = true
	end
	if find(err,stringv) then
		pointer = 5^5
	end
	Env[4] = 11
	
	if Tamper then
		pointer = 10^5
	else
		local Checked = nil
		local _,er = pcall(function()
			Checked = (proxy(pnt)) 
		end)
		if Checked then
			pointer = 50^5
		else
			pointer = 1^5
		end
	end
	local counter = ooptest(1, 2, 3)
	
	if counter <2 then
		pointer = 5^5
	end
end)()
,(function() -- Constants decode
				for i, v in pairs(EncryptedConstants) do
					v = gsub(v, dot, function(bb)
						if tfind({11,4,7,6},byte(bb)) then
							return bb 
						end
						return char(byte(bb) +9) 
					end)
					Constants[i] = (function(toSend)
						local len = #toSend
						local lastByte = byte(toSend, len)
						if lastByte == 11 then
							return tonumber(sub(toSend, pointer, len - pointer))
						elseif lastByte == 4 then
							local removedByte = sub(toSend, pointer, len - pointer)
							local decrypted = {}
							local n = 0
							for i = 1, #removedByte do
								n = n + 1
								decrypted[n] = char(byte(removedByte, i) - 0)
							end
							return concat(decrypted)
						elseif lastByte == 7 then
							return byte(toSend, 1) == 116
						elseif lastByte == 6 then
							return nil
						end
						return toSend
					end)(v)
				end
			end)()

			-- VM STARTS HERE
			while true do
				if pointer == 1 then -- 2 [LOADBOOL] 
 Temp[1] = 0
Temp[11] = ttostring ~= __metatable
Stack[Temp[1]] = Temp[6] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[2] = vmEnv
Temp[15] = 20
Temp[5] = Constants[Temp[15]]
Temp[16] = 0
Temp[2][Temp[5]] = Temp[5] 
elseif pointer == 3 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\113\127\121\119\126\119\125", "782")),(decrypt("\013\117\013\013", "2157")),(decrypt("\122\095\084\108\110\101\099", "1986")),(decrypt("\010\004\124", "2868")),((decrypt("\025\031\019", "2884"))),}

		for i, v in pairs(encoded) do
			v = gsub(v, dot, function(bb)
				if tfind({11,4,7,6},byte(bb)) then
					return bb
				end
				return char(byte(bb) +9)
			end)
			local len = #v
			local lastByte = byte(v, len)
			if lastByte == 11 then
				C1[i] = tonumber(sub(v, 1, #v-1))
			elseif lastByte == 7 then
				C1[i] = byte(v, 1) == 116
			elseif lastByte == 6 then
				C1[i] = nil
			else
				C1[i] = v
			end
		end
		ProtosConstants[1] = C1
	else
		C1 = ProtosConstants[1]
	end
	
	Stack[0] = function(...) -- PROTOTYPE 1
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {}
		local Args = {...}
		local Constants = C1

		-- fix upvalues
		if next(Map) then
			setmeta(Upvalues, {
			    [__index] = function(self, Key)
			        local map = Map[Key]
			        if not map then return nil end
			        
			        if map[1] == 0 then -- Type 0: Parent Stack
			            return prevStack[map[2]]
			        else -- Type 1: Parent Upvalue
			            return prevUpvalues[map[2]]
			        end
			    end,
			    [__newindex] = function(self, Key, Value)
			        local map = Map[Key]
			        if not map then return end
			        
			        if map[1] == 0 then
			            prevStack[map[2]] = Value
			        else
			            prevUpvalues[map[2]] = Value
			        end
			    end,
			    [__metatable] = {}
			})
		end
		-- Args
		local argCount = #Args
		for i = 1, argCount do
			Stack[i - 1] = Args[i]
			Varargs[i] = Args[i]
		end
		
		while true do
		if pointer == 1 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 4 then -- 7 [SETGLOBAL] 
 Temp[14] = vmEnv
Temp[6] = 3
Temp[15] = Constants[Temp[6]]
Temp[13] = 0
Temp[14][Temp[15]] = Temp[15] 
elseif pointer == 5 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\087\093\083\085", "2106")),(decrypt("\013\080\095\085\088", "1963")),(decrypt("\104\093\092\080\092\006\017\016\108\087\092\109\081\095\108\018\108\081\083\016\111\080\086\017\089\106\110\104\080\081\085\092\017\031\029\016\016\031\031\027\027\026\027\016\070\110\095\071\081\108\102\013\082\090\093\104\125\031\070\127\114\082\029\070\012\084\115\125\008\026\111\118\104\006\008\009\110\102\027\081\031\122\127\107\105\110\084", "767")),(decrypt("\118\082\084\090\110", "2480")),}

		for i, v in pairs(encoded) do
			v = gsub(v, dot, function(bb)
				if tfind({11,4,7,6},byte(bb)) then
					return bb
				end
				return char(byte(bb) +9)
			end)
			local len = #v
			local lastByte = byte(v, len)
			if lastByte == 11 then
				C1[i] = tonumber(sub(v, 1, #v-1))
			elseif lastByte == 7 then
				C1[i] = byte(v, 1) == 116
			elseif lastByte == 6 then
				C1[i] = nil
			else
				C1[i] = v
			end
		end
		ProtosConstants[2] = C1
	else
		C1 = ProtosConstants[2]
	end
	
	Stack[0] = function(...) -- PROTOTYPE 2
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {}
		local Args = {...}
		local Constants = C1

		-- fix upvalues
		if next(Map) then
			setmeta(Upvalues, {
			    [__index] = function(self, Key)
			        local map = Map[Key]
			        if not map then return nil end
			        
			        if map[1] == 0 then -- Type 0: Parent Stack
			            return prevStack[map[2]]
			        else -- Type 1: Parent Upvalue
			            return prevUpvalues[map[2]]
			        end
			    end,
			    [__newindex] = function(self, Key, Value)
			        local map = Map[Key]
			        if not map then return end
			        
			        if map[1] == 0 then
			            prevStack[map[2]] = Value
			        else
			            prevUpvalues[map[2]] = Value
			        end
			    end,
			    [__metatable] = {}
			})
		end
		-- Args
		local argCount = #Args
		for i = 1, argCount do
			Stack[i - 1] = Args[i]
			Varargs[i] = Args[i]
		end
		
		while true do
		if pointer == 1 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 6 then -- 7 [SETGLOBAL] 
 Temp[9] = vmEnv
Temp[11] = 18
Temp[10] = Constants[Temp[11]]
Temp[5] = 0
Temp[9][Temp[10]] = Temp[10] 
elseif pointer == 7 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\013\106\090\083", "1208")),(decrypt("\009\084\082\082\120\094\082\108\090\100", "1894")),}

		for i, v in pairs(encoded) do
			v = gsub(v, dot, function(bb)
				if tfind({11,4,7,6},byte(bb)) then
					return bb
				end
				return char(byte(bb) +9)
			end)
			local len = #v
			local lastByte = byte(v, len)
			if lastByte == 11 then
				C1[i] = tonumber(sub(v, 1, #v-1))
			elseif lastByte == 7 then
				C1[i] = byte(v, 1) == 116
			elseif lastByte == 6 then
				C1[i] = nil
			else
				C1[i] = v
			end
		end
		ProtosConstants[3] = C1
	else
		C1 = ProtosConstants[3]
	end
	
	Stack[0] = function(...) -- PROTOTYPE 3
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {}
		local Args = {...}
		local Constants = C1

		-- fix upvalues
		if next(Map) then
			setmeta(Upvalues, {
			    [__index] = function(self, Key)
			        local map = Map[Key]
			        if not map then return nil end
			        
			        if map[1] == 0 then -- Type 0: Parent Stack
			            return prevStack[map[2]]
			        else -- Type 1: Parent Upvalue
			            return prevUpvalues[map[2]]
			        end
			    end,
			    [__newindex] = function(self, Key, Value)
			        local map = Map[Key]
			        if not map then return end
			        
			        if map[1] == 0 then
			            prevStack[map[2]] = Value
			        else
			            prevUpvalues[map[2]] = Value
			        end
			    end,
			    [__metatable] = {}
			})
		end
		-- Args
		local argCount = #Args
		for i = 1, argCount do
			Stack[i - 1] = Args[i]
			Varargs[i] = Args[i]
		end
		
		while true do
		if pointer == 1 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 8 then -- 7 [SETGLOBAL] 
 Temp[16] = vmEnv
Temp[15] = 15
Temp[13] = Constants[Temp[15]]
Temp[10] = 0
Temp[16][Temp[13]] = Temp[13] 
elseif pointer == 9 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\015\088\086\082\082\108\110\099", "283")),(decrypt("\091\105\093\095\081\080\104\094\103", "1564")),(decrypt("\008\101\092\013\101\093\108\101\082\109\097\082\093\083", "697")),(decrypt("\122\080\091\107\105\011\084\109\107\106", "167")),(decrypt("\113\010\100\113\118\113\113\118\114\116\013\100\123\120\010\120\120", "132")),}

		for i, v in pairs(encoded) do
			v = gsub(v, dot, function(bb)
				if tfind({11,4,7,6},byte(bb)) then
					return bb
				end
				return char(byte(bb) +9)
			end)
			local len = #v
			local lastByte = byte(v, len)
			if lastByte == 11 then
				C1[i] = tonumber(sub(v, 1, #v-1))
			elseif lastByte == 7 then
				C1[i] = byte(v, 1) == 116
			elseif lastByte == 6 then
				C1[i] = nil
			else
				C1[i] = v
			end
		end
		ProtosConstants[4] = C1
	else
		C1 = ProtosConstants[4]
	end
	
	Stack[0] = function(...) -- PROTOTYPE 4
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {}
		local Args = {...}
		local Constants = C1

		-- fix upvalues
		if next(Map) then
			setmeta(Upvalues, {
			    [__index] = function(self, Key)
			        local map = Map[Key]
			        if not map then return nil end
			        
			        if map[1] == 0 then -- Type 0: Parent Stack
			            return prevStack[map[2]]
			        else -- Type 1: Parent Upvalue
			            return prevUpvalues[map[2]]
			        end
			    end,
			    [__newindex] = function(self, Key, Value)
			        local map = Map[Key]
			        if not map then return end
			        
			        if map[1] == 0 then
			            prevStack[map[2]] = Value
			        else
			            prevUpvalues[map[2]] = Value
			        end
			    end,
			    [__metatable] = {}
			})
		end
		-- Args
		local argCount = #Args
		for i = 1, argCount do
			Stack[i - 1] = Args[i]
			Varargs[i] = Args[i]
		end
		
		while true do
		if pointer == 1 then -- 5 [GETGLOBAL] 
 Temp[9] = 2
Temp[11] = 5
Temp[16] = Constants[Temp[11]]
Stack[Temp[9]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 2 then -- 2 [LOADBOOL] 
 Temp[3] = 3
Temp[11] = ttostring ~= __metatable
Stack[Temp[3]] = Temp[13] 
elseif pointer == 3 then -- 28 [CALL] 
 	Stack[2](Stack[3]) 
elseif pointer == 4 then -- 12 [ADD] 
 	Stack[2] = Stack[0] + Stack[1] 
elseif pointer == 5 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 6 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 10 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {(decrypt("\123\110\106\091", "222")),(decrypt("\116\013\101\116\113\112\116\113\115\113\010\101\126\127\011\125\127", "443")),(decrypt("\120\106\088\094\105\088\087\089\084\104", "1629")),(decrypt("\010\101\104\081\106\101\105", "1927")),}

		for i, v in pairs(encoded) do
			v = gsub(v, dot, function(bb)
				if tfind({11,4,7,6},byte(bb)) then
					return bb
				end
				return char(byte(bb) +9)
			end)
			local len = #v
			local lastByte = byte(v, len)
			if lastByte == 11 then
				C1[i] = tonumber(sub(v, 1, #v-1))
			elseif lastByte == 7 then
				C1[i] = byte(v, 1) == 116
			elseif lastByte == 6 then
				C1[i] = nil
			else
				C1[i] = v
			end
		end
		ProtosConstants[5] = C1
	else
		C1 = ProtosConstants[5]
	end
	
	Stack[1] = function(...) -- PROTOTYPE 5
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {}
		local Args = {...}
		local Constants = C1

		-- fix upvalues
		if next(Map) then
			setmeta(Upvalues, {
			    [__index] = function(self, Key)
			        local map = Map[Key]
			        if not map then return nil end
			        
			        if map[1] == 0 then -- Type 0: Parent Stack
			            return prevStack[map[2]]
			        else -- Type 1: Parent Upvalue
			            return prevUpvalues[map[2]]
			        end
			    end,
			    [__newindex] = function(self, Key, Value)
			        local map = Map[Key]
			        if not map then return end
			        
			        if map[1] == 0 then
			            prevStack[map[2]] = Value
			        else
			            prevUpvalues[map[2]] = Value
			        end
			    end,
			    [__metatable] = {}
			})
		end
		-- Args
		local argCount = #Args
		for i = 1, argCount do
			Stack[i - 1] = Args[i]
			Varargs[i] = Args[i]
		end
		
		while true do
		if pointer == 1 then -- 5 [GETGLOBAL] 
 Temp[12] = 2
Temp[10] = 2
Temp[2] = Constants[Temp[10]]
Stack[Temp[12]] = vmEnv[Temp[2]] or Env[Temp[2]] 
elseif pointer == 2 then -- 2 [LOADBOOL] 
 Temp[10] = 3
Temp[8] = ttostring ~= __metatable
Stack[Temp[10]] = Temp[14] 
elseif pointer == 3 then -- 28 [CALL] 
 	Stack[2](Stack[3]) 
elseif pointer == 4 then -- 14 [MUL] 
 	Stack[2] = Stack[0] * Stack[1] 
elseif pointer == 5 then -- 15 [DIV] 
 	Stack[3] = Stack[0] / Stack[1] 
elseif pointer == 6 then -- 30 [RETURN] 
 	return Stack[2], Stack[3] 
elseif pointer == 7 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 11 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[6] then
		C1 = {}
		local encoded = {((decrypt("\030\028\018\017\002\030\024", "2278"))),(decrypt("\095\098\106", "991")),(decrypt("\119\001\100\115\000\125\097\002\015\116\126\124\097\114\121\015\113\121", "782")),(decrypt("\027\063", "2400")),(decrypt("\064\111\090\082", "1334")),(decrypt("\014\086\107\091\066\084\090\110\105", "2312")),(decrypt("\022\056", "1326")),(decrypt("\105\090\106\080", "576")),(decrypt("\011\105\083\013\087\082\085\087\106\109", "1167")),(decrypt("\113\015\103\116\009\121\103\010\012\117\119\126\103\010\116\011", "1610")),(decrypt("\087\111\106\107\089\083\089\111", "2343")),(decrypt("\109\082\092\087\088\008\017\022", "2970")),}

		for i, v in pairs(encoded) do
			v = gsub(v, dot, function(bb)
				if tfind({11,4,7,6},byte(bb)) then
					return bb
				end
				return char(byte(bb) +9)
			end)
			local len = #v
			local lastByte = byte(v, len)
			if lastByte == 11 then
				C1[i] = tonumber(sub(v, 1, #v-1))
			elseif lastByte == 7 then
				C1[i] = byte(v, 1) == 116
			elseif lastByte == 6 then
				C1[i] = nil
			else
				C1[i] = v
			end
		end
		ProtosConstants[6] = C1
	else
		C1 = ProtosConstants[6]
	end
	
	Stack[2] = function(...) -- PROTOTYPE 6
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {}
		local Args = {...}
		local Constants = C1

		-- fix upvalues
		if next(Map) then
			setmeta(Upvalues, {
			    [__index] = function(self, Key)
			        local map = Map[Key]
			        if not map then return nil end
			        
			        if map[1] == 0 then -- Type 0: Parent Stack
			            return prevStack[map[2]]
			        else -- Type 1: Parent Upvalue
			            return prevUpvalues[map[2]]
			        end
			    end,
			    [__newindex] = function(self, Key, Value)
			        local map = Map[Key]
			        if not map then return end
			        
			        if map[1] == 0 then
			            prevStack[map[2]] = Value
			        else
			            prevUpvalues[map[2]] = Value
			        end
			    end,
			    [__metatable] = {}
			})
		end
		-- Args
		local argCount = #Args
		for i = 1, argCount do
			Stack[i - 1] = Args[i]
			Varargs[i] = Args[i]
		end
		
		while true do
		if pointer == 1 then -- 5 [GETGLOBAL] 
 Temp[16] = 1
Temp[4] = 3
Temp[14] = Constants[Temp[4]]
Stack[Temp[16]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 2 then -- 28 [CALL] 
 	Stack[1]() 
elseif pointer == 3 then -- 3 [LOADNIL] 
 	Stack[1], Stack[2] = nil 
elseif pointer == 4 then -- 24 [LT] 
 	if Stack[0] < Constants[7] then pointer = pointer + 1 end 
elseif pointer == 5 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 6 then -- 1 [LOADK] 
 Temp[8] = 1
Temp[4] = Constants
Temp[16] = 11
Stack[Temp[8]] = Temp[4][Temp[16]] 
elseif pointer == 7 then -- 22 [JMP] 
 pointer = pointer + 10  
elseif pointer == 8 then -- 23 [EQ] 
 	if Stack[0] == Constants[7] then pointer = pointer + 1 end 
elseif pointer == 9 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 10 then -- 1 [LOADK] 
 Temp[1] = 1
Temp[3] = Constants
Temp[10] = 5
Stack[Temp[1]] = Temp[3][Temp[10]] 
elseif pointer == 11 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 12 then -- 16 [MOD] 
 	Stack[2] = Stack[0] % Constants[4] 
elseif pointer == 13 then -- 23 [EQ] 
 	if Stack[2] == Constants[7] then pointer = pointer + 1 end 
elseif pointer == 14 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 15 then -- 1 [LOADK] 
 Temp[4] = 1
Temp[2] = Constants
Temp[6] = 8
Stack[Temp[4]] = Temp[2][Temp[6]] 
elseif pointer == 16 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 17 then -- 1 [LOADK] 
 Temp[1] = 1
Temp[4] = Constants
Temp[15] = 2
Stack[Temp[1]] = Temp[4][Temp[15]] 
elseif pointer == 18 then -- 5 [GETGLOBAL] 
 Temp[4] = 2
Temp[2] = 10
Temp[9] = Constants[Temp[2]]
Stack[Temp[4]] = vmEnv[Temp[9]] or Env[Temp[9]] 
elseif pointer == 19 then -- 28 [CALL] 
 	Stack[2]() 
elseif pointer == 20 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 21 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 12 then -- 1 [LOADK] 
 Temp[3] = 3
Temp[9] = Constants
Temp[14] = 5
Stack[Temp[3]] = Temp[9][Temp[14]] 
elseif pointer == 13 then -- 1 [LOADK] 
 Temp[16] = 4
Temp[4] = Constants
Temp[5] = 1
Stack[Temp[16]] = Temp[4][Temp[5]] 
elseif pointer == 14 then -- 1 [LOADK] 
 Temp[15] = 5
Temp[5] = Constants
Temp[4] = 13
Stack[Temp[15]] = Temp[5][Temp[4]] 
elseif pointer == 15 then -- 1 [LOADK] 
 Temp[10] = 6
Temp[5] = Constants
Temp[16] = 1
Stack[Temp[10]] = Temp[5][Temp[16]] 
elseif pointer == 16 then -- 32 [FORPREP] 
     Stack[4] = Stack[4] - Stack[6]
    pointer = pointer + 5
     
elseif pointer == 17 then -- 0 [MOVE] 
 Temp[6] = 8
Temp[3] = 0
Stack[Temp[6]] = Stack[Temp[3]] 
elseif pointer == 18 then -- 0 [MOVE] 
 Temp[5] = 9
Temp[6] = 3
Stack[Temp[5]] = Stack[Temp[6]] 
elseif pointer == 19 then -- 0 [MOVE] 
 Temp[16] = 10
Temp[10] = 7
Stack[Temp[16]] = Stack[Temp[10]] 
elseif pointer == 20 then -- 28 [CALL] 
 	Stack[8] = Stack[8](Stack[9], Stack[10]) 
elseif pointer == 21 then -- 0 [MOVE] 
 Temp[4] = 3
Temp[13] = 8
Stack[Temp[4]] = Stack[Temp[13]] 
elseif pointer == 22 then -- 31 [FORLOOP] 
     Stack[4] = Stack[4] + Stack[6]
    if (Stack[6] > 0 and Stack[4] <= Stack[5]) or (Stack[6] <= 0 and Stack[4] >= Stack[5]) then
        pointer = pointer + -6
        Stack[7] = Stack[4]
    end
     
elseif pointer == 23 then -- 5 [GETGLOBAL] 
 Temp[2] = 4
Temp[15] = 19
Temp[6] = Constants[Temp[15]]
Stack[Temp[2]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 24 then -- 1 [LOADK] 
 Temp[6] = 5
Temp[14] = Constants
Temp[5] = 22
Stack[Temp[6]] = Temp[14][Temp[5]] 
elseif pointer == 25 then -- 0 [MOVE] 
 Temp[3] = 6
Temp[7] = 3
Stack[Temp[3]] = Stack[Temp[7]] 
elseif pointer == 26 then -- 28 [CALL] 
 	Stack[4](Stack[5], Stack[6]) 
elseif pointer == 27 then -- 5 [GETGLOBAL] 
 Temp[7] = 4
Temp[11] = 7
Temp[5] = Constants[Temp[11]]
Stack[Temp[7]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 28 then -- 10 [NEWTABLE] 
 	Stack[5] = {} 
elseif pointer == 29 then -- 1 [LOADK] 
 Temp[7] = 6
Temp[15] = Constants
Temp[9] = 21
Stack[Temp[7]] = Temp[15][Temp[9]] 
elseif pointer == 30 then -- 1 [LOADK] 
 Temp[12] = 7
Temp[14] = Constants
Temp[15] = 5
Stack[Temp[12]] = Temp[14][Temp[15]] 
elseif pointer == 31 then -- 1 [LOADK] 
 Temp[7] = 8
Temp[4] = Constants
Temp[11] = 6
Stack[Temp[7]] = Temp[4][Temp[11]] 
elseif pointer == 32 then -- 1 [LOADK] 
 Temp[7] = 9
Temp[10] = Constants
Temp[14] = 2
Stack[Temp[7]] = Temp[10][Temp[14]] 
elseif pointer == 33 then -- 34 [SETLIST] 
 	for i = 1, 4 do
		Stack[5][(1 - 1) * 50 + i] = Stack[5 + i]
	end
	 
elseif pointer == 34 then -- 28 [CALL] 
 	Stack[4], Stack[5], Stack[6] = Stack[4](Stack[5]) 
elseif pointer == 35 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 36 then -- 5 [GETGLOBAL] 
 Temp[12] = 9
Temp[15] = 19
Temp[13] = Constants[Temp[15]]
Stack[Temp[12]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 37 then -- 0 [MOVE] 
 Temp[6] = 10
Temp[2] = 8
Stack[Temp[6]] = Stack[Temp[2]] 
elseif pointer == 38 then -- 0 [MOVE] 
 Temp[9] = 11
Temp[7] = 2
Stack[Temp[9]] = Stack[Temp[7]] 
elseif pointer == 39 then -- 0 [MOVE] 
 Temp[16] = 12
Temp[15] = 8
Stack[Temp[16]] = Stack[Temp[15]] 
elseif pointer == 40 then -- 28 [CALL] 
 	Temp[2] = {Stack[11](Stack[12])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[11] = nil
		top = 11
	else
		top = 11 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[11 + i - 1] = Temp[2][i]
		end
	end
	 
elseif pointer == 41 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 9 + 1, top do
		Temp[1][i - 9] = Stack[i]
	end
	Temp[2] = {Stack[9](unpack(Temp[1], 1, top - 9))}
		for i = 1, 0 do
		Stack[9 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 42 then -- 33 [TFORLOOP] 
     local r1, r2 = Stack[4](Stack[5], Stack[6])
    Stack[7] = r1
        Stack[8] = r2
    if Stack[7] ~= nil then
        Stack[6] = Stack[7]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 43 then -- 22 [JMP] 
 pointer = pointer + -8  
elseif pointer == 44 then -- 0 [MOVE] 
 Temp[13] = 4
Temp[3] = 1
Stack[Temp[13]] = Stack[Temp[3]] 
elseif pointer == 45 then -- 1 [LOADK] 
 Temp[16] = 5
Temp[4] = Constants
Temp[10] = 14
Stack[Temp[16]] = Temp[4][Temp[10]] 
elseif pointer == 46 then -- 1 [LOADK] 
 Temp[10] = 6
Temp[8] = Constants
Temp[1] = 9
Stack[Temp[10]] = Temp[8][Temp[1]]
	Stack[4], Stack[5] = Stack[4](Stack[5], Stack[6])
	pointer = pointer + 1 
elseif pointer == 48 then -- 5 [GETGLOBAL] 
 Temp[8] = 6
Temp[1] = 19
Temp[12] = Constants[Temp[1]]
Stack[Temp[8]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 49 then -- 0 [MOVE] 
 Temp[5] = 7
Temp[14] = 4
Stack[Temp[5]] = Stack[Temp[14]] 
elseif pointer == 50 then -- 0 [MOVE] 
 Temp[11] = 8
Temp[12] = 5
Stack[Temp[11]] = Stack[Temp[12]] 
elseif pointer == 51 then -- 28 [CALL] 
 	Stack[6](Stack[7], Stack[8]) 
elseif pointer == 52 then -- 5 [GETGLOBAL] 
 Temp[5] = 6
Temp[14] = 19
Temp[7] = Constants[Temp[14]]
Stack[Temp[5]] = vmEnv[Temp[7]] or Env[Temp[7]] 
elseif pointer == 53 then -- 5 [GETGLOBAL] 
 Temp[11] = 7
Temp[7] = 10
Temp[4] = Constants[Temp[7]]
Stack[Temp[11]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 54 then -- 1 [LOADK] 
 Temp[6] = 8
Temp[5] = Constants
Temp[1] = 4
Stack[Temp[6]] = Temp[5][Temp[1]] 
elseif pointer == 55 then -- 0 [MOVE] 
 Temp[12] = 9
Temp[7] = 1
Stack[Temp[12]] = Stack[Temp[7]] 
elseif pointer == 56 then -- 1 [LOADK] 
 Temp[10] = 10
Temp[3] = Constants
Temp[7] = 1
Stack[Temp[10]] = Temp[3][Temp[7]] 
elseif pointer == 57 then -- 1 [LOADK] 
 Temp[8] = 11
Temp[15] = Constants
Temp[3] = 17
Stack[Temp[8]] = Temp[15][Temp[3]]
	Temp[2] = {Stack[9](Stack[10], Stack[11])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[9] = nil
		top = 9
	else
		top = 9 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[9 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 59 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 7 + 1, top do
		Temp[1][i - 7] = Stack[i]
	end
	Temp[2] = {Stack[7](unpack(Temp[1], 1, top - 7))}
		Temp[3]  = #Temp[2]
	if Temp[3]  == 0 then
		Stack[7] = nil
		top = 7
	else
		top = 7 + Temp[3]  - 1
		for i = 1, Temp[3]  do
			Stack[7 + i - 1] = Temp[2][i]
		end
	end
	
	 
elseif pointer == 60 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 6 + 1, top do
		Temp[1][i - 6] = Stack[i]
	end
	Temp[2] = {Stack[6](unpack(Temp[1], 1, top - 6))}
		for i = 1, 0 do
		Stack[6 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 61 then -- 30 [RETURN] 
 	return 
end
				pointer = pointer + 1
			end
		end)()

 end)((_ENV or getfenv()),{},0,function(str, key) -- Decrypt vars
	local result = {}
	local keyLen = #key
	local sbyte = string.byte
	local schar = string.char
	local bxor = bit32 and bit32.bxor or function(a, b)
		local r, p = 0, 1
		for _ = 1, 8 do
			if a % 2 ~= b % 2 then r = r + p end
			a, b, p = (a - a % 2) / 2, (b - b % 2) / 2, p * 2
		end
		return r
	end
	for i = 1, #str do
		result[i] = schar(bxor(sbyte(str, i), sbyte(key, (i - 1) % keyLen + 1)))
	end
	return table.concat(result)
end
) end)())