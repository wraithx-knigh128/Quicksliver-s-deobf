return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env[decrypt("\066\067\070\090\095\080", "1743")][decrypt("\082\093\087\065", "1563")],Env[decrypt("\066\065\075\089\095\082", "1590")][decrypt("\080\074\069\093", "2318")],Env[decrypt("\066\070\065\095\095\085", "1236")][decrypt("\065\077\082", "2806")],Env[decrypt("\067\088\065\067\069\091\089\080", "772")],Env[decrypt("\065\084\088\093\093", "1791")],Env[decrypt("\069\086\082\094\084", "1702")][decrypt("\071\087\064\084\081\082", "2905")] or Env[decrypt("\065\088\068\085\085\095", "464")],Env[decrypt("\069\084\080\092\084", "1520")][decrypt("\081\086\091\081\083\077", "2952")],Env[decrypt("\070\094\095\068\095\083\084\067", "2111")],Env[decrypt("\066\093\066\091\084\076\087\066\080\090\090\083", "1866")],decrypt("\109\102\092\093\070\088\069\089\080\085\084", "2918"),decrypt("\104\103\094\089\092\082\079", "787"),Env[decrypt("\090\092\065\068\075\089\076\064", "496")],Env[decrypt("\066\075\095\092\070", "2962")],{(decrypt("\025\031\051", "2686")),(decrypt("\027\029\063", "2341")),(decrypt("\017\034\001\034", "1555")),(decrypt("\037\080\088\036", "2023")),(decrypt("\009\098\106\105\086\083", "1805")),(decrypt("\008\027\063", "834")),(decrypt("\022\020\057", "2823")),(decrypt("\031\060", "2759")),(decrypt("\026\020\020\021\057", "2332")),(decrypt("\022\051", "1859")),(decrypt("\009\109\111\095\090\110\106\105\092", "617")),(decrypt("\031\061", "1601")),(decrypt("\085\092\088\082\089", "2587")),(decrypt("\115\085\083\094\082\092\105", "2979")),(decrypt("\109\081\085\084\111\093\070\040", "776")),(decrypt("\087\080\096\087\094\082", "778")),(decrypt("\111\115\000\004\121\115\003\013\114\005\014", "959")),(decrypt("\002\023\030\030\030\051", "2803")),(decrypt("\086\087\105\096\098\105\096", "981")),(decrypt("\111\104\110\088", "707")),(decrypt("\001\022\063", "1847")),},Env[decrypt("\066\088\095\064\074", "296")],decrypt("\109\102\094\087\078\089\092\093\085\074", "290"),Env[decrypt("\089\082\079\067", "777")],decrypt("\028", "2812"),Env[decrypt("\065\065\067\090\092\082", "2513")][decrypt("\085\075\068\084", "2816")],decrypt("\066\070\066\088\092\087", "120"),Env[decrypt("\065\076\065\080\092\095", "2839")][decrypt("\084\081\090\087", "2843")],Env[decrypt("\066\082\084\090\086", "636")][decrypt("\084\090\093\083", "2337")] or function(targetTable, value)
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
 Temp[10] = 0
Temp[5] = ttostring ~= __metatable
Stack[Temp[10]] = Temp[16] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[6] = vmEnv
Temp[3] = 17
Temp[5] = Constants[Temp[3]]
Temp[16] = 0
Temp[6][Temp[5]] = Temp[5] 
elseif pointer == 3 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\121\094\095\104\103\015\087\099\111\105", "283")),(decrypt("\015\105\093\015\109\095\108\104\084\110\110\081\090\095", "1564")),(decrypt("\114\002\027", "697")),((decrypt("\029", "167"))),(decrypt("\022\056", "132")),(decrypt("\027\060", "1726")),(decrypt("\012\089\082\088\091\102\107\099", "1978")),(decrypt("\027\051", "2823")),(decrypt("\095\110\083\094\082\093\107\088\110", "528")),(decrypt("\025\050", "1971")),}

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
	
	Stack[0] = function(...) -- PROTOTYPE 1
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
 Temp[3] = 1
Temp[13] = Constants
Temp[6] = 5
Stack[Temp[3]] = Temp[13][Temp[6]] 
elseif pointer == 2 then -- 23 [EQ] 
 	if Stack[0] ~= Constants[10] then pointer = pointer + 1 end 
elseif pointer == 3 then -- 22 [JMP] 
 pointer = pointer + 9  
elseif pointer == 4 then -- 16 [MOD] 
 	Stack[2] = Stack[0] % Constants[8] 
elseif pointer == 5 then -- 23 [EQ] 
 	if Stack[2] == Constants[5] then pointer = pointer + 1 end 
elseif pointer == 6 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 7 then -- 15 [DIV] 
 	Stack[0] = Stack[0] / Constants[8] 
elseif pointer == 8 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 9 then -- 14 [MUL] 
 	Stack[2] = Constants[6] * Stack[0] 
elseif pointer == 10 then -- 12 [ADD] 
 	Stack[0] = Stack[2] + Constants[10] 
elseif pointer == 11 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Constants[10] 
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
 
elseif pointer == 4 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\010\106\082\083\104", "328")),(decrypt("\084\106\104\107\090\086\091\111", "1663")),((decrypt("\031\021\024\027\031", "2941"))),(decrypt("\085\101\110\085\093\093", "1955")),(decrypt("\017\063", "641")),(decrypt("\088\083\110\087\081", "2764")),(decrypt("\026\020\031\063", "2384")),(decrypt("\067\105\088\085", "2513")),((decrypt("\025", "367"))),((decrypt("\022\018\031", "1735"))),(decrypt("\127\006\008\029", "590")),(decrypt("\081\111\090\104\110", "2736")),(decrypt("\025\016\062", "1755")),(decrypt("\011\086\080\080\082\108\095\107", "1047")),}

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
	
	Stack[1] = function(...) -- PROTOTYPE 2
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
 	if Stack[0] < Constants[5] then pointer = pointer + 1 end 
elseif pointer == 2 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[13] = 1
Temp[5] = Constants
Temp[4] = 2
Stack[Temp[13]] = Temp[5][Temp[4]] 
elseif pointer == 4 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 5 then -- 22 [JMP] 
 pointer = pointer + 17  
elseif pointer == 6 then -- 23 [EQ] 
 	if Stack[0] == Constants[5] then pointer = pointer + 1 end 
elseif pointer == 7 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 8 then -- 1 [LOADK] 
 Temp[13] = 1
Temp[7] = Constants
Temp[3] = 8
Stack[Temp[13]] = Temp[7][Temp[3]] 
elseif pointer == 9 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 10 then -- 22 [JMP] 
 pointer = pointer + 12  
elseif pointer == 11 then -- 24 [LT] 
 	if Stack[0] < Constants[13] then pointer = pointer + 1 end 
elseif pointer == 12 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 13 then -- 1 [LOADK] 
 Temp[6] = 1
Temp[9] = Constants
Temp[13] = 6
Stack[Temp[6]] = Temp[9][Temp[13]] 
elseif pointer == 14 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 15 then -- 22 [JMP] 
 pointer = pointer + 7  
elseif pointer == 16 then -- 24 [LT] 
 	if Stack[0] < Constants[7] then pointer = pointer + 1 end 
elseif pointer == 17 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 18 then -- 1 [LOADK] 
 Temp[16] = 1
Temp[4] = Constants
Temp[14] = 4
Stack[Temp[16]] = Temp[4][Temp[14]] 
elseif pointer == 19 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 20 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 21 then -- 1 [LOADK] 
 Temp[8] = 1
Temp[4] = Constants
Temp[16] = 12
Stack[Temp[8]] = Temp[4][Temp[16]] 
elseif pointer == 22 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 23 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 5 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\012\080\083\083\106\108\093", "666")),(decrypt("\027\051", "2802")),(decrypt("\010\106\085\084\110\110\032\089\083\032\082\080\087\089\085\111\081\085\070\110", "725")),(decrypt("\028\059", "402")),(decrypt("\022\062", "1557")),}

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
	
	Stack[2] = function(...) -- PROTOTYPE 3
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
 Temp[9] = 2
Temp[14] = Constants
Temp[13] = 2
Stack[Temp[9]] = Temp[14][Temp[13]] 
elseif pointer == 2 then -- 0 [MOVE] 
 Temp[13] = 3
Temp[11] = 0
Stack[Temp[13]] = Stack[Temp[11]] 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[4] = 4
Temp[9] = Constants
Temp[2] = 4
Stack[Temp[4]] = Temp[9][Temp[2]] 
elseif pointer == 4 then -- 32 [FORPREP] 
     Stack[2] = Stack[2] - Stack[4]
    pointer = pointer + 5
     
elseif pointer == 5 then -- 16 [MOD] 
 	Stack[6] = Stack[0] % Stack[5] 
elseif pointer == 6 then -- 23 [EQ] 
 	if Stack[6] == Constants[5] then pointer = pointer + 1 end 
elseif pointer == 7 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[7] = 1
Temp[15] = 5
Stack[Temp[7]] = Stack[Temp[15]] 
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
 
elseif pointer == 6 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\093\109\093\102", "956")),(decrypt("\008\104\105\081\106\109\090\100\091\126\109\092\084\090\081\093\108", "2718")),(decrypt("\114\089\092\109", "1981")),(decrypt("\123\091\097\088\090\108\080\118\105\106\091", "1091")),(decrypt("\020\051", "383")),(decrypt("\108\084\094\085\088", "1783")),(decrypt("\013\084\105\081\091\107\106", "1716")),(decrypt("\030\031\061", "686")),}

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
	
	Stack[3] = function(...) -- PROTOTYPE 4
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
 Temp[2] = 1
Temp[1] = Constants
Temp[15] = 5
Stack[Temp[2]] = Temp[1][Temp[15]] 
elseif pointer == 2 then -- 16 [MOD] 
 	Stack[2] = Stack[0] % Constants[8] 
elseif pointer == 3 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Stack[2] 
elseif pointer == 4 then -- 5 [GETGLOBAL] 
 Temp[15] = 2
Temp[12] = 1
Temp[3] = Constants[Temp[12]]
Stack[Temp[15]] = vmEnv[Temp[3]] or Env[Temp[3]]
	Stack[2] = Stack[2][Constants[6]]
	
	pointer = pointer + 1 
elseif pointer == 6 then -- 15 [DIV] 
 	Stack[3] = Stack[0] / Constants[8] 
elseif pointer == 7 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3]) 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[7] = 0
Temp[13] = 2
Stack[Temp[7]] = Stack[Temp[13]] 
elseif pointer == 9 then -- 23 [EQ] 
 	if Stack[0] == Constants[5] then pointer = pointer + 1 end 
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
 
elseif pointer == 7 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {(decrypt("\097", "851")),(decrypt("\104\084\085\108\106\089", "2206")),(decrypt("\000\099\083\088\084\100", "898")),(decrypt("\105", "1140")),(decrypt("\088\111\107\084\010\010", "2371")),(decrypt("\123\096\087\087\114\083\105\100\111", "584")),(decrypt("\093\083\107\094\083", "783")),(decrypt("\025\062", "1514")),(decrypt("\097\111\105\101\082\088", "953")),(decrypt("\114\089\093\111", "1993")),(decrypt("\082\090\107", "862")),(decrypt("\007", "2482")),(decrypt("\088\101\111\082\010", "2937")),(decrypt("\090\097\107\085\109", "1926")),(decrypt("\107", "1610")),((decrypt("\017\029\026", "682"))),}

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
	
	Stack[4] = function(...) -- PROTOTYPE 5
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
 Temp[9] = 1
Temp[11] = Constants
Temp[3] = 7
Stack[Temp[9]] = Temp[11][Temp[3]] 
elseif pointer == 2 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[9] = 3
Temp[6] = Constants
Temp[14] = 8
Stack[Temp[9]] = Temp[6][Temp[14]] 
elseif pointer == 4 then -- 20 [LEN] 
 	Stack[4] = #Stack[0] 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[10] = 5
Temp[15] = Constants
Temp[14] = 8
Stack[Temp[10]] = Temp[15][Temp[14]] 
elseif pointer == 6 then -- 32 [FORPREP] 
     Stack[3] = Stack[3] - Stack[5]
    pointer = pointer + 31
     
elseif pointer == 7 then -- 11 [SELF] 
 	Stack[8] = Stack[0]
	if Stack[8] then
		Stack[7] = Stack[0][Constants[11]]
	end
	 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[16] = 9
Temp[5] = 6
Stack[Temp[16]] = Stack[Temp[5]] 
elseif pointer == 9 then -- 0 [MOVE] 
 Temp[8] = 10
Temp[11] = 6
Stack[Temp[8]] = Stack[Temp[11]] 
elseif pointer == 10 then -- 28 [CALL] 
 	Stack[7] = Stack[7](Stack[8], Stack[9], Stack[10]) 
elseif pointer == 11 then -- 23 [EQ] 
 	if Stack[1] == Constants[7] then pointer = pointer + 1 end 
elseif pointer == 12 then -- 22 [JMP] 
 pointer = pointer + 4  
elseif pointer == 13 then -- 23 [EQ] 
 	if Stack[7] == Constants[4] then pointer = pointer + 1 end 
elseif pointer == 14 then -- 22 [JMP] 
 pointer = pointer + 20  
elseif pointer == 15 then -- 1 [LOADK] 
 Temp[14] = 1
Temp[11] = Constants
Temp[15] = 13
Stack[Temp[14]] = Temp[11][Temp[15]] 
elseif pointer == 16 then -- 22 [JMP] 
 pointer = pointer + 18  
elseif pointer == 17 then -- 23 [EQ] 
 	if Stack[1] == Constants[13] then pointer = pointer + 1 end 
elseif pointer == 18 then -- 22 [JMP] 
 pointer = pointer + 8  
elseif pointer == 19 then -- 23 [EQ] 
 	if Stack[7] == Constants[1] then pointer = pointer + 1 end 
elseif pointer == 20 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 21 then -- 1 [LOADK] 
 Temp[9] = 1
Temp[15] = Constants
Temp[5] = 5
Stack[Temp[9]] = Temp[15][Temp[5]] 
elseif pointer == 22 then -- 22 [JMP] 
 pointer = pointer + 12  
elseif pointer == 23 then -- 23 [EQ] 
 	if Stack[7] ~= Constants[4] then pointer = pointer + 1 end 
elseif pointer == 24 then -- 22 [JMP] 
 pointer = pointer + 10  
elseif pointer == 25 then -- 1 [LOADK] 
 Temp[6] = 1
Temp[2] = Constants
Temp[9] = 7
Stack[Temp[6]] = Temp[2][Temp[9]] 
elseif pointer == 26 then -- 22 [JMP] 
 pointer = pointer + 8  
elseif pointer == 27 then -- 23 [EQ] 
 	if Stack[1] == Constants[5] then pointer = pointer + 1 end 
elseif pointer == 28 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 29 then -- 23 [EQ] 
 	if Stack[7] == Constants[15] then pointer = pointer + 1 end 
elseif pointer == 30 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 31 then -- 1 [LOADK] 
 Temp[14] = 8
Temp[6] = Constants
Temp[3] = 9
Stack[Temp[14]] = Temp[6][Temp[3]] 
elseif pointer == 32 then -- 27 [TESTSET] 
 	if (not Stack[8]) then
		pointer = pointer + 1
	else
		Stack[1] = Stack[8]
	end
	 
elseif pointer == 33 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 34 then -- 1 [LOADK] 
 Temp[2] = 1
Temp[4] = Constants
Temp[3] = 7
Stack[Temp[2]] = Temp[4][Temp[3]] 
elseif pointer == 35 then -- 20 [LEN] 
 	Stack[8] = #Stack[2] 
elseif pointer == 36 then -- 12 [ADD] 
 	Stack[8] = Stack[8] + Constants[8] 
elseif pointer == 37 then -- 9 [SETTABLE] 
 	Stack[2][Stack[8]] = Stack[1] 
elseif pointer == 38 then -- 31 [FORLOOP] 
     Stack[3] = Stack[3] + Stack[5]
    if (Stack[5] > 0 and Stack[3] <= Stack[4]) or (Stack[5] <= 0 and Stack[3] >= Stack[4]) then
        pointer = pointer + -32
        Stack[6] = Stack[3]
    end
     
elseif pointer == 39 then -- 0 [MOVE] 
 Temp[12] = 3
Temp[6] = 1
Stack[Temp[12]] = Stack[Temp[6]] 
elseif pointer == 40 then -- 5 [GETGLOBAL] 
 Temp[5] = 4
Temp[6] = 14
Temp[9] = Constants[Temp[6]]
Stack[Temp[5]] = vmEnv[Temp[9]] or Env[Temp[9]]
	Stack[4] = Stack[4][Constants[2]]
	
	pointer = pointer + 1 
elseif pointer == 42 then -- 0 [MOVE] 
 Temp[14] = 5
Temp[12] = 2
Stack[Temp[14]] = Stack[Temp[12]] 
elseif pointer == 43 then -- 1 [LOADK] 
 Temp[7] = 6
Temp[10] = Constants
Temp[4] = 12
Stack[Temp[7]] = Temp[10][Temp[4]]
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
 
elseif pointer == 8 then -- 5 [GETGLOBAL] 
 Temp[10] = 5
Temp[4] = 16
Temp[13] = Constants[Temp[4]]
Stack[Temp[10]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 9 then -- 10 [NEWTABLE] 
 	Stack[6] = {} 
elseif pointer == 10 then -- 1 [LOADK] 
 Temp[2] = 7
Temp[15] = Constants
Temp[6] = 8
Stack[Temp[2]] = Temp[15][Temp[6]] 
elseif pointer == 11 then -- 1 [LOADK] 
 Temp[6] = 8
Temp[14] = Constants
Temp[5] = 12
Stack[Temp[6]] = Temp[14][Temp[5]] 
elseif pointer == 12 then -- 1 [LOADK] 
 Temp[3] = 9
Temp[7] = Constants
Temp[11] = 2
Stack[Temp[3]] = Temp[7][Temp[11]] 
elseif pointer == 13 then -- 34 [SETLIST] 
 	for i = 1, 3 do
		Stack[6][(1 - 1) * 50 + i] = Stack[6 + i]
	end
	 
elseif pointer == 14 then -- 28 [CALL] 
 	Stack[5], Stack[6], Stack[7] = Stack[5](Stack[6]) 
elseif pointer == 15 then -- 22 [JMP] 
 pointer = pointer + 9  
elseif pointer == 16 then -- 5 [GETGLOBAL] 
 Temp[5] = 10
Temp[7] = 13
Temp[15] = Constants[Temp[7]]
Stack[Temp[5]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 17 then -- 1 [LOADK] 
 Temp[9] = 11
Temp[12] = Constants
Temp[14] = 15
Stack[Temp[9]] = Temp[12][Temp[14]] 
elseif pointer == 18 then -- 0 [MOVE] 
 Temp[14] = 12
Temp[15] = 9
Stack[Temp[14]] = Stack[Temp[15]] 
elseif pointer == 19 then -- 1 [LOADK] 
 Temp[7] = 13
Temp[4] = Constants
Temp[11] = 3
Stack[Temp[7]] = Temp[4][Temp[11]] 
elseif pointer == 20 then -- 0 [MOVE] 
 Temp[7] = 14
Temp[10] = 0
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 21 then -- 0 [MOVE] 
 Temp[14] = 15
Temp[12] = 9
Stack[Temp[14]] = Stack[Temp[12]] 
elseif pointer == 22 then -- 28 [CALL] 
 	Stack[14] = Stack[14](Stack[15]) 
elseif pointer == 23 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 11, 14 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[11] = Temp[1]
	 
elseif pointer == 24 then -- 28 [CALL] 
 	Stack[10](Stack[11]) 
elseif pointer == 25 then -- 33 [TFORLOOP] 
     local r1, r2 = Stack[5](Stack[6], Stack[7])
    Stack[8] = r1
        Stack[9] = r2
    if Stack[8] ~= nil then
        Stack[7] = Stack[8]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 26 then -- 22 [JMP] 
 pointer = pointer + -11  
elseif pointer == 27 then -- 5 [GETGLOBAL] 
 Temp[15] = 5
Temp[13] = 16
Temp[6] = Constants[Temp[13]]
Stack[Temp[15]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 28 then -- 10 [NEWTABLE] 
 	Stack[6] = {} 
elseif pointer == 29 then -- 1 [LOADK] 
 Temp[2] = 7
Temp[9] = Constants
Temp[7] = 7
Stack[Temp[2]] = Temp[9][Temp[7]] 
elseif pointer == 30 then -- 1 [LOADK] 
 Temp[16] = 8
Temp[15] = Constants
Temp[13] = 10
Stack[Temp[16]] = Temp[15][Temp[13]] 
elseif pointer == 31 then -- 1 [LOADK] 
 Temp[13] = 9
Temp[3] = Constants
Temp[16] = 12
Stack[Temp[13]] = Temp[3][Temp[16]] 
elseif pointer == 32 then -- 1 [LOADK] 
 Temp[4] = 10
Temp[10] = Constants
Temp[8] = 1
Stack[Temp[4]] = Temp[10][Temp[8]] 
elseif pointer == 33 then -- 1 [LOADK] 
 Temp[1] = 11
Temp[8] = Constants
Temp[12] = 9
Stack[Temp[1]] = Temp[8][Temp[12]] 
elseif pointer == 34 then -- 34 [SETLIST] 
 	for i = 1, 5 do
		Stack[6][(1 - 1) * 50 + i] = Stack[6 + i]
	end
	 
elseif pointer == 35 then -- 28 [CALL] 
 	Stack[5], Stack[6], Stack[7] = Stack[5](Stack[6]) 
elseif pointer == 36 then -- 22 [JMP] 
 pointer = pointer + 8  
elseif pointer == 37 then -- 5 [GETGLOBAL] 
 Temp[5] = 10
Temp[14] = 13
Temp[11] = Constants[Temp[14]]
Stack[Temp[5]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 38 then -- 0 [MOVE] 
 Temp[12] = 11
Temp[5] = 9
Stack[Temp[12]] = Stack[Temp[5]] 
elseif pointer == 39 then -- 1 [LOADK] 
 Temp[14] = 12
Temp[7] = Constants
Temp[11] = 4
Stack[Temp[14]] = Temp[7][Temp[11]] 
elseif pointer == 40 then -- 0 [MOVE] 
 Temp[7] = 13
Temp[4] = 1
Stack[Temp[7]] = Stack[Temp[4]] 
elseif pointer == 41 then -- 0 [MOVE] 
 Temp[6] = 14
Temp[5] = 9
Stack[Temp[6]] = Stack[Temp[5]] 
elseif pointer == 42 then -- 28 [CALL] 
 	Stack[13] = Stack[13](Stack[14]) 
elseif pointer == 43 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 11, 13 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[11] = Temp[1]
	 
elseif pointer == 44 then -- 28 [CALL] 
 	Stack[10](Stack[11]) 
elseif pointer == 45 then -- 33 [TFORLOOP] 
     local r1, r2 = Stack[5](Stack[6], Stack[7])
    Stack[8] = r1
        Stack[9] = r2
    if Stack[8] ~= nil then
        Stack[7] = Stack[8]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 46 then -- 22 [JMP] 
 pointer = pointer + -10  
elseif pointer == 47 then -- 5 [GETGLOBAL] 
 Temp[1] = 5
Temp[12] = 13
Temp[7] = Constants[Temp[12]]
Stack[Temp[1]] = vmEnv[Temp[7]] or Env[Temp[7]] 
elseif pointer == 48 then -- 0 [MOVE] 
 Temp[10] = 6
Temp[3] = 2
Stack[Temp[10]] = Stack[Temp[3]] 
elseif pointer == 49 then -- 1 [LOADK] 
 Temp[7] = 7
Temp[8] = Constants
Temp[15] = 6
Stack[Temp[7]] = Temp[8][Temp[15]]
	Stack[6] = Stack[6](Stack[7])
	pointer = pointer + 1 
elseif pointer == 51 then -- 0 [MOVE] 
 Temp[3] = 7
Temp[11] = 2
Stack[Temp[3]] = Stack[Temp[11]] 
elseif pointer == 52 then -- 1 [LOADK] 
 Temp[14] = 8
Temp[7] = Constants
Temp[4] = 21
Stack[Temp[14]] = Temp[7][Temp[4]]
	Stack[7] = Stack[7](Stack[8])
	pointer = pointer + 1 
elseif pointer == 54 then -- 0 [MOVE] 
 Temp[8] = 8
Temp[15] = 3
Stack[Temp[8]] = Stack[Temp[15]] 
elseif pointer == 55 then -- 1 [LOADK] 
 Temp[5] = 9
Temp[16] = Constants
Temp[15] = 18
Stack[Temp[5]] = Temp[16][Temp[15]]
	Temp[2] = {Stack[8](Stack[9])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[8] = nil
		top = 8
	else
		top = 8 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[8 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 57 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 5 + 1, top do
		Temp[1][i - 5] = Stack[i]
	end
	Temp[2] = {Stack[5](unpack(Temp[1], 1, top - 5))}
		for i = 1, 0 do
		Stack[5 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 58 then -- 5 [GETGLOBAL] 
 Temp[16] = 5
Temp[4] = 13
Temp[12] = Constants[Temp[4]]
Stack[Temp[16]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 59 then -- 0 [MOVE] 
 Temp[11] = 6
Temp[16] = 4
Stack[Temp[11]] = Stack[Temp[16]] 
elseif pointer == 60 then -- 1 [LOADK] 
 Temp[16] = 7
Temp[9] = Constants
Temp[6] = 19
Stack[Temp[16]] = Temp[9][Temp[6]]
	Temp[2] = {Stack[6](Stack[7])}
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
elseif pointer == 62 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 5 + 1, top do
		Temp[1][i - 5] = Stack[i]
	end
	Temp[2] = {Stack[5](unpack(Temp[1], 1, top - 5))}
		for i = 1, 0 do
		Stack[5 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 63 then -- 5 [GETGLOBAL] 
 Temp[10] = 5
Temp[15] = 13
Temp[16] = Constants[Temp[15]]
Stack[Temp[10]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 64 then -- 0 [MOVE] 
 Temp[4] = 6
Temp[11] = 4
Stack[Temp[4]] = Stack[Temp[11]] 
elseif pointer == 65 then -- 1 [LOADK] 
 Temp[12] = 7
Temp[11] = Constants
Temp[4] = 20
Stack[Temp[12]] = Temp[11][Temp[4]]
	Temp[2] = {Stack[6](Stack[7])}
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
elseif pointer == 67 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 5 + 1, top do
		Temp[1][i - 5] = Stack[i]
	end
	Temp[2] = {Stack[5](unpack(Temp[1], 1, top - 5))}
		for i = 1, 0 do
		Stack[5 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 68 then -- 30 [RETURN] 
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