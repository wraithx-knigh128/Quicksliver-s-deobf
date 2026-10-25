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
    local code = "000055B08DA201F7E88E04725C2E8C10A2A95711E2132699103F4895A42026403999C040F78AB0913045298D9C3066FA5CA440F792EFAC50897E0F31334D3DBDA001010000C550440000B180410B000039000000C160440000C19040000000C960440000C99040000000D160440000D110440000B980200B000039000000C120010000CDE003440000C19041000000C920010000D58005440000C9A001440000B980204F0000BC6014DDBDC47011C249499C34B5D130000000D970000000E18001440000D1C041010000DD50440000D1B041000000D930000000E18001000000E970440000D9D041010000E550440000D9C001440000C980200B0000490B0000D180200E0000D1A041000000D940130000E180800152000006010000ED10010000F520010000FD3001000085414E0000E1404F0000EC80017776FBD9D041D9BDF8E430440000D1C001440000C980200B000049000000D150010000DD10010000E520010000ED30010000F540010000FD50440000D1F041000000D950440000D910440000C980204F0000CC9001D9FD2251D7563FD99001010000E510440000D9C041010000E520440000D9C041010000E530440000D9C001440000D18020460000D190210400000004052A130C001504052E000702040406390E0B0D00180401760100000001000A0000000200047E39461169BCCD1CC3C5A19930F3EB27992000000000000000000100000000000816E82F01090000891022000081102E00008190C0010A0000010900000148000081204700008110000000000200000001020101000000000100051E60D309CCCD4606365AC114834B5691200BE87A911000000000000000000100000001000CF11627096B814189109E075A09D4C2E23F9860FC911048B3661944000091B0400000008920090000111000009180204800008920CD60759110010000000002000000010101000000000001000F94079C8290103B9014175F857A81204FECA4096C4E529380C01FC9D1198180F00144000089A040090000111500009B80A01F2F00008190F00144000091B04022000089A0202E000089A0C001480000892047000089100000000001000000010200000000000008431170011300000152000006500000094E0000014F00000CF4D7ED8990207E39DC89802000000000000000000100000001000D416D0A09340000891001000095100100009DF0FF3F4A00008C509B557229CCC6DAA9D0800131B7EE3163184FA9E04057392981507F67B08C609E31558120CC2ADC891000000000010000000100000000000200107173EA11520000060B0000190000002144000099C080014B00009C501DE0A9C910B12110D18001E48D82D97098F48EC9B041F49C5491F0A0029876789980400252309C7081A37E1907D30291208198C3992001000000040633110407131F0100000000000000000000001250689E01010000050100008D100B0000110300009C10500000214400009180400100009D104A00008C60F5FE592940B6E1B14050000039440000A9804022000081502E000081D0C0017E59D58C70922E96818020C02EF88980200200000004062904090B021804017901000000000000000000010004C665B28B808020EFFDE88180D001CA237389206A05E4891000000000000000000000000001000478E56609F51800818080026207D7892028CBFD8910010000000302000000000000000000000000000000020004E2404881904018E328819080027A94239120F4C7FD91100000000000000000000000000100039130180C1DD0E58910BC87DA911000000000000000000100000001000384DC650C6FED1889106A1BF79110000000000100000001000100000001000C96CB22091800008980203000008980800209000091101800009190403000009190800222000089A0202E000089A0C0012200008980202E00008980C0011A07B68920F81EC4891002000000036400000000000000030A00000000000000020000000000010000000000"
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

            return {[15829494] = opcode, [14067917] = A, [3719341] = B, [11930509] = C}
        elseif format == 2 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = ((instruction >> Bshift) & 0xFF) - 127
            --assert(B == (instruction // 2 ^ 23))
            C = (instruction >> Cshift) & 0xFF

            return {[15829494] = opcode, [14067917] = A, [3719341] = B, [11930509] = C}
        elseif format == 3 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = (instruction >> Bshift) & 0xFF
            --assert(B == (instruction // 2 ^ 23))
            C = ((instruction >> Cshift) & 0xFF) - 127

            return {[15829494] = opcode, [14067917] = A, [3719341] = B, [11930509] = C}
        elseif format == 4 then
            A = (instruction >> Ashift) & 0xFF
            Bx = (instruction >> Bxshift) & 0xFFFF

            return {[15829494] = opcode, [14067917] = A, [9132680] = Bx}
        elseif format == 5 then
            A = (instruction >> Ashift) & 0xFF
            sBx = convertValue((instruction >> sBxshift) & 0xFFFF, 16)

            return {[15829494] = opcode, [14067917] = A, [13481583] = sBx}
        elseif format == 6 then
            Ax = instruction >> Ashift & 0x1FFFFFF

            return {[15829494] = opcode, [10229273] = Ax,}
        elseif format == 7 then
            sJ = convertValue(instruction >> Ashift & 0x1FFFFFF, 24)

            return {[15829494] = opcode, [4005309] = sJ,}
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
					OP, args = instructions[PC][15829494], regs[PC]
					if OP <= 0x07A855F then
						if OP <= 0x03F56D7 then
							if OP <= 0x022FDD9 then
								if OP <= 0x01021B1 then
									if OP <= 0x002D307 then
										if OP == 0x00018F5 then
											
										else
											A = args[14067917];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[3719341]); end;
										end
									else
										if OP <= 0x00A6D41 then
											uv = upvalues[args[3719341]]; stack[args[14067917]] = uv.store[uv.index];args = regs[PC + 1];stack[args[14067917]] = #(stack[args[3719341]]);args = regs[PC + 2];stack[args[14067917]] = args[13481583];args = regs[PC + 3];stack[args[14067917]] = args[13481583];args = regs[PC + 4];A=args[14067917];init=stack[A]limit=stack[A+1]step=stack[A+2]stack[A]=init-step;stack[A+1]=limit;stack[A+2]=step;stack[A+3]=init;PC=PC+args[9132680];args = regs[PC + 5];PC = PC + 5;goto RESET;
										else
											if OP > 0x00F7E89 then
												stack[args[14067917]] = stack[args[3719341]];
											else
												stack[args[14067917]] = stack[args[3719341]];
											end
										end
									end
								else
									if OP <= 0x018ED6F then
										if OP <= 0x014903B then
											PC = PC + args[4005309]; goto RESET;
										else
											if OP == 0x0183091 then
												proto = protos[args[9132680]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[14067917]]=lua_wrap_state(proto,ENV,uvlist);
											else
												A = args[14067917];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[3719341]); end;
											end
										end
									else
										if OP <= 0x019D1C9 then
											args = regs[PC + 1];A = args[14067917];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 2];uv = upvalues[args[3719341]]; stack[args[14067917]] = uv.store[uv.index];args = regs[PC + 3];stack[args[14067917]] = stack[args[3719341]] + args[11930509];args = regs[PC + 4];args = regs[PC + 5];A = args[14067917];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 6];stack[args[11930509]] = stack[args[14067917]] + stack[args[3719341]];args = regs[PC + 7];args = regs[PC + 8];do return stack[args[14067917]]; end;args = regs[PC + 9];do return end;args = regs[PC + 10];PC = PC + 10;goto RESET;
										else
											if OP > 0x022CB96 then
												stack[args[14067917]] = ENV[constants[args[11930509]]];
											else
												uv = upvalues[args[3719341]]; stack[args[14067917]] = uv.store[uv.index];args = regs[PC + 1];stack[args[14067917]] = stack[args[11930509]] * constants[args[3719341]];args = regs[PC + 2];args = regs[PC + 3];uv = upvalues[args[3719341]]; stack[args[14067917]] = uv.store[uv.index];args = regs[PC + 4];stack[args[14067917]] = stack[args[11930509]] * constants[args[3719341]];args = regs[PC + 5];args = regs[PC + 6];stack[args[11930509]] = stack[args[14067917]] + stack[args[3719341]];args = regs[PC + 7];args = regs[PC + 8];stack[args[11930509]] = stack[args[14067917]] + stack[args[3719341]];args = regs[PC + 9];args = regs[PC + 10];PC = PC + 10;goto RESET;
											end
										end
									end
								end
							else
								if OP <= 0x0293957 then
									if OP <= 0x02716F1 then
										if OP <= 0x023947A then
											do return stack[args[14067917]]; end;
										else
											if OP > 0x02613E2 then
												uv = upvalues[args[3719341]]; stack[args[14067917]] = uv.store[uv.index];
											else
												stack[args[14067917]] = stack[args[3719341]];
											end
										end
									else
										if OP <= 0x027EBF3 then
											A = args[14067917];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[3719341]); end;
										else
											if OP == 0x028E318 then
												
											else
												stack[args[14067917]] = stack[args[3719341]];
											end
										end
									end
								else
									if OP <= 0x0305202 then
										if OP <= 0x02E5C72 then
											proto = protos[args[9132680]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[14067917]]=lua_wrap_state(proto,ENV,uvlist);
										else
											if OP == 0x02FE816 then
												uv = upvalues[args[3719341]]; stack[args[14067917]] = uv.store[uv.index];args = regs[PC + 1];uv = upvalues[args[3719341]]; stack[args[14067917]] = uv.store[uv.index];args = regs[PC + 2];stack[args[11930509]] = stack[args[14067917]] + stack[args[3719341]];args = regs[PC + 3];args = regs[PC + 4];uv = upvalues[args[3719341]]; uv.store[uv.index] = stack[args[14067917]];args = regs[PC + 5];uv = upvalues[args[3719341]]; stack[args[14067917]] = uv.store[uv.index];args = regs[PC + 6];do return stack[args[14067917]]; end;args = regs[PC + 7];do return end;args = regs[PC + 8];PC = PC + 8;goto RESET;
											else
												A=args[14067917];if stack[A+4]~=nil then stack[A+2]=stack[A+4]PC=PC-args[9132680] end;
											end
										end
									else
										if OP <= 0x0394026 then
											A = args[14067917];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];
										else
											if OP > 0x03D4D33 then
												stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 1];stack[args[14067917]] = args[13481583];args = regs[PC + 2];A = args[14067917];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 3];stack[args[14067917]] = args[13481583];args = regs[PC + 4];A = args[14067917];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 5];stack[args[14067917]] = args[13481583];args = regs[PC + 6];A = args[14067917];retlist = {stack[A](stack[A + 1])}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 7];A = args[14067917];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 8];A = args[14067917];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[3719341]); end;args = regs[PC + 9];PC = PC + 9;goto RESET;
											else
												stack[args[14067917]] = args[13481583];args = regs[PC + 1];stack[args[14067917]] = args[13481583];args = regs[PC + 2];A = args[14067917];retlist = {stack[A](unpack(stack, A + 1, args[3719341]))}; stack[A] = retlist[1];args = regs[PC + 3];stack[args[14067917]] = ENV[constants[args[11930509]]];args = regs[PC + 4];stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 5];A = args[14067917];retlist = {stack[A]()}; stack[A] = retlist[1];args = regs[PC + 6];stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 7];A = args[14067917];retlist = {stack[A]()}; stack[A] = retlist[1];args = regs[PC + 8];stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 9];A = args[14067917];retlist = {stack[A]()}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 10];A = args[14067917];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 11];stack[args[14067917]] = ENV[constants[args[11930509]]];args = regs[PC + 12];stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 13];stack[args[14067917]] = args[13481583];args = regs[PC + 14];A = args[14067917];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 15];stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 16];stack[args[14067917]] = args[13481583];args = regs[PC + 17];A = args[14067917];retlist = {stack[A](stack[A + 1])}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 18];A = args[14067917];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 19];proto = protos[args[9132680]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[14067917]]=lua_wrap_state(proto,ENV,uvlist);args = regs[PC + 20];PC = PC + 20;goto RESET;
											end
										end
									end
								end
							end
						else
							if OP <= 0x057A9A2 then
								if OP <= 0x049C211 then
									if OP <= 0x046397E then
										if OP > 0x041816B then
											stack[args[14067917]] = stack[args[3719341]];
										else
											stack[args[14067917]] = stack[args[3719341]][stack[args[11930509]]];
										end
									else
										if OP <= 0x046CDCC then
											
										else
											if OP == 0x04840E2 then
												stack[args[11930509]] = stack[args[14067917]] * stack[args[3719341]];
											else
												stack[args[14067917]] = ENV[constants[args[11930509]]];
											end
										end
									end
								else
									if OP <= 0x0549CF4 then
										if OP <= 0x04F1863 then
											A = args[14067917];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];
										else
											if OP > 0x0524E6C then
												stack[args[14067917]][stack[args[3719341]]] = stack[args[11930509]];
											else
												stack[args[14067917]] = stack[args[3719341]] + args[11930509];
											end
										end
									else
										if OP <= 0x055319E then
											do return stack[args[14067917]]; end;
										else
											if OP == 0x0564B83 then
												A = args[14067917];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[3719341]); end;
											else
												for i = args[3719341], 0, -1 do stack[i + args[14067917]] = nil; end;
											end
										end
									end
								end
							else
								if OP <= 0x066E578 then
									if OP <= 0x05CFA66 then
										if OP <= 0x059FEF5 then
											stack[args[14067917]] = ENV[constants[args[11930509]]];
										else
											if OP > 0x05A079E then
												proto = protos[args[9132680]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[14067917]]=lua_wrap_state(proto,ENV,uvlist);
											else
												if ((stack[args[14067917]] == constants[args[3719341]]) ~= false) then PC = PC + 1 end;
											end
										end
									else
										if OP <= 0x065DC84 then
											proto = protos[args[9132680]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[14067917]]=lua_wrap_state(proto,ENV,uvlist);
										else
											if OP == 0x066B348 then
												stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 1];A = args[14067917];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 2];stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 3];uv = upvalues[args[3719341]]; stack[args[14067917]] = uv.store[uv.index];args = regs[PC + 4];stack[args[14067917]][stack[args[3719341]]] = stack[args[11930509]];args = regs[PC + 5];do return stack[args[14067917]]; end;args = regs[PC + 6];PC = PC + 6;goto RESET;
											else
												stack[args[14067917]] = stack[args[11930509]] * constants[args[3719341]];
											end
										end
									end
								else
									if OP <= 0x07323CA then
										if OP <= 0x0701143 then
											stack[args[14067917]] = nil;args = regs[PC + 1];stack[args[14067917]] = ({});args = regs[PC + 2];args = regs[PC + 3];A = args[14067917]; C = args[11930509];C = vararg.len; top = A + C - 1; move(vararg.list, 1, C, A, stack);args = regs[PC + 4];A = args[14067917]; C = args[11930509]; for i = 1, args[3719341] do stack[A][C + i] = stack[A + i]; end;args = regs[PC + 5];proto = protos[args[9132680]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[14067917]]=lua_wrap_state(proto,ENV,uvlist);args = regs[PC + 6];PC = PC + 6;goto RESET;
										else
											if OP == 0x072559B then
												uv = upvalues[args[3719341]]; stack[args[14067917]] = uv.store[uv.index];
											else
												do return stack[args[14067917]]; end;
											end
										end
									else
										if OP <= 0x07560CD then
											do return end;
										else
											if OP > 0x0787698 then
												do return stack[args[14067917]]; end;
											else
												A=args[14067917];stack[A+4],stack[A+5],stack[A+3+args[11930509]]=stack[A](stack[A+1],stack[A+2]);
											end
										end
									end
								end
							end
						end
					else
						if OP <= 0x0C41EF8 then
							if OP <= 0x0A1C5C3 then
								if OP <= 0x08EE8F7 then
									if OP <= 0x07EA381 then
										if OP > 0x07AE80B then
											close_lua_upvalues(openlist, args[14067917]);
										else
											A = args[14067917];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[3719341]); end;
										end
									else
										if OP <= 0x0828DE4 then
											stack[args[14067917]] = stack[args[3719341]];
										else
											if OP == 0x08D2945 then
												proto = protos[args[9132680]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[14067917]]=lua_wrap_state(proto,ENV,uvlist);
											else
												proto = protos[args[9132680]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[14067917]]=lua_wrap_state(proto,ENV,uvlist);
											end
										end
									end
								else
									if OP <= 0x0962E92 then
										if OP <= 0x08EF498 then
											A = args[14067917];retlist = {stack[A](unpack(stack, A + 1, args[3719341]))}; stack[A] = retlist[1];
										else
											if OP == 0x095483F then
												proto = protos[args[9132680]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[14067917]]=lua_wrap_state(proto,ENV,uvlist);
											else
												A = args[14067917];do return unpack(stack, A, args[3719341]); end;
											end
										end
									else
										if OP <= 0x09C0794 then
											if ((stack[args[14067917]] < args[3719341]) ~= false) then PC = PC + 1; end;
										else
											if OP > 0x09E6850 then
												A = args[14067917];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[3719341]); end;
											else
												stack[args[14067917]] = nil;args = regs[PC + 1];stack[args[14067917]] = args[13481583];args = regs[PC + 2];stack[args[14067917]] = args[13481583];args = regs[PC + 3];stack[args[14067917]] = ENV[constants[args[11930509]]];args = regs[PC + 4];stack[args[14067917]] = constants[args[9132680]];args = regs[PC + 5];A = args[14067917]; C = args[11930509];C = vararg.len; top = A + C - 1; move(vararg.list, 1, C, A, stack);args = regs[PC + 6];A = args[14067917];retlist = {stack[A](unpack(stack, A + 1, top))}; stack[A] = retlist[1];args = regs[PC + 7];stack[args[14067917]] = args[13481583];args = regs[PC + 8];A=args[14067917];init=stack[A]limit=stack[A+1]step=stack[A+2]stack[A]=init-step;stack[A+1]=limit;stack[A+2]=step;stack[A+3]=init;PC=PC+args[9132680];args = regs[PC + 9];PC = PC + 9;goto RESET;
											end
										end
									end
								end
							else
								if OP <= 0x0B265C6 then
									if OP <= 0x0A9E01D then
										if OP <= 0x0A28DB0 then
											stack[args[14067917]] = nil;
										else
											if OP > 0x0A4EC4F then
												stack[args[14067917]] = stack[args[3719341]];
											else
												uv = upvalues[args[3719341]]; stack[args[14067917]] = uv.store[uv.index];
											end
										end
									else
										if OP <= 0x0B0677F then
											A=args[14067917];limit=stack[A+1]step=stack[A+2]index=stack[A]index=index+step;stack[A]=index;if step>0 and index<=limit or step<=0 and index>=limit then stack[A+3]=index;PC=PC-args[9132680] end;
										else
											if OP == 0x0B08AF7 then
												stack[args[14067917]] = stack[args[3719341]];
											else
												stack[args[14067917]] = stack[args[3719341]] + args[11930509];
											end
										end
									end
								else
									if OP <= 0x0BDDD14 then
										if OP <= 0x0B5349C then
											stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 1];stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 2];stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 3];A = args[14067917];retlist = {stack[A](unpack(stack, A + 1, args[3719341]))}; stack[A] = retlist[1];args = regs[PC + 4];stack[args[14067917]] = args[13481583];args = regs[PC + 5];A = args[14067917];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 6];stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 7];stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 8];stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 9];A = args[14067917];retlist = {stack[A](unpack(stack, A + 1, args[3719341]))}; stack[A] = retlist[1];args = regs[PC + 10];stack[args[14067917]] = args[13481583];args = regs[PC + 11];A = args[14067917];retlist = {stack[A](stack[A + 1])}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 12];A = args[14067917];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 13];stack[args[14067917]] = ENV[constants[args[11930509]]];args = regs[PC + 14];stack[args[14067917]] = ENV[constants[args[11930509]]];args = regs[PC + 15];stack[args[14067917]] = stack[args[3719341]][constants[args[11930509]]];args = regs[PC + 16];stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 17];stack[args[14067917]] = ({});args = regs[PC + 18];args = regs[PC + 19];stack[args[14067917]] = args[13481583];args = regs[PC + 20];stack[args[14067917]] = args[13481583];args = regs[PC + 21];stack[args[14067917]] = args[13481583];args = regs[PC + 22];stack[args[14067917]] = args[13481583];args = regs[PC + 23];A = args[14067917]; C = args[11930509]; for i = 1, args[3719341] do stack[A][C + i] = stack[A + i]; end;args = regs[PC + 24];proto = protos[args[9132680]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[14067917]]=lua_wrap_state(proto,ENV,uvlist);args = regs[PC + 25];PC = PC + 25;goto RESET;
										else
											if OP == 0x0B6071A then
												do return stack[args[14067917]]; end;
											else
												proto = protos[args[9132680]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[14067917]]=lua_wrap_state(proto,ENV,uvlist);
											end
										end
									else
										if OP <= 0x0C15A36 then
											proto = protos[args[9132680]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[14067917]]=lua_wrap_state(proto,ENV,uvlist);
										else
											if OP > 0x0C39881 then
												do return end;
											else
												A = args[14067917];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[3719341]); end;
											end
										end
									end
								end
							end
						else
							if OP <= 0x0E5D01D then
								if OP <= 0x0DAC6CC then
									if OP <= 0x0D5597E then
										if OP <= 0x0CDBC69 then
											proto = protos[args[9132680]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[14067917]]=lua_wrap_state(proto,ENV,uvlist);
										else
											if OP > 0x0D3601E then
												A=args[14067917];limit=stack[A+1]step=stack[A+2]index=stack[A]index=index+step;stack[A]=index;if step>0 and index<=limit or step<=0 and index>=limit then stack[A+3]=index;PC=PC-args[9132680] end;
											else
												stack[args[14067917]] = ({});
											end
										end
									else
										if OP <= 0x0D70762 then
											do return stack[args[14067917]]; end;
										else
											if OP > 0x0DA87BC then
												stack[args[14067917]] = stack[args[3719341]][stack[args[11930509]]];
											else
												A = args[14067917];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[3719341]); end;
											end
										end
									end
								else
									if OP <= 0x0E1B640 then
										if OP <= 0x0DC2ACC then
											do return end;
										else
											if OP == 0x0DC397E then
												A = args[14067917];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[3719341]); end;
											else
												stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 1];A = args[14067917]; C = args[11930509];C = vararg.len; top = A + C - 1; move(vararg.list, 1, C, A, stack);args = regs[PC + 2];A = args[14067917];retlist = {stack[A](unpack(stack, A + 1, top))}; stack[A] = retlist[1];args = regs[PC + 3];stack[args[11930509]] = stack[args[14067917]] + stack[args[3719341]];args = regs[PC + 4];args = regs[PC + 5];PC = PC + 5;goto RESET;
											end
										end
									else
										if OP <= 0x0E2C2D4 then
											PC = PC + args[4005309]; goto RESET;
										else
											if OP > 0x0E4056A then
												A = args[14067917];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[3719341]); end;
											else
												do return end;
											end
										end
									end
								end
							else
								if OP <= 0x0F71B6A then
									if OP <= 0x0EDD7F4 then
										if OP <= 0x0E8FDEF then
											
										else
											if OP == 0x0EA7371 then
												stack[args[14067917]] = ({});args = regs[PC + 1];args = regs[PC + 2];stack[args[14067917]] = ENV[constants[args[11930509]]];args = regs[PC + 3];stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 4];A = args[14067917];retlist = {stack[A](stack[A + 1])}; retnum = args[11930509]; move(retlist, 1, retnum, A, stack);args = regs[PC + 5];stack[A + 3] = nil; PC = PC + args[9132680];args = regs[PC + 6];PC = PC + 6;goto RESET;
											else
												A = args[14067917];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[3719341]); end;
											end
										end
									else
										if OP <= 0x0EEB731 then
											stack[args[14067917]] = stack[args[3719341]];
										else
											if OP == 0x0EF92F7 then
												proto = protos[args[9132680]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[14067917]]=lua_wrap_state(proto,ENV,uvlist);
											else
												A = args[14067917];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[3719341]); end;
											end
										end
									end
								else
									if OP <= 0x0FB7677 then
										if OP <= 0x0F82EC0 then
											A = args[14067917];do return unpack(stack, A, args[3719341]); end;
										else
											if OP == 0x0F8BDD9 then
												stack[args[14067917]] = constants[args[9132680]];args = regs[PC + 1];A = args[14067917];retlist = {stack[A](unpack(stack, A + 1, args[3719341]))}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 2];A = args[14067917];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 3];stack[args[14067917]] = ENV[constants[args[11930509]]];args = regs[PC + 4];stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 5];stack[args[14067917]] = args[13481583];args = regs[PC + 6];stack[args[14067917]] = args[13481583];args = regs[PC + 7];stack[args[14067917]] = args[13481583];args = regs[PC + 8];stack[args[14067917]] = args[13481583];args = regs[PC + 9];stack[args[14067917]] = args[13481583];args = regs[PC + 10];A = args[14067917];retlist = {stack[A](unpack(stack, A + 1, args[3719341]))}; stack[A] = retlist[1];args = regs[PC + 11];stack[args[14067917]] = stack[args[3719341]];args = regs[PC + 12];A = args[14067917];retlist = {stack[A]()}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 13];A = args[14067917];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 14];proto = protos[args[9132680]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[14067917]]=lua_wrap_state(proto,ENV,uvlist);args = regs[PC + 15];PC = PC + 15;goto RESET;
											else
												A = args[14067917];retlist = {stack[A](unpack(stack, A + 1, args[3719341]))}; stack[A] = retlist[1];
											end
										end
									else
										if OP <= 0x0FC6098 then
											uv = upvalues[args[3719341]]; stack[args[14067917]] = uv.store[uv.index];
										else
											if OP == 0x0FDC7F4 then
												do return end;
											else
												do return end;
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
