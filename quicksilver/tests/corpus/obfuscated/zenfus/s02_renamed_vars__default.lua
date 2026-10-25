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
    local code = "00002C3F48950113000001520000060100000D0100009580054F00001CF7E88EA410725C2EAC20A2A95731E21326B930030000C410010000CD30010000D520440000B9A001440000B180200B000031000000B930030000C420010000CD50010000D510440000B9A001440000B180200B000031000000B930030000C430010000CDE003010000D520440000B9A001440000B180200B000031000000B940030000C410010000CD10440000B99001440000B180200B000031000000B940030000C440010000CD10440000B99001440000B18020000000B150440000B19020460000B1D0200500000004052A130C00150404280E150B040736000B1A041E0104053B0F13070D040529160A1C050100000001000300000003002398F48E190C0000993024000089A080012E000089A08002090000A910220000A9C0A0012E0000A9C0C001090000B1203A0000B150573929377F67B0299E31553400000039350000B120460000A9603C00009910CC2ADC47416D0AA9201DE0A906120000A9A020120000A9B08001000000995009000029100000A980600E0000A9B060B12110A9A0A001E48D82A9A0C00112000099B0A001090000A910220000A9C0A0012E0000A9C0C0010A0000A91007000029480000A920470000A91005000000040B2E0E0A4E09090E05235B450004062D040C09091804082B14040015051B0A030000000000000000030000000100010101020000000002001F9E075A112640399120F78AB01145298D2766FA5C99A020F792EF9910897E0F37334D3D1914DDBDA42011C249299C34B5A1207776FB9940D9BDF899A020D9FD22999060D7563F9990E00112000091906009000099100E0000A1A060240000A19080012E0000A190800223000099C0602E000099C0E0010A000099100E000099A020B08DA29AF00FCCCD461F365AC119834B56190BE87A191E60D399206B81419910040000000004082B14040015051B0A040B340E114E040200063D094504062D040C09091802000000010001010000000000002C63184F01520000060B000009090000911044000089A080014B00008C40D4C2E2319860FCB3E0802048B366B180D001CD607581E0A001F116278980203B90148C605F857A094FECA48980200E00008990400000001144000089A0200B00008980600000001144000089A080014B00008CE0016C4E52B910C9D119B9F0C0010B0000C1808001000000C960030000D4500E0000D9F0C001030000E4700E0000E9F080020E0000F1F0C001240000E9E0A1032E0000E9E0810294079CF49001F4D7EDC9607E39DCC190214311708980409B55728C8002CCC6DA0931B7EE8980800103000094A0010900009920350000912044000089A020460000090B00000004052A000C1C1204052E000702040404290E171A040633110407131F04052A130C001504027A1904082B14040015051B0A04027A4904062D040C090918040331064C040E2E0E110F0D4C181633060D1A5B4C0300000000000100010100000000"
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

            return {[12058255] = opcode, [11625770] = A, [10394800] = B, [16664372] = C}
        elseif format == 2 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = ((instruction >> Bshift) & 0xFF) - 127
            --assert(B == (instruction // 2 ^ 23))
            C = (instruction >> Cshift) & 0xFF

            return {[12058255] = opcode, [11625770] = A, [10394800] = B, [16664372] = C}
        elseif format == 3 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = (instruction >> Bshift) & 0xFF
            --assert(B == (instruction // 2 ^ 23))
            C = ((instruction >> Cshift) & 0xFF) - 127

            return {[12058255] = opcode, [11625770] = A, [10394800] = B, [16664372] = C}
        elseif format == 4 then
            A = (instruction >> Ashift) & 0xFF
            Bx = (instruction >> Bxshift) & 0xFFFF

            return {[12058255] = opcode, [11625770] = A, [7674727] = Bx}
        elseif format == 5 then
            A = (instruction >> Ashift) & 0xFF
            sBx = convertValue((instruction >> sBxshift) & 0xFFFF, 16)

            return {[12058255] = opcode, [11625770] = A, [11421950] = sBx}
        elseif format == 6 then
            Ax = instruction >> Ashift & 0x1FFFFFF

            return {[12058255] = opcode, [143000] = Ax,}
        elseif format == 7 then
            sJ = convertValue(instruction >> Ashift & 0x1FFFFFF, 24)

            return {[12058255] = opcode, [12647531] = sJ,}
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
					OP, args = instructions[PC][12058255], regs[PC]
					if OP <= 0x07560CD then
						if OP <= 0x03F56D7 then
							if OP <= 0x022FDD9 then
								if OP <= 0x01021B1 then
									if OP <= 0x00A6D41 then
										stack[args[11625770]] = ({});
									else
										if OP == 0x00F7E89 then
											PC = PC + args[12647531]; goto RESET;
										else
											stack[args[16664372]] = stack[args[11625770]] + stack[args[10394800]];
										end
									end
								else
									if OP <= 0x014903B then
										A=args[11625770];if stack[A+4]~=nil then stack[A+2]=stack[A+4]PC=PC-args[7674727] end;
									else
										if OP == 0x019D1C9 then
											stack[args[11625770]] = stack[args[10394800]][stack[args[16664372]]];args = regs[PC + 1];stack[args[11625770]] = ENV[constants[args[16664372]]];args = regs[PC + 2];stack[args[11625770]] = stack[args[10394800]];args = regs[PC + 3];stack[args[11625770]] = constants[args[7674727]];args = regs[PC + 4];stack[args[11625770]] = stack[args[10394800]][constants[args[16664372]]];args = regs[PC + 5];stack[args[11625770]] = constants[args[7674727]];args = regs[PC + 6];stack[args[11625770]] = stack[args[10394800]][constants[args[16664372]]];args = regs[PC + 7];stack[args[11625770]] = stack[args[10394800]][constants[args[16664372]]];args = regs[PC + 8];stack[args[16664372]] = stack[args[11625770]] * stack[args[10394800]];args = regs[PC + 9];args = regs[PC + 10];PC = PC + 10;goto RESET;
										else
											stack[args[16664372]] = stack[args[11625770]] - stack[args[10394800]];
										end
									end
								end
							else
								if OP <= 0x0293957 then
									if OP <= 0x02613E2 then
										stack[args[11625770]] = stack[args[10394800]];args = regs[PC + 1];stack[args[11625770]] = constants[args[7674727]];args = regs[PC + 2];stack[args[11625770]] = args[11421950];args = regs[PC + 3];stack[args[11625770]] = args[11421950];args = regs[PC + 4];A = args[11625770];retlist = {stack[A](unpack(stack, A + 1, args[10394800]))}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 5];A = args[11625770];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 6];stack[args[11625770]] = ENV[constants[args[16664372]]];args = regs[PC + 7];stack[args[11625770]] = stack[args[10394800]];args = regs[PC + 8];stack[args[11625770]] = constants[args[7674727]];args = regs[PC + 9];stack[args[11625770]] = args[11421950];args = regs[PC + 10];stack[args[11625770]] = args[11421950];args = regs[PC + 11];A = args[11625770];retlist = {stack[A](unpack(stack, A + 1, args[10394800]))}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 12];A = args[11625770];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 13];stack[args[11625770]] = ENV[constants[args[16664372]]];args = regs[PC + 14];stack[args[11625770]] = stack[args[10394800]];args = regs[PC + 15];stack[args[11625770]] = constants[args[7674727]];args = regs[PC + 16];stack[args[11625770]] = args[11421950];args = regs[PC + 17];stack[args[11625770]] = args[11421950];args = regs[PC + 18];A = args[11625770];retlist = {stack[A](unpack(stack, A + 1, args[10394800]))}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 19];A = args[11625770];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 20];stack[args[11625770]] = ENV[constants[args[16664372]]];args = regs[PC + 21];stack[args[11625770]] = stack[args[10394800]];args = regs[PC + 22];stack[args[11625770]] = constants[args[7674727]];args = regs[PC + 23];stack[args[11625770]] = args[11421950];args = regs[PC + 24];A = args[11625770];retlist = {stack[A](unpack(stack, A + 1, args[10394800]))}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 25];A = args[11625770];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 26];stack[args[11625770]] = ENV[constants[args[16664372]]];args = regs[PC + 27];stack[args[11625770]] = stack[args[10394800]];args = regs[PC + 28];stack[args[11625770]] = constants[args[7674727]];args = regs[PC + 29];stack[args[11625770]] = args[11421950];args = regs[PC + 30];A = args[11625770];retlist = {stack[A](unpack(stack, A + 1, args[10394800]))}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 31];A = args[11625770];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 32];stack[args[11625770]] = stack[args[10394800]];args = regs[PC + 33];A = args[11625770];retlist = {stack[A]()}; args = regs[PC + 34];A = args[11625770];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[10394800]); end;args = regs[PC + 35];PC = PC + 35;goto RESET;
									else
										if OP > 0x02716F1 then
											PC = PC + args[12647531]; goto RESET;
										else
											A=args[11625770];stack[A+4],stack[A+5],stack[A+3+args[16664372]]=stack[A](stack[A+1],stack[A+2]);
										end
									end
								else
									if OP <= 0x0394026 then
										if OP == 0x02E5C72 then
											proto = protos[args[7674727]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[11625770]]=lua_wrap_state(proto,ENV,uvlist);
										else
											stack[args[11625770]] = stack[args[10394800]][stack[args[16664372]]];
										end
									else
										if OP == 0x03D4D33 then
											stack[args[11625770]] = false;
										else
											args = regs[PC + 1];stack[args[11625770]][constants[args[10394800]]] = stack[args[16664372]];args = regs[PC + 2];uv = upvalues[args[10394800]]; stack[args[11625770]] = uv.store[uv.index];args = regs[PC + 3];stack[args[11625770]] = stack[args[10394800]][constants[args[16664372]]];args = regs[PC + 4];stack[args[16664372]] = stack[args[11625770]] * stack[args[10394800]];args = regs[PC + 5];args = regs[PC + 6];stack[args[16664372]] = stack[args[11625770]] - stack[args[10394800]];args = regs[PC + 7];args = regs[PC + 8];uv = upvalues[args[10394800]]; uv.store[uv.index] = stack[args[11625770]];args = regs[PC + 9];stack[args[11625770]] = stack[args[10394800]][constants[args[16664372]]];args = regs[PC + 10];PC = PC + 10;goto RESET;
										end
									end
								end
							end
						else
							if OP <= 0x0564B83 then
								if OP <= 0x049C211 then
									if OP <= 0x041816B then
										do return end;
									else
										if OP > 0x046CDCC then
											stack[args[11625770]] = stack[args[10394800]];
										else
											PC = PC + args[12647531]; goto RESET;
										end
									end
								else
									if OP <= 0x0524E6C then
										if OP == 0x04F1863 then
											stack[args[11625770]] = ({});args = regs[PC + 1];args = regs[PC + 2];stack[args[11625770]] = ENV[constants[args[16664372]]];args = regs[PC + 3];uv = upvalues[args[10394800]]; stack[args[11625770]] = uv.store[uv.index];args = regs[PC + 4];A = args[11625770];retlist = {stack[A](stack[A + 1])}; retnum = args[16664372]; move(retlist, 1, retnum, A, stack);args = regs[PC + 5];stack[A + 3] = nil; PC = PC + args[7674727];args = regs[PC + 6];PC = PC + 6;goto RESET;
										else
											uv = upvalues[args[10394800]]; stack[args[11625770]] = uv.store[uv.index];
										end
									else
										if OP == 0x055319E then
											stack[args[11625770]] = constants[args[7674727]];args = regs[PC + 1];stack[args[11625770]] = stack[args[10394800]];args = regs[PC + 2];A=args[11625770];result={}for a=A,A+args[10394800]-1 do insert(result,stack[a])end;stack[args[11625770]]=concat(result);args = regs[PC + 3];A = args[11625770];do return unpack(stack, A, args[10394800]); end;args = regs[PC + 4];if ((stack[args[11625770]] == constants[args[10394800]]) ~= false) then PC = PC + 1 end;args = regs[PC + 5];PC = PC + 5;goto RESET;
										else
											stack[args[11625770]][stack[args[10394800]]] = constants[args[16664372]];
										end
									end
								end
							else
								if OP <= 0x05CFA66 then
									if OP <= 0x057A9A2 then
										stack[args[11625770]] = ENV[constants[args[16664372]]];
									else
										if OP == 0x05A079E then
											uv = upvalues[args[10394800]]; stack[args[11625770]] = uv.store[uv.index];
										else
											stack[args[11625770]] = stack[args[10394800]][constants[args[16664372]]];
										end
									end
								else
									if OP <= 0x0701143 then
										if OP == 0x066B348 then
											
										else
											A=args[11625770];stack[A+4],stack[A+5],stack[A+3+args[16664372]]=stack[A](stack[A+1],stack[A+2]);
										end
									else
										if OP > 0x072559B then
											stack[args[11625770]][stack[args[10394800]]] = stack[args[16664372]];
										else
											A=args[11625770];if stack[A+4]~=nil then stack[A+2]=stack[A+4]PC=PC-args[7674727] end;
										end
									end
								end
							end
						end
					else
						if OP <= 0x0B08AF7 then
							if OP <= 0x08EF498 then
								if OP <= 0x0828DE4 then
									if OP <= 0x07A855F then
										close_lua_upvalues(openlist, args[11625770]);
									else
										if OP > 0x07AE80B then
											args = regs[PC + 1];stack[args[11625770]][constants[args[10394800]]] = stack[args[16664372]];args = regs[PC + 2];uv = upvalues[args[10394800]]; stack[args[11625770]] = uv.store[uv.index];args = regs[PC + 3];stack[args[16664372]] = stack[args[11625770]] + stack[args[10394800]];args = regs[PC + 4];args = regs[PC + 5];uv = upvalues[args[10394800]]; uv.store[uv.index] = stack[args[11625770]];args = regs[PC + 6];stack[args[11625770]] = true;args = regs[PC + 7];do return stack[args[11625770]]; end;args = regs[PC + 8];do return end;args = regs[PC + 9];PC = PC + 9;goto RESET;
										else
											stack[args[11625770]] = true;
										end
									end
								else
									if OP <= 0x08D2945 then
										PC = PC + args[12647531]; goto RESET;
									else
										if OP == 0x08EE8F7 then
											proto = protos[args[7674727]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[11625770]]=lua_wrap_state(proto,ENV,uvlist);
										else
											uv = upvalues[args[10394800]]; stack[args[11625770]] = uv.store[uv.index];args = regs[PC + 1];stack[args[11625770]] = stack[args[10394800]][stack[args[16664372]]];args = regs[PC + 2];stack[args[16664372]] = stack[args[11625770]] * stack[args[10394800]];args = regs[PC + 3];args = regs[PC + 4];uv = upvalues[args[10394800]]; stack[args[11625770]] = uv.store[uv.index];args = regs[PC + 5];stack[args[16664372]] = stack[args[11625770]] + stack[args[10394800]];args = regs[PC + 6];args = regs[PC + 7];uv = upvalues[args[10394800]]; stack[args[11625770]] = uv.store[uv.index];args = regs[PC + 8];if ((stack[args[11625770]] < stack[args[10394800]]) ~= false) then PC = PC + 1; end;args = regs[PC + 9];PC = PC + 9;goto RESET;
										end
									end
								end
							else
								if OP <= 0x0A28DB0 then
									if OP <= 0x095483F then
										stack[args[11625770]] = nil;args = regs[PC + 1];stack[args[11625770]] = ({});args = regs[PC + 2];args = regs[PC + 3];stack[args[11625770]] = args[11421950];args = regs[PC + 4];stack[args[11625770]] = args[11421950];args = regs[PC + 5];proto = protos[args[7674727]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[11625770]]=lua_wrap_state(proto,ENV,uvlist);args = regs[PC + 6];PC = PC + 6;goto RESET;
									else
										if OP > 0x09C0794 then
											if ((stack[args[11625770]] == args[10394800]) ~= false) then PC = PC + 1 end;
										else
											stack[args[11625770]] = constants[args[7674727]];
										end
									end
								else
									if OP <= 0x0A9E01D then
										if OP > 0x0A4EC4F then
											args = regs[PC + 1];stack[args[11625770]][constants[args[10394800]]] = stack[args[16664372]];args = regs[PC + 2];stack[args[11625770]][constants[args[10394800]]] = constants[args[16664372]];args = regs[PC + 3];stack[args[11625770]] = stack[args[10394800]];args = regs[PC + 4];uv = upvalues[args[10394800]]; stack[args[11625770]] = uv.store[uv.index];args = regs[PC + 5];stack[args[11625770]][stack[args[10394800]]] = stack[args[16664372]];args = regs[PC + 6];stack[args[11625770]] = stack[args[10394800]][constants[args[16664372]]];args = regs[PC + 7];PC = PC + 7;goto RESET;
										else
											stack[args[11625770]] = ENV[constants[args[16664372]]];args = regs[PC + 1];stack[args[11625770]] = stack[args[10394800]][constants[args[16664372]]];args = regs[PC + 2];stack[args[11625770]] = stack[args[10394800]];args = regs[PC + 3];A = args[11625770];retlist = {stack[A](stack[A + 1])}; args = regs[PC + 4];stack[args[11625770]] = ENV[constants[args[16664372]]];args = regs[PC + 5];stack[args[11625770]] = stack[args[10394800]];args = regs[PC + 6];A = args[11625770];retlist = {stack[A](stack[A + 1])}; retnum = args[16664372]; move(retlist, 1, retnum, A, stack);args = regs[PC + 7];stack[A + 3] = nil; PC = PC + args[7674727];args = regs[PC + 8];PC = PC + 8;goto RESET;
										end
									else
										if OP > 0x0B0677F then
											if ((stack[args[11625770]] == constants[args[10394800]]) ~= true) then PC = PC + 1 end;
										else
											stack[args[11625770]] = false;
										end
									end
								end
							end
						else
							if OP <= 0x0DC397E then
								if OP <= 0x0C15A36 then
									if OP <= 0x0B5349C then
										A=args[11625770];result={}for a=A,A+args[10394800]-1 do insert(result,stack[a])end;stack[args[11625770]]=concat(result);
									else
										if OP > 0x0BDDD14 then
											uv = upvalues[args[10394800]]; stack[args[11625770]] = uv.store[uv.index];
										else
											stack[args[11625770]] = constants[args[7674727]];
										end
									end
								else
									if OP <= 0x0DAC6CC then
										if OP == 0x0D3601E then
											do return stack[args[11625770]]; end;
										else
											close_lua_upvalues(openlist, args[11625770]);
										end
									else
										if OP == 0x0DC2ACC then
											PC = PC + args[12647531]; goto RESET;
										else
											A = args[11625770];retlist = {stack[A](stack[A + 1])}; 
										end
									end
								end
							else
								if OP <= 0x0EEB731 then
									if OP <= 0x0E2C2D4 then
										stack[args[11625770]] = #(stack[args[10394800]]);
									else
										if OP > 0x0EDD7F4 then
											stack[args[11625770]] = ENV[constants[args[16664372]]];args = regs[PC + 1];stack[args[11625770]] = constants[args[7674727]];args = regs[PC + 2];uv = upvalues[args[10394800]]; stack[args[11625770]] = uv.store[uv.index];args = regs[PC + 3];A=args[11625770];result={}for a=A,A+args[10394800]-1 do insert(result,stack[a])end;stack[args[11625770]]=concat(result);args = regs[PC + 4];A = args[11625770];retlist = {stack[A](stack[A + 1])}; args = regs[PC + 5];A = args[11625770];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[10394800]); end;args = regs[PC + 6];PC = PC + 6;goto RESET;
										else
											A=args[11625770];result={}for a=A,A+args[10394800]-1 do insert(result,stack[a])end;stack[args[11625770]]=concat(result);
										end
									end
								else
									if OP <= 0x0F8BDD9 then
										if OP > 0x0EF92F7 then
											stack[args[11625770]] = stack[args[10394800]][constants[args[16664372]]];
										else
											if ((stack[args[11625770]] < stack[args[10394800]]) ~= false) then PC = PC + 1; end;
										end
									else
										if OP > 0x0FB7677 then
											stack[args[11625770]] = stack[args[10394800]] + args[16664372];
										else
											A = args[11625770];do return unpack(stack, A, args[10394800]); end;
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
