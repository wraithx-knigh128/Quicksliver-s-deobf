return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env[decrypt("\066\067\070\090\095\080", "1743")][decrypt("\082\093\087\065", "1563")],Env[decrypt("\066\065\075\089\095\082", "1590")][decrypt("\080\074\069\093", "2318")],Env[decrypt("\066\070\065\095\095\085", "1236")][decrypt("\065\077\082", "2806")],Env[decrypt("\067\088\065\067\069\091\089\080", "772")],Env[decrypt("\065\084\088\093\093", "1791")],Env[decrypt("\069\086\082\094\084", "1702")][decrypt("\071\087\064\084\081\082", "2905")] or Env[decrypt("\065\088\068\085\085\095", "464")],Env[decrypt("\069\084\080\092\084", "1520")][decrypt("\081\086\091\081\083\077", "2952")],Env[decrypt("\070\094\095\068\095\083\084\067", "2111")],Env[decrypt("\066\093\066\091\084\076\087\066\080\090\090\083", "1866")],decrypt("\109\102\092\093\070\088\069\089\080\085\084", "2918"),decrypt("\104\103\094\089\092\082\079", "787"),Env[decrypt("\090\092\065\068\075\089\076\064", "496")],Env[decrypt("\066\075\095\092\070", "2962")],{(decrypt("\022\028\051", "2686")),(decrypt("\021\056", "2341")),(decrypt("\086\092\085\080\090", "1555")),(decrypt("\028\059", "2023")),(decrypt("\009\098\106\105\086\083", "1805")),(decrypt("\016\026\063", "834")),(decrypt("\089\094\089\107\081", "2823")),(decrypt("\114\014\099\125\010\120\099\003\015\116\115\119\100\011\112\002", "2759")),(decrypt("\025\056", "2332")),(decrypt("\081\095\109\089\088\082", "1859")),(decrypt("\009\109\111\095\090\110\106\105\092", "617")),(decrypt("\113\015\102\113\116\117\112\116\113\115\014\103\123\125\008\120\122", "1601")),(decrypt("\026\062", "2587")),(decrypt("\115\085\083\094\082\092\105", "2979")),(decrypt("\031\016\061", "776")),(decrypt("\119\014\110\115\015\119\097\013\005\116\113\118\097\125\115\015\126\115", "778")),(decrypt("\111\115\000\004\121\115\003\013\114\005\014", "959")),(decrypt("\088\100\083\111\104\083", "2803")),(decrypt("\035", "981")),(decrypt("\030\059", "707")),(decrypt("\029\051", "1847")),},Env[decrypt("\066\088\095\064\074", "296")],decrypt("\109\102\094\087\078\089\092\093\085\074", "290"),Env[decrypt("\089\082\079\067", "777")],decrypt("\028", "2812"),Env[decrypt("\065\065\067\090\092\082", "2513")][decrypt("\085\075\068\084", "2816")],decrypt("\066\070\066\088\092\087", "120"),Env[decrypt("\065\076\065\080\092\095", "2839")][decrypt("\084\081\090\087", "2843")],Env[decrypt("\066\082\084\090\086", "636")][decrypt("\084\090\093\083", "2337")] or function(targetTable, value)
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
 Temp[10] = 0
Temp[5] = ttostring ~= __metatable
Stack[Temp[10]] = Temp[16] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[6] = vmEnv
Temp[3] = 17
Temp[5] = Constants[Temp[3]]
Temp[16] = 0
Temp[6][Temp[5]] = Temp[5] 
elseif pointer == 3 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\113\090\111\070\101\094\092", "697")),(decrypt("\012\086\082\081\092\104\109\109", "167")),(decrypt("\122\085\094\107\108\014\084\104\110\106", "132")),((decrypt("\026\016\002\027", "1726"))),}

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
 Temp[10] = vmEnv
Temp[4] = 16
Temp[13] = Constants[Temp[4]]
Temp[2] = 0
Temp[10][Temp[13]] = Temp[13] 
elseif pointer == 5 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\124\109\084\089\015\083\093\008\109\085\087\105", "2542")),(decrypt("\008\084\085\085\105\084\093\083", "2236")),(decrypt("\118\087\086\089\089\107\089", "2735")),(decrypt("\080\110\066\100", "222")),(decrypt("\014\082\080\082\093", "443")),}

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
 Temp[15] = vmEnv
Temp[6] = 8
Temp[5] = Constants[Temp[6]]
Temp[14] = 0
Temp[15][Temp[5]] = Temp[5] 
elseif pointer == 7 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\014\095\095\083\123\104\093\089\081\110\104", "1444")),(decrypt("\009\086\089\106\107\085\111\105", "2632")),((decrypt("\022\016\021", "1595"))),(decrypt("\008\095\084\094\081\101\091\101", "2909")),}

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
 Temp[3] = vmEnv
Temp[7] = 12
Temp[5] = Constants[Temp[7]]
Temp[11] = 0
Temp[3][Temp[5]] = Temp[5] 
elseif pointer == 9 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\114\014\096\116\119\116\118\113\114\114\008\098\120\124\014\125\121", "2764")),(decrypt("\013\111\096\087\089\108", "2384")),(decrypt("\121\092\105\105\110", "2513")),}

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
 Temp[2] = 2
Temp[10] = 1
Temp[3] = Constants[Temp[10]]
Stack[Temp[2]] = vmEnv[Temp[3]] or Env[Temp[3]] 
elseif pointer == 2 then -- 2 [LOADBOOL] 
 Temp[15] = 3
Temp[10] = ttostring ~= __metatable
Stack[Temp[15]] = Temp[6] 
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
		local encoded = {(decrypt("\114\000\097\112\119\122\119\117\114\124\009\102\120\114\015\121\121", "2970")),(decrypt("\120\101\104\084\087\098\088", "2922")),(decrypt("\012\100\110\091\102\032\083\094\108\107\047\107\082\096\110\084\100\108", "787")),(decrypt("\015\110\080\082\110\109\039\090\084\033\080\084\082\093\080\105\081\086\065\109", "2601")),(decrypt("\124\085\091\087\104\086\109", "1517")),((decrypt("\030\030\018\017\030\018\017", "695"))),}

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
 Temp[16] = 2
Temp[1] = 1
Temp[3] = Constants[Temp[1]]
Stack[Temp[16]] = vmEnv[Temp[3]] or Env[Temp[3]] 
elseif pointer == 2 then -- 2 [LOADBOOL] 
 Temp[10] = 3
Temp[4] = ttostring ~= __metatable
Stack[Temp[10]] = Temp[2] 
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
		local encoded = {((decrypt("\020\021\030\025\026", "304"))),(decrypt("\117\084\089\083\109", "1259")),(decrypt("\027\060", "2734")),(decrypt("\109\085\109\080", "1815")),(decrypt("\083\108\111\110\091\081\091\108", "601")),(decrypt("\067\107\089\085", "2703")),(decrypt("\113\014\101\115\009\120\101\013\012\116\117\121\103\125\120\015\120\124", "1737")),(decrypt("\022\057", "1288")),(decrypt("\118\111\107\083\094\087", "2303")),(decrypt("\114\012\101\118\013\124\100\015\014\113\115\125\100\009\118\009", "253")),(decrypt("\087\099\099", "1883")),}

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
 Temp[12] = 1
Temp[2] = 7
Temp[13] = Constants[Temp[2]]
Stack[Temp[12]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 2 then -- 28 [CALL] 
 	Stack[1]() 
elseif pointer == 3 then -- 3 [LOADNIL] 
 	Stack[1], Stack[2] = nil 
elseif pointer == 4 then -- 24 [LT] 
 	if Stack[0] < Constants[8] then pointer = pointer + 1 end 
elseif pointer == 5 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 6 then -- 1 [LOADK] 
 Temp[5] = 1
Temp[15] = Constants
Temp[11] = 5
Stack[Temp[5]] = Temp[15][Temp[11]] 
elseif pointer == 7 then -- 22 [JMP] 
 pointer = pointer + 10  
elseif pointer == 8 then -- 23 [EQ] 
 	if Stack[0] == Constants[8] then pointer = pointer + 1 end 
elseif pointer == 9 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 10 then -- 1 [LOADK] 
 Temp[6] = 1
Temp[2] = Constants
Temp[10] = 6
Stack[Temp[6]] = Temp[2][Temp[10]] 
elseif pointer == 11 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 12 then -- 16 [MOD] 
 	Stack[2] = Stack[0] % Constants[3] 
elseif pointer == 13 then -- 23 [EQ] 
 	if Stack[2] == Constants[8] then pointer = pointer + 1 end 
elseif pointer == 14 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 15 then -- 1 [LOADK] 
 Temp[9] = 1
Temp[4] = Constants
Temp[2] = 4
Stack[Temp[9]] = Temp[4][Temp[2]] 
elseif pointer == 16 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 17 then -- 1 [LOADK] 
 Temp[2] = 1
Temp[1] = Constants
Temp[15] = 11
Stack[Temp[2]] = Temp[1][Temp[15]] 
elseif pointer == 18 then -- 5 [GETGLOBAL] 
 Temp[15] = 2
Temp[12] = 10
Temp[3] = Constants[Temp[12]]
Stack[Temp[15]] = vmEnv[Temp[3]] or Env[Temp[3]] 
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
 Temp[7] = 3
Temp[15] = Constants
Temp[9] = 2
Stack[Temp[7]] = Temp[15][Temp[9]] 
elseif pointer == 13 then -- 1 [LOADK] 
 Temp[12] = 4
Temp[14] = Constants
Temp[15] = 13
Stack[Temp[12]] = Temp[14][Temp[15]] 
elseif pointer == 14 then -- 1 [LOADK] 
 Temp[7] = 5
Temp[4] = Constants
Temp[11] = 15
Stack[Temp[7]] = Temp[4][Temp[11]] 
elseif pointer == 15 then -- 1 [LOADK] 
 Temp[7] = 6
Temp[10] = Constants
Temp[14] = 13
Stack[Temp[7]] = Temp[10][Temp[14]] 
elseif pointer == 16 then -- 32 [FORPREP] 
     Stack[4] = Stack[4] - Stack[6]
    pointer = pointer + 5
     
elseif pointer == 17 then -- 0 [MOVE] 
 Temp[12] = 8
Temp[15] = 0
Stack[Temp[12]] = Stack[Temp[15]] 
elseif pointer == 18 then -- 0 [MOVE] 
 Temp[13] = 9
Temp[6] = 3
Stack[Temp[13]] = Stack[Temp[6]] 
elseif pointer == 19 then -- 0 [MOVE] 
 Temp[2] = 10
Temp[9] = 7
Stack[Temp[2]] = Stack[Temp[9]] 
elseif pointer == 20 then -- 28 [CALL] 
 	Stack[8] = Stack[8](Stack[9], Stack[10]) 
elseif pointer == 21 then -- 0 [MOVE] 
 Temp[7] = 3
Temp[16] = 8
Stack[Temp[7]] = Stack[Temp[16]] 
elseif pointer == 22 then -- 31 [FORLOOP] 
     Stack[4] = Stack[4] + Stack[6]
    if (Stack[6] > 0 and Stack[4] <= Stack[5]) or (Stack[6] <= 0 and Stack[4] >= Stack[5]) then
        pointer = pointer + -6
        Stack[7] = Stack[4]
    end
     
elseif pointer == 23 then -- 5 [GETGLOBAL] 
 Temp[15] = 4
Temp[13] = 3
Temp[3] = Constants[Temp[13]]
Stack[Temp[15]] = vmEnv[Temp[3]] or Env[Temp[3]] 
elseif pointer == 24 then -- 1 [LOADK] 
 Temp[16] = 5
Temp[4] = Constants
Temp[10] = 7
Stack[Temp[16]] = Temp[4][Temp[10]] 
elseif pointer == 25 then -- 0 [MOVE] 
 Temp[10] = 6
Temp[8] = 3
Stack[Temp[10]] = Stack[Temp[8]] 
elseif pointer == 26 then -- 28 [CALL] 
 	Stack[4](Stack[5], Stack[6]) 
elseif pointer == 27 then -- 5 [GETGLOBAL] 
 Temp[1] = 4
Temp[8] = 10
Temp[12] = Constants[Temp[8]]
Stack[Temp[1]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 28 then -- 10 [NEWTABLE] 
 	Stack[5] = {} 
elseif pointer == 29 then -- 1 [LOADK] 
 Temp[5] = 6
Temp[14] = Constants
Temp[11] = 1
Stack[Temp[5]] = Temp[14][Temp[11]] 
elseif pointer == 30 then -- 1 [LOADK] 
 Temp[12] = 7
Temp[5] = Constants
Temp[14] = 2
Stack[Temp[12]] = Temp[5][Temp[14]] 
elseif pointer == 31 then -- 1 [LOADK] 
 Temp[7] = 8
Temp[11] = Constants
Temp[4] = 9
Stack[Temp[7]] = Temp[11][Temp[4]] 
elseif pointer == 32 then -- 1 [LOADK] 
 Temp[6] = 9
Temp[5] = Constants
Temp[1] = 4
Stack[Temp[6]] = Temp[5][Temp[1]] 
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
Temp[7] = 3
Temp[10] = Constants[Temp[7]]
Stack[Temp[12]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 37 then -- 0 [MOVE] 
 Temp[3] = 10
Temp[7] = 8
Stack[Temp[3]] = Stack[Temp[7]] 
elseif pointer == 38 then -- 0 [MOVE] 
 Temp[8] = 11
Temp[15] = 2
Stack[Temp[8]] = Stack[Temp[15]] 
elseif pointer == 39 then -- 0 [MOVE] 
 Temp[3] = 12
Temp[11] = 8
Stack[Temp[3]] = Stack[Temp[11]] 
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
 Temp[14] = 4
Temp[7] = 1
Stack[Temp[14]] = Stack[Temp[7]] 
elseif pointer == 45 then -- 1 [LOADK] 
 Temp[4] = 5
Temp[8] = Constants
Temp[15] = 6
Stack[Temp[4]] = Temp[8][Temp[15]] 
elseif pointer == 46 then -- 1 [LOADK] 
 Temp[5] = 6
Temp[16] = Constants
Temp[15] = 21
Stack[Temp[5]] = Temp[16][Temp[15]]
	Stack[4], Stack[5] = Stack[4](Stack[5], Stack[6])
	pointer = pointer + 1 
elseif pointer == 48 then -- 5 [GETGLOBAL] 
 Temp[16] = 6
Temp[4] = 3
Temp[12] = Constants[Temp[4]]
Stack[Temp[16]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 49 then -- 0 [MOVE] 
 Temp[11] = 7
Temp[16] = 4
Stack[Temp[11]] = Stack[Temp[16]] 
elseif pointer == 50 then -- 0 [MOVE] 
 Temp[16] = 8
Temp[9] = 5
Stack[Temp[16]] = Stack[Temp[9]] 
elseif pointer == 51 then -- 28 [CALL] 
 	Stack[6](Stack[7], Stack[8]) 
elseif pointer == 52 then -- 5 [GETGLOBAL] 
 Temp[6] = 6
Temp[10] = 3
Temp[15] = Constants[Temp[10]]
Stack[Temp[6]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 53 then -- 5 [GETGLOBAL] 
 Temp[10] = 7
Temp[16] = 18
Temp[4] = Constants[Temp[16]]
Stack[Temp[10]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 54 then -- 1 [LOADK] 
 Temp[11] = 8
Temp[12] = Constants
Temp[4] = 19
Stack[Temp[11]] = Temp[12][Temp[4]] 
elseif pointer == 55 then -- 0 [MOVE] 
 Temp[14] = 9
Temp[1] = 1
Stack[Temp[14]] = Stack[Temp[1]] 
elseif pointer == 56 then -- 1 [LOADK] 
 Temp[12] = 10
Temp[13] = Constants
Temp[4] = 13
Stack[Temp[12]] = Temp[13][Temp[4]] 
elseif pointer == 57 then -- 1 [LOADK] 
 Temp[7] = 11
Temp[10] = Constants
Temp[2] = 20
Stack[Temp[7]] = Temp[10][Temp[2]]
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