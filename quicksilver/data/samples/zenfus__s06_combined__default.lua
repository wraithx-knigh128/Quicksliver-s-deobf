return (function(pack, move, unpack, env, pCall, Err)
    local function hexToString(hex)
        local str = ""
        for i = 1, #hex, 2 do
            local byte = tonumber(hex:sub(i, i + 1), 16)
            str = str .. string.char(byte)
        end
        return str
    end

    local insert = table.insert
    local concat = table.concat
    local byte = string.byte
    local char = string.char

    local lua_wrap_state, run_vm
    function lua_wrap_state(cache, env, upvalues)
        if env and (cache.upvalueSize == 1) and not upvalues[0] then
            local eup = {index = "value", value = env}
            eup.store = eup
            upvalues[0] = eup
        end
        return (function(...)
            local passed = pack(...)
            local passn = passed.n
            local numparams = cache.numparams
            local stack, vararg = {}, {len = 0, list = {}}
            if numparams < passn then
                local start = numparams + 1
                local len = passn - numparams
                vararg.len = len
                move(passed, start, start + len - 1, 1, vararg.list)
            end
            move(passed, 1, numparams, 0, stack)
            local res = pack(pCall(run_vm, ({vararg = vararg, stack = stack, cache = cache}), env, upvalues))
            if res[1] then
                return unpack(res, 2, res.n)
            else
                Err(res[2], 0)
            end
        end)
    end

    local loadFunction
    local code = "000052F11627011300000152000006120000014F00000CF7E88E819020725C2E8C10A2A95781A020E213268C203F489581B0202640398980800113000011520000061300009910520000061200001944000089B0401200008980204F00009430F78AB089904045298D944066FA5C89B040F792EF9180A0011300001952000006130000A110520000061200002144000091C0401200009180404F00009C50897E0F91E060334D3D9C6014DDBD91B06011C249195200000612000099806012000099F080024F0000A4709C34B5999081017776FBA48001D9BDF899A08101D9FD22A49001D7563F99B08101B08DA2A4A001CCCD4699C08101365AC1A1B0A002440000A19040140000A9C0C0020E0000B990A002010000C520440000B98001440000A98020140000A9C0C0020E0000B9A0A002010000C530010000CD40440000B99001440000A98020140000A9C0C0020E0000B980A002030000C4D001440000B98001440000A98020834B56A9C080030BE87AA9E0401E60D3AAF00F6B8141479E075AA980C003D4C2E2B1C0E002440000B1F040140000B1E040440000B170440000A98020380000AFFFFF3F9860FCACB00148B366B180C003CD6075B950030000C4F001440000B98001440000B18020460000B1D020100000000407053E0C00050917040334041204083E04160D13050D1604043B13000F040C2904110304180E073B03090B040C2904110304180E073B03090B04033404120405053E090B0F00040334041204042A14160604032A0E15040429081F0B0404380D0A0C04052A130C0015143E0E0E450C04404F1C28410B01154C1B1C7A030042411807122E410C1D411807167A10100B1218061C345B451A0E4C0D167A160C1D044C06007A150A4E03090100000001000C0000000100084A058A0913000091105200000612000091100900009910450000893046000009470000891002000000040C2904110304180E073B03090B04043400080B02000000000001000000000001000B5F857A0903000094100B00009980400E000099B060030000A440140000A980A001440000A960440000998040350000893048000089203B901489100600000004043400080B040B7A160C1A094C0E013F00450406291517070F0B04063C0E1703001804047F4F570804043B13000F01000000000000000000010003C9D1190D4FECA489206C4E52891000000000000000000000000001000A94079C09030000941044000089A04012000089200B00009190600000009910090000A120450000914046000011470000911004000000040334041204063908170D0D09040628000107141F040C2904110304180E073B03090B0300000001000000010100000000010009F4D7ED090E00008990200E00009180401A000091B04030000091B0C00224000089A0202E000089A08002480000892047000089100400000004043700110604022A08040628000107141F0302000000000000000100000000000000000002000C9B5572110300009C1044000091B0400000001912000091B02012000091A0600B000099908001000000A120090000A92045000099507E39DC19431170991005000000040334041204042804061A04052D08011A09040632040C090918040C2904110304180E073B03090B0300000001000000010200000000010006CCC6DA090E000091802024000089A0202E000089A08002480000892047000089100200000004052D08011A09040632040C090918000000000000000000000C5739290113000089305200000612000089904012000089B08001130000115200000612000089D0400900009110450000812031B7EE0163184F811006000000040C2904110304180E073B03090B04053C08171D1503010000000000000004043600161A030000000000000000040533150003120200000000000103000000000200087F67B01115000093A080202F00009180D0011200008180400E00009180200E00001910000091B02047000091100200000004043600161A040533150003120000000000000000010012987678099E3155918020CC2ADC9110416D0A1F1DE0A909B121108920E48D8289804098F48E11F49C548990400E00009180400E00001910000091B0600E00001115000093A080202F00009180D001120000818040480000892047000091100400000004053C08171D1504043600161A04053315000312000000000000000000010008025230090E000091802023000089A0202E000089A0E0011500008B9080202F00008980D001480000892047000089100200000004043600161A04053C08171D15000000000000000001003FF81EC409520000061400001144000091B04014000091A020030000A42044000091C080014B0000947081A37EB990C00107D302398198C3177173EA3DF5FE59BBF0802040B6E1B980D0017E59D589E0E001922E96918020C02EF894900150689E11EFFDE811520000060B0000998060000000A11044000099C080014B00009C40CA2373C1206A05E4C3808120C665B2C180D001F518009180E1016207D799802028CBFD9C6078E5661918E328998080017A942399B0A001F4C7FDA120E240482C1DD0E599D020BC87DA1952000006010000A5100B0000A980C0010E0000A9D0E001010000B530340000B920440000A9F040010000B5104A0000A49001913018C1306FED18C38081202F0000C180D0010C0000C9A0E001030000D480010C0000D9A0E0010C0000D990E002350000C9301000009980A1026A1BF7A4A00184DC65A18080011A07B6A1C0A002000000A930030000B4A001450000A16046000021460000A1300B0000000405360E120B1304063D0C041A020404037F004E04052A000C1C1204052E000702040404290E171A040437001106040337080B0401600406390E0B0D00180402764101000000000001000000020015397F2D110C00009120090000190C000099B020390000913096CB225769BCCD11C3C5A19120F3EB27197E394699B02016E82F9920485DD4177C2A24118686491154771891201C274A8110354994170FABEF110618821116F15C9120577FEA91100000000001000000010100000000"
    code = hexToString(code)
    local strUnpack = string.unpack
    local pos, UNPACK, getByte, get12Bits, get16Bits, get24Bits, get27Bits, get32Bits, get64Bits, loadUnsigned, loadInt, loadSize, loadString = 1

    function UNPACK(fmt, posi)
        local res, newPos = strUnpack(fmt, code, posi)
        pos = newPos
        return res
    end

    function getByte()
        local S = pos
        pos = pos + 1
        return code:byte(S, S)
    end

    function get12Bits()
        -- Extract the high and low bytes
        local highByte = getByte()
        local lowByte = getByte()

        -- Reconstruct the 12-bit number
        local num = highByte * 256 + lowByte

        -- Convert back from two's complement if necessary
        if num >= 2048 then
            num = num - 4096
        end

        return num
    end

    function get16Bits()
        return UNPACK("<I2", pos)
    end

    function get24Bits()
        return UNPACK("<I3", pos)
    end

    function loadUnsigned(limit)
        local size = 0
        local b = getByte()
        local shift = 0

        while (b & 0x80) ~= 0 do -- While the MSB is set, continue reading
            size = size | ((b & 0x7F) << shift) -- Combine the 7 bits
            shift = shift + 7
            b = getByte()
        end
        size = size | (b << shift) -- Combine the final byte
        return size
    end

    function loadSize()
        return loadUnsigned(4294967295)
    end

    function loadInt()
        return loadUnsigned(math.maxinteger)
    end

    function get32Bits()
        return UNPACK("<I4", pos)
    end

    function get64Bits()
        return UNPACK("<I8", pos)
    end

    function loadString()
        return UNPACK("c" .. loadSize(), pos)
    end

    local sizeType = 3
    local sizeB = 8
    local sizeA = 8
    local sizeC = 8
    local sizeBx = 16
    local sizeSbx = sizeBx
    -- Shifting positions
    local typeShift = 0
    local Ashift = (typeShift + sizeType)
    local Bshift = (Ashift + sizeA)
    local Cshift = (Bshift + sizeB)
    local Bxshift = Bshift
    local sBxshift = Bxshift
    local max = 2 ^ (16 - 1)

    local function convertValue(value, bits)
        local max_unsigned = 2 ^ bits - 1
        local max_signed = 2 ^ (bits - 1) - 1
        local min_signed = -2 ^ (bits - 1)

        if value < 0 then
            -- Convert signed to unsigned
            return value + 2 ^ bits
        elseif value > max_signed then
            -- Convert unsigned to signed
            return value - 2 ^ bits
        else
            -- Value is already within signed range
            return value
        end
    end

    local function decodeInsts()
        --local opcode = (instruction >> OPshift) & ((1 << 6) - 1)
        local opcode, instruction, A, B, C, Bx, sBx, Ax, sJ = get24Bits(), loadInt()

        local format = (instruction >> 0) & 0x7
        if format == 1 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = (instruction >> Bshift) & 0xFF
            --assert(B == (instruction // 2 ^ 23))
            C = (instruction >> Cshift) & 0xFF

            return {[11815415] = opcode, [10925983] = A, [13778436] = B, [3300777] = C}
        elseif format == 2 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = ((instruction >> Bshift) & 0xFF) - 127
            --assert(B == (instruction // 2 ^ 23))
            C = (instruction >> Cshift) & 0xFF

            return {[11815415] = opcode, [10925983] = A, [13778436] = B, [3300777] = C}
        elseif format == 3 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = (instruction >> Bshift) & 0xFF
            --assert(B == (instruction // 2 ^ 23))
            C = ((instruction >> Cshift) & 0xFF) - 127

            return {[11815415] = opcode, [10925983] = A, [13778436] = B, [3300777] = C}
        elseif format == 4 then
            A = (instruction >> Ashift) & 0xFF
            Bx = (instruction >> Bxshift) & 0xFFFF

            return {[11815415] = opcode, [10925983] = A, [11721544] = Bx}
        elseif format == 5 then
            A = (instruction >> Ashift) & 0xFF
            sBx = convertValue((instruction >> sBxshift) & 0xFFFF, 16)

            return {[11815415] = opcode, [10925983] = A, [3017768] = sBx}
        elseif format == 6 then
            Ax = instruction >> Ashift & 0x1FFFFFF

            return {[11815415] = opcode, [11680739] = Ax,}
        elseif format == 7 then
            sJ = convertValue(instruction >> Ashift & 0x1FFFFFF, 24)

            return {[11815415] = opcode, [10962574] = sJ,}
        end
    end

    local function luaF_newproto()
        local f = {
            numparams = 0,
            isvararg = 0,
            maxstacksize = 0,
            codeSize = 0,
            code = {},
            constSize = 0,
            constants = {},
            protoSize = 0,
            proto = {},
            upvalueSize = 0,
            upvalues = {}
        }
        return f
    end

    local function loadCode(f)
        local n = get12Bits()
        --print("INSTRUCTION SIZE:", n)
        f.sizeCode = n
        for i = 1, n do
            f.code[i - 1] = decodeInsts()
        end
    end

    local function loadConstants(f)
        local n = get32Bits()
        local o, type
        f.conSize = n
        for i = 1, n do
            type = getByte()
            if type == 0 then
                o = nil
            elseif type == 1 then
                o = false
            elseif type == 17 then
                o = true
            elseif type == 19 then
                o = UNPACK("n", pos)
            elseif type == 3 then
                o = UNPACK("j", pos)
            elseif type == 4 or type == 20 then
                o = (function(input, key)
                    local output, key_byte, input_byte, encrypted_byte = {}
                    for i = 1, #input do
                        key_byte = byte(key, (i - 1) % #key + 1)
                        input_byte = byte(input, i)
                        encrypted_byte = (input_byte ~ key_byte)
                        output[i] = char(encrypted_byte)
                    end
                    return concat(output)
                end)(loadString(), "Zaenalos")
            end
            f.constants[i - 1] = o
        end
    end

    local function loadProtos(f)
        local n = get32Bits()
        f.protoSize = n
        for i = 1, n do
            f.proto[i - 1] = luaF_newproto()
            loadFunction(f.proto[i - 1])
        end
    end

    local function loadUpvalues(f)
        local n = get32Bits()
        f.upvalueSize = n
        for i = 1, n do
            f.upvalues[i - 1] = {instack = getByte() ~= 0, idx = getByte()}
        end
    end

    function loadFunction(p)
        p.numparams = getByte()
        loadCode(p)
        loadConstants(p)
        loadUpvalues(p)
        loadProtos(p)
    end

    local chunk = luaF_newproto()
    loadFunction(chunk)

    local function close_lua_upvalues(list, index)
        for i, uv in pairs(list) do
            if uv.index >= index then
                uv.value = uv.store[uv.index]
                uv.store = uv
                uv.index = "value"
                list[i] = nil
            end
        end
    end

    return (function()
        do
            run_vm = function(state, env, upvalues)
                local cache = state.cache
                local constants = cache.constants
                local instructions, regs = cache.code, cache.code
                local instSize = cache.sizeCode
                local protos = cache.proto
                local stack = state.stack
                local PC = 0
                local vararg = state.vararg
                local openlist = {}
                local ENV = env
                local top = -1
                local A, B, C, SBX, step, init, index, limit, loops, OP, args, proto, nups, uvlist, fun, uv, result, offset, tab, retnum, retlist, IP, index, prev, idx
                ::RESET::
                repeat
					OP, args = instructions[PC][11815415], regs[PC]
					if OP <= 0x07A855F then
						if OP <= 0x03F56D7 then
							if OP <= 0x023947A then
								if OP <= 0x014903B then
									if OP <= 0x00A6D41 then
										if OP <= 0x00018F5 then
											stack[args[10925983]][stack[args[13778436]]] = stack[args[3300777]];
										else
											if OP == 0x002D307 then
												if (not stack[args[10925983]] == true) then PC = PC + 1; end;
											else
												PC = PC + args[10962574]; goto RESET;
											end
										end
									else
										if OP <= 0x00F7E89 then
											stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];
										else
											if OP > 0x01021B1 then
												do return end;
											else
												do return stack[args[10925983]]; end;
											end
										end
									end
								else
									if OP <= 0x018ED6F then
										if OP <= 0x0183091 then
											stack[args[10925983]] = #(stack[args[13778436]]);
										else
											if OP == 0x0187754 then
												do return stack[args[10925983]]; end;
											else
												stack[args[10925983]] = stack[args[13778436]] + args[3300777];args = regs[PC + 1];args = regs[PC + 2];stack[args[10925983]] = stack[args[13778436]][stack[args[3300777]]];args = regs[PC + 3];stack[args[10925983]] = constants[args[11721544]];args = regs[PC + 4];stack[args[10925983]] = stack[args[13778436]][stack[args[3300777]]];args = regs[PC + 5];stack[args[10925983]] = stack[args[13778436]][stack[args[3300777]]];args = regs[PC + 6];A=args[10925983];result={}for a=A,A+args[13778436]-1 do insert(result,stack[a])end;stack[args[10925983]]=concat(result);args = regs[PC + 7];stack[args[10925983]][stack[args[13778436]]] = stack[args[3300777]];args = regs[PC + 8];PC = PC + 8;goto RESET;
											end
										end
									else
										if OP <= 0x022CB96 then
											if OP == 0x019D1C9 then
												stack[args[10925983]] = args[3017768];
											else
												PC = PC + args[10962574]; goto RESET;
											end
										else
											if OP == 0x022FDD9 then
												proto = protos[args[11721544]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10925983]]=lua_wrap_state(proto,ENV,uvlist);
											else
												stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];
											end
										end
									end
								end
							else
								if OP <= 0x0293957 then
									if OP <= 0x02716F1 then
										if OP <= 0x0242A7C then
											stack[args[10925983]] = false; PC = PC + 1;
										else
											if OP == 0x02613E2 then
												proto = protos[args[11721544]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10925983]]=lua_wrap_state(proto,ENV,uvlist);
											else
												stack[args[10925983]] = nil;args = regs[PC + 1];stack[args[10925983]] = ({});args = regs[PC + 2];args = regs[PC + 3];stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];args = regs[PC + 4];proto = protos[args[11721544]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10925983]]=lua_wrap_state(proto,ENV,uvlist);args = regs[PC + 5];PC = PC + 5;goto RESET;
											end
										end
									else
										if OP <= 0x027EBF3 then
											uv = upvalues[args[13778436]]; stack[args[10925983]] = uv.store[uv.index];
										else
											if OP == 0x028E318 then
												stack[args[10925983]] = ENV[constants[args[3300777]]];
											else
												stack[args[10925983]] = ENV[constants[args[3300777]]];args = regs[PC + 1];stack[args[10925983]] = ({});args = regs[PC + 2];args = regs[PC + 3];stack[args[10925983]][constants[args[13778436]]] = constants[args[3300777]];args = regs[PC + 4];stack[args[10925983]][constants[args[13778436]]] = constants[args[3300777]];args = regs[PC + 5];stack[args[10925983]] = ({});args = regs[PC + 6];args = regs[PC + 7];stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];args = regs[PC + 8];uv = upvalues[args[13778436]]; stack[args[10925983]] = uv.store[uv.index];args = regs[PC + 9];A = args[10925983];do return stack[A](unpack(stack, A + 1, args[13778436])); end;args = regs[PC + 10];PC = PC + 10;goto RESET;
											end
										end
									end
								else
									if OP <= 0x02FE816 then
										if OP <= 0x02D7F39 then
											uv = upvalues[args[13778436]]; stack[args[10925983]] = uv.store[uv.index];args = regs[PC + 1];stack[args[10925983]] = stack[args[13778436]][stack[args[3300777]]];args = regs[PC + 2];uv = upvalues[args[13778436]]; stack[args[10925983]] = uv.store[uv.index];args = regs[PC + 3];stack[args[10925983]] = stack[args[13778436]][stack[args[3300777]]];args = regs[PC + 4];if ((stack[args[10925983]] == stack[args[13778436]]) ~= true) then PC = PC + 1 end;args = regs[PC + 5];PC = PC + 5;goto RESET;
										else
											if OP > 0x02E5C72 then
												if ((stack[args[10925983]] < stack[args[13778436]]) ~= true) then PC = PC + 1; end;
											else
												proto = protos[args[11721544]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10925983]]=lua_wrap_state(proto,ENV,uvlist);
											end
										end
									else
										if OP <= 0x0394026 then
											if OP == 0x0305202 then
												stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 1];stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 2];stack[args[3300777]] = stack[args[10925983]] - stack[args[13778436]];args = regs[PC + 3];args = regs[PC + 4];stack[args[10925983]] = stack[args[13778436]] + args[3300777];args = regs[PC + 5];args = regs[PC + 6];do return stack[args[10925983]]; end;args = regs[PC + 7];do return end;args = regs[PC + 8];PC = PC + 8;goto RESET;
											else
												stack[args[10925983]] = ENV[constants[args[3300777]]];args = regs[PC + 1];stack[args[10925983]] = ({});args = regs[PC + 2];args = regs[PC + 3];stack[args[10925983]] = ({});args = regs[PC + 4];args = regs[PC + 5];stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];args = regs[PC + 6];A = args[10925983];retlist = {stack[A](unpack(stack, A + 1, args[13778436]))}; stack[A] = retlist[1];args = regs[PC + 7];stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];args = regs[PC + 8];proto = protos[args[11721544]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10925983]]=lua_wrap_state(proto,ENV,uvlist);args = regs[PC + 9];PC = PC + 9;goto RESET;
											end
										else
											if OP == 0x03D4D33 then
												proto = protos[args[11721544]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10925983]]=lua_wrap_state(proto,ENV,uvlist);
											else
												stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];
											end
										end
									end
								end
							end
						else
							if OP <= 0x057A9A2 then
								if OP <= 0x049C211 then
									if OP <= 0x046CDCC then
										if OP <= 0x041816B then
											PC = PC + args[10962574]; goto RESET;
										else
											if OP == 0x046397E then
												stack[args[10925983]] = stack[args[13778436]][stack[args[3300777]]];
											else
												stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];
											end
										end
									else
										if OP <= 0x04840E2 then
											proto = protos[args[11721544]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10925983]]=lua_wrap_state(proto,ENV,uvlist);
										else
											if OP > 0x0498686 then
												stack[args[10925983]] = ({});args = regs[PC + 1];args = regs[PC + 2];stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];args = regs[PC + 3];stack[args[10925983]][constants[args[13778436]]] = constants[args[3300777]];args = regs[PC + 4];proto = protos[args[11721544]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10925983]]=lua_wrap_state(proto,ENV,uvlist);args = regs[PC + 5];PC = PC + 5;goto RESET;
											else
												stack[args[10925983]] = true;
											end
										end
									end
								else
									if OP <= 0x0524E6C then
										if OP <= 0x04A271C then
											if ((stack[args[10925983]] < stack[args[13778436]]) ~= true) then PC = PC + 1; end;
										else
											if OP == 0x04F1863 then
												do return end;
											else
												do return end;
											end
										end
									else
										if OP <= 0x055319E then
											if OP > 0x0549CF4 then
												stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];
											else
												stack[args[10925983]] = stack[args[13778436]][stack[args[3300777]]];args = regs[PC + 1];stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 2];stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 3];stack[args[10925983]][stack[args[13778436]]] = constants[args[3300777]];args = regs[PC + 4];stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 5];stack[args[10925983]] = stack[args[13778436]] + args[3300777];args = regs[PC + 6];args = regs[PC + 7];stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];args = regs[PC + 8];do return stack[args[10925983]]; end;args = regs[PC + 9];do return end;args = regs[PC + 10];PC = PC + 10;goto RESET;
											end
										else
											if OP == 0x0564B83 then
												A = args[10925983]; B = args[13778436]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[3300777]]];
											else
												stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];
											end
										end
									end
								end
							else
								if OP <= 0x066B348 then
									if OP <= 0x05CF116 then
										if OP <= 0x059FEF5 then
											stack[args[10925983]] = stack[args[13778436]] + args[3300777];
										else
											if OP == 0x05A079E then
												stack[args[10925983]] = ENV[constants[args[3300777]]];
											else
												do return stack[args[10925983]]; end;
											end
										end
									else
										if OP <= 0x05CFA66 then
											stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];
										else
											if OP == 0x065DC84 then
												stack[args[10925983]] = ENV[constants[args[3300777]]];
											else
												stack[args[10925983]] = ENV[constants[args[3300777]]];
											end
										end
									end
								else
									if OP <= 0x072559B then
										if OP <= 0x066E578 then
											close_lua_upvalues(openlist, args[10925983]);
										else
											if OP > 0x0701143 then
												stack[args[10925983]] = ENV[constants[args[3300777]]];args = regs[PC + 1];stack[args[10925983]] = constants[args[11721544]];args = regs[PC + 2];A = args[10925983];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 3];stack[args[10925983]] = stack[args[13778436]];args = regs[PC + 4];stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];args = regs[PC + 5];stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];args = regs[PC + 6];stack[args[10925983]] = ENV[constants[args[3300777]]];args = regs[PC + 7];stack[args[10925983]] = stack[args[13778436]];args = regs[PC + 8];uv = upvalues[args[13778436]]; stack[args[10925983]] = uv.store[uv.index];args = regs[PC + 9];A = args[10925983];do return stack[A](unpack(stack, A + 1, args[13778436])); end;args = regs[PC + 10];PC = PC + 10;goto RESET;
											else
												do return end;
											end
										end
									else
										if OP <= 0x07560CD then
											if OP == 0x07323CA then
												stack[args[10925983]] = #(stack[args[13778436]]);
											else
												stack[args[10925983]] = stack[args[13778436]];args = regs[PC + 1];stack[args[10925983]] = constants[args[11721544]];args = regs[PC + 2];A = args[10925983];retlist = {stack[A](stack[A + 1])}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 3];A = args[10925983];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 4];A = args[10925983];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[13778436]); end;args = regs[PC + 5];PC = PC + 5;goto RESET;
											end
										else
											if OP == 0x0787698 then
												stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];
											else
												stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 1];stack[args[10925983]] = constants[args[11721544]];args = regs[PC + 2];stack[args[10925983]] = ENV[constants[args[3300777]]];args = regs[PC + 3];stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 4];stack[args[10925983]] = constants[args[11721544]];args = regs[PC + 5];A = args[10925983]; B = args[13778436]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[3300777]]];args = regs[PC + 6];A = args[10925983];retlist = {stack[A](stack[A + 1])}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 7];A = args[10925983];retlist = {stack[A](unpack(stack, A + 1, top))}; stack[A] = retlist[1];args = regs[PC + 8];A=args[10925983];result={}for a=A,A+args[13778436]-1 do insert(result,stack[a])end;stack[args[10925983]]=concat(result);args = regs[PC + 9];do return stack[args[10925983]]; end;args = regs[PC + 10];PC = PC + 10;goto RESET;
											end
										end
									end
								end
							end
						end
					else
						if OP <= 0x0C41EF8 then
							if OP <= 0x09E6850 then
								if OP <= 0x08D2945 then
									if OP <= 0x0821806 then
										if OP <= 0x07AE80B then
											A = args[10925983];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];
										else
											if OP == 0x07EA381 then
												stack[args[10925983]] = stack[args[13778436]][stack[args[3300777]]];
											else
												stack[args[10925983]] = true;
											end
										end
									else
										if OP <= 0x0828DE4 then
											stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];
										else
											if OP == 0x08A054A then
												stack[args[10925983]] = ENV[constants[args[3300777]]];args = regs[PC + 1];stack[args[10925983]] = ({});args = regs[PC + 2];args = regs[PC + 3];stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];args = regs[PC + 4];uv = upvalues[args[13778436]]; stack[args[10925983]] = uv.store[uv.index];args = regs[PC + 5];A = args[10925983];do return stack[A](unpack(stack, A + 1, args[13778436])); end;args = regs[PC + 6];A = args[10925983];B = top; do return unpack(stack, A, B); end;args = regs[PC + 7];do return end;args = regs[PC + 8];PC = PC + 8;goto RESET;
											else
												proto = protos[args[11721544]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10925983]]=lua_wrap_state(proto,ENV,uvlist);
											end
										end
									end
								else
									if OP <= 0x0944935 then
										if OP <= 0x08EE8F7 then
											stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];
										else
											if OP > 0x08EF498 then
												PC = PC + args[10962574]; goto RESET;
											else
												stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];
											end
										end
									else
										if OP <= 0x0962E92 then
											if OP > 0x095483F then
												A=args[10925983];stack[A+4],stack[A+5],stack[A+3+args[3300777]]=stack[A](stack[A+1],stack[A+2]);
											else
												stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];
											end
										else
											if OP == 0x09C0794 then
												stack[args[10925983]] = ENV[constants[args[3300777]]];args = regs[PC + 1];stack[args[10925983]] = constants[args[11721544]];args = regs[PC + 2];A = args[10925983];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 3];stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];args = regs[PC + 4];stack[args[10925983]] = ENV[constants[args[3300777]]];args = regs[PC + 5];stack[args[10925983]] = stack[args[13778436]];args = regs[PC + 6];uv = upvalues[args[13778436]]; stack[args[10925983]] = uv.store[uv.index];args = regs[PC + 7];A = args[10925983];do return stack[A](unpack(stack, A + 1, args[13778436])); end;args = regs[PC + 8];A = args[10925983];B = top; do return unpack(stack, A, B); end;args = regs[PC + 9];do return end;args = regs[PC + 10];PC = PC + 10;goto RESET;
											else
												close_lua_upvalues(openlist, args[10925983]);
											end
										end
									end
								end
							else
								if OP <= 0x0B08AF7 then
									if OP <= 0x0A4EC4F then
										if OP <= 0x0A1C5C3 then
											stack[args[10925983]] = stack[args[13778436]][stack[args[3300777]]];
										else
											if OP == 0x0A28DB0 then
												proto = protos[args[11721544]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10925983]]=lua_wrap_state(proto,ENV,uvlist);
											else
												do return stack[args[10925983]]; end;
											end
										end
									else
										if OP <= 0x0A9E01D then
											for i = args[13778436], 0, -1 do stack[i + args[10925983]] = nil; end;
										else
											if OP == 0x0B0677F then
												stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 1];stack[args[10925983]] = stack[args[13778436]] + args[3300777];args = regs[PC + 2];args = regs[PC + 3];stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];args = regs[PC + 4];stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 5];stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 6];stack[args[10925983]][stack[args[13778436]]] = stack[args[3300777]];args = regs[PC + 7];do return end;args = regs[PC + 8];PC = PC + 8;goto RESET;
											else
												stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];
											end
										end
									end
								else
									if OP <= 0x0B6071A then
										if OP <= 0x0B265C6 then
											
										else
											if OP == 0x0B5349C then
												stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];
											else
												stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 1];stack[args[10925983]] = stack[args[13778436]];args = regs[PC + 2];stack[args[10925983]] = constants[args[11721544]];args = regs[PC + 3];A = args[10925983];close_lua_upvalues(openlist, 0);do return stack[A](unpack(stack, A + 1, args[13778436])); end;args = regs[PC + 4];A = args[10925983];close_lua_upvalues(openlist, 0);B = top; do return unpack(stack, A, B); end;args = regs[PC + 5];A = args[10925983];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[13778436]); end;args = regs[PC + 6];PC = PC + 6;goto RESET;
											end
										end
									else
										if OP <= 0x0C15A36 then
											if OP > 0x0BDDD14 then
												stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 1];A = args[10925983];retlist = {stack[A]()}; stack[A] = retlist[1];args = regs[PC + 2];A = args[10925983]; B = args[13778436]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[3300777]]];args = regs[PC + 3];stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 4];stack[args[10925983]] = args[3017768];args = regs[PC + 5];A = args[10925983];retlist = {stack[A](stack[A + 1])}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 6];A = args[10925983];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 7];A = args[10925983]; B = args[13778436]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[3300777]]];args = regs[PC + 8];stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 9];stack[args[10925983]] = args[3017768];args = regs[PC + 10];stack[args[10925983]] = args[3017768];args = regs[PC + 11];A = args[10925983];retlist = {stack[A](unpack(stack, A + 1, args[13778436]))}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 12];A = args[10925983];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 13];A = args[10925983]; B = args[13778436]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[3300777]]];args = regs[PC + 14];stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 15];stack[args[10925983]] = constants[args[11721544]];args = regs[PC + 16];A = args[10925983];retlist = {stack[A](stack[A + 1])}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 17];A = args[10925983];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 18];PC = PC + 18;goto RESET;
											else
												stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];
											end
										else
											if OP == 0x0C39881 then
												PC = PC + args[10962574]; goto RESET;
											else
												stack[args[10925983]] = ({});args = regs[PC + 1];args = regs[PC + 2];A = args[10925983]; B = args[13778436]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[3300777]]];args = regs[PC + 3];A = args[10925983];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 4];A = args[10925983]; B = args[13778436]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[3300777]]];args = regs[PC + 5];stack[args[10925983]] = constants[args[11721544]];args = regs[PC + 6];A = args[10925983];retlist = {stack[A](unpack(stack, A + 1, args[13778436]))}; retnum = args[3300777]; move(retlist, 1, retnum, A, stack);args = regs[PC + 7];stack[A + 3] = nil; PC = PC + args[11721544];args = regs[PC + 8];PC = PC + 8;goto RESET;
											end
										end
									end
								end
							end
						else
							if OP <= 0x0E5D01D then
								if OP <= 0x0DA87BC then
									if OP <= 0x0D45D48 then
										if OP <= 0x0CDBC69 then
											uv = upvalues[args[13778436]]; stack[args[10925983]] = uv.store[uv.index];
										else
											if OP == 0x0D3601E then
												if ((stack[args[10925983]] > args[13778436]) ~= false) then PC = PC + 1; end;
											else
												PC = PC + args[10962574]; goto RESET;
											end
										end
									else
										if OP <= 0x0D5597E then
											stack[args[10925983]][stack[args[13778436]]] = stack[args[3300777]];
										else
											if OP > 0x0D70762 then
												stack[args[10925983]] = ({});args = regs[PC + 1];args = regs[PC + 2];stack[args[10925983]] = args[3017768];args = regs[PC + 3];stack[args[10925983]] = ENV[constants[args[3300777]]];args = regs[PC + 4];stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 5];stack[args[10925983]] = args[3017768];args = regs[PC + 6];stack[args[10925983]] = #(stack[args[13778436]]);args = regs[PC + 7];A = args[10925983];retlist = {stack[A](unpack(stack, A + 1, args[13778436]))}; stack[A] = retlist[1];args = regs[PC + 8];stack[args[10925983]] = args[3017768];args = regs[PC + 9];A=args[10925983];init=stack[A]limit=stack[A+1]step=stack[A+2]stack[A]=init-step;stack[A+1]=limit;stack[A+2]=step;stack[A+3]=init;PC=PC+args[11721544];args = regs[PC + 10];PC = PC + 10;goto RESET;
											else
												A=args[10925983];stack[A+4],stack[A+5],stack[A+3+args[3300777]]=stack[A](stack[A+1],stack[A+2]);
											end
										end
									end
								else
									if OP <= 0x0DC397E then
										if OP <= 0x0DAC6CC then
											stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 1];stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 2];stack[args[3300777]] = stack[args[10925983]] * stack[args[13778436]];args = regs[PC + 3];args = regs[PC + 4];do return stack[args[10925983]]; end;args = regs[PC + 5];do return end;args = regs[PC + 6];PC = PC + 6;goto RESET;
										else
											if OP == 0x0DC2ACC then
												if ((stack[args[10925983]] < stack[args[13778436]]) ~= false) then PC = PC + 1; end;
											else
												A = args[10925983];B = top; do return unpack(stack, A, B); end;
											end
										end
									else
										if OP <= 0x0E2C2D4 then
											if OP > 0x0E1B640 then
												A = args[10925983]; B = args[13778436]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[3300777]]];args = regs[PC + 1];A = args[10925983];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 2];A = args[10925983]; B = args[13778436]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[3300777]]];args = regs[PC + 3];A = args[10925983];retlist = {stack[A](stack[A + 1])}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 4];A = args[10925983];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 5];PC = PC + args[10962574];args = regs[PC + 6];PC = PC + 6;goto RESET;
											else
												
											end
										else
											if OP == 0x0E4056A then
												stack[args[10925983]] = stack[args[13778436]] + args[3300777];
											else
												A = args[10925983];retlist = {stack[A](unpack(stack, A + 1, args[13778436]))}; 
											end
										end
									end
								end
							else
								if OP <= 0x0EFAB0F then
									if OP <= 0x0EA7F57 then
										if OP <= 0x0E8FDEF then
											stack[args[10925983]] = ({});args = regs[PC + 1];args = regs[PC + 2];stack[args[10925983]] = ENV[constants[args[3300777]]];args = regs[PC + 3];stack[args[10925983]] = stack[args[13778436]];args = regs[PC + 4];A = args[10925983];retlist = {stack[A](stack[A + 1])}; retnum = args[3300777]; move(retlist, 1, retnum, A, stack);args = regs[PC + 5];stack[A + 3] = nil; PC = PC + args[11721544];args = regs[PC + 6];PC = PC + 6;goto RESET;
										else
											if OP > 0x0EA7371 then
												do return end;
											else
												stack[args[10925983]] = args[3017768];
											end
										end
									else
										if OP <= 0x0EEB731 then
											if OP == 0x0EDD7F4 then
												stack[args[10925983]] = ENV[constants[args[3300777]]];args = regs[PC + 1];stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 2];stack[args[10925983]] = stack[args[13778436]][constants[args[3300777]]];args = regs[PC + 3];stack[args[10925983]] = stack[args[3300777]] ^ constants[args[13778436]];args = regs[PC + 4];args = regs[PC + 5];stack[args[3300777]] = stack[args[10925983]] * stack[args[13778436]];args = regs[PC + 6];args = regs[PC + 7];do return stack[args[10925983]]; end;args = regs[PC + 8];do return end;args = regs[PC + 9];PC = PC + 9;goto RESET;
											else
												A = args[10925983];B = top; do return unpack(stack, A, B); end;
											end
										else
											if OP > 0x0EF92F7 then
												stack[args[10925983]] = false; PC = PC + 1;
											else
												stack[args[10925983]] = ENV[constants[args[3300777]]];args = regs[PC + 1];stack[args[10925983]] = ({});args = regs[PC + 2];args = regs[PC + 3];stack[args[10925983]] = ({});args = regs[PC + 4];args = regs[PC + 5];stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];args = regs[PC + 6];A = args[10925983];retlist = {stack[A](unpack(stack, A + 1, args[13778436]))}; stack[A] = retlist[1];args = regs[PC + 7];stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];args = regs[PC + 8];proto = protos[args[11721544]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10925983]]=lua_wrap_state(proto,ENV,uvlist);args = regs[PC + 9];PC = PC + 9;goto RESET;
											end
										end
									end
								else
									if OP <= 0x0F8BDD9 then
										if OP <= 0x0F71B6A then
											A=args[10925983];limit=stack[A+1]step=stack[A+2]index=stack[A]index=index+step;stack[A]=index;if step>0 and index<=limit or step<=0 and index>=limit then stack[A+3]=index;PC=PC-args[11721544] end;
										else
											if OP == 0x0F82EC0 then
												A=args[10925983];if stack[A+4]~=nil then stack[A+2]=stack[A+4]PC=PC-args[11721544] end;
											else
												stack[args[10925983]][constants[args[13778436]]] = stack[args[3300777]];
											end
										end
									else
										if OP <= 0x0FC6098 then
											if OP > 0x0FB7677 then
												proto = protos[args[11721544]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10925983]]=lua_wrap_state(proto,ENV,uvlist);
											else
												proto = protos[args[11721544]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10925983]]=lua_wrap_state(proto,ENV,uvlist);
											end
										else
											if OP == 0x0FDC7F4 then
												stack[args[10925983]] = stack[args[13778436]];
											else
												A=args[10925983];if stack[A+4]~=nil then stack[A+2]=stack[A+4]PC=PC-args[11721544] end;
											end
										end
									end
								end
							end
						end
					end
					PC = PC + 1
				until PC >= instSize
            end
            return lua_wrap_state(chunk, env, {})()
        end
    end)()
end)(table.pack, table.move, table.unpack, _ENV, pcall, error)
