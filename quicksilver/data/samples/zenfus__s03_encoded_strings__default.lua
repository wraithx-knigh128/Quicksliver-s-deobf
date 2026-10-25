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
    local code = "00007F4FECA401030000040300008C101300009180C001520000060300009C20030000A430030000AC40030000B450030000BC60030000C4704E000091600300009C80010B0000A180A00200000029440000A1D0200B0000A180A002000000A910440000A1D0200B0000A180C002F7E88EA920725C2EA1D08001A2A957A4A001E21326D180A0023F4895D980E0020E0000D9B08103000000E130000000E98001140000F190A103440000F1F041340000F99001440000D9F001440000D18020264039A18040F78AB0A4C00145298D2166FA5CA180A002000000A910440000A1D020030000A4E0011300002952000006140000B1C0E003030000C48002440000B18081014B0000B470F792EFD9D0C002897E0F59334D3D1714DDBD5D11C249DBB081209C34B5D980D0017776FBA9A0E102D9BDF8B18020D9FD22B49001D7563F31B08DA231520000060B0000B980A004000000C150440000B98081014B0000BC40CCCD46E160365AC1E3C08120834B56E180D0010BE87AB1C0E1021E60D3B980206B8141BC609E075A39D4C2E2B980C0040E0000B9F0E004000000C160440000B9802113000039520000060B0000C180C002000000C960440000C19081014B0000C480019860FCF17048B366F3E081202F0000F180D001000000F9D00103000084C1020C000089D1A003350000F930100000B9E0E103CD6075C18040F11627C4A0013B9014415F857AC180A0020B0000C980C0040E0000C990A105000000D170030000DCE002440000C9B001440000C180200B0000C180A002140000C9C0E005440000C9A001440000C180200B0000C180A002140000C9C08006030000DC9003030000E4A003440000C9C041440000C190210B0000C180A002030000CCB003140000C9908107010000DD30440000C9B001440000C180200B0000C180A002140000C9C0A007010000DD50010000E59001440000C9C041030000D4E003140000D9C0E007030000EC8004010000F51007000079440000D9F041350000C930440000C19021460000C1F020210000000413120409020E404F222F080605320503053F13440414774C48434C41425E774C48434C41425E774C484304053B0D1506000405381304180E04073909041C0D050A04053E04091A0004043F020D0104073C0E1D1A13031B04140144555C05314F5629414D4B054C0C1B3B13164704052A130C0015040633110407131F0406291517070F0B04063C0E1703001804052F11150B13142B2E09004E101906103141071C0E1B01533C0E1D4E0B19020329410A18041E4F0732044502001616533E0E0204063D0C041A020404027F0004052A000C1C1204052E000702040404290E171A0401670406390E0B0D001804017A04072804130B131F0A04043D12100C04013504016A04023B030403280415040329140704012604043C080B0A04033C0E1D01000000010000000000"
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

            return {[4818567] = opcode, [1603413] = A, [4859677] = B, [9718070] = C}
        elseif format == 2 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = ((instruction >> Bshift) & 0xFF) - 127
            --assert(B == (instruction // 2 ^ 23))
            C = (instruction >> Cshift) & 0xFF

            return {[4818567] = opcode, [1603413] = A, [4859677] = B, [9718070] = C}
        elseif format == 3 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = (instruction >> Bshift) & 0xFF
            --assert(B == (instruction // 2 ^ 23))
            C = ((instruction >> Cshift) & 0xFF) - 127

            return {[4818567] = opcode, [1603413] = A, [4859677] = B, [9718070] = C}
        elseif format == 4 then
            A = (instruction >> Ashift) & 0xFF
            Bx = (instruction >> Bxshift) & 0xFFFF

            return {[4818567] = opcode, [1603413] = A, [15706896] = Bx}
        elseif format == 5 then
            A = (instruction >> Ashift) & 0xFF
            sBx = convertValue((instruction >> sBxshift) & 0xFFFF, 16)

            return {[4818567] = opcode, [1603413] = A, [8525831] = sBx}
        elseif format == 6 then
            Ax = instruction >> Ashift & 0x1FFFFFF

            return {[4818567] = opcode, [6091031] = Ax,}
        elseif format == 7 then
            sJ = convertValue(instruction >> Ashift & 0x1FFFFFF, 24)

            return {[4818567] = opcode, [15368024] = sJ,}
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
					OP, args = instructions[PC][4818567], regs[PC]
					if OP <= 0x066B348 then
						if OP <= 0x03D4D33 then
							if OP <= 0x02613E2 then
								if OP <= 0x014903B then
									if OP > 0x00F7E89 then
										close_lua_upvalues(openlist, args[1603413]);
									else
										if (not stack[args[1603413]] == true) then PC = PC + 1; end;
									end
								else
									if OP == 0x022FDD9 then
										A=args[1603413];if stack[A+4]~=nil then stack[A+2]=stack[A+4]PC=PC-args[15706896] end;
									else
										stack[args[1603413]] = ENV[constants[args[9718070]]];
									end
								end
							else
								if OP <= 0x02E5C72 then
									if OP > 0x02716F1 then
										A = args[1603413];retlist = {stack[A](stack[A + 1])}; retnum = args[9718070]; move(retlist, 1, retnum, A, stack);
									else
										A=args[1603413];if stack[A+4]~=nil then stack[A+2]=stack[A+4]PC=PC-args[15706896] end;
									end
								else
									if OP > 0x0394026 then
										PC = PC + args[15368024]; goto RESET;
									else
										A=args[1603413];stack[A+4],stack[A+5],stack[A+3+args[9718070]]=stack[A](stack[A+1],stack[A+2]);
									end
								end
							end
						else
							if OP <= 0x049C211 then
								if OP <= 0x041816B then
									if OP == 0x03F56D7 then
										close_lua_upvalues(openlist, args[1603413]);
									else
										A=args[1603413];if stack[A+4]~=nil then stack[A+2]=stack[A+4]PC=PC-args[15706896] end;
									end
								else
									if OP == 0x046CDCC then
										stack[args[1603413]] = #(stack[args[4859677]]);
									else
										stack[args[1603413]] = stack[args[4859677]] + args[9718070];
									end
								end
							else
								if OP <= 0x057A9A2 then
									if OP == 0x0564B83 then
										
									else
										stack[A + 3] = nil; PC = PC + args[15706896];
									end
								else
									if OP <= 0x05A079E then
										close_lua_upvalues(openlist, args[1603413]);
									else
										if OP == 0x05CFA66 then
											stack[args[1603413]] = ENV[constants[args[9718070]]];args = regs[PC + 1];stack[args[1603413]] = stack[args[4859677]];args = regs[PC + 2];A = args[1603413];retlist = {stack[A](stack[A + 1])}; args = regs[PC + 3];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 4];stack[args[1603413]] = ({});args = regs[PC + 5];args = regs[PC + 6];A = args[1603413]; B = args[4859677]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[9718070]]];args = regs[PC + 7];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 8];A = args[1603413];retlist = {stack[A](unpack(stack, A + 1, args[4859677]))}; retnum = args[9718070]; move(retlist, 1, retnum, A, stack);args = regs[PC + 9];stack[A + 3] = nil; PC = PC + args[15706896];args = regs[PC + 10];PC = PC + 10;goto RESET;
										else
											stack[args[1603413]] = stack[args[4859677]] + args[9718070];args = regs[PC + 1];args = regs[PC + 2];stack[args[1603413]] = stack[args[4859677]];args = regs[PC + 3];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 4];stack[args[1603413]] = stack[args[4859677]][stack[args[9718070]]];args = regs[PC + 5];A=args[1603413];result={}for a=A,A+args[4859677]-1 do insert(result,stack[a])end;stack[args[1603413]]=concat(result);args = regs[PC + 6];stack[args[1603413]][stack[args[4859677]]] = stack[args[9718070]];args = regs[PC + 7];PC = PC + 7;goto RESET;
										end
									end
								end
							end
						end
					else
						if OP <= 0x0B08AF7 then
							if OP <= 0x08D2945 then
								if OP <= 0x07A855F then
									if OP == 0x07560CD then
										A=args[1603413];stack[A+4],stack[A+5],stack[A+3+args[9718070]]=stack[A](stack[A+1],stack[A+2]);
									else
										stack[args[1603413]] = ENV[constants[args[9718070]]];args = regs[PC + 1];stack[args[1603413]] = ENV[constants[args[9718070]]];args = regs[PC + 2];stack[args[1603413]] = stack[args[4859677]][constants[args[9718070]]];args = regs[PC + 3];stack[args[1603413]] = stack[args[4859677]];args = regs[PC + 4];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 5];A = args[1603413];retlist = {stack[A](unpack(stack, A + 1, args[4859677]))}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 6];A = args[1603413];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 7];stack[args[1603413]] = ENV[constants[args[9718070]]];args = regs[PC + 8];A = args[1603413]; B = args[4859677]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[9718070]]];args = regs[PC + 9];A = args[1603413];retlist = {stack[A](stack[A + 1])}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 10];A = args[1603413];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 11];stack[args[1603413]] = ENV[constants[args[9718070]]];args = regs[PC + 12];A = args[1603413]; B = args[4859677]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[9718070]]];args = regs[PC + 13];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 14];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 15];A = args[1603413];retlist = {stack[A](unpack(stack, A + 1, args[4859677]))}; stack[A] = retlist[1];args = regs[PC + 16];A = args[1603413];retlist = {stack[A](stack[A + 1])}; args = regs[PC + 17];stack[args[1603413]] = ENV[constants[args[9718070]]];args = regs[PC + 18];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 19];A = args[1603413]; B = args[4859677]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[9718070]]];args = regs[PC + 20];stack[args[1603413]] = args[8525831];args = regs[PC + 21];A = args[1603413];retlist = {stack[A](unpack(stack, A + 1, args[4859677]))}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 22];A = args[1603413];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 23];stack[args[1603413]] = ENV[constants[args[9718070]]];args = regs[PC + 24];A = args[1603413]; B = args[4859677]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[9718070]]];args = regs[PC + 25];stack[args[1603413]] = args[8525831];args = regs[PC + 26];stack[args[1603413]] = args[8525831];args = regs[PC + 27];A = args[1603413];retlist = {stack[A](unpack(stack, A + 1, args[4859677]))}; stack[A] = retlist[1];args = regs[PC + 28];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 29];A = args[1603413]; B = args[4859677]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[9718070]]];args = regs[PC + 30];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 31];stack[args[1603413]] = args[8525831];args = regs[PC + 32];stack[args[1603413]] = true;args = regs[PC + 33];A = args[1603413];retlist = {stack[A](unpack(stack, A + 1, args[4859677]))}; stack[A] = retlist[1];args = regs[PC + 34];A=args[1603413];result={}for a=A,A+args[4859677]-1 do insert(result,stack[a])end;stack[args[1603413]]=concat(result);args = regs[PC + 35];A = args[1603413];retlist = {stack[A](stack[A + 1])}; args = regs[PC + 36];A = args[1603413];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[4859677]); end;args = regs[PC + 37];PC = PC + 37;goto RESET;
									end
								else
									if OP > 0x07AE80B then
										close_lua_upvalues(openlist, args[1603413]);
									else
										stack[args[1603413]][stack[args[4859677]]] = stack[args[9718070]];
									end
								end
							else
								if OP <= 0x095483F then
									if OP > 0x08EE8F7 then
										stack[args[1603413]] = ENV[constants[args[9718070]]];args = regs[PC + 1];stack[args[1603413]] = stack[args[4859677]][constants[args[9718070]]];args = regs[PC + 2];stack[args[1603413]] = stack[args[4859677]];args = regs[PC + 3];stack[args[1603413]] = stack[args[4859677]];args = regs[PC + 4];A = args[1603413]; B = args[4859677]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[9718070]]];args = regs[PC + 5];A = args[1603413];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 6];stack[args[1603413]] = #(stack[args[4859677]]);args = regs[PC + 7];A = args[1603413];retlist = {stack[A](unpack(stack, A + 1, args[4859677]))}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 8];A = args[1603413];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 9];PC = PC + 9;goto RESET;
									else
										stack[args[1603413]] = stack[args[4859677]];
									end
								else
									if OP <= 0x0A28DB0 then
										stack[args[1603413]] = ({});args = regs[PC + 1];args = regs[PC + 2];stack[args[1603413]] = ENV[constants[args[9718070]]];args = regs[PC + 3];stack[args[1603413]] = stack[args[4859677]];args = regs[PC + 4];A = args[1603413];retlist = {stack[A](stack[A + 1])}; retnum = args[9718070]; move(retlist, 1, retnum, A, stack);args = regs[PC + 5];stack[A + 3] = nil; PC = PC + args[15706896];args = regs[PC + 6];PC = PC + 6;goto RESET;
									else
										if OP > 0x0A4EC4F then
											A=args[1603413];if stack[A+4]~=nil then stack[A+2]=stack[A+4]PC=PC-args[15706896] end;
										else
											stack[args[1603413]] = nil;args = regs[PC + 1];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 2];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 3];stack[args[1603413]] = ({});args = regs[PC + 4];args = regs[PC + 5];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 6];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 7];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 8];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 9];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 10];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 11];A = args[1603413]; C = args[9718070]; for i = 1, args[4859677] do stack[A][C + i] = stack[A + i]; end;args = regs[PC + 12];stack[args[1603413]] = constants[args[15706896]];args = regs[PC + 13];stack[args[1603413]] = ENV[constants[args[9718070]]];args = regs[PC + 14];stack[args[1603413]] = stack[args[4859677]];args = regs[PC + 15];A = args[1603413];retlist = {stack[A](stack[A + 1])}; args = regs[PC + 16];stack[args[1603413]] = ENV[constants[args[9718070]]];args = regs[PC + 17];stack[args[1603413]] = stack[args[4859677]];args = regs[PC + 18];A = args[1603413];retlist = {stack[A](stack[A + 1])}; args = regs[PC + 19];stack[args[1603413]] = ENV[constants[args[9718070]]];args = regs[PC + 20];PC = PC + 20;goto RESET;
										end
									end
								end
							end
						else
							if OP <= 0x0D3601E then
								if OP <= 0x0BDDD14 then
									if OP == 0x0B5349C then
										
									else
										stack[args[1603413]] = args[8525831];
									end
								else
									if OP == 0x0C15A36 then
										stack[args[1603413]] = stack[args[4859677]] + args[9718070];
									else
										A=args[1603413];stack[A+4],stack[A+5],stack[A+3+args[9718070]]=stack[A](stack[A+1],stack[A+2]);
									end
								end
							else
								if OP <= 0x0EF92F7 then
									if OP == 0x0E2C2D4 then
										stack[args[1603413]] = ENV[constants[args[9718070]]];args = regs[PC + 1];stack[args[1603413]] = stack[args[4859677]][constants[args[9718070]]];args = regs[PC + 2];stack[args[1603413]] = stack[args[4859677]];args = regs[PC + 3];A = args[1603413];retlist = {stack[A](stack[A + 1])}; args = regs[PC + 4];stack[args[1603413]] = ({});args = regs[PC + 5];args = regs[PC + 6];stack[args[1603413]] = ENV[constants[args[9718070]]];args = regs[PC + 7];stack[args[1603413]] = stack[args[4859677]];args = regs[PC + 8];A = args[1603413];retlist = {stack[A](stack[A + 1])}; retnum = args[9718070]; move(retlist, 1, retnum, A, stack);args = regs[PC + 9];stack[A + 3] = nil; PC = PC + args[15706896];args = regs[PC + 10];PC = PC + 10;goto RESET;
									else
										stack[args[1603413]] = stack[args[4859677]][stack[args[9718070]]];
									end
								else
									if OP <= 0x0F8BDD9 then
										A=args[1603413];stack[A+4],stack[A+5],stack[A+3+args[9718070]]=stack[A](stack[A+1],stack[A+2]);
									else
										if OP == 0x0FB7677 then
											stack[args[1603413]][stack[args[4859677]]] = stack[args[9718070]];
										else
											stack[args[1603413]] = #(stack[args[4859677]]);
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
