return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\026\051", "2839")),(decrypt("\028\051", "2843")),(decrypt("\118\010\096\114\011\121\096\009\011\117\117\120\096\121\125\014\122\125", "636")),(decrypt("\040", "2337")),(decrypt("\021\063", "2464")),(decrypt("\025\057", "2280")),(decrypt("\089\087\104\089\089\090", "900")),(decrypt("\014\012\013\008", "1053")),(decrypt("\029\062", "1598")),(decrypt("\088\108\080\107\104\091", "2037")),(decrypt("\007\009\001\003", "859")),(decrypt("\124\106\087\091\015\084\094\010\109\082\084\107", "2270")),(decrypt("\016\021\060", "827")),(decrypt("\026\029\061", "2461")),(decrypt("\114\008\097\117\119\114\119\112\114\116\009\099\120\122\015\124\121", "2175")),(decrypt("\011\082\089\086\104\081\092\108", "1192")),(decrypt("\016\051", "981")),(decrypt("\114\008\100\115\010\126\100\013\015\114\116\121\100\013\119\012", "2127")),(decrypt("\084\089\082\086\091", "302")),(decrypt("\100\113\013\005\126\125\014\000\121\011\015", "2748")),(decrypt("\022\026\063", "2045")),(decrypt("\082\095\091\097\090", "990")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
				if (pointer * pointer) + (9 * pointer) <= 1102 then
	if pointer * pointer <= 196 then
		if (pointer * 11) + pointer <= 84 then
			if (pointer * 9) + pointer <= 30 then
				if (pointer * 7) + (pointer * 8) == 45 then
					do
						do
			if pointer * 2 - 9 == -3 then
					if pointer * 2 - 2 == 4 then
					if pointer + 9 == 12 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\118\103\070\095\081\098\092\127\109\081\091\085\107\100", "1865")),(decrypt("\118\106\080\106\086\080\111", "165")),(decrypt("\117\091\110\092\111\094\095\083\120\083\110\082\105", "2867")),}

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
		if (pointer * 14) + (pointer * 12) == 26 then
	do
		if (pointer - 47) > pointer then
						Temp[19] = vmEnv
			Temp[19] = 6
			Temp[5] = Constants[Temp[9]]
			Temp[13] = 15
			Temp[8][Temp[1]] = Temp[17]
		else
			do
				if pointer * 2 - 6 == -4 then
					if pointer - 6 == -5 then
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
				end
		end
					end
				elseif (pointer * pointer * 4) + pointer == 18 then
					do
						do
			if pointer + 5 == 8 then
					Stack[3] = nil
				end
				Temp[2] = vmEnv
Temp[15] = 20
Temp[5] = Constants[Temp[15]]
Temp[16] = 0
Temp[2][Temp[5]] = Temp[5]
		end
					end
				elseif (pointer * 4) + (pointer * 33) == 37 then
					do
						do
			if pointer * 3 - 3 == 0 then
					if pointer + 4 == 5 then
					Temp[1] = 0
Temp[11] = ttostring ~= __metatable
Stack[Temp[1]] = Temp[6]
				end
				else
					Stack[5] = nil
				end
		end
					end
				end
			else
				if (pointer * pointer) + (10 * pointer) == 96 then
					do
						do
			if pointer + 14 == 20 then
					if pointer - 6 == 0 then
					Temp[9] = vmEnv
Temp[11] = 18
Temp[10] = Constants[Temp[11]]
Temp[5] = 0
Temp[9][Temp[10]] = Temp[10]
				end
				end
		end
					end
				elseif (pointer * pointer * 3) + pointer == 52 then
					do
						if (pointer + 88) > pointer then
			do
				if pointer * 2 - 8 == 0 then
					if pointer + 4 == 27 then
					Stack[1] = nil
				end
				if pointer * 3 - 5 == 7 then
					Temp[14] = vmEnv
Temp[6] = 3
Temp[15] = Constants[Temp[6]]
Temp[13] = 0
Temp[14][Temp[15]] = Temp[15]
				else
					Stack[3] = nil
				end
				end
			end
		else
			Stack[2] = (0 == 1)
		end
					end
				elseif (pointer * 5) + (pointer * 25) == 210 then
					do
						if (pointer + 61) > pointer then
			do
				if pointer + 9 == 16 then
					if pointer * 2 - 4 == 10 then
					if pointer * 2 + 5 == 19 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\110\083\094\087\091\009\019\022\106\088\095\106\087\081\110\021\107\094\081\022\105\095\085\022\095\100\108\111\087\094\087\090\023\016\031\025\024\019\025\030\028\018\027\022\109\127\029\031\116\123\094\126\109\126\126\014\081\126\120\028\022\001\010\030\121\096\113\124\121\081\091\094\095\117\084\009\008\097\013\108\117\115\029\121\094\122\083", "1850")),(decrypt("\117\087\096\070\110\093\113\106\086\082\085\086\087\106", "2486")),(decrypt("\117\095\095\081\081\111", "2366")),(decrypt("\126", "1519")),(decrypt("\007\109\093\103\105\108", "857")),(decrypt("\014\107\108\089\105\034\081\081\110\105\032\105\080\111\108\086\107\110", "575")),}

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
		if (pointer * 15) + (pointer * 25) == 40 then
	do
		if pointer + 7 == 8 then
				return
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
			Temp[18] = 3
			Temp[9] = Constants
			Temp[16] = 2
			Stack[Temp[13]] = Temp[15][Temp[2]]
		end
					end
				elseif (pointer * pointer) + (10 * pointer) == 75 then
					do
						if pointer + 8 == 13 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\013\090\105\108\081\082\082\083\080\095\036\106\084\088", "435")),(decrypt("\015\100\109\111", "485")),(decrypt("\010\105\104\111\088\089\037\104\110\086\082\111\105", "2323")),(decrypt("\112\094\084\086\081\087\110", "1201")),(decrypt("\118\083\110\083\108\086\095\092\123\091\110\093\106", "1068")),}

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
		if (pointer * pointer) + (2 * pointer) == 3 then
	do
		if pointer + 1 == 2 then
				return
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
			if pointer * pointer <= 100 then
				if (pointer * pointer) + 11 == 92 then
					do
						do
			if pointer * 2 + 3 == 21 then
					if pointer * 2 + 1 == 19 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\114\008\101\114\116\112\114\116\115\119\015\101\120\122\011\123\122", "213")),((decrypt("\025\020\026\019\024", "1149"))),(decrypt("\120\090\082\082\086\084\087\104", "2426")),(decrypt("\123\088\085\083\082\081\110", "2406")),(decrypt("\015\101\095\013\109\083\110\106\084\098\108\083\090\083", "1946")),((decrypt("\025\029\022", "1492"))),}

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
		if (pointer * pointer) + (15 * pointer) <= 54 then
	if (pointer * 6) + (pointer * 31) == 37 then
		do
			if pointer + 10 == 11 then
			Temp[12] = 2
Temp[11] = 1
Temp[15] = Constants[Temp[11]]
Stack[Temp[12]] = vmEnv[Temp[15]] or Env[Temp[15]]
		end
		end
	elseif (pointer * pointer) + (14 * pointer) == 51 then
		do
			do
			if pointer * 3 - 15 == -6 then
						Stack[2](Stack[3])
				else
					Stack[8] = nil
				end
		end
		end
	elseif (pointer * pointer * 4) + pointer == 18 then
		do
			if (pointer - 60) > pointer then
			if pointer > 139 then Stack[4] = Stack[6] end
		else
			do
				if pointer + 2 == 4 then
					if pointer - 11 == -9 then
					Temp[6] = 3
Temp[8] = ttostring ~= __metatable
Stack[Temp[6]] = Temp[11]
				end
				end
			end
		end
		end
	end
else
	if (pointer * 10) + (pointer * 14) == 96 then
		do
			if pointer + 5 == 9 then
				Stack[2] = Stack[0] + Stack[1]
		end
		end
	elseif (pointer * pointer) + 38 == 63 then
		do
			if pointer + 11 == 16 then
				return Stack[2]
		end
		end
	elseif (pointer * pointer) + (9 * pointer) == 90 then
		do
			if pointer + 1 == 7 then
				return
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
				elseif (pointer * pointer) + (13 * pointer) == 168 then
					do
						if pointer + 12 == 20 then
			Temp[16] = vmEnv
Temp[15] = 15
Temp[13] = Constants[Temp[15]]
Temp[10] = 0
Temp[16][Temp[13]] = Temp[13]
		end
					end
				elseif (pointer * pointer) + 23 == 123 then
					do
						if pointer + 2 == 12 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {(decrypt("\111\108\087\094\110", "2444")),(decrypt("\093\084\082\082\088\086\097\081\090\031\101\087\080\092\021\098\096\090\097", "981")),(decrypt("\116\083\105\095\106\095\085\080\087\035\104\110\082\087\105\109", "2456")),(decrypt("\115\001\097\115\125\116\115\125\119\118\006\097\121\115\015\122\115", "387")),(decrypt("\011\086\093\080\082\108\082\107", "1097")),(decrypt("\009\084\094\102\087\081\085\072\105\083\085\095\084", "1859")),(decrypt("\015\005\123", "1905")),}

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
		if (pointer * pointer) + (15 * pointer) <= 54 then
	if (pointer * pointer) + (7 * pointer) == 18 then
		do
			if pointer + 4 == 6 then
			Temp[5] = 3
Temp[1] = ttostring ~= __metatable
Stack[Temp[5]] = Temp[15]
		end
		end
	elseif (pointer * pointer) + (11 * pointer) == 12 then
		do
			if pointer + 14 == 15 then
			Temp[1] = 2
Temp[9] = 4
Temp[4] = Constants[Temp[9]]
Stack[Temp[1]] = vmEnv[Temp[4]] or Env[Temp[4]]
		end
		end
	elseif (pointer * pointer) + (5 * pointer) == 24 then
		do
			do
			if pointer + 14 == 17 then
						Stack[2](Stack[3])
				end
		end
		end
	end
else
	if (pointer * 3) + (pointer * 36) == 273 then
		do
			if (pointer - 23) > pointer then
			Stack[2] = (0 == 1)
		else
			do
				if pointer * 3 - 6 == 15 then
						return
				else
					Stack[2] = nil
				end
			end
		end
		end
	elseif (pointer * pointer) + 46 == 82 then
		do
			do
			if pointer * 2 + 10 == 22 then
					if pointer * 2 - 2 == 10 then
						return Stack[2], Stack[3]
				end
				end
		end
		end
	elseif (pointer * 9) + (pointer * 33) == 210 then
		do
			if pointer + 14 == 19 then
				Stack[3] = Stack[0] / Stack[1]
		end
		end
	elseif (pointer * pointer) + (12 * pointer) == 64 then
		do
			do
			if pointer - 4 == 0 then
					if pointer * 2 - 9 == -1 then
						Stack[2] = Stack[0] * Stack[1]
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
			else
				if (pointer * pointer) + 17 == 186 then
					do
						if pointer + 9 == 22 then
			Temp[16] = 4
Temp[4] = Constants
Temp[5] = 1
Stack[Temp[16]] = Temp[4][Temp[5]]
		end
					end
				elseif (pointer * 6) + (pointer * 20) == 364 then
					do
						if (pointer + 8) > pointer then
			do
				if pointer * 2 + 6 == 34 then
					if pointer - 1 == 13 then
					if pointer * 3 - 8 == 34 then
					Temp[15] = 5
Temp[5] = Constants
Temp[4] = 13
Stack[Temp[15]] = Temp[5][Temp[4]]
				else
					Stack[7] = nil
				end
				elseif pointer - 1 == 25 then
					Stack[1] = Env[4]
				end
				end
			end
		else
			Stack[8] = -Stack[3]
		end
					end
				elseif (pointer * pointer) + (2 * pointer) == 143 then
					do
						do
			if pointer + 14 == 25 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[6] then
		C1 = {}
		local encoded = {(decrypt("\113\014\100\125\009\120\100\003\012\116\116\119\103\011\119\002", "1729")),(decrypt("\084\089\086", "1958")),(decrypt("\087\104\106", "1317")),(decrypt("\114\086\095\104\081\083\105\039\088\088\106\091\110", "2320")),(decrypt("\021\056", "2396")),(decrypt("\114\014\097\117\010\120\097\011\015\116\113\127\100\125\124\009\123\124", "2771")),(decrypt("\064\100\080\080", "1896")),(decrypt("\027\060", "2715")),(decrypt("\084\100\106\097\090\088\089\101", "1849")),(decrypt("\109\093\107\080", "1075")),}

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
		if (pointer * 5) + pointer <= 60 then
	if (pointer * pointer) + (15 * pointer) <= 100 then
		if (pointer * 7) + pointer <= 16 then
			if (pointer * pointer) + (7 * pointer) == 8 then
				do
					if (pointer - 88) > pointer then
			if pointer > 170 then Stack[6] = Stack[6] end
		else
			do
				if pointer - 5 == -4 then
					if pointer + 4 ~= 10 then
					if pointer * 2 + 12 == 14 then
					Temp[4] = 1
Temp[8] = 6
Temp[13] = Constants[Temp[8]]
Stack[Temp[4]] = vmEnv[Temp[13]] or Env[Temp[13]]
				end
				end
				end
			end
		end
				end
			elseif (pointer * pointer) + 35 == 39 then
				do
					if (pointer + 7) > pointer then
			do
				if pointer * 2 + 8 == 12 then
					if pointer * 3 - 12 == -6 then
					if pointer + 5 ~= 27 then
						Stack[1]()
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
		else
			if (pointer * pointer) + 14 == 30 then
				do
					do
			if pointer - 8 == -4 then
						if Stack[0] < Constants[5] then pointer = pointer + 1 end
				elseif pointer - 8 == 16 then
					Stack[2] = Env[7]
				end
		end
				end
			elseif (pointer * pointer) + 50 == 59 then
				do
					if (pointer - 61) > pointer then
			Stack[4] = -Stack[1]
		else
			do
				if pointer * 2 - 9 == -3 then
					if pointer + 4 == 7 then
					if pointer - 5 == -2 then
						Stack[1], Stack[2] = nil
				end
				end
				end
			end
		end
				end
			elseif (pointer * pointer) + (10 * pointer) == 75 then
				do
					if (pointer + 75) > pointer then
			do
				if pointer + 6 == 11 then
					pointer = pointer + 2 
				end
			end
		else
			Stack[5] = nil
		end
				end
			end
		end
	else
		if (pointer * pointer) + (13 * pointer) <= 140 then
			if (pointer * pointer) + (9 * pointer) == 90 then
				do
					if pointer + 3 == 9 then
			Temp[12] = 1
Temp[2] = Constants
Temp[8] = 9
Stack[Temp[12]] = Temp[2][Temp[8]]
		end
				end
			elseif (pointer * 12) + (pointer * 38) == 350 then
				do
					if pointer + 3 == 10 then
			pointer = pointer + 10 
		end
				end
			end
		else
			if (pointer * 3) + (pointer * 17) == 160 then
				do
					if pointer + 11 == 19 then
				if Stack[0] == Constants[5] then pointer = pointer + 1 end
		end
				end
			elseif (pointer * pointer * 4) + pointer == 333 then
				do
					if (pointer + 72) > pointer then
			do
				if pointer * 2 - 9 == 9 then
					if pointer * 2 + 1 == 19 then
					pointer = pointer + 2 
				end
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
				end
			elseif (pointer * 10) + (pointer * 13) == 230 then
				do
					do
			if pointer + 13 ~= 36 then
					Temp[8] = 1
Temp[1] = Constants
Temp[12] = 7
Stack[Temp[8]] = Temp[1][Temp[12]]
				end
		end
				end
			end
		end
	end
else
	if (pointer * pointer) + (14 * pointer) <= 435 then
		if (pointer * pointer) + (13 * pointer) <= 300 then
			if (pointer * 13) + (pointer * 37) == 600 then
				do
					if (pointer + 20) > pointer then
			do
				if pointer * 2 - 2 == 22 then
						Stack[2] = Stack[0] % Constants[8]
				end
			end
		else
			Stack[1] = nil
		end
				end
			elseif (pointer * 12) + (pointer * 37) == 539 then
				do
					if pointer + 3 == 14 then
			pointer = pointer + 6 
		end
				end
			end
		else
			if (pointer * pointer) + 24 == 220 then
				do
					if pointer + 5 == 19 then
			pointer = pointer + 2 
		end
				end
			elseif (pointer * pointer) + (13 * pointer) == 338 then
				do
					if (pointer - 19) > pointer then
			Stack[6] = (1 == 1)
		else
			do
				if pointer * 2 - 8 == 18 then
						if Stack[2] == Constants[5] then pointer = pointer + 1 end
				end
			end
		end
				end
			elseif (pointer * pointer) + 8 == 233 then
				do
					if (pointer - 44) > pointer then
			Stack[7] = -Stack[8]
		else
			do
				if pointer * 2 - 8 == 22 then
					if pointer * 2 + 7 == 37 then
					if pointer - 14 == 1 then
					Temp[9] = 1
Temp[4] = Constants
Temp[2] = 10
Stack[Temp[9]] = Temp[4][Temp[2]]
				end
				end
				end
			end
		end
				end
			end
		end
	else
		if pointer * pointer <= 324 then
			if (pointer * pointer) + 28 == 284 then
				do
					if pointer + 2 == 18 then
			pointer = pointer + 1 
		end
				end
			elseif (pointer * pointer) + 11 == 300 then
				do
					if (pointer - 95) > pointer then
			Stack[3] = nil
		else
			do
				if pointer + 11 == 34 then
					Stack[4] = nil
				end
				Temp[9] = 1
Temp[7] = Constants
Temp[12] = 3
Stack[Temp[9]] = Temp[7][Temp[12]]
			end
		end
				end
			elseif (pointer * pointer) + 49 == 373 then
				do
					if (pointer - 70) > pointer then
						Temp[2] = vmEnv
			Temp[18] = 5
			Temp[9] = Constants[Temp[11]]
			Temp[12] = 16
			Temp[18][Temp[10]] = Temp[8]
		else
			do
				if pointer + 12 == 30 then
					if pointer * 2 - 3 == 33 then
					Temp[4] = 2
Temp[10] = 1
Temp[2] = Constants[Temp[10]]
Stack[Temp[4]] = vmEnv[Temp[2]] or Env[Temp[2]]
				end
				end
			end
		end
				end
			end
		else
			if (pointer * 4) + (pointer * 49) == 1113 then
				do
					if pointer + 4 == 25 then
				return
		end
				end
			elseif (pointer * pointer) + 27 == 427 then
				do
					do
			if pointer - 15 == 5 then
						return Stack[1]
				elseif pointer - 15 == 15 then
					Stack[6] = Env[1]
				end
		end
				end
			elseif (pointer * pointer * 5) + pointer == 1824 then
				do
					if (pointer + 84) > pointer then
			do
				if pointer + 8 == 27 then
					if pointer * 2 + 2 == 40 then
					if pointer - 13 == 6 then
						Stack[2]()
				end
				end
				end
			end
		else
			Stack[6] = nil
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
				elseif (pointer * 6) + (pointer * 38) == 528 then
					do
						if pointer + 15 == 27 then
			Temp[3] = 3
Temp[9] = Constants
Temp[14] = 5
Stack[Temp[3]] = Temp[9][Temp[14]]
		end
					end
				end
			end
		end
	else
		if pointer * pointer <= 441 then
			if pointer * pointer <= 289 then
				if (pointer * 4) + (pointer * 50) == 864 then
					do
						do
			if pointer * 3 - 6 == 42 then
					if pointer - 3 == 13 then
					    Stack[4] = Stack[4] - Stack[6]
    pointer = pointer + 5
    
				elseif pointer - 3 == 19 then
					Stack[2] = Env[2]
				end
				else
					Stack[3] = nil
				end
		end
					end
				elseif (pointer * pointer) + 42 == 267 then
					do
						if pointer + 14 == 29 then
			Temp[10] = 6
Temp[5] = Constants
Temp[16] = 1
Stack[Temp[10]] = Temp[5][Temp[16]]
		end
					end
				elseif (pointer * pointer * 2) + pointer == 595 then
					do
						if (pointer + 19) > pointer then
			do
				if pointer * 2 + 4 == 38 then
					if pointer - 2 == 15 then
					if pointer - 11 == 6 then
					Temp[6] = 8
Temp[3] = 0
Stack[Temp[6]] = Stack[Temp[3]]
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
				end
			else
				if (pointer * pointer) + 10 == 371 then
					do
						if pointer + 14 == 33 then
			Temp[16] = 10
Temp[10] = 7
Stack[Temp[16]] = Stack[Temp[10]]
		end
					end
				elseif (pointer * pointer) + (12 * pointer) == 540 then
					do
						if (pointer + 45) > pointer then
			do
				if pointer * 2 - 2 == 34 then
					Temp[5] = 9
Temp[6] = 3
Stack[Temp[5]] = Stack[Temp[6]]
				end
			end
		else
			Temp[8] = 3
			Temp[16] = Constants
			Temp[20] = 20
			Stack[Temp[5]] = Temp[18][Temp[10]]
		end
					end
				elseif (pointer * pointer) + (13 * pointer) == 660 then
					do
						do
			if pointer + 8 == 28 then
					if pointer * 2 + 6 == 46 then
					if pointer - 10 == 10 then
						Stack[8] = Stack[8](Stack[9], Stack[10])
				elseif pointer - 10 == 29 then
					Stack[5] = Env[8]
				end
				end
				end
		end
					end
				elseif (pointer * 3) + (pointer * 26) == 609 then
					do
						if pointer + 1 == 22 then
			Temp[4] = 3
Temp[13] = 8
Stack[Temp[4]] = Stack[Temp[13]]
		end
					end
				end
			end
		else
			if (pointer * 15) + pointer <= 400 then
				if (pointer * pointer) + (13 * pointer) == 950 then
					do
						if (pointer - 17) > pointer then
			Stack[6] = Stack[4] or Constants[8+1]
		else
			do
				if pointer - 12 == 13 then
					if pointer * 2 - 2 == 48 then
					if pointer * 3 - 9 == 66 then
					Temp[3] = 6
Temp[7] = 3
Stack[Temp[3]] = Stack[Temp[7]]
				else
					Stack[4] = nil
				end
				end
				end
			end
		end
					end
				elseif (pointer * pointer * 5) + pointer == 2442 then
					do
						do
			if pointer * 3 - 2 == 64 then
					if pointer - 13 == 9 then
					    Stack[4] = Stack[4] + Stack[6]
    if (Stack[6] > 0 and Stack[4] <= Stack[5]) or (Stack[6] <= 0 and Stack[4] >= Stack[5]) then
        pointer = pointer + -6
        Stack[7] = Stack[4]
    end
    
				elseif pointer - 13 == 25 then
					Stack[6] = Env[2]
				end
				else
					Stack[4] = nil
				end
		end
					end
				elseif (pointer * 8) + (pointer * 22) == 720 then
					do
						do
			if pointer - 4 == 20 then
					if pointer + 2 ~= 40 then
					Temp[6] = 5
Temp[14] = Constants
Temp[5] = 22
Stack[Temp[6]] = Temp[14][Temp[5]]
				end
				end
		end
					end
				elseif (pointer * pointer) + 11 == 540 then
					do
						if pointer + 12 == 35 then
			Temp[2] = 4
Temp[15] = 19
Temp[6] = Constants[Temp[15]]
Stack[Temp[2]] = vmEnv[Temp[6]] or Env[Temp[6]]
		end
					end
				end
			else
				if (pointer * pointer) + (5 * pointer) == 806 then
					do
						if (pointer + 41) > pointer then
			do
				if pointer + 12 ~= 43 then
					if pointer + 13 == 45 then
					Stack[4] = nil
				end
					Stack[4](Stack[5], Stack[6])
				end
			end
		else
			Stack[5] = -Stack[1]
		end
					end
				elseif (pointer * 5) + (pointer * 14) == 551 then
					do
						if pointer + 1 == 30 then
			Temp[7] = 6
Temp[15] = Constants
Temp[9] = 21
Stack[Temp[7]] = Temp[15][Temp[9]]
		end
					end
				elseif (pointer * pointer) + (7 * pointer) == 918 then
					do
						do
			if pointer * 2 + 5 == 59 then
					Temp[7] = 4
Temp[11] = 7
Temp[5] = Constants[Temp[11]]
Stack[Temp[7]] = vmEnv[Temp[5]] or Env[Temp[5]]
				end
		end
					end
				elseif (pointer * 2) + (pointer * 19) == 588 then
					do
						if (pointer - 95) > pointer then
						Temp[2] = vmEnv
			Temp[1] = 4
			Temp[12] = Constants[Temp[14]]
			Temp[8] = 19
			Temp[15][Temp[6]] = Temp[6]
		else
			do
				if pointer + 12 == 40 then
						Stack[5] = {}
				end
			end
		end
					end
				end
			end
		end
	end
else
	if (pointer * pointer) + (6 * pointer) <= 2200 then
		if (pointer * pointer) + (11 * pointer) <= 1692 then
			if pointer * pointer <= 1024 then
				if (pointer * pointer) + 23 == 923 then
					do
						if (pointer + 74) > pointer then
			do
				if pointer * 3 - 7 == 83 then
					if pointer + 10 == 42 then
					Stack[5] = nil
				end
				Temp[12] = 7
Temp[14] = Constants
Temp[15] = 5
Stack[Temp[12]] = Temp[14][Temp[15]]
				else
					Stack[4] = nil
				end
			end
		else
			Stack[1] = Stack[1] or Constants[5+1]
		end
					end
				elseif (pointer * pointer * 2) + pointer == 2080 then
					do
						if (pointer - 64) > pointer then
			Stack[2] = nil
		else
			do
				if pointer - 10 == 22 then
					if pointer + 3 == 46 then
					Stack[3] = nil
				end
				Temp[7] = 9
Temp[10] = Constants
Temp[14] = 2
Stack[Temp[7]] = Temp[10][Temp[14]]
				elseif pointer - 10 == 40 then
					Stack[7] = Env[8]
				end
			end
		end
					end
				elseif (pointer * pointer * 5) + pointer == 4836 then
					do
						if pointer + 3 == 34 then
			Temp[7] = 8
Temp[4] = Constants
Temp[11] = 6
Stack[Temp[7]] = Temp[4][Temp[11]]
		end
					end
				end
			else
				if (pointer * 5) + (pointer * 23) == 980 then
					do
						if pointer + 15 == 50 then
			pointer = pointer + 6 
		end
					end
				elseif (pointer * pointer * 4) + pointer == 4658 then
					do
						if pointer + 13 == 47 then
				Stack[4], Stack[5], Stack[6] = Stack[4](Stack[5])
		end
					end
				elseif (pointer * pointer * 2) + pointer == 2211 then
					do
						if (pointer + 40) > pointer then
			do
				if pointer - 7 == 26 then
					if pointer - 11 == 22 then
						for i = 1, 4 do
		Stack[5][(1 - 1) * 50 + i] = Stack[5 + i]
	end
	
				elseif pointer - 11 == 31 then
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
				elseif (pointer * pointer) + 9 == 1305 then
					do
						if pointer + 2 == 38 then
			Temp[12] = 9
Temp[15] = 19
Temp[13] = Constants[Temp[15]]
Stack[Temp[12]] = vmEnv[Temp[13]] or Env[Temp[13]]
		end
					end
				end
			end
		else
			if pointer * pointer <= 1600 then
				if (pointer * pointer) + (10 * pointer) == 1911 then
					do
						if (pointer + 7) > pointer then
			do
				if pointer - 9 == 30 then
					if pointer - 3 == 36 then
					Temp[16] = 12
Temp[15] = 8
Stack[Temp[16]] = Stack[Temp[15]]
				end
				elseif pointer - 9 == 33 then
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
				elseif (pointer * 10) + (pointer * 48) == 2146 then
					do
						if (pointer - 39) > pointer then
			Stack[5] = -Stack[6]
		else
			do
				if pointer + 5 == 50 then
					Stack[7] = nil
				end
				if pointer - 4 == 33 then
					Temp[6] = 10
Temp[2] = 8
Stack[Temp[6]] = Stack[Temp[2]]
				end
			end
		end
					end
				elseif (pointer * pointer) + 40 == 1640 then
					do
						if pointer + 9 == 49 then
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
	
		end
					end
				elseif (pointer * pointer) + 48 == 1492 then
					do
						if pointer + 8 == 46 then
			Temp[9] = 11
Temp[7] = 2
Stack[Temp[9]] = Stack[Temp[7]]
		end
					end
				end
			else
				if (pointer * pointer * 4) + pointer == 7788 then
					do
						if (pointer + 82) > pointer then
			do
				if pointer + 5 == 64 then
					Stack[8] = nil
				end
				if pointer + 9 == 53 then
					if pointer + 11 ~= 66 then
					Temp[13] = 4
Temp[3] = 1
Stack[Temp[13]] = Stack[Temp[3]]
				end
				end
			end
		else
			Stack[1] = (0 == 1)
		end
					end
				elseif (pointer * 3) + (pointer * 24) == 1107 then
					do
						if pointer + 13 == 54 then
				Temp[1] = {}
	for i = 9 + 1, top do
		Temp[1][i - 9] = Stack[i]
	end
	Temp[2] = {Stack[9](unpack(Temp[1], 1, top - 9))}
		for i = 1, 0 do
		Stack[9 + i - 1] = Temp[2][i]
	end
	
	
		end
					end
				elseif (pointer * pointer * 5) + pointer == 8862 then
					do
						if pointer + 10 == 52 then
			    local r1, r2 = Stack[4](Stack[5], Stack[6])
    Stack[7] = r1
        Stack[8] = r2
    if Stack[7] ~= nil then
        Stack[6] = Stack[7]
    else
        pointer = pointer + 1
    end
    
		end
					end
				elseif (pointer * pointer) + (10 * pointer) == 2279 then
					do
						do
			if pointer - 7 == 36 then
					pointer = pointer + -8 
				elseif pointer - 7 == 50 then
					Stack[8] = Env[5]
				end
		end
					end
				end
			end
		end
	else
		if (pointer * 5) + pointer <= 312 then
			if pointer * pointer <= 2304 then
				if (pointer * pointer * 4) + pointer == 8510 then
					do
						if pointer + 15 == 61 then
			Temp[10] = 6
Temp[8] = Constants
Temp[1] = 9
Stack[Temp[10]] = Temp[8][Temp[1]]
	Stack[4], Stack[5] = Stack[4](Stack[5], Stack[6])
	pointer = pointer + 1
		end
					end
				elseif (pointer * 10) + (pointer * 8) == 810 then
					do
						do
			if pointer * 3 - 9 == 126 then
					if pointer - 2 == 43 then
					Temp[16] = 5
Temp[4] = Constants
Temp[10] = 14
Stack[Temp[16]] = Temp[4][Temp[10]]
				elseif pointer - 2 == 54 then
					Stack[3] = Env[5]
				end
				else
					Stack[1] = nil
				end
		end
					end
				elseif (pointer * pointer) + (2 * pointer) == 2400 then
					do
						if pointer + 9 == 57 then
			Temp[8] = 6
Temp[1] = 19
Temp[12] = Constants[Temp[1]]
Stack[Temp[8]] = vmEnv[Temp[12]] or Env[Temp[12]]
		end
					end
				end
			else
				if (pointer * pointer) + (2 * pointer) == 2703 then
					do
						if (pointer + 65) > pointer then
			do
				if pointer - 11 == 40 then
					if pointer * 2 + 3 == 105 then
					if pointer * 3 - 8 == 145 then
						Stack[6](Stack[7], Stack[8])
				else
					Stack[7] = nil
				end
				end
				elseif pointer - 11 == 42 then
					Stack[2] = Env[4]
				end
			end
		else
			Stack[1] = Stack[7] or Constants[7+1]
		end
					end
				elseif (pointer * 8) + (pointer * 6) == 728 then
					do
						do
			if pointer - 15 == 37 then
					if pointer - 13 == 39 then
					Temp[5] = 6
Temp[14] = 19
Temp[7] = Constants[Temp[14]]
Stack[Temp[5]] = vmEnv[Temp[7]] or Env[Temp[7]]
				elseif pointer - 13 == 45 then
					Stack[5] = Env[1]
				end
				elseif pointer - 15 == 55 then
					Stack[8] = Env[6]
				end
		end
					end
				elseif (pointer * pointer) + 41 == 2541 then
					do
						if pointer + 8 == 58 then
			Temp[11] = 8
Temp[12] = 5
Stack[Temp[11]] = Stack[Temp[12]]
		end
					end
				elseif (pointer * 10) + (pointer * 17) == 1323 then
					do
						if pointer + 8 == 57 then
			Temp[5] = 7
Temp[14] = 4
Stack[Temp[5]] = Stack[Temp[14]]
		end
					end
				end
			end
		else
			if pointer * pointer <= 3136 then
				if (pointer * pointer * 4) + pointer == 11289 then
					do
						do
			if pointer - 5 == 48 then
					Temp[11] = 7
Temp[7] = 10
Temp[4] = Constants[Temp[7]]
Stack[Temp[11]] = vmEnv[Temp[4]] or Env[Temp[4]]
				elseif pointer - 5 == 53 then
					Stack[7] = Env[4]
				end
		end
					end
				elseif (pointer * pointer * 2) + pointer == 6328 then
					do
						if pointer + 5 == 61 then
			Temp[10] = 10
Temp[3] = Constants
Temp[7] = 1
Stack[Temp[10]] = Temp[3][Temp[7]]
		end
					end
				elseif (pointer * pointer) + (7 * pointer) == 3410 then
					do
						if (pointer + 52) > pointer then
			do
				if pointer + 10 == 65 then
					Temp[12] = 9
Temp[7] = 1
Stack[Temp[12]] = Stack[Temp[7]]
				end
			end
		else
			if pointer > 101 then Stack[1] = Stack[3] end
		end
					end
				elseif (pointer * pointer) + 50 == 2966 then
					do
						if pointer + 2 == 56 then
			Temp[6] = 8
Temp[5] = Constants
Temp[1] = 4
Stack[Temp[6]] = Temp[5][Temp[1]]
		end
					end
				end
			else
				if (pointer * pointer) + (15 * pointer) == 4104 then
					do
						do
			if pointer * 2 + 12 == 126 then
					Temp[8] = 11
Temp[15] = Constants
Temp[3] = 17
Stack[Temp[8]] = Temp[15][Temp[3]]
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
				end
		end
					end
				elseif (pointer * 15) + (pointer * 12) == 1647 then
					do
						do
			if pointer + 2 == 63 then
					if pointer - 2 == 59 then
					if pointer * 3 - 9 == 174 then
						return
				else
					Stack[6] = nil
				end
				end
				end
		end
					end
				elseif (pointer * pointer) + (10 * pointer) == 4071 then
					do
						if pointer + 14 == 73 then
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
	
	
		end
					end
				elseif (pointer * 8) + (pointer * 18) == 1560 then
					do
						if (pointer + 78) > pointer then
			do
				if pointer * 2 - 8 == 112 then
						Temp[1] = {}
	for i = 6 + 1, top do
		Temp[1][i - 6] = Stack[i]
	end
	Temp[2] = {Stack[6](unpack(Temp[1], 1, top - 6))}
		for i = 1, 0 do
		Stack[6 + i - 1] = Temp[2][i]
	end
	
	
				end
			end
		else
			Stack[5] = Stack[8] or Constants[2+1]
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