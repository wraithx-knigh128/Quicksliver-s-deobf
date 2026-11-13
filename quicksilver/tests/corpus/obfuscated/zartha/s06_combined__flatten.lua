return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\088\100\088\093\110\083\107\082\106\097\080\101", "2839")),(decrypt("\024\051", "2843")),(decrypt("\096\101\086\083\104\106\089", "636")),(decrypt("\085\090\083\082\089", "2337")),(decrypt("\106\093\106\108", "2464")),(decrypt("\027\057", "2280")),(decrypt("\094\086\087", "900")),(decrypt("\014\012\013\008", "1053")),(decrypt("\104\086\095\097", "1598")),(decrypt("\021\059", "2037")),(decrypt("\007\009\001\003", "859")),(decrypt("\124\106\087\091\015\084\094\010\109\082\084\107", "2270")),(decrypt("\110\100\084\100\087", "827")),(decrypt("\025\063", "2461")),(decrypt("\105\109\093\111\091\081\110\105", "2175")),(decrypt("\011\082\089\086\104\081\092\108", "1192")),(decrypt("\114\094\038\096\100\018\046\094\088\046\093\087\082\047\090\095\047\104\101\027\038\082\103\105\082\047\081\083\047\090\102\100\038\081\084\109\083\083\081\095\093\000\046\083\087\046\097\109\046\086\081\083\100\038\089\082\038\082\094\038\096\100", "981")),(decrypt("\087\109\092", "2127")),(decrypt("\086\080\081\053", "302")),(decrypt("\100\113\013\005\126\125\014\000\121\011\015", "2748")),(decrypt("\088\080\069\105", "2045")),(decrypt("\094\085\090\102", "990")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
				if pointer * pointer <= 1764 then
	if pointer * pointer <= 441 then
		if pointer * pointer <= 100 then
			if pointer * pointer <= 16 then
				if (pointer * pointer * 3) + pointer == 30 then
					do
						if pointer + 13 == 16 then
				Stack[0] = {}
		end
					end
				elseif (pointer * pointer * 2) + pointer == 36 then
					do
						if (pointer - 95) > pointer then
						Temp[2] = vmEnv
			Temp[1] = 4
			Temp[12] = Constants[Temp[14]]
			Temp[8] = 19
			Temp[15][Temp[6]] = Temp[6]
		else
			do
				if pointer + 12 == 16 then
						Stack[0][Constants[3]] = Stack[0]
				end
			end
		end
					end
				elseif (pointer * pointer) + (12 * pointer) == 13 then
					do
						if pointer + 13 == 14 then
			Temp[1] = 0
Temp[11] = ttostring ~= __metatable
Stack[Temp[1]] = Temp[6]
		end
					end
				elseif (pointer * pointer) + 10 == 14 then
					do
						do
			if pointer + 11 == 13 then
					if pointer + 10 == 17 then
					Stack[7] = nil
				end
				if pointer - 10 == -8 then
					Temp[2] = vmEnv
Temp[15] = 20
Temp[5] = Constants[Temp[15]]
Temp[16] = 0
Temp[2][Temp[5]] = Temp[5]
				end
				end
		end
					end
				end
			else
				if (pointer * 12) + pointer <= 91 then
					if (pointer * pointer) + (13 * pointer) == 140 then
						do
							do
			if pointer - 7 == 0 then
						Stack[0][Constants[18]] = Stack[1]
				elseif pointer - 7 == 14 then
					Stack[8] = Env[5]
				end
		end
						end
					elseif (pointer * 3) + (pointer * 26) == 145 then
						do
							if (pointer + 61) > pointer then
			do
				if pointer + 9 == 14 then
					if pointer * 2 - 4 == 6 then
					if pointer * 2 + 5 == 15 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\009\109\111\094\111", "216")),(decrypt("\015\084\108\087\105\114\109\121\082\104\094", "2404")),(decrypt("\091\106\090\092\109\093\105\083\105\111\082\100", "1618")),(decrypt("\013\117\013\015", "2155")),(decrypt("\087\111\080\109", "2741")),(decrypt("\092\096\082\098", "1814")),(decrypt("\127\091\082\083\087\082\104", "677")),}

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
		if (pointer * pointer) + (4 * pointer) <= 21 then
	if (pointer * pointer * 4) + pointer == 39 then
		do
			if pointer + 13 == 16 then
				Stack[2][Constants[5]] = Stack[0]
		end
		end
	elseif (pointer * pointer * 4) + pointer == 5 then
		do
			do
			if pointer - 4 == -3 then
					if pointer + 8 == 9 then
					Temp[9] = 1
Temp[11] = 3
Temp[12] = Constants[Temp[11]]
Stack[Temp[9]] = vmEnv[Temp[12]] or Env[Temp[12]]
				end
				end
		end
		end
	elseif (pointer * pointer) + (11 * pointer) == 26 then
		do
			if pointer + 3 == 5 then
				Stack[2] = {}
		end
		end
	end
else
	if (pointer * 12) + (pointer * 13) == 125 then
		do
			if pointer + 6 == 11 then
				return Stack[1](Stack[2], Stack[3])
		end
		end
	elseif (pointer * pointer) + 15 == 51 then
		do
			do
			if pointer * 2 - 9 == 3 then
					if pointer + 15 ~= 40 then
					if pointer - 10 == -4 then
					            Temp[1] = {}
            Temp[2] = 0
            for i = 1, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
        
				end
				end
				end
		end
		end
	elseif (pointer * pointer) + (10 * pointer) == 56 then
		do
			if (pointer + 53) > pointer then
			do
				if pointer * 3 - 9 == 3 then
					if pointer - 14 == -10 then
						Stack[3] = Upvalues[0]
				end
				else
					Stack[8] = nil
				end
			end
		else
			Stack[1] = -Stack[5]
		end
		end
	elseif (pointer * pointer) + (4 * pointer) == 77 then
		do
			if pointer + 14 == 21 then
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
		else
			Temp[18] = 3
			Temp[9] = Constants
			Temp[16] = 2
			Stack[Temp[13]] = Temp[15][Temp[2]]
		end
						end
					end
				else
					if (pointer * pointer) + (6 * pointer) == 135 then
						do
							do
			if pointer + 6 == 24 then
					Stack[2] = nil
				end
				if pointer - 13 == -4 then
						Stack[0][Constants[15]] = Stack[1]
				elseif pointer - 13 == 10 then
					Stack[2] = Env[5]
				end
		end
						end
					elseif (pointer * pointer) + (13 * pointer) == 168 then
						do
							do
			if pointer + 5 == 14 then
					Stack[3] = nil
				end
					local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\088\093\080\085\087\104", "2695")),(decrypt("\088\109\090\097\091\094\105\082\081\111\004\031\023", "1459")),(decrypt("\122\105\084\100\086\083\094\083\123\105\094\085\081\111\107", "1578")),(decrypt("\108\094\080\080\105\083", "1894")),(decrypt("\012\086\087\106", "2041")),(decrypt("\124\109\082\093\110", "2226")),(decrypt("\046\029\024\104", "2815")),((decrypt("\016\022\030\019", "817"))),(decrypt("\036\090\080\088\107\039\107\093\108\107\035", "340")),(decrypt("\008\086\083\085\092\105\105\109", "566")),(decrypt("\084\106\081\104", "1254")),(decrypt("\105\090\104\105", "134")),}

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
		if pointer * pointer <= 36 then
	if (pointer * pointer) + (13 * pointer) <= 30 then
		if (pointer * pointer * 2) + pointer == 3 then
			do
				if pointer + 3 == 4 then
				Stack[1] = Stack[0][Constants[11]]
	
		end
			end
		elseif (pointer * pointer * 5) + pointer == 22 then
			do
				do
			if pointer + 1 == 3 then
					Temp[5] = 2
Temp[3] = Constants
Temp[12] = 9
Stack[Temp[5]] = Temp[3][Temp[12]]
				end
		end
			end
		end
	else
		if (pointer * pointer * 3) + pointer == 30 then
			do
				do
			if pointer * 3 - 12 == -3 then
					if pointer + 4 == 11 then
					Stack[1] = nil
				end
				Temp[13] = 3
Temp[7] = 1
Temp[10] = Constants[Temp[7]]
Stack[Temp[13]] = vmEnv[Temp[10]] or Env[Temp[10]]
	Stack[3] = Stack[3][Constants[4]]
	
	pointer = pointer + 1
				else
					Stack[6] = nil
				end
		end
			end
		elseif (pointer * pointer) + 10 == 46 then
			do
				do
			if pointer + 6 ~= 20 then
					if pointer * 3 - 12 == 6 then
						Stack[6] = Stack[0]
	if Stack[6] then
		Stack[5] = Stack[0][Constants[12]]
	end
	
				else
					Stack[7] = nil
				end
				end
		end
			end
		elseif (pointer * 11) + (pointer * 38) == 245 then
			do
				if (pointer + 73) > pointer then
			do
				if pointer - 3 == 2 then
					if pointer + 7 ~= 14 then
					Temp[9] = 4
Temp[11] = Constants
Temp[7] = 7
Stack[Temp[9]] = Temp[11][Temp[7]]
				end
				elseif pointer - 3 == 9 then
					Stack[1] = Env[2]
				end
			end
		else
						Temp[4] = vmEnv
			Temp[5] = 4
			Temp[18] = Constants[Temp[7]]
			Temp[13] = 8
			Temp[8][Temp[8]] = Temp[19]
		end
			end
		end
	end
else
	if (pointer * 3) + pointer <= 32 then
		if (pointer * pointer * 5) + pointer == 328 then
			do
				if (pointer + 74) > pointer then
			do
				if pointer * 3 - 4 == 20 then
					if pointer + 1 ~= 24 then
						Temp[1] = {}
	for i = 3 + 1, top do
		Temp[1][i - 3] = Stack[i]
	end
	Temp[2] = {Stack[3](unpack(Temp[1], 1, top - 3))}
		for i = 1, 1 do
		Stack[3 + i - 1] = Temp[2][i]
	end
	
	
				end
				else
					Stack[1] = nil
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
			end
		elseif (pointer * pointer) + (14 * pointer) == 147 then
			do
				if (pointer - 89) > pointer then
			Temp[1] = 2
			Temp[5] = Constants
			Temp[3] = 7
			Stack[Temp[4]] = Temp[18][Temp[14]]
		else
			do
				if pointer + 13 == 20 then
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
	
				end
			end
		end
			end
		end
	else
		if (pointer * pointer) + (8 * pointer) == 153 then
			do
				do
			if pointer - 10 == -1 then
					if pointer - 7 == 2 then
						Temp[1] = ""
	for i = 1, 3 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[1] = Temp[1]
	
				end
				elseif pointer - 10 == 19 then
					Stack[4] = Env[4]
				end
		end
			end
		elseif (pointer * pointer * 2) + pointer == 210 then
			do
				if (pointer + 50) > pointer then
			do
				if pointer * 3 - 2 == 28 then
						return Stack[1]
				else
					Stack[3] = nil
				end
			end
		else
			Temp[3] = 4
			Temp[6] = Constants
			Temp[8] = 15
			Stack[Temp[3]] = Temp[6][Temp[18]]
		end
			end
		elseif (pointer * pointer) + (12 * pointer) == 253 then
			do
				if pointer + 3 == 14 then
				return
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
					elseif (pointer * pointer * 5) + pointer == 510 then
						do
							if (pointer + 8) > pointer then
			do
				if pointer * 2 + 6 == 26 then
					if pointer - 1 == 9 then
					if pointer * 3 - 8 == 22 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\021\063", "2418")),(decrypt("\120\015\014\031\030\029", "2066")),(decrypt("\014\104\083\082", "2099")),(decrypt("\121\080\092\108\084\092\083", "2080")),(decrypt("\120\084\093\094\088\092\103", "989")),(decrypt("\117\081\097\064\110\091\001\107\105\110\098", "2290")),((decrypt("\028\031\026\019\029", "1369"))),}

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
		if (pointer * 15) + (pointer * 12) == 27 then
	do
		if pointer + 12 == 13 then
			Temp[4] = 1
Temp[3] = Constants
Temp[5] = 1
Stack[Temp[4]] = Temp[3][Temp[5]]
		end
	end
elseif (pointer * pointer) + 43 == 52 then
	do
		if pointer + 7 == 10 then
				return
		end
	end
elseif (pointer * pointer * 2) + pointer == 10 then
	do
		do
			if pointer * 3 - 1 == 5 then
					if pointer * 2 - 6 == -2 then
					if pointer - 12 == -10 then
						return Stack[1]
				end
				end
				else
					Stack[1] = nil
				end
		end
	end
end
		pointer = pointer+1
		end
	end

				else
					Stack[7] = nil
				end
				elseif pointer - 1 == 21 then
					Stack[1] = Env[4]
				end
				end
			end
		else
			Stack[8] = -Stack[3]
		end
						end
					end
				end
			end
		else
			if (pointer * 8) + pointer <= 126 then
				if (pointer * 7) + (pointer * 39) == 552 then
					do
						if pointer + 14 == 26 then
			Temp[14] = 1
Temp[6] = 1
Temp[15] = Constants[Temp[6]]
Stack[Temp[14]] = vmEnv[Temp[15]] or Env[Temp[15]]
		end
					end
				elseif (pointer * pointer) + 15 == 136 then
					do
						do
			if pointer * 2 + 5 == 27 then
						Stack[0][Constants[5]] = Stack[1]
				end
		end
					end
				elseif (pointer * pointer) + (2 * pointer) == 224 then
					do
						if pointer + 10 == 24 then
				Stack[3] = {}
		end
					end
				elseif (pointer * pointer) + 22 == 191 then
					do
						do
			if pointer * 2 - 9 == 17 then
					if pointer * 2 - 2 == 24 then
					if pointer + 9 == 22 then
						Stack[2] = {}
				end
				end
				end
		end
					end
				end
			else
				if (pointer * pointer) + (4 * pointer) <= 320 then
					if (pointer * pointer) + (10 * pointer) == 416 then
						do
							if pointer + 2 == 18 then
				Stack[1] = Stack[1](Stack[2], Stack[3])
		end
						end
					elseif (pointer * pointer) + (11 * pointer) == 390 then
						do
							if pointer + 12 == 27 then
				Stack[3][Constants[3]] = Stack[0]
		end
						end
					end
				else
					if (pointer * pointer) + 36 == 325 then
						do
							do
			if pointer + 12 == 29 then
					if pointer * 3 - 4 == 47 then
						Stack[1][Constants[3]] = Stack[1]
				else
					Stack[2] = nil
				end
				end
		end
						end
					elseif (pointer * pointer * 5) + pointer == 1638 then
						do
							if pointer + 12 == 30 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\104\084\088\110\081\104", "2414")),((decrypt("\024\021\027", "1238"))),(decrypt("\115\092\081\094\013\108\085\103\109\091", "2059")),(decrypt("\121\086\080\094\122\104\069", "530")),(decrypt("\119\092\091\111\090\086\108\046\110\094\103\090\083\101\083\092", "796")),(decrypt("\091\104\107\088\094\090", "2008")),(decrypt("\083\100\083\093\100\083\097\083\096\096\091\100", "988")),(decrypt("\087\106\089", "2673")),(decrypt("\123\092\104\110\109\090\088", "1024")),((decrypt("\018\017\019\029\026\031\025\030\030", "544"))),}

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
		if (pointer * pointer) + (4 * pointer) <= 60 then
	if (pointer * pointer) + (4 * pointer) <= 12 then
		if (pointer * pointer * 4) + pointer == 5 then
			do
				if (pointer + 50) > pointer then
			do
				if pointer + 15 == 17 then
					Stack[4] = nil
				end
				if pointer * 2 - 3 == -1 then
					if pointer + 1 ~= 22 then
						Stack[1] = Upvalues[0]
				end
				end
			end
		else
						Temp[16] = vmEnv
			Temp[4] = 20
			Temp[11] = Constants[Temp[18]]
			Temp[10] = 10
			Temp[6][Temp[12]] = Temp[19]
		end
			end
		elseif (pointer * pointer * 2) + pointer == 10 then
			do
				if pointer + 3 == 5 then
				Stack[1] = Stack[1][Constants[8]]
	
		end
			end
		end
	else
		if (pointer * pointer * 4) + pointer == 39 then
			do
				do
			if pointer + 11 ~= 33 then
					if pointer + 11 == 25 then
					Stack[8] = nil
				end
				if pointer + 11 ~= 16 then
					Temp[4] = 2
Temp[5] = Constants
Temp[13] = 1
Stack[Temp[4]] = Temp[5][Temp[13]]
	Stack[1] = Stack[1](Stack[2])
	pointer = pointer + 1
				end
				end
		end
			end
		elseif (pointer * pointer * 4) + pointer == 105 then
			do
				if (pointer + 63) > pointer then
			do
				if pointer * 3 - 13 == 2 then
					if pointer + 10 ~= 21 then
					if pointer + 10 ~= 23 then
						Stack[1][Constants[6]] = Stack[0]
				end
				end
				else
					Stack[8] = nil
				end
			end
		else
			Stack[4] = -Stack[8]
		end
			end
		elseif (pointer * pointer) + (15 * pointer) == 126 then
			do
				if (pointer + 93) > pointer then
			do
				if pointer + 8 == 33 then
					Stack[7] = nil
				end
				Temp[16] = 2
Temp[8] = 7
Temp[10] = Constants[Temp[8]]
Stack[Temp[16]] = vmEnv[Temp[10]] or Env[Temp[10]]
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
			end
		end
	end
else
	if (pointer * 3) + pointer <= 32 then
		if (pointer * pointer) + 46 == 110 then
			do
				if (pointer - 24) > pointer then
			if (pointer * 2) < 0 then Env[1] = nil end
		else
			do
				if pointer + 7 == 15 then
					if pointer * 3 - 15 == 9 then
					if pointer + 11 == 35 then
					Stack[6] = nil
				end
					Stack[4] = Upvalues[1]
				else
					Stack[4] = nil
				end
				end
			end
		end
			end
		elseif (pointer * pointer) + 9 == 58 then
			do
				if (pointer - 47) > pointer then
			Temp[10] = 2
			Temp[13] = Constants
			Temp[4] = 7
			Stack[Temp[7]] = Temp[17][Temp[17]]
		else
			do
				if pointer * 2 + 9 == 23 then
					Temp[15] = 3
Temp[1] = 1
Stack[Temp[15]] = Stack[Temp[1]]
				end
			end
		end
			end
		end
	else
		if (pointer * pointer * 5) + pointer == 616 then
			do
				do
			if pointer * 3 - 14 == 19 then
						return
				else
					Stack[3] = nil
				end
		end
			end
		elseif (pointer * pointer) + (12 * pointer) == 189 then
			do
				if (pointer - 19) > pointer then
			Temp[11] = 1
			Temp[7] = Constants
			Temp[16] = 17
			Stack[Temp[16]] = Temp[15][Temp[14]]
		else
			do
				if pointer - 5 == 4 then
					if pointer * 2 + 13 == 31 then
						return Stack[2](Stack[3], Stack[4])
				end
				end
			end
		end
			end
		elseif (pointer * pointer) + (8 * pointer) == 180 then
			do
				do
			if pointer * 2 - 4 == 16 then
					if pointer - 11 == -1 then
					if pointer + 8 == 18 then
					            Temp[1] = {}
            Temp[2] = 0
            for i = 2, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
        
				end
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
					elseif (pointer * 4) + (pointer * 23) == 567 then
						do
							if (pointer + 40) > pointer then
			do
				if pointer - 7 == 14 then
					if pointer - 11 == 10 then
						Stack[1][Constants[18]] = Stack[2]
				elseif pointer - 11 == 19 then
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
					end
				end
			end
		end
	else
		if pointer * pointer <= 900 then
			if (pointer * pointer) + (15 * pointer) <= 1000 then
				if (pointer * 11) + (pointer * 32) == 989 then
					do
						do
			if pointer - 4 == 19 then
					if pointer + 2 ~= 39 then
						Stack[1][Constants[5]] = Stack[2]
				end
				end
		end
					end
				elseif (pointer * pointer) + (14 * pointer) == 912 then
					do
						do
			if pointer - 5 == 19 then
					Temp[13] = 2
Temp[9] = 1
Temp[11] = Constants[Temp[9]]
Stack[Temp[13]] = vmEnv[Temp[11]] or Env[Temp[11]]
				elseif pointer - 5 == 24 then
					Stack[7] = Env[4]
				end
		end
					end
				elseif (pointer * pointer) + (8 * pointer) == 660 then
					do
						if (pointer + 88) > pointer then
			do
				if pointer * 2 - 8 == 36 then
					if pointer + 4 == 45 then
					Stack[1] = nil
				end
				if pointer * 3 - 5 == 61 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {((decrypt("\030\022\027", "2116"))),(decrypt("\120\100\088\088\082\098\109\034\094\093\105\088\106\088\082\109\107\091\109", "2815")),(decrypt("\027\061", "2696")),(decrypt("\089\080\091\110", "2972")),(decrypt("\091\106\110\084\094\088", "2254")),(decrypt("\008\102\110\090\106\099\093\111\091\001\109\104\110\098", "2963")),(decrypt("\085\108\095\109", "1442")),(decrypt("\080\084", "742")),}

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
		if pointer * pointer <= 16 then
	if (pointer * pointer) + (2 * pointer) == 3 then
		do
			if (pointer + 63) > pointer then
			do
				if pointer - 6 == -5 then
					if pointer + 10 == 11 then
					if pointer * 2 - 3 == -1 then
					Temp[3] = 1
Temp[10] = 7
Temp[9] = Constants[Temp[10]]
Stack[Temp[3]] = vmEnv[Temp[9]] or Env[Temp[9]]
	Stack[1] = Stack[1][Constants[8]]
	
	pointer = pointer + 1
				end
				end
				elseif pointer - 6 == 8 then
					Stack[5] = Env[3]
				end
			end
		else
			if pointer > 90 then Stack[6] = Stack[6] end
		end
		end
	elseif (pointer * pointer) + (2 * pointer) == 15 then
		do
			if pointer + 5 == 8 then
				Stack[2] = Stack[0][Constants[5]]
	
		end
		end
	elseif (pointer * pointer * 2) + pointer == 36 then
		do
			if pointer + 5 == 9 then
				Stack[2] = Stack[2] ^ Constants[3]
		end
		end
	end
else
	if (pointer * 4) + (pointer * 12) == 112 then
		do
			do
			if pointer * 2 + 3 == 17 then
						return
				end
		end
		end
	elseif (pointer * pointer) + 46 == 82 then
		do
			do
			if pointer + 15 ~= 27 then
						return Stack[1]
				end
		end
		end
	elseif (pointer * 2) + (pointer * 17) == 95 then
		do
			do
			if pointer - 13 == -8 then
					if pointer - 10 == -5 then
						Stack[1] = Stack[1] * Stack[2]
				elseif pointer - 10 == -3 then
					Stack[1] = Env[1]
				end
				elseif pointer - 13 == 7 then
					Stack[6] = Env[1]
				end
		end
		end
	end
end
		pointer = pointer+1
		end
	end

				else
					Stack[3] = nil
				end
				end
			end
		else
			Stack[2] = (0 == 1)
		end
					end
				elseif (pointer * pointer) + 9 == 634 then
					do
						if pointer + 14 == 39 then
				Stack[3] = {}
		end
					end
				end
			else
				if pointer * pointer <= 729 then
					if (pointer * 11) + (pointer * 10) == 567 then
						do
							if pointer + 3 == 30 then
				Stack[4][Constants[3]] = Stack[0]
		end
						end
					elseif (pointer * 12) + (pointer * 9) == 546 then
						do
							do
			if pointer * 2 + 12 == 64 then
						Stack[4] = {}
				end
		end
						end
					end
				else
					if (pointer * pointer) + 40 == 824 then
						do
							if (pointer + 7) > pointer then
			do
				if pointer - 9 == 19 then
					if pointer - 3 == 25 then
						Stack[2] = Stack[2](Stack[3], Stack[4])
				end
				elseif pointer - 9 == 22 then
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
					elseif (pointer * pointer) + 48 == 889 then
						do
							if pointer + 13 == 42 then
				Stack[2][Constants[3]] = Stack[2]
		end
						end
					elseif (pointer * pointer) + (9 * pointer) == 1170 then
						do
							if (pointer + 41) > pointer then
			do
				if pointer + 12 ~= 47 then
					if pointer + 13 == 49 then
					Stack[4] = nil
				end
					local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[6] then
		C1 = {}
		local encoded = {(decrypt("\013\104\088\085\095\111", "523")),(decrypt("\091\101\090\092\109\082\105\083\105\096\082\100", "1918")),(decrypt("\088\108\107\092", "1017")),(decrypt("\010\081\088\098\087\084\087\100\107\090", "1128")),(decrypt("\087\108\089", "2079")),(decrypt("\093\083\104\088\108", "333")),(decrypt("\110\107\082\102\110\092", "1728")),}

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
		if (pointer * 12) + pointer <= 91 then
	if pointer * pointer <= 9 then
		if (pointer * pointer * 4) + pointer == 39 then
			do
				if (pointer - 77) > pointer then
			if pointer > 110 then Stack[8] = Stack[2] end
		else
			do
				if pointer + 11 ~= 18 then
					if pointer - 4 == -1 then
					Temp[16] = 3
Temp[9] = Constants
Temp[6] = 3
Stack[Temp[16]] = Temp[9][Temp[6]]
	Stack[2] = Stack[2](Stack[3])
	pointer = pointer + 1
				elseif pointer - 4 == 8 then
					Stack[4] = Env[2]
				end
				end
			end
		end
			end
		elseif (pointer * pointer) + (3 * pointer) == 10 then
			do
				do
			if pointer * 3 - 4 == 2 then
					if pointer + 12 ~= 34 then
					if pointer - 14 == -12 then
						Stack[2] = Stack[2][Constants[5]]
	
				end
				end
				else
					Stack[1] = nil
				end
		end
			end
		elseif (pointer * 8) + (pointer * 22) == 30 then
			do
				if pointer + 5 == 6 then
				Stack[2] = Upvalues[0]
		end
			end
		end
	else
		if (pointer * pointer) + 38 == 87 then
			do
				do
			if pointer - 3 == 4 then
					if pointer - 12 == -5 then
						Stack[2][Constants[6]] = Stack[3]
				elseif pointer - 12 == 8 then
					Stack[5] = Env[5]
				end
				elseif pointer - 3 == 20 then
					Stack[2] = Env[1]
				end
		end
			end
		elseif (pointer * pointer * 5) + pointer == 186 then
			do
				do
			if pointer * 2 - 4 == 8 then
					if pointer * 3 - 8 == 10 then
						Stack[2][Constants[7]] = Stack[1]
				else
					Stack[2] = nil
				end
				end
		end
			end
		elseif (pointer * pointer) + (10 * pointer) == 75 then
			do
				if pointer + 15 == 20 then
			Temp[2] = 3
Temp[10] = 0
Stack[Temp[2]] = Stack[Temp[10]]
		end
			end
		end
	end
else
	if pointer * pointer <= 100 then
		if (pointer * pointer) + (5 * pointer) == 150 then
			do
				do
			if pointer - 15 == -5 then
						Stack[5] = Upvalues[1]
				elseif pointer - 15 == 9 then
					Stack[2] = Env[6]
				end
		end
			end
		elseif (pointer * pointer) + (9 * pointer) == 136 then
			do
				do
			if pointer * 3 - 2 == 22 then
					if pointer * 2 + 12 == 28 then
					Temp[4] = 3
Temp[5] = 2
Temp[13] = Constants[Temp[5]]
Stack[Temp[4]] = vmEnv[Temp[13]] or Env[Temp[13]]
				end
				else
					Stack[1] = nil
				end
		end
			end
		elseif (pointer * pointer * 5) + pointer == 414 then
			do
				if pointer + 4 == 13 then
			Temp[14] = 4
Temp[4] = 2
Stack[Temp[14]] = Stack[Temp[4]]
		end
			end
		end
	else
		if (pointer * 7) + (pointer * 39) == 598 then
			do
				if (pointer - 5) > pointer then
			Stack[4] = (1 == 1)
		else
			do
				if pointer - 7 == 6 then
					if pointer - 5 == 8 then
						return
				elseif pointer - 5 == 21 then
					Stack[1] = Env[4]
				end
				end
			end
		end
			end
		elseif (pointer * pointer * 3) + pointer == 374 then
			do
				if (pointer + 9) > pointer then
			do
				if pointer + 2 == 13 then
						return Stack[3](Stack[4], Stack[5])
				end
			end
		else
			if pointer > 130 then Stack[8] = Stack[8] end
		end
			end
		elseif (pointer * pointer * 3) + pointer == 444 then
			do
				do
			if pointer * 2 + 3 == 27 then
					if pointer + 5 == 31 then
					Stack[2] = nil
				end
				            Temp[1] = {}
            Temp[2] = 0
            for i = 3, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
        
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
		else
			Stack[5] = -Stack[1]
		end
						end
					end
				end
			end
		else
			if (pointer * pointer) + (3 * pointer) <= 1404 then
				if (pointer * pointer) + 35 == 1191 then
					do
						if pointer + 15 == 49 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[7] then
		C1 = {}
		local encoded = {(decrypt("\093\082\104\088\109", "323")),(decrypt("\118\082\109\069\109\088\124\105\085\087\088\085\084\111", "1155")),(decrypt("\109\104\086\108\107\093", "246")),(decrypt("\012\095\080\111", "2934")),(decrypt("\126\088\110\089\114\087\085\092\089\120\110\089\095\082\104\108", "2220")),(decrypt("\014\106\104\080\092\087\093\008\108\106", "602")),(decrypt("\117\010\026", "1168")),(decrypt("\010\084\082\110\087\081\093\104\107\095", "1484")),}

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
		if (pointer * pointer) + (7 * pointer) <= 18 then
	if (pointer * pointer) + (10 * pointer) == 11 then
		do
			if pointer + 7 == 8 then
				Stack[1] = Stack[0][Constants[1]]
	
		end
		end
	elseif (pointer * 13) + (pointer * 18) == 62 then
		do
			do
			if pointer - 9 == -7 then
						Stack[2] = Stack[0][Constants[3]]
	
				elseif pointer - 9 == 10 then
					Stack[5] = Env[7]
				end
		end
		end
	end
else
	if (pointer * pointer * 5) + pointer == 48 then
		do
			if pointer + 1 == 4 then
				Stack[1] = Stack[1] * Stack[2]
		end
		end
	elseif (pointer * pointer) + 33 == 58 then
		do
			if pointer + 14 == 19 then
				return
		end
		end
	elseif (pointer * pointer) + (5 * pointer) == 36 then
		do
			do
			if pointer - 2 == 2 then
					if pointer + 12 == 18 then
					Stack[1] = nil
				end
				if pointer + 7 == 26 then
					Stack[1] = nil
				end
					return Stack[1]
				elseif pointer - 2 == 18 then
					Stack[1] = Env[4]
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
				elseif (pointer * pointer * 4) + pointer == 4389 then
					do
						if pointer + 1 == 34 then
				Stack[2][Constants[18]] = Stack[3]
		end
					end
				elseif (pointer * pointer) + (8 * pointer) == 1505 then
					do
						do
			if pointer + 8 == 43 then
					if pointer * 2 + 6 == 76 then
					if pointer - 10 == 25 then
						Stack[2][Constants[5]] = Stack[3]
				elseif pointer - 10 == 44 then
					Stack[5] = Env[8]
				end
				end
				end
		end
					end
				elseif (pointer * pointer * 4) + pointer == 5220 then
					do
						if pointer + 5 == 41 then
				Stack[3] = {}
		end
					end
				end
			else
				if pointer * pointer <= 1444 then
					if (pointer * 13) + (pointer * 37) == 1900 then
						do
							do
			if pointer + 2 == 40 then
					if pointer - 2 == 36 then
					if pointer * 3 - 9 == 105 then
						Stack[3][Constants[13]] = Constants[19]
				else
					Stack[6] = nil
				end
				end
				end
		end
						end
					elseif (pointer * pointer) + (2 * pointer) == 1443 then
						do
							if pointer + 9 == 46 then
				Stack[3][Constants[3]] = Stack[3]
		end
						end
					end
				else
					if (pointer * pointer) + (3 * pointer) == 1890 then
						do
							do
			if pointer - 12 == 30 then
					if pointer * 2 - 7 == 77 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[9] then
		C1 = {}
		local encoded = {(decrypt("\114\093\082\108\091\093\097\083\037\100\080\089\084\081", "2890")),(decrypt("\028\060", "474")),(decrypt("\013\107\110\090\089\110\106\107\089", "2763")),(decrypt("\114\093\085\096\081\088\099\047\088\083\096\083\110", "2888")),(decrypt("\093\082\083\106\081\103", "641")),(decrypt("\081\105\091\090", "2111")),(decrypt("\084\082\104\080\083", "494")),}

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
		if (pointer * 10) + pointer <= 33 then
	if (pointer * pointer) + 28 == 32 then
		do
			if (pointer - 34) > pointer then
			Stack[4] = (0 == 1)
		else
			do
				if pointer * 2 - 10 == -6 then
					if pointer * 2 - 5 == -1 then
					if pointer + 12 == 27 then
					Stack[2] = nil
				end
					Stack[2] = Stack[2] + Constants[2]
				end
				end
			end
		end
		end
	elseif (pointer * pointer) + (8 * pointer) == 9 then
		do
			if pointer + 2 == 3 then
				Stack[2] = Stack[0][Constants[6]]
	
		end
		end
	elseif (pointer * pointer) + (6 * pointer) == 27 then
		do
			if (pointer + 53) > pointer then
			do
				if pointer - 11 == -8 then
					if pointer + 8 == 13 then
					Stack[5] = nil
				end
					Stack[0][Constants[6]] = Stack[2]
				elseif pointer - 11 == -6 then
					Stack[1] = Env[6]
				end
			end
		else
			if pointer > 196 then Stack[1] = Stack[4] end
		end
		end
	end
else
	if (pointer * pointer * 5) + pointer == 186 then
		do
			if (pointer + 28) > pointer then
			do
				if pointer + 12 == 18 then
					if pointer + 5 == 16 then
					Stack[7] = nil
				end
				if pointer * 3 - 6 == 12 then
						Stack[2][Stack[3]] = Stack[1]
				else
					Stack[8] = nil
				end
				end
			end
		else
			Stack[7] = Stack[6] or Constants[4+1]
		end
		end
	elseif (pointer * pointer) + (5 * pointer) == 50 then
		do
			if pointer + 11 == 16 then
				Stack[3] = Stack[0][Constants[6]]
	
		end
		end
	elseif (pointer * pointer * 4) + pointer == 203 then
		do
			if pointer + 14 == 21 then
				return
		end
		end
	elseif (pointer * 7) + (pointer * 37) == 176 then
		do
			if pointer + 13 == 17 then
				Stack[2] = Stack[0][Constants[7]]
	
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
					elseif (pointer * pointer) + (2 * pointer) == 1599 then
						do
							do
			if pointer * 3 - 9 == 108 then
					if pointer - 2 == 37 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[8] then
		C1 = {}
		local encoded = {(decrypt("\011\094\086\086\088", "1850")),(decrypt("\093\109\090\083\109\090\111\090\105\110\082\109", "711")),(decrypt("\025\058", "1143")),(decrypt("\016\050", "792")),(decrypt("\081\104\083\091", "2090")),(decrypt("\010\105\109\104", "1553")),(decrypt("\110\084\094\089\095", "347")),(decrypt("\082\082\104\081\088", "2945")),}

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
		if (pointer * 4) + pointer <= 25 then
	if (pointer * 10) + pointer <= 22 then
		if (pointer * pointer) + 43 == 47 then
			do
				do
			if pointer * 3 - 3 == 3 then
					if pointer * 3 - 4 == 2 then
						Stack[1] = {}
				else
					Stack[8] = nil
				end
				else
					Stack[2] = nil
				end
		end
			end
		elseif (pointer * pointer) + (6 * pointer) == 7 then
			do
				if pointer + 1 == 2 then
			Temp[4] = 0
Temp[12] = 2
Temp[14] = Constants[Temp[12]]
Stack[Temp[4]] = vmEnv[Temp[14]] or Env[Temp[14]]
		end
			end
		end
	else
		if (pointer * 7) + (pointer * 15) == 66 then
			do
				do
			if pointer * 2 + 7 == 13 then
						Stack[1][Constants[7]] = Constants[3]
				end
		end
			end
		elseif (pointer * 3) + (pointer * 41) == 176 then
			do
				if pointer + 7 == 11 then
				Stack[1][Constants[5]] = Constants[4]
		end
			end
		elseif (pointer * pointer) + 11 == 36 then
			do
				do
			if pointer + 4 ~= 14 then
					if pointer + 7 ~= 24 then
						Stack[2] = {}
				end
				end
		end
			end
		end
	end
else
	if (pointer * 15) + pointer <= 112 then
		if (pointer * pointer) + (9 * pointer) == 90 then
			do
				if (pointer - 61) > pointer then
			Stack[2] = -Stack[1]
		else
			do
				if pointer * 3 - 1 == 17 then
					if pointer * 3 - 2 == 16 then
					if pointer + 6 == 30 then
					Stack[3] = nil
				end
					Stack[1][Constants[8]] = Stack[2]
				else
					Stack[6] = nil
				end
				else
					Stack[4] = nil
				end
			end
		end
			end
		elseif (pointer * pointer) + 13 == 62 then
			do
				if pointer + 5 == 12 then
				Stack[2] = Upvalues[0]
		end
			end
		end
	else
		if (pointer * pointer * 2) + pointer == 136 then
			do
				if pointer + 6 == 14 then
				return Stack[0](Stack[1], Stack[2])
		end
			end
		elseif (pointer * 5) + (pointer * 13) == 162 then
			do
				if (pointer - 83) > pointer then
			if pointer > 146 then Stack[8] = Stack[1] end
		else
			do
				if pointer - 5 == 4 then
					if pointer - 10 == -1 then
					if pointer - 1 == 8 then
					            Temp[1] = {}
            Temp[2] = 0
            for i = 0, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
        
				end
				elseif pointer - 10 == 14 then
					Stack[1] = Env[8]
				end
				end
			end
		end
			end
		elseif (pointer * pointer) + 18 == 118 then
			do
				do
			if pointer - 5 == 5 then
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

				elseif pointer - 2 == 48 then
					Stack[3] = Env[5]
				end
				else
					Stack[1] = nil
				end
		end
						end
					elseif (pointer * 8) + (pointer * 6) == 574 then
						do
							if (pointer - 39) > pointer then
			Stack[5] = -Stack[6]
		else
			do
				if pointer + 5 == 54 then
					Stack[7] = nil
				end
				if pointer - 4 == 37 then
						Stack[3][Constants[18]] = Stack[4]
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
	if pointer * pointer <= 3969 then
		if (pointer * 8) + pointer <= 468 then
			if (pointer * 5) + pointer <= 276 then
				if (pointer * pointer * 5) + pointer == 9724 then
					do
						do
			if pointer * 2 + 3 == 91 then
					if pointer * 2 + 1 == 89 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[10] then
		C1 = {}
		local encoded = {(decrypt("\082\110\089\083", "1638")),(decrypt("\098\108\086", "2480")),(decrypt("\011\110\087\013\087\085\081\087\106\106", "1627")),(decrypt("\082\092\106\083\088", "2767")),(decrypt("\026\061", "2605")),(decrypt("\111\082\088\095\089", "2215")),(decrypt("\087\089\084\054", "2970")),}

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
		if (pointer * pointer) + (12 * pointer) <= 160 then
	if (pointer * pointer) + (14 * pointer) <= 72 then
		if (pointer * pointer) + (4 * pointer) == 32 then
			do
				do
			if pointer * 2 + 8 == 16 then
					pointer = pointer + 2 
				end
		end
			end
		elseif (pointer * pointer) + (9 * pointer) == 10 then
			do
				do
			if pointer + 13 ~= 31 then
						Stack[1] = Stack[0][Constants[6]]
	
				end
		end
			end
		elseif (pointer * pointer * 2) + pointer == 21 then
			do
				if (pointer + 44) > pointer then
			do
				if pointer + 15 == 34 then
					Stack[3] = nil
				end
				if pointer * 2 - 4 == 2 then
						if Stack[2] < Stack[1] then pointer = pointer + 1 end
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
			end
		elseif (pointer * 12) + (pointer * 35) == 94 then
			do
				do
			if pointer * 2 + 8 == 12 then
					if pointer + 15 == 17 then
						Stack[2] = Stack[0][Constants[1]]
	
				end
				end
		end
			end
		end
	else
		if (pointer * 12) + (pointer * 49) == 366 then
			do
				if (pointer - 15) > pointer then
			Temp[10] = 3
			Temp[10] = Constants
			Temp[18] = 8
			Stack[Temp[7]] = Temp[9][Temp[8]]
		else
			do
				if pointer + 3 == 9 then
					if pointer - 13 == -7 then
						return Stack[1]
				end
				end
			end
		end
			end
		elseif (pointer * 12) + (pointer * 16) == 196 then
			do
				if pointer + 3 == 10 then
				Stack[1] = Stack[0][Constants[4]]
	
		end
			end
		elseif (pointer * pointer) + 23 == 48 then
			do
				do
			if pointer + 5 ~= 14 then
					if pointer + 7 == 20 then
					Stack[2] = nil
				end
					Stack[1], Stack[2] = nil
				end
		end
			end
		elseif (pointer * 4) + (pointer * 18) == 176 then
			do
				do
			if pointer * 2 + 14 == 30 then
					if pointer + 10 ~= 37 then
					if pointer + 13 == 21 then
						Stack[2] = Stack[0][Constants[6]]
	
				end
				end
				end
		end
			end
		end
	end
else
	if (pointer * pointer) + (10 * pointer) <= 264 then
		if (pointer * pointer) + (13 * pointer) == 230 then
			do
				if pointer + 13 == 23 then
				Stack[2] = Stack[0][Constants[4]]
	
		end
			end
		elseif (pointer * pointer * 5) + pointer == 414 then
			do
				if (pointer + 80) > pointer then
			do
				if pointer * 3 - 11 == 16 then
					if pointer + 4 ~= 17 then
					if pointer + 11 == 21 then
					Stack[8] = nil
				end
					Stack[1] = Stack[1][Stack[2]]
	
				end
				else
					Stack[6] = nil
				end
			end
		else
			Stack[6] = Stack[5] or Constants[2+1]
		end
			end
		elseif (pointer * 8) + (pointer * 34) == 462 then
			do
				if (pointer + 79) > pointer then
			do
				if pointer - 14 == -3 then
						Stack[3] = Stack[0][Constants[6]]
	
				elseif pointer - 14 == 10 then
					Stack[1] = Env[3]
				end
			end
		else
			Stack[1] = (0 == 1)
		end
			end
		elseif (pointer * 4) + (pointer * 29) == 396 then
			do
				if pointer + 14 == 26 then
				Stack[2][Stack[3]] = Constants[7]
		end
			end
		end
	else
		if (pointer * pointer) + (5 * pointer) <= 266 then
			if (pointer * pointer * 3) + pointer == 520 then
				do
					do
			if pointer + 15 ~= 48 then
						Stack[2] = Stack[0][Constants[6]]
	
				end
		end
				end
			elseif (pointer * pointer * 2) + pointer == 406 then
				do
					if pointer + 10 == 24 then
				Stack[2] = Stack[2] + Constants[5]
		end
				end
			end
		else
			if (pointer * pointer) + 33 == 258 then
				do
					if pointer + 12 == 27 then
				Stack[0][Constants[6]] = Stack[2]
		end
				end
			elseif (pointer * pointer) + (10 * pointer) == 459 then
				do
					if (pointer - 77) > pointer then
						Temp[5] = vmEnv
			Temp[4] = 10
			Temp[1] = Constants[Temp[5]]
			Temp[14] = 5
			Temp[5][Temp[5]] = Temp[10]
		else
			do
				if pointer + 12 == 29 then
					if pointer * 2 + 5 == 39 then
						return
				end
				end
			end
		end
				end
			elseif (pointer * pointer) + (14 * pointer) == 480 then
				do
					if (pointer + 60) > pointer then
			do
				if pointer * 2 - 5 == 27 then
					if pointer - 12 == 4 then
						return Stack[1]
				elseif pointer - 12 == 14 then
					Stack[8] = Env[8]
				end
				end
			end
		else
			Temp[7] = 1
			Temp[17] = Constants
			Temp[12] = 10
			Stack[Temp[17]] = Temp[11][Temp[18]]
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
				elseif (pointer * pointer) + 36 == 1885 then
					do
						if pointer + 9 == 52 then
				Stack[3][Constants[22]] = Stack[4]
		end
					end
				elseif (pointer * pointer) + (7 * pointer) == 2340 then
					do
						if (pointer - 17) > pointer then
			Stack[6] = Stack[4] or Constants[8+1]
		else
			do
				if pointer - 12 == 33 then
					if pointer * 2 - 2 == 88 then
					if pointer * 3 - 9 == 126 then
						Stack[3][Constants[7]] = Stack[4]
				else
					Stack[4] = nil
				end
				end
				end
			end
		end
					end
				elseif (pointer * pointer) + (7 * pointer) == 2438 then
					do
						do
			if pointer * 2 + 12 == 104 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[11] then
		C1 = {}
		local encoded = {(decrypt("\103", "765")),(decrypt("\108\082\088\091\089", "121")),(decrypt("\082\097\089\094", "1935")),(decrypt("\120\086\111\111\093\121\111\081\094\083\098\111", "383")),(decrypt("\026\058", "210")),(decrypt("\010\111\089\089\088\085\067", "1332")),}

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
		if pointer * pointer <= 9 then
	if (pointer * pointer) + (6 * pointer) == 16 then
		do
			do
			if pointer - 10 == -8 then
					if pointer * 3 - 1 == 5 then
					if pointer * 2 + 10 == 14 then
						Stack[2] = Stack[0][Constants[2]]
	
				end
				else
					Stack[7] = nil
				end
				elseif pointer - 10 == 9 then
					Stack[6] = Env[7]
				end
		end
		end
	elseif (pointer * pointer * 5) + pointer == 48 then
		do
			if pointer + 10 == 13 then
				Stack[1] = Stack[1] - Stack[2]
		end
		end
	elseif (pointer * pointer) + 10 == 11 then
		do
			do
			if pointer * 2 - 5 == -3 then
					if pointer * 2 - 1 == 1 then
						Stack[1] = Stack[0][Constants[3]]
	
				end
				end
		end
		end
	end
else
	if (pointer * 6) + (pointer * 49) == 220 then
		do
			do
			if pointer + 14 == 18 then
					if pointer * 2 - 2 == 6 then
					if pointer + 1 == 5 then
						Stack[1] = Stack[1] + Constants[5]
				end
				end
				end
		end
		end
	elseif (pointer * pointer) + (6 * pointer) == 72 then
		do
			if pointer + 2 == 8 then
				return
		end
		end
	elseif (pointer * pointer) + (14 * pointer) == 95 then
		do
			if pointer + 11 == 16 then
				return Stack[1]
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
				if pointer * pointer <= 2304 then
					if (pointer * 9) + (pointer * 21) == 1440 then
						do
							if pointer + 8 == 56 then
				Stack[4] = Stack[3][Constants[18]]
	
	Stack[4] = Stack[4]()
	pointer = pointer + 1
		end
						end
					elseif (pointer * pointer) + (15 * pointer) == 2914 then
						do
							if (pointer - 64) > pointer then
			Stack[2] = nil
		else
			do
				if pointer - 10 == 37 then
					if pointer + 3 == 61 then
					Stack[3] = nil
				end
					Stack[3][Constants[21]] = Stack[4]
				elseif pointer - 10 == 55 then
					Stack[7] = Env[8]
				end
			end
		end
						end
					end
				else
					if (pointer * pointer) + 32 == 2633 then
						do
							if (pointer + 82) > pointer then
			do
				if pointer + 5 == 71 then
					Stack[8] = nil
				end
				if pointer + 9 == 60 then
					if pointer + 11 ~= 73 then
						Stack[7] = Stack[1][Constants[18]]
	
				end
				end
			end
		else
			Stack[1] = (0 == 1)
		end
						end
					elseif (pointer * pointer) + 26 == 2526 then
						do
							if (pointer + 45) > pointer then
			do
				if pointer * 2 - 2 == 98 then
						Stack[6] = Stack[4]
	if Stack[6] then
		Stack[5] = Stack[4][Constants[22]]
	end
	
				end
			end
		else
			Temp[8] = 3
			Temp[16] = Constants
			Temp[20] = 20
			Stack[Temp[5]] = Temp[18][Temp[10]]
		end
						end
					elseif (pointer * pointer * 4) + pointer == 10868 then
						do
							if (pointer - 34) > pointer then
						Temp[4] = vmEnv
			Temp[8] = 17
			Temp[15] = Constants[Temp[5]]
			Temp[14] = 9
			Temp[9][Temp[6]] = Temp[2]
		else
			do
				if pointer + 5 == 57 then
					if pointer * 2 + 9 == 113 then
					if pointer + 5 == 66 then
					Stack[3] = nil
				end
				Temp[10] = 8
Temp[5] = Constants
Temp[16] = 6
Stack[Temp[10]] = Temp[5][Temp[16]]
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
				end
				end
			end
		end
						end
					end
				end
			end
		else
			if (pointer * 3) + pointer <= 228 then
				if (pointer * pointer) + 40 == 3176 then
					do
						do
			if pointer + 14 == 70 then
					if pointer - 6 == 50 then
						Stack[7] = Stack[2][Constants[18]]
	
				end
				end
		end
					end
				elseif (pointer * pointer * 3) + pointer == 9804 then
					do
						if (pointer + 78) > pointer then
			do
				if pointer * 2 - 8 == 106 then
					Temp[15] = 8
Temp[13] = Constants
Temp[10] = 2
Stack[Temp[15]] = Temp[13][Temp[10]]
				end
			end
		else
			Stack[5] = Stack[8] or Constants[2+1]
		end
					end
				elseif (pointer * 4) + (pointer * 25) == 1595 then
					do
						if pointer + 9 == 64 then
				Stack[6] = Stack[4]
	if Stack[6] then
		Stack[5] = Stack[4][Constants[22]]
	end
	
		end
					end
				elseif (pointer * pointer) + (11 * pointer) == 3510 then
					do
						if (pointer + 74) > pointer then
			do
				if pointer * 3 - 7 == 155 then
					if pointer + 10 == 66 then
					Stack[5] = nil
				end
					Temp[1] = {}
	for i = 5 + 1, top do
		Temp[1][i - 5] = Stack[i]
	end
	Temp[2] = {Stack[5](unpack(Temp[1], 1, top - 5))}
		for i = 1, 0 do
		Stack[5 + i - 1] = Temp[2][i]
	end
	
	
				else
					Stack[4] = nil
				end
			end
		else
			Stack[1] = Stack[1] or Constants[5+1]
		end
					end
				end
			else
				if (pointer * 13) + pointer <= 840 then
					if (pointer * 7) + (pointer * 48) == 3300 then
						do
							if (pointer + 65) > pointer then
			do
				if pointer - 11 == 49 then
					if pointer * 2 + 3 == 123 then
					if pointer * 3 - 8 == 172 then
						Temp[1] = {}
	for i = 5 + 1, top do
		Temp[1][i - 5] = Stack[i]
	end
	Temp[2] = {Stack[5](unpack(Temp[1], 1, top - 5))}
		for i = 1, 0 do
		Stack[5 + i - 1] = Temp[2][i]
	end
	
	
				else
					Stack[7] = nil
				end
				end
				elseif pointer - 11 == 51 then
					Stack[2] = Env[4]
				end
			end
		else
			Stack[1] = Stack[7] or Constants[7+1]
		end
						end
					elseif (pointer * pointer * 2) + pointer == 6786 then
						do
							do
			if pointer * 3 - 3 == 171 then
					if pointer + 4 == 62 then
					Temp[3] = 9
Temp[9] = Constants
Temp[14] = 14
Stack[Temp[3]] = Temp[9][Temp[14]]
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
				end
				else
					Stack[5] = nil
				end
		end
						end
					end
				else
					if (pointer * pointer) + 43 == 3764 then
						do
							if (pointer - 24) > pointer then
			Stack[5] = -Stack[5]
		else
			do
				if pointer - 1 == 60 then
					if pointer + 8 == 69 then
						Stack[6] = Stack[4]
	if Stack[6] then
		Stack[5] = Stack[4][Constants[22]]
	end
	
				end
				elseif pointer - 1 == 68 then
					Stack[7] = Env[3]
				end
			end
		end
						end
					elseif (pointer * pointer) + 25 == 3869 then
						do
							do
			if pointer + 15 == 87 then
					Stack[2] = nil
				end
				if pointer + 3 == 65 then
						Stack[7] = Stack[0][Constants[18]]
	
				end
		end
						end
					elseif (pointer * pointer * 2) + pointer == 8001 then
						do
							if pointer + 1 == 64 then
			Temp[16] = 8
Temp[4] = Constants
Temp[5] = 9
Stack[Temp[16]] = Temp[4][Temp[5]]
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
		end
						end
					end
				end
			end
		end
	else
		if pointer * pointer <= 5329 then
			if (pointer * 7) + pointer <= 544 then
				if (pointer * pointer * 5) + pointer == 21846 then
					do
						do
			if pointer + 14 == 80 then
						Stack[6] = Stack[4]
	if Stack[6] then
		Stack[5] = Stack[4][Constants[21]]
	end
	
				end
		end
					end
				elseif (pointer * pointer * 5) + pointer == 22512 then
					do
						do
			if pointer * 3 - 6 == 195 then
					if pointer - 3 == 64 then
						Stack[5] = Stack[5](Stack[6])
				elseif pointer - 3 == 70 then
					Stack[2] = Env[2]
				end
				else
					Stack[3] = nil
				end
		end
					end
				elseif (pointer * 12) + (pointer * 17) == 1972 then
					do
						if pointer + 14 == 82 then
				if Constants[10] < Stack[5] then pointer = pointer + 1 end
		end
					end
				elseif (pointer * pointer) + 50 == 4275 then
					do
						if pointer + 2 == 67 then
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
				end
			else
				if pointer * pointer <= 4900 then
					if (pointer * pointer) + (8 * pointer) == 5313 then
						do
							if (pointer + 52) > pointer then
			do
				if pointer + 10 == 79 then
					pointer = pointer + 7 
				end
			end
		else
			if pointer > 101 then Stack[1] = Stack[3] end
		end
						end
					elseif (pointer * pointer * 3) + pointer == 14770 then
						do
							do
			if pointer * 3 - 6 == 204 then
					if pointer * 3 - 10 == 200 then
					Temp[15] = 5
Temp[5] = 4
Temp[4] = Constants[Temp[5]]
Stack[Temp[15]] = vmEnv[Temp[4]] or Env[Temp[4]]
				else
					Stack[3] = nil
				end
				else
					Stack[1] = nil
				end
		end
						end
					end
				else
					if (pointer * pointer * 5) + pointer == 25276 then
						do
							if (pointer + 19) > pointer then
			do
				if pointer * 2 + 4 == 146 then
					if pointer - 2 == 69 then
					if pointer - 11 == 60 then
						Stack[7] = Stack[4]
	if Stack[7] then
		Stack[6] = Stack[4][Constants[7]]
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
					elseif (pointer * pointer * 5) + pointer == 26718 then
						do
							do
			if pointer + 1 == 74 then
						Stack[7] = Stack[6]
	if Stack[7] then
		Stack[6] = Stack[6][Constants[15]]
	end
	
				end
		end
						end
					elseif (pointer * pointer) + (8 * pointer) == 5760 then
						do
							if pointer + 8 == 80 then
				Stack[6] = Stack[6](Stack[7])
		end
						end
					end
				end
			end
		else
			if pointer * pointer <= 5929 then
				if (pointer * pointer * 3) + pointer == 17404 then
					do
						if pointer + 15 == 91 then
			pointer = pointer + -11 
		end
					end
				elseif (pointer * pointer * 4) + pointer == 21978 then
					do
						if pointer + 8 == 82 then
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
	
		end
					end
				elseif (pointer * pointer) + (13 * pointer) == 6600 then
					do
						if pointer + 8 == 83 then
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
				elseif (pointer * pointer * 4) + pointer == 23793 then
					do
						if pointer + 2 == 79 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[12] then
		C1 = {}
		local encoded = {(decrypt("\021\061", "265")),(decrypt("\120\083\107\107\080\047\088\088\106\098\111", "2831")),(decrypt("\011\083\083\087\109\111\093\082\087\080\033\089\081\081\106\084\093\094", "1562")),(decrypt("\082\084\089\100\088", "1278")),(decrypt("\118\117\123", "190")),(decrypt("\027\063", "1460")),(decrypt("\087\084\092\108", "2290")),(decrypt("\114\082\095\099\107\015\092\111\111\098", "943")),(decrypt("\085\111\089\108", "1723")),(decrypt("\092\080\091\093", "662")),((decrypt("\025\020", "1341"))),(decrypt("\083\088\085", "780")),(decrypt("\086\106\083\095\091", "1236")),(decrypt("\089\107\104\084\110", "2317")),(decrypt("\005", "473")),(decrypt("\017\033", "2679")),(decrypt("\045\104\020", "1067")),(decrypt("\108\084\107\089\106\108", "203")),(decrypt("\107\080\080\104\105\093", "1652")),(decrypt("\026\056", "2302")),}

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
		if (pointer * 13) + pointer <= 364 then
	if pointer * pointer <= 169 then
		if pointer * pointer <= 49 then
			if (pointer * pointer) + (2 * pointer) <= 15 then
				if (pointer * pointer) + 22 == 26 then
					do
						if pointer + 15 == 17 then
				Stack[3] = Stack[0]
	if Stack[3] then
		Stack[2] = Stack[0][Constants[4]]
	end
	
		end
					end
				elseif (pointer * pointer * 5) + pointer == 48 then
					do
						if pointer + 4 == 7 then
				Stack[2] = Stack[2](Stack[3])
		end
					end
				elseif (pointer * pointer * 3) + pointer == 4 then
					do
						if (pointer + 74) > pointer then
			do
				if pointer - 15 == -14 then
					if pointer + 5 ~= 8 then
						Stack[1] = {}
				end
				elseif pointer - 15 == -11 then
					Stack[1] = Env[7]
				end
			end
		else
			Stack[6] = nil
		end
					end
				end
			else
				if (pointer * 15) + (pointer * 49) == 320 then
					do
						if pointer + 2 == 7 then
			Temp[13] = 4
Temp[16] = Constants
Temp[15] = 17
Stack[Temp[13]] = Temp[16][Temp[15]]
	Stack[2], Stack[3], Stack[4] = Stack[2](Stack[3], Stack[4])
	pointer = pointer + 1
		end
					end
				elseif (pointer * pointer * 3) + pointer == 154 then
					do
						if pointer + 14 == 21 then
			pointer = pointer + 6 
		end
					end
				elseif (pointer * pointer * 2) + pointer == 36 then
					do
						if pointer + 2 == 6 then
				Stack[3] = Stack[2]
	if Stack[3] then
		Stack[2] = Stack[2][Constants[18]]
	end
	
		end
					end
				end
			end
		else
			if pointer * pointer <= 100 then
				if (pointer * pointer * 3) + pointer == 200 then
					do
						if pointer + 8 == 16 then
				Stack[6] = Stack[1][Stack[5]]
	
		end
					end
				elseif (pointer * pointer * 5) + pointer == 414 then
					do
						if (pointer + 21) > pointer then
			do
				if pointer * 2 + 7 == 25 then
					if pointer - 14 == -5 then
						if not Stack[6] then pointer = pointer + 1 end
				elseif pointer - 14 == 10 then
					Stack[5] = Env[7]
				end
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
					end
				elseif (pointer * pointer * 3) + pointer == 310 then
					do
						do
			if pointer * 2 - 6 == 14 then
					pointer = pointer + 1 
				end
		end
					end
				end
			else
				if (pointer * pointer) + 33 == 202 then
					do
						if pointer + 9 == 22 then
				Stack[1][Stack[5]] = Stack[6]
		end
					end
				elseif (pointer * pointer) + 13 == 134 then
					do
						if pointer + 10 == 21 then
			Temp[10] = 6
Temp[15] = Constants
Temp[7] = 1
Stack[Temp[10]] = Temp[15][Temp[7]]
		end
					end
				elseif (pointer * pointer * 5) + pointer == 732 then
					do
						do
			if pointer + 5 == 17 then
						Stack[6] = Stack[6] + Constants[20]
				end
		end
					end
				end
			end
		end
	else
		if pointer * pointer <= 361 then
			if (pointer * pointer) + (2 * pointer) <= 288 then
				if (pointer * pointer) + (12 * pointer) == 448 then
					do
						if (pointer - 41) > pointer then
			Stack[8] = (1 == 1)
		else
			do
				if pointer + 12 == 44 then
					Stack[5] = nil
				end
				if pointer * 2 - 1 == 31 then
					if pointer * 2 - 1 == 31 then
						Stack[2] = {}
				end
				end
			end
		end
					end
				elseif (pointer * pointer * 2) + pointer == 406 then
					do
						if pointer + 6 == 20 then
			    local r1 = Stack[2](Stack[3], Stack[4])
    Stack[5] = r1
    if Stack[5] ~= nil then
        Stack[4] = Stack[5]
    else
        pointer = pointer + 1
    end
    
		end
					end
				elseif (pointer * pointer) + (10 * pointer) == 375 then
					do
						if (pointer + 68) > pointer then
			do
				if pointer - 10 == 5 then
					if pointer + 15 == 43 then
					Stack[6] = nil
				end
				if pointer - 2 == 13 then
					pointer = pointer + -8 
				end
				end
			end
		else
			Temp[1] = 3
			Temp[8] = Constants
			Temp[13] = 14
			Stack[Temp[17]] = Temp[11][Temp[4]]
		end
					end
				end
			else
				if (pointer * pointer * 2) + pointer == 595 then
					do
						if pointer + 6 == 23 then
			Temp[16] = 3
Temp[3] = 13
Temp[13] = Constants[Temp[3]]
Stack[Temp[16]] = vmEnv[Temp[13]] or Env[Temp[13]]
		end
					end
				elseif (pointer * 8) + (pointer * 16) == 456 then
					do
						do
			if pointer - 12 == 7 then
					if pointer * 2 - 4 == 34 then
					if pointer + 4 == 23 then
						Stack[3], Stack[4], Stack[5] = Stack[3](Stack[4])
				end
				end
				end
		end
					end
				elseif (pointer * pointer) + 31 == 355 then
					do
						if (pointer + 38) > pointer then
			do
				if pointer * 3 - 14 == 40 then
					if pointer - 9 == 9 then
					if pointer + 4 == 22 then
					Temp[15] = 4
Temp[12] = 1
Stack[Temp[15]] = Stack[Temp[12]]
				end
				elseif pointer - 9 == 18 then
					Stack[3] = Env[6]
				end
				else
					Stack[7] = nil
				end
			end
		else
						Temp[10] = vmEnv
			Temp[20] = 14
			Temp[20] = Constants[Temp[16]]
			Temp[16] = 19
			Temp[12][Temp[12]] = Temp[8]
		end
					end
				end
			end
		else
			if (pointer * 10) + pointer <= 242 then
				if (pointer * pointer) + 20 == 461 then
					do
						if pointer + 3 == 24 then
				Stack[7] = #Stack[2]
		end
					end
				elseif (pointer * pointer) + (10 * pointer) == 704 then
					do
						if pointer + 9 == 31 then
				Stack[7] = Stack[7] + Constants[20]
		end
					end
				elseif (pointer * pointer * 5) + pointer == 2020 then
					do
						do
			if pointer * 2 + 9 == 49 then
					if pointer * 2 - 6 == 34 then
					pointer = pointer + 3 
				end
				end
		end
					end
				end
			else
				if (pointer * pointer * 3) + pointer == 1610 then
					do
						do
			if pointer + 11 ~= 47 then
						Stack[2][Stack[7]] = Stack[6]
				end
		end
					end
				elseif (pointer * pointer) + 38 == 714 then
					do
						do
			if pointer + 12 == 41 then
					Stack[8] = nil
				end
				Temp[14] = 3
Temp[5] = 14
Temp[4] = Constants[Temp[5]]
Stack[Temp[14]] = vmEnv[Temp[4]] or Env[Temp[4]]
	Stack[3] = Stack[3][Constants[10]]
	
	pointer = pointer + 1
		end
					end
				elseif (pointer * 11) + (pointer * 13) == 600 then
					do
						if pointer + 9 == 34 then
			pointer = pointer + -5 
		end
					end
				elseif (pointer * pointer) + (6 * pointer) == 720 then
					do
						if pointer + 3 == 27 then
			    local r1 = Stack[3](Stack[4], Stack[5])
    Stack[6] = r1
    if Stack[6] ~= nil then
        Stack[5] = Stack[6]
    else
        pointer = pointer + 1
    end
    
		end
					end
				end
			end
		end
	end
else
	if (pointer * 13) + pointer <= 588 then
		if (pointer * pointer) + (9 * pointer) <= 1462 then
			if (pointer * 11) + pointer <= 372 then
				if (pointer * pointer) + (4 * pointer) == 1085 then
					do
						if (pointer + 10) > pointer then
			do
				if pointer + 1 ~= 39 then
					if pointer * 3 - 10 == 83 then
						Stack[3](Stack[4], Stack[5])
				else
					Stack[1] = nil
				end
				end
			end
		else
			Stack[5] = -Stack[7]
		end
					end
				elseif (pointer * pointer * 2) + pointer == 1596 then
					do
						do
			if pointer - 15 == 13 then
					if pointer + 3 ~= 44 then
					Temp[14] = 4
Temp[12] = 2
Stack[Temp[14]] = Stack[Temp[12]]
				end
				end
		end
					end
				elseif (pointer * pointer * 4) + pointer == 3393 then
					do
						if (pointer + 37) > pointer then
			do
				if pointer * 2 - 1 == 57 then
					if pointer - 8 == 21 then
					if pointer + 10 == 39 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[13] then
		C1 = {}
		local encoded = {(decrypt("\123\085\084\083\082\092\111", "2916")),((decrypt("\017\020\025\018", "930"))),(decrypt("\124\111\086\084\082\082\107", "2756")),(decrypt("\114\085\082\095\089\012\080\104\110\107", "2053")),((decrypt("\026\029\024\028\021\023", "2842"))),(decrypt("\008\083\083\082\110\090\093\001\104\094\086\095\087\127\106\080\095\085\108\101", "2569")),}

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
		if (pointer * 6) + pointer <= 70 then
	if (pointer * 13) + pointer <= 70 then
		if (pointer * pointer) + (11 * pointer) <= 26 then
			if (pointer * pointer * 5) + pointer == 6 then
				do
					if (pointer + 57) > pointer then
			do
				if pointer - 2 == -1 then
					if pointer * 3 - 4 == -1 then
					if pointer * 2 + 7 == 9 then
						Stack[2] = Upvalues[0]
				end
				else
					Stack[1] = nil
				end
				end
			end
		else
			if pointer > 147 then Stack[8] = Stack[8] end
		end
				end
			elseif (pointer * pointer) + 44 == 48 then
				do
					if pointer + 7 == 9 then
				Stack[2] = Stack[2][Stack[0]]
	
		end
				end
			end
		else
			if (pointer * pointer) + 10 == 35 then
				do
					if (pointer + 88) > pointer then
			do
				if pointer * 2 - 8 == 2 then
					if pointer - 13 == -8 then
						if Stack[2] ~= Stack[3] then pointer = pointer + 1 end
				elseif pointer - 13 == -1 then
					Stack[1] = Env[6]
				end
				end
			end
		else
			Stack[6] = Stack[4] or Constants[8+1]
		end
				end
			elseif (pointer * pointer * 5) + pointer == 84 then
				do
					if pointer + 6 == 10 then
				Stack[3] = Stack[3][Stack[1]]
	
		end
				end
			elseif (pointer * pointer * 2) + pointer == 21 then
				do
					if pointer + 2 == 5 then
				Stack[3] = Upvalues[0]
		end
				end
			end
		end
	else
		if (pointer * pointer) + (10 * pointer) <= 119 then
			if (pointer * pointer * 5) + pointer == 252 then
				do
					if pointer + 1 == 8 then
				Stack[2] = Upvalues[0]
		end
				end
			elseif (pointer * pointer) + (14 * pointer) == 120 then
				do
					if (pointer - 37) > pointer then
			Temp[4] = 3
			Temp[11] = Constants
			Temp[15] = 20
			Stack[Temp[12]] = Temp[13][Temp[17]]
		else
			do
				if pointer * 3 - 15 == 3 then
					if pointer * 2 + 4 == 16 then
					pointer = pointer + 9 
				end
				else
					Stack[1] = nil
				end
			end
		end
				end
			end
		else
			if (pointer * pointer) + (7 * pointer) == 170 then
				do
					do
			if pointer - 2 == 8 then
					if pointer * 2 + 9 == 29 then
					if pointer + 13 == 23 then
						Stack[3] = Stack[3][Stack[1]]
	
				end
				end
				end
		end
				end
			elseif (pointer * pointer) + 18 == 82 then
				do
					do
			if pointer + 2 == 10 then
					if pointer + 6 == 30 then
					Stack[8] = nil
				end
				if pointer - 7 == 1 then
						Stack[2] = Stack[2][Stack[0]]
	
				end
				end
		end
				end
			elseif (pointer * 2) + (pointer * 41) == 387 then
				do
					if pointer + 7 == 16 then
				Stack[3] = Upvalues[0]
		end
				end
			end
		end
	end
else
	if (pointer * pointer) + (3 * pointer) <= 270 then
		if pointer * pointer <= 144 then
			if (pointer * pointer) + (2 * pointer) == 168 then
				do
					if pointer + 3 == 15 then
			pointer = pointer + 1 
		end
				end
			elseif (pointer * 15) + (pointer * 26) == 451 then
				do
					if (pointer + 21) > pointer then
			do
				if pointer * 2 - 4 == 18 then
					if pointer * 2 - 6 == 16 then
						if Stack[3] > Stack[2] then pointer = pointer + 1 end
				end
				end
			end
		else
			Stack[6] = -Stack[3]
		end
				end
			end
		else
			if (pointer * pointer * 5) + pointer == 1140 then
				do
					if pointer + 14 == 29 then
				return Stack[2]
		end
				end
			elseif (pointer * pointer) + (9 * pointer) == 322 then
				do
					do
			if pointer * 3 - 9 == 33 then
					if pointer + 6 == 20 then
					Temp[16] = 2
Temp[6] = ttostring ~= __metatable
Stack[Temp[16]] = Temp[7]
				end
				else
					Stack[1] = nil
				end
		end
				end
			elseif (pointer * pointer) + 33 == 202 then
				do
					if pointer + 13 == 26 then
			Temp[8] = 2
Temp[15] = byte == pairs
Stack[Temp[8]] = Temp[5]\n\tpointer = pointer + 1
		end
				end
			end
		end
	else
		if (pointer * 7) + pointer <= 144 then
			if (pointer * 2) + (pointer * 15) == 306 then
				do
					do
			if pointer - 8 == 10 then
					Temp[6] = 2
Temp[14] = byte == pairs
Stack[Temp[6]] = Temp[5]\n\tpointer = pointer + 1
				end
		end
				end
			elseif (pointer * 11) + (pointer * 20) == 527 then
				do
					if pointer + 5 == 22 then
			pointer = pointer + 1 
		end
				end
			elseif (pointer * 14) + (pointer * 6) == 320 then
				do
					if pointer + 10 == 26 then
				if Stack[0] > Stack[1] then pointer = pointer + 1 end
		end
				end
			end
		else
			if (pointer * pointer * 4) + pointer == 1620 then
				do
					if (pointer - 31) > pointer then
			if pointer > 148 then Stack[1] = Stack[1] end
		else
			do
				if pointer * 2 - 4 == 36 then
					if pointer - 2 == 18 then
					if pointer * 2 + 9 == 49 then
						return Stack[2]
				end
				end
				end
			end
		end
				end
			elseif (pointer * pointer) + 32 == 393 then
				do
					do
			if pointer * 3 - 4 == 53 then
					if pointer * 2 + 4 == 42 then
					if pointer - 1 == 18 then
					Temp[3] = 2
Temp[16] = ttostring ~= __metatable
Stack[Temp[3]] = Temp[12]
				elseif pointer - 1 == 21 then
					Stack[1] = Env[7]
				end
				end
				else
					Stack[1] = nil
				end
		end
				end
			elseif (pointer * pointer) + 22 == 463 then
				do
					if (pointer - 87) > pointer then
			if pointer > 176 then Stack[8] = Stack[8] end
		else
			do
				if pointer * 2 + 8 == 50 then
					if pointer * 3 - 5 == 58 then
					if pointer + 4 == 30 then
					Stack[3] = nil
				end
					return
				else
					Stack[7] = nil
				end
				end
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
			Stack[4] = -Stack[3]
		end
					end
				end
			else
				if (pointer * pointer) + 11 == 1035 then
					do
						if (pointer + 10) > pointer then
			do
				if pointer + 14 ~= 50 then
						Stack[3] = {}
				end
			end
		else
			Stack[7] = Stack[7] or Constants[4+1]
		end
					end
				elseif (pointer * 7) + (pointer * 42) == 1666 then
					do
						do
			if pointer * 3 - 8 == 94 then
					Temp[4] = 5
Temp[10] = 9
Temp[8] = Constants[Temp[10]]
Stack[Temp[4]] = vmEnv[Temp[8]] or Env[Temp[8]]
	Stack[5] = Stack[5][Constants[12]]
	
	pointer = pointer + 1
				else
					Stack[4] = nil
				end
		end
					end
				elseif (pointer * pointer) + 12 == 1101 then
					do
						if (pointer + 17) > pointer then
			do
				if pointer * 2 + 7 == 73 then
					if pointer * 2 + 2 == 68 then
					if pointer - 3 == 30 then
					Temp[1] = 4
Temp[3] = Constants
Temp[5] = 20
Stack[Temp[1]] = Temp[3][Temp[5]]
				elseif pointer - 3 == 40 then
					Stack[2] = Env[3]
				end
				end
				end
			end
		else
			Stack[4] = Stack[1] or Constants[6+1]
		end
					end
				end
			end
		else
			if (pointer * pointer) + (3 * pointer) <= 1558 then
				if (pointer * pointer) + (3 * pointer) == 1404 then
					do
						if pointer + 6 == 42 then
			Temp[10] = 6
Temp[6] = Constants
Temp[9] = 6
Stack[Temp[10]] = Temp[6][Temp[9]]
		end
					end
				elseif (pointer * pointer) + 32 == 1401 then
					do
						do
			if pointer * 3 - 7 == 104 then
						Stack[7] = #Stack[2]
				else
					Stack[1] = nil
				end
		end
					end
				elseif (pointer * 8) + (pointer * 37) == 1710 then
					do
						if pointer + 3 == 41 then
				Stack[5] = Stack[5](Stack[6], Stack[7])
		end
					end
				end
			else
				if (pointer * 10) + (pointer * 17) == 1053 then
					do
						if (pointer + 73) > pointer then
			do
				if pointer + 10 ~= 58 then
					if pointer + 2 == 41 then
					if pointer + 3 == 42 then
					Temp[12] = 6
Temp[11] = Constants
Temp[1] = 20
Stack[Temp[12]] = Temp[11][Temp[1]]
				end
				end
				end
			end
		else
			if pointer > 121 then Stack[2] = Stack[3] end
		end
					end
				elseif (pointer * pointer) + 46 == 1727 then
					do
						do
			if pointer - 3 == 38 then
					if pointer * 3 - 1 == 122 then
						Stack[8] = #Stack[3]
				else
					Stack[7] = nil
				end
				end
		end
					end
				elseif (pointer * pointer * 4) + pointer == 6440 then
					do
						do
			if pointer * 2 - 10 == 70 then
					if pointer + 7 == 47 then
					    Stack[4] = Stack[4] - Stack[6]
    pointer = pointer + 8
    
				end
				end
		end
					end
				elseif (pointer * 14) + (pointer * 25) == 1638 then
					do
						if (pointer + 22) > pointer then
			do
				if pointer - 10 == 32 then
					if pointer * 3 - 13 == 113 then
						Stack[8] = Stack[8] + Constants[20]
				else
					Stack[7] = nil
				end
				elseif pointer - 10 == 43 then
					Stack[4] = Env[8]
				end
			end
		else
			Stack[7] = nil
		end
					end
				end
			end
		end
	else
		if pointer * pointer <= 2304 then
			if (pointer * pointer) + (12 * pointer) <= 2565 then
				if (pointer * 4) + (pointer * 21) == 1100 then
					do
						if (pointer + 28) > pointer then
			do
				if pointer * 2 - 7 == 81 then
					if pointer + 1 == 45 then
					if pointer + 4 ~= 51 then
					Temp[8] = 10
Temp[7] = Constants
Temp[1] = 15
Stack[Temp[8]] = Temp[7][Temp[1]]
				end
				end
				end
			end
		else
			Temp[12] = 1
			Temp[16] = Constants
			Temp[15] = 20
			Stack[Temp[20]] = Temp[17][Temp[13]]
		end
					end
				elseif (pointer * pointer * 2) + pointer == 3741 then
					do
						if (pointer + 45) > pointer then
			do
				if pointer - 7 == 36 then
						Stack[9] = Stack[2][Stack[7]]
	
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
					end
				elseif (pointer * pointer) + (11 * pointer) == 2520 then
					do
						if (pointer - 47) > pointer then
			Stack[6] = (0 == 1)
		else
			do
				if pointer - 6 == 39 then
					if pointer * 3 - 4 == 131 then
						Stack[11] = Stack[2][Stack[7]]
	
				else
					Stack[8] = nil
				end
				elseif pointer - 6 == 59 then
					Stack[3] = Env[5]
				end
			end
		end
					end
				end
			else
				if (pointer * pointer) + (11 * pointer) == 2832 then
					do
						do
			if pointer * 2 + 2 == 98 then
						Stack[3][Stack[8]] = Stack[9]
				end
		end
					end
				elseif (pointer * 15) + (pointer * 26) == 1927 then
					do
						if pointer + 15 == 62 then
				Temp[1] = ""
	for i = 9, 11 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[9] = Temp[1]
	
		end
					end
				elseif (pointer * 6) + (pointer * 29) == 1610 then
					do
						if (pointer + 46) > pointer then
			do
				if pointer * 3 - 10 == 128 then
					if pointer * 3 - 4 == 134 then
						Stack[11] = Stack[1][Stack[11]]
	
				else
					Stack[4] = nil
				end
				else
					Stack[4] = nil
				end
			end
		else
			if pointer > 61 then Stack[5] = Stack[2] end
		end
					end
				end
			end
		else
			if (pointer * 3) + pointer <= 208 then
				if (pointer * 8) + (pointer * 44) == 2548 then
					do
						if pointer + 15 == 64 then
			    Stack[4] = Stack[4] + Stack[6]
    if (Stack[6] > 0 and Stack[4] <= Stack[5]) or (Stack[6] <= 0 and Stack[4] >= Stack[5]) then
        pointer = pointer + -9
        Stack[7] = Stack[4]
    end
    
		end
					end
				elseif (pointer * pointer * 4) + pointer == 10050 then
					do
						if pointer + 3 == 53 then
			Temp[6] = 4
Temp[1] = 14
Temp[15] = Constants[Temp[1]]
Stack[Temp[6]] = vmEnv[Temp[15]] or Env[Temp[15]]
	Stack[4] = Stack[4][Constants[19]]
	
	pointer = pointer + 1
		end
					end
				elseif (pointer * pointer) + 25 == 2729 then
					do
						if pointer + 7 == 59 then
			Temp[12] = 5
Temp[16] = 3
Stack[Temp[12]] = Stack[Temp[16]]
		end
					end
				end
			else
				if (pointer * pointer * 5) + pointer == 14098 then
					do
						do
			if pointer * 2 - 8 == 98 then
					if pointer + 3 == 56 then
					Temp[1] = 6
Temp[9] = Constants
Temp[15] = 16
Stack[Temp[1]] = Temp[9][Temp[15]]
				end
				end
		end
					end
				elseif (pointer * pointer) + 27 == 3052 then
					do
						if (pointer + 81) > pointer then
			do
				if pointer + 3 == 58 then
					            Temp[1] = {}
            Temp[2] = 0
            for i = 4, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
        
				end
			end
		else
			Stack[5] = (1 == 1)
		end
					end
				elseif (pointer * pointer * 3) + pointer == 8802 then
					do
						do
			if pointer * 2 + 5 == 113 then
					if pointer * 2 + 7 == 115 then
					if pointer * 2 + 10 == 118 then
						return Stack[4](Stack[5], Stack[6])
				end
				end
				end
		end
					end
				elseif (pointer * pointer * 5) + pointer == 15736 then
					do
						if pointer + 13 == 69 then
				return
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
			else
				if pointer * pointer <= 6241 then
					if (pointer * pointer) + (5 * pointer) == 6474 then
						do
							if pointer + 15 == 93 then
			Temp[10] = 6
Temp[5] = 4
Temp[16] = Constants[Temp[5]]
Stack[Temp[10]] = vmEnv[Temp[16]] or Env[Temp[16]]
		end
						end
					elseif (pointer * 2) + (pointer * 27) == 2291 then
						do
							if (pointer + 41) > pointer then
			do
				if pointer * 2 + 10 == 168 then
					if pointer * 2 - 6 == 152 then
					Temp[6] = 7
Temp[3] = 5
Stack[Temp[6]] = Stack[Temp[3]]
				end
				end
			end
		else
			Temp[10] = 5
			Temp[6] = Constants
			Temp[19] = 18
			Stack[Temp[20]] = Temp[5][Temp[15]]
		end
						end
					end
				else
					if (pointer * pointer) + 45 == 6934 then
						do
							if pointer + 3 == 86 then
				return
		end
						end
					elseif (pointer * pointer) + (10 * pointer) == 7544 then
						do
							do
			if pointer * 3 - 2 == 244 then
					if pointer - 13 == 69 then
						Temp[1] = {}
	for i = 6 + 1, top do
		Temp[1][i - 6] = Stack[i]
	end
	Temp[2] = {Stack[6](unpack(Temp[1], 1, top - 6))}
		for i = 1, 0 do
		Stack[6 + i - 1] = Temp[2][i]
	end
	
	
				elseif pointer - 13 == 85 then
					Stack[6] = Env[2]
				end
				else
					Stack[4] = nil
				end
		end
						end
					elseif (pointer * pointer) + 17 == 6417 then
						do
							do
			if pointer - 15 == 65 then
					if pointer - 13 == 67 then
					Temp[5] = 8
Temp[6] = Constants
Temp[16] = 17
Stack[Temp[5]] = Temp[6][Temp[16]]
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
				elseif pointer - 13 == 73 then
					Stack[5] = Env[1]
				end
				elseif pointer - 15 == 83 then
					Stack[8] = Env[6]
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