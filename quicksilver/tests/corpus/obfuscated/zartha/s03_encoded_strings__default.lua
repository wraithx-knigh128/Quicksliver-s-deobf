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
				if pointer == 1 then -- 2 [LOADBOOL] 
 Temp[2] = 0
Temp[15] = ttostring ~= __metatable
Stack[Temp[2]] = Temp[6] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[6] = vmEnv
Temp[14] = 11
Temp[5] = Constants[Temp[14]]
Temp[3] = 0
Temp[6][Temp[5]] = Temp[5] 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[7] = 0
Temp[11] = Constants
Temp[5] = 36
Stack[Temp[7]] = Temp[11][Temp[5]] 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[7] = 1
Temp[15] = Constants
Temp[9] = 38
Stack[Temp[7]] = Temp[15][Temp[9]] 
elseif pointer == 5 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 6 then -- 1 [LOADK] 
 Temp[12] = 3
Temp[14] = Constants
Temp[15] = 8
Stack[Temp[12]] = Temp[14][Temp[15]] 
elseif pointer == 7 then -- 1 [LOADK] 
 Temp[7] = 4
Temp[4] = Constants
Temp[11] = 35
Stack[Temp[7]] = Temp[4][Temp[11]] 
elseif pointer == 8 then -- 1 [LOADK] 
 Temp[7] = 5
Temp[10] = Constants
Temp[14] = 24
Stack[Temp[7]] = Temp[10][Temp[14]] 
elseif pointer == 9 then -- 1 [LOADK] 
 Temp[12] = 6
Temp[15] = Constants
Temp[13] = 13
Stack[Temp[12]] = Temp[15][Temp[13]] 
elseif pointer == 10 then -- 1 [LOADK] 
 Temp[6] = 7
Temp[2] = Constants
Temp[9] = 40
Stack[Temp[6]] = Temp[2][Temp[9]] 
elseif pointer == 11 then -- 1 [LOADK] 
 Temp[7] = 8
Temp[16] = Constants
Temp[15] = 28
Stack[Temp[7]] = Temp[16][Temp[15]] 
elseif pointer == 12 then -- 34 [SETLIST] 
 	for i = 1, 6 do
		Stack[2][(1 - 1) * 50 + i] = Stack[2 + i]
	end
	 
elseif pointer == 13 then -- 1 [LOADK] 
 Temp[13] = 3
Temp[3] = Constants
Temp[16] = 23
Stack[Temp[13]] = Temp[3][Temp[16]] 
elseif pointer == 14 then -- 5 [GETGLOBAL] 
 Temp[4] = 4
Temp[10] = 14
Temp[8] = Constants[Temp[10]]
Stack[Temp[4]] = vmEnv[Temp[8]] or Env[Temp[8]] 
elseif pointer == 15 then -- 0 [MOVE] 
 Temp[1] = 5
Temp[8] = 0
Stack[Temp[1]] = Stack[Temp[8]] 
elseif pointer == 16 then -- 28 [CALL] 
 	Stack[4](Stack[5]) 
elseif pointer == 17 then -- 5 [GETGLOBAL] 
 Temp[1] = 4
Temp[12] = 14
Temp[5] = Constants[Temp[12]]
Stack[Temp[1]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 18 then -- 0 [MOVE] 
 Temp[14] = 5
Temp[11] = 1
Stack[Temp[14]] = Stack[Temp[11]] 
elseif pointer == 19 then -- 28 [CALL] 
 	Stack[4](Stack[5]) 
elseif pointer == 20 then -- 5 [GETGLOBAL] 
 Temp[12] = 4
Temp[5] = 27
Temp[14] = Constants[Temp[5]]
Stack[Temp[12]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 21 then -- 0 [MOVE] 
 Temp[7] = 5
Temp[11] = 2
Stack[Temp[7]] = Stack[Temp[11]] 
elseif pointer == 22 then -- 28 [CALL] 
 	Stack[4], Stack[5], Stack[6] = Stack[4](Stack[5]) 
elseif pointer == 23 then -- 22 [JMP] 
 pointer = pointer + 10  
elseif pointer == 24 then -- 5 [GETGLOBAL] 
 Temp[7] = 9
Temp[4] = 14
Temp[6] = Constants[Temp[4]]
Stack[Temp[7]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 25 then -- 5 [GETGLOBAL] 
 Temp[5] = 10
Temp[1] = 10
Temp[12] = Constants[Temp[1]]
Stack[Temp[5]] = vmEnv[Temp[12]] or Env[Temp[12]]
	Stack[10] = Stack[10][Constants[15]]
	
	pointer = pointer + 1 
elseif pointer == 27 then -- 0 [MOVE] 
 Temp[7] = 11
Temp[10] = 3
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 28 then -- 0 [MOVE] 
 Temp[3] = 12
Temp[7] = 7
Stack[Temp[3]] = Stack[Temp[7]] 
elseif pointer == 29 then -- 11 [SELF] 
 	Stack[14] = Stack[8]
	if Stack[14] then
		Stack[13] = Stack[8][Constants[12]]
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
 Temp[8] = 4
Temp[15] = 14
Temp[3] = Constants[Temp[15]]
Stack[Temp[8]] = vmEnv[Temp[3]] or Env[Temp[3]] 
elseif pointer == 37 then -- 0 [MOVE] 
 Temp[11] = 5
Temp[14] = 1
Stack[Temp[11]] = Stack[Temp[14]] 
elseif pointer == 38 then -- 28 [CALL] 
 	Stack[4](Stack[5]) 
elseif pointer == 39 then -- 1 [LOADK] 
 Temp[7] = 4
Temp[4] = Constants
Temp[8] = 3
Stack[Temp[7]] = Temp[4][Temp[8]] 
elseif pointer == 40 then -- 10 [NEWTABLE] 
 	Stack[5] = {} 
elseif pointer == 41 then -- 11 [SELF] 
 	Stack[7] = Stack[4]
	if Stack[7] then
		Stack[6] = Stack[4][Constants[33]]
	end
	 
elseif pointer == 42 then -- 1 [LOADK] 
 Temp[15] = 8
Temp[5] = Constants
Temp[16] = 31
Stack[Temp[15]] = Temp[5][Temp[16]]
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
 Temp[15] = 10
Temp[16] = Constants
Temp[4] = 1
Stack[Temp[15]] = Temp[16][Temp[4]] 
elseif pointer == 49 then -- 12 [ADD] 
 	Stack[10] = Stack[10] + Constants[30] 
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
 Temp[12] = 7
Temp[11] = 18
Temp[16] = Constants[Temp[11]]
Stack[Temp[12]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 55 then -- 0 [MOVE] 
 Temp[16] = 8
Temp[9] = 5
Stack[Temp[16]] = Stack[Temp[9]] 
elseif pointer == 56 then -- 28 [CALL] 
 	Stack[7], Stack[8], Stack[9] = Stack[7](Stack[8]) 
elseif pointer == 57 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 58 then -- 20 [LEN] 
 	Stack[11] = #Stack[6] 
elseif pointer == 59 then -- 12 [ADD] 
 	Stack[11] = Stack[11] + Constants[30] 
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
 Temp[6] = 7
Temp[10] = 21
Temp[15] = Constants[Temp[10]]
Stack[Temp[6]] = vmEnv[Temp[15]] or Env[Temp[15]]
	Stack[7] = Stack[7][Constants[6]]
	
	pointer = pointer + 1 
elseif pointer == 65 then -- 0 [MOVE] 
 Temp[10] = 8
Temp[16] = 6
Stack[Temp[10]] = Stack[Temp[16]] 
elseif pointer == 66 then -- 28 [CALL] 
 	Stack[7](Stack[8]) 
elseif pointer == 67 then -- 10 [NEWTABLE] 
 	Stack[7] = {} 
elseif pointer == 68 then -- 5 [GETGLOBAL] 
 Temp[4] = 8
Temp[11] = 27
Temp[12] = Constants[Temp[11]]
Stack[Temp[4]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 69 then -- 0 [MOVE] 
 Temp[11] = 9
Temp[4] = 6
Stack[Temp[11]] = Stack[Temp[4]] 
elseif pointer == 70 then -- 28 [CALL] 
 	Stack[8], Stack[9], Stack[10] = Stack[8](Stack[9]) 
elseif pointer == 71 then -- 22 [JMP] 
 pointer = pointer + 7  
elseif pointer == 72 then -- 20 [LEN] 
 	Stack[13] = #Stack[7] 
elseif pointer == 73 then -- 12 [ADD] 
 	Stack[13] = Stack[13] + Constants[30] 
elseif pointer == 74 then -- 0 [MOVE] 
 Temp[14] = 14
Temp[1] = 12
Stack[Temp[14]] = Stack[Temp[1]] 
elseif pointer == 75 then -- 1 [LOADK] 
 Temp[12] = 15
Temp[13] = Constants
Temp[4] = 25
Stack[Temp[12]] = Temp[13][Temp[4]] 
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
 Temp[7] = 8
Temp[10] = 14
Temp[2] = Constants[Temp[10]]
Stack[Temp[7]] = vmEnv[Temp[2]] or Env[Temp[2]] 
elseif pointer == 82 then -- 5 [GETGLOBAL] 
 Temp[8] = 9
Temp[14] = 21
Temp[1] = Constants[Temp[14]]
Stack[Temp[8]] = vmEnv[Temp[1]] or Env[Temp[1]]
	Stack[9] = Stack[9][Constants[2]]
	
	pointer = pointer + 1 
elseif pointer == 84 then -- 0 [MOVE] 
 Temp[6] = 10
Temp[14] = 7
Stack[Temp[6]] = Stack[Temp[14]] 
elseif pointer == 85 then -- 1 [LOADK] 
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
 Temp[4] = 8
Temp[1] = 14
Temp[9] = Constants[Temp[1]]
Stack[Temp[4]] = vmEnv[Temp[9]] or Env[Temp[9]] 
elseif pointer == 89 then -- 11 [SELF] 
 	Stack[10] = Stack[4]
	if Stack[10] then
		Stack[9] = Stack[4][Constants[4]]
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
 Temp[11] = 8
Temp[16] = 14
Temp[3] = Constants[Temp[16]]
Stack[Temp[11]] = vmEnv[Temp[3]] or Env[Temp[3]] 
elseif pointer == 93 then -- 11 [SELF] 
 	Stack[10] = Stack[4]
	if Stack[10] then
		Stack[9] = Stack[4][Constants[7]]
	end
	 
elseif pointer == 94 then -- 1 [LOADK] 
 Temp[11] = 11
Temp[3] = Constants
Temp[13] = 29
Stack[Temp[11]] = Temp[3][Temp[13]] 
elseif pointer == 95 then -- 1 [LOADK] 
 Temp[6] = 12
Temp[14] = Constants
Temp[1] = 19
Stack[Temp[6]] = Temp[14][Temp[1]]
	Stack[9] = Stack[9](Stack[10], Stack[11], Stack[12])
	pointer = pointer + 1 
elseif pointer == 97 then -- 28 [CALL] 
 	Stack[8](Stack[9]) 
elseif pointer == 98 then -- 5 [GETGLOBAL] 
 Temp[3] = 8
Temp[14] = 14
Temp[12] = Constants[Temp[14]]
Stack[Temp[3]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 99 then -- 1 [LOADK] 
 Temp[15] = 9
Temp[1] = Constants
Temp[2] = 39
Stack[Temp[15]] = Temp[1][Temp[2]] 
elseif pointer == 100 then -- 11 [SELF] 
 	Stack[10] = Stack[9]
	if Stack[10] then
		Stack[9] = Stack[9][Constants[41]]
	end
	 
elseif pointer == 101 then -- 1 [LOADK] 
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
 Temp[10] = 8
Temp[2] = 14
Temp[8] = Constants[Temp[2]]
Stack[Temp[10]] = vmEnv[Temp[8]] or Env[Temp[8]] 
elseif pointer == 105 then -- 11 [SELF] 
 	Stack[10] = Stack[4]
	if Stack[10] then
		Stack[9] = Stack[4][Constants[5]]
	end
	 
elseif pointer == 106 then -- 1 [LOADK] 
 Temp[8] = 11
Temp[14] = Constants
Temp[9] = 34
Stack[Temp[8]] = Temp[14][Temp[9]] 
elseif pointer == 107 then -- 1 [LOADK] 
 Temp[16] = 12
Temp[2] = Constants
Temp[9] = 20
Stack[Temp[16]] = Temp[2][Temp[9]]
	Stack[9] = Stack[9](Stack[10], Stack[11], Stack[12])
	pointer = pointer + 1 
elseif pointer == 109 then -- 1 [LOADK] 
 Temp[16] = 10
Temp[11] = Constants
Temp[3] = 42
Stack[Temp[16]] = Temp[11][Temp[3]] 
elseif pointer == 110 then -- 11 [SELF] 
 	Stack[12] = Stack[4]
	if Stack[12] then
		Stack[11] = Stack[4][Constants[9]]
	end
	 
elseif pointer == 111 then -- 1 [LOADK] 
 Temp[15] = 13
Temp[13] = Constants
Temp[14] = 37
Stack[Temp[15]] = Temp[13][Temp[14]] 
elseif pointer == 112 then -- 1 [LOADK] 
 Temp[2] = 14
Temp[10] = Constants
Temp[3] = 30
Stack[Temp[2]] = Temp[10][Temp[3]] 
elseif pointer == 113 then -- 2 [LOADBOOL] 
 Temp[15] = 15
Temp[10] = ttostring ~= __metatable
Stack[Temp[15]] = Temp[6] 
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