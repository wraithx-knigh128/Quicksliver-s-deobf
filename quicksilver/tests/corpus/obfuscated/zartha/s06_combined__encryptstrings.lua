return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env[decrypt("\066\067\070\090\095\080", "1743")][decrypt("\082\093\087\065", "1563")],Env[decrypt("\066\065\075\089\095\082", "1590")][decrypt("\080\074\069\093", "2318")],Env[decrypt("\066\070\065\095\095\085", "1236")][decrypt("\065\077\082", "2806")],Env[decrypt("\067\088\065\067\069\091\089\080", "772")],Env[decrypt("\065\084\088\093\093", "1791")],Env[decrypt("\069\086\082\094\084", "1702")][decrypt("\071\087\064\084\081\082", "2905")] or Env[decrypt("\065\088\068\085\085\095", "464")],Env[decrypt("\069\084\080\092\084", "1520")][decrypt("\081\086\091\081\083\077", "2952")],Env[decrypt("\070\094\095\068\095\083\084\067", "2111")],Env[decrypt("\066\093\066\091\084\076\087\066\080\090\090\083", "1866")],decrypt("\109\102\092\093\070\088\069\089\080\085\084", "2918"),decrypt("\104\103\094\089\092\082\079", "787"),Env[decrypt("\090\092\065\068\075\089\076\064", "496")],Env[decrypt("\066\075\095\092\070", "2962")],{(decrypt("\088\086\073\106", "2686")),(decrypt("\106\090\104\105", "2341")),(decrypt("\084\085\086\051", "1555")),(decrypt("\024\059", "2023")),(decrypt("\009\098\106\105\086\083", "1805")),(decrypt("\019\056", "834")),(decrypt("\085\084\088\108", "2823")),(decrypt("\087\107\091", "2759")),(decrypt("\027\056", "2332")),(decrypt("\086\094\082", "1859")),(decrypt("\009\109\111\095\090\110\106\105\092", "617")),(decrypt("\106\106\090\107\088\086\105\109", "1601")),(decrypt("\088\105\083\083\110\094\096\092\106\108\091\107", "2587")),(decrypt("\115\085\083\094\082\092\105", "2979")),(decrypt("\097\097\085\107\082", "776")),(decrypt("\097\097\088\082\108\100\088", "778")),(decrypt("\111\115\000\004\121\115\003\013\114\005\014", "959")),(decrypt("\021\051", "2803")),(decrypt("\094\081\081\092\083", "981")),(decrypt("\124\086\032\110\108\020\032\086\094\032\085\081\092\039\092\081\039\110\107\019\032\092\111\111\092\039\087\093\039\092\104\108\032\095\092\107\093\091\087\081\085\006\032\091\081\032\105\107\032\094\087\093\108\032\087\090\032\092\086\032\110\108", "707")),(decrypt("\104\091\082\110", "1847")),},Env[decrypt("\066\088\095\064\074", "296")],decrypt("\109\102\094\087\078\089\092\093\085\074", "290"),Env[decrypt("\089\082\079\067", "777")],decrypt("\028", "2812"),Env[decrypt("\065\065\067\090\092\082", "2513")][decrypt("\085\075\068\084", "2816")],decrypt("\066\070\066\088\092\087", "120"),Env[decrypt("\065\076\065\080\092\095", "2839")][decrypt("\084\081\090\087", "2843")],Env[decrypt("\066\082\084\090\086", "636")][decrypt("\084\090\093\083", "2337")] or function(targetTable, value)
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
elseif pointer == 3 then -- 10 [NEWTABLE] 
 	Stack[0] = {} 
elseif pointer == 4 then -- 9 [SETTABLE] 
 	Stack[0][Constants[16]] = Stack[0] 
elseif pointer == 5 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\084\089\081\090", "1529")),(decrypt("\084\107\080\109", "134")),(decrypt("\118\093\088\092\105\093\072", "1488")),(decrypt("\116\109\090\090\088\110\082", "116")),(decrypt("\121\082\104\091", "2229")),(decrypt("\115\086\066\101", "963")),(decrypt("\088\104\083\083\110\095\096\092\106\109\091\107", "2487")),(decrypt("\116\119\120\113\116\117\121", "2031")),}

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
		if pointer == 1 then -- 5 [GETGLOBAL] 
 Temp[12] = 1
Temp[5] = 7
Temp[14] = Constants[Temp[5]]
Stack[Temp[12]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 2 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 3 then -- 9 [SETTABLE] 
 	Stack[2][Constants[2]] = Stack[0] 
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
 
elseif pointer == 7 then -- 9 [SETTABLE] 
 	Stack[0][Constants[8]] = Stack[1] 
elseif pointer == 8 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\042\021\031\107", "606")),(decrypt("\009\099\099\110\091\083\046\105\109\092\089\110\106", "1992")),(decrypt("\121\106\094\092\120\106\088\090\082\108\109", "2617")),((decrypt("\025\021\027\031", "1224"))),(decrypt("\082\097\085\107", "791")),(decrypt("\091\095\090\082\084\106", "1432")),(decrypt("\009\010\118\015\121\010", "2653")),(decrypt("\096\091\105\096", "825")),(decrypt("\037\086\082\091\109\047\106\089\110\096\037", "2820")),(decrypt("\111\080\094\084\106\093", "2670")),}

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
		if pointer == 1 then -- 6 [GETTABLE] 
 	Stack[1] = Stack[0][Constants[5]]
	 
elseif pointer == 2 then -- 1 [LOADK] 
 Temp[16] = 2
Temp[4] = Constants
Temp[12] = 9
Stack[Temp[16]] = Temp[4][Temp[12]] 
elseif pointer == 3 then -- 5 [GETGLOBAL] 
 Temp[11] = 3
Temp[16] = 6
Temp[9] = Constants[Temp[16]]
Stack[Temp[11]] = vmEnv[Temp[9]] or Env[Temp[9]]
	Stack[3] = Stack[3][Constants[10]]
	
	pointer = pointer + 1 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[6] = 4
Temp[10] = Constants
Temp[15] = 1
Stack[Temp[6]] = Temp[10][Temp[15]] 
elseif pointer == 6 then -- 11 [SELF] 
 	Stack[6] = Stack[0]
	if Stack[6] then
		Stack[5] = Stack[0][Constants[8]]
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
 
elseif pointer == 9 then -- 9 [SETTABLE] 
 	Stack[0][Constants[12]] = Stack[1] 
elseif pointer == 10 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\123\094\084\083\082\087\111", "2216")),(decrypt("\015\082\107\091\105\116\106\117\082\110\089", "2278")),(decrypt("\012\081\080\093\088\106\110\091", "680")),(decrypt("\022\057", "1208")),(decrypt("\015\100\082\115\088\088\093\108\088\072\126\108\088\083\003\009\088\096\093\104", "1894")),}

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
	
	Stack[1] = function(...) -- PROTOTYPE 3
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
 Temp[10] = 1
Temp[2] = Constants
Temp[8] = 4
Stack[Temp[10]] = Temp[2][Temp[8]] 
elseif pointer == 2 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 3 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 11 then -- 9 [SETTABLE] 
 	Stack[0][Constants[2]] = Stack[1] 
elseif pointer == 12 then -- 5 [GETGLOBAL] 
 Temp[10] = 1
Temp[4] = 13
Temp[13] = Constants[Temp[4]]
Stack[Temp[10]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 13 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 14 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 15 then -- 9 [SETTABLE] 
 	Stack[3][Constants[16]] = Stack[0] 
elseif pointer == 16 then -- 28 [CALL] 
 	Stack[1] = Stack[1](Stack[2], Stack[3]) 
elseif pointer == 17 then -- 9 [SETTABLE] 
 	Stack[1][Constants[16]] = Stack[1] 
elseif pointer == 18 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\008\080\109\088\088\118\109\086\110", "2352")),(decrypt("\119\119\124\119\119\117\125", "1077")),((decrypt("\024\017\030\019\026\024\006\017\031\024\028\020\002", "2468"))),(decrypt("\014\081\103\110", "119")),(decrypt("\111\085\094\111\086\107", "557")),(decrypt("\088\105\095\086\110\094\108\089\106\108\087\110", "2542")),(decrypt("\121\110\092\093", "2236")),(decrypt("\087\107\093", "2735")),(decrypt("\091\106\105\082\094\088", "222")),(decrypt("\112\104\104\084\088\087", "443")),}

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
	
	Stack[2] = function(...) -- PROTOTYPE 4
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
 	Stack[1] = Upvalues[0] 
elseif pointer == 2 then -- 6 [GETTABLE] 
 	Stack[1] = Stack[1][Constants[8]]
	 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[9] = 2
Temp[11] = Constants
Temp[12] = 5
Stack[Temp[9]] = Temp[11][Temp[12]]
	Stack[1] = Stack[1](Stack[2])
	pointer = pointer + 1 
elseif pointer == 5 then -- 9 [SETTABLE] 
 	Stack[1][Constants[9]] = Stack[0] 
elseif pointer == 6 then -- 5 [GETGLOBAL] 
 Temp[10] = 2
Temp[2] = 6
Temp[8] = Constants[Temp[2]]
Stack[Temp[10]] = vmEnv[Temp[8]] or Env[Temp[8]] 
elseif pointer == 7 then -- 0 [MOVE] 
 Temp[8] = 3
Temp[14] = 1
Stack[Temp[8]] = Stack[Temp[14]] 
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
 
elseif pointer == 21 then -- 9 [SETTABLE] 
 	Stack[1][Constants[8]] = Stack[2] 
elseif pointer == 22 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {(decrypt("\121\083\108\092\121\085\082\085\091\127\101\089\088\089\106\105", "590")),(decrypt("\085\087", "2736")),(decrypt("\024\060", "1755")),(decrypt("\011\083\084\083\104\080\081\105", "1047")),(decrypt("\118\084\082\083\109\088", "2278")),(decrypt("\093\097\090\102", "991")),(decrypt("\094\096\105\087\084\088", "782")),((decrypt("\031\017\025\031\024\028\031", "2400"))),}

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
	
	Stack[2] = function(...) -- PROTOTYPE 5
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
 Temp[7] = 1
Temp[13] = 6
Temp[3] = Constants[Temp[13]]
Stack[Temp[7]] = vmEnv[Temp[3]] or Env[Temp[3]]
	Stack[1] = Stack[1][Constants[2]]
	
	pointer = pointer + 1 
elseif pointer == 3 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[7]]
	 
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
 
elseif pointer == 23 then -- 9 [SETTABLE] 
 	Stack[1][Constants[2]] = Stack[2] 
elseif pointer == 24 then -- 5 [GETGLOBAL] 
 Temp[2] = 2
Temp[15] = 13
Temp[6] = Constants[Temp[15]]
Stack[Temp[2]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 25 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 26 then -- 10 [NEWTABLE] 
 	Stack[4] = {} 
elseif pointer == 27 then -- 9 [SETTABLE] 
 	Stack[4][Constants[16]] = Stack[0] 
elseif pointer == 28 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3], Stack[4]) 
elseif pointer == 29 then -- 9 [SETTABLE] 
 	Stack[2][Constants[16]] = Stack[2] 
elseif pointer == 30 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[6] then
		C1 = {}
		local encoded = {(decrypt("\105\111\085\104\108\094", "635")),(decrypt("\084\107\086", "1783")),(decrypt("\089\082\105\092\109", "722")),(decrypt("\090\101\098\088", "398")),(decrypt("\122\095\106\106\084\118\080\092\081\090\086\080\084", "1166")),(decrypt("\008\085\081\089\111\081\089\023\127\066\084\104", "234")),(decrypt("\124\086\093", "666")),(decrypt("\088\100\091\086\110\083\104\089\106\097\083\110", "2802")),}

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
	
	Stack[3] = function(...) -- PROTOTYPE 6
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 0}, [1] = {0, 2}}
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
 	Stack[2] = Stack[2][Constants[2]]
	 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[4] = 3
Temp[2] = Constants
Temp[9] = 4
Stack[Temp[4]] = Temp[2][Temp[9]]
	Stack[2] = Stack[2](Stack[3])
	pointer = pointer + 1 
elseif pointer == 5 then -- 0 [MOVE] 
 Temp[9] = 3
Temp[14] = 0
Stack[Temp[9]] = Stack[Temp[14]] 
elseif pointer == 6 then -- 9 [SETTABLE] 
 	Stack[2][Constants[1]] = Stack[1] 
elseif pointer == 7 then -- 9 [SETTABLE] 
 	Stack[2][Constants[3]] = Stack[3] 
elseif pointer == 8 then -- 5 [GETGLOBAL] 
 Temp[13] = 3
Temp[4] = 8
Temp[11] = Constants[Temp[4]]
Stack[Temp[13]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 9 then -- 0 [MOVE] 
 Temp[9] = 4
Temp[2] = 2
Stack[Temp[9]] = Stack[Temp[2]] 
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
 
elseif pointer == 33 then -- 9 [SETTABLE] 
 	Stack[2][Constants[8]] = Stack[3] 
elseif pointer == 34 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[7] then
		C1 = {}
		local encoded = {((decrypt("\026\016\031\028\018\028", "253"))),(decrypt("\110\100\088\109\110\083", "1883")),(decrypt("\120\109\089\088\082\087\086\037\110\094\084\082\091\109\104", "2132")),(decrypt("\093\083\111\088\108", "334")),(decrypt("\098", "2419")),}

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
	
	Stack[3] = function(...) -- PROTOTYPE 7
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
 	Stack[1] = Stack[0][Constants[4]]
	 
elseif pointer == 2 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[2]]
	 
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
 
elseif pointer == 35 then -- 9 [SETTABLE] 
 	Stack[2][Constants[2]] = Stack[3] 
elseif pointer == 36 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 37 then -- 9 [SETTABLE] 
 	Stack[3][Constants[16]] = Stack[3] 
elseif pointer == 38 then -- 9 [SETTABLE] 
 	Stack[3][Constants[15]] = Constants[3] 
elseif pointer == 39 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[8] then
		C1 = {}
		local encoded = {(decrypt("\021\061", "2687")),(decrypt("\026\061", "2644")),(decrypt("\009\109\087\108\066", "2144")),(decrypt("\094\106\082\080\106\082\108\093\097\109\085\101", "469")),(decrypt("\123\088\105\089\090\111\088\119\082\107\065\108\088", "1310")),(decrypt("\081\107\094\082", "2349")),(decrypt("\108\086\091\082\090", "1628")),(decrypt("\117\104\093\081\109\091\083\080\105\106\104\121\109\089\089\083\107\108", "1043")),(decrypt("\081\090\106\087\091", "1163")),}

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
	
	Stack[4] = function(...) -- PROTOTYPE 8
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 3}}
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
Temp[4] = 4
Temp[15] = Constants[Temp[4]]
Stack[Temp[12]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 2 then -- 10 [NEWTABLE] 
 	Stack[1] = {} 
elseif pointer == 3 then -- 9 [SETTABLE] 
 	Stack[1][Constants[7]] = Constants[2] 
elseif pointer == 4 then -- 9 [SETTABLE] 
 	Stack[1][Constants[6]] = Constants[1] 
elseif pointer == 5 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 6 then -- 9 [SETTABLE] 
 	Stack[1][Constants[9]] = Stack[2] 
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
 
elseif pointer == 41 then -- 9 [SETTABLE] 
 	Stack[3][Constants[8]] = Stack[4] 
elseif pointer == 42 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[9] then
		C1 = {}
		local encoded = {(decrypt("\081\096\083\093", "2896")),(decrypt("\025\058", "1144")),(decrypt("\081\088\111\082\091", "1336")),(decrypt("\118\091\111\070\109\081\093", "1876")),((decrypt("\021\020\027", "2136"))),}

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
	
	Stack[4] = function(...) -- PROTOTYPE 9
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
 	Stack[2] = Stack[0][Constants[1]]
	 
elseif pointer == 2 then -- 12 [ADD] 
 	Stack[2] = Stack[2] + Constants[2] 
elseif pointer == 3 then -- 9 [SETTABLE] 
 	Stack[0][Constants[1]] = Stack[2] 
elseif pointer == 4 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[3]]
	 
elseif pointer == 5 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[0][Constants[1]]
	 
elseif pointer == 6 then -- 9 [SETTABLE] 
 	Stack[2][Stack[3]] = Stack[1] 
elseif pointer == 7 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 43 then -- 9 [SETTABLE] 
 	Stack[3][Constants[7]] = Stack[4] 
elseif pointer == 44 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[10] then
		C1 = {}
		local encoded = {(decrypt("\082\095\100\086\088", "2482")),(decrypt("\009\101\089\109\110\092\104\111\087\082\011\108\105\101\104", "2937")),(decrypt("\116\095\087\106", "1926")),(decrypt("\084\086\082\054", "1610")),(decrypt("\107\088\091\092\083", "682")),(decrypt("\123\089\082\082\085\087\087\104", "1726")),(decrypt("\025\050", "1927")),(decrypt("\085\107\091\093", "631")),((decrypt("\025\031\024", "1679"))),}

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
	
	Stack[4] = function(...) -- PROTOTYPE 10
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
 	Stack[2] = Stack[0][Constants[8]]
	 
elseif pointer == 3 then -- 24 [LT] 
 	if Stack[2] < Stack[1] then pointer = pointer + 1 end 
elseif pointer == 4 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 5 then -- 3 [LOADNIL] 
 	Stack[1], Stack[2] = nil 
elseif pointer == 6 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 7 then -- 6 [GETTABLE] 
 	Stack[1] = Stack[0][Constants[1]]
	 
elseif pointer == 8 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[5]]
	 
elseif pointer == 9 then -- 6 [GETTABLE] 
 	Stack[1] = Stack[1][Stack[2]]
	 
elseif pointer == 10 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[1]]
	 
elseif pointer == 11 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[0][Constants[5]]
	 
elseif pointer == 12 then -- 9 [SETTABLE] 
 	Stack[2][Stack[3]] = Constants[4] 
elseif pointer == 13 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[5]]
	 
elseif pointer == 14 then -- 12 [ADD] 
 	Stack[2] = Stack[2] + Constants[7] 
elseif pointer == 15 then -- 9 [SETTABLE] 
 	Stack[0][Constants[5]] = Stack[2] 
elseif pointer == 16 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 17 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 45 then -- 9 [SETTABLE] 
 	Stack[3][Constants[10]] = Stack[4] 
elseif pointer == 46 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[11] then
		C1 = {}
		local encoded = {(decrypt("\081\109\090\089", "2502")),(decrypt("\108\089\093\089\090", "1943")),(decrypt("\026\060", "2799")),(decrypt("\113\082\093\111\088\087\104\082\090\032\093\087\087\084\104\092\109\108", "1707")),(decrypt("\114\082\083\093\089\014\104\111\106\082", "2741")),(decrypt("\105\111\090\090\085\087", "939")),}

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
	
	Stack[4] = function(...) -- PROTOTYPE 11
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
 	Stack[2] = Stack[0][Constants[2]]
	 
elseif pointer == 3 then -- 13 [SUB] 
 	Stack[1] = Stack[1] - Stack[2] 
elseif pointer == 4 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Constants[3] 
elseif pointer == 5 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 6 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 47 then -- 9 [SETTABLE] 
 	Stack[3][Constants[1]] = Stack[4] 
elseif pointer == 48 then -- 6 [GETTABLE] 
 	Stack[4] = Stack[3][Constants[8]]
	
	Stack[4] = Stack[4]()
	pointer = pointer + 1 
elseif pointer == 50 then -- 11 [SELF] 
 	Stack[6] = Stack[4]
	if Stack[6] then
		Stack[5] = Stack[4][Constants[7]]
	end
	 
elseif pointer == 51 then -- 6 [GETTABLE] 
 	Stack[7] = Stack[1][Constants[8]]
	 
elseif pointer == 52 then -- 1 [LOADK] 
 Temp[6] = 8
Temp[14] = Constants
Temp[5] = 9
Stack[Temp[6]] = Temp[14][Temp[5]]
	Temp[2] = {Stack[7](Stack[8])}
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
elseif pointer == 54 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 5 + 1, top do
		Temp[1][i - 5] = Stack[i]
	end
	Temp[2] = {Stack[5](unpack(Temp[1], 1, top - 5))}
		for i = 1, 0 do
		Stack[5 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 55 then -- 11 [SELF] 
 	Stack[6] = Stack[4]
	if Stack[6] then
		Stack[5] = Stack[4][Constants[7]]
	end
	 
elseif pointer == 56 then -- 6 [GETTABLE] 
 	Stack[7] = Stack[2][Constants[8]]
	 
elseif pointer == 57 then -- 1 [LOADK] 
 Temp[3] = 8
Temp[7] = Constants
Temp[11] = 4
Stack[Temp[3]] = Temp[7][Temp[11]] 
elseif pointer == 58 then -- 1 [LOADK] 
 Temp[5] = 9
Temp[7] = Constants
Temp[15] = 6
Stack[Temp[5]] = Temp[7][Temp[15]]
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
elseif pointer == 60 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 5 + 1, top do
		Temp[1][i - 5] = Stack[i]
	end
	Temp[2] = {Stack[5](unpack(Temp[1], 1, top - 5))}
		for i = 1, 0 do
		Stack[5 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 61 then -- 11 [SELF] 
 	Stack[6] = Stack[4]
	if Stack[6] then
		Stack[5] = Stack[4][Constants[7]]
	end
	 
elseif pointer == 62 then -- 6 [GETTABLE] 
 	Stack[7] = Stack[0][Constants[8]]
	 
elseif pointer == 63 then -- 1 [LOADK] 
 Temp[9] = 8
Temp[12] = Constants
Temp[14] = 21
Stack[Temp[9]] = Temp[12][Temp[14]]
	Temp[2] = {Stack[7](Stack[8])}
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
elseif pointer == 65 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 5 + 1, top do
		Temp[1][i - 5] = Stack[i]
	end
	Temp[2] = {Stack[5](unpack(Temp[1], 1, top - 5))}
		for i = 1, 0 do
		Stack[5 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 66 then -- 11 [SELF] 
 	Stack[6] = Stack[4]
	if Stack[6] then
		Stack[5] = Stack[4][Constants[1]]
	end
	 
elseif pointer == 67 then -- 28 [CALL] 
 	Stack[5] = Stack[5](Stack[6]) 
elseif pointer == 68 then -- 24 [LT] 
 	if Constants[18] < Stack[5] then pointer = pointer + 1 end 
elseif pointer == 69 then -- 22 [JMP] 
 pointer = pointer + 7  
elseif pointer == 70 then -- 5 [GETGLOBAL] 
 Temp[14] = 5
Temp[15] = 19
Temp[7] = Constants[Temp[15]]
Stack[Temp[14]] = vmEnv[Temp[7]] or Env[Temp[7]] 
elseif pointer == 71 then -- 11 [SELF] 
 	Stack[7] = Stack[4]
	if Stack[7] then
		Stack[6] = Stack[4][Constants[10]]
	end
	 
elseif pointer == 72 then -- 28 [CALL] 
 	Stack[6] = Stack[6](Stack[7]) 
elseif pointer == 73 then -- 11 [SELF] 
 	Stack[7] = Stack[6]
	if Stack[7] then
		Stack[6] = Stack[6][Constants[12]]
	end
	 
elseif pointer == 74 then -- 28 [CALL] 
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
	 
elseif pointer == 75 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 5 + 1, top do
		Temp[1][i - 5] = Stack[i]
	end
	Temp[2] = {Stack[5](unpack(Temp[1], 1, top - 5))}
		for i = 1, 0 do
		Stack[5 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 76 then -- 22 [JMP] 
 pointer = pointer + -11  
elseif pointer == 77 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[12] then
		C1 = {}
		local encoded = {(decrypt("\084\094\088\107\081", "786")),((decrypt("\025\002\027\017\024", "1264"))),(decrypt("\104\080\080\104\106\093", "2652")),(decrypt("\046\104\021", "2071")),(decrypt("\109\085\105\088\107\110", "311")),(decrypt("\017\038", "2153")),(decrypt("\085\104\090\108", "1013")),(decrypt("\025\058", "110")),(decrypt("\124\106\084\094\095\064\047\109\092\092\081", "860")),(decrypt("\080\109\083\094\095", "753")),(decrypt("\082\108\096\090\104", "949")),(decrypt("\085\088\086", "1838")),(decrypt("\115\087\102\092\111\083\085\094\100\046\087\093\084\111\091\089\108", "978")),(decrypt("\088\082\094\089", "2472")),(decrypt("\027\056", "1330")),(decrypt("\021\059", "2057")),(decrypt("\003", "2988")),}

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
	
	Stack[5] = function(...) -- PROTOTYPE 12
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
		Stack[2] = Stack[0][Constants[1]]
	end
	 
elseif pointer == 3 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3]) 
elseif pointer == 4 then -- 11 [SELF] 
 	Stack[3] = Stack[2]
	if Stack[3] then
		Stack[2] = Stack[2][Constants[5]]
	end
	 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[9] = 4
Temp[14] = Constants
Temp[3] = 4
Stack[Temp[9]] = Temp[14][Temp[3]]
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
 Temp[4] = 6
Temp[10] = Constants
Temp[9] = 16
Stack[Temp[4]] = Temp[10][Temp[9]] 
elseif pointer == 12 then -- 12 [ADD] 
 	Stack[6] = Stack[6] + Constants[8] 
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
 Temp[9] = 3
Temp[15] = 10
Temp[1] = Constants[Temp[15]]
Stack[Temp[9]] = vmEnv[Temp[1]] or Env[Temp[1]] 
elseif pointer == 18 then -- 0 [MOVE] 
 Temp[6] = 4
Temp[10] = 1
Stack[Temp[6]] = Stack[Temp[10]] 
elseif pointer == 19 then -- 28 [CALL] 
 	Stack[3], Stack[4], Stack[5] = Stack[3](Stack[4]) 
elseif pointer == 20 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 21 then -- 20 [LEN] 
 	Stack[7] = #Stack[2] 
elseif pointer == 22 then -- 12 [ADD] 
 	Stack[7] = Stack[7] + Constants[8] 
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
 Temp[8] = 3
Temp[13] = 11
Temp[4] = Constants[Temp[13]]
Stack[Temp[8]] = vmEnv[Temp[4]] or Env[Temp[4]]
	Stack[3] = Stack[3][Constants[14]]
	
	pointer = pointer + 1 
elseif pointer == 28 then -- 0 [MOVE] 
 Temp[12] = 4
Temp[3] = 2
Stack[Temp[12]] = Stack[Temp[3]] 
elseif pointer == 29 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[13] then
		C1 = {}
		local encoded = {(decrypt("\008\106\083\100\028\025", "1298")),((decrypt("\027\018\019\020\018", "354"))),}

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
	
	Stack[5] = function(...) -- PROTOTYPE 13
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
 Temp[4] = 2
Temp[10] = byte == pairs
Stack[Temp[4]] = Temp[3]\n\tpointer = pointer + 1 
elseif pointer == 14 then -- 2 [LOADBOOL] 
 Temp[10] = 2
Temp[14] = ttostring ~= __metatable
Stack[Temp[10]] = Temp[16] 
elseif pointer == 15 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 16 then -- 24 [LT] 
 	if Stack[0] > Stack[1] then pointer = pointer + 1 end 
elseif pointer == 17 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 18 then -- 2 [LOADBOOL] 
 Temp[5] = 2
Temp[1] = byte == pairs
Stack[Temp[5]] = Temp[3]\n\tpointer = pointer + 1 
elseif pointer == 19 then -- 2 [LOADBOOL] 
 Temp[10] = 2
Temp[11] = ttostring ~= __metatable
Stack[Temp[10]] = Temp[7] 
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
 Temp[2] = 4
Temp[6] = Constants
Temp[4] = 8
Stack[Temp[2]] = Temp[6][Temp[4]] 
elseif pointer == 34 then -- 5 [GETGLOBAL] 
 Temp[13] = 5
Temp[11] = 7
Temp[4] = Constants[Temp[11]]
Stack[Temp[13]] = vmEnv[Temp[4]] or Env[Temp[4]]
	Stack[5] = Stack[5][Constants[12]]
	
	pointer = pointer + 1 
elseif pointer == 36 then -- 1 [LOADK] 
 Temp[1] = 6
Temp[15] = Constants
Temp[9] = 15
Stack[Temp[1]] = Temp[15][Temp[9]] 
elseif pointer == 37 then -- 20 [LEN] 
 	Stack[7] = #Stack[2] 
elseif pointer == 38 then -- 28 [CALL] 
 	Stack[5] = Stack[5](Stack[6], Stack[7]) 
elseif pointer == 39 then -- 1 [LOADK] 
 Temp[11] = 6
Temp[4] = Constants
Temp[6] = 8
Stack[Temp[11]] = Temp[4][Temp[6]] 
elseif pointer == 40 then -- 32 [FORPREP] 
     Stack[4] = Stack[4] - Stack[6]
    pointer = pointer + 8
     
elseif pointer == 41 then -- 20 [LEN] 
 	Stack[8] = #Stack[3] 
elseif pointer == 42 then -- 12 [ADD] 
 	Stack[8] = Stack[8] + Constants[8] 
elseif pointer == 43 then -- 6 [GETTABLE] 
 	Stack[9] = Stack[2][Stack[7]]
	 
elseif pointer == 44 then -- 1 [LOADK] 
 Temp[2] = 10
Temp[15] = Constants
Temp[6] = 17
Stack[Temp[2]] = Temp[15][Temp[6]] 
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
 Temp[10] = 4
Temp[13] = 11
Temp[8] = Constants[Temp[13]]
Stack[Temp[10]] = vmEnv[Temp[8]] or Env[Temp[8]]
	Stack[4] = Stack[4][Constants[3]]
	
	pointer = pointer + 1 
elseif pointer == 52 then -- 0 [MOVE] 
 Temp[14] = 5
Temp[6] = 3
Stack[Temp[14]] = Stack[Temp[6]] 
elseif pointer == 53 then -- 1 [LOADK] 
 Temp[1] = 6
Temp[6] = Constants
Temp[5] = 6
Stack[Temp[1]] = Temp[6][Temp[5]] 
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
 
elseif pointer == 78 then -- 5 [GETGLOBAL] 
 Temp[7] = 6
Temp[4] = 19
Temp[11] = Constants[Temp[4]]
Stack[Temp[7]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 79 then -- 0 [MOVE] 
 Temp[7] = 7
Temp[10] = 5
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 80 then -- 1 [LOADK] 
 Temp[14] = 8
Temp[12] = Constants
Temp[15] = 20
Stack[Temp[14]] = Temp[12][Temp[15]]
	Temp[2] = {Stack[7](Stack[8])}
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
elseif pointer == 82 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 6 + 1, top do
		Temp[1][i - 6] = Stack[i]
	end
	Temp[2] = {Stack[6](unpack(Temp[1], 1, top - 6))}
		for i = 1, 0 do
		Stack[6 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 83 then -- 30 [RETURN] 
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