return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\031\016\060", "777")),(decrypt("\104\094\084\104\106\083", "2812")),(decrypt("\025\062", "2513")),(decrypt("\089\096\104\085\110", "2816")),(decrypt("\029\057", "120")),(decrypt("\008\094\090\101\117\096\105\091\106\102\111\083", "2839")),(decrypt("\024\051", "2843")),(decrypt("\096\117\015\011\127\124\012\011\125\010\008", "636")),(decrypt("\124\085\090\085\088\084\107\109\110", "2337")),(decrypt("\025\019\061", "2464")),(decrypt("\024\021\051", "2280")),((decrypt("\021\023\023", "900"))),(decrypt("\018", "1053")),(decrypt("\024\062", "1598")),(decrypt("\085\089\083\082\089", "2037")),(decrypt("\016\062", "859")),(decrypt("\123\110\080\083\082\104\111\091\110\105\125\091\084\091\111\110\110", "2270")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
 Temp[5] = 0
Temp[14] = ttostring ~= __metatable
Stack[Temp[5]] = Temp[12] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[7] = vmEnv
Temp[5] = 8
Temp[12] = Constants[Temp[5]]
Temp[2] = 0
Temp[7][Temp[12]] = Temp[12] 
elseif pointer == 3 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {((decrypt("\028\031\002\026", "782"))),(decrypt("\110\082\089\084\091\008\020\021\106\089\088\105\087\080\105\022\107\095\086\021\105\094\082\021\095\101\107\108\087\095\080\089\023\017\025\020\022\016\026\031\028\020\030\021\064\096\091\067\087\099\099\009\085\084\088\109\123\017\066\123\116\093\024\066\011\090\118\120\014\020\107\114\110\009\013\013\105\104\030\084\025\116\123\111\111\097\081", "1923")),(decrypt("\117\125\123", "2106")),(decrypt("\084\085\085\080", "1963")),(decrypt("\125\090\109\109\106\093\093", "767")),(decrypt("\088\104\083\091\082\081\102\090\100", "2480")),}

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
		if pointer == 1 then -- 0 [MOVE] 
 Temp[1] = 2
Temp[12] = 0
Stack[Temp[1]] = Stack[Temp[12]] 
elseif pointer == 2 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[11] then
		C1 = {}
		local encoded = {(decrypt("\123\085\085\100", "851")),((decrypt("\021\023\024", "2206"))),(decrypt("\000\099\083\088\084\100", "898")),(decrypt("\127\105\087\082\123\086\104\108\106", "1140")),}

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
		ProtosConstants[11] = C1
	else
		C1 = ProtosConstants[11]
	end
	
	Stack[3] = function(...) -- PROTOTYPE 11
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 2}, [1] = {0, 1}}
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
		if pointer == 1 then -- 4 [GETUPVAL] 
 	Stack[0] = Upvalues[0] 
elseif pointer == 2 then -- 4 [GETUPVAL] 
 	Stack[1] = Upvalues[1] 
elseif pointer == 3 then -- 12 [ADD] 
 	Stack[0] = Stack[0] + Stack[1] 
elseif pointer == 4 then -- 8 [SETUPVAL] 
 	Upvalues[0] = Stack[0] 
elseif pointer == 5 then -- 4 [GETUPVAL] 
 	Stack[0] = Upvalues[0] 
elseif pointer == 6 then -- 30 [RETURN] 
 	return Stack[0] 
elseif pointer == 7 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 5 then -- 30 [RETURN] 
 	return Stack[3] 
elseif pointer == 6 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 4 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\011\087\086\080\082\109\089\107", "1127")),(decrypt("\012\105\092\002\110\095\109\101\087\110\111\092\089\095", "2579")),(decrypt("\114\089\097\081\089\101\081\012\085\088", "829")),((decrypt("\030", "283"))),(decrypt("\117\014\026", "1564")),}

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
	
	Stack[1] = function(...) -- PROTOTYPE 2
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
		if pointer == 1 then -- 10 [NEWTABLE] 
 	Stack[1] = {} 
elseif pointer == 2 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[12] then
		C1 = {}
		local encoded = {(decrypt("\127\084\087\083\088\087\104", "682")),((decrypt("\025\016\021\017\022\016\021", "1726"))),(decrypt("\084\089\081\049", "1927")),(decrypt("\013\111\091\108\111\084\109\107\084\093\011\106\109\111\106", "631")),((decrypt("\026\017\031", "1679"))),(decrypt("\127\105\091\082\081\084\108", "1127")),}

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
		ProtosConstants[12] = C1
	else
		C1 = ProtosConstants[12]
	end
	
	Stack[2] = function(...) -- PROTOTYPE 12
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 1}, [1] = {0, 0}}
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
		if pointer == 1 then -- 4 [GETUPVAL] 
 	Stack[1] = Upvalues[0] 
elseif pointer == 2 then -- 6 [GETTABLE] 
 	Stack[1] = Stack[1][Stack[0]]
	 
elseif pointer == 3 then -- 23 [EQ] 
 	if Stack[1] == Constants[3] then pointer = pointer + 1 end 
elseif pointer == 4 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 5 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[1] 
elseif pointer == 6 then -- 0 [MOVE] 
 Temp[14] = 3
Temp[10] = 0
Stack[Temp[14]] = Stack[Temp[10]] 
elseif pointer == 7 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3]) 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[15] = 1
Temp[14] = 2
Stack[Temp[15]] = Stack[Temp[14]] 
elseif pointer == 9 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 10 then -- 9 [SETTABLE] 
 	Stack[2][Stack[0]] = Stack[1] 
elseif pointer == 11 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 12 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 5 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 6 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 5 then -- 3 [LOADNIL] 
 	Stack[2], Stack[3], Stack[4] = nil 
elseif pointer == 6 then -- 0 [MOVE] 
 Temp[15] = 3
Temp[11] = 1
Stack[Temp[15]] = Stack[Temp[11]] 
elseif pointer == 7 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\009\080\106\105", "604")),(decrypt("\116\116\126\114\116\118\127", "2352")),(decrypt("\025\059", "1077")),(decrypt("\027\063", "2468")),(decrypt("\122\109\086\090", "119")),}

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
	
	Stack[4] = function(...) -- PROTOTYPE 3
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 2}}
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
		if pointer == 1 then -- 24 [LT] 
 	if Stack[0] < Constants[4] then pointer = pointer + 1 end 
elseif pointer == 2 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 3 then -- 30 [RETURN] 
 	return Stack[0] 
elseif pointer == 4 then -- 4 [GETUPVAL] 
 	Stack[1] = Upvalues[0] 
elseif pointer == 5 then -- 13 [SUB] 
 	Stack[2] = Stack[0] - Constants[3] 
elseif pointer == 6 then -- 28 [CALL] 
 	Stack[1] = Stack[1](Stack[2]) 
elseif pointer == 7 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 8 then -- 13 [SUB] 
 	Stack[3] = Stack[0] - Constants[4] 
elseif pointer == 9 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3]) 
elseif pointer == 10 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Stack[2] 
elseif pointer == 11 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 12 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 9 then -- 28 [CALL] 
 	Stack[3] = Stack[3](Stack[4]) 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[5] = 2
Temp[1] = 3
Stack[Temp[5]] = Stack[Temp[1]] 
elseif pointer == 11 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\123\110\106\091", "222")),(decrypt("\015\104\105\082\111\111\111", "443")),}

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
	
	Stack[3] = function(...) -- PROTOTYPE 4
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
		if pointer == 1 then -- 10 [NEWTABLE] 
 	Stack[1] = {} 
elseif pointer == 2 then -- 37 [VARARG] 
 	top = 2 + #Varargs - 1
	for i = 1, #Varargs do
		Stack[2 + i - 1] = Varargs[i]
	end
	 
elseif pointer == 3 then -- 34 [SETLIST] 
 	local _limit = top - 1
	for i = 1, _limit do
		Stack[1][(1 - 1) * 50 + i] = Stack[1 + i]
	end
	 
elseif pointer == 4 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[13] then
		C1 = {}
		local encoded = {(decrypt("\025\058", "1178")),(decrypt("\018\025\062", "615")),(decrypt("\125\109\087\081\085\081\109", "354")),((decrypt("\017\016\030\030", "659"))),(decrypt("\127\094\106\092\094\110\092\011\094\085", "552")),(decrypt("\080\109\072\103", "2181")),(decrypt("\014\084\109\089\066\086\092\108\105", "2170")),(decrypt("\112\093\087\082\081\084\109", "1135")),}

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
		ProtosConstants[13] = C1
	else
		C1 = ProtosConstants[13]
	end
	
	Stack[2] = function(...) -- PROTOTYPE 13
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 1}}
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
		if pointer == 1 then -- 4 [GETUPVAL] 
 	Stack[1] = Upvalues[0] 
elseif pointer == 2 then -- 20 [LEN] 
 	Stack[1] = #Stack[1] 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[5] = 2
Temp[6] = Constants
Temp[9] = 1
Stack[Temp[5]] = Temp[6][Temp[9]] 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[14] = 3
Temp[12] = Constants
Temp[7] = 2
Stack[Temp[14]] = Temp[12][Temp[7]] 
elseif pointer == 5 then -- 32 [FORPREP] 
     Stack[1] = Stack[1] - Stack[3]
    pointer = pointer + 5
     
elseif pointer == 6 then -- 4 [GETUPVAL] 
 	Stack[5] = Upvalues[0] 
elseif pointer == 7 then -- 6 [GETTABLE] 
 	Stack[5] = Stack[5][Stack[4]]
	 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[7] = 6
Temp[10] = 0
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 9 then -- 28 [CALL] 
 	Stack[5] = Stack[5](Stack[6]) 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[4] = 0
Temp[7] = 5
Stack[Temp[4]] = Stack[Temp[7]] 
elseif pointer == 11 then -- 31 [FORLOOP] 
     Stack[1] = Stack[1] + Stack[3]
    if (Stack[3] > 0 and Stack[1] <= Stack[2]) or (Stack[3] <= 0 and Stack[1] >= Stack[2]) then
        pointer = pointer + -6
        Stack[4] = Stack[1]
    end
     
elseif pointer == 12 then -- 30 [RETURN] 
 	return Stack[0] 
elseif pointer == 13 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 6 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 7 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 12 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {(decrypt("\009\086\089\106\107\085\111\105", "2632")),(decrypt("\011\083\093\082\082\105\082\105", "1595")),((decrypt("\021\028\028", "2909"))),((decrypt("\025", "328"))),(decrypt("\081\081\110\083\088\092", "1663")),}

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
	
	Stack[4] = function(...) -- PROTOTYPE 5
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
		if pointer == 1 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 2 then -- 5 [GETGLOBAL] 
 Temp[16] = 3
Temp[11] = 5
Temp[3] = Constants[Temp[11]]
Stack[Temp[16]] = vmEnv[Temp[3]] or Env[Temp[3]] 
elseif pointer == 3 then -- 0 [MOVE] 
 Temp[15] = 4
Temp[13] = 0
Stack[Temp[15]] = Stack[Temp[13]] 
elseif pointer == 4 then -- 28 [CALL] 
 	Stack[3], Stack[4], Stack[5] = Stack[3](Stack[4]) 
elseif pointer == 5 then -- 22 [JMP] 
 pointer = pointer + 5  
elseif pointer == 6 then -- 0 [MOVE] 
 Temp[14] = 8
Temp[2] = 1
Stack[Temp[14]] = Stack[Temp[2]] 
elseif pointer == 7 then -- 0 [MOVE] 
 Temp[10] = 9
Temp[3] = 7
Stack[Temp[10]] = Stack[Temp[3]] 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[15] = 10
Temp[10] = 6
Stack[Temp[15]] = Stack[Temp[10]] 
elseif pointer == 9 then -- 28 [CALL] 
 	Stack[8] = Stack[8](Stack[9], Stack[10]) 
elseif pointer == 10 then -- 9 [SETTABLE] 
 	Stack[2][Stack[6]] = Stack[8] 
elseif pointer == 11 then -- 33 [TFORLOOP] 
     local r1, r2 = Stack[3](Stack[4], Stack[5])
    Stack[6] = r1
        Stack[7] = r2
    if Stack[6] ~= nil then
        Stack[5] = Stack[6]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 12 then -- 22 [JMP] 
 pointer = pointer + -7  
elseif pointer == 13 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 14 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 13 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[6] then
		C1 = {}
		local encoded = {(decrypt("\022\061", "1610")),(decrypt("\127\083\094\083\107\080\104", "2343")),(decrypt("\026\050", "2970")),(decrypt("\040", "2922")),(decrypt("\093\100\084\107\098\092", "787")),(decrypt("\015\110\080\082\110\109\039\090\084\033\080\084\082\093\080\105\081\086\065\109", "2601")),(decrypt("\010\105\104\091\111\034\085\081\106\105\038\107\084\109\104\084\109\110", "1517")),}

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
	
	Stack[5] = function(...) -- PROTOTYPE 6
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
		if pointer == 1 then -- 1 [LOADK] 
 Temp[4] = 1
Temp[16] = Constants
Temp[1] = 1
Stack[Temp[4]] = Temp[16][Temp[1]] 
elseif pointer == 2 then -- 1 [LOADK] 
 Temp[3] = 2
Temp[10] = Constants
Temp[4] = 3
Stack[Temp[3]] = Temp[10][Temp[4]] 
elseif pointer == 3 then -- 5 [GETGLOBAL] 
 Temp[2] = 3
Temp[6] = 5
Temp[1] = Constants[Temp[6]]
Stack[Temp[2]] = vmEnv[Temp[1]] or Env[Temp[1]] 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[4] = 4
Temp[15] = Constants
Temp[2] = 4
Stack[Temp[4]] = Temp[15][Temp[2]] 
elseif pointer == 5 then -- 37 [VARARG] 
 	top = 5 + #Varargs - 1
	for i = 1, #Varargs do
		Stack[5 + i - 1] = Varargs[i]
	end
	 
elseif pointer == 6 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 3 + 1, top do
		Temp[1][i - 3] = Stack[i]
	end
	Temp[2] = {Stack[3](unpack(Temp[1], 1, top - 3))}
		for i = 1, 1 do
		Stack[3 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 7 then -- 1 [LOADK] 
 Temp[9] = 4
Temp[14] = Constants
Temp[13] = 3
Stack[Temp[9]] = Temp[14][Temp[13]] 
elseif pointer == 8 then -- 32 [FORPREP] 
     Stack[2] = Stack[2] - Stack[4]
    pointer = pointer + 5
     
elseif pointer == 9 then -- 5 [GETGLOBAL] 
 Temp[13] = 6
Temp[11] = 5
Temp[4] = Constants[Temp[11]]
Stack[Temp[13]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[9] = 7
Temp[2] = 5
Stack[Temp[9]] = Stack[Temp[2]] 
elseif pointer == 11 then -- 37 [VARARG] 
 	top = 8 + #Varargs - 1
	for i = 1, #Varargs do
		Stack[8 + i - 1] = Varargs[i]
	end
	 
elseif pointer == 12 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 6 + 1, top do
		Temp[1][i - 6] = Stack[i]
	end
	Temp[2] = {Stack[6](unpack(Temp[1], 1, top - 6))}
		for i = 1, 1 do
		Stack[6 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 13 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Stack[6] 
elseif pointer == 14 then -- 31 [FORLOOP] 
     Stack[2] = Stack[2] + Stack[4]
    if (Stack[4] > 0 and Stack[2] <= Stack[3]) or (Stack[4] <= 0 and Stack[2] >= Stack[3]) then
        pointer = pointer + -6
        Stack[5] = Stack[2]
    end
     
elseif pointer == 15 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 16 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 14 then -- 0 [MOVE] 
 Temp[11] = 6
Temp[6] = 0
Stack[Temp[11]] = Stack[Temp[6]] 
elseif pointer == 15 then -- 1 [LOADK] 
 Temp[2] = 7
Temp[15] = Constants
Temp[5] = 1
Stack[Temp[2]] = Temp[15][Temp[5]] 
elseif pointer == 16 then -- 1 [LOADK] 
 Temp[16] = 8
Temp[14] = Constants
Temp[6] = 5
Stack[Temp[16]] = Temp[14][Temp[6]]
	Stack[6] = Stack[6](Stack[7], Stack[8])
	pointer = pointer + 1 
elseif pointer == 18 then -- 5 [GETGLOBAL] 
 Temp[15] = 7
Temp[13] = 15
Temp[9] = Constants[Temp[13]]
Stack[Temp[15]] = vmEnv[Temp[9]] or Env[Temp[9]] 
elseif pointer == 19 then -- 0 [MOVE] 
 Temp[11] = 8
Temp[10] = 6
Stack[Temp[11]] = Stack[Temp[10]] 
elseif pointer == 20 then -- 28 [CALL] 
 	Stack[8] = Stack[8]() 
elseif pointer == 21 then -- 0 [MOVE] 
 Temp[5] = 9
Temp[16] = 6
Stack[Temp[5]] = Stack[Temp[16]] 
elseif pointer == 22 then -- 28 [CALL] 
 	Stack[9] = Stack[9]() 
elseif pointer == 23 then -- 0 [MOVE] 
 Temp[15] = 10
Temp[13] = 6
Stack[Temp[15]] = Stack[Temp[13]] 
elseif pointer == 24 then -- 28 [CALL] 
 	Temp[2] = {Stack[10]()}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[10] = nil
		top = 10
	else
		top = 10 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[10 + i - 1] = Temp[2][i]
		end
	end
	 
elseif pointer == 25 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 7 + 1, top do
		Temp[1][i - 7] = Stack[i]
	end
	Temp[2] = {Stack[7](unpack(Temp[1], 1, top - 7))}
		for i = 1, 0 do
		Stack[7 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 26 then -- 5 [GETGLOBAL] 
 Temp[10] = 7
Temp[3] = 15
Temp[9] = Constants[Temp[3]]
Stack[Temp[10]] = vmEnv[Temp[9]] or Env[Temp[9]] 
elseif pointer == 27 then -- 0 [MOVE] 
 Temp[14] = 8
Temp[16] = 2
Stack[Temp[14]] = Stack[Temp[16]] 
elseif pointer == 28 then -- 1 [LOADK] 
 Temp[4] = 9
Temp[5] = Constants
Temp[15] = 11
Stack[Temp[4]] = Temp[5][Temp[15]]
	Stack[8] = Stack[8](Stack[9])
	pointer = pointer + 1 
elseif pointer == 30 then -- 0 [MOVE] 
 Temp[5] = 9
Temp[4] = 2
Stack[Temp[5]] = Stack[Temp[4]] 
elseif pointer == 31 then -- 1 [LOADK] 
 Temp[10] = 10
Temp[5] = Constants
Temp[16] = 10
Stack[Temp[10]] = Temp[5][Temp[16]]
	Temp[2] = {Stack[9](Stack[10])}
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
elseif pointer == 33 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 7 + 1, top do
		Temp[1][i - 7] = Stack[i]
	end
	Temp[2] = {Stack[7](unpack(Temp[1], 1, top - 7))}
		for i = 1, 0 do
		Stack[7 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 34 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[7] then
		C1 = {}
		local encoded = {(decrypt("\010\121\010\115\114", "2303")),((decrypt("\026\016\031\028\018\028", "253"))),(decrypt("\025\051", "1883")),(decrypt("\120\109\089\088\082\087\086\037\110\094\084\082\091\109\104", "2132")),}

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
		ProtosConstants[7] = C1
	else
		C1 = ProtosConstants[7]
	end
	
	Stack[7] = function(...) -- PROTOTYPE 7
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
		if pointer == 1 then -- 12 [ADD] 
 	Stack[1] = Stack[0] + Constants[3] 
elseif pointer == 2 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 3 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 35 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[8] then
		C1 = {}
		local encoded = {(decrypt("\011\090\088\085\104\089\093\111", "1981")),(decrypt("\024\059", "1091")),(decrypt("\010\088\086\107\081\067", "383")),}

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
		ProtosConstants[8] = C1
	else
		C1 = ProtosConstants[8]
	end
	
	Stack[8] = function(...) -- PROTOTYPE 8
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
		if pointer == 1 then -- 14 [MUL] 
 	Stack[1] = Stack[0] * Constants[2] 
elseif pointer == 2 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 3 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 36 then -- 5 [GETGLOBAL] 
 Temp[6] = 9
Temp[3] = 15
Temp[5] = Constants[Temp[3]]
Stack[Temp[6]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 37 then -- 0 [MOVE] 
 Temp[6] = 10
Temp[16] = 3
Stack[Temp[6]] = Stack[Temp[16]] 
elseif pointer == 38 then -- 0 [MOVE] 
 Temp[10] = 11
Temp[4] = 7
Stack[Temp[10]] = Stack[Temp[4]] 
elseif pointer == 39 then -- 0 [MOVE] 
 Temp[13] = 12
Temp[2] = 8
Stack[Temp[13]] = Stack[Temp[2]] 
elseif pointer == 40 then -- 28 [CALL] 
 	Stack[10] = Stack[10](Stack[11], Stack[12]) 
elseif pointer == 41 then -- 1 [LOADK] 
 Temp[15] = 11
Temp[6] = Constants
Temp[14] = 5
Stack[Temp[15]] = Temp[6][Temp[14]]
	Stack[10] = Stack[10](Stack[11])
	pointer = pointer + 1 
elseif pointer == 43 then -- 0 [MOVE] 
 Temp[5] = 11
Temp[3] = 3
Stack[Temp[5]] = Stack[Temp[3]] 
elseif pointer == 44 then -- 0 [MOVE] 
 Temp[7] = 12
Temp[11] = 8
Stack[Temp[7]] = Stack[Temp[11]] 
elseif pointer == 45 then -- 0 [MOVE] 
 Temp[5] = 13
Temp[7] = 7
Stack[Temp[5]] = Stack[Temp[7]] 
elseif pointer == 46 then -- 28 [CALL] 
 	Stack[11] = Stack[11](Stack[12], Stack[13]) 
elseif pointer == 47 then -- 1 [LOADK] 
 Temp[15] = 12
Temp[9] = Constants
Temp[12] = 5
Stack[Temp[15]] = Temp[9][Temp[12]]
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
	
	pointer = pointer + 1 
elseif pointer == 49 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 9 + 1, top do
		Temp[1][i - 9] = Stack[i]
	end
	Temp[2] = {Stack[9](unpack(Temp[1], 1, top - 9))}
		for i = 1, 0 do
		Stack[9 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 50 then -- 5 [GETGLOBAL] 
 Temp[14] = 9
Temp[7] = 15
Temp[15] = Constants[Temp[7]]
Stack[Temp[14]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 51 then -- 5 [GETGLOBAL] 
 Temp[7] = 10
Temp[4] = 4
Temp[11] = Constants[Temp[4]]
Stack[Temp[7]] = vmEnv[Temp[11]] or Env[Temp[11]]
	Stack[10] = Stack[10][Constants[2]]
	
	pointer = pointer + 1 
elseif pointer == 53 then -- 0 [MOVE] 
 Temp[7] = 11
Temp[10] = 4
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 54 then -- 10 [NEWTABLE] 
 	Stack[12] = {} 
elseif pointer == 55 then -- 1 [LOADK] 
 Temp[14] = 13
Temp[12] = Constants
Temp[15] = 16
Stack[Temp[14]] = Temp[12][Temp[15]] 
elseif pointer == 56 then -- 1 [LOADK] 
 Temp[13] = 14
Temp[6] = Constants
Temp[2] = 14
Stack[Temp[13]] = Temp[6][Temp[2]] 
elseif pointer == 57 then -- 1 [LOADK] 
 Temp[9] = 15
Temp[7] = Constants
Temp[16] = 7
Stack[Temp[9]] = Temp[7][Temp[16]] 
elseif pointer == 58 then -- 1 [LOADK] 
 Temp[15] = 16
Temp[13] = Constants
Temp[3] = 3
Stack[Temp[15]] = Temp[13][Temp[3]] 
elseif pointer == 59 then -- 34 [SETLIST] 
 	for i = 1, 4 do
		Stack[12][(1 - 1) * 50 + i] = Stack[12 + i]
	end
	 
elseif pointer == 60 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[9] then
		C1 = {}
		local encoded = {(decrypt("\013\109\091", "2144")),(decrypt("\112\110\080\086\106\082\083\085\097\110\106\115\104\095\084\084\108\101", "469")),(decrypt("\123\012\009\025\029\030", "1310")),(decrypt("\009\111\087\097\066", "2349")),}

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
		ProtosConstants[9] = C1
	else
		C1 = ProtosConstants[9]
	end
	
	Stack[13] = function(...) -- PROTOTYPE 9
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
		if pointer == 1 then -- 14 [MUL] 
 	Stack[2] = Stack[0] * Stack[1] 
elseif pointer == 2 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 3 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 61 then -- 28 [CALL] 
 	Stack[11] = Stack[11](Stack[12], Stack[13]) 
elseif pointer == 62 then -- 1 [LOADK] 
 Temp[16] = 12
Temp[4] = Constants
Temp[10] = 13
Stack[Temp[16]] = Temp[4][Temp[10]]
	Temp[2] = {Stack[10](Stack[11], Stack[12])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[10] = nil
		top = 10
	else
		top = 10 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[10 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 64 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 9 + 1, top do
		Temp[1][i - 9] = Stack[i]
	end
	Temp[2] = {Stack[9](unpack(Temp[1], 1, top - 9))}
		for i = 1, 0 do
		Stack[9 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 65 then -- 5 [GETGLOBAL] 
 Temp[10] = 9
Temp[8] = 15
Temp[1] = Constants[Temp[8]]
Stack[Temp[10]] = vmEnv[Temp[1]] or Env[Temp[1]] 
elseif pointer == 66 then -- 0 [MOVE] 
 Temp[8] = 10
Temp[1] = 5
Stack[Temp[8]] = Stack[Temp[1]] 
elseif pointer == 67 then -- 1 [LOADK] 
 Temp[12] = 11
Temp[5] = Constants
Temp[14] = 16
Stack[Temp[12]] = Temp[5][Temp[14]] 
elseif pointer == 68 then -- 1 [LOADK] 
 Temp[11] = 12
Temp[12] = Constants
Temp[5] = 14
Stack[Temp[11]] = Temp[12][Temp[5]] 
elseif pointer == 69 then -- 1 [LOADK] 
 Temp[14] = 13
Temp[7] = Constants
Temp[11] = 7
Stack[Temp[14]] = Temp[7][Temp[11]] 
elseif pointer == 70 then -- 1 [LOADK] 
 Temp[7] = 14
Temp[4] = Constants
Temp[6] = 3
Stack[Temp[7]] = Temp[4][Temp[6]] 
elseif pointer == 71 then -- 1 [LOADK] 
 Temp[5] = 15
Temp[1] = Constants
Temp[12] = 5
Stack[Temp[5]] = Temp[1][Temp[12]]
	Stack[10] = Stack[10](Stack[11], Stack[12], Stack[13], Stack[14], Stack[15])
	pointer = pointer + 1 
elseif pointer == 73 then -- 0 [MOVE] 
 Temp[7] = 11
Temp[10] = 5
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 74 then -- 28 [CALL] 
 	Temp[2] = {Stack[11]()}
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
	 
elseif pointer == 75 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 9 + 1, top do
		Temp[1][i - 9] = Stack[i]
	end
	Temp[2] = {Stack[9](unpack(Temp[1], 1, top - 9))}
		for i = 1, 0 do
		Stack[9 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 76 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[10] then
		C1 = {}
		local encoded = {(decrypt("\118\101\081\109\110\080\095\107\082\094\126\068\085\101", "2954")),((decrypt("\025\021\027", "2200"))),(decrypt("\009\012\123\013\121\012", "2081")),(decrypt("\121\100\091\110\095\094\091\083\114\110\081\085\082\098\100", "288")),}

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
		ProtosConstants[10] = C1
	else
		C1 = ProtosConstants[10]
	end
	
	Stack[9] = function(...) -- PROTOTYPE 10
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
		if pointer == 1 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[14] then
		C1 = {}
		local encoded = {(decrypt("\113\086\084\092\090\010\111\110\105\086", "1330")),(decrypt("\009\108\095\109\110\085\110\111\087\091\013\108\105\108\110", "2057")),(decrypt("\008\085\082\083\084\093", "2988")),(decrypt("\114\083\098\109\082\114\091\109\065\105\081", "1585")),(decrypt("\114\109\082\107", "2617")),(decrypt("\127\090\080\081\080\080\080\106", "540")),}

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
		ProtosConstants[14] = C1
	else
		C1 = ProtosConstants[14]
	end
	
	Stack[1] = function(...) -- PROTOTYPE 14
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 0}}
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
		if pointer == 1 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[15] then
		C1 = {}
		local encoded = {(decrypt("\025\019\021\059", "1420")),(decrypt("\009\083\090\099\084\086\085\101\104\088", "2309")),(decrypt("\011\111\088\085\107\099", "678")),(decrypt("\026\022\059", "2107")),(decrypt("\107\111\087\105\006", "573")),}

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
		ProtosConstants[15] = C1
	else
		C1 = ProtosConstants[15]
	end
	
	Stack[1] = function(...) -- PROTOTYPE 15
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {1, 0}, [1] = {0, 0}}
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
		if pointer == 1 then -- 4 [GETUPVAL] 
 	Stack[1] = Upvalues[0] 
elseif pointer == 2 then -- 14 [MUL] 
 	Stack[1] = Stack[1] * Constants[1] 
elseif pointer == 3 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[1] 
elseif pointer == 4 then -- 14 [MUL] 
 	Stack[2] = Stack[2] * Constants[4] 
elseif pointer == 5 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Stack[2] 
elseif pointer == 6 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Stack[0] 
elseif pointer == 7 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 8 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 4 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 5 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 3 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 4 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 77 then -- 5 [GETGLOBAL] 
 Temp[3] = 10
Temp[7] = 15
Temp[8] = Constants[Temp[7]]
Stack[Temp[3]] = vmEnv[Temp[8]] or Env[Temp[8]] 
elseif pointer == 78 then -- 0 [MOVE] 
 Temp[15] = 11
Temp[3] = 9
Stack[Temp[15]] = Stack[Temp[3]] 
elseif pointer == 79 then -- 1 [LOADK] 
 Temp[11] = 12
Temp[14] = Constants
Temp[7] = 16
Stack[Temp[11]] = Temp[14][Temp[7]]
	Stack[11] = Stack[11](Stack[12])
	pointer = pointer + 1 
elseif pointer == 81 then -- 1 [LOADK] 
 Temp[4] = 12
Temp[8] = Constants
Temp[15] = 14
Stack[Temp[4]] = Temp[8][Temp[15]]
	Stack[11] = Stack[11](Stack[12])
	pointer = pointer + 1 
elseif pointer == 83 then -- 1 [LOADK] 
 Temp[5] = 12
Temp[16] = Constants
Temp[15] = 7
Stack[Temp[5]] = Temp[16][Temp[15]]
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
	
	pointer = pointer + 1 
elseif pointer == 85 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 10 + 1, top do
		Temp[1][i - 10] = Stack[i]
	end
	Temp[2] = {Stack[10](unpack(Temp[1], 1, top - 10))}
		for i = 1, 0 do
		Stack[10 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 86 then -- 30 [RETURN] 
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