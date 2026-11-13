return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\085\081\083\092\089", "2839")),(decrypt("\037\088\094\036", "2843")),(decrypt("\086\084\110\086\090\092", "636")),(decrypt("\093\092\107\110\104\107\106", "2337")),(decrypt("\027\026\061", "2464")),(decrypt("\026\021\031\023\057", "2280")),(decrypt("\030\059", "900")),(decrypt("\014\012\013\008", "1053")),(decrypt("\001\027\050", "1598")),(decrypt("\002\031\029\026\030\059", "2037")),(decrypt("\007\009\001\003", "859")),(decrypt("\124\106\087\091\015\084\094\010\109\082\084\107", "2270")),(decrypt("\098\084\084\091\106\092\073\045", "827")),(decrypt("\002\028\061", "2461")),(decrypt("\028\058", "2175")),(decrypt("\011\082\089\086\104\081\092\108", "1192")),(decrypt("\097\096\104\086", "981")),(decrypt("\031\058", "2127")),(decrypt("\019\039\006\036", "302")),(decrypt("\100\113\013\005\126\125\014\000\121\011\015", "2748")),(decrypt("\025\025\063", "2045")),(decrypt("\029\021\059", "990")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
elseif pointer == 3 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\030\050", "791")),(decrypt("\025\063", "1432")),(decrypt("\119\080\094\036\111\080\089\086\105", "2653")),(decrypt("\018\057", "825")),(decrypt("\021\051", "2820")),(decrypt("\114\083\087\091\082\110\084\080\067\106\108", "2670")),}

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
 Temp[16] = 1
Temp[4] = Constants
Temp[12] = 5
Stack[Temp[16]] = Temp[4][Temp[12]] 
elseif pointer == 2 then -- 23 [EQ] 
 	if Stack[0] ~= Constants[2] then pointer = pointer + 1 end 
elseif pointer == 3 then -- 22 [JMP] 
 pointer = pointer + 9  
elseif pointer == 4 then -- 16 [MOD] 
 	Stack[2] = Stack[0] % Constants[1] 
elseif pointer == 5 then -- 23 [EQ] 
 	if Stack[2] == Constants[5] then pointer = pointer + 1 end 
elseif pointer == 6 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 7 then -- 15 [DIV] 
 	Stack[0] = Stack[0] / Constants[1] 
elseif pointer == 8 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 9 then -- 14 [MUL] 
 	Stack[2] = Constants[4] * Stack[0] 
elseif pointer == 10 then -- 12 [ADD] 
 	Stack[0] = Stack[2] + Constants[2] 
elseif pointer == 11 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Constants[2] 
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
		local encoded = {(decrypt("\017\051", "680")),(decrypt("\091\086\104\091\082", "1208")),(decrypt("\025\031\050", "1894")),(decrypt("\120\084\085\080\081\093\110", "1805")),(decrypt("\085\100\098\089\093\092", "1899")),(decrypt("\013\110\093\116\091\086\087\106\095\067\117\110\090\089\012\014\091\110\087\110", "326")),(decrypt("\084\104\107\111\090\084\088\107", "1457")),(decrypt("\081\110\091\106\110", "2624")),(decrypt("\025\019\017\058", "146")),(decrypt("\064\109\091\081", "1127")),(decrypt("\015\085\107\090\105\115\106\116\082\105\089", "2579")),(decrypt("\005\084\080\086\106\080\099", "829")),(decrypt("\014\096\089\089", "283")),}

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
 	if Stack[0] < Constants[1] then pointer = pointer + 1 end 
elseif pointer == 2 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[9] = 1
Temp[4] = Constants
Temp[1] = 7
Stack[Temp[9]] = Temp[4][Temp[1]] 
elseif pointer == 4 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 5 then -- 22 [JMP] 
 pointer = pointer + 17  
elseif pointer == 6 then -- 23 [EQ] 
 	if Stack[0] == Constants[1] then pointer = pointer + 1 end 
elseif pointer == 7 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 8 then -- 1 [LOADK] 
 Temp[1] = 1
Temp[9] = Constants
Temp[11] = 10
Stack[Temp[1]] = Temp[9][Temp[11]] 
elseif pointer == 9 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 10 then -- 22 [JMP] 
 pointer = pointer + 12  
elseif pointer == 11 then -- 24 [LT] 
 	if Stack[0] < Constants[3] then pointer = pointer + 1 end 
elseif pointer == 12 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 13 then -- 1 [LOADK] 
 Temp[16] = 1
Temp[3] = Constants
Temp[11] = 2
Stack[Temp[16]] = Temp[3][Temp[11]] 
elseif pointer == 14 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 15 then -- 22 [JMP] 
 pointer = pointer + 7  
elseif pointer == 16 then -- 24 [LT] 
 	if Stack[0] < Constants[9] then pointer = pointer + 1 end 
elseif pointer == 17 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 18 then -- 1 [LOADK] 
 Temp[3] = 1
Temp[13] = Constants
Temp[6] = 5
Stack[Temp[3]] = Temp[13][Temp[6]] 
elseif pointer == 19 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 20 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 21 then -- 1 [LOADK] 
 Temp[14] = 1
Temp[1] = Constants
Temp[3] = 8
Stack[Temp[14]] = Temp[1][Temp[3]] 
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
		local encoded = {((decrypt("\022\016\021", "1595"))),(decrypt("\026\050", "2909")),(decrypt("\008\082\082\107\107\091\111\105", "328")),(decrypt("\022\061", "1663")),(decrypt("\013\082\095\086\120\101\093\092\082\099\104", "2941")),(decrypt("\024\050", "1955")),(decrypt("\124\011\009\030", "641")),((decrypt("\024", "2764"))),(decrypt("\008\085\092\083\081\111\083\104", "2384")),}

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
 Temp[14] = 2
Temp[2] = Constants
Temp[10] = 6
Stack[Temp[14]] = Temp[2][Temp[10]] 
elseif pointer == 2 then -- 0 [MOVE] 
 Temp[3] = 3
Temp[15] = 0
Stack[Temp[3]] = Stack[Temp[15]] 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[10] = 4
Temp[6] = Constants
Temp[13] = 2
Stack[Temp[10]] = Temp[6][Temp[13]] 
elseif pointer == 4 then -- 32 [FORPREP] 
     Stack[2] = Stack[2] - Stack[4]
    pointer = pointer + 5
     
elseif pointer == 5 then -- 16 [MOD] 
 	Stack[6] = Stack[0] % Stack[5] 
elseif pointer == 6 then -- 23 [EQ] 
 	if Stack[6] == Constants[4] then pointer = pointer + 1 end 
elseif pointer == 7 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[5] = 1
Temp[4] = 5
Stack[Temp[5]] = Stack[Temp[4]] 
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
		local encoded = {(decrypt("\118\094\094\083\110", "2829")),((decrypt("\024\031\024", "180"))),(decrypt("\124\088\083\081\084\105\109", "635")),(decrypt("\123\087\083", "1783")),(decrypt("\031\021\057", "722")),(decrypt("\020\050", "398")),((decrypt("\024\029\026", "1166"))),(decrypt("\111\080\082\084\090", "234")),(decrypt("\082\110\093\105", "666")),}

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
 Temp[15] = 1
Temp[4] = Constants
Temp[2] = 6
Stack[Temp[15]] = Temp[4][Temp[2]] 
elseif pointer == 2 then -- 16 [MOD] 
 	Stack[2] = Stack[0] % Constants[5] 
elseif pointer == 3 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Stack[2] 
elseif pointer == 4 then -- 5 [GETGLOBAL] 
 Temp[9] = 2
Temp[13] = 9
Temp[14] = Constants[Temp[13]]
Stack[Temp[9]] = vmEnv[Temp[14]] or Env[Temp[14]]
	Stack[2] = Stack[2][Constants[8]]
	
	pointer = pointer + 1 
elseif pointer == 6 then -- 15 [DIV] 
 	Stack[3] = Stack[0] / Constants[5] 
elseif pointer == 7 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3]) 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[13] = 0
Temp[11] = 2
Stack[Temp[13]] = Stack[Temp[11]] 
elseif pointer == 9 then -- 23 [EQ] 
 	if Stack[0] == Constants[6] then pointer = pointer + 1 end 
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
		local encoded = {(decrypt("\008\104\105\081\106\109\090\100\091\126\109\092\084\090\081\093\108", "2718")),(decrypt("\090\097\097\082\109", "1981")),(decrypt("\091\108\101\084\009\009", "1091")),(decrypt("\089\084\106", "383")),(decrypt("\107", "1783")),(decrypt("\013\084\105\081\091\107\106", "1716")),(decrypt("\108\094\083\108\096\093", "686")),(decrypt("\106", "339")),(decrypt("\009\091\088\087\097\088\086\102", "388")),(decrypt("\088\093\109\091\093", "265")),(decrypt("\007", "2687")),(decrypt("\106", "2644")),(decrypt("\026\058", "2144")),(decrypt("\094\106\101\081\014", "469")),(decrypt("\105\105\107\108\086\088", "1310")),}

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
 Temp[13] = 1
Temp[9] = Constants
Temp[6] = 10
Stack[Temp[13]] = Temp[9][Temp[6]] 
elseif pointer == 2 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[6] = 3
Temp[12] = Constants
Temp[4] = 13
Stack[Temp[6]] = Temp[12][Temp[4]] 
elseif pointer == 4 then -- 20 [LEN] 
 	Stack[4] = #Stack[0] 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[15] = 5
Temp[2] = Constants
Temp[16] = 13
Stack[Temp[15]] = Temp[2][Temp[16]] 
elseif pointer == 6 then -- 32 [FORPREP] 
     Stack[3] = Stack[3] - Stack[5]
    pointer = pointer + 31
     
elseif pointer == 7 then -- 11 [SELF] 
 	Stack[8] = Stack[0]
	if Stack[8] then
		Stack[7] = Stack[0][Constants[4]]
	end
	 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[16] = 9
Temp[12] = 6
Stack[Temp[16]] = Stack[Temp[12]] 
elseif pointer == 9 then -- 0 [MOVE] 
 Temp[11] = 10
Temp[2] = 6
Stack[Temp[11]] = Stack[Temp[2]] 
elseif pointer == 10 then -- 28 [CALL] 
 	Stack[7] = Stack[7](Stack[8], Stack[9], Stack[10]) 
elseif pointer == 11 then -- 23 [EQ] 
 	if Stack[1] == Constants[10] then pointer = pointer + 1 end 
elseif pointer == 12 then -- 22 [JMP] 
 pointer = pointer + 4  
elseif pointer == 13 then -- 23 [EQ] 
 	if Stack[7] == Constants[12] then pointer = pointer + 1 end 
elseif pointer == 14 then -- 22 [JMP] 
 pointer = pointer + 20  
elseif pointer == 15 then -- 1 [LOADK] 
 Temp[9] = 1
Temp[16] = Constants
Temp[6] = 14
Stack[Temp[9]] = Temp[16][Temp[6]] 
elseif pointer == 16 then -- 22 [JMP] 
 pointer = pointer + 18  
elseif pointer == 17 then -- 23 [EQ] 
 	if Stack[1] == Constants[14] then pointer = pointer + 1 end 
elseif pointer == 18 then -- 22 [JMP] 
 pointer = pointer + 8  
elseif pointer == 19 then -- 23 [EQ] 
 	if Stack[7] == Constants[8] then pointer = pointer + 1 end 
elseif pointer == 20 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 21 then -- 1 [LOADK] 
 Temp[7] = 1
Temp[10] = Constants
Temp[12] = 3
Stack[Temp[7]] = Temp[10][Temp[12]] 
elseif pointer == 22 then -- 22 [JMP] 
 pointer = pointer + 12  
elseif pointer == 23 then -- 23 [EQ] 
 	if Stack[7] ~= Constants[12] then pointer = pointer + 1 end 
elseif pointer == 24 then -- 22 [JMP] 
 pointer = pointer + 10  
elseif pointer == 25 then -- 1 [LOADK] 
 Temp[9] = 1
Temp[4] = Constants
Temp[5] = 10
Stack[Temp[9]] = Temp[4][Temp[5]] 
elseif pointer == 26 then -- 22 [JMP] 
 pointer = pointer + 8  
elseif pointer == 27 then -- 23 [EQ] 
 	if Stack[1] == Constants[3] then pointer = pointer + 1 end 
elseif pointer == 28 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 29 then -- 23 [EQ] 
 	if Stack[7] == Constants[5] then pointer = pointer + 1 end 
elseif pointer == 30 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 31 then -- 1 [LOADK] 
 Temp[12] = 8
Temp[5] = Constants
Temp[6] = 15
Stack[Temp[12]] = Temp[5][Temp[6]] 
elseif pointer == 32 then -- 27 [TESTSET] 
 	if (not Stack[8]) then
		pointer = pointer + 1
	else
		Stack[1] = Stack[8]
	end
	 
elseif pointer == 33 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 34 then -- 1 [LOADK] 
 Temp[13] = 1
Temp[3] = Constants
Temp[4] = 10
Stack[Temp[13]] = Temp[3][Temp[4]] 
elseif pointer == 35 then -- 20 [LEN] 
 	Stack[8] = #Stack[2] 
elseif pointer == 36 then -- 12 [ADD] 
 	Stack[8] = Stack[8] + Constants[13] 
elseif pointer == 37 then -- 9 [SETTABLE] 
 	Stack[2][Stack[8]] = Stack[1] 
elseif pointer == 38 then -- 31 [FORLOOP] 
     Stack[3] = Stack[3] + Stack[5]
    if (Stack[5] > 0 and Stack[3] <= Stack[4]) or (Stack[5] <= 0 and Stack[3] >= Stack[4]) then
        pointer = pointer + -32
        Stack[6] = Stack[3]
    end
     
elseif pointer == 39 then -- 0 [MOVE] 
 Temp[8] = 3
Temp[5] = 1
Stack[Temp[8]] = Stack[Temp[5]] 
elseif pointer == 40 then -- 5 [GETGLOBAL] 
 Temp[11] = 4
Temp[5] = 2
Temp[14] = Constants[Temp[5]]
Stack[Temp[11]] = vmEnv[Temp[14]] or Env[Temp[14]]
	Stack[4] = Stack[4][Constants[7]]
	
	pointer = pointer + 1 
elseif pointer == 42 then -- 0 [MOVE] 
 Temp[16] = 5
Temp[11] = 2
Stack[Temp[16]] = Stack[Temp[11]] 
elseif pointer == 43 then -- 1 [LOADK] 
 Temp[9] = 6
Temp[4] = Constants
Temp[11] = 11
Stack[Temp[9]] = Temp[4][Temp[11]]
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
 Temp[14] = 5
Temp[6] = 3
Temp[15] = Constants[Temp[6]]
Stack[Temp[14]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 9 then -- 10 [NEWTABLE] 
 	Stack[6] = {} 
elseif pointer == 10 then -- 1 [LOADK] 
 Temp[13] = 7
Temp[9] = Constants
Temp[11] = 18
Stack[Temp[13]] = Temp[9][Temp[11]] 
elseif pointer == 11 then -- 1 [LOADK] 
 Temp[10] = 8
Temp[5] = Constants
Temp[16] = 15
Stack[Temp[10]] = Temp[5][Temp[16]] 
elseif pointer == 12 then -- 1 [LOADK] 
 Temp[15] = 9
Temp[13] = Constants
Temp[10] = 5
Stack[Temp[15]] = Temp[13][Temp[10]] 
elseif pointer == 13 then -- 34 [SETLIST] 
 	for i = 1, 3 do
		Stack[6][(1 - 1) * 50 + i] = Stack[6 + i]
	end
	 
elseif pointer == 14 then -- 28 [CALL] 
 	Stack[5], Stack[6], Stack[7] = Stack[5](Stack[6]) 
elseif pointer == 15 then -- 22 [JMP] 
 pointer = pointer + 9  
elseif pointer == 16 then -- 5 [GETGLOBAL] 
 Temp[3] = 10
Temp[9] = 1
Temp[14] = Constants[Temp[9]]
Stack[Temp[3]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 17 then -- 1 [LOADK] 
 Temp[16] = 11
Temp[4] = Constants
Temp[5] = 13
Stack[Temp[16]] = Temp[4][Temp[5]] 
elseif pointer == 18 then -- 0 [MOVE] 
 Temp[15] = 12
Temp[5] = 9
Stack[Temp[15]] = Stack[Temp[5]] 
elseif pointer == 19 then -- 1 [LOADK] 
 Temp[4] = 13
Temp[10] = Constants
Temp[5] = 19
Stack[Temp[4]] = Temp[10][Temp[5]] 
elseif pointer == 20 then -- 0 [MOVE] 
 Temp[5] = 14
Temp[16] = 0
Stack[Temp[5]] = Stack[Temp[16]] 
elseif pointer == 21 then -- 0 [MOVE] 
 Temp[6] = 15
Temp[3] = 9
Stack[Temp[6]] = Stack[Temp[3]] 
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
 Temp[5] = 5
Temp[6] = 3
Temp[16] = Constants[Temp[6]]
Stack[Temp[5]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 28 then -- 10 [NEWTABLE] 
 	Stack[6] = {} 
elseif pointer == 29 then -- 1 [LOADK] 
 Temp[10] = 7
Temp[4] = Constants
Temp[13] = 22
Stack[Temp[10]] = Temp[4][Temp[13]] 
elseif pointer == 30 then -- 1 [LOADK] 
 Temp[2] = 8
Temp[15] = Constants
Temp[6] = 7
Stack[Temp[2]] = Temp[15][Temp[6]] 
elseif pointer == 31 then -- 1 [LOADK] 
 Temp[6] = 9
Temp[14] = Constants
Temp[5] = 15
Stack[Temp[6]] = Temp[14][Temp[5]] 
elseif pointer == 32 then -- 1 [LOADK] 
 Temp[3] = 10
Temp[7] = Constants
Temp[11] = 21
Stack[Temp[3]] = Temp[7][Temp[11]] 
elseif pointer == 33 then -- 1 [LOADK] 
 Temp[5] = 11
Temp[7] = Constants
Temp[15] = 6
Stack[Temp[5]] = Temp[7][Temp[15]] 
elseif pointer == 34 then -- 34 [SETLIST] 
 	for i = 1, 5 do
		Stack[6][(1 - 1) * 50 + i] = Stack[6 + i]
	end
	 
elseif pointer == 35 then -- 28 [CALL] 
 	Stack[5], Stack[6], Stack[7] = Stack[5](Stack[6]) 
elseif pointer == 36 then -- 22 [JMP] 
 pointer = pointer + 8  
elseif pointer == 37 then -- 5 [GETGLOBAL] 
 Temp[9] = 10
Temp[12] = 1
Temp[14] = Constants[Temp[12]]
Stack[Temp[9]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 38 then -- 0 [MOVE] 
 Temp[14] = 11
Temp[15] = 9
Stack[Temp[14]] = Stack[Temp[15]] 
elseif pointer == 39 then -- 1 [LOADK] 
 Temp[7] = 12
Temp[4] = Constants
Temp[11] = 2
Stack[Temp[7]] = Temp[4][Temp[11]] 
elseif pointer == 40 then -- 0 [MOVE] 
 Temp[7] = 13
Temp[10] = 1
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 41 then -- 0 [MOVE] 
 Temp[14] = 14
Temp[12] = 9
Stack[Temp[14]] = Stack[Temp[12]] 
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
 Temp[15] = 5
Temp[13] = 1
Temp[6] = Constants[Temp[13]]
Stack[Temp[15]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 48 then -- 0 [MOVE] 
 Temp[2] = 6
Temp[9] = 2
Stack[Temp[2]] = Stack[Temp[9]] 
elseif pointer == 49 then -- 1 [LOADK] 
 Temp[7] = 7
Temp[16] = Constants
Temp[15] = 14
Stack[Temp[7]] = Temp[16][Temp[15]]
	Stack[6] = Stack[6](Stack[7])
	pointer = pointer + 1 
elseif pointer == 51 then -- 0 [MOVE] 
 Temp[13] = 7
Temp[3] = 2
Stack[Temp[13]] = Stack[Temp[3]] 
elseif pointer == 52 then -- 1 [LOADK] 
 Temp[16] = 8
Temp[4] = Constants
Temp[10] = 9
Stack[Temp[16]] = Temp[4][Temp[10]]
	Stack[7] = Stack[7](Stack[8])
	pointer = pointer + 1 
elseif pointer == 54 then -- 0 [MOVE] 
 Temp[10] = 8
Temp[8] = 3
Stack[Temp[10]] = Stack[Temp[8]] 
elseif pointer == 55 then -- 1 [LOADK] 
 Temp[1] = 9
Temp[8] = Constants
Temp[12] = 10
Stack[Temp[1]] = Temp[8][Temp[12]]
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
 Temp[5] = 5
Temp[14] = 1
Temp[11] = Constants[Temp[14]]
Stack[Temp[5]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 59 then -- 0 [MOVE] 
 Temp[12] = 6
Temp[5] = 4
Stack[Temp[12]] = Stack[Temp[5]] 
elseif pointer == 60 then -- 1 [LOADK] 
 Temp[14] = 7
Temp[7] = Constants
Temp[11] = 4
Stack[Temp[14]] = Temp[7][Temp[11]]
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
 Temp[7] = 5
Temp[4] = 1
Temp[6] = Constants[Temp[4]]
Stack[Temp[7]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 64 then -- 0 [MOVE] 
 Temp[5] = 6
Temp[1] = 4
Stack[Temp[5]] = Stack[Temp[1]] 
elseif pointer == 65 then -- 1 [LOADK] 
 Temp[12] = 7
Temp[7] = Constants
Temp[10] = 17
Stack[Temp[12]] = Temp[7][Temp[10]]
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