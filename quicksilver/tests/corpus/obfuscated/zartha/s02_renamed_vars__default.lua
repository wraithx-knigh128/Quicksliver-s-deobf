return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\016\060", "777")),(decrypt("\081\096\084\089\110\081\084", "2812")),(decrypt("\024\018\058", "2513")),(decrypt("\027\051", "2816")),(decrypt("\026\021\059", "120")),(decrypt("\008\094\090\101\117\096\105\091\106\102\111\083", "2839")),(decrypt("\106\093\089\083\081", "2843")),(decrypt("\096\117\015\011\127\124\012\011\125\010\008", "636")),(decrypt("\124\085\090\085\088\084\107\109\110", "2337")),(decrypt("\024\063", "2464")),(decrypt("\091\084\095\108", "2280")),((decrypt("\021\023\023", "900"))),(decrypt("\091\094\083\090\106", "1053")),(decrypt("\025\062", "1598")),(decrypt("\085\089\083\082\089", "2037")),(decrypt("\020\062", "859")),(decrypt("\123\110\080\083\082\104\111\091\110\105\125\091\084\091\111\110\110", "2270")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
Temp[14] = ttostring ~= __metatable
Stack[Temp[5]] = Temp[12] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[7] = vmEnv
Temp[5] = 8
Temp[12] = Constants[Temp[5]]
Temp[2] = 0
Temp[7][Temp[12]] = Temp[12] 
elseif pointer == 3 then -- 10 [NEWTABLE] 
 	Stack[0] = {} 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[15] = 1
Temp[11] = Constants
Temp[5] = 1
Stack[Temp[15]] = Temp[11][Temp[5]] 
elseif pointer == 5 then -- 1 [LOADK] 
 Temp[1] = 2
Temp[11] = Constants
Temp[6] = 5
Stack[Temp[1]] = Temp[11][Temp[6]] 
elseif pointer == 6 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\087\081\091\051", "2185")),(decrypt("\005\091\081\093\089", "827")),(decrypt("\021\062", "2584")),(decrypt("\090\084\080\038\110\110\110\092\065\003\033", "1261")),(decrypt("\090\092\106\082\089\080\089\071", "2027")),(decrypt("\095\111\082\111\110\088", "1321")),(decrypt("\121\111\083\092\010\085\094\013\108\087\084\104", "773")),(decrypt("\011\082\088\086\104\081\093\108", "1182")),(decrypt("\119\097\081\091\089\087\103", "992")),(decrypt("\012\091\108\110\087", "220")),((decrypt("\024\024", "2113"))),}

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
 Temp[7] = 5
Temp[10] = byte == pairs
Stack[Temp[7]] = Temp[3] 
elseif pointer == 10 then -- 1 [LOADK] 
 Temp[7] = 6
Temp[8] = Constants
Temp[15] = 4
Stack[Temp[7]] = Temp[8][Temp[15]] 
elseif pointer == 11 then -- 0 [MOVE] 
 Temp[3] = 7
Temp[11] = 0
Stack[Temp[3]] = Stack[Temp[11]] 
elseif pointer == 12 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 6, 7 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[6] = Temp[1]
	 
elseif pointer == 13 then -- 30 [RETURN] 
 	return Stack[5], Stack[6] 
elseif pointer == 14 then -- 23 [EQ] 
 	if Stack[3] == Constants[1] then pointer = pointer + 1 end 
elseif pointer == 15 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 16 then -- 10 [NEWTABLE] 
 	Stack[5] = {} 
elseif pointer == 17 then -- 9 [SETTABLE] 
 	Stack[5][Constants[6]] = Stack[1] 
elseif pointer == 18 then -- 9 [SETTABLE] 
 	Stack[5][Constants[5]] = Constants[3] 
elseif pointer == 19 then -- 0 [MOVE] 
 Temp[14] = 3
Temp[7] = 5
Stack[Temp[14]] = Stack[Temp[7]] 
elseif pointer == 20 then -- 4 [GETUPVAL] 
 	Stack[5] = Upvalues[0] 
elseif pointer == 21 then -- 9 [SETTABLE] 
 	Stack[5][Stack[0]] = Stack[3] 
elseif pointer == 22 then -- 6 [GETTABLE] 
 	Stack[5] = Stack[3][Constants[5]]
	 
elseif pointer == 23 then -- 12 [ADD] 
 	Stack[5] = Stack[5] + Stack[2] 
elseif pointer == 24 then -- 9 [SETTABLE] 
 	Stack[3][Constants[5]] = Stack[5] 
elseif pointer == 25 then -- 4 [GETUPVAL] 
 	Stack[5] = Upvalues[1] 
elseif pointer == 26 then -- 12 [ADD] 
 	Stack[5] = Stack[5] + Stack[4] 
elseif pointer == 27 then -- 8 [SETUPVAL] 
 	Upvalues[1] = Stack[5] 
elseif pointer == 28 then -- 2 [LOADBOOL] 
 Temp[4] = 5
Temp[8] = ttostring ~= __metatable
Stack[Temp[4]] = Temp[15] 
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
		local encoded = {(decrypt("\084\089\082\055", "1911")),(decrypt("\021\060", "2791")),(decrypt("\095\100\080\109\110\083", "1803")),(decrypt("\090\085\097\086\089\089\082\067", "2993")),(decrypt("\082\094\089\032\100\087\081\084\108\104\047", "782")),(decrypt("\090\101\093\088\023\102\089\087\082", "1923")),((decrypt("\025\022\000\027", "2106"))),(decrypt("\091\101\093\088\081\092\104\089\103", "1963")),}

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
 	if Stack[2] ~= Constants[1] then pointer = pointer + 1 end 
elseif pointer == 4 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 5 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[2][Constants[4]]
	 
elseif pointer == 6 then -- 24 [LT] 
 	if Stack[3] < Stack[1] then pointer = pointer + 1 end 
elseif pointer == 7 then -- 22 [JMP] 
 pointer = pointer + 5  
elseif pointer == 8 then -- 2 [LOADBOOL] 
 Temp[4] = 3
Temp[14] = byte == pairs
Stack[Temp[4]] = Temp[1] 
elseif pointer == 9 then -- 1 [LOADK] 
 Temp[12] = 4
Temp[13] = Constants
Temp[4] = 5
Stack[Temp[12]] = Temp[13][Temp[4]] 
elseif pointer == 10 then -- 0 [MOVE] 
 Temp[7] = 5
Temp[10] = 0
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 11 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 4, 5 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[4] = Temp[1]
	 
elseif pointer == 12 then -- 30 [RETURN] 
 	return Stack[3], Stack[4] 
elseif pointer == 13 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[2][Constants[4]]
	 
elseif pointer == 14 then -- 13 [SUB] 
 	Stack[3] = Stack[3] - Stack[1] 
elseif pointer == 15 then -- 9 [SETTABLE] 
 	Stack[2][Constants[4]] = Stack[3] 
elseif pointer == 16 then -- 4 [GETUPVAL] 
 	Stack[3] = Upvalues[1] 
elseif pointer == 17 then -- 6 [GETTABLE] 
 	Stack[4] = Stack[2][Constants[3]]
	 
elseif pointer == 18 then -- 14 [MUL] 
 	Stack[4] = Stack[4] * Stack[1] 
elseif pointer == 19 then -- 13 [SUB] 
 	Stack[3] = Stack[3] - Stack[4] 
elseif pointer == 20 then -- 8 [SETUPVAL] 
 	Upvalues[1] = Stack[3] 
elseif pointer == 21 then -- 6 [GETTABLE] 
 	Stack[3] = Stack[2][Constants[4]]
	 
elseif pointer == 22 then -- 23 [EQ] 
 	if Stack[3] == Constants[2] then pointer = pointer + 1 end 
elseif pointer == 23 then -- 22 [JMP] 
 pointer = pointer + 2  
elseif pointer == 24 then -- 4 [GETUPVAL] 
 	Stack[3] = Upvalues[0] 
elseif pointer == 25 then -- 9 [SETTABLE] 
 	Stack[3][Stack[0]] = Constants[1] 
elseif pointer == 26 then -- 2 [LOADBOOL] 
 Temp[10] = 3
Temp[8] = ttostring ~= __metatable
Stack[Temp[10]] = Temp[2] 
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
		local encoded = {(decrypt("\009\110\104\084\105\110\105", "222")),(decrypt("\083\108\083\093\094", "443")),(decrypt("\090\080\089\097\082\033\092\101\081\104\109\082\000\033", "1629")),(decrypt("\011\095\081\081\088", "1927")),(decrypt("\026\057", "2242")),(decrypt("\038\039", "1856")),(decrypt("\122\100\108\090", "384")),(decrypt("\091\094\095\093", "1866")),(decrypt("\089\085\104\087\090\089\091\066", "1902")),(decrypt("\086\093\081\087\090", "1412")),(decrypt("\095\104\084\106\110\095", "1444")),(decrypt("\089\110\106\081\110", "2632")),(decrypt("\038\090", "1595")),(decrypt("\123\101\090\094\106\087\085\089\087\103", "2909")),(decrypt("\083\085\096\083\091\082", "328")),(decrypt("\083\104\022", "1663")),(decrypt("\008\095\082\082\105\095\090\084", "2941")),(decrypt("\127\097\085\094\012\095\092\015\110\089\086\110", "1955")),}

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
 Temp[3] = 1
Temp[15] = 2
Temp[13] = Constants[Temp[15]]
Stack[Temp[3]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 3 then -- 4 [GETUPVAL] 
 	Stack[2] = Upvalues[0] 
elseif pointer == 4 then -- 28 [CALL] 
 	Stack[1], Stack[2], Stack[3] = Stack[1](Stack[2]) 
elseif pointer == 5 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 6 then -- 20 [LEN] 
 	Stack[5] = #Stack[0] 
elseif pointer == 7 then -- 12 [ADD] 
 	Stack[5] = Stack[5] + Constants[5] 
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
 Temp[14] = 1
Temp[2] = 12
Temp[10] = Constants[Temp[2]]
Stack[Temp[14]] = vmEnv[Temp[10]] or Env[Temp[10]]
	Stack[1] = Stack[1][Constants[8]]
	
	pointer = pointer + 1 
elseif pointer == 13 then -- 0 [MOVE] 
 Temp[3] = 2
Temp[15] = 0
Stack[Temp[3]] = Stack[Temp[15]] 
elseif pointer == 14 then -- 28 [CALL] 
 	Stack[1](Stack[2]) 
elseif pointer == 15 then -- 5 [GETGLOBAL] 
 Temp[10] = 1
Temp[6] = 15
Temp[13] = Constants[Temp[6]]
Stack[Temp[10]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 16 then -- 0 [MOVE] 
 Temp[5] = 2
Temp[4] = 0
Stack[Temp[5]] = Stack[Temp[4]] 
elseif pointer == 17 then -- 28 [CALL] 
 	Stack[1], Stack[2], Stack[3] = Stack[1](Stack[2]) 
elseif pointer == 18 then -- 22 [JMP] 
 pointer = pointer + 13  
elseif pointer == 19 then -- 4 [GETUPVAL] 
 	Stack[6] = Upvalues[0] 
elseif pointer == 20 then -- 6 [GETTABLE] 
 	Stack[6] = Stack[6][Stack[5]]
	 
elseif pointer == 21 then -- 5 [GETGLOBAL] 
 Temp[13] = 7
Temp[7] = 10
Temp[3] = Constants[Temp[7]]
Stack[Temp[13]] = vmEnv[Temp[3]] or Env[Temp[3]] 
elseif pointer == 22 then -- 0 [MOVE] 
 Temp[6] = 8
Temp[9] = 5
Stack[Temp[6]] = Stack[Temp[9]] 
elseif pointer == 23 then -- 1 [LOADK] 
 Temp[13] = 9
Temp[16] = Constants
Temp[4] = 13
Stack[Temp[13]] = Temp[16][Temp[4]] 
elseif pointer == 24 then -- 6 [GETTABLE] 
 	Stack[10] = Stack[6][Constants[9]]
	 
elseif pointer == 25 then -- 1 [LOADK] 
 Temp[14] = 11
Temp[8] = Constants
Temp[4] = 6
Stack[Temp[14]] = Temp[8][Temp[4]] 
elseif pointer == 26 then -- 6 [GETTABLE] 
 	Stack[12] = Stack[6][Constants[11]]
	 
elseif pointer == 27 then -- 6 [GETTABLE] 
 	Stack[13] = Stack[6][Constants[9]]
	 
elseif pointer == 28 then -- 14 [MUL] 
 	Stack[12] = Stack[12] * Stack[13] 
elseif pointer == 29 then -- 1 [LOADK] 
 Temp[16] = 13
Temp[1] = Constants
Temp[3] = 16
Stack[Temp[16]] = Temp[1][Temp[3]] 
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
 Temp[10] = 1
Temp[4] = 10
Temp[2] = Constants[Temp[4]]
Stack[Temp[10]] = vmEnv[Temp[2]] or Env[Temp[2]] 
elseif pointer == 35 then -- 1 [LOADK] 
 Temp[6] = 2
Temp[1] = Constants
Temp[4] = 3
Stack[Temp[6]] = Temp[1][Temp[4]] 
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
 Temp[2] = 6
Temp[15] = 15
Temp[5] = Constants[Temp[15]]
Stack[Temp[2]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 17 then -- 0 [MOVE] 
 Temp[16] = 7
Temp[14] = 3
Stack[Temp[16]] = Stack[Temp[14]] 
elseif pointer == 18 then -- 1 [LOADK] 
 Temp[6] = 8
Temp[15] = Constants
Temp[13] = 11
Stack[Temp[6]] = Temp[15][Temp[13]] 
elseif pointer == 19 then -- 1 [LOADK] 
 Temp[9] = 9
Temp[11] = Constants
Temp[10] = 10
Stack[Temp[9]] = Temp[11][Temp[10]] 
elseif pointer == 20 then -- 1 [LOADK] 
 Temp[5] = 10
Temp[16] = Constants
Temp[15] = 4
Stack[Temp[5]] = Temp[16][Temp[15]]
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
 Temp[13] = 6
Temp[10] = 15
Temp[3] = Constants[Temp[10]]
Stack[Temp[13]] = vmEnv[Temp[3]] or Env[Temp[3]] 
elseif pointer == 24 then -- 0 [MOVE] 
 Temp[9] = 7
Temp[14] = 3
Stack[Temp[9]] = Stack[Temp[14]] 
elseif pointer == 25 then -- 1 [LOADK] 
 Temp[16] = 8
Temp[4] = Constants
Temp[5] = 2
Stack[Temp[16]] = Temp[4][Temp[5]] 
elseif pointer == 26 then -- 1 [LOADK] 
 Temp[15] = 9
Temp[5] = Constants
Temp[4] = 16
Stack[Temp[15]] = Temp[5][Temp[4]] 
elseif pointer == 27 then -- 1 [LOADK] 
 Temp[10] = 10
Temp[5] = Constants
Temp[16] = 14
Stack[Temp[10]] = Temp[5][Temp[16]]
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
 Temp[6] = 6
Temp[3] = 15
Temp[5] = Constants[Temp[3]]
Stack[Temp[6]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 31 then -- 0 [MOVE] 
 Temp[6] = 7
Temp[16] = 3
Stack[Temp[6]] = Stack[Temp[16]] 
elseif pointer == 32 then -- 1 [LOADK] 
 Temp[10] = 8
Temp[4] = Constants
Temp[13] = 7
Stack[Temp[10]] = Temp[4][Temp[13]] 
elseif pointer == 33 then -- 1 [LOADK] 
 Temp[2] = 9
Temp[15] = Constants
Temp[6] = 3
Stack[Temp[2]] = Temp[15][Temp[6]] 
elseif pointer == 34 then -- 1 [LOADK] 
 Temp[6] = 10
Temp[14] = Constants
Temp[5] = 4
Stack[Temp[6]] = Temp[14][Temp[5]]
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
 Temp[3] = 6
Temp[7] = 15
Temp[11] = Constants[Temp[7]]
Stack[Temp[3]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 38 then -- 0 [MOVE] 
 Temp[5] = 7
Temp[7] = 4
Stack[Temp[5]] = Stack[Temp[7]] 
elseif pointer == 39 then -- 1 [LOADK] 
 Temp[15] = 8
Temp[9] = Constants
Temp[12] = 11
Stack[Temp[15]] = Temp[9][Temp[12]] 
elseif pointer == 40 then -- 1 [LOADK] 
 Temp[14] = 9
Temp[15] = Constants
Temp[7] = 14
Stack[Temp[14]] = Temp[15][Temp[7]]
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
 Temp[7] = 6
Temp[4] = 15
Temp[11] = Constants[Temp[4]]
Stack[Temp[7]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 44 then -- 0 [MOVE] 
 Temp[7] = 7
Temp[10] = 4
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 45 then -- 1 [LOADK] 
 Temp[14] = 8
Temp[12] = Constants
Temp[15] = 13
Stack[Temp[14]] = Temp[12][Temp[15]] 
elseif pointer == 46 then -- 1 [LOADK] 
 Temp[13] = 9
Temp[6] = Constants
Temp[2] = 14
Stack[Temp[13]] = Temp[6][Temp[2]]
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
 Temp[9] = 6
Temp[7] = 5
Stack[Temp[9]] = Stack[Temp[7]] 
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