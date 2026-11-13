return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\029\025\051", "2280")),(decrypt("\080\108\106\104\065\026\021", "1053")),(decrypt("\104\107\106\071\071\094", "2037")),(decrypt("\066\064\096\110\070", "2270")),(decrypt("\109\086", "2461")),(decrypt("\113\097\114\117\011\013\117\124\008\123\112", "1192")),(decrypt("\026\058", "2127")),(decrypt("\028\060", "2748")),(decrypt("\019\020\059", "990")),(decrypt("\010\106\106\106\085\091", "2006")),(decrypt("\020\003\045\001\082\083\020\043\005\066\084\020\007\005\107", "434")),(decrypt("\019\028\016\018\017\020\009\050", "998")),(decrypt("\123\082\090\090", "2499")),(decrypt("\044", "2686")),(decrypt("\021\031\062", "1555")),(decrypt("\025\031\059", "1805")),(decrypt("\026\020\057", "2823")),(decrypt("\067\089\086\090\070\108", "2332")),(decrypt("\009\093\083\110\084\081\086\106", "617")),(decrypt("\021\062", "2587")),(decrypt("\015\091\093\104\081\095\087\070\110\092\087\080\082", "776")),(decrypt("\086\068\097\101\081\075\016\042", "959")),(decrypt("\013", "981")),(decrypt("\029\031\063", "1847")),(decrypt("\083\082\095\010\023\047\014\031\038\036\004\027\029\031", "851")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
 Temp[5] = 0
Temp[16] = ttostring ~= __metatable
Stack[Temp[5]] = Temp[6] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[3] = vmEnv
Temp[5] = 6
Temp[6] = Constants[Temp[5]]
Temp[16] = 0
Temp[3][Temp[6]] = Temp[6] 
elseif pointer == 3 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\121\111\090\089", "2352")),(decrypt("\013\084\104\103", "2468")),(decrypt("\115\114\124\117\115\114\127", "557")),((decrypt("\024\023\027\029\026\030\003\031\031\030\025\026\002", "2236"))),(decrypt("\118\110\105\082\094\086", "222")),(decrypt("\010\106\088\082\088\080\066", "1629")),}

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
		local encoded = {(decrypt("\123\009\014\027", "1663")),((decrypt("\027", "1955"))),((decrypt("\021\018\026", "2764"))),((decrypt("\031\025\029\025\031", "2513"))),(decrypt("\008\111\089\085\107", "1735")),(decrypt("\021\060", "2736")),}

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
 	if Stack[1] ~= Constants[6] then pointer = pointer + 1 end 
elseif pointer == 2 then -- 22 [JMP] 
 pointer = pointer + 4  
elseif pointer == 3 then -- 0 [MOVE] 
 Temp[10] = 2
Temp[6] = 1
Stack[Temp[10]] = Stack[Temp[6]] 
elseif pointer == 4 then -- 16 [MOD] 
 	Stack[1] = Stack[0] % Stack[1] 
elseif pointer == 5 then -- 0 [MOVE] 
 Temp[13] = 0
Temp[5] = 2
Stack[Temp[13]] = Stack[Temp[5]] 
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
		local encoded = {(decrypt("\025\062", "1517")),(decrypt("\089\085\094\083", "2829")),(decrypt("\017\056", "635")),((decrypt("\030\021\026", "722"))),(decrypt("\024\058", "1166")),((decrypt("\026\017\031", "666"))),(decrypt("\080\065\085\091", "725")),(decrypt("\117\083\089\093\109", "1557")),(decrypt("\092\065\077\069\104", "2580")),}

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
 	if Stack[0] < Constants[5] then pointer = pointer + 1 end 
elseif pointer == 2 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 3 then -- 2 [LOADBOOL] 
 Temp[13] = 1
Temp[4] = byte == pairs
Stack[Temp[13]] = Temp[11] 
elseif pointer == 4 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[9] = 1
Temp[2] = Constants
Temp[7] = 5
Stack[Temp[9]] = Temp[2][Temp[7]] 
elseif pointer == 6 then -- 5 [GETGLOBAL] 
 Temp[15] = 2
Temp[10] = 7
Temp[3] = Constants[Temp[10]]
Stack[Temp[15]] = vmEnv[Temp[3]] or Env[Temp[3]]
	Stack[2] = Stack[2][Constants[9]]
	
	pointer = pointer + 1 
elseif pointer == 8 then -- 5 [GETGLOBAL] 
 Temp[15] = 3
Temp[10] = 7
Temp[7] = Constants[Temp[10]]
Stack[Temp[15]] = vmEnv[Temp[7]] or Env[Temp[7]]
	Stack[3] = Stack[3][Constants[2]]
	
	pointer = pointer + 1 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[13] = 4
Temp[1] = 0
Stack[Temp[13]] = Stack[Temp[1]] 
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
 Temp[10] = 3
Temp[12] = Constants
Temp[2] = 1
Stack[Temp[10]] = Temp[12][Temp[2]] 
elseif pointer == 14 then -- 32 [FORPREP] 
     Stack[1] = Stack[1] - Stack[3]
    pointer = pointer + 5
     
elseif pointer == 15 then -- 16 [MOD] 
 	Stack[5] = Stack[0] % Stack[4] 
elseif pointer == 16 then -- 23 [EQ] 
 	if Stack[5] == Constants[3] then pointer = pointer + 1 end 
elseif pointer == 17 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 18 then -- 2 [LOADBOOL] 
 Temp[13] = 5
Temp[5] = byte == pairs
Stack[Temp[13]] = Temp[15] 
elseif pointer == 19 then -- 30 [RETURN] 
 	return Stack[5] 
elseif pointer == 20 then -- 31 [FORLOOP] 
     Stack[1] = Stack[1] + Stack[3]
    if (Stack[3] > 0 and Stack[1] <= Stack[2]) or (Stack[3] <= 0 and Stack[1] >= Stack[2]) then
        pointer = pointer + -6
        Stack[4] = Stack[1]
    end
     
elseif pointer == 21 then -- 2 [LOADBOOL] 
 Temp[11] = 1
Temp[6] = ttostring ~= __metatable
Stack[Temp[11]] = Temp[2] 
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
		local encoded = {(decrypt("\118\086\087\083\107\064\126\111\088\093\084\105\109", "1043")),(decrypt("\114\084\089\101\091\084\106\090\037\109\091\080\084\088", "2129")),(decrypt("\065\088\081\107\086", "2800")),(decrypt("\026\050", "2950")),(decrypt("\120\110\106\086\087\105\090", "2200")),(decrypt("\121\100\096\081", "288")),(decrypt("\110\077\096\106\104\087\079\091", "2896")),(decrypt("\087\105\106\080\085\092", "1336")),}

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
 Temp[10] = 3
Temp[12] = Constants
Temp[9] = 4
Stack[Temp[10]] = Temp[12][Temp[9]] 
elseif pointer == 3 then -- 20 [LEN] 
 	Stack[4] = #Stack[0] 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[4] = 5
Temp[5] = Constants
Temp[12] = 4
Stack[Temp[4]] = Temp[5][Temp[12]] 
elseif pointer == 5 then -- 32 [FORPREP] 
     Stack[3] = Stack[3] - Stack[5]
    pointer = pointer + 6
     
elseif pointer == 6 then -- 20 [LEN] 
 	Stack[7] = #Stack[2] 
elseif pointer == 7 then -- 12 [ADD] 
 	Stack[7] = Stack[7] + Constants[4] 
elseif pointer == 8 then -- 5 [GETGLOBAL] 
 Temp[5] = 8
Temp[6] = 7
Temp[13] = Constants[Temp[6]]
Stack[Temp[5]] = vmEnv[Temp[13]] or Env[Temp[13]] 
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
 Temp[3] = 3
Temp[4] = 3
Temp[8] = Constants[Temp[4]]
Stack[Temp[3]] = vmEnv[Temp[8]] or Env[Temp[8]]
	Stack[3] = Stack[3][Constants[8]]
	
	pointer = pointer + 1 
elseif pointer == 15 then -- 0 [MOVE] 
 Temp[5] = 4
Temp[11] = 2
Stack[Temp[5]] = Stack[Temp[11]] 
elseif pointer == 16 then -- 0 [MOVE] 
 Temp[5] = 5
Temp[14] = 1
Stack[Temp[5]] = Stack[Temp[14]] 
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
Temp[4] = Constants
Temp[13] = 7
Stack[Temp[10]] = Temp[4][Temp[13]] 
elseif pointer == 9 then -- 1 [LOADK] 
 Temp[2] = 6
Temp[15] = Constants
Temp[6] = 24
Stack[Temp[2]] = Temp[15][Temp[6]] 
elseif pointer == 10 then -- 1 [LOADK] 
 Temp[6] = 7
Temp[14] = Constants
Temp[5] = 7
Stack[Temp[6]] = Temp[14][Temp[5]] 
elseif pointer == 11 then -- 32 [FORPREP] 
     Stack[5] = Stack[5] - Stack[7]
    pointer = pointer + 8
     
elseif pointer == 12 then -- 0 [MOVE] 
 Temp[3] = 9
Temp[7] = 2
Stack[Temp[3]] = Stack[Temp[7]] 
elseif pointer == 13 then -- 0 [MOVE] 
 Temp[7] = 10
Temp[11] = 8
Stack[Temp[7]] = Stack[Temp[11]] 
elseif pointer == 14 then -- 28 [CALL] 
 	Stack[9] = Stack[9](Stack[10]) 
elseif pointer == 15 then -- 26 [TEST] 
 	if Stack[9] then pointer = pointer + 1 end 
elseif pointer == 16 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 17 then -- 20 [LEN] 
 	Stack[9] = #Stack[4] 
elseif pointer == 18 then -- 12 [ADD] 
 	Stack[9] = Stack[9] + Constants[7] 
elseif pointer == 19 then -- 9 [SETTABLE] 
 	Stack[4][Stack[9]] = Stack[8] 
elseif pointer == 20 then -- 31 [FORLOOP] 
     Stack[5] = Stack[5] + Stack[7]
    if (Stack[7] > 0 and Stack[5] <= Stack[6]) or (Stack[7] <= 0 and Stack[5] >= Stack[6]) then
        pointer = pointer + -9
        Stack[8] = Stack[5]
    end
     
elseif pointer == 21 then -- 5 [GETGLOBAL] 
 Temp[5] = 5
Temp[7] = 4
Temp[15] = Constants[Temp[7]]
Stack[Temp[5]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 22 then -- 1 [LOADK] 
 Temp[9] = 6
Temp[12] = Constants
Temp[14] = 22
Stack[Temp[9]] = Temp[12][Temp[14]] 
elseif pointer == 23 then -- 0 [MOVE] 
 Temp[14] = 7
Temp[15] = 3
Stack[Temp[14]] = Stack[Temp[15]] 
elseif pointer == 24 then -- 0 [MOVE] 
 Temp[7] = 8
Temp[4] = 4
Stack[Temp[7]] = Stack[Temp[4]] 
elseif pointer == 25 then -- 1 [LOADK] 
 Temp[11] = 9
Temp[7] = Constants
Temp[10] = 14
Stack[Temp[11]] = Temp[7][Temp[10]]
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
 Temp[14] = 5
Temp[12] = 4
Temp[15] = Constants[Temp[12]]
Stack[Temp[14]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 30 then -- 1 [LOADK] 
 Temp[13] = 6
Temp[6] = Constants
Temp[2] = 25
Stack[Temp[13]] = Temp[6][Temp[2]] 
elseif pointer == 31 then -- 0 [MOVE] 
 Temp[9] = 7
Temp[7] = 1
Stack[Temp[9]] = Stack[Temp[7]] 
elseif pointer == 32 then -- 1 [LOADK] 
 Temp[16] = 8
Temp[15] = Constants
Temp[13] = 1
Stack[Temp[16]] = Temp[15][Temp[13]] 
elseif pointer == 33 then -- 1 [LOADK] 
 Temp[13] = 9
Temp[3] = Constants
Temp[16] = 9
Stack[Temp[13]] = Temp[3][Temp[16]]
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
 Temp[4] = 5
Temp[10] = 4
Temp[8] = Constants[Temp[10]]
Stack[Temp[4]] = vmEnv[Temp[8]] or Env[Temp[8]] 
elseif pointer == 38 then -- 1 [LOADK] 
 Temp[1] = 6
Temp[8] = Constants
Temp[12] = 2
Stack[Temp[1]] = Temp[8][Temp[12]] 
elseif pointer == 39 then -- 0 [MOVE] 
 Temp[5] = 7
Temp[14] = 0
Stack[Temp[5]] = Stack[Temp[14]] 
elseif pointer == 40 then -- 1 [LOADK] 
 Temp[11] = 8
Temp[12] = Constants
Temp[5] = 17
Stack[Temp[11]] = Temp[12][Temp[5]] 
elseif pointer == 41 then -- 1 [LOADK] 
 Temp[14] = 9
Temp[7] = Constants
Temp[11] = 20
Stack[Temp[14]] = Temp[7][Temp[11]] 
elseif pointer == 42 then -- 1 [LOADK] 
 Temp[7] = 10
Temp[4] = Constants
Temp[6] = 16
Stack[Temp[7]] = Temp[4][Temp[6]]
	Stack[7] = Stack[7](Stack[8], Stack[9], Stack[10])
	pointer = pointer + 1 
elseif pointer == 44 then -- 1 [LOADK] 
 Temp[5] = 8
Temp[1] = Constants
Temp[12] = 23
Stack[Temp[5]] = Temp[1][Temp[12]] 
elseif pointer == 45 then -- 0 [MOVE] 
 Temp[7] = 9
Temp[10] = 0
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 46 then -- 1 [LOADK] 
 Temp[3] = 10
Temp[7] = Constants
Temp[8] = 15
Stack[Temp[3]] = Temp[7][Temp[8]] 
elseif pointer == 47 then -- 1 [LOADK] 
 Temp[15] = 11
Temp[3] = Constants
Temp[11] = 20
Stack[Temp[15]] = Temp[3][Temp[11]] 
elseif pointer == 48 then -- 1 [LOADK] 
 Temp[14] = 12
Temp[7] = Constants
Temp[4] = 16
Stack[Temp[14]] = Temp[7][Temp[4]]
	Stack[9] = Stack[9](Stack[10], Stack[11], Stack[12])
	pointer = pointer + 1 
elseif pointer == 50 then -- 1 [LOADK] 
 Temp[8] = 10
Temp[15] = Constants
Temp[5] = 23
Stack[Temp[8]] = Temp[15][Temp[5]] 
elseif pointer == 51 then -- 0 [MOVE] 
 Temp[16] = 11
Temp[15] = 0
Stack[Temp[16]] = Stack[Temp[15]] 
elseif pointer == 52 then -- 1 [LOADK] 
 Temp[16] = 12
Temp[4] = Constants
Temp[12] = 8
Stack[Temp[16]] = Temp[4][Temp[12]] 
elseif pointer == 53 then -- 1 [LOADK] 
 Temp[11] = 13
Temp[16] = Constants
Temp[9] = 20
Stack[Temp[11]] = Temp[16][Temp[9]] 
elseif pointer == 54 then -- 1 [LOADK] 
 Temp[6] = 14
Temp[10] = Constants
Temp[15] = 16
Stack[Temp[6]] = Temp[10][Temp[15]]
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
 Temp[10] = 5
Temp[16] = 4
Temp[4] = Constants[Temp[16]]
Stack[Temp[10]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 59 then -- 5 [GETGLOBAL] 
 Temp[11] = 6
Temp[12] = 3
Temp[4] = Constants[Temp[12]]
Stack[Temp[11]] = vmEnv[Temp[4]] or Env[Temp[4]]
	Stack[6] = Stack[6][Constants[18]]
	
	pointer = pointer + 1 
elseif pointer == 61 then -- 1 [LOADK] 
 Temp[14] = 7
Temp[1] = Constants
Temp[12] = 11
Stack[Temp[14]] = Temp[1][Temp[12]] 
elseif pointer == 62 then -- 1 [LOADK] 
 Temp[13] = 8
Temp[4] = Constants
Temp[7] = 12
Stack[Temp[13]] = Temp[4][Temp[7]] 
elseif pointer == 63 then -- 1 [LOADK] 
 Temp[10] = 9
Temp[2] = Constants
Temp[8] = 5
Stack[Temp[10]] = Temp[2][Temp[8]] 
elseif pointer == 64 then -- 1 [LOADK] 
 Temp[14] = 10
Temp[1] = Constants
Temp[6] = 8
Stack[Temp[14]] = Temp[1][Temp[6]]
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