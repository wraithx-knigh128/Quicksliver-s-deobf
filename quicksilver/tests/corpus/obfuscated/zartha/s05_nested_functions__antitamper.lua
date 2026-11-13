return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\037\107\018", "900")),(decrypt("\109\089\092\085\088", "1053")),(decrypt("\090\109\096\091\109", "1598")),(decrypt("\121\104\087\080\110\089\036\108\110\091\111\109\089\108\104", "2037")),(decrypt("\016\062", "859")),(decrypt("\025\057", "2270")),(decrypt("\095\104\111\091\081", "827")),(decrypt("\100\098\093\087\088\095\095\081\087\106", "2461")),(decrypt("\024\022\060", "2175")),(decrypt("\014\093\093\106\084\087\089\105", "1192")),(decrypt("\018\031\058", "981")),(decrypt("\027\058", "2127")),(decrypt("\025\059", "302")),(decrypt("\008\081\082\091\105\081\090\093", "2748")),(decrypt("\014\104\094\094", "2045")),(decrypt("\082\095\085\085\093\105\101\080", "990")),(decrypt("\085\093\083\087\095", "243")),(decrypt("\100\102\080\083\105\108\095", "2006")),(decrypt("\103\103\088\092\109\088", "1187")),(decrypt("\125\085\087\087", "434")),(decrypt("\030\061", "2683")),(decrypt("\083\101\083\093\101\083\097\082\096\096\090\100", "998")),(decrypt("\017", "2847")),(decrypt("\100\098\093\101\089\108\082\097\107\087\101", "2499")),(decrypt("\025\023\058", "1018")),(decrypt("\104\080\093\108\106\093", "2686")),(decrypt("\100\117\013\012\126\121\014\009\121\015\015", "2341")),(decrypt("\085\109\094\111\110", "1555")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
 Temp[11] = 0
Temp[10] = byte == pairs
Stack[Temp[11]] = Temp[5] 
elseif pointer == 2 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\103\013\122\013\123\008", "1735")),(decrypt("\015\090\080\081\096\080\080\103", "590")),(decrypt("\126\093\111\095\114\082\084\090\089\125\111\095\095\087\105\106", "2736")),}

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
 Temp[6] = 0
Temp[13] = ttostring ~= __metatable
Stack[Temp[6]] = Temp[5] 
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
 Temp[16] = 2
Temp[15] = 22
Temp[13] = Constants[Temp[15]]
Stack[Temp[16]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 5 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 6 then -- 10 [NEWTABLE] 
 	Stack[4] = {} 
elseif pointer == 7 then -- 9 [SETTABLE] 
 	Stack[4][Constants[8]] = Stack[1] 
elseif pointer == 8 then -- 9 [SETTABLE] 
 	Stack[4][Constants[19]] = Stack[1] 
elseif pointer == 9 then -- 9 [SETTABLE] 
 	Stack[4][Constants[18]] = Stack[1] 
elseif pointer == 10 then -- 9 [SETTABLE] 
 	Stack[4][Constants[24]] = Constants[5] 
elseif pointer == 11 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3], Stack[4]) 
elseif pointer == 12 then -- 5 [GETGLOBAL] 
 Temp[10] = 3
Temp[3] = 7
Temp[9] = Constants[Temp[3]]
Stack[Temp[10]] = vmEnv[Temp[9]] or Env[Temp[9]] 
elseif pointer == 13 then -- 5 [GETGLOBAL] 
 Temp[14] = 4
Temp[16] = 7
Temp[4] = Constants[Temp[16]]
Stack[Temp[14]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 14 then -- 0 [MOVE] 
 Temp[4] = 5
Temp[5] = 2
Stack[Temp[4]] = Stack[Temp[5]] 
elseif pointer == 15 then -- 0 [MOVE] 
 Temp[15] = 6
Temp[5] = 2
Stack[Temp[15]] = Stack[Temp[5]] 
elseif pointer == 16 then -- 28 [CALL] 
 	Stack[3](Stack[4], Stack[5], Stack[6]) 
elseif pointer == 17 then -- 5 [GETGLOBAL] 
 Temp[4] = 3
Temp[10] = 7
Temp[5] = Constants[Temp[10]]
Stack[Temp[4]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 18 then -- 5 [GETGLOBAL] 
 Temp[5] = 4
Temp[16] = 16
Temp[6] = Constants[Temp[16]]
Stack[Temp[5]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 19 then -- 0 [MOVE] 
 Temp[3] = 5
Temp[5] = 2
Stack[Temp[3]] = Stack[Temp[5]] 
elseif pointer == 20 then -- 28 [CALL] 
 	Stack[3](Stack[4], Stack[5]) 
elseif pointer == 21 then -- 5 [GETGLOBAL] 
 Temp[6] = 3
Temp[16] = 7
Temp[10] = Constants[Temp[16]]
Stack[Temp[6]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 22 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\105\110\027", "1610")),(decrypt("\127\083\094\083\107\080\104", "2343")),(decrypt("\009\101\110\092\108\046\083\086\105\101\032\108\087\097\110\083\110\098", "2970")),(decrypt("\015\097\082\081\110\098\037\089\084\046\082\087\082\082\082\106\081\089\067\110", "2922")),}

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
 Temp[4] = 0
Temp[14] = 1
Temp[8] = Constants[Temp[14]]
Stack[Temp[4]] = vmEnv[Temp[8]] or Env[Temp[8]] 
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
 Temp[4] = 5
Temp[13] = 16
Temp[2] = Constants[Temp[13]]
Stack[Temp[4]] = vmEnv[Temp[2]] or Env[Temp[2]] 
elseif pointer == 27 then -- 11 [SELF] 
 	Stack[7] = Stack[4]
	if Stack[7] then
		Stack[6] = Stack[4][Constants[28]]
	end
	 
elseif pointer == 28 then -- 1 [LOADK] 
 Temp[15] = 8
Temp[6] = Constants
Temp[14] = 1
Stack[Temp[15]] = Temp[6][Temp[14]]
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
 Temp[5] = 5
Temp[3] = 1
Stack[Temp[5]] = Stack[Temp[3]] 
elseif pointer == 34 then -- 28 [CALL] 
 	Stack[5]() 
elseif pointer == 35 then -- 5 [GETGLOBAL] 
 Temp[7] = 5
Temp[5] = 2
Temp[11] = Constants[Temp[5]]
Stack[Temp[7]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 36 then -- 1 [LOADK] 
 Temp[7] = 6
Temp[15] = Constants
Temp[9] = 4
Stack[Temp[7]] = Temp[15][Temp[9]] 
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
 Temp[12] = 5
Temp[14] = ttostring ~= __metatable
Stack[Temp[12]] = Temp[15] 
elseif pointer == 40 then -- 7 [SETGLOBAL] 
 Temp[7] = vmEnv
Temp[10] = 27
Temp[4] = Constants[Temp[10]]
Temp[11] = 5
Temp[7][Temp[4]] = Temp[4] 
elseif pointer == 41 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\110\097\091\089\101", "398")),(decrypt("\014\093\082\110\084\087\086\109", "1166")),(decrypt("\126\089\104\091\115\111", "234")),}

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
		if pointer == 1 then -- 0 [MOVE] 
 Temp[4] = 2
Temp[15] = 0
Stack[Temp[4]] = Stack[Temp[15]] 
elseif pointer == 2 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[13] then
		C1 = {}
		local encoded = {(decrypt("\121\108\090\108\104\088", "243")),(decrypt("\114\082\089\109\081\087\111\034\106\094\106\089\086\107\081\094", "2745")),(decrypt("\008\085\108\111\083", "1645")),(decrypt("\117\095\084\088\109", "1982")),(decrypt("\115\084\086\092\109\089", "723")),}

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
	
	Stack[3] = function(...) -- PROTOTYPE 13
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
 
elseif pointer == 42 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\114\086\094\105\091\094\109\086", "2355")),(decrypt("\012\089\082\089\091\102\107\098", "1979")),((decrypt("\016\029\031\026\021", "782"))),}

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
		if pointer == 1 then -- 10 [NEWTABLE] 
 	Stack[1] = {} 
elseif pointer == 2 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[14] then
		C1 = {}
		local encoded = {((decrypt("\026\019\017\021", "2462"))),(decrypt("\084\080\091\050", "1084")),(decrypt("\097", "119")),(decrypt("\084\092\080\081", "1032")),}

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
	
	Stack[2] = function(...) -- PROTOTYPE 14
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
 	if Stack[1] == Constants[2] then pointer = pointer + 1 end 
elseif pointer == 4 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 5 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[1] 
elseif pointer == 6 then -- 0 [MOVE] 
 Temp[5] = 3
Temp[1] = 0
Stack[Temp[5]] = Stack[Temp[1]] 
elseif pointer == 7 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3]) 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[11] = 1
Temp[15] = 2
Stack[Temp[11]] = Stack[Temp[15]] 
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
 
elseif pointer == 43 then -- 3 [LOADNIL] 
 	Stack[7], Stack[8], Stack[9], Stack[10], Stack[11], Stack[12], Stack[13], Stack[14] = nil 
elseif pointer == 44 then -- 0 [MOVE] 
 Temp[14] = 8
Temp[12] = 6
Stack[Temp[14]] = Stack[Temp[12]] 
elseif pointer == 45 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {(decrypt("\098", "253")),(decrypt("\123\100\082\089\081\094\093\036\109\087\095\083\088\100\099", "1883")),(decrypt("\027\058", "2132")),((decrypt("\027\022\024\029\020\027", "334"))),(decrypt("\010\126\011\121\114", "2419")),(decrypt("\017\058", "914")),}

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
	
	Stack[9] = function(...) -- PROTOTYPE 5
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 7}}
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
 	if Stack[0] < Constants[3] then pointer = pointer + 1 end 
elseif pointer == 2 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 3 then -- 30 [RETURN] 
 	return Stack[0] 
elseif pointer == 4 then -- 4 [GETUPVAL] 
 	Stack[1] = Upvalues[0] 
elseif pointer == 5 then -- 13 [SUB] 
 	Stack[2] = Stack[0] - Constants[6] 
elseif pointer == 6 then -- 28 [CALL] 
 	Stack[1] = Stack[1](Stack[2]) 
elseif pointer == 7 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 8 then -- 13 [SUB] 
 	Stack[3] = Stack[0] - Constants[3] 
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
 
elseif pointer == 47 then -- 28 [CALL] 
 	Stack[8] = Stack[8](Stack[9]) 
elseif pointer == 48 then -- 0 [MOVE] 
 Temp[15] = 7
Temp[13] = 8
Stack[Temp[15]] = Stack[Temp[13]] 
elseif pointer == 49 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[6] then
		C1 = {}
		local encoded = {(decrypt("\092\111\082\096", "1716")),(decrypt("\009\083\093\081\114\106\095\085\086\108\100", "686")),(decrypt("\110\107\090\089\111", "339")),}

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

	if not ProtosConstants[15] then
		C1 = {}
		local encoded = {(decrypt("\106\082\085\081\085\104\106\094\082\084\080\020\083\095\084\087", "252")),((decrypt("\025\001\029\020\024", "110"))),(decrypt("\012\111\081\085\107\120\106\084\087\091\108\106", "601")),(decrypt("\021\031\050", "1798")),(decrypt("\010\101\090\106\065", "1992")),(decrypt("\025\057", "1225")),}

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
	
	Stack[2] = function(...) -- PROTOTYPE 15
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
 Temp[15] = 2
Temp[12] = Constants
Temp[5] = 6
Stack[Temp[15]] = Temp[12][Temp[5]] 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[5] = 3
Temp[1] = Constants
Temp[13] = 4
Stack[Temp[5]] = Temp[1][Temp[13]] 
elseif pointer == 5 then -- 32 [FORPREP] 
     Stack[1] = Stack[1] - Stack[3]
    pointer = pointer + 5
     
elseif pointer == 6 then -- 4 [GETUPVAL] 
 	Stack[5] = Upvalues[0] 
elseif pointer == 7 then -- 6 [GETTABLE] 
 	Stack[5] = Stack[5][Stack[4]]
	 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[2] = 6
Temp[6] = 0
Stack[Temp[2]] = Stack[Temp[6]] 
elseif pointer == 9 then -- 28 [CALL] 
 	Stack[5] = Stack[5](Stack[6]) 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[13] = 0
Temp[8] = 5
Stack[Temp[13]] = Stack[Temp[8]] 
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
 
elseif pointer == 50 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[7] then
		C1 = {}
		local encoded = {(decrypt("\127\106\097\087", "469")),(decrypt("\123\012\009\025\029\030", "1310")),(decrypt("\082\084\108\089\091\089", "2349")),}

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
		if pointer == 1 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 2 then -- 5 [GETGLOBAL] 
 Temp[9] = 3
Temp[6] = 3
Temp[12] = Constants[Temp[6]]
Stack[Temp[9]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 3 then -- 0 [MOVE] 
 Temp[4] = 4
Temp[15] = 0
Stack[Temp[4]] = Stack[Temp[15]] 
elseif pointer == 4 then -- 28 [CALL] 
 	Stack[3], Stack[4], Stack[5] = Stack[3](Stack[4]) 
elseif pointer == 5 then -- 22 [JMP] 
 pointer = pointer + 5  
elseif pointer == 6 then -- 0 [MOVE] 
 Temp[2] = 8
Temp[16] = 1
Stack[Temp[2]] = Stack[Temp[16]] 
elseif pointer == 7 then -- 0 [MOVE] 
 Temp[16] = 9
Temp[12] = 7
Stack[Temp[16]] = Stack[Temp[12]] 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[11] = 10
Temp[2] = 6
Stack[Temp[11]] = Stack[Temp[2]] 
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
 
elseif pointer == 51 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[8] then
		C1 = {}
		local encoded = {(decrypt("\026\056", "2371")),(decrypt("\095\100\087\105\098\095", "584")),(decrypt("\112\091\107\071\100\090\126\100\087\081\085\083\082\102", "783")),(decrypt("\011\106\081\087\106\124\109\080\087\088\109\111", "1514")),(decrypt("\030\062", "953")),(decrypt("\043", "1993")),(decrypt("\113\086\108\103\093", "862")),(decrypt("\088\104\082\088\082\082\093\100", "2482")),}

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
	
	Stack[10] = function(...) -- PROTOTYPE 8
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
 Temp[16] = 1
Temp[11] = Constants
Temp[9] = 5
Stack[Temp[16]] = Temp[11][Temp[9]] 
elseif pointer == 2 then -- 1 [LOADK] 
 Temp[4] = 2
Temp[9] = Constants
Temp[11] = 1
Stack[Temp[4]] = Temp[9][Temp[11]] 
elseif pointer == 3 then -- 5 [GETGLOBAL] 
 Temp[3] = 3
Temp[9] = 2
Temp[6] = Constants[Temp[9]]
Stack[Temp[3]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[14] = 4
Temp[10] = Constants
Temp[15] = 6
Stack[Temp[14]] = Temp[10][Temp[15]] 
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
 Temp[14] = 4
Temp[16] = Constants
Temp[5] = 1
Stack[Temp[14]] = Temp[16][Temp[5]] 
elseif pointer == 8 then -- 32 [FORPREP] 
     Stack[2] = Stack[2] - Stack[4]
    pointer = pointer + 5
     
elseif pointer == 9 then -- 5 [GETGLOBAL] 
 Temp[8] = 6
Temp[11] = 2
Temp[14] = Constants[Temp[11]]
Stack[Temp[8]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[11] = 7
Temp[15] = 5
Stack[Temp[11]] = Stack[Temp[15]] 
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
 
elseif pointer == 52 then -- 0 [MOVE] 
 Temp[6] = 11
Temp[2] = 5
Stack[Temp[6]] = Stack[Temp[2]] 
elseif pointer == 53 then -- 1 [LOADK] 
 Temp[9] = 12
Temp[7] = Constants
Temp[16] = 25
Stack[Temp[9]] = Temp[7][Temp[16]] 
elseif pointer == 54 then -- 1 [LOADK] 
 Temp[15] = 13
Temp[13] = Constants
Temp[3] = 21
Stack[Temp[15]] = Temp[13][Temp[3]]
	Stack[11] = Stack[11](Stack[12], Stack[13])
	pointer = pointer + 1 
elseif pointer == 56 then -- 5 [GETGLOBAL] 
 Temp[16] = 12
Temp[4] = 17
Temp[10] = Constants[Temp[4]]
Stack[Temp[16]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 57 then -- 0 [MOVE] 
 Temp[10] = 13
Temp[8] = 11
Stack[Temp[10]] = Stack[Temp[8]] 
elseif pointer == 58 then -- 28 [CALL] 
 	Stack[13] = Stack[13]() 
elseif pointer == 59 then -- 0 [MOVE] 
 Temp[1] = 14
Temp[8] = 11
Stack[Temp[1]] = Stack[Temp[8]] 
elseif pointer == 60 then -- 28 [CALL] 
 	Stack[14] = Stack[14]() 
elseif pointer == 61 then -- 0 [MOVE] 
 Temp[1] = 15
Temp[12] = 11
Stack[Temp[1]] = Stack[Temp[12]] 
elseif pointer == 62 then -- 28 [CALL] 
 	Temp[2] = {Stack[15]()}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[15] = nil
		top = 15
	else
		top = 15 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[15 + i - 1] = Temp[2][i]
		end
	end
	 
elseif pointer == 63 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 12 + 1, top do
		Temp[1][i - 12] = Stack[i]
	end
	Temp[2] = {Stack[12](unpack(Temp[1], 1, top - 12))}
		for i = 1, 0 do
		Stack[12 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 64 then -- 5 [GETGLOBAL] 
 Temp[5] = 12
Temp[14] = 17
Temp[11] = Constants[Temp[14]]
Stack[Temp[5]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 65 then -- 0 [MOVE] 
 Temp[12] = 13
Temp[5] = 7
Stack[Temp[12]] = Stack[Temp[5]] 
elseif pointer == 66 then -- 1 [LOADK] 
 Temp[14] = 14
Temp[7] = Constants
Temp[11] = 9
Stack[Temp[14]] = Temp[7][Temp[11]]
	Stack[13] = Stack[13](Stack[14])
	pointer = pointer + 1 
elseif pointer == 68 then -- 0 [MOVE] 
 Temp[7] = 14
Temp[4] = 7
Stack[Temp[7]] = Stack[Temp[4]] 
elseif pointer == 69 then -- 1 [LOADK] 
 Temp[6] = 15
Temp[5] = Constants
Temp[1] = 11
Stack[Temp[6]] = Temp[5][Temp[1]]
	Temp[2] = {Stack[14](Stack[15])}
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
elseif pointer == 71 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 12 + 1, top do
		Temp[1][i - 12] = Stack[i]
	end
	Temp[2] = {Stack[12](unpack(Temp[1], 1, top - 12))}
		for i = 1, 0 do
		Stack[12 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 72 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[9] then
		C1 = {}
		local encoded = {((decrypt("\020\016\019\027", "354"))),(decrypt("\118\080\084\110\086\089\109\034\097\095\107\085\082\105\092\093", "659")),(decrypt("\029\062", "552")),(decrypt("\124\105\091\083\082\084\102", "2181")),(decrypt("\013\093\083\104\087\087\087\107\123\087\081\091\117\105\094\091", "2170")),}

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
	
	Stack[12] = function(...) -- PROTOTYPE 9
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
 
elseif pointer == 73 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[10] then
		C1 = {}
		local encoded = {(decrypt("\024\056", "1353")),(decrypt("\123\087\105\085\105\092\091\089\109\032\087\085\092\111\084\080\106", "1770")),(decrypt("\121\096\085\085\088\083\105", "786")),(decrypt("\117\106\104\104\084\089\110", "1264")),}

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
	
	Stack[13] = function(...) -- PROTOTYPE 10
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
 	Stack[1] = Stack[0] * Constants[1] 
elseif pointer == 2 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 3 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 74 then -- 5 [GETGLOBAL] 
 Temp[12] = 14
Temp[7] = 17
Temp[10] = Constants[Temp[7]]
Stack[Temp[12]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 75 then -- 0 [MOVE] 
 Temp[3] = 15
Temp[7] = 8
Stack[Temp[3]] = Stack[Temp[7]] 
elseif pointer == 76 then -- 0 [MOVE] 
 Temp[8] = 16
Temp[15] = 12
Stack[Temp[8]] = Stack[Temp[15]] 
elseif pointer == 77 then -- 0 [MOVE] 
 Temp[3] = 17
Temp[11] = 13
Stack[Temp[3]] = Stack[Temp[11]] 
elseif pointer == 78 then -- 28 [CALL] 
 	Stack[15] = Stack[15](Stack[16], Stack[17]) 
elseif pointer == 79 then -- 1 [LOADK] 
 Temp[14] = 16
Temp[7] = Constants
Temp[4] = 21
Stack[Temp[14]] = Temp[7][Temp[4]]
	Stack[15] = Stack[15](Stack[16])
	pointer = pointer + 1 
elseif pointer == 81 then -- 0 [MOVE] 
 Temp[8] = 16
Temp[15] = 8
Stack[Temp[8]] = Stack[Temp[15]] 
elseif pointer == 82 then -- 0 [MOVE] 
 Temp[5] = 17
Temp[16] = 13
Stack[Temp[5]] = Stack[Temp[16]] 
elseif pointer == 83 then -- 0 [MOVE] 
 Temp[15] = 18
Temp[16] = 12
Stack[Temp[15]] = Stack[Temp[16]] 
elseif pointer == 84 then -- 28 [CALL] 
 	Stack[16] = Stack[16](Stack[17], Stack[18]) 
elseif pointer == 85 then -- 1 [LOADK] 
 Temp[4] = 17
Temp[12] = Constants
Temp[11] = 21
Stack[Temp[4]] = Temp[12][Temp[11]]
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
	
	pointer = pointer + 1 
elseif pointer == 87 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 14 + 1, top do
		Temp[1][i - 14] = Stack[i]
	end
	Temp[2] = {Stack[14](unpack(Temp[1], 1, top - 14))}
		for i = 1, 0 do
		Stack[14 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 88 then -- 5 [GETGLOBAL] 
 Temp[16] = 14
Temp[6] = 17
Temp[9] = Constants[Temp[6]]
Stack[Temp[16]] = vmEnv[Temp[9]] or Env[Temp[9]] 
elseif pointer == 89 then -- 5 [GETGLOBAL] 
 Temp[10] = 15
Temp[15] = 3
Temp[16] = Constants[Temp[15]]
Stack[Temp[10]] = vmEnv[Temp[16]] or Env[Temp[16]]
	Stack[15] = Stack[15][Constants[26]]
	
	pointer = pointer + 1 
elseif pointer == 91 then -- 0 [MOVE] 
 Temp[4] = 16
Temp[11] = 9
Stack[Temp[4]] = Stack[Temp[11]] 
elseif pointer == 92 then -- 10 [NEWTABLE] 
 	Stack[17] = {} 
elseif pointer == 93 then -- 1 [LOADK] 
 Temp[12] = 18
Temp[11] = Constants
Temp[4] = 5
Stack[Temp[12]] = Temp[11][Temp[4]] 
elseif pointer == 94 then -- 1 [LOADK] 
 Temp[14] = 19
Temp[1] = Constants
Temp[12] = 12
Stack[Temp[14]] = Temp[1][Temp[12]] 
elseif pointer == 95 then -- 1 [LOADK] 
 Temp[13] = 20
Temp[4] = Constants
Temp[7] = 13
Stack[Temp[13]] = Temp[4][Temp[7]] 
elseif pointer == 96 then -- 1 [LOADK] 
 Temp[10] = 21
Temp[2] = Constants
Temp[8] = 6
Stack[Temp[10]] = Temp[2][Temp[8]] 
elseif pointer == 97 then -- 34 [SETLIST] 
 	for i = 1, 4 do
		Stack[17][(1 - 1) * 50 + i] = Stack[17 + i]
	end
	 
elseif pointer == 98 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[11] then
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
		ProtosConstants[11] = C1
	else
		C1 = ProtosConstants[11]
	end
	
	Stack[18] = function(...) -- PROTOTYPE 11
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
 
elseif pointer == 99 then -- 28 [CALL] 
 	Stack[16] = Stack[16](Stack[17], Stack[18]) 
elseif pointer == 100 then -- 1 [LOADK] 
 Temp[14] = 17
Temp[1] = Constants
Temp[6] = 23
Stack[Temp[14]] = Temp[1][Temp[6]]
	Temp[2] = {Stack[15](Stack[16], Stack[17])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[15] = nil
		top = 15
	else
		top = 15 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[15 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 102 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 14 + 1, top do
		Temp[1][i - 14] = Stack[i]
	end
	Temp[2] = {Stack[14](unpack(Temp[1], 1, top - 14))}
		for i = 1, 0 do
		Stack[14 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 103 then -- 5 [GETGLOBAL] 
 Temp[14] = 14
Temp[5] = 17
Temp[2] = Constants[Temp[5]]
Stack[Temp[14]] = vmEnv[Temp[2]] or Env[Temp[2]] 
elseif pointer == 104 then -- 0 [MOVE] 
 Temp[9] = 15
Temp[4] = 10
Stack[Temp[9]] = Stack[Temp[4]] 
elseif pointer == 105 then -- 1 [LOADK] 
 Temp[1] = 16
Temp[9] = Constants
Temp[11] = 5
Stack[Temp[1]] = Temp[9][Temp[11]] 
elseif pointer == 106 then -- 1 [LOADK] 
 Temp[16] = 17
Temp[3] = Constants
Temp[11] = 12
Stack[Temp[16]] = Temp[3][Temp[11]] 
elseif pointer == 107 then -- 1 [LOADK] 
 Temp[3] = 18
Temp[13] = Constants
Temp[6] = 13
Stack[Temp[3]] = Temp[13][Temp[6]] 
elseif pointer == 108 then -- 1 [LOADK] 
 Temp[14] = 19
Temp[1] = Constants
Temp[3] = 6
Stack[Temp[14]] = Temp[1][Temp[3]] 
elseif pointer == 109 then -- 1 [LOADK] 
 Temp[14] = 20
Temp[12] = Constants
Temp[15] = 21
Stack[Temp[14]] = Temp[12][Temp[15]]
	Stack[15] = Stack[15](Stack[16], Stack[17], Stack[18], Stack[19], Stack[20])
	pointer = pointer + 1 
elseif pointer == 111 then -- 0 [MOVE] 
 Temp[1] = 16
Temp[2] = 10
Stack[Temp[1]] = Stack[Temp[2]] 
elseif pointer == 112 then -- 28 [CALL] 
 	Temp[2] = {Stack[16]()}
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
	 
elseif pointer == 113 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 14 + 1, top do
		Temp[1][i - 14] = Stack[i]
	end
	Temp[2] = {Stack[14](unpack(Temp[1], 1, top - 14))}
		for i = 1, 0 do
		Stack[14 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 114 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[12] then
		C1 = {}
		local encoded = {((decrypt("\030\024\005\031", "1056"))),(decrypt("\010\089\090\098\087\092\085\100\107\082", "1908")),(decrypt("\118\114\120\123", "1420")),}

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
	
	Stack[14] = function(...) -- PROTOTYPE 12
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

	if not ProtosConstants[16] then
		C1 = {}
		local encoded = {(decrypt("\126\094\092\081\099\122\104\081\093\084\098\108", "480")),((decrypt("\024\018\025\027\026\027\001", "2710"))),((decrypt("\026\021\020\031\021", "2238"))),(decrypt("\113\087\107\098\090\082\094\100", "1238")),(decrypt("\009\096\070\088", "2862")),}

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
		ProtosConstants[16] = C1
	else
		C1 = ProtosConstants[16]
	end
	
	Stack[1] = function(...) -- PROTOTYPE 16
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

	if not ProtosConstants[17] then
		C1 = {}
		local encoded = {(decrypt("\025\016\059", "1707")),(decrypt("\118\080\083\100\081\090\085\092\111\046\095\082\105\080\094\101\106", "1959")),(decrypt("\025\023\019\063", "1044")),((decrypt("\022\021\025\024\028", "101"))),(decrypt("\004\081\104\090\106\114\100\124\084\101\095", "914")),(decrypt("\122", "589")),(decrypt("\008\100\094\105\100\081\104\096\081\088\113\104\087\094\089\083\093\106", "384")),}

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
		ProtosConstants[17] = C1
	else
		C1 = ProtosConstants[17]
	end
	
	Stack[1] = function(...) -- PROTOTYPE 17
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
 	Stack[1] = Stack[1] * Constants[3] 
elseif pointer == 3 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[1] 
elseif pointer == 4 then -- 14 [MUL] 
 	Stack[2] = Stack[2] * Constants[1] 
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
 
elseif pointer == 115 then -- 5 [GETGLOBAL] 
 Temp[9] = 15
Temp[11] = 17
Temp[12] = Constants[Temp[11]]
Stack[Temp[9]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 116 then -- 0 [MOVE] 
 Temp[10] = 16
Temp[2] = 14
Stack[Temp[10]] = Stack[Temp[2]] 
elseif pointer == 117 then -- 1 [LOADK] 
 Temp[10] = 17
Temp[8] = Constants
Temp[14] = 5
Stack[Temp[10]] = Temp[8][Temp[14]]
	Stack[16] = Stack[16](Stack[17])
	pointer = pointer + 1 
elseif pointer == 119 then -- 1 [LOADK] 
 Temp[9] = 17
Temp[16] = Constants
Temp[2] = 12
Stack[Temp[9]] = Temp[16][Temp[2]]
	Stack[16] = Stack[16](Stack[17])
	pointer = pointer + 1 
elseif pointer == 121 then -- 1 [LOADK] 
 Temp[9] = 17
Temp[16] = Constants
Temp[11] = 13
Stack[Temp[9]] = Temp[16][Temp[11]]
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
	
	pointer = pointer + 1 
elseif pointer == 123 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 15 + 1, top do
		Temp[1][i - 15] = Stack[i]
	end
	Temp[2] = {Stack[15](unpack(Temp[1], 1, top - 15))}
		for i = 1, 0 do
		Stack[15 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 124 then -- 30 [RETURN] 
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