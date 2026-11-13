return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\030\020\061", "636")),(decrypt("\026\029\061", "2464")),(decrypt("\006\127\124\113\009\011\114\125\010\112\122", "900")),(decrypt("\008\117\114\005\112\127\114\007\117\011\002\107\122\112\005\126", "1598")),(decrypt("\017\062", "859")),(decrypt("\016\057", "827")),(decrypt("\028\058", "2175")),(decrypt("\006\004\009\002", "981")),(decrypt("\111\090\067\089\092\107", "302")),(decrypt("\004", "2045")),(decrypt("\008\011\127\012\118\122\126\116\112\015\008\103\126\100\102\112\123\102", "243")),(decrypt("\009\093\083\104\087\088\088\070\105\090\088\081\084", "1187")),(decrypt("\081\090\099\080\092\091", "2683")),(decrypt("\067\087\110\108\071", "2847")),(decrypt("\029\059", "1018")),(decrypt("\084\088\082\064\092", "2341")),(decrypt("\124\104\082\088\015\086\091\009\109\080\081\104", "2023")),(decrypt("\002\080\084\092\106\084\093\109", "834")),(decrypt("\121\097\012\114\120\127\126\115\121\125\100\000\119\119\102\127\114", "2759")),(decrypt("\021\018\062", "1859")),(decrypt("\022\061", "1601")),(decrypt("\025\050", "2979")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
elseif pointer == 3 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\008\083\083\094\081\105\092\101", "2579")),(decrypt("\012\100\088\009\100\089\104\100\086\105\096\086\089\082", "283")),(decrypt("\124\082\111\095\082\107\095\007\091\086", "697")),((decrypt("\029", "132"))),(decrypt("\117\002\027", "1978")),}

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
		if pointer == 1 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 4 then -- 7 [SETGLOBAL] 
 Temp[6] = vmEnv
Temp[3] = 11
Temp[5] = Constants[Temp[3]]
Temp[16] = 0
Temp[6][Temp[5]] = Temp[5] 
elseif pointer == 5 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\015\104\105\082\111\111\111", "443")),(decrypt("\011\095\084\084\106\095\092\082", "1927")),(decrypt("\011\094\086\080\088", "1856")),(decrypt("\120\100\110\095", "1866")),(decrypt("\127\108\081\089\012\082\088\008\110\084\082\105", "1412")),(decrypt("\123\106\089\085\106\088\086\082\087\104", "2632")),}

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
	
	Stack[0] = function(...) -- PROTOTYPE 2
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
		if pointer == 1 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 6 then -- 7 [SETGLOBAL] 
 Temp[10] = vmEnv
Temp[4] = 4
Temp[13] = Constants[Temp[4]]
Temp[2] = 0
Temp[10][Temp[13]] = Temp[13] 
elseif pointer == 7 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\013\105\105\080\089\106", "2513")),(decrypt("\122\094\107\111\109", "1735")),((decrypt("\025\016\025", "2736"))),(decrypt("\124\108\093\087\108\080\104\108", "1047")),}

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
	
	Stack[0] = function(...) -- PROTOTYPE 3
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
		if pointer == 1 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 8 then -- 7 [SETGLOBAL] 
 Temp[15] = vmEnv
Temp[6] = 19
Temp[5] = Constants[Temp[6]]
Temp[14] = 0
Temp[15][Temp[5]] = Temp[5] 
elseif pointer == 9 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\124\106\010\124\117\112\124\117\124\126\098\010\118\120\100\113\115", "2922")),(decrypt("\120\106\106\087\087\109\090", "2601")),(decrypt("\013\101\108\090\103\034\082\095\110\106\046\105\083\097\108\085\101\110", "695")),(decrypt("\012\096\080\082\100\107\038\083\086\038\088\085\081\083\080\105\091\080\064\100", "180")),(decrypt("\124\087\082\083\104\084\100", "1783")),((decrypt("\027\030\031\020\030\031\020", "398"))),}

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
	
	Stack[0] = function(...) -- PROTOTYPE 4
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
 Temp[6] = 2
Temp[1] = 1
Temp[4] = Constants[Temp[1]]
Stack[Temp[6]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 2 then -- 2 [LOADBOOL] 
 Temp[15] = 3
Temp[4] = ttostring ~= __metatable
Stack[Temp[15]] = Temp[2] 
elseif pointer == 3 then -- 28 [CALL] 
 	Stack[2](Stack[3]) 
elseif pointer == 4 then -- 12 [ADD] 
 	Stack[2] = Stack[0] + Stack[1] 
elseif pointer == 5 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 6 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 10 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {(decrypt("\009\113\122\015\008\015\008\014\009\013\114\125\103\103\112\098\098", "2734")),(decrypt("\114\108\106\086\092\085", "601")),(decrypt("\123\107\090\090\109\094\121\092\087\094\107\105\109", "1737")),((decrypt("\021\022\026\025\024", "2303"))),(decrypt("\117\094\084\089\109", "1883")),}

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
	
	Stack[1] = function(...) -- PROTOTYPE 5
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
 Temp[12] = 2
Temp[2] = 1
Temp[13] = Constants[Temp[2]]
Stack[Temp[12]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 2 then -- 2 [LOADBOOL] 
 Temp[5] = 3
Temp[11] = ttostring ~= __metatable
Stack[Temp[5]] = Temp[15] 
elseif pointer == 3 then -- 28 [CALL] 
 	Stack[2](Stack[3]) 
elseif pointer == 4 then -- 14 [MUL] 
 	Stack[2] = Stack[0] * Stack[1] 
elseif pointer == 5 then -- 15 [DIV] 
 	Stack[3] = Stack[0] / Stack[1] 
elseif pointer == 6 then -- 30 [RETURN] 
 	return Stack[2], Stack[3] 
elseif pointer == 7 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 11 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[6] then
		C1 = {}
		local encoded = {(decrypt("\068\092\088", "1043")),(decrypt("\120\109\104\095\087\106\088", "2129")),(decrypt("\111\092\086\080\065\096\069\084", "2800")),(decrypt("\068\110\091\081", "2950")),(decrypt("\124\097\008\122\100\015\008\100\125\123\120\112\010\118\113\102\113\115", "2200")),(decrypt("\114\093\083\110\081\093\106\091\047\110\081\081\084\081", "288")),(decrypt("\089\102\082\064", "2896")),(decrypt("\022\056", "1336")),(decrypt("\027\058", "2136")),(decrypt("\113\083\091\086\111\072\124\105\081\091\085\098\106", "658")),(decrypt("\005\112\125\013\013\122\125\119\116\014\013\099\127\113\014\114", "2206")),}

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
	
	Stack[2] = function(...) -- PROTOTYPE 6
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
 Temp[5] = 1
Temp[6] = 5
Temp[13] = Constants[Temp[6]]
Stack[Temp[5]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 2 then -- 28 [CALL] 
 	Stack[1]() 
elseif pointer == 3 then -- 3 [LOADNIL] 
 	Stack[1], Stack[2] = nil 
elseif pointer == 4 then -- 24 [LT] 
 	if Stack[0] < Constants[8] then pointer = pointer + 1 end 
elseif pointer == 5 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 6 then -- 1 [LOADK] 
 Temp[3] = 1
Temp[4] = Constants
Temp[8] = 3
Stack[Temp[3]] = Temp[4][Temp[8]] 
elseif pointer == 7 then -- 22 [JMP] 
 pointer = pointer + 10  
elseif pointer == 8 then -- 23 [EQ] 
 	if Stack[0] == Constants[8] then pointer = pointer + 1 end 
elseif pointer == 9 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 10 then -- 1 [LOADK] 
 Temp[5] = 1
Temp[11] = Constants
Temp[14] = 4
Stack[Temp[5]] = Temp[11][Temp[14]] 
elseif pointer == 11 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 12 then -- 16 [MOD] 
 	Stack[2] = Stack[0] % Constants[9] 
elseif pointer == 13 then -- 23 [EQ] 
 	if Stack[2] == Constants[8] then pointer = pointer + 1 end 
elseif pointer == 14 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 15 then -- 1 [LOADK] 
 Temp[16] = 1
Temp[11] = Constants
Temp[9] = 7
Stack[Temp[16]] = Temp[11][Temp[9]] 
elseif pointer == 16 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 17 then -- 1 [LOADK] 
 Temp[4] = 1
Temp[9] = Constants
Temp[11] = 1
Stack[Temp[4]] = Temp[9][Temp[11]] 
elseif pointer == 18 then -- 5 [GETGLOBAL] 
 Temp[3] = 2
Temp[9] = 11
Temp[6] = Constants[Temp[9]]
Stack[Temp[3]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 19 then -- 28 [CALL] 
 	Stack[2]() 
elseif pointer == 20 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 21 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 12 then -- 1 [LOADK] 
 Temp[3] = 3
Temp[7] = Constants
Temp[11] = 21
Stack[Temp[3]] = Temp[7][Temp[11]] 
elseif pointer == 13 then -- 1 [LOADK] 
 Temp[5] = 4
Temp[7] = Constants
Temp[15] = 6
Stack[Temp[5]] = Temp[7][Temp[15]] 
elseif pointer == 14 then -- 1 [LOADK] 
 Temp[9] = 5
Temp[12] = Constants
Temp[14] = 1
Stack[Temp[9]] = Temp[12][Temp[14]] 
elseif pointer == 15 then -- 1 [LOADK] 
 Temp[14] = 6
Temp[15] = Constants
Temp[7] = 6
Stack[Temp[14]] = Temp[15][Temp[7]] 
elseif pointer == 16 then -- 32 [FORPREP] 
     Stack[4] = Stack[4] - Stack[6]
    pointer = pointer + 5
     
elseif pointer == 17 then -- 0 [MOVE] 
 Temp[7] = 8
Temp[4] = 0
Stack[Temp[7]] = Stack[Temp[4]] 
elseif pointer == 18 then -- 0 [MOVE] 
 Temp[11] = 9
Temp[7] = 3
Stack[Temp[11]] = Stack[Temp[7]] 
elseif pointer == 19 then -- 0 [MOVE] 
 Temp[10] = 10
Temp[14] = 7
Stack[Temp[10]] = Stack[Temp[14]] 
elseif pointer == 20 then -- 28 [CALL] 
 	Stack[8] = Stack[8](Stack[9], Stack[10]) 
elseif pointer == 21 then -- 0 [MOVE] 
 Temp[12] = 3
Temp[15] = 8
Stack[Temp[12]] = Stack[Temp[15]] 
elseif pointer == 22 then -- 31 [FORLOOP] 
     Stack[4] = Stack[4] + Stack[6]
    if (Stack[6] > 0 and Stack[4] <= Stack[5]) or (Stack[6] <= 0 and Stack[4] >= Stack[5]) then
        pointer = pointer + -6
        Stack[7] = Stack[4]
    end
     
elseif pointer == 23 then -- 5 [GETGLOBAL] 
 Temp[13] = 4
Temp[6] = 14
Temp[2] = Constants[Temp[6]]
Stack[Temp[13]] = vmEnv[Temp[2]] or Env[Temp[2]] 
elseif pointer == 24 then -- 1 [LOADK] 
 Temp[9] = 5
Temp[7] = Constants
Temp[16] = 16
Stack[Temp[9]] = Temp[7][Temp[16]] 
elseif pointer == 25 then -- 0 [MOVE] 
 Temp[15] = 6
Temp[13] = 3
Stack[Temp[15]] = Stack[Temp[13]] 
elseif pointer == 26 then -- 28 [CALL] 
 	Stack[4](Stack[5], Stack[6]) 
elseif pointer == 27 then -- 5 [GETGLOBAL] 
 Temp[13] = 4
Temp[3] = 13
Temp[16] = Constants[Temp[3]]
Stack[Temp[13]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 28 then -- 10 [NEWTABLE] 
 	Stack[5] = {} 
elseif pointer == 29 then -- 1 [LOADK] 
 Temp[4] = 6
Temp[10] = Constants
Temp[8] = 20
Stack[Temp[4]] = Temp[10][Temp[8]] 
elseif pointer == 30 then -- 1 [LOADK] 
 Temp[1] = 7
Temp[8] = Constants
Temp[12] = 21
Stack[Temp[1]] = Temp[8][Temp[12]] 
elseif pointer == 31 then -- 1 [LOADK] 
 Temp[5] = 8
Temp[14] = Constants
Temp[11] = 22
Stack[Temp[5]] = Temp[14][Temp[11]] 
elseif pointer == 32 then -- 1 [LOADK] 
 Temp[12] = 9
Temp[5] = Constants
Temp[14] = 7
Stack[Temp[12]] = Temp[5][Temp[14]] 
elseif pointer == 33 then -- 34 [SETLIST] 
 	for i = 1, 4 do
		Stack[5][(1 - 1) * 50 + i] = Stack[5 + i]
	end
	 
elseif pointer == 34 then -- 28 [CALL] 
 	Stack[4], Stack[5], Stack[6] = Stack[4](Stack[5]) 
elseif pointer == 35 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 36 then -- 5 [GETGLOBAL] 
 Temp[7] = 9
Temp[11] = 14
Temp[4] = Constants[Temp[11]]
Stack[Temp[7]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 37 then -- 0 [MOVE] 
 Temp[6] = 10
Temp[5] = 8
Stack[Temp[6]] = Stack[Temp[5]] 
elseif pointer == 38 then -- 0 [MOVE] 
 Temp[1] = 11
Temp[12] = 2
Stack[Temp[1]] = Stack[Temp[12]] 
elseif pointer == 39 then -- 0 [MOVE] 
 Temp[7] = 12
Temp[10] = 8
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 40 then -- 28 [CALL] 
 	Temp[2] = {Stack[11](Stack[12])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[11] = nil
		top = 11
	else
		top = 11 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[11 + i - 1] = Temp[2][i]
		end
	end
	 
elseif pointer == 41 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 9 + 1, top do
		Temp[1][i - 9] = Stack[i]
	end
	Temp[2] = {Stack[9](unpack(Temp[1], 1, top - 9))}
		for i = 1, 0 do
		Stack[9 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 42 then -- 33 [TFORLOOP] 
     local r1, r2 = Stack[4](Stack[5], Stack[6])
    Stack[7] = r1
        Stack[8] = r2
    if Stack[7] ~= nil then
        Stack[6] = Stack[7]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 43 then -- 22 [JMP] 
 pointer = pointer + -8  
elseif pointer == 44 then -- 0 [MOVE] 
 Temp[3] = 4
Temp[7] = 1
Stack[Temp[3]] = Stack[Temp[7]] 
elseif pointer == 45 then -- 1 [LOADK] 
 Temp[8] = 5
Temp[15] = Constants
Temp[3] = 2
Stack[Temp[8]] = Temp[15][Temp[3]] 
elseif pointer == 46 then -- 1 [LOADK] 
 Temp[11] = 6
Temp[14] = Constants
Temp[7] = 15
Stack[Temp[11]] = Temp[14][Temp[7]]
	Stack[4], Stack[5] = Stack[4](Stack[5], Stack[6])
	pointer = pointer + 1 
elseif pointer == 48 then -- 5 [GETGLOBAL] 
 Temp[4] = 6
Temp[8] = 14
Temp[15] = Constants[Temp[8]]
Stack[Temp[4]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 49 then -- 0 [MOVE] 
 Temp[5] = 7
Temp[16] = 4
Stack[Temp[5]] = Stack[Temp[16]] 
elseif pointer == 50 then -- 0 [MOVE] 
 Temp[15] = 8
Temp[16] = 5
Stack[Temp[15]] = Stack[Temp[16]] 
elseif pointer == 51 then -- 28 [CALL] 
 	Stack[6](Stack[7], Stack[8]) 
elseif pointer == 52 then -- 5 [GETGLOBAL] 
 Temp[4] = 6
Temp[12] = 14
Temp[11] = Constants[Temp[12]]
Stack[Temp[4]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 53 then -- 5 [GETGLOBAL] 
 Temp[16] = 7
Temp[6] = 9
Temp[9] = Constants[Temp[6]]
Stack[Temp[16]] = vmEnv[Temp[9]] or Env[Temp[9]] 
elseif pointer == 54 then -- 1 [LOADK] 
 Temp[10] = 8
Temp[15] = Constants
Temp[16] = 10
Stack[Temp[10]] = Temp[15][Temp[16]] 
elseif pointer == 55 then -- 0 [MOVE] 
 Temp[4] = 9
Temp[11] = 1
Stack[Temp[4]] = Stack[Temp[11]] 
elseif pointer == 56 then -- 1 [LOADK] 
 Temp[12] = 10
Temp[11] = Constants
Temp[4] = 6
Stack[Temp[12]] = Temp[11][Temp[4]] 
elseif pointer == 57 then -- 1 [LOADK] 
 Temp[14] = 11
Temp[1] = Constants
Temp[12] = 5
Stack[Temp[14]] = Temp[1][Temp[12]]
	Temp[2] = {Stack[9](Stack[10], Stack[11])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[9] = nil
		top = 9
	else
		top = 9 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[9 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 59 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 7 + 1, top do
		Temp[1][i - 7] = Stack[i]
	end
	Temp[2] = {Stack[7](unpack(Temp[1], 1, top - 7))}
		Temp[3]  = #Temp[2]
	if Temp[3]  == 0 then
		Stack[7] = nil
		top = 7
	else
		top = 7 + Temp[3]  - 1
		for i = 1, Temp[3]  do
			Stack[7 + i - 1] = Temp[2][i]
		end
	end
	
	 
elseif pointer == 60 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 6 + 1, top do
		Temp[1][i - 6] = Stack[i]
	end
	Temp[2] = {Stack[6](unpack(Temp[1], 1, top - 6))}
		for i = 1, 0 do
		Stack[6 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 61 then -- 30 [RETURN] 
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