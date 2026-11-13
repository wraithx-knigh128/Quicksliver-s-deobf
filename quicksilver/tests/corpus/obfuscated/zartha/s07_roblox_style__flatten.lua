return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\087\109\092", "2127")),(decrypt("\116\104\091\111\085\089", "302")),(decrypt("\081\111\109\100\081", "2748")),(decrypt("\008\086\081\080\110\106\095", "2045")),(decrypt("\001\092\106\102\095\089\101\098", "990")),(decrypt("\085\093\083\087\095", "243")),(decrypt("\027\027\059", "2006")),(decrypt("\110\109\091\084\087", "1187")),(decrypt("\024\020\063", "434")),(decrypt("\012\106\083\121\110\095\085\083\104\106", "2683")),(decrypt("\088\085\092\094", "998")),(decrypt("\088\095\104\107\105", "2847")),(decrypt("\122\088\089\099\080\126\089\090\095\104\080", "2499")),(decrypt("\113\085\091\083\105\085\107\100", "1018")),(decrypt("\009\106\091\110\066", "2686")),(decrypt("\124\107\087\083\120\084\104\109\105", "2341")),(decrypt("\117\109\092\087\109\092", "1555")),(decrypt("\123\108\086\085\089\108", "2023")),(decrypt("\112\084\084\082\118\094\094\105\088", "1805")),(decrypt("\120\086\083\084\088\013\100\109\108\093", "834")),(decrypt("\089\081\094\111\053", "2823")),(decrypt("\092\081\092\091\088\080\109\099\110", "2759")),(decrypt("\123\111\084\081\082\105\107\089\110\104\121\089\084\090\107\108\110", "2332")),(decrypt("\120\084\080\115\109\081\088\089\107\100", "1859")),(decrypt("\108\087\082\107\081\105\090\088\107\109", "617")),(decrypt("\111\110\084\109", "1601")),(decrypt("\100\115\001\010\126\127\002\015\121\009\003", "2587")),(decrypt("\021\050", "2979")),(decrypt("\009\081\085\108", "776")),(decrypt("\121\111\088\092\010\094\094\013\103\087\084\099", "778")),(decrypt("\003\106\097\080\109\099\082\105\080", "959")),(decrypt("\117\096\089\088", "2803")),(decrypt("\018\017\058", "981")),(decrypt("\116\086\109\111\083\112\084\104\071\107\089", "707")),(decrypt("\118\091\108\071\109\081\094", "1847")),(decrypt("\014\100\111\088\090\097\107\105\090", "1871")),(decrypt("\125\109\085\100", "851")),(decrypt("\005\085\090\100\127\111\081\088\111\081", "853")),(decrypt("\120\082\109\099\080\046\083\084\110\080\104\090\084\087", "2959")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
				if (pointer * pointer) + (9 * pointer) <= 1170 then
	if (pointer * pointer) + (6 * pointer) <= 315 then
		if (pointer * 10) + pointer <= 77 then
			if (pointer * pointer) + (13 * pointer) <= 48 then
				if (pointer * pointer) + 29 == 33 then
					do
						if pointer + 9 == 11 then
			Temp[6] = vmEnv
Temp[16] = 27
Temp[10] = Constants[Temp[16]]
Temp[4] = 0
Temp[6][Temp[10]] = Temp[10]
		end
					end
				elseif (pointer * pointer * 5) + pointer == 48 then
					do
						if pointer + 9 == 12 then
			Temp[13] = 0
Temp[2] = 26
Temp[15] = Constants[Temp[2]]
Stack[Temp[13]] = vmEnv[Temp[15]] or Env[Temp[15]]
		end
					end
				elseif (pointer * 12) + (pointer * 48) == 60 then
					do
						if (pointer + 74) > pointer then
			do
				if pointer * 3 - 7 == -4 then
					if pointer + 10 == 13 then
					Stack[5] = nil
				end
				Temp[6] = 0
Temp[3] = ttostring ~= __metatable
Stack[Temp[6]] = Temp[5]
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
				if (pointer * pointer * 4) + pointer == 105 then
					do
						if pointer + 13 == 18 then
			Temp[6] = 2
Temp[14] = Constants
Temp[5] = 35
Stack[Temp[6]] = Temp[14][Temp[5]]
	Stack[0] = Stack[0](Stack[1], Stack[2])
	pointer = pointer + 1
		end
					end
				elseif (pointer * pointer * 4) + pointer == 68 then
					do
						if pointer + 2 == 6 then
				Stack[1] = Stack[0]
	if Stack[1] then
		Stack[0] = Stack[0][Constants[10]]
	end
	
		end
					end
				elseif (pointer * pointer * 3) + pointer == 154 then
					do
						if (pointer - 95) > pointer then
						Temp[2] = vmEnv
			Temp[1] = 4
			Temp[12] = Constants[Temp[14]]
			Temp[8] = 19
			Temp[15][Temp[6]] = Temp[6]
		else
			do
				if pointer + 12 == 19 then
					Temp[3] = 1
Temp[7] = 26
Temp[11] = Constants[Temp[7]]
Stack[Temp[3]] = vmEnv[Temp[11]] or Env[Temp[11]]
				end
			end
		end
					end
				end
			end
		else
			if (pointer * 11) + pointer <= 132 then
				if (pointer * 11) + (pointer * 18) == 319 then
					do
						if (pointer + 45) > pointer then
			do
				if pointer * 2 - 2 == 20 then
					Temp[9] = 2
Temp[12] = 26
Temp[14] = Constants[Temp[12]]
Stack[Temp[9]] = vmEnv[Temp[14]] or Env[Temp[14]]
				end
			end
		else
			Temp[8] = 3
			Temp[16] = Constants
			Temp[20] = 20
			Stack[Temp[5]] = Temp[18][Temp[10]]
		end
					end
				elseif (pointer * pointer) + (14 * pointer) == 207 then
					do
						if pointer + 5 == 14 then
			Temp[5] = 3
Temp[7] = Constants
Temp[15] = 24
Stack[Temp[5]] = Temp[7][Temp[15]]
	Stack[1] = Stack[1](Stack[2], Stack[3])
	pointer = pointer + 1
		end
					end
				elseif (pointer * pointer * 2) + pointer == 136 then
					do
						do
			if pointer + 14 == 22 then
					if pointer - 6 == 2 then
						Stack[2] = Stack[1]
	if Stack[2] then
		Stack[1] = Stack[1][Constants[10]]
	end
	
				end
				end
		end
					end
				end
			else
				if (pointer * pointer) + (10 * pointer) == 264 then
					do
						if pointer + 14 == 26 then
				Stack[3] = Stack[2]
	if Stack[3] then
		Stack[2] = Stack[2][Constants[10]]
	end
	
		end
					end
				elseif (pointer * pointer * 4) + pointer == 689 then
					do
						do
			if pointer - 4 == 9 then
					if pointer + 2 ~= 29 then
					Temp[14] = 4
Temp[15] = Constants
Temp[7] = 23
Stack[Temp[14]] = Temp[15][Temp[7]]
	Stack[2] = Stack[2](Stack[3], Stack[4])
	pointer = pointer + 1
				end
				end
		end
					end
				elseif (pointer * pointer) + 39 == 264 then
					do
						do
			if pointer * 3 - 2 == 43 then
					if pointer - 13 == 2 then
						Stack[3] = Stack[0][Constants[34]]
	
				elseif pointer - 13 == 18 then
					Stack[6] = Env[2]
				end
				else
					Stack[4] = nil
				end
		end
					end
				end
			end
		end
	else
		if pointer * pointer <= 484 then
			if (pointer * pointer) + (12 * pointer) <= 540 then
				if (pointer * pointer * 3) + pointer == 884 then
					do
						do
			if pointer * 2 + 3 == 37 then
					if pointer * 2 + 1 == 35 then
						Stack[4][Constants[12]] = Constants[7]
				end
				end
		end
					end
				elseif (pointer * pointer) + (9 * pointer) == 486 then
					do
						do
			if pointer * 3 - 3 == 51 then
					if pointer + 4 == 22 then
						Stack[4][Constants[11]] = Constants[9]
				end
				else
					Stack[5] = nil
				end
		end
					end
				elseif (pointer * pointer) + 40 == 296 then
					do
						do
			if pointer - 7 == 9 then
						Stack[4] = {}
				elseif pointer - 7 == 23 then
					Stack[8] = Env[5]
				end
		end
					end
				end
			else
				if (pointer * 7) + (pointer * 27) == 646 then
					do
						if pointer + 2 == 21 then
				Stack[4][Constants[3]] = Constants[13]
		end
					end
				elseif (pointer * 2) + (pointer * 24) == 572 then
					do
						if pointer + 13 == 35 then
			Temp[7] = 6
Temp[4] = 14
Temp[11] = Constants[Temp[4]]
Stack[Temp[7]] = vmEnv[Temp[11]] or Env[Temp[11]]
	Stack[6] = Stack[6][Constants[1]]
	
	pointer = pointer + 1
		end
					end
				elseif (pointer * pointer) + 17 == 417 then
					do
						if pointer + 13 == 33 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\010\110\111\093\111", "1261")),(decrypt("\014\092\082\106\084\086\086\105", "1062")),(decrypt("\115\090\085\094\117\080\095\101\091", "2619")),(decrypt("\122\085\081\121\101\093\094\089\110\111", "394")),((decrypt("\027", "2462"))),(decrypt("\124\109\084\080\127\080\110\105\108", "257")),(decrypt("\125\108\088\088\009\094\090\014\103\083\087\099", "348")),(decrypt("\091\084\101\107\106", "1397")),(decrypt("\080\085\085\081", "1916")),((decrypt("\030\016\024", "2715"))),(decrypt("\012\088\083\121\110\093\094\083\104\104", "2433")),}

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
	
	Stack[5] = function(...) -- PROTOTYPE 1
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 4}}
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
	if (pointer * 3) + pointer <= 8 then
		if (pointer * pointer * 5) + pointer == 6 then
			do
				if pointer + 1 == 2 then
				Stack[2] = Stack[0]
	if Stack[2] then
		Stack[1] = Stack[0][Constants[7]]
	end
	
		end
			end
		elseif (pointer * pointer) + (10 * pointer) == 24 then
			do
				if pointer + 2 == 4 then
			Temp[7] = 3
Temp[10] = Constants
Temp[11] = 2
Stack[Temp[7]] = Temp[10][Temp[11]]
	Stack[1] = Stack[1](Stack[2], Stack[3])
	pointer = pointer + 1
		end
			end
		end
	else
		if (pointer * 13) + (pointer * 50) == 378 then
			do
				do
			if pointer * 2 - 2 == 10 then
					if pointer * 3 - 1 == 17 then
					if pointer * 3 - 11 == 7 then
						Stack[1][Constants[6]] = Stack[2]
				else
					Stack[8] = nil
				end
				else
					Stack[4] = nil
				end
				end
		end
			end
		elseif (pointer * pointer) + (8 * pointer) == 65 then
			do
				if (pointer - 72) > pointer then
						Temp[14] = vmEnv
			Temp[3] = 13
			Temp[15] = Constants[Temp[3]]
			Temp[13] = 20
			Temp[11][Temp[7]] = Temp[16]
		else
			do
				if pointer + 8 ~= 21 then
					if pointer * 2 + 15 == 25 then
						Stack[2] = Stack[2][Constants[8]]
	
				end
				end
			end
		end
			end
		elseif (pointer * 13) + (pointer * 37) == 200 then
			do
				if pointer + 5 == 9 then
				Stack[2] = Upvalues[0]
		end
			end
		end
	end
else
	if (pointer * 2) + pointer <= 24 then
		if (pointer * pointer) + (9 * pointer) == 136 then
			do
				if pointer + 10 == 18 then
				Stack[2] = Stack[2][Constants[9]]
	
		end
			end
		elseif (pointer * pointer) + (11 * pointer) == 126 then
			do
				if pointer + 8 == 15 then
				Stack[2] = Upvalues[0]
		end
			end
		end
	else
		if (pointer * 8) + (pointer * 6) == 154 then
			do
				if pointer + 3 == 14 then
				return
		end
			end
		elseif (pointer * pointer) + 41 == 122 then
			do
				if pointer + 12 == 21 then
				Stack[1][Constants[3]] = Stack[2]
		end
			end
		elseif (pointer * 10) + (pointer * 17) == 270 then
			do
				if (pointer - 19) > pointer then
			Temp[16] = 4
			Temp[18] = Constants
			Temp[14] = 9
			Stack[Temp[7]] = Temp[2][Temp[20]]
		else
			do
				if pointer - 15 == -5 then
					if pointer + 13 == 42 then
					Stack[8] = nil
				end
				if pointer - 6 == 4 then
						return Stack[1]
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
			if pointer * pointer <= 729 then
				if (pointer * pointer) + 6 == 735 then
					do
						do
			if pointer + 2 == 29 then
					if pointer - 2 == 25 then
					if pointer * 3 - 9 == 72 then
					Temp[12] = 8
Temp[15] = Constants
Temp[13] = 17
Stack[Temp[12]] = Temp[15][Temp[13]]
				else
					Stack[6] = nil
				end
				end
				end
		end
					end
				elseif (pointer * pointer * 4) + pointer == 2730 then
					do
						do
			if pointer * 2 - 9 == 43 then
					if pointer * 2 - 2 == 50 then
					if pointer + 9 == 35 then
						Stack[7] = Stack[4][Constants[3]]
	
				end
				end
				end
		end
					end
				elseif (pointer * pointer * 2) + pointer == 1176 then
					do
						if (pointer + 52) > pointer then
			do
				if pointer + 10 == 34 then
					Temp[7] = 7
Temp[10] = Constants
Temp[14] = 32
Stack[Temp[7]] = Temp[10][Temp[14]]
	Stack[6] = Stack[6](Stack[7])
	pointer = pointer + 1
				end
			end
		else
			if pointer > 101 then Stack[1] = Stack[3] end
		end
					end
				end
			else
				if (pointer * pointer) + 19 == 919 then
					do
						if pointer + 13 == 43 then
				Stack[6][Constants[5]] = Constants[21]
		end
					end
				elseif (pointer * 14) + (pointer * 6) == 560 then
					do
						if pointer + 1 == 29 then
				Temp[1] = ""
	for i = 7, 8 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[7] = Temp[1]
	
		end
					end
				elseif (pointer * pointer * 5) + pointer == 4234 then
					do
						do
			if pointer + 14 == 43 then
						Stack[6][Constants[37]] = Stack[7]
				end
		end
					end
				end
			end
		end
	end
else
	if (pointer * 5) + pointer <= 252 then
		if pointer * pointer <= 1296 then
			if pointer * pointer <= 1089 then
				if (pointer * pointer) + (12 * pointer) == 1333 then
					do
						if pointer + 12 == 43 then
			Temp[6] = 7
Temp[2] = 22
Temp[9] = Constants[Temp[2]]
Stack[Temp[6]] = vmEnv[Temp[9]] or Env[Temp[9]]
		end
					end
				elseif (pointer * pointer) + (12 * pointer) == 1408 then
					do
						if pointer + 10 == 42 then
				Stack[6][Constants[2]] = Stack[7]
		end
					end
				elseif (pointer * pointer * 2) + pointer == 2211 then
					do
						if (pointer + 40) > pointer then
			do
				if pointer - 7 == 26 then
					if pointer - 11 == 22 then
					Temp[7] = 7
Temp[16] = 5
Stack[Temp[7]] = Stack[Temp[16]]
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
				end
			else
				if (pointer * pointer * 4) + pointer == 4658 then
					do
						do
			if pointer + 14 ~= 49 then
						Stack[8] = Stack[3][Constants[31]]
	
				end
		end
					end
				elseif (pointer * pointer) + 45 == 1270 then
					do
						if pointer + 14 == 49 then
				Stack[7] = Stack[7](Stack[8])
		end
					end
				elseif (pointer * pointer) + (9 * pointer) == 1620 then
					do
						if (pointer - 17) > pointer then
			Stack[6] = Stack[4] or Constants[8+1]
		else
			do
				if pointer - 12 == 24 then
					if pointer * 2 - 2 == 70 then
					if pointer * 3 - 9 == 99 then
					Temp[15] = 8
Temp[13] = 6
Temp[3] = Constants[Temp[13]]
Stack[Temp[15]] = vmEnv[Temp[3]] or Env[Temp[3]]
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
		else
			if pointer * pointer <= 1521 then
				if (pointer * pointer) + 34 == 1555 then
					do
						do
			if pointer - 5 == 34 then
						Stack[11] = Stack[7][Constants[19]]
	
				elseif pointer - 5 == 39 then
					Stack[7] = Env[4]
				end
		end
					end
				elseif (pointer * pointer) + (9 * pointer) == 1702 then
					do
						if pointer + 8 == 45 then
			Temp[16] = 9
Temp[4] = Constants
Temp[10] = 25
Stack[Temp[16]] = Temp[4][Temp[10]]
		end
					end
				elseif (pointer * pointer * 5) + pointer == 7258 then
					do
						do
			if pointer + 8 == 46 then
					if pointer * 2 + 6 == 82 then
					if pointer - 10 == 28 then
						Stack[10] = Stack[7][Constants[16]]
	
				elseif pointer - 10 == 47 then
					Stack[5] = Env[8]
				end
				end
				end
		end
					end
				end
			else
				if (pointer * pointer) + 35 == 1716 then
					do
						if pointer + 9 == 50 then
				Stack[8](Stack[9], Stack[10], Stack[11], Stack[12])
		end
					end
				elseif (pointer * 7) + (pointer * 14) == 840 then
					do
						if (pointer - 64) > pointer then
			Stack[2] = nil
		else
			do
				if pointer - 10 == 30 then
					if pointer + 3 == 54 then
					Stack[3] = nil
				end
					Stack[12] = Stack[6][Constants[37]]
	
				elseif pointer - 10 == 48 then
					Stack[7] = Env[8]
				end
			end
		end
					end
				elseif (pointer * pointer) + (10 * pointer) == 2184 then
					do
						if (pointer + 61) > pointer then
			do
				if pointer + 9 == 51 then
					if pointer * 2 - 4 == 80 then
					if pointer * 2 + 5 == 89 then
					Temp[10] = 8
Temp[8] = Constants
Temp[1] = 28
Stack[Temp[10]] = Temp[8][Temp[1]]
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
		end
	else
		if pointer * pointer <= 2500 then
			if (pointer * pointer) + (8 * pointer) <= 2385 then
				if (pointer * pointer) + (10 * pointer) == 2279 then
					do
						if pointer + 1 == 44 then
				Stack[9], Stack[10], Stack[11], Stack[12], Stack[13], Stack[14], Stack[15], Stack[16], Stack[17], Stack[18] = nil
		end
					end
				elseif (pointer * pointer * 3) + pointer == 6120 then
					do
						do
			if pointer + 5 == 51 then
					Stack[3] = nil
				end
					Stack[11] = Stack[10]
	if Stack[11] then
		Stack[10] = Stack[10][Constants[4]]
	end
	
		end
					end
				elseif (pointer * pointer) + 11 == 1947 then
					do
						do
			if pointer + 1 == 45 then
						Stack[10] = Stack[1][Constants[36]]
	
				end
		end
					end
				end
			else
				if (pointer * pointer) + 35 == 2151 then
					do
						if pointer + 8 == 54 then
				local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\024\050", "2967")),(decrypt("\003\088\088\098\094\087\093\100\104\083", "882")),(decrypt("\086\092\086\084\090", "1561")),(decrypt("\110\109\108\089\090\104\104\104\090\038\111\086\084\109", "1140")),(decrypt("\011\109\083\014\087\086\085\084\106\105", "1564")),(decrypt("\026\051", "2808")),(decrypt("\011\015\089\097\085\110", "1209")),(decrypt("\093\104\095\108\091\090\104\090\001\018\023", "410")),(decrypt("\014\097\091\092", "2917")),((decrypt("\025\016\017", "588"))),(decrypt("\010\106\096\091\111\033\093\081\106\106\046\107\084\110\096\084\109\109", "1697")),}

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
	
	Stack[12] = function(...) -- PROTOTYPE 2
		local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {[0] = {0, 8}, [1] = {0, 9}}
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
				if (pointer + 85) > pointer then
			do
				if pointer + 2 == 5 then
					Stack[4] = nil
				end
					Stack[1] = Upvalues[0]
			end
		else
			Temp[4] = 5
			Temp[12] = Constants
			Temp[16] = 12
			Stack[Temp[9]] = Temp[14][Temp[12]]
		end
			end
		elseif (pointer * pointer * 4) + pointer == 18 then
			do
				if pointer + 14 == 16 then
				Stack[1] = Stack[1] + Constants[6]
		end
			end
		elseif (pointer * 10) + (pointer * 46) == 168 then
			do
				if (pointer + 30) > pointer then
			do
				if pointer + 14 ~= 21 then
					if pointer * 2 - 6 == 0 then
						Upvalues[0] = Stack[1]
				end
				end
			end
		else
			Temp[9] = 4
			Temp[15] = Constants
			Temp[8] = 1
			Stack[Temp[17]] = Temp[7][Temp[4]]
		end
			end
		end
	else
		if (pointer * pointer) + (3 * pointer) == 54 then
			do
				do
			if pointer + 11 ~= 34 then
					if pointer + 10 == 35 then
					Stack[3] = nil
				end
				pointer = pointer + 7 
				end
		end
			end
		elseif (pointer * pointer) + (15 * pointer) == 100 then
			do
				if (pointer + 18) > pointer then
			do
				if pointer * 3 - 10 == 5 then
					if pointer - 5 == 0 then
					if pointer * 2 - 6 == 4 then
						if Constants[1] <= Stack[1] then pointer = pointer + 1 end
				end
				elseif pointer - 5 == 17 then
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
		elseif (pointer * 2) + (pointer * 46) == 336 then
			do
				if pointer + 5 == 12 then
				Stack[1] = Upvalues[1]
		end
			end
		elseif (pointer * pointer) + (11 * pointer) == 60 then
			do
				if (pointer + 83) > pointer then
			do
				if pointer * 2 + 13 == 21 then
					if pointer - 13 == -9 then
						Stack[1] = Upvalues[0]
				elseif pointer - 13 == 1 then
					Stack[1] = Env[1]
				end
				end
			end
		else
			Stack[8] = Stack[7] or Constants[8+1]
		end
			end
		end
	end
else
	if (pointer * pointer) + (14 * pointer) <= 240 then
		if (pointer * pointer) + (4 * pointer) == 140 then
			do
				do
			if pointer - 15 == -5 then
					Temp[10] = 1
Temp[7] = 3
Temp[3] = Constants[Temp[7]]
Stack[Temp[10]] = vmEnv[Temp[3]] or Env[Temp[3]]
				elseif pointer - 15 == -1 then
					Stack[2] = Env[7]
				end
		end
			end
		elseif (pointer * 5) + (pointer * 19) == 216 then
			do
				if (pointer + 76) > pointer then
			do
				if pointer + 15 ~= 33 then
						Stack[1](Stack[2])
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
		elseif (pointer * pointer) + (6 * pointer) == 112 then
			do
				if (pointer - 69) > pointer then
			if pointer > 104 then Stack[8] = Stack[4] end
		else
			do
				if pointer - 6 == 2 then
					if pointer - 4 == 4 then
						Stack[2] = Stack[1]
	if Stack[2] then
		Stack[1] = Stack[1][Constants[2]]
	end
	
				elseif pointer - 4 == 21 then
					Stack[1] = Env[2]
				end
				elseif pointer - 6 == 9 then
					Stack[2] = Env[1]
				end
			end
		end
			end
		end
	else
		if (pointer * 3) + (pointer * 24) == 351 then
			do
				do
			if pointer + 9 ~= 24 then
					if pointer * 3 - 11 == 28 then
					if pointer * 2 - 2 == 24 then
						Stack[1](Stack[2], Stack[3])
				end
				else
					Stack[6] = nil
				end
				end
		end
			end
		elseif (pointer * pointer * 2) + pointer == 300 then
			do
				if pointer + 7 == 19 then
				Stack[3] = Upvalues[0]
		end
			end
		elseif (pointer * pointer) + (5 * pointer) == 176 then
			do
				if (pointer + 89) > pointer then
			do
				if pointer * 2 + 1 == 23 then
					if pointer + 14 == 32 then
					Stack[2] = nil
				end
				if pointer * 2 + 9 == 31 then
					Temp[8] = 2
Temp[5] = Constants
Temp[10] = 4
Stack[Temp[8]] = Temp[5][Temp[10]]
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
		elseif (pointer * pointer * 2) + pointer == 406 then
			do
				if pointer + 8 == 22 then
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
				elseif (pointer * pointer) + (8 * pointer) == 2793 then
					do
						if pointer + 3 == 52 then
				Stack[10] = Stack[10](Stack[11], Stack[12])
		end
					end
				elseif (pointer * pointer) + 37 == 2537 then
					do
						if (pointer - 39) > pointer then
			Stack[5] = -Stack[6]
		else
			do
				if pointer + 5 == 63 then
					Stack[7] = nil
				end
				if pointer - 4 == 46 then
					Temp[8] = 9
Temp[1] = 10
Stack[Temp[8]] = Stack[Temp[1]]
				end
			end
		end
					end
				end
			end
		else
			if (pointer * pointer) + (7 * pointer) <= 3294 then
				if (pointer * pointer) + (2 * pointer) == 2703 then
					do
						if (pointer + 19) > pointer then
			do
				if pointer * 2 + 4 == 106 then
					if pointer - 2 == 49 then
					if pointer - 11 == 40 then
						Stack[11] = Stack[2]
	if Stack[11] then
		Stack[10] = Stack[2][Constants[30]]
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
				elseif (pointer * 6) + (pointer * 38) == 2376 then
					do
						if pointer + 1 == 55 then
				Stack[12] = Stack[10]
	if Stack[12] then
		Stack[11] = Stack[10][Constants[38]]
	end
	
		end
					end
				elseif (pointer * 14) + (pointer * 48) == 3224 then
					do
						do
			if pointer - 12 == 40 then
					if pointer * 2 - 7 == 97 then
					Temp[12] = 12
Temp[5] = Constants
Temp[14] = 18
Stack[Temp[12]] = Temp[5][Temp[14]]
	Stack[10] = Stack[10](Stack[11], Stack[12])
	pointer = pointer + 1
				end
				end
		end
					end
				end
			else
				if (pointer * pointer * 4) + pointer == 12155 then
					do
						do
			if pointer * 3 - 9 == 156 then
					if pointer - 2 == 53 then
					Temp[11] = 13
Temp[12] = Constants
Temp[5] = 8
Stack[Temp[11]] = Temp[12][Temp[5]]
				elseif pointer - 2 == 64 then
					Stack[3] = Env[5]
				end
				else
					Stack[1] = nil
				end
		end
					end
				elseif (pointer * pointer) + 42 == 3178 then
					do
						if pointer + 2 == 58 then
			Temp[14] = 14
Temp[7] = Constants
Temp[11] = 33
Stack[Temp[14]] = Temp[7][Temp[11]]
	Stack[11](Stack[12], Stack[13], Stack[14])
	pointer = pointer + 1
		end
					end
				elseif (pointer * pointer * 2) + pointer == 6786 then
					do
						if (pointer + 88) > pointer then
			do
				if pointer * 2 - 8 == 108 then
					if pointer + 4 == 81 then
					Stack[1] = nil
				end
				if pointer * 3 - 5 == 169 then
						return
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