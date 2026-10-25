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
    local code = "000047834B5601F7E88E04725C2E8C10A2A9579420E213269C303F4895A44026403929F78AB0B1806052000006010000BD60010000C570010000CDB0034E0000B130440000A9E080014B0000AC900145298DD9802066FA5CE420000000E9A001030000F4300000007900000081A101440000F98042350000E140440000D9C021F792EFA98040897E0FACB001334D3D2914DDBD29130000B180A00152000006010000BDB0FF3F01000045010000CD70010000D5A005010000DD807D4E0000B150440000A9E0800111C249AC80019C34B5D980207776FBE1A001030000EC40000000F110000000F9A001440000F1F041350000E130440000D9C021D9BDF8A98040D9FD22ACA001D7563F29B08DA2A98020000000B120010000BDB00B440000B1F040000000B920010000C5900C440000B98041000000C130030000CC50440000C19001440000A980200B0000A98020000000B140030000BC60440000B170440000A980200B0000A98020000000B140030000BC70440000B170CCCD46A98020365AC1A9C02008000000040633110407131F04052A130C00150408390E09020018155B04047341584E04047A08164E03CD8101000000000004072219040C020D0D04043B0007160100000001000500000001001395461D0D3549948280100FABEF7F0618821116F15C8180A002577FEA92F00F397F2D274A058A017FC67E8180E002168E842F0424299110548EF9819080021051D383A080200BB7239180D001A96D7E8B908020F490CD8980D0013FAE1887FFFF3F0721FD892085E183911002000000030200000000000000030300000000000000000000000000000001001757392982F00F0BE87A271E60D30C6B814189209E075A9701D4C2E282F00F9860FC2748B3668C10CD60758920F116276F3B90148290115F857A274FECA48C206C4E528920C9D1194794079C82B01CF4D7ED277E39DC8C3043117089209B55721FCCC6DA8C4031B7EE892063184F89100500000004083404020F150519160404200417010405290C04020D040637040107140104053600170904000000000000000001000E98767809010000952000000019010000A5104A000094607F67B081D0C0019E315581D0A002CC2ADCB2F00F416D0A1F1DE0A98950B1211017E48D82947098F48E8920F49C54911000000000000000000000000001000FF5FE590D0252301181A37E8180A00222000089A0202E000089A0C0010B00009180200E000091A0401B0000193000008180E00244000091B04000000081203D000082F00F07D302A7FFFF3F8198C389207173EA911003000000030A0000000000000004043700110604053C0D0A0113010000000000000000000100301C274A0C13000011520000060100009D1034000021010000AD104A00009C800440B6E1B980207E59D5C960922E96D160C02EF8B9A04150689E09EFFDE82FCA2373B9206A05E4AF01C665B28C30F518009F016207D7893028CBFD4F78E566B94018E3281F7A94238C50F4C7FD6FE24048B9201DD0E55FBC87DA0C9130184F6FED1889506A1BF73F84DC65B9601A07B627F81EC4C47096CB2289800169BCCD17C3C5A10CF3EB27C1207E3946C380812016E82FC180D001485DD49180217C2A249C90048686499910547718A18080020E0000A1C0A002000000A920030000B4A001440000A1604600001947000099100B00000004052915041C15040329140704013B04052904000020040138040629040000202E04013904063B02060B111804052E000702040406390E0B0D001804016401000000000000000000"
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

            return {[5064497] = opcode, [15002702] = A, [10253729] = B, [11566686] = C}
        elseif format == 2 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = ((instruction >> Bshift) & 0xFF) - 127
            --assert(B == (instruction // 2 ^ 23))
            C = (instruction >> Cshift) & 0xFF

            return {[5064497] = opcode, [15002702] = A, [10253729] = B, [11566686] = C}
        elseif format == 3 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = (instruction >> Bshift) & 0xFF
            --assert(B == (instruction // 2 ^ 23))
            C = ((instruction >> Cshift) & 0xFF) - 127

            return {[5064497] = opcode, [15002702] = A, [10253729] = B, [11566686] = C}
        elseif format == 4 then
            A = (instruction >> Ashift) & 0xFF
            Bx = (instruction >> Bxshift) & 0xFFFF

            return {[5064497] = opcode, [15002702] = A, [6066085] = Bx}
        elseif format == 5 then
            A = (instruction >> Ashift) & 0xFF
            sBx = convertValue((instruction >> sBxshift) & 0xFFFF, 16)

            return {[5064497] = opcode, [15002702] = A, [8975339] = sBx}
        elseif format == 6 then
            Ax = instruction >> Ashift & 0x1FFFFFF

            return {[5064497] = opcode, [1332586] = Ax,}
        elseif format == 7 then
            sJ = convertValue(instruction >> Ashift & 0x1FFFFFF, 24)

            return {[5064497] = opcode, [3051876] = sJ,}
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
					OP, args = instructions[PC][5064497], regs[PC]
					if OP <= 0x07E6DA9 then
						if OP <= 0x03D4D33 then
							if OP <= 0x022FDD9 then
								if OP <= 0x0183091 then
									if OP <= 0x00A6D41 then
										if OP <= 0x00018F5 then
											PC = PC + args[3051876]; goto RESET;
										else
											if OP == 0x002D307 then
												PC = PC + args[3051876];
											else
												PC = PC + args[3051876]; goto RESET;
											end
										end
									else
										if OP <= 0x01021B1 then
											if OP > 0x00F7E89 then
												PC = PC + args[3051876]; goto RESET;
											else
												A=args[15002702];if stack[A+4]~=nil then stack[A+2]=stack[A+4]PC=PC-args[6066085] end;
											end
										else
											if OP == 0x014903B then
												if ((stack[args[15002702]] < args[10253729]) ~= false) then PC = PC + 1; end;
											else
												PC = PC + args[3051876]; goto RESET;
											end
										end
									end
								else
									if OP <= 0x018ED6F then
										if OP <= 0x0187754 then
											stack[args[15002702]] = ENV[constants[args[11566686]]];args = regs[PC + 1];stack[args[15002702]] = stack[args[10253729]][constants[args[11566686]]];args = regs[PC + 2];stack[args[15002702]] = stack[args[10253729]];args = regs[PC + 3];stack[args[15002702]] = constants[args[6066085]];args = regs[PC + 4];A = args[15002702];retlist = {stack[A](unpack(stack, A + 1, args[10253729]))}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 5];A = args[15002702];B = top; do return unpack(stack, A, B); end;args = regs[PC + 6];do return end;args = regs[PC + 7];PC = PC + 7;goto RESET;
										else
											if OP == 0x018AE3F then
												PC = PC + args[3051876];
											else
												if ((stack[args[15002702]] == constants[args[10253729]]) ~= false) then PC = PC + 1 end;
											end
										end
									else
										if OP <= 0x01D4695 then
											if OP == 0x019D1C9 then
												PC = PC + args[3051876]; goto RESET;
											else
												stack[args[15002702]] = args[8975339];
											end
										else
											if OP == 0x022CB96 then
												if (not stack[args[10253729]] == true) then PC = PC + 1; else stack[args[15002702]] = stack[args[10253729]]; end;
											else
												A=args[15002702];if stack[A+4]~=nil then stack[A+2]=stack[A+4]PC=PC-args[6066085] end;
											end
										end
									end
								end
							else
								if OP <= 0x028E318 then
									if OP <= 0x0242A7C then
										if OP <= 0x023947A then
											stack[args[15002702]] = constants[args[6066085]];
										else
											if OP > 0x023B70B then
												A=args[15002702];limit=stack[A+1]step=stack[A+2]index=stack[A]index=index+step;stack[A]=index;if step>0 and index<=limit or step<=0 and index>=limit then stack[A+3]=index;PC=PC-args[6066085] end;
											else
												
											end
										end
									else
										if OP <= 0x02716F1 then
											if OP > 0x02613E2 then
												PC = PC + args[3051876]; goto RESET;
											else
												proto = protos[args[6066085]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[15002702]]=lua_wrap_state(proto,ENV,uvlist);
											end
										else
											if OP == 0x027EBF3 then
												stack[args[15002702]] = #(stack[args[10253729]]);
											else
												PC = PC + args[3051876]; goto RESET;
											end
										end
									end
								else
									if OP <= 0x02E5C72 then
										if OP <= 0x0293957 then
											if OP == 0x0292404 then
												stack[args[15002702]] = stack[args[11566686]] * constants[args[10253729]];
											else
												if ((stack[args[15002702]] < args[10253729]) ~= false) then PC = PC + 1; end;
											end
										else
											if OP == 0x02D7F39 then
												PC = PC + args[3051876]; goto RESET;
											else
												proto = protos[args[6066085]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[15002702]]=lua_wrap_state(proto,ENV,uvlist);
											end
										end
									else
										if OP <= 0x0305202 then
											if OP == 0x02FE816 then
												
											else
												stack[args[15002702]] = stack[args[11566686]] % constants[args[10253729]];
											end
										else
											if OP > 0x0394026 then
												close_lua_upvalues(openlist, args[15002702]);
											else
												stack[args[15002702]] = ENV[constants[args[11566686]]];
											end
										end
									end
								end
							end
						else
							if OP <= 0x057A9A2 then
								if OP <= 0x049C211 then
									if OP <= 0x046397E then
										if OP <= 0x03F56D7 then
											close_lua_upvalues(openlist, args[15002702]);
										else
											if OP == 0x041816B then
												do return stack[args[15002702]]; end;
											else
												stack[args[15002702]] = stack[args[10253729]] + args[11566686];
											end
										end
									else
										if OP <= 0x04840E2 then
											if OP == 0x046CDCC then
												A = args[15002702];retlist = {stack[A](unpack(stack, A + 1, top))}; 
											else
												if ((stack[args[15002702]] == constants[args[10253729]]) ~= true) then PC = PC + 1 end;
											end
										else
											if OP > 0x0498686 then
												stack[A + 3] = nil; PC = PC + args[6066085];
											else
												stack[args[15002702]] = stack[args[10253729]];
											end
										end
									end
								else
									if OP <= 0x0524E6C then
										if OP <= 0x04A271C then
											stack[args[15002702]] = constants[args[6066085]];args = regs[PC + 1];stack[args[15002702]] = ({});args = regs[PC + 2];args = regs[PC + 3];stack[args[15002702]] = args[8975339];args = regs[PC + 4];stack[args[15002702]] = #(stack[args[10253729]]);args = regs[PC + 5];stack[args[15002702]] = args[8975339];args = regs[PC + 6];A=args[15002702];init=stack[A]limit=stack[A+1]step=stack[A+2]stack[A]=init-step;stack[A+1]=limit;stack[A+2]=step;stack[A+3]=init;PC=PC+args[6066085];args = regs[PC + 7];PC = PC + 7;goto RESET;
										else
											if OP == 0x04F1863 then
												do return end;
											else
												do return stack[args[15002702]]; end;
											end
										end
									else
										if OP <= 0x055319E then
											if OP > 0x0549CF4 then
												
											else
												do return end;
											end
										else
											if OP == 0x0564B83 then
												stack[args[15002702]] = nil;
											else
												proto = protos[args[6066085]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[15002702]]=lua_wrap_state(proto,ENV,uvlist);
											end
										end
									end
								end
							else
								if OP <= 0x066E578 then
									if OP <= 0x05CF116 then
										if OP <= 0x059FEF5 then
											stack[args[15002702]] = args[8975339];
										else
											if OP > 0x05A079E then
												
											else
												PC = PC + args[3051876]; goto RESET;
											end
										end
									else
										if OP <= 0x065DC84 then
											if OP == 0x05CFA66 then
												stack[args[15002702]] = constants[args[6066085]];args = regs[PC + 1];stack[args[15002702]] = stack[args[10253729]];args = regs[PC + 2];stack[args[15002702]] = constants[args[6066085]];args = regs[PC + 3];stack[args[15002702]] = stack[args[10253729]];args = regs[PC + 4];stack[args[15002702]] = stack[args[10253729]];args = regs[PC + 5];A = args[15002702];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 6];A=args[15002702];result={}for a=A,A+args[10253729]-1 do insert(result,stack[a])end;stack[args[15002702]]=concat(result);args = regs[PC + 7];A = args[15002702];retlist = {stack[A](stack[A + 1])}; args = regs[PC + 8];PC = PC + 8;goto RESET;
											else
												if ((stack[args[15002702]] == constants[args[10253729]]) ~= false) then PC = PC + 1 end;
											end
										else
											if OP > 0x066B348 then
												if ((stack[args[15002702]] == constants[args[10253729]]) ~= false) then PC = PC + 1 end;
											else
												stack[args[15002702]] = constants[args[6066085]];
											end
										end
									end
								else
									if OP <= 0x07560CD then
										if OP <= 0x072559B then
											if OP == 0x0701143 then
												do return stack[args[15002702]]; end;
											else
												PC = PC + args[3051876]; goto RESET;
											end
										else
											if OP > 0x07323CA then
												do return stack[args[15002702]]; end;
											else
												if ((stack[args[15002702]] == constants[args[10253729]]) ~= false) then PC = PC + 1 end;
											end
										end
									else
										if OP <= 0x07A855F then
											if OP == 0x0787698 then
												for i = args[10253729], 0, -1 do stack[i + args[15002702]] = nil; end;args = regs[PC + 1];stack[args[15002702]] = args[8975339];args = regs[PC + 2];stack[args[15002702]] = stack[args[10253729]];args = regs[PC + 3];stack[args[15002702]] = args[8975339];args = regs[PC + 4];A=args[15002702];init=stack[A]limit=stack[A+1]step=stack[A+2]stack[A]=init-step;stack[A+1]=limit;stack[A+2]=step;stack[A+3]=init;PC=PC+args[6066085];args = regs[PC + 5];PC = PC + 5;goto RESET;
											else
												PC = PC + args[3051876]; goto RESET;
											end
										else
											if OP == 0x07AE80B then
												PC = PC + args[3051876]; goto RESET;
											else
												stack[args[15002702]] = stack[args[10253729]] + args[11566686];
											end
										end
									end
								end
							end
						end
					else
						if OP <= 0x0CD90F4 then
							if OP <= 0x09C0794 then
								if OP <= 0x08A054A then
									if OP <= 0x0821806 then
										if OP <= 0x07EA381 then
											args = regs[PC + 1];stack[args[11566686]] = stack[args[15002702]] + stack[args[10253729]];args = regs[PC + 2];args = regs[PC + 3];stack[args[15002702]] = ENV[constants[args[11566686]]];args = regs[PC + 4];stack[args[15002702]] = stack[args[10253729]][constants[args[11566686]]];args = regs[PC + 5];stack[args[15002702]] = stack[args[11566686]] / constants[args[10253729]];args = regs[PC + 6];args = regs[PC + 7];A = args[15002702];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 8];stack[args[15002702]] = stack[args[10253729]];args = regs[PC + 9];if ((stack[args[15002702]] == args[10253729]) ~= false) then PC = PC + 1 end;args = regs[PC + 10];PC = PC + 10;goto RESET;
										else
											if OP == 0x07EC67F then
												
											else
												stack[args[15002702]] = stack[args[11566686]] % constants[args[10253729]];
											end
										end
									else
										if OP <= 0x083E185 then
											if OP > 0x0828DE4 then
												do return end;
											else
												A=args[15002702];limit=stack[A+1]step=stack[A+2]index=stack[A]index=index+step;stack[A]=index;if step>0 and index<=limit or step<=0 and index>=limit then stack[A+3]=index;PC=PC-args[6066085] end;
											end
										else
											if OP == 0x0848E16 then
												PC = PC + args[3051876]; goto RESET;
											else
												stack[args[15002702]] = stack[args[11566686]] / constants[args[10253729]];
											end
										end
									end
								else
									if OP <= 0x08EF498 then
										if OP <= 0x08D2945 then
											stack[args[15002702]] = ENV[constants[args[11566686]]];
										else
											if OP > 0x08EE8F7 then
												do return stack[args[15002702]]; end;
											else
												proto = protos[args[6066085]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[15002702]]=lua_wrap_state(proto,ENV,uvlist);
											end
										end
									else
										if OP <= 0x095483F then
											if OP > 0x0944935 then
												proto = protos[args[6066085]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[15002702]]=lua_wrap_state(proto,ENV,uvlist);
											else
												if ((stack[args[15002702]] == args[10253729]) ~= true) then PC = PC + 1 end;
											end
										else
											if OP == 0x0962E92 then
												stack[args[15002702]] = stack[args[10253729]];
											else
												if ((stack[args[15002702]] < args[10253729]) ~= false) then PC = PC + 1; end;
											end
										end
									end
								end
							else
								if OP <= 0x0B08AF7 then
									if OP <= 0x0A28DB0 then
										if OP <= 0x09E6850 then
											if ((stack[args[15002702]] == constants[args[10253729]]) ~= false) then PC = PC + 1 end;
										else
											if OP > 0x0A1C5C3 then
												stack[args[15002702]] = ENV[constants[args[11566686]]];args = regs[PC + 1];stack[args[15002702]] = stack[args[10253729]];args = regs[PC + 2];stack[args[15002702]] = args[8975339];args = regs[PC + 3];A = args[15002702];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 4];stack[args[15002702]] = stack[args[10253729]];args = regs[PC + 5];stack[args[15002702]] = args[8975339];args = regs[PC + 6];A = args[15002702];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 7];stack[args[15002702]] = stack[args[10253729]];args = regs[PC + 8];stack[args[15002702]] = constants[args[6066085]];args = regs[PC + 9];A = args[15002702];retlist = {stack[A](stack[A + 1])}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 10];A = args[15002702];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 11];stack[args[15002702]] = ENV[constants[args[11566686]]];args = regs[PC + 12];stack[args[15002702]] = stack[args[10253729]];args = regs[PC + 13];stack[args[15002702]] = constants[args[6066085]];args = regs[PC + 14];A = args[15002702];retlist = {stack[A](stack[A + 1])}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 15];A = args[15002702];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 16];stack[args[15002702]] = ENV[constants[args[11566686]]];args = regs[PC + 17];stack[args[15002702]] = stack[args[10253729]];args = regs[PC + 18];stack[args[15002702]] = constants[args[6066085]];args = regs[PC + 19];A = args[15002702];retlist = {stack[A](stack[A + 1])}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 20];PC = PC + 20;goto RESET;
											else
												stack[args[15002702]] = constants[args[6066085]];
											end
										end
									else
										if OP <= 0x0A9E01D then
											if OP == 0x0A4EC4F then
												stack[args[15002702]] = constants[args[6066085]];
											else
												stack[args[15002702]] = stack[args[10253729]];
											end
										else
											if OP == 0x0B0677F then
												stack[args[11566686]] = stack[args[15002702]] % stack[args[10253729]];
											else
												stack[args[15002702]] = ({});args = regs[PC + 1];args = regs[PC + 2];stack[args[15002702]] = args[8975339];args = regs[PC + 3];stack[args[15002702]] = args[8975339];args = regs[PC + 4];stack[args[15002702]] = args[8975339];args = regs[PC + 5];A = args[15002702]; C = args[11566686]; for i = 1, args[10253729] do stack[A][C + i] = stack[A + i]; end;args = regs[PC + 6];A = args[15002702];retlist = {stack[A](stack[A + 1])}; retnum = args[11566686]; move(retlist, 1, retnum, A, stack);args = regs[PC + 7];stack[A + 3] = nil; PC = PC + args[6066085];args = regs[PC + 8];PC = PC + 8;goto RESET;
											end
										end
									end
								else
									if OP <= 0x0BDDD14 then
										if OP <= 0x0B5349C then
											if OP > 0x0B265C6 then
												stack[args[15002702]] = ENV[constants[args[11566686]]];
											else
												stack[args[15002702]] = constants[args[6066085]];
											end
										else
											if OP > 0x0B6071A then
												stack[args[15002702]] = ENV[constants[args[11566686]]];args = regs[PC + 1];stack[args[15002702]] = ({});args = regs[PC + 2];args = regs[PC + 3];stack[args[15002702]] = args[8975339];args = regs[PC + 4];stack[args[15002702]] = args[8975339];args = regs[PC + 5];stack[args[15002702]] = args[8975339];args = regs[PC + 6];stack[args[15002702]] = args[8975339];args = regs[PC + 7];stack[args[15002702]] = args[8975339];args = regs[PC + 8];A = args[15002702]; C = args[11566686]; for i = 1, args[10253729] do stack[A][C + i] = stack[A + i]; end;args = regs[PC + 9];A = args[15002702];retlist = {stack[A](stack[A + 1])}; retnum = args[11566686]; move(retlist, 1, retnum, A, stack);args = regs[PC + 10];PC = PC + 10;goto RESET;
											else
												PC = PC + args[3051876]; goto RESET;
											end
										end
									else
										if OP <= 0x0C39881 then
											if OP > 0x0C15A36 then
												do return stack[args[15002702]]; end;
											else
												A = args[15002702];close_lua_upvalues(openlist, 0);do return unpack(stack, A, args[10253729]); end;
											end
										else
											if OP > 0x0C41EF8 then
												
											else
												stack[args[15002702]] = constants[args[6066085]];
											end
										end
									end
								end
							end
						else
							if OP <= 0x0E8FDEF then
								if OP <= 0x0DA87BC then
									if OP <= 0x0D3601E then
										if OP <= 0x0CDBC69 then
											PC = PC + args[3051876]; goto RESET;
										else
											if OP == 0x0D35110 then
												stack[args[15002702]] = stack[args[10253729]] + args[11566686];
											else
												stack[args[15002702]] = constants[args[6066085]];
											end
										end
									else
										if OP <= 0x0D5597E then
											if OP == 0x0D45D48 then
												stack[args[15002702]][stack[args[10253729]]] = stack[args[11566686]];
											else
												stack[args[15002702]] = stack[args[10253729]];
											end
										else
											if OP > 0x0D70762 then
												stack[args[15002702]] = constants[args[6066085]];
											else
												if ((stack[args[15002702]] == constants[args[10253729]]) ~= false) then PC = PC + 1 end;
											end
										end
									end
								else
									if OP <= 0x0E1B640 then
										if OP <= 0x0DC2ACC then
											if OP == 0x0DAC6CC then
												stack[args[15002702]] = constants[args[6066085]];
											else
												if ((stack[args[15002702]] == args[10253729]) ~= false) then PC = PC + 1 end;
											end
										else
											if OP == 0x0DC397E then
												stack[args[15002702]] = constants[args[6066085]];
											else
												A = args[15002702]; B = args[10253729]; stack[A+1] = stack[B]; stack[A] = stack[B][constants[args[11566686]]];
											end
										end
									else
										if OP <= 0x0E4056A then
											if OP > 0x0E2C2D4 then
												PC = PC + args[3051876]; goto RESET;
											else
												if ((stack[args[15002702]] == args[10253729]) ~= false) then PC = PC + 1 end;
											end
										else
											if OP == 0x0E5D01D then
												PC = PC + args[3051876]; goto RESET;
											else
												PC = PC + args[3051876]; goto RESET;
											end
										end
									end
								end
							else
								if OP <= 0x0F71B6A then
									if OP <= 0x0EDD7F4 then
										if OP <= 0x0EA7371 then
											do return end;
										else
											if OP > 0x0EA7F57 then
												PC = PC + args[3051876]; goto RESET;
											else
												if ((stack[args[15002702]] == args[10253729]) ~= false) then PC = PC + 1 end;
											end
										end
									else
										if OP <= 0x0EF92F7 then
											if OP == 0x0EEB731 then
												do return stack[args[15002702]]; end;
											else
												A=args[15002702];stack[A+4],stack[A+5],stack[A+3+args[11566686]]=stack[A](stack[A+1],stack[A+2]);
											end
										else
											if OP == 0x0EFAB0F then
												PC = PC + args[3051876]; goto RESET;
											else
												PC = PC + args[3051876]; goto RESET;
											end
										end
									end
								else
									if OP <= 0x0FB7677 then
										if OP <= 0x0F8BDD9 then
											if OP == 0x0F82EC0 then
												A = args[15002702];retlist = {stack[A](unpack(stack, A + 1, args[10253729]))}; stack[A] = retlist[1];
											else
												A=args[15002702];stack[A+4],stack[A+5],stack[A+3+args[11566686]]=stack[A](stack[A+1],stack[A+2]);
											end
										else
											if OP == 0x0F98E54 then
												
											else
												stack[args[15002702]] = stack[args[10253729]];args = regs[PC + 1];stack[args[15002702]] = constants[args[6066085]];args = regs[PC + 2];stack[args[15002702]] = stack[args[10253729]];args = regs[PC + 3];stack[args[15002702]] = stack[args[10253729]];args = regs[PC + 4];A = args[15002702];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 5];A=args[15002702];result={}for a=A,A+args[10253729]-1 do insert(result,stack[a])end;stack[args[15002702]]=concat(result);args = regs[PC + 6];A = args[15002702];retlist = {stack[A](stack[A + 1])}; args = regs[PC + 7];PC = PC + 7;goto RESET;
											end
										end
									else
										if OP <= 0x0FD2107 then
											if OP > 0x0FC6098 then
												do return stack[args[15002702]]; end;
											else
												PC = PC + args[3051876]; goto RESET;
											end
										else
											if OP > 0x0FDC7F4 then
												PC = PC + args[3051876]; goto RESET;
											else
												PC = PC + args[3051876]; goto RESET;
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
