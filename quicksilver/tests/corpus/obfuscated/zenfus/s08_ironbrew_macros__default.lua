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
    local code = "00003EF1162701F7E88E04725C2E01A2A9578410E2132681103F489584202640398120F78AB0843045298D8C4066FA5C9450F792EF1D897E0FA510334D3DADA00114DDBDB51011C249A4509C34B5417776FBC930D9BDF8D170D9FD22C1A041D7563F998001B08DA2A460CCCD46A18060365AC1AC40000000B130440000A1E0200B0000A180A001130000A980800152000006010000B5D0FF3F0100003D010000C540010000CD70834B56A9400BE87AA1D080011E60D3A4606B8141D180609E075AD99001000000E120000000E99001440000E1D001440000D18020D4C2E2A180409860FCA4800148B36621CD6075A110010000ADC001010000B550440000A1E0400B0000B18060000000B940000000C150440000B180210B0000B180600B0000B980C001030000C470000000C910010000D510010000DD20440000C9B00144000039440000B18020460000B1D02008000000041213233A23203430301C2D2A393E3F3B320835041013233A23203430301C2D2A393E292137041113233A272F20263D132F223132382E210E04052A130C001504052E0E110F0D040633110407131F04062904090B02180401790100000001000600000000000107D30281100000000000000000000000000000013B901481100000000000000000000000000000015F857A81100000000000000000000000000200074FECA4110700001944000091B0202200008190402E00008190C0014800009120470000911001000000041113233A272F20263D132F223132382E210E010000000000000000000200096C4E52110700001944000091B0202400008190402E0000819080022700008190602E00008190E0024600009130470000911001000000041113233A272F20263D132F223132382E210E0100000000000000000001001681A37E09C9D11989902094079C09F4D7ED82F00F7E39DC1F4311708C109B557267CCC6DA82F00F31B7EE1F63184F8C20573929477F67B091309E315581B0A002CC2ADC92F00F416D0A1F1DE0A98C40B1211017E48D828C5098F48E9180C001F49C549190209876788920025230911007000000041213233A23203430301C2D2A393E3F3B32083504083404020F1505191604042004170103020000000000000004043F1700000403350501041013233A23203430301C2D2A393E29213701000000000000000000"
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

            return {[10034043] = opcode, [10851934] = A, [13019573] = B, [4455990] = C}
        elseif format == 2 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = ((instruction >> Bshift) & 0xFF) - 127
            --assert(B == (instruction // 2 ^ 23))
            C = (instruction >> Cshift) & 0xFF

            return {[10034043] = opcode, [10851934] = A, [13019573] = B, [4455990] = C}
        elseif format == 3 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = (instruction >> Bshift) & 0xFF
            --assert(B == (instruction // 2 ^ 23))
            C = ((instruction >> Cshift) & 0xFF) - 127

            return {[10034043] = opcode, [10851934] = A, [13019573] = B, [4455990] = C}
        elseif format == 4 then
            A = (instruction >> Ashift) & 0xFF
            Bx = (instruction >> Bxshift) & 0xFFFF

            return {[10034043] = opcode, [10851934] = A, [670521] = Bx}
        elseif format == 5 then
            A = (instruction >> Ashift) & 0xFF
            sBx = convertValue((instruction >> sBxshift) & 0xFFFF, 16)

            return {[10034043] = opcode, [10851934] = A, [5489828] = sBx}
        elseif format == 6 then
            Ax = instruction >> Ashift & 0x1FFFFFF

            return {[10034043] = opcode, [13439273] = Ax,}
        elseif format == 7 then
            sJ = convertValue(instruction >> Ashift & 0x1FFFFFF, 24)

            return {[10034043] = opcode, [8870347] = sJ,}
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
					OP, args = instructions[PC][10034043], regs[PC]
					if OP <= 0x072559B then
						if OP <= 0x03D4D33 then
							if OP <= 0x022FDD9 then
								if OP <= 0x00F7E89 then
									if OP <= 0x002D307 then
										do return end;
									else
										if OP > 0x00A6D41 then
											stack[args[10851934]] = args[5489828];
										else
											PC = PC + args[8870347]; goto RESET;
										end
									end
								else
									if OP <= 0x014903B then
										if OP > 0x01021B1 then
											do return end;
										else
											PC = PC + args[8870347]; goto RESET;
										end
									else
										if OP == 0x019D1C9 then
											A = args[10851934];retlist = {stack[A]()}; 
										else
											A = args[10851934];retlist = {stack[A](unpack(stack, A + 1, args[13019573]))}; stack[A] = retlist[1];
										end
									end
								end
							else
								if OP <= 0x0293957 then
									if OP <= 0x02613E2 then
										ENV[constants[args[13019573]]] = stack[args[4455990]];
									else
										if OP > 0x02716F1 then
											PC = PC + args[8870347]; goto RESET;
										else
											stack[args[10851934]] = nil;
										end
									end
								else
									if OP <= 0x0305202 then
										if OP > 0x02E5C72 then
											do return end;
										else
											ENV[constants[args[13019573]]] = stack[args[4455990]];
										end
									else
										if OP > 0x0394026 then
											stack[args[10851934]] = args[5489828];
										else
											ENV[constants[args[13019573]]] = stack[args[4455990]];
										end
									end
								end
							end
						else
							if OP <= 0x0549CF4 then
								if OP <= 0x046CDCC then
									if OP <= 0x03F56D7 then
										stack[args[10851934]] = stack[args[13019573]];
									else
										if OP > 0x041816B then
											stack[args[10851934]] = ENV[constants[args[4455990]]];
										else
											stack[args[10851934]] = ENV[constants[args[4455990]]];
										end
									end
								else
									if OP <= 0x04F1863 then
										if OP == 0x049C211 then
											A=args[10851934];init=stack[A]limit=stack[A+1]step=stack[A+2]stack[A]=init-step;stack[A+1]=limit;stack[A+2]=step;stack[A+3]=init;PC=PC+args[670521];
										else
											stack[args[10851934]] = constants[args[670521]];
										end
									else
										if OP == 0x0524E6C then
											stack[args[10851934]] = ENV[constants[args[4455990]]];args = regs[PC + 1];stack[args[10851934]] = true;args = regs[PC + 2];A = args[10851934];retlist = {stack[A](stack[A + 1])}; args = regs[PC + 3];stack[args[4455990]] = stack[args[10851934]] * stack[args[13019573]];args = regs[PC + 4];args = regs[PC + 5];stack[args[4455990]] = stack[args[10851934]] / stack[args[13019573]];args = regs[PC + 6];args = regs[PC + 7];A = args[10851934];do return unpack(stack, A, args[13019573]); end;args = regs[PC + 8];do return end;args = regs[PC + 9];PC = PC + 9;goto RESET;
										else
											A = args[10851934];retlist = {stack[A]()}; 
										end
									end
								end
							else
								if OP <= 0x05A079E then
									if OP <= 0x0564B83 then
										if OP > 0x055319E then
											A = args[10851934]; C = args[4455990]; for i = 1, args[13019573] do stack[A][C + i] = stack[A + i]; end;
										else
											
										end
									else
										if OP > 0x057A9A2 then
											stack[args[10851934]] = stack[args[13019573]];args = regs[PC + 1];stack[args[10851934]] = stack[args[13019573]];args = regs[PC + 2];stack[args[10851934]] = stack[args[13019573]];args = regs[PC + 3];A = args[10851934];retlist = {stack[A](stack[A + 1])}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 4];A = args[10851934];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 5];PC = PC + 5;goto RESET;
										else
											proto = protos[args[670521]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10851934]]=lua_wrap_state(proto,ENV,uvlist);
										end
									end
								else
									if OP <= 0x066B348 then
										if OP > 0x05CFA66 then
											close_lua_upvalues(openlist, args[10851934]);
										else
											proto = protos[args[670521]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10851934]]=lua_wrap_state(proto,ENV,uvlist);
										end
									else
										if OP == 0x0701143 then
											stack[args[10851934]] = constants[args[670521]];
										else
											PC = PC + args[8870347]; goto RESET;
										end
									end
								end
							end
						end
					else
						if OP <= 0x0B0677F then
							if OP <= 0x08D2945 then
								if OP <= 0x07A855F then
									if OP <= 0x07560CD then
										stack[args[10851934]] = stack[args[13019573]];args = regs[PC + 1];stack[args[10851934]] = args[5489828];args = regs[PC + 2];stack[args[10851934]] = args[5489828];args = regs[PC + 3];A = args[10851934];retlist = {stack[A](unpack(stack, A + 1, args[13019573]))}; retnum = args[4455990]; move(retlist, 1, retnum, A, stack);args = regs[PC + 4];stack[args[10851934]] = ENV[constants[args[4455990]]];args = regs[PC + 5];stack[args[10851934]] = stack[args[13019573]];args = regs[PC + 6];stack[args[10851934]] = stack[args[13019573]];args = regs[PC + 7];A = args[10851934];retlist = {stack[A](unpack(stack, A + 1, args[13019573]))}; args = regs[PC + 8];stack[args[10851934]] = ENV[constants[args[4455990]]];args = regs[PC + 9];stack[args[10851934]] = ENV[constants[args[4455990]]];args = regs[PC + 10];stack[args[10851934]] = constants[args[670521]];args = regs[PC + 11];stack[args[10851934]] = stack[args[13019573]];args = regs[PC + 12];stack[args[10851934]] = args[5489828];args = regs[PC + 13];stack[args[10851934]] = args[5489828];args = regs[PC + 14];A = args[10851934];retlist = {stack[A](unpack(stack, A + 1, args[13019573]))}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 15];A = args[10851934];retlist = {stack[A](unpack(stack, A + 1, top))}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 16];A = args[10851934];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 17];A = args[10851934];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[13019573]); end;args = regs[PC + 18];PC = PC + 18;goto RESET;
									else
										if OP > 0x0787698 then
											do return end;
										else
											do return stack[args[10851934]]; end;
										end
									end
								else
									if OP <= 0x07EA381 then
										if OP > 0x07AE80B then
											stack[args[10851934]] = ENV[constants[args[4455990]]];
										else
											A = args[10851934];retlist = {stack[A](stack[A + 1])}; retnum = args[4455990]; move(retlist, 1, retnum, A, stack);
										end
									else
										if OP > 0x0828DE4 then
											proto = protos[args[670521]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10851934]]=lua_wrap_state(proto,ENV,uvlist);
										else
											stack[args[10851934]] = constants[args[670521]];
										end
									end
								end
							else
								if OP <= 0x09C0794 then
									if OP <= 0x08EF498 then
										if OP == 0x08EE8F7 then
											proto = protos[args[670521]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10851934]]=lua_wrap_state(proto,ENV,uvlist);
										else
											stack[args[10851934]] = ENV[constants[args[4455990]]];
										end
									else
										if OP > 0x095483F then
											for i = args[13019573], 0, -1 do stack[i + args[10851934]] = nil; end;
										else
											proto = protos[args[670521]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10851934]]=lua_wrap_state(proto,ENV,uvlist);
										end
									end
								else
									if OP <= 0x0A4EC4F then
										if OP > 0x0A28DB0 then
											stack[args[10851934]] = ENV[constants[args[4455990]]];args = regs[PC + 1];stack[args[10851934]] = true;args = regs[PC + 2];A = args[10851934];retlist = {stack[A](stack[A + 1])}; args = regs[PC + 3];stack[args[4455990]] = stack[args[10851934]] + stack[args[13019573]];args = regs[PC + 4];args = regs[PC + 5];do return stack[args[10851934]]; end;args = regs[PC + 6];do return end;args = regs[PC + 7];PC = PC + 7;goto RESET;
										else
											A=args[10851934];limit=stack[A+1]step=stack[A+2]index=stack[A]index=index+step;stack[A]=index;if step>0 and index<=limit or step<=0 and index>=limit then stack[A+3]=index;PC=PC-args[670521] end;
										end
									else
										if OP == 0x0A9E01D then
											stack[args[10851934]] = constants[args[670521]];
										else
											stack[args[10851934]] = stack[args[4455990]] % constants[args[13019573]];
										end
									end
								end
							end
						else
							if OP <= 0x0DC2ACC then
								if OP <= 0x0BDDD14 then
									if OP <= 0x0B08AF7 then
										proto = protos[args[670521]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[10851934]]=lua_wrap_state(proto,ENV,uvlist);
									else
										if OP == 0x0B5349C then
											stack[args[10851934]] = stack[args[13019573]];
										else
											stack[args[10851934]] = args[5489828];
										end
									end
								else
									if OP <= 0x0D3601E then
										if OP > 0x0C15A36 then
											stack[A + 3] = nil; PC = PC + args[670521];
										else
											stack[args[10851934]] = constants[args[670521]];args = regs[PC + 1];stack[args[10851934]] = stack[args[13019573]];args = regs[PC + 2];A = args[10851934];retlist = {stack[A](unpack(stack, A + 1, args[13019573]))}; args = regs[PC + 3];stack[args[10851934]] = ENV[constants[args[4455990]]];args = regs[PC + 4];stack[args[10851934]] = ({});args = regs[PC + 5];args = regs[PC + 6];stack[args[10851934]] = args[5489828];args = regs[PC + 7];stack[args[10851934]] = args[5489828];args = regs[PC + 8];stack[args[10851934]] = args[5489828];args = regs[PC + 9];stack[args[10851934]] = args[5489828];args = regs[PC + 10];PC = PC + 10;goto RESET;
										end
									else
										if OP == 0x0DAC6CC then
											if ((stack[args[10851934]] == args[13019573]) ~= false) then PC = PC + 1 end;
										else
											if ((stack[args[10851934]] == args[13019573]) ~= false) then PC = PC + 1 end;
										end
									end
								end
							else
								if OP <= 0x0EEB731 then
									if OP <= 0x0E2C2D4 then
										if OP == 0x0DC397E then
											PC = PC + args[8870347]; goto RESET;
										else
											A=args[10851934];stack[A+4],stack[A+5],stack[A+3+args[4455990]]=stack[A](stack[A+1],stack[A+2]);
										end
									else
										if OP == 0x0EDD7F4 then
											if ((stack[args[10851934]] < args[13019573]) ~= false) then PC = PC + 1; end;
										else
											PC = PC + args[8870347]; goto RESET;
										end
									end
								else
									if OP <= 0x0F8BDD9 then
										if OP > 0x0EF92F7 then
											stack[args[10851934]] = stack[args[13019573]];
										else
											stack[args[10851934]] = args[5489828];
										end
									else
										if OP == 0x0FB7677 then
											stack[args[10851934]] = stack[args[13019573]];
										else
											A=args[10851934];if stack[A+4]~=nil then stack[A+2]=stack[A+4]PC=PC-args[670521] end;
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
