return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env[decrypt("\066\067\070\090\095\080", "1743")][decrypt("\082\093\087\065", "1563")],Env[decrypt("\066\065\075\089\095\082", "1590")][decrypt("\080\074\069\093", "2318")],Env[decrypt("\066\070\065\095\095\085", "1236")][decrypt("\065\077\082", "2806")],Env[decrypt("\067\088\065\067\069\091\089\080", "772")],Env[decrypt("\065\084\088\093\093", "1791")],Env[decrypt("\069\086\082\094\084", "1702")][decrypt("\071\087\064\084\081\082", "2905")] or Env[decrypt("\065\088\068\085\085\095", "464")],Env[decrypt("\069\084\080\092\084", "1520")][decrypt("\081\086\091\081\083\077", "2952")],Env[decrypt("\070\094\095\068\095\083\084\067", "2111")],Env[decrypt("\066\093\066\091\084\076\087\066\080\090\090\083", "1866")],decrypt("\109\102\092\093\070\088\069\089\080\085\084", "2918"),decrypt("\104\103\094\089\092\082\079", "787"),Env[decrypt("\090\092\065\068\075\089\076\064", "496")],Env[decrypt("\066\075\095\092\070", "2962")],{(decrypt("\037", "2023")),(decrypt("\086\081\080\081\109\082\001\034", "1805")),(decrypt("\023\024\063", "834")),(decrypt("\026\020\057", "2823")),(decrypt("\028\060", "2759")),(decrypt("\013\111\092", "2332")),(decrypt("\091\083\092\089\084\102", "1859")),(decrypt("\026\022\060", "617")),(decrypt("\022\061", "1601")),(decrypt("\108\111\099\040\029\030\027\032\024\024\024\032\006\034", "2587")),(decrypt("\022\019\060", "2979")),(decrypt("\031\016\061", "776")),((decrypt("\030\016\019\024", "778"))),(decrypt("\099\086\097\093\082\008\046", "959")),(decrypt("\085\081\080\086\089", "2803")),(decrypt("\112\094\082\090", "981")),(decrypt("\031\059", "707")),(decrypt("\018", "1847")),(decrypt("\103\126\014\012\125\114\013\009\122\004\012", "1871")),(decrypt("\018\024\058", "851")),(decrypt("\036\025\022\017\104\064\036\017\030\082\070\047\031\031\104", "853")),(decrypt("\024\028\029\018\026\021\005\050", "2959")),(decrypt("\105\104", "1185")),(decrypt("\104\085\095\081\107\093", "536")),},Env[decrypt("\066\088\095\064\074", "296")],decrypt("\109\102\094\087\078\089\092\093\085\074", "290"),Env[decrypt("\089\082\079\067", "777")],decrypt("\028", "2812"),Env[decrypt("\065\065\067\090\092\082", "2513")][decrypt("\085\075\068\084", "2816")],decrypt("\066\070\066\088\092\087", "120"),Env[decrypt("\065\076\065\080\092\095", "2839")][decrypt("\084\081\090\087", "2843")],Env[decrypt("\066\082\084\090\086", "636")][decrypt("\084\090\093\083", "2337")] or function(targetTable, value)
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
 Temp[5] = 0
Temp[6] = ttostring ~= __metatable
Stack[Temp[5]] = Temp[16] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[10] = vmEnv
Temp[4] = 19
Temp[13] = Constants[Temp[4]]
Temp[2] = 0
Temp[10][Temp[13]] = Temp[13] 
elseif pointer == 3 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\122\101\088\090", "1971")),((decrypt("\028\021\028\029\024\024\006\025\025\026\026\024\006", "604"))),(decrypt("\118\111\110\082\094\087", "2352")),(decrypt("\119\119\124\119\119\117\125", "1077")),}

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
		if pointer == 1 then -- 24 [LT] 
 	if Stack[0] < Stack[1] then pointer = pointer + 1 end 
elseif pointer == 2 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 3 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 4 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 5 then -- 24 [LT] 
 	if Stack[2] < Stack[0] then pointer = pointer + 1 end 
elseif pointer == 6 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 7 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 8 then -- 30 [RETURN] 
 	return Stack[0] 
elseif pointer == 9 then -- 30 [RETURN] 
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
		local encoded = {(decrypt("\014\083\093\081\123\100\095\091\081\098\106", "1866")),(decrypt("\022\050", "1902")),(decrypt("\127\108\088\087\081\081\111", "1412")),((decrypt("\022\017\019\028", "1444"))),(decrypt("\123\106\107\091", "2632")),(decrypt("\011\083\092\094\109\090\082\013\107\094\089\083\084\127\101\092\092\085\099\105", "1595")),(decrypt("\118\097\085\085\106\090", "2909")),}

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
		if pointer == 1 then -- 23 [EQ] 
 	if Stack[1] ~= Constants[2] then pointer = pointer + 1 end 
elseif pointer == 2 then -- 22 [JMP] 
 pointer = pointer + 4  
elseif pointer == 3 then -- 0 [MOVE] 
 Temp[2] = 2
Temp[9] = 1
Stack[Temp[2]] = Stack[Temp[9]] 
elseif pointer == 4 then -- 16 [MOD] 
 	Stack[1] = Stack[0] % Stack[1] 
elseif pointer == 5 then -- 0 [MOVE] 
 Temp[16] = 0
Temp[11] = 2
Stack[Temp[16]] = Stack[Temp[11]] 
elseif pointer == 6 then -- 22 [JMP] 
 pointer = pointer + -6  
elseif pointer == 7 then -- 30 [RETURN] 
 	return Stack[0] 
elseif pointer == 8 then -- 30 [RETURN] 
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
		local encoded = {(decrypt("\026\057", "2278")),(decrypt("\093\097\090\102", "991")),(decrypt("\093\080\091\092", "782")),(decrypt("\027\063", "2400")),(decrypt("\022\056", "1334")),((decrypt("\030\029\020\027\002\031\030", "2312"))),(decrypt("\108\080\084\080\088", "1326")),(decrypt("\106\092\093\082\093\007\019\017", "576")),}

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
		if pointer == 1 then -- 24 [LT] 
 	if Stack[0] < Constants[4] then pointer = pointer + 1 end 
elseif pointer == 2 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 3 then -- 2 [LOADBOOL] 
 Temp[6] = 1
Temp[9] = byte == pairs
Stack[Temp[6]] = Temp[13] 
elseif pointer == 4 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[16] = 1
Temp[4] = Constants
Temp[14] = 4
Stack[Temp[16]] = Temp[4][Temp[14]] 
elseif pointer == 6 then -- 5 [GETGLOBAL] 
 Temp[8] = 2
Temp[4] = 2
Temp[16] = Constants[Temp[4]]
Stack[Temp[8]] = vmEnv[Temp[16]] or Env[Temp[16]]
	Stack[2] = Stack[2][Constants[7]]
	
	pointer = pointer + 1 
elseif pointer == 8 then -- 5 [GETGLOBAL] 
 Temp[1] = 3
Temp[3] = 2
Temp[10] = Constants[Temp[3]]
Stack[Temp[1]] = vmEnv[Temp[10]] or Env[Temp[10]]
	Stack[3] = Stack[3][Constants[3]]
	
	pointer = pointer + 1 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[4] = 4
Temp[2] = 0
Stack[Temp[4]] = Stack[Temp[2]] 
elseif pointer == 11 then -- 28 [CALL] 
 	Temp[2] = {Stack[3](Stack[4])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[3] = nil
		top = 3
	else
		top = 3 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[3 + i - 1] = Temp[2][i]
		end
	end
	 
elseif pointer == 12 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 2 + 1, top do
		Temp[1][i - 2] = Stack[i]
	end
	Temp[2] = {Stack[2](unpack(Temp[1], 1, top - 2))}
		for i = 1, 1 do
		Stack[2 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 13 then -- 1 [LOADK] 
 Temp[6] = 3
Temp[1] = Constants
Temp[4] = 1
Stack[Temp[6]] = Temp[1][Temp[4]] 
elseif pointer == 14 then -- 32 [FORPREP] 
     Stack[1] = Stack[1] - Stack[3]
    pointer = pointer + 5
     
elseif pointer == 15 then -- 16 [MOD] 
 	Stack[5] = Stack[0] % Stack[4] 
elseif pointer == 16 then -- 23 [EQ] 
 	if Stack[5] == Constants[5] then pointer = pointer + 1 end 
elseif pointer == 17 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 18 then -- 2 [LOADBOOL] 
 Temp[15] = 5
Temp[4] = byte == pairs
Stack[Temp[15]] = Temp[2] 
elseif pointer == 19 then -- 30 [RETURN] 
 	return Stack[5] 
elseif pointer == 20 then -- 31 [FORLOOP] 
     Stack[1] = Stack[1] + Stack[3]
    if (Stack[3] > 0 and Stack[1] <= Stack[2]) or (Stack[3] <= 0 and Stack[1] >= Stack[2]) then
        pointer = pointer + -6
        Stack[4] = Stack[1]
    end
     
elseif pointer == 21 then -- 2 [LOADBOOL] 
 Temp[9] = 1
Temp[13] = ttostring ~= __metatable
Stack[Temp[9]] = Temp[14] 
elseif pointer == 22 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 23 then -- 30 [RETURN] 
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
		local encoded = {((decrypt("\025\029\020\029\022\023", "1883"))),(decrypt("\098", "2132")),(decrypt("\027\056", "334")),(decrypt("\120\104\091\083\082\082\084\046\110\091\086\089\091\104\106", "2419")),(decrypt("\082\105\109\090\109", "914")),(decrypt("\115\082\110\087\080", "956")),(decrypt("\104\081\084\098\106\092", "2718")),(decrypt("\009\115\002\113\113", "1981")),(decrypt("\090\086\083\090\088\080\092\111", "1091")),}

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
		if pointer == 1 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 2 then -- 1 [LOADK] 
 Temp[2] = 3
Temp[10] = Constants
Temp[9] = 3
Stack[Temp[2]] = Temp[10][Temp[9]] 
elseif pointer == 3 then -- 20 [LEN] 
 	Stack[4] = #Stack[0] 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[4] = 5
Temp[2] = Constants
Temp[1] = 3
Stack[Temp[4]] = Temp[2][Temp[1]] 
elseif pointer == 5 then -- 32 [FORPREP] 
     Stack[3] = Stack[3] - Stack[5]
    pointer = pointer + 6
     
elseif pointer == 6 then -- 20 [LEN] 
 	Stack[7] = #Stack[2] 
elseif pointer == 7 then -- 12 [ADD] 
 	Stack[7] = Stack[7] + Constants[3] 
elseif pointer == 8 then -- 5 [GETGLOBAL] 
 Temp[15] = 8
Temp[3] = 9
Temp[12] = Constants[Temp[3]]
Stack[Temp[15]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 9 then -- 6 [GETTABLE] 
 	Stack[9] = Stack[0][Stack[6]]
	 
elseif pointer == 10 then -- 28 [CALL] 
 	Stack[8] = Stack[8](Stack[9]) 
elseif pointer == 11 then -- 9 [SETTABLE] 
 	Stack[2][Stack[7]] = Stack[8] 
elseif pointer == 12 then -- 31 [FORLOOP] 
     Stack[3] = Stack[3] + Stack[5]
    if (Stack[5] > 0 and Stack[3] <= Stack[4]) or (Stack[5] <= 0 and Stack[3] >= Stack[4]) then
        pointer = pointer + -7
        Stack[6] = Stack[3]
    end
     
elseif pointer == 13 then -- 5 [GETGLOBAL] 
 Temp[7] = 3
Temp[13] = 5
Temp[9] = Constants[Temp[13]]
Stack[Temp[7]] = vmEnv[Temp[9]] or Env[Temp[9]]
	Stack[3] = Stack[3][Constants[7]]
	
	pointer = pointer + 1 
elseif pointer == 15 then -- 0 [MOVE] 
 Temp[6] = 4
Temp[12] = 2
Stack[Temp[6]] = Stack[Temp[12]] 
elseif pointer == 16 then -- 0 [MOVE] 
 Temp[4] = 5
Temp[15] = 1
Stack[Temp[4]] = Stack[Temp[15]] 
elseif pointer == 17 then -- 29 [TAILCALL] 
 	return Stack[3](Stack[4], Stack[5]) 
elseif pointer == 18 then -- 30 [RETURN] 
             Temp[1] = {}
            Temp[2] = 0
            for i = 3, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
         
elseif pointer == 19 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 7 then -- 10 [NEWTABLE] 
 	Stack[4] = {} 
elseif pointer == 8 then -- 1 [LOADK] 
 Temp[15] = 5
Temp[6] = Constants
Temp[14] = 17
Stack[Temp[15]] = Temp[6][Temp[14]] 
elseif pointer == 9 then -- 1 [LOADK] 
 Temp[5] = 6
Temp[3] = Constants
Temp[7] = 8
Stack[Temp[5]] = Temp[3][Temp[7]] 
elseif pointer == 10 then -- 1 [LOADK] 
 Temp[7] = 7
Temp[11] = Constants
Temp[5] = 17
Stack[Temp[7]] = Temp[11][Temp[5]] 
elseif pointer == 11 then -- 32 [FORPREP] 
     Stack[5] = Stack[5] - Stack[7]
    pointer = pointer + 8
     
elseif pointer == 12 then -- 0 [MOVE] 
 Temp[7] = 9
Temp[15] = 2
Stack[Temp[7]] = Stack[Temp[15]] 
elseif pointer == 13 then -- 0 [MOVE] 
 Temp[9] = 10
Temp[12] = 8
Stack[Temp[9]] = Stack[Temp[12]] 
elseif pointer == 14 then -- 28 [CALL] 
 	Stack[9] = Stack[9](Stack[10]) 
elseif pointer == 15 then -- 26 [TEST] 
 	if Stack[9] then pointer = pointer + 1 end 
elseif pointer == 16 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 17 then -- 20 [LEN] 
 	Stack[9] = #Stack[4] 
elseif pointer == 18 then -- 12 [ADD] 
 	Stack[9] = Stack[9] + Constants[17] 
elseif pointer == 19 then -- 9 [SETTABLE] 
 	Stack[4][Stack[9]] = Stack[8] 
elseif pointer == 20 then -- 31 [FORLOOP] 
     Stack[5] = Stack[5] + Stack[7]
    if (Stack[7] > 0 and Stack[5] <= Stack[6]) or (Stack[7] <= 0 and Stack[5] >= Stack[6]) then
        pointer = pointer + -9
        Stack[8] = Stack[5]
    end
     
elseif pointer == 21 then -- 5 [GETGLOBAL] 
 Temp[14] = 5
Temp[7] = 15
Temp[15] = Constants[Temp[7]]
Stack[Temp[14]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 22 then -- 1 [LOADK] 
 Temp[7] = 6
Temp[4] = Constants
Temp[11] = 2
Stack[Temp[7]] = Temp[4][Temp[11]] 
elseif pointer == 23 then -- 0 [MOVE] 
 Temp[7] = 7
Temp[10] = 3
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 24 then -- 0 [MOVE] 
 Temp[14] = 8
Temp[12] = 4
Stack[Temp[14]] = Stack[Temp[12]] 
elseif pointer == 25 then -- 1 [LOADK] 
 Temp[15] = 9
Temp[13] = Constants
Temp[6] = 18
Stack[Temp[15]] = Temp[13][Temp[6]]
	Stack[7] = Stack[7](Stack[8], Stack[9])
	pointer = pointer + 1 
elseif pointer == 27 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 6, 7 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[6] = Temp[1]
	 
elseif pointer == 28 then -- 28 [CALL] 
 	Stack[5](Stack[6]) 
elseif pointer == 29 then -- 5 [GETGLOBAL] 
 Temp[2] = 5
Temp[9] = 15
Temp[7] = Constants[Temp[9]]
Stack[Temp[2]] = vmEnv[Temp[7]] or Env[Temp[7]] 
elseif pointer == 30 then -- 1 [LOADK] 
 Temp[16] = 6
Temp[15] = Constants
Temp[13] = 10
Stack[Temp[16]] = Temp[15][Temp[13]] 
elseif pointer == 31 then -- 0 [MOVE] 
 Temp[13] = 7
Temp[3] = 1
Stack[Temp[13]] = Stack[Temp[3]] 
elseif pointer == 32 then -- 1 [LOADK] 
 Temp[16] = 8
Temp[4] = Constants
Temp[10] = 3
Stack[Temp[16]] = Temp[4][Temp[10]] 
elseif pointer == 33 then -- 1 [LOADK] 
 Temp[10] = 9
Temp[8] = Constants
Temp[1] = 20
Stack[Temp[10]] = Temp[8][Temp[1]]
	Stack[7] = Stack[7](Stack[8], Stack[9])
	pointer = pointer + 1 
elseif pointer == 35 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 6, 7 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[6] = Temp[1]
	 
elseif pointer == 36 then -- 28 [CALL] 
 	Stack[5](Stack[6]) 
elseif pointer == 37 then -- 5 [GETGLOBAL] 
 Temp[8] = 5
Temp[1] = 15
Temp[12] = Constants[Temp[1]]
Stack[Temp[8]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 38 then -- 1 [LOADK] 
 Temp[5] = 6
Temp[14] = Constants
Temp[11] = 14
Stack[Temp[5]] = Temp[14][Temp[11]] 
elseif pointer == 39 then -- 0 [MOVE] 
 Temp[12] = 7
Temp[5] = 0
Stack[Temp[12]] = Stack[Temp[5]] 
elseif pointer == 40 then -- 1 [LOADK] 
 Temp[14] = 8
Temp[7] = Constants
Temp[11] = 4
Stack[Temp[14]] = Temp[7][Temp[11]] 
elseif pointer == 41 then -- 1 [LOADK] 
 Temp[7] = 9
Temp[4] = Constants
Temp[6] = 9
Stack[Temp[7]] = Temp[4][Temp[6]] 
elseif pointer == 42 then -- 1 [LOADK] 
 Temp[5] = 10
Temp[1] = Constants
Temp[12] = 12
Stack[Temp[5]] = Temp[1][Temp[12]]
	Stack[7] = Stack[7](Stack[8], Stack[9], Stack[10])
	pointer = pointer + 1 
elseif pointer == 44 then -- 1 [LOADK] 
 Temp[7] = 8
Temp[10] = Constants
Temp[3] = 1
Stack[Temp[7]] = Temp[10][Temp[3]] 
elseif pointer == 45 then -- 0 [MOVE] 
 Temp[7] = 9
Temp[8] = 0
Stack[Temp[7]] = Stack[Temp[8]] 
elseif pointer == 46 then -- 1 [LOADK] 
 Temp[15] = 10
Temp[3] = Constants
Temp[11] = 11
Stack[Temp[15]] = Temp[3][Temp[11]] 
elseif pointer == 47 then -- 1 [LOADK] 
 Temp[14] = 11
Temp[7] = Constants
Temp[4] = 9
Stack[Temp[14]] = Temp[7][Temp[4]] 
elseif pointer == 48 then -- 1 [LOADK] 
 Temp[8] = 12
Temp[15] = Constants
Temp[5] = 12
Stack[Temp[8]] = Temp[15][Temp[5]]
	Stack[9] = Stack[9](Stack[10], Stack[11], Stack[12])
	pointer = pointer + 1 
elseif pointer == 50 then -- 1 [LOADK] 
 Temp[16] = 10
Temp[15] = Constants
Temp[4] = 1
Stack[Temp[16]] = Temp[15][Temp[4]] 
elseif pointer == 51 then -- 0 [MOVE] 
 Temp[12] = 11
Temp[11] = 0
Stack[Temp[12]] = Stack[Temp[11]] 
elseif pointer == 52 then -- 1 [LOADK] 
 Temp[16] = 12
Temp[9] = Constants
Temp[6] = 5
Stack[Temp[16]] = Temp[9][Temp[6]] 
elseif pointer == 53 then -- 1 [LOADK] 
 Temp[10] = 13
Temp[15] = Constants
Temp[16] = 9
Stack[Temp[10]] = Temp[15][Temp[16]] 
elseif pointer == 54 then -- 1 [LOADK] 
 Temp[4] = 14
Temp[11] = Constants
Temp[12] = 12
Stack[Temp[4]] = Temp[11][Temp[12]]
	Stack[11] = Stack[11](Stack[12], Stack[13], Stack[14])
	pointer = pointer + 1 
elseif pointer == 56 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 6, 11 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[6] = Temp[1]
	 
elseif pointer == 57 then -- 28 [CALL] 
 	Stack[5](Stack[6]) 
elseif pointer == 58 then -- 5 [GETGLOBAL] 
 Temp[11] = 5
Temp[4] = 15
Temp[14] = Constants[Temp[4]]
Stack[Temp[11]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 59 then -- 5 [GETGLOBAL] 
 Temp[1] = 6
Temp[12] = 7
Temp[13] = Constants[Temp[12]]
Stack[Temp[1]] = vmEnv[Temp[13]] or Env[Temp[13]]
	Stack[6] = Stack[6][Constants[24]]
	
	pointer = pointer + 1 
elseif pointer == 61 then -- 1 [LOADK] 
 Temp[4] = 7
Temp[7] = Constants
Temp[10] = 21
Stack[Temp[4]] = Temp[7][Temp[10]] 
elseif pointer == 62 then -- 1 [LOADK] 
 Temp[10] = 8
Temp[2] = Constants
Temp[8] = 22
Stack[Temp[10]] = Temp[2][Temp[8]] 
elseif pointer == 63 then -- 1 [LOADK] 
 Temp[14] = 9
Temp[1] = Constants
Temp[6] = 23
Stack[Temp[14]] = Temp[1][Temp[6]] 
elseif pointer == 64 then -- 1 [LOADK] 
 Temp[14] = 10
Temp[5] = Constants
Temp[2] = 5
Stack[Temp[14]] = Temp[5][Temp[2]]
	Temp[2] = {Stack[6](Stack[7], Stack[8], Stack[9], Stack[10])}
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
elseif pointer == 66 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 5 + 1, top do
		Temp[1][i - 5] = Stack[i]
	end
	Temp[2] = {Stack[5](unpack(Temp[1], 1, top - 5))}
		for i = 1, 0 do
		Stack[5 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 67 then -- 30 [RETURN] 
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