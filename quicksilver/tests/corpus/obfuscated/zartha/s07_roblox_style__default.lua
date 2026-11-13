return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\087\109\092", "2127")),(decrypt("\116\104\091\111\085\089", "302")),(decrypt("\081\111\109\100\081", "2748")),(decrypt("\008\086\081\080\110\106\095", "2045")),(decrypt("\001\092\106\102\095\089\101\098", "990")),(decrypt("\085\093\083\087\095", "243")),(decrypt("\027\027\059", "2006")),(decrypt("\110\109\091\084\087", "1187")),(decrypt("\024\020\063", "434")),(decrypt("\012\106\083\121\110\095\085\083\104\106", "2683")),(decrypt("\088\085\092\094", "998")),(decrypt("\088\095\104\107\105", "2847")),(decrypt("\122\088\089\099\080\126\089\090\095\104\080", "2499")),(decrypt("\113\085\091\083\105\085\107\100", "1018")),(decrypt("\009\106\091\110\066", "2686")),(decrypt("\124\107\087\083\120\084\104\109\105", "2341")),(decrypt("\117\109\092\087\109\092", "1555")),(decrypt("\123\108\086\085\089\108", "2023")),(decrypt("\112\084\084\082\118\094\094\105\088", "1805")),(decrypt("\120\086\083\084\088\013\100\109\108\093", "834")),(decrypt("\089\081\094\111\053", "2823")),(decrypt("\092\081\092\091\088\080\109\099\110", "2759")),(decrypt("\123\111\084\081\082\105\107\089\110\104\121\089\084\090\107\108\110", "2332")),(decrypt("\120\084\080\115\109\081\088\089\107\100", "1859")),(decrypt("\108\087\082\107\081\105\090\088\107\109", "617")),(decrypt("\111\110\084\109", "1601")),(decrypt("\100\115\001\010\126\127\002\015\121\009\003", "2587")),(decrypt("\021\050", "2979")),(decrypt("\009\081\085\108", "776")),(decrypt("\121\111\088\092\010\094\094\013\103\087\084\099", "778")),(decrypt("\003\106\097\080\109\099\082\105\080", "959")),(decrypt("\117\096\089\088", "2803")),(decrypt("\018\017\058", "981")),(decrypt("\116\086\109\111\083\112\084\104\071\107\089", "707")),(decrypt("\118\091\108\071\109\081\094", "1847")),(decrypt("\014\100\111\088\090\097\107\105\090", "1871")),(decrypt("\125\109\085\100", "851")),(decrypt("\005\085\090\100\127\111\081\088\111\081", "853")),(decrypt("\120\082\109\099\080\046\083\084\110\080\104\090\084\087", "2959")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
 Temp[6] = 0
Temp[3] = ttostring ~= __metatable
Stack[Temp[6]] = Temp[5] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[6] = vmEnv
Temp[16] = 27
Temp[10] = Constants[Temp[16]]
Temp[4] = 0
Temp[6][Temp[10]] = Temp[10] 
elseif pointer == 3 then -- 5 [GETGLOBAL] 
 Temp[13] = 0
Temp[2] = 26
Temp[15] = Constants[Temp[2]]
Stack[Temp[13]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 4 then -- 11 [SELF] 
 	Stack[1] = Stack[0]
	if Stack[1] then
		Stack[0] = Stack[0][Constants[10]]
	end
	 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[6] = 2
Temp[14] = Constants
Temp[5] = 35
Stack[Temp[6]] = Temp[14][Temp[5]]
	Stack[0] = Stack[0](Stack[1], Stack[2])
	pointer = pointer + 1 
elseif pointer == 7 then -- 5 [GETGLOBAL] 
 Temp[3] = 1
Temp[7] = 26
Temp[11] = Constants[Temp[7]]
Stack[Temp[3]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 8 then -- 11 [SELF] 
 	Stack[2] = Stack[1]
	if Stack[2] then
		Stack[1] = Stack[1][Constants[10]]
	end
	 
elseif pointer == 9 then -- 1 [LOADK] 
 Temp[5] = 3
Temp[7] = Constants
Temp[15] = 24
Stack[Temp[5]] = Temp[7][Temp[15]]
	Stack[1] = Stack[1](Stack[2], Stack[3])
	pointer = pointer + 1 
elseif pointer == 11 then -- 5 [GETGLOBAL] 
 Temp[9] = 2
Temp[12] = 26
Temp[14] = Constants[Temp[12]]
Stack[Temp[9]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 12 then -- 11 [SELF] 
 	Stack[3] = Stack[2]
	if Stack[3] then
		Stack[2] = Stack[2][Constants[10]]
	end
	 
elseif pointer == 13 then -- 1 [LOADK] 
 Temp[14] = 4
Temp[15] = Constants
Temp[7] = 23
Stack[Temp[14]] = Temp[15][Temp[7]]
	Stack[2] = Stack[2](Stack[3], Stack[4])
	pointer = pointer + 1 
elseif pointer == 15 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[0][Constants[34]]
	 
elseif pointer == 16 then -- 10 [NEWTABLE] 
 	Stack[4] = {} 
elseif pointer == 17 then -- 9 [SETTABLE] 
 	Stack[4][Constants[12]] = Constants[7] 
elseif pointer == 18 then -- 9 [SETTABLE] 
 	Stack[4][Constants[11]] = Constants[9] 
elseif pointer == 19 then -- 9 [SETTABLE] 
 	Stack[4][Constants[3]] = Constants[13] 
elseif pointer == 20 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {((decrypt("\026\017\024\028", "2617"))),(decrypt("\127\106\082\095\012\084\091\014\110\082\081\111", "1224")),(decrypt("\116\095\095", "791")),(decrypt("\011\087\107\088\091\113\107\086\109", "1432")),(decrypt("\083\090\081\084", "2653")),(decrypt("\082\085\105\100\105", "825")),(decrypt("\124\096\081\082\120\095\110\108\105", "2820")),(decrypt("\115\090\083\087\117\080\089\108\091", "2670")),(decrypt("\013\085\081\109\087\095\085\110", "2955")),(decrypt("\012\004\113\011\115\014", "782")),}

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
	
	Stack[5] = function(...) -- PROTOTYPE 1
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 4}}
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
		Stack[1] = Stack[0][Constants[2]]
	end
	 
elseif pointer == 2 then -- 1 [LOADK] 
 Temp[12] = 3
Temp[11] = Constants
Temp[16] = 9
Stack[Temp[12]] = Temp[11][Temp[16]]
	Stack[1] = Stack[1](Stack[2], Stack[3])
	pointer = pointer + 1 
elseif pointer == 4 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 5 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[2][Constants[6]]
	 
elseif pointer == 6 then -- 9 [SETTABLE] 
 	Stack[1][Constants[7]] = Stack[2] 
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
 
elseif pointer == 22 then -- 5 [GETGLOBAL] 
 Temp[7] = 6
Temp[4] = 14
Temp[11] = Constants[Temp[4]]
Stack[Temp[7]] = vmEnv[Temp[11]] or Env[Temp[11]]
	Stack[6] = Stack[6][Constants[1]]
	
	pointer = pointer + 1 
elseif pointer == 24 then -- 1 [LOADK] 
 Temp[7] = 7
Temp[10] = Constants
Temp[14] = 32
Stack[Temp[7]] = Temp[10][Temp[14]]
	Stack[6] = Stack[6](Stack[7])
	pointer = pointer + 1 
elseif pointer == 26 then -- 6 [GETTABLE] 
 	Stack[7] = Stack[4][Constants[3]]
	 
elseif pointer == 27 then -- 1 [LOADK] 
 Temp[12] = 8
Temp[15] = Constants
Temp[13] = 17
Stack[Temp[12]] = Temp[15][Temp[13]] 
elseif pointer == 28 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 7, 8 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[7] = Temp[1]
	 
elseif pointer == 29 then -- 9 [SETTABLE] 
 	Stack[6][Constants[37]] = Stack[7] 
elseif pointer == 30 then -- 9 [SETTABLE] 
 	Stack[6][Constants[5]] = Constants[21] 
elseif pointer == 31 then -- 5 [GETGLOBAL] 
 Temp[6] = 7
Temp[2] = 22
Temp[9] = Constants[Temp[2]]
Stack[Temp[6]] = vmEnv[Temp[9]] or Env[Temp[9]] 
elseif pointer == 32 then -- 9 [SETTABLE] 
 	Stack[6][Constants[2]] = Stack[7] 
elseif pointer == 33 then -- 0 [MOVE] 
 Temp[7] = 7
Temp[16] = 5
Stack[Temp[7]] = Stack[Temp[16]] 
elseif pointer == 34 then -- 6 [GETTABLE] 
 	Stack[8] = Stack[3][Constants[31]]
	 
elseif pointer == 35 then -- 28 [CALL] 
 	Stack[7] = Stack[7](Stack[8]) 
elseif pointer == 36 then -- 5 [GETGLOBAL] 
 Temp[15] = 8
Temp[13] = 6
Temp[3] = Constants[Temp[13]]
Stack[Temp[15]] = vmEnv[Temp[3]] or Env[Temp[3]] 
elseif pointer == 37 then -- 1 [LOADK] 
 Temp[16] = 9
Temp[4] = Constants
Temp[10] = 25
Stack[Temp[16]] = Temp[4][Temp[10]] 
elseif pointer == 38 then -- 6 [GETTABLE] 
 	Stack[10] = Stack[7][Constants[16]]
	 
elseif pointer == 39 then -- 6 [GETTABLE] 
 	Stack[11] = Stack[7][Constants[19]]
	 
elseif pointer == 40 then -- 6 [GETTABLE] 
 	Stack[12] = Stack[6][Constants[37]]
	 
elseif pointer == 41 then -- 28 [CALL] 
 	Stack[8](Stack[9], Stack[10], Stack[11], Stack[12]) 
elseif pointer == 42 then -- 1 [LOADK] 
 Temp[10] = 8
Temp[8] = Constants
Temp[1] = 28
Stack[Temp[10]] = Temp[8][Temp[1]] 
elseif pointer == 43 then -- 3 [LOADNIL] 
 	Stack[9], Stack[10], Stack[11], Stack[12], Stack[13], Stack[14], Stack[15], Stack[16], Stack[17], Stack[18] = nil 
elseif pointer == 44 then -- 6 [GETTABLE] 
 	Stack[10] = Stack[1][Constants[36]]
	 
elseif pointer == 45 then -- 11 [SELF] 
 	Stack[11] = Stack[10]
	if Stack[11] then
		Stack[10] = Stack[10][Constants[4]]
	end
	 
elseif pointer == 46 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\025\057", "1208")),(decrypt("\110\100\097\093\090\097\101\108\090\047\098\082\084\100", "1894")),(decrypt("\086\081\080\080\090", "1805")),(decrypt("\013\096\083\082", "1899")),(decrypt("\122\094\083\086\082\083\109", "326")),(decrypt("\009\088\094\081\120\082\094\111\090\104", "1457")),(decrypt("\024\061", "2624")),(decrypt("\015\104\093\118\093\086\085\108\095\065\115\110\088\095\012\012\093\110\085\104", "146")),(decrypt("\012\081\110\084\106\119\111\122\081\109\092", "1127")),(decrypt("\009\085\093\099\084\080\082\101\104\094", "2579")),(decrypt("\005\084\080\086\106\080\099", "829")),}

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
	
	Stack[12] = function(...) -- PROTOTYPE 2
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 8}, [1] = {0, 9}}
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
 	Stack[1] = Stack[1] + Constants[1] 
elseif pointer == 3 then -- 8 [SETUPVAL] 
 	Upvalues[0] = Stack[1] 
elseif pointer == 4 then -- 4 [GETUPVAL] 
 	Stack[1] = Upvalues[0] 
elseif pointer == 5 then -- 25 [LE] 
 	if Constants[7] <= Stack[1] then pointer = pointer + 1 end 
elseif pointer == 6 then -- 22 [JMP] 
 pointer = pointer + 7  
elseif pointer == 7 then -- 4 [GETUPVAL] 
 	Stack[1] = Upvalues[1] 
elseif pointer == 8 then -- 11 [SELF] 
 	Stack[2] = Stack[1]
	if Stack[2] then
		Stack[1] = Stack[1][Constants[10]]
	end
	 
elseif pointer == 9 then -- 28 [CALL] 
 	Stack[1](Stack[2]) 
elseif pointer == 10 then -- 5 [GETGLOBAL] 
 Temp[2] = 1
Temp[9] = 3
Temp[4] = Constants[Temp[9]]
Stack[Temp[2]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 11 then -- 1 [LOADK] 
 Temp[1] = 2
Temp[9] = Constants
Temp[11] = 2
Stack[Temp[1]] = Temp[9][Temp[11]] 
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
 
elseif pointer == 49 then -- 28 [CALL] 
 	Stack[10] = Stack[10](Stack[11], Stack[12]) 
elseif pointer == 50 then -- 0 [MOVE] 
 Temp[8] = 9
Temp[1] = 10
Stack[Temp[8]] = Stack[Temp[1]] 
elseif pointer == 51 then -- 11 [SELF] 
 	Stack[11] = Stack[2]
	if Stack[11] then
		Stack[10] = Stack[2][Constants[30]]
	end
	 
elseif pointer == 52 then -- 1 [LOADK] 
 Temp[12] = 12
Temp[5] = Constants
Temp[14] = 18
Stack[Temp[12]] = Temp[5][Temp[14]]
	Stack[10] = Stack[10](Stack[11], Stack[12])
	pointer = pointer + 1 
elseif pointer == 54 then -- 11 [SELF] 
 	Stack[12] = Stack[10]
	if Stack[12] then
		Stack[11] = Stack[10][Constants[38]]
	end
	 
elseif pointer == 55 then -- 1 [LOADK] 
 Temp[11] = 13
Temp[12] = Constants
Temp[5] = 8
Stack[Temp[11]] = Temp[12][Temp[5]] 
elseif pointer == 56 then -- 1 [LOADK] 
 Temp[14] = 14
Temp[7] = Constants
Temp[11] = 33
Stack[Temp[14]] = Temp[7][Temp[11]]
	Stack[11](Stack[12], Stack[13], Stack[14])
	pointer = pointer + 1 
elseif pointer == 58 then -- 30 [RETURN] 
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