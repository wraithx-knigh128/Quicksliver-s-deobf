return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\031\016\060", "777")),(decrypt("\104\094\084\104\106\083", "2812")),(decrypt("\025\062", "2513")),(decrypt("\089\096\104\085\110", "2816")),(decrypt("\029\057", "120")),(decrypt("\008\094\090\101\117\096\105\091\106\102\111\083", "2839")),(decrypt("\024\051", "2843")),(decrypt("\096\117\015\011\127\124\012\011\125\010\008", "636")),(decrypt("\124\085\090\085\088\084\107\109\110", "2337")),(decrypt("\025\019\061", "2464")),(decrypt("\024\021\051", "2280")),((decrypt("\021\023\023", "900"))),(decrypt("\018", "1053")),(decrypt("\024\062", "1598")),(decrypt("\085\089\083\082\089", "2037")),(decrypt("\016\062", "859")),(decrypt("\123\110\080\083\082\104\111\091\110\105\125\091\084\091\111\110\110", "2270")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
				if (pointer * 14) + pointer <= 615 then
	if (pointer * 2) + pointer <= 60 then
		if (pointer * pointer) + (15 * pointer) <= 250 then
			if (pointer * pointer) + (4 * pointer) <= 32 then
				if (pointer * pointer) + (6 * pointer) == 7 then
					do
						if pointer + 15 == 16 then
			Temp[5] = 0
Temp[14] = ttostring ~= __metatable
Stack[Temp[5]] = Temp[12]
		end
					end
				elseif (pointer * pointer) + (10 * pointer) == 56 then
					do
						if pointer + 8 == 12 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\002\091\089\083\082\099\096\081", "829")),(decrypt("\013\086\090\110\111\083\106\109", "660")),(decrypt("\123\110\098\094\084\105\082", "1288")),}

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
		if (pointer * pointer) + 16 == 41 then
	do
		if (pointer - 89) > pointer then
			Temp[1] = 2
			Temp[5] = Constants
			Temp[3] = 7
			Stack[Temp[4]] = Temp[18][Temp[14]]
		else
			do
				if pointer + 13 == 18 then
						return Stack[2]
				end
			end
		end
	end
elseif (pointer * pointer * 3) + pointer == 114 then
	do
		do
			if pointer + 6 ~= 20 then
					if pointer * 3 - 12 == 6 then
						return
				else
					Stack[7] = nil
				end
				end
		end
	end
elseif (pointer * pointer * 5) + pointer == 6 then
	do
		if (pointer + 50) > pointer then
			do
				if pointer * 3 - 2 == 1 then
						Stack[1] = {}
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
elseif (pointer * pointer) + 45 == 49 then
	do
		if (pointer + 73) > pointer then
			do
				if pointer - 3 == -1 then
					if pointer + 7 ~= 11 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[12] then
		C1 = {}
		local encoded = {(decrypt("\120\121\010", "1329")),(decrypt("\087\085\084\054", "2570")),(decrypt("\109\093\092\085\092\006\020\016", "267")),}

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
		if (pointer * 11) + pointer <= 72 then
	if pointer * pointer <= 9 then
		if (pointer * pointer) + (15 * pointer) == 34 then
			do
				do
			if pointer + 15 == 17 then
					if pointer + 14 ~= 29 then
						Stack[1] = Stack[1][Stack[0]]
	
				end
				end
		end
			end
		elseif (pointer * 3) + (pointer * 45) == 144 then
			do
				if (pointer - 48) > pointer then
			Stack[3] = (1 == 1)
		else
			do
				if pointer - 10 == -7 then
					if pointer + 12 == 15 then
						if Stack[1] == Constants[2] then pointer = pointer + 1 end
				end
				elseif pointer - 10 == 10 then
					Stack[6] = Env[7]
				end
			end
		end
			end
		elseif (pointer * pointer) + (12 * pointer) == 13 then
			do
				if (pointer + 72) > pointer then
			do
				if pointer - 1 == 0 then
						Stack[1] = Upvalues[0]
				end
			end
		else
			Temp[7] = 3
			Temp[1] = Constants
			Temp[17] = 5
			Stack[Temp[11]] = Temp[1][Temp[16]]
		end
			end
		end
	else
		if (pointer * pointer * 5) + pointer == 130 then
			do
				if (pointer - 7) > pointer then
			if pointer > 124 then Stack[1] = Stack[2] end
		else
			do
				if pointer + 9 ~= 27 then
					if pointer * 3 - 13 == 2 then
					if pointer - 8 == -3 then
						Stack[2] = Upvalues[1]
				end
				else
					Stack[5] = nil
				end
				end
			end
		end
			end
		elseif (pointer * pointer) + (13 * pointer) == 114 then
			do
				if pointer + 12 == 18 then
			Temp[3] = 3
Temp[14] = 0
Stack[Temp[3]] = Stack[Temp[14]]
		end
			end
		elseif (pointer * 8) + (pointer * 20) == 112 then
			do
				if (pointer + 46) > pointer then
			do
				if pointer * 3 - 4 == 8 then
					if pointer - 8 == -4 then
					pointer = pointer + 6 
				end
				else
					Stack[2] = nil
				end
			end
		else
			Stack[7] = Stack[4] or Constants[6+1]
		end
			end
		end
	end
else
	if pointer * pointer <= 81 then
		if (pointer * pointer * 3) + pointer == 252 then
			do
				if (pointer + 66) > pointer then
			do
				if pointer + 10 == 22 then
					Stack[7] = nil
				end
				if pointer + 3 ~= 18 then
						Stack[2] = Upvalues[0]
				end
			end
		else
			if pointer > 87 then Stack[5] = Stack[8] end
		end
			end
		elseif (pointer * pointer) + 49 == 98 then
			do
				if pointer + 1 == 8 then
				Stack[2] = Stack[2](Stack[3])
		end
			end
		elseif (pointer * pointer) + 9 == 73 then
			do
				do
			if pointer + 5 ~= 15 then
					if pointer + 10 == 18 then
					Temp[1] = 1
Temp[9] = 2
Stack[Temp[1]] = Stack[Temp[9]]
				end
				end
		end
			end
		end
	else
		if (pointer * pointer * 3) + pointer == 444 then
			do
				if pointer + 2 == 14 then
				return
		end
			end
		elseif (pointer * 9) + (pointer * 46) == 605 then
			do
				if pointer + 2 == 13 then
				return Stack[1]
		end
			end
		elseif (pointer * pointer) + 38 == 138 then
			do
				if pointer + 11 == 21 then
				Stack[2][Stack[0]] = Stack[1]
		end
			end
		end
	end
end
		pointer = pointer+1
		end
	end

				end
				elseif pointer - 3 == 6 then
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
		pointer = pointer+1
		end
	end

		end
					end
				elseif (pointer * 10) + (pointer * 48) == 174 then
					do
						if (pointer + 78) > pointer then
			do
				if pointer * 2 - 8 == -2 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\015\080\082\089\088\111\107\098", "2079")),(decrypt("\121\109\091\108\085\087\081\091\120\109\081\093\082\107\100", "2180")),}

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
		if (pointer * pointer) + 26 == 27 then
	do
		do
			if pointer + 5 == 6 then
					if pointer - 6 == -5 then
					if pointer * 2 - 1 == 1 then
					Temp[6] = 2
Temp[15] = 0
Stack[Temp[6]] = Stack[Temp[15]]
				end
				end
				end
		end
	end
elseif (pointer * 2) + (pointer * 38) == 240 then
	do
		if (pointer + 81) > pointer then
			do
				if pointer * 2 - 10 == 2 then
					if pointer + 7 == 29 then
					Stack[7] = nil
				end
					return
				end
			end
		else
			Stack[4] = -Stack[5]
		end
	end
elseif (pointer * 4) + (pointer * 10) == 70 then
	do
		if pointer + 3 == 8 then
				return Stack[3]
		end
	end
elseif (pointer * 9) + (pointer * 22) == 62 then
	do
		if pointer + 4 == 6 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[11] then
		C1 = {}
		local encoded = {((decrypt("\028\022\026\025\027\027\028", "1336"))),((decrypt("\030\023\024", "2022"))),(decrypt("\123\107\082\110\082\082\086\083\108", "2766")),(decrypt("\014\090\094\080\123\109\092\090\081\107\105", "1157")),(decrypt("\117\094\082\109\110\093\094\087\087\105", "2747")),(decrypt("\011\085\082\082\106\085\090\084", "1341")),}

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
		if pointer * pointer <= 9 then
	if (pointer * pointer * 4) + pointer == 5 then
		do
			do
			if pointer + 5 ~= 10 then
					if pointer + 7 == 16 then
					Stack[2] = nil
				end
					Stack[0] = Upvalues[0]
				end
		end
		end
	elseif (pointer * pointer * 3) + pointer == 14 then
		do
			if (pointer - 77) > pointer then
						Temp[5] = vmEnv
			Temp[4] = 10
			Temp[1] = Constants[Temp[5]]
			Temp[14] = 5
			Temp[5][Temp[5]] = Temp[10]
		else
			do
				if pointer + 12 == 14 then
					if pointer * 2 + 5 == 9 then
						Stack[1] = Upvalues[1]
				end
				end
			end
		end
		end
	elseif (pointer * 5) + (pointer * 12) == 51 then
		do
			if (pointer + 60) > pointer then
			do
				if pointer * 2 - 5 == 1 then
					if pointer + 15 ~= 38 then
					if pointer * 3 - 13 == -4 then
						Stack[0] = Stack[0] + Stack[1]
				else
					Stack[6] = nil
				end
				end
				end
			end
		else
			Stack[7] = -Stack[5]
		end
		end
	end
else
	if (pointer * 15) + (pointer * 41) == 224 then
		do
			if pointer + 3 == 7 then
				Upvalues[0] = Stack[0]
		end
		end
	elseif (pointer * pointer) + 24 == 49 then
		do
			do
			if pointer * 2 + 1 == 11 then
						Stack[0] = Upvalues[0]
				end
		end
		end
	elseif (pointer * 13) + (pointer * 45) == 406 then
		do
			if pointer + 15 == 22 then
				return
		end
		end
	elseif (pointer * pointer * 2) + pointer == 78 then
		do
			if (pointer + 95) > pointer then
			do
				if pointer + 7 ~= 18 then
					if pointer * 2 + 7 == 19 then
						return Stack[0]
				end
				end
			end
		else
						Temp[16] = vmEnv
			Temp[6] = 18
			Temp[18] = Constants[Temp[3]]
			Temp[5] = 10
			Temp[11][Temp[10]] = Temp[18]
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
		pointer = pointer+1
		end
	end

				end
			end
		else
			Stack[5] = Stack[8] or Constants[2+1]
		end
					end
				elseif (pointer * pointer) + 40 == 44 then
					do
						do
			if pointer * 2 + 12 == 16 then
					Temp[7] = vmEnv
Temp[5] = 8
Temp[12] = Constants[Temp[5]]
Temp[2] = 0
Temp[7][Temp[12]] = Temp[12]
				end
		end
					end
				end
			else
				if pointer * pointer <= 36 then
					if (pointer * pointer) + (9 * pointer) == 90 then
						do
							do
			if pointer * 3 - 9 == 9 then
					if pointer - 2 == 4 then
					Temp[15] = 3
Temp[11] = 1
Stack[Temp[15]] = Stack[Temp[11]]
				elseif pointer - 2 == 15 then
					Stack[3] = Env[5]
				end
				else
					Stack[1] = nil
				end
		end
						end
					elseif (pointer * pointer * 4) + pointer == 105 then
						do
							if pointer + 9 == 14 then
				Stack[2], Stack[3], Stack[4] = nil
		end
						end
					end
				else
					if (pointer * 11) + (pointer * 21) == 288 then
						do
							if pointer + 1 == 10 then
				Stack[3] = Stack[3](Stack[4])
		end
						end
					elseif (pointer * 12) + (pointer * 43) == 550 then
						do
							do
			if pointer * 3 - 6 == 24 then
					if pointer - 3 == 7 then
					Temp[5] = 2
Temp[1] = 3
Stack[Temp[5]] = Stack[Temp[1]]
				elseif pointer - 3 == 13 then
					Stack[2] = Env[2]
				end
				else
					Stack[3] = nil
				end
		end
						end
					elseif (pointer * pointer) + (8 * pointer) == 105 then
						do
							if pointer + 14 == 21 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\117\111\110\093", "633")),(decrypt("\015\086\067\081\087\107", "2531")),(decrypt("\004\096\082\090\100\105", "982")),(decrypt("\027\058", "311")),(decrypt("\029\056", "435")),(decrypt("\110\095\093\082\091\005\016\019\106\084\092\111\087\093\109\016\107\082\082\019\105\083\086\019\095\104\111\106\087\082\084\095\023\028\029\018\022\029\030\025\028\025\026\019\064\109\095\069\087\110\103\015\085\089\092\107\123\028\070\125\116\080\028\068\011\087\114\126\014\025\111\116\110\004\009\011\105\101\026\082\025\121\127\105\111\108\085", "1465")),}

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
		if pointer * pointer <= 36 then
	if pointer * pointer <= 9 then
		if (pointer * pointer) + 38 == 42 then
			do
				if pointer + 2 == 4 then
			pointer = pointer + 1 
		end
			end
		elseif (pointer * 15) + (pointer * 45) == 60 then
			do
				if (pointer - 95) > pointer then
			Stack[3] = nil
		else
			do
				if pointer + 11 == 18 then
					Stack[4] = nil
				end
					if Stack[0] < Constants[5] then pointer = pointer + 1 end
			end
		end
			end
		elseif (pointer * 10) + (pointer * 13) == 69 then
			do
				if (pointer + 75) > pointer then
			do
				if pointer + 6 == 9 then
						return Stack[0]
				end
			end
		else
			Stack[5] = nil
		end
			end
		end
	else
		if (pointer * pointer) + (13 * pointer) == 90 then
			do
				if (pointer - 19) > pointer then
			Stack[6] = (1 == 1)
		else
			do
				if pointer * 2 - 8 == 2 then
						Stack[2] = Stack[0] - Constants[4]
				end
			end
		end
			end
		elseif (pointer * 13) + (pointer * 37) == 200 then
			do
				if (pointer - 88) > pointer then
			if pointer > 170 then Stack[6] = Stack[6] end
		else
			do
				if pointer - 5 == -1 then
					if pointer + 4 ~= 13 then
					if pointer * 2 + 12 == 20 then
						Stack[1] = Upvalues[0]
				end
				end
				end
			end
		end
			end
		elseif (pointer * 12) + (pointer * 37) == 294 then
			do
				do
			if pointer - 15 == -9 then
						Stack[1] = Stack[1](Stack[2])
				elseif pointer - 15 == 1 then
					Stack[6] = Env[1]
				end
		end
			end
		end
	end
else
	if (pointer * 15) + pointer <= 144 then
		if (pointer * pointer) + (8 * pointer) == 128 then
			do
				if (pointer - 52) > pointer then
			Stack[8] = nil
		else
			do
				if pointer - 3 == 5 then
						Stack[3] = Stack[0] - Constants[5]
				elseif pointer - 3 == 19 then
					Stack[5] = Env[4]
				end
			end
		end
			end
		elseif (pointer * pointer) + (4 * pointer) == 117 then
			do
				do
			if pointer - 8 == 1 then
						Stack[2] = Stack[2](Stack[3])
				elseif pointer - 8 == 21 then
					Stack[2] = Env[7]
				end
		end
			end
		elseif (pointer * pointer * 5) + pointer == 252 then
			do
				if (pointer + 7) > pointer then
			do
				if pointer * 2 + 8 == 22 then
					if pointer * 3 - 12 == 9 then
					if pointer + 5 ~= 32 then
						Stack[2] = Upvalues[0]
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
		if (pointer * pointer * 2) + pointer == 210 then
			do
				if pointer + 3 == 13 then
				Stack[1] = Stack[1] + Stack[2]
		end
			end
		elseif (pointer * pointer * 3) + pointer == 374 then
			do
				if pointer + 10 == 21 then
				return Stack[1]
		end
			end
		elseif (pointer * pointer) + (5 * pointer) == 204 then
			do
				if (pointer + 23) > pointer then
			do
				if pointer - 5 == 7 then
						return
				end
			end
		else
						Temp[12] = vmEnv
			Temp[16] = 8
			Temp[14] = Constants[Temp[3]]
			Temp[5] = 14
			Temp[7][Temp[18]] = Temp[7]
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
		else
			if pointer * pointer <= 196 then
				if (pointer * pointer * 4) + pointer == 588 then
					do
						if pointer + 12 == 24 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[5] then
		C1 = {}
		local encoded = {((decrypt("\027\020\026\030\025\029\002", "1125"))),(decrypt("\117\083\092", "652")),(decrypt("\081\084\104\081\088\089", "1301")),(decrypt("\117\087\082\085\090\107\093", "1779")),(decrypt("\125\086\089\083\108", "905")),}

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
		if (pointer * 13) + pointer <= 98 then
	if pointer * pointer <= 9 then
		if (pointer * pointer * 3) + pointer == 14 then
			do
				if pointer + 11 == 13 then
			Temp[16] = 3
Temp[12] = 3
Temp[15] = Constants[Temp[12]]
Stack[Temp[16]] = vmEnv[Temp[15]] or Env[Temp[15]]
		end
			end
		elseif (pointer * 6) + (pointer * 32) == 38 then
			do
				if (pointer - 24) > pointer then
						Temp[2] = vmEnv
			Temp[13] = 18
			Temp[8] = Constants[Temp[13]]
			Temp[11] = 6
			Temp[11][Temp[11]] = Temp[1]
		else
			do
				if pointer * 3 - 12 == -9 then
					if pointer * 2 - 7 == -5 then
						Stack[2] = {}
				end
				else
					Stack[6] = nil
				end
			end
		end
			end
		elseif (pointer * 11) + (pointer * 17) == 84 then
			do
				if pointer + 6 == 9 then
			Temp[15] = 4
Temp[16] = 0
Stack[Temp[15]] = Stack[Temp[16]]
		end
			end
		end
	else
		if (pointer * pointer * 5) + pointer == 130 then
			do
				if pointer + 9 == 14 then
			pointer = pointer + 5 
		end
			end
		elseif (pointer * 10) + (pointer * 29) == 234 then
			do
				if (pointer + 68) > pointer then
			do
				if pointer - 1 == 5 then
					Temp[12] = 8
Temp[16] = 1
Stack[Temp[12]] = Stack[Temp[16]]
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
			end
		elseif (pointer * pointer * 2) + pointer == 105 then
			do
				if (pointer - 32) > pointer then
			Stack[5] = -Stack[1]
		else
			do
				if pointer + 5 == 20 then
					Stack[6] = nil
				end
				Temp[8] = 9
Temp[4] = 7
Stack[Temp[8]] = Stack[Temp[4]]
			end
		end
			end
		elseif (pointer * pointer) + 30 == 46 then
			do
				if pointer + 2 == 6 then
				Stack[3], Stack[4], Stack[5] = Stack[3](Stack[4])
		end
			end
		end
	end
else
	if (pointer * 10) + pointer <= 110 then
		if (pointer * pointer * 2) + pointer == 210 then
			do
				if pointer + 5 == 15 then
				Stack[2][Stack[6]] = Stack[8]
		end
			end
		elseif (pointer * 11) + (pointer * 27) == 342 then
			do
				do
			if pointer * 2 - 1 == 17 then
					if pointer - 3 == 6 then
					if pointer + 1 == 10 then
						Stack[8] = Stack[8](Stack[9], Stack[10])
				end
				elseif pointer - 3 == 10 then
					Stack[6] = Env[8]
				end
				end
		end
			end
		elseif (pointer * pointer) + 40 == 104 then
			do
				if pointer + 14 == 22 then
			Temp[3] = 10
Temp[10] = 6
Stack[Temp[3]] = Stack[Temp[10]]
		end
			end
		end
	else
		if (pointer * pointer) + (4 * pointer) == 192 then
			do
				if pointer + 10 == 22 then
			pointer = pointer + -7 
		end
			end
		elseif (pointer * pointer * 4) + pointer == 798 then
			do
				if (pointer - 83) > pointer then
			Stack[6] = (0 == 1)
		else
			do
				if pointer * 2 + 8 == 36 then
					if pointer * 2 + 1 == 29 then
						return
				end
				end
			end
		end
			end
		elseif (pointer * pointer) + 49 == 170 then
			do
				if pointer + 3 == 14 then
			    local r1, r2 = Stack[3](Stack[4], Stack[5])
    Stack[6] = r1
        Stack[7] = r2
    if Stack[6] ~= nil then
        Stack[5] = Stack[6]
    else
        pointer = pointer + 1
    end
    
		end
			end
		elseif (pointer * pointer * 4) + pointer == 689 then
			do
				do
			if pointer - 13 == 0 then
					if pointer * 3 - 3 == 36 then
					if pointer * 3 - 5 == 34 then
						return Stack[2]
				else
					Stack[1] = nil
				end
				else
					Stack[3] = nil
				end
				elseif pointer - 13 == 5 then
					Stack[6] = Env[2]
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
				elseif (pointer * 10) + (pointer * 8) == 198 then
					do
						if (pointer - 95) > pointer then
						Temp[2] = vmEnv
			Temp[1] = 4
			Temp[12] = Constants[Temp[14]]
			Temp[8] = 19
			Temp[15][Temp[6]] = Temp[6]
		else
			do
				if pointer + 12 == 23 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\009\107\108\082\105\107\109", "2764")),(decrypt("\117\085\084\109\083\089\110\039\083\094\104\082\105", "509")),(decrypt("\083\092\093\100", "851")),(decrypt("\089\109\089\095\020\110\093\080\081", "2164")),(decrypt("\098\088\104\087\105", "2844")),(decrypt("\124\104\090\089", "240")),}

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
		if (pointer * pointer) + (4 * pointer) <= 21 then
	if (pointer * pointer) + (15 * pointer) == 16 then
		do
			do
			if pointer * 3 - 13 == -10 then
					if pointer + 10 ~= 17 then
						Stack[1] = {}
				end
				else
					Stack[8] = nil
				end
		end
		end
	elseif (pointer * pointer) + (3 * pointer) == 10 then
		do
			if (pointer - 10) > pointer then
			Stack[6] = (1 == 1)
		else
			do
				if pointer + 14 ~= 36 then
					if pointer * 2 - 4 == 0 then
					if pointer + 11 ~= 32 then
						top = 2 + #Varargs - 1
	for i = 1, #Varargs do
		Stack[2 + i - 1] = Varargs[i]
	end
	
				end
				end
				end
			end
		end
		end
	elseif (pointer * pointer) + 46 == 55 then
		do
			do
			if pointer * 2 - 6 == 0 then
					if pointer - 3 == 0 then
					if pointer * 3 - 14 == -5 then
						local _limit = top - 1
	for i = 1, _limit do
		Stack[1][(1 - 1) * 50 + i] = Stack[1 + i]
	end
	
				else
					Stack[4] = nil
				end
				elseif pointer - 3 == 16 then
					Stack[5] = Env[1]
				end
				end
		end
		end
	end
else
	if (pointer * pointer) + (8 * pointer) == 84 then
		do
			do
			if pointer - 5 == 1 then
					if pointer - 10 == -4 then
					if pointer + 3 ~= 19 then
						return Stack[2]
				end
				end
				end
		end
		end
	elseif (pointer * pointer * 5) + pointer == 84 then
		do
			if (pointer - 28) > pointer then
						Temp[12] = vmEnv
			Temp[4] = 6
			Temp[4] = Constants[Temp[11]]
			Temp[16] = 2
			Temp[11][Temp[3]] = Temp[15]
		else
			do
				if pointer - 11 == -7 then
					if pointer - 3 == 1 then
					if pointer * 3 - 5 == 7 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[13] then
		C1 = {}
		local encoded = {(decrypt("\021\027\062", "1359")),(decrypt("\026\060", "2789")),(decrypt("\011\094\084\085\109\098\090\080\087\093\038\091\081\092\109\086\093\083", "1810")),(decrypt("\121\080\089\104\105\009\087\109\105\105", "265")),}

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
		if pointer * pointer <= 36 then
	if (pointer * 8) + pointer <= 27 then
		if (pointer * pointer) + 42 == 51 then
			do
				if (pointer + 91) > pointer then
			do
				if pointer + 3 ~= 15 then
					if pointer + 4 ~= 9 then
					Temp[16] = 2
Temp[9] = Constants
Temp[7] = 2
Stack[Temp[16]] = Temp[9][Temp[7]]
				end
				end
			end
		else
			Temp[1] = 3
			Temp[1] = Constants
			Temp[16] = 17
			Stack[Temp[15]] = Temp[16][Temp[11]]
		end
			end
		elseif (pointer * 15) + (pointer * 20) == 35 then
			do
				if (pointer - 10) > pointer then
			if (pointer * 2) < 0 then Env[1] = nil end
		else
			do
				if pointer + 3 == 4 then
					if pointer + 2 == 20 then
					Stack[2] = nil
				end
					Stack[1] = Upvalues[0]
				end
			end
		end
			end
		elseif (pointer * pointer) + (7 * pointer) == 18 then
			do
				do
			if pointer + 1 ~= 22 then
					if pointer * 3 - 14 == -8 then
					if pointer + 12 ~= 33 then
						Stack[1] = #Stack[1]
				end
				else
					Stack[8] = nil
				end
				end
		end
			end
		end
	else
		if (pointer * 15) + (pointer * 41) == 336 then
			do
				do
			if pointer * 2 + 1 == 13 then
						Stack[5] = Upvalues[0]
				end
		end
			end
		elseif (pointer * pointer) + 31 == 47 then
			do
				if (pointer - 73) > pointer then
			Stack[7] = nil
		else
			do
				if pointer + 12 ~= 32 then
					Temp[1] = 3
Temp[8] = Constants
Temp[13] = 1
Stack[Temp[1]] = Temp[8][Temp[13]]
				end
			end
		end
			end
		elseif (pointer * pointer) + 10 == 35 then
			do
				do
			if pointer - 3 == 2 then
					if pointer * 2 + 6 == 16 then
					    Stack[1] = Stack[1] - Stack[3]
    pointer = pointer + 5
    
				end
				elseif pointer - 3 == 5 then
					Stack[3] = Env[7]
				end
		end
			end
		end
	end
else
	if (pointer * 6) + pointer <= 63 then
		if (pointer * pointer * 3) + pointer == 200 then
			do
				do
			if pointer * 3 - 11 == 13 then
					if pointer * 2 + 10 == 26 then
					Temp[5] = 6
Temp[9] = 0
Stack[Temp[5]] = Stack[Temp[9]]
				end
				else
					Stack[6] = nil
				end
		end
			end
		elseif (pointer * 4) + (pointer * 20) == 216 then
			do
				if (pointer - 7) > pointer then
			Stack[7] = (1 == 1)
		else
			do
				if pointer * 2 - 2 == 16 then
					if pointer * 2 + 2 == 20 then
						Stack[5] = Stack[5](Stack[6])
				end
				end
			end
		end
			end
		elseif (pointer * pointer) + (3 * pointer) == 70 then
			do
				do
			if pointer - 5 == 2 then
					if pointer - 14 == -7 then
					if pointer + 15 ~= 25 then
						Stack[5] = Stack[5][Stack[4]]
	
				end
				elseif pointer - 14 == 8 then
					Stack[7] = Env[7]
				end
				end
		end
			end
		end
	else
		if (pointer * pointer * 2) + pointer == 351 then
			do
				if (pointer + 73) > pointer then
			do
				if pointer - 15 == -2 then
					if pointer + 9 == 36 then
					Stack[6] = nil
				end
				if pointer + 11 ~= 44 then
						return
				end
				elseif pointer - 15 == 17 then
					Stack[3] = Env[4]
				end
			end
		else
			Stack[1] = Stack[5] or Constants[8+1]
		end
			end
		elseif (pointer * pointer * 3) + pointer == 444 then
			do
				if pointer + 7 == 19 then
				return Stack[0]
		end
			end
		elseif (pointer * pointer * 2) + pointer == 253 then
			do
				do
			if pointer * 2 - 6 == 16 then
					    Stack[1] = Stack[1] + Stack[3]
    if (Stack[3] > 0 and Stack[1] <= Stack[2]) or (Stack[3] <= 0 and Stack[1] >= Stack[2]) then
        pointer = pointer + -6
        Stack[4] = Stack[1]
    end
    
				end
		end
			end
		elseif (pointer * pointer) + 12 == 112 then
			do
				if (pointer + 71) > pointer then
			do
				if pointer * 2 + 4 == 24 then
					Temp[4] = 0
Temp[7] = 5
Stack[Temp[4]] = Stack[Temp[7]]
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
			end
		end
	end
end
		pointer = pointer+1
		end
	end

				else
					Stack[2] = nil
				end
				end
				end
			end
		end
		end
	elseif (pointer * pointer) + (12 * pointer) == 133 then
		do
			if pointer + 13 == 20 then
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
				elseif (pointer * pointer) + (2 * pointer) == 195 then
					do
						if (pointer + 40) > pointer then
			do
				if pointer - 7 == 6 then
					if pointer - 11 == 2 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[6] then
		C1 = {}
		local encoded = {(decrypt("\116\090\106\083\108\111", "2326")),(decrypt("\040", "2393")),(decrypt("\022\057", "1270")),(decrypt("\008\094\084\091\110\093\090\020\121\072\086\108", "2810")),(decrypt("\011\085\110\110\083\106\108", "706")),(decrypt("\123\095\091\095\110", "1974")),(decrypt("\088\105\090\104\104\094", "2594")),((decrypt("\019\019\026", "840"))),(decrypt("\025\056", "1347")),}

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
		if (pointer * 6) + pointer <= 56 then
	if (pointer * 8) + pointer <= 36 then
		if (pointer * pointer) + 15 == 31 then
			do
				if pointer + 12 == 16 then
			Temp[8] = 4
Temp[13] = Constants
Temp[16] = 2
Stack[Temp[8]] = Temp[13][Temp[16]]
		end
			end
		elseif (pointer * pointer * 5) + pointer == 22 then
			do
				if (pointer + 84) > pointer then
			do
				if pointer * 2 - 5 == -1 then
					if pointer + 6 == 8 then
					if pointer + 5 == 7 then
					Temp[4] = 2
Temp[8] = Constants
Temp[9] = 9
Stack[Temp[4]] = Temp[8][Temp[9]]
				end
				end
				end
			end
		else
			Stack[4] = (1 == 1)
		end
			end
		elseif (pointer * pointer) + (10 * pointer) == 39 then
			do
				if (pointer - 79) > pointer then
			Stack[8] = Stack[2] or Constants[2+1]
		else
			do
				if pointer * 3 - 2 == 7 then
					if pointer - 11 == -8 then
					if pointer * 3 - 4 == 5 then
					Temp[12] = 3
Temp[3] = 7
Temp[15] = Constants[Temp[3]]
Stack[Temp[12]] = vmEnv[Temp[15]] or Env[Temp[15]]
				else
					Stack[3] = nil
				end
				end
				else
					Stack[8] = nil
				end
			end
		end
			end
		elseif (pointer * pointer) + (11 * pointer) == 12 then
			do
				if (pointer - 6) > pointer then
			Stack[7] = (0 == 1)
		else
			do
				if pointer - 2 == -1 then
					Temp[7] = 1
Temp[3] = Constants
Temp[12] = 3
Stack[Temp[7]] = Temp[3][Temp[12]]
				elseif pointer - 2 == 15 then
					Stack[1] = Env[4]
				end
			end
		end
			end
		end
	else
		if (pointer * pointer) + (3 * pointer) == 40 then
			do
				do
			if pointer * 2 + 11 == 21 then
						top = 5 + #Varargs - 1
	for i = 1, #Varargs do
		Stack[5 + i - 1] = Varargs[i]
	end
	
				end
		end
			end
		elseif (pointer * pointer * 4) + pointer == 203 then
			do
				if (pointer - 18) > pointer then
			Stack[8] = Stack[3] or Constants[1+1]
		else
			do
				if pointer - 5 == 2 then
					if pointer + 11 == 30 then
					Stack[3] = nil
				end
				Temp[10] = 4
Temp[4] = Constants
Temp[2] = 9
Stack[Temp[10]] = Temp[4][Temp[2]]
				elseif pointer - 5 == 15 then
					Stack[8] = Env[8]
				end
			end
		end
			end
		elseif (pointer * pointer) + (7 * pointer) == 78 then
			do
				do
			if pointer * 3 - 3 == 15 then
						Temp[1] = {}
	for i = 3 + 1, top do
		Temp[1][i - 3] = Stack[i]
	end
	Temp[2] = {Stack[3](unpack(Temp[1], 1, top - 3))}
		for i = 1, 1 do
		Stack[3 + i - 1] = Temp[2][i]
	end
	
	
				else
					Stack[2] = nil
				end
		end
			end
		elseif (pointer * pointer) + 37 == 101 then
			do
				if (pointer + 41) > pointer then
			do
				if pointer * 2 + 11 == 27 then
					if pointer + 8 == 19 then
					Stack[7] = nil
				end
				    Stack[2] = Stack[2] - Stack[4]
    pointer = pointer + 5
    
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
			end
		end
	end
else
	if (pointer * pointer) + (14 * pointer) <= 312 then
		if (pointer * pointer) + 7 == 151 then
			do
				if (pointer - 61) > pointer then
			Stack[2] = (0 == 1)
		else
			do
				if pointer - 5 == 7 then
					if pointer + 12 == 39 then
					Stack[1] = nil
				end
					Temp[1] = {}
	for i = 6 + 1, top do
		Temp[1][i - 6] = Stack[i]
	end
	Temp[2] = {Stack[6](unpack(Temp[1], 1, top - 6))}
		for i = 1, 1 do
		Stack[6 + i - 1] = Temp[2][i]
	end
	
	
				elseif pointer - 5 == 12 then
					Stack[1] = Env[1]
				end
			end
		end
			end
		elseif (pointer * pointer) + 36 == 136 then
			do
				if pointer + 15 == 25 then
			Temp[9] = 7
Temp[16] = 5
Stack[Temp[9]] = Stack[Temp[16]]
		end
			end
		elseif (pointer * 7) + (pointer * 23) == 270 then
			do
				do
			if pointer + 7 == 25 then
					Stack[3] = nil
				end
				if pointer - 11 == -2 then
					if pointer * 2 - 4 == 14 then
					Temp[6] = 6
Temp[4] = 7
Temp[12] = Constants[Temp[4]]
Stack[Temp[6]] = vmEnv[Temp[12]] or Env[Temp[12]]
				end
				end
		end
			end
		elseif (pointer * pointer) + (8 * pointer) == 209 then
			do
				if pointer + 2 == 13 then
				top = 8 + #Varargs - 1
	for i = 1, #Varargs do
		Stack[8 + i - 1] = Varargs[i]
	end
	
		end
			end
		end
	else
		if (pointer * pointer) + 33 == 258 then
			do
				if pointer + 4 == 19 then
				return Stack[1]
		end
			end
		elseif (pointer * pointer * 3) + pointer == 784 then
			do
				if pointer + 6 == 22 then
				return
		end
			end
		elseif (pointer * pointer) + (6 * pointer) == 280 then
			do
				if (pointer - 53) > pointer then
			Stack[8] = (1 == 1)
		else
			do
				if pointer + 2 == 18 then
					Stack[6] = nil
				end
				if pointer * 3 - 6 == 36 then
					    Stack[2] = Stack[2] + Stack[4]
    if (Stack[4] > 0 and Stack[2] <= Stack[3]) or (Stack[4] <= 0 and Stack[2] >= Stack[3]) then
        pointer = pointer + -6
        Stack[5] = Stack[2]
    end
    
				else
					Stack[3] = nil
				end
			end
		end
			end
		elseif (pointer * pointer) + 31 == 200 then
			do
				if (pointer - 21) > pointer then
						Temp[10] = vmEnv
			Temp[18] = 19
			Temp[16] = Constants[Temp[13]]
			Temp[6] = 9
			Temp[13][Temp[5]] = Temp[17]
		else
			do
				if pointer + 13 ~= 41 then
					if pointer - 9 == 4 then
						Stack[1] = Stack[1] + Stack[6]
				elseif pointer - 9 == 20 then
					Stack[1] = Env[1]
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

				elseif pointer - 11 == 11 then
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
				elseif (pointer * pointer) + (3 * pointer) == 238 then
					do
						if pointer + 8 == 22 then
			Temp[11] = 6
Temp[6] = 0
Stack[Temp[11]] = Stack[Temp[6]]
		end
					end
				end
			else
				if (pointer * 2) + pointer <= 48 then
					if (pointer * 8) + (pointer * 6) == 224 then
						do
							if pointer + 11 == 27 then
			Temp[16] = 8
Temp[14] = Constants
Temp[6] = 5
Stack[Temp[16]] = Temp[14][Temp[6]]
	Stack[6] = Stack[6](Stack[7], Stack[8])
	pointer = pointer + 1
		end
						end
					elseif (pointer * pointer) + 41 == 266 then
						do
							do
			if pointer + 6 == 30 then
					Stack[2] = nil
				end
				if pointer - 13 == 2 then
					Temp[2] = 7
Temp[15] = Constants
Temp[5] = 1
Stack[Temp[2]] = Temp[15][Temp[5]]
				elseif pointer - 13 == 16 then
					Stack[2] = Env[5]
				end
		end
						end
					end
				else
					if (pointer * pointer * 3) + pointer == 1220 then
						do
							if (pointer - 62) > pointer then
			if pointer > 154 then Stack[4] = Stack[3] end
		else
			do
				if pointer * 2 - 3 == 37 then
						Stack[8] = Stack[8]()
				end
			end
		end
						end
					elseif (pointer * pointer * 5) + pointer == 1638 then
						do
							if pointer + 15 == 33 then
			Temp[15] = 7
Temp[13] = 15
Temp[9] = Constants[Temp[13]]
Stack[Temp[15]] = vmEnv[Temp[9]] or Env[Temp[9]]
		end
						end
					elseif (pointer * pointer) + 36 == 397 then
						do
							if pointer + 2 == 21 then
			Temp[11] = 8
Temp[10] = 6
Stack[Temp[11]] = Stack[Temp[10]]
		end
						end
					end
				end
			end
		end
	else
		if pointer * pointer <= 900 then
			if (pointer * 4) + pointer <= 120 then
				if (pointer * 15) + (pointer * 17) == 768 then
					do
						do
			if pointer + 14 == 38 then
					if pointer - 6 == 18 then
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
	
				end
				end
		end
					end
				elseif (pointer * pointer * 3) + pointer == 1610 then
					do
						if pointer + 14 == 37 then
			Temp[15] = 10
Temp[13] = 6
Stack[Temp[15]] = Stack[Temp[13]]
		end
					end
				elseif (pointer * pointer) + (3 * pointer) == 504 then
					do
						if pointer + 1 == 22 then
			Temp[5] = 9
Temp[16] = 6
Stack[Temp[5]] = Stack[Temp[16]]
		end
					end
				elseif (pointer * pointer) + 32 == 516 then
					do
						if (pointer + 8) > pointer then
			do
				if pointer * 2 + 6 == 50 then
					if pointer - 1 == 21 then
					if pointer * 3 - 8 == 58 then
						Stack[9] = Stack[9]()
				else
					Stack[7] = nil
				end
				elseif pointer - 1 == 33 then
					Stack[1] = Env[4]
				end
				end
			end
		else
			Stack[8] = -Stack[3]
		end
					end
				end
			else
				if (pointer * 4) + pointer <= 130 then
					if (pointer * pointer * 4) + pointer == 2730 then
						do
							do
			if pointer + 9 ~= 49 then
					if pointer * 2 - 5 == 47 then
					Temp[10] = 7
Temp[3] = 15
Temp[9] = Constants[Temp[3]]
Stack[Temp[10]] = vmEnv[Temp[9]] or Env[Temp[9]]
				end
				end
		end
						end
					elseif (pointer * pointer) + (3 * pointer) == 700 then
						do
							if pointer + 15 == 40 then
				Temp[1] = {}
	for i = 7 + 1, top do
		Temp[1][i - 7] = Stack[i]
	end
	Temp[2] = {Stack[7](unpack(Temp[1], 1, top - 7))}
		for i = 1, 0 do
		Stack[7 + i - 1] = Temp[2][i]
	end
	
	
		end
						end
					end
				else
					if (pointer * pointer) + 40 == 940 then
						do
							do
			if pointer - 7 == 23 then
					Temp[5] = 9
Temp[4] = 2
Stack[Temp[5]] = Stack[Temp[4]]
				elseif pointer - 7 == 37 then
					Stack[8] = Env[5]
				end
		end
						end
					elseif (pointer * pointer * 3) + pointer == 2214 then
						do
							if (pointer + 61) > pointer then
			do
				if pointer + 9 == 36 then
					if pointer * 2 - 4 == 50 then
					if pointer * 2 + 5 == 59 then
					Temp[14] = 8
Temp[16] = 2
Stack[Temp[14]] = Stack[Temp[16]]
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
					elseif (pointer * 4) + (pointer * 25) == 812 then
						do
							if (pointer - 13) > pointer then
			Stack[2] = nil
		else
			do
				if pointer - 7 == 21 then
					if pointer * 2 + 4 == 60 then
					if pointer * 3 - 5 == 79 then
					Temp[4] = 9
Temp[5] = Constants
Temp[15] = 11
Stack[Temp[4]] = Temp[5][Temp[15]]
	Stack[8] = Stack[8](Stack[9])
	pointer = pointer + 1
				else
					Stack[7] = nil
				end
				end
				elseif pointer - 7 == 37 then
					Stack[4] = Env[2]
				end
			end
		end
						end
					end
				end
			end
		else
			if (pointer * 11) + pointer <= 432 then
				if pointer * pointer <= 1089 then
					if (pointer * pointer * 4) + pointer == 4389 then
						do
							if pointer + 10 == 43 then
				Temp[1] = {}
	for i = 7 + 1, top do
		Temp[1][i - 7] = Stack[i]
	end
	Temp[2] = {Stack[7](unpack(Temp[1], 1, top - 7))}
		for i = 1, 0 do
		Stack[7 + i - 1] = Temp[2][i]
	end
	
	
		end
						end
					elseif (pointer * pointer * 2) + pointer == 1953 then
						do
							if pointer + 2 == 33 then
			Temp[10] = 10
Temp[5] = Constants
Temp[16] = 10
Stack[Temp[10]] = Temp[5][Temp[16]]
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
		end
						end
					end
				else
					if (pointer * pointer) + 43 == 1199 then
						do
							if pointer + 8 == 42 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[7] then
		C1 = {}
		local encoded = {(decrypt("\084\084\092\105", "1295")),(decrypt("\012\095\083\105", "2902")),(decrypt("\124\086\094\082\093\110\084\121\084\081\091\082\117\110\082\097\111\106\094", "1679")),(decrypt("\026\063", "2456")),}

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
		if (pointer * pointer) + 42 == 46 then
	do
		if (pointer + 55) > pointer then
			do
				if pointer * 2 - 3 == 1 then
					if pointer - 4 == -2 then
						return Stack[1]
				elseif pointer - 4 == 3 then
					Stack[2] = Env[5]
				end
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
	end
elseif (pointer * pointer) + 23 == 24 then
	do
		if pointer + 12 == 13 then
				Stack[1] = Stack[0] + Constants[4]
		end
	end
elseif (pointer * pointer * 2) + pointer == 21 then
	do
		if pointer + 7 == 10 then
				return
		end
	end
end
		pointer = pointer+1
		end
	end

		end
						end
					elseif (pointer * pointer) + 25 == 1250 then
						do
							do
			if pointer * 2 + 12 == 82 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[8] then
		C1 = {}
		local encoded = {(decrypt("\118\090\105\068\109\080\091", "1914")),(decrypt("\123\011\010\028", "1424")),(decrypt("\104\105\082\091\083\095", "851")),((decrypt("\021", "2747"))),(decrypt("\027\058", "2190")),(decrypt("\014\090\094\094\091", "2378")),(decrypt("\113\092\086\094\090\005\084\105\109\098", "1912")),}

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
		if (pointer * 8) + (pointer * 38) == 46 then
	do
		if (pointer + 72) > pointer then
			do
				if pointer + 12 == 31 then
					Stack[3] = nil
				end
					Stack[1] = Stack[0] * Constants[5]
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
	end
elseif (pointer * 7) + (pointer * 47) == 108 then
	do
		if (pointer + 35) > pointer then
			do
				if pointer + 12 == 25 then
					Stack[1] = nil
				end
				if pointer + 7 == 9 then
					if pointer * 3 - 12 == -6 then
						return Stack[1]
				else
					Stack[8] = nil
				end
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
	end
elseif (pointer * pointer * 2) + pointer == 21 then
	do
		do
			if pointer - 3 == 0 then
					if pointer * 2 - 10 == -4 then
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
						end
					elseif (pointer * pointer * 2) + pointer == 2628 then
						do
							if (pointer + 41) > pointer then
			do
				if pointer + 12 ~= 53 then
					if pointer + 13 == 55 then
					Stack[4] = nil
				end
				Temp[6] = 9
Temp[3] = 15
Temp[5] = Constants[Temp[3]]
Stack[Temp[6]] = vmEnv[Temp[5]] or Env[Temp[5]]
				end
			end
		else
			Stack[5] = -Stack[1]
		end
						end
					end
				end
			else
				if pointer * pointer <= 1444 then
					if (pointer * pointer) + (6 * pointer) == 1672 then
						do
							if (pointer + 19) > pointer then
			do
				if pointer * 2 + 4 == 80 then
					if pointer - 2 == 36 then
					if pointer - 11 == 27 then
					Temp[10] = 11
Temp[4] = 7
Stack[Temp[10]] = Stack[Temp[4]]
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
					elseif (pointer * pointer) + (2 * pointer) == 1443 then
						do
							if pointer + 9 == 46 then
			Temp[6] = 10
Temp[16] = 3
Stack[Temp[6]] = Stack[Temp[16]]
		end
						end
					end
				else
					if (pointer * pointer * 5) + pointer == 7644 then
						do
							if pointer + 7 == 46 then
			Temp[13] = 12
Temp[2] = 8
Stack[Temp[13]] = Stack[Temp[2]]
		end
						end
					elseif (pointer * 12) + (pointer * 17) == 1160 then
						do
							if (pointer - 17) > pointer then
			Stack[6] = Stack[4] or Constants[8+1]
		else
			do
				if pointer - 12 == 28 then
					if pointer * 2 - 2 == 78 then
					if pointer * 3 - 9 == 111 then
						Stack[10] = Stack[10](Stack[11], Stack[12])
				else
					Stack[4] = nil
				end
				end
				end
			end
		end
						end
					elseif (pointer * pointer) + 50 == 1731 then
						do
							if pointer + 3 == 44 then
			Temp[15] = 11
Temp[6] = Constants
Temp[14] = 5
Stack[Temp[15]] = Temp[6][Temp[14]]
	Stack[10] = Stack[10](Stack[11])
	pointer = pointer + 1
		end
						end
					end
				end
			end
		end
	end
else
	if pointer * pointer <= 3844 then
		if (pointer * 12) + pointer <= 689 then
			if (pointer * pointer) + (5 * pointer) <= 2346 then
				if (pointer * pointer * 5) + pointer == 9288 then
					do
						if (pointer + 50) > pointer then
			do
				if pointer + 2 ~= 55 then
					Temp[5] = 11
Temp[3] = 3
Stack[Temp[5]] = Stack[Temp[3]]
				end
			end
		else
			if pointer > 86 then Stack[7] = Stack[7] end
		end
					end
				elseif (pointer * pointer * 5) + pointer == 10170 then
					do
						do
			if pointer - 4 == 41 then
					if pointer + 2 ~= 61 then
					Temp[5] = 13
Temp[7] = 7
Stack[Temp[5]] = Stack[Temp[7]]
				end
				end
		end
					end
				elseif (pointer * pointer * 3) + pointer == 6394 then
					do
						if (pointer + 7) > pointer then
			do
				if pointer - 9 == 37 then
					if pointer - 3 == 43 then
						Stack[11] = Stack[11](Stack[12], Stack[13])
				end
				elseif pointer - 9 == 40 then
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
				elseif (pointer * pointer) + 6 == 1942 then
					do
						if (pointer - 34) > pointer then
						Temp[4] = vmEnv
			Temp[8] = 17
			Temp[15] = Constants[Temp[5]]
			Temp[14] = 9
			Temp[9][Temp[6]] = Temp[2]
		else
			do
				if pointer + 5 == 49 then
					if pointer * 2 + 9 == 97 then
					if pointer + 5 == 58 then
					Stack[3] = nil
				end
				Temp[7] = 12
Temp[11] = 8
Stack[Temp[7]] = Stack[Temp[11]]
				end
				end
			end
		end
					end
				end
			else
				if pointer * pointer <= 2401 then
					if (pointer * 8) + (pointer * 37) == 2115 then
						do
							do
			if pointer + 2 == 49 then
					if pointer + 13 == 60 then
					if pointer + 5 ~= 70 then
					Temp[15] = 12
Temp[9] = Constants
Temp[12] = 5
Stack[Temp[15]] = Temp[9][Temp[12]]
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
				end
				end
				end
		end
						end
					elseif (pointer * pointer) + 19 == 2420 then
						do
							if (pointer + 52) > pointer then
			do
				if pointer + 10 == 59 then
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
		else
			if pointer > 101 then Stack[1] = Stack[3] end
		end
						end
					end
				else
					if (pointer * pointer) + (11 * pointer) == 3050 then
						do
							do
			if pointer - 9 == 41 then
					if pointer - 8 == 42 then
					if pointer * 2 - 3 == 97 then
					Temp[14] = 9
Temp[7] = 15
Temp[15] = Constants[Temp[7]]
Stack[Temp[14]] = vmEnv[Temp[15]] or Env[Temp[15]]
				end
				elseif pointer - 8 == 47 then
					Stack[8] = Env[1]
				end
				end
		end
						end
					elseif (pointer * 4) + (pointer * 43) == 2397 then
						do
							do
			if pointer * 2 + 5 == 107 then
					Temp[7] = 10
Temp[4] = 4
Temp[11] = Constants[Temp[4]]
Stack[Temp[7]] = vmEnv[Temp[11]] or Env[Temp[11]]
	Stack[10] = Stack[10][Constants[2]]
	
	pointer = pointer + 1
				end
		end
						end
					elseif (pointer * pointer) + 32 == 2841 then
						do
							if pointer + 5 == 58 then
			Temp[7] = 11
Temp[10] = 4
Stack[Temp[7]] = Stack[Temp[10]]
		end
						end
					end
				end
			end
		else
			if (pointer * 11) + pointer <= 684 then
				if (pointer * 2) + (pointer * 27) == 1595 then
					do
						do
			if pointer * 3 - 2 == 163 then
					if pointer - 13 == 42 then
					Temp[14] = 13
Temp[12] = Constants
Temp[15] = 16
Stack[Temp[14]] = Temp[12][Temp[15]]
				elseif pointer - 13 == 58 then
					Stack[6] = Env[2]
				end
				else
					Stack[4] = nil
				end
		end
					end
				elseif (pointer * pointer * 5) + pointer == 16302 then
					do
						if pointer + 2 == 59 then
			Temp[9] = 15
Temp[7] = Constants
Temp[16] = 7
Stack[Temp[9]] = Temp[7][Temp[16]]
		end
					end
				elseif (pointer * pointer) + 32 == 3168 then
					do
						if (pointer - 39) > pointer then
			Stack[5] = -Stack[6]
		else
			do
				if pointer + 5 == 69 then
					Stack[7] = nil
				end
				if pointer - 4 == 52 then
					Temp[13] = 14
Temp[6] = Constants
Temp[2] = 14
Stack[Temp[13]] = Temp[6][Temp[2]]
				end
			end
		end
					end
				elseif (pointer * pointer) + 15 == 2931 then
					do
						if pointer + 5 == 59 then
				Stack[12] = {}
		end
					end
				end
			else
				if pointer * pointer <= 3481 then
					if (pointer * pointer * 3) + pointer == 10150 then
						do
							do
			if pointer * 2 + 3 == 119 then
					if pointer * 2 + 1 == 117 then
					Temp[15] = 16
Temp[13] = Constants
Temp[3] = 3
Stack[Temp[15]] = Temp[13][Temp[3]]
				end
				end
		end
						end
					elseif (pointer * pointer * 3) + pointer == 10502 then
						do
							do
			if pointer - 4 == 55 then
					if pointer - 11 == 48 then
						for i = 1, 4 do
		Stack[12][(1 - 1) * 50 + i] = Stack[12 + i]
	end
	
				end
				end
		end
						end
					end
				else
					if (pointer * 2) + (pointer * 41) == 2623 then
						do
							if (pointer + 65) > pointer then
			do
				if pointer - 11 == 50 then
					if pointer * 2 + 3 == 125 then
					if pointer * 3 - 8 == 175 then
						Stack[11] = Stack[11](Stack[12], Stack[13])
				else
					Stack[7] = nil
				end
				end
				elseif pointer - 11 == 52 then
					Stack[2] = Env[4]
				end
			end
		else
			Stack[1] = Stack[7] or Constants[7+1]
		end
						end
					elseif (pointer * 11) + (pointer * 46) == 3534 then
						do
							do
			if pointer - 15 == 47 then
					if pointer - 13 == 49 then
					Temp[16] = 12
Temp[4] = Constants
Temp[10] = 13
Stack[Temp[16]] = Temp[4][Temp[10]]
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
				elseif pointer - 13 == 55 then
					Stack[5] = Env[1]
				end
				elseif pointer - 15 == 65 then
					Stack[8] = Env[6]
				end
		end
						end
					elseif (pointer * 4) + (pointer * 28) == 1920 then
						do
							if (pointer + 82) > pointer then
			do
				if pointer + 5 == 80 then
					Stack[8] = nil
				end
				if pointer + 9 == 69 then
					if pointer + 11 ~= 82 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[9] then
		C1 = {}
		local encoded = {(decrypt("\013\081\109\081\091\110\110", "1256")),(decrypt("\123\085\091\084\109\092", "1589")),(decrypt("\127\084\107\083\106\085\081\083\121\083\111\086\099", "873")),(decrypt("\010\105\109\111\093\086\091", "1507")),((decrypt("\025\030\022\028\000\031\026", "503"))),}

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
		if (pointer * 11) + (pointer * 21) == 96 then
	do
		if pointer + 2 == 5 then
				return
		end
	end
elseif (pointer * pointer) + 8 == 12 then
	do
		if pointer + 1 == 3 then
				return Stack[2]
		end
	end
elseif (pointer * 5) + (pointer * 45) == 50 then
	do
		do
			if pointer + 2 == 3 then
					if pointer * 2 + 3 == 5 then
					if pointer * 3 - 14 == -11 then
						Stack[2] = Stack[0] * Stack[1]
				else
					Stack[7] = nil
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
			Stack[1] = (0 == 1)
		end
						end
					end
				end
			end
		end
	else
		if (pointer * 12) + pointer <= 949 then
			if (pointer * pointer) + (9 * pointer) <= 5092 then
				if (pointer * pointer) + 14 == 4239 then
					do
						if pointer + 13 == 78 then
			Temp[10] = 9
Temp[8] = 15
Temp[1] = Constants[Temp[8]]
Stack[Temp[10]] = vmEnv[Temp[1]] or Env[Temp[1]]
		end
					end
				elseif (pointer * 15) + (pointer * 11) == 1742 then
					do
						do
			if pointer + 2 == 69 then
					if pointer - 2 == 65 then
					if pointer * 3 - 9 == 192 then
					Temp[12] = 11
Temp[5] = Constants
Temp[14] = 16
Stack[Temp[12]] = Temp[5][Temp[14]]
				else
					Stack[6] = nil
				end
				end
				end
		end
					end
				elseif (pointer * pointer * 5) + pointer == 21846 then
					do
						do
			if pointer + 8 == 74 then
					if pointer * 2 + 6 == 138 then
					if pointer - 10 == 56 then
					Temp[8] = 10
Temp[1] = 5
Stack[Temp[8]] = Stack[Temp[1]]
				elseif pointer - 10 == 75 then
					Stack[5] = Env[8]
				end
				end
				end
		end
					end
				elseif (pointer * pointer) + 42 == 4138 then
					do
						if pointer + 13 == 77 then
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
				end
			else
				if (pointer * pointer) + (13 * pointer) <= 5658 then
					if (pointer * pointer) + (10 * pointer) == 5451 then
						do
							do
			if pointer - 12 == 57 then
					Temp[14] = 13
Temp[7] = Constants
Temp[11] = 7
Stack[Temp[14]] = Temp[7][Temp[11]]
				elseif pointer - 12 == 59 then
					Stack[1] = Env[4]
				end
		end
						end
					elseif (pointer * pointer) + 14 == 4638 then
						do
							do
			if pointer + 5 == 74 then
					Stack[3] = nil
				end
				Temp[11] = 12
Temp[12] = Constants
Temp[5] = 14
Stack[Temp[11]] = Temp[12][Temp[5]]
		end
						end
					end
				else
					if (pointer * pointer) + 28 == 5357 then
						do
							do
			if pointer + 15 == 98 then
					Stack[2] = nil
				end
				if pointer + 3 == 76 then
					Temp[7] = 11
Temp[10] = 5
Stack[Temp[7]] = Stack[Temp[10]]
				end
		end
						end
					elseif (pointer * pointer) + 32 == 5073 then
						do
							do
			if pointer + 9 == 97 then
					Stack[3] = nil
				end
				if pointer + 8 == 83 then
					Stack[8] = nil
				end
				if pointer * 2 - 9 == 133 then
					Temp[5] = 15
Temp[1] = Constants
Temp[12] = 5
Stack[Temp[5]] = Temp[1][Temp[12]]
	Stack[10] = Stack[10](Stack[11], Stack[12], Stack[13], Stack[14], Stack[15])
	pointer = pointer + 1
				end
		end
						end
					elseif (pointer * 3) + (pointer * 46) == 3430 then
						do
							if (pointer + 88) > pointer then
			do
				if pointer * 2 - 8 == 132 then
					if pointer + 4 == 93 then
					Stack[1] = nil
				end
				if pointer * 3 - 5 == 205 then
					Temp[7] = 14
Temp[4] = Constants
Temp[6] = 3
Stack[Temp[7]] = Temp[4][Temp[6]]
				else
					Stack[3] = nil
				end
				end
			end
		else
			Stack[2] = (0 == 1)
		end
						end
					end
				end
			end
		else
			if pointer * pointer <= 6084 then
				if (pointer * pointer) + (12 * pointer) <= 6525 then
					if (pointer * pointer) + 10 == 5635 then
						do
							do
			if pointer + 12 == 87 then
					if pointer * 3 - 4 == 221 then
						Temp[1] = {}
	for i = 9 + 1, top do
		Temp[1][i - 9] = Stack[i]
	end
	Temp[2] = {Stack[9](unpack(Temp[1], 1, top - 9))}
		for i = 1, 0 do
		Stack[9 + i - 1] = Temp[2][i]
	end
	
	
				else
					Stack[2] = nil
				end
				end
		end
						end
					elseif (pointer * 5) + (pointer * 47) == 3848 then
						do
							if pointer + 8 == 82 then
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
	
		end
						end
					end
				else
					if (pointer * 14) + (pointer * 35) == 3773 then
						do
							do
			if pointer * 3 - 3 == 228 then
					if pointer + 4 == 81 then
					Temp[3] = 10
Temp[7] = 15
Temp[8] = Constants[Temp[7]]
Stack[Temp[3]] = vmEnv[Temp[8]] or Env[Temp[8]]
				end
				else
					Stack[5] = nil
				end
		end
						end
					elseif (pointer * pointer * 2) + pointer == 12246 then
						do
							if pointer + 12 == 90 then
			Temp[15] = 11
Temp[3] = 9
Stack[Temp[15]] = Stack[Temp[3]]
		end
						end
					elseif (pointer * pointer) + (4 * pointer) == 6080 then
						do
							if pointer + 4 == 80 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[10] then
		C1 = {}
		local encoded = {(decrypt("\013\097\093\111\110\098", "2970")),(decrypt("\012\084\090\091\105\091\104", "1235")),(decrypt("\123\092\085\084\082\085\110", "2001")),(decrypt("\123\092\082\086\086\107\111", "1741")),((decrypt("\022\021\022\026", "1012"))),}

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
		if (pointer * pointer * 5) + pointer == 48 then
	do
		do
			if pointer * 2 + 8 == 14 then
					if pointer + 15 == 18 then
						return Stack[1]
				end
				end
		end
	end
elseif (pointer * pointer * 5) + pointer == 6 then
	do
		do
			if pointer * 3 - 3 == 0 then
					if pointer * 2 - 5 == -3 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[14] then
		C1 = {}
		local encoded = {(decrypt("\013\092\095\081\120\107\093\091\082\109\104", "2746")),(decrypt("\113\081\106\109\090\084\095\107", "1427")),}

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
		if (pointer * 15) + (pointer * 6) == 84 then
	do
		do
			if pointer - 10 == -6 then
					if pointer * 2 + 9 == 17 then
						return Stack[1]
				end
				end
		end
	end
elseif (pointer * 15) + (pointer * 38) == 53 then
	do
		do
			if pointer * 3 - 14 == -11 then
					if pointer * 2 + 11 == 13 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[15] then
		C1 = {}
		local encoded = {(decrypt("\015\092\108\068", "1544")),(decrypt("\028\020\016\063", "437")),(decrypt("\120\093\083\120\109\088\091\082\107\109", "1162")),(decrypt("\015\085\104\084\092\108\104", "360")),(decrypt("\026\019\059", "240")),}

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
		if (pointer * 12) + pointer <= 52 then
	if (pointer * 12) + (pointer * 10) == 66 then
		do
			if pointer + 8 == 11 then
				Stack[2] = Upvalues[1]
		end
		end
	elseif (pointer * pointer * 3) + pointer == 4 then
		do
			if (pointer + 20) > pointer then
			do
				if pointer * 3 - 12 == -9 then
						Stack[1] = Upvalues[0]
				else
					Stack[4] = nil
				end
			end
		else
			Temp[14] = 5
			Temp[7] = Constants
			Temp[14] = 7
			Stack[Temp[9]] = Temp[8][Temp[6]]
		end
		end
	elseif (pointer * pointer * 5) + pointer == 84 then
		do
			if pointer + 7 == 11 then
				Stack[2] = Stack[2] * Constants[5]
		end
		end
	elseif (pointer * pointer * 2) + pointer == 10 then
		do
			do
			if pointer - 4 == -2 then
					if pointer - 15 == -13 then
						Stack[1] = Stack[1] * Constants[2]
				end
				end
		end
		end
	end
else
	if (pointer * pointer) + (9 * pointer) == 112 then
		do
			if (pointer - 79) > pointer then
			Temp[20] = 2
			Temp[3] = Constants
			Temp[14] = 20
			Stack[Temp[17]] = Temp[4][Temp[10]]
		else
			do
				if pointer * 2 + 5 == 19 then
						return Stack[1]
				end
			end
		end
		end
	elseif (pointer * pointer) + (5 * pointer) == 66 then
		do
			if pointer + 9 == 15 then
				Stack[1] = Stack[1] + Stack[0]
		end
		end
	elseif (pointer * pointer * 4) + pointer == 264 then
		do
			if (pointer - 9) > pointer then
			Stack[1] = Stack[4] or Constants[1+1]
		else
			do
				if pointer * 3 - 9 == 15 then
						return
				else
					Stack[5] = nil
				end
			end
		end
		end
	elseif (pointer * pointer) + (11 * pointer) == 80 then
		do
			do
			if pointer + 9 ~= 27 then
						Stack[1] = Stack[1] + Stack[2]
				end
		end
		end
	end
end
		pointer = pointer+1
		end
	end

				end
				else
					Stack[7] = nil
				end
		end
	end
elseif (pointer * pointer) + 27 == 52 then
	do
		if (pointer + 32) > pointer then
			do
				if pointer + 4 == 9 then
					if pointer * 2 + 11 == 21 then
					if pointer * 2 - 6 == 4 then
						return
				end
				end
				end
			end
		else
			Temp[20] = 2
			Temp[6] = Constants
			Temp[10] = 20
			Stack[Temp[14]] = Temp[20][Temp[16]]
		end
	end
end
		pointer = pointer+1
		end
	end

				end
				else
					Stack[2] = nil
				end
		end
	end
elseif (pointer * pointer) + (6 * pointer) == 40 then
	do
		if pointer + 4 == 8 then
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
				if (pointer * pointer) + (12 * pointer) <= 7533 then
					if (pointer * pointer) + 31 == 6592 then
						do
							do
			if pointer * 3 - 6 == 237 then
					if pointer * 3 - 10 == 233 then
					Temp[4] = 12
Temp[8] = Constants
Temp[15] = 14
Stack[Temp[4]] = Temp[8][Temp[15]]
	Stack[11] = Stack[11](Stack[12])
	pointer = pointer + 1
				else
					Stack[3] = nil
				end
				else
					Stack[1] = nil
				end
		end
						end
					elseif (pointer * pointer * 2) + pointer == 12561 then
						do
							if (pointer - 62) > pointer then
			Stack[2] = nil
		else
			do
				if pointer - 12 == 67 then
					if pointer + 5 == 84 then
					Temp[11] = 12
Temp[14] = Constants
Temp[7] = 16
Stack[Temp[11]] = Temp[14][Temp[7]]
	Stack[11] = Stack[11](Stack[12])
	pointer = pointer + 1
				end
				end
			end
		end
						end
					end
				else
					if (pointer * pointer) + (7 * pointer) == 7820 then
						do
							if (pointer + 82) > pointer then
			do
				if pointer + 11 ~= 108 then
						Temp[1] = {}
	for i = 10 + 1, top do
		Temp[1][i - 10] = Stack[i]
	end
	Temp[2] = {Stack[10](unpack(Temp[1], 1, top - 10))}
		for i = 1, 0 do
		Stack[10 + i - 1] = Temp[2][i]
	end
	
	
				end
			end
		else
			Stack[8] = Stack[2] or Constants[8+1]
		end
						end
					elseif (pointer * pointer) + (11 * pointer) == 7802 then
						do
							if (pointer - 64) > pointer then
			Stack[2] = nil
		else
			do
				if pointer - 10 == 73 then
					if pointer + 3 == 97 then
					Stack[3] = nil
				end
				Temp[5] = 12
Temp[16] = Constants
Temp[15] = 7
Stack[Temp[5]] = Temp[16][Temp[15]]
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
				elseif pointer - 10 == 91 then
					Stack[7] = Env[8]
				end
			end
		end
						end
					elseif (pointer * pointer) + (5 * pointer) == 7826 then
						do
							do
			if pointer + 14 == 100 then
						return
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