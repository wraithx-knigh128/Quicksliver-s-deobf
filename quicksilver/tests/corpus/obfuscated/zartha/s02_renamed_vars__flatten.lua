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
				if pointer * pointer <= 729 then
	if (pointer * 8) + pointer <= 144 then
		if (pointer * pointer) + (13 * pointer) <= 68 then
			if (pointer * pointer) + (10 * pointer) == 11 then
				do
					if (pointer + 40) > pointer then
			do
				if pointer - 7 == -6 then
					if pointer - 11 == -10 then
					Temp[5] = 0
Temp[14] = ttostring ~= __metatable
Stack[Temp[5]] = Temp[12]
				elseif pointer - 11 == -1 then
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
			elseif (pointer * pointer * 4) + pointer == 68 then
				do
					if pointer + 2 == 6 then
			Temp[15] = 1
Temp[11] = Constants
Temp[5] = 1
Stack[Temp[15]] = Temp[11][Temp[5]]
		end
				end
			elseif (pointer * 7) + (pointer * 48) == 110 then
				do
					if pointer + 9 == 11 then
			Temp[7] = vmEnv
Temp[5] = 8
Temp[12] = Constants[Temp[5]]
Temp[2] = 0
Temp[7][Temp[12]] = Temp[12]
		end
				end
			elseif (pointer * pointer) + 29 == 38 then
				do
					if pointer + 8 == 11 then
				Stack[0] = {}
		end
				end
			end
		else
			if (pointer * 15) + pointer <= 96 then
				if (pointer * pointer) + 39 == 75 then
					do
						do
			if pointer + 14 == 20 then
					if pointer - 6 == 0 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\090\089\096\087\089\085\083\066", "2582")),(decrypt("\084\087\081\049", "1727")),(decrypt("\117\094\087\083\117\085\090\110\090", "423")),(decrypt("\089\080\083\038\109\106\109\092\066\007\034", "2651")),(decrypt("\124\105\089\082\092\109\090", "955")),(decrypt("\022\062", "1588")),(decrypt("\095\105\085\102\110\094", "1558")),}

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
		if pointer * pointer <= 225 then
	if (pointer * pointer) + (7 * pointer) <= 98 then
		if (pointer * 13) + pointer <= 42 then
			if (pointer * 15) + (pointer * 32) == 94 then
				do
					if (pointer + 71) > pointer then
			do
				if pointer - 9 == -7 then
						Stack[3] = Stack[3][Stack[0]]
	
				end
			end
		else
			Temp[9] = 4
			Temp[8] = Constants
			Temp[13] = 16
			Stack[Temp[17]] = Temp[12][Temp[10]]
		end
				end
			elseif (pointer * pointer) + (7 * pointer) == 30 then
				do
					if pointer + 2 == 5 then
				Stack[4] = Stack[1] * Stack[2]
		end
				end
			elseif (pointer * 12) + (pointer * 39) == 51 then
				do
					if pointer + 7 == 8 then
				Stack[3] = Upvalues[0]
		end
				end
			end
		else
			if (pointer * pointer * 2) + pointer == 36 then
				do
					if (pointer + 82) > pointer then
			do
				if pointer + 11 ~= 27 then
						Stack[5] = Upvalues[1]
				end
			end
		else
			Stack[8] = Stack[2] or Constants[8+1]
		end
				end
			elseif (pointer * pointer) + (13 * pointer) == 114 then
				do
					if (pointer - 41) > pointer then
			if (pointer * 2) < 0 then Env[1] = nil end
		else
			do
				if pointer + 5 ~= 24 then
					if pointer * 3 - 7 == 11 then
					if pointer - 9 == -3 then
						Stack[6] = Upvalues[2]
				end
				else
					Stack[2] = nil
				end
				end
			end
		end
				end
			elseif (pointer * pointer) + 22 == 47 then
				do
					if pointer + 4 == 9 then
				Stack[5] = Stack[5] + Stack[4]
		end
				end
			elseif (pointer * pointer) + (4 * pointer) == 77 then
				do
					if (pointer + 62) > pointer then
			do
				if pointer + 8 == 15 then
					if pointer * 2 - 2 == 12 then
						if Stack[6] < Stack[5] then pointer = pointer + 1 end
				end
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
				end
			end
		end
	else
		if (pointer * pointer) + (10 * pointer) <= 231 then
			if (pointer * pointer * 5) + pointer == 414 then
				do
					do
			if pointer - 12 == -3 then
					Temp[1] = 5
Temp[6] = byte == pairs
Stack[Temp[1]] = Temp[13]
				elseif pointer - 12 == -1 then
					Stack[1] = Env[4]
				end
		end
				end
			elseif (pointer * pointer * 5) + pointer == 328 then
				do
					do
			if pointer + 9 == 34 then
					Stack[3] = nil
				end
				if pointer + 8 == 20 then
					Stack[8] = nil
				end
				if pointer * 2 - 9 == 7 then
					pointer = pointer + 5 
				end
		end
				end
			elseif (pointer * pointer * 5) + pointer == 510 then
				do
					do
			if pointer - 13 == -3 then
					if pointer * 2 + 10 == 30 then
					Temp[11] = 6
Temp[7] = Constants
Temp[9] = 4
Stack[Temp[11]] = Temp[7][Temp[9]]
				end
				elseif pointer - 13 == 6 then
					Stack[7] = Env[5]
				end
		end
				end
			elseif (pointer * pointer) + (8 * pointer) == 209 then
				do
					if (pointer + 50) > pointer then
			do
				if pointer + 2 ~= 23 then
					Temp[11] = 7
Temp[5] = 0
Stack[Temp[11]] = Stack[Temp[5]]
				end
			end
		else
			if pointer > 86 then Stack[7] = Stack[7] end
		end
				end
			end
		else
			if (pointer * pointer * 5) + pointer == 732 then
				do
					if pointer + 5 == 17 then
				Temp[1] = ""
	for i = 6, 7 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[6] = Temp[1]
	
		end
				end
			elseif (pointer * pointer * 5) + pointer == 994 then
				do
					if (pointer - 73) > pointer then
			Temp[14] = 3
			Temp[9] = Constants
			Temp[6] = 2
			Stack[Temp[17]] = Temp[15][Temp[6]]
		else
			do
				if pointer * 3 - 1 == 41 then
					if pointer * 2 + 6 == 34 then
						if Stack[3] == Constants[2] then pointer = pointer + 1 end
				end
				else
					Stack[3] = nil
				end
			end
		end
				end
			elseif (pointer * pointer * 3) + pointer == 690 then
				do
					do
			if pointer - 4 == 11 then
					if pointer - 11 == 4 then
					pointer = pointer + 6 
				end
				end
		end
				end
			elseif (pointer * pointer) + 6 == 175 then
				do
					if pointer + 1 == 14 then
				return Stack[5], Stack[6]
		end
				end
			end
		end
	end
else
	if pointer * pointer <= 484 then
		if (pointer * 10) + pointer <= 198 then
			if (pointer * pointer) + 19 == 275 then
				do
					if pointer + 8 == 24 then
				Stack[5] = {}
		end
				end
			elseif (pointer * 11) + (pointer * 42) == 901 then
				do
					if (pointer + 80) > pointer then
			do
				if pointer + 15 ~= 38 then
					if pointer * 2 + 3 == 37 then
					if pointer - 7 == 10 then
						Stack[5][Constants[7]] = Stack[1]
				end
				end
				end
			end
		else
			if pointer > 153 then Stack[4] = Stack[4] end
		end
				end
			elseif (pointer * pointer) + (13 * pointer) == 558 then
				do
					if pointer + 4 == 22 then
				Stack[5][Constants[1]] = Constants[6]
		end
				end
			end
		else
			if (pointer * 10) + (pointer * 23) == 627 then
				do
					if (pointer - 62) > pointer then
			Stack[2] = nil
		else
			do
				if pointer - 12 == 7 then
					if pointer + 5 == 24 then
					Temp[9] = 3
Temp[6] = 5
Stack[Temp[9]] = Stack[Temp[6]]
				end
				end
			end
		end
				end
			elseif (pointer * 9) + (pointer * 15) == 504 then
				do
					if (pointer + 71) > pointer then
			do
				if pointer + 2 == 23 then
					if pointer + 9 == 30 then
					if pointer + 10 == 33 then
					Stack[6] = nil
				end
					Stack[5][Stack[0]] = Stack[3]
				end
				end
			end
		else
			Stack[8] = -Stack[2]
		end
				end
			elseif (pointer * pointer) + 8 == 408 then
				do
					if (pointer + 54) > pointer then
			do
				if pointer + 15 == 35 then
					if pointer - 10 == 10 then
						Stack[5] = Upvalues[0]
				end
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
				end
			elseif (pointer * 10) + (pointer * 8) == 396 then
				do
					do
			if pointer + 2 == 24 then
					if pointer + 13 == 35 then
					if pointer + 5 ~= 45 then
						Stack[5] = Stack[3][Constants[1]]
	
				end
				end
				end
		end
				end
			end
		end
	else
		if pointer * pointer <= 676 then
			if (pointer * pointer) + 15 == 640 then
				do
					do
			if pointer * 2 - 3 == 47 then
						Stack[5] = Upvalues[1]
				end
		end
				end
			elseif (pointer * pointer * 2) + pointer == 1081 then
				do
					if pointer + 11 == 34 then
				Stack[5] = Stack[5] + Stack[2]
		end
				end
			elseif (pointer * pointer) + 41 == 717 then
				do
					if pointer + 7 == 33 then
				Stack[5] = Stack[5] + Stack[4]
		end
				end
			elseif (pointer * pointer * 3) + pointer == 1752 then
				do
					do
			if pointer * 3 - 1 == 71 then
						Stack[3][Constants[1]] = Stack[5]
				else
					Stack[7] = nil
				end
		end
				end
			end
		else
			if (pointer * 13) + (pointer * 29) == 1176 then
				do
					if pointer + 1 == 29 then
			Temp[2] = 5
Temp[9] = ttostring ~= __metatable
Stack[Temp[2]] = Temp[10]
		end
				end
			elseif (pointer * pointer) + (14 * pointer) == 1247 then
				do
					do
			if pointer + 9 ~= 52 then
					if pointer * 2 - 5 == 53 then
						return Stack[5]
				end
				end
		end
				end
			elseif (pointer * 9) + (pointer * 36) == 1350 then
				do
					if (pointer + 37) > pointer then
			do
				if pointer - 7 == 23 then
					if pointer * 2 - 4 == 56 then
					if pointer + 10 == 40 then
						return
				end
				end
				elseif pointer - 7 == 29 then
					Stack[8] = Env[4]
				end
			end
		else
			Stack[1] = (1 == 1)
		end
				end
			elseif (pointer * pointer) + (8 * pointer) == 945 then
				do
					if (pointer - 62) > pointer then
			if pointer > 154 then Stack[4] = Stack[3] end
		else
			do
				if pointer * 2 - 3 == 51 then
						Upvalues[1] = Stack[5]
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
				elseif (pointer * 5) + (pointer * 29) == 170 then
					do
						if pointer + 1 == 6 then
			Temp[1] = 2
Temp[11] = Constants
Temp[6] = 5
Stack[Temp[1]] = Temp[11][Temp[6]]
		end
					end
				end
			else
				if (pointer * pointer) + (2 * pointer) == 288 then
					do
						if (pointer + 45) > pointer then
			do
				if pointer * 2 - 2 == 30 then
					Temp[2] = 6
Temp[15] = 15
Temp[5] = Constants[Temp[15]]
Stack[Temp[2]] = vmEnv[Temp[5]] or Env[Temp[5]]
				end
			end
		else
			Temp[8] = 3
			Temp[16] = Constants
			Temp[20] = 20
			Stack[Temp[5]] = Temp[18][Temp[10]]
		end
					end
				elseif (pointer * 3) + (pointer * 42) == 450 then
					do
						if pointer + 14 == 24 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\122\110\092\092", "1237")),(decrypt("\021\051", "2840")),(decrypt("\090\091\111\082\089\087\092\071", "2777")),(decrypt("\087\088\090\053", "2893")),(decrypt("\084\081\083\035\109\082\094\088\111\104\047", "1784")),(decrypt("\092\104\084\106\109\095", "2444")),(decrypt("\003\094\085\094\091\109\082\100", "981")),}

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
		if (pointer * 5) + pointer <= 84 then
	if (pointer * pointer) + (15 * pointer) <= 154 then
		if (pointer * 7) + pointer <= 24 then
			if (pointer * pointer) + (11 * pointer) == 26 then
				do
					do
			if pointer + 6 ~= 16 then
					if pointer * 3 - 12 == -6 then
						Stack[2] = Stack[2][Stack[0]]
	
				else
					Stack[7] = nil
				end
				end
		end
				end
			elseif (pointer * pointer * 3) + pointer == 4 then
				do
					if (pointer + 75) > pointer then
			do
				if pointer + 6 == 7 then
						Stack[2] = Upvalues[0]
				end
			end
		else
			Stack[5] = nil
		end
				end
			elseif (pointer * pointer) + 14 == 23 then
				do
					if (pointer - 88) > pointer then
			if pointer > 170 then Stack[6] = Stack[6] end
		else
			do
				if pointer - 5 == -2 then
					if pointer + 4 ~= 12 then
					if pointer * 2 + 12 == 18 then
						if Stack[2] ~= Constants[4] then pointer = pointer + 1 end
				end
				end
				end
			end
		end
				end
			end
		else
			if (pointer * pointer) + (10 * pointer) == 75 then
				do
					if pointer + 3 == 8 then
				Stack[3] = Stack[2][Constants[3]]
	
		end
				end
			elseif (pointer * 13) + (pointer * 13) == 104 then
				do
					do
			if pointer - 10 == -6 then
					if pointer - 7 == -3 then
					pointer = pointer + 3 
				end
				elseif pointer - 10 == 14 then
					Stack[4] = Env[4]
				end
		end
				end
			elseif (pointer * pointer) + (9 * pointer) == 90 then
				do
					do
			if pointer + 15 == 21 then
					if pointer + 2 == 8 then
					if pointer + 4 == 14 then
					Stack[4] = nil
				end
					if Stack[3] < Stack[1] then pointer = pointer + 1 end
				end
				end
		end
				end
			elseif (pointer * 12) + (pointer * 38) == 350 then
				do
					if pointer + 4 == 11 then
			pointer = pointer + 5 
		end
				end
			end
		end
	else
		if pointer * pointer <= 100 then
			if (pointer * pointer * 5) + pointer == 414 then
				do
					do
			if pointer * 3 - 4 == 23 then
					if pointer + 11 == 20 then
					if pointer + 2 == 21 then
					Stack[4] = nil
				end
				Temp[10] = 4
Temp[1] = Constants
Temp[9] = 5
Stack[Temp[10]] = Temp[1][Temp[9]]
				end
				else
					Stack[1] = nil
				end
		end
				end
			elseif (pointer * pointer) + (12 * pointer) == 220 then
				do
					if pointer + 3 == 13 then
			Temp[4] = 5
Temp[5] = 0
Stack[Temp[4]] = Stack[Temp[5]]
		end
				end
			elseif (pointer * pointer) + 47 == 111 then
				do
					if (pointer + 17) > pointer then
			do
				if pointer + 12 == 24 then
					Stack[2] = nil
				end
				Temp[13] = 3
Temp[2] = byte == pairs
Stack[Temp[13]] = Temp[6]
			end
		else
			if pointer > 69 then Stack[4] = Stack[5] end
		end
				end
			end
		else
			if (pointer * 13) + (pointer * 37) == 600 then
				do
					do
			if pointer - 14 == -2 then
					if pointer + 15 == 27 then
					if pointer + 2 == 26 then
					Stack[3] = nil
				end
					return Stack[3], Stack[4]
				end
				elseif pointer - 14 == 16 then
					Stack[6] = Env[1]
				end
		end
				end
			elseif (pointer * 12) + (pointer * 37) == 637 then
				do
					if (pointer - 19) > pointer then
			Stack[6] = (1 == 1)
		else
			do
				if pointer * 2 - 8 == 18 then
						Stack[3] = Stack[2][Constants[3]]
	
				end
			end
		end
				end
			elseif (pointer * pointer) + (15 * pointer) == 286 then
				do
					if (pointer - 39) > pointer then
			Temp[5] = 1
			Temp[18] = Constants
			Temp[7] = 13
			Stack[Temp[8]] = Temp[8][Temp[8]]
		else
			do
				if pointer - 5 == 6 then
					if pointer + 14 == 25 then
					if pointer * 3 - 8 == 25 then
						Temp[1] = ""
	for i = 4, 5 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[4] = Temp[1]
	
				else
					Stack[4] = nil
				end
				end
				end
			end
		end
				end
			elseif (pointer * pointer * 2) + pointer == 406 then
				do
					if (pointer - 23) > pointer then
			Stack[2] = (0 == 1)
		else
			do
				if pointer * 3 - 6 == 36 then
						Stack[3] = Stack[3] - Stack[1]
				else
					Stack[2] = nil
				end
			end
		end
				end
			end
		end
	end
else
	if (pointer * 4) + pointer <= 105 then
		if (pointer * pointer) + (3 * pointer) <= 340 then
			if (pointer * 13) + (pointer * 39) == 780 then
				do
					if (pointer - 95) > pointer then
			Stack[3] = nil
		else
			do
				if pointer + 11 == 32 then
					Stack[4] = nil
				end
					Stack[2][Constants[3]] = Stack[3]
			end
		end
				end
			elseif (pointer * pointer * 2) + pointer == 528 then
				do
					if pointer + 3 == 19 then
				Stack[3] = Upvalues[1]
		end
				end
			elseif (pointer * pointer * 3) + pointer == 884 then
				do
					if (pointer - 89) > pointer then
			Temp[1] = 2
			Temp[5] = Constants
			Temp[3] = 7
			Stack[Temp[4]] = Temp[18][Temp[14]]
		else
			do
				if pointer + 13 == 30 then
						Stack[4] = Stack[2][Constants[6]]
	
				end
			end
		end
				end
			end
		else
			if (pointer * pointer * 3) + pointer == 1344 then
				do
					if (pointer + 91) > pointer then
			do
				if pointer * 2 + 13 == 55 then
					if pointer * 2 - 8 == 34 then
						Stack[3] = Stack[2][Constants[3]]
	
				end
				end
			end
		else
			if pointer > 77 then Stack[7] = Stack[3] end
		end
				end
			elseif (pointer * 8) + (pointer * 17) == 450 then
				do
					do
			if pointer + 8 == 26 then
					if pointer * 2 + 2 == 38 then
					if pointer * 2 - 9 == 27 then
						Stack[4] = Stack[4] * Stack[1]
				end
				end
				end
		end
				end
			elseif (pointer * pointer) + 39 == 439 then
				do
					if (pointer + 61) > pointer then
			do
				if pointer * 2 + 8 == 48 then
					if pointer * 3 - 12 == 48 then
					if pointer + 5 ~= 45 then
						Upvalues[1] = Stack[3]
				end
				else
					Stack[6] = nil
				end
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
				end
			elseif (pointer * pointer * 2) + pointer == 741 then
				do
					if (pointer + 93) > pointer then
			do
				if pointer - 12 == 7 then
					if pointer * 3 - 10 == 47 then
					if pointer + 6 ~= 37 then
						Stack[3] = Stack[3] - Stack[4]
				end
				else
					Stack[4] = nil
				end
				elseif pointer - 12 == 26 then
					Stack[5] = Env[8]
				end
			end
		else
			Temp[2] = 1
			Temp[8] = Constants
			Temp[1] = 6
			Stack[Temp[6]] = Temp[3][Temp[15]]
		end
				end
			end
		end
	else
		if pointer * pointer <= 576 then
			if (pointer * 8) + (pointer * 33) == 943 then
				do
					if pointer + 14 == 37 then
			pointer = pointer + 2 
		end
				end
			elseif (pointer * 13) + (pointer * 27) == 880 then
				do
					if pointer + 4 == 26 then
				if Stack[3] == Constants[2] then pointer = pointer + 1 end
		end
				end
			elseif (pointer * 2) + (pointer * 35) == 888 then
				do
					if (pointer + 50) > pointer then
			do
				if pointer * 3 - 2 == 70 then
						Stack[3] = Upvalues[0]
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
			end
		else
			if (pointer * pointer * 4) + pointer == 2730 then
				do
					do
			if pointer - 2 == 24 then
					if pointer + 11 ~= 42 then
					Temp[1] = 3
Temp[15] = ttostring ~= __metatable
Stack[Temp[1]] = Temp[16]
				end
				end
		end
				end
			elseif (pointer * pointer * 5) + pointer == 3150 then
				do
					do
			if pointer * 3 - 10 == 65 then
					if pointer + 5 == 48 then
					Stack[4] = nil
				end
				if pointer + 11 == 36 then
						Stack[3][Stack[0]] = Constants[4]
				end
				else
					Stack[6] = nil
				end
		end
				end
			elseif (pointer * pointer) + 34 == 818 then
				do
					do
			if pointer - 8 == 20 then
						return
				elseif pointer - 8 == 40 then
					Stack[2] = Env[7]
				end
		end
				end
			elseif (pointer * pointer) + 32 == 761 then
				do
					if (pointer - 94) > pointer then
			Stack[6] = -Stack[1]
		else
			do
				if pointer + 14 == 41 then
						return Stack[3]
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
				elseif (pointer * pointer) + (10 * pointer) == 299 then
					do
						if (pointer + 19) > pointer then
			do
				if pointer * 2 + 4 == 30 then
					if pointer - 2 == 11 then
					if pointer - 11 == 2 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\030\056", "635")),(decrypt("\083\104\025", "1694")),(decrypt("\037\045", "2299")),(decrypt("\089\087\080\088", "319")),(decrypt("\095\106\081\107\110\093", "1615")),(decrypt("\095\094\082\108\091\046\090\100\089\106\103\082\005\047", "489")),(decrypt("\085\088\089\086\089", "2193")),((decrypt("\021\019\031\029\028\029\020\031\024", "2685"))),(decrypt("\090\111\108\086\109", "1755")),(decrypt("\086\104\084\093\091", "1044")),(decrypt("\033\094", "617")),(decrypt("\008\090\108\105\014\104\086\080\080\080\109", "530")),(decrypt("\094\088\111\083\095\087\093\068", "647")),(decrypt("\119\093\080\081\081\081\104", "614")),(decrypt("\008\013\092\104\086\108", "2050")),(decrypt("\083\094\104\083\080\090", "390")),}

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
		if (pointer * pointer) + (7 * pointer) <= 540 then
	if (pointer * pointer) + (9 * pointer) <= 162 then
		if pointer * pointer <= 16 then
			if (pointer * pointer) + 10 == 26 then
				do
					if pointer + 11 == 15 then
				Stack[1], Stack[2], Stack[3] = Stack[1](Stack[2])
		end
				end
			elseif (pointer * 12) + (pointer * 36) == 96 then
				do
					if pointer + 4 == 6 then
			Temp[11] = 1
Temp[14] = 10
Temp[10] = Constants[Temp[14]]
Stack[Temp[11]] = vmEnv[Temp[10]] or Env[Temp[10]]
		end
				end
			elseif (pointer * pointer) + 40 == 49 then
				do
					if pointer + 9 == 12 then
				Stack[2] = Upvalues[0]
		end
				end
			elseif (pointer * pointer * 3) + pointer == 4 then
				do
					if (pointer + 30) > pointer then
			do
				if pointer - 6 == -5 then
					if pointer + 10 == 11 then
					if pointer - 5 == -4 then
						Stack[0] = {}
				end
				end
				elseif pointer - 6 == 8 then
					Stack[5] = Env[3]
				end
			end
		else
			Stack[6] = (1 == 1)
		end
				end
			end
		else
			if (pointer * 15) + pointer <= 96 then
				if (pointer * pointer) + 18 == 43 then
					do
						if pointer + 8 == 13 then
			pointer = pointer + 3 
		end
					end
				elseif (pointer * 10) + (pointer * 38) == 288 then
					do
						if pointer + 9 == 15 then
				Stack[5] = #Stack[0]
		end
					end
				end
			else
				if (pointer * pointer) + (5 * pointer) == 126 then
					do
						do
			if pointer * 3 - 10 == 17 then
					if pointer + 13 == 22 then
					if pointer * 2 - 1 == 17 then
					    local r1 = Stack[1](Stack[2], Stack[3])
    Stack[4] = r1
    if Stack[4] ~= nil then
        Stack[3] = Stack[4]
    else
        pointer = pointer + 1
    end
    
				end
				end
				else
					Stack[3] = nil
				end
		end
					end
				elseif (pointer * pointer) + (3 * pointer) == 88 then
					do
						if (pointer + 68) > pointer then
			do
				if pointer - 1 == 7 then
						Stack[0][Stack[5]] = Stack[4]
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
					end
				elseif (pointer * pointer) + (15 * pointer) == 154 then
					do
						do
			if pointer + 15 == 38 then
					Stack[7] = nil
				end
					Stack[5] = Stack[5] + Constants[1]
		end
					end
				end
			end
		end
	else
		if (pointer * 7) + pointer <= 120 then
			if pointer * pointer <= 121 then
				if (pointer * pointer) + 16 == 116 then
					do
						do
			if pointer + 4 ~= 33 then
					pointer = pointer + -5 
				end
		end
					end
				elseif (pointer * pointer * 4) + pointer == 495 then
					do
						do
			if pointer * 2 + 3 == 25 then
					Temp[14] = 1
Temp[8] = 9
Temp[13] = Constants[Temp[8]]
Stack[Temp[14]] = vmEnv[Temp[13]] or Env[Temp[13]]
	Stack[1] = Stack[1][Constants[4]]
	
	pointer = pointer + 1
				end
		end
					end
				end
			else
				if (pointer * pointer) + (12 * pointer) == 325 then
					do
						do
			if pointer - 13 == 0 then
					if pointer * 3 - 3 == 36 then
					if pointer * 3 - 5 == 34 then
					Temp[3] = 2
Temp[13] = 0
Stack[Temp[3]] = Stack[Temp[13]]
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
				elseif (pointer * 7) + (pointer * 43) == 700 then
					do
						if (pointer - 40) > pointer then
			Stack[1] = Stack[6] or Constants[4+1]
		else
			do
				if pointer * 2 + 10 == 38 then
					if pointer * 2 + 12 == 40 then
						Stack[1](Stack[2])
				end
				end
			end
		end
					end
				elseif (pointer * pointer) + (8 * pointer) == 345 then
					do
						if pointer + 12 == 27 then
			Temp[10] = 1
Temp[1] = 16
Temp[16] = Constants[Temp[1]]
Stack[Temp[10]] = vmEnv[Temp[16]] or Env[Temp[16]]
		end
					end
				end
			end
		else
			if pointer * pointer <= 289 then
				if (pointer * pointer) + (2 * pointer) == 323 then
					do
						if (pointer + 56) > pointer then
			do
				if pointer - 15 == 2 then
						Stack[1], Stack[2], Stack[3] = Stack[1](Stack[2])
				end
			end
		else
			Stack[6] = Stack[3] or Constants[7+1]
		end
					end
				elseif (pointer * pointer) + 5 == 261 then
					do
						if (pointer + 61) > pointer then
			do
				if pointer + 2 ~= 34 then
					Temp[15] = 2
Temp[10] = 0
Stack[Temp[15]] = Stack[Temp[10]]
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
					end
				end
			else
				if (pointer * 7) + (pointer * 7) == 280 then
					do
						do
			if pointer + 11 ~= 35 then
					if pointer - 4 == 16 then
					if pointer - 10 == 10 then
						Stack[6] = Stack[6][Stack[5]]
	
				end
				elseif pointer - 4 == 25 then
					Stack[4] = Env[2]
				end
				end
		end
					end
				elseif (pointer * pointer) + (10 * pointer) == 551 then
					do
						if pointer + 14 == 33 then
				Stack[6] = Upvalues[0]
		end
					end
				elseif (pointer * 13) + (pointer * 18) == 558 then
					do
						if pointer + 9 == 27 then
			pointer = pointer + 13 
		end
					end
				end
			end
		end
	end
else
	if pointer * pointer <= 841 then
		if pointer * pointer <= 576 then
			if (pointer * pointer) + 22 == 463 then
				do
					if pointer + 12 == 33 then
			Temp[3] = 7
Temp[4] = 7
Temp[13] = Constants[Temp[4]]
Stack[Temp[3]] = vmEnv[Temp[13]] or Env[Temp[13]]
		end
				end
			elseif (pointer * pointer) + (10 * pointer) == 704 then
				do
					do
			if pointer * 2 - 1 == 43 then
					if pointer - 3 == 19 then
					if pointer + 1 == 23 then
					Temp[12] = 8
Temp[16] = 5
Stack[Temp[12]] = Stack[Temp[16]]
				end
				elseif pointer - 3 == 23 then
					Stack[6] = Env[8]
				end
				end
		end
				end
			elseif (pointer * pointer * 5) + pointer == 2668 then
				do
					do
			if pointer - 13 == 10 then
					if pointer - 10 == 13 then
					Temp[14] = 9
Temp[4] = Constants
Temp[2] = 11
Stack[Temp[14]] = Temp[4][Temp[2]]
				elseif pointer - 10 == 15 then
					Stack[1] = Env[1]
				end
				elseif pointer - 13 == 25 then
					Stack[6] = Env[1]
				end
		end
				end
			elseif (pointer * pointer) + (14 * pointer) == 912 then
				do
					do
			if pointer - 15 == 9 then
					if pointer + 3 == 46 then
					Stack[4] = nil
				end
					Stack[10] = Stack[6][Constants[13]]
	
				elseif pointer - 15 == 21 then
					Stack[2] = Env[1]
				end
		end
				end
			end
		else
			if pointer * pointer <= 676 then
				if (pointer * pointer) + (4 * pointer) == 725 then
					do
						if pointer + 5 == 30 then
			Temp[10] = 11
Temp[2] = Constants
Temp[11] = 3
Stack[Temp[10]] = Temp[2][Temp[11]]
		end
					end
				elseif (pointer * pointer) + (11 * pointer) == 962 then
					do
						if pointer + 5 == 31 then
				Stack[12] = Stack[6][Constants[5]]
	
		end
					end
				end
			else
				if (pointer * 12) + (pointer * 43) == 1540 then
					do
						if pointer + 6 == 34 then
				Stack[12] = Stack[12] * Stack[13]
		end
					end
				elseif (pointer * 8) + (pointer * 37) == 1215 then
					do
						if pointer + 5 == 32 then
				Stack[13] = Stack[6][Constants[13]]
	
		end
					end
				elseif (pointer * pointer) + (2 * pointer) == 899 then
					do
						if pointer + 4 == 33 then
			Temp[15] = 13
Temp[5] = Constants
Temp[13] = 2
Stack[Temp[15]] = Temp[5][Temp[13]]
		end
					end
				end
			end
		end
	else
		if pointer * pointer <= 1156 then
			if (pointer * 3) + pointer <= 124 then
				if (pointer * pointer) + 20 == 920 then
					do
						do
			if pointer + 15 ~= 51 then
						Temp[1] = ""
	for i = 8, 13 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[8] = Temp[1]
	
				end
		end
					end
				elseif (pointer * 4) + (pointer * 18) == 682 then
					do
						if pointer + 10 == 41 then
				Stack[7](Stack[8])
		end
					end
				end
			else
				if (pointer * pointer) + 29 == 1118 then
					do
						if pointer + 14 == 47 then
			pointer = pointer + -15 
		end
					end
				elseif (pointer * pointer * 4) + pointer == 4658 then
					do
						if pointer + 12 == 46 then
			Temp[2] = 1
Temp[8] = 7
Temp[4] = Constants[Temp[8]]
Stack[Temp[2]] = vmEnv[Temp[4]] or Env[Temp[4]]
		end
					end
				elseif (pointer * pointer) + 15 == 1039 then
					do
						if (pointer + 38) > pointer then
			do
				if pointer * 2 - 4 == 60 then
					if pointer - 3 == 29 then
					    local r1, r2 = Stack[1](Stack[2], Stack[3])
    Stack[4] = r1
        Stack[5] = r2
    if Stack[4] ~= nil then
        Stack[3] = Stack[4]
    else
        pointer = pointer + 1
    end
    
				end
				end
			end
		else
			Stack[8] = -Stack[6]
		end
					end
				end
			end
		else
			if pointer * pointer <= 1296 then
				if (pointer * pointer * 2) + pointer == 2485 then
					do
						do
			if pointer - 9 == 26 then
					if pointer - 5 == 30 then
					if pointer * 2 + 11 == 81 then
					Temp[2] = 2
Temp[5] = Constants
Temp[13] = 6
Stack[Temp[2]] = Temp[5][Temp[13]]
				end
				end
				end
		end
					end
				elseif (pointer * pointer) + (11 * pointer) == 1692 then
					do
						if pointer + 4 == 40 then
				Stack[3] = Upvalues[1]
		end
					end
				end
			else
				if (pointer * pointer * 2) + pointer == 2775 then
					do
						if (pointer - 64) > pointer then
			Stack[5] = nil
		else
			do
				if pointer * 3 - 8 == 103 then
					if pointer - 2 == 35 then
					if pointer - 12 == 25 then
						Temp[1] = ""
	for i = 2, 3 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[2] = Temp[1]
	
				end
				end
				else
					Stack[5] = nil
				end
			end
		end
					end
				elseif (pointer * pointer * 4) + pointer == 5814 then
					do
						do
			if pointer + 7 == 54 then
					Stack[3] = nil
				end
				if pointer - 11 == 27 then
					if pointer * 2 - 4 == 72 then
						Stack[1](Stack[2])
				end
				end
		end
					end
				elseif (pointer * pointer) + (7 * pointer) == 1794 then
					do
						if (pointer - 32) > pointer then
			Stack[5] = -Stack[1]
		else
			do
				if pointer + 5 == 52 then
					Stack[6] = nil
				end
					return
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
			Temp[12] = 3
			Temp[11] = Constants
			Temp[19] = 1
			Stack[Temp[7]] = Temp[13][Temp[10]]
		end
					end
				end
			end
		end
	else
		if (pointer * pointer) + (11 * pointer) <= 726 then
			if (pointer * 4) + pointer <= 90 then
				if (pointer * 10) + (pointer * 30) == 680 then
					do
						do
			if pointer * 3 - 9 == 42 then
					if pointer + 12 == 34 then
					Stack[4] = nil
				end
				if pointer + 4 == 38 then
					Stack[1] = nil
				end
				Temp[16] = 7
Temp[14] = 3
Stack[Temp[16]] = Stack[Temp[14]]
				else
					Stack[5] = nil
				end
		end
					end
				elseif (pointer * pointer) + (4 * pointer) == 396 then
					do
						if (pointer - 28) > pointer then
			Stack[8] = Stack[8] or Constants[2+1]
		else
			do
				if pointer * 2 - 10 == 26 then
					if pointer * 2 + 10 == 46 then
					if pointer + 15 == 53 then
					Stack[5] = nil
				end
				Temp[6] = 8
Temp[15] = Constants
Temp[13] = 11
Stack[Temp[6]] = Temp[15][Temp[13]]
				end
				end
			end
		end
					end
				end
			else
				if (pointer * pointer) + 21 == 505 then
					do
						do
			if pointer + 8 == 30 then
					if pointer * 2 + 6 == 50 then
					if pointer - 10 == 12 then
						Temp[1] = {}
	for i = 6 + 1, top do
		Temp[1][i - 6] = Stack[i]
	end
	Temp[2] = {Stack[6](unpack(Temp[1], 1, top - 6))}
		for i = 1, 0 do
		Stack[6 + i - 1] = Temp[2][i]
	end
	
	
				elseif pointer - 10 == 31 then
					Stack[5] = Env[8]
				end
				end
				end
		end
					end
				elseif (pointer * pointer * 2) + pointer == 820 then
					do
						if (pointer + 6) > pointer then
			do
				if pointer + 3 == 39 then
					Stack[3] = nil
				end
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
			end
		else
						Temp[18] = vmEnv
			Temp[6] = 2
			Temp[11] = Constants[Temp[5]]
			Temp[1] = 1
			Temp[12][Temp[13]] = Temp[19]
		end
					end
				elseif (pointer * pointer) + (5 * pointer) == 456 then
					do
						if (pointer + 61) > pointer then
			do
				if pointer + 9 == 28 then
					if pointer * 2 - 4 == 34 then
					if pointer * 2 + 5 == 43 then
					Temp[9] = 9
Temp[11] = Constants
Temp[10] = 10
Stack[Temp[9]] = Temp[11][Temp[10]]
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
			if (pointer * 9) + pointer <= 240 then
				if (pointer * pointer * 5) + pointer == 2904 then
					do
						if (pointer - 39) > pointer then
			Stack[5] = -Stack[6]
		else
			do
				if pointer + 5 == 37 then
					Stack[7] = nil
				end
				if pointer - 4 == 20 then
					Temp[9] = 7
Temp[14] = 3
Stack[Temp[9]] = Stack[Temp[14]]
				end
			end
		end
					end
				elseif (pointer * pointer * 2) + pointer == 1081 then
					do
						do
			if pointer + 5 == 29 then
					Stack[3] = nil
				end
				Temp[13] = 6
Temp[10] = 15
Temp[3] = Constants[Temp[10]]
Stack[Temp[13]] = vmEnv[Temp[3]] or Env[Temp[3]]
		end
					end
				end
			else
				if (pointer * 12) + (pointer * 38) == 1350 then
					do
						do
			if pointer - 7 == 20 then
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
				elseif pointer - 7 == 34 then
					Stack[8] = Env[5]
				end
		end
					end
				elseif (pointer * 15) + (pointer * 42) == 1482 then
					do
						if pointer + 1 == 27 then
			Temp[15] = 9
Temp[5] = Constants
Temp[4] = 16
Stack[Temp[15]] = Temp[5][Temp[4]]
		end
					end
				elseif (pointer * pointer * 3) + pointer == 1900 then
					do
						if (pointer + 74) > pointer then
			do
				if pointer * 3 - 7 == 68 then
					if pointer + 10 == 37 then
					Stack[5] = nil
				end
				Temp[16] = 8
Temp[4] = Constants
Temp[5] = 2
Stack[Temp[16]] = Temp[4][Temp[5]]
				else
					Stack[4] = nil
				end
			end
		else
			Stack[1] = Stack[1] or Constants[5+1]
		end
					end
				end
			end
		end
	end
else
	if (pointer * 11) + pointer <= 468 then
		if (pointer * 2) + pointer <= 99 then
			if (pointer * pointer) + (11 * pointer) <= 1230 then
				if (pointer * pointer) + (14 * pointer) == 1247 then
					do
						if pointer + 13 == 42 then
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
				elseif (pointer * pointer * 2) + pointer == 1830 then
					do
						if pointer + 14 == 44 then
			Temp[6] = 6
Temp[3] = 15
Temp[5] = Constants[Temp[3]]
Stack[Temp[6]] = vmEnv[Temp[5]] or Env[Temp[5]]
		end
					end
				end
			else
				if (pointer * pointer) + (10 * pointer) == 1271 then
					do
						do
			if pointer * 2 - 9 == 53 then
					if pointer * 2 - 2 == 60 then
					if pointer + 9 == 40 then
					Temp[6] = 7
Temp[16] = 3
Stack[Temp[6]] = Stack[Temp[16]]
				end
				end
				end
		end
					end
				elseif (pointer * pointer * 4) + pointer == 4128 then
					do
						if pointer + 8 == 40 then
			Temp[10] = 8
Temp[4] = Constants
Temp[13] = 7
Stack[Temp[10]] = Temp[4][Temp[13]]
		end
					end
				elseif (pointer * pointer) + 39 == 1128 then
					do
						if pointer + 2 == 35 then
			Temp[2] = 9
Temp[15] = Constants
Temp[6] = 3
Stack[Temp[2]] = Temp[15][Temp[6]]
		end
					end
				end
			end
		else
			if pointer * pointer <= 1296 then
				if (pointer * pointer) + 14 == 1170 then
					do
						if pointer + 10 == 44 then
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
		end
					end
				elseif (pointer * pointer * 3) + pointer == 3924 then
					do
						if pointer + 5 == 41 then
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
				end
			else
				if (pointer * pointer * 3) + pointer == 4144 then
					do
						if pointer + 2 == 39 then
			Temp[3] = 6
Temp[7] = 15
Temp[11] = Constants[Temp[7]]
Stack[Temp[3]] = vmEnv[Temp[11]] or Env[Temp[11]]
		end
					end
				elseif (pointer * pointer) + 37 == 1558 then
					do
						do
			if pointer - 5 == 34 then
					Temp[15] = 8
Temp[9] = Constants
Temp[12] = 11
Stack[Temp[15]] = Temp[9][Temp[12]]
				elseif pointer - 5 == 39 then
					Stack[7] = Env[4]
				end
		end
					end
				elseif (pointer * pointer) + (8 * pointer) == 1748 then
					do
						do
			if pointer * 3 - 3 == 111 then
					if pointer + 4 == 42 then
					Temp[5] = 7
Temp[7] = 4
Stack[Temp[5]] = Stack[Temp[7]]
				end
				else
					Stack[5] = nil
				end
		end
					end
				end
			end
		end
	else
		if (pointer * 7) + pointer <= 360 then
			if (pointer * pointer) + (13 * pointer) <= 2310 then
				if (pointer * pointer) + (7 * pointer) == 2058 then
					do
						if pointer + 3 == 45 then
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
				elseif (pointer * pointer) + (12 * pointer) == 2080 then
					do
						if (pointer - 64) > pointer then
			Stack[2] = nil
		else
			do
				if pointer - 10 == 30 then
					if pointer + 3 == 54 then
					Stack[3] = nil
				end
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
				elseif pointer - 10 == 48 then
					Stack[7] = Env[8]
				end
			end
		end
					end
				end
			else
				if (pointer * 5) + (pointer * 46) == 2193 then
					do
						if (pointer + 52) > pointer then
			do
				if pointer + 10 == 53 then
					Temp[7] = 6
Temp[4] = 15
Temp[11] = Constants[Temp[4]]
Stack[Temp[7]] = vmEnv[Temp[11]] or Env[Temp[11]]
				end
			end
		else
			if pointer > 101 then Stack[1] = Stack[3] end
		end
					end
				elseif (pointer * pointer * 2) + pointer == 4095 then
					do
						do
			if pointer * 3 - 2 == 133 then
					if pointer - 13 == 32 then
					Temp[14] = 8
Temp[12] = Constants
Temp[15] = 13
Stack[Temp[14]] = Temp[12][Temp[15]]
				elseif pointer - 13 == 48 then
					Stack[6] = Env[2]
				end
				else
					Stack[4] = nil
				end
		end
					end
				elseif (pointer * pointer) + 5 == 1941 then
					do
						if (pointer + 88) > pointer then
			do
				if pointer * 2 - 8 == 80 then
					if pointer + 4 == 67 then
					Stack[1] = nil
				end
				if pointer * 3 - 5 == 127 then
					Temp[7] = 7
Temp[10] = 4
Stack[Temp[7]] = Stack[Temp[10]]
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
		else
			if (pointer * 6) + pointer <= 336 then
				if (pointer * pointer) + 38 == 2154 then
					do
						if pointer + 7 == 53 then
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
		end
					end
				elseif (pointer * pointer * 3) + pointer == 6960 then
					do
						if (pointer - 95) > pointer then
						Temp[2] = vmEnv
			Temp[1] = 4
			Temp[12] = Constants[Temp[14]]
			Temp[8] = 19
			Temp[15][Temp[6]] = Temp[6]
		else
			do
				if pointer + 12 == 60 then
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
		end
					end
				end
			else
				if (pointer * pointer * 5) + pointer == 13056 then
					do
						if pointer + 9 == 60 then
				return
		end
					end
				elseif (pointer * pointer) + (12 * pointer) == 2989 then
					do
						do
			if pointer + 14 == 63 then
					Temp[9] = 6
Temp[7] = 5
Stack[Temp[9]] = Stack[Temp[7]]
				end
		end
					end
				elseif (pointer * pointer) + 40 == 2540 then
					do
						if pointer + 8 == 58 then
				Stack[6]()
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