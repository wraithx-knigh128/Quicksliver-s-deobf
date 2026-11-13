return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\121\107\089\095", "2748")),(decrypt("\096\072\110\076\100\108\082\084\087", "990")),(decrypt("\123\093\081\097\109\119\081\080\094\109\088", "2006")),(decrypt("\102\087\104\091\114\110\065\117\111\104\100\107", "434")),(decrypt("\082\080\084\101\062", "998")),(decrypt("\071\093\083\075\089\069\102\095\093\068", "2499")),(decrypt("\121\013\120\114\103\121\007\119\100\115\126", "2686")),(decrypt("\088\081\089\106", "1555")),(decrypt("\026\017\059", "1805")),(decrypt("\110\103\080\080\110", "2823")),(decrypt("\084\080\067\066\093", "2332")),(decrypt("\012\071\094\087\092\111\097", "617")),(decrypt("\027\030\051", "2587")),(decrypt("\121\080\082\086\065\081\067\069", "776")),(decrypt("\115\094\097\099\087\046\095\088\101\080\104\090\095\091", "959")),(decrypt("\115\075\086\086", "981")),(decrypt("\008\076\104\088\126\102\066\083\064", "1847")),(decrypt("\113\065\086\074\070\105\085\091", "851")),(decrypt("\116\110\071\090\099\090\071\079\081\075", "2959")),(decrypt("\110\083\097\098\105", "536")),(decrypt("\117\104\109\110\084\091\107", "1032")),(decrypt("\116\078\084\071\086\089", "1875")),(decrypt("\112\101\087\071\082\080\068\082\067", "2276")),(decrypt("\114\087\105\105\082\122\084\105\065\097\090", "2642")),(decrypt("\082\080\107\086", "1163")),(decrypt("\125\092\085\081\114\089\075\064\077", "839")),(decrypt("\008\100\090\121\102\093\088\087\108\100", "1324")),(decrypt("\098\091\076\111\111\093\095\071\083\088\109\071\105\074\095\086\083", "1996")),(decrypt("\008\085\081\090\068\108\085\087\068", "1335")),(decrypt("\113\080\095\084\090\012\100\102\105\080", "1588")),(decrypt("\009\094\069\069\107\094", "2475")),(decrypt("\082\090\087\092\086", "2802")),(decrypt("\102\081\068", "1341")),(decrypt("\012\086\084\109", "2076")),(decrypt("\029\016\056", "1738")),(decrypt("\021\058", "2156")),(decrypt("\125\095\088\084\071\091\082", "2448")),(decrypt("\014\089\073\100\093\073", "389")),(decrypt("\006\109\069\008\095\100\109\066\089\093", "1360")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
Temp[15] = ttostring ~= __metatable
Stack[Temp[16]] = Temp[13] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[13] = vmEnv
Temp[3] = 7
Temp[16] = Constants[Temp[3]]
Temp[4] = 0
Temp[13][Temp[16]] = Temp[16] 
elseif pointer == 3 then -- 5 [GETGLOBAL] 
 Temp[10] = 0
Temp[1] = 25
Temp[8] = Constants[Temp[1]]
Stack[Temp[10]] = vmEnv[Temp[8]] or Env[Temp[8]] 
elseif pointer == 4 then -- 11 [SELF] 
 	Stack[1] = Stack[0]
	if Stack[1] then
		Stack[0] = Stack[0][Constants[27]]
	end
	 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[8] = 2
Temp[1] = Constants
Temp[12] = 12
Stack[Temp[8]] = Temp[1][Temp[12]]
	Stack[0] = Stack[0](Stack[1], Stack[2])
	pointer = pointer + 1 
elseif pointer == 7 then -- 5 [GETGLOBAL] 
 Temp[5] = 1
Temp[14] = 25
Temp[11] = Constants[Temp[14]]
Stack[Temp[5]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 8 then -- 11 [SELF] 
 	Stack[2] = Stack[1]
	if Stack[2] then
		Stack[1] = Stack[1][Constants[27]]
	end
	 
elseif pointer == 9 then -- 1 [LOADK] 
 Temp[12] = 3
Temp[5] = Constants
Temp[14] = 39
Stack[Temp[12]] = Temp[5][Temp[14]]
	Stack[1] = Stack[1](Stack[2], Stack[3])
	pointer = pointer + 1 
elseif pointer == 11 then -- 5 [GETGLOBAL] 
 Temp[7] = 2
Temp[11] = 25
Temp[4] = Constants[Temp[11]]
Stack[Temp[7]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 12 then -- 11 [SELF] 
 	Stack[3] = Stack[2]
	if Stack[3] then
		Stack[2] = Stack[2][Constants[27]]
	end
	 
elseif pointer == 13 then -- 1 [LOADK] 
 Temp[6] = 4
Temp[5] = Constants
Temp[1] = 28
Stack[Temp[6]] = Temp[5][Temp[1]]
	Stack[2] = Stack[2](Stack[3], Stack[4])
	pointer = pointer + 1 
elseif pointer == 15 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[0][Constants[24]]
	 
elseif pointer == 16 then -- 10 [NEWTABLE] 
 	Stack[4] = {} 
elseif pointer == 17 then -- 9 [SETTABLE] 
 	Stack[4][Constants[11]] = Constants[13] 
elseif pointer == 18 then -- 9 [SETTABLE] 
 	Stack[4][Constants[8]] = Constants[35] 
elseif pointer == 19 then -- 9 [SETTABLE] 
 	Stack[4][Constants[10]] = Constants[3] 
elseif pointer == 20 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\114\069\095\087\096\093\081\123\092\088\090\064", "146")),(decrypt("\111\069\111\074", "2579")),(decrypt("\067\072\080\081\092", "283")),(decrypt("\121\101\067\094\076\065\070\082", "697")),(decrypt("\125\105\087\081\123\091\111\109\111", "132")),((decrypt("\029", "1978"))),(decrypt("\123\109\095\081\118\081\084\093\094", "528")),(decrypt("\124\091\108\095\091\104\095\014\088\086", "604")),}

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
		Stack[1] = Stack[0][Constants[1]]
	end
	 
elseif pointer == 2 then -- 1 [LOADK] 
 Temp[13] = 3
Temp[6] = Constants
Temp[14] = 4
Stack[Temp[13]] = Temp[6][Temp[14]]
	Stack[1] = Stack[1](Stack[2], Stack[3])
	pointer = pointer + 1 
elseif pointer == 4 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 5 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[2][Constants[3]]
	 
elseif pointer == 6 then -- 9 [SETTABLE] 
 	Stack[1][Constants[5]] = Stack[2] 
elseif pointer == 7 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 8 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[2][Constants[2]]
	 
elseif pointer == 9 then -- 9 [SETTABLE] 
 	Stack[1][Constants[7]] = Stack[2] 
elseif pointer == 10 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 11 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 22 then -- 5 [GETGLOBAL] 
 Temp[12] = 6
Temp[7] = 14
Temp[10] = Constants[Temp[7]]
Stack[Temp[12]] = vmEnv[Temp[10]] or Env[Temp[10]]
	Stack[6] = Stack[6][Constants[33]]
	
	pointer = pointer + 1 
elseif pointer == 24 then -- 1 [LOADK] 
 Temp[3] = 7
Temp[7] = Constants
Temp[8] = 1
Stack[Temp[3]] = Temp[7][Temp[8]]
	Stack[6] = Stack[6](Stack[7])
	pointer = pointer + 1 
elseif pointer == 26 then -- 6 [GETTABLE] 
 	Stack[7] = Stack[4][Constants[10]]
	 
elseif pointer == 27 then -- 1 [LOADK] 
 Temp[15] = 8
Temp[3] = Constants
Temp[11] = 38
Stack[Temp[15]] = Temp[3][Temp[11]] 
elseif pointer == 28 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 7, 8 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[7] = Temp[1]
	 
elseif pointer == 29 then -- 9 [SETTABLE] 
 	Stack[6][Constants[16]] = Stack[7] 
elseif pointer == 30 then -- 9 [SETTABLE] 
 	Stack[6][Constants[18]] = Constants[5] 
elseif pointer == 31 then -- 5 [GETGLOBAL] 
 Temp[14] = 7
Temp[7] = 2
Temp[4] = Constants[Temp[7]]
Stack[Temp[14]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 32 then -- 9 [SETTABLE] 
 	Stack[6][Constants[22]] = Stack[7] 
elseif pointer == 33 then -- 0 [MOVE] 
 Temp[8] = 7
Temp[15] = 5
Stack[Temp[8]] = Stack[Temp[15]] 
elseif pointer == 34 then -- 6 [GETTABLE] 
 	Stack[8] = Stack[3][Constants[23]]
	 
elseif pointer == 35 then -- 28 [CALL] 
 	Stack[7] = Stack[7](Stack[8]) 
elseif pointer == 36 then -- 5 [GETGLOBAL] 
 Temp[5] = 8
Temp[16] = 32
Temp[15] = Constants[Temp[16]]
Stack[Temp[5]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 37 then -- 1 [LOADK] 
 Temp[16] = 9
Temp[4] = Constants
Temp[12] = 6
Stack[Temp[16]] = Temp[4][Temp[12]] 
elseif pointer == 38 then -- 6 [GETTABLE] 
 	Stack[10] = Stack[7][Constants[26]]
	 
elseif pointer == 39 then -- 6 [GETTABLE] 
 	Stack[11] = Stack[7][Constants[17]]
	 
elseif pointer == 40 then -- 6 [GETTABLE] 
 	Stack[12] = Stack[6][Constants[16]]
	 
elseif pointer == 41 then -- 28 [CALL] 
 	Stack[8](Stack[9], Stack[10], Stack[11], Stack[12]) 
elseif pointer == 42 then -- 1 [LOADK] 
 Temp[11] = 8
Temp[16] = Constants
Temp[9] = 36
Stack[Temp[11]] = Temp[16][Temp[9]] 
elseif pointer == 43 then -- 3 [LOADNIL] 
 	Stack[9], Stack[10], Stack[11], Stack[12], Stack[13], Stack[14], Stack[15], Stack[16], Stack[17], Stack[18] = nil 
elseif pointer == 44 then -- 6 [GETTABLE] 
 	Stack[10] = Stack[1][Constants[29]]
	 
elseif pointer == 45 then -- 11 [SELF] 
 	Stack[11] = Stack[10]
	if Stack[11] then
		Stack[10] = Stack[10][Constants[37]]
	end
	 
elseif pointer == 46 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\123\077\110\093\094\072\069\095\090\098", "1856")),(decrypt("\127\096\095\083\081\093\104", "1866")),(decrypt("\027\063", "1412")),(decrypt("\108\087\086\070\064\082\082\087\064\016\081\101\106\087", "2632")),(decrypt("\101\096\064\076\105", "2909")),((decrypt("\022\019\017\027", "1663"))),(decrypt("\025\050", "1955")),}

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
 	Stack[1] = Stack[1] + Constants[7] 
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
		Stack[1] = Stack[1][Constants[1]]
	end
	 
elseif pointer == 9 then -- 28 [CALL] 
 	Stack[1](Stack[2]) 
elseif pointer == 10 then -- 5 [GETGLOBAL] 
 Temp[3] = 1
Temp[15] = 5
Temp[13] = Constants[Temp[15]]
Stack[Temp[3]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 11 then -- 1 [LOADK] 
 Temp[14] = 2
Temp[2] = Constants
Temp[10] = 4
Stack[Temp[14]] = Temp[2][Temp[10]] 
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
 Temp[6] = 9
Temp[10] = 10
Stack[Temp[6]] = Stack[Temp[10]] 
elseif pointer == 51 then -- 11 [SELF] 
 	Stack[11] = Stack[2]
	if Stack[11] then
		Stack[10] = Stack[2][Constants[4]]
	end
	 
elseif pointer == 52 then -- 1 [LOADK] 
 Temp[15] = 12
Temp[10] = Constants
Temp[16] = 31
Stack[Temp[15]] = Temp[10][Temp[16]]
	Stack[10] = Stack[10](Stack[11], Stack[12])
	pointer = pointer + 1 
elseif pointer == 54 then -- 11 [SELF] 
 	Stack[12] = Stack[10]
	if Stack[12] then
		Stack[11] = Stack[10][Constants[19]]
	end
	 
elseif pointer == 55 then -- 1 [LOADK] 
 Temp[4] = 13
Temp[11] = Constants
Temp[12] = 20
Stack[Temp[4]] = Temp[11][Temp[12]] 
elseif pointer == 56 then -- 1 [LOADK] 
 Temp[11] = 14
Temp[4] = Constants
Temp[14] = 9
Stack[Temp[11]] = Temp[4][Temp[14]]
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