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
				if (pointer * 10) + pointer <= 341 then
	if (pointer * pointer) + (2 * pointer) <= 255 then
		if pointer * pointer <= 49 then
			if (pointer * pointer) + (8 * pointer) <= 33 then
				if (pointer * pointer) + (10 * pointer) == 11 then
					do
						if pointer + 9 == 10 then
			Temp[1] = 0
Temp[11] = ttostring ~= __metatable
Stack[Temp[1]] = Temp[6]
		end
					end
				elseif (pointer * pointer * 3) + pointer == 30 then
					do
						if pointer + 2 == 5 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\027\059", "107")),(decrypt("\085\082\092\003", "215")),(decrypt("\022\051", "1800")),(decrypt("\024\057", "123")),(decrypt("\116\089\092\035\084\104\032\080\110\081\081\093\066", "2574")),(decrypt("\121\100\105\084\008\094\082\086\091", "2810")),(decrypt("\030\057", "627")),}

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
		if (pointer * pointer) + (4 * pointer) <= 77 then
	if pointer * pointer <= 9 then
		if (pointer * 8) + (pointer * 6) == 14 then
			do
				if (pointer - 80) > pointer then
			Stack[4] = (1 == 1)
		else
			do
				if pointer + 13 == 29 then
					Stack[7] = nil
				end
				if pointer * 2 - 5 == -3 then
					Temp[4] = 1
Temp[14] = Constants
Temp[13] = 3
Stack[Temp[4]] = Temp[14][Temp[13]]
				end
			end
		end
			end
		elseif (pointer * pointer * 4) + pointer == 18 then
			do
				if pointer + 13 == 15 then
				if Stack[0] ~= Constants[7] then pointer = pointer + 1 end
		end
			end
		elseif (pointer * 10) + (pointer * 46) == 168 then
			do
				do
			if pointer + 2 == 5 then
					if pointer * 3 - 4 == 5 then
					if pointer * 3 - 7 == 2 then
					pointer = pointer + 9 
				else
					Stack[6] = nil
				end
				else
					Stack[6] = nil
				end
				end
		end
			end
		end
	else
		if (pointer * pointer) + (3 * pointer) == 54 then
			do
				do
			if pointer * 2 + 6 == 18 then
					if pointer + 4 == 10 then
					pointer = pointer + 2 
				end
				end
		end
			end
		elseif (pointer * pointer) + (15 * pointer) == 100 then
			do
				do
			if pointer * 2 + 4 == 14 then
					if pointer - 5 == 0 then
					if pointer - 6 == -1 then
						if Stack[2] == Constants[3] then pointer = pointer + 1 end
				end
				elseif pointer - 5 == 12 then
					Stack[6] = Env[8]
				end
				end
		end
			end
		elseif (pointer * 2) + (pointer * 46) == 336 then
			do
				do
			if pointer + 6 == 13 then
						Stack[0] = Stack[0] / Constants[4]
				end
		end
			end
		elseif (pointer * pointer) + (11 * pointer) == 60 then
			do
				if pointer + 7 == 11 then
				Stack[2] = Stack[0] % Constants[4]
		end
			end
		end
	end
else
	if (pointer * pointer) + (14 * pointer) <= 240 then
		if (pointer * pointer) + (4 * pointer) == 140 then
			do
				if (pointer - 54) > pointer then
			Stack[8] = (1 == 1)
		else
			do
				if pointer * 3 - 11 == 19 then
						Stack[0] = Stack[2] + Constants[7]
				else
					Stack[6] = nil
				end
			end
		end
			end
		elseif (pointer * 5) + (pointer * 19) == 216 then
			do
				if pointer + 5 == 14 then
				Stack[2] = Constants[1] * Stack[0]
		end
			end
		elseif (pointer * pointer) + (6 * pointer) == 112 then
			do
				do
			if pointer * 2 - 4 == 12 then
					if pointer + 8 == 16 then
					pointer = pointer + 2 
				end
				end
		end
			end
		end
	else
		if (pointer * 3) + (pointer * 24) == 351 then
			do
				if pointer + 1 == 14 then
				return Stack[1]
		end
			end
		elseif (pointer * pointer * 2) + pointer == 300 then
			do
				do
			if pointer * 3 - 13 == 23 then
					if pointer - 14 == -2 then
					if pointer + 9 ~= 37 then
					pointer = pointer + -11 
				end
				elseif pointer - 14 == 18 then
					Stack[7] = Env[8]
				end
				else
					Stack[7] = nil
				end
		end
			end
		elseif (pointer * pointer) + (5 * pointer) == 176 then
			do
				if (pointer + 18) > pointer then
			do
				if pointer * 3 - 10 == 23 then
					if pointer - 5 == 6 then
					if pointer * 2 - 6 == 16 then
						Stack[1] = Stack[1] + Constants[7]
				end
				elseif pointer - 5 == 23 then
					Stack[1] = Env[3]
				end
				else
					Stack[1] = nil
				end
			end
		else
			Stack[4] = nil
		end
			end
		elseif (pointer * pointer * 2) + pointer == 406 then
			do
				do
			if pointer + 14 == 28 then
						return
				end
		end
			end
		end
	end
end
		pointer = pointer+1
		end
	end

		end
					end
				elseif (pointer * pointer) + 11 == 15 then
					do
						do
			if pointer + 8 == 10 then
					if pointer * 2 + 6 == 10 then
					if pointer - 10 == -8 then
					Temp[2] = vmEnv
Temp[15] = 20
Temp[5] = Constants[Temp[15]]
Temp[16] = 0
Temp[2][Temp[5]] = Temp[5]
				elseif pointer - 10 == 11 then
					Stack[5] = Env[8]
				end
				end
				end
		end
					end
				end
			else
				if (pointer * pointer) + 23 == 48 then
					do
						if pointer + 8 == 13 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\024\050", "1973")),(decrypt("\025\058", "1170")),(decrypt("\014\111\089", "1366")),((decrypt("\029", "1852"))),(decrypt("\115\088\107\099\081\036\095\094\111\080\110\080\095\093", "933")),(decrypt("\022\060", "1775")),((decrypt("\027\017\024", "2603"))),(decrypt("\114\092\084\111\081\089\098\032\088\082\097\092\110", "2997")),}

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
		if (pointer * 11) + pointer <= 72 then
	if (pointer * 12) + pointer <= 39 then
		if (pointer * pointer * 4) + pointer == 18 then
			do
				if pointer + 3 == 5 then
			Temp[3] = 3
Temp[8] = 0
Stack[Temp[3]] = Stack[Temp[8]]
		end
			end
		elseif (pointer * pointer) + 9 == 18 then
			do
				if (pointer + 63) > pointer then
			do
				if pointer - 6 == -3 then
					if pointer + 10 == 13 then
					if pointer * 2 - 3 == 3 then
					Temp[4] = 4
Temp[11] = Constants
Temp[3] = 2
Stack[Temp[4]] = Temp[11][Temp[3]]
				end
				end
				elseif pointer - 6 == 10 then
					Stack[5] = Env[3]
				end
			end
		else
			if pointer > 90 then Stack[6] = Stack[6] end
		end
			end
		elseif (pointer * pointer) + 5 == 6 then
			do
				if pointer + 12 == 13 then
			Temp[9] = 2
Temp[15] = Constants
Temp[8] = 1
Stack[Temp[9]] = Temp[15][Temp[8]]
		end
			end
		end
	else
		if (pointer * pointer) + (6 * pointer) == 72 then
			do
				do
			if pointer + 15 == 39 then
					Stack[8] = nil
				end
				if pointer * 2 + 15 == 27 then
						if Stack[6] == Constants[6] then pointer = pointer + 1 end
				end
		end
			end
		elseif (pointer * 12) + (pointer * 39) == 204 then
			do
				if (pointer + 98) > pointer then
			do
				if pointer * 2 + 8 == 16 then
					if pointer * 3 - 15 == -3 then
					    Stack[2] = Stack[2] - Stack[4]
    pointer = pointer + 5
    
				else
					Stack[5] = nil
				end
				end
			end
		else
			Stack[2] = -Stack[2]
		end
			end
		elseif (pointer * pointer) + (2 * pointer) == 35 then
			do
				if pointer + 11 == 16 then
				Stack[6] = Stack[0] % Stack[5]
		end
			end
		end
	end
else
	if pointer * pointer <= 81 then
		if (pointer * pointer) + (8 * pointer) == 128 then
			do
				if (pointer + 76) > pointer then
			do
				if pointer + 1 ~= 25 then
					if pointer - 3 == 5 then
					Temp[5] = 1
Temp[14] = 5
Stack[Temp[5]] = Stack[Temp[14]]
				end
				end
			end
		else
			Stack[2] = nil
		end
			end
		elseif (pointer * pointer) + (2 * pointer) == 99 then
			do
				if (pointer - 59) > pointer then
						Temp[4] = vmEnv
			Temp[3] = 4
			Temp[4] = Constants[Temp[14]]
			Temp[3] = 13
			Temp[17][Temp[12]] = Temp[18]
		else
			do
				if pointer * 2 - 6 == 12 then
					if pointer - 3 == 6 then
					pointer = pointer + 1 
				elseif pointer - 3 == 22 then
					Stack[5] = Env[1]
				end
				end
			end
		end
			end
		elseif (pointer * pointer * 5) + pointer == 252 then
			do
				do
			if pointer * 2 + 12 == 26 then
					if pointer - 2 == 5 then
					pointer = pointer + 2 
				end
				end
		end
			end
		end
	else
		if (pointer * pointer) + (5 * pointer) == 176 then
			do
				do
			if pointer + 15 ~= 32 then
						return Stack[1]
				end
		end
			end
		elseif (pointer * pointer) + 11 == 155 then
			do
				if pointer + 9 == 21 then
				return
		end
			end
		elseif (pointer * pointer) + 18 == 118 then
			do
				if (pointer - 95) > pointer then
			if pointer > 83 then Stack[1] = Stack[5] end
		else
			do
				if pointer + 14 == 30 then
					Stack[7] = nil
				end
				    Stack[2] = Stack[2] + Stack[4]
    if (Stack[4] > 0 and Stack[2] <= Stack[3]) or (Stack[4] <= 0 and Stack[2] >= Stack[3]) then
        pointer = pointer + -6
        Stack[5] = Stack[2]
    end
    
			end
		end
			end
		end
	end
end
		pointer = pointer+1
		end
	end

		end
					end
				elseif (pointer * pointer * 4) + pointer == 68 then
					do
						if (pointer + 65) > pointer then
			do
				if pointer - 5 == -1 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\026\022\061", "2168")),(decrypt("\021\063", "2429")),(decrypt("\084\110\111\096\090\082\092\100", "1218")),(decrypt("\009\087\110\100\091\089\093\072\011\109\108\093\111\110\111", "1248")),(decrypt("\010\107\083\091\088\081\073", "1790")),(decrypt("\091\083\106\090\082", "1729")),(decrypt("\025\030\018\051", "1958")),(decrypt("\085\111\106\087\093\087", "1317")),(decrypt("\081\107\091\110\110", "2320")),(decrypt("\008\085\080\106\117\107\099\084\106\109\101\092", "2396")),(decrypt("\008\081\094\088\094\080\092\109\105\032\108\105\089\111", "2771")),(decrypt("\064\100\080\080", "1896")),(decrypt("\115\091\085\082\082\082\111", "2715")),}

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
		if (pointer * pointer) + (15 * pointer) <= 286 then
	if (pointer * 7) + pointer <= 40 then
		if (pointer * 13) + pointer <= 28 then
			if (pointer * 4) + (pointer * 16) == 20 then
				do
					if (pointer + 72) > pointer then
			do
				if pointer * 2 - 9 == -7 then
					if pointer * 2 + 1 == 3 then
						if Stack[0] < Constants[2] then pointer = pointer + 1 end
				end
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
				end
			elseif (pointer * pointer) + 45 == 49 then
				do
					if (pointer + 75) > pointer then
			do
				if pointer + 6 == 8 then
					pointer = pointer + 3 
				end
			end
		else
			Stack[5] = nil
		end
				end
			end
		else
			if (pointer * pointer * 3) + pointer == 52 then
				do
					if pointer + 4 == 8 then
				return Stack[1]
		end
				end
			elseif (pointer * pointer) + (10 * pointer) == 75 then
				do
					if (pointer - 95) > pointer then
			Stack[3] = nil
		else
			do
				if pointer + 11 == 22 then
					Stack[4] = nil
				end
				pointer = pointer + 17 
			end
		end
				end
			elseif (pointer * 13) + (pointer * 13) == 78 then
				do
					if pointer + 2 == 5 then
			Temp[10] = 1
Temp[6] = Constants
Temp[4] = 3
Stack[Temp[10]] = Temp[6][Temp[4]]
		end
				end
			end
		end
	else
		if (pointer * 9) + pointer <= 80 then
			if (pointer * 12) + (pointer * 38) == 400 then
				do
					if pointer + 6 == 14 then
			Temp[8] = 1
Temp[13] = Constants
Temp[12] = 12
Stack[Temp[8]] = Temp[13][Temp[12]]
		end
				end
			elseif (pointer * pointer) + 9 == 58 then
				do
					if (pointer + 20) > pointer then
			do
				if pointer * 2 - 2 == 12 then
					pointer = pointer + 3 
				end
			end
		else
			Stack[1] = nil
		end
				end
			elseif (pointer * pointer * 5) + pointer == 186 then
				do
					do
			if pointer - 15 == -9 then
						if Stack[0] == Constants[2] then pointer = pointer + 1 end
				elseif pointer - 15 == 1 then
					Stack[6] = Env[1]
				end
		end
				end
			end
		else
			if (pointer * pointer * 3) + pointer == 252 then
				do
					if (pointer - 70) > pointer then
						Temp[2] = vmEnv
			Temp[18] = 5
			Temp[9] = Constants[Temp[11]]
			Temp[12] = 16
			Temp[18][Temp[10]] = Temp[8]
		else
			do
				if pointer + 12 == 21 then
					if pointer * 2 - 3 == 15 then
						return Stack[1]
				end
				end
			end
		end
				end
			elseif (pointer * pointer) + (13 * pointer) == 230 then
				do
					do
			if pointer + 13 ~= 36 then
					pointer = pointer + 12 
				end
		end
				end
			elseif (pointer * 13) + (pointer * 37) == 550 then
				do
					if (pointer - 88) > pointer then
			if pointer > 170 then Stack[6] = Stack[6] end
		else
			do
				if pointer - 5 == 6 then
					if pointer + 4 ~= 20 then
					if pointer * 2 + 12 == 34 then
						if Stack[0] < Constants[1] then pointer = pointer + 1 end
				end
				end
				end
			end
		end
				end
			end
		end
	end
else
	if pointer * pointer <= 289 then
		if pointer * pointer <= 196 then
			if (pointer * pointer * 2) + pointer == 406 then
				do
					if pointer + 3 == 17 then
				return Stack[1]
		end
				end
			elseif (pointer * pointer) + (4 * pointer) == 192 then
				do
					do
			if pointer - 8 == 4 then
					pointer = pointer + 3 
				elseif pointer - 8 == 24 then
					Stack[2] = Env[7]
				end
		end
				end
			elseif (pointer * pointer * 5) + pointer == 858 then
				do
					if (pointer - 44) > pointer then
			Stack[7] = -Stack[8]
		else
			do
				if pointer * 2 - 8 == 18 then
					if pointer * 2 + 7 == 33 then
					if pointer - 14 == -1 then
					Temp[2] = 1
Temp[8] = Constants
Temp[1] = 6
Stack[Temp[2]] = Temp[8][Temp[1]]
				end
				end
				end
			end
		end
				end
			end
		else
			if (pointer * pointer * 2) + pointer == 465 then
				do
					if pointer + 4 == 19 then
			pointer = pointer + 7 
		end
				end
			elseif (pointer * pointer * 3) + pointer == 784 then
				do
					do
			if pointer - 5 == 11 then
					if pointer + 2 ~= 36 then
						if Stack[0] < Constants[7] then pointer = pointer + 1 end
				end
				end
		end
				end
			elseif (pointer * pointer) + (5 * pointer) == 374 then
				do
					if pointer + 10 == 27 then
			pointer = pointer + 3 
		end
				end
			end
		end
	else
		if (pointer * 15) + pointer <= 320 then
			if (pointer * 8) + (pointer * 17) == 475 then
				do
					if pointer + 11 == 30 then
				return Stack[1]
		end
				end
			elseif (pointer * pointer) + 39 == 363 then
				do
					if pointer + 14 == 32 then
			Temp[12] = 1
Temp[9] = Constants
Temp[4] = 8
Stack[Temp[12]] = Temp[9][Temp[4]]
		end
				end
			elseif (pointer * pointer * 2) + pointer == 820 then
				do
					if (pointer + 84) > pointer then
			do
				if pointer + 8 == 28 then
					if pointer * 2 + 2 == 42 then
					if pointer - 13 == 7 then
					pointer = pointer + 2 
				end
				end
				end
			end
		else
			Stack[6] = nil
		end
				end
			end
		else
			if (pointer * pointer) + 7 == 536 then
				do
					if (pointer - 84) > pointer then
			Stack[2] = Stack[1] or Constants[3+1]
		else
			do
				if pointer - 5 == 18 then
						return
				end
			end
		end
				end
			elseif (pointer * pointer * 3) + pointer == 1474 then
				do
					if (pointer - 19) > pointer then
			Stack[6] = (1 == 1)
		else
			do
				if pointer * 2 - 8 == 36 then
						return Stack[1]
				end
			end
		end
				end
			elseif (pointer * 11) + (pointer * 7) == 378 then
				do
					if (pointer + 7) > pointer then
			do
				if pointer * 2 + 8 == 50 then
					if pointer * 3 - 12 == 51 then
					if pointer + 5 ~= 46 then
					Temp[2] = 1
Temp[9] = Constants
Temp[7] = 9
Stack[Temp[2]] = Temp[9][Temp[7]]
				end
				else
					Stack[6] = nil
				end
				end
			end
		else
			Stack[5] = (0 == 1)
		end
				end
			end
		end
	end
end
		pointer = pointer+1
		end
	end

				elseif pointer - 5 == 4 then
					Stack[7] = Env[4]
				end
			end
		else
			Temp[19] = 4
			Temp[17] = Constants
			Temp[2] = 12
			Stack[Temp[4]] = Temp[19][Temp[12]]
		end
					end
				elseif (pointer * pointer) + 24 == 60 then
					do
						if (pointer + 19) > pointer then
			do
				if pointer * 2 + 4 == 16 then
					if pointer - 2 == 4 then
					if pointer - 11 == -5 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\083\090\080\085", "663")),(decrypt("\124\107\089\090\111\091\095\080\104\098\111\122\100\090\093\088\105\108", "830")),(decrypt("\111\080\086\085\091", "2303")),(decrypt("\021\062", "2559")),(decrypt("\104\094\095\080\095\005\017\019", "754")),(decrypt("\110\082\082\087\091\008\031\022\106\089\083\106\087\080\098\021\107\095\093\022\105\094\089\022\095\101\096\111\087\095\091\090\023\017\018\023\022\016\017\028\028\020\021\022\064\096\080\064\087\099\104\010\085\084\083\110\123\017\073\120\116\093\019\065\011\090\125\123\014\020\096\113\110\009\006\014\105\104\021\087\025\116\112\108\111\097\090", "1990")),(decrypt("\029\016\058", "571")),((decrypt("\017\020\019\030\020\019\030", "934"))),(decrypt("\086\111\092\110", "2771")),}

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
		if (pointer * 8) + pointer <= 54 then
	if (pointer * pointer) + (12 * pointer) <= 28 then
		if (pointer * pointer * 4) + pointer == 5 then
			do
				if (pointer - 64) > pointer then
			Stack[5] = nil
		else
			do
				if pointer * 3 - 8 == -5 then
					if pointer - 2 == -1 then
					if pointer - 12 == -11 then
					Temp[13] = 1
Temp[6] = Constants
Temp[8] = 4
Stack[Temp[13]] = Temp[6][Temp[8]]
				end
				end
				else
					Stack[5] = nil
				end
			end
		end
			end
		elseif (pointer * pointer) + 8 == 12 then
			do
				if (pointer - 40) > pointer then
			Stack[1] = Stack[6] or Constants[4+1]
		else
			do
				if pointer * 2 + 10 == 14 then
					if pointer * 2 + 12 == 16 then
						Stack[2] = Stack[0] % Constants[7]
				end
				end
			end
		end
			end
		end
	else
		if (pointer * 9) + (pointer * 49) == 348 then
			do
				do
			if pointer * 3 - 10 == 8 then
					if pointer + 13 == 19 then
					if pointer * 2 - 1 == 11 then
						Stack[3] = Stack[0] / Constants[7]
				end
				end
				else
					Stack[3] = nil
				end
		end
			end
		elseif (pointer * pointer) + (6 * pointer) == 40 then
			do
				if pointer + 12 == 16 then
			Temp[15] = 2
Temp[12] = 9
Temp[6] = Constants[Temp[12]]
Stack[Temp[15]] = vmEnv[Temp[6]] or Env[Temp[6]]
	Stack[2] = Stack[2][Constants[3]]
	
	pointer = pointer + 1
		end
			end
		elseif (pointer * 5) + (pointer * 49) == 162 then
			do
				do
			if pointer + 15 == 34 then
					Stack[7] = nil
				end
					Stack[1] = Stack[1] + Stack[2]
		end
			end
		end
	end
else
	if (pointer * pointer) + (3 * pointer) <= 108 then
		if (pointer * pointer) + (7 * pointer) == 120 then
			do
				do
			if pointer + 4 ~= 31 then
					Temp[4] = 0
Temp[3] = 2
Stack[Temp[4]] = Stack[Temp[3]]
				end
		end
			end
		elseif (pointer * 10) + (pointer * 8) == 162 then
			do
				if pointer + 12 == 21 then
				if Stack[0] == Constants[4] then pointer = pointer + 1 end
		end
			end
		elseif (pointer * 6) + (pointer * 15) == 147 then
			do
				if pointer + 9 == 16 then
				Stack[2] = Stack[2](Stack[3])
		end
			end
		end
	else
		if (pointer * pointer) + (10 * pointer) == 200 then
			do
				if pointer + 14 == 24 then
			pointer = pointer + -9 
		end
			end
		elseif (pointer * pointer) + 38 == 159 then
			do
				if (pointer + 61) > pointer then
			do
				if pointer + 2 ~= 29 then
						return Stack[1]
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
			end
		elseif (pointer * pointer) + 16 == 160 then
			do
				do
			if pointer + 11 ~= 27 then
					if pointer - 4 == 8 then
					if pointer - 10 == 2 then
						return
				end
				elseif pointer - 4 == 17 then
					Stack[4] = Env[2]
				end
				end
		end
			end
		end
	end
end
		pointer = pointer+1
		end
	end

				end
				end
				end
			end
		else
			Temp[12] = 3
			Temp[11] = Constants
			Temp[19] = 1
			Stack[Temp[7]] = Temp[13][Temp[10]]
		end
					end
				elseif (pointer * pointer) + (6 * pointer) == 91 then
					do
						if pointer + 8 == 15 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {(decrypt("\104", "1004")),(decrypt("\090\097\104\080\109", "1913")),(decrypt("\091\096\088\105\088\083\107\090\082\098\006\023\020", "2971")),(decrypt("\088\084\110", "2875")),(decrypt("\025\057", "1251")),(decrypt("\088\082\105\091\089", "2912")),(decrypt("\105", "1811")),(decrypt("\124", "2253")),(decrypt("\108\083\086\108\109\088", "653")),(decrypt("\083\104\100\092\012", "948")),(decrypt("\105\110\105\104\086\095", "1434")),(decrypt("\091\101\104\085\009\000", "1940")),(decrypt("\007", "2244")),(decrypt("\104", "2175")),}

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
		if (pointer * pointer) + (10 * pointer) <= 704 then
	if pointer * pointer <= 121 then
		if (pointer * 15) + pointer <= 80 then
			if (pointer * pointer) + (12 * pointer) <= 28 then
				if (pointer * pointer) + (14 * pointer) == 15 then
					do
						do
			if pointer * 2 + 14 == 16 then
					if pointer + 10 ~= 30 then
					if pointer + 13 == 14 then
					Temp[1] = 1
Temp[14] = Constants
Temp[5] = 6
Stack[Temp[1]] = Temp[14][Temp[5]]
				end
				end
				end
		end
					end
				elseif (pointer * pointer) + 29 == 33 then
					do
						if pointer + 14 == 16 then
				Stack[2] = {}
		end
					end
				end
			else
				if (pointer * pointer) + 25 == 41 then
					do
						if (pointer + 27) > pointer then
			do
				if pointer + 6 == 10 then
					if pointer + 11 == 17 then
					Stack[3] = nil
				end
					Stack[4] = #Stack[0]
				end
			end
		else
			Stack[7] = (1 == 1)
		end
					end
				elseif (pointer * pointer * 2) + pointer == 21 then
					do
						do
			if pointer * 2 + 8 == 14 then
					if pointer + 15 == 18 then
					Temp[4] = 3
Temp[2] = Constants
Temp[6] = 5
Stack[Temp[4]] = Temp[2][Temp[6]]
				end
				end
		end
					end
				elseif (pointer * pointer * 4) + pointer == 105 then
					do
						do
			if pointer * 2 + 14 == 24 then
					if pointer + 11 == 18 then
					Stack[3] = nil
				end
				Temp[1] = 5
Temp[16] = Constants
Temp[12] = 5
Stack[Temp[1]] = Temp[16][Temp[12]]
				end
		end
					end
				end
			end
		else
			if (pointer * pointer) + (5 * pointer) <= 104 then
				if (pointer * pointer * 4) + pointer == 264 then
					do
						if (pointer - 61) > pointer then
			Stack[2] = -Stack[1]
		else
			do
				if pointer * 3 - 1 == 23 then
					if pointer * 3 - 2 == 22 then
					if pointer + 6 == 32 then
					Stack[3] = nil
				end
				Temp[3] = 9
Temp[6] = 6
Stack[Temp[3]] = Stack[Temp[6]]
				else
					Stack[6] = nil
				end
				else
					Stack[4] = nil
				end
			end
		end
					end
				elseif (pointer * pointer * 4) + pointer == 203 then
					do
						do
			if pointer - 5 == 2 then
						Stack[8] = Stack[0]
	if Stack[8] then
		Stack[7] = Stack[0][Constants[4]]
	end
	
				end
		end
					end
				elseif (pointer * pointer * 5) + pointer == 186 then
					do
						if (pointer + 79) > pointer then
			do
				if pointer * 2 + 2 == 14 then
					if pointer - 14 == -8 then
					if pointer + 8 ~= 32 then
					    Stack[3] = Stack[3] - Stack[5]
    pointer = pointer + 31
    
				end
				elseif pointer - 14 == -4 then
					Stack[2] = Env[7]
				end
				end
			end
		else
			Stack[2] = nil
		end
					end
				end
			else
				if (pointer * pointer * 3) + pointer == 374 then
					do
						if pointer + 10 == 21 then
				if Stack[1] == Constants[6] then pointer = pointer + 1 end
		end
					end
				elseif (pointer * pointer) + 12 == 93 then
					do
						do
			if pointer * 3 - 13 == 14 then
					if pointer + 12 == 32 then
					Stack[1] = nil
				end
				if pointer * 2 - 5 == 13 then
					Temp[8] = 10
Temp[14] = 6
Stack[Temp[8]] = Stack[Temp[14]]
				end
				else
					Stack[6] = nil
				end
		end
					end
				elseif (pointer * 2) + (pointer * 15) == 170 then
					do
						if pointer + 8 == 18 then
				Stack[7] = Stack[7](Stack[8], Stack[9], Stack[10])
		end
					end
				end
			end
		end
	else
		if (pointer * pointer) + (5 * pointer) <= 336 then
			if (pointer * 5) + pointer <= 78 then
				if (pointer * pointer) + (6 * pointer) == 216 then
					do
						do
			if pointer + 13 == 25 then
					if pointer + 4 ~= 30 then
					pointer = pointer + 4 
				end
				end
		end
					end
				elseif (pointer * 12) + (pointer * 10) == 286 then
					do
						if (pointer + 22) > pointer then
			do
				if pointer - 5 == 8 then
					if pointer + 10 == 25 then
					Stack[4] = nil
				end
					if Stack[7] == Constants[7] then pointer = pointer + 1 end
				elseif pointer - 5 == 21 then
					Stack[4] = Env[3]
				end
			end
		else
			Stack[2] = (1 == 1)
		end
					end
				end
			else
				if (pointer * pointer) + (8 * pointer) == 308 then
					do
						do
			if pointer + 14 ~= 42 then
					if pointer + 11 ~= 36 then
					if pointer - 4 == 10 then
					pointer = pointer + 20 
				elseif pointer - 4 == 30 then
					Stack[7] = Env[6]
				end
				end
				end
		end
					end
				elseif (pointer * pointer) + (7 * pointer) == 368 then
					do
						do
			if pointer + 4 ~= 25 then
					if pointer + 7 ~= 35 then
					pointer = pointer + 18 
				end
				end
		end
					end
				elseif (pointer * pointer * 4) + pointer == 915 then
					do
						if (pointer + 44) > pointer then
			do
				if pointer + 15 == 46 then
					Stack[3] = nil
				end
				if pointer * 2 - 4 == 26 then
					Temp[16] = 1
Temp[13] = Constants
Temp[11] = 10
Stack[Temp[16]] = Temp[13][Temp[11]]
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
					end
				end
			end
		else
			if (pointer * pointer) + (9 * pointer) <= 532 then
				if (pointer * pointer * 3) + pointer == 884 then
					do
						do
			if pointer * 2 - 8 == 26 then
					if pointer * 3 - 13 == 38 then
					if pointer + 12 ~= 33 then
						if Stack[1] == Constants[10] then pointer = pointer + 1 end
				end
				else
					Stack[5] = nil
				end
				end
		end
					end
				elseif (pointer * 5) + (pointer * 12) == 306 then
					do
						do
			if pointer * 2 - 3 == 33 then
					if pointer - 9 == 9 then
					if pointer - 4 == 14 then
					pointer = pointer + 8 
				end
				end
				end
		end
					end
				elseif (pointer * pointer * 5) + pointer == 1824 then
					do
						do
			if pointer + 13 ~= 49 then
						if Stack[7] == Constants[1] then pointer = pointer + 1 end
				end
		end
					end
				end
			else
				if (pointer * pointer) + 24 == 424 then
					do
						if pointer + 4 == 24 then
			pointer = pointer + 2 
		end
					end
				elseif (pointer * 13) + (pointer * 45) == 1218 then
					do
						if pointer + 8 == 29 then
			Temp[5] = 1
Temp[7] = Constants
Temp[10] = 12
Stack[Temp[5]] = Temp[7][Temp[10]]
		end
					end
				elseif (pointer * pointer * 2) + pointer == 990 then
					do
						do
			if pointer * 2 + 7 == 51 then
					pointer = pointer + 12 
				end
		end
					end
				end
			end
		end
	end
else
	if pointer * pointer <= 1089 then
		if pointer * pointer <= 729 then
			if (pointer * 6) + pointer <= 168 then
				if (pointer * pointer * 2) + pointer == 1081 then
					do
						if (pointer - 42) > pointer then
			Stack[5] = (0 == 1)
		else
			do
				if pointer + 9 ~= 36 then
					if pointer - 8 == 15 then
						if Stack[7] ~= Constants[7] then pointer = pointer + 1 end
				elseif pointer - 8 == 27 then
					Stack[8] = Env[7]
				end
				end
			end
		end
					end
				elseif (pointer * pointer) + (9 * pointer) == 792 then
					do
						if pointer + 4 == 28 then
			pointer = pointer + 10 
		end
					end
				end
			else
				if (pointer * pointer * 4) + pointer == 2943 then
					do
						if pointer + 5 == 32 then
				if Stack[1] == Constants[12] then pointer = pointer + 1 end
		end
					end
				elseif (pointer * pointer) + (12 * pointer) == 988 then
					do
						do
			if pointer - 7 == 19 then
					if pointer - 4 == 22 then
					pointer = pointer + 8 
				end
				elseif pointer - 7 == 26 then
					Stack[6] = Env[1]
				end
		end
					end
				elseif (pointer * pointer * 4) + pointer == 2525 then
					do
						if pointer + 1 == 26 then
			Temp[4] = 1
Temp[14] = Constants
Temp[10] = 6
Stack[Temp[4]] = Temp[14][Temp[10]]
		end
					end
				end
			end
		else
			if (pointer * pointer) + (12 * pointer) <= 1260 then
				if (pointer * pointer) + (7 * pointer) == 980 then
					do
						if (pointer + 59) > pointer then
			do
				if pointer + 5 == 33 then
					pointer = pointer + 6 
				end
			end
		else
			Stack[7] = Stack[3] or Constants[2+1]
		end
					end
				elseif (pointer * 5) + (pointer * 38) == 1290 then
					do
						do
			if pointer + 7 ~= 44 then
					if pointer * 2 + 14 == 74 then
					if pointer + 3 ~= 50 then
					pointer = pointer + 3 
				end
				end
				end
		end
					end
				elseif (pointer * pointer * 2) + pointer == 1711 then
					do
						if (pointer - 61) > pointer then
			Temp[9] = 5
			Temp[11] = Constants
			Temp[17] = 12
			Stack[Temp[20]] = Temp[2][Temp[16]]
		else
			do
				if pointer + 15 ~= 55 then
						if Stack[7] == Constants[14] then pointer = pointer + 1 end
				end
			end
		end
					end
				end
			else
				if (pointer * pointer) + 50 == 1074 then
					do
						if pointer + 1 == 33 then
				if (not Stack[8]) then
		pointer = pointer + 1
	else
		Stack[1] = Stack[8]
	end
	
		end
					end
				elseif (pointer * pointer) + 44 == 1005 then
					do
						if (pointer - 14) > pointer then
			if pointer > 140 then Stack[1] = Stack[7] end
		else
			do
				if pointer + 9 == 52 then
					Stack[7] = nil
				end
				Temp[13] = 8
Temp[9] = Constants
Temp[2] = 11
Stack[Temp[13]] = Temp[9][Temp[2]]
			end
		end
					end
				elseif (pointer * pointer) + (11 * pointer) == 1452 then
					do
						if pointer + 2 == 35 then
			pointer = pointer + 1 
		end
					end
				end
			end
		end
	else
		if (pointer * 9) + pointer <= 380 then
			if (pointer * pointer) + (5 * pointer) <= 1400 then
				if (pointer * pointer * 3) + pointer == 3502 then
					do
						if (pointer - 83) > pointer then
			if pointer > 146 then Stack[8] = Stack[1] end
		else
			do
				if pointer - 5 == 29 then
					if pointer - 10 == 24 then
					if pointer - 1 == 33 then
					Temp[1] = 1
Temp[7] = Constants
Temp[14] = 6
Stack[Temp[1]] = Temp[7][Temp[14]]
				end
				elseif pointer - 10 == 39 then
					Stack[1] = Env[8]
				end
				end
			end
		end
					end
				elseif (pointer * pointer * 2) + pointer == 2485 then
					do
						do
			if pointer * 2 + 8 == 78 then
						Stack[8] = #Stack[2]
				end
		end
					end
				end
			else
				if (pointer * pointer) + 33 == 1329 then
					do
						if pointer + 13 == 49 then
				Stack[8] = Stack[8] + Constants[5]
		end
					end
				elseif (pointer * pointer) + (10 * pointer) == 1824 then
					do
						if pointer + 6 == 44 then
			    Stack[3] = Stack[3] + Stack[5]
    if (Stack[5] > 0 and Stack[3] <= Stack[4]) or (Stack[5] <= 0 and Stack[3] >= Stack[4]) then
        pointer = pointer + -32
        Stack[6] = Stack[3]
    end
    
		end
					end
				elseif (pointer * pointer) + (14 * pointer) == 1887 then
					do
						if pointer + 6 == 43 then
				Stack[2][Stack[8]] = Stack[1]
		end
					end
				end
			end
		else
			if (pointer * 6) + pointer <= 294 then
				if (pointer * pointer) + (5 * pointer) == 1974 then
					do
						do
			if pointer * 3 - 3 == 123 then
					if pointer * 3 - 4 == 122 then
					Temp[13] = 5
Temp[2] = 2
Stack[Temp[13]] = Stack[Temp[2]]
				else
					Stack[8] = nil
				end
				else
					Stack[2] = nil
				end
		end
					end
				elseif (pointer * pointer) + (12 * pointer) == 2080 then
					do
						if pointer + 4 == 44 then
			Temp[12] = 4
Temp[1] = 2
Temp[11] = Constants[Temp[1]]
Stack[Temp[12]] = vmEnv[Temp[11]] or Env[Temp[11]]
	Stack[4] = Stack[4][Constants[9]]
	
	pointer = pointer + 1
		end
					end
				elseif (pointer * pointer) + (2 * pointer) == 1599 then
					do
						if pointer + 8 == 47 then
			Temp[12] = 3
Temp[8] = 1
Stack[Temp[12]] = Stack[Temp[8]]
		end
					end
				end
			else
				if (pointer * 10) + (pointer * 7) == 765 then
					do
						if pointer + 7 == 52 then
			            Temp[1] = {}
            Temp[2] = 0
            for i = 3, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
        
		end
					end
				elseif (pointer * pointer) + (8 * pointer) == 2484 then
					do
						if pointer + 6 == 52 then
				return
		end
					end
				elseif (pointer * 3) + (pointer * 9) == 516 then
					do
						if pointer + 15 == 58 then
			Temp[1] = 6
Temp[14] = Constants
Temp[2] = 13
Stack[Temp[1]] = Temp[14][Temp[2]]
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
		end
					end
				end
			end
		end
	end
end
		pointer = pointer+1
		end
	end

		end
					end
				end
			end
		else
			if (pointer * pointer) + (5 * pointer) <= 176 then
				if (pointer * 14) + (pointer * 48) == 496 then
					do
						do
			if pointer * 3 - 3 == 21 then
					if pointer + 4 == 12 then
					Temp[14] = 5
Temp[6] = 3
Temp[15] = Constants[Temp[6]]
Stack[Temp[14]] = vmEnv[Temp[15]] or Env[Temp[15]]
				end
				else
					Stack[5] = nil
				end
		end
					end
				elseif (pointer * pointer) + 37 == 158 then
					do
						do
			if pointer - 15 == -4 then
					if pointer - 13 == -2 then
					Temp[10] = 8
Temp[5] = Constants
Temp[16] = 15
Stack[Temp[10]] = Temp[5][Temp[16]]
				elseif pointer - 13 == 4 then
					Stack[5] = Env[1]
				end
				elseif pointer - 15 == 14 then
					Stack[8] = Env[6]
				end
		end
					end
				elseif (pointer * 4) + (pointer * 50) == 540 then
					do
						if pointer + 13 == 23 then
			Temp[13] = 7
Temp[9] = Constants
Temp[11] = 18
Stack[Temp[13]] = Temp[9][Temp[11]]
		end
					end
				elseif (pointer * pointer) + 42 == 123 then
					do
						do
			if pointer + 6 == 24 then
					Stack[2] = nil
				end
				if pointer - 13 == -4 then
						Stack[6] = {}
				elseif pointer - 13 == 10 then
					Stack[2] = Env[5]
				end
		end
					end
				end
			else
				if (pointer * pointer * 2) + pointer == 300 then
					do
						if pointer + 3 == 15 then
			Temp[15] = 9
Temp[13] = Constants
Temp[10] = 5
Stack[Temp[15]] = Temp[13][Temp[10]]
		end
					end
				elseif (pointer * pointer) + 10 == 206 then
					do
						if pointer + 8 == 22 then
				Stack[5], Stack[6], Stack[7] = Stack[5](Stack[6])
		end
					end
				elseif (pointer * pointer) + (12 * pointer) == 325 then
					do
						do
			if pointer * 3 - 2 == 37 then
					if pointer - 13 == 0 then
						for i = 1, 3 do
		Stack[6][(1 - 1) * 50 + i] = Stack[6 + i]
	end
	
				elseif pointer - 13 == 16 then
					Stack[6] = Env[2]
				end
				else
					Stack[4] = nil
				end
		end
					end
				elseif (pointer * pointer) + (13 * pointer) == 420 then
					do
						do
			if pointer + 2 == 17 then
					if pointer - 2 == 13 then
					if pointer * 3 - 9 == 36 then
					pointer = pointer + 9 
				else
					Stack[6] = nil
				end
				end
				end
		end
					end
				end
			end
		end
	else
		if (pointer * 3) + pointer <= 92 then
			if pointer * pointer <= 361 then
				if (pointer * pointer) + (3 * pointer) == 378 then
					do
						if pointer + 2 == 20 then
			Temp[15] = 12
Temp[5] = 9
Stack[Temp[15]] = Stack[Temp[5]]
		end
					end
				elseif (pointer * 3) + (pointer * 25) == 532 then
					do
						if pointer + 13 == 32 then
			Temp[4] = 13
Temp[10] = Constants
Temp[5] = 19
Stack[Temp[4]] = Temp[10][Temp[5]]
		end
					end
				elseif (pointer * pointer) + 42 == 298 then
					do
						if (pointer - 39) > pointer then
			Stack[5] = -Stack[6]
		else
			do
				if pointer + 5 == 29 then
					Stack[7] = nil
				end
				if pointer - 4 == 12 then
					Temp[3] = 10
Temp[9] = 1
Temp[14] = Constants[Temp[9]]
Stack[Temp[3]] = vmEnv[Temp[14]] or Env[Temp[14]]
				end
			end
		end
					end
				elseif (pointer * 7) + (pointer * 31) == 646 then
					do
						if pointer + 5 == 22 then
			Temp[16] = 11
Temp[4] = Constants
Temp[5] = 13
Stack[Temp[16]] = Temp[4][Temp[5]]
		end
					end
				end
			else
				if (pointer * pointer) + (10 * pointer) == 759 then
					do
						do
			if pointer * 2 + 3 == 49 then
					if pointer * 2 + 1 == 47 then
						Temp[1] = ""
	for i = 11, 14 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[11] = Temp[1]
	
				end
				end
		end
					end
				elseif (pointer * pointer) + 5 == 489 then
					do
						if (pointer + 41) > pointer then
			do
				if pointer + 12 ~= 39 then
					if pointer + 13 == 41 then
					Stack[4] = nil
				end
					Stack[14] = Stack[14](Stack[15])
				end
			end
		else
			Stack[5] = -Stack[1]
		end
					end
				elseif (pointer * pointer) + 39 == 480 then
					do
						if pointer + 2 == 23 then
			Temp[6] = 15
Temp[3] = 9
Stack[Temp[6]] = Stack[Temp[3]]
		end
					end
				elseif (pointer * pointer) + (6 * pointer) == 520 then
					do
						if (pointer + 61) > pointer then
			do
				if pointer + 9 == 29 then
					if pointer * 2 - 4 == 36 then
					if pointer * 2 + 5 == 45 then
					Temp[5] = 14
Temp[16] = 0
Stack[Temp[5]] = Stack[Temp[16]]
				end
				end
				end
			end
		else
			Temp[18] = 3
			Temp[9] = Constants
			Temp[16] = 2
			Stack[Temp[13]] = Temp[15][Temp[2]]
		end
					end
				end
			end
		else
			if (pointer * 6) + pointer <= 189 then
				if (pointer * pointer * 4) + pointer == 2730 then
					do
						do
			if pointer - 4 == 22 then
					if pointer + 2 ~= 42 then
					pointer = pointer + -11 
				end
				end
		end
					end
				elseif (pointer * pointer) + 36 == 765 then
					do
						if (pointer + 52) > pointer then
			do
				if pointer + 10 == 37 then
					Temp[5] = 5
Temp[6] = 3
Temp[16] = Constants[Temp[6]]
Stack[Temp[5]] = vmEnv[Temp[16]] or Env[Temp[16]]
				end
			end
		else
			if pointer > 101 then Stack[1] = Stack[3] end
		end
					end
				elseif (pointer * pointer * 5) + pointer == 2904 then
					do
						do
			if pointer * 3 - 6 == 66 then
					if pointer * 3 - 10 == 62 then
						Stack[10](Stack[11])
				else
					Stack[3] = nil
				end
				else
					Stack[1] = nil
				end
		end
					end
				elseif (pointer * 4) + (pointer * 23) == 675 then
					do
						do
			if pointer * 2 + 12 == 62 then
					    local r1, r2 = Stack[5](Stack[6], Stack[7])
    Stack[8] = r1
        Stack[9] = r2
    if Stack[8] ~= nil then
        Stack[7] = Stack[8]
    else
        pointer = pointer + 1
    end
    
				end
		end
					end
				end
			else
				if (pointer * pointer) + (4 * pointer) == 896 then
					do
						do
			if pointer * 2 - 6 == 50 then
					if pointer + 14 ~= 53 then
						Stack[6] = {}
				end
				end
		end
					end
				elseif (pointer * 7) + (pointer * 36) == 1247 then
					do
						if pointer + 14 == 43 then
			Temp[10] = 7
Temp[4] = Constants
Temp[13] = 22
Stack[Temp[10]] = Temp[4][Temp[13]]
		end
					end
				elseif (pointer * 12) + (pointer * 45) == 1710 then
					do
						if (pointer + 78) > pointer then
			do
				if pointer * 2 - 8 == 52 then
					Temp[2] = 8
Temp[15] = Constants
Temp[6] = 7
Stack[Temp[2]] = Temp[15][Temp[6]]
				end
			end
		else
			Stack[5] = Stack[8] or Constants[2+1]
		end
					end
				elseif (pointer * pointer * 2) + pointer == 1953 then
					do
						do
			if pointer * 2 + 12 == 74 then
					Temp[6] = 9
Temp[14] = Constants
Temp[5] = 15
Stack[Temp[6]] = Temp[14][Temp[5]]
				end
		end
					end
				end
			end
		end
	end
else
	if (pointer * pointer) + (4 * pointer) <= 2397 then
		if pointer * pointer <= 1521 then
			if (pointer * 11) + pointer <= 420 then
				if (pointer * 12) + (pointer * 9) == 735 then
					do
						if (pointer + 40) > pointer then
			do
				if pointer - 7 == 28 then
					if pointer - 11 == 24 then
						Stack[5], Stack[6], Stack[7] = Stack[5](Stack[6])
				elseif pointer - 11 == 33 then
					Stack[4] = Env[5]
				end
				end
			end
		else
			Temp[2] = 1
			Temp[4] = Constants
			Temp[15] = 15
			Stack[Temp[8]] = Temp[6][Temp[7]]
		end
					end
				elseif (pointer * pointer) + 28 == 1117 then
					do
						if pointer + 1 == 34 then
			Temp[5] = 11
Temp[7] = Constants
Temp[15] = 6
Stack[Temp[5]] = Temp[7][Temp[15]]
		end
					end
				elseif (pointer * pointer) + 25 == 1049 then
					do
						if (pointer - 64) > pointer then
			Stack[2] = nil
		else
			do
				if pointer - 10 == 22 then
					if pointer + 3 == 46 then
					Stack[3] = nil
				end
				Temp[3] = 10
Temp[7] = Constants
Temp[11] = 21
Stack[Temp[3]] = Temp[7][Temp[11]]
				elseif pointer - 10 == 40 then
					Stack[7] = Env[8]
				end
			end
		end
					end
				elseif (pointer * 15) + (pointer * 22) == 1258 then
					do
						if (pointer + 82) > pointer then
			do
				if pointer + 5 == 54 then
					Stack[8] = nil
				end
				if pointer + 9 == 43 then
					if pointer + 11 ~= 56 then
						for i = 1, 5 do
		Stack[6][(1 - 1) * 50 + i] = Stack[6 + i]
	end
	
				end
				end
			end
		else
			Stack[1] = (0 == 1)
		end
					end
				end
			else
				if (pointer * 3) + (pointer * 48) == 1989 then
					do
						do
			if pointer * 3 - 9 == 108 then
					if pointer - 2 == 37 then
					Temp[7] = 12
Temp[4] = Constants
Temp[11] = 2
Stack[Temp[7]] = Temp[4][Temp[11]]
				elseif pointer - 2 == 48 then
					Stack[3] = Env[5]
				end
				else
					Stack[1] = nil
				end
		end
					end
				elseif (pointer * 3) + (pointer * 24) == 1026 then
					do
						if pointer + 12 == 50 then
			Temp[14] = 11
Temp[15] = 9
Stack[Temp[14]] = Stack[Temp[15]]
		end
					end
				elseif (pointer * pointer * 5) + pointer == 6516 then
					do
						if (pointer + 88) > pointer then
			do
				if pointer * 2 - 8 == 64 then
					if pointer + 4 == 59 then
					Stack[1] = nil
				end
				if pointer * 3 - 5 == 103 then
					pointer = pointer + 8 
				else
					Stack[3] = nil
				end
				end
			end
		else
			Stack[2] = (0 == 1)
		end
					end
				elseif (pointer * pointer) + (10 * pointer) == 1739 then
					do
						if pointer + 1 == 38 then
			Temp[9] = 10
Temp[12] = 1
Temp[14] = Constants[Temp[12]]
Stack[Temp[9]] = vmEnv[Temp[14]] or Env[Temp[14]]
		end
					end
				end
			end
		else
			if (pointer * 5) + pointer <= 258 then
				if (pointer * pointer) + (8 * pointer) == 1920 then
					do
						if pointer + 9 == 49 then
			Temp[7] = 13
Temp[10] = 1
Stack[Temp[7]] = Stack[Temp[10]]
		end
					end
				elseif (pointer * 13) + (pointer * 37) == 2050 then
					do
						if (pointer + 98) > pointer then
			do
				if pointer * 2 - 2 == 80 then
					Temp[14] = 14
Temp[12] = 9
Stack[Temp[14]] = Stack[Temp[12]]
				end
			end
		else
			Stack[2] = Stack[7] or Constants[4+1]
		end
					end
				elseif (pointer * pointer) + (2 * pointer) == 1848 then
					do
						do
			if pointer + 5 == 48 then
					Stack[3] = nil
				end
					Stack[13] = Stack[13](Stack[14])
		end
					end
				elseif (pointer * pointer) + (9 * pointer) == 2236 then
					do
						if pointer + 14 == 57 then
				Temp[1] = ""
	for i = 11, 13 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[11] = Temp[1]
	
		end
					end
				end
			else
				if (pointer * pointer) + 15 == 2040 then
					do
						if pointer + 15 == 60 then
			    local r1, r2 = Stack[5](Stack[6], Stack[7])
    Stack[8] = r1
        Stack[9] = r2
    if Stack[8] ~= nil then
        Stack[7] = Stack[8]
    else
        pointer = pointer + 1
    end
    
		end
					end
				elseif (pointer * pointer) + (2 * pointer) == 2303 then
					do
						if pointer + 8 == 55 then
			Temp[15] = 5
Temp[13] = 1
Temp[6] = Constants[Temp[13]]
Stack[Temp[15]] = vmEnv[Temp[6]] or Env[Temp[6]]
		end
					end
				elseif (pointer * 13) + (pointer * 25) == 1672 then
					do
						if (pointer - 95) > pointer then
						Temp[2] = vmEnv
			Temp[1] = 4
			Temp[12] = Constants[Temp[14]]
			Temp[8] = 19
			Temp[15][Temp[6]] = Temp[6]
		else
			do
				if pointer + 12 == 56 then
						Stack[10](Stack[11])
				end
			end
		end
					end
				elseif (pointer * pointer * 5) + pointer == 10626 then
					do
						do
			if pointer + 14 == 60 then
					pointer = pointer + -10 
				end
		end
					end
				end
			end
		end
	else
		if pointer * pointer <= 3364 then
			if pointer * pointer <= 2704 then
				if (pointer * pointer * 2) + pointer == 4656 then
					do
						if (pointer + 65) > pointer then
			do
				if pointer - 11 == 37 then
					if pointer * 2 + 3 == 99 then
					if pointer * 3 - 8 == 136 then
					Temp[2] = 6
Temp[9] = 2
Stack[Temp[2]] = Stack[Temp[9]]
				else
					Stack[7] = nil
				end
				end
				elseif pointer - 11 == 39 then
					Stack[2] = Env[4]
				end
			end
		else
			Stack[1] = Stack[7] or Constants[7+1]
		end
					end
				elseif (pointer * pointer) + (7 * pointer) == 2744 then
					do
						if pointer + 15 == 64 then
			Temp[7] = 7
Temp[16] = Constants
Temp[15] = 14
Stack[Temp[7]] = Temp[16][Temp[15]]
	Stack[6] = Stack[6](Stack[7])
	pointer = pointer + 1
		end
					end
				elseif (pointer * pointer) + 50 == 2651 then
					do
						if (pointer + 8) > pointer then
			do
				if pointer * 2 + 6 == 108 then
					if pointer - 1 == 50 then
					if pointer * 3 - 8 == 145 then
					Temp[13] = 7
Temp[3] = 2
Stack[Temp[13]] = Stack[Temp[3]]
				else
					Stack[7] = nil
				end
				elseif pointer - 1 == 62 then
					Stack[1] = Env[4]
				end
				end
			end
		else
			Stack[8] = -Stack[3]
		end
					end
				elseif (pointer * 9) + (pointer * 21) == 1560 then
					do
						if (pointer + 91) > pointer then
			do
				if pointer * 3 - 10 == 146 then
					Temp[16] = 8
Temp[4] = Constants
Temp[10] = 9
Stack[Temp[16]] = Temp[4][Temp[10]]
	Stack[7] = Stack[7](Stack[8])
	pointer = pointer + 1
				else
					Stack[6] = nil
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
					end
				end
			else
				if (pointer * 15) + (pointer * 12) == 1539 then
					do
						if pointer + 12 == 69 then
				Temp[1] = {}
	for i = 5 + 1, top do
		Temp[1][i - 5] = Stack[i]
	end
	Temp[2] = {Stack[5](unpack(Temp[1], 1, top - 5))}
		for i = 1, 0 do
		Stack[5 + i - 1] = Temp[2][i]
	end
	
	
		end
					end
				elseif (pointer * pointer) + (10 * pointer) == 3456 then
					do
						if pointer + 10 == 64 then
			Temp[10] = 8
Temp[8] = 3
Stack[Temp[10]] = Stack[Temp[8]]
		end
					end
				elseif (pointer * 8) + (pointer * 18) == 1430 then
					do
						do
			if pointer + 14 == 69 then
					if pointer - 6 == 49 then
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
				end
				end
		end
					end
				elseif (pointer * 6) + (pointer * 44) == 2900 then
					do
						if pointer + 15 == 73 then
			Temp[5] = 5
Temp[14] = 1
Temp[11] = Constants[Temp[14]]
Stack[Temp[5]] = vmEnv[Temp[11]] or Env[Temp[11]]
		end
					end
				end
			end
		else
			if (pointer * 3) + pointer <= 252 then
				if (pointer * pointer) + 40 == 3884 then
					do
						if pointer + 13 == 75 then
				Temp[1] = {}
	for i = 5 + 1, top do
		Temp[1][i - 5] = Stack[i]
	end
	Temp[2] = {Stack[5](unpack(Temp[1], 1, top - 5))}
		for i = 1, 0 do
		Stack[5 + i - 1] = Temp[2][i]
	end
	
	
		end
					end
				elseif (pointer * pointer * 3) + pointer == 11970 then
					do
						do
			if pointer - 7 == 56 then
					Temp[7] = 5
Temp[4] = 1
Temp[6] = Constants[Temp[4]]
Stack[Temp[7]] = vmEnv[Temp[6]] or Env[Temp[6]]
				elseif pointer - 7 == 70 then
					Stack[8] = Env[5]
				end
		end
					end
				elseif (pointer * 4) + (pointer * 25) == 1740 then
					do
						do
			if pointer * 3 - 6 == 174 then
					if pointer - 3 == 57 then
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
				elseif pointer - 3 == 63 then
					Stack[2] = Env[2]
				end
				else
					Stack[3] = nil
				end
		end
					end
				elseif (pointer * pointer) + (11 * pointer) == 4130 then
					do
						if (pointer + 7) > pointer then
			do
				if pointer - 9 == 50 then
					if pointer - 3 == 56 then
					Temp[12] = 6
Temp[5] = 4
Stack[Temp[12]] = Stack[Temp[5]]
				end
				elseif pointer - 9 == 53 then
					Stack[8] = Env[3]
				end
			end
		else
			Temp[16] = 2
			Temp[3] = Constants
			Temp[7] = 16
			Stack[Temp[20]] = Temp[4][Temp[17]]
		end
					end
				end
			else
				if (pointer * 7) + (pointer * 48) == 3685 then
					do
						if pointer + 10 == 77 then
				Temp[1] = {}
	for i = 5 + 1, top do
		Temp[1][i - 5] = Stack[i]
	end
	Temp[2] = {Stack[5](unpack(Temp[1], 1, top - 5))}
		for i = 1, 0 do
		Stack[5 + i - 1] = Temp[2][i]
	end
	
	
		end
					end
				elseif (pointer * pointer * 2) + pointer == 8256 then
					do
						do
			if pointer * 2 + 5 == 133 then
					Temp[5] = 6
Temp[1] = 4
Stack[Temp[5]] = Stack[Temp[1]]
				end
		end
					end
				elseif (pointer * 12) + (pointer * 39) == 3315 then
					do
						do
			if pointer * 2 + 8 == 138 then
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
				end
		end
					end
				elseif (pointer * pointer * 3) + pointer == 13940 then
					do
						if (pointer - 17) > pointer then
			Stack[6] = Stack[4] or Constants[8+1]
		else
			do
				if pointer - 12 == 56 then
					if pointer * 2 - 2 == 134 then
					if pointer * 3 - 9 == 195 then
						return
				else
					Stack[4] = nil
				end
				end
				end
			end
		end
					end
				end
			end
		end
	end
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