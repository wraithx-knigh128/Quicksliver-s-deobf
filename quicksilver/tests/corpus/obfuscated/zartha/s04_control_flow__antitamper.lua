return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\025\019\061", "2461")),(decrypt("\028\058", "2175")),(decrypt("\086\088\089\087\090", "1192")),(decrypt("\046\088\091\046", "981")),(decrypt("\104\087\081\084\106\090\067\040", "2127")),(decrypt("\084\106\106\080\083", "302")),(decrypt("\093\088\108\097\104\111\109", "2748")),(decrypt("\100\102\084\080\105\108\091", "2045")),(decrypt("\093\097\091\099\102", "990")),(decrypt("\046\111\017", "243")),(decrypt("\121\104\084\081\110\089\039\109\110\091\108\108\089\108\107", "2006")),(decrypt("\109\088\081\081\088", "1187")),(decrypt("\010\090\104\104\086", "434")),(decrypt("\022\026\051", "2683")),(decrypt("\111\111\092\101\082\096\082\097\097\090\101", "998")),(decrypt("\002\022\063", "2847")),(decrypt("\002\027\023\020\030\063", "2499")),(decrypt("\122\086\093\098\110\012\084\099\109\107", "1018")),(decrypt("\088\106\083\082\110\093\096\093\106\111\091\106", "2686")),(decrypt("\026\056", "2341")),(decrypt("\017\034\001\034", "1555")),(decrypt("\100\118\011\014\126\122\008\011\121\012\009", "2023")),(decrypt("\090\094\085\089\085\097\108\092", "1805")),(decrypt("\019\026\063", "834")),(decrypt("\100\110\082\088\110\081", "2823")),(decrypt("\009\107\095\099\110\082\110\097\087\092\013\098\105\107\110", "2759")),(decrypt("\002\027\056", "2332")),(decrypt("\022\051", "1859")),(decrypt("\110\105\110\089", "617")),(decrypt("\103\096\091\087\091\093\089\081\084\104", "1601")),(decrypt("\031\062", "2587")),(decrypt("\026\030\016\030\057", "2979")),(decrypt("\087\080\110\087\094\092", "776")),(decrypt("\030\025\051", "778")),(decrypt("\115\083\085\082\106", "959")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
 Temp[15] = 0
Temp[5] = byte == pairs
Stack[Temp[15]] = Temp[4] 
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
 Temp[10] = 2
Temp[5] = 19
Temp[16] = Constants[Temp[5]]
Stack[Temp[10]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 5 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 6 then -- 10 [NEWTABLE] 
 	Stack[4] = {} 
elseif pointer == 7 then -- 9 [SETTABLE] 
 	Stack[4][Constants[30]] = Stack[1] 
elseif pointer == 8 then -- 9 [SETTABLE] 
 	Stack[4][Constants[25]] = Stack[1] 
elseif pointer == 9 then -- 9 [SETTABLE] 
 	Stack[4][Constants[8]] = Stack[1] 
elseif pointer == 10 then -- 9 [SETTABLE] 
 	Stack[4][Constants[15]] = Constants[20] 
elseif pointer == 11 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3], Stack[4]) 
elseif pointer == 12 then -- 5 [GETGLOBAL] 
 Temp[6] = 3
Temp[3] = 6
Temp[5] = Constants[Temp[3]]
Stack[Temp[6]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 13 then -- 5 [GETGLOBAL] 
 Temp[6] = 4
Temp[16] = 6
Temp[10] = Constants[Temp[16]]
Stack[Temp[6]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 14 then -- 0 [MOVE] 
 Temp[4] = 5
Temp[13] = 2
Stack[Temp[4]] = Stack[Temp[13]] 
elseif pointer == 15 then -- 0 [MOVE] 
 Temp[2] = 6
Temp[15] = 2
Stack[Temp[2]] = Stack[Temp[15]] 
elseif pointer == 16 then -- 28 [CALL] 
 	Stack[3](Stack[4], Stack[5], Stack[6]) 
elseif pointer == 17 then -- 5 [GETGLOBAL] 
 Temp[6] = 3
Temp[5] = 6
Temp[14] = Constants[Temp[5]]
Stack[Temp[6]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 18 then -- 5 [GETGLOBAL] 
 Temp[3] = 4
Temp[7] = 23
Temp[11] = Constants[Temp[7]]
Stack[Temp[3]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 19 then -- 0 [MOVE] 
 Temp[5] = 5
Temp[7] = 2
Stack[Temp[5]] = Stack[Temp[7]] 
elseif pointer == 20 then -- 28 [CALL] 
 	Stack[3](Stack[4], Stack[5]) 
elseif pointer == 21 then -- 5 [GETGLOBAL] 
 Temp[15] = 3
Temp[9] = 6
Temp[12] = Constants[Temp[9]]
Stack[Temp[15]] = vmEnv[Temp[12]] or Env[Temp[12]] 
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
 Temp[14] = 5
Temp[7] = 23
Temp[15] = Constants[Temp[7]]
Stack[Temp[14]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 27 then -- 11 [SELF] 
 	Stack[7] = Stack[4]
	if Stack[7] then
		Stack[6] = Stack[4][Constants[9]]
	end
	 
elseif pointer == 28 then -- 1 [LOADK] 
 Temp[7] = 8
Temp[4] = Constants
Temp[11] = 10
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
 	if Constants[1] < Stack[5] then pointer = pointer + 1 end 
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
Temp[2] = 11
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
Temp[13] = 22
Temp[16] = Constants[Temp[13]]
Temp[3] = 5
Temp[15][Temp[16]] = Temp[16] 
elseif pointer == 41 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {((decrypt("\021\017\025\021\031", "2448"))),(decrypt("\015\083\080\085\088\108\105\110", "2355")),((decrypt("\024\030\028\022", "1979"))),(decrypt("\031\051", "782")),(decrypt("\027\061", "1666")),(decrypt("\026\059", "304")),(decrypt("\010\106\094\097\123\089\083\080\109\120\105\080\092\082\111\101", "1259")),(decrypt("\021\060", "2734")),}

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
		if pointer == 1 then -- 1 [LOADK] 
 Temp[10] = 1
Temp[3] = Constants
Temp[15] = 8
Stack[Temp[10]] = Temp[3][Temp[15]] 
elseif pointer == 2 then -- 23 [EQ] 
 	if Stack[0] ~= Constants[4] then pointer = pointer + 1 end 
elseif pointer == 3 then -- 22 [JMP] 
 pointer = pointer + 9  
elseif pointer == 4 then -- 16 [MOD] 
 	Stack[2] = Stack[0] % Constants[6] 
elseif pointer == 5 then -- 23 [EQ] 
 	if Stack[2] == Constants[8] then pointer = pointer + 1 end 
elseif pointer == 6 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 7 then -- 15 [DIV] 
 	Stack[0] = Stack[0] / Constants[6] 
elseif pointer == 8 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 9 then -- 14 [MUL] 
 	Stack[2] = Constants[5] * Stack[0] 
elseif pointer == 10 then -- 12 [ADD] 
 	Stack[0] = Stack[2] + Constants[4] 
elseif pointer == 11 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Constants[4] 
elseif pointer == 12 then -- 22 [JMP] 
 pointer = pointer + -11  
elseif pointer == 13 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 14 then -- 30 [RETURN] 
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
		local encoded = {(decrypt("\009\083\093\081\114\106\095\085\086\108\100", "686")),(decrypt("\089\087\097\080\080", "339")),(decrypt("\066\100\081\085", "388")),(decrypt("\087\106\107\106\093\085\095\106", "265")),((decrypt("\024\019\016\028\026\026\008", "2687"))),(decrypt("\095\110\087\098", "2644")),(decrypt("\021\058", "2144")),(decrypt("\028\017\050", "469")),(decrypt("\108\107\082\090\109", "1310")),(decrypt("\086\111\111\089\094\087", "2349")),(decrypt("\082\110\091\102\109", "1628")),(decrypt("\025\023\019\056", "1043")),}

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
		if pointer == 1 then -- 24 [LT] 
 	if Stack[0] < Constants[7] then pointer = pointer + 1 end 
elseif pointer == 2 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[6] = 1
Temp[12] = Constants
Temp[4] = 4
Stack[Temp[6]] = Temp[12][Temp[4]] 
elseif pointer == 4 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 5 then -- 22 [JMP] 
 pointer = pointer + 17  
elseif pointer == 6 then -- 23 [EQ] 
 	if Stack[0] == Constants[7] then pointer = pointer + 1 end 
elseif pointer == 7 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 8 then -- 1 [LOADK] 
 Temp[15] = 1
Temp[2] = Constants
Temp[16] = 3
Stack[Temp[15]] = Temp[2][Temp[16]] 
elseif pointer == 9 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 10 then -- 22 [JMP] 
 pointer = pointer + 12  
elseif pointer == 11 then -- 24 [LT] 
 	if Stack[0] < Constants[8] then pointer = pointer + 1 end 
elseif pointer == 12 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 13 then -- 1 [LOADK] 
 Temp[16] = 1
Temp[12] = Constants
Temp[11] = 2
Stack[Temp[16]] = Temp[12][Temp[11]] 
elseif pointer == 14 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 15 then -- 22 [JMP] 
 pointer = pointer + 7  
elseif pointer == 16 then -- 24 [LT] 
 	if Stack[0] < Constants[12] then pointer = pointer + 1 end 
elseif pointer == 17 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 18 then -- 1 [LOADK] 
 Temp[2] = 1
Temp[9] = Constants
Temp[16] = 10
Stack[Temp[2]] = Temp[9][Temp[16]] 
elseif pointer == 19 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 20 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 21 then -- 1 [LOADK] 
 Temp[6] = 1
Temp[7] = Constants
Temp[10] = 11
Stack[Temp[6]] = Temp[7][Temp[10]] 
elseif pointer == 22 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 23 then -- 30 [RETURN] 
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
		local encoded = {(decrypt("\017\061", "862")),(decrypt("\120\090\088\086\086\084\093\108", "2482")),(decrypt("\026\050", "2937")),(decrypt("\117\095\094\092\109", "1926")),(decrypt("\116\080\084\108", "1610")),(decrypt("\012\096\087\012\094\081\085\088\105\106", "682")),((decrypt("\025\030\029", "1726"))),(decrypt("\022\050", "1927")),}

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
		if pointer == 1 then -- 1 [LOADK] 
 Temp[3] = 2
Temp[9] = Constants
Temp[6] = 1
Stack[Temp[3]] = Temp[9][Temp[6]] 
elseif pointer == 2 then -- 0 [MOVE] 
 Temp[14] = 3
Temp[10] = 0
Stack[Temp[14]] = Stack[Temp[10]] 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[15] = 4
Temp[14] = Constants
Temp[16] = 3
Stack[Temp[15]] = Temp[14][Temp[16]] 
elseif pointer == 4 then -- 32 [FORPREP] 
     Stack[2] = Stack[2] - Stack[4]
    pointer = pointer + 5
     
elseif pointer == 5 then -- 16 [MOD] 
 	Stack[6] = Stack[0] % Stack[5] 
elseif pointer == 6 then -- 23 [EQ] 
 	if Stack[6] == Constants[8] then pointer = pointer + 1 end 
elseif pointer == 7 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[5] = 1
Temp[8] = 5
Stack[Temp[5]] = Stack[Temp[8]] 
elseif pointer == 9 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 10 then -- 31 [FORLOOP] 
     Stack[2] = Stack[2] + Stack[4]
    if (Stack[4] > 0 and Stack[2] <= Stack[3]) or (Stack[4] <= 0 and Stack[2] >= Stack[3]) then
        pointer = pointer + -6
        Stack[5] = Stack[2]
    end
     
elseif pointer == 11 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 12 then -- 30 [RETURN] 
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
		local encoded = {(decrypt("\030\018\050", "659")),(decrypt("\104\086\084\083\092", "552")),(decrypt("\021\058", "2181")),(decrypt("\124\105\084\082\082\084\105", "2170")),((decrypt("\022\020\020\029", "1135"))),(decrypt("\006\092\082\097\085\080\089\107\127\095\086\093\126\104\095\082", "906")),(decrypt("\113\085\084\111\082\080\098\032\105\089\103\091\085\108\092\092", "1097")),(decrypt("\123\080\090\082\106\124\106\094\092\086\108\107", "1667")),(decrypt("\086\108\083\105", "2486")),}

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
		if pointer == 1 then -- 1 [LOADK] 
 Temp[12] = 1
Temp[7] = Constants
Temp[10] = 3
Stack[Temp[12]] = Temp[7][Temp[10]] 
elseif pointer == 2 then -- 16 [MOD] 
 	Stack[2] = Stack[0] % Constants[1] 
elseif pointer == 3 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Stack[2] 
elseif pointer == 4 then -- 5 [GETGLOBAL] 
 Temp[4] = 2
Temp[7] = 9
Temp[15] = Constants[Temp[7]]
Stack[Temp[4]] = vmEnv[Temp[15]] or Env[Temp[15]]
	Stack[2] = Stack[2][Constants[2]]
	
	pointer = pointer + 1 
elseif pointer == 6 then -- 15 [DIV] 
 	Stack[3] = Stack[0] / Constants[1] 
elseif pointer == 7 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3]) 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[11] = 0
Temp[2] = 2
Stack[Temp[11]] = Stack[Temp[2]] 
elseif pointer == 9 then -- 23 [EQ] 
 	if Stack[0] == Constants[3] then pointer = pointer + 1 end 
elseif pointer == 10 then -- 22 [JMP] 
 pointer = pointer + -9  
elseif pointer == 11 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 12 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 45 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[7] then
		C1 = {}
		local encoded = {(decrypt("\010\089\090\098\087\092\085\100\107\082", "1908")),(decrypt("\025\063", "1420")),(decrypt("\088\088\104\080\089", "2309")),(decrypt("\113\113\114\125", "678")),(decrypt("\088\109\108\082\010", "2107")),(decrypt("\107\111\087\105\006", "573")),(decrypt("\089\110\101\086\010\000", "329")),(decrypt("\004", "1178")),(decrypt("\092\096\108\084\100", "785")),(decrypt("\107", "2383")),(decrypt("\106\106\099\109\085\091", "2091")),(decrypt("\093\085\111", "796")),(decrypt("\104\082\086\104\108\088", "243")),((decrypt("\029\031\004\028", "2745"))),((decrypt("\030\030\004\028", "1645"))),(decrypt("\105", "1982")),(decrypt("\109", "723")),}

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
	
	Stack[9] = function(...) -- PROTOTYPE 7
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
 Temp[6] = 1
Temp[2] = Constants
Temp[15] = 3
Stack[Temp[6]] = Temp[2][Temp[15]] 
elseif pointer == 2 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[6] = 3
Temp[10] = Constants
Temp[13] = 2
Stack[Temp[6]] = Temp[10][Temp[13]] 
elseif pointer == 4 then -- 20 [LEN] 
 	Stack[4] = #Stack[0] 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[8] = 5
Temp[14] = Constants
Temp[6] = 2
Stack[Temp[8]] = Temp[14][Temp[6]] 
elseif pointer == 6 then -- 32 [FORPREP] 
     Stack[3] = Stack[3] - Stack[5]
    pointer = pointer + 31
     
elseif pointer == 7 then -- 11 [SELF] 
 	Stack[8] = Stack[0]
	if Stack[8] then
		Stack[7] = Stack[0][Constants[12]]
	end
	 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[1] = 9
Temp[6] = 6
Stack[Temp[1]] = Stack[Temp[6]] 
elseif pointer == 9 then -- 0 [MOVE] 
 Temp[5] = 10
Temp[1] = 6
Stack[Temp[5]] = Stack[Temp[1]] 
elseif pointer == 10 then -- 28 [CALL] 
 	Stack[7] = Stack[7](Stack[8], Stack[9], Stack[10]) 
elseif pointer == 11 then -- 23 [EQ] 
 	if Stack[1] == Constants[3] then pointer = pointer + 1 end 
elseif pointer == 12 then -- 22 [JMP] 
 pointer = pointer + 4  
elseif pointer == 13 then -- 23 [EQ] 
 	if Stack[7] == Constants[16] then pointer = pointer + 1 end 
elseif pointer == 14 then -- 22 [JMP] 
 pointer = pointer + 20  
elseif pointer == 15 then -- 1 [LOADK] 
 Temp[11] = 1
Temp[15] = Constants
Temp[9] = 5
Stack[Temp[11]] = Temp[15][Temp[9]] 
elseif pointer == 16 then -- 22 [JMP] 
 pointer = pointer + 18  
elseif pointer == 17 then -- 23 [EQ] 
 	if Stack[1] == Constants[5] then pointer = pointer + 1 end 
elseif pointer == 18 then -- 22 [JMP] 
 pointer = pointer + 8  
elseif pointer == 19 then -- 23 [EQ] 
 	if Stack[7] == Constants[10] then pointer = pointer + 1 end 
elseif pointer == 20 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 21 then -- 1 [LOADK] 
 Temp[7] = 1
Temp[2] = Constants
Temp[4] = 7
Stack[Temp[7]] = Temp[2][Temp[4]] 
elseif pointer == 22 then -- 22 [JMP] 
 pointer = pointer + 12  
elseif pointer == 23 then -- 23 [EQ] 
 	if Stack[7] ~= Constants[16] then pointer = pointer + 1 end 
elseif pointer == 24 then -- 22 [JMP] 
 pointer = pointer + 10  
elseif pointer == 25 then -- 1 [LOADK] 
 Temp[10] = 1
Temp[3] = Constants
Temp[14] = 3
Stack[Temp[10]] = Temp[3][Temp[14]] 
elseif pointer == 26 then -- 22 [JMP] 
 pointer = pointer + 8  
elseif pointer == 27 then -- 23 [EQ] 
 	if Stack[1] == Constants[7] then pointer = pointer + 1 end 
elseif pointer == 28 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 29 then -- 23 [EQ] 
 	if Stack[7] == Constants[17] then pointer = pointer + 1 end 
elseif pointer == 30 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 31 then -- 1 [LOADK] 
 Temp[16] = 8
Temp[5] = Constants
Temp[1] = 11
Stack[Temp[16]] = Temp[5][Temp[1]] 
elseif pointer == 32 then -- 27 [TESTSET] 
 	if (not Stack[8]) then
		pointer = pointer + 1
	else
		Stack[1] = Stack[8]
	end
	 
elseif pointer == 33 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 34 then -- 1 [LOADK] 
 Temp[1] = 1
Temp[3] = Constants
Temp[10] = 3
Stack[Temp[1]] = Temp[3][Temp[10]] 
elseif pointer == 35 then -- 20 [LEN] 
 	Stack[8] = #Stack[2] 
elseif pointer == 36 then -- 12 [ADD] 
 	Stack[8] = Stack[8] + Constants[2] 
elseif pointer == 37 then -- 9 [SETTABLE] 
 	Stack[2][Stack[8]] = Stack[1] 
elseif pointer == 38 then -- 31 [FORLOOP] 
     Stack[3] = Stack[3] + Stack[5]
    if (Stack[5] > 0 and Stack[3] <= Stack[4]) or (Stack[5] <= 0 and Stack[3] >= Stack[4]) then
        pointer = pointer + -32
        Stack[6] = Stack[3]
    end
     
elseif pointer == 39 then -- 0 [MOVE] 
 Temp[11] = 3
Temp[7] = 1
Stack[Temp[11]] = Stack[Temp[7]] 
elseif pointer == 40 then -- 5 [GETGLOBAL] 
 Temp[15] = 4
Temp[12] = 9
Temp[5] = Constants[Temp[12]]
Stack[Temp[15]] = vmEnv[Temp[5]] or Env[Temp[5]]
	Stack[4] = Stack[4][Constants[13]]
	
	pointer = pointer + 1 
elseif pointer == 42 then -- 0 [MOVE] 
 Temp[5] = 5
Temp[1] = 2
Stack[Temp[5]] = Stack[Temp[1]] 
elseif pointer == 43 then -- 1 [LOADK] 
 Temp[13] = 6
Temp[2] = Constants
Temp[6] = 8
Stack[Temp[13]] = Temp[2][Temp[6]]
	Temp[2] = {Stack[4](Stack[5], Stack[6])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[4] = nil
		top = 4
	else
		top = 4 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[4 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 45 then -- 30 [RETURN] 
             Temp[1] = {}
            Temp[2] = 0
            for i = 3, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
         
elseif pointer == 46 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 46 then -- 5 [GETGLOBAL] 
 Temp[4] = 10
Temp[10] = 33
Temp[8] = Constants[Temp[10]]
Stack[Temp[4]] = vmEnv[Temp[8]] or Env[Temp[8]] 
elseif pointer == 47 then -- 10 [NEWTABLE] 
 	Stack[11] = {} 
elseif pointer == 48 then -- 1 [LOADK] 
 Temp[1] = 12
Temp[8] = Constants
Temp[12] = 31
Stack[Temp[1]] = Temp[8][Temp[12]] 
elseif pointer == 49 then -- 1 [LOADK] 
 Temp[5] = 13
Temp[14] = Constants
Temp[11] = 2
Stack[Temp[5]] = Temp[14][Temp[11]] 
elseif pointer == 50 then -- 1 [LOADK] 
 Temp[12] = 14
Temp[5] = Constants
Temp[14] = 34
Stack[Temp[12]] = Temp[5][Temp[14]] 
elseif pointer == 51 then -- 34 [SETLIST] 
 	for i = 1, 3 do
		Stack[11][(1 - 1) * 50 + i] = Stack[11 + i]
	end
	 
elseif pointer == 52 then -- 28 [CALL] 
 	Stack[10], Stack[11], Stack[12] = Stack[10](Stack[11]) 
elseif pointer == 53 then -- 22 [JMP] 
 pointer = pointer + 9  
elseif pointer == 54 then -- 5 [GETGLOBAL] 
 Temp[7] = 15
Temp[11] = 3
Temp[4] = Constants[Temp[11]]
Stack[Temp[7]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 55 then -- 1 [LOADK] 
 Temp[6] = 16
Temp[5] = Constants
Temp[1] = 5
Stack[Temp[6]] = Temp[5][Temp[1]] 
elseif pointer == 56 then -- 0 [MOVE] 
 Temp[12] = 17
Temp[7] = 14
Stack[Temp[12]] = Stack[Temp[7]] 
elseif pointer == 57 then -- 1 [LOADK] 
 Temp[10] = 18
Temp[3] = Constants
Temp[7] = 21
Stack[Temp[10]] = Temp[3][Temp[7]] 
elseif pointer == 58 then -- 0 [MOVE] 
 Temp[8] = 19
Temp[15] = 5
Stack[Temp[8]] = Stack[Temp[15]] 
elseif pointer == 59 then -- 0 [MOVE] 
 Temp[3] = 20
Temp[11] = 14
Stack[Temp[3]] = Stack[Temp[11]] 
elseif pointer == 60 then -- 28 [CALL] 
 	Stack[19] = Stack[19](Stack[20]) 
elseif pointer == 61 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 16, 19 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[16] = Temp[1]
	 
elseif pointer == 62 then -- 28 [CALL] 
 	Stack[15](Stack[16]) 
elseif pointer == 63 then -- 33 [TFORLOOP] 
     local r1, r2 = Stack[10](Stack[11], Stack[12])
    Stack[13] = r1
        Stack[14] = r2
    if Stack[13] ~= nil then
        Stack[12] = Stack[13]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 64 then -- 22 [JMP] 
 pointer = pointer + -11  
elseif pointer == 65 then -- 5 [GETGLOBAL] 
 Temp[14] = 10
Temp[7] = 33
Temp[4] = Constants[Temp[7]]
Stack[Temp[14]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 66 then -- 10 [NEWTABLE] 
 	Stack[11] = {} 
elseif pointer == 67 then -- 1 [LOADK] 
 Temp[8] = 12
Temp[15] = Constants
Temp[5] = 14
Stack[Temp[8]] = Temp[15][Temp[5]] 
elseif pointer == 68 then -- 1 [LOADK] 
 Temp[16] = 13
Temp[15] = Constants
Temp[4] = 28
Stack[Temp[16]] = Temp[15][Temp[4]] 
elseif pointer == 69 then -- 1 [LOADK] 
 Temp[12] = 14
Temp[11] = Constants
Temp[16] = 2
Stack[Temp[12]] = Temp[11][Temp[16]] 
elseif pointer == 70 then -- 1 [LOADK] 
 Temp[16] = 15
Temp[9] = Constants
Temp[6] = 24
Stack[Temp[16]] = Temp[9][Temp[6]] 
elseif pointer == 71 then -- 1 [LOADK] 
 Temp[10] = 16
Temp[15] = Constants
Temp[16] = 32
Stack[Temp[10]] = Temp[15][Temp[16]] 
elseif pointer == 72 then -- 34 [SETLIST] 
 	for i = 1, 5 do
		Stack[11][(1 - 1) * 50 + i] = Stack[11 + i]
	end
	 
elseif pointer == 73 then -- 28 [CALL] 
 	Stack[10], Stack[11], Stack[12] = Stack[10](Stack[11]) 
elseif pointer == 74 then -- 22 [JMP] 
 pointer = pointer + 8  
elseif pointer == 75 then -- 5 [GETGLOBAL] 
 Temp[4] = 15
Temp[11] = 3
Temp[12] = Constants[Temp[11]]
Stack[Temp[4]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 76 then -- 0 [MOVE] 
 Temp[11] = 16
Temp[4] = 14
Stack[Temp[11]] = Stack[Temp[4]] 
elseif pointer == 77 then -- 1 [LOADK] 
 Temp[14] = 17
Temp[1] = Constants
Temp[12] = 4
Stack[Temp[14]] = Temp[1][Temp[12]] 
elseif pointer == 78 then -- 0 [MOVE] 
 Temp[13] = 18
Temp[4] = 6
Stack[Temp[13]] = Stack[Temp[4]] 
elseif pointer == 79 then -- 0 [MOVE] 
 Temp[7] = 19
Temp[10] = 14
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 80 then -- 28 [CALL] 
 	Stack[18] = Stack[18](Stack[19]) 
elseif pointer == 81 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 16, 18 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[16] = Temp[1]
	 
elseif pointer == 82 then -- 28 [CALL] 
 	Stack[15](Stack[16]) 
elseif pointer == 83 then -- 33 [TFORLOOP] 
     local r1, r2 = Stack[10](Stack[11], Stack[12])
    Stack[13] = r1
        Stack[14] = r2
    if Stack[13] ~= nil then
        Stack[12] = Stack[13]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 84 then -- 22 [JMP] 
 pointer = pointer + -10  
elseif pointer == 85 then -- 5 [GETGLOBAL] 
 Temp[10] = 10
Temp[8] = 3
Temp[2] = Constants[Temp[8]]
Stack[Temp[10]] = vmEnv[Temp[2]] or Env[Temp[2]] 
elseif pointer == 86 then -- 0 [MOVE] 
 Temp[14] = 11
Temp[1] = 7
Stack[Temp[14]] = Stack[Temp[1]] 
elseif pointer == 87 then -- 1 [LOADK] 
 Temp[6] = 12
Temp[14] = Constants
Temp[5] = 27
Stack[Temp[6]] = Temp[14][Temp[5]]
	Stack[11] = Stack[11](Stack[12])
	pointer = pointer + 1 
elseif pointer == 89 then -- 0 [MOVE] 
 Temp[2] = 12
Temp[9] = 7
Stack[Temp[2]] = Stack[Temp[9]] 
elseif pointer == 90 then -- 1 [LOADK] 
 Temp[4] = 13
Temp[1] = Constants
Temp[9] = 16
Stack[Temp[4]] = Temp[1][Temp[9]]
	Stack[12] = Stack[12](Stack[13])
	pointer = pointer + 1 
elseif pointer == 92 then -- 0 [MOVE] 
 Temp[11] = 13
Temp[16] = 8
Stack[Temp[11]] = Stack[Temp[16]] 
elseif pointer == 93 then -- 1 [LOADK] 
 Temp[3] = 14
Temp[11] = Constants
Temp[13] = 17
Stack[Temp[3]] = Temp[11][Temp[13]]
	Temp[2] = {Stack[13](Stack[14])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[13] = nil
		top = 13
	else
		top = 13 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[13 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 95 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 10 + 1, top do
		Temp[1][i - 10] = Stack[i]
	end
	Temp[2] = {Stack[10](unpack(Temp[1], 1, top - 10))}
		for i = 1, 0 do
		Stack[10 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 96 then -- 5 [GETGLOBAL] 
 Temp[6] = 10
Temp[14] = 3
Temp[1] = Constants[Temp[14]]
Stack[Temp[6]] = vmEnv[Temp[1]] or Env[Temp[1]] 
elseif pointer == 97 then -- 0 [MOVE] 
 Temp[3] = 11
Temp[14] = 9
Stack[Temp[3]] = Stack[Temp[14]] 
elseif pointer == 98 then -- 1 [LOADK] 
 Temp[12] = 12
Temp[15] = Constants
Temp[1] = 7
Stack[Temp[12]] = Temp[15][Temp[1]]
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
elseif pointer == 100 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 10 + 1, top do
		Temp[1][i - 10] = Stack[i]
	end
	Temp[2] = {Stack[10](unpack(Temp[1], 1, top - 10))}
		for i = 1, 0 do
		Stack[10 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 101 then -- 5 [GETGLOBAL] 
 Temp[2] = 10
Temp[9] = 3
Temp[11] = Constants[Temp[9]]
Stack[Temp[2]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 102 then -- 0 [MOVE] 
 Temp[12] = 11
Temp[10] = 9
Stack[Temp[12]] = Stack[Temp[10]] 
elseif pointer == 103 then -- 1 [LOADK] 
 Temp[2] = 12
Temp[10] = Constants
Temp[8] = 29
Stack[Temp[2]] = Temp[10][Temp[8]]
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
elseif pointer == 105 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 10 + 1, top do
		Temp[1][i - 10] = Stack[i]
	end
	Temp[2] = {Stack[10](unpack(Temp[1], 1, top - 10))}
		for i = 1, 0 do
		Stack[10 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 106 then -- 30 [RETURN] 
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