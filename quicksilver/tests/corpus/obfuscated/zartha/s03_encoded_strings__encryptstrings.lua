return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env[decrypt("\066\067\070\090\095\080", "1743")][decrypt("\082\093\087\065", "1563")],Env[decrypt("\066\065\075\089\095\082", "1590")][decrypt("\080\074\069\093", "2318")],Env[decrypt("\066\070\065\095\095\085", "1236")][decrypt("\065\077\082", "2806")],Env[decrypt("\067\088\065\067\069\091\089\080", "772")],Env[decrypt("\065\084\088\093\093", "1791")],Env[decrypt("\069\086\082\094\084", "1702")][decrypt("\071\087\064\084\081\082", "2905")] or Env[decrypt("\065\088\068\085\085\095", "464")],Env[decrypt("\069\084\080\092\084", "1520")][decrypt("\081\086\091\081\083\077", "2952")],Env[decrypt("\070\094\095\068\095\083\084\067", "2111")],Env[decrypt("\066\093\066\091\084\076\087\066\080\090\090\083", "1866")],decrypt("\109\102\092\093\070\088\069\089\080\085\084", "2918"),decrypt("\104\103\094\089\092\082\079", "787"),Env[decrypt("\090\092\065\068\075\089\076\064", "496")],Env[decrypt("\066\075\095\092\070", "2962")],{(decrypt("\105\091\080\110\105", "1871")),(decrypt("\102\095\093\097", "851")),(decrypt("\081\105\084", "853")),(decrypt("\111\095\092\093\106\082", "2959")),(decrypt("\109\107\103\083", "1185")),(decrypt("\111\108\110\092\080\086\105", "536")),(decrypt("\017\062", "956")),(decrypt("\091\086\090\089", "1032")),(decrypt("\084", "2936")),(decrypt("\108\088\082\110", "1875")),(decrypt("\119\084\095\091\090\001\107\111\096\082", "718")),(decrypt("\107\091\111\091\084", "2276")),(decrypt("\094\089\080\084\087\103", "429")),(decrypt("\030\061", "2642")),(decrypt("\086\089\088\084\090", "1081")),(decrypt("\081\086\110\083\088\091", "1163")),(decrypt("\021\063", "2465")),(decrypt("\081\111\084\100\090\083\100", "839")),(decrypt("\088\094\082\104\080", "495")),(decrypt("\099\047\021\029\106\103\037\040\091\036\045\040\106\036\104\107\105\090\088\020", "1324")),(decrypt("\022", "1356")),(decrypt("\009\085\082\080", "1996")),(decrypt("\006\109\083\090\087\019\046\121\092\089\107\082\115\081\083\084\109\089\033", "910")),(decrypt("\027\056", "1335")),(decrypt("\100\112\014\014\126\124\013\011\121\010\012", "2673")),(decrypt("\001\062", "1588")),(decrypt("\085\105\089\092\088", "2195")),(decrypt("\121\104\111\081\008\082\084\083\091", "2475")),(decrypt("\106\109", "2470")),(decrypt("\111\094\095", "2802")),(decrypt("\066", "1322")),(decrypt("\107\085\081\107\105\088", "1341")),(decrypt("\018\017\022\018\017\022\018\017\022\018\017\022\018\017\022\018\017\022\018\017", "652")),(decrypt("\089\111\107\033\090\092\087\108\080\039\110\095\084\094\082\033\111\086\088\033\083\092\083\081\088\039\081\091\110\089\032\093\109\108\032\085\106\065\071\033\105\086\105", "2076")),(decrypt("\045\106", "1299")),(decrypt("\106\107\080\083\105", "1738")),(decrypt("\108\081\105\088\104\106", "2513")),(decrypt("\037", "2156")),(decrypt("\089\110\110\082\110", "2671")),(decrypt("\088\088\109", "2448")),(decrypt("\108\086\092\090\088\086\088", "1031")),(decrypt("\007", "389")),},Env[decrypt("\066\088\095\064\074", "296")],decrypt("\109\102\094\087\078\089\092\093\085\074", "290"),Env[decrypt("\089\082\079\067", "777")],decrypt("\028", "2812"),Env[decrypt("\065\065\067\090\092\082", "2513")][decrypt("\085\075\068\084", "2816")],decrypt("\066\070\066\088\092\087", "120"),Env[decrypt("\065\076\065\080\092\095", "2839")][decrypt("\084\081\090\087", "2843")],Env[decrypt("\066\082\084\090\086", "636")][decrypt("\084\090\093\083", "2337")] or function(targetTable, value)
	for i,v in pairs(targetTable) do
		if v == value then
			return i
		end
	end
	
	return nil
end,Env[decrypt("\080\093\066\007\000", "2464")] and Env[decrypt("\080\091\076\003\000", "2280")][decrypt("\091\072\095\075", "900")] or function(a, b)
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
 Temp[9] = 0
Temp[7] = ttostring ~= __metatable
Stack[Temp[9]] = Temp[16] 
elseif pointer == 2 then -- 7 [SETGLOBAL] 
 Temp[15] = vmEnv
Temp[13] = 25
Temp[16] = Constants[Temp[13]]
Temp[3] = 0
Temp[15][Temp[16]] = Temp[16] 
elseif pointer == 3 then -- 1 [LOADK] 
 Temp[4] = 0
Temp[10] = Constants
Temp[8] = 23
Stack[Temp[4]] = Temp[10][Temp[8]] 
elseif pointer == 4 then -- 1 [LOADK] 
 Temp[1] = 1
Temp[8] = Constants
Temp[12] = 33
Stack[Temp[1]] = Temp[8][Temp[12]] 
elseif pointer == 5 then -- 10 [NEWTABLE] 
 	Stack[2] = {} 
elseif pointer == 6 then -- 1 [LOADK] 
 Temp[5] = 3
Temp[14] = Constants
Temp[11] = 1
Stack[Temp[5]] = Temp[14][Temp[11]] 
elseif pointer == 7 then -- 1 [LOADK] 
 Temp[12] = 4
Temp[5] = Constants
Temp[14] = 12
Stack[Temp[12]] = Temp[5][Temp[14]] 
elseif pointer == 8 then -- 1 [LOADK] 
 Temp[7] = 5
Temp[11] = Constants
Temp[4] = 6
Stack[Temp[7]] = Temp[11][Temp[4]] 
elseif pointer == 9 then -- 1 [LOADK] 
 Temp[6] = 6
Temp[5] = Constants
Temp[1] = 36
Stack[Temp[6]] = Temp[5][Temp[1]] 
elseif pointer == 10 then -- 1 [LOADK] 
 Temp[12] = 7
Temp[7] = Constants
Temp[10] = 5
Stack[Temp[12]] = Temp[7][Temp[10]] 
elseif pointer == 11 then -- 1 [LOADK] 
 Temp[3] = 8
Temp[7] = Constants
Temp[8] = 41
Stack[Temp[3]] = Temp[7][Temp[8]] 
elseif pointer == 12 then -- 34 [SETLIST] 
 	for i = 1, 6 do
		Stack[2][(1 - 1) * 50 + i] = Stack[2 + i]
	end
	 
elseif pointer == 13 then -- 1 [LOADK] 
 Temp[15] = 3
Temp[3] = Constants
Temp[11] = 20
Stack[Temp[15]] = Temp[3][Temp[11]] 
elseif pointer == 14 then -- 5 [GETGLOBAL] 
 Temp[14] = 4
Temp[7] = 15
Temp[4] = Constants[Temp[7]]
Stack[Temp[14]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 15 then -- 0 [MOVE] 
 Temp[8] = 5
Temp[15] = 0
Stack[Temp[8]] = Stack[Temp[15]] 
elseif pointer == 16 then -- 28 [CALL] 
 	Stack[4](Stack[5]) 
elseif pointer == 17 then -- 5 [GETGLOBAL] 
 Temp[5] = 4
Temp[16] = 15
Temp[15] = Constants[Temp[16]]
Stack[Temp[5]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 18 then -- 0 [MOVE] 
 Temp[16] = 5
Temp[4] = 1
Stack[Temp[16]] = Stack[Temp[4]] 
elseif pointer == 19 then -- 28 [CALL] 
 	Stack[4](Stack[5]) 
elseif pointer == 20 then -- 5 [GETGLOBAL] 
 Temp[12] = 4
Temp[11] = 16
Temp[16] = Constants[Temp[11]]
Stack[Temp[12]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 21 then -- 0 [MOVE] 
 Temp[16] = 5
Temp[9] = 2
Stack[Temp[16]] = Stack[Temp[9]] 
elseif pointer == 22 then -- 28 [CALL] 
 	Stack[4], Stack[5], Stack[6] = Stack[4](Stack[5]) 
elseif pointer == 23 then -- 22 [JMP] 
 pointer = pointer + 10  
elseif pointer == 24 then -- 5 [GETGLOBAL] 
 Temp[6] = 9
Temp[10] = 15
Temp[15] = Constants[Temp[10]]
Stack[Temp[6]] = vmEnv[Temp[15]] or Env[Temp[15]] 
elseif pointer == 25 then -- 5 [GETGLOBAL] 
 Temp[10] = 10
Temp[16] = 13
Temp[4] = Constants[Temp[16]]
Stack[Temp[10]] = vmEnv[Temp[4]] or Env[Temp[4]]
	Stack[10] = Stack[10][Constants[4]]
	
	pointer = pointer + 1 
elseif pointer == 27 then -- 0 [MOVE] 
 Temp[11] = 11
Temp[12] = 3
Stack[Temp[11]] = Stack[Temp[12]] 
elseif pointer == 28 then -- 0 [MOVE] 
 Temp[11] = 12
Temp[4] = 7
Stack[Temp[11]] = Stack[Temp[4]] 
elseif pointer == 29 then -- 11 [SELF] 
 	Stack[14] = Stack[8]
	if Stack[14] then
		Stack[13] = Stack[8][Constants[19]]
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
 Temp[14] = 4
Temp[1] = 15
Temp[12] = Constants[Temp[1]]
Stack[Temp[14]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 37 then -- 0 [MOVE] 
 Temp[13] = 5
Temp[4] = 1
Stack[Temp[13]] = Stack[Temp[4]] 
elseif pointer == 38 then -- 28 [CALL] 
 	Stack[4](Stack[5]) 
elseif pointer == 39 then -- 1 [LOADK] 
 Temp[7] = 4
Temp[10] = Constants
Temp[2] = 34
Stack[Temp[7]] = Temp[10][Temp[2]] 
elseif pointer == 40 then -- 10 [NEWTABLE] 
 	Stack[5] = {} 
elseif pointer == 41 then -- 11 [SELF] 
 	Stack[7] = Stack[4]
	if Stack[7] then
		Stack[6] = Stack[4][Constants[37]]
	end
	 
elseif pointer == 42 then -- 1 [LOADK] 
 Temp[8] = 8
Temp[14] = Constants
Temp[1] = 35
Stack[Temp[8]] = Temp[14][Temp[1]]
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
 Temp[6] = 10
Temp[14] = Constants
Temp[5] = 17
Stack[Temp[6]] = Temp[14][Temp[5]] 
elseif pointer == 49 then -- 12 [ADD] 
 	Stack[10] = Stack[10] + Constants[7] 
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
 Temp[2] = 7
Temp[9] = 27
Temp[4] = Constants[Temp[9]]
Stack[Temp[2]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 55 then -- 0 [MOVE] 
 Temp[1] = 8
Temp[9] = 5
Stack[Temp[1]] = Stack[Temp[9]] 
elseif pointer == 56 then -- 28 [CALL] 
 	Stack[7], Stack[8], Stack[9] = Stack[7](Stack[8]) 
elseif pointer == 57 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 58 then -- 20 [LEN] 
 	Stack[11] = #Stack[6] 
elseif pointer == 59 then -- 12 [ADD] 
 	Stack[11] = Stack[11] + Constants[7] 
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
 Temp[11] = 7
Temp[16] = 39
Temp[3] = Constants[Temp[16]]
Stack[Temp[11]] = vmEnv[Temp[3]] or Env[Temp[3]]
	Stack[7] = Stack[7][Constants[8]]
	
	pointer = pointer + 1 
elseif pointer == 65 then -- 0 [MOVE] 
 Temp[11] = 8
Temp[3] = 6
Stack[Temp[11]] = Stack[Temp[3]] 
elseif pointer == 66 then -- 28 [CALL] 
 	Stack[7](Stack[8]) 
elseif pointer == 67 then -- 10 [NEWTABLE] 
 	Stack[7] = {} 
elseif pointer == 68 then -- 5 [GETGLOBAL] 
 Temp[13] = 8
Temp[6] = 16
Temp[14] = Constants[Temp[6]]
Stack[Temp[13]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 69 then -- 0 [MOVE] 
 Temp[1] = 9
Temp[3] = 6
Stack[Temp[1]] = Stack[Temp[3]] 
elseif pointer == 70 then -- 28 [CALL] 
 	Stack[8], Stack[9], Stack[10] = Stack[8](Stack[9]) 
elseif pointer == 71 then -- 22 [JMP] 
 pointer = pointer + 7  
elseif pointer == 72 then -- 20 [LEN] 
 	Stack[13] = #Stack[7] 
elseif pointer == 73 then -- 12 [ADD] 
 	Stack[13] = Stack[13] + Constants[7] 
elseif pointer == 74 then -- 0 [MOVE] 
 Temp[14] = 14
Temp[12] = 12
Stack[Temp[14]] = Stack[Temp[12]] 
elseif pointer == 75 then -- 1 [LOADK] 
 Temp[15] = 15
Temp[1] = Constants
Temp[2] = 42
Stack[Temp[15]] = Temp[1][Temp[2]] 
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
Temp[11] = 15
Temp[12] = Constants[Temp[11]]
Stack[Temp[9]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 82 then -- 5 [GETGLOBAL] 
 Temp[10] = 9
Temp[2] = 39
Temp[8] = Constants[Temp[2]]
Stack[Temp[10]] = vmEnv[Temp[8]] or Env[Temp[8]]
	Stack[9] = Stack[9][Constants[32]]
	
	pointer = pointer + 1 
elseif pointer == 84 then -- 0 [MOVE] 
 Temp[8] = 10
Temp[14] = 7
Stack[Temp[8]] = Stack[Temp[14]] 
elseif pointer == 85 then -- 1 [LOADK] 
 Temp[9] = 11
Temp[16] = Constants
Temp[2] = 38
Stack[Temp[9]] = Temp[16][Temp[2]]
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
 Temp[9] = 8
Temp[16] = 15
Temp[11] = Constants[Temp[16]]
Stack[Temp[9]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 89 then -- 11 [SELF] 
 	Stack[10] = Stack[4]
	if Stack[10] then
		Stack[9] = Stack[4][Constants[18]]
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
 Temp[3] = 8
Temp[15] = 15
Temp[13] = Constants[Temp[15]]
Stack[Temp[3]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 93 then -- 11 [SELF] 
 	Stack[10] = Stack[4]
	if Stack[10] then
		Stack[9] = Stack[4][Constants[2]]
	end
	 
elseif pointer == 94 then -- 1 [LOADK] 
 Temp[14] = 11
Temp[2] = Constants
Temp[10] = 9
Stack[Temp[14]] = Temp[2][Temp[10]] 
elseif pointer == 95 then -- 1 [LOADK] 
 Temp[3] = 12
Temp[15] = Constants
Temp[10] = 21
Stack[Temp[3]] = Temp[15][Temp[10]]
	Stack[9] = Stack[9](Stack[10], Stack[11], Stack[12])
	pointer = pointer + 1 
elseif pointer == 97 then -- 28 [CALL] 
 	Stack[8](Stack[9]) 
elseif pointer == 98 then -- 5 [GETGLOBAL] 
 Temp[6] = 8
Temp[13] = 15
Temp[5] = Constants[Temp[13]]
Stack[Temp[6]] = vmEnv[Temp[5]] or Env[Temp[5]] 
elseif pointer == 99 then -- 1 [LOADK] 
 Temp[4] = 9
Temp[13] = Constants
Temp[7] = 29
Stack[Temp[4]] = Temp[13][Temp[7]] 
elseif pointer == 100 then -- 11 [SELF] 
 	Stack[10] = Stack[9]
	if Stack[10] then
		Stack[9] = Stack[9][Constants[3]]
	end
	 
elseif pointer == 101 then -- 1 [LOADK] 
 Temp[13] = 11
Temp[7] = Constants
Temp[3] = 24
Stack[Temp[13]] = Temp[7][Temp[3]]
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
 Temp[6] = 8
Temp[9] = 15
Temp[13] = Constants[Temp[9]]
Stack[Temp[6]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 105 then -- 11 [SELF] 
 	Stack[10] = Stack[4]
	if Stack[10] then
		Stack[9] = Stack[4][Constants[40]]
	end
	 
elseif pointer == 106 then -- 1 [LOADK] 
 Temp[16] = 11
Temp[4] = Constants
Temp[14] = 14
Stack[Temp[16]] = Temp[4][Temp[14]] 
elseif pointer == 107 then -- 1 [LOADK] 
 Temp[8] = 12
Temp[4] = Constants
Temp[16] = 26
Stack[Temp[8]] = Temp[4][Temp[16]]
	Stack[9] = Stack[9](Stack[10], Stack[11], Stack[12])
	pointer = pointer + 1 
elseif pointer == 109 then -- 1 [LOADK] 
 Temp[1] = 10
Temp[3] = Constants
Temp[10] = 31
Stack[Temp[1]] = Temp[3][Temp[10]] 
elseif pointer == 110 then -- 11 [SELF] 
 	Stack[12] = Stack[4]
	if Stack[12] then
		Stack[11] = Stack[4][Constants[10]]
	end
	 
elseif pointer == 111 then -- 1 [LOADK] 
 Temp[4] = 13
Temp[2] = Constants
Temp[6] = 30
Stack[Temp[4]] = Temp[2][Temp[6]] 
elseif pointer == 112 then -- 1 [LOADK] 
 Temp[1] = 14
Temp[4] = Constants
Temp[15] = 7
Stack[Temp[1]] = Temp[4][Temp[15]] 
elseif pointer == 113 then -- 2 [LOADBOOL] 
 Temp[4] = 15
Temp[2] = ttostring ~= __metatable
Stack[Temp[4]] = Temp[9] 
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