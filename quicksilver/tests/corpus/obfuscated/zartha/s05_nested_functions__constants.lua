return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\030\062", "2513")),(decrypt("\025\057", "120")),(decrypt("\026\031\063", "2843")),(decrypt("\016", "2337")),(decrypt("\025\021\051", "2280")),(decrypt("\120\108\082\080\081\106\109\088\109\107\127\088\087\089\109\109\109", "1053")),(decrypt("\025\059", "2037")),(decrypt("\024\021\060", "2270")),(decrypt("\127\084\106\095\085\082\095\090\120\084\071\109", "2461")),(decrypt("\024\058", "1192")),(decrypt("\071\083\109\106\084", "2127")),(decrypt("\024\060", "2748")),(decrypt("\119\095\089\091\083\087\097\099\108", "990")),((decrypt("\030\023\023", "2006"))),(decrypt("\071\070\104\109\092", "434")),(decrypt("\086\082\084\086\072\094", "998")),(decrypt("\011\125\111\107\013\113\108\106\114\123\105", "2499")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
 Temp[6] = 0
Temp[15] = ttostring ~= __metatable
Stack[Temp[6]] = Temp[13] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[9] = vmEnv
Temp[11] = 17
Temp[10] = Constants[Temp[11]]
Temp[5] = 0
Temp[9][Temp[10]] = Temp[10] 
elseif pointer == 3 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\117\010\030", "1127")),(decrypt("\127\110\092\099\082\092\102", "829")),(decrypt("\084\083\083\104", "1564")),((decrypt("\029", "167"))),(decrypt("\123\092\106\095\090\107\091\008\093\087", "1726")),(decrypt("\008\094\086\084\081\100\089\111", "2823")),}

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
		if pointer == 1 then -- 0 [MOVE] 
 Temp[3] = 2
Temp[11] = 0
Stack[Temp[3]] = Stack[Temp[11]] 
elseif pointer == 2 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[11] then
		C1 = {}
		local encoded = {(decrypt("\125\094\111\080\082\111\108", "753")),(decrypt("\012\088\086\099\012\088\090\082\090\002\108\088\082\099", "1838")),}

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
	
	Stack[3] = function(...) -- PROTOTYPE 11
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 2}, [1] = {0, 1}}
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
 	Stack[0] = Upvalues[0] 
elseif pointer == 2 then -- 4 [GETUPVAL] 
 	Stack[1] = Upvalues[1] 
elseif pointer == 3 then -- 12 [ADD] 
 	Stack[0] = Stack[0] + Stack[1] 
elseif pointer == 4 then -- 8 [SETUPVAL] 
 	Upvalues[0] = Stack[0] 
elseif pointer == 5 then -- 4 [GETUPVAL] 
 	Stack[0] = Upvalues[0] 
elseif pointer == 6 then -- 30 [RETURN] 
 	return Stack[0] 
elseif pointer == 7 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 5 then -- 30 [RETURN] 
 	return Stack[3] 
elseif pointer == 6 then -- 30 [RETURN] 
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
		local encoded = {(decrypt("\087\105\071\099", "557")),(decrypt("\008\084\085\085\105\084\093\083", "2236")),}

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
		if pointer == 1 then -- 10 [NEWTABLE] 
 	Stack[1] = {} 
elseif pointer == 2 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[12] then
		C1 = {}
		local encoded = {(decrypt("\082\086\086\049", "765")),((decrypt("\028\025\027\031\029", "1575"))),(decrypt("\109\092\083\083\088\006\030\018\105\087\082\110\084\094\099\017\104\081\092\018\106\080\088\018\092\107\097\107\084\081\090\094\020\031\017\028\030\025\022\031\024\026\018\018\085\007\002\105\010\007\098\107\106\112\016\124\031\081\099\095\002\083\116\013\087\085\005\019\024\089\120\093\028\121\104\081\124\095\082\080\090\090\083\093\107\084\023", "2784")),(decrypt("\113\085\085\093\081\104\086\086\064\108\110", "1056")),}

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
	
	Stack[2] = function(...) -- PROTOTYPE 12
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 1}, [1] = {0, 0}}
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
 	Stack[1] = Stack[1][Stack[0]]
	 
elseif pointer == 3 then -- 23 [EQ] 
 	if Stack[1] == Constants[1] then pointer = pointer + 1 end 
elseif pointer == 4 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 5 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[1] 
elseif pointer == 6 then -- 0 [MOVE] 
 Temp[10] = 3
Temp[8] = 0
Stack[Temp[10]] = Stack[Temp[8]] 
elseif pointer == 7 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3]) 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[13] = 1
Temp[4] = 2
Stack[Temp[13]] = Stack[Temp[4]] 
elseif pointer == 9 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 10 then -- 9 [SETTABLE] 
 	Stack[2][Stack[0]] = Stack[1] 
elseif pointer == 11 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 12 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 5 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 6 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 5 then -- 3 [LOADNIL] 
 	Stack[2], Stack[3], Stack[4] = nil 
elseif pointer == 6 then -- 0 [MOVE] 
 Temp[16] = 3
Temp[15] = 1
Stack[Temp[16]] = Stack[Temp[15]] 
elseif pointer == 7 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {((decrypt("\030\030\020\025\031", "328"))),(decrypt("\009\089\094\105\107\090\104\106", "2941")),(decrypt("\012\082\085\081\087\109\093\104", "641")),((decrypt("\024", "2384"))),(decrypt("\026\061", "367")),((decrypt("\018\028\028", "590"))),(decrypt("\025\060", "1755")),(decrypt("\120\013\015\016", "2278")),}

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
	
	Stack[4] = function(...) -- PROTOTYPE 3
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 2}}
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
 pointer = pointer + 1  
elseif pointer == 3 then -- 30 [RETURN] 
 	return Stack[0] 
elseif pointer == 4 then -- 4 [GETUPVAL] 
 	Stack[1] = Upvalues[0] 
elseif pointer == 5 then -- 13 [SUB] 
 	Stack[2] = Stack[0] - Constants[7] 
elseif pointer == 6 then -- 28 [CALL] 
 	Stack[1] = Stack[1](Stack[2]) 
elseif pointer == 7 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 8 then -- 13 [SUB] 
 	Stack[3] = Stack[0] - Constants[5] 
elseif pointer == 9 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3]) 
elseif pointer == 10 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Stack[2] 
elseif pointer == 11 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 12 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 9 then -- 28 [CALL] 
 	Stack[3] = Stack[3](Stack[4]) 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[13] = 2
Temp[10] = 3
Stack[Temp[13]] = Stack[Temp[10]] 
elseif pointer == 11 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\010\109\111\091\111\038\082\081\106\109\033\107\084\105\111\084\109\106", "1167")),(decrypt("\124", "2343")),(decrypt("\121\080\106\104\110\046\110\087\106\096\081\110\105", "2922")),}

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
 	Stack[1] = {} 
elseif pointer == 2 then -- 37 [VARARG] 
 	top = 2 + #Varargs - 1
	for i = 1, #Varargs do
		Stack[2 + i - 1] = Varargs[i]
	end
	 
elseif pointer == 3 then -- 34 [SETLIST] 
 	local _limit = top - 1
	for i = 1, _limit do
		Stack[1][(1 - 1) * 50 + i] = Stack[1 + i]
	end
	 
elseif pointer == 4 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[13] then
		C1 = {}
		local encoded = {((decrypt("\022\020\031\027", "1117"))),(decrypt("\118\106\099\081\094\082", "2681")),(decrypt("\122\111\080\104\109\092", "1796")),(decrypt("\025\062", "1545")),(decrypt("\021\024\051", "1084")),(decrypt("\010\080\089\104\087\085\086\110\107\091", "1032")),(decrypt("\009\106\106\091\070\087\089\106\107", "260")),}

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
	
	Stack[2] = function(...) -- PROTOTYPE 13
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
 	Stack[1] = Upvalues[0] 
elseif pointer == 2 then -- 20 [LEN] 
 	Stack[1] = #Stack[1] 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[11] = 2
Temp[15] = Constants
Temp[9] = 4
Stack[Temp[11]] = Temp[15][Temp[9]] 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[7] = 3
Temp[2] = Constants
Temp[4] = 5
Stack[Temp[7]] = Temp[2][Temp[4]] 
elseif pointer == 5 then -- 32 [FORPREP] 
     Stack[1] = Stack[1] - Stack[3]
    pointer = pointer + 5
     
elseif pointer == 6 then -- 4 [GETUPVAL] 
 	Stack[5] = Upvalues[0] 
elseif pointer == 7 then -- 6 [GETTABLE] 
 	Stack[5] = Stack[5][Stack[4]]
	 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[10] = 6
Temp[3] = 0
Stack[Temp[10]] = Stack[Temp[3]] 
elseif pointer == 9 then -- 28 [CALL] 
 	Stack[5] = Stack[5](Stack[6]) 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[10] = 0
Temp[14] = 5
Stack[Temp[10]] = Stack[Temp[14]] 
elseif pointer == 11 then -- 31 [FORLOOP] 
     Stack[1] = Stack[1] + Stack[3]
    if (Stack[3] > 0 and Stack[1] <= Stack[2]) or (Stack[3] <= 0 and Stack[1] >= Stack[2]) then
        pointer = pointer + -6
        Stack[4] = Stack[1]
    end
     
elseif pointer == 12 then -- 30 [RETURN] 
 	return Stack[0] 
elseif pointer == 13 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 6 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 7 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 12 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {(decrypt("\013\084\087\092\110\087\092\022\121\071\085\110", "722")),(decrypt("\122\095\106\106\084\118\080\092\081\090\086\080\084", "1166")),(decrypt("\087\092\111\087\094\081", "666")),(decrypt("\008\094\081\111\087\083\087\105", "725")),}

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
		if pointer == 1 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 2 then -- 5 [GETGLOBAL] 
 Temp[2] = 3
Temp[9] = 3
Temp[14] = Constants[Temp[9]]
Stack[Temp[2]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 3 then -- 0 [MOVE] 
 Temp[13] = 4
Temp[11] = 0
Stack[Temp[13]] = Stack[Temp[11]] 
elseif pointer == 4 then -- 28 [CALL] 
 	Stack[3], Stack[4], Stack[5] = Stack[3](Stack[4]) 
elseif pointer == 5 then -- 22 [JMP] 
 pointer = pointer + 5  
elseif pointer == 6 then -- 0 [MOVE] 
 Temp[4] = 8
Temp[9] = 1
Stack[Temp[4]] = Stack[Temp[9]] 
elseif pointer == 7 then -- 0 [MOVE] 
 Temp[2] = 9
Temp[7] = 7
Stack[Temp[2]] = Stack[Temp[7]] 
elseif pointer == 8 then -- 0 [MOVE] 
 Temp[15] = 10
Temp[10] = 6
Stack[Temp[15]] = Stack[Temp[10]] 
elseif pointer == 9 then -- 28 [CALL] 
 	Stack[8] = Stack[8](Stack[9], Stack[10]) 
elseif pointer == 10 then -- 9 [SETTABLE] 
 	Stack[2][Stack[6]] = Stack[8] 
elseif pointer == 11 then -- 33 [TFORLOOP] 
     local r1, r2 = Stack[3](Stack[4], Stack[5])
    Stack[6] = r1
        Stack[7] = r2
    if Stack[6] ~= nil then
        Stack[5] = Stack[6]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 12 then -- 22 [JMP] 
 pointer = pointer + -7  
elseif pointer == 13 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 14 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 13 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[6] then
		C1 = {}
		local encoded = {(decrypt("\026\063", "2419")),(decrypt("\025", "956")),(decrypt("\113\092\096\107\090\089\085\109", "1981")),(decrypt("\020\051", "383")),(decrypt("\105\089\068\088\089\106", "1716")),(decrypt("\112\083\093\111", "339")),}

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
	
	Stack[5] = function(...) -- PROTOTYPE 6
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
Temp[15] = 4
Stack[Temp[2]] = Temp[1][Temp[15]] 
elseif pointer == 2 then -- 1 [LOADK] 
 Temp[15] = 2
Temp[12] = Constants
Temp[3] = 1
Stack[Temp[15]] = Temp[12][Temp[3]] 
elseif pointer == 3 then -- 5 [GETGLOBAL] 
 Temp[7] = 3
Temp[13] = 5
Temp[9] = Constants[Temp[13]]
Stack[Temp[7]] = vmEnv[Temp[9]] or Env[Temp[9]] 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[6] = 4
Temp[12] = Constants
Temp[4] = 2
Stack[Temp[6]] = Temp[12][Temp[4]] 
elseif pointer == 5 then -- 37 [VARARG] 
 	top = 5 + #Varargs - 1
	for i = 1, #Varargs do
		Stack[5 + i - 1] = Varargs[i]
	end
	 
elseif pointer == 6 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 3 + 1, top do
		Temp[1][i - 3] = Stack[i]
	end
	Temp[2] = {Stack[3](unpack(Temp[1], 1, top - 3))}
		for i = 1, 1 do
		Stack[3 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 7 then -- 1 [LOADK] 
 Temp[15] = 4
Temp[2] = Constants
Temp[16] = 1
Stack[Temp[15]] = Temp[2][Temp[16]] 
elseif pointer == 8 then -- 32 [FORPREP] 
     Stack[2] = Stack[2] - Stack[4]
    pointer = pointer + 5
     
elseif pointer == 9 then -- 5 [GETGLOBAL] 
 Temp[16] = 6
Temp[12] = 5
Temp[11] = Constants[Temp[12]]
Stack[Temp[16]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[2] = 7
Temp[9] = 5
Stack[Temp[2]] = Stack[Temp[9]] 
elseif pointer == 11 then -- 37 [VARARG] 
 	top = 8 + #Varargs - 1
	for i = 1, #Varargs do
		Stack[8 + i - 1] = Varargs[i]
	end
	 
elseif pointer == 12 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 6 + 1, top do
		Temp[1][i - 6] = Stack[i]
	end
	Temp[2] = {Stack[6](unpack(Temp[1], 1, top - 6))}
		for i = 1, 1 do
		Stack[6 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 13 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Stack[6] 
elseif pointer == 14 then -- 31 [FORLOOP] 
     Stack[2] = Stack[2] + Stack[4]
    if (Stack[4] > 0 and Stack[2] <= Stack[3]) or (Stack[4] <= 0 and Stack[2] >= Stack[3]) then
        pointer = pointer + -6
        Stack[5] = Stack[2]
    end
     
elseif pointer == 15 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 16 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 14 then -- 0 [MOVE] 
 Temp[3] = 6
Temp[9] = 0
Stack[Temp[3]] = Stack[Temp[9]] 
elseif pointer == 15 then -- 1 [LOADK] 
 Temp[14] = 7
Temp[16] = Constants
Temp[4] = 3
Stack[Temp[14]] = Temp[16][Temp[4]] 
elseif pointer == 16 then -- 1 [LOADK] 
 Temp[4] = 8
Temp[5] = Constants
Temp[15] = 1
Stack[Temp[4]] = Temp[5][Temp[15]]
	Stack[6] = Stack[6](Stack[7], Stack[8])
	pointer = pointer + 1 
elseif pointer == 18 then -- 5 [GETGLOBAL] 
 Temp[5] = 7
Temp[4] = 15
Temp[10] = Constants[Temp[4]]
Stack[Temp[5]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 19 then -- 0 [MOVE] 
 Temp[10] = 8
Temp[5] = 6
Stack[Temp[10]] = Stack[Temp[5]] 
elseif pointer == 20 then -- 28 [CALL] 
 	Stack[8] = Stack[8]() 
elseif pointer == 21 then -- 0 [MOVE] 
 Temp[5] = 9
Temp[16] = 6
Stack[Temp[5]] = Stack[Temp[16]] 
elseif pointer == 22 then -- 28 [CALL] 
 	Stack[9] = Stack[9]() 
elseif pointer == 23 then -- 0 [MOVE] 
 Temp[6] = 10
Temp[3] = 6
Stack[Temp[6]] = Stack[Temp[3]] 
elseif pointer == 24 then -- 28 [CALL] 
 	Temp[2] = {Stack[10]()}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[10] = nil
		top = 10
	else
		top = 10 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[10 + i - 1] = Temp[2][i]
		end
	end
	 
elseif pointer == 25 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 7 + 1, top do
		Temp[1][i - 7] = Stack[i]
	end
	Temp[2] = {Stack[7](unpack(Temp[1], 1, top - 7))}
		for i = 1, 0 do
		Stack[7 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 26 then -- 5 [GETGLOBAL] 
 Temp[5] = 7
Temp[6] = 15
Temp[16] = Constants[Temp[6]]
Stack[Temp[5]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 27 then -- 0 [MOVE] 
 Temp[10] = 8
Temp[4] = 2
Stack[Temp[10]] = Stack[Temp[4]] 
elseif pointer == 28 then -- 1 [LOADK] 
 Temp[13] = 9
Temp[2] = Constants
Temp[15] = 8
Stack[Temp[13]] = Temp[2][Temp[15]]
	Stack[8] = Stack[8](Stack[9])
	pointer = pointer + 1 
elseif pointer == 30 then -- 0 [MOVE] 
 Temp[6] = 9
Temp[14] = 2
Stack[Temp[6]] = Stack[Temp[14]] 
elseif pointer == 31 then -- 1 [LOADK] 
 Temp[5] = 10
Temp[3] = Constants
Temp[7] = 5
Stack[Temp[5]] = Temp[3][Temp[7]]
	Temp[2] = {Stack[9](Stack[10])}
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
elseif pointer == 33 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 7 + 1, top do
		Temp[1][i - 7] = Stack[i]
	end
	Temp[2] = {Stack[7](unpack(Temp[1], 1, top - 7))}
		for i = 1, 0 do
		Stack[7 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 34 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[7] then
		C1 = {}
		local encoded = {(decrypt("\011\106\081\087\106\124\109\080\087\088\109\111", "1514")),(decrypt("\120\089\103\108\090", "1993")),(decrypt("\008\108\093\008\084\087\091\082\105\104", "2482")),(decrypt("\091\101\088\092\081\095\087\096", "1926")),(decrypt("\030\051", "682")),(decrypt("\118\090\106\071\109\080\123\107\085\095\095\087\084\103", "1927")),(decrypt("\010\110\071\083", "1679")),}

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
	
	Stack[7] = function(...) -- PROTOTYPE 7
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
		if pointer == 1 then -- 12 [ADD] 
 	Stack[1] = Stack[0] + Constants[5] 
elseif pointer == 2 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 3 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 35 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[8] then
		C1 = {}
		local encoded = {(decrypt("\027\059", "2047")),((decrypt("\024\030\019", "1943"))),(decrypt("\012\111\083\084\081\082\110", "1707")),(decrypt("\121\086\094\085\088\000\101\109\097\092", "939")),}

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
	
	Stack[8] = function(...) -- PROTOTYPE 8
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
		if pointer == 1 then -- 14 [MUL] 
 	Stack[1] = Stack[0] * Constants[1] 
elseif pointer == 2 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 3 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 36 then -- 5 [GETGLOBAL] 
 Temp[7] = 9
Temp[11] = 15
Temp[5] = Constants[Temp[11]]
Stack[Temp[7]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 37 then -- 0 [MOVE] 
 Temp[7] = 10
Temp[15] = 3
Stack[Temp[7]] = Stack[Temp[15]] 
elseif pointer == 38 then -- 0 [MOVE] 
 Temp[9] = 11
Temp[12] = 7
Stack[Temp[9]] = Stack[Temp[12]] 
elseif pointer == 39 then -- 0 [MOVE] 
 Temp[14] = 12
Temp[15] = 8
Stack[Temp[14]] = Stack[Temp[15]] 
elseif pointer == 40 then -- 28 [CALL] 
 	Stack[10] = Stack[10](Stack[11], Stack[12]) 
elseif pointer == 41 then -- 1 [LOADK] 
 Temp[7] = 11
Temp[4] = Constants
Temp[11] = 1
Stack[Temp[7]] = Temp[4][Temp[11]]
	Stack[10] = Stack[10](Stack[11])
	pointer = pointer + 1 
elseif pointer == 43 then -- 0 [MOVE] 
 Temp[7] = 11
Temp[10] = 3
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 44 then -- 0 [MOVE] 
 Temp[14] = 12
Temp[12] = 8
Stack[Temp[14]] = Stack[Temp[12]] 
elseif pointer == 45 then -- 0 [MOVE] 
 Temp[15] = 13
Temp[13] = 7
Stack[Temp[15]] = Stack[Temp[13]] 
elseif pointer == 46 then -- 28 [CALL] 
 	Stack[11] = Stack[11](Stack[12], Stack[13]) 
elseif pointer == 47 then -- 1 [LOADK] 
 Temp[6] = 12
Temp[2] = Constants
Temp[9] = 1
Stack[Temp[6]] = Temp[2][Temp[9]]
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
	
	pointer = pointer + 1 
elseif pointer == 49 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 9 + 1, top do
		Temp[1][i - 9] = Stack[i]
	end
	Temp[2] = {Stack[9](unpack(Temp[1], 1, top - 9))}
		for i = 1, 0 do
		Stack[9 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 50 then -- 5 [GETGLOBAL] 
 Temp[7] = 9
Temp[16] = 15
Temp[15] = Constants[Temp[16]]
Stack[Temp[7]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 51 then -- 5 [GETGLOBAL] 
 Temp[13] = 10
Temp[16] = 11
Temp[3] = Constants[Temp[16]]
Stack[Temp[13]] = vmEnv[Temp[3]] or Env[Temp[3]]
	Stack[10] = Stack[10][Constants[16]]
	
	pointer = pointer + 1 
elseif pointer == 53 then -- 0 [MOVE] 
 Temp[4] = 11
Temp[10] = 4
Stack[Temp[4]] = Stack[Temp[10]] 
elseif pointer == 54 then -- 10 [NEWTABLE] 
 	Stack[12] = {} 
elseif pointer == 55 then -- 1 [LOADK] 
 Temp[10] = 13
Temp[8] = Constants
Temp[1] = 2
Stack[Temp[10]] = Temp[8][Temp[1]] 
elseif pointer == 56 then -- 1 [LOADK] 
 Temp[8] = 14
Temp[1] = Constants
Temp[12] = 10
Stack[Temp[8]] = Temp[1][Temp[12]] 
elseif pointer == 57 then -- 1 [LOADK] 
 Temp[5] = 15
Temp[14] = Constants
Temp[11] = 12
Stack[Temp[5]] = Temp[14][Temp[11]] 
elseif pointer == 58 then -- 1 [LOADK] 
 Temp[12] = 16
Temp[5] = Constants
Temp[14] = 7
Stack[Temp[12]] = Temp[5][Temp[14]] 
elseif pointer == 59 then -- 34 [SETLIST] 
 	for i = 1, 4 do
		Stack[12][(1 - 1) * 50 + i] = Stack[12 + i]
	end
	 
elseif pointer == 60 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[9] then
		C1 = {}
		local encoded = {(decrypt("\009\089\093\110\080\095\086\110\112\080\083\082\113\109\080\093", "659")),(decrypt("\114\084\085\105\081\081\099\038\106\088\102\093\086\109\093\090", "2181")),(decrypt("\127\105\080\087\081\084\109", "1135")),}

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
	
	Stack[13] = function(...) -- PROTOTYPE 9
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
		if pointer == 1 then -- 14 [MUL] 
 	Stack[2] = Stack[0] * Stack[1] 
elseif pointer == 2 then -- 30 [RETURN] 
 	return Stack[2] 
elseif pointer == 3 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 61 then -- 28 [CALL] 
 	Stack[11] = Stack[11](Stack[12], Stack[13]) 
elseif pointer == 62 then -- 1 [LOADK] 
 Temp[7] = 12
Temp[11] = Constants
Temp[4] = 4
Stack[Temp[7]] = Temp[11][Temp[4]]
	Temp[2] = {Stack[10](Stack[11], Stack[12])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[10] = nil
		top = 10
	else
		top = 10 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[10 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 64 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 9 + 1, top do
		Temp[1][i - 9] = Stack[i]
	end
	Temp[2] = {Stack[9](unpack(Temp[1], 1, top - 9))}
		for i = 1, 0 do
		Stack[9 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 65 then -- 5 [GETGLOBAL] 
 Temp[6] = 9
Temp[5] = 15
Temp[1] = Constants[Temp[5]]
Stack[Temp[6]] = vmEnv[Temp[1]] or Env[Temp[1]] 
elseif pointer == 66 then -- 0 [MOVE] 
 Temp[12] = 10
Temp[7] = 5
Stack[Temp[12]] = Stack[Temp[7]] 
elseif pointer == 67 then -- 1 [LOADK] 
 Temp[10] = 11
Temp[3] = Constants
Temp[7] = 2
Stack[Temp[10]] = Temp[3][Temp[7]] 
elseif pointer == 68 then -- 1 [LOADK] 
 Temp[8] = 12
Temp[15] = Constants
Temp[3] = 10
Stack[Temp[8]] = Temp[15][Temp[3]] 
elseif pointer == 69 then -- 1 [LOADK] 
 Temp[11] = 13
Temp[14] = Constants
Temp[7] = 12
Stack[Temp[11]] = Temp[14][Temp[7]] 
elseif pointer == 70 then -- 1 [LOADK] 
 Temp[4] = 14
Temp[8] = Constants
Temp[15] = 7
Stack[Temp[4]] = Temp[8][Temp[15]] 
elseif pointer == 71 then -- 1 [LOADK] 
 Temp[5] = 15
Temp[16] = Constants
Temp[15] = 1
Stack[Temp[5]] = Temp[16][Temp[15]]
	Stack[10] = Stack[10](Stack[11], Stack[12], Stack[13], Stack[14], Stack[15])
	pointer = pointer + 1 
elseif pointer == 73 then -- 0 [MOVE] 
 Temp[16] = 11
Temp[4] = 5
Stack[Temp[16]] = Stack[Temp[4]] 
elseif pointer == 74 then -- 28 [CALL] 
 	Temp[2] = {Stack[11]()}
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
	 
elseif pointer == 75 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 9 + 1, top do
		Temp[1][i - 9] = Stack[i]
	end
	Temp[2] = {Stack[9](unpack(Temp[1], 1, top - 9))}
		for i = 1, 0 do
		Stack[9 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 76 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[10] then
		C1 = {}
		local encoded = {(decrypt("\127\111\084\082\081\082\105", "1770")),(decrypt("\123\082\104\081\105\089\090\093\109\037\086\081\092\106\085\084\106", "1264")),(decrypt("\118\104\105\109\087\091\111", "2071")),}

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
	
	Stack[9] = function(...) -- PROTOTYPE 10
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
		if pointer == 1 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[14] then
		C1 = {}
		local encoded = {(decrypt("\008\111\106\091\104\104\089\108\091\010\107\105\110\107", "202")),(decrypt("\015\086\109\111", "461")),(decrypt("\113\085\086", "2385")),(decrypt("\014\005\013\014", "1955")),(decrypt("\112\100\110\088", "383")),(decrypt("\116\087\089\033\108\087\094\083\106", "1126")),}

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
		ProtosConstants[14] = C1
	else
		C1 = ProtosConstants[14]
	end
	
	Stack[1] = function(...) -- PROTOTYPE 14
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
		if pointer == 1 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[15] then
		C1 = {}
		local encoded = {(decrypt("\120\107\107\080", "1739")),(decrypt("\025\021\019\058", "1241")),(decrypt("\119\083\107\092\105\095\087\083\084\035\106\109\081\087\107\110", "1475")),(decrypt("\013\110\099\104\106\029\013\080\092\092\095\095\084", "769")),(decrypt("\125\086\084\111\087\104\104", "1345")),(decrypt("\025\017\061", "1660")),}

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
		ProtosConstants[15] = C1
	else
		C1 = ProtosConstants[15]
	end
	
	Stack[1] = function(...) -- PROTOTYPE 15
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {1, 0}, [1] = {0, 0}}
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
elseif pointer == 2 then -- 14 [MUL] 
 	Stack[1] = Stack[1] * Constants[2] 
elseif pointer == 3 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[1] 
elseif pointer == 4 then -- 14 [MUL] 
 	Stack[2] = Stack[2] * Constants[6] 
elseif pointer == 5 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Stack[2] 
elseif pointer == 6 then -- 12 [ADD] 
 	Stack[1] = Stack[1] + Stack[0] 
elseif pointer == 7 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 8 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 4 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 5 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 3 then -- 30 [RETURN] 
 	return Stack[1] 
elseif pointer == 4 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 77 then -- 5 [GETGLOBAL] 
 Temp[12] = 10
Temp[11] = 15
Temp[16] = Constants[Temp[11]]
Stack[Temp[12]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 78 then -- 0 [MOVE] 
 Temp[16] = 11
Temp[9] = 9
Stack[Temp[16]] = Stack[Temp[9]] 
elseif pointer == 79 then -- 1 [LOADK] 
 Temp[6] = 12
Temp[10] = Constants
Temp[15] = 2
Stack[Temp[6]] = Temp[10][Temp[15]]
	Stack[11] = Stack[11](Stack[12])
	pointer = pointer + 1 
elseif pointer == 81 then -- 1 [LOADK] 
 Temp[10] = 12
Temp[16] = Constants
Temp[4] = 10
Stack[Temp[10]] = Temp[16][Temp[4]]
	Stack[11] = Stack[11](Stack[12])
	pointer = pointer + 1 
elseif pointer == 83 then -- 1 [LOADK] 
 Temp[11] = 12
Temp[12] = Constants
Temp[4] = 12
Stack[Temp[11]] = Temp[12][Temp[4]]
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
	
	pointer = pointer + 1 
elseif pointer == 85 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 10 + 1, top do
		Temp[1][i - 10] = Stack[i]
	end
	Temp[2] = {Stack[10](unpack(Temp[1], 1, top - 10))}
		for i = 1, 0 do
		Stack[10 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 86 then -- 30 [RETURN] 
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