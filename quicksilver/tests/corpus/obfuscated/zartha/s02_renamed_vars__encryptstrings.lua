return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env[decrypt("\066\067\070\090\095\080", "1743")][decrypt("\082\093\087\065", "1563")],Env[decrypt("\066\065\075\089\095\082", "1590")][decrypt("\080\074\069\093", "2318")],Env[decrypt("\066\070\065\095\095\085", "1236")][decrypt("\065\077\082", "2806")],Env[decrypt("\067\088\065\067\069\091\089\080", "772")],Env[decrypt("\065\084\088\093\093", "1791")],Env[decrypt("\069\086\082\094\084", "1702")][decrypt("\071\087\064\084\081\082", "2905")] or Env[decrypt("\065\088\068\085\085\095", "464")],Env[decrypt("\069\084\080\092\084", "1520")][decrypt("\081\086\091\081\083\077", "2952")],Env[decrypt("\070\094\095\068\095\083\084\067", "2111")],Env[decrypt("\066\093\066\091\084\076\087\066\080\090\090\083", "1866")],decrypt("\109\102\092\093\070\088\069\089\080\085\084", "2918"),decrypt("\104\103\094\089\092\082\079", "787"),Env[decrypt("\090\092\065\068\075\089\076\064", "496")],Env[decrypt("\066\075\095\092\070", "2962")],{(decrypt("\024\061", "2683")),(decrypt("\111\127\001\004\117\114\003\001\115\005\002", "998")),(decrypt("\081\096\081\092\110\081\081", "2847")),(decrypt("\010\087\090", "2499")),(decrypt("\024\059", "1018")),(decrypt("\025\017\051", "2686")),(decrypt("\091\085\083\109", "2341")),(decrypt("\025\062", "1555")),(decrypt("\008\086\081\080\110\106\089\083\084\085\120\111\091\093\082\105\110", "2023")),(decrypt("\091\086\086\092\106", "1805")),(decrypt("\116\086\104\087\084\104\098\088\104\099\036\095\094\081\104\093", "834")),(decrypt("\030\051", "2823")),(decrypt("\085\094\085\092\089", "2759")),(decrypt("\024\020\056", "2332")),(decrypt("\022\051", "1859")),(decrypt("\110\084\090\086\082", "617")),},Env[decrypt("\066\088\095\064\074", "296")],decrypt("\109\102\094\087\078\089\092\093\085\074", "290"),Env[decrypt("\089\082\079\067", "777")],decrypt("\028", "2812"),Env[decrypt("\065\065\067\090\092\082", "2513")][decrypt("\085\075\068\084", "2816")],decrypt("\066\070\066\088\092\087", "120"),Env[decrypt("\065\076\065\080\092\095", "2839")][decrypt("\084\081\090\087", "2843")],Env[decrypt("\066\082\084\090\086", "636")][decrypt("\084\090\093\083", "2337")] or function(targetTable, value)
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
 Temp[9] = 0
Temp[14] = ttostring ~= __metatable
Stack[Temp[9]] = Temp[16] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[4] = vmEnv
Temp[5] = 2
Temp[10] = Constants[Temp[5]]
Temp[15] = 0
Temp[4][Temp[10]] = Temp[10] 
elseif pointer == 3 then -- 10 [NEWTABLE] 
 	Stack[0] = {} 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[10] = 1
Temp[5] = Constants
Temp[16] = 15
Stack[Temp[10]] = Temp[5][Temp[16]] 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[6] = 2
Temp[3] = Constants
Temp[5] = 6
Stack[Temp[6]] = Temp[3][Temp[5]] 
elseif pointer == 6 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\095\084\106\082\083\082\092\072", "782")),(decrypt("\013\117\013\013", "2157")),(decrypt("\084\089\091\048", "1986")),(decrypt("\089\094\080\047\109\100\110\085\066\009\033", "2868")),(decrypt("\116\127\115\116\116\125\114", "2884")),(decrypt("\122\083\090\099\110\105\109", "1569")),(decrypt("\095\109\082\103\110\090", "1129")),(decrypt("\022\050", "1911")),((decrypt("\025\016\018", "2791"))),}

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
	
	Stack[3] = function(...) -- PROTOTYPE 1
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 0}, [1] = {0, 1}, [2] = {0, 2}}
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
 Temp[10] = 5
Temp[16] = byte == pairs
Stack[Temp[10]] = Temp[4] 
elseif pointer == 10 then -- 1 [LOADK] 
 Temp[11] = 6
Temp[12] = Constants
Temp[4] = 4
Stack[Temp[11]] = Temp[12][Temp[4]] 
elseif pointer == 11 then -- 0 [MOVE] 
 Temp[14] = 7
Temp[1] = 0
Stack[Temp[14]] = Stack[Temp[1]] 
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
 	Stack[5][Constants[7]] = Stack[1] 
elseif pointer == 18 then -- 9 [SETTABLE] 
 	Stack[5][Constants[1]] = Constants[8] 
elseif pointer == 19 then -- 0 [MOVE] 
 Temp[12] = 3
Temp[13] = 5
Stack[Temp[12]] = Stack[Temp[13]] 
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
Temp[7] = ttostring ~= __metatable
Stack[Temp[4]] = Temp[10] 
elseif pointer == 29 then -- 30 [RETURN] 
 	return Stack[5] 
elseif pointer == 30 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 10 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\123\083\089", "132")),(decrypt("\095\107\082\104\110\092", "1726")),(decrypt("\084\095\092\047\109\092\081\084\111\102\032", "1978")),((decrypt("\025\031\002\030", "2823"))),(decrypt("\093\094\096\080\089\088\094\066", "528")),(decrypt("\123\101\092\118\088\089\083\105\088\073\112\105\088\082\013\012\088\097\083\109", "1971")),(decrypt("\083\080\087\048", "604")),(decrypt("\021\056", "2352")),(decrypt("\118\083\111\071\109\089\093", "1077")),}

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
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 0}, [1] = {0, 1}}
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
 	if Stack[2] ~= Constants[7] then pointer = pointer + 1 end 
elseif pointer == 4 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 5 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[2][Constants[5]]
	 
elseif pointer == 6 then -- 24 [LT] 
 	if Stack[3] < Stack[1] then pointer = pointer + 1 end 
elseif pointer == 7 then -- 22 [JMP] 
 pointer = pointer + 5  
elseif pointer == 8 then -- 2 [LOADBOOL] 
 Temp[14] = 3
Temp[1] = byte == pairs
Stack[Temp[14]] = Temp[3] 
elseif pointer == 9 then -- 1 [LOADK] 
 Temp[14] = 4
Temp[12] = Constants
Temp[15] = 3
Stack[Temp[14]] = Temp[12][Temp[15]] 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[1] = 5
Temp[2] = 0
Stack[Temp[1]] = Stack[Temp[2]] 
elseif pointer == 11 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 4, 5 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[4] = Temp[1]
	 
elseif pointer == 12 then -- 30 [RETURN] 
 	return Stack[3], Stack[4] 
elseif pointer == 13 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[2][Constants[5]]
	 
elseif pointer == 14 then -- 13 [SUB] 
 	Stack[3] = Stack[3] - Stack[1] 
elseif pointer == 15 then -- 9 [SETTABLE] 
 	Stack[2][Constants[5]] = Stack[3] 
elseif pointer == 16 then -- 4 [GETUPVAL] 
 	Stack[3] = Upvalues[1] 
elseif pointer == 17 then -- 6 [GETTABLE] 
 	Stack[4] = Stack[2][Constants[2]]
	 
elseif pointer == 18 then -- 14 [MUL] 
 	Stack[4] = Stack[4] * Stack[1] 
elseif pointer == 19 then -- 13 [SUB] 
 	Stack[3] = Stack[3] - Stack[4] 
elseif pointer == 20 then -- 8 [SETUPVAL] 
 	Upvalues[1] = Stack[3] 
elseif pointer == 21 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[2][Constants[5]]
	 
elseif pointer == 22 then -- 23 [EQ] 
 	if Stack[3] == Constants[8] then pointer = pointer + 1 end 
elseif pointer == 23 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 24 then -- 4 [GETUPVAL] 
 	Stack[3] = Upvalues[0] 
elseif pointer == 25 then -- 9 [SETTABLE] 
 	Stack[3][Stack[0]] = Constants[7] 
elseif pointer == 26 then -- 2 [LOADBOOL] 
 Temp[9] = 3
Temp[11] = ttostring ~= __metatable
Stack[Temp[9]] = Temp[12] 
elseif pointer == 27 then -- 30 [RETURN] 
 	return Stack[3] 
elseif pointer == 28 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 13 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\038\047", "1047")),((decrypt("\030\028\018\017\002\030\024", "2278"))),(decrypt("\082\097\104\090\101", "991")),(decrypt("\080\081\082\082\083", "782")),(decrypt("\090\088\104\085\089\084\091\064", "2400")),(decrypt("\083\109\019", "1334")),((decrypt("\031\022\024\029\024\027\030", "2312"))),(decrypt("\086\107\082\095\091", "1326")),(decrypt("\085\080\110\085\094\092", "576")),(decrypt("\013\084\108\094\065\086\093\107\106", "1167")),(decrypt("\090\080\090\104\082\033\095\108\081\104\110\091\000\033", "1610")),(decrypt("\088\085\093\088", "2343")),(decrypt("\037\086", "2970")),(decrypt("\126\083\110\091\114\092\085\094\089\115\110\091\095\089\104\110", "2922")),(decrypt("\089\100\087\105\103\092", "787")),(decrypt("\008\110\085\011\084\085\083\081\105\106", "2601")),(decrypt("\025\062", "1517")),}

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
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 0}, [1] = {0, 1}}
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
 Temp[4] = 1
Temp[16] = 8
Temp[1] = Constants[Temp[16]]
Stack[Temp[4]] = vmEnv[Temp[1]] or Env[Temp[1]] 
elseif pointer == 3 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 4 then -- 28 [CALL] 
 	Stack[1], Stack[2], Stack[3] = Stack[1](Stack[2]) 
elseif pointer == 5 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 6 then -- 20 [LEN] 
 	Stack[5] = #Stack[0] 
elseif pointer == 7 then -- 12 [ADD] 
 	Stack[5] = Stack[5] + Constants[17] 
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
 Temp[3] = 1
Temp[10] = 3
Temp[4] = Constants[Temp[10]]
Stack[Temp[3]] = vmEnv[Temp[4]] or Env[Temp[4]]
	Stack[1] = Stack[1][Constants[12]]
	
	pointer = pointer + 1 
elseif pointer == 13 then -- 0 [MOVE] 
 Temp[2] = 2
Temp[6] = 0
Stack[Temp[2]] = Stack[Temp[6]] 
elseif pointer == 14 then -- 28 [CALL] 
 	Stack[1](Stack[2]) 
elseif pointer == 15 then -- 5 [GETGLOBAL] 
 Temp[1] = 1
Temp[4] = 9
Temp[15] = Constants[Temp[4]]
Stack[Temp[1]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 16 then -- 0 [MOVE] 
 Temp[4] = 2
Temp[2] = 0
Stack[Temp[4]] = Stack[Temp[2]] 
elseif pointer == 17 then -- 28 [CALL] 
 	Stack[1], Stack[2], Stack[3] = Stack[1](Stack[2]) 
elseif pointer == 18 then -- 22 [JMP] 
 pointer = pointer + 13  
elseif pointer == 19 then -- 4 [GETUPVAL] 
 	Stack[6] = Upvalues[0] 
elseif pointer == 20 then -- 6 [GETTABLE] 
 	Stack[6] = Stack[6][Stack[5]]
	 
elseif pointer == 21 then -- 5 [GETGLOBAL] 
 Temp[9] = 7
Temp[13] = 4
Temp[14] = Constants[Temp[13]]
Stack[Temp[9]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 22 then -- 0 [MOVE] 
 Temp[13] = 8
Temp[11] = 5
Stack[Temp[13]] = Stack[Temp[11]] 
elseif pointer == 23 then -- 1 [LOADK] 
 Temp[4] = 9
Temp[9] = Constants
Temp[2] = 13
Stack[Temp[4]] = Temp[9][Temp[2]] 
elseif pointer == 24 then -- 6 [GETTABLE] 
 	Stack[10] = Stack[6][Constants[5]]
	 
elseif pointer == 25 then -- 1 [LOADK] 
 Temp[7] = 11
Temp[15] = Constants
Temp[10] = 1
Stack[Temp[7]] = Temp[15][Temp[10]] 
elseif pointer == 26 then -- 6 [GETTABLE] 
 	Stack[12] = Stack[6][Constants[15]]
	 
elseif pointer == 27 then -- 6 [GETTABLE] 
 	Stack[13] = Stack[6][Constants[5]]
	 
elseif pointer == 28 then -- 14 [MUL] 
 	Stack[12] = Stack[12] * Stack[13] 
elseif pointer == 29 then -- 1 [LOADK] 
 Temp[3] = 13
Temp[15] = Constants
Temp[10] = 6
Stack[Temp[3]] = Temp[15][Temp[10]] 
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
 Temp[7] = 1
Temp[13] = 4
Temp[1] = Constants[Temp[13]]
Stack[Temp[7]] = vmEnv[Temp[1]] or Env[Temp[1]] 
elseif pointer == 35 then -- 1 [LOADK] 
 Temp[10] = 2
Temp[12] = Constants
Temp[2] = 11
Stack[Temp[10]] = Temp[12][Temp[2]] 
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
 
elseif pointer == 16 then -- 5 [GETGLOBAL] 
 Temp[6] = 6
Temp[16] = 13
Temp[10] = Constants[Temp[16]]
Stack[Temp[6]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 17 then -- 0 [MOVE] 
 Temp[4] = 7
Temp[13] = 3
Stack[Temp[4]] = Stack[Temp[13]] 
elseif pointer == 18 then -- 1 [LOADK] 
 Temp[2] = 8
Temp[15] = Constants
Temp[6] = 7
Stack[Temp[2]] = Temp[15][Temp[6]] 
elseif pointer == 19 then -- 1 [LOADK] 
 Temp[6] = 9
Temp[14] = Constants
Temp[5] = 1
Stack[Temp[6]] = Temp[14][Temp[5]] 
elseif pointer == 20 then -- 1 [LOADK] 
 Temp[3] = 10
Temp[7] = Constants
Temp[11] = 5
Stack[Temp[3]] = Temp[7][Temp[11]]
	Temp[2] = {Stack[7](Stack[8], Stack[9], Stack[10])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[7] = nil
		top = 7
	else
		top = 7 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[7 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 22 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 6 + 1, top do
		Temp[1][i - 6] = Stack[i]
	end
	Temp[2] = {Stack[6](unpack(Temp[1], 1, top - 6))}
		for i = 1, 0 do
		Stack[6 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 23 then -- 5 [GETGLOBAL] 
 Temp[5] = 6
Temp[7] = 13
Temp[15] = Constants[Temp[7]]
Stack[Temp[5]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 24 then -- 0 [MOVE] 
 Temp[9] = 7
Temp[12] = 3
Stack[Temp[9]] = Stack[Temp[12]] 
elseif pointer == 25 then -- 1 [LOADK] 
 Temp[14] = 8
Temp[15] = Constants
Temp[7] = 3
Stack[Temp[14]] = Temp[15][Temp[7]] 
elseif pointer == 26 then -- 1 [LOADK] 
 Temp[7] = 9
Temp[4] = Constants
Temp[11] = 12
Stack[Temp[7]] = Temp[4][Temp[11]] 
elseif pointer == 27 then -- 1 [LOADK] 
 Temp[7] = 10
Temp[10] = Constants
Temp[14] = 8
Stack[Temp[7]] = Temp[10][Temp[14]]
	Temp[2] = {Stack[7](Stack[8], Stack[9], Stack[10])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[7] = nil
		top = 7
	else
		top = 7 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[7 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 29 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 6 + 1, top do
		Temp[1][i - 6] = Stack[i]
	end
	Temp[2] = {Stack[6](unpack(Temp[1], 1, top - 6))}
		for i = 1, 0 do
		Stack[6 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 30 then -- 5 [GETGLOBAL] 
 Temp[12] = 6
Temp[15] = 13
Temp[13] = Constants[Temp[15]]
Stack[Temp[12]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 31 then -- 0 [MOVE] 
 Temp[6] = 7
Temp[2] = 3
Stack[Temp[6]] = Stack[Temp[2]] 
elseif pointer == 32 then -- 1 [LOADK] 
 Temp[9] = 8
Temp[7] = Constants
Temp[16] = 16
Stack[Temp[9]] = Temp[7][Temp[16]] 
elseif pointer == 33 then -- 1 [LOADK] 
 Temp[15] = 9
Temp[13] = Constants
Temp[3] = 14
Stack[Temp[15]] = Temp[13][Temp[3]] 
elseif pointer == 34 then -- 1 [LOADK] 
 Temp[16] = 10
Temp[4] = Constants
Temp[10] = 5
Stack[Temp[16]] = Temp[4][Temp[10]]
	Temp[2] = {Stack[7](Stack[8], Stack[9], Stack[10])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[7] = nil
		top = 7
	else
		top = 7 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[7 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 36 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 6 + 1, top do
		Temp[1][i - 6] = Stack[i]
	end
	Temp[2] = {Stack[6](unpack(Temp[1], 1, top - 6))}
		for i = 1, 0 do
		Stack[6 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 37 then -- 5 [GETGLOBAL] 
 Temp[10] = 6
Temp[8] = 13
Temp[1] = Constants[Temp[8]]
Stack[Temp[10]] = vmEnv[Temp[1]] or Env[Temp[1]] 
elseif pointer == 38 then -- 0 [MOVE] 
 Temp[8] = 7
Temp[1] = 4
Stack[Temp[8]] = Stack[Temp[1]] 
elseif pointer == 39 then -- 1 [LOADK] 
 Temp[12] = 8
Temp[5] = Constants
Temp[14] = 7
Stack[Temp[12]] = Temp[5][Temp[14]] 
elseif pointer == 40 then -- 1 [LOADK] 
 Temp[11] = 9
Temp[12] = Constants
Temp[5] = 8
Stack[Temp[11]] = Temp[12][Temp[5]]
	Temp[2] = {Stack[7](Stack[8], Stack[9])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[7] = nil
		top = 7
	else
		top = 7 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[7 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 42 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 6 + 1, top do
		Temp[1][i - 6] = Stack[i]
	end
	Temp[2] = {Stack[6](unpack(Temp[1], 1, top - 6))}
		for i = 1, 0 do
		Stack[6 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 43 then -- 5 [GETGLOBAL] 
 Temp[14] = 6
Temp[7] = 13
Temp[11] = Constants[Temp[7]]
Stack[Temp[14]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 44 then -- 0 [MOVE] 
 Temp[7] = 7
Temp[4] = 4
Stack[Temp[7]] = Stack[Temp[4]] 
elseif pointer == 45 then -- 1 [LOADK] 
 Temp[6] = 8
Temp[5] = Constants
Temp[1] = 10
Stack[Temp[6]] = Temp[5][Temp[1]] 
elseif pointer == 46 then -- 1 [LOADK] 
 Temp[12] = 9
Temp[7] = Constants
Temp[10] = 8
Stack[Temp[12]] = Temp[7][Temp[10]]
	Temp[2] = {Stack[7](Stack[8], Stack[9])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[7] = nil
		top = 7
	else
		top = 7 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[7 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 48 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 6 + 1, top do
		Temp[1][i - 6] = Stack[i]
	end
	Temp[2] = {Stack[6](unpack(Temp[1], 1, top - 6))}
		for i = 1, 0 do
		Stack[6 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 49 then -- 0 [MOVE] 
 Temp[3] = 6
Temp[7] = 5
Stack[Temp[3]] = Stack[Temp[7]] 
elseif pointer == 50 then -- 28 [CALL] 
 	Stack[6]() 
elseif pointer == 51 then -- 30 [RETURN] 
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