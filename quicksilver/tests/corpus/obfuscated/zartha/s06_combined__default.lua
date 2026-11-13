return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\088\100\088\093\110\083\107\082\106\097\080\101", "2839")),(decrypt("\024\051", "2843")),(decrypt("\096\101\086\083\104\106\089", "636")),(decrypt("\085\090\083\082\089", "2337")),(decrypt("\106\093\106\108", "2464")),(decrypt("\027\057", "2280")),(decrypt("\094\086\087", "900")),(decrypt("\014\012\013\008", "1053")),(decrypt("\104\086\095\097", "1598")),(decrypt("\021\059", "2037")),(decrypt("\007\009\001\003", "859")),(decrypt("\124\106\087\091\015\084\094\010\109\082\084\107", "2270")),(decrypt("\110\100\084\100\087", "827")),(decrypt("\025\063", "2461")),(decrypt("\105\109\093\111\091\081\110\105", "2175")),(decrypt("\011\082\089\086\104\081\092\108", "1192")),(decrypt("\114\094\038\096\100\018\046\094\088\046\093\087\082\047\090\095\047\104\101\027\038\082\103\105\082\047\081\083\047\090\102\100\038\081\084\109\083\083\081\095\093\000\046\083\087\046\097\109\046\086\081\083\100\038\089\082\038\082\094\038\096\100", "981")),(decrypt("\087\109\092", "2127")),(decrypt("\086\080\081\053", "302")),(decrypt("\100\113\013\005\126\125\014\000\121\011\015", "2748")),(decrypt("\088\080\069\105", "2045")),(decrypt("\094\085\090\102", "990")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
 Temp[1] = 0
Temp[11] = ttostring ~= __metatable
Stack[Temp[1]] = Temp[6] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[2] = vmEnv
Temp[15] = 20
Temp[5] = Constants[Temp[15]]
Temp[16] = 0
Temp[2][Temp[5]] = Temp[5] 
elseif pointer == 3 then -- 10 [NEWTABLE] 
 	Stack[0] = {} 
elseif pointer == 4 then -- 9 [SETTABLE] 
 	Stack[0][Constants[3]] = Stack[0] 
elseif pointer == 5 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\011\095\080\106\118\097\099\084\105\103\101\092", "1996")),(decrypt("\125\109\084\095\088\064\046\106\092\093\086", "910")),(decrypt("\091\111\088\081\109\088\107\094\105\106\080\105", "1335")),(decrypt("\008\105\111\086\108\106\108", "2673")),(decrypt("\010\105\097\084\111\034\092\094\106\105\047\100\084\109\097\091\109\110", "1588")),(decrypt("\087\105\093\105", "2195")),(decrypt("\008\082\081\086\105\082\089\080", "2475")),}

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
 Temp[14] = 1
Temp[15] = 3
Temp[7] = Constants[Temp[15]]
Stack[Temp[14]] = vmEnv[Temp[7]] or Env[Temp[7]] 
elseif pointer == 2 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 3 then -- 9 [SETTABLE] 
 	Stack[2][Constants[6]] = Stack[0] 
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
 	Stack[0][Constants[18]] = Stack[1] 
elseif pointer == 8 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\037\089\080\094\109\032\104\092\110\111\039", "2705")),((decrypt("\025\019\021", "2424"))),(decrypt("\088\088\080\085\087\109", "2395")),((decrypt("\031\017\027\030\028\031\005\029\030\025\030\031\005", "543"))),(decrypt("\106\081\109\097", "2819")),(decrypt("\106\087\081\083\105\083", "718")),(decrypt("\123\092\097\099\083\032\082\080\105\109\101", "1799")),(decrypt("\117\096\088\087\109\083\086\086\105\098\109\127\109\081\092\085\107\100", "1815")),(decrypt("\045\016\027\100", "1529")),(decrypt("\084\107\080\109", "134")),}

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
 	Stack[1] = Stack[0][Constants[10]]
	 
elseif pointer == 2 then -- 1 [LOADK] 
 Temp[8] = 2
Temp[1] = Constants
Temp[12] = 1
Stack[Temp[8]] = Temp[1][Temp[12]] 
elseif pointer == 3 then -- 5 [GETGLOBAL] 
 Temp[5] = 3
Temp[14] = 3
Temp[11] = Constants[Temp[14]]
Stack[Temp[5]] = vmEnv[Temp[11]] or Env[Temp[11]]
	Stack[3] = Stack[3][Constants[6]]
	
	pointer = pointer + 1 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[12] = 4
Temp[5] = Constants
Temp[14] = 9
Stack[Temp[12]] = Temp[5][Temp[14]] 
elseif pointer == 6 then -- 11 [SELF] 
 	Stack[6] = Stack[0]
	if Stack[6] then
		Stack[5] = Stack[0][Constants[5]]
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
 	Stack[0][Constants[15]] = Stack[1] 
elseif pointer == 10 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\119\093\126\104\088\085\104\093\013\085\104\081\090", "1844")),(decrypt("\013\094\085\090\082", "473")),(decrypt("\113\087\086\093\090\014\084\106\109\105", "1211")),(decrypt("\123\085\106\092\105\094\088\080\109\034\084\092\092\109\087\089\106", "1549")),(decrypt("\021\060", "2798")),}

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
 Temp[3] = 1
Temp[11] = Constants
Temp[14] = 5
Stack[Temp[3]] = Temp[11][Temp[14]] 
elseif pointer == 2 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 3 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 11 then -- 9 [SETTABLE] 
 	Stack[0][Constants[5]] = Stack[1] 
elseif pointer == 12 then -- 5 [GETGLOBAL] 
 Temp[14] = 1
Temp[6] = 1
Temp[15] = Constants[Temp[6]]
Stack[Temp[14]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 13 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 14 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 15 then -- 9 [SETTABLE] 
 	Stack[3][Constants[3]] = Stack[0] 
elseif pointer == 16 then -- 28 [CALL] 
 	Stack[1] = Stack[1](Stack[2], Stack[3]) 
elseif pointer == 17 then -- 9 [SETTABLE] 
 	Stack[1][Constants[3]] = Stack[1] 
elseif pointer == 18 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\084\101\086", "1986")),(decrypt("\118\096\095\094\084\093", "2868")),(decrypt("\118\094\084\094\110", "2884")),(decrypt("\107\085\095\099\082\105", "1569")),((decrypt("\026\022\025", "1129"))),(decrypt("\088\097\106\081\093\083", "1911")),(decrypt("\088\107\082\085\110\092\097\090\106\110\090\109", "2791")),}

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
 	Stack[1] = Stack[1][Constants[1]]
	 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[10] = 2
Temp[16] = Constants
Temp[4] = 4
Stack[Temp[10]] = Temp[16][Temp[4]]
	Stack[1] = Stack[1](Stack[2])
	pointer = pointer + 1 
elseif pointer == 5 then -- 9 [SETTABLE] 
 	Stack[1][Constants[6]] = Stack[0] 
elseif pointer == 6 then -- 5 [GETGLOBAL] 
 Temp[11] = 2
Temp[12] = 7
Temp[4] = Constants[Temp[12]]
Stack[Temp[11]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 7 then -- 0 [MOVE] 
 Temp[14] = 3
Temp[1] = 1
Stack[Temp[14]] = Stack[Temp[1]] 
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
 	Stack[1][Constants[18]] = Stack[2] 
elseif pointer == 22 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {(decrypt("\091\096\104\082\084\089", "283")),(decrypt("\012\085\083\084\091\106\106\111", "1564")),(decrypt("\092\101\092\093\089\082\104\083\097", "697")),(decrypt("\015\106\092\010\106\093\107\106\082\106\110\082\090\092", "167")),(decrypt("\024\056", "132")),(decrypt("\086\087", "1726")),(decrypt("\122\095\091\098\110\005\082\099\109\098", "1978")),(decrypt("\086\096\089\108", "2823")),(decrypt("\113\009\020", "528")),}

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
 Temp[11] = 1
Temp[3] = 8
Temp[13] = Constants[Temp[3]]
Stack[Temp[11]] = vmEnv[Temp[13]] or Env[Temp[13]]
	Stack[1] = Stack[1][Constants[6]]
	
	pointer = pointer + 1 
elseif pointer == 3 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[1]]
	 
elseif pointer == 4 then -- 17 [POW] 
 	Stack[2] = Stack[2] ^ Constants[5] 
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
 	Stack[1][Constants[5]] = Stack[2] 
elseif pointer == 24 then -- 5 [GETGLOBAL] 
 Temp[13] = 2
Temp[9] = 1
Temp[11] = Constants[Temp[9]]
Stack[Temp[13]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 25 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 26 then -- 10 [NEWTABLE] 
 	Stack[4] = {} 
elseif pointer == 27 then -- 9 [SETTABLE] 
 	Stack[4][Constants[3]] = Stack[0] 
elseif pointer == 28 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3], Stack[4]) 
elseif pointer == 29 then -- 9 [SETTABLE] 
 	Stack[2][Constants[3]] = Stack[2] 
elseif pointer == 30 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[6] then
		C1 = {}
		local encoded = {((decrypt("\021\023\019\026", "2242"))),(decrypt("\084\100\091", "1856")),(decrypt("\108\100\084\109\103\095", "384")),(decrypt("\095\088\109\093\110", "1866")),(decrypt("\091\101\091\086\109\082\104\089\105\096\083\110", "1902")),(decrypt("\088\104\107\089", "1412")),(decrypt("\127\108\093\081\081\081\106", "1444")),(decrypt("\008\080\086\089\110\089\088\010\104\093\083\084\087\124\111\091\095\086\105\110", "2632")),}

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
 Temp[9] = 3
Temp[16] = Constants
Temp[2] = 6
Stack[Temp[9]] = Temp[16][Temp[2]]
	Stack[2] = Stack[2](Stack[3])
	pointer = pointer + 1 
elseif pointer == 5 then -- 0 [MOVE] 
 Temp[9] = 3
Temp[16] = 0
Stack[Temp[9]] = Stack[Temp[16]] 
elseif pointer == 6 then -- 9 [SETTABLE] 
 	Stack[2][Constants[3]] = Stack[1] 
elseif pointer == 7 then -- 9 [SETTABLE] 
 	Stack[2][Constants[4]] = Stack[3] 
elseif pointer == 8 then -- 5 [GETGLOBAL] 
 Temp[11] = 3
Temp[3] = 5
Temp[15] = Constants[Temp[3]]
Stack[Temp[11]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 9 then -- 0 [MOVE] 
 Temp[13] = 4
Temp[14] = 2
Stack[Temp[13]] = Stack[Temp[14]] 
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
 	Stack[2][Constants[18]] = Stack[3] 
elseif pointer == 34 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[7] then
		C1 = {}
		local encoded = {((decrypt("\030\028\018\017\002\030\024", "2278"))),(decrypt("\102\101\081\103\102\090", "991")),(decrypt("\104\083\089\080\082\003\017\030", "782")),(decrypt("\092\084\107\091\109", "2400")),}

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
 	Stack[2][Constants[5]] = Stack[3] 
elseif pointer == 36 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 37 then -- 9 [SETTABLE] 
 	Stack[3][Constants[3]] = Stack[3] 
elseif pointer == 38 then -- 9 [SETTABLE] 
 	Stack[3][Constants[13]] = Constants[19] 
elseif pointer == 39 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[8] then
		C1 = {}
		local encoded = {(decrypt("\108\088\089\091\083", "180")),((decrypt("\031\031\025", "635"))),(decrypt("\123\092\094\084\086\107\099", "1783")),(decrypt("\125\082\089", "722")),(decrypt("\080\097\082\088", "398")),(decrypt("\022\058", "1166")),(decrypt("\026\056", "234")),(decrypt("\012\080\083\093\106\083\093\018\125\070\081\106", "666")),(decrypt("\082\083\108\086\088", "2802")),(decrypt("\093\110\094\083\110\094\111\089\109\110\081\105", "725")),}

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
 Temp[2] = 0
Temp[9] = 10
Temp[14] = Constants[Temp[9]]
Stack[Temp[2]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 2 then -- 10 [NEWTABLE] 
 	Stack[1] = {} 
elseif pointer == 3 then -- 9 [SETTABLE] 
 	Stack[1][Constants[1]] = Constants[7] 
elseif pointer == 4 then -- 9 [SETTABLE] 
 	Stack[1][Constants[5]] = Constants[6] 
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
 	Stack[3][Constants[18]] = Stack[4] 
elseif pointer == 42 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[9] then
		C1 = {}
		local encoded = {(decrypt("\009\114\002\115\113", "1883")),(decrypt("\120\109\089\088\082\087\086\037\110\094\084\082\091\109\104", "2132")),(decrypt("\083\088\104\087\089", "334")),((decrypt("\026\017\029\023\021\027", "2419"))),(decrypt("\090\105\094\082", "914")),(decrypt("\105", "956")),(decrypt("\120\080\105\086\087", "2718")),(decrypt("\025\050", "1981")),(decrypt("\011\083\097\091\091\117\097\085\109", "1091")),}

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
 	Stack[2] = Stack[0][Constants[5]]
	 
elseif pointer == 2 then -- 12 [ADD] 
 	Stack[2] = Stack[2] + Constants[8] 
elseif pointer == 3 then -- 9 [SETTABLE] 
 	Stack[0][Constants[5]] = Stack[2] 
elseif pointer == 4 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[3]]
	 
elseif pointer == 5 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[0][Constants[5]]
	 
elseif pointer == 6 then -- 9 [SETTABLE] 
 	Stack[2][Stack[3]] = Stack[1] 
elseif pointer == 7 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 43 then -- 9 [SETTABLE] 
 	Stack[3][Constants[22]] = Stack[4] 
elseif pointer == 44 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[10] then
		C1 = {}
		local encoded = {(decrypt("\087\081\087\050", "2144")),(decrypt("\028\061", "469")),(decrypt("\082\107\091\091", "1310")),(decrypt("\013\111\091", "2349")),(decrypt("\123\009\010\017\029\027", "1628")),(decrypt("\081\091\104\087\091", "1043")),(decrypt("\108\081\095\089\090", "1163")),}

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
 	Stack[1] = Stack[0][Constants[7]]
	 
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
 	Stack[2] = Stack[0][Constants[7]]
	 
elseif pointer == 9 then -- 6 [GETTABLE] 
 	Stack[1] = Stack[1][Stack[2]]
	 
elseif pointer == 10 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[6]]
	 
elseif pointer == 11 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[0][Constants[7]]
	 
elseif pointer == 12 then -- 9 [SETTABLE] 
 	Stack[2][Stack[3]] = Constants[1] 
elseif pointer == 13 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[7]]
	 
elseif pointer == 14 then -- 12 [ADD] 
 	Stack[2] = Stack[2] + Constants[2] 
elseif pointer == 15 then -- 9 [SETTABLE] 
 	Stack[0][Constants[7]] = Stack[2] 
elseif pointer == 16 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 17 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 45 then -- 9 [SETTABLE] 
 	Stack[3][Constants[7]] = Stack[4] 
elseif pointer == 46 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[11] then
		C1 = {}
		local encoded = {(decrypt("\008\100\111\095\109\081", "1876")),(decrypt("\121\088\107\108\110\038\111\083\106\104\080\106\105", "2136")),(decrypt("\025\061", "1620")),(decrypt("\113\086\096\070\105\081\092", "658")),((decrypt("\031\016\025", "851"))),(decrypt("\081\106\090\093", "2206")),(decrypt("\082\101\082\082\089\094\093\111", "898")),(decrypt("\108\081\093\090\090", "1140")),}

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
 	Stack[1] = Stack[0][Constants[6]]
	 
elseif pointer == 2 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[8]]
	 
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
 	Stack[3][Constants[21]] = Stack[4] 
elseif pointer == 48 then -- 6 [GETTABLE] 
 	Stack[4] = Stack[3][Constants[18]]
	
	Stack[4] = Stack[4]()
	pointer = pointer + 1 
elseif pointer == 50 then -- 11 [SELF] 
 	Stack[6] = Stack[4]
	if Stack[6] then
		Stack[5] = Stack[4][Constants[22]]
	end
	 
elseif pointer == 51 then -- 6 [GETTABLE] 
 	Stack[7] = Stack[1][Constants[18]]
	 
elseif pointer == 52 then -- 1 [LOADK] 
 Temp[10] = 8
Temp[5] = Constants
Temp[16] = 6
Stack[Temp[10]] = Temp[5][Temp[16]]
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
		Stack[5] = Stack[4][Constants[22]]
	end
	 
elseif pointer == 56 then -- 6 [GETTABLE] 
 	Stack[7] = Stack[2][Constants[18]]
	 
elseif pointer == 57 then -- 1 [LOADK] 
 Temp[15] = 8
Temp[13] = Constants
Temp[10] = 2
Stack[Temp[15]] = Temp[13][Temp[10]] 
elseif pointer == 58 then -- 1 [LOADK] 
 Temp[3] = 9
Temp[9] = Constants
Temp[14] = 14
Stack[Temp[3]] = Temp[9][Temp[14]]
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
		Stack[5] = Stack[4][Constants[22]]
	end
	 
elseif pointer == 62 then -- 6 [GETTABLE] 
 	Stack[7] = Stack[0][Constants[18]]
	 
elseif pointer == 63 then -- 1 [LOADK] 
 Temp[16] = 8
Temp[4] = Constants
Temp[5] = 9
Stack[Temp[16]] = Temp[4][Temp[5]]
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
		Stack[5] = Stack[4][Constants[21]]
	end
	 
elseif pointer == 67 then -- 28 [CALL] 
 	Stack[5] = Stack[5](Stack[6]) 
elseif pointer == 68 then -- 24 [LT] 
 	if Constants[10] < Stack[5] then pointer = pointer + 1 end 
elseif pointer == 69 then -- 22 [JMP] 
 pointer = pointer + 7  
elseif pointer == 70 then -- 5 [GETGLOBAL] 
 Temp[15] = 5
Temp[5] = 4
Temp[4] = Constants[Temp[5]]
Stack[Temp[15]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 71 then -- 11 [SELF] 
 	Stack[7] = Stack[4]
	if Stack[7] then
		Stack[6] = Stack[4][Constants[7]]
	end
	 
elseif pointer == 72 then -- 28 [CALL] 
 	Stack[6] = Stack[6](Stack[7]) 
elseif pointer == 73 then -- 11 [SELF] 
 	Stack[7] = Stack[6]
	if Stack[7] then
		Stack[6] = Stack[6][Constants[15]]
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
		local encoded = {(decrypt("\081\086\090\107\091", "2047")),(decrypt("\086\109\091\109", "2502")),(decrypt("\025\050", "1943")),(decrypt("\114\082\084\097\091\087\097\092\089\032\084\089\084\084\097\082\110\108", "2799")),(decrypt("\113\082\087\091\090\014\108\105\105\082", "1707")),(decrypt("\086\087\081", "2741")),(decrypt("\019\056", "939")),(decrypt("\090\104\110\091\109", "1078")),((decrypt("\026\021\018", "325"))),(decrypt("\123\009\010\030\025\031", "1622")),(decrypt("\104\082\092\104\106\095", "2492")),(decrypt("\000", "1178")),(decrypt("\042\105\023", "615")),(decrypt("\109\081\108\088\111\107", "354")),(decrypt("\017\062", "659")),(decrypt("\095\083\091\094", "552")),(decrypt("\085\105\088\088\088", "2181")),(decrypt("\015\105\084\083\082\084\105", "2170")),(decrypt("\018\038", "1135")),}

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
		Stack[2] = Stack[2][Constants[14]]
	end
	 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[5] = 4
Temp[6] = Constants
Temp[9] = 13
Stack[Temp[5]] = Temp[6][Temp[9]]
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
 Temp[14] = 6
Temp[12] = Constants
Temp[7] = 15
Stack[Temp[14]] = Temp[12][Temp[7]] 
elseif pointer == 12 then -- 12 [ADD] 
 	Stack[6] = Stack[6] + Constants[3] 
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
 Temp[7] = 3
Temp[10] = 17
Temp[4] = Constants[Temp[10]]
Stack[Temp[7]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 18 then -- 0 [MOVE] 
 Temp[7] = 4
Temp[15] = 1
Stack[Temp[7]] = Stack[Temp[15]] 
elseif pointer == 19 then -- 28 [CALL] 
 	Stack[3], Stack[4], Stack[5] = Stack[3](Stack[4]) 
elseif pointer == 20 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 21 then -- 20 [LEN] 
 	Stack[7] = #Stack[2] 
elseif pointer == 22 then -- 12 [ADD] 
 	Stack[7] = Stack[7] + Constants[3] 
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
 Temp[11] = 3
Temp[2] = 8
Temp[12] = Constants[Temp[2]]
Stack[Temp[11]] = vmEnv[Temp[12]] or Env[Temp[12]]
	Stack[3] = Stack[3][Constants[16]]
	
	pointer = pointer + 1 
elseif pointer == 28 then -- 0 [MOVE] 
 Temp[6] = 4
Temp[1] = 2
Stack[Temp[6]] = Stack[Temp[1]] 
elseif pointer == 29 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[13] then
		C1 = {}
		local encoded = {(decrypt("\118\086\092\090\109\090", "2091")),(decrypt("\115\095\090\093\101", "796")),}

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
 Temp[1] = 2
Temp[15] = byte == pairs
Stack[Temp[1]] = Temp[9]\n\tpointer = pointer + 1 
elseif pointer == 14 then -- 2 [LOADBOOL] 
 Temp[11] = 2
Temp[4] = ttostring ~= __metatable
Stack[Temp[11]] = Temp[6] 
elseif pointer == 15 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 16 then -- 24 [LT] 
 	if Stack[0] > Stack[1] then pointer = pointer + 1 end 
elseif pointer == 17 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 18 then -- 2 [LOADBOOL] 
 Temp[2] = 2
Temp[15] = byte == pairs
Stack[Temp[2]] = Temp[6]\n\tpointer = pointer + 1 
elseif pointer == 19 then -- 2 [LOADBOOL] 
 Temp[10] = 2
Temp[13] = ttostring ~= __metatable
Stack[Temp[10]] = Temp[8] 
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
 Temp[5] = 4
Temp[4] = Constants
Temp[10] = 3
Stack[Temp[5]] = Temp[4][Temp[10]] 
elseif pointer == 34 then -- 5 [GETGLOBAL] 
 Temp[5] = 5
Temp[14] = 2
Temp[7] = Constants[Temp[14]]
Stack[Temp[5]] = vmEnv[Temp[7]] or Env[Temp[7]]
	Stack[5] = Stack[5][Constants[6]]
	
	pointer = pointer + 1 
elseif pointer == 36 then -- 1 [LOADK] 
 Temp[11] = 6
Temp[16] = Constants
Temp[9] = 7
Stack[Temp[11]] = Temp[16][Temp[9]] 
elseif pointer == 37 then -- 20 [LEN] 
 	Stack[7] = #Stack[2] 
elseif pointer == 38 then -- 28 [CALL] 
 	Stack[5] = Stack[5](Stack[6], Stack[7]) 
elseif pointer == 39 then -- 1 [LOADK] 
 Temp[14] = 6
Temp[3] = Constants
Temp[4] = 3
Stack[Temp[14]] = Temp[3][Temp[4]] 
elseif pointer == 40 then -- 32 [FORPREP] 
     Stack[4] = Stack[4] - Stack[6]
    pointer = pointer + 8
     
elseif pointer == 41 then -- 20 [LEN] 
 	Stack[8] = #Stack[3] 
elseif pointer == 42 then -- 12 [ADD] 
 	Stack[8] = Stack[8] + Constants[3] 
elseif pointer == 43 then -- 6 [GETTABLE] 
 	Stack[9] = Stack[2][Stack[7]]
	 
elseif pointer == 44 then -- 1 [LOADK] 
 Temp[10] = 10
Temp[9] = Constants
Temp[15] = 12
Stack[Temp[10]] = Temp[9][Temp[15]] 
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
 Temp[1] = 4
Temp[6] = 8
Temp[10] = Constants[Temp[6]]
Stack[Temp[1]] = vmEnv[Temp[10]] or Env[Temp[10]]
	Stack[4] = Stack[4][Constants[11]]
	
	pointer = pointer + 1 
elseif pointer == 52 then -- 0 [MOVE] 
 Temp[8] = 5
Temp[13] = 3
Stack[Temp[8]] = Stack[Temp[13]] 
elseif pointer == 53 then -- 1 [LOADK] 
 Temp[4] = 6
Temp[12] = Constants
Temp[3] = 19
Stack[Temp[4]] = Temp[12][Temp[3]] 
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
 Temp[10] = 6
Temp[5] = 4
Temp[16] = Constants[Temp[5]]
Stack[Temp[10]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 79 then -- 0 [MOVE] 
 Temp[6] = 7
Temp[3] = 5
Stack[Temp[6]] = Stack[Temp[3]] 
elseif pointer == 80 then -- 1 [LOADK] 
 Temp[5] = 8
Temp[6] = Constants
Temp[16] = 17
Stack[Temp[5]] = Temp[6][Temp[16]]
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