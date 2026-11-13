return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\108\105\104\040\029\024\016\032\024\030\019\032\006\036", "2337")),(decrypt("\024\025\061", "2464")),(decrypt("\028\057", "2280")),(decrypt("\094\089\080\092\091", "900")),(decrypt("\027\021\029\024\025\028\005\056", "1053")),(decrypt("\103\115\000\005\125\127\003\000\122\009\002", "1598")),(decrypt("\017", "2037")),(decrypt("\028\031\050", "859")),(decrypt("\124\106\087\091\015\084\094\010\109\082\084\107", "2270")),(decrypt("\101\084\094\092\106\092", "827")),(decrypt("\026\024\061", "2461")),(decrypt("\046\029\018\028\111\066\043\017\031\091\068\041\021\027\108", "2175")),(decrypt("\014\093\093\106\084\087\089\105", "1192")),(decrypt("\046", "981")),(decrypt("\021\058", "2127")),(decrypt("\105\083\106\087\087\003\036", "302")),(decrypt("\088\092\093\088\087\105", "2748")),(decrypt("\010\092\095\106\084\089\084\068\106\091\084\083\087", "2045")),(decrypt("\022\018\059", "990")),(decrypt("\106\109", "243")),(decrypt("\026\059", "2006")),(decrypt("\086\088\088\083\109\091\009\032", "1187")),(decrypt("\028\020\063", "434")),(decrypt("\030\017\051", "2683")),(decrypt("\001\099\098\101\094\083", "998")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
				if (pointer * 9) + pointer <= 310 then
	if pointer * pointer <= 225 then
		if (pointer * pointer) + (11 * pointer) <= 126 then
			if (pointer * 10) + pointer <= 33 then
				if (pointer * 4) + (pointer * 32) == 108 then
					do
						if (pointer - 95) > pointer then
						Temp[2] = vmEnv
			Temp[1] = 4
			Temp[12] = Constants[Temp[14]]
			Temp[8] = 19
			Temp[15][Temp[6]] = Temp[6]
		else
			do
				if pointer + 12 == 15 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\119\108\088\072", "2458")),(decrypt("\127\105\080\082\012\087\089\003\110\081\083\098", "1109")),(decrypt("\124\091\108\108\082\035\080\093\104\095\109\087\080\094", "604")),}

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
		if pointer * pointer <= 16 then
	if (pointer * pointer) + (8 * pointer) == 20 then
		do
			do
			if pointer - 15 == -13 then
					pointer = pointer + 2 
				elseif pointer - 15 == -9 then
					Stack[2] = Env[7]
				end
		end
		end
	elseif (pointer * pointer * 5) + pointer == 48 then
		do
			do
			if pointer + 11 ~= 31 then
					if pointer + 10 == 32 then
					Stack[3] = nil
				end
					return Stack[1]
				end
		end
		end
	elseif (pointer * pointer * 3) + pointer == 52 then
		do
			do
			if pointer + 9 ~= 15 then
					if pointer * 3 - 11 == 1 then
					if pointer * 2 - 2 == 6 then
					pointer = pointer + 3 
				end
				else
					Stack[6] = nil
				end
				end
		end
		end
	elseif (pointer * pointer) + 9 == 10 then
		do
			if (pointer + 76) > pointer then
			do
				if pointer + 15 ~= 25 then
						if Stack[0] < Stack[1] then pointer = pointer + 1 end
				end
			end
		else
						Temp[14] = vmEnv
			Temp[19] = 20
			Temp[9] = Constants[Temp[13]]
			Temp[17] = 16
			Temp[10][Temp[6]] = Temp[4]
		end
		end
	end
else
	if (pointer * 10) + pointer <= 66 then
		if (pointer * pointer) + 14 == 50 then
			do
				if (pointer + 83) > pointer then
			do
				if pointer * 2 + 13 == 25 then
					if pointer - 13 == -7 then
					pointer = pointer + 1 
				elseif pointer - 13 == 3 then
					Stack[1] = Env[1]
				end
				end
			end
		else
			Stack[8] = Stack[7] or Constants[8+1]
		end
			end
		elseif (pointer * pointer * 4) + pointer == 105 then
			do
				if pointer + 8 == 13 then
				if Stack[2] < Stack[0] then pointer = pointer + 1 end
		end
			end
		end
	else
		if (pointer * pointer) + (10 * pointer) == 171 then
			do
				if (pointer + 85) > pointer then
			do
				if pointer + 2 == 13 then
					Stack[4] = nil
				end
					return
			end
		else
			Temp[4] = 5
			Temp[12] = Constants
			Temp[16] = 12
			Stack[Temp[9]] = Temp[14][Temp[12]]
		end
			end
		elseif (pointer * 14) + (pointer * 31) == 315 then
			do
				if (pointer - 69) > pointer then
			if pointer > 104 then Stack[8] = Stack[4] end
		else
			do
				if pointer - 6 == 1 then
					if pointer - 4 == 3 then
						return Stack[2]
				elseif pointer - 4 == 20 then
					Stack[1] = Env[2]
				end
				elseif pointer - 6 == 8 then
					Stack[2] = Env[1]
				end
			end
		end
			end
		elseif (pointer * pointer) + (14 * pointer) == 176 then
			do
				if (pointer + 89) > pointer then
			do
				if pointer * 2 + 1 == 17 then
					if pointer + 14 == 29 then
					Stack[2] = nil
				end
				if pointer * 2 + 9 == 25 then
						return Stack[0]
				end
				end
			end
		else
						Temp[13] = vmEnv
			Temp[8] = 1
			Temp[5] = Constants[Temp[6]]
			Temp[8] = 14
			Temp[20][Temp[4]] = Temp[8]
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
				elseif (pointer * 2) + (pointer * 12) == 14 then
					do
						if pointer + 9 == 10 then
			Temp[16] = 0
Temp[14] = ttostring ~= __metatable
Stack[Temp[16]] = Temp[6]
		end
					end
				elseif (pointer * pointer) + (15 * pointer) == 34 then
					do
						if pointer + 15 == 17 then
			Temp[15] = vmEnv
Temp[13] = 6
Temp[9] = Constants[Temp[13]]
Temp[11] = 0
Temp[15][Temp[9]] = Temp[9]
		end
					end
				end
			else
				if (pointer * pointer) + (5 * pointer) == 36 then
					do
						do
			if pointer - 4 == 0 then
					if pointer + 2 ~= 20 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\117\122\125", "266")),(decrypt("\022\051", "180")),((decrypt("\031\018\027\023\024\031\029", "2728"))),(decrypt("\116\089\082\104\082\085", "2026")),}

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
		if (pointer * pointer) + (6 * pointer) <= 40 then
	if (pointer * 7) + (pointer * 23) == 120 then
		do
			if pointer + 4 == 8 then
				Stack[1] = Stack[0] % Stack[1]
		end
		end
	elseif (pointer * pointer) + 34 == 38 then
		do
			if pointer + 1 == 3 then
			pointer = pointer + 4 
		end
		end
	elseif (pointer * pointer * 4) + pointer == 39 then
		do
			if pointer + 14 == 17 then
			Temp[11] = 2
Temp[16] = 1
Stack[Temp[11]] = Stack[Temp[16]]
		end
		end
	elseif (pointer * pointer) + 32 == 33 then
		do
			if pointer + 7 == 8 then
				if Stack[1] ~= Constants[2] then pointer = pointer + 1 end
		end
		end
	end
else
	if (pointer * pointer) + 10 == 74 then
		do
			if (pointer - 24) > pointer then
			Temp[11] = 5
			Temp[3] = Constants
			Temp[14] = 15
			Stack[Temp[7]] = Temp[18][Temp[10]]
		else
			do
				if pointer * 2 - 1 == 15 then
					if pointer * 3 - 11 == 13 then
						return
				else
					Stack[6] = nil
				end
				end
			end
		end
		end
	elseif (pointer * 8) + (pointer * 7) == 105 then
		do
			if pointer + 9 == 16 then
				return Stack[0]
		end
		end
	elseif (pointer * pointer) + (9 * pointer) == 90 then
		do
			if pointer + 14 == 20 then
			pointer = pointer + -6 
		end
		end
	elseif (pointer * pointer) + 28 == 53 then
		do
			do
			if pointer + 12 == 21 then
					Stack[2] = nil
				end
				Temp[3] = 0
Temp[14] = 2
Stack[Temp[3]] = Stack[Temp[14]]
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
				elseif (pointer * pointer) + 41 == 77 then
					do
						if (pointer + 61) > pointer then
			do
				if pointer + 9 == 15 then
					if pointer * 2 - 4 == 8 then
					if pointer * 2 + 5 == 17 then
						local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[4] then
		C1 = {}
		local encoded = {(decrypt("\089\084\093\093\091\082\082\104", "2276")),(decrypt("\025\051", "1859")),(decrypt("\107\081\092\107\111\082", "179")),(decrypt("\008\102\097\095\106\099\082\106\091", "2996")),(decrypt("\098", "2729")),(decrypt("\090\096\107\091\109", "1828")),}

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
		if pointer * pointer <= 81 then
	if pointer * pointer <= 16 then
		if (pointer * pointer * 5) + pointer == 22 then
			do
				do
			if pointer - 13 == -11 then
					if pointer * 3 - 3 == 3 then
					if pointer * 3 - 5 == 1 then
					Temp[3] = 3
Temp[4] = Constants
Temp[13] = 2
Stack[Temp[3]] = Temp[4][Temp[13]]
				else
					Stack[1] = nil
				end
				else
					Stack[3] = nil
				end
				elseif pointer - 13 == -6 then
					Stack[6] = Env[2]
				end
		end
			end
		elseif (pointer * 10) + (pointer * 29) == 117 then
			do
				do
			if pointer + 5 ~= 9 then
					if pointer - 13 == -10 then
					if pointer + 2 == 7 then
					Stack[1] = nil
				end
					Stack[4] = #Stack[0]
				elseif pointer - 13 == 5 then
					Stack[6] = Env[1]
				end
				end
		end
			end
		elseif (pointer * pointer * 2) + pointer == 36 then
			do
				if pointer + 14 == 18 then
			Temp[12] = 5
Temp[16] = Constants
Temp[14] = 2
Stack[Temp[12]] = Temp[16][Temp[14]]
		end
			end
		elseif (pointer * pointer) + 30 == 31 then
			do
				do
			if pointer * 2 - 7 == -5 then
					if pointer + 8 == 9 then
						Stack[2] = {}
				end
				end
		end
			end
		end
	else
		if (pointer * 10) + pointer <= 66 then
			if (pointer * pointer) + 38 == 74 then
				do
					if pointer + 7 == 13 then
				Stack[7] = #Stack[2]
		end
				end
			elseif (pointer * 14) + (pointer * 5) == 95 then
				do
					if (pointer - 32) > pointer then
			Stack[5] = -Stack[1]
		else
			do
				if pointer + 5 == 18 then
					Stack[6] = nil
				end
				    Stack[3] = Stack[3] - Stack[5]
    pointer = pointer + 6
    
			end
		end
				end
			end
		else
			if (pointer * pointer) + 40 == 89 then
				do
					do
			if pointer * 2 + 10 == 24 then
					if pointer + 12 == 32 then
					Stack[7] = nil
				end
				if pointer * 3 - 5 == 16 then
						Stack[7] = Stack[7] + Constants[2]
				else
					Stack[4] = nil
				end
				end
		end
				end
			elseif (pointer * pointer) + 6 == 87 then
				do
					if (pointer + 38) > pointer then
			do
				if pointer * 2 - 4 == 14 then
					if pointer - 3 == 6 then
						Stack[9] = Stack[0][Stack[6]]
	
				end
				end
			end
		else
			Stack[8] = -Stack[6]
		end
				end
			elseif (pointer * pointer) + (4 * pointer) == 96 then
				do
					if pointer + 8 == 16 then
			Temp[4] = 8
Temp[2] = 1
Temp[10] = Constants[Temp[2]]
Stack[Temp[4]] = vmEnv[Temp[10]] or Env[Temp[10]]
		end
				end
			end
		end
	end
else
	if (pointer * pointer) + (14 * pointer) <= 351 then
		if (pointer * pointer) + (15 * pointer) == 250 then
			do
				if pointer + 6 == 16 then
				Stack[8] = Stack[8](Stack[9])
		end
			end
		elseif (pointer * 3) + (pointer * 44) == 564 then
			do
				do
			if pointer - 9 == 3 then
					if pointer * 2 - 3 == 21 then
					if pointer * 2 - 8 == 16 then
					    Stack[3] = Stack[3] + Stack[5]
    if (Stack[5] > 0 and Stack[3] <= Stack[4]) or (Stack[5] <= 0 and Stack[3] >= Stack[4]) then
        pointer = pointer + -7
        Stack[6] = Stack[3]
    end
    
				end
				end
				end
		end
			end
		elseif (pointer * 11) + (pointer * 21) == 352 then
			do
				if pointer + 6 == 17 then
				Stack[2][Stack[7]] = Stack[8]
		end
			end
		elseif (pointer * pointer) + (10 * pointer) == 299 then
			do
				if pointer + 9 == 22 then
			Temp[2] = 3
Temp[11] = 6
Temp[15] = Constants[Temp[11]]
Stack[Temp[2]] = vmEnv[Temp[15]] or Env[Temp[15]]
	Stack[3] = Stack[3][Constants[3]]
	
	pointer = pointer + 1
		end
			end
		end
	else
		if (pointer * pointer) + (8 * pointer) <= 384 then
			if (pointer * pointer) + (15 * pointer) == 450 then
				do
					do
			if pointer * 3 - 5 == 40 then
					if pointer - 7 == 8 then
					Temp[5] = 4
Temp[13] = 2
Stack[Temp[5]] = Stack[Temp[13]]
				end
				else
					Stack[8] = nil
				end
		end
				end
			elseif (pointer * pointer * 5) + pointer == 1296 then
				do
					if pointer + 2 == 18 then
			Temp[2] = 5
Temp[8] = 1
Stack[Temp[2]] = Stack[Temp[8]]
		end
				end
			end
		else
			if (pointer * pointer * 3) + pointer == 884 then
				do
					if (pointer - 76) > pointer then
			Stack[1] = (0 == 1)
		else
			do
				if pointer + 12 == 29 then
						return Stack[3](Stack[4], Stack[5])
				end
			end
		end
				end
			elseif (pointer * pointer) + (8 * pointer) == 513 then
				do
					if (pointer + 14) > pointer then
			do
				if pointer + 5 == 24 then
					if pointer + 15 == 52 then
					Stack[3] = nil
				end
				if pointer - 3 == 16 then
						return
				end
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
				end
			elseif (pointer * pointer) + (7 * pointer) == 450 then
				do
					do
			if pointer - 6 == 12 then
					if pointer + 10 == 28 then
					if pointer * 2 - 3 == 33 then
					            Temp[1] = {}
            Temp[2] = 0
            for i = 3, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
        
				end
				end
				elseif pointer - 6 == 25 then
					Stack[5] = Env[3]
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
			Temp[18] = 3
			Temp[9] = Constants
			Temp[16] = 2
			Stack[Temp[13]] = Temp[15][Temp[2]]
		end
					end
				elseif (pointer * pointer) + 11 == 60 then
					do
						if (pointer + 52) > pointer then
			do
				if pointer + 10 == 17 then
						Stack[4] = {}
				end
			end
		else
			if pointer > 101 then Stack[1] = Stack[3] end
		end
					end
				elseif (pointer * pointer) + (13 * pointer) == 90 then
					do
						if pointer + 14 == 19 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[3] then
		C1 = {}
		local encoded = {(decrypt("\013\084\091\106\094\089\085\073\104\094\088\086\080", "580")),(decrypt("\009\084\081\108", "722")),(decrypt("\091\101\107\106\095\084\087", "592")),(decrypt("\021\060", "2701")),(decrypt("\122\094\105\101\084\122\085\072\109", "1059")),(decrypt("\118\097\093\104\108\089\083\108\081\092\104\125\109\080\091\087\107\101", "1967")),(decrypt("\085\105\095\106", "1145")),(decrypt("\108\081\087\087\088", "1211")),(decrypt("\091\089\092\082", "1159")),(decrypt("\026\060", "2732")),(decrypt("\024\051", "1829")),}

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
		if pointer * pointer <= 144 then
	if pointer * pointer <= 25 then
		if (pointer * 9) + pointer <= 20 then
			if (pointer * pointer) + (3 * pointer) == 4 then
				do
					if pointer + 1 == 2 then
				if Stack[0] < Constants[11] then pointer = pointer + 1 end
		end
				end
			elseif (pointer * pointer) + 26 == 30 then
				do
					do
			if pointer - 8 == -6 then
					pointer = pointer + 2 
				elseif pointer - 8 == 14 then
					Stack[2] = Env[7]
				end
		end
				end
			end
		else
			if (pointer * pointer * 3) + pointer == 52 then
				do
					if pointer + 13 == 17 then
				return Stack[1]
		end
				end
			elseif (pointer * 8) + (pointer * 17) == 75 then
				do
					if (pointer + 75) > pointer then
			do
				if pointer + 6 == 9 then
					Temp[8] = 1
Temp[14] = byte == pairs
Stack[Temp[8]] = Temp[2]
				end
			end
		else
			Stack[5] = nil
		end
				end
			elseif (pointer * pointer) + 39 == 64 then
				do
					if (pointer + 31) > pointer then
			do
				if pointer * 2 + 7 == 17 then
					if pointer - 14 == -9 then
					Temp[3] = 1
Temp[6] = Constants
Temp[2] = 11
Stack[Temp[3]] = Temp[6][Temp[2]]
				elseif pointer - 14 == 8 then
					Stack[2] = Env[7]
				end
				end
			end
		else
			Temp[12] = 4
			Temp[5] = Constants
			Temp[9] = 17
			Stack[Temp[13]] = Temp[20][Temp[9]]
		end
				end
			end
		end
	else
		if pointer * pointer <= 64 then
			if (pointer * 3) + (pointer * 16) == 114 then
				do
					if pointer + 10 == 16 then
			Temp[4] = 2
Temp[15] = 7
Temp[14] = Constants[Temp[15]]
Stack[Temp[4]] = vmEnv[Temp[14]] or Env[Temp[14]]
	Stack[2] = Stack[2][Constants[8]]
	
	pointer = pointer + 1
		end
				end
			elseif (pointer * pointer) + 7 == 71 then
				do
					if (pointer + 23) > pointer then
			do
				if pointer - 5 == 3 then
					Temp[15] = 3
Temp[3] = 7
Temp[1] = Constants[Temp[3]]
Stack[Temp[15]] = vmEnv[Temp[1]] or Env[Temp[1]]
	Stack[3] = Stack[3][Constants[9]]
	
	pointer = pointer + 1
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
		else
			if (pointer * 13) + (pointer * 27) == 400 then
				do
					if pointer + 3 == 13 then
			Temp[5] = 4
Temp[4] = 0
Stack[Temp[5]] = Stack[Temp[4]]
		end
				end
			elseif (pointer * 2) + (pointer * 35) == 444 then
				do
					if pointer + 5 == 17 then
				Temp[1] = {}
	for i = 2 + 1, top do
		Temp[1][i - 2] = Stack[i]
	end
	Temp[2] = {Stack[2](unpack(Temp[1], 1, top - 2))}
		for i = 1, 1 do
		Stack[2 + i - 1] = Temp[2][i]
	end
	
	
		end
				end
			elseif (pointer * pointer) + 48 == 169 then
				do
					if (pointer - 52) > pointer then
			Stack[8] = nil
		else
			do
				if pointer - 3 == 8 then
						Temp[2] = {Stack[3](Stack[4])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[3] = nil
		top = 3
	else
		top = 3 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[3 + i - 1] = Temp[2][i]
		end
	end
	
				elseif pointer - 3 == 22 then
					Stack[5] = Env[4]
				end
			end
		end
				end
			end
		end
	end
else
	if pointer * pointer <= 289 then
		if (pointer * 15) + pointer <= 224 then
			if (pointer * pointer * 3) + pointer == 602 then
				do
					if (pointer - 69) > pointer then
			if pointer > 157 then Stack[5] = Stack[8] end
		else
			do
				if pointer + 13 ~= 31 then
					if pointer + 7 == 21 then
					    Stack[1] = Stack[1] - Stack[3]
    pointer = pointer + 5
    
				end
				end
			end
		end
				end
			elseif (pointer * pointer) + 21 == 190 then
				do
					do
			if pointer * 2 + 12 == 38 then
					Temp[3] = 3
Temp[6] = Constants
Temp[14] = 10
Stack[Temp[3]] = Temp[6][Temp[14]]
				end
		end
				end
			end
		else
			if (pointer * pointer * 4) + pointer == 1173 then
				do
					if (pointer - 81) > pointer then
			Stack[8] = Stack[6] or Constants[1+1]
		else
			do
				if pointer + 14 == 31 then
					if pointer + 3 == 20 then
					if pointer * 2 - 8 == 26 then
					pointer = pointer + 2 
				end
				end
				end
			end
		end
				end
			elseif (pointer * pointer) + (14 * pointer) == 435 then
				do
					if pointer + 11 == 26 then
				Stack[5] = Stack[0] % Stack[4]
		end
				end
			elseif (pointer * 8) + (pointer * 16) == 384 then
				do
					if (pointer - 95) > pointer then
			Stack[3] = nil
		else
			do
				if pointer + 11 == 33 then
					Stack[4] = nil
				end
					if Stack[5] == Constants[4] then pointer = pointer + 1 end
			end
		end
				end
			end
		end
	else
		if (pointer * pointer) + (4 * pointer) <= 480 then
			if (pointer * pointer) + 16 == 416 then
				do
					if (pointer - 19) > pointer then
			Stack[6] = (1 == 1)
		else
			do
				if pointer * 2 - 8 == 32 then
					    Stack[1] = Stack[1] + Stack[3]
    if (Stack[3] > 0 and Stack[1] <= Stack[2]) or (Stack[3] <= 0 and Stack[1] >= Stack[2]) then
        pointer = pointer + -6
        Stack[4] = Stack[1]
    end
    
				end
			end
		end
				end
			elseif (pointer * pointer) + 12 == 373 then
				do
					if (pointer + 61) > pointer then
			do
				if pointer * 2 + 8 == 46 then
					if pointer * 3 - 12 == 45 then
					if pointer + 5 ~= 44 then
						return Stack[5]
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
			elseif (pointer * pointer * 2) + pointer == 666 then
				do
					if (pointer + 87) > pointer then
			do
				if pointer - 2 == 16 then
					if pointer * 2 - 9 == 27 then
					Temp[12] = 5
Temp[6] = byte == pairs
Stack[Temp[12]] = Temp[2]
				end
				end
			end
		else
			Stack[5] = (0 == 1)
		end
				end
			end
		else
			if (pointer * 12) + (pointer * 45) == 1311 then
				do
					if (pointer + 64) > pointer then
			do
				if pointer + 11 == 49 then
					Stack[1] = nil
				end
				if pointer + 8 == 31 then
					if pointer * 2 + 2 == 48 then
						return
				end
				end
			end
		else
			Stack[8] = (0 == 1)
		end
				end
			elseif (pointer * pointer) + (6 * pointer) == 567 then
				do
					if (pointer - 74) > pointer then
			Stack[6] = (1 == 1)
		else
			do
				if pointer * 2 + 11 == 53 then
					Temp[14] = 1
Temp[4] = ttostring ~= __metatable
Stack[Temp[14]] = Temp[7]
				end
			end
		end
				end
			elseif (pointer * 4) + (pointer * 13) == 374 then
				do
					if (pointer - 88) > pointer then
			if pointer > 170 then Stack[6] = Stack[6] end
		else
			do
				if pointer - 5 == 17 then
					if pointer + 4 ~= 31 then
					if pointer * 2 + 12 == 56 then
						return Stack[1]
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
		pointer = pointer+1
		end
	end

		end
					end
				end
			end
		else
			if (pointer * 11) + pointer <= 132 then
				if (pointer * pointer) + 37 == 158 then
					do
						if (pointer + 45) > pointer then
			do
				if pointer * 2 - 2 == 20 then
					    Stack[5] = Stack[5] - Stack[7]
    pointer = pointer + 8
    
				end
			end
		else
			Temp[8] = 3
			Temp[16] = Constants
			Temp[20] = 20
			Stack[Temp[5]] = Temp[18][Temp[10]]
		end
					end
				elseif (pointer * pointer) + 19 == 119 then
					do
						if pointer + 2 == 12 then
			Temp[3] = 7
Temp[9] = Constants
Temp[14] = 21
Stack[Temp[3]] = Temp[9][Temp[14]]
		end
					end
				elseif (pointer * pointer) + 7 == 71 then
					do
						if pointer + 14 == 22 then
			Temp[10] = 5
Temp[5] = Constants
Temp[16] = 21
Stack[Temp[10]] = Temp[5][Temp[16]]
		end
					end
				elseif (pointer * 2) + (pointer * 18) == 180 then
					do
						if (pointer + 78) > pointer then
			do
				if pointer * 2 - 8 == 10 then
					Temp[15] = 6
Temp[13] = Constants
Temp[10] = 24
Stack[Temp[15]] = Temp[13][Temp[10]]
				end
			end
		else
			Stack[5] = Stack[8] or Constants[2+1]
		end
					end
				end
			else
				if (pointer * 11) + (pointer * 45) == 672 then
					do
						if (pointer + 65) > pointer then
			do
				if pointer - 11 == 1 then
					if pointer * 2 + 3 == 27 then
					if pointer * 3 - 8 == 28 then
					Temp[16] = 9
Temp[4] = 2
Stack[Temp[16]] = Stack[Temp[4]]
				else
					Stack[7] = nil
				end
				end
				elseif pointer - 11 == 3 then
					Stack[2] = Env[4]
				end
			end
		else
			Stack[1] = Stack[7] or Constants[7+1]
		end
					end
				elseif (pointer * pointer * 4) + pointer == 689 then
					do
						if pointer + 8 == 21 then
			Temp[4] = 10
Temp[5] = 8
Stack[Temp[4]] = Stack[Temp[5]]
		end
					end
				elseif (pointer * pointer) + 42 == 267 then
					do
						do
			if pointer + 5 == 21 then
					Stack[3] = nil
				end
					if Stack[9] then pointer = pointer + 1 end
		end
					end
				elseif (pointer * pointer * 2) + pointer == 406 then
					do
						if (pointer - 39) > pointer then
			Stack[5] = -Stack[6]
		else
			do
				if pointer + 5 == 27 then
					Stack[7] = nil
				end
				if pointer - 4 == 10 then
						Stack[9] = Stack[9](Stack[10])
				end
			end
		end
					end
				end
			end
		end
	else
		if pointer * pointer <= 484 then
			if (pointer * 2) + pointer <= 54 then
				if (pointer * pointer) + (12 * pointer) == 493 then
					do
						if pointer + 14 == 31 then
				Stack[9] = #Stack[4]
		end
					end
				elseif (pointer * pointer) + (13 * pointer) == 558 then
					do
						if pointer + 13 == 31 then
				Stack[9] = Stack[9] + Constants[21]
		end
					end
				elseif (pointer * 3) + (pointer * 26) == 464 then
					do
						do
			if pointer * 3 - 3 == 45 then
					if pointer + 4 == 20 then
					pointer = pointer + 3 
				end
				else
					Stack[5] = nil
				end
		end
					end
				end
			else
				if (pointer * pointer * 2) + pointer == 903 then
					do
						if (pointer + 7) > pointer then
			do
				if pointer - 9 == 12 then
					if pointer - 3 == 18 then
					Temp[15] = 5
Temp[5] = 4
Temp[4] = Constants[Temp[5]]
Stack[Temp[15]] = vmEnv[Temp[4]] or Env[Temp[4]]
				end
				elseif pointer - 9 == 15 then
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
				elseif (pointer * 3) + (pointer * 25) == 532 then
					do
						if pointer + 1 == 20 then
				Stack[4][Stack[9]] = Stack[8]
		end
					end
				elseif (pointer * pointer) + 42 == 442 then
					do
						do
			if pointer * 3 - 2 == 58 then
					if pointer - 13 == 7 then
					    Stack[5] = Stack[5] + Stack[7]
    if (Stack[7] > 0 and Stack[5] <= Stack[6]) or (Stack[7] <= 0 and Stack[5] >= Stack[6]) then
        pointer = pointer + -9
        Stack[8] = Stack[5]
    end
    
				elseif pointer - 13 == 23 then
					Stack[6] = Env[2]
				end
				else
					Stack[4] = nil
				end
		end
					end
				elseif (pointer * 7) + (pointer * 31) == 836 then
					do
						if pointer + 2 == 24 then
			Temp[10] = 6
Temp[5] = Constants
Temp[16] = 22
Stack[Temp[10]] = Temp[5][Temp[16]]
		end
					end
				end
			end
		else
			if (pointer * 3) + pointer <= 108 then
				if (pointer * pointer) + (5 * pointer) == 644 then
					do
						do
			if pointer - 5 == 18 then
					Temp[6] = 7
Temp[3] = 3
Stack[Temp[6]] = Stack[Temp[3]]
				elseif pointer - 5 == 23 then
					Stack[7] = Env[4]
				end
		end
					end
				elseif (pointer * 5) + (pointer * 14) == 513 then
					do
						do
			if pointer * 3 - 6 == 75 then
					if pointer - 3 == 24 then
						Temp[1] = ""
	for i = 6, 7 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[6] = Temp[1]
	
				elseif pointer - 3 == 30 then
					Stack[2] = Env[2]
				end
				else
					Stack[3] = nil
				end
		end
					end
				elseif (pointer * pointer) + (7 * pointer) == 744 then
					do
						do
			if pointer - 7 == 17 then
					Temp[5] = 8
Temp[6] = 4
Stack[Temp[5]] = Stack[Temp[6]]
				elseif pointer - 7 == 31 then
					Stack[8] = Env[5]
				end
		end
					end
				elseif (pointer * 2) + (pointer * 19) == 525 then
					do
						do
			if pointer * 2 + 5 == 55 then
					Temp[16] = 9
Temp[10] = Constants
Temp[4] = 7
Stack[Temp[16]] = Temp[10][Temp[4]]
	Stack[7] = Stack[7](Stack[8], Stack[9])
	pointer = pointer + 1
				end
		end
					end
				end
			else
				if (pointer * pointer * 4) + pointer == 3630 then
					do
						do
			if pointer + 14 == 44 then
					if pointer - 6 == 24 then
					Temp[6] = 6
Temp[14] = Constants
Temp[5] = 1
Stack[Temp[6]] = Temp[14][Temp[5]]
				end
				end
		end
					end
				elseif (pointer * pointer) + 36 == 997 then
					do
						do
			if pointer * 2 + 12 == 74 then
					Temp[3] = 7
Temp[7] = 1
Stack[Temp[3]] = Stack[Temp[7]]
				end
		end
					end
				elseif (pointer * pointer * 5) + pointer == 3948 then
					do
						if pointer + 13 == 41 then
				Stack[5](Stack[6])
		end
					end
				elseif (pointer * 4) + (pointer * 23) == 783 then
					do
						if pointer + 10 == 39 then
			Temp[13] = 5
Temp[2] = 4
Temp[15] = Constants[Temp[2]]
Stack[Temp[13]] = vmEnv[Temp[15]] or Env[Temp[15]]
		end
					end
				end
			end
		end
	end
else
	if pointer * pointer <= 2304 then
		if (pointer * pointer) + (15 * pointer) <= 2106 then
			if (pointer * pointer) + (15 * pointer) <= 1750 then
				if (pointer * pointer * 4) + pointer == 4128 then
					do
						do
			if pointer + 14 == 46 then
					Temp[7] = 8
Temp[11] = Constants
Temp[5] = 19
Stack[Temp[7]] = Temp[11][Temp[5]]
				end
		end
					end
				elseif (pointer * pointer * 2) + pointer == 2485 then
					do
						if (pointer + 8) > pointer then
			do
				if pointer * 2 + 6 == 76 then
					if pointer - 1 == 34 then
					if pointer * 3 - 8 == 97 then
						Temp[1] = ""
	for i = 6, 7 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[6] = Temp[1]
	
				else
					Stack[7] = nil
				end
				elseif pointer - 1 == 46 then
					Stack[1] = Env[4]
				end
				end
			end
		else
			Stack[8] = -Stack[3]
		end
					end
				elseif (pointer * pointer) + 9 == 1098 then
					do
						if pointer + 8 == 41 then
			Temp[7] = 9
Temp[15] = Constants
Temp[9] = 2
Stack[Temp[7]] = Temp[15][Temp[9]]
	Stack[7] = Stack[7](Stack[8], Stack[9])
	pointer = pointer + 1
		end
					end
				end
			else
				if (pointer * 11) + (pointer * 10) == 777 then
					do
						if (pointer + 88) > pointer then
			do
				if pointer * 2 - 8 == 66 then
					if pointer + 4 == 60 then
					Stack[1] = nil
				end
				if pointer * 3 - 5 == 106 then
					Temp[12] = 5
Temp[14] = 4
Temp[15] = Constants[Temp[14]]
Stack[Temp[12]] = vmEnv[Temp[15]] or Env[Temp[15]]
				else
					Stack[3] = nil
				end
				end
			end
		else
			Stack[2] = (0 == 1)
		end
					end
				elseif (pointer * 12) + (pointer * 9) == 756 then
					do
						if pointer + 3 == 39 then
				Stack[5](Stack[6])
		end
					end
				elseif (pointer * pointer) + 28 == 1472 then
					do
						do
			if pointer - 15 == 23 then
					if pointer - 13 == 25 then
					Temp[7] = 6
Temp[4] = Constants
Temp[11] = 16
Stack[Temp[7]] = Temp[4][Temp[11]]
				elseif pointer - 13 == 31 then
					Stack[5] = Env[1]
				end
				elseif pointer - 15 == 41 then
					Stack[8] = Env[6]
				end
		end
					end
				elseif (pointer * pointer) + 25 == 1546 then
					do
						do
			if pointer * 2 - 9 == 69 then
					if pointer * 2 - 2 == 76 then
					if pointer + 9 == 48 then
					Temp[7] = 7
Temp[10] = 0
Stack[Temp[7]] = Stack[Temp[10]]
				end
				end
				end
		end
					end
				end
			end
		else
			if (pointer * 15) + pointer <= 704 then
				if (pointer * pointer * 4) + pointer == 7788 then
					do
						do
			if pointer + 2 == 46 then
					if pointer - 2 == 42 then
					if pointer * 3 - 9 == 123 then
					Temp[15] = 8
Temp[13] = Constants
Temp[3] = 14
Stack[Temp[15]] = Temp[13][Temp[3]]
				else
					Stack[6] = nil
				end
				end
				end
		end
					end
				elseif (pointer * 3) + (pointer * 24) == 1080 then
					do
						if pointer + 1 == 41 then
			Temp[14] = 8
Temp[12] = Constants
Temp[15] = 11
Stack[Temp[14]] = Temp[12][Temp[15]]
		end
					end
				elseif (pointer * pointer * 5) + pointer == 8446 then
					do
						if pointer + 5 == 46 then
			Temp[13] = 9
Temp[6] = Constants
Temp[2] = 15
Stack[Temp[13]] = Temp[6][Temp[2]]
		end
					end
				elseif (pointer * pointer) + (10 * pointer) == 2184 then
					do
						if pointer + 15 == 57 then
			Temp[9] = 10
Temp[7] = Constants
Temp[16] = 23
Stack[Temp[9]] = Temp[7][Temp[16]]
	Stack[7] = Stack[7](Stack[8], Stack[9], Stack[10])
	pointer = pointer + 1
		end
					end
				end
			else
				if (pointer * pointer) + 37 == 2341 then
					do
						if (pointer - 64) > pointer then
			Stack[2] = nil
		else
			do
				if pointer - 10 == 38 then
					if pointer + 3 == 62 then
					Stack[3] = nil
				end
				Temp[5] = 12
Temp[14] = Constants
Temp[11] = 23
Stack[Temp[5]] = Temp[14][Temp[11]]
	Stack[9] = Stack[9](Stack[10], Stack[11], Stack[12])
	pointer = pointer + 1
				elseif pointer - 10 == 56 then
					Stack[7] = Env[8]
				end
			end
		end
					end
				elseif (pointer * pointer * 4) + pointer == 8883 then
					do
						if pointer + 12 == 59 then
			Temp[8] = 11
Temp[1] = Constants
Temp[12] = 15
Stack[Temp[8]] = Temp[1][Temp[12]]
		end
					end
				elseif (pointer * 10) + (pointer * 8) == 828 then
					do
						if (pointer + 19) > pointer then
			do
				if pointer * 2 + 4 == 96 then
					if pointer - 2 == 44 then
					if pointer - 11 == 35 then
					Temp[10] = 10
Temp[8] = Constants
Temp[1] = 8
Stack[Temp[10]] = Temp[8][Temp[1]]
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
				elseif (pointer * pointer) + (2 * pointer) == 2115 then
					do
						do
			if pointer + 8 == 53 then
					if pointer * 2 + 6 == 96 then
					if pointer - 10 == 35 then
					Temp[16] = 9
Temp[4] = 0
Stack[Temp[16]] = Stack[Temp[4]]
				elseif pointer - 10 == 54 then
					Stack[5] = Env[8]
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
			if (pointer * pointer) + (3 * pointer) <= 2860 then
				if (pointer * 8) + (pointer * 6) == 728 then
					do
						if (pointer + 40) > pointer then
			do
				if pointer - 7 == 45 then
					if pointer - 11 == 41 then
					Temp[7] = 12
Temp[4] = Constants
Temp[6] = 3
Stack[Temp[7]] = Temp[4][Temp[6]]
				elseif pointer - 11 == 50 then
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
				elseif (pointer * pointer) + 41 == 2541 then
					do
						if (pointer + 82) > pointer then
			do
				if pointer + 5 == 70 then
					Stack[8] = nil
				end
				if pointer + 9 == 59 then
					if pointer + 11 ~= 72 then
					Temp[12] = 10
Temp[5] = Constants
Temp[14] = 14
Stack[Temp[12]] = Temp[5][Temp[14]]
				end
				end
			end
		else
			Stack[1] = (0 == 1)
		end
					end
				elseif (pointer * 10) + (pointer * 17) == 1377 then
					do
						if pointer + 2 == 53 then
			Temp[7] = 11
Temp[11] = 0
Stack[Temp[7]] = Stack[Temp[11]]
		end
					end
				end
			else
				if (pointer * pointer * 5) + pointer == 14634 then
					do
						do
			if pointer * 2 + 3 == 111 then
					if pointer * 2 + 1 == 109 then
					Temp[7] = 14
Temp[10] = Constants
Temp[3] = 23
Stack[Temp[7]] = Temp[10][Temp[3]]
	Stack[11] = Stack[11](Stack[12], Stack[13], Stack[14])
	pointer = pointer + 1
				end
				end
		end
					end
				elseif (pointer * pointer) + 36 == 2845 then
					do
						if pointer + 8 == 61 then
			Temp[5] = 13
Temp[1] = Constants
Temp[12] = 15
Stack[Temp[5]] = Temp[1][Temp[12]]
		end
					end
				elseif (pointer * pointer) + (7 * pointer) == 3528 then
					do
						if pointer + 9 == 65 then
				Temp[1] = ""
	for i = 6, 11 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[6] = Temp[1]
	
		end
					end
				elseif (pointer * pointer) + (7 * pointer) == 3648 then
					do
						if pointer + 12 == 69 then
				Stack[5](Stack[6])
		end
					end
				end
			end
		else
			if pointer * pointer <= 3844 then
				if (pointer * pointer) + 47 == 3768 then
					do
						do
			if pointer * 2 + 12 == 134 then
					Temp[7] = 7
Temp[4] = Constants
Temp[8] = 12
Stack[Temp[7]] = Temp[4][Temp[8]]
				end
		end
					end
				elseif (pointer * pointer) + (3 * pointer) == 3538 then
					do
						if (pointer - 17) > pointer then
			Stack[6] = Stack[4] or Constants[8+1]
		else
			do
				if pointer - 12 == 46 then
					if pointer * 2 - 2 == 114 then
					if pointer * 3 - 9 == 165 then
					Temp[7] = 5
Temp[8] = 4
Temp[15] = Constants[Temp[8]]
Stack[Temp[7]] = vmEnv[Temp[15]] or Env[Temp[15]]
				else
					Stack[4] = nil
				end
				end
				end
			end
		end
					end
				elseif (pointer * pointer) + 32 == 3876 then
					do
						if pointer + 15 == 77 then
			Temp[15] = 8
Temp[5] = Constants
Temp[16] = 5
Stack[Temp[15]] = Temp[5][Temp[16]]
		end
					end
				elseif (pointer * pointer) + 26 == 3507 then
					do
						if (pointer + 41) > pointer then
			do
				if pointer + 12 ~= 76 then
					if pointer + 13 == 78 then
					Stack[4] = nil
				end
				Temp[3] = 6
Temp[11] = 17
Temp[14] = Constants[Temp[11]]
Stack[Temp[3]] = vmEnv[Temp[14]] or Env[Temp[14]]
	Stack[6] = Stack[6][Constants[10]]
	
	pointer = pointer + 1
				end
			end
		else
			Stack[5] = -Stack[1]
		end
					end
				end
			else
				if (pointer * 9) + (pointer * 10) == 1273 then
					do
						if pointer + 9 == 76 then
				return
		end
					end
				elseif (pointer * pointer) + (4 * pointer) == 4352 then
					do
						do
			if pointer * 3 - 6 == 186 then
					if pointer * 3 - 10 == 182 then
					Temp[12] = 10
Temp[11] = Constants
Temp[16] = 3
Stack[Temp[12]] = Temp[11][Temp[16]]
	Temp[2] = {Stack[6](Stack[7], Stack[8], Stack[9], Stack[10])}
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
				else
					Stack[3] = nil
				end
				else
					Stack[1] = nil
				end
		end
					end
				elseif (pointer * pointer) + 40 == 4009 then
					do
						if pointer + 8 == 71 then
			Temp[15] = 9
Temp[16] = Constants
Temp[4] = 20
Stack[Temp[15]] = Temp[16][Temp[4]]
		end
					end
				elseif (pointer * pointer * 3) + pointer == 13134 then
					do
						do
			if pointer * 3 - 9 == 189 then
					if pointer - 2 == 64 then
						Temp[1] = {}
	for i = 5 + 1, top do
		Temp[1][i - 5] = Stack[i]
	end
	Temp[2] = {Stack[5](unpack(Temp[1], 1, top - 5))}
		for i = 1, 0 do
		Stack[5 + i - 1] = Temp[2][i]
	end
	
	
				elseif pointer - 2 == 75 then
					Stack[3] = Env[5]
				end
				else
					Stack[1] = nil
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