return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\025\018\058", "2513")),(decrypt("\029\057", "120")),(decrypt("\021\051", "2843")),(decrypt("\089\084\108\091\104", "2337")),(decrypt("\024\057", "2280")),(decrypt("\120\108\082\080\081\106\109\088\109\107\127\088\087\089\109\109\109", "1053")),(decrypt("\024\023\056", "2037")),(decrypt("\064\111\071\083", "2270")),(decrypt("\127\084\106\095\085\082\095\090\120\084\071\109", "2461")),(decrypt("\025\058", "1192")),(decrypt("\027\058", "2127")),(decrypt("\110\086\093\092\109", "2748")),(decrypt("\119\095\089\091\083\087\097\099\108", "990")),((decrypt("\030\023\023", "2006"))),(decrypt("\071\070\104\109\092", "434")),(decrypt("\087\072\084\095\076\088\085", "998")),(decrypt("\011\125\111\107\013\113\108\106\114\123\105", "2499")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
elseif pointer == 3 then -- 10 [NEWTABLE] 
 	Stack[0] = {} 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[16] = 1
Temp[15] = Constants
Temp[13] = 3
Stack[Temp[16]] = Temp[15][Temp[13]] 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[10] = 2
Temp[3] = Constants
Temp[9] = 1
Stack[Temp[10]] = Temp[3][Temp[9]] 
elseif pointer == 6 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\022\057", "1224")),((decrypt("\025\019\026\025", "1432"))),(decrypt("\000\104\111\100\088\095\047\105\105\093\082\105\099", "825")),(decrypt("\009\010\116\012\121\010", "2670")),(decrypt("\116\094\092", "782")),(decrypt("\105\083\078\094\068\096", "1986")),(decrypt("\008\091\096\094\088\125\096\080\110", "2884")),(decrypt("\122\109\093\082\123\109\091\084\081\107\110", "1129")),(decrypt("\087\087\090\055", "2791")),(decrypt("\107\100\080\071\108\072\103\082", "2993")),(decrypt("\066\103\108\044\102\093\082\070\089\016\045", "1923")),}

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
 Temp[12] = 5
Temp[11] = byte == pairs
Stack[Temp[12]] = Temp[4] 
elseif pointer == 10 then -- 1 [LOADK] 
 Temp[14] = 6
Temp[1] = Constants
Temp[12] = 11
Stack[Temp[14]] = Temp[1][Temp[12]] 
elseif pointer == 11 then -- 0 [MOVE] 
 Temp[13] = 7
Temp[4] = 0
Stack[Temp[13]] = Stack[Temp[4]] 
elseif pointer == 12 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 6, 7 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[6] = Temp[1]
	 
elseif pointer == 13 then -- 30 [RETURN] 
 	return Stack[5], Stack[6] 
elseif pointer == 14 then -- 23 [EQ] 
 	if Stack[3] == Constants[9] then pointer = pointer + 1 end 
elseif pointer == 15 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 16 then -- 10 [NEWTABLE] 
 	Stack[5] = {} 
elseif pointer == 17 then -- 9 [SETTABLE] 
 	Stack[5][Constants[6]] = Stack[1] 
elseif pointer == 18 then -- 9 [SETTABLE] 
 	Stack[5][Constants[10]] = Constants[1] 
elseif pointer == 19 then -- 0 [MOVE] 
 Temp[7] = 3
Temp[10] = 5
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 20 then -- 4 [GETUPVAL] 
 	Stack[5] = Upvalues[0] 
elseif pointer == 21 then -- 9 [SETTABLE] 
 	Stack[5][Stack[0]] = Stack[3] 
elseif pointer == 22 then -- 6 [GETTABLE] 
 	Stack[5] = Stack[3][Constants[10]]
	 
elseif pointer == 23 then -- 12 [ADD] 
 	Stack[5] = Stack[5] + Stack[2] 
elseif pointer == 24 then -- 9 [SETTABLE] 
 	Stack[3][Constants[10]] = Stack[5] 
elseif pointer == 25 then -- 4 [GETUPVAL] 
 	Stack[5] = Upvalues[1] 
elseif pointer == 26 then -- 12 [ADD] 
 	Stack[5] = Stack[5] + Stack[4] 
elseif pointer == 27 then -- 8 [SETUPVAL] 
 	Upvalues[1] = Stack[5] 
elseif pointer == 28 then -- 2 [LOADBOOL] 
 Temp[10] = 5
Temp[8] = ttostring ~= __metatable
Stack[Temp[10]] = Temp[2] 
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
		local encoded = {(decrypt("\118\084\083\084\089\104\092", "2468")),(decrypt("\018\062", "557")),(decrypt("\121\110\092\093", "2236")),(decrypt("\008\081\106\088\088\119\106\086\110", "222")),(decrypt("\090\081\105\091\089\085\090\074", "1629")),(decrypt("\067\064\099\025\090\067\070\106\088\065\031", "2242")),(decrypt("\104\085\069\088\074\106", "384")),(decrypt("\014\089\110\109", "1902")),(decrypt("\084\084\087\050", "1444")),(decrypt("\117\105\098\085\093\081", "1595")),(decrypt("\117\117\115\115\116\125\121", "328")),}

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
 	if Stack[2] ~= Constants[9] then pointer = pointer + 1 end 
elseif pointer == 4 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 5 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[2][Constants[5]]
	 
elseif pointer == 6 then -- 24 [LT] 
 	if Stack[3] < Stack[1] then pointer = pointer + 1 end 
elseif pointer == 7 then -- 22 [JMP] 
 pointer = pointer + 5  
elseif pointer == 8 then -- 2 [LOADBOOL] 
 Temp[9] = 3
Temp[16] = byte == pairs
Stack[Temp[9]] = Temp[11] 
elseif pointer == 9 then -- 1 [LOADK] 
 Temp[3] = 4
Temp[15] = Constants
Temp[13] = 6
Stack[Temp[3]] = Temp[15][Temp[13]] 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[14] = 5
Temp[2] = 0
Stack[Temp[14]] = Stack[Temp[2]] 
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
 	Stack[4] = Stack[2][Constants[7]]
	 
elseif pointer == 18 then -- 14 [MUL] 
 	Stack[4] = Stack[4] * Stack[1] 
elseif pointer == 19 then -- 13 [SUB] 
 	Stack[3] = Stack[3] - Stack[4] 
elseif pointer == 20 then -- 8 [SETUPVAL] 
 	Upvalues[1] = Stack[3] 
elseif pointer == 21 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[2][Constants[5]]
	 
elseif pointer == 22 then -- 23 [EQ] 
 	if Stack[3] == Constants[2] then pointer = pointer + 1 end 
elseif pointer == 23 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 24 then -- 4 [GETUPVAL] 
 	Stack[3] = Upvalues[0] 
elseif pointer == 25 then -- 9 [SETTABLE] 
 	Stack[3][Stack[0]] = Constants[9] 
elseif pointer == 26 then -- 2 [LOADBOOL] 
 Temp[10] = 3
Temp[3] = ttostring ~= __metatable
Stack[Temp[10]] = Temp[15] 
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
		local encoded = {(decrypt("\030\056", "635")),(decrypt("\109\108\088\068\111\064\106\080", "722")),(decrypt("\042\066", "1166")),(decrypt("\124\093\080\081\081\106\109", "666")),((decrypt("\030\030\025", "725"))),(decrypt("\011\083\080\092\109\080\094\019\122\069\082\107", "1557")),(decrypt("\110\082\082\068\089", "2580")),(decrypt("\087\064\082\064\090\087", "2355")),(decrypt("\108\101\070\070\111", "782")),(decrypt("\111\069\104\084\068\028\110\091\091\094\064\104\017\024", "304")),(decrypt("\071\110\069\068", "2734")),(decrypt("\124\080\090", "601")),(decrypt("\002\028", "1737")),(decrypt("\111\082\043", "2303")),(decrypt("\091\097\089\091\086", "1883")),(decrypt("\069\110\090\069\104\104", "334")),}

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
 Temp[13] = 1
Temp[5] = 15
Temp[15] = Constants[Temp[5]]
Stack[Temp[13]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 3 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 4 then -- 28 [CALL] 
 	Stack[1], Stack[2], Stack[3] = Stack[1](Stack[2]) 
elseif pointer == 5 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 6 then -- 20 [LEN] 
 	Stack[5] = #Stack[0] 
elseif pointer == 7 then -- 12 [ADD] 
 	Stack[5] = Stack[5] + Constants[1] 
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
 Temp[11] = 1
Temp[6] = 7
Temp[2] = Constants[Temp[6]]
Stack[Temp[11]] = vmEnv[Temp[2]] or Env[Temp[2]]
	Stack[1] = Stack[1][Constants[11]]
	
	pointer = pointer + 1 
elseif pointer == 13 then -- 0 [MOVE] 
 Temp[10] = 2
Temp[9] = 0
Stack[Temp[10]] = Stack[Temp[9]] 
elseif pointer == 14 then -- 28 [CALL] 
 	Stack[1](Stack[2]) 
elseif pointer == 15 then -- 5 [GETGLOBAL] 
 Temp[4] = 1
Temp[2] = 16
Temp[1] = Constants[Temp[2]]
Stack[Temp[4]] = vmEnv[Temp[1]] or Env[Temp[1]] 
elseif pointer == 16 then -- 0 [MOVE] 
 Temp[15] = 2
Temp[12] = 0
Stack[Temp[15]] = Stack[Temp[12]] 
elseif pointer == 17 then -- 28 [CALL] 
 	Stack[1], Stack[2], Stack[3] = Stack[1](Stack[2]) 
elseif pointer == 18 then -- 22 [JMP] 
 pointer = pointer + 13  
elseif pointer == 19 then -- 4 [GETUPVAL] 
 	Stack[6] = Upvalues[0] 
elseif pointer == 20 then -- 6 [GETTABLE] 
 	Stack[6] = Stack[6][Stack[5]]
	 
elseif pointer == 21 then -- 5 [GETGLOBAL] 
 Temp[3] = 7
Temp[7] = 9
Temp[13] = Constants[Temp[7]]
Stack[Temp[3]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 22 then -- 0 [MOVE] 
 Temp[9] = 8
Temp[6] = 5
Stack[Temp[9]] = Stack[Temp[6]] 
elseif pointer == 23 then -- 1 [LOADK] 
 Temp[6] = 9
Temp[12] = Constants
Temp[4] = 3
Stack[Temp[6]] = Temp[12][Temp[4]] 
elseif pointer == 24 then -- 6 [GETTABLE] 
 	Stack[10] = Stack[6][Constants[2]]
	 
elseif pointer == 25 then -- 1 [LOADK] 
 Temp[15] = 11
Temp[2] = Constants
Temp[16] = 13
Stack[Temp[15]] = Temp[2][Temp[16]] 
elseif pointer == 26 then -- 6 [GETTABLE] 
 	Stack[12] = Stack[6][Constants[8]]
	 
elseif pointer == 27 then -- 6 [GETTABLE] 
 	Stack[13] = Stack[6][Constants[2]]
	 
elseif pointer == 28 then -- 14 [MUL] 
 	Stack[12] = Stack[12] * Stack[13] 
elseif pointer == 29 then -- 1 [LOADK] 
 Temp[16] = 13
Temp[12] = Constants
Temp[11] = 14
Stack[Temp[16]] = Temp[12][Temp[11]] 
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
 Temp[2] = 1
Temp[9] = 9
Temp[16] = Constants[Temp[9]]
Stack[Temp[2]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 35 then -- 1 [LOADK] 
 Temp[6] = 2
Temp[7] = Constants
Temp[10] = 10
Stack[Temp[6]] = Temp[7][Temp[10]] 
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
 Temp[14] = 6
Temp[16] = 15
Temp[4] = Constants[Temp[16]]
Stack[Temp[14]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 17 then -- 0 [MOVE] 
 Temp[4] = 7
Temp[5] = 3
Stack[Temp[4]] = Stack[Temp[5]] 
elseif pointer == 18 then -- 1 [LOADK] 
 Temp[15] = 8
Temp[5] = Constants
Temp[4] = 8
Stack[Temp[15]] = Temp[5][Temp[4]] 
elseif pointer == 19 then -- 1 [LOADK] 
 Temp[10] = 9
Temp[5] = Constants
Temp[16] = 5
Stack[Temp[10]] = Temp[5][Temp[16]] 
elseif pointer == 20 then -- 1 [LOADK] 
 Temp[6] = 10
Temp[3] = Constants
Temp[5] = 11
Stack[Temp[6]] = Temp[3][Temp[5]]
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
 Temp[6] = 6
Temp[16] = 15
Temp[10] = Constants[Temp[16]]
Stack[Temp[6]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 24 then -- 0 [MOVE] 
 Temp[4] = 7
Temp[13] = 3
Stack[Temp[4]] = Stack[Temp[13]] 
elseif pointer == 25 then -- 1 [LOADK] 
 Temp[2] = 8
Temp[15] = Constants
Temp[6] = 16
Stack[Temp[2]] = Temp[15][Temp[6]] 
elseif pointer == 26 then -- 1 [LOADK] 
 Temp[6] = 9
Temp[14] = Constants
Temp[5] = 2
Stack[Temp[6]] = Temp[14][Temp[5]] 
elseif pointer == 27 then -- 1 [LOADK] 
 Temp[3] = 10
Temp[7] = Constants
Temp[11] = 10
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
 Temp[5] = 6
Temp[7] = 15
Temp[15] = Constants[Temp[7]]
Stack[Temp[5]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 31 then -- 0 [MOVE] 
 Temp[9] = 7
Temp[12] = 3
Stack[Temp[9]] = Stack[Temp[12]] 
elseif pointer == 32 then -- 1 [LOADK] 
 Temp[14] = 8
Temp[15] = Constants
Temp[7] = 12
Stack[Temp[14]] = Temp[15][Temp[7]] 
elseif pointer == 33 then -- 1 [LOADK] 
 Temp[7] = 9
Temp[4] = Constants
Temp[11] = 7
Stack[Temp[7]] = Temp[4][Temp[11]] 
elseif pointer == 34 then -- 1 [LOADK] 
 Temp[7] = 10
Temp[10] = Constants
Temp[14] = 11
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
 Temp[12] = 6
Temp[15] = 15
Temp[13] = Constants[Temp[15]]
Stack[Temp[12]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 38 then -- 0 [MOVE] 
 Temp[6] = 7
Temp[2] = 4
Stack[Temp[6]] = Stack[Temp[2]] 
elseif pointer == 39 then -- 1 [LOADK] 
 Temp[9] = 8
Temp[7] = Constants
Temp[16] = 8
Stack[Temp[9]] = Temp[7][Temp[16]] 
elseif pointer == 40 then -- 1 [LOADK] 
 Temp[15] = 9
Temp[13] = Constants
Temp[3] = 10
Stack[Temp[15]] = Temp[13][Temp[3]]
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
 Temp[16] = 6
Temp[4] = 15
Temp[10] = Constants[Temp[4]]
Stack[Temp[16]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 44 then -- 0 [MOVE] 
 Temp[10] = 7
Temp[8] = 4
Stack[Temp[10]] = Stack[Temp[8]] 
elseif pointer == 45 then -- 1 [LOADK] 
 Temp[1] = 8
Temp[8] = Constants
Temp[12] = 4
Stack[Temp[1]] = Temp[8][Temp[12]] 
elseif pointer == 46 then -- 1 [LOADK] 
 Temp[5] = 9
Temp[14] = Constants
Temp[11] = 10
Stack[Temp[5]] = Temp[14][Temp[11]]
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
 Temp[12] = 6
Temp[5] = 5
Stack[Temp[12]] = Stack[Temp[5]] 
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