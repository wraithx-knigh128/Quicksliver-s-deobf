return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\100\116\014\013\126\120\013\008\121\014\012", "2270")),(decrypt("\093\110\089", "827")),(decrypt("\106\093\106\105", "2461")),(decrypt("\024\058", "2175")),(decrypt("\103\103\090\110\084", "1192")),(decrypt("\083\100\090\093\100\090\097\083\105\096\091\109", "981")),(decrypt("\085\088\082\082\089", "2127")),(decrypt("\088\086\087\095\084\107\111\089", "302")),(decrypt("\100\097\095\094\088\092\093\088\087\105", "2748")),(decrypt("\025\023\063", "2045")),(decrypt("\037\098\018", "990")),(decrypt("\109\095\088\085\094\002\020\018", "243")),(decrypt("\085\092\090\105", "2006")),(decrypt("\085\105\083\109\110", "1187")),(decrypt("\109\080\082\109", "434")),(decrypt("\021\061", "2683")),(decrypt("\002\101\082\099\101\093\098\097\093\082\001\099\098\101\099", "998")),(decrypt("\100\110\084\082\105\100\091", "2847")),(decrypt("\087\084\090\063", "2499")),(decrypt("\103\102\085\100\090\104\090\096\104\083\109", "1018")),(decrypt("\026\061", "2686")),(decrypt("\088\083\069\109", "2341")),(decrypt("\109\092\092\083\088", "1555")),((decrypt("\031\028\030\025\031", "2023"))),(decrypt("\026\051", "1805")),(decrypt("\095\085\083", "834")),(decrypt("\105\100\088\105\091\088\107\111", "2823")),(decrypt("\121\081\034\096\110\020\034\095\091\032\080\095\089\032\094\095\037\110\105\026\037\092\106\097\089\032\085\083\037\092\106\101\037\095\089\101\088\092\085\095\087\006\034\082\084\032\108\101\037\089\085\083\110\032\085\083\037\092\083\046\107\107", "2759")),(decrypt("\085\105\107\081\081", "2332")),(decrypt("\024\051", "1859")),(decrypt("\125\105\083\081\109\094\033\106\107\093\109\109\093\109\108", "617")),(decrypt("\103\096\080\090\109\095", "1601")),(decrypt("\012\092\100\107\087", "2587")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
 Temp[16] = 0
Temp[4] = byte == pairs
Stack[Temp[16]] = Temp[5] 
elseif pointer == 2 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\013\117\013\013", "2157")),((decrypt("\026\030\019", "1986"))),(decrypt("\121\094\090\098\109\100\109", "2868")),(decrypt("\100\002\113\012\120\007", "2884")),(decrypt("\119\114\125\121\119\112\124", "1569")),(decrypt("\117\087\094\083\109", "1129")),}

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
Stack[Temp[15]] = Temp[16] 
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
 Temp[15] = 2
Temp[5] = 6
Temp[4] = Constants[Temp[5]]
Stack[Temp[15]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 5 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 6 then -- 10 [NEWTABLE] 
 	Stack[4] = {} 
elseif pointer == 7 then -- 9 [SETTABLE] 
 	Stack[4][Constants[9]] = Stack[1] 
elseif pointer == 8 then -- 9 [SETTABLE] 
 	Stack[4][Constants[32]] = Stack[1] 
elseif pointer == 9 then -- 9 [SETTABLE] 
 	Stack[4][Constants[18]] = Stack[1] 
elseif pointer == 10 then -- 9 [SETTABLE] 
 	Stack[4][Constants[20]] = Constants[21] 
elseif pointer == 11 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3], Stack[4]) 
elseif pointer == 12 then -- 5 [GETGLOBAL] 
 Temp[10] = 3
Temp[5] = 29
Temp[16] = Constants[Temp[5]]
Stack[Temp[10]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 13 then -- 5 [GETGLOBAL] 
 Temp[6] = 4
Temp[3] = 29
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
Temp[2] = 29
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
Temp[11] = 29
Temp[5] = Constants[Temp[11]]
Stack[Temp[7]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 22 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\106\106\027", "2216")),(decrypt("\015\082\107\091\105\116\106\117\082\110\089", "2278")),(decrypt("\008\100\091\113\081\080\082\096\089\070\127\104\095\083\010\011\081\104\082\100", "680")),(decrypt("\120\094\085\093\081\087\110", "1208")),}

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
 Temp[10] = 0
Temp[2] = 1
Temp[8] = Constants[Temp[2]]
Stack[Temp[10]] = vmEnv[Temp[8]] or Env[Temp[8]] 
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
		Stack[6] = Stack[4][Constants[14]]
	end
	 
elseif pointer == 28 then -- 1 [LOADK] 
 Temp[12] = 8
Temp[14] = Constants
Temp[15] = 11
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
 	if Constants[10] < Stack[5] then pointer = pointer + 1 end 
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
Temp[7] = 23
Temp[10] = Constants[Temp[7]]
Stack[Temp[11]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 36 then -- 1 [LOADK] 
 Temp[14] = 6
Temp[12] = Constants
Temp[15] = 31
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
Temp[7] = 1
Temp[16] = Constants[Temp[7]]
Temp[15] = 5
Temp[9][Temp[16]] = Temp[16] 
elseif pointer == 41 then -- 10 [NEWTABLE] 
 	Stack[5] = {} 
elseif pointer == 42 then -- 9 [SETTABLE] 
 	Stack[5][Constants[18]] = Stack[5] 
elseif pointer == 43 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\122\101\088\090", "1971")),((decrypt("\028\021\028\029\024\024\006\025\025\026\026\024\006", "604"))),(decrypt("\116\116\126\114\116\118\127", "2352")),(decrypt("\084\104\083\107", "1077")),(decrypt("\120\104\093\127\091\084\082\096\091\068\113\096\091\095\012\005\091\108\082\100", "2468")),(decrypt("\117\109\098\081\093\093", "119")),(decrypt("\095\105\092\081\105\092\109\094\111\108\086\107", "557")),(decrypt("\009\105\094\089\091\083\068", "2542")),}

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
	
	Stack[6] = function(...) -- PROTOTYPE 3
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 5}}
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
Temp[15] = 7
Temp[1] = Constants[Temp[15]]
Stack[Temp[12]] = vmEnv[Temp[1]] or Env[Temp[1]] 
elseif pointer == 2 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 3 then -- 9 [SETTABLE] 
 	Stack[2][Constants[4]] = Stack[0] 
elseif pointer == 4 then -- 4 [GETUPVAL] 
 	Stack[3] = Upvalues[0] 
elseif pointer == 5 then -- 29 [TAILCALL] 
 	return Stack[1](Stack[2], Stack[3]) 
elseif pointer == 6 then -- 30 [RETURN] 
             Temp[1] = {}
            Temp[2] = 0
            for i = 1, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
         
elseif pointer == 7 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 45 then -- 9 [SETTABLE] 
 	Stack[5][Constants[2]] = Stack[6] 
elseif pointer == 46 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\111\080\090\086\106\093", "2632")),(decrypt("\091\094\080\085\084\107", "1595")),(decrypt("\037\087\080\082\109\046\104\080\110\097\039", "2909")),(decrypt("\047\023\017\110", "328")),((decrypt("\027", "1663"))),(decrypt("\087\097\080\109", "2941")),(decrypt("\105\080\105\109", "1955")),((decrypt("\017\017\029", "641"))),}

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
		if pointer == 1 then -- 6 [GETTABLE] 
 	Stack[1] = Stack[0][Constants[6]]
	 
elseif pointer == 2 then -- 1 [LOADK] 
 Temp[15] = 2
Temp[13] = Constants
Temp[14] = 3
Stack[Temp[15]] = Temp[13][Temp[14]] 
elseif pointer == 3 then -- 5 [GETGLOBAL] 
 Temp[2] = 3
Temp[10] = 2
Temp[3] = Constants[Temp[10]]
Stack[Temp[2]] = vmEnv[Temp[3]] or Env[Temp[3]]
	Stack[3] = Stack[3][Constants[1]]
	
	pointer = pointer + 1 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[15] = 4
Temp[10] = Constants
Temp[6] = 4
Stack[Temp[15]] = Temp[10][Temp[6]] 
elseif pointer == 6 then -- 11 [SELF] 
 	Stack[6] = Stack[0]
	if Stack[6] then
		Stack[5] = Stack[0][Constants[7]]
	end
	 
elseif pointer == 7 then -- 28 [CALL] 
 	Temp[2] = {Stack[5](Stack[6])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[5] = nil
		top = 5
	else
		top = 5 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[5 + i - 1] = Temp[2][i]
		end
	end
	 
elseif pointer == 8 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 3 + 1, top do
		Temp[1][i - 3] = Stack[i]
	end
	Temp[2] = {Stack[3](unpack(Temp[1], 1, top - 3))}
		for i = 1, 1 do
		Stack[3 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 9 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 1, 3 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[1] = Temp[1]
	 
elseif pointer == 10 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 11 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 47 then -- 9 [SETTABLE] 
 	Stack[5][Constants[27]] = Stack[6] 
elseif pointer == 48 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {(decrypt("\021\050", "2970")),(decrypt("\120\101\104\084\087\098\088", "2922")),(decrypt("\012\100\110\091\102\032\083\094\108\107\047\107\082\096\110\084\100\108", "787")),(decrypt("\015\110\080\082\110\109\039\090\084\033\080\084\082\093\080\105\081\086\065\109", "2601")),(decrypt("\124\085\091\087\104\086\109", "1517")),((decrypt("\030\030\018\017\030\018\017", "695"))),}

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
	
	Stack[6] = function(...) -- PROTOTYPE 5
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
Temp[1] = Constants
Temp[3] = 1
Stack[Temp[16]] = Temp[1][Temp[3]] 
elseif pointer == 2 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 3 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 49 then -- 9 [SETTABLE] 
 	Stack[5][Constants[3]] = Stack[6] 
elseif pointer == 50 then -- 5 [GETGLOBAL] 
 Temp[13] = 6
Temp[16] = 6
Temp[3] = Constants[Temp[16]]
Stack[Temp[13]] = vmEnv[Temp[3]] or Env[Temp[3]] 
elseif pointer == 51 then -- 10 [NEWTABLE] 
 	Stack[7] = {} 
elseif pointer == 52 then -- 10 [NEWTABLE] 
 	Stack[8] = {} 
elseif pointer == 53 then -- 9 [SETTABLE] 
 	Stack[8][Constants[18]] = Stack[5] 
elseif pointer == 54 then -- 28 [CALL] 
 	Stack[6] = Stack[6](Stack[7], Stack[8]) 
elseif pointer == 55 then -- 9 [SETTABLE] 
 	Stack[6][Constants[18]] = Stack[6] 
elseif pointer == 56 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[6] then
		C1 = {}
		local encoded = {((decrypt("\021\017\025\021\031", "2448"))),(decrypt("\015\083\080\085\088\108\105\110", "2355")),((decrypt("\024\030\028\022", "1979"))),(decrypt("\109\088\091\109\091\110", "782")),(decrypt("\091\106\093\082\109\093\110\093\105\111\085\106", "1666")),(decrypt("\090\104\111\083\092\094", "304")),(decrypt("\010\106\094\097\123\089\083\080\109\120\105\080\092\082\111\101", "1259")),(decrypt("\087\107\093", "2734")),}

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
	
	Stack[7] = function(...) -- PROTOTYPE 6
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 5}, [1] = {0, 6}}
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
 	Stack[1] = Stack[1][Constants[8]]
	 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[10] = 2
Temp[3] = Constants
Temp[15] = 4
Stack[Temp[10]] = Temp[3][Temp[15]]
	Stack[1] = Stack[1](Stack[2])
	pointer = pointer + 1 
elseif pointer == 5 then -- 9 [SETTABLE] 
 	Stack[1][Constants[6]] = Stack[0] 
elseif pointer == 6 then -- 5 [GETGLOBAL] 
 Temp[10] = 2
Temp[7] = 5
Temp[13] = Constants[Temp[7]]
Stack[Temp[10]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 7 then -- 0 [MOVE] 
 Temp[1] = 3
Temp[10] = 1
Stack[Temp[1]] = Stack[Temp[10]] 
elseif pointer == 8 then -- 4 [GETUPVAL] 
 	Stack[4] = Upvalues[1] 
elseif pointer == 9 then -- 29 [TAILCALL] 
 	return Stack[2](Stack[3], Stack[4]) 
elseif pointer == 10 then -- 30 [RETURN] 
             Temp[1] = {}
            Temp[2] = 0
            for i = 2, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
         
elseif pointer == 11 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 59 then -- 9 [SETTABLE] 
 	Stack[6][Constants[2]] = Stack[7] 
elseif pointer == 60 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[7] then
		C1 = {}
		local encoded = {(decrypt("\118\110\092\080\106\094\085\085\109\104\106\127\110\095\088\082\108\105", "265")),(decrypt("\117\085\096\092\111\080\081\083\120\093\096\082\105", "2687")),(decrypt("\027\061", "2644")),(decrypt("\086\105\095\107", "2144")),(decrypt("\105\110\090\094\106", "469")),(decrypt("\088\107\106\080\093\089", "1310")),(decrypt("\120\088\108\080\089\111\093\126\081\107\068\101\091", "2349")),((decrypt("\027\019\026\019\025\026\002", "1628"))),(decrypt("\086\080", "1043")),}

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
		if pointer == 1 then -- 5 [GETGLOBAL] 
 Temp[6] = 1
Temp[12] = 4
Temp[4] = Constants[Temp[12]]
Stack[Temp[6]] = vmEnv[Temp[4]] or Env[Temp[4]]
	Stack[1] = Stack[1][Constants[9]]
	
	pointer = pointer + 1 
elseif pointer == 3 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[6]]
	 
elseif pointer == 4 then -- 17 [POW] 
 	Stack[2] = Stack[2] ^ Constants[3] 
elseif pointer == 5 then -- 14 [MUL] 
 	Stack[1] = Stack[1] * Stack[2] 
elseif pointer == 6 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 7 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 61 then -- 9 [SETTABLE] 
 	Stack[6][Constants[3]] = Stack[7] 
elseif pointer == 62 then -- 5 [GETGLOBAL] 
 Temp[4] = 7
Temp[10] = 6
Temp[8] = Constants[Temp[10]]
Stack[Temp[4]] = vmEnv[Temp[8]] or Env[Temp[8]] 
elseif pointer == 63 then -- 10 [NEWTABLE] 
 	Stack[8] = {} 
elseif pointer == 64 then -- 10 [NEWTABLE] 
 	Stack[9] = {} 
elseif pointer == 65 then -- 9 [SETTABLE] 
 	Stack[9][Constants[18]] = Stack[5] 
elseif pointer == 66 then -- 28 [CALL] 
 	Stack[7] = Stack[7](Stack[8], Stack[9]) 
elseif pointer == 67 then -- 9 [SETTABLE] 
 	Stack[7][Constants[18]] = Stack[7] 
elseif pointer == 68 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[8] then
		C1 = {}
		local encoded = {(decrypt("\000\099\083\088\084\100", "898")),(decrypt("\120\081\106\111\090", "1140")),(decrypt("\088\111\092\085\110\088\111\090\106\106\084\109", "2371")),(decrypt("\106\100\084\107\103\095", "584")),(decrypt("\116\088\087\107", "783")),((decrypt("\022\016\025", "1514"))),(decrypt("\092\105\093", "953")),(decrypt("\088\101\099\088", "1993")),(decrypt("\118\110\081\090\124\085\100\106\105", "862")),(decrypt("\008\107\088\081\105\125\100\086\084\089\100\105", "2482")),(decrypt("\092\089\104\092\109", "2937")),}

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
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 5}, [1] = {0, 7}}
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
 	Stack[2] = Upvalues[0] 
elseif pointer == 2 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[2][Constants[7]]
	 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[11] = 3
Temp[9] = Constants
Temp[4] = 8
Stack[Temp[11]] = Temp[9][Temp[4]]
	Stack[2] = Stack[2](Stack[3])
	pointer = pointer + 1 
elseif pointer == 5 then -- 0 [MOVE] 
 Temp[9] = 3
Temp[11] = 0
Stack[Temp[9]] = Stack[Temp[11]] 
elseif pointer == 6 then -- 9 [SETTABLE] 
 	Stack[2][Constants[4]] = Stack[1] 
elseif pointer == 7 then -- 9 [SETTABLE] 
 	Stack[2][Constants[11]] = Stack[3] 
elseif pointer == 8 then -- 5 [GETGLOBAL] 
 Temp[3] = 3
Temp[9] = 3
Temp[6] = Constants[Temp[9]]
Stack[Temp[3]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 9 then -- 0 [MOVE] 
 Temp[14] = 4
Temp[10] = 2
Stack[Temp[14]] = Stack[Temp[10]] 
elseif pointer == 10 then -- 4 [GETUPVAL] 
 	Stack[5] = Upvalues[1] 
elseif pointer == 11 then -- 29 [TAILCALL] 
 	return Stack[3](Stack[4], Stack[5]) 
elseif pointer == 12 then -- 30 [RETURN] 
             Temp[1] = {}
            Temp[2] = 0
            for i = 3, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
         
elseif pointer == 13 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 71 then -- 9 [SETTABLE] 
 	Stack[7][Constants[2]] = Stack[8] 
elseif pointer == 72 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[9] then
		C1 = {}
		local encoded = {(decrypt("\095\086\105\089\110", "1622")),(decrypt("\115\088\093\085\082\081\103", "2492")),(decrypt("\013\084\109\081\065\086\092\100\106", "1178")),(decrypt("\013\013\118\010\122\009", "615")),((decrypt("\026\016\026\027\026", "354"))),(decrypt("\105\105\089\104\106\082", "659")),(decrypt("\127\094\106\092\094\110\092\011\094\085", "552")),(decrypt("\080\109\072\103", "2181")),}

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
	
	Stack[8] = function(...) -- PROTOTYPE 9
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
		if pointer == 1 then -- 6 [GETTABLE] 
 	Stack[1] = Stack[0][Constants[1]]
	 
elseif pointer == 2 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[6]]
	 
elseif pointer == 3 then -- 14 [MUL] 
 	Stack[1] = Stack[1] * Stack[2] 
elseif pointer == 4 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 5 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 73 then -- 9 [SETTABLE] 
 	Stack[7][Constants[3]] = Stack[8] 
elseif pointer == 74 then -- 10 [NEWTABLE] 
 	Stack[8] = {} 
elseif pointer == 75 then -- 9 [SETTABLE] 
 	Stack[8][Constants[18]] = Stack[8] 
elseif pointer == 76 then -- 9 [SETTABLE] 
 	Stack[8][Constants[5]] = Constants[19] 
elseif pointer == 77 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[10] then
		C1 = {}
		local encoded = {(decrypt("\108\080\088\089\090", "1013")),(decrypt("\082\105\090\090", "110")),(decrypt("\114\106\089\085\106\089\114\093\086\081\110\110\100", "860")),(decrypt("\115\109\090\081\083\086", "753")),(decrypt("\001\008\115", "949")),(decrypt("\124\100\090\082\081\094\086\047\085\088\089\092\105\083\105\103", "1838")),(decrypt("\083\107\083\093\107\083\097\092\096\096\084\100", "978")),(decrypt("\082\095\107\086\088", "2472")),(decrypt("\025\056", "1330")),(decrypt("\021\059", "2057")),(decrypt("\117\089\093\090", "2988")),}

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
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 8}}
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
 Temp[9] = 0
Temp[14] = 7
Temp[3] = Constants[Temp[14]]
Stack[Temp[9]] = vmEnv[Temp[3]] or Env[Temp[3]] 
elseif pointer == 2 then -- 10 [NEWTABLE] 
 	Stack[1] = {} 
elseif pointer == 3 then -- 9 [SETTABLE] 
 	Stack[1][Constants[1]] = Constants[9] 
elseif pointer == 4 then -- 9 [SETTABLE] 
 	Stack[1][Constants[2]] = Constants[10] 
elseif pointer == 5 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 6 then -- 9 [SETTABLE] 
 	Stack[1][Constants[8]] = Stack[2] 
elseif pointer == 7 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 8 then -- 29 [TAILCALL] 
 	return Stack[0](Stack[1], Stack[2]) 
elseif pointer == 9 then -- 30 [RETURN] 
             Temp[1] = {}
            Temp[2] = 0
            for i = 0, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
         
elseif pointer == 10 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 79 then -- 9 [SETTABLE] 
 	Stack[8][Constants[2]] = Stack[9] 
elseif pointer == 80 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[11] then
		C1 = {}
		local encoded = {(decrypt("\026\056", "2309")),(decrypt("\085\111\082\093", "678")),(decrypt("\015\105\080\084\110\106", "2107")),((decrypt("\017\016\022\025", "573"))),(decrypt("\109\106\093\111\003", "329")),(decrypt("\081\090\107\092\091", "1178")),}

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
	
	Stack[9] = function(...) -- PROTOTYPE 11
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
		if pointer == 1 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[2]]
	 
elseif pointer == 2 then -- 12 [ADD] 
 	Stack[2] = Stack[2] + Constants[1] 
elseif pointer == 3 then -- 9 [SETTABLE] 
 	Stack[0][Constants[2]] = Stack[2] 
elseif pointer == 4 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[6]]
	 
elseif pointer == 5 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[0][Constants[2]]
	 
elseif pointer == 6 then -- 9 [SETTABLE] 
 	Stack[2][Stack[3]] = Stack[1] 
elseif pointer == 7 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 81 then -- 9 [SETTABLE] 
 	Stack[8][Constants[13]] = Stack[9] 
elseif pointer == 82 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[12] then
		C1 = {}
		local encoded = {(decrypt("\026\061", "2681")),(decrypt("\125\091\108\092\113\106", "1105")),(decrypt("\082\111\083\093", "1796")),(decrypt("\087\082\090\062", "2298")),(decrypt("\107\083\081\104\081\107\098", "1545")),(decrypt("\082\095\106\086\088", "2462")),(decrypt("\123\108\081\089\109\089\114\095\087\089\096\106\109", "1084")),(decrypt("\108\081\080\091\090", "119")),}

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
	
	Stack[9] = function(...) -- PROTOTYPE 12
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
		if pointer == 1 then -- 6 [GETTABLE] 
 	Stack[1] = Stack[0][Constants[8]]
	 
elseif pointer == 2 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[3]]
	 
elseif pointer == 3 then -- 24 [LT] 
 	if Stack[2] < Stack[1] then pointer = pointer + 1 end 
elseif pointer == 4 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 5 then -- 3 [LOADNIL] 
 	Stack[1], Stack[2] = nil 
elseif pointer == 6 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 7 then -- 6 [GETTABLE] 
 	Stack[1] = Stack[0][Constants[6]]
	 
elseif pointer == 8 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[8]]
	 
elseif pointer == 9 then -- 6 [GETTABLE] 
 	Stack[1] = Stack[1][Stack[2]]
	 
elseif pointer == 10 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[6]]
	 
elseif pointer == 11 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[0][Constants[8]]
	 
elseif pointer == 12 then -- 9 [SETTABLE] 
 	Stack[2][Stack[3]] = Constants[4] 
elseif pointer == 13 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[8]]
	 
elseif pointer == 14 then -- 12 [ADD] 
 	Stack[2] = Stack[2] + Constants[1] 
elseif pointer == 15 then -- 9 [SETTABLE] 
 	Stack[0][Constants[8]] = Stack[2] 
elseif pointer == 16 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 17 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 83 then -- 9 [SETTABLE] 
 	Stack[8][Constants[26]] = Stack[9] 
elseif pointer == 84 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[13] then
		C1 = {}
		local encoded = {(decrypt("\123\081\091\084\106\125\107\088\092\087\109\109", "1771")),(decrypt("\114\091\108\094\101\082\092\092\126\094\096\081\110", "584")),(decrypt("\123\107\095\091\081\109\106\033\093\082\110\091\105\087\085\110\104\084\106", "1766")),(decrypt("\026\063", "2457")),(decrypt("\081\096\092\083", "2868")),(decrypt("\101\085\094\082\094", "857")),}

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
	
	Stack[9] = function(...) -- PROTOTYPE 13
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
		if pointer == 1 then -- 6 [GETTABLE] 
 	Stack[1] = Stack[0][Constants[5]]
	 
elseif pointer == 2 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[6]]
	 
elseif pointer == 3 then -- 13 [SUB] 
 	Stack[1] = Stack[1] - Stack[2] 
elseif pointer == 4 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Constants[4] 
elseif pointer == 5 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 6 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 85 then -- 9 [SETTABLE] 
 	Stack[8][Constants[22]] = Stack[9] 
elseif pointer == 86 then -- 6 [GETTABLE] 
 	Stack[9] = Stack[8][Constants[2]]
	
	Stack[9] = Stack[9]()
	pointer = pointer + 1 
elseif pointer == 88 then -- 11 [SELF] 
 	Stack[11] = Stack[9]
	if Stack[11] then
		Stack[10] = Stack[9][Constants[13]]
	end
	 
elseif pointer == 89 then -- 6 [GETTABLE] 
 	Stack[12] = Stack[6][Constants[2]]
	 
elseif pointer == 90 then -- 1 [LOADK] 
 Temp[1] = 13
Temp[8] = Constants
Temp[12] = 30
Stack[Temp[1]] = Temp[8][Temp[12]]
	Temp[2] = {Stack[12](Stack[13])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[12] = nil
		top = 12
	else
		top = 12 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[12 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 92 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 10 + 1, top do
		Temp[1][i - 10] = Stack[i]
	end
	Temp[2] = {Stack[10](unpack(Temp[1], 1, top - 10))}
		for i = 1, 0 do
		Stack[10 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 93 then -- 11 [SELF] 
 	Stack[11] = Stack[9]
	if Stack[11] then
		Stack[10] = Stack[9][Constants[13]]
	end
	 
elseif pointer == 94 then -- 6 [GETTABLE] 
 	Stack[12] = Stack[7][Constants[2]]
	 
elseif pointer == 95 then -- 1 [LOADK] 
 Temp[5] = 13
Temp[14] = Constants
Temp[11] = 4
Stack[Temp[5]] = Temp[14][Temp[11]] 
elseif pointer == 96 then -- 1 [LOADK] 
 Temp[12] = 14
Temp[5] = Constants
Temp[14] = 25
Stack[Temp[12]] = Temp[5][Temp[14]]
	Temp[2] = {Stack[12](Stack[13], Stack[14])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[12] = nil
		top = 12
	else
		top = 12 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[12 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 98 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 10 + 1, top do
		Temp[1][i - 10] = Stack[i]
	end
	Temp[2] = {Stack[10](unpack(Temp[1], 1, top - 10))}
		for i = 1, 0 do
		Stack[10 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 99 then -- 11 [SELF] 
 	Stack[11] = Stack[9]
	if Stack[11] then
		Stack[10] = Stack[9][Constants[13]]
	end
	 
elseif pointer == 100 then -- 6 [GETTABLE] 
 	Stack[12] = Stack[5][Constants[2]]
	 
elseif pointer == 101 then -- 1 [LOADK] 
 Temp[7] = 13
Temp[11] = Constants
Temp[4] = 15
Stack[Temp[7]] = Temp[11][Temp[4]]
	Temp[2] = {Stack[12](Stack[13])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[12] = nil
		top = 12
	else
		top = 12 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[12 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 103 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 10 + 1, top do
		Temp[1][i - 10] = Stack[i]
	end
	Temp[2] = {Stack[10](unpack(Temp[1], 1, top - 10))}
		for i = 1, 0 do
		Stack[10 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 104 then -- 11 [SELF] 
 	Stack[11] = Stack[9]
	if Stack[11] then
		Stack[10] = Stack[9][Constants[22]]
	end
	 
elseif pointer == 105 then -- 28 [CALL] 
 	Stack[10] = Stack[10](Stack[11]) 
elseif pointer == 106 then -- 24 [LT] 
 	if Constants[16] < Stack[10] then pointer = pointer + 1 end 
elseif pointer == 107 then -- 22 [JMP] 
 pointer = pointer + 7  
elseif pointer == 108 then -- 5 [GETGLOBAL] 
 Temp[6] = 10
Temp[5] = 7
Temp[1] = Constants[Temp[5]]
Stack[Temp[6]] = vmEnv[Temp[1]] or Env[Temp[1]] 
elseif pointer == 109 then -- 11 [SELF] 
 	Stack[12] = Stack[9]
	if Stack[12] then
		Stack[11] = Stack[9][Constants[26]]
	end
	 
elseif pointer == 110 then -- 28 [CALL] 
 	Stack[11] = Stack[11](Stack[12]) 
elseif pointer == 111 then -- 11 [SELF] 
 	Stack[12] = Stack[11]
	if Stack[12] then
		Stack[11] = Stack[11][Constants[27]]
	end
	 
elseif pointer == 112 then -- 28 [CALL] 
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
	 
elseif pointer == 113 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 10 + 1, top do
		Temp[1][i - 10] = Stack[i]
	end
	Temp[2] = {Stack[10](unpack(Temp[1], 1, top - 10))}
		for i = 1, 0 do
		Stack[10 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 114 then -- 22 [JMP] 
 pointer = pointer + -11  
elseif pointer == 115 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[14] then
		C1 = {}
		local encoded = {(decrypt("\015\109\095\110\081", "2546")),(decrypt("\047\096\017", "383")),((decrypt("\022", "1632"))),(decrypt("\025\058", "1126")),(decrypt("\000", "1581")),(decrypt("\022\051", "1886")),(decrypt("\111\083\105\094\107\104", "1715")),(decrypt("\087\085\087", "352")),(decrypt("\017\036", "2371")),(decrypt("\095\096\105\087\100", "480")),(decrypt("\024\060", "2710")),(decrypt("\081\084\093\100\091", "2238")),(decrypt("\091\084\090\083", "1238")),(decrypt("\104\094\083\104\106\083", "2862")),(decrypt("\086\106\095\102", "2249")),(decrypt("\086\111\083\080\091", "1739")),}

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
	
	Stack[10] = function(...) -- PROTOTYPE 14
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
elseif pointer == 2 then -- 11 [SELF] 
 	Stack[3] = Stack[0]
	if Stack[3] then
		Stack[2] = Stack[0][Constants[12]]
	end
	 
elseif pointer == 3 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3]) 
elseif pointer == 4 then -- 11 [SELF] 
 	Stack[3] = Stack[2]
	if Stack[3] then
		Stack[2] = Stack[2][Constants[7]]
	end
	 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[9] = 4
Temp[7] = Constants
Temp[16] = 2
Stack[Temp[9]] = Temp[7][Temp[16]]
	Stack[2], Stack[3], Stack[4] = Stack[2](Stack[3], Stack[4])
	pointer = pointer + 1 
elseif pointer == 7 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 8 then -- 6 [GETTABLE] 
 	Stack[6] = Stack[1][Stack[5]]
	 
elseif pointer == 9 then -- 26 [TEST] 
 	if not Stack[6] then pointer = pointer + 1 end 
elseif pointer == 10 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 11 then -- 1 [LOADK] 
 Temp[8] = 6
Temp[2] = Constants
Temp[4] = 6
Stack[Temp[8]] = Temp[2][Temp[4]] 
elseif pointer == 12 then -- 12 [ADD] 
 	Stack[6] = Stack[6] + Constants[4] 
elseif pointer == 13 then -- 9 [SETTABLE] 
 	Stack[1][Stack[5]] = Stack[6] 
elseif pointer == 14 then -- 33 [TFORLOOP] 
     local r1 = Stack[2](Stack[3], Stack[4])
    Stack[5] = r1
    if Stack[5] ~= nil then
        Stack[4] = Stack[5]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 15 then -- 22 [JMP] 
 pointer = pointer + -8  
elseif pointer == 16 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 17 then -- 5 [GETGLOBAL] 
 Temp[13] = 3
Temp[7] = 16
Temp[5] = Constants[Temp[7]]
Stack[Temp[13]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 18 then -- 0 [MOVE] 
 Temp[9] = 4
Temp[11] = 1
Stack[Temp[9]] = Stack[Temp[11]] 
elseif pointer == 19 then -- 28 [CALL] 
 	Stack[3], Stack[4], Stack[5] = Stack[3](Stack[4]) 
elseif pointer == 20 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 21 then -- 20 [LEN] 
 	Stack[7] = #Stack[2] 
elseif pointer == 22 then -- 12 [ADD] 
 	Stack[7] = Stack[7] + Constants[4] 
elseif pointer == 23 then -- 9 [SETTABLE] 
 	Stack[2][Stack[7]] = Stack[6] 
elseif pointer == 24 then -- 33 [TFORLOOP] 
     local r1 = Stack[3](Stack[4], Stack[5])
    Stack[6] = r1
    if Stack[6] ~= nil then
        Stack[5] = Stack[6]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 25 then -- 22 [JMP] 
 pointer = pointer + -5  
elseif pointer == 26 then -- 5 [GETGLOBAL] 
 Temp[6] = 3
Temp[1] = 10
Temp[5] = Constants[Temp[1]]
Stack[Temp[6]] = vmEnv[Temp[5]] or Env[Temp[5]]
	Stack[3] = Stack[3][Constants[13]]
	
	pointer = pointer + 1 
elseif pointer == 28 then -- 0 [MOVE] 
 Temp[3] = 4
Temp[2] = 2
Stack[Temp[3]] = Stack[Temp[2]] 
elseif pointer == 29 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[15] then
		C1 = {}
		local encoded = {(decrypt("\120\100\111\094\087\099\095", "2858")),(decrypt("\117\012\021", "1796")),(decrypt("\011\097\095\108\031\018", "2950")),}

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
	
	Stack[5] = function(...) -- PROTOTYPE 15
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
 	Stack[2] = Upvalues[0] 
elseif pointer == 2 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[2][Stack[0]]
	 
elseif pointer == 3 then -- 4 [GETUPVAL] 
 	Stack[3] = Upvalues[0] 
elseif pointer == 4 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[3][Stack[1]]
	 
elseif pointer == 5 then -- 23 [EQ] 
 	if Stack[2] ~= Stack[3] then pointer = pointer + 1 end 
elseif pointer == 6 then -- 22 [JMP] 
 pointer = pointer + 9  
elseif pointer == 7 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 8 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[2][Stack[0]]
	 
elseif pointer == 9 then -- 4 [GETUPVAL] 
 	Stack[3] = Upvalues[0] 
elseif pointer == 10 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[3][Stack[1]]
	 
elseif pointer == 11 then -- 24 [LT] 
 	if Stack[3] > Stack[2] then pointer = pointer + 1 end 
elseif pointer == 12 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 13 then -- 2 [LOADBOOL] 
 Temp[3] = 2
Temp[13] = byte == pairs
Stack[Temp[3]] = Temp[15]\n\tpointer = pointer + 1 
elseif pointer == 14 then -- 2 [LOADBOOL] 
 Temp[12] = 2
Temp[10] = ttostring ~= __metatable
Stack[Temp[12]] = Temp[15] 
elseif pointer == 15 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 16 then -- 24 [LT] 
 	if Stack[0] > Stack[1] then pointer = pointer + 1 end 
elseif pointer == 17 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 18 then -- 2 [LOADBOOL] 
 Temp[14] = 2
Temp[12] = byte == pairs
Stack[Temp[14]] = Temp[1]\n\tpointer = pointer + 1 
elseif pointer == 19 then -- 2 [LOADBOOL] 
 Temp[6] = 2
Temp[15] = ttostring ~= __metatable
Stack[Temp[6]] = Temp[7] 
elseif pointer == 20 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 21 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 31 then -- 28 [CALL] 
 	Stack[3](Stack[4], Stack[5]) 
elseif pointer == 32 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 33 then -- 1 [LOADK] 
 Temp[13] = 4
Temp[9] = Constants
Temp[10] = 4
Stack[Temp[13]] = Temp[9][Temp[10]] 
elseif pointer == 34 then -- 5 [GETGLOBAL] 
 Temp[7] = 5
Temp[2] = 15
Temp[12] = Constants[Temp[2]]
Stack[Temp[7]] = vmEnv[Temp[12]] or Env[Temp[12]]
	Stack[5] = Stack[5][Constants[8]]
	
	pointer = pointer + 1 
elseif pointer == 36 then -- 1 [LOADK] 
 Temp[4] = 6
Temp[10] = Constants
Temp[16] = 11
Stack[Temp[4]] = Temp[10][Temp[16]] 
elseif pointer == 37 then -- 20 [LEN] 
 	Stack[7] = #Stack[2] 
elseif pointer == 38 then -- 28 [CALL] 
 	Stack[5] = Stack[5](Stack[6], Stack[7]) 
elseif pointer == 39 then -- 1 [LOADK] 
 Temp[10] = 6
Temp[9] = Constants
Temp[11] = 4
Stack[Temp[10]] = Temp[9][Temp[11]] 
elseif pointer == 40 then -- 32 [FORPREP] 
     Stack[4] = Stack[4] - Stack[6]
    pointer = pointer + 8
     
elseif pointer == 41 then -- 20 [LEN] 
 	Stack[8] = #Stack[3] 
elseif pointer == 42 then -- 12 [ADD] 
 	Stack[8] = Stack[8] + Constants[4] 
elseif pointer == 43 then -- 6 [GETTABLE] 
 	Stack[9] = Stack[2][Stack[7]]
	 
elseif pointer == 44 then -- 1 [LOADK] 
 Temp[3] = 10
Temp[2] = Constants
Temp[9] = 5
Stack[Temp[3]] = Temp[2][Temp[9]] 
elseif pointer == 45 then -- 6 [GETTABLE] 
 	Stack[11] = Stack[2][Stack[7]]
	 
elseif pointer == 46 then -- 6 [GETTABLE] 
 	Stack[11] = Stack[1][Stack[11]]
	 
elseif pointer == 47 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 9, 11 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[9] = Temp[1]
	 
elseif pointer == 48 then -- 9 [SETTABLE] 
 	Stack[3][Stack[8]] = Stack[9] 
elseif pointer == 49 then -- 31 [FORLOOP] 
     Stack[4] = Stack[4] + Stack[6]
    if (Stack[6] > 0 and Stack[4] <= Stack[5]) or (Stack[6] <= 0 and Stack[4] >= Stack[5]) then
        pointer = pointer + -9
        Stack[7] = Stack[4]
    end
     
elseif pointer == 50 then -- 5 [GETGLOBAL] 
 Temp[4] = 4
Temp[6] = 10
Temp[11] = Constants[Temp[6]]
Stack[Temp[4]] = vmEnv[Temp[11]] or Env[Temp[11]]
	Stack[4] = Stack[4][Constants[14]]
	
	pointer = pointer + 1 
elseif pointer == 52 then -- 0 [MOVE] 
 Temp[10] = 5
Temp[14] = 3
Stack[Temp[10]] = Stack[Temp[14]] 
elseif pointer == 53 then -- 1 [LOADK] 
 Temp[3] = 6
Temp[5] = Constants
Temp[9] = 9
Stack[Temp[3]] = Temp[5][Temp[9]] 
elseif pointer == 54 then -- 29 [TAILCALL] 
 	return Stack[4](Stack[5], Stack[6]) 
elseif pointer == 55 then -- 30 [RETURN] 
             Temp[1] = {}
            Temp[2] = 0
            for i = 4, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
         
elseif pointer == 56 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 116 then -- 5 [GETGLOBAL] 
 Temp[12] = 11
Temp[7] = 7
Temp[10] = Constants[Temp[7]]
Stack[Temp[12]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 117 then -- 0 [MOVE] 
 Temp[3] = 12
Temp[7] = 10
Stack[Temp[3]] = Stack[Temp[7]] 
elseif pointer == 118 then -- 1 [LOADK] 
 Temp[8] = 13
Temp[15] = Constants
Temp[3] = 28
Stack[Temp[8]] = Temp[15][Temp[3]]
	Temp[2] = {Stack[12](Stack[13])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[12] = nil
		top = 12
	else
		top = 12 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[12 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 120 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 11 + 1, top do
		Temp[1][i - 11] = Stack[i]
	end
	Temp[2] = {Stack[11](unpack(Temp[1], 1, top - 11))}
		for i = 1, 0 do
		Stack[11 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 121 then -- 30 [RETURN] 
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