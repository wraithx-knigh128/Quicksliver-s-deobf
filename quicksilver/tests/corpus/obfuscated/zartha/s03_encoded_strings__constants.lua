return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\026\059", "2006")),(decrypt("\023", "434")),(decrypt("\077\082\098\095\089\083\095", "998")),(decrypt("\067\081\102\079", "2499")),(decrypt("\030\061", "2686")),(decrypt("\045", "1555")),(decrypt("\064", "1805")),(decrypt("\010\091\110\111\111\036\018\124\065\111\083\106\099\111\110\069\081\074\045", "2823")),(decrypt("\008\121\102\099\114\117\101\102\013\099\124", "2332")),(decrypt("\090\066\085", "617")),(decrypt("\092\064\098\068\085\105", "2587")),(decrypt("\068\084\064\104\095", "776")),(decrypt("\074\098\093\038\069\077\097\087\099\038\084\072\103\067\100\038\080\103\094\042\096\077\105\086\075\042\103\076\081\072\038\070\110\093\042\098\089\092\081\038\086\103\095", "959")),(decrypt("\086\077\093\080", "981")),(decrypt("\105\087\084\111\064\074", "1847")),(decrypt("\101\111\107\085\109", "851")),(decrypt("\009\101\111\080\066\094\094\101\105", "2959")),(decrypt("\018\056", "536")),(decrypt("\083\111", "1032")),(decrypt("\084\078\089\086\085", "1875")),(decrypt("\089", "2276")),(decrypt("\095\087\090\090", "2642")),(decrypt("\113\084\081\095\090\013\083\104\109\106", "1163")),(decrypt("\088\081\094\086\087", "839")),(decrypt("\105\100\082\092\106", "1324")),(decrypt("\085\097\110\082\087\072", "1996")),(decrypt("\094\085\064\083\094\067\085", "1335")),(decrypt("\066\088\073\094\094\095", "1588")),(decrypt("\118\030\042\046\091\118\026\031\110\025\002\031\091\025\091\064\092\111\107\003", "2475")),(decrypt("\018", "2802")),(decrypt("\064\085\087\104\083", "1341")),(decrypt("\043\109", "2076")),(decrypt("\008\084\095\100", "1738")),(decrypt("\082\084\106\092\089\069", "2156")),(decrypt("\002\063", "2448")),(decrypt("\108\098\088\067\102\096\086", "389")),(decrypt("\007\005\000\006\007\005\000\006\007\005\000\006\007\005\000\006\007\005\000\006", "1360")),(decrypt("\123\107\087\086\082\109\104\094\110\108\122\094\084\094\104\107\110", "2705")),(decrypt("\093\095\089\093\093", "2395")),(decrypt("\089\098\092", "2819")),(decrypt("\067\067\088", "1799")),(decrypt("\027\062", "1529")),(decrypt("\106\086\091\101", "1488")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
 Temp[1] = 0
Temp[12] = ttostring ~= __metatable
Stack[Temp[1]] = Temp[5] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[14] = vmEnv
Temp[11] = 9
Temp[12] = Constants[Temp[11]]
Temp[5] = 0
Temp[14][Temp[12]] = Temp[12] 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[14] = 0
Temp[7] = Constants
Temp[11] = 8
Stack[Temp[14]] = Temp[7][Temp[11]] 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[7] = 1
Temp[4] = Constants
Temp[6] = 37
Stack[Temp[7]] = Temp[4][Temp[6]] 
elseif pointer == 5 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 6 then -- 1 [LOADK] 
 Temp[5] = 3
Temp[1] = Constants
Temp[12] = 39
Stack[Temp[5]] = Temp[1][Temp[12]] 
elseif pointer == 7 then -- 1 [LOADK] 
 Temp[7] = 4
Temp[10] = Constants
Temp[3] = 12
Stack[Temp[7]] = Temp[10][Temp[3]] 
elseif pointer == 8 then -- 1 [LOADK] 
 Temp[7] = 5
Temp[8] = Constants
Temp[15] = 36
Stack[Temp[7]] = Temp[8][Temp[15]] 
elseif pointer == 9 then -- 1 [LOADK] 
 Temp[3] = 6
Temp[11] = Constants
Temp[14] = 25
Stack[Temp[3]] = Temp[11][Temp[14]] 
elseif pointer == 10 then -- 1 [LOADK] 
 Temp[7] = 7
Temp[4] = Constants
Temp[8] = 14
Stack[Temp[7]] = Temp[4][Temp[8]] 
elseif pointer == 11 then -- 1 [LOADK] 
 Temp[15] = 8
Temp[5] = Constants
Temp[16] = 3
Stack[Temp[15]] = Temp[5][Temp[16]] 
elseif pointer == 12 then -- 34 [SETLIST] 
 	for i = 1, 6 do
		Stack[2][(1 - 1) * 50 + i] = Stack[2 + i]
	end
	 
elseif pointer == 13 then -- 1 [LOADK] 
 Temp[15] = 3
Temp[16] = Constants
Temp[4] = 29
Stack[Temp[15]] = Temp[16][Temp[4]] 
elseif pointer == 14 then -- 5 [GETGLOBAL] 
 Temp[12] = 4
Temp[11] = 24
Temp[16] = Constants[Temp[11]]
Stack[Temp[12]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 15 then -- 0 [MOVE] 
 Temp[16] = 5
Temp[9] = 0
Stack[Temp[16]] = Stack[Temp[9]] 
elseif pointer == 16 then -- 28 [CALL] 
 	Stack[4](Stack[5]) 
elseif pointer == 17 then -- 5 [GETGLOBAL] 
 Temp[6] = 4
Temp[10] = 24
Temp[15] = Constants[Temp[10]]
Stack[Temp[6]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 18 then -- 0 [MOVE] 
 Temp[10] = 5
Temp[16] = 1
Stack[Temp[10]] = Stack[Temp[16]] 
elseif pointer == 19 then -- 28 [CALL] 
 	Stack[4](Stack[5]) 
elseif pointer == 20 then -- 5 [GETGLOBAL] 
 Temp[4] = 4
Temp[11] = 15
Temp[12] = Constants[Temp[11]]
Stack[Temp[4]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 21 then -- 0 [MOVE] 
 Temp[11] = 5
Temp[4] = 2
Stack[Temp[11]] = Stack[Temp[4]] 
elseif pointer == 22 then -- 28 [CALL] 
 	Stack[4], Stack[5], Stack[6] = Stack[4](Stack[5]) 
elseif pointer == 23 then -- 22 [JMP] 
 pointer = pointer + 10  
elseif pointer == 24 then -- 5 [GETGLOBAL] 
 Temp[14] = 9
Temp[1] = 24
Temp[12] = Constants[Temp[1]]
Stack[Temp[14]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 25 then -- 5 [GETGLOBAL] 
 Temp[13] = 10
Temp[4] = 34
Temp[7] = Constants[Temp[4]]
Stack[Temp[13]] = vmEnv[Temp[7]] or Env[Temp[7]]
	Stack[10] = Stack[10][Constants[11]]
	
	pointer = pointer + 1 
elseif pointer == 27 then -- 0 [MOVE] 
 Temp[10] = 11
Temp[2] = 3
Stack[Temp[10]] = Stack[Temp[2]] 
elseif pointer == 28 then -- 0 [MOVE] 
 Temp[8] = 12
Temp[14] = 7
Stack[Temp[8]] = Stack[Temp[14]] 
elseif pointer == 29 then -- 11 [SELF] 
 	Stack[14] = Stack[8]
	if Stack[14] then
		Stack[13] = Stack[8][Constants[16]]
	end
	 
elseif pointer == 30 then -- 28 [CALL] 
 	Stack[13] = Stack[13](Stack[14]) 
elseif pointer == 31 then -- 20 [LEN] 
 	Stack[14] = #Stack[8] 
elseif pointer == 32 then -- 28 [CALL] 
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
	 
elseif pointer == 33 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 9 + 1, top do
		Temp[1][i - 9] = Stack[i]
	end
	Temp[2] = {Stack[9](unpack(Temp[1], 1, top - 9))}
		for i = 1, 0 do
		Stack[9 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 34 then -- 33 [TFORLOOP] 
     local r1, r2 = Stack[4](Stack[5], Stack[6])
    Stack[7] = r1
        Stack[8] = r2
    if Stack[7] ~= nil then
        Stack[6] = Stack[7]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 35 then -- 22 [JMP] 
 pointer = pointer + -12  
elseif pointer == 36 then -- 5 [GETGLOBAL] 
 Temp[1] = 4
Temp[6] = 24
Temp[14] = Constants[Temp[6]]
Stack[Temp[1]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 37 then -- 0 [MOVE] 
 Temp[5] = 5
Temp[2] = 1
Stack[Temp[5]] = Stack[Temp[2]] 
elseif pointer == 38 then -- 28 [CALL] 
 	Stack[4](Stack[5]) 
elseif pointer == 39 then -- 1 [LOADK] 
 Temp[9] = 4
Temp[4] = Constants
Temp[1] = 13
Stack[Temp[9]] = Temp[4][Temp[1]] 
elseif pointer == 40 then -- 10 [NEWTABLE] 
 	Stack[5] = {} 
elseif pointer == 41 then -- 11 [SELF] 
 	Stack[7] = Stack[4]
	if Stack[7] then
		Stack[6] = Stack[4][Constants[28]]
	end
	 
elseif pointer == 42 then -- 1 [LOADK] 
 Temp[1] = 8
Temp[9] = Constants
Temp[11] = 32
Stack[Temp[1]] = Temp[9][Temp[11]]
	Stack[6], Stack[7], Stack[8] = Stack[6](Stack[7], Stack[8])
	pointer = pointer + 1 
elseif pointer == 44 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 45 then -- 6 [GETTABLE] 
 	Stack[10] = Stack[5][Stack[9]]
	 
elseif pointer == 46 then -- 26 [TEST] 
 	if not Stack[10] then pointer = pointer + 1 end 
elseif pointer == 47 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 48 then -- 1 [LOADK] 
 Temp[16] = 10
Temp[3] = Constants
Temp[11] = 18
Stack[Temp[16]] = Temp[3][Temp[11]] 
elseif pointer == 49 then -- 12 [ADD] 
 	Stack[10] = Stack[10] + Constants[1] 
elseif pointer == 50 then -- 9 [SETTABLE] 
 	Stack[5][Stack[9]] = Stack[10] 
elseif pointer == 51 then -- 33 [TFORLOOP] 
     local r1 = Stack[6](Stack[7], Stack[8])
    Stack[9] = r1
    if Stack[9] ~= nil then
        Stack[8] = Stack[9]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 52 then -- 22 [JMP] 
 pointer = pointer + -8  
elseif pointer == 53 then -- 10 [NEWTABLE] 
 	Stack[6] = {} 
elseif pointer == 54 then -- 5 [GETGLOBAL] 
 Temp[3] = 7
Temp[13] = 20
Temp[6] = Constants[Temp[13]]
Stack[Temp[3]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 55 then -- 0 [MOVE] 
 Temp[14] = 8
Temp[1] = 5
Stack[Temp[14]] = Stack[Temp[1]] 
elseif pointer == 56 then -- 28 [CALL] 
 	Stack[7], Stack[8], Stack[9] = Stack[7](Stack[8]) 
elseif pointer == 57 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 58 then -- 20 [LEN] 
 	Stack[11] = #Stack[6] 
elseif pointer == 59 then -- 12 [ADD] 
 	Stack[11] = Stack[11] + Constants[1] 
elseif pointer == 60 then -- 9 [SETTABLE] 
 	Stack[6][Stack[11]] = Stack[10] 
elseif pointer == 61 then -- 33 [TFORLOOP] 
     local r1 = Stack[7](Stack[8], Stack[9])
    Stack[10] = r1
    if Stack[10] ~= nil then
        Stack[9] = Stack[10]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 62 then -- 22 [JMP] 
 pointer = pointer + -5  
elseif pointer == 63 then -- 5 [GETGLOBAL] 
 Temp[3] = 7
Temp[14] = 31
Temp[12] = Constants[Temp[14]]
Stack[Temp[3]] = vmEnv[Temp[12]] or Env[Temp[12]]
	Stack[7] = Stack[7][Constants[22]]
	
	pointer = pointer + 1 
elseif pointer == 65 then -- 0 [MOVE] 
 Temp[15] = 8
Temp[1] = 6
Stack[Temp[15]] = Stack[Temp[1]] 
elseif pointer == 66 then -- 28 [CALL] 
 	Stack[7](Stack[8]) 
elseif pointer == 67 then -- 10 [NEWTABLE] 
 	Stack[7] = {} 
elseif pointer == 68 then -- 5 [GETGLOBAL] 
 Temp[2] = 8
Temp[9] = 15
Temp[11] = Constants[Temp[9]]
Stack[Temp[2]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 69 then -- 0 [MOVE] 
 Temp[12] = 9
Temp[10] = 6
Stack[Temp[12]] = Stack[Temp[10]] 
elseif pointer == 70 then -- 28 [CALL] 
 	Stack[8], Stack[9], Stack[10] = Stack[8](Stack[9]) 
elseif pointer == 71 then -- 22 [JMP] 
 pointer = pointer + 7  
elseif pointer == 72 then -- 20 [LEN] 
 	Stack[13] = #Stack[7] 
elseif pointer == 73 then -- 12 [ADD] 
 	Stack[13] = Stack[13] + Constants[1] 
elseif pointer == 74 then -- 0 [MOVE] 
 Temp[2] = 14
Temp[10] = 12
Stack[Temp[2]] = Stack[Temp[10]] 
elseif pointer == 75 then -- 1 [LOADK] 
 Temp[10] = 15
Temp[8] = Constants
Temp[14] = 6
Stack[Temp[10]] = Temp[8][Temp[14]] 
elseif pointer == 76 then -- 6 [GETTABLE] 
 	Stack[16] = Stack[5][Stack[12]]
	 
elseif pointer == 77 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 14, 16 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[14] = Temp[1]
	 
elseif pointer == 78 then -- 9 [SETTABLE] 
 	Stack[7][Stack[13]] = Stack[14] 
elseif pointer == 79 then -- 33 [TFORLOOP] 
     local r1, r2 = Stack[8](Stack[9], Stack[10])
    Stack[11] = r1
        Stack[12] = r2
    if Stack[11] ~= nil then
        Stack[10] = Stack[11]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 80 then -- 22 [JMP] 
 pointer = pointer + -9  
elseif pointer == 81 then -- 5 [GETGLOBAL] 
 Temp[9] = 8
Temp[16] = 24
Temp[2] = Constants[Temp[16]]
Stack[Temp[9]] = vmEnv[Temp[2]] or Env[Temp[2]] 
elseif pointer == 82 then -- 5 [GETGLOBAL] 
 Temp[9] = 9
Temp[16] = 31
Temp[11] = Constants[Temp[16]]
Stack[Temp[9]] = vmEnv[Temp[11]] or Env[Temp[11]]
	Stack[9] = Stack[9][Constants[26]]
	
	pointer = pointer + 1 
elseif pointer == 84 then -- 0 [MOVE] 
 Temp[3] = 10
Temp[15] = 7
Stack[Temp[3]] = Stack[Temp[15]] 
elseif pointer == 85 then -- 1 [LOADK] 
 Temp[13] = 11
Temp[14] = Constants
Temp[2] = 2
Stack[Temp[13]] = Temp[14][Temp[2]]
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
elseif pointer == 87 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 8 + 1, top do
		Temp[1][i - 8] = Stack[i]
	end
	Temp[2] = {Stack[8](unpack(Temp[1], 1, top - 8))}
		for i = 1, 0 do
		Stack[8 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 88 then -- 5 [GETGLOBAL] 
 Temp[10] = 8
Temp[3] = 24
Temp[15] = Constants[Temp[3]]
Stack[Temp[10]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 89 then -- 11 [SELF] 
 	Stack[10] = Stack[4]
	if Stack[10] then
		Stack[9] = Stack[4][Constants[27]]
	end
	 
elseif pointer == 90 then -- 28 [CALL] 
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
	 
elseif pointer == 91 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 8 + 1, top do
		Temp[1][i - 8] = Stack[i]
	end
	Temp[2] = {Stack[8](unpack(Temp[1], 1, top - 8))}
		for i = 1, 0 do
		Stack[8 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 92 then -- 5 [GETGLOBAL] 
 Temp[10] = 8
Temp[6] = 24
Temp[13] = Constants[Temp[6]]
Stack[Temp[10]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 93 then -- 11 [SELF] 
 	Stack[10] = Stack[4]
	if Stack[10] then
		Stack[9] = Stack[4][Constants[4]]
	end
	 
elseif pointer == 94 then -- 1 [LOADK] 
 Temp[5] = 11
Temp[4] = Constants
Temp[13] = 7
Stack[Temp[5]] = Temp[4][Temp[13]] 
elseif pointer == 95 then -- 1 [LOADK] 
 Temp[7] = 12
Temp[13] = Constants
Temp[3] = 30
Stack[Temp[7]] = Temp[13][Temp[3]]
	Stack[9] = Stack[9](Stack[10], Stack[11], Stack[12])
	pointer = pointer + 1 
elseif pointer == 97 then -- 28 [CALL] 
 	Stack[8](Stack[9]) 
elseif pointer == 98 then -- 5 [GETGLOBAL] 
 Temp[6] = 8
Temp[9] = 24
Temp[13] = Constants[Temp[9]]
Stack[Temp[6]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 99 then -- 1 [LOADK] 
 Temp[16] = 9
Temp[4] = Constants
Temp[14] = 19
Stack[Temp[16]] = Temp[4][Temp[14]] 
elseif pointer == 100 then -- 11 [SELF] 
 	Stack[10] = Stack[9]
	if Stack[10] then
		Stack[9] = Stack[9][Constants[40]]
	end
	 
elseif pointer == 101 then -- 1 [LOADK] 
 Temp[8] = 11
Temp[4] = Constants
Temp[16] = 42
Stack[Temp[8]] = Temp[4][Temp[16]]
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
elseif pointer == 103 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 8 + 1, top do
		Temp[1][i - 8] = Stack[i]
	end
	Temp[2] = {Stack[8](unpack(Temp[1], 1, top - 8))}
		for i = 1, 0 do
		Stack[8 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 104 then -- 5 [GETGLOBAL] 
 Temp[1] = 8
Temp[3] = 24
Temp[10] = Constants[Temp[3]]
Stack[Temp[1]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 105 then -- 11 [SELF] 
 	Stack[10] = Stack[4]
	if Stack[10] then
		Stack[9] = Stack[4][Constants[41]]
	end
	 
elseif pointer == 106 then -- 1 [LOADK] 
 Temp[4] = 11
Temp[2] = Constants
Temp[6] = 5
Stack[Temp[4]] = Temp[2][Temp[6]] 
elseif pointer == 107 then -- 1 [LOADK] 
 Temp[1] = 12
Temp[4] = Constants
Temp[15] = 35
Stack[Temp[1]] = Temp[4][Temp[15]]
	Stack[9] = Stack[9](Stack[10], Stack[11], Stack[12])
	pointer = pointer + 1 
elseif pointer == 109 then -- 1 [LOADK] 
 Temp[4] = 10
Temp[2] = Constants
Temp[9] = 21
Stack[Temp[4]] = Temp[2][Temp[9]] 
elseif pointer == 110 then -- 11 [SELF] 
 	Stack[12] = Stack[4]
	if Stack[12] then
		Stack[11] = Stack[4][Constants[43]]
	end
	 
elseif pointer == 111 then -- 1 [LOADK] 
 Temp[9] = 13
Temp[14] = Constants
Temp[13] = 10
Stack[Temp[9]] = Temp[14][Temp[13]] 
elseif pointer == 112 then -- 1 [LOADK] 
 Temp[13] = 14
Temp[11] = Constants
Temp[4] = 1
Stack[Temp[13]] = Temp[11][Temp[4]] 
elseif pointer == 113 then -- 2 [LOADBOOL] 
 Temp[9] = 15
Temp[2] = ttostring ~= __metatable
Stack[Temp[9]] = Temp[7] 
elseif pointer == 114 then -- 28 [CALL] 
 	Stack[11] = Stack[11](Stack[12], Stack[13], Stack[14], Stack[15]) 
elseif pointer == 115 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 9, 11 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[9] = Temp[1]
	 
elseif pointer == 116 then -- 28 [CALL] 
 	Stack[8](Stack[9]) 
elseif pointer == 117 then -- 30 [RETURN] 
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