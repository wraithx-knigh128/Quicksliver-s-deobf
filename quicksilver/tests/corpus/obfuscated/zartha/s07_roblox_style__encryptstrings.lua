return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env[decrypt("\066\067\070\090\095\080", "1743")][decrypt("\082\093\087\065", "1563")],Env[decrypt("\066\065\075\089\095\082", "1590")][decrypt("\080\074\069\093", "2318")],Env[decrypt("\066\070\065\095\095\085", "1236")][decrypt("\065\077\082", "2806")],Env[decrypt("\067\088\065\067\069\091\089\080", "772")],Env[decrypt("\065\084\088\093\093", "1791")],Env[decrypt("\069\086\082\094\084", "1702")][decrypt("\071\087\064\084\081\082", "2905")] or Env[decrypt("\065\088\068\085\085\095", "464")],Env[decrypt("\069\084\080\092\084", "1520")][decrypt("\081\086\091\081\083\077", "2952")],Env[decrypt("\070\094\095\068\095\083\084\067", "2111")],Env[decrypt("\066\093\066\091\084\076\087\066\080\090\090\083", "1866")],decrypt("\109\102\092\093\070\088\069\089\080\085\084", "2918"),decrypt("\104\103\094\089\092\082\079", "787"),Env[decrypt("\090\092\065\068\075\089\076\064", "496")],Env[decrypt("\066\075\095\092\070", "2962")],{(decrypt("\123\084\085\121\110\081\093\083\104\100", "2803")),(decrypt("\030\051", "981")),(decrypt("\112\104\094\107\085\092", "707")),(decrypt("\120\100\083\084\081\098\108\092\109\099\126\092\087\081\108\105\109", "1847")),(decrypt("\103\126\014\012\125\114\013\009\122\004\012", "1871")),(decrypt("\000\080\107\103\083\088\100\110", "851")),(decrypt("\112\089\083\098\087\121\088\086\094\100\092", "853")),(decrypt("\104\095\080\100\082\103\089\080\110\098", "2959")),(decrypt("\110\109\091\086\087", "1185")),(decrypt("\120\083\106\091\084\080\092\088\124\085\066\106", "536")),(decrypt("\121\080\092\082\109\083\099\105", "956")),(decrypt("\127\104\083\089\012\086\090\008\110\080\080\105", "1032")),(decrypt("\030\030\056", "2936")),(decrypt("\084\100\089", "1875")),(decrypt("\114\105\092\107", "718")),(decrypt("\008\109\111\095\106\104\092\106\091", "2276")),(decrypt("\010\110\082\126\110\080\089\082\099\104", "429")),(decrypt("\124\110\087\080\120\081\104\110\105", "2642")),(decrypt("\118\104\081\090", "1081")),(decrypt("\011\082\086\087\104\081\083\109", "1163")),(decrypt("\013\104\110\092\089\109\106\109\089", "2465")),(decrypt("\017\024\050", "839")),(decrypt("\125\101\081\082\082\105", "495")),(decrypt("\111\107\086\104", "1324")),(decrypt("\124\083\105\088\086\085\092\093\123\083\068\106", "1356")),(decrypt("\090\080\085\106\054", "1996")),(decrypt("\018\024\059", "910")),(decrypt("\086\090\083\080\090", "1335")),(decrypt("\083\090\083\084", "2673")),(decrypt("\118\086\096\072\109\092\082", "1588")),(decrypt("\088\086\101\105\105", "2195")),(decrypt("\113\082\109\109\081\115\084\109\066\104\094", "2475")),(decrypt("\081\108\110\108\081", "2470")),(decrypt("\092\094\089\080\088\095\104\104\110", "2802")),(decrypt("\012\083\091\110\123\111\091\095\109\090", "1322")),(decrypt("\011\085\081\084\109\105\095", "1341")),(decrypt("\119\089\086\081\114\084\088\105\091", "652")),(decrypt("\118\104\094\084\110\089", "2076")),},Env[decrypt("\066\088\095\064\074", "296")],decrypt("\109\102\094\087\078\089\092\093\085\074", "290"),Env[decrypt("\089\082\079\067", "777")],decrypt("\028", "2812"),Env[decrypt("\065\065\067\090\092\082", "2513")][decrypt("\085\075\068\084", "2816")],decrypt("\066\070\066\088\092\087", "120"),Env[decrypt("\065\076\065\080\092\095", "2839")][decrypt("\084\081\090\087", "2843")],Env[decrypt("\066\082\084\090\086", "636")][decrypt("\084\090\093\083", "2337")] or function(targetTable, value)
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
 Temp[7] = 0
Temp[10] = ttostring ~= __metatable
Stack[Temp[7]] = Temp[14] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[12] = vmEnv
Temp[15] = 5
Temp[13] = Constants[Temp[15]]
Temp[6] = 0
Temp[12][Temp[13]] = Temp[13] 
elseif pointer == 3 then -- 5 [GETGLOBAL] 
 Temp[2] = 0
Temp[9] = 24
Temp[7] = Constants[Temp[9]]
Stack[Temp[2]] = vmEnv[Temp[7]] or Env[Temp[7]] 
elseif pointer == 4 then -- 11 [SELF] 
 	Stack[1] = Stack[0]
	if Stack[1] then
		Stack[0] = Stack[0][Constants[17]]
	end
	 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[16] = 2
Temp[15] = Constants
Temp[13] = 30
Stack[Temp[16]] = Temp[15][Temp[13]]
	Stack[0] = Stack[0](Stack[1], Stack[2])
	pointer = pointer + 1 
elseif pointer == 7 then -- 5 [GETGLOBAL] 
 Temp[13] = 1
Temp[3] = 24
Temp[16] = Constants[Temp[3]]
Stack[Temp[13]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 8 then -- 11 [SELF] 
 	Stack[2] = Stack[1]
	if Stack[2] then
		Stack[1] = Stack[1][Constants[17]]
	end
	 
elseif pointer == 9 then -- 1 [LOADK] 
 Temp[4] = 3
Temp[10] = Constants
Temp[8] = 1
Stack[Temp[4]] = Temp[10][Temp[8]]
	Stack[1] = Stack[1](Stack[2], Stack[3])
	pointer = pointer + 1 
elseif pointer == 11 then -- 5 [GETGLOBAL] 
 Temp[1] = 2
Temp[8] = 24
Temp[12] = Constants[Temp[8]]
Stack[Temp[1]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 12 then -- 11 [SELF] 
 	Stack[3] = Stack[2]
	if Stack[3] then
		Stack[2] = Stack[2][Constants[17]]
	end
	 
elseif pointer == 13 then -- 1 [LOADK] 
 Temp[5] = 4
Temp[14] = Constants
Temp[11] = 4
Stack[Temp[5]] = Temp[14][Temp[11]]
	Stack[2] = Stack[2](Stack[3], Stack[4])
	pointer = pointer + 1 
elseif pointer == 15 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[0][Constants[32]]
	 
elseif pointer == 16 then -- 10 [NEWTABLE] 
 	Stack[4] = {} 
elseif pointer == 17 then -- 9 [SETTABLE] 
 	Stack[4][Constants[31]] = Constants[22] 
elseif pointer == 18 then -- 9 [SETTABLE] 
 	Stack[4][Constants[29]] = Constants[13] 
elseif pointer == 19 then -- 9 [SETTABLE] 
 	Stack[4][Constants[33]] = Constants[7] 
elseif pointer == 20 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\091\095\108\105\106", "1805")),(decrypt("\013\096\083\082", "1899")),(decrypt("\125\106\085\081\120\081\111\110\109", "326")),(decrypt("\112\088\081\080\118\082\091\107\088", "1457")),(decrypt("\015\080\091\090\106\095\105", "2624")),(decrypt("\009\110\108\109\094\092\038\111\106\084\084\106\106", "146")),(decrypt("\080\093\086\080", "1127")),(decrypt("\124\109\087\082\015\083\094\003\109\085\084\098", "2579")),(decrypt("\000\094\082\094\123\095\083\106\082\100", "829")),(decrypt("\013\084\087\106\093\085\082\099", "283")),(decrypt("\118\105\083\111\081\080\104", "1564")),}

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
		Stack[1] = Stack[0][Constants[8]]
	end
	 
elseif pointer == 2 then -- 1 [LOADK] 
 Temp[4] = 3
Temp[1] = Constants
Temp[9] = 10
Stack[Temp[4]] = Temp[1][Temp[9]]
	Stack[1] = Stack[1](Stack[2], Stack[3])
	pointer = pointer + 1 
elseif pointer == 4 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 5 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[2][Constants[1]]
	 
elseif pointer == 6 then -- 9 [SETTABLE] 
 	Stack[1][Constants[3]] = Stack[2] 
elseif pointer == 7 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 8 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[2][Constants[7]]
	 
elseif pointer == 9 then -- 9 [SETTABLE] 
 	Stack[1][Constants[4]] = Stack[2] 
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
Temp[5] = 11
Temp[14] = Constants[Temp[5]]
Stack[Temp[12]] = vmEnv[Temp[14]] or Env[Temp[14]]
	Stack[6] = Stack[6][Constants[14]]
	
	pointer = pointer + 1 
elseif pointer == 24 then -- 1 [LOADK] 
 Temp[7] = 7
Temp[11] = Constants
Temp[4] = 19
Stack[Temp[7]] = Temp[11][Temp[4]]
	Stack[6] = Stack[6](Stack[7])
	pointer = pointer + 1 
elseif pointer == 26 then -- 6 [GETTABLE] 
 	Stack[7] = Stack[4][Constants[33]]
	 
elseif pointer == 27 then -- 1 [LOADK] 
 Temp[6] = 8
Temp[5] = Constants
Temp[1] = 38
Stack[Temp[6]] = Temp[5][Temp[1]] 
elseif pointer == 28 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 7, 8 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[7] = Temp[1]
	 
elseif pointer == 29 then -- 9 [SETTABLE] 
 	Stack[6][Constants[15]] = Stack[7] 
elseif pointer == 30 then -- 9 [SETTABLE] 
 	Stack[6][Constants[6]] = Constants[26] 
elseif pointer == 31 then -- 5 [GETGLOBAL] 
 Temp[12] = 7
Temp[7] = 34
Temp[10] = Constants[Temp[7]]
Stack[Temp[12]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 32 then -- 9 [SETTABLE] 
 	Stack[6][Constants[3]] = Stack[7] 
elseif pointer == 33 then -- 0 [MOVE] 
 Temp[3] = 7
Temp[7] = 5
Stack[Temp[3]] = Stack[Temp[7]] 
elseif pointer == 34 then -- 6 [GETTABLE] 
 	Stack[8] = Stack[3][Constants[16]]
	 
elseif pointer == 35 then -- 28 [CALL] 
 	Stack[7] = Stack[7](Stack[8]) 
elseif pointer == 36 then -- 5 [GETGLOBAL] 
 Temp[8] = 8
Temp[15] = 28
Temp[3] = Constants[Temp[15]]
Stack[Temp[8]] = vmEnv[Temp[3]] or Env[Temp[3]] 
elseif pointer == 37 then -- 1 [LOADK] 
 Temp[11] = 9
Temp[14] = Constants
Temp[7] = 8
Stack[Temp[11]] = Temp[14][Temp[7]] 
elseif pointer == 38 then -- 6 [GETTABLE] 
 	Stack[10] = Stack[7][Constants[18]]
	 
elseif pointer == 39 then -- 6 [GETTABLE] 
 	Stack[11] = Stack[7][Constants[37]]
	 
elseif pointer == 40 then -- 6 [GETTABLE] 
 	Stack[12] = Stack[6][Constants[15]]
	 
elseif pointer == 41 then -- 28 [CALL] 
 	Stack[8](Stack[9], Stack[10], Stack[11], Stack[12]) 
elseif pointer == 42 then -- 1 [LOADK] 
 Temp[4] = 8
Temp[8] = Constants
Temp[15] = 2
Stack[Temp[4]] = Temp[8][Temp[15]] 
elseif pointer == 43 then -- 3 [LOADNIL] 
 	Stack[9], Stack[10], Stack[11], Stack[12], Stack[13], Stack[14], Stack[15], Stack[16], Stack[17], Stack[18] = nil 
elseif pointer == 44 then -- 6 [GETTABLE] 
 	Stack[10] = Stack[1][Constants[21]]
	 
elseif pointer == 45 then -- 11 [SELF] 
 	Stack[11] = Stack[10]
	if Stack[11] then
		Stack[10] = Stack[10][Constants[36]]
	end
	 
elseif pointer == 46 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\010\086\088\099\087\083\087\101\107\093", "1629")),(decrypt("\119\092\008\084\081\101\087\092\013\084\110\082\090", "1927")),(decrypt("\024\057", "2242")),(decrypt("\086\081\085\083\090", "1856")),(decrypt("\122\100\094\084\096\090\086\088\081\109", "384")),(decrypt("\010\100\108\080\106\100\109", "1866")),(decrypt("\110\101\104\091\090\096\108\106\090\046\107\084\084\101", "1902")),(decrypt("\025\063", "1412")),(decrypt("\120\104\108\093", "1444")),(decrypt("\008\080\086\089\110\089\088\010\104\093\083\084\087\124\111\091\095\086\105\110", "2632")),}

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
 	Stack[1] = Stack[1] + Constants[8] 
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
 Temp[9] = 1
Temp[16] = 4
Temp[2] = Constants[Temp[16]]
Stack[Temp[9]] = vmEnv[Temp[2]] or Env[Temp[2]] 
elseif pointer == 11 then -- 1 [LOADK] 
 Temp[9] = 2
Temp[16] = Constants
Temp[11] = 7
Stack[Temp[9]] = Temp[16][Temp[11]] 
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
 Temp[5] = 9
Temp[16] = 10
Stack[Temp[5]] = Stack[Temp[16]] 
elseif pointer == 51 then -- 11 [SELF] 
 	Stack[11] = Stack[2]
	if Stack[11] then
		Stack[10] = Stack[2][Constants[12]]
	end
	 
elseif pointer == 52 then -- 1 [LOADK] 
 Temp[15] = 12
Temp[16] = Constants
Temp[4] = 23
Stack[Temp[15]] = Temp[16][Temp[4]]
	Stack[10] = Stack[10](Stack[11], Stack[12])
	pointer = pointer + 1 
elseif pointer == 54 then -- 11 [SELF] 
 	Stack[12] = Stack[10]
	if Stack[12] then
		Stack[11] = Stack[10][Constants[35]]
	end
	 
elseif pointer == 55 then -- 1 [LOADK] 
 Temp[12] = 13
Temp[11] = Constants
Temp[16] = 9
Stack[Temp[12]] = Temp[11][Temp[16]] 
elseif pointer == 56 then -- 1 [LOADK] 
 Temp[16] = 14
Temp[9] = Constants
Temp[6] = 27
Stack[Temp[16]] = Temp[9][Temp[6]]
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