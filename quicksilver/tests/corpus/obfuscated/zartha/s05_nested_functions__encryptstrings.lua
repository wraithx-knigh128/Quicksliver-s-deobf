return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env[decrypt("\066\067\070\090\095\080", "1743")][decrypt("\082\093\087\065", "1563")],Env[decrypt("\066\065\075\089\095\082", "1590")][decrypt("\080\074\069\093", "2318")],Env[decrypt("\066\070\065\095\095\085", "1236")][decrypt("\065\077\082", "2806")],Env[decrypt("\067\088\065\067\069\091\089\080", "772")],Env[decrypt("\065\084\088\093\093", "1791")],Env[decrypt("\069\086\082\094\084", "1702")][decrypt("\071\087\064\084\081\082", "2905")] or Env[decrypt("\065\088\068\085\085\095", "464")],Env[decrypt("\069\084\080\092\084", "1520")][decrypt("\081\086\091\081\083\077", "2952")],Env[decrypt("\070\094\095\068\095\083\084\067", "2111")],Env[decrypt("\066\093\066\091\084\076\087\066\080\090\090\083", "1866")],decrypt("\109\102\092\093\070\088\069\089\080\085\084", "2918"),decrypt("\104\103\094\089\092\082\079", "787"),Env[decrypt("\090\092\065\068\075\089\076\064", "496")],Env[decrypt("\066\075\095\092\070", "2962")],{(decrypt("\025\017\051", "2683")),(decrypt("\111\127\001\004\117\114\003\001\115\005\002", "998")),(decrypt("\104\094\081\109\106\083", "2847")),(decrypt("\010\087\090", "2499")),(decrypt("\090\104\104\091\109", "1018")),(decrypt("\030\061", "2686")),(decrypt("\024\020\063", "2341")),(decrypt("\024\062", "1555")),(decrypt("\008\086\081\080\110\106\089\083\084\085\120\111\091\093\082\105\110", "2023")),(decrypt("\018", "1805")),(decrypt("\116\086\104\087\084\104\098\088\104\099\036\095\094\081\104\093", "834")),(decrypt("\026\051", "2823")),(decrypt("\085\094\085\092\089", "2759")),(decrypt("\025\056", "2332")),(decrypt("\025\031\062", "1859")),(decrypt("\028\058", "617")),},Env[decrypt("\066\088\095\064\074", "296")],decrypt("\109\102\094\087\078\089\092\093\085\074", "290"),Env[decrypt("\089\082\079\067", "777")],decrypt("\028", "2812"),Env[decrypt("\065\065\067\090\092\082", "2513")][decrypt("\085\075\068\084", "2816")],decrypt("\066\070\066\088\092\087", "120"),Env[decrypt("\065\076\065\080\092\095", "2839")][decrypt("\084\081\090\087", "2843")],Env[decrypt("\066\082\084\090\086", "636")][decrypt("\084\090\093\083", "2337")] or function(targetTable, value)
	for i,v in pairs(targetTable) do
		if v == value then
			return i
		end
	end
	
	return nil
end,Env[decrypt("\080\093\066\007\000", "2464")] and Env[decrypt("\080\091\076\003\000", "2280")][decrypt("\091\072\095\075", "900")] or function(a, b)
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
 Temp[9] = 0
Temp[14] = ttostring ~= __metatable
Stack[Temp[9]] = Temp[16] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[4] = vmEnv
Temp[5] = 2
Temp[10] = Constants[Temp[5]]
Temp[15] = 0
Temp[4][Temp[10]] = Temp[10] 
elseif pointer == 3 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\123\083\089", "132")),(decrypt("\123\107\089\113\088\087\086\110\088\071\117\110\088\092\008\011\088\111\086\106", "1726")),}

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
 Temp[11] = 2
Temp[16] = 0
Stack[Temp[11]] = Stack[Temp[16]] 
elseif pointer == 2 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[11] then
		C1 = {}
		local encoded = {(decrypt("\121\094\108\090\094\104\090\011\088\083", "354")),(decrypt("\084\105\073\096", "659")),(decrypt("\123\109\081\087\085\087\107", "552")),(decrypt("\013\093\092\105\087\087\088\106\123\087\094\090\117\105\081\090", "2181")),(decrypt("\114\084\090\104\081\081\108\039\106\088\105\092\086\109\082\091", "2170")),((decrypt("\022\020\020\029", "1135"))),}

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
		local encoded = {(decrypt("\011\083\111\093\091\117\111\083\109", "1077")),(decrypt("\118\084\083\084\089\104\092", "2468")),}

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
		local encoded = {(decrypt("\084\087\084\054", "1770")),(decrypt("\115\100\082\081\081\070\032\099\090\083\095", "786")),(decrypt("\117\106\104\104\084\089\110", "1264")),(decrypt("\120\086\107\087\106\093\089\091\110\033\085\087\095\110\086\082\105", "2652")),}

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
 	if Stack[1] == Constants[1] then pointer = pointer + 1 end 
elseif pointer == 4 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 5 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[1] 
elseif pointer == 6 then -- 0 [MOVE] 
 Temp[11] = 3
Temp[2] = 0
Stack[Temp[11]] = Stack[Temp[2]] 
elseif pointer == 7 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3]) 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[12] = 1
Temp[6] = 2
Stack[Temp[12]] = Stack[Temp[6]] 
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
 Temp[10] = 3
Temp[5] = 1
Stack[Temp[10]] = Stack[Temp[5]] 
elseif pointer == 7 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\114\081\009\087\084\111\081\095\015\089\104\086\095", "443")),(decrypt("\025\061", "1629")),(decrypt("\010\101\104\081\106\101\105", "1927")),(decrypt("\027\057", "2242")),}

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
 	Stack[2] = Stack[0] - Constants[2] 
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
Temp[16] = 3
Stack[Temp[5]] = Stack[Temp[16]] 
elseif pointer == 11 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\123\093\110\090\090\106\095\116\105\108\084", "1663")),((decrypt("\031\021\024\027\031", "2941"))),(decrypt("\008\097\095\085\107", "1955")),((decrypt("\028", "641"))),(decrypt("\120\008\014\028", "2764")),}

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
		local encoded = {(decrypt("\008\088\093\089\084\080", "2472")),(decrypt("\113\086\084\092\090\010\111\110\105\086", "1330")),(decrypt("\022\024\062", "2057")),(decrypt("\026\050", "2988")),}

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
 Temp[9] = 2
Temp[14] = Constants
Temp[3] = 4
Stack[Temp[9]] = Temp[14][Temp[3]] 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[4] = 3
Temp[10] = Constants
Temp[9] = 3
Stack[Temp[4]] = Temp[10][Temp[9]] 
elseif pointer == 5 then -- 32 [FORPREP] 
     Stack[1] = Stack[1] - Stack[3]
    pointer = pointer + 5
     
elseif pointer == 6 then -- 4 [GETUPVAL] 
 	Stack[5] = Upvalues[0] 
elseif pointer == 7 then -- 6 [GETTABLE] 
 	Stack[5] = Stack[5][Stack[4]]
	 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[9] = 6
Temp[15] = 0
Stack[Temp[9]] = Stack[Temp[15]] 
elseif pointer == 9 then -- 28 [CALL] 
 	Stack[5] = Stack[5](Stack[6]) 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[1] = 0
Temp[6] = 5
Stack[Temp[1]] = Stack[Temp[6]] 
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
		local encoded = {(decrypt("\114\081\087\092\089\008\085\107\110\111", "2400")),((decrypt("\029\029\022\029\001\031\028", "1334"))),(decrypt("\014\107\091\089", "2312")),(decrypt("\081\084\106\086\088\089", "1326")),(decrypt("\113\081\090\095\107", "576")),(decrypt("\110\090\093\080\091\000\016\017", "1167")),}

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
 Temp[9] = 3
Temp[13] = 4
Temp[16] = Constants[Temp[13]]
Stack[Temp[9]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 3 then -- 0 [MOVE] 
 Temp[16] = 4
Temp[4] = 0
Stack[Temp[16]] = Stack[Temp[4]] 
elseif pointer == 4 then -- 28 [CALL] 
 	Stack[3], Stack[4], Stack[5] = Stack[3](Stack[4]) 
elseif pointer == 5 then -- 22 [JMP] 
 pointer = pointer + 5  
elseif pointer == 6 then -- 0 [MOVE] 
 Temp[14] = 8
Temp[8] = 1
Stack[Temp[14]] = Stack[Temp[8]] 
elseif pointer == 7 then -- 0 [MOVE] 
 Temp[4] = 9
Temp[16] = 7
Stack[Temp[4]] = Stack[Temp[16]] 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[1] = 10
Temp[3] = 6
Stack[Temp[1]] = Stack[Temp[3]] 
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
		local encoded = {((decrypt("\021\017\025\021\031", "2448"))),(decrypt("\015\083\080\085\088\108\105\110", "2355")),((decrypt("\024\030\028\022", "1979"))),(decrypt("\031\051", "782")),(decrypt("\043", "1666")),(decrypt("\089\108\087\111\106\095", "304")),(decrypt("\010\106\094\097\123\089\083\080\109\120\105\080\092\082\111\101", "1259")),(decrypt("\021\060", "2734")),}

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
 Temp[10] = 1
Temp[3] = Constants
Temp[15] = 8
Stack[Temp[10]] = Temp[3][Temp[15]] 
elseif pointer == 2 then -- 1 [LOADK] 
 Temp[10] = 2
Temp[7] = Constants
Temp[13] = 4
Stack[Temp[10]] = Temp[7][Temp[13]] 
elseif pointer == 3 then -- 5 [GETGLOBAL] 
 Temp[1] = 3
Temp[10] = 6
Temp[12] = Constants[Temp[10]]
Stack[Temp[1]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[2] = 4
Temp[13] = Constants
Temp[5] = 5
Stack[Temp[2]] = Temp[13][Temp[5]] 
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
 Temp[5] = 4
Temp[15] = Constants
Temp[11] = 4
Stack[Temp[5]] = Temp[15][Temp[11]] 
elseif pointer == 8 then -- 32 [FORPREP] 
     Stack[2] = Stack[2] - Stack[4]
    pointer = pointer + 5
     
elseif pointer == 9 then -- 5 [GETGLOBAL] 
 Temp[6] = 6
Temp[2] = 6
Temp[10] = Constants[Temp[2]]
Stack[Temp[6]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[9] = 7
Temp[4] = 5
Stack[Temp[9]] = Stack[Temp[4]] 
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
 Temp[6] = 6
Temp[3] = 0
Stack[Temp[6]] = Stack[Temp[3]] 
elseif pointer == 15 then -- 1 [LOADK] 
 Temp[5] = 7
Temp[6] = Constants
Temp[16] = 15
Stack[Temp[5]] = Temp[6][Temp[16]] 
elseif pointer == 16 then -- 1 [LOADK] 
 Temp[10] = 8
Temp[4] = Constants
Temp[13] = 6
Stack[Temp[10]] = Temp[4][Temp[13]]
	Stack[6] = Stack[6](Stack[7], Stack[8])
	pointer = pointer + 1 
elseif pointer == 18 then -- 5 [GETGLOBAL] 
 Temp[2] = 7
Temp[15] = 13
Temp[6] = Constants[Temp[15]]
Stack[Temp[2]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 19 then -- 0 [MOVE] 
 Temp[6] = 8
Temp[14] = 6
Stack[Temp[6]] = Stack[Temp[14]] 
elseif pointer == 20 then -- 28 [CALL] 
 	Stack[8] = Stack[8]() 
elseif pointer == 21 then -- 0 [MOVE] 
 Temp[5] = 9
Temp[3] = 6
Stack[Temp[5]] = Stack[Temp[3]] 
elseif pointer == 22 then -- 28 [CALL] 
 	Stack[9] = Stack[9]() 
elseif pointer == 23 then -- 0 [MOVE] 
 Temp[7] = 10
Temp[11] = 6
Stack[Temp[7]] = Stack[Temp[11]] 
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
 Temp[5] = 7
Temp[7] = 13
Temp[15] = Constants[Temp[7]]
Stack[Temp[5]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 27 then -- 0 [MOVE] 
 Temp[9] = 8
Temp[12] = 2
Stack[Temp[9]] = Stack[Temp[12]] 
elseif pointer == 28 then -- 1 [LOADK] 
 Temp[14] = 9
Temp[15] = Constants
Temp[7] = 7
Stack[Temp[14]] = Temp[15][Temp[7]]
	Stack[8] = Stack[8](Stack[9])
	pointer = pointer + 1 
elseif pointer == 30 then -- 0 [MOVE] 
 Temp[7] = 9
Temp[4] = 2
Stack[Temp[7]] = Stack[Temp[4]] 
elseif pointer == 31 then -- 1 [LOADK] 
 Temp[11] = 10
Temp[7] = Constants
Temp[10] = 1
Stack[Temp[11]] = Temp[7][Temp[10]]
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
		local encoded = {(decrypt("\120\014\012\029\030\028", "2144")),(decrypt("\028\061", "469")),(decrypt("\014\111\094", "1310")),}

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
 	Stack[1] = Stack[0] + Constants[2] 
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
		local encoded = {(decrypt("\009\012\123\013\121\012", "2081")),((decrypt("\025\031\019", "288"))),(decrypt("\122\106\082\101\086\080\088\082\123\106\088\084\081\108\109", "1619")),(decrypt("\113\100\100\093", "2896")),((decrypt("\026\022\031", "1144"))),(decrypt("\024\056", "1336")),}

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
 	Stack[1] = Stack[0] * Constants[6] 
elseif pointer == 2 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 3 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 36 then -- 5 [GETGLOBAL] 
 Temp[14] = 9
Temp[12] = 13
Temp[15] = Constants[Temp[12]]
Stack[Temp[14]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 37 then -- 0 [MOVE] 
 Temp[13] = 10
Temp[6] = 3
Stack[Temp[13]] = Stack[Temp[6]] 
elseif pointer == 38 then -- 0 [MOVE] 
 Temp[2] = 11
Temp[9] = 7
Stack[Temp[2]] = Stack[Temp[9]] 
elseif pointer == 39 then -- 0 [MOVE] 
 Temp[7] = 12
Temp[16] = 8
Stack[Temp[7]] = Stack[Temp[16]] 
elseif pointer == 40 then -- 28 [CALL] 
 	Stack[10] = Stack[10](Stack[11], Stack[12]) 
elseif pointer == 41 then -- 1 [LOADK] 
 Temp[15] = 11
Temp[13] = Constants
Temp[3] = 6
Stack[Temp[15]] = Temp[13][Temp[3]]
	Stack[10] = Stack[10](Stack[11])
	pointer = pointer + 1 
elseif pointer == 43 then -- 0 [MOVE] 
 Temp[16] = 11
Temp[4] = 3
Stack[Temp[16]] = Stack[Temp[4]] 
elseif pointer == 44 then -- 0 [MOVE] 
 Temp[10] = 12
Temp[8] = 8
Stack[Temp[10]] = Stack[Temp[8]] 
elseif pointer == 45 then -- 0 [MOVE] 
 Temp[1] = 13
Temp[8] = 7
Stack[Temp[1]] = Stack[Temp[8]] 
elseif pointer == 46 then -- 28 [CALL] 
 	Stack[11] = Stack[11](Stack[12], Stack[13]) 
elseif pointer == 47 then -- 1 [LOADK] 
 Temp[1] = 12
Temp[12] = Constants
Temp[5] = 6
Stack[Temp[1]] = Temp[12][Temp[5]]
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
Temp[11] = 13
Temp[12] = Constants[Temp[11]]
Stack[Temp[14]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 51 then -- 5 [GETGLOBAL] 
 Temp[5] = 10
Temp[14] = 5
Temp[7] = Constants[Temp[14]]
Stack[Temp[5]] = vmEnv[Temp[7]] or Env[Temp[7]]
	Stack[10] = Stack[10][Constants[3]]
	
	pointer = pointer + 1 
elseif pointer == 53 then -- 0 [MOVE] 
 Temp[11] = 11
Temp[7] = 4
Stack[Temp[11]] = Stack[Temp[7]] 
elseif pointer == 54 then -- 10 [NEWTABLE] 
 	Stack[12] = {} 
elseif pointer == 55 then -- 1 [LOADK] 
 Temp[4] = 13
Temp[6] = Constants
Temp[5] = 12
Stack[Temp[4]] = Temp[6][Temp[5]] 
elseif pointer == 56 then -- 1 [LOADK] 
 Temp[1] = 14
Temp[12] = Constants
Temp[7] = 8
Stack[Temp[1]] = Temp[12][Temp[7]] 
elseif pointer == 57 then -- 1 [LOADK] 
 Temp[10] = 15
Temp[3] = Constants
Temp[7] = 16
Stack[Temp[10]] = Temp[3][Temp[7]] 
elseif pointer == 58 then -- 1 [LOADK] 
 Temp[8] = 16
Temp[15] = Constants
Temp[3] = 14
Stack[Temp[8]] = Temp[15][Temp[3]] 
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
		local encoded = {(decrypt("\093\100\089\093\088\085\082\110", "783")),(decrypt("\120\085\111\107\090", "1514")),(decrypt("\002\109\067\083", "953")),(decrypt("\011\097\092\009\087\090\090\083\106\101", "1993")),(decrypt("\127\085\106\072\106\091\113\106\086\094\091\082\093\104", "862")),}

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
 Temp[11] = 12
Temp[14] = Constants
Temp[7] = 10
Stack[Temp[11]] = Temp[14][Temp[7]]
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
 Temp[4] = 9
Temp[8] = 13
Temp[15] = Constants[Temp[8]]
Stack[Temp[4]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 66 then -- 0 [MOVE] 
 Temp[5] = 10
Temp[16] = 5
Stack[Temp[5]] = Stack[Temp[16]] 
elseif pointer == 67 then -- 1 [LOADK] 
 Temp[15] = 11
Temp[16] = Constants
Temp[4] = 12
Stack[Temp[15]] = Temp[16][Temp[4]] 
elseif pointer == 68 then -- 1 [LOADK] 
 Temp[12] = 12
Temp[11] = Constants
Temp[16] = 8
Stack[Temp[12]] = Temp[11][Temp[16]] 
elseif pointer == 69 then -- 1 [LOADK] 
 Temp[16] = 13
Temp[9] = Constants
Temp[6] = 16
Stack[Temp[16]] = Temp[9][Temp[6]] 
elseif pointer == 70 then -- 1 [LOADK] 
 Temp[10] = 14
Temp[15] = Constants
Temp[16] = 14
Stack[Temp[10]] = Temp[15][Temp[16]] 
elseif pointer == 71 then -- 1 [LOADK] 
 Temp[4] = 15
Temp[11] = Constants
Temp[12] = 6
Stack[Temp[4]] = Temp[11][Temp[12]]
	Stack[10] = Stack[10](Stack[11], Stack[12], Stack[13], Stack[14], Stack[15])
	pointer = pointer + 1 
elseif pointer == 73 then -- 0 [MOVE] 
 Temp[11] = 11
Temp[4] = 5
Stack[Temp[11]] = Stack[Temp[4]] 
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
		local encoded = {((decrypt("\021\019\026\017\028", "2646"))),(decrypt("\013\089\084\096\087\083\080\099", "2508")),(decrypt("\088\101\090\089\082\092\111\088\100", "2912")),(decrypt("\115\083\106\080\083\110\098", "982")),(decrypt("\127\107\081\081\081\086\102", "1384")),(decrypt("\009\080\094\111\107\083\104\108", "2047")),}

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
		local encoded = {(decrypt("\114\085\084\105\081\080\098\038\106\089\103\093\086\108\092\090", "2091")),(decrypt("\125\082\110\094\082\106\094\126\110\109\091", "796")),(decrypt("\118\082\086\089\107\089", "243")),(decrypt("\118\081\088\095\110", "2745")),(decrypt("\124\086\094\085\104\085\104", "1645")),}

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
		local encoded = {(decrypt("\010\108\080\106\065", "1032")),(decrypt("\118\110\088\083\011\094\081\012\103\088\085\099", "868")),(decrypt("\080\106\064\100", "260")),((decrypt("\025\030\031\030", "1989"))),(decrypt("\026\017\016\060", "2677")),(decrypt("\025\018\051", "1581")),(decrypt("\097", "1298")),}

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
 	Stack[1] = Stack[1] * Constants[5] 
elseif pointer == 3 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[1] 
elseif pointer == 4 then -- 14 [MUL] 
 	Stack[2] = Stack[2] * Constants[6] 
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
 Temp[14] = 10
Temp[1] = 13
Temp[12] = Constants[Temp[1]]
Stack[Temp[14]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 78 then -- 0 [MOVE] 
 Temp[13] = 11
Temp[4] = 9
Stack[Temp[13]] = Stack[Temp[4]] 
elseif pointer == 79 then -- 1 [LOADK] 
 Temp[7] = 12
Temp[10] = Constants
Temp[2] = 12
Stack[Temp[7]] = Temp[10][Temp[2]]
	Stack[11] = Stack[11](Stack[12])
	pointer = pointer + 1 
elseif pointer == 81 then -- 1 [LOADK] 
 Temp[8] = 12
Temp[14] = Constants
Temp[1] = 8
Stack[Temp[8]] = Temp[14][Temp[1]]
	Stack[11] = Stack[11](Stack[12])
	pointer = pointer + 1 
elseif pointer == 83 then -- 1 [LOADK] 
 Temp[6] = 12
Temp[14] = Constants
Temp[5] = 16
Stack[Temp[6]] = Temp[14][Temp[5]]
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