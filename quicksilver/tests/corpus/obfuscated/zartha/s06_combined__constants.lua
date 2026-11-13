return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\015\010\094\089\089", "636")),(decrypt("\025\063", "2464")),(decrypt("\006\127\124\113\009\011\114\125\010\112\122", "900")),(decrypt("\109\080\074", "1598")),(decrypt("\000\068\021\086\082\009\020\068\103\020\071\072\096\025\097\073\025\087\095\005\021\096\065\082\096\025\074\101\025\097\076\082\021\099\098\094\101\109\074\073\071\031\020\109\072\020\091\094\020\108\074\101\082\021\075\104\021\096\068\021\086\082", "859")),(decrypt("\099\091\109\073\091\109\085\104\090\084\064\094", "827")),(decrypt("\024\058", "2175")),(decrypt("\006\004\009\002", "981")),(decrypt("\020\059", "302")),(decrypt("\081\085\088\092\109", "2045")),(decrypt("\126\120\105\105\081\085\091", "243")),(decrypt("\009\093\083\104\087\088\088\070\105\090\088\081\084", "1187")),(decrypt("\094\087\084", "2683")),(decrypt("\087\088\087\049", "2847")),(decrypt("\067\092\092\074", "1018")),(decrypt("\080\086\107\091", "2341")),(decrypt("\124\104\082\088\015\086\091\009\109\080\081\104", "2023")),(decrypt("\002\080\084\092\106\084\093\109", "834")),(decrypt("\066\088\080\076\084\092\067\086", "2759")),(decrypt("\083\080\108\077", "1859")),(decrypt("\108\090\105\108", "1601")),(decrypt("\027\050", "2979")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
 Temp[4] = 0
Temp[15] = ttostring ~= __metatable
Stack[Temp[4]] = Temp[5] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[5] = vmEnv
Temp[4] = 3
Temp[10] = Constants[Temp[4]]
Temp[16] = 0
Temp[5][Temp[10]] = Temp[10] 
elseif pointer == 3 then -- 10 [NEWTABLE] 
 	Stack[0] = {} 
elseif pointer == 4 then -- 9 [SETTABLE] 
 	Stack[0][Constants[11]] = Stack[0] 
elseif pointer == 5 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\009\125\003\121\113", "1799")),(decrypt("\013\086\106\094\091\105\105", "1529")),(decrypt("\089\106\085\094\111\089\098\085\107\099\093\102", "1488")),(decrypt("\081\104\084\103", "2229")),(decrypt("\121\084\098\085", "2487")),(decrypt("\116\118\115\117\116\116\114", "2185")),(decrypt("\120\085\073\104", "2584")),((decrypt("\025\023\021", "2027"))),}

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
 Temp[7] = 1
Temp[4] = 3
Temp[6] = Constants[Temp[4]]
Stack[Temp[7]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 2 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 3 then -- 9 [SETTABLE] 
 	Stack[2][Constants[4]] = Stack[0] 
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
 	Stack[0][Constants[4]] = Stack[1] 
elseif pointer == 8 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\119\092\081\092\089\105\084\089\064\107\098", "791")),(decrypt("\082\097\065\106\087\068", "2653")),(decrypt("\008\091\106\090\088\125\106\084\110", "2820")),(decrypt("\067\089\064\068", "2955")),(decrypt("\111\081\105\083", "2157")),(decrypt("\113\094\088", "2868")),(decrypt("\005\084\093\089\093\001\069\095\094\070\002", "1569")),(decrypt("\071\086\068\109\104\091", "1911")),(decrypt("\001\017\021\066", "1803")),}

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
Temp[11] = 7
Stack[Temp[16]] = Temp[4][Temp[11]] 
elseif pointer == 3 then -- 5 [GETGLOBAL] 
 Temp[12] = 3
Temp[11] = 8
Temp[4] = Constants[Temp[11]]
Stack[Temp[12]] = vmEnv[Temp[4]] or Env[Temp[4]]
	Stack[3] = Stack[3][Constants[2]]
	
	pointer = pointer + 1 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[14] = 4
Temp[1] = Constants
Temp[12] = 9
Stack[Temp[14]] = Temp[1][Temp[12]] 
elseif pointer == 6 then -- 11 [SELF] 
 	Stack[6] = Stack[0]
	if Stack[6] then
		Stack[5] = Stack[0][Constants[4]]
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
 	Stack[0][Constants[19]] = Stack[1] 
elseif pointer == 10 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\031\057", "829")),(decrypt("\091\105\093\095\081\080\104\094\103", "1564")),(decrypt("\117\013\027", "167")),(decrypt("\123\092\106\095\090\107\091\008\093\087", "1726")),((decrypt("\030", "2823"))),(decrypt("\015\101\092\010\109\083\109\109\084\098\111\084\090\083", "1971")),}

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
Temp[13] = Constants
Temp[6] = 1
Stack[Temp[3]] = Temp[13][Temp[6]] 
elseif pointer == 2 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 3 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 11 then -- 9 [SETTABLE] 
 	Stack[0][Constants[21]] = Stack[1] 
elseif pointer == 12 then -- 5 [GETGLOBAL] 
 Temp[6] = 1
Temp[3] = 6
Temp[5] = Constants[Temp[3]]
Stack[Temp[6]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 13 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 14 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 15 then -- 9 [SETTABLE] 
 	Stack[3][Constants[11]] = Stack[0] 
elseif pointer == 16 then -- 28 [CALL] 
 	Stack[1] = Stack[1](Stack[2], Stack[3]) 
elseif pointer == 17 then -- 9 [SETTABLE] 
 	Stack[1][Constants[11]] = Stack[1] 
elseif pointer == 18 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {((decrypt("\021\019\031", "2632"))),(decrypt("\008\095\084\094\081\101\091\101", "2909")),(decrypt("\111\082\091\109\110\110", "1663")),(decrypt("\086\075\085", "1955")),(decrypt("\089\110\092\085\107\093\107\094\111\107\084\109", "2764")),(decrypt("\013\094\090\084\120\105\088\094\082\111\109", "2513")),(decrypt("\010\087\089\109\104\084\111\110", "1735")),(decrypt("\118\111\086\090\106\084", "2736")),(decrypt("\102\090\089\069\111\104", "1047")),(decrypt("\112\101\105\080", "991")),}

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
 	Stack[1] = Stack[1][Constants[4]]
	 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[4] = 2
Temp[13] = Constants
Temp[7] = 3
Stack[Temp[4]] = Temp[13][Temp[7]]
	Stack[1] = Stack[1](Stack[2])
	pointer = pointer + 1 
elseif pointer == 5 then -- 9 [SETTABLE] 
 	Stack[1][Constants[9]] = Stack[0] 
elseif pointer == 6 then -- 5 [GETGLOBAL] 
 Temp[13] = 2
Temp[7] = 5
Temp[3] = Constants[Temp[7]]
Stack[Temp[13]] = vmEnv[Temp[3]] or Env[Temp[3]] 
elseif pointer == 7 then -- 0 [MOVE] 
 Temp[6] = 3
Temp[9] = 1
Stack[Temp[6]] = Stack[Temp[9]] 
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
 	Stack[1][Constants[4]] = Stack[2] 
elseif pointer == 22 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {(decrypt("\031\061", "666")),(decrypt("\123\088\105\094\114\110", "725")),(decrypt("\014\089\081\111\084\083\085\108", "1557")),(decrypt("\106\090", "2580")),(decrypt("\080\092\065\082\081\082", "2355")),(decrypt("\106\096\081\093\100", "782")),(decrypt("\064\087\104\067", "304")),(decrypt("\009\111\088\108\120\092\085\093\110\125\111\093\095\087\105\104", "2734")),(decrypt("\011\104\081\085\108\106\033\091\087\033\080\084\086\091\081\110\083\081\071\108", "601")),}

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
 Temp[15] = 1
Temp[10] = 7
Temp[7] = Constants[Temp[10]]
Stack[Temp[15]] = vmEnv[Temp[7]] or Env[Temp[7]]
	Stack[1] = Stack[1][Constants[4]]
	
	pointer = pointer + 1 
elseif pointer == 3 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[5]]
	 
elseif pointer == 4 then -- 17 [POW] 
 	Stack[2] = Stack[2] ^ Constants[1] 
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
 	Stack[1][Constants[21]] = Stack[2] 
elseif pointer == 24 then -- 5 [GETGLOBAL] 
 Temp[6] = 2
Temp[16] = 6
Temp[10] = Constants[Temp[16]]
Stack[Temp[6]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 25 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 26 then -- 10 [NEWTABLE] 
 	Stack[4] = {} 
elseif pointer == 27 then -- 9 [SETTABLE] 
 	Stack[4][Constants[11]] = Stack[0] 
elseif pointer == 28 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3], Stack[4]) 
elseif pointer == 29 then -- 9 [SETTABLE] 
 	Stack[2][Constants[11]] = Stack[2] 
elseif pointer == 30 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[6] then
		C1 = {}
		local encoded = {(decrypt("\116\091\096\088\101\094\090\092\114\088\096\093\104", "388")),(decrypt("\085\107\086\082\111\088\097\089\107\110\094\106", "2687")),(decrypt("\081\088\066\082\088", "2144")),(decrypt("\095\100\108\088", "1310")),(decrypt("\092\110\081\110", "1628")),((decrypt("\027\020\030\024\025\029\006", "1163"))),(decrypt("\088\094\110", "746")),(decrypt("\095\065\091\070\090\104", "417")),(decrypt("\111\097\086\094\110", "2954")),(decrypt("\013\091\083\086\120\108\081\092\082\106\100", "2081")),}

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
 	Stack[2] = Stack[2][Constants[7]]
	 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[2] = 3
Temp[9] = Constants
Temp[16] = 4
Stack[Temp[2]] = Temp[9][Temp[16]]
	Stack[2] = Stack[2](Stack[3])
	pointer = pointer + 1 
elseif pointer == 5 then -- 0 [MOVE] 
 Temp[6] = 3
Temp[7] = 0
Stack[Temp[6]] = Stack[Temp[7]] 
elseif pointer == 6 then -- 9 [SETTABLE] 
 	Stack[2][Constants[8]] = Stack[1] 
elseif pointer == 7 then -- 9 [SETTABLE] 
 	Stack[2][Constants[3]] = Stack[3] 
elseif pointer == 8 then -- 5 [GETGLOBAL] 
 Temp[10] = 3
Temp[12] = 2
Temp[9] = Constants[Temp[12]]
Stack[Temp[10]] = vmEnv[Temp[9]] or Env[Temp[9]] 
elseif pointer == 9 then -- 0 [MOVE] 
 Temp[4] = 4
Temp[5] = 2
Stack[Temp[4]] = Stack[Temp[5]] 
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
 	Stack[2][Constants[4]] = Stack[3] 
elseif pointer == 34 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[7] then
		C1 = {}
		local encoded = {(decrypt("\116\080\084\108", "1610")),((decrypt("\026\016\026", "1726"))),(decrypt("\127\095\084\083\083\084\104", "631")),(decrypt("\010\109\088\109\109\084\105\111\084\090\010\108\106\109\105", "1127")),(decrypt("\123\086\086\092\085\088\083\102", "1868")),(decrypt("\088\064\089\075\088\083", "2508")),(decrypt("\089\086\067\088\085", "982")),}

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
 	Stack[1] = Stack[0][Constants[7]]
	 
elseif pointer == 2 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[6]]
	 
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
 	Stack[2][Constants[21]] = Stack[3] 
elseif pointer == 36 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 37 then -- 9 [SETTABLE] 
 	Stack[3][Constants[11]] = Stack[3] 
elseif pointer == 38 then -- 9 [SETTABLE] 
 	Stack[3][Constants[1]] = Constants[14] 
elseif pointer == 39 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[8] then
		C1 = {}
		local encoded = {(decrypt("\111\081\084\088\082", "659")),(decrypt("\083\111\084\088", "2181")),(decrypt("\109\091\106\071\091\104\093\108\095\090\066\095", "1135")),(decrypt("\107\069\095\105\065", "1097")),(decrypt("\021\063", "2486")),(decrypt("\127\106\084\091\081\087\105", "1279")),(decrypt("\014\091\083\104\084\081\087\107\120\081\081\091\118\111\094\091", "1770")),(decrypt("\113\087\091\108\082\082\109\035\105\091\104\088\085\110\083\095", "1264")),(decrypt("\026\059", "2071")),((decrypt("\021\020\018\027", "2153"))),}

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
 Temp[6] = 0
Temp[1] = 3
Temp[5] = Constants[Temp[1]]
Stack[Temp[6]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 2 then -- 10 [NEWTABLE] 
 	Stack[1] = {} 
elseif pointer == 3 then -- 9 [SETTABLE] 
 	Stack[1][Constants[1]] = Constants[9] 
elseif pointer == 4 then -- 9 [SETTABLE] 
 	Stack[1][Constants[2]] = Constants[5] 
elseif pointer == 5 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 6 then -- 9 [SETTABLE] 
 	Stack[1][Constants[4]] = Stack[2] 
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
 	Stack[3][Constants[4]] = Stack[4] 
elseif pointer == 42 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[9] then
		C1 = {}
		local encoded = {(decrypt("\029\063", "540")),((decrypt("\028\027\020\029\029", "1787"))),(decrypt("\110\094\092\086\091\004\017\023\106\085\093\107\087\092\108\020\107\083\083\023\105\082\087\023\095\105\110\110\087\083\085\091\023\029\030\025\029\027\025\026\027\024\029\023\086\005\013\108\009\005\109\110\105\114\031\121\028\083\108\090\001\081\123\008\084\087\010\022\027\091\119\088\031\123\103\084\127\093\093\085\089\088\092\088\104\086\024", "1571")),(decrypt("\085\064\087\109", "241")),(decrypt("\104\079\085\101\094", "1908")),(decrypt("\116\090\104\092\108\111", "2309")),}

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
 	Stack[2] = Stack[0][Constants[4]]
	 
elseif pointer == 2 then -- 12 [ADD] 
 	Stack[2] = Stack[2] + Constants[1] 
elseif pointer == 3 then -- 9 [SETTABLE] 
 	Stack[0][Constants[4]] = Stack[2] 
elseif pointer == 4 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[5]]
	 
elseif pointer == 5 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[0][Constants[4]]
	 
elseif pointer == 6 then -- 9 [SETTABLE] 
 	Stack[2][Stack[3]] = Stack[1] 
elseif pointer == 7 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 43 then -- 9 [SETTABLE] 
 	Stack[3][Constants[16]] = Stack[4] 
elseif pointer == 44 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[10] then
		C1 = {}
		local encoded = {(decrypt("\011\084\108\111\080", "2745")),(decrypt("\084\089\091\052", "1982")),(decrypt("\084\105\064\069\066", "1117")),(decrypt("\109\106\086\086", "2681")),(decrypt("\122\111\080\104\109\092", "1796")),(decrypt("\025\062", "1545")),(decrypt("\086\084\075\095\080", "1084")),}

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
 	Stack[1] = Stack[0][Constants[3]]
	 
elseif pointer == 2 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[4]]
	 
elseif pointer == 3 then -- 24 [LT] 
 	if Stack[2] < Stack[1] then pointer = pointer + 1 end 
elseif pointer == 4 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 5 then -- 3 [LOADNIL] 
 	Stack[1], Stack[2] = nil 
elseif pointer == 6 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 7 then -- 6 [GETTABLE] 
 	Stack[1] = Stack[0][Constants[7]]
	 
elseif pointer == 8 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[3]]
	 
elseif pointer == 9 then -- 6 [GETTABLE] 
 	Stack[1] = Stack[1][Stack[2]]
	 
elseif pointer == 10 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[7]]
	 
elseif pointer == 11 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[0][Constants[3]]
	 
elseif pointer == 12 then -- 9 [SETTABLE] 
 	Stack[2][Stack[3]] = Constants[2] 
elseif pointer == 13 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[3]]
	 
elseif pointer == 14 then -- 12 [ADD] 
 	Stack[2] = Stack[2] + Constants[6] 
elseif pointer == 15 then -- 9 [SETTABLE] 
 	Stack[0][Constants[3]] = Stack[2] 
elseif pointer == 16 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 17 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 45 then -- 9 [SETTABLE] 
 	Stack[3][Constants[13]] = Stack[4] 
elseif pointer == 46 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[11] then
		C1 = {}
		local encoded = {(decrypt("\027\062", "354")),((decrypt("\025\016\016\022\022", "1771"))),(decrypt("\080\105\090\095", "1766")),(decrypt("\068\095\084\089\086", "2868")),(decrypt("\011\109\088\110\024\025", "252")),}

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
 	Stack[1] = Stack[0][Constants[3]]
	 
elseif pointer == 2 then -- 6 [GETTABLE] 
 	Stack[2] = Stack[0][Constants[4]]
	 
elseif pointer == 3 then -- 13 [SUB] 
 	Stack[1] = Stack[1] - Stack[2] 
elseif pointer == 4 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Constants[1] 
elseif pointer == 5 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 6 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 47 then -- 9 [SETTABLE] 
 	Stack[3][Constants[20]] = Stack[4] 
elseif pointer == 48 then -- 6 [GETTABLE] 
 	Stack[4] = Stack[3][Constants[4]]
	
	Stack[4] = Stack[4]()
	pointer = pointer + 1 
elseif pointer == 50 then -- 11 [SELF] 
 	Stack[6] = Stack[4]
	if Stack[6] then
		Stack[5] = Stack[4][Constants[16]]
	end
	 
elseif pointer == 51 then -- 6 [GETTABLE] 
 	Stack[7] = Stack[1][Constants[4]]
	 
elseif pointer == 52 then -- 1 [LOADK] 
 Temp[4] = 8
Temp[13] = Constants
Temp[2] = 22
Stack[Temp[4]] = Temp[13][Temp[2]]
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
		Stack[5] = Stack[4][Constants[16]]
	end
	 
elseif pointer == 56 then -- 6 [GETTABLE] 
 	Stack[7] = Stack[2][Constants[4]]
	 
elseif pointer == 57 then -- 1 [LOADK] 
 Temp[15] = 8
Temp[6] = Constants
Temp[14] = 7
Stack[Temp[15]] = Temp[6][Temp[14]] 
elseif pointer == 58 then -- 1 [LOADK] 
 Temp[5] = 9
Temp[3] = Constants
Temp[7] = 2
Stack[Temp[5]] = Temp[3][Temp[7]]
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
		Stack[5] = Stack[4][Constants[16]]
	end
	 
elseif pointer == 62 then -- 6 [GETTABLE] 
 	Stack[7] = Stack[0][Constants[4]]
	 
elseif pointer == 63 then -- 1 [LOADK] 
 Temp[7] = 8
Temp[11] = Constants
Temp[5] = 15
Stack[Temp[7]] = Temp[11][Temp[5]]
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
		Stack[5] = Stack[4][Constants[20]]
	end
	 
elseif pointer == 67 then -- 28 [CALL] 
 	Stack[5] = Stack[5](Stack[6]) 
elseif pointer == 68 then -- 24 [LT] 
 	if Constants[9] < Stack[5] then pointer = pointer + 1 end 
elseif pointer == 69 then -- 22 [JMP] 
 pointer = pointer + 7  
elseif pointer == 70 then -- 5 [GETGLOBAL] 
 Temp[7] = 5
Temp[15] = 10
Temp[9] = Constants[Temp[15]]
Stack[Temp[7]] = vmEnv[Temp[9]] or Env[Temp[9]] 
elseif pointer == 71 then -- 11 [SELF] 
 	Stack[7] = Stack[4]
	if Stack[7] then
		Stack[6] = Stack[4][Constants[13]]
	end
	 
elseif pointer == 72 then -- 28 [CALL] 
 	Stack[6] = Stack[6](Stack[7]) 
elseif pointer == 73 then -- 11 [SELF] 
 	Stack[7] = Stack[6]
	if Stack[7] then
		Stack[6] = Stack[6][Constants[19]]
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
		local encoded = {(decrypt("\086\106\110\109\105", "1632")),(decrypt("\022\062", "1581")),(decrypt("\120\107\091\082\105\089\084\085\084\105", "1715")),(decrypt("\109\081\093\105\095", "2371")),(decrypt("\094\108\082\094\095", "2710")),(decrypt("\090\093\067\083\092\104", "1238")),(decrypt("\026\057", "2249")),(decrypt("\027\061", "1660")),(decrypt("\015\096\093\109\081", "2865")),(decrypt("\046\018", "445")),(decrypt("\022\082\035", "2295")),(decrypt("\019", "872")),(decrypt("\092\068\087\107\088\071", "1707")),(decrypt("\065\092\099\071", "1044")),(decrypt("\081\085\083\084", "914")),(decrypt("\081\094\107", "384")),}

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
		Stack[2] = Stack[0][Constants[4]]
	end
	 
elseif pointer == 3 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3]) 
elseif pointer == 4 then -- 11 [SELF] 
 	Stack[3] = Stack[2]
	if Stack[3] then
		Stack[2] = Stack[2][Constants[13]]
	end
	 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[13] = 4
Temp[9] = Constants
Temp[10] = 11
Stack[Temp[13]] = Temp[9][Temp[10]]
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
 Temp[7] = 6
Temp[2] = Constants
Temp[12] = 2
Stack[Temp[7]] = Temp[2][Temp[12]] 
elseif pointer == 12 then -- 12 [ADD] 
 	Stack[6] = Stack[6] + Constants[7] 
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
 Temp[4] = 3
Temp[16] = 5
Temp[10] = Constants[Temp[16]]
Stack[Temp[4]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 18 then -- 0 [MOVE] 
 Temp[10] = 4
Temp[9] = 1
Stack[Temp[10]] = Stack[Temp[9]] 
elseif pointer == 19 then -- 28 [CALL] 
 	Stack[3], Stack[4], Stack[5] = Stack[3](Stack[4]) 
elseif pointer == 20 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 21 then -- 20 [LEN] 
 	Stack[7] = #Stack[2] 
elseif pointer == 22 then -- 12 [ADD] 
 	Stack[7] = Stack[7] + Constants[7] 
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
Temp[3] = 1
Temp[2] = Constants[Temp[3]]
Stack[Temp[11]] = vmEnv[Temp[2]] or Env[Temp[2]]
	Stack[3] = Stack[3][Constants[15]]
	
	pointer = pointer + 1 
elseif pointer == 28 then -- 0 [MOVE] 
 Temp[2] = 4
Temp[9] = 2
Stack[Temp[2]] = Stack[Temp[9]] 
elseif pointer == 29 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[13] then
		C1 = {}
		local encoded = {(decrypt("\121\095\101\100\087\118\095\082\082\090\089\094\087", "2198")),((decrypt("\026\019\030\030\021\019\030", "2499"))),(decrypt("\011\094\106\069", "576")),((decrypt("\021\029\029\016\028", "2837"))),(decrypt("\113\088\082\108", "2860")),(decrypt("\123\101\095\091\081\095\080\038\109\086\082\081\088\101\110", "1951")),}

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
 Temp[15] = 2
Temp[1] = byte == pairs
Stack[Temp[15]] = Temp[14]\n\tpointer = pointer + 1 
elseif pointer == 14 then -- 2 [LOADBOOL] 
 Temp[14] = 2
Temp[8] = ttostring ~= __metatable
Stack[Temp[14]] = Temp[9] 
elseif pointer == 15 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 16 then -- 24 [LT] 
 	if Stack[0] > Stack[1] then pointer = pointer + 1 end 
elseif pointer == 17 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 18 then -- 2 [LOADBOOL] 
 Temp[13] = 2
Temp[6] = byte == pairs
Stack[Temp[13]] = Temp[3]\n\tpointer = pointer + 1 
elseif pointer == 19 then -- 2 [LOADBOOL] 
 Temp[13] = 2
Temp[12] = ttostring ~= __metatable
Stack[Temp[13]] = Temp[1] 
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
 Temp[4] = 4
Temp[6] = Constants
Temp[11] = 7
Stack[Temp[4]] = Temp[6][Temp[11]] 
elseif pointer == 34 then -- 5 [GETGLOBAL] 
 Temp[10] = 5
Temp[14] = 14
Temp[3] = Constants[Temp[14]]
Stack[Temp[10]] = vmEnv[Temp[3]] or Env[Temp[3]]
	Stack[5] = Stack[5][Constants[16]]
	
	pointer = pointer + 1 
elseif pointer == 36 then -- 1 [LOADK] 
 Temp[5] = 6
Temp[3] = Constants
Temp[9] = 8
Stack[Temp[5]] = Temp[3][Temp[9]] 
elseif pointer == 37 then -- 20 [LEN] 
 	Stack[7] = #Stack[2] 
elseif pointer == 38 then -- 28 [CALL] 
 	Stack[5] = Stack[5](Stack[6], Stack[7]) 
elseif pointer == 39 then -- 1 [LOADK] 
 Temp[6] = 6
Temp[5] = Constants
Temp[14] = 7
Stack[Temp[6]] = Temp[5][Temp[14]] 
elseif pointer == 40 then -- 32 [FORPREP] 
     Stack[4] = Stack[4] - Stack[6]
    pointer = pointer + 8
     
elseif pointer == 41 then -- 20 [LEN] 
 	Stack[8] = #Stack[3] 
elseif pointer == 42 then -- 12 [ADD] 
 	Stack[8] = Stack[8] + Constants[7] 
elseif pointer == 43 then -- 6 [GETTABLE] 
 	Stack[9] = Stack[2][Stack[7]]
	 
elseif pointer == 44 then -- 1 [LOADK] 
 Temp[15] = 10
Temp[13] = Constants
Temp[16] = 12
Stack[Temp[15]] = Temp[13][Temp[16]] 
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
Temp[16] = 1
Temp[3] = Constants[Temp[16]]
Stack[Temp[10]] = vmEnv[Temp[3]] or Env[Temp[3]]
	Stack[4] = Stack[4][Constants[6]]
	
	pointer = pointer + 1 
elseif pointer == 52 then -- 0 [MOVE] 
 Temp[3] = 5
Temp[15] = 3
Stack[Temp[3]] = Stack[Temp[15]] 
elseif pointer == 53 then -- 1 [LOADK] 
 Temp[13] = 6
Temp[12] = Constants
Temp[10] = 10
Stack[Temp[13]] = Temp[12][Temp[10]] 
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
 Temp[12] = 6
Temp[14] = 10
Temp[15] = Constants[Temp[14]]
Stack[Temp[12]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 79 then -- 0 [MOVE] 
 Temp[7] = 7
Temp[4] = 5
Stack[Temp[7]] = Stack[Temp[4]] 
elseif pointer == 80 then -- 1 [LOADK] 
 Temp[11] = 8
Temp[7] = Constants
Temp[10] = 5
Stack[Temp[11]] = Temp[7][Temp[10]]
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