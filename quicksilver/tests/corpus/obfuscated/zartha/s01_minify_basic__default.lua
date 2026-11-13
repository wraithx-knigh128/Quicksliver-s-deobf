return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\108\105\104\040\029\024\016\032\024\030\019\032\006\036", "2337")),(decrypt("\024\025\061", "2464")),(decrypt("\028\057", "2280")),(decrypt("\094\089\080\092\091", "900")),(decrypt("\027\021\029\024\025\028\005\056", "1053")),(decrypt("\103\115\000\005\125\127\003\000\122\009\002", "1598")),(decrypt("\017", "2037")),(decrypt("\028\031\050", "859")),(decrypt("\124\106\087\091\015\084\094\010\109\082\084\107", "2270")),(decrypt("\101\084\094\092\106\092", "827")),(decrypt("\026\024\061", "2461")),(decrypt("\046\029\018\028\111\066\043\017\031\091\068\041\021\027\108", "2175")),(decrypt("\014\093\093\106\084\087\089\105", "1192")),(decrypt("\046", "981")),(decrypt("\021\058", "2127")),(decrypt("\105\083\106\087\087\003\036", "302")),(decrypt("\088\092\093\088\087\105", "2748")),(decrypt("\010\092\095\106\084\089\084\068\106\091\084\083\087", "2045")),(decrypt("\022\018\059", "990")),(decrypt("\106\109", "243")),(decrypt("\026\059", "2006")),(decrypt("\086\088\088\083\109\091\009\032", "1187")),(decrypt("\028\020\063", "434")),(decrypt("\030\017\051", "2683")),(decrypt("\001\099\098\101\094\083", "998")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
Temp[14] = ttostring ~= __metatable
Stack[Temp[16]] = Temp[6] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[15] = vmEnv
Temp[13] = 6
Temp[9] = Constants[Temp[13]]
Temp[11] = 0
Temp[15][Temp[9]] = Temp[9] 
elseif pointer == 3 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\109\095\083\087\088\005\030\022\105\084\082\106\084\093\099\021\104\082\092\022\106\083\088\022\092\104\097\111\084\082\090\090\020\028\019\023\021\029\016\028\031\025\020\022\067\109\081\064\084\110\105\010\086\089\082\110\120\028\072\120\119\080\018\065\008\087\124\123\013\025\097\113\109\004\007\014\106\101\020\087\026\121\113\108\108\108\091", "2480")),(decrypt("\011\094\084\090\087\110\105\084", "174")),(decrypt("\012\091\109\070", "2216")),(decrypt("\015\082\107\091\105\116\106\117\082\110\089", "2278")),(decrypt("\114\094\092\092\100", "680")),(decrypt("\013\091\089\094\088", "1208")),}

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
		local encoded = {(decrypt("\012\085\083\084\091\106\106\111", "1564")),(decrypt("\092\101\092\093\089\082\104\083\097", "697")),(decrypt("\015\106\092\010\106\093\107\106\082\106\110\082\090\092", "167")),(decrypt("\118\080\106\065\111\091\091", "132")),(decrypt("\022\060", "1726")),(decrypt("\122\095\091\098\110\005\082\099\109\098", "1978")),}

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
 	if Stack[1] ~= Constants[5] then pointer = pointer + 1 end 
elseif pointer == 2 then -- 22 [JMP] 
 pointer = pointer + 4  
elseif pointer == 3 then -- 0 [MOVE] 
 Temp[16] = 2
Temp[3] = 1
Stack[Temp[16]] = Stack[Temp[3]] 
elseif pointer == 4 then -- 16 [MOD] 
 	Stack[1] = Stack[0] % Stack[1] 
elseif pointer == 5 then -- 0 [MOVE] 
 Temp[11] = 0
Temp[3] = 2
Stack[Temp[11]] = Stack[Temp[3]] 
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
		local encoded = {(decrypt("\117\097\085\094\105\090", "1902")),(decrypt("\120\104\105\091", "1412")),(decrypt("\024\063", "1444")),(decrypt("\009\086\089\106\107\085\111\105", "2632")),(decrypt("\022\062", "1595")),(decrypt("\124\097\089\092\082\092\110", "2909")),(decrypt("\027\057", "328")),(decrypt("\085\110\093\108", "1663")),(decrypt("\013\082\095\086\120\101\093\092\082\099\104", "2941")),(decrypt("\091\081\092\094", "1955")),(decrypt("\107\087\087\080\093", "641")),}

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
 	if Stack[0] < Constants[3] then pointer = pointer + 1 end 
elseif pointer == 2 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 3 then -- 2 [LOADBOOL] 
 Temp[15] = 1
Temp[13] = byte == pairs
Stack[Temp[15]] = Temp[14] 
elseif pointer == 4 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[2] = 1
Temp[10] = Constants
Temp[3] = 3
Stack[Temp[2]] = Temp[10][Temp[3]] 
elseif pointer == 6 then -- 5 [GETGLOBAL] 
 Temp[15] = 2
Temp[10] = 8
Temp[6] = Constants[Temp[10]]
Stack[Temp[15]] = vmEnv[Temp[6]] or Env[Temp[6]]
	Stack[2] = Stack[2][Constants[11]]
	
	pointer = pointer + 1 
elseif pointer == 8 then -- 5 [GETGLOBAL] 
 Temp[13] = 3
Temp[5] = 8
Temp[4] = Constants[Temp[5]]
Stack[Temp[13]] = vmEnv[Temp[4]] or Env[Temp[4]]
	Stack[3] = Stack[3][Constants[10]]
	
	pointer = pointer + 1 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[13] = 4
Temp[7] = 0
Stack[Temp[13]] = Stack[Temp[7]] 
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
 Temp[13] = 3
Temp[7] = Constants
Temp[3] = 7
Stack[Temp[13]] = Temp[7][Temp[3]] 
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
 Temp[6] = 5
Temp[9] = byte == pairs
Stack[Temp[6]] = Temp[13] 
elseif pointer == 19 then -- 30 [RETURN] 
 	return Stack[5] 
elseif pointer == 20 then -- 31 [FORLOOP] 
     Stack[1] = Stack[1] + Stack[3]
    if (Stack[3] > 0 and Stack[1] <= Stack[2]) or (Stack[3] <= 0 and Stack[1] >= Stack[2]) then
        pointer = pointer + -6
        Stack[4] = Stack[1]
    end
     
elseif pointer == 21 then -- 2 [LOADBOOL] 
 Temp[16] = 1
Temp[14] = ttostring ~= __metatable
Stack[Temp[16]] = Temp[4] 
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
		local encoded = {(decrypt("\013\084\080\082\110\111\092", "725")),(decrypt("\015\012\113\008\123\014", "402")),(decrypt("\107\083\080\109\105\094", "1557")),(decrypt("\090\080\093\088\088\086\082\109", "1673")),(decrypt("\089\109\097\083\110", "2580")),(decrypt("\015\108\084\091\110\111\035\083\084\035\084\093\082\095\084\096\081\084\069\100", "2448")),(decrypt("\115\095\081\082\117\085\091\105\091", "2355")),(decrypt("\025\050", "1979")),}

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
 Temp[4] = 3
Temp[9] = Constants
Temp[2] = 8
Stack[Temp[4]] = Temp[9][Temp[2]] 
elseif pointer == 3 then -- 20 [LEN] 
 	Stack[4] = #Stack[0] 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[7] = 5
Temp[15] = Constants
Temp[10] = 8
Stack[Temp[7]] = Temp[15][Temp[10]] 
elseif pointer == 5 then -- 32 [FORPREP] 
     Stack[3] = Stack[3] - Stack[5]
    pointer = pointer + 6
     
elseif pointer == 6 then -- 20 [LEN] 
 	Stack[7] = #Stack[2] 
elseif pointer == 7 then -- 12 [ADD] 
 	Stack[7] = Stack[7] + Constants[8] 
elseif pointer == 8 then -- 5 [GETGLOBAL] 
 Temp[3] = 8
Temp[15] = 4
Temp[10] = Constants[Temp[15]]
Stack[Temp[3]] = vmEnv[Temp[10]] or Env[Temp[10]] 
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
Temp[1] = Constants[Temp[13]]
Stack[Temp[7]] = vmEnv[Temp[1]] or Env[Temp[1]]
	Stack[3] = Stack[3][Constants[3]]
	
	pointer = pointer + 1 
elseif pointer == 15 then -- 0 [MOVE] 
 Temp[10] = 4
Temp[12] = 2
Stack[Temp[10]] = Stack[Temp[12]] 
elseif pointer == 16 then -- 0 [MOVE] 
 Temp[2] = 5
Temp[13] = 1
Stack[Temp[2]] = Stack[Temp[13]] 
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
 Temp[10] = 5
Temp[5] = Constants
Temp[16] = 21
Stack[Temp[10]] = Temp[5][Temp[16]] 
elseif pointer == 9 then -- 1 [LOADK] 
 Temp[15] = 6
Temp[13] = Constants
Temp[10] = 24
Stack[Temp[15]] = Temp[13][Temp[10]] 
elseif pointer == 10 then -- 1 [LOADK] 
 Temp[3] = 7
Temp[9] = Constants
Temp[14] = 21
Stack[Temp[3]] = Temp[9][Temp[14]] 
elseif pointer == 11 then -- 32 [FORPREP] 
     Stack[5] = Stack[5] - Stack[7]
    pointer = pointer + 8
     
elseif pointer == 12 then -- 0 [MOVE] 
 Temp[16] = 9
Temp[4] = 2
Stack[Temp[16]] = Stack[Temp[4]] 
elseif pointer == 13 then -- 0 [MOVE] 
 Temp[4] = 10
Temp[5] = 8
Stack[Temp[4]] = Stack[Temp[5]] 
elseif pointer == 14 then -- 28 [CALL] 
 	Stack[9] = Stack[9](Stack[10]) 
elseif pointer == 15 then -- 26 [TEST] 
 	if Stack[9] then pointer = pointer + 1 end 
elseif pointer == 16 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 17 then -- 20 [LEN] 
 	Stack[9] = #Stack[4] 
elseif pointer == 18 then -- 12 [ADD] 
 	Stack[9] = Stack[9] + Constants[21] 
elseif pointer == 19 then -- 9 [SETTABLE] 
 	Stack[4][Stack[9]] = Stack[8] 
elseif pointer == 20 then -- 31 [FORLOOP] 
     Stack[5] = Stack[5] + Stack[7]
    if (Stack[7] > 0 and Stack[5] <= Stack[6]) or (Stack[7] <= 0 and Stack[5] >= Stack[6]) then
        pointer = pointer + -9
        Stack[8] = Stack[5]
    end
     
elseif pointer == 21 then -- 5 [GETGLOBAL] 
 Temp[15] = 5
Temp[5] = 4
Temp[4] = Constants[Temp[5]]
Stack[Temp[15]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 22 then -- 1 [LOADK] 
 Temp[10] = 6
Temp[5] = Constants
Temp[16] = 22
Stack[Temp[10]] = Temp[5][Temp[16]] 
elseif pointer == 23 then -- 0 [MOVE] 
 Temp[6] = 7
Temp[3] = 3
Stack[Temp[6]] = Stack[Temp[3]] 
elseif pointer == 24 then -- 0 [MOVE] 
 Temp[5] = 8
Temp[6] = 4
Stack[Temp[5]] = Stack[Temp[6]] 
elseif pointer == 25 then -- 1 [LOADK] 
 Temp[16] = 9
Temp[10] = Constants
Temp[4] = 7
Stack[Temp[16]] = Temp[10][Temp[4]]
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
 Temp[13] = 5
Temp[2] = 4
Temp[15] = Constants[Temp[2]]
Stack[Temp[13]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 30 then -- 1 [LOADK] 
 Temp[6] = 6
Temp[14] = Constants
Temp[5] = 1
Stack[Temp[6]] = Temp[14][Temp[5]] 
elseif pointer == 31 then -- 0 [MOVE] 
 Temp[3] = 7
Temp[7] = 1
Stack[Temp[3]] = Stack[Temp[7]] 
elseif pointer == 32 then -- 1 [LOADK] 
 Temp[7] = 8
Temp[11] = Constants
Temp[5] = 19
Stack[Temp[7]] = Temp[11][Temp[5]] 
elseif pointer == 33 then -- 1 [LOADK] 
 Temp[7] = 9
Temp[15] = Constants
Temp[9] = 2
Stack[Temp[7]] = Temp[15][Temp[9]]
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
 Temp[12] = 5
Temp[14] = 4
Temp[15] = Constants[Temp[14]]
Stack[Temp[12]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 38 then -- 1 [LOADK] 
 Temp[7] = 6
Temp[4] = Constants
Temp[11] = 16
Stack[Temp[7]] = Temp[4][Temp[11]] 
elseif pointer == 39 then -- 0 [MOVE] 
 Temp[7] = 7
Temp[10] = 0
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 40 then -- 1 [LOADK] 
 Temp[14] = 8
Temp[12] = Constants
Temp[15] = 11
Stack[Temp[14]] = Temp[12][Temp[15]] 
elseif pointer == 41 then -- 1 [LOADK] 
 Temp[13] = 9
Temp[6] = Constants
Temp[2] = 15
Stack[Temp[13]] = Temp[6][Temp[2]] 
elseif pointer == 42 then -- 1 [LOADK] 
 Temp[9] = 10
Temp[7] = Constants
Temp[16] = 23
Stack[Temp[9]] = Temp[7][Temp[16]]
	Stack[7] = Stack[7](Stack[8], Stack[9], Stack[10])
	pointer = pointer + 1 
elseif pointer == 44 then -- 1 [LOADK] 
 Temp[15] = 8
Temp[13] = Constants
Temp[3] = 14
Stack[Temp[15]] = Temp[13][Temp[3]] 
elseif pointer == 45 then -- 0 [MOVE] 
 Temp[16] = 9
Temp[4] = 0
Stack[Temp[16]] = Stack[Temp[4]] 
elseif pointer == 46 then -- 1 [LOADK] 
 Temp[10] = 10
Temp[8] = Constants
Temp[1] = 8
Stack[Temp[10]] = Temp[8][Temp[1]] 
elseif pointer == 47 then -- 1 [LOADK] 
 Temp[8] = 11
Temp[1] = Constants
Temp[12] = 15
Stack[Temp[8]] = Temp[1][Temp[12]] 
elseif pointer == 48 then -- 1 [LOADK] 
 Temp[5] = 12
Temp[14] = Constants
Temp[11] = 23
Stack[Temp[5]] = Temp[14][Temp[11]]
	Stack[9] = Stack[9](Stack[10], Stack[11], Stack[12])
	pointer = pointer + 1 
elseif pointer == 50 then -- 1 [LOADK] 
 Temp[12] = 10
Temp[5] = Constants
Temp[14] = 14
Stack[Temp[12]] = Temp[5][Temp[14]] 
elseif pointer == 51 then -- 0 [MOVE] 
 Temp[7] = 11
Temp[11] = 0
Stack[Temp[7]] = Stack[Temp[11]] 
elseif pointer == 52 then -- 1 [LOADK] 
 Temp[7] = 12
Temp[4] = Constants
Temp[6] = 3
Stack[Temp[7]] = Temp[4][Temp[6]] 
elseif pointer == 53 then -- 1 [LOADK] 
 Temp[5] = 13
Temp[1] = Constants
Temp[12] = 15
Stack[Temp[5]] = Temp[1][Temp[12]] 
elseif pointer == 54 then -- 1 [LOADK] 
 Temp[7] = 14
Temp[10] = Constants
Temp[3] = 23
Stack[Temp[7]] = Temp[10][Temp[3]]
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
 Temp[7] = 5
Temp[8] = 4
Temp[15] = Constants[Temp[8]]
Stack[Temp[7]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 59 then -- 5 [GETGLOBAL] 
 Temp[3] = 6
Temp[11] = 17
Temp[14] = Constants[Temp[11]]
Stack[Temp[3]] = vmEnv[Temp[14]] or Env[Temp[14]]
	Stack[6] = Stack[6][Constants[10]]
	
	pointer = pointer + 1 
elseif pointer == 61 then -- 1 [LOADK] 
 Temp[7] = 7
Temp[4] = Constants
Temp[8] = 12
Stack[Temp[7]] = Temp[4][Temp[8]] 
elseif pointer == 62 then -- 1 [LOADK] 
 Temp[15] = 8
Temp[5] = Constants
Temp[16] = 5
Stack[Temp[15]] = Temp[5][Temp[16]] 
elseif pointer == 63 then -- 1 [LOADK] 
 Temp[15] = 9
Temp[16] = Constants
Temp[4] = 20
Stack[Temp[15]] = Temp[16][Temp[4]] 
elseif pointer == 64 then -- 1 [LOADK] 
 Temp[12] = 10
Temp[11] = Constants
Temp[16] = 3
Stack[Temp[12]] = Temp[11][Temp[16]]
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