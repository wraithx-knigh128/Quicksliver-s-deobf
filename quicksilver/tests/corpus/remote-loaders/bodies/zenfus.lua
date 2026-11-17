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
    local code = "000044D7563F01F7E88E04725C2E8C10A2A9579420E213269C303F48952126403906010000AD10010000B5A006010000BD104A0000AC9001F78AB0C92045298DD1800166FA5CC9A041F792EF49897E0F2F334D3DC94014DDBDCB90812011C249C980D0019C34B5A19081027776FBACA001D9BDF829D9FD22B410000000B930000000C140030000CC20440000B99041350000B120440000A9E0200B000029030000B430000000B910010000C5C00A010000CDC004440000B99041350000B120440000A9E0200B000029030000B44000000039010000C5F0010100004D010000D5A001440000B9A041030000C45000000049010000D5D0FF3F0100005D010000E5A001440000C9C041030000D45000000059010000E5700100006D010000F5A001440000D9E041350000B160440000A9E0200B0000290B0000B180C0010E0000B1E0E001030000BC8001030000C49001030000CCA001010000D570440000B1A001440000A98020460000A9C0200B00000004052A130C001504082A130C03041F5553040176040E3D0201465958435369574C4E5C4C0407390D040311564F04017A0406291517070F0B04063C0E17030018040F7F544B5C07104A5E6C12194B515F0B136E861BF0F921094004023B03010000000100040000000300098198C38110B121101FE48D82892098F48E27F49C541198767817025230912081A37E812007D3029910000000000000000000000000020009D4C2E28AF00FB08DA237CCCD469110365AC1819020834B568190A0020BE87A81201E60D3CFFFFF3F6B814181209E075A911000000000000000000000000001001863184F8290109860FC1F48B36609CD60758920F116278D203B9014115F857A91A0200B0000190E000099B0400000002144000099404400009180400100009D104A00008C604FECA481C0A0016C4E5281C0A002C9D119AAF00F94079C1FF4D7ED297E39DCA9204311708C709B557209CCC6DA892031B7EE89100300000004043700110604053C0D0A011304042910171A010000000000000000000200151DE0A911520000060100009D1034000021010000AD104A00009C70573929B9207F67B0BBF080202F0000B980D0010B0000410C0000C980C001440000C1904110000091F080029E31559C8001CC2ADC998020416D0A99B040000000A120000000A91045000099504600001947000099100300000004082E0E161A1305011404052E000702040406390E0B0D001801000000000000000000"
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

            return {[10851934] = opcode, [13019573] = A, [4455990] = B, [670521] = C}
        elseif format == 2 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = ((instruction >> Bshift) & 0xFF) - 127
            --assert(B == (instruction // 2 ^ 23))
            C = (instruction >> Cshift) & 0xFF

            return {[10851934] = opcode, [13019573] = A, [4455990] = B, [670521] = C}
        elseif format == 3 then
            A = (instruction >> Ashift) & 0xFF
            --assert(A == (instruction // 64) % 256)
            B = (instruction >> Bshift) & 0xFF
            --assert(B == (instruction // 2 ^ 23))
            C = ((instruction >> Cshift) & 0xFF) - 127

            return {[10851934] = opcode, [13019573] = A, [4455990] = B, [670521] = C}
        elseif format == 4 then
            A = (instruction >> Ashift) & 0xFF
            Bx = (instruction >> Bxshift) & 0xFFFF

            return {[10851934] = opcode, [13019573] = A, [5489828] = Bx}
        elseif format == 5 then
            A = (instruction >> Ashift) & 0xFF
            sBx = convertValue((instruction >> sBxshift) & 0xFFFF, 16)

            return {[10851934] = opcode, [13019573] = A, [13439273] = sBx}
        elseif format == 6 then
            Ax = instruction >> Ashift & 0x1FFFFFF

            return {[10851934] = opcode, [8870347] = Ax,}
        elseif format == 7 then
            sJ = convertValue(instruction >> Ashift & 0x1FFFFFF, 24)

            return {[10851934] = opcode, [16284868] = sJ,}
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
					OP, args = instructions[PC][10851934], regs[PC]
					if OP <= 0x07560CD then
						if OP <= 0x03F56D7 then
							if OP <= 0x022FDD9 then
								if OP <= 0x00F7E89 then
									if OP <= 0x002D307 then
										do return end;
									else
										if OP > 0x00A6D41 then
											PC = PC + args[16284868]; goto RESET;
										else
											stack[args[13019573]] = stack[args[4455990]][constants[args[670521]]];args = regs[PC + 1];stack[args[13019573]] = stack[args[4455990]];args = regs[PC + 2];stack[args[13019573]] = stack[args[4455990]];args = regs[PC + 3];A = args[13019573];do return stack[A](unpack(stack, A + 1, args[4455990])); end;args = regs[PC + 4];A = args[13019573];B = top; do return unpack(stack, A, B); end;args = regs[PC + 5];do return end;args = regs[PC + 6];PC = PC + 6;goto RESET;
										end
									end
								else
									if OP <= 0x014903B then
										if OP > 0x01021B1 then
											stack[args[13019573]] = ENV[constants[args[670521]]];
										else
											PC = PC + args[16284868]; goto RESET;
										end
									else
										if OP == 0x019D1C9 then
											if ((stack[args[13019573]] == args[4455990]) ~= false) then PC = PC + 1 end;
										else
											stack[args[13019573]] = constants[args[5489828]];args = regs[PC + 1];stack[args[13019573]] = stack[args[4455990]];args = regs[PC + 2];stack[args[13019573]] = stack[args[4455990]];args = regs[PC + 3];stack[args[13019573]] = constants[args[5489828]];args = regs[PC + 4];A = args[13019573];retlist = {stack[A](unpack(stack, A + 1, args[4455990]))}; stack[A] = retlist[1];args = regs[PC + 5];A=args[13019573];result={}for a=A,A+args[4455990]-1 do insert(result,stack[a])end;stack[args[13019573]]=concat(result);args = regs[PC + 6];A = args[13019573];retlist = {stack[A](stack[A + 1])}; args = regs[PC + 7];stack[args[13019573]] = ENV[constants[args[670521]]];args = regs[PC + 8];stack[args[13019573]] = constants[args[5489828]];args = regs[PC + 9];stack[args[13019573]] = stack[args[4455990]];args = regs[PC + 10];stack[args[13019573]] = args[13439273];args = regs[PC + 11];stack[args[13019573]] = args[13439273];args = regs[PC + 12];A = args[13019573];retlist = {stack[A](unpack(stack, A + 1, args[4455990]))}; stack[A] = retlist[1];args = regs[PC + 13];A=args[13019573];result={}for a=A,A+args[4455990]-1 do insert(result,stack[a])end;stack[args[13019573]]=concat(result);args = regs[PC + 14];A = args[13019573];retlist = {stack[A](stack[A + 1])}; args = regs[PC + 15];stack[args[13019573]] = ENV[constants[args[670521]]];args = regs[PC + 16];stack[args[13019573]] = constants[args[5489828]];args = regs[PC + 17];stack[args[13019573]] = stack[args[4455990]];args = regs[PC + 18];stack[args[13019573]] = args[13439273];args = regs[PC + 19];stack[args[13019573]] = args[13439273];args = regs[PC + 20];stack[args[13019573]] = args[13439273];args = regs[PC + 21];A = args[13019573];retlist = {stack[A](unpack(stack, A + 1, args[4455990]))}; stack[A] = retlist[1];args = regs[PC + 22];stack[args[13019573]] = constants[args[5489828]];args = regs[PC + 23];stack[args[13019573]] = stack[args[4455990]];args = regs[PC + 24];stack[args[13019573]] = args[13439273];args = regs[PC + 25];stack[args[13019573]] = args[13439273];args = regs[PC + 26];stack[args[13019573]] = args[13439273];args = regs[PC + 27];A = args[13019573];retlist = {stack[A](unpack(stack, A + 1, args[4455990]))}; stack[A] = retlist[1];args = regs[PC + 28];stack[args[13019573]] = constants[args[5489828]];args = regs[PC + 29];stack[args[13019573]] = stack[args[4455990]];args = regs[PC + 30];stack[args[13019573]] = args[13439273];args = regs[PC + 31];stack[args[13019573]] = args[13439273];args = regs[PC + 32];stack[args[13019573]] = args[13439273];args = regs[PC + 33];A = args[13019573];retlist = {stack[A](unpack(stack, A + 1, args[4455990]))}; stack[A] = retlist[1];args = regs[PC + 34];A=args[13019573];result={}for a=A,A+args[4455990]-1 do insert(result,stack[a])end;stack[args[13019573]]=concat(result);args = regs[PC + 35];A = args[13019573];retlist = {stack[A](stack[A + 1])}; args = regs[PC + 36];stack[args[13019573]] = ENV[constants[args[670521]]];args = regs[PC + 37];stack[args[13019573]] = ENV[constants[args[670521]]];args = regs[PC + 38];stack[args[13019573]] = stack[args[4455990]][constants[args[670521]]];args = regs[PC + 39];stack[args[13019573]] = constants[args[5489828]];args = regs[PC + 40];stack[args[13019573]] = constants[args[5489828]];args = regs[PC + 41];stack[args[13019573]] = constants[args[5489828]];args = regs[PC + 42];stack[args[13019573]] = args[13439273];args = regs[PC + 43];A = args[13019573];retlist = {stack[A](unpack(stack, A + 1, args[4455990]))}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 44];A = args[13019573];retlist = {stack[A](unpack(stack, A + 1, top))}; args = regs[PC + 45];A = args[13019573];do return unpack(stack, A, args[4455990]); end;args = regs[PC + 46];PC = PC + 46;goto RESET;
										end
									end
								end
							else
								if OP <= 0x02E5C72 then
									if OP <= 0x02716F1 then
										if OP > 0x02613E2 then
											stack[args[13019573]] = args[13439273];
										else
											proto = protos[args[5489828]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[13019573]]=lua_wrap_state(proto,ENV,uvlist);
										end
									else
										if OP > 0x0293957 then
											proto = protos[args[5489828]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[13019573]]=lua_wrap_state(proto,ENV,uvlist);
										else
											stack[args[13019573]] = #(stack[args[4455990]]);
										end
									end
								else
									if OP <= 0x0394026 then
										if OP > 0x0305202 then
											args = regs[PC + 1];stack[args[13019573]] = args[13439273];args = regs[PC + 2];stack[args[13019573]] = args[13439273];args = regs[PC + 3];stack[args[13019573]] = args[13439273];args = regs[PC + 4];A=args[13019573];init=stack[A]limit=stack[A+1]step=stack[A+2]stack[A]=init-step;stack[A+1]=limit;stack[A+2]=step;stack[A+3]=init;PC=PC+args[5489828];args = regs[PC + 5];PC = PC + 5;goto RESET;
										else
											do return stack[args[13019573]]; end;
										end
									else
										if OP > 0x03D4D33 then
											stack[args[13019573]] = nil;
										else
											stack[args[13019573]] = #(stack[args[4455990]]);
										end
									end
								end
							end
						else
							if OP <= 0x055319E then
								if OP <= 0x049C211 then
									if OP <= 0x041816B then
										do return stack[args[13019573]]; end;
									else
										if OP == 0x046CDCC then
											stack[args[13019573]] = stack[args[4455990]];
										else
											
										end
									end
								else
									if OP <= 0x0524E6C then
										if OP == 0x04F1863 then
											if ((stack[args[13019573]] < args[4455990]) ~= false) then PC = PC + 1; end;
										else
											
										end
									else
										if OP > 0x0549CF4 then
											A=args[13019573];limit=stack[A+1]step=stack[A+2]index=stack[A]index=index+step;stack[A]=index;if step>0 and index<=limit or step<=0 and index>=limit then stack[A+3]=index;PC=PC-args[5489828] end;
										else
											if ((stack[args[13019573]] < stack[args[4455990]]) ~= false) then PC = PC + 1; end;
										end
									end
								end
							else
								if OP <= 0x05CFA66 then
									if OP <= 0x057A9A2 then
										if OP > 0x0564B83 then
											proto = protos[args[5489828]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[13019573]]=lua_wrap_state(proto,ENV,uvlist);
										else
											
										end
									else
										if OP > 0x05A079E then
											A = args[13019573];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];
										else
											do return end;
										end
									end
								else
									if OP <= 0x0701143 then
										if OP == 0x066B348 then
											stack[args[13019573]] = false;
										else
											A=args[13019573];limit=stack[A+1]step=stack[A+2]index=stack[A]index=index+step;stack[A]=index;if step>0 and index<=limit or step<=0 and index>=limit then stack[A+3]=index;PC=PC-args[5489828] end;
										end
									else
										if OP > 0x072559B then
											do return stack[args[13019573]]; end;
										else
											stack[args[13019573]] = true;
										end
									end
								end
							end
						end
					else
						if OP <= 0x0B08AF7 then
							if OP <= 0x08EE8F7 then
								if OP <= 0x07AE80B then
									if OP <= 0x0787698 then
										PC = PC + args[16284868]; goto RESET;
									else
										if OP > 0x07A855F then
											stack[args[13019573]] = stack[args[4455990]];
										else
											stack[args[13019573]] = stack[args[4455990]][constants[args[670521]]];args = regs[PC + 1];stack[args[13019573]] = ENV[constants[args[670521]]];args = regs[PC + 2];stack[args[13019573]] = stack[args[4455990]][constants[args[670521]]];args = regs[PC + 3];stack[args[13019573]] = stack[args[4455990]];args = regs[PC + 4];A = args[13019573];retlist = {stack[A](stack[A + 1])}; retnum = #retlist; top = A + retnum - 1; move(retlist, 1, retnum, A, stack);args = regs[PC + 5];A = args[13019573];retlist = {stack[A](unpack(stack, A + 1, top))}; stack[A] = retlist[1];args = regs[PC + 6];stack[args[13019573]] = args[13439273];args = regs[PC + 7];A=args[13019573];init=stack[A]limit=stack[A+1]step=stack[A+2]stack[A]=init-step;stack[A+1]=limit;stack[A+2]=step;stack[A+3]=init;PC=PC+args[5489828];args = regs[PC + 8];PC = PC + 8;goto RESET;
										end
									end
								else
									if OP <= 0x0828DE4 then
										if OP > 0x07EA381 then
											do return stack[args[13019573]]; end;
										else
											do return stack[args[13019573]]; end;
										end
									else
										if OP == 0x08D2945 then
											stack[args[13019573]] = stack[args[4455990]];
										else
											proto = protos[args[5489828]];nups=proto.upvalueSize;uvlist={}for a=1,nups do if proto.upvalues[a-1].instack then index=proto.upvalues[a-1].idx;prev=openlist[index]if not prev then prev={index=index,store=stack}openlist[index]=prev end;uvlist[a-1]=prev else uvlist[a-1]=upvalues[proto.upvalues[a-1].idx]end end;stack[args[13019573]]=lua_wrap_state(proto,ENV,uvlist);
										end
									end
								end
							else
								if OP <= 0x0A28DB0 then
									if OP <= 0x095483F then
										if OP > 0x08EF498 then
											stack[args[13019573]] = ({});
										else
											PC = PC + args[16284868]; goto RESET;
										end
									else
										if OP > 0x09C0794 then
											PC = PC + args[16284868]; goto RESET;
										else
											PC = PC + args[16284868]; goto RESET;
										end
									end
								else
									if OP <= 0x0A9E01D then
										if OP == 0x0A4EC4F then
											stack[args[670521]] = stack[args[13019573]] % stack[args[4455990]];
										else
											stack[args[13019573]] = ({});args = regs[PC + 1];args = regs[PC + 2];stack[args[13019573]] = args[13439273];args = regs[PC + 3];stack[args[13019573]] = #(stack[args[4455990]]);args = regs[PC + 4];stack[args[13019573]] = args[13439273];args = regs[PC + 5];A=args[13019573];init=stack[A]limit=stack[A+1]step=stack[A+2]stack[A]=init-step;stack[A+1]=limit;stack[A+2]=step;stack[A+3]=init;PC=PC+args[5489828];args = regs[PC + 6];PC = PC + 6;goto RESET;
										end
									else
										if OP == 0x0B0677F then
											stack[args[13019573]] = stack[args[4455990]] + args[670521];args = regs[PC + 1];args = regs[PC + 2];stack[args[13019573]] = ENV[constants[args[670521]]];args = regs[PC + 3];stack[args[13019573]] = stack[args[4455990]][stack[args[670521]]];args = regs[PC + 4];A = args[13019573];retlist = {stack[A](stack[A + 1])}; stack[A] = retlist[1];args = regs[PC + 5];stack[args[13019573]][stack[args[4455990]]] = stack[args[670521]];args = regs[PC + 6];PC = PC + 6;goto RESET;
										else
											stack[args[13019573]] = stack[args[4455990]];
										end
									end
								end
							end
						else
							if OP <= 0x0DC2ACC then
								if OP <= 0x0C15A36 then
									if OP <= 0x0B5349C then
										stack[args[13019573]][stack[args[4455990]]] = stack[args[670521]];
									else
										if OP > 0x0BDDD14 then
											stack[args[670521]] = stack[args[13019573]] % stack[args[4455990]];
										else
											stack[args[13019573]] = stack[args[4455990]] + args[670521];
										end
									end
								else
									if OP <= 0x0D3601E then
										if OP == 0x0C39881 then
											if ((stack[args[13019573]] < stack[args[4455990]]) ~= false) then PC = PC + 1; end;
										else
											PC = PC + args[16284868];
										end
									else
										if OP == 0x0DAC6CC then
											do return stack[args[13019573]]; end;
										else
											stack[args[13019573]] = ENV[constants[args[670521]]];
										end
									end
								end
							else
								if OP <= 0x0EEB731 then
									if OP <= 0x0E2C2D4 then
										if OP == 0x0DC397E then
											do return stack[args[13019573]]; end;
										else
											if ((stack[args[13019573]] == args[4455990]) ~= true) then PC = PC + 1 end;
										end
									else
										if OP > 0x0EDD7F4 then
											do return end;
										else
											stack[args[13019573]] = false;
										end
									end
								else
									if OP <= 0x0F8BDD9 then
										if OP == 0x0EF92F7 then
											if (not stack[args[13019573]] == false) then PC = PC + 1; end;
										else
											stack[args[13019573]] = ENV[constants[args[670521]]];
										end
									else
										if OP == 0x0FB7677 then
											A=args[13019573];limit=stack[A+1]step=stack[A+2]index=stack[A]index=index+step;stack[A]=index;if step>0 and index<=limit or step<=0 and index>=limit then stack[A+3]=index;PC=PC-args[5489828] end;
										else
											PC = PC + args[16284868]; goto RESET;
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
