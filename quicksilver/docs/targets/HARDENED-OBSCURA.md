# Hardened Obscura (vm-max, vm-cached): investigation record

Source: github.com/vo3pal/obscura at 5657a73 (v1.1.0, MIT), fetched and read as text (`layers/vm/interpreter.py`, `compiler.py`, `config.py`). The
plain VM (`--mode vm` before 1.1.0) has been lifted since Prompt XI (`src/recover/obscura-vm.js`). The hardened profiles are not lifted.

## What the hardened profiles add (config.py `_resolve_vm_profile`)

`client-max` and `max` turn on eleven features at once. `max` alone adds extended fusion.

| Feature | What it does | What a lifter has to do |
|---|---|---|
| per-proto keys, dynamic keys | each prototype's bytes are encrypted with its own key table, itself keyed | evaluate the key set-up (static, like RealObfuscator's codec) |
| integrity check | hash over bytes and constants | verify, as a check that decoding is right |
| lazy / partitioned constants, encoded numbers | constants decoded on first use, per prototype, numbers encoded | read the pool per prototype |
| operand layouts, handler variants | every opcode picks its own operand order and byte order, and one of three handler shapes | read the order per opcode from its handler |
| range-tree dispatch | `if op <= N` tree instead of a flat chain | flatten to leaves (done for RealObfuscator) |
| fused instructions, superinstructions, extended fusion | several operations in one generated handler (`BLOCKn`) | split a handler into the templates it was made from |

## Why this was not done in this round

RealObfuscator and MoonVeil 2.1.0 took priority: RealObfuscator's VM was fully tractable with one lifter covering its 20 builds, and MoonVeil
2.1.0 was the named milestone. Hardened Obscura needs all of the work in the table above.

## Next experiment

Apply the MoonVeil 2.1.0 technique: partially evaluate each instruction through its handler, with the instruction's bytes known. That handles
operand order, byte order, handler variants and fused handlers without a template per variant. The key set-up and the constant pool would be
evaluated statically, as RealObfuscator's codec is. The 14 hardened 1.1.0 fixtures and 6 earlier ones are committed (MIT) and ready.
