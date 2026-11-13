return (("File generated using [Zartha]") and (function() return(function(Env,Constants,shiftKey,decrypt) -- Vars
local char,byte,sub,ttostring,pcall,unpack,concat,tonumber,setmeta,__metatable,__index,proxy,pnt,EncryptedConstants,pairs,__newindex,next,dot,gsub,stringv,find,tfind,bxor = Env["string"]["char"],Env["string"]["byte"],Env["string"]["sub"],Env["tostring"],Env["pcall"],Env["table"]["unpack"] or Env["unpack"],Env["table"]["concat"],Env["tonumber"],Env["setmetatable"],"__metatable","__index",Env["newproxy"],Env["print"],{(decrypt("\045\109", "1555")),(decrypt("\100\102\089\085\088\091\091\083\087\110", "2023")),(decrypt("\107\094\085\111\105\083", "1805")),(decrypt("\110\101\084\093\104\104\087", "834")),(decrypt("\107\081\106\094\084", "2823")),(decrypt("\088\091\108", "2759")),(decrypt("\085\090\083\087\089", "2332")),(decrypt("\099\036\018\016\106\108\034\037\091\047\042\037\106\047\111\102\105\081\095\025", "1859")),(decrypt("\092\087\094\093", "617")),(decrypt("\111\092\092\104", "1601")),(decrypt("\025\018\051", "2587")),(decrypt("\111\089\082\098", "2979")),(decrypt("\097\097\086\092\107\095", "776")),(decrypt("\111\084\095\104\111", "778")),(decrypt("\101\111\102\095", "959")),(decrypt("\089\094\085\095\086\097\108\090", "2803")),(decrypt("\094\098\105\090\091", "981")),(decrypt("\097\118\014\010\124\125\013\008\124\011\011", "707")),(decrypt("\081\095\108\087\088\082", "1847")),(decrypt("\014\100\084\082\087\027\032\121\093\088\109\083\123\088\084\092\109\081\047", "1871")),(decrypt("\121\089\085\095\085\084\102", "851")),(decrypt("\082\094\090\088\080\109", "853")),(decrypt("\024\050", "2959")),(decrypt("\045\106\026", "1185")),(decrypt("\095\111\093\081\111\093\109\088\110\108\080\106", "536")),(decrypt("\030", "956")),(decrypt("\001\059", "1032")),(decrypt("\123\095\080\085", "2936")),(decrypt("\066", "1875")),(decrypt("\111\104", "718")),(decrypt("\110\091\094\080\091", "2276")),(decrypt("\095\106\096\087\110", "429")),(decrypt("\089\105\104\037\090\090\084\104\080\033\109\091\084\088\081\037\111\080\091\037\083\090\080\085\088\033\082\095\110\095\035\089\109\106\035\081\106\071\068\037\105\080\106", "2642")),(decrypt("\106\108\091\090\105", "1081")),(decrypt("\025\058", "1163")),(decrypt("\086\108\093\111\109", "2465")),(decrypt("\012", "839")),(decrypt("\035", "495")),(decrypt("\093\084\085\104\088", "1324")),(decrypt("\087", "1356")),(decrypt("\014\101\097\095\090\096\101\110\090", "1996")),(decrypt("\029\021\020\029\021\020\029\021\020\029\021\020\029\021\020\029\021\020\029\021", "910")),(decrypt("\022\056", "1335")),(decrypt("\091\106\080", "2673")),(decrypt("\103\099\092\100\090\109\083\096\104\086\100", "1588")),(decrypt("\030\058", "2195")),(decrypt("\091\104\090\105\091\094\107", "2475")),(decrypt("\111\082\088", "2470")),(decrypt("\108\092\104\089\104\103", "2802")),(decrypt("\108\085\093\089\088\085\089", "1322")),(decrypt("\107\108\108\088\082\083\104", "1341")),(decrypt("\107\083\091\082\109\089", "652")),(decrypt("\121\104\083\081\110\089\032\109\110\091\107\108\089\108\108", "2076")),(decrypt("\086\106\089\080\091", "1299")),(decrypt("\014\107\092", "1738")),},Env["pairs"],"__newindex",Env["next"],".",Env["string"]["gsub"],"string",Env["string"]["find"],Env["table"]["find"] or function(targetTable, value)
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
 Temp[14] = 0
Temp[12] = byte == pairs
Stack[Temp[14]] = Temp[15] 
elseif pointer == 2 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[1] then
		C1 = {}
		local encoded = {(decrypt("\118\101\081\105\110\080\095\111\082\094\126\064\085\101", "2950")),(decrypt("\100\003\124\012\120\006", "2954")),(decrypt("\009\014\115\012\121\014", "2200")),(decrypt("\121\108\091\109\085\086\081\090\120\108\081\092\082\106\100", "2081")),(decrypt("\118\096\102\110\093\083\106", "288")),}

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
		if pointer == 1 then -- 2 [LOADBOOL] 
 Temp[16] = 0
Temp[6] = ttostring ~= __metatable
Stack[Temp[16]] = Temp[7] 
elseif pointer == 2 then -- 8 [SETUPVAL] 
 	Upvalues[0] = Stack[0] 
elseif pointer == 3 then -- INVALID [INVALID] 
 --INVALID OPCODE (EMPTY) 
elseif pointer == 4 then -- _CRASH [_CRASH] 
 		pointer = pointer + 40^10
	 
elseif pointer == 5 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 4 then -- 5 [GETGLOBAL] 
 Temp[13] = 2
Temp[6] = 25
Temp[2] = Constants[Temp[6]]
Stack[Temp[13]] = vmEnv[Temp[2]] or Env[Temp[2]] 
elseif pointer == 5 then -- 10 [NEWTABLE] 
 	Stack[3] = {} 
elseif pointer == 6 then -- 10 [NEWTABLE] 
 	Stack[4] = {} 
elseif pointer == 7 then -- 9 [SETTABLE] 
 	Stack[4][Constants[2]] = Stack[1] 
elseif pointer == 8 then -- 9 [SETTABLE] 
 	Stack[4][Constants[13]] = Stack[1] 
elseif pointer == 9 then -- 9 [SETTABLE] 
 	Stack[4][Constants[4]] = Stack[1] 
elseif pointer == 10 then -- 9 [SETTABLE] 
 	Stack[4][Constants[45]] = Constants[35] 
elseif pointer == 11 then -- 28 [CALL] 
 	Stack[2] = Stack[2](Stack[3], Stack[4]) 
elseif pointer == 12 then -- 5 [GETGLOBAL] 
 Temp[9] = 3
Temp[7] = 17
Temp[16] = Constants[Temp[7]]
Stack[Temp[9]] = vmEnv[Temp[16]] or Env[Temp[16]] 
elseif pointer == 13 then -- 5 [GETGLOBAL] 
 Temp[15] = 4
Temp[13] = 17
Temp[3] = Constants[Temp[13]]
Stack[Temp[15]] = vmEnv[Temp[3]] or Env[Temp[3]] 
elseif pointer == 14 then -- 0 [MOVE] 
 Temp[16] = 5
Temp[4] = 2
Stack[Temp[16]] = Stack[Temp[4]] 
elseif pointer == 15 then -- 0 [MOVE] 
 Temp[10] = 6
Temp[8] = 2
Stack[Temp[10]] = Stack[Temp[8]] 
elseif pointer == 16 then -- 28 [CALL] 
 	Stack[3](Stack[4], Stack[5], Stack[6]) 
elseif pointer == 17 then -- 5 [GETGLOBAL] 
 Temp[1] = 3
Temp[8] = 17
Temp[12] = Constants[Temp[8]]
Stack[Temp[1]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 18 then -- 5 [GETGLOBAL] 
 Temp[5] = 4
Temp[14] = 16
Temp[11] = Constants[Temp[14]]
Stack[Temp[5]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 19 then -- 0 [MOVE] 
 Temp[12] = 5
Temp[5] = 2
Stack[Temp[12]] = Stack[Temp[5]] 
elseif pointer == 20 then -- 28 [CALL] 
 	Stack[3](Stack[4], Stack[5]) 
elseif pointer == 21 then -- 5 [GETGLOBAL] 
 Temp[14] = 3
Temp[7] = 17
Temp[11] = Constants[Temp[7]]
Stack[Temp[14]] = vmEnv[Temp[11]] or Env[Temp[11]] 
elseif pointer == 22 then -- 36 [CLOSURE] 
 	local prevStack = Stack
	local prevUpvalues = Upvalues
	local C1

	if not ProtosConstants[2] then
		C1 = {}
		local encoded = {(decrypt("\010\109\065\094", "1514")),(decrypt("\126\086\107\073\105\090\112\105\087\095\088\083\092\107", "953")),(decrypt("\011\097\092\009\087\090\090\083\106\101", "1993")),(decrypt("\082\106\088\082\086\084\093\096", "862")),(decrypt("\118\082\084\088\110", "2482")),(decrypt("\106\097\025", "2937")),}

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
		if pointer == 1 then -- 5 [GETGLOBAL] 
 Temp[11] = 0
Temp[9] = 6
Temp[4] = Constants[Temp[9]]
Stack[Temp[11]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 2 then -- 28 [CALL] 
 	Stack[0]() 
elseif pointer == 3 then -- 30 [RETURN] 
 	return 
end
		pointer = pointer+1
		end
	end
 
elseif pointer == 23 then -- 28 [CALL] 
 	Stack[3], Stack[4] = Stack[3](Stack[4]) 
elseif pointer == 24 then -- 26 [TEST] 
 	if not Stack[0] then pointer = pointer + 1 end 
elseif pointer == 25 then -- 22 [JMP] 
 pointer = pointer + 7  
elseif pointer == 26 then -- 5 [GETGLOBAL] 
 Temp[7] = 5
Temp[4] = 16
Temp[6] = Constants[Temp[4]]
Stack[Temp[7]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 27 then -- 11 [SELF] 
 	Stack[7] = Stack[4]
	if Stack[7] then
		Stack[6] = Stack[4][Constants[36]]
	end
	 
elseif pointer == 28 then -- 1 [LOADK] 
 Temp[5] = 8
Temp[1] = Constants
Temp[12] = 24
Stack[Temp[5]] = Temp[1][Temp[12]]
	Temp[2] = {Stack[6](Stack[7], Stack[8])}
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
elseif pointer == 30 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 5 + 1, top do
		Temp[1][i - 5] = Stack[i]
	end
	Temp[2] = {Stack[5](unpack(Temp[1], 1, top - 5))}
		for i = 1, 1 do
		Stack[5 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 31 then -- 24 [LT] 
 	if Constants[11] < Stack[5] then pointer = pointer + 1 end 
elseif pointer == 32 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 33 then -- 0 [MOVE] 
 Temp[7] = 5
Temp[10] = 1
Stack[Temp[7]] = Stack[Temp[10]] 
elseif pointer == 34 then -- 28 [CALL] 
 	Stack[5]() 
elseif pointer == 35 then -- 5 [GETGLOBAL] 
 Temp[3] = 5
Temp[7] = 31
Temp[8] = Constants[Temp[7]]
Stack[Temp[3]] = vmEnv[Temp[8]] or Env[Temp[8]] 
elseif pointer == 36 then -- 1 [LOADK] 
 Temp[15] = 6
Temp[3] = Constants
Temp[11] = 53
Stack[Temp[15]] = Temp[3][Temp[11]] 
elseif pointer == 37 then -- 29 [TAILCALL] 
 	return Stack[5](Stack[6]) 
elseif pointer == 38 then -- 30 [RETURN] 
             Temp[1] = {}
            Temp[2] = 0
            for i = 5, top do
                Temp[2] = Temp[2] + 1
                Temp[1][Temp[2]] = Stack[i]
            end
            return unpack(Temp[1], 1, Temp[2])
         
elseif pointer == 39 then -- 2 [LOADBOOL] 
 Temp[14] = 5
Temp[7] = ttostring ~= __metatable
Stack[Temp[14]] = Temp[4] 
elseif pointer == 40 then -- 7 [SETGLOBAL] 
 Temp[8] = vmEnv
Temp[15] = 18
Temp[5] = Constants[Temp[15]]
Temp[16] = 5
Temp[8][Temp[5]] = Temp[5] 
elseif pointer == 41 then -- 1 [LOADK] 
 Temp[15] = 5
Temp[16] = Constants
Temp[4] = 20
Stack[Temp[15]] = Temp[16][Temp[4]] 
elseif pointer == 42 then -- 1 [LOADK] 
 Temp[12] = 6
Temp[11] = Constants
Temp[16] = 42
Stack[Temp[12]] = Temp[11][Temp[16]] 
elseif pointer == 43 then -- 10 [NEWTABLE] 
 	Stack[7] = {} 
elseif pointer == 44 then -- 1 [LOADK] 
 Temp[16] = 8
Temp[9] = Constants
Temp[6] = 14
Stack[Temp[16]] = Temp[9][Temp[6]] 
elseif pointer == 45 then -- 1 [LOADK] 
 Temp[10] = 9
Temp[15] = Constants
Temp[16] = 5
Stack[Temp[10]] = Temp[15][Temp[16]] 
elseif pointer == 46 then -- 1 [LOADK] 
 Temp[4] = 10
Temp[11] = Constants
Temp[12] = 51
Stack[Temp[4]] = Temp[11][Temp[12]] 
elseif pointer == 47 then -- 1 [LOADK] 
 Temp[11] = 11
Temp[4] = Constants
Temp[14] = 34
Stack[Temp[11]] = Temp[4][Temp[14]] 
elseif pointer == 48 then -- 1 [LOADK] 
 Temp[1] = 12
Temp[12] = Constants
Temp[13] = 15
Stack[Temp[1]] = Temp[12][Temp[13]] 
elseif pointer == 49 then -- 1 [LOADK] 
 Temp[4] = 13
Temp[7] = Constants
Temp[10] = 50
Stack[Temp[4]] = Temp[7][Temp[10]] 
elseif pointer == 50 then -- 34 [SETLIST] 
 	for i = 1, 6 do
		Stack[7][(1 - 1) * 50 + i] = Stack[7 + i]
	end
	 
elseif pointer == 51 then -- 1 [LOADK] 
 Temp[10] = 8
Temp[2] = Constants
Temp[8] = 8
Stack[Temp[10]] = Temp[2][Temp[8]] 
elseif pointer == 52 then -- 5 [GETGLOBAL] 
 Temp[14] = 9
Temp[1] = 7
Temp[6] = Constants[Temp[1]]
Stack[Temp[14]] = vmEnv[Temp[6]] or Env[Temp[6]] 
elseif pointer == 53 then -- 0 [MOVE] 
 Temp[14] = 10
Temp[5] = 5
Stack[Temp[14]] = Stack[Temp[5]] 
elseif pointer == 54 then -- 28 [CALL] 
 	Stack[9](Stack[10]) 
elseif pointer == 55 then -- 5 [GETGLOBAL] 
 Temp[2] = 9
Temp[9] = 7
Temp[4] = Constants[Temp[9]]
Stack[Temp[2]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 56 then -- 0 [MOVE] 
 Temp[1] = 10
Temp[9] = 6
Stack[Temp[1]] = Stack[Temp[9]] 
elseif pointer == 57 then -- 28 [CALL] 
 	Stack[9](Stack[10]) 
elseif pointer == 58 then -- 5 [GETGLOBAL] 
 Temp[11] = 9
Temp[16] = 19
Temp[3] = Constants[Temp[16]]
Stack[Temp[11]] = vmEnv[Temp[3]] or Env[Temp[3]] 
elseif pointer == 59 then -- 0 [MOVE] 
 Temp[11] = 10
Temp[3] = 7
Stack[Temp[11]] = Stack[Temp[3]] 
elseif pointer == 60 then -- 28 [CALL] 
 	Stack[9], Stack[10], Stack[11] = Stack[9](Stack[10]) 
elseif pointer == 61 then -- 22 [JMP] 
 pointer = pointer + 10  
elseif pointer == 62 then -- 5 [GETGLOBAL] 
 Temp[13] = 14
Temp[6] = 7
Temp[14] = Constants[Temp[6]]
Stack[Temp[13]] = vmEnv[Temp[14]] or Env[Temp[14]] 
elseif pointer == 63 then -- 5 [GETGLOBAL] 
 Temp[1] = 15
Temp[3] = 22
Temp[14] = Constants[Temp[3]]
Stack[Temp[1]] = vmEnv[Temp[14]] or Env[Temp[14]]
	Stack[15] = Stack[15][Constants[52]]
	
	pointer = pointer + 1 
elseif pointer == 65 then -- 0 [MOVE] 
 Temp[12] = 16
Temp[15] = 8
Stack[Temp[12]] = Stack[Temp[15]] 
elseif pointer == 66 then -- 0 [MOVE] 
 Temp[1] = 17
Temp[2] = 12
Stack[Temp[1]] = Stack[Temp[2]] 
elseif pointer == 67 then -- 11 [SELF] 
 	Stack[19] = Stack[13]
	if Stack[19] then
		Stack[18] = Stack[13][Constants[39]]
	end
	 
elseif pointer == 68 then -- 28 [CALL] 
 	Stack[18] = Stack[18](Stack[19]) 
elseif pointer == 69 then -- 20 [LEN] 
 	Stack[19] = #Stack[13] 
elseif pointer == 70 then -- 28 [CALL] 
 	Temp[2] = {Stack[15](Stack[16], Stack[17], Stack[18], Stack[19])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[15] = nil
		top = 15
	else
		top = 15 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[15 + i - 1] = Temp[2][i]
		end
	end
	 
elseif pointer == 71 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 14 + 1, top do
		Temp[1][i - 14] = Stack[i]
	end
	Temp[2] = {Stack[14](unpack(Temp[1], 1, top - 14))}
		for i = 1, 0 do
		Stack[14 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 72 then -- 33 [TFORLOOP] 
     local r1, r2 = Stack[9](Stack[10], Stack[11])
    Stack[12] = r1
        Stack[13] = r2
    if Stack[12] ~= nil then
        Stack[11] = Stack[12]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 73 then -- 22 [JMP] 
 pointer = pointer + -12  
elseif pointer == 74 then -- 5 [GETGLOBAL] 
 Temp[9] = 9
Temp[11] = 7
Temp[12] = Constants[Temp[11]]
Stack[Temp[9]] = vmEnv[Temp[12]] or Env[Temp[12]] 
elseif pointer == 75 then -- 0 [MOVE] 
 Temp[10] = 10
Temp[2] = 6
Stack[Temp[10]] = Stack[Temp[2]] 
elseif pointer == 76 then -- 28 [CALL] 
 	Stack[9](Stack[10]) 
elseif pointer == 77 then -- 1 [LOADK] 
 Temp[10] = 9
Temp[8] = Constants
Temp[14] = 33
Stack[Temp[10]] = Temp[8][Temp[14]] 
elseif pointer == 78 then -- 10 [NEWTABLE] 
 	Stack[10] = {} 
elseif pointer == 79 then -- 11 [SELF] 
 	Stack[12] = Stack[9]
	if Stack[12] then
		Stack[11] = Stack[9][Constants[49]]
	end
	 
elseif pointer == 80 then -- 1 [LOADK] 
 Temp[9] = 13
Temp[16] = Constants
Temp[2] = 1
Stack[Temp[9]] = Temp[16][Temp[2]]
	Stack[11], Stack[12], Stack[13] = Stack[11](Stack[12], Stack[13])
	pointer = pointer + 1 
elseif pointer == 82 then -- 22 [JMP] 
 pointer = pointer + 6  
elseif pointer == 83 then -- 6 [GETTABLE] 
 	Stack[15] = Stack[10][Stack[14]]
	 
elseif pointer == 84 then -- 26 [TEST] 
 	if not Stack[15] then pointer = pointer + 1 end 
elseif pointer == 85 then -- 22 [JMP] 
 pointer = pointer + 1  
elseif pointer == 86 then -- 1 [LOADK] 
 Temp[9] = 15
Temp[16] = Constants
Temp[11] = 43
Stack[Temp[9]] = Temp[16][Temp[11]] 
elseif pointer == 87 then -- 12 [ADD] 
 	Stack[15] = Stack[15] + Constants[35] 
elseif pointer == 88 then -- 9 [SETTABLE] 
 	Stack[10][Stack[14]] = Stack[15] 
elseif pointer == 89 then -- 33 [TFORLOOP] 
     local r1 = Stack[11](Stack[12], Stack[13])
    Stack[14] = r1
    if Stack[14] ~= nil then
        Stack[13] = Stack[14]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 90 then -- 22 [JMP] 
 pointer = pointer + -8  
elseif pointer == 91 then -- 10 [NEWTABLE] 
 	Stack[11] = {} 
elseif pointer == 92 then -- 5 [GETGLOBAL] 
 Temp[3] = 12
Temp[15] = 54
Temp[13] = Constants[Temp[15]]
Stack[Temp[3]] = vmEnv[Temp[13]] or Env[Temp[13]] 
elseif pointer == 93 then -- 0 [MOVE] 
 Temp[14] = 13
Temp[2] = 10
Stack[Temp[14]] = Stack[Temp[2]] 
elseif pointer == 94 then -- 28 [CALL] 
 	Stack[12], Stack[13], Stack[14] = Stack[12](Stack[13]) 
elseif pointer == 95 then -- 22 [JMP] 
 pointer = pointer + 3  
elseif pointer == 96 then -- 20 [LEN] 
 	Stack[16] = #Stack[11] 
elseif pointer == 97 then -- 12 [ADD] 
 	Stack[16] = Stack[16] + Constants[35] 
elseif pointer == 98 then -- 9 [SETTABLE] 
 	Stack[11][Stack[16]] = Stack[15] 
elseif pointer == 99 then -- 33 [TFORLOOP] 
     local r1 = Stack[12](Stack[13], Stack[14])
    Stack[15] = r1
    if Stack[15] ~= nil then
        Stack[14] = Stack[15]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 100 then -- 22 [JMP] 
 pointer = pointer + -5  
elseif pointer == 101 then -- 5 [GETGLOBAL] 
 Temp[10] = 12
Temp[3] = 32
Temp[15] = Constants[Temp[3]]
Stack[Temp[10]] = vmEnv[Temp[15]] or Env[Temp[15]]
	Stack[12] = Stack[12][Constants[9]]
	
	pointer = pointer + 1 
elseif pointer == 103 then -- 0 [MOVE] 
 Temp[10] = 13
Temp[6] = 11
Stack[Temp[10]] = Stack[Temp[6]] 
elseif pointer == 104 then -- 28 [CALL] 
 	Stack[12](Stack[13]) 
elseif pointer == 105 then -- 10 [NEWTABLE] 
 	Stack[12] = {} 
elseif pointer == 106 then -- 5 [GETGLOBAL] 
 Temp[13] = 13
Temp[5] = 19
Temp[4] = Constants[Temp[5]]
Stack[Temp[13]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 107 then -- 0 [MOVE] 
 Temp[13] = 14
Temp[7] = 11
Stack[Temp[13]] = Stack[Temp[7]] 
elseif pointer == 108 then -- 28 [CALL] 
 	Stack[13], Stack[14], Stack[15] = Stack[13](Stack[14]) 
elseif pointer == 109 then -- 22 [JMP] 
 pointer = pointer + 7  
elseif pointer == 110 then -- 20 [LEN] 
 	Stack[18] = #Stack[12] 
elseif pointer == 111 then -- 12 [ADD] 
 	Stack[18] = Stack[18] + Constants[35] 
elseif pointer == 112 then -- 0 [MOVE] 
 Temp[13] = 19
Temp[7] = 17
Stack[Temp[13]] = Stack[Temp[7]] 
elseif pointer == 113 then -- 1 [LOADK] 
 Temp[3] = 20
Temp[6] = Constants
Temp[9] = 37
Stack[Temp[3]] = Temp[6][Temp[9]] 
elseif pointer == 114 then -- 6 [GETTABLE] 
 	Stack[21] = Stack[10][Stack[17]]
	 
elseif pointer == 115 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 19, 21 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[19] = Temp[1]
	 
elseif pointer == 116 then -- 9 [SETTABLE] 
 	Stack[12][Stack[18]] = Stack[19] 
elseif pointer == 117 then -- 33 [TFORLOOP] 
     local r1, r2 = Stack[13](Stack[14], Stack[15])
    Stack[16] = r1
        Stack[17] = r2
    if Stack[16] ~= nil then
        Stack[15] = Stack[16]
    else
        pointer = pointer + 1
    end
     
elseif pointer == 118 then -- 22 [JMP] 
 pointer = pointer + -9  
elseif pointer == 119 then -- 5 [GETGLOBAL] 
 Temp[13] = 13
Temp[16] = 7
Temp[4] = Constants[Temp[16]]
Stack[Temp[13]] = vmEnv[Temp[4]] or Env[Temp[4]] 
elseif pointer == 120 then -- 5 [GETGLOBAL] 
 Temp[14] = 14
Temp[8] = 32
Temp[4] = Constants[Temp[8]]
Stack[Temp[14]] = vmEnv[Temp[4]] or Env[Temp[4]]
	Stack[14] = Stack[14][Constants[3]]
	
	pointer = pointer + 1 
elseif pointer == 122 then -- 0 [MOVE] 
 Temp[16] = 15
Temp[1] = 12
Stack[Temp[16]] = Stack[Temp[1]] 
elseif pointer == 123 then -- 1 [LOADK] 
 Temp[3] = 16
Temp[10] = Constants
Temp[4] = 38
Stack[Temp[3]] = Temp[10][Temp[4]]
	Temp[2] = {Stack[14](Stack[15], Stack[16])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[14] = nil
		top = 14
	else
		top = 14 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[14 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 125 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 13 + 1, top do
		Temp[1][i - 13] = Stack[i]
	end
	Temp[2] = {Stack[13](unpack(Temp[1], 1, top - 13))}
		for i = 1, 0 do
		Stack[13 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 126 then -- 5 [GETGLOBAL] 
 Temp[2] = 13
Temp[6] = 7
Temp[1] = Constants[Temp[6]]
Stack[Temp[2]] = vmEnv[Temp[1]] or Env[Temp[1]] 
elseif pointer == 127 then -- 11 [SELF] 
 	Stack[15] = Stack[9]
	if Stack[15] then
		Stack[14] = Stack[9][Constants[47]]
	end
	 
elseif pointer == 128 then -- 28 [CALL] 
 	Temp[2] = {Stack[14](Stack[15])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[14] = nil
		top = 14
	else
		top = 14 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[14 + i - 1] = Temp[2][i]
		end
	end
	 
elseif pointer == 129 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 13 + 1, top do
		Temp[1][i - 13] = Stack[i]
	end
	Temp[2] = {Stack[13](unpack(Temp[1], 1, top - 13))}
		for i = 1, 0 do
		Stack[13 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 130 then -- 5 [GETGLOBAL] 
 Temp[4] = 13
Temp[15] = 7
Temp[2] = Constants[Temp[15]]
Stack[Temp[4]] = vmEnv[Temp[2]] or Env[Temp[2]] 
elseif pointer == 131 then -- 11 [SELF] 
 	Stack[15] = Stack[9]
	if Stack[15] then
		Stack[14] = Stack[9][Constants[10]]
	end
	 
elseif pointer == 132 then -- 1 [LOADK] 
 Temp[9] = 16
Temp[14] = Constants
Temp[13] = 40
Stack[Temp[9]] = Temp[14][Temp[13]] 
elseif pointer == 133 then -- 1 [LOADK] 
 Temp[13] = 17
Temp[11] = Constants
Temp[4] = 26
Stack[Temp[13]] = Temp[11][Temp[4]]
	Stack[14] = Stack[14](Stack[15], Stack[16], Stack[17])
	pointer = pointer + 1 
elseif pointer == 135 then -- 28 [CALL] 
 	Stack[13](Stack[14]) 
elseif pointer == 136 then -- 5 [GETGLOBAL] 
 Temp[9] = 13
Temp[2] = 7
Temp[7] = Constants[Temp[2]]
Stack[Temp[9]] = vmEnv[Temp[7]] or Env[Temp[7]] 
elseif pointer == 137 then -- 1 [LOADK] 
 Temp[15] = 14
Temp[10] = Constants
Temp[3] = 30
Stack[Temp[15]] = Temp[10][Temp[3]] 
elseif pointer == 138 then -- 11 [SELF] 
 	Stack[15] = Stack[14]
	if Stack[15] then
		Stack[14] = Stack[14][Constants[44]]
	end
	 
elseif pointer == 139 then -- 1 [LOADK] 
 Temp[15] = 16
Temp[10] = Constants
Temp[7] = 23
Stack[Temp[15]] = Temp[10][Temp[7]]
	Temp[2] = {Stack[14](Stack[15], Stack[16])}
	Temp[3] = #Temp[2]
	if Temp[3] == 0 then
		Stack[14] = nil
		top = 14
	else
		top = 14 + Temp[3] - 1
		for i = 1, Temp[3] do
			Stack[14 + i - 1] = Temp[2][i]
		end
	end
	
	pointer = pointer + 1 
elseif pointer == 141 then -- 28 [CALL] 
 	Temp[1] = {}
	for i = 13 + 1, top do
		Temp[1][i - 13] = Stack[i]
	end
	Temp[2] = {Stack[13](unpack(Temp[1], 1, top - 13))}
		for i = 1, 0 do
		Stack[13 + i - 1] = Temp[2][i]
	end
	
	 
elseif pointer == 142 then -- 5 [GETGLOBAL] 
 Temp[13] = 13
Temp[1] = 7
Temp[10] = Constants[Temp[1]]
Stack[Temp[13]] = vmEnv[Temp[10]] or Env[Temp[10]] 
elseif pointer == 143 then -- 11 [SELF] 
 	Stack[15] = Stack[9]
	if Stack[15] then
		Stack[14] = Stack[9][Constants[6]]
	end
	 
elseif pointer == 144 then -- 1 [LOADK] 
 Temp[12] = 16
Temp[2] = Constants
Temp[13] = 46
Stack[Temp[12]] = Temp[2][Temp[13]] 
elseif pointer == 145 then -- 1 [LOADK] 
 Temp[5] = 17
Temp[15] = Constants
Temp[11] = 27
Stack[Temp[5]] = Temp[15][Temp[11]]
	Stack[14] = Stack[14](Stack[15], Stack[16], Stack[17])
	pointer = pointer + 1 
elseif pointer == 147 then -- 1 [LOADK] 
 Temp[6] = 15
Temp[2] = Constants
Temp[10] = 29
Stack[Temp[6]] = Temp[2][Temp[10]] 
elseif pointer == 148 then -- 11 [SELF] 
 	Stack[17] = Stack[9]
	if Stack[17] then
		Stack[16] = Stack[9][Constants[12]]
	end
	 
elseif pointer == 149 then -- 1 [LOADK] 
 Temp[9] = 18
Temp[4] = Constants
Temp[2] = 48
Stack[Temp[9]] = Temp[4][Temp[2]] 
elseif pointer == 150 then -- 1 [LOADK] 
 Temp[2] = 19
Temp[1] = Constants
Temp[15] = 35
Stack[Temp[2]] = Temp[1][Temp[15]] 
elseif pointer == 151 then -- 2 [LOADBOOL] 
 Temp[15] = 20
Temp[12] = ttostring ~= __metatable
Stack[Temp[15]] = Temp[3] 
elseif pointer == 152 then -- 28 [CALL] 
 	Stack[16] = Stack[16](Stack[17], Stack[18], Stack[19], Stack[20]) 
elseif pointer == 153 then -- 21 [CONCAT] 
 	Temp[1] = ""
	for i = 14, 16 do
		Temp[1] = Temp[1] .. Stack[i]
	end
	Stack[14] = Temp[1]
	 
elseif pointer == 154 then -- 28 [CALL] 
 	Stack[13](Stack[14]) 
elseif pointer == 155 then -- 30 [RETURN] 
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