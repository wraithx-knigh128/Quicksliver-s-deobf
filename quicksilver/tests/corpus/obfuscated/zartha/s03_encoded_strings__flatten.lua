return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\030\050", "990")),(decrypt("\104\082\086\104\108\088", "243")),(decrypt("\089\111\108\033\090\092\080\108\080\039\105\095\084\094\085\033\111\086\095\033\083\092\084\081\088\039\086\091\110\089\039\093\109\108\039\085\106\065\064\033\105\086\110", "2006")),(decrypt("\088\109\085\107\088\091\100", "1187")),(decrypt("\094\095\109", "434")),(decrypt("\088\080\081\088", "2683")),(decrypt("\103\083\084\096", "998")),(decrypt("\106\091\083\104\106", "2847")),(decrypt("\111\084\092\098", "2499")),(decrypt("\091\091\088\088\084\110", "1018")),(decrypt("\100\112\001\011\126\124\002\014\121\010\003", "2686")),(decrypt("\094\084\083\109\091", "2341")),(decrypt("\106\105\086\094\105", "1555")),(decrypt("\085\089\082\086\089", "2023")),(decrypt("\108\094\089\081\105\083", "1805")),(decrypt("\124\107\106\100\086\095\096", "834")),(decrypt("\024\051", "2823")),(decrypt("\085\111\085\080\088", "2759")),(decrypt("\021", "2332")),(decrypt("\001\051", "1859")),(decrypt("\093\105\110\085\109", "617")),(decrypt("\008\085\092\109", "1601")),(decrypt("\096\041\031\030\105\097\047\043\088\034\039\043\105\034\098\104\106\092\082\023", "2587")),(decrypt("\104\102\111\080\081\089\107", "2979")),(decrypt("\003", "776")),(decrypt("\032", "778")),(decrypt("\089\082\097\089\092\083", "959")),(decrypt("\111\094\095\088\091\094\091", "2803")),(decrypt("\095", "981")),(decrypt("\031\059", "707")),(decrypt("\045\096", "1847")),(decrypt("\120\100\080\082\081\098\111\090\109\099\125\090\087\081\111\111\109", "1871")),(decrypt("\102\081\105\083\111\110", "851")),(decrypt("\020\062", "853")),(decrypt("\107\080\109\084\084", "2959")),(decrypt("\014\109\091\086\087\018\047\125\093\081\098\087\123\081\091\088\109\088\032", "1185")),(decrypt("\104\085\089", "536")),(decrypt("\029\017\018\029\017\018\029\017\018\029\017\018\029\017\018\029\017\018\029\017", "956")),(decrypt("\105\105", "1032")),(decrypt("\110\099\108\080", "2936")),(decrypt("\088\100\080", "1875")),(decrypt("\068", "718")),(decrypt("\009\110\109\095\066\085\092\106\105", "2276")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
				if (pointer * 12) + pointer <= 728 then
	if (pointer * pointer) + (4 * pointer) <= 896 then
		if pointer * pointer <= 169 then
			if (pointer * 6) + pointer <= 42 then
				if (pointer * 7) + pointer <= 24 then
					if (pointer * pointer) + 27 == 28 then
						do
							do
			if pointer + 8 == 9 then
					if pointer * 2 + 6 == 8 then
					if pointer + 14 == 27 then
					Stack[8] = nil
				end
				Temp[2] = 0
Temp[15] = ttostring ~= __metatable
Stack[Temp[2]] = Temp[6]
				end
				end
		end
						end
					elseif (pointer * pointer) + (3 * pointer) == 18 then
						do
							if pointer + 7 == 10 then
			Temp[7] = 0
Temp[11] = Constants
Temp[5] = 36
Stack[Temp[7]] = Temp[11][Temp[5]]
		end
						end
					elseif (pointer * pointer) + (6 * pointer) == 16 then
						do
							if pointer + 15 == 17 then
			Temp[6] = vmEnv
Temp[14] = 11
Temp[5] = Constants[Temp[14]]
Temp[3] = 0
Temp[6][Temp[5]] = Temp[5]
		end
						end
					end
				else
					if (pointer * pointer) + (14 * pointer) == 72 then
						do
							if (pointer + 85) > pointer then
			do
				if pointer + 2 == 8 then
					Stack[4] = nil
				end
				Temp[7] = 1
Temp[15] = Constants
Temp[9] = 38
Stack[Temp[7]] = Temp[15][Temp[9]]
			end
		else
			Temp[4] = 5
			Temp[12] = Constants
			Temp[16] = 12
			Stack[Temp[9]] = Temp[14][Temp[12]]
		end
						end
					elseif (pointer * pointer) + (6 * pointer) == 55 then
						do
							if (pointer + 37) > pointer then
			do
				if pointer - 7 == -2 then
					if pointer * 2 - 4 == 6 then
					if pointer + 10 == 15 then
						Stack[2] = {}
				end
				end
				elseif pointer - 7 == 4 then
					Stack[8] = Env[4]
				end
			end
		else
			Stack[1] = (1 == 1)
		end
						end
					elseif (pointer * pointer * 4) + pointer == 150 then
						do
							if (pointer + 54) > pointer then
			do
				if pointer + 15 == 21 then
					if pointer - 10 == -4 then
					Temp[12] = 3
Temp[14] = Constants
Temp[15] = 8
Stack[Temp[12]] = Temp[14][Temp[15]]
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
				if (pointer * pointer) + (6 * pointer) <= 135 then
					if (pointer * 7) + (pointer * 28) == 280 then
						do
							if (pointer + 52) > pointer then
			do
				if pointer + 10 == 18 then
					Temp[7] = 5
Temp[10] = Constants
Temp[14] = 24
Stack[Temp[7]] = Temp[10][Temp[14]]
				end
			end
		else
			if pointer > 101 then Stack[1] = Stack[3] end
		end
						end
					elseif (pointer * pointer) + 45 == 94 then
						do
							if pointer + 9 == 16 then
			Temp[7] = 4
Temp[4] = Constants
Temp[11] = 35
Stack[Temp[7]] = Temp[4][Temp[11]]
		end
						end
					elseif (pointer * pointer * 3) + pointer == 252 then
						do
							if (pointer + 89) > pointer then
			do
				if pointer * 2 + 1 == 19 then
					if pointer + 14 == 30 then
					Stack[2] = nil
				end
				if pointer * 2 + 9 == 27 then
					Temp[12] = 6
Temp[15] = Constants
Temp[13] = 13
Stack[Temp[12]] = Temp[15][Temp[13]]
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
				else
					if (pointer * 6) + (pointer * 21) == 324 then
						do
							do
			if pointer - 13 == -1 then
					if pointer * 2 + 10 == 34 then
						for i = 1, 6 do
		Stack[2][(1 - 1) * 50 + i] = Stack[2 + i]
	end
	
				end
				elseif pointer - 13 == 8 then
					Stack[7] = Env[5]
				end
		end
						end
					elseif (pointer * pointer * 2) + pointer == 253 then
						do
							do
			if pointer + 2 == 13 then
					if pointer + 13 == 24 then
					if pointer + 5 ~= 34 then
					Temp[7] = 8
Temp[16] = Constants
Temp[15] = 28
Stack[Temp[7]] = Temp[16][Temp[15]]
				end
				end
				end
		end
						end
					elseif (pointer * pointer) + 10 == 179 then
						do
							if (pointer + 7) > pointer then
			do
				if pointer - 9 == 4 then
					if pointer - 3 == 10 then
					Temp[13] = 3
Temp[3] = Constants
Temp[16] = 23
Stack[Temp[13]] = Temp[3][Temp[16]]
				end
				elseif pointer - 9 == 7 then
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
					elseif (pointer * pointer) + (14 * pointer) == 240 then
						do
							if (pointer + 82) > pointer then
			do
				if pointer + 5 == 30 then
					Stack[8] = nil
				end
				if pointer + 9 == 19 then
					if pointer + 11 ~= 32 then
					Temp[6] = 7
Temp[2] = Constants
Temp[9] = 40
Stack[Temp[6]] = Temp[2][Temp[9]]
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
		else
			if (pointer * 10) + pointer <= 220 then
				if (pointer * 5) + pointer <= 96 then
					if (pointer * pointer) + 24 == 220 then
						do
							do
			if pointer - 15 == -1 then
					if pointer - 13 == 1 then
					Temp[4] = 4
Temp[10] = 14
Temp[8] = Constants[Temp[10]]
Stack[Temp[4]] = vmEnv[Temp[8]] or Env[Temp[8]]
				elseif pointer - 13 == 7 then
					Stack[5] = Env[1]
				end
				elseif pointer - 15 == 17 then
					Stack[8] = Env[6]
				end
		end
						end
					elseif (pointer * pointer * 2) + pointer == 465 then
						do
							if pointer + 15 == 30 then
			Temp[1] = 5
Temp[8] = 0
Stack[Temp[1]] = Stack[Temp[8]]
		end
						end
					elseif (pointer * pointer) + 19 == 275 then
						do
							if (pointer + 40) > pointer then
			do
				if pointer - 7 == 9 then
					if pointer - 11 == 5 then
						Stack[4](Stack[5])
				elseif pointer - 11 == 14 then
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
					if (pointer * pointer * 4) + pointer == 1463 then
						do
							do
			if pointer + 9 ~= 30 then
					if pointer * 3 - 11 == 46 then
					if pointer * 2 - 2 == 36 then
						Stack[4](Stack[5])
				end
				else
					Stack[6] = nil
				end
				end
		end
						end
					elseif (pointer * pointer) + (12 * pointer) == 540 then
						do
							do
			if pointer * 2 - 9 == 27 then
					if pointer - 13 == 5 then
					Temp[14] = 5
Temp[11] = 1
Stack[Temp[14]] = Stack[Temp[11]]
				elseif pointer - 13 == 24 then
					Stack[8] = Env[7]
				end
				end
		end
						end
					elseif (pointer * pointer) + (13 * pointer) == 510 then
						do
							if (pointer + 17) > pointer then
			do
				if pointer + 12 == 33 then
					Stack[2] = nil
				end
				Temp[1] = 4
Temp[12] = 14
Temp[5] = Constants[Temp[12]]
Stack[Temp[1]] = vmEnv[Temp[5]] or Env[Temp[5]]
			end
		else
			if pointer > 69 then Stack[4] = Stack[5] end
		end
						end
					elseif (pointer * 3) + (pointer * 26) == 580 then
						do
							if pointer + 4 == 24 then
			Temp[12] = 4
Temp[5] = 27
Temp[14] = Constants[Temp[5]]
Stack[Temp[12]] = vmEnv[Temp[14]] or Env[Temp[14]]
		end
						end
					end
				end
			else
				if pointer * pointer <= 529 then
					if (pointer * pointer * 5) + pointer == 2668 then
						do
							if pointer + 5 == 28 then
			pointer = pointer + 10 
		end
						end
					elseif (pointer * 14) + (pointer * 45) == 1298 then
						do
							do
			if pointer * 2 + 12 == 56 then
						Stack[4], Stack[5], Stack[6] = Stack[4](Stack[5])
				end
		end
						end
					elseif (pointer * pointer * 3) + pointer == 1344 then
						do
							if (pointer + 65) > pointer then
			do
				if pointer - 11 == 10 then
					if pointer * 2 + 3 == 45 then
					if pointer * 3 - 8 == 55 then
					Temp[7] = 5
Temp[11] = 2
Stack[Temp[7]] = Stack[Temp[11]]
				else
					Stack[7] = nil
				end
				end
				elseif pointer - 11 == 12 then
					Stack[2] = Env[4]
				end
			end
		else
			Stack[1] = Stack[7] or Constants[7+1]
		end
						end
					end
				else
					if (pointer * pointer) + (3 * pointer) == 700 then
						do
							do
			if pointer + 14 == 39 then
					if pointer - 6 == 19 then
					Temp[5] = 10
Temp[1] = 10
Temp[12] = Constants[Temp[1]]
Stack[Temp[5]] = vmEnv[Temp[12]] or Env[Temp[12]]
	Stack[10] = Stack[10][Constants[15]]
	
	pointer = pointer + 1
				end
				end
		end
						end
					elseif (pointer * pointer) + (12 * pointer) == 1120 then
						do
							if pointer + 1 == 29 then
			Temp[3] = 12
Temp[7] = 7
Stack[Temp[3]] = Stack[Temp[7]]
		end
						end
					elseif (pointer * pointer) + 25 == 601 then
						do
							if pointer + 9 == 33 then
			Temp[7] = 9
Temp[4] = 14
Temp[6] = Constants[Temp[4]]
Stack[Temp[7]] = vmEnv[Temp[6]] or Env[Temp[6]]
		end
						end
					elseif (pointer * pointer * 4) + pointer == 2943 then
						do
							do
			if pointer * 3 - 4 == 77 then
					if pointer + 11 == 38 then
					if pointer + 2 == 39 then
					Stack[4] = nil
				end
				Temp[7] = 11
Temp[10] = 3
Stack[Temp[7]] = Stack[Temp[10]]
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
	else
		if (pointer * 5) + pointer <= 246 then
			if pointer * pointer <= 1156 then
				if pointer * pointer <= 961 then
					if (pointer * pointer) + 36 == 877 then
						do
							if pointer + 14 == 43 then
				Stack[14] = Stack[8]
	if Stack[14] then
		Stack[13] = Stack[8][Constants[12]]
	end
	
		end
						end
					elseif (pointer * pointer) + (12 * pointer) == 1260 then
						do
							if (pointer - 41) > pointer then
			if (pointer * 2) < 0 then Env[1] = nil end
		else
			do
				if pointer + 5 ~= 48 then
					if pointer * 3 - 7 == 83 then
					if pointer - 9 == 21 then
						Stack[13] = Stack[13](Stack[14])
				end
				else
					Stack[2] = nil
				end
				end
			end
		end
						end
					elseif (pointer * pointer) + 13 == 974 then
						do
							do
			if pointer * 2 + 3 == 65 then
					if pointer * 2 + 1 == 63 then
						Stack[14] = #Stack[8]
				end
				end
		end
						end
					end
				else
					if (pointer * pointer) + (4 * pointer) == 1292 then
						do
							if (pointer + 41) > pointer then
			do
				if pointer + 12 ~= 51 then
					if pointer + 13 == 53 then
					Stack[4] = nil
				end
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
		else
			Stack[5] = -Stack[1]
		end
						end
					elseif (pointer * pointer * 2) + pointer == 2080 then
						do
							if pointer + 7 == 39 then
				Temp[2] = {Stack[10](Stack[11], Stack[12], Stack[13], Stack[14])}
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
					elseif (pointer * 13) + (pointer * 48) == 2013 then
						do
							if pointer + 8 == 41 then
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
				end
			else
				if (pointer * 10) + pointer <= 407 then
					if (pointer * pointer * 2) + pointer == 2628 then
						do
							do
			if pointer * 2 + 12 == 84 then
					Temp[8] = 4
Temp[15] = 14
Temp[3] = Constants[Temp[15]]
Stack[Temp[8]] = vmEnv[Temp[3]] or Env[Temp[3]]
				end
		end
						end
					elseif (pointer * pointer * 3) + pointer == 4144 then
						do
							if pointer + 5 == 42 then
			Temp[11] = 5
Temp[14] = 1
Stack[Temp[11]] = Stack[Temp[14]]
		end
						end
					elseif (pointer * pointer * 2) + pointer == 2485 then
						do
							do
			if pointer - 2 == 33 then
					if pointer + 11 ~= 51 then
					pointer = pointer + -12 
				end
				end
		end
						end
					end
				else
					if (pointer * 5) + (pointer * 16) == 798 then
						do
							do
			if pointer + 5 == 44 then
					Stack[3] = nil
				end
					Stack[4](Stack[5])
		end
						end
					elseif (pointer * pointer) + 18 == 1539 then
						do
							if (pointer - 23) > pointer then
			Stack[2] = (0 == 1)
		else
			do
				if pointer * 3 - 6 == 111 then
					Temp[7] = 4
Temp[4] = Constants
Temp[8] = 3
Stack[Temp[7]] = Temp[4][Temp[8]]
				else
					Stack[2] = nil
				end
			end
		end
						end
					elseif (pointer * 4) + (pointer * 16) == 800 then
						do
							if pointer + 2 == 42 then
				Stack[5] = {}
		end
						end
					elseif (pointer * pointer) + 14 == 1695 then
						do
							do
			if pointer * 2 - 3 == 79 then
						Stack[7] = Stack[4]
	if Stack[7] then
		Stack[6] = Stack[4][Constants[33]]
	end
	
				end
		end
						end
					end
				end
			end
		else
			if pointer * pointer <= 2401 then
				if pointer * pointer <= 2025 then
					if (pointer * pointer * 3) + pointer == 5852 then
						do
							if pointer + 11 == 55 then
			pointer = pointer + 6 
		end
						end
					elseif (pointer * pointer) + 14 == 2039 then
						do
							if pointer + 9 == 54 then
				Stack[10] = Stack[5][Stack[9]]
	
		end
						end
					elseif (pointer * pointer) + 50 == 1814 then
						do
							if pointer + 13 == 55 then
			Temp[15] = 8
Temp[5] = Constants
Temp[16] = 31
Stack[Temp[15]] = Temp[5][Temp[16]]
	Stack[6], Stack[7], Stack[8] = Stack[6](Stack[7], Stack[8])
	pointer = pointer + 1
		end
						end
					end
				else
					if (pointer * 13) + (pointer * 13) == 1222 then
						do
							if (pointer + 93) > pointer then
			do
				if pointer - 12 == 35 then
					if pointer * 3 - 10 == 131 then
					if pointer + 6 ~= 65 then
					pointer = pointer + 1 
				end
				else
					Stack[4] = nil
				end
				elseif pointer - 12 == 54 then
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
					elseif (pointer * pointer) + (9 * pointer) == 2530 then
						do
							if pointer + 3 == 49 then
				if not Stack[10] then pointer = pointer + 1 end
		end
						end
					elseif (pointer * 12) + (pointer * 38) == 2450 then
						do
							do
			if pointer * 3 - 9 == 138 then
					if pointer - 2 == 47 then
						Stack[10] = Stack[10] + Constants[30]
				elseif pointer - 2 == 58 then
					Stack[3] = Env[5]
				end
				else
					Stack[1] = nil
				end
		end
						end
					elseif (pointer * pointer) + (11 * pointer) == 2832 then
						do
							if pointer + 14 == 62 then
			Temp[15] = 10
Temp[16] = Constants
Temp[4] = 1
Stack[Temp[15]] = Temp[16][Temp[4]]
		end
						end
					end
				end
			else
				if pointer * pointer <= 2704 then
					if (pointer * 14) + (pointer * 38) == 2600 then
						do
							if (pointer + 62) > pointer then
			do
				if pointer + 8 == 58 then
					if pointer * 2 - 2 == 98 then
						Stack[5][Stack[9]] = Stack[10]
				end
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
						end
					elseif (pointer * pointer * 3) + pointer == 8164 then
						do
							if (pointer + 78) > pointer then
			do
				if pointer * 2 - 8 == 96 then
					pointer = pointer + -8 
				end
			end
		else
			Stack[5] = Stack[8] or Constants[2+1]
		end
						end
					elseif (pointer * pointer) + (13 * pointer) == 3264 then
						do
							do
			if pointer * 2 + 15 == 117 then
					if pointer * 2 + 3 == 105 then
					if pointer + 1 ~= 69 then
					    local r1 = Stack[6](Stack[7], Stack[8])
    Stack[9] = r1
    if Stack[9] ~= nil then
        Stack[8] = Stack[9]
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
					if (pointer * 12) + (pointer * 37) == 2597 then
						do
							do
			if pointer - 4 == 49 then
					if pointer - 11 == 42 then
						Stack[6] = {}
				end
				end
		end
						end
					elseif (pointer * pointer) + (15 * pointer) == 3726 then
						do
							if pointer + 14 == 68 then
			Temp[12] = 7
Temp[11] = 18
Temp[16] = Constants[Temp[11]]
Stack[Temp[12]] = vmEnv[Temp[16]] or Env[Temp[16]]
		end
						end
					elseif (pointer * pointer * 2) + pointer == 6105 then
						do
							if pointer + 4 == 59 then
			Temp[16] = 8
Temp[9] = 5
Stack[Temp[16]] = Stack[Temp[9]]
		end
						end
					elseif (pointer * pointer) + (4 * pointer) == 3360 then
						do
							do
			if pointer * 3 - 3 == 165 then
					if pointer + 4 == 60 then
						Stack[7], Stack[8], Stack[9] = Stack[7](Stack[8])
				end
				else
					Stack[5] = nil
				end
		end
						end
					end
				end
			end
		end
	end
else
	if pointer * pointer <= 7225 then
		if pointer * pointer <= 4900 then
			if pointer * pointer <= 3844 then
				if (pointer * 9) + pointer <= 590 then
					if (pointer * pointer * 3) + pointer == 10150 then
						do
							if pointer + 5 == 63 then
				Stack[11] = #Stack[6]
		end
						end
					elseif (pointer * pointer) + (5 * pointer) == 3534 then
						do
							do
			if pointer + 14 == 71 then
					pointer = pointer + 3 
				end
		end
						end
					elseif (pointer * pointer * 3) + pointer == 10502 then
						do
							do
			if pointer * 3 - 6 == 171 then
					if pointer - 3 == 56 then
						Stack[11] = Stack[11] + Constants[30]
				elseif pointer - 3 == 62 then
					Stack[2] = Env[2]
				end
				else
					Stack[3] = nil
				end
		end
						end
					end
				else
					if (pointer * pointer * 3) + pointer == 11594 then
						do
							do
			if pointer + 12 == 88 then
					Stack[7] = nil
				end
				if pointer + 14 ~= 80 then
					pointer = pointer + -5 
				end
		end
						end
					elseif (pointer * pointer * 2) + pointer == 7260 then
						do
							if (pointer - 62) > pointer then
			if pointer > 154 then Stack[4] = Stack[3] end
		else
			do
				if pointer * 2 - 3 == 117 then
						Stack[6][Stack[11]] = Stack[10]
				end
			end
		end
						end
					elseif (pointer * pointer * 2) + pointer == 7503 then
						do
							do
			if pointer + 2 == 63 then
					if pointer - 2 == 59 then
					if pointer * 3 - 9 == 174 then
					    local r1 = Stack[7](Stack[8], Stack[9])
    Stack[10] = r1
    if Stack[10] ~= nil then
        Stack[9] = Stack[10]
    else
        pointer = pointer + 1
    end
    
				else
					Stack[6] = nil
				end
				end
				end
		end
						end
					end
				end
			else
				if (pointer * 8) + pointer <= 594 then
					if (pointer * pointer) + (8 * pointer) == 4473 then
						do
							do
			if pointer * 3 - 1 == 188 then
					Temp[6] = 7
Temp[10] = 21
Temp[15] = Constants[Temp[10]]
Stack[Temp[6]] = vmEnv[Temp[15]] or Env[Temp[15]]
	Stack[7] = Stack[7][Constants[6]]
	
	pointer = pointer + 1
				else
					Stack[7] = nil
				end
		end
						end
					elseif (pointer * 11) + (pointer * 35) == 3036 then
						do
							if pointer + 14 == 80 then
				Stack[7](Stack[8])
		end
						end
					elseif (pointer * 15) + (pointer * 25) == 2600 then
						do
							if (pointer - 17) > pointer then
			Stack[6] = Stack[4] or Constants[8+1]
		else
			do
				if pointer - 12 == 53 then
					if pointer * 2 - 2 == 128 then
					if pointer * 3 - 9 == 186 then
					Temp[10] = 8
Temp[16] = 6
Stack[Temp[10]] = Stack[Temp[16]]
				else
					Stack[4] = nil
				end
				end
				end
			end
		end
						end
					end
				else
					if (pointer * pointer * 5) + pointer == 22512 then
						do
							if pointer + 8 == 75 then
				Stack[7] = {}
		end
						end
					elseif (pointer * pointer) + 34 == 4658 then
						do
							if pointer + 3 == 71 then
			Temp[4] = 8
Temp[11] = 27
Temp[12] = Constants[Temp[11]]
Stack[Temp[4]] = vmEnv[Temp[12]] or Env[Temp[12]]
		end
						end
					elseif (pointer * pointer) + 32 == 4793 then
						do
							if pointer + 13 == 82 then
			Temp[11] = 9
Temp[4] = 6
Stack[Temp[11]] = Stack[Temp[4]]
		end
						end
					elseif (pointer * pointer * 4) + pointer == 19670 then
						do
							do
			if pointer - 6 == 64 then
					if pointer - 4 == 66 then
						Stack[8], Stack[9], Stack[10] = Stack[8](Stack[9])
				elseif pointer - 4 == 83 then
					Stack[1] = Env[2]
				end
				elseif pointer - 6 == 71 then
					Stack[2] = Env[1]
				end
		end
						end
					end
				end
			end
		else
			if (pointer * 14) + pointer <= 1155 then
				if (pointer * 4) + pointer <= 365 then
					if (pointer * pointer) + 19 == 5348 then
						do
							if (pointer + 50) > pointer then
			do
				if pointer + 2 ~= 85 then
						Stack[13] = Stack[13] + Constants[30]
				end
			end
		else
			if pointer > 86 then Stack[7] = Stack[7] end
		end
						end
					elseif (pointer * pointer) + (13 * pointer) == 6120 then
						do
							if pointer + 8 == 80 then
				Stack[13] = #Stack[7]
		end
						end
					elseif (pointer * pointer) + (6 * pointer) == 5467 then
						do
							do
			if pointer * 2 + 5 == 147 then
					pointer = pointer + 7 
				end
		end
						end
					end
				else
					if (pointer * 12) + (pointer * 8) == 1520 then
						do
							if (pointer - 34) > pointer then
						Temp[4] = vmEnv
			Temp[8] = 17
			Temp[15] = Constants[Temp[5]]
			Temp[14] = 9
			Temp[9][Temp[6]] = Temp[2]
		else
			do
				if pointer + 5 == 81 then
					if pointer * 2 + 9 == 161 then
					if pointer + 5 == 90 then
					Stack[3] = nil
				end
					Stack[16] = Stack[5][Stack[12]]
	
				end
				end
			end
		end
						end
					elseif (pointer * pointer * 4) + pointer == 23793 then
						do
							do
			if pointer + 6 == 92 then
					Stack[2] = nil
				end
				if pointer - 13 == 64 then
						Temp[1] = ""
	for i = 14, 16 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[14] = Temp[1]
	
				elseif pointer - 13 == 78 then
					Stack[2] = Env[5]
				end
		end
						end
					elseif (pointer * pointer) + (6 * pointer) == 5920 then
						do
							do
			if pointer + 9 ~= 97 then
					if pointer * 2 - 5 == 143 then
					Temp[14] = 14
Temp[1] = 12
Stack[Temp[14]] = Stack[Temp[1]]
				end
				end
		end
						end
					elseif (pointer * 4) + (pointer * 13) == 1275 then
						do
							if (pointer - 62) > pointer then
			Stack[2] = nil
		else
			do
				if pointer - 12 == 63 then
					if pointer + 5 == 80 then
					Temp[12] = 15
Temp[13] = Constants
Temp[4] = 25
Stack[Temp[12]] = Temp[13][Temp[4]]
				end
				end
			end
		end
						end
					end
				end
			else
				if (pointer * 3) + pointer <= 320 then
					if (pointer * pointer * 2) + pointer == 12246 then
						do
							if (pointer + 71) > pointer then
			do
				if pointer + 2 == 80 then
					if pointer + 9 == 87 then
					if pointer + 10 == 90 then
					Stack[6] = nil
				end
					Stack[7][Stack[13]] = Stack[14]
				end
				end
			end
		else
			Stack[8] = -Stack[2]
		end
						end
					elseif (pointer * pointer) + (12 * pointer) == 7189 then
						do
							do
			if pointer - 12 == 67 then
					    local r1, r2 = Stack[8](Stack[9], Stack[10])
    Stack[11] = r1
        Stack[12] = r2
    if Stack[11] ~= nil then
        Stack[10] = Stack[11]
    else
        pointer = pointer + 1
    end
    
				elseif pointer - 12 == 69 then
					Stack[1] = Env[4]
				end
		end
						end
					elseif (pointer * 15) + (pointer * 46) == 4880 then
						do
							if pointer + 13 == 93 then
			pointer = pointer + -9 
		end
						end
					end
				else
					if (pointer * pointer * 2) + pointer == 14196 then
						do
							do
			if pointer * 3 - 10 == 242 then
					if pointer + 5 == 107 then
					Stack[4] = nil
				end
				if pointer + 11 == 95 then
					Temp[6] = 10
Temp[14] = 7
Stack[Temp[6]] = Stack[Temp[14]]
				end
				else
					Stack[6] = nil
				end
		end
						end
					elseif (pointer * pointer) + (3 * pointer) == 6970 then
						do
							if pointer + 1 == 83 then
			Temp[8] = 9
Temp[14] = 21
Temp[1] = Constants[Temp[14]]
Stack[Temp[8]] = vmEnv[Temp[1]] or Env[Temp[1]]
	Stack[9] = Stack[9][Constants[2]]
	
	pointer = pointer + 1
		end
						end
					elseif (pointer * pointer) + 46 == 7271 then
						do
							if (pointer + 8) > pointer then
			do
				if pointer * 2 + 6 == 176 then
					if pointer - 1 == 84 then
					if pointer * 3 - 8 == 247 then
					Temp[5] = 11
Temp[2] = Constants
Temp[9] = 26
Stack[Temp[5]] = Temp[2][Temp[9]]
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
				else
					Stack[7] = nil
				end
				elseif pointer - 1 == 96 then
					Stack[1] = Env[4]
				end
				end
			end
		else
			Stack[8] = -Stack[3]
		end
						end
					elseif (pointer * pointer) + 9 == 6570 then
						do
							if (pointer + 51) > pointer then
			do
				if pointer * 2 + 13 == 175 then
					Temp[7] = 8
Temp[10] = 14
Temp[2] = Constants[Temp[10]]
Stack[Temp[7]] = vmEnv[Temp[2]] or Env[Temp[2]]
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
						end
					end
				end
			end
		end
	else
		if (pointer * pointer) + (8 * pointer) <= 11009 then
			if (pointer * pointer) + (3 * pointer) <= 8928 then
				if pointer * pointer <= 7921 then
					if (pointer * pointer) + (4 * pointer) == 7917 then
						do
							do
			if pointer + 15 == 102 then
					if pointer + 2 == 89 then
					if pointer + 4 == 95 then
					Stack[4] = nil
				end
					Temp[1] = {}
	for i = 8 + 1, top do
		Temp[1][i - 8] = Stack[i]
	end
	Temp[2] = {Stack[8](unpack(Temp[1], 1, top - 8))}
		for i = 1, 0 do
		Stack[8 + i - 1] = Temp[2][i]
	end
	
	
				end
				end
		end
						end
					elseif (pointer * pointer) + (4 * pointer) == 8096 then
						do
							do
			if pointer - 4 == 84 then
					if pointer + 2 ~= 104 then
					Temp[4] = 8
Temp[1] = 14
Temp[9] = Constants[Temp[1]]
Stack[Temp[4]] = vmEnv[Temp[9]] or Env[Temp[9]]
				end
				end
		end
						end
					elseif (pointer * pointer) + (12 * pointer) == 8989 then
						do
							if (pointer + 82) > pointer then
			do
				if pointer + 11 ~= 112 then
						Stack[10] = Stack[4]
	if Stack[10] then
		Stack[9] = Stack[4][Constants[4]]
	end
	
				end
			end
		else
			Stack[8] = Stack[2] or Constants[8+1]
		end
						end
					end
				else
					if (pointer * pointer) + 31 == 8680 then
						do
							if pointer + 4 == 97 then
				Stack[10] = Stack[4]
	if Stack[10] then
		Stack[9] = Stack[4][Constants[7]]
	end
	
		end
						end
					elseif (pointer * pointer * 5) + pointer == 40590 then
						do
							if pointer + 4 == 94 then
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
	
		end
						end
					elseif (pointer * pointer * 3) + pointer == 24934 then
						do
							do
			if pointer + 12 == 103 then
					if pointer * 3 - 4 == 269 then
						Temp[1] = {}
	for i = 8 + 1, top do
		Temp[1][i - 8] = Stack[i]
	end
	Temp[2] = {Stack[8](unpack(Temp[1], 1, top - 8))}
		for i = 1, 0 do
		Stack[8 + i - 1] = Temp[2][i]
	end
	
	
				else
					Stack[2] = nil
				end
				end
		end
						end
					elseif (pointer * 5) + (pointer * 13) == 1656 then
						do
							if (pointer + 18) > pointer then
			do
				if pointer * 3 - 10 == 266 then
					if pointer - 5 == 87 then
					if pointer * 2 - 6 == 178 then
					Temp[11] = 8
Temp[16] = 14
Temp[3] = Constants[Temp[16]]
Stack[Temp[11]] = vmEnv[Temp[3]] or Env[Temp[3]]
				end
				elseif pointer - 5 == 104 then
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
					end
				end
			else
				if pointer * pointer <= 9409 then
					if (pointer * pointer * 4) + pointer == 37733 then
						do
							do
			if pointer + 9 == 123 then
					Stack[3] = nil
				end
				if pointer + 8 == 109 then
					Stack[8] = nil
				end
				if pointer * 2 - 9 == 185 then
						Stack[8](Stack[9])
				end
		end
						end
					elseif (pointer * 14) + (pointer * 17) == 2914 then
						do
							if (pointer - 95) > pointer then
						Temp[2] = vmEnv
			Temp[1] = 4
			Temp[12] = Constants[Temp[14]]
			Temp[8] = 19
			Temp[15][Temp[6]] = Temp[6]
		else
			do
				if pointer + 12 == 106 then
					Temp[11] = 11
Temp[3] = Constants
Temp[13] = 29
Stack[Temp[11]] = Temp[3][Temp[13]]
				end
			end
		end
						end
					elseif (pointer * pointer * 2) + pointer == 18145 then
						do
							do
			if pointer + 11 ~= 123 then
					if pointer + 10 == 124 then
					Stack[3] = nil
				end
				Temp[6] = 12
Temp[14] = Constants
Temp[1] = 19
Stack[Temp[6]] = Temp[14][Temp[1]]
	Stack[9] = Stack[9](Stack[10], Stack[11], Stack[12])
	pointer = pointer + 1
				end
		end
						end
					end
				else
					if (pointer * 13) + (pointer * 21) == 3400 then
						do
							if (pointer + 19) > pointer then
			do
				if pointer * 2 + 4 == 204 then
					if pointer - 2 == 98 then
					if pointer - 11 == 89 then
						Stack[10] = Stack[9]
	if Stack[10] then
		Stack[9] = Stack[9][Constants[41]]
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
					elseif (pointer * 9) + (pointer * 18) == 2727 then
						do
							do
			if pointer * 2 + 4 == 206 then
					Temp[9] = 11
Temp[11] = Constants
Temp[12] = 17
Stack[Temp[9]] = Temp[11][Temp[12]]
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
					elseif (pointer * pointer) + 6 == 9610 then
						do
							if (pointer + 22) > pointer then
			do
				if pointer * 2 + 7 == 203 then
					if pointer - 12 == 86 then
					Temp[3] = 8
Temp[14] = 14
Temp[12] = Constants[Temp[14]]
Stack[Temp[3]] = vmEnv[Temp[12]] or Env[Temp[12]]
				elseif pointer - 12 == 96 then
					Stack[3] = Env[2]
				end
				end
			end
		else
			Temp[18] = 4
			Temp[16] = Constants
			Temp[6] = 14
			Stack[Temp[19]] = Temp[20][Temp[9]]
		end
						end
					elseif (pointer * 15) + (pointer * 17) == 3168 then
						do
							do
			if pointer * 2 + 7 == 205 then
					if pointer - 10 == 89 then
					Temp[15] = 9
Temp[1] = Constants
Temp[2] = 39
Stack[Temp[15]] = Temp[1][Temp[2]]
				elseif pointer - 10 == 107 then
					Stack[7] = Env[8]
				end
				end
		end
						end
					end
				end
			end
		else
			if pointer * pointer <= 12100 then
				if (pointer * pointer) + (10 * pointer) <= 12075 then
					if (pointer * 13) + (pointer * 42) == 5720 then
						do
							if (pointer + 58) > pointer then
			do
				if pointer * 2 - 7 == 201 then
					Temp[10] = 8
Temp[2] = 14
Temp[8] = Constants[Temp[2]]
Stack[Temp[10]] = vmEnv[Temp[8]] or Env[Temp[8]]
				end
			end
		else
			if (pointer * 2) < 0 then Env[1] = nil end
		end
						end
					elseif (pointer * pointer) + 9 == 11034 then
						do
							if pointer + 7 == 112 then
				Stack[10] = Stack[4]
	if Stack[10] then
		Stack[9] = Stack[4][Constants[5]]
	end
	
		end
						end
					elseif (pointer * pointer) + 5 == 10614 then
						do
							if pointer + 15 == 118 then
				Temp[1] = {}
	for i = 8 + 1, top do
		Temp[1][i - 8] = Stack[i]
	end
	Temp[2] = {Stack[8](unpack(Temp[1], 1, top - 8))}
		for i = 1, 0 do
		Stack[8 + i - 1] = Temp[2][i]
	end
	
	
		end
						end
					end
				else
					if (pointer * 4) + (pointer * 10) == 1498 then
						do
							do
			if pointer + 15 == 132 then
					Stack[2] = nil
				end
				if pointer + 3 == 110 then
					Temp[16] = 12
Temp[2] = Constants
Temp[9] = 20
Stack[Temp[16]] = Temp[2][Temp[9]]
	Stack[9] = Stack[9](Stack[10], Stack[11], Stack[12])
	pointer = pointer + 1
				end
		end
						end
					elseif (pointer * pointer) + (12 * pointer) == 13420 then
						do
							if pointer + 5 == 115 then
				Stack[12] = Stack[4]
	if Stack[12] then
		Stack[11] = Stack[4][Constants[9]]
	end
	
		end
						end
					elseif (pointer * pointer) + (5 * pointer) == 11766 then
						do
							if pointer + 8 == 114 then
			Temp[8] = 11
Temp[14] = Constants
Temp[9] = 34
Stack[Temp[8]] = Temp[14][Temp[9]]
		end
						end
					elseif (pointer * pointer) + 14 == 11895 then
						do
							if pointer + 4 == 113 then
			Temp[16] = 10
Temp[11] = Constants
Temp[3] = 42
Stack[Temp[16]] = Temp[11][Temp[3]]
		end
						end
					end
				end
			else
				if pointer * pointer <= 12769 then
					if (pointer * pointer) + (14 * pointer) == 14112 then
						do
							if (pointer + 80) > pointer then
			do
				if pointer + 15 ~= 133 then
					if pointer * 2 + 3 == 227 then
					if pointer - 7 == 105 then
					Temp[2] = 14
Temp[10] = Constants
Temp[3] = 30
Stack[Temp[2]] = Temp[10][Temp[3]]
				end
				end
				end
			end
		else
			if pointer > 153 then Stack[4] = Stack[4] end
		end
						end
					elseif (pointer * pointer * 3) + pointer == 38420 then
						do
							do
			if pointer - 7 == 106 then
					Temp[15] = 15
Temp[10] = ttostring ~= __metatable
Stack[Temp[15]] = Temp[6]
				elseif pointer - 7 == 120 then
					Stack[8] = Env[5]
				end
		end
						end
					elseif (pointer * 2) + (pointer * 17) == 2109 then
						do
							do
			if pointer * 3 - 6 == 327 then
					if pointer * 3 - 10 == 323 then
					Temp[15] = 13
Temp[13] = Constants
Temp[14] = 37
Stack[Temp[15]] = Temp[13][Temp[14]]
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
					if (pointer * pointer) + 46 == 13502 then
						do
							if pointer + 12 == 128 then
				Stack[8](Stack[9])
		end
						end
					elseif (pointer * pointer) + (8 * pointer) == 14625 then
						do
							if (pointer + 53) > pointer then
			do
				if pointer * 3 - 9 == 342 then
					if pointer - 14 == 103 then
						return
				end
				else
					Stack[8] = nil
				end
			end
		else
			Stack[1] = -Stack[5]
		end
						end
					elseif (pointer * pointer) + 33 == 13258 then
						do
							if pointer + 12 == 127 then
				Temp[1] = ""
	for i = 9, 11 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[9] = Temp[1]
	
		end
						end
					elseif (pointer * pointer) + (6 * pointer) == 13680 then
						do
							if (pointer + 71) > pointer then
			do
				if pointer - 9 == 105 then
						Stack[11] = Stack[11](Stack[12], Stack[13], Stack[14], Stack[15])
				end
			end
		else
			Temp[9] = 4
			Temp[8] = Constants
			Temp[13] = 16
			Stack[Temp[17]] = Temp[12][Temp[10]]
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