return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\120\011\097\124\010\120\110\008\010\123\116\121\110\120\124\000\123\124", "827")),(decrypt("\114\013\096\117\010\123\096\011\015\119\112\127\100\008\115\010", "2461")),(decrypt("\021\058", "2175")),(decrypt("\031\058", "1192")),(decrypt("\017\031\058", "981")),(decrypt("\100\103\086\107\089\105\089\111\107\082\110", "2127")),(decrypt("\041", "302")),(decrypt("\089\081\081\084\086\110\104\081", "2748")),(decrypt("\086\104\095\111\109", "2045")),(decrypt("\101\080\089\095\080", "990")),(decrypt("\025\019\056", "243")),(decrypt("\025\059", "2006")),((decrypt("\028\029\020\029\028", "1187"))),(decrypt("\098\101\084\081\104\104\091", "434")),(decrypt("\030\061", "2683")),(decrypt("\089\094\096\089\080\082", "998")),(decrypt("\009\100\094\109\110\093\111\111\087\083\012\108\105\100\111", "2847")),(decrypt("\120\082\085\082\109", "2499")),(decrypt("\025\059", "1018")),(decrypt("\085\095\088\083\089", "2686")),(decrypt("\121\107\080\086\110\090\035\106\110\088\104\107\089\111\111", "2341")),(decrypt("\086\111\109\086\082", "1555")),(decrypt("\022\026\057", "2023")),(decrypt("\103\110\080\094\109\081", "1805")),(decrypt("\006\090\104\100\086", "834")),(decrypt("\026\017\057", "2823")),(decrypt("\046\108\023", "2759")),(decrypt("\027\056", "2332")),(decrypt("\091\100\094\093\109\083\109\082\105\097\086\101", "1859")),(decrypt("\118\008\097\118\116\116\118\116\119\115\015\097\124\122\015\127\122", "617")),(decrypt("\090\080\091\105\082", "1601")),(decrypt("\100\115\001\010\126\127\002\015\121\009\003", "2587")),(decrypt("\088\101\084\101\104\082", "2979")),(decrypt("\097\097\093\081\093\093\094\087\083\105", "776")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
 Temp[4] = 0
Temp[5] = byte == pairs
Stack[Temp[4]] = Temp[15] 
elseif pointer == 2 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {((decrypt("\021\018\028\030\024", "2764"))),(decrypt("\100\009\113\012\120\012", "2384")),(decrypt("\121\092\105\105\110", "2513")),((decrypt("\024\017\029", "367"))),(decrypt("\014\107\107\086\090\104", "1735")),}

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
 Temp[15] = 0
Temp[10] = ttostring ~= __metatable
Stack[Temp[15]] = Temp[6] 
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
 Temp[5] = 2
Temp[4] = 29
Temp[10] = Constants[Temp[4]]
Stack[Temp[5]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 5 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 6 then -- 10 [NEWTABLE] 
 	Stack[4] = {} 
elseif pointer == 7 then -- 9 [SETTABLE] 
 	Stack[4][Constants[34]] = Stack[1] 
elseif pointer == 8 then -- 9 [SETTABLE] 
 	Stack[4][Constants[24]] = Stack[1] 
elseif pointer == 9 then -- 9 [SETTABLE] 
 	Stack[4][Constants[14]] = Stack[1] 
elseif pointer == 10 then -- 9 [SETTABLE] 
 	Stack[4][Constants[6]] = Constants[19] 
elseif pointer == 11 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3], Stack[4]) 
elseif pointer == 12 then -- 5 [GETGLOBAL] 
 Temp[10] = 3
Temp[5] = 22
Temp[16] = Constants[Temp[5]]
Stack[Temp[10]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 13 then -- 5 [GETGLOBAL] 
 Temp[6] = 4
Temp[3] = 22
Temp[5] = Constants[Temp[3]]
Stack[Temp[6]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 14 then -- 0 [MOVE] 
 Temp[6] = 5
Temp[16] = 2
Stack[Temp[6]] = Stack[Temp[16]] 
elseif pointer == 15 then -- 0 [MOVE] 
 Temp[10] = 6
Temp[4] = 2
Stack[Temp[10]] = Stack[Temp[4]] 
elseif pointer == 16 then -- 28 [CALL] 
 	Stack[3](Stack[4], Stack[5], Stack[6]) 
elseif pointer == 17 then -- 5 [GETGLOBAL] 
 Temp[13] = 3
Temp[2] = 22
Temp[15] = Constants[Temp[2]]
Stack[Temp[13]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 18 then -- 5 [GETGLOBAL] 
 Temp[6] = 4
Temp[5] = 8
Temp[14] = Constants[Temp[5]]
Stack[Temp[6]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 19 then -- 0 [MOVE] 
 Temp[3] = 5
Temp[7] = 2
Stack[Temp[3]] = Stack[Temp[7]] 
elseif pointer == 20 then -- 28 [CALL] 
 	Stack[3](Stack[4], Stack[5]) 
elseif pointer == 21 then -- 5 [GETGLOBAL] 
 Temp[7] = 3
Temp[11] = 22
Temp[5] = Constants[Temp[11]]
Stack[Temp[7]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 22 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\106\097\029", "2970")),(decrypt("\120\101\104\084\087\098\088", "2922")),(decrypt("\012\100\110\091\102\032\083\094\108\107\047\107\082\096\110\084\100\108", "787")),(decrypt("\015\110\080\082\110\109\039\090\084\033\080\084\082\093\080\105\081\086\065\109", "2601")),(decrypt("\124\085\091\087\104\086\109", "1517")),((decrypt("\030\030\018\017\030\018\017", "695"))),}

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
 Temp[16] = 0
Temp[1] = 1
Temp[3] = Constants[Temp[1]]
Stack[Temp[16]] = vmEnv[Temp[3]] or Env[Temp[3]] 
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
 Temp[7] = 5
Temp[15] = 8
Temp[9] = Constants[Temp[15]]
Stack[Temp[7]] = vmEnv[Temp[9]] or Env[Temp[9]] 
elseif pointer == 27 then -- 11 [SELF] 
 	Stack[7] = Stack[4]
	if Stack[7] then
		Stack[6] = Stack[4][Constants[9]]
	end
	 
elseif pointer == 28 then -- 1 [LOADK] 
 Temp[12] = 8
Temp[14] = Constants
Temp[15] = 27
Stack[Temp[12]] = Temp[14][Temp[15]]
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
Temp[4] = 1
Stack[Temp[7]] = Stack[Temp[4]] 
elseif pointer == 34 then -- 28 [CALL] 
 	Stack[5]() 
elseif pointer == 35 then -- 5 [GETGLOBAL] 
 Temp[11] = 5
Temp[7] = 10
Temp[10] = Constants[Temp[7]]
Stack[Temp[11]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 36 then -- 1 [LOADK] 
 Temp[14] = 6
Temp[12] = Constants
Temp[15] = 21
Stack[Temp[14]] = Temp[12][Temp[15]] 
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
 Temp[13] = 5
Temp[6] = ttostring ~= __metatable
Stack[Temp[13]] = Temp[2] 
elseif pointer == 40 then -- 7 [SETGLOBAL] 
 Temp[9] = vmEnv
Temp[7] = 32
Temp[16] = Constants[Temp[7]]
Temp[15] = 5
Temp[9][Temp[16]] = Temp[16] 
elseif pointer == 41 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\120\090\110\093\112\105", "402")),(decrypt("\011\083\080\082\109\111\094", "1557")),(decrypt("\112\090\083\084\118\080\089\111\088", "1673")),(decrypt("\009\009\123\012\121\009", "2580")),}

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
		if pointer == 1 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 42 then -- 7 [SETGLOBAL] 
 Temp[13] = vmEnv
Temp[4] = 1
Temp[3] = Constants[Temp[4]]
Temp[16] = 5
Temp[13][Temp[3]] = Temp[3] 
elseif pointer == 43 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\011\081\096\082\091\119\096\092\109", "1288")),(decrypt("\117\090\080\087\106\090\064", "2303")),(decrypt("\127\105\090\088\085\085\087\034\087\082\095\087\106\094\105\109", "253")),(decrypt("\009\114\002\115\113", "1883")),((decrypt("\026\020\031\028\021\030", "2132"))),(decrypt("\008\111\110\085\104\104\104", "334")),}

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
	
	Stack[5] = function(...) -- PROTOTYPE 4
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
 
elseif pointer == 44 then -- 7 [SETGLOBAL] 
 Temp[10] = vmEnv
Temp[8] = 2
Temp[1] = Constants[Temp[8]]
Temp[12] = 5
Temp[10][Temp[1]] = Temp[1] 
elseif pointer == 45 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {(decrypt("\094\107\090\101", "339")),(decrypt("\116\091\096\088\101\094\090\092\114\088\096\093\104", "388")),(decrypt("\111\110\086\088\106", "265")),(decrypt("\013\093\083\080\120\106\081\090\082\108\100", "2687")),((decrypt("\024\019\028\031\026\026\004", "2644"))),}

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
	
	Stack[5] = function(...) -- PROTOTYPE 5
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
 
elseif pointer == 46 then -- 7 [SETGLOBAL] 
 Temp[5] = vmEnv
Temp[14] = 30
Temp[11] = Constants[Temp[14]]
Temp[12] = 5
Temp[5][Temp[11]] = Temp[11] 
elseif pointer == 47 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[6] then
		C1 = {}
		local encoded = {(decrypt("\121\101\086\108\085\095\092\091\120\101\092\093\082\099\105", "2950")),(decrypt("\118\097\107\104\087\082\109", "2954")),(decrypt("\009\014\115\012\121\014", "2200")),(decrypt("\118\108\092\104\110\089\082\110\082\087\115\065\085\108", "2081")),(decrypt("\114\001\110\114\125\123\114\125\120\119\006\110\120\115\000\123\115", "288")),(decrypt("\012\110\081\090\109\109\038\082\087\033\081\092\081\093\081\097\082\086\064\101", "1619")),}

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
		if pointer == 1 then -- 5 [GETGLOBAL] 
 Temp[16] = 2
Temp[6] = 5
Temp[7] = Constants[Temp[6]]
Stack[Temp[16]] = vmEnv[Temp[7]] or Env[Temp[7]] 
elseif pointer == 2 then -- 2 [LOADBOOL] 
 Temp[10] = 3
Temp[12] = ttostring ~= __metatable
Stack[Temp[10]] = Temp[9] 
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
 
elseif pointer == 48 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[7] then
		C1 = {}
		local encoded = {(decrypt("\088\111\093\091\082\085\082\103", "2371")),(decrypt("\114\091\108\069\100\093\124\100\080\083\085\084\080\102", "584")),(decrypt("\119\001\101\119\125\112\119\125\115\114\006\101\125\115\011\126\115", "783")),}

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
	
	Stack[6] = function(...) -- PROTOTYPE 7
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
 Temp[8] = 2
Temp[5] = 3
Temp[11] = Constants[Temp[5]]
Stack[Temp[8]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 2 then -- 2 [LOADBOOL] 
 Temp[5] = 3
Temp[14] = ttostring ~= __metatable
Stack[Temp[5]] = Temp[16] 
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
 
elseif pointer == 49 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[8] then
		C1 = {}
		local encoded = {(decrypt("\114\014\111\125\010\120\111\003\015\116\127\119\100\125\114\001\123\124", "2799")),(decrypt("\113\082\087\091\090\014\108\105\105\082", "1707")),(decrypt("\015\111\087\082\082\082\106", "2741")),(decrypt("\016\056", "939")),(decrypt("\113\009\097\124\009\127\097\002\012\115\113\118\103\012\114\003", "1078")),(decrypt("\111\095\105\086", "325")),(decrypt("\010\106\107\094\111", "1622")),(decrypt("\067\104\080\084", "2492")),(decrypt("\022\058", "1178")),(decrypt("\083\109\107\110\090\085\091\109", "615")),(decrypt("\115\080\089\107\092\084\107\080\095\036\088\084\085\086\108\088\105\111", "354")),(decrypt("\080\110\098", "659")),(decrypt("\101\105\081\086\083\092", "552")),}

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
	
	Stack[7] = function(...) -- PROTOTYPE 8
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
Temp[5] = 1
Temp[6] = Constants[Temp[5]]
Stack[Temp[12]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 2 then -- 28 [CALL] 
 	Stack[1]() 
elseif pointer == 3 then -- 3 [LOADNIL] 
 	Stack[1], Stack[2] = nil 
elseif pointer == 4 then -- 24 [LT] 
 	if Stack[0] < Constants[9] then pointer = pointer + 1 end 
elseif pointer == 5 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 6 then -- 1 [LOADK] 
 Temp[6] = 1
Temp[9] = Constants
Temp[14] = 10
Stack[Temp[6]] = Temp[9][Temp[14]] 
elseif pointer == 7 then -- 22 [JMP] 
 pointer = pointer + 10  
elseif pointer == 8 then -- 23 [EQ] 
 	if Stack[0] == Constants[9] then pointer = pointer + 1 end 
elseif pointer == 9 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 10 then -- 1 [LOADK] 
 Temp[12] = 1
Temp[7] = Constants
Temp[10] = 8
Stack[Temp[12]] = Temp[7][Temp[10]] 
elseif pointer == 11 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 12 then -- 16 [MOD] 
 	Stack[2] = Stack[0] % Constants[4] 
elseif pointer == 13 then -- 23 [EQ] 
 	if Stack[2] == Constants[9] then pointer = pointer + 1 end 
elseif pointer == 14 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 15 then -- 1 [LOADK] 
 Temp[4] = 1
Temp[7] = Constants
Temp[15] = 6
Stack[Temp[4]] = Temp[7][Temp[15]] 
elseif pointer == 16 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 17 then -- 1 [LOADK] 
 Temp[11] = 1
Temp[2] = Constants
Temp[12] = 12
Stack[Temp[11]] = Temp[2][Temp[12]] 
elseif pointer == 18 then -- 5 [GETGLOBAL] 
 Temp[6] = 2
Temp[1] = 5
Temp[5] = Constants[Temp[1]]
Stack[Temp[6]] = vmEnv[Temp[5]] or Env[Temp[5]] 
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
 
elseif pointer == 50 then -- 1 [LOADK] 
 Temp[5] = 8
Temp[14] = Constants
Temp[7] = 3
Stack[Temp[5]] = Temp[14][Temp[7]] 
elseif pointer == 51 then -- 1 [LOADK] 
 Temp[11] = 9
Temp[7] = Constants
Temp[4] = 19
Stack[Temp[11]] = Temp[7][Temp[4]] 
elseif pointer == 52 then -- 1 [LOADK] 
 Temp[6] = 10
Temp[5] = Constants
Temp[1] = 5
Stack[Temp[6]] = Temp[5][Temp[1]] 
elseif pointer == 53 then -- 1 [LOADK] 
 Temp[12] = 11
Temp[7] = Constants
Temp[10] = 19
Stack[Temp[12]] = Temp[7][Temp[10]] 
elseif pointer == 54 then -- 32 [FORPREP] 
     Stack[9] = Stack[9] - Stack[11]
    pointer = pointer + 5
     
elseif pointer == 55 then -- 0 [MOVE] 
 Temp[3] = 13
Temp[7] = 5
Stack[Temp[3]] = Stack[Temp[7]] 
elseif pointer == 56 then -- 0 [MOVE] 
 Temp[8] = 14
Temp[15] = 8
Stack[Temp[8]] = Stack[Temp[15]] 
elseif pointer == 57 then -- 0 [MOVE] 
 Temp[3] = 15
Temp[11] = 12
Stack[Temp[3]] = Stack[Temp[11]] 
elseif pointer == 58 then -- 28 [CALL] 
 	Stack[13] = Stack[13](Stack[14], Stack[15]) 
elseif pointer == 59 then -- 0 [MOVE] 
 Temp[14] = 8
Temp[7] = 13
Stack[Temp[14]] = Stack[Temp[7]] 
elseif pointer == 60 then -- 31 [FORLOOP] 
     Stack[9] = Stack[9] + Stack[11]
    if (Stack[11] > 0 and Stack[9] <= Stack[10]) or (Stack[11] <= 0 and Stack[9] >= Stack[10]) then
        pointer = pointer + -6
        Stack[12] = Stack[9]
    end
     
elseif pointer == 61 then -- 5 [GETGLOBAL] 
 Temp[4] = 9
Temp[8] = 20
Temp[15] = Constants[Temp[8]]
Stack[Temp[4]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 62 then -- 1 [LOADK] 
 Temp[5] = 10
Temp[16] = Constants
Temp[15] = 31
Stack[Temp[5]] = Temp[16][Temp[15]] 
elseif pointer == 63 then -- 0 [MOVE] 
 Temp[16] = 11
Temp[4] = 8
Stack[Temp[16]] = Stack[Temp[4]] 
elseif pointer == 64 then -- 28 [CALL] 
 	Stack[9](Stack[10], Stack[11]) 
elseif pointer == 65 then -- 5 [GETGLOBAL] 
 Temp[12] = 9
Temp[11] = 16
Temp[16] = Constants[Temp[11]]
Stack[Temp[12]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 66 then -- 10 [NEWTABLE] 
 	Stack[10] = {} 
elseif pointer == 67 then -- 1 [LOADK] 
 Temp[16] = 11
Temp[9] = Constants
Temp[6] = 23
Stack[Temp[16]] = Temp[9][Temp[6]] 
elseif pointer == 68 then -- 1 [LOADK] 
 Temp[10] = 12
Temp[15] = Constants
Temp[16] = 3
Stack[Temp[10]] = Temp[15][Temp[16]] 
elseif pointer == 69 then -- 1 [LOADK] 
 Temp[4] = 13
Temp[11] = Constants
Temp[12] = 12
Stack[Temp[4]] = Temp[11][Temp[12]] 
elseif pointer == 70 then -- 1 [LOADK] 
 Temp[11] = 14
Temp[4] = Constants
Temp[14] = 4
Stack[Temp[11]] = Temp[4][Temp[14]] 
elseif pointer == 71 then -- 34 [SETLIST] 
 	for i = 1, 4 do
		Stack[10][(1 - 1) * 50 + i] = Stack[10 + i]
	end
	 
elseif pointer == 72 then -- 28 [CALL] 
 	Stack[9], Stack[10], Stack[11] = Stack[9](Stack[10]) 
elseif pointer == 73 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 74 then -- 5 [GETGLOBAL] 
 Temp[1] = 14
Temp[12] = 20
Temp[13] = Constants[Temp[12]]
Stack[Temp[1]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 75 then -- 0 [MOVE] 
 Temp[4] = 15
Temp[7] = 13
Stack[Temp[4]] = Stack[Temp[7]] 
elseif pointer == 76 then -- 0 [MOVE] 
 Temp[10] = 16
Temp[2] = 7
Stack[Temp[10]] = Stack[Temp[2]] 
elseif pointer == 77 then -- 0 [MOVE] 
 Temp[8] = 17
Temp[14] = 13
Stack[Temp[8]] = Stack[Temp[14]] 
elseif pointer == 78 then -- 28 [CALL] 
 	Temp[2] = {Stack[16](Stack[17])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[16] = nil
		top = 16
	else
		top = 16 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[16 + i - 1] = Temp[2][i]
		end
	end
	 
elseif pointer == 79 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 14 + 1, top do
		Temp[1][i - 14] = Stack[i]
	end
	Temp[2] = {Stack[14](unpack(Temp[1], 1, top - 14))}
		for i = 1, 0 do
		Stack[14 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 80 then -- 33 [TFORLOOP] 
     local r1, r2 = Stack[9](Stack[10], Stack[11])
    Stack[12] = r1
        Stack[13] = r2
    if Stack[12] ~= nil then
        Stack[11] = Stack[12]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 81 then -- 22 [JMP] 
 pointer = pointer + -8  
elseif pointer == 82 then -- 0 [MOVE] 
 Temp[1] = 9
Temp[6] = 6
Stack[Temp[1]] = Stack[Temp[6]] 
elseif pointer == 83 then -- 1 [LOADK] 
 Temp[14] = 10
Temp[5] = Constants
Temp[2] = 26
Stack[Temp[14]] = Temp[5][Temp[2]] 
elseif pointer == 84 then -- 1 [LOADK] 
 Temp[9] = 11
Temp[4] = Constants
Temp[1] = 15
Stack[Temp[9]] = Temp[4][Temp[1]]
	Stack[9], Stack[10] = Stack[9](Stack[10], Stack[11])
	pointer = pointer + 1 
elseif pointer == 86 then -- 5 [GETGLOBAL] 
 Temp[1] = 11
Temp[9] = 20
Temp[11] = Constants[Temp[9]]
Stack[Temp[1]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 87 then -- 0 [MOVE] 
 Temp[16] = 12
Temp[3] = 9
Stack[Temp[16]] = Stack[Temp[3]] 
elseif pointer == 88 then -- 0 [MOVE] 
 Temp[11] = 13
Temp[3] = 10
Stack[Temp[11]] = Stack[Temp[3]] 
elseif pointer == 89 then -- 28 [CALL] 
 	Stack[11](Stack[12], Stack[13]) 
elseif pointer == 90 then -- 5 [GETGLOBAL] 
 Temp[13] = 11
Temp[6] = 20
Temp[14] = Constants[Temp[6]]
Stack[Temp[13]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 91 then -- 5 [GETGLOBAL] 
 Temp[1] = 12
Temp[3] = 33
Temp[14] = Constants[Temp[3]]
Stack[Temp[1]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 92 then -- 1 [LOADK] 
 Temp[12] = 13
Temp[15] = Constants
Temp[1] = 7
Stack[Temp[12]] = Temp[15][Temp[1]] 
elseif pointer == 93 then -- 0 [MOVE] 
 Temp[2] = 14
Temp[9] = 6
Stack[Temp[2]] = Stack[Temp[9]] 
elseif pointer == 94 then -- 1 [LOADK] 
 Temp[11] = 15
Temp[12] = Constants
Temp[10] = 19
Stack[Temp[11]] = Temp[12][Temp[10]] 
elseif pointer == 95 then -- 1 [LOADK] 
 Temp[2] = 16
Temp[10] = Constants
Temp[8] = 28
Stack[Temp[2]] = Temp[10][Temp[8]]
	Temp[2] = {Stack[14](Stack[15], Stack[16])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[14] = nil
		top = 14
	else
		top = 14 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[14 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 97 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 12 + 1, top do
		Temp[1][i - 12] = Stack[i]
	end
	Temp[2] = {Stack[12](unpack(Temp[1], 1, top - 12))}
		Temp[3]  = #Temp[2]
	if Temp[3]  == 0 then
		Stack[12] = nil
		top = 12
	else
		top = 12 + Temp[3]  - 1
		for i = 1, Temp[3]  do
			Stack[12 + i - 1] = Temp[2][i]
		end
	end
	
	 
elseif pointer == 98 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 11 + 1, top do
		Temp[1][i - 11] = Stack[i]
	end
	Temp[2] = {Stack[11](unpack(Temp[1], 1, top - 11))}
		for i = 1, 0 do
		Stack[11 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 99 then -- 30 [RETURN] 
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