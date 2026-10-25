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
    local code = "00003766FA5C010B000001140000818020030000942044000081A0400B0000091400008990200300009C3044000089B0400B00001114000091A020030000A44044000091C0400E00009980A001130000A13052000006120000A1E0E001120000A180A102120000A1A0E1024F00002CF7E88EB1808003725C2EB1E0A003030000BCE001440000B1F0400E0000B9C0C002030000C48002350000B920120000B1F0E101120000B190C2040B0000B9808005120000B1B0E201000000B9500E0000C1B0A005440000B980410B0000C180C005030000CCF0020E0000D1F080060E0000D9F0A0060E0000E1E0E003440000C1C02101000045A2A95749E21326D190C0063F4895D1A0E106264039E410F78AB0D1C04145298DC9A001140000D1A08007030000E4D003440000D1C041140000D9A0C107030000ECF003010000F5A005440000D9E021460000D9A0212000000004043D00080B040A1D04113D041E191A390404070A0D0417041E1C040A08140B3D041E191A3904041108041502080F0E073F05361A0E1E0E143F040B160E060F0D3C031223041704052911000B0503180000000000000004043014081E03320000000000000004053600070B0D040B0B140C0D0A3F061F2C04170408130F161A00020C16040334041204040A00171A04041400080B040617001705041E04081B0F06060E1E0A171104060A00170B0F1804092D0E1705121C0E103F04091909041C000F1B162804052A130C0015040A390E0B08080B1A013F0504090D000905321C0A163E04091014081E310318162804091204041C150E0A122E0407190E0B00040F1B040C0D000C1A27031D303208090A0406080408011509040A1C08170B32091D053F130405320409020E0100000001000200000001000911C249090300009C1044000089B0400B000091806012000089A0400B00009180A00112000089C0404800008920470000911006000000040C0D000C1A27031D303208090A04081214080F0F03061704090D000905321C0A163E04052911000B0504091014081E310318162804043014081E0100000001040000000001000F14DDBD091500008B9080202F00008980D0010A000009090000094100008AA010F792EF47897E0F8910334D3D891044000089A0200B000089A02003000094200900001944000089B020470000891003000000040A1E08160D0E020116391504052A130C0015040E3204041C150E0A122E4101010F090300000001080109000000000000"
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

            return {[10808400] = opcode, [5394029] = A, [1692106] = B, [10225557] = C}
        elseif format == 2 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = ((instruction >> Bshift) & 0xFF) - 127
            --assert(B == (instruction // 2 ^ 23))
            C = (instruction >> Cshift) & 0xFF

            return {[10808400] = opcode, [5394029] = A, [1692106] = B, [10225557] = C}
        elseif format == 3 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = (instruction >> Bshift) & 0xFF
            --assert(B == (instruction // 2 ^ 23))
            C = ((instruction >> Cshift) & 0xFF) - 127

            return {[10808400] = opcode, [5394029] = A, [1692106] = B, [10225557] = C}
        elseif format == 4 then
            A = (instruction >> Ashift) & 0xFF
            Bx = (instruction >> Bxshift) & 0xFFFF

            return {[10808400] = opcode, [5394029] = A, [15587317] = Bx}
        elseif format == 5 then
            A = (instruction >> Ashift) & 0xFF
            sBx = convertValue((instruction >> sBxshift) & 0xFFFF, 16)

            return {[10808400] = opcode, [5394029] = A, [14432639] = sBx}
        elseif format == 6 then
            Ax = instruction >> Ashift & 0x1FFFFFF

            return {[10808400] = opcode, [7344452] = Ax,}
        elseif format == 7 then
            sJ = convertValue(instruction >> Ashift & 0x1FFFFFF, 24)

            return {[10808400] = opcode, [7493020] = sJ,}
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
					OP, args = instructions[PC][10808400], regs[PC]
					if OP <= 0x057A9A2 then
						if OP <= 0x02E5C72 then
							if OP <= 0x00F7E89 then
								uv = upvalues[args[1692106]]; stack[args[5394029]] = uv.store[uv.index];
							else
								if OP == 0x02613E2 then
									stack[args[5394029]] = stack[args[1692106]][constants[args[10225557]]];
								else
									stack[args[5394029]] = stack[args[1692106]][constants[args[10225557]]];args = regs[PC + 1];stack[args[5394029]] = constants[args[15587317]];args = regs[PC + 2];A = args[5394029];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 3];stack[args[5394029]] = stack[args[1692106]][constants[args[10225557]]];args = regs[PC + 4];stack[args[5394029]] = constants[args[15587317]];args = regs[PC + 5];A=args[5394029];result={}for a=A,A+args[1692106]-1 do insert(result,stack[a])end;stack[args[5394029]]=concat(result);args = regs[PC + 6];stack[args[5394029]][constants[args[1692106]]] = stack[args[10225557]];args = regs[PC + 7];stack[args[5394029]][constants[args[1692106]]] = constants[args[10225557]];args = regs[PC + 8];stack[args[5394029]] = ENV[constants[args[10225557]]];args = regs[PC + 9];stack[args[5394029]][constants[args[1692106]]] = stack[args[10225557]];args = regs[PC + 10];stack[args[5394029]] = stack[args[1692106]];args = regs[PC + 11];stack[args[5394029]] = stack[args[1692106]][constants[args[10225557]]];args = regs[PC + 12];A = args[5394029];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 13];stack[args[5394029]] = ENV[constants[args[10225557]]];args = regs[PC + 14];stack[args[5394029]] = constants[args[15587317]];args = regs[PC + 15];stack[args[5394029]] = stack[args[1692106]][constants[args[10225557]]];args = regs[PC + 16];stack[args[5394029]] = stack[args[1692106]][constants[args[10225557]]];args = regs[PC + 17];stack[args[5394029]] = stack[args[1692106]][constants[args[10225557]]];args = regs[PC + 18];A = args[5394029];retlist = {stack[A](unpack(stack, A + 1, args[1692106]))}; args = regs[PC + 19];stack[args[5394029]] = args[14432639];args = regs[PC + 20];PC = PC + 20;goto RESET;
								end
							end
						else
							if OP <= 0x03D4D33 then
								if OP == 0x0394026 then
									proto = protos[args[15587317]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[5394029]]=lua_wrap_state(proto,ENV,uvlist);
								else
									A = args[5394029]; B = args[1692106]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[10225557]]];args = regs[PC + 1];A = args[5394029];retlist = {stack[A](stack[A + 1])}; args = regs[PC + 2];stack[args[5394029]] = ENV[constants[args[10225557]]];args = regs[PC + 3];stack[args[5394029]] = constants[args[15587317]];args = regs[PC + 4];uv = upvalues[args[1692106]]; stack[args[5394029]] = uv.store[uv.index];args = regs[PC + 5];A = args[5394029];retlist = {stack[A](unpack(stack, A + 1, args[1692106]))}; args = regs[PC + 6];do return end;args = regs[PC + 7];PC = PC + 7;goto RESET;
								end
							else
								if OP > 0x049C211 then
									for i = args[1692106], 0, -1 do stack[i + args[5394029]] = nil; end;
								else
									A = args[5394029]; B = args[1692106]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[10225557]]];args = regs[PC + 1];stack[args[5394029]] = constants[args[15587317]];args = regs[PC + 2];A = args[5394029];retlist = {stack[A](unpack(stack, A + 1, args[1692106]))}; stack[A] = retlist[1];args = regs[PC + 3];stack[args[5394029]] = ENV[constants[args[10225557]]];args = regs[PC + 4];stack[args[5394029]][constants[args[1692106]]] = stack[args[10225557]];args = regs[PC + 5];stack[args[5394029]] = ENV[constants[args[10225557]]];args = regs[PC + 6];stack[args[5394029]][constants[args[1692106]]] = stack[args[10225557]];args = regs[PC + 7];do return stack[args[5394029]]; end;args = regs[PC + 8];do return end;args = regs[PC + 9];PC = PC + 9;goto RESET;
								end
							end
						end
					else
						if OP <= 0x08EE8F7 then
							if OP <= 0x05CFA66 then
								stack[args[5394029]] = nil;args = regs[PC + 1];stack[args[5394029]] = ENV[constants[args[10225557]]];args = regs[PC + 2];A = args[5394029]; B = args[1692106]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[10225557]]];args = regs[PC + 3];stack[args[5394029]] = constants[args[15587317]];args = regs[PC + 4];A = args[5394029];retlist = {stack[A](unpack(stack, A + 1, args[1692106]))}; stack[A] = retlist[1];args = regs[PC + 5];stack[args[5394029]] = ENV[constants[args[10225557]]];args = regs[PC + 6];A = args[5394029]; B = args[1692106]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[10225557]]];args = regs[PC + 7];stack[args[5394029]] = constants[args[15587317]];args = regs[PC + 8];A = args[5394029];retlist = {stack[A](unpack(stack, A + 1, args[1692106]))}; stack[A] = retlist[1];args = regs[PC + 9];stack[args[5394029]] = ENV[constants[args[10225557]]];args = regs[PC + 10];A = args[5394029]; B = args[1692106]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[10225557]]];args = regs[PC + 11];stack[args[5394029]] = constants[args[15587317]];args = regs[PC + 12];A = args[5394029];retlist = {stack[A](unpack(stack, A + 1, args[1692106]))}; stack[A] = retlist[1];args = regs[PC + 13];stack[args[5394029]] = stack[args[1692106]][constants[args[10225557]]];args = regs[PC + 14];stack[args[5394029]] = ({});args = regs[PC + 15];args = regs[PC + 16];stack[args[5394029]][constants[args[1692106]]] = constants[args[10225557]];args = regs[PC + 17];stack[args[5394029]][constants[args[1692106]]] = constants[args[10225557]];args = regs[PC + 18];stack[args[5394029]][constants[args[1692106]]] = constants[args[10225557]];args = regs[PC + 19];proto = protos[args[15587317]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[5394029]]=lua_wrap_state(proto,ENV,uvlist);args = regs[PC + 20];PC = PC + 20;goto RESET;
							else
								if OP > 0x08D2945 then
									stack[args[5394029]] = ENV[constants[args[10225557]]];
								else
									stack[args[5394029]] = stack[args[1692106]];args = regs[PC + 1];A = args[5394029]; B = args[1692106]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[10225557]]];args = regs[PC + 2];stack[args[5394029]] = constants[args[15587317]];args = regs[PC + 3];A = args[5394029];retlist = {stack[A](unpack(stack, A + 1, args[1692106]))}; stack[A] = retlist[1];args = regs[PC + 4];A = args[5394029]; B = args[1692106]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[10225557]]];args = regs[PC + 5];stack[args[5394029]] = constants[args[15587317]];args = regs[PC + 6];stack[args[5394029]] = args[14432639];args = regs[PC + 7];A = args[5394029];retlist = {stack[A](unpack(stack, A + 1, args[1692106]))}; args = regs[PC + 8];A = args[5394029];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[1692106]); end;args = regs[PC + 9];PC = PC + 9;goto RESET;
								end
							end
						else
							if OP <= 0x0B08AF7 then
								if OP > 0x095483F then
									A = args[5394029];retlist = {stack[A](unpack(stack, A + 1, args[1692106]))}; stack[A] = retlist[1];
								else
									A = args[5394029]; B = args[1692106]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[10225557]]];
								end
							else
								if OP > 0x0BDDD14 then
									PC = PC + args[7493020]; goto RESET;
								else
									uv = upvalues[args[1692106]]; stack[args[5394029]] = uv.store[uv.index];args = regs[PC + 1];stack[args[5394029]] = stack[args[1692106]] + args[10225557];args = regs[PC + 2];args = regs[PC + 3];uv = upvalues[args[1692106]]; uv.store[uv.index] = stack[args[5394029]];args = regs[PC + 4];uv = upvalues[args[1692106]]; stack[args[5394029]] = uv.store[uv.index];args = regs[PC + 5];if ((stack[args[5394029]] >= args[1692106]) ~= false) then PC = PC + 1 end;args = regs[PC + 6];PC = PC + 6;goto RESET;
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
