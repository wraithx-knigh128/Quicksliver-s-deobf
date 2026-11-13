return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\122\105\093\085\109\088\046\105\109\090\101\104\090\109\098", "1192")),(decrypt("\103\098\106\038\023\026\026\047\027\020\024\038\013\047", "981")),(decrypt("\024\028\057", "2127")),(decrypt("\029\059", "302")),(decrypt("\088\107\095\092\110\092\108\083\106\110\087\100", "2748")),(decrypt("\104\083\108\081\085\001\035", "2045")),(decrypt("\093\097\091\099\102", "990")),(decrypt("\024\017\027\025\028\031\002\063", "243")),(decrypt("\089\086\085\090\086\105\108\095", "2006")),(decrypt("\025\058", "1187")),(decrypt("\031\020\063", "434")),(decrypt("\110\095\081\085\091", "2683")),(decrypt("\021\030\051", "998")),(decrypt("\120\094\088\092\109", "2847")),(decrypt("\021\063", "2499")),(decrypt("\103\102\090\094\091\091\088\088\084\110", "1018")),(decrypt("\111\080\081\082\106\093", "2686")),(decrypt("\026\020\063", "2341")),(decrypt("\015\083\086\110", "1555")),(decrypt("\029\027\057", "2023")),(decrypt("\103\110\080\080\106\100\095", "1805")),(decrypt("\095\105\108\091\080", "834")),(decrypt("\026\020\057", "2823")),(decrypt("\085\094\085\092\089", "2759")),(decrypt("\046\104\017", "2332")),(decrypt("\038", "1859")),(decrypt("\125\087\091\108\110\011\083\106\107\109", "617")),(decrypt("\086\095\080\085\109\092\001\038", "1601")),(decrypt("\088\094\081\087\087\107", "2587")),(decrypt("\100\111\087\082\110\080", "2979")),(decrypt("\111\110", "776")),(decrypt("\097\097\092\107\092\096\092\111\097\084\107", "778")),(decrypt("\026", "959")),(decrypt("\022\018\059", "2803")),(decrypt("\111\126\008\004\116\123\003\000\122\005\003", "981")),(decrypt("\043\028\018\030\109\068\043\020\026\093\067\043\016\026\108", "707")),(decrypt("\010\100\087\111\065", "1847")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
 Temp[10] = 0
Temp[5] = byte == pairs
Stack[Temp[10]] = Temp[16] 
elseif pointer == 2 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\013\085\110\094\065\087\095\107\106", "1047")),((decrypt("\030\028\018\017\002\030\024", "2278"))),(decrypt("\111\003\120\001\115\014", "991")),}

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
	
	Stack[1] = function(...) -- PROTOTYPE 1
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
		if pointer == 1 then -- 2 [LOADBOOL] 
 Temp[13] = 0
Temp[7] = ttostring ~= __metatable
Stack[Temp[13]] = Temp[3] 
elseif pointer == 2 then -- 8 [SETUPVAL] 
 	Upvalues[0] = Stack[0] 
elseif pointer == 3 then -- INVALID [INVALID] 
 --INVALID OPCODE (EMPTY) 
elseif pointer == 4 then -- _CRASH [_CRASH] 
 		pointer = pointer + 40^10
	 
elseif pointer == 5 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 4 then -- 5 [GETGLOBAL] 
 Temp[6] = 2
Temp[3] = 5
Temp[5] = Constants[Temp[3]]
Stack[Temp[6]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 5 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 6 then -- 10 [NEWTABLE] 
 	Stack[4] = {} 
elseif pointer == 7 then -- 9 [SETTABLE] 
 	Stack[4][Constants[16]] = Stack[1] 
elseif pointer == 8 then -- 9 [SETTABLE] 
 	Stack[4][Constants[30]] = Stack[1] 
elseif pointer == 9 then -- 9 [SETTABLE] 
 	Stack[4][Constants[21]] = Stack[1] 
elseif pointer == 10 then -- 9 [SETTABLE] 
 	Stack[4][Constants[32]] = Constants[10] 
elseif pointer == 11 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3], Stack[4]) 
elseif pointer == 12 then -- 5 [GETGLOBAL] 
 Temp[6] = 3
Temp[16] = 22
Temp[10] = Constants[Temp[16]]
Stack[Temp[6]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 13 then -- 5 [GETGLOBAL] 
 Temp[4] = 4
Temp[13] = 22
Temp[2] = Constants[Temp[13]]
Stack[Temp[4]] = vmEnv[Temp[2]] or Env[Temp[2]] 
elseif pointer == 14 then -- 0 [MOVE] 
 Temp[15] = 5
Temp[6] = 2
Stack[Temp[15]] = Stack[Temp[6]] 
elseif pointer == 15 then -- 0 [MOVE] 
 Temp[6] = 6
Temp[14] = 2
Stack[Temp[6]] = Stack[Temp[14]] 
elseif pointer == 16 then -- 28 [CALL] 
 	Stack[3](Stack[4], Stack[5], Stack[6]) 
elseif pointer == 17 then -- 5 [GETGLOBAL] 
 Temp[5] = 3
Temp[3] = 22
Temp[7] = Constants[Temp[3]]
Stack[Temp[5]] = vmEnv[Temp[7]] or Env[Temp[7]] 
elseif pointer == 18 then -- 5 [GETGLOBAL] 
 Temp[7] = 4
Temp[11] = 9
Temp[5] = Constants[Temp[11]]
Stack[Temp[7]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 19 then -- 0 [MOVE] 
 Temp[7] = 5
Temp[15] = 2
Stack[Temp[7]] = Stack[Temp[15]] 
elseif pointer == 20 then -- 28 [CALL] 
 	Stack[3](Stack[4], Stack[5]) 
elseif pointer == 21 then -- 5 [GETGLOBAL] 
 Temp[9] = 3
Temp[12] = 22
Temp[14] = Constants[Temp[12]]
Stack[Temp[9]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 22 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\105\109\027", "1517")),((decrypt("\031\030\029", "695"))),(decrypt("\120\083\084\094\085\100\105", "2829")),(decrypt("\117\094\092\091\100", "180")),}

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
	
	Stack[4] = function(...) -- PROTOTYPE 2
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
 Temp[3] = 0
Temp[10] = 1
Temp[4] = Constants[Temp[10]]
Stack[Temp[3]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 2 then -- 28 [CALL] 
 	Stack[0]() 
elseif pointer == 3 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 23 then -- 28 [CALL] 
 	Stack[3], Stack[4] = Stack[3](Stack[4]) 
elseif pointer == 24 then -- 26 [TEST] 
 	if not Stack[0] then pointer = pointer + 1 end 
elseif pointer == 25 then -- 22 [JMP] 
 pointer = pointer + 7  
elseif pointer == 26 then -- 5 [GETGLOBAL] 
 Temp[14] = 5
Temp[15] = 9
Temp[7] = Constants[Temp[15]]
Stack[Temp[14]] = vmEnv[Temp[7]] or Env[Temp[7]] 
elseif pointer == 27 then -- 11 [SELF] 
 	Stack[7] = Stack[4]
	if Stack[7] then
		Stack[6] = Stack[4][Constants[7]]
	end
	 
elseif pointer == 28 then -- 1 [LOADK] 
 Temp[7] = 8
Temp[4] = Constants
Temp[11] = 25
Stack[Temp[7]] = Temp[4][Temp[11]]
	Temp[2] = {Stack[6](Stack[7], Stack[8])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[6] = nil
		top = 6
	else
		top = 6 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[6 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 30 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 5 + 1, top do
		Temp[1][i - 5] = Stack[i]
	end
	Temp[2] = {Stack[5](unpack(Temp[1], 1, top - 5))}
		for i = 1, 1 do
		Stack[5 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 31 then -- 24 [LT] 
 	if Constants[11] < Stack[5] then pointer = pointer + 1 end 
elseif pointer == 32 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 33 then -- 0 [MOVE] 
 Temp[7] = 5
Temp[10] = 1
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 34 then -- 28 [CALL] 
 	Stack[5]() 
elseif pointer == 35 then -- 5 [GETGLOBAL] 
 Temp[14] = 5
Temp[12] = 12
Temp[15] = Constants[Temp[12]]
Stack[Temp[14]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 36 then -- 1 [LOADK] 
 Temp[13] = 6
Temp[6] = Constants
Temp[2] = 1
Stack[Temp[13]] = Temp[6][Temp[2]] 
elseif pointer == 37 then -- 29 [TAILCALL] 
 	return Stack[5](Stack[6]) 
elseif pointer == 38 then -- 30 [RETURN] 
             Temp[1] = {}
            Temp[2] = 0
            for i = 5, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
         
elseif pointer == 39 then -- 2 [LOADBOOL] 
 Temp[9] = 5
Temp[7] = ttostring ~= __metatable
Stack[Temp[9]] = Temp[16] 
elseif pointer == 40 then -- 7 [SETGLOBAL] 
 Temp[15] = vmEnv
Temp[13] = 35
Temp[16] = Constants[Temp[13]]
Temp[3] = 5
Temp[15][Temp[16]] = Temp[16] 
elseif pointer == 41 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\115\084\084\085\117\094\094\110\091", "2802")),(decrypt("\013\084\080\082\110\111\092", "725")),}

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
	
	Stack[5] = function(...) -- PROTOTYPE 3
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
		if pointer == 1 then -- 24 [LT] 
 	if Stack[0] < Stack[1] then pointer = pointer + 1 end 
elseif pointer == 2 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 3 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 4 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 5 then -- 24 [LT] 
 	if Stack[2] < Stack[0] then pointer = pointer + 1 end 
elseif pointer == 6 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 7 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 8 then -- 30 [RETURN] 
 	return Stack[0] 
elseif pointer == 9 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 42 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\021\056", "2355")),(decrypt("\113\092\092\101\088\084\111\090", "1979")),(decrypt("\010\088\087\087\082\109\107\099", "782")),}

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
	
	Stack[6] = function(...) -- PROTOTYPE 4
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
		if pointer == 1 then -- 23 [EQ] 
 	if Stack[1] ~= Constants[1] then pointer = pointer + 1 end 
elseif pointer == 2 then -- 22 [JMP] 
 pointer = pointer + 4  
elseif pointer == 3 then -- 0 [MOVE] 
 Temp[9] = 2
Temp[2] = 1
Stack[Temp[9]] = Stack[Temp[2]] 
elseif pointer == 4 then -- 16 [MOD] 
 	Stack[1] = Stack[0] % Stack[1] 
elseif pointer == 5 then -- 0 [MOVE] 
 Temp[7] = 0
Temp[15] = 2
Stack[Temp[7]] = Stack[Temp[15]] 
elseif pointer == 6 then -- 22 [JMP] 
 pointer = pointer + -6  
elseif pointer == 7 then -- 30 [RETURN] 
 	return Stack[0] 
elseif pointer == 8 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 43 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {(decrypt("\025\050", "1981")),(decrypt("\008\080\092\105\088\064", "1091")),(decrypt("\015\091\107\084\082\111\104", "383")),(decrypt("\108\084\094\085\088", "1783")),(decrypt("\011\104\105\095\105\109\090\106\088\126\109\082\087\090\081\083\111", "1716")),(decrypt("\082\096\093\105", "686")),(decrypt("\089\091\080\088", "339")),(decrypt("\020\051", "388")),(decrypt("\008\085\085\086\111\085\087\104", "265")),(decrypt("\027\061", "2687")),}

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
	
	Stack[7] = function(...) -- PROTOTYPE 5
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
		if pointer == 1 then -- 24 [LT] 
 	if Stack[0] < Constants[10] then pointer = pointer + 1 end 
elseif pointer == 2 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 3 then -- 2 [LOADBOOL] 
 Temp[15] = 1
Temp[12] = byte == pairs
Stack[Temp[15]] = Temp[3] 
elseif pointer == 4 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[7] = 1
Temp[13] = Constants
Temp[9] = 10
Stack[Temp[7]] = Temp[13][Temp[9]] 
elseif pointer == 6 then -- 5 [GETGLOBAL] 
 Temp[6] = 2
Temp[4] = 6
Temp[12] = Constants[Temp[4]]
Stack[Temp[6]] = vmEnv[Temp[12]] or Env[Temp[12]]
	Stack[2] = Stack[2][Constants[4]]
	
	pointer = pointer + 1 
elseif pointer == 8 then -- 5 [GETGLOBAL] 
 Temp[15] = 3
Temp[2] = 6
Temp[16] = Constants[Temp[2]]
Stack[Temp[15]] = vmEnv[Temp[16]] or Env[Temp[16]]
	Stack[3] = Stack[3][Constants[7]]
	
	pointer = pointer + 1 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[16] = 4
Temp[12] = 0
Stack[Temp[16]] = Stack[Temp[12]] 
elseif pointer == 11 then -- 28 [CALL] 
 	Temp[2] = {Stack[3](Stack[4])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[3] = nil
		top = 3
	else
		top = 3 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[3 + i - 1] = Temp[2][i]
		end
	end
	 
elseif pointer == 12 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 2 + 1, top do
		Temp[1][i - 2] = Stack[i]
	end
	Temp[2] = {Stack[2](unpack(Temp[1], 1, top - 2))}
		for i = 1, 1 do
		Stack[2 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 13 then -- 1 [LOADK] 
 Temp[11] = 3
Temp[2] = Constants
Temp[9] = 1
Stack[Temp[11]] = Temp[2][Temp[9]] 
elseif pointer == 14 then -- 32 [FORPREP] 
     Stack[1] = Stack[1] - Stack[3]
    pointer = pointer + 5
     
elseif pointer == 15 then -- 16 [MOD] 
 	Stack[5] = Stack[0] % Stack[4] 
elseif pointer == 16 then -- 23 [EQ] 
 	if Stack[5] == Constants[8] then pointer = pointer + 1 end 
elseif pointer == 17 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 18 then -- 2 [LOADBOOL] 
 Temp[16] = 5
Temp[6] = byte == pairs
Stack[Temp[16]] = Temp[7] 
elseif pointer == 19 then -- 30 [RETURN] 
 	return Stack[5] 
elseif pointer == 20 then -- 31 [FORLOOP] 
     Stack[1] = Stack[1] + Stack[3]
    if (Stack[3] > 0 and Stack[1] <= Stack[2]) or (Stack[3] <= 0 and Stack[1] >= Stack[2]) then
        pointer = pointer + -6
        Stack[4] = Stack[1]
    end
     
elseif pointer == 21 then -- 2 [LOADBOOL] 
 Temp[10] = 1
Temp[12] = ttostring ~= __metatable
Stack[Temp[10]] = Temp[9] 
elseif pointer == 22 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 23 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 44 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[6] then
		C1 = {}
		local encoded = {(decrypt("\025\062", "1514")),(decrypt("\125\083\095\083\105", "953")),(decrypt("\090\095\083\088\088\089\092\109", "1993")),(decrypt("\002\110\087\002\080\081\091\086\105\100", "862")),(decrypt("\089\108\097\081\110", "2482")),(decrypt("\104\095\086\109\106\082", "2937")),}

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
	
	Stack[8] = function(...) -- PROTOTYPE 6
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
elseif pointer == 2 then -- 1 [LOADK] 
 Temp[11] = 3
Temp[9] = Constants
Temp[4] = 1
Stack[Temp[11]] = Temp[9][Temp[4]] 
elseif pointer == 3 then -- 20 [LEN] 
 	Stack[4] = #Stack[0] 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[9] = 5
Temp[11] = Constants
Temp[3] = 1
Stack[Temp[9]] = Temp[11][Temp[3]] 
elseif pointer == 5 then -- 32 [FORPREP] 
     Stack[3] = Stack[3] - Stack[5]
    pointer = pointer + 6
     
elseif pointer == 6 then -- 20 [LEN] 
 	Stack[7] = #Stack[2] 
elseif pointer == 7 then -- 12 [ADD] 
 	Stack[7] = Stack[7] + Constants[1] 
elseif pointer == 8 then -- 5 [GETGLOBAL] 
 Temp[9] = 8
Temp[6] = 3
Temp[14] = Constants[Temp[6]]
Stack[Temp[9]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 9 then -- 6 [GETTABLE] 
 	Stack[9] = Stack[0][Stack[6]]
	 
elseif pointer == 10 then -- 28 [CALL] 
 	Stack[8] = Stack[8](Stack[9]) 
elseif pointer == 11 then -- 9 [SETTABLE] 
 	Stack[2][Stack[7]] = Stack[8] 
elseif pointer == 12 then -- 31 [FORLOOP] 
     Stack[3] = Stack[3] + Stack[5]
    if (Stack[5] > 0 and Stack[3] <= Stack[4]) or (Stack[5] <= 0 and Stack[3] >= Stack[4]) then
        pointer = pointer + -7
        Stack[6] = Stack[3]
    end
     
elseif pointer == 13 then -- 5 [GETGLOBAL] 
 Temp[10] = 3
Temp[15] = 5
Temp[14] = Constants[Temp[15]]
Stack[Temp[10]] = vmEnv[Temp[14]] or Env[Temp[14]]
	Stack[3] = Stack[3][Constants[6]]
	
	pointer = pointer + 1 
elseif pointer == 15 then -- 0 [MOVE] 
 Temp[16] = 4
Temp[5] = 2
Stack[Temp[16]] = Stack[Temp[5]] 
elseif pointer == 16 then -- 0 [MOVE] 
 Temp[8] = 5
Temp[11] = 1
Stack[Temp[8]] = Stack[Temp[11]] 
elseif pointer == 17 then -- 29 [TAILCALL] 
 	return Stack[3](Stack[4], Stack[5]) 
elseif pointer == 18 then -- 30 [RETURN] 
             Temp[1] = {}
            Temp[2] = 0
            for i = 3, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
         
elseif pointer == 19 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 45 then -- 10 [NEWTABLE] 
 	Stack[9] = {} 
elseif pointer == 46 then -- 1 [LOADK] 
 Temp[4] = 10
Temp[10] = Constants
Temp[8] = 10
Stack[Temp[4]] = Temp[10][Temp[8]] 
elseif pointer == 47 then -- 1 [LOADK] 
 Temp[1] = 11
Temp[8] = Constants
Temp[12] = 13
Stack[Temp[1]] = Temp[8][Temp[12]] 
elseif pointer == 48 then -- 1 [LOADK] 
 Temp[5] = 12
Temp[14] = Constants
Temp[11] = 10
Stack[Temp[5]] = Temp[14][Temp[11]] 
elseif pointer == 49 then -- 32 [FORPREP] 
     Stack[10] = Stack[10] - Stack[12]
    pointer = pointer + 8
     
elseif pointer == 50 then -- 0 [MOVE] 
 Temp[12] = 14
Temp[5] = 7
Stack[Temp[12]] = Stack[Temp[5]] 
elseif pointer == 51 then -- 0 [MOVE] 
 Temp[14] = 15
Temp[7] = 13
Stack[Temp[14]] = Stack[Temp[7]] 
elseif pointer == 52 then -- 28 [CALL] 
 	Stack[14] = Stack[14](Stack[15]) 
elseif pointer == 53 then -- 26 [TEST] 
 	if Stack[14] then pointer = pointer + 1 end 
elseif pointer == 54 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 55 then -- 20 [LEN] 
 	Stack[14] = #Stack[9] 
elseif pointer == 56 then -- 12 [ADD] 
 	Stack[14] = Stack[14] + Constants[10] 
elseif pointer == 57 then -- 9 [SETTABLE] 
 	Stack[9][Stack[14]] = Stack[13] 
elseif pointer == 58 then -- 31 [FORLOOP] 
     Stack[10] = Stack[10] + Stack[12]
    if (Stack[12] > 0 and Stack[10] <= Stack[11]) or (Stack[12] <= 0 and Stack[10] >= Stack[11]) then
        pointer = pointer + -9
        Stack[13] = Stack[10]
    end
     
elseif pointer == 59 then -- 5 [GETGLOBAL] 
 Temp[11] = 10
Temp[7] = 24
Temp[4] = Constants[Temp[7]]
Stack[Temp[11]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 60 then -- 1 [LOADK] 
 Temp[6] = 11
Temp[5] = Constants
Temp[1] = 28
Stack[Temp[6]] = Temp[5][Temp[1]] 
elseif pointer == 61 then -- 0 [MOVE] 
 Temp[12] = 12
Temp[7] = 8
Stack[Temp[12]] = Stack[Temp[7]] 
elseif pointer == 62 then -- 0 [MOVE] 
 Temp[10] = 13
Temp[3] = 9
Stack[Temp[10]] = Stack[Temp[3]] 
elseif pointer == 63 then -- 1 [LOADK] 
 Temp[7] = 14
Temp[8] = Constants
Temp[15] = 33
Stack[Temp[7]] = Temp[8][Temp[15]]
	Stack[12] = Stack[12](Stack[13], Stack[14])
	pointer = pointer + 1 
elseif pointer == 65 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 11, 12 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[11] = Temp[1]
	 
elseif pointer == 66 then -- 28 [CALL] 
 	Stack[10](Stack[11]) 
elseif pointer == 67 then -- 5 [GETGLOBAL] 
 Temp[3] = 10
Temp[11] = 24
Temp[14] = Constants[Temp[11]]
Stack[Temp[3]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 68 then -- 1 [LOADK] 
 Temp[7] = 11
Temp[4] = Constants
Temp[8] = 2
Stack[Temp[7]] = Temp[4][Temp[8]] 
elseif pointer == 69 then -- 0 [MOVE] 
 Temp[15] = 12
Temp[5] = 6
Stack[Temp[15]] = Stack[Temp[5]] 
elseif pointer == 70 then -- 1 [LOADK] 
 Temp[16] = 13
Temp[15] = Constants
Temp[4] = 20
Stack[Temp[16]] = Temp[15][Temp[4]] 
elseif pointer == 71 then -- 1 [LOADK] 
 Temp[12] = 14
Temp[11] = Constants
Temp[16] = 3
Stack[Temp[12]] = Temp[11][Temp[16]]
	Stack[12] = Stack[12](Stack[13], Stack[14])
	pointer = pointer + 1 
elseif pointer == 73 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 11, 12 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[11] = Temp[1]
	 
elseif pointer == 74 then -- 28 [CALL] 
 	Stack[10](Stack[11]) 
elseif pointer == 75 then -- 5 [GETGLOBAL] 
 Temp[16] = 10
Temp[9] = 24
Temp[6] = Constants[Temp[9]]
Stack[Temp[16]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 76 then -- 1 [LOADK] 
 Temp[10] = 11
Temp[15] = Constants
Temp[16] = 6
Stack[Temp[10]] = Temp[15][Temp[16]] 
elseif pointer == 77 then -- 0 [MOVE] 
 Temp[4] = 12
Temp[11] = 5
Stack[Temp[4]] = Stack[Temp[11]] 
elseif pointer == 78 then -- 1 [LOADK] 
 Temp[12] = 13
Temp[11] = Constants
Temp[4] = 23
Stack[Temp[12]] = Temp[11][Temp[4]] 
elseif pointer == 79 then -- 1 [LOADK] 
 Temp[14] = 14
Temp[1] = Constants
Temp[12] = 15
Stack[Temp[14]] = Temp[1][Temp[12]] 
elseif pointer == 80 then -- 1 [LOADK] 
 Temp[13] = 15
Temp[4] = Constants
Temp[7] = 18
Stack[Temp[13]] = Temp[4][Temp[7]]
	Stack[12] = Stack[12](Stack[13], Stack[14], Stack[15])
	pointer = pointer + 1 
elseif pointer == 82 then -- 1 [LOADK] 
 Temp[10] = 13
Temp[2] = Constants
Temp[8] = 26
Stack[Temp[10]] = Temp[2][Temp[8]] 
elseif pointer == 83 then -- 0 [MOVE] 
 Temp[14] = 14
Temp[1] = 5
Stack[Temp[14]] = Stack[Temp[1]] 
elseif pointer == 84 then -- 1 [LOADK] 
 Temp[6] = 15
Temp[14] = Constants
Temp[5] = 34
Stack[Temp[6]] = Temp[14][Temp[5]] 
elseif pointer == 85 then -- 1 [LOADK] 
 Temp[2] = 16
Temp[9] = Constants
Temp[4] = 15
Stack[Temp[2]] = Temp[9][Temp[4]] 
elseif pointer == 86 then -- 1 [LOADK] 
 Temp[1] = 17
Temp[9] = Constants
Temp[11] = 18
Stack[Temp[1]] = Temp[9][Temp[11]]
	Stack[14] = Stack[14](Stack[15], Stack[16], Stack[17])
	pointer = pointer + 1 
elseif pointer == 88 then -- 1 [LOADK] 
 Temp[16] = 15
Temp[3] = Constants
Temp[11] = 26
Stack[Temp[16]] = Temp[3][Temp[11]] 
elseif pointer == 89 then -- 0 [MOVE] 
 Temp[3] = 16
Temp[13] = 5
Stack[Temp[3]] = Stack[Temp[13]] 
elseif pointer == 90 then -- 1 [LOADK] 
 Temp[6] = 17
Temp[14] = Constants
Temp[1] = 4
Stack[Temp[6]] = Temp[14][Temp[1]] 
elseif pointer == 91 then -- 1 [LOADK] 
 Temp[3] = 18
Temp[14] = Constants
Temp[12] = 15
Stack[Temp[3]] = Temp[14][Temp[12]] 
elseif pointer == 92 then -- 1 [LOADK] 
 Temp[15] = 19
Temp[1] = Constants
Temp[2] = 18
Stack[Temp[15]] = Temp[1][Temp[2]]
	Stack[16] = Stack[16](Stack[17], Stack[18], Stack[19])
	pointer = pointer + 1 
elseif pointer == 94 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 11, 16 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[11] = Temp[1]
	 
elseif pointer == 95 then -- 28 [CALL] 
 	Stack[10](Stack[11]) 
elseif pointer == 96 then -- 5 [GETGLOBAL] 
 Temp[9] = 10
Temp[11] = 24
Temp[12] = Constants[Temp[11]]
Stack[Temp[9]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 97 then -- 5 [GETGLOBAL] 
 Temp[10] = 11
Temp[2] = 29
Temp[8] = Constants[Temp[2]]
Stack[Temp[10]] = vmEnv[Temp[8]] or Env[Temp[8]]
	Stack[11] = Stack[11][Constants[17]]
	
	pointer = pointer + 1 
elseif pointer == 99 then -- 1 [LOADK] 
 Temp[8] = 12
Temp[14] = Constants
Temp[9] = 36
Stack[Temp[8]] = Temp[14][Temp[9]] 
elseif pointer == 100 then -- 1 [LOADK] 
 Temp[16] = 13
Temp[2] = Constants
Temp[9] = 8
Stack[Temp[16]] = Temp[2][Temp[9]] 
elseif pointer == 101 then -- 1 [LOADK] 
 Temp[16] = 14
Temp[11] = Constants
Temp[3] = 31
Stack[Temp[16]] = Temp[11][Temp[3]] 
elseif pointer == 102 then -- 1 [LOADK] 
 Temp[15] = 15
Temp[13] = Constants
Temp[14] = 4
Stack[Temp[15]] = Temp[13][Temp[14]]
	Temp[2] = {Stack[11](Stack[12], Stack[13], Stack[14], Stack[15])}
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
elseif pointer == 104 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 10 + 1, top do
		Temp[1][i - 10] = Stack[i]
	end
	Temp[2] = {Stack[10](unpack(Temp[1], 1, top - 10))}
		for i = 1, 0 do
		Stack[10 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 105 then -- 30 [RETURN] 
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