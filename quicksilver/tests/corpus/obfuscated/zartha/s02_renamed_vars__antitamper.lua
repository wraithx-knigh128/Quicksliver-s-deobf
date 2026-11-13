return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\037\107\018", "900")),(decrypt("\109\089\092\085\088", "1053")),(decrypt("\024\062", "1598")),(decrypt("\121\104\087\080\110\089\036\108\110\091\111\109\089\108\104", "2037")),(decrypt("\016\062", "859")),(decrypt("\024\021\060", "2270")),(decrypt("\095\104\111\091\081", "827")),(decrypt("\100\098\093\087\088\095\095\081\087\106", "2461")),(decrypt("\024\058", "2175")),(decrypt("\014\093\093\106\084\087\089\105", "1192")),(decrypt("\018\031\058", "981")),(decrypt("\030\058", "2127")),(decrypt("\107\085\095\083\083", "302")),(decrypt("\008\081\082\091\105\081\090\093", "2748")),(decrypt("\014\104\094\094", "2045")),(decrypt("\082\095\085\085\093\105\101\080", "990")),(decrypt("\091\082\084\110", "243")),(decrypt("\100\102\080\083\105\108\095", "2006")),(decrypt("\103\103\088\092\109\088", "1187")),(decrypt("\125\085\087\087", "434")),(decrypt("\085\095\088\086\089", "2683")),(decrypt("\083\101\083\093\101\083\097\082\096\096\090\100", "998")),(decrypt("\088\086\082\094\105", "2847")),(decrypt("\100\098\093\101\089\108\082\097\107\087\101", "2499")),(decrypt("\022\059", "1018")),(decrypt("\081\110\093\093\110\095\093", "2686")),(decrypt("\100\117\013\012\126\121\014\009\121\015\015", "2341")),(decrypt("\085\109\094\111\110", "1555")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
		local encoded = {((decrypt("\026\017\007\028", "167"))),(decrypt("\118\080\106\065\111\091\091", "132")),(decrypt("\122\081\094\108\110\011\087\109\109\108", "1726")),(decrypt("\103\003\126\000\123\006", "1978")),(decrypt("\120\088\089", "2823")),}

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
 Temp[11] = 0
Temp[3] = ttostring ~= __metatable
Stack[Temp[11]] = Temp[13] 
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
		local encoded = {(decrypt("\123\110\106\091", "222")),(decrypt("\108\108\025", "443")),(decrypt("\120\106\088\094\105\088\087\089\084\104", "1629")),(decrypt("\010\101\104\081\106\101\105", "1927")),}

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
 Temp[12] = 0
Temp[10] = 2
Temp[2] = Constants[Temp[10]]
Stack[Temp[12]] = vmEnv[Temp[2]] or Env[Temp[2]] 
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
elseif pointer == 41 then -- 10 [NEWTABLE] 
 	Stack[5] = {} 
elseif pointer == 42 then -- 1 [LOADK] 
 Temp[14] = 6
Temp[12] = Constants
Temp[15] = 25
Stack[Temp[14]] = Temp[12][Temp[15]] 
elseif pointer == 43 then -- 1 [LOADK] 
 Temp[13] = 7
Temp[6] = Constants
Temp[2] = 11
Stack[Temp[13]] = Temp[6][Temp[2]] 
elseif pointer == 44 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\091\090\111\086\093\087\088\070", "367")),(decrypt("\095\107\083\107\110\092", "1735")),(decrypt("\080\089\083\051", "590")),(decrypt("\127\107\090\086\111\087\111\109", "2736")),(decrypt("\117\081\080\094\110\093", "1755")),(decrypt("\090\086\082\032\110\108\108\090\065\001\035", "1047")),(decrypt("\008\081\087\092\107\082\082\102", "2278")),(decrypt("\114\080\105\099\101", "991")),(decrypt("\016\051", "782")),(decrypt("\013\104\104\083\089\107", "2400")),}

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
	
	Stack[8] = function(...) -- PROTOTYPE 3
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 5}, [1] = {0, 6}, [2] = {0, 7}}
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
 	Stack[3] = Upvalues[0] 
elseif pointer == 2 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[3][Stack[0]]
	 
elseif pointer == 3 then -- 14 [MUL] 
 	Stack[4] = Stack[1] * Stack[2] 
elseif pointer == 4 then -- 4 [GETUPVAL] 
 	Stack[5] = Upvalues[1] 
elseif pointer == 5 then -- 12 [ADD] 
 	Stack[5] = Stack[5] + Stack[4] 
elseif pointer == 6 then -- 4 [GETUPVAL] 
 	Stack[6] = Upvalues[2] 
elseif pointer == 7 then -- 24 [LT] 
 	if Stack[6] < Stack[5] then pointer = pointer + 1 end 
elseif pointer == 8 then -- 22 [JMP] 
 pointer = pointer + 5  
elseif pointer == 9 then -- 2 [LOADBOOL] 
 Temp[7] = 5
Temp[13] = byte == pairs
Stack[Temp[7]] = Temp[3] 
elseif pointer == 10 then -- 1 [LOADK] 
 Temp[6] = 6
Temp[9] = Constants
Temp[13] = 6
Stack[Temp[6]] = Temp[9][Temp[13]] 
elseif pointer == 11 then -- 0 [MOVE] 
 Temp[16] = 7
Temp[4] = 0
Stack[Temp[16]] = Stack[Temp[4]] 
elseif pointer == 12 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 6, 7 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[6] = Temp[1]
	 
elseif pointer == 13 then -- 30 [RETURN] 
 	return Stack[5], Stack[6] 
elseif pointer == 14 then -- 23 [EQ] 
 	if Stack[3] == Constants[3] then pointer = pointer + 1 end 
elseif pointer == 15 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 16 then -- 10 [NEWTABLE] 
 	Stack[5] = {} 
elseif pointer == 17 then -- 9 [SETTABLE] 
 	Stack[5][Constants[2]] = Stack[1] 
elseif pointer == 18 then -- 9 [SETTABLE] 
 	Stack[5][Constants[1]] = Constants[9] 
elseif pointer == 19 then -- 0 [MOVE] 
 Temp[14] = 3
Temp[8] = 5
Stack[Temp[14]] = Stack[Temp[8]] 
elseif pointer == 20 then -- 4 [GETUPVAL] 
 	Stack[5] = Upvalues[0] 
elseif pointer == 21 then -- 9 [SETTABLE] 
 	Stack[5][Stack[0]] = Stack[3] 
elseif pointer == 22 then -- 6 [GETTABLE] 
 	Stack[5] = Stack[3][Constants[1]]
	 
elseif pointer == 23 then -- 12 [ADD] 
 	Stack[5] = Stack[5] + Stack[2] 
elseif pointer == 24 then -- 9 [SETTABLE] 
 	Stack[3][Constants[1]] = Stack[5] 
elseif pointer == 25 then -- 4 [GETUPVAL] 
 	Stack[5] = Upvalues[1] 
elseif pointer == 26 then -- 12 [ADD] 
 	Stack[5] = Stack[5] + Stack[4] 
elseif pointer == 27 then -- 8 [SETUPVAL] 
 	Upvalues[1] = Stack[5] 
elseif pointer == 28 then -- 2 [LOADBOOL] 
 Temp[4] = 5
Temp[16] = ttostring ~= __metatable
Stack[Temp[4]] = Temp[1] 
elseif pointer == 29 then -- 30 [RETURN] 
 	return Stack[5] 
elseif pointer == 30 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 48 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\019\059", "402")),(decrypt("\010\009\118\011\122\009", "1557")),(decrypt("\089\090\111\086\090\086\092\067", "1673")),(decrypt("\087\085\091\054", "2580")),(decrypt("\126\094\104\081\114\111", "2448")),(decrypt("\092\111\085\107\109\088", "2355")),(decrypt("\084\095\092\046\109\092\081\085\111\102\032", "1979")),}

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
	
	Stack[9] = function(...) -- PROTOTYPE 4
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
 	Stack[2] = Upvalues[0] 
elseif pointer == 2 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[2][Stack[0]]
	 
elseif pointer == 3 then -- 23 [EQ] 
 	if Stack[2] ~= Constants[4] then pointer = pointer + 1 end 
elseif pointer == 4 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 5 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[2][Constants[3]]
	 
elseif pointer == 6 then -- 24 [LT] 
 	if Stack[3] < Stack[1] then pointer = pointer + 1 end 
elseif pointer == 7 then -- 22 [JMP] 
 pointer = pointer + 5  
elseif pointer == 8 then -- 2 [LOADBOOL] 
 Temp[4] = 3
Temp[9] = byte == pairs
Stack[Temp[4]] = Temp[2] 
elseif pointer == 9 then -- 1 [LOADK] 
 Temp[7] = 4
Temp[15] = Constants
Temp[10] = 7
Stack[Temp[7]] = Temp[15][Temp[10]] 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[3] = 5
Temp[15] = 0
Stack[Temp[3]] = Stack[Temp[15]] 
elseif pointer == 11 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 4, 5 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[4] = Temp[1]
	 
elseif pointer == 12 then -- 30 [RETURN] 
 	return Stack[3], Stack[4] 
elseif pointer == 13 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[2][Constants[3]]
	 
elseif pointer == 14 then -- 13 [SUB] 
 	Stack[3] = Stack[3] - Stack[1] 
elseif pointer == 15 then -- 9 [SETTABLE] 
 	Stack[2][Constants[3]] = Stack[3] 
elseif pointer == 16 then -- 4 [GETUPVAL] 
 	Stack[3] = Upvalues[1] 
elseif pointer == 17 then -- 6 [GETTABLE] 
 	Stack[4] = Stack[2][Constants[6]]
	 
elseif pointer == 18 then -- 14 [MUL] 
 	Stack[4] = Stack[4] * Stack[1] 
elseif pointer == 19 then -- 13 [SUB] 
 	Stack[3] = Stack[3] - Stack[4] 
elseif pointer == 20 then -- 8 [SETUPVAL] 
 	Upvalues[1] = Stack[3] 
elseif pointer == 21 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[2][Constants[3]]
	 
elseif pointer == 22 then -- 23 [EQ] 
 	if Stack[3] == Constants[1] then pointer = pointer + 1 end 
elseif pointer == 23 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 24 then -- 4 [GETUPVAL] 
 	Stack[3] = Upvalues[0] 
elseif pointer == 25 then -- 9 [SETTABLE] 
 	Stack[3][Stack[0]] = Constants[4] 
elseif pointer == 26 then -- 2 [LOADBOOL] 
 Temp[10] = 3
Temp[7] = ttostring ~= __metatable
Stack[Temp[10]] = Temp[13] 
elseif pointer == 27 then -- 30 [RETURN] 
 	return Stack[3] 
elseif pointer == 28 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 51 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {(decrypt("\089\080\094\106\085\034\092\106\085\108\105\094\003\033", "265")),(decrypt("\089\110\097\084\110", "2687")),(decrypt("\092\106\084\106\109\093", "2644")),(decrypt("\085\105\084\093\088", "2144")),(decrypt("\035\089", "469")),(decrypt("\091\085\088\091", "1310")),(decrypt("\026\056", "2349")),(decrypt("\089\090\106\093\090\086\089\072", "1628")),(decrypt("\117\104\093\081\109\091\083\080\105\106\104\121\109\089\089\083\107\108", "1043")),(decrypt("\123\090\110\090\090\109\095\116\082\105\070\111\088", "1163")),(decrypt("\085\088\082\092\089", "2129")),(decrypt("\087\083\110\087\093\092", "746")),(decrypt("\037\039", "2800")),(decrypt("\086\111\023", "417")),}

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
	
	Stack[10] = function(...) -- PROTOTYPE 5
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
		if pointer == 1 then -- 10 [NEWTABLE] 
 	Stack[0] = {} 
elseif pointer == 2 then -- 5 [GETGLOBAL] 
 Temp[16] = 1
Temp[11] = 4
Temp[12] = Constants[Temp[11]]
Stack[Temp[16]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 3 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 4 then -- 28 [CALL] 
 	Stack[1], Stack[2], Stack[3] = Stack[1](Stack[2]) 
elseif pointer == 5 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 6 then -- 20 [LEN] 
 	Stack[5] = #Stack[0] 
elseif pointer == 7 then -- 12 [ADD] 
 	Stack[5] = Stack[5] + Constants[7] 
elseif pointer == 8 then -- 9 [SETTABLE] 
 	Stack[0][Stack[5]] = Stack[4] 
elseif pointer == 9 then -- 33 [TFORLOOP] 
     local r1 = Stack[1](Stack[2], Stack[3])
    Stack[4] = r1
    if Stack[4] ~= nil then
        Stack[3] = Stack[4]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 10 then -- 22 [JMP] 
 pointer = pointer + -5  
elseif pointer == 11 then -- 5 [GETGLOBAL] 
 Temp[2] = 1
Temp[9] = 2
Temp[16] = Constants[Temp[9]]
Stack[Temp[2]] = vmEnv[Temp[16]] or Env[Temp[16]]
	Stack[1] = Stack[1][Constants[6]]
	
	pointer = pointer + 1 
elseif pointer == 13 then -- 0 [MOVE] 
 Temp[6] = 2
Temp[7] = 0
Stack[Temp[6]] = Stack[Temp[7]] 
elseif pointer == 14 then -- 28 [CALL] 
 	Stack[1](Stack[2]) 
elseif pointer == 15 then -- 5 [GETGLOBAL] 
 Temp[10] = 1
Temp[12] = 12
Temp[9] = Constants[Temp[12]]
Stack[Temp[10]] = vmEnv[Temp[9]] or Env[Temp[9]] 
elseif pointer == 16 then -- 0 [MOVE] 
 Temp[4] = 2
Temp[5] = 0
Stack[Temp[4]] = Stack[Temp[5]] 
elseif pointer == 17 then -- 28 [CALL] 
 	Stack[1], Stack[2], Stack[3] = Stack[1](Stack[2]) 
elseif pointer == 18 then -- 22 [JMP] 
 pointer = pointer + 13  
elseif pointer == 19 then -- 4 [GETUPVAL] 
 	Stack[6] = Upvalues[0] 
elseif pointer == 20 then -- 6 [GETTABLE] 
 	Stack[6] = Stack[6][Stack[5]]
	 
elseif pointer == 21 then -- 5 [GETGLOBAL] 
 Temp[12] = 7
Temp[5] = 11
Temp[6] = Constants[Temp[5]]
Stack[Temp[12]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 22 then -- 0 [MOVE] 
 Temp[13] = 8
Temp[3] = 5
Stack[Temp[13]] = Stack[Temp[3]] 
elseif pointer == 23 then -- 1 [LOADK] 
 Temp[4] = 9
Temp[8] = Constants
Temp[5] = 5
Stack[Temp[4]] = Temp[8][Temp[5]] 
elseif pointer == 24 then -- 6 [GETTABLE] 
 	Stack[10] = Stack[6][Constants[8]]
	 
elseif pointer == 25 then -- 1 [LOADK] 
 Temp[11] = 11
Temp[5] = Constants
Temp[14] = 13
Stack[Temp[11]] = Temp[5][Temp[14]] 
elseif pointer == 26 then -- 6 [GETTABLE] 
 	Stack[12] = Stack[6][Constants[3]]
	 
elseif pointer == 27 then -- 6 [GETTABLE] 
 	Stack[13] = Stack[6][Constants[8]]
	 
elseif pointer == 28 then -- 14 [MUL] 
 	Stack[12] = Stack[12] * Stack[13] 
elseif pointer == 29 then -- 1 [LOADK] 
 Temp[16] = 13
Temp[11] = Constants
Temp[9] = 14
Stack[Temp[16]] = Temp[11][Temp[9]] 
elseif pointer == 30 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 8, 13 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[8] = Temp[1]
	 
elseif pointer == 31 then -- 28 [CALL] 
 	Stack[7](Stack[8]) 
elseif pointer == 32 then -- 33 [TFORLOOP] 
     local r1, r2 = Stack[1](Stack[2], Stack[3])
    Stack[4] = r1
        Stack[5] = r2
    if Stack[4] ~= nil then
        Stack[3] = Stack[4]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 33 then -- 22 [JMP] 
 pointer = pointer + -15  
elseif pointer == 34 then -- 5 [GETGLOBAL] 
 Temp[4] = 1
Temp[9] = 11
Temp[11] = Constants[Temp[9]]
Stack[Temp[4]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 35 then -- 1 [LOADK] 
 Temp[3] = 2
Temp[9] = Constants
Temp[6] = 1
Stack[Temp[3]] = Temp[9][Temp[6]] 
elseif pointer == 36 then -- 4 [GETUPVAL] 
 	Stack[3] = Upvalues[1] 
elseif pointer == 37 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 2, 3 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[2] = Temp[1]
	 
elseif pointer == 38 then -- 28 [CALL] 
 	Stack[1](Stack[2]) 
elseif pointer == 39 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 54 then -- 5 [GETGLOBAL] 
 Temp[9] = 11
Temp[7] = 21
Temp[16] = Constants[Temp[7]]
Stack[Temp[9]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 55 then -- 0 [MOVE] 
 Temp[15] = 12
Temp[13] = 8
Stack[Temp[15]] = Stack[Temp[13]] 
elseif pointer == 56 then -- 1 [LOADK] 
 Temp[13] = 13
Temp[3] = Constants
Temp[16] = 17
Stack[Temp[13]] = Temp[3][Temp[16]] 
elseif pointer == 57 then -- 1 [LOADK] 
 Temp[4] = 14
Temp[10] = Constants
Temp[8] = 9
Stack[Temp[4]] = Temp[10][Temp[8]] 
elseif pointer == 58 then -- 1 [LOADK] 
 Temp[1] = 15
Temp[8] = Constants
Temp[12] = 3
Stack[Temp[1]] = Temp[8][Temp[12]]
	Temp[2] = {Stack[12](Stack[13], Stack[14], Stack[15])}
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
elseif pointer == 60 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 11 + 1, top do
		Temp[1][i - 11] = Stack[i]
	end
	Temp[2] = {Stack[11](unpack(Temp[1], 1, top - 11))}
		for i = 1, 0 do
		Stack[11 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 61 then -- 5 [GETGLOBAL] 
 Temp[5] = 11
Temp[14] = 21
Temp[11] = Constants[Temp[14]]
Stack[Temp[5]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 62 then -- 0 [MOVE] 
 Temp[12] = 12
Temp[5] = 8
Stack[Temp[12]] = Stack[Temp[5]] 
elseif pointer == 63 then -- 1 [LOADK] 
 Temp[14] = 13
Temp[7] = Constants
Temp[11] = 26
Stack[Temp[14]] = Temp[7][Temp[11]] 
elseif pointer == 64 then -- 1 [LOADK] 
 Temp[7] = 14
Temp[4] = Constants
Temp[6] = 12
Stack[Temp[7]] = Temp[4][Temp[6]] 
elseif pointer == 65 then -- 1 [LOADK] 
 Temp[5] = 15
Temp[1] = Constants
Temp[12] = 5
Stack[Temp[5]] = Temp[1][Temp[12]]
	Temp[2] = {Stack[12](Stack[13], Stack[14], Stack[15])}
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
elseif pointer == 67 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 11 + 1, top do
		Temp[1][i - 11] = Stack[i]
	end
	Temp[2] = {Stack[11](unpack(Temp[1], 1, top - 11))}
		for i = 1, 0 do
		Stack[11 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 68 then -- 5 [GETGLOBAL] 
 Temp[7] = 11
Temp[10] = 21
Temp[3] = Constants[Temp[10]]
Stack[Temp[7]] = vmEnv[Temp[3]] or Env[Temp[3]] 
elseif pointer == 69 then -- 0 [MOVE] 
 Temp[7] = 12
Temp[8] = 8
Stack[Temp[7]] = Stack[Temp[8]] 
elseif pointer == 70 then -- 1 [LOADK] 
 Temp[15] = 13
Temp[3] = Constants
Temp[11] = 13
Stack[Temp[15]] = Temp[3][Temp[11]] 
elseif pointer == 71 then -- 1 [LOADK] 
 Temp[14] = 14
Temp[7] = Constants
Temp[4] = 6
Stack[Temp[14]] = Temp[7][Temp[4]] 
elseif pointer == 72 then -- 1 [LOADK] 
 Temp[8] = 15
Temp[15] = Constants
Temp[5] = 3
Stack[Temp[8]] = Temp[15][Temp[5]]
	Temp[2] = {Stack[12](Stack[13], Stack[14], Stack[15])}
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
elseif pointer == 74 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 11 + 1, top do
		Temp[1][i - 11] = Stack[i]
	end
	Temp[2] = {Stack[11](unpack(Temp[1], 1, top - 11))}
		for i = 1, 0 do
		Stack[11 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 75 then -- 5 [GETGLOBAL] 
 Temp[16] = 11
Temp[15] = 21
Temp[4] = Constants[Temp[15]]
Stack[Temp[16]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 76 then -- 0 [MOVE] 
 Temp[12] = 12
Temp[11] = 9
Stack[Temp[12]] = Stack[Temp[11]] 
elseif pointer == 77 then -- 1 [LOADK] 
 Temp[16] = 13
Temp[9] = Constants
Temp[6] = 17
Stack[Temp[16]] = Temp[9][Temp[6]] 
elseif pointer == 78 then -- 1 [LOADK] 
 Temp[10] = 14
Temp[15] = Constants
Temp[16] = 5
Stack[Temp[10]] = Temp[15][Temp[16]]
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
elseif pointer == 80 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 11 + 1, top do
		Temp[1][i - 11] = Stack[i]
	end
	Temp[2] = {Stack[11](unpack(Temp[1], 1, top - 11))}
		for i = 1, 0 do
		Stack[11 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 81 then -- 5 [GETGLOBAL] 
 Temp[4] = 11
Temp[11] = 21
Temp[12] = Constants[Temp[11]]
Stack[Temp[4]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 82 then -- 0 [MOVE] 
 Temp[11] = 12
Temp[4] = 9
Stack[Temp[11]] = Stack[Temp[4]] 
elseif pointer == 83 then -- 1 [LOADK] 
 Temp[14] = 13
Temp[1] = Constants
Temp[12] = 23
Stack[Temp[14]] = Temp[1][Temp[12]] 
elseif pointer == 84 then -- 1 [LOADK] 
 Temp[13] = 14
Temp[4] = Constants
Temp[7] = 5
Stack[Temp[13]] = Temp[4][Temp[7]]
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
elseif pointer == 86 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 11 + 1, top do
		Temp[1][i - 11] = Stack[i]
	end
	Temp[2] = {Stack[11](unpack(Temp[1], 1, top - 11))}
		for i = 1, 0 do
		Stack[11 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 87 then -- 0 [MOVE] 
 Temp[10] = 11
Temp[2] = 10
Stack[Temp[10]] = Stack[Temp[2]] 
elseif pointer == 88 then -- 28 [CALL] 
 	Stack[11]() 
elseif pointer == 89 then -- 30 [RETURN] 
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