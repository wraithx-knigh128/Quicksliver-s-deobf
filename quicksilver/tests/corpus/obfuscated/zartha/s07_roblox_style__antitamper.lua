return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\084\108\095", "1018")),(decrypt("\026\061", "2686")),(decrypt("\117\107\093\109\087\088", "2341")),(decrypt("\111\109\081\105", "1555")),(decrypt("\008\111\106\090\106\106\089\111\091", "2023")),(decrypt("\011\094\085\080\109\098\091", "1805")),(decrypt("\123\085\110\096\080\115\091\107\068\100\090", "834")),(decrypt("\010\093\104\108\084\081\110\104", "2823")),(decrypt("\085\094\085\092\089", "2759")),(decrypt("\123\111\084\081\082\105\107\089\110\104\121\089\084\090\107\108\110", "2332")),(decrypt("\110\100\086\090\087", "1859")),(decrypt("\008\109\092\124\109\094\091\081\109\106", "617")),(decrypt("\120\090\085\123\109\095\093\081\107\106", "1601")),(decrypt("\085\111\096\084\081", "2587")),(decrypt("\025\030\060", "2979")),(decrypt("\097\113\015\010\123\124\013\015\125\011\012", "776")),(decrypt("\030\028\051", "778")),(decrypt("\111\099\082\095\095\082\080\085\092\103", "959")),(decrypt("\030\031\059", "2803")),(decrypt("\006\100\094", "981")),(decrypt("\008\108\111\094\091\110\107\104\092", "707")),(decrypt("\109\081\093\081\088", "1847")),(decrypt("\122\096\083\086\109\081\032\106\109\083\107\107\090\100\108", "1871")),(decrypt("\118\109\082\090\127\086\100\105\106", "851")),(decrypt("\113\105\087\094\094\111", "853")),(decrypt("\114\092\095\082\106\092\111\101", "2959")),(decrypt("\112\093\092\082\081\084\102", "1185")),(decrypt("\116\095\082\082\116\080\091\111\095", "536")),(decrypt("\125\109\095\091\105\095", "956")),(decrypt("\121\092\083\104\083\122\083\081\092\108\090", "1032")),(decrypt("\086\097\088\108\109", "2936")),(decrypt("\090\094\082\089\085\097\107\092", "1875")),(decrypt("\097\103\088\082\106\100\088", "718")),(decrypt("\089\091\091\106\053", "2276")),(decrypt("\090\084\080\086\088\094\108\104\101", "429")),(decrypt("\081\110\109\110\081", "2642")),(decrypt("\107\086\093\108\081\110\084\088\109\107", "1081")),(decrypt("\103\103\082\111\090\105\093\107\104\082\106", "1163")),(decrypt("\114\081\081\089\089\014\105\109\087\106\106\110", "2465")),(decrypt("\127\107\080\083", "839")),(decrypt("\019\050", "495")),(decrypt("\103\101\082\095\109\090", "1324")),(decrypt("\127\107\085\093\012\085\092\012\110\083\086\109", "1356")),(decrypt("\091\094\101\106\106", "1996")),(decrypt("\018\024\059", "910")),(decrypt("\118\080\107\069\109\090\089", "1335")),(decrypt("\088\106\092\087\110\093\111\088\106\111\084\111", "2673")),(decrypt("\116\109\092\100", "1588")),(decrypt("\046\106\027", "2195")),(decrypt("\083\088\083\082", "2475")),(decrypt("\015\084\094\108\120\104\094\093\110\093", "2470")),(decrypt("\010\098\106\110\085\083", "2802")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
 Temp[7] = 0
Temp[11] = byte == pairs
Stack[Temp[7]] = Temp[4] 
elseif pointer == 2 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\098\014\122\012\126\012", "443")),(decrypt("\010\106\104\095\106\106\105", "1629")),(decrypt("\119\092\008\084\081\101\087\092\013\084\110\082\090", "1927")),}

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
 Temp[10] = 0
Temp[2] = ttostring ~= __metatable
Stack[Temp[10]] = Temp[8] 
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
 Temp[7] = 2
Temp[10] = 47
Temp[14] = Constants[Temp[10]]
Stack[Temp[7]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 5 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 6 then -- 10 [NEWTABLE] 
 	Stack[4] = {} 
elseif pointer == 7 then -- 9 [SETTABLE] 
 	Stack[4][Constants[18]] = Stack[1] 
elseif pointer == 8 then -- 9 [SETTABLE] 
 	Stack[4][Constants[42]] = Stack[1] 
elseif pointer == 9 then -- 9 [SETTABLE] 
 	Stack[4][Constants[33]] = Stack[1] 
elseif pointer == 10 then -- 9 [SETTABLE] 
 	Stack[4][Constants[38]] = Constants[2] 
elseif pointer == 11 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3], Stack[4]) 
elseif pointer == 12 then -- 5 [GETGLOBAL] 
 Temp[12] = 3
Temp[15] = 14
Temp[13] = Constants[Temp[15]]
Stack[Temp[12]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 13 then -- 5 [GETGLOBAL] 
 Temp[6] = 4
Temp[2] = 14
Temp[9] = Constants[Temp[2]]
Stack[Temp[6]] = vmEnv[Temp[9]] or Env[Temp[9]] 
elseif pointer == 14 then -- 0 [MOVE] 
 Temp[7] = 5
Temp[16] = 2
Stack[Temp[7]] = Stack[Temp[16]] 
elseif pointer == 15 then -- 0 [MOVE] 
 Temp[15] = 6
Temp[13] = 2
Stack[Temp[15]] = Stack[Temp[13]] 
elseif pointer == 16 then -- 28 [CALL] 
 	Stack[3](Stack[4], Stack[5], Stack[6]) 
elseif pointer == 17 then -- 5 [GETGLOBAL] 
 Temp[13] = 3
Temp[3] = 14
Temp[16] = Constants[Temp[3]]
Stack[Temp[13]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 18 then -- 5 [GETGLOBAL] 
 Temp[4] = 4
Temp[10] = 32
Temp[8] = Constants[Temp[10]]
Stack[Temp[4]] = vmEnv[Temp[8]] or Env[Temp[8]] 
elseif pointer == 19 then -- 0 [MOVE] 
 Temp[1] = 5
Temp[8] = 2
Stack[Temp[1]] = Stack[Temp[8]] 
elseif pointer == 20 then -- 28 [CALL] 
 	Stack[3](Stack[4], Stack[5]) 
elseif pointer == 21 then -- 5 [GETGLOBAL] 
 Temp[1] = 3
Temp[12] = 14
Temp[5] = Constants[Temp[12]]
Stack[Temp[1]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 22 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {((decrypt("\021\018\028\030\024", "2764"))),(decrypt("\106\107\018", "2384")),(decrypt("\121\092\105\105\110", "2513")),((decrypt("\024\017\029", "367"))),(decrypt("\014\107\107\086\090\104", "1735")),}

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
Temp[15] = 2
Temp[10] = Constants[Temp[15]]
Stack[Temp[3]] = vmEnv[Temp[10]] or Env[Temp[10]] 
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
Temp[11] = 32
Temp[12] = Constants[Temp[11]]
Stack[Temp[14]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 27 then -- 11 [SELF] 
 	Stack[7] = Stack[4]
	if Stack[7] then
		Stack[6] = Stack[4][Constants[31]]
	end
	 
elseif pointer == 28 then -- 1 [LOADK] 
 Temp[5] = 8
Temp[14] = Constants
Temp[7] = 49
Stack[Temp[5]] = Temp[14][Temp[7]]
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
 	if Constants[15] < Stack[5] then pointer = pointer + 1 end 
elseif pointer == 32 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 33 then -- 0 [MOVE] 
 Temp[11] = 5
Temp[7] = 1
Stack[Temp[11]] = Stack[Temp[7]] 
elseif pointer == 34 then -- 28 [CALL] 
 	Stack[5]() 
elseif pointer == 35 then -- 5 [GETGLOBAL] 
 Temp[4] = 5
Temp[6] = 22
Temp[5] = Constants[Temp[6]]
Stack[Temp[4]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 36 then -- 1 [LOADK] 
 Temp[1] = 6
Temp[12] = Constants
Temp[7] = 23
Stack[Temp[1]] = Temp[12][Temp[7]] 
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
 Temp[10] = 5
Temp[3] = ttostring ~= __metatable
Stack[Temp[10]] = Temp[7] 
elseif pointer == 40 then -- 7 [SETGLOBAL] 
 Temp[8] = vmEnv
Temp[15] = 16
Temp[3] = Constants[Temp[15]]
Temp[11] = 5
Temp[8][Temp[3]] = Temp[3] 
elseif pointer == 41 then -- 5 [GETGLOBAL] 
 Temp[14] = 5
Temp[7] = 4
Temp[4] = Constants[Temp[7]]
Stack[Temp[14]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 42 then -- 11 [SELF] 
 	Stack[6] = Stack[5]
	if Stack[6] then
		Stack[5] = Stack[5][Constants[12]]
	end
	 
elseif pointer == 43 then -- 1 [LOADK] 
 Temp[8] = 7
Temp[15] = Constants
Temp[5] = 46
Stack[Temp[8]] = Temp[15][Temp[5]]
	Stack[5] = Stack[5](Stack[6], Stack[7])
	pointer = pointer + 1 
elseif pointer == 45 then -- 5 [GETGLOBAL] 
 Temp[16] = 6
Temp[15] = 4
Temp[4] = Constants[Temp[15]]
Stack[Temp[16]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 46 then -- 11 [SELF] 
 	Stack[7] = Stack[6]
	if Stack[7] then
		Stack[6] = Stack[6][Constants[12]]
	end
	 
elseif pointer == 47 then -- 1 [LOADK] 
 Temp[12] = 8
Temp[11] = Constants
Temp[16] = 13
Stack[Temp[12]] = Temp[11][Temp[16]]
	Stack[6] = Stack[6](Stack[7], Stack[8])
	pointer = pointer + 1 
elseif pointer == 49 then -- 5 [GETGLOBAL] 
 Temp[16] = 7
Temp[9] = 4
Temp[6] = Constants[Temp[9]]
Stack[Temp[16]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 50 then -- 11 [SELF] 
 	Stack[8] = Stack[7]
	if Stack[8] then
		Stack[7] = Stack[7][Constants[12]]
	end
	 
elseif pointer == 51 then -- 1 [LOADK] 
 Temp[10] = 9
Temp[15] = Constants
Temp[16] = 10
Stack[Temp[10]] = Temp[15][Temp[16]]
	Stack[7] = Stack[7](Stack[8], Stack[9])
	pointer = pointer + 1 
elseif pointer == 53 then -- 6 [GETTABLE] 
 	Stack[8] = Stack[5][Constants[7]]
	 
elseif pointer == 54 then -- 10 [NEWTABLE] 
 	Stack[9] = {} 
elseif pointer == 55 then -- 9 [SETTABLE] 
 	Stack[9][Constants[44]] = Constants[17] 
elseif pointer == 56 then -- 9 [SETTABLE] 
 	Stack[9][Constants[50]] = Constants[19] 
elseif pointer == 57 then -- 9 [SETTABLE] 
 	Stack[9][Constants[36]] = Constants[30] 
elseif pointer == 58 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\013\085\083\104\087\095\087\107", "2970")),(decrypt("\015\097\082\081\110\098\037\089\084\046\082\087\082\082\082\106\081\089\067\110", "2922")),((decrypt("\031\031\016\016\031\016\016", "787"))),(decrypt("\088\081\108\109\105", "2601")),(decrypt("\080\089\085\080", "1517")),(decrypt("\120\097\085\093\004\083\095\003\106\086\090\110", "695")),(decrypt("\120\100\104\095\087\099\088", "2829")),(decrypt("\112\084\084\086\127\086\095\100\089", "180")),(decrypt("\120\107\086\084\121\082\106\111\110", "635")),}

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
	
	Stack[10] = function(...) -- PROTOTYPE 3
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 9}}
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
		if pointer == 1 then -- 11 [SELF] 
 	Stack[2] = Stack[0]
	if Stack[2] then
		Stack[1] = Stack[0][Constants[6]]
	end
	 
elseif pointer == 2 then -- 1 [LOADK] 
 Temp[10] = 3
Temp[4] = Constants
Temp[2] = 1
Stack[Temp[10]] = Temp[4][Temp[2]]
	Stack[1] = Stack[1](Stack[2], Stack[3])
	pointer = pointer + 1 
elseif pointer == 4 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 5 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[2][Constants[4]]
	 
elseif pointer == 6 then -- 9 [SETTABLE] 
 	Stack[1][Constants[9]] = Stack[2] 
elseif pointer == 7 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 8 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[2][Constants[5]]
	 
elseif pointer == 9 then -- 9 [SETTABLE] 
 	Stack[1][Constants[8]] = Stack[2] 
elseif pointer == 10 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 11 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 60 then -- 5 [GETGLOBAL] 
 Temp[4] = 11
Temp[11] = 26
Temp[12] = Constants[Temp[11]]
Stack[Temp[4]] = vmEnv[Temp[12]] or Env[Temp[12]]
	Stack[11] = Stack[11][Constants[1]]
	
	pointer = pointer + 1 
elseif pointer == 62 then -- 1 [LOADK] 
 Temp[11] = 12
Temp[4] = Constants
Temp[14] = 40
Stack[Temp[11]] = Temp[4][Temp[14]]
	Stack[11] = Stack[11](Stack[12])
	pointer = pointer + 1 
elseif pointer == 64 then -- 6 [GETTABLE] 
 	Stack[12] = Stack[9][Constants[36]]
	 
elseif pointer == 65 then -- 1 [LOADK] 
 Temp[1] = 13
Temp[12] = Constants
Temp[13] = 29
Stack[Temp[1]] = Temp[12][Temp[13]] 
elseif pointer == 66 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 12, 13 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[12] = Temp[1]
	 
elseif pointer == 67 then -- 9 [SETTABLE] 
 	Stack[11][Constants[48]] = Stack[12] 
elseif pointer == 68 then -- 9 [SETTABLE] 
 	Stack[11][Constants[8]] = Constants[34] 
elseif pointer == 69 then -- 5 [GETGLOBAL] 
 Temp[4] = 12
Temp[7] = 35
Temp[10] = Constants[Temp[7]]
Stack[Temp[4]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 70 then -- 9 [SETTABLE] 
 	Stack[11][Constants[3]] = Stack[12] 
elseif pointer == 71 then -- 0 [MOVE] 
 Temp[10] = 12
Temp[2] = 10
Stack[Temp[10]] = Stack[Temp[2]] 
elseif pointer == 72 then -- 6 [GETTABLE] 
 	Stack[13] = Stack[8][Constants[5]]
	 
elseif pointer == 73 then -- 28 [CALL] 
 	Stack[12] = Stack[12](Stack[13]) 
elseif pointer == 74 then -- 5 [GETGLOBAL] 
 Temp[8] = 13
Temp[14] = 9
Temp[1] = Constants[Temp[14]]
Stack[Temp[8]] = vmEnv[Temp[1]] or Env[Temp[1]] 
elseif pointer == 75 then -- 1 [LOADK] 
 Temp[6] = 14
Temp[14] = Constants
Temp[5] = 37
Stack[Temp[6]] = Temp[14][Temp[5]] 
elseif pointer == 76 then -- 6 [GETTABLE] 
 	Stack[15] = Stack[12][Constants[24]]
	 
elseif pointer == 77 then -- 6 [GETTABLE] 
 	Stack[16] = Stack[12][Constants[28]]
	 
elseif pointer == 78 then -- 6 [GETTABLE] 
 	Stack[17] = Stack[11][Constants[48]]
	 
elseif pointer == 79 then -- 28 [CALL] 
 	Stack[13](Stack[14], Stack[15], Stack[16], Stack[17]) 
elseif pointer == 80 then -- 1 [LOADK] 
 Temp[2] = 13
Temp[9] = Constants
Temp[4] = 41
Stack[Temp[2]] = Temp[9][Temp[4]] 
elseif pointer == 81 then -- 3 [LOADNIL] 
 	Stack[14], Stack[15], Stack[16], Stack[17], Stack[18], Stack[19], Stack[20], Stack[21], Stack[22], Stack[23], Stack[24], Stack[25], Stack[26], Stack[27], Stack[28] = nil 
elseif pointer == 82 then -- 6 [GETTABLE] 
 	Stack[15] = Stack[6][Constants[21]]
	 
elseif pointer == 83 then -- 11 [SELF] 
 	Stack[16] = Stack[15]
	if Stack[16] then
		Stack[15] = Stack[15][Constants[6]]
	end
	 
elseif pointer == 84 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\117\089\082\085\090\101\093", "1979")),(decrypt("\119\093\089\107\081\095\111\091", "782")),(decrypt("\027\061", "1666")),(decrypt("\027\059", "304")),(decrypt("\010\082\095\099\087\087\080\101\107\089", "1259")),(decrypt("\015\087\086\084\088\104\111\111", "2734")),(decrypt("\110\100\105\092\090\097\109\109\090\047\106\083\084\100", "1815")),(decrypt("\081\089\081\083\091", "601")),}

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
	
	Stack[17] = function(...) -- PROTOTYPE 4
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 13}, [1] = {0, 14}}
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
elseif pointer == 2 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Constants[4] 
elseif pointer == 3 then -- 8 [SETUPVAL] 
 	Upvalues[0] = Stack[1] 
elseif pointer == 4 then -- 4 [GETUPVAL] 
 	Stack[1] = Upvalues[0] 
elseif pointer == 5 then -- 25 [LE] 
 	if Constants[3] <= Stack[1] then pointer = pointer + 1 end 
elseif pointer == 6 then -- 22 [JMP] 
 pointer = pointer + 7  
elseif pointer == 7 then -- 4 [GETUPVAL] 
 	Stack[1] = Upvalues[1] 
elseif pointer == 8 then -- 11 [SELF] 
 	Stack[2] = Stack[1]
	if Stack[2] then
		Stack[1] = Stack[1][Constants[5]]
	end
	 
elseif pointer == 9 then -- 28 [CALL] 
 	Stack[1](Stack[2]) 
elseif pointer == 10 then -- 5 [GETGLOBAL] 
 Temp[15] = 1
Temp[10] = 8
Temp[7] = Constants[Temp[10]]
Stack[Temp[15]] = vmEnv[Temp[7]] or Env[Temp[7]] 
elseif pointer == 11 then -- 1 [LOADK] 
 Temp[13] = 2
Temp[1] = Constants
Temp[10] = 7
Stack[Temp[13]] = Temp[1][Temp[10]] 
elseif pointer == 12 then -- 4 [GETUPVAL] 
 	Stack[3] = Upvalues[0] 
elseif pointer == 13 then -- 28 [CALL] 
 	Stack[1](Stack[2], Stack[3]) 
elseif pointer == 14 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 87 then -- 28 [CALL] 
 	Stack[15] = Stack[15](Stack[16], Stack[17]) 
elseif pointer == 88 then -- 0 [MOVE] 
 Temp[1] = 14
Temp[9] = 15
Stack[Temp[1]] = Stack[Temp[9]] 
elseif pointer == 89 then -- 11 [SELF] 
 	Stack[16] = Stack[7]
	if Stack[16] then
		Stack[15] = Stack[7][Constants[43]]
	end
	 
elseif pointer == 90 then -- 1 [LOADK] 
 Temp[11] = 17
Temp[16] = Constants
Temp[3] = 25
Stack[Temp[11]] = Temp[16][Temp[3]]
	Stack[15] = Stack[15](Stack[16], Stack[17])
	pointer = pointer + 1 
elseif pointer == 92 then -- 11 [SELF] 
 	Stack[17] = Stack[15]
	if Stack[17] then
		Stack[16] = Stack[15][Constants[51]]
	end
	 
elseif pointer == 93 then -- 1 [LOADK] 
 Temp[11] = 18
Temp[3] = Constants
Temp[13] = 11
Stack[Temp[11]] = Temp[3][Temp[13]] 
elseif pointer == 94 then -- 1 [LOADK] 
 Temp[6] = 19
Temp[14] = Constants
Temp[1] = 45
Stack[Temp[6]] = Temp[14][Temp[1]]
	Stack[16](Stack[17], Stack[18], Stack[19])
	pointer = pointer + 1 
elseif pointer == 96 then -- 30 [RETURN] 
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