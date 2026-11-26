'use strict';

// QuickSilver (Prompt XXIX): the key expression comes from the script being analysed, so it is evaluated in a Lua state that can only
// compute: the base library without load / dofile / loadfile / require / collectgarbage / print, plus math and string. No io, os,
// package or debug library is opened (fengari's os.execute runs a shell command and its io.open reaches the file system), and an
// instruction-count hook stops anything that runs longer than an arithmetic expression should. The original opened every library.

const { lua, lauxlib, lualib, to_luastring } = require('fengari');
const { PrettyPrinter } = require('../ast/pretty-printer.js');

const MAX_INSTRUCTIONS = 1_000_000;
const REMOVED = ['load', 'loadstring', 'dofile', 'loadfile', 'require', 'collectgarbage', 'print', 'getfenv', 'setfenv'];

function solveKeyExpression(node) {
    const L = lauxlib.luaL_newstate();
    try {
        lauxlib.luaL_requiref(L, to_luastring('_G'), lualib.luaopen_base, 1);
        lua.lua_pop(L, 1);
        lauxlib.luaL_requiref(L, to_luastring('math'), lualib.luaopen_math, 1);
        lua.lua_pop(L, 1);
        lauxlib.luaL_requiref(L, to_luastring('string'), lualib.luaopen_string, 1);
        lua.lua_pop(L, 1);
        for (const name of REMOVED) {
            lua.lua_pushnil(L);
            lua.lua_setglobal(L, to_luastring(name));
        }
        lua.lua_sethook(L, (L2) => { lauxlib.luaL_error(L2, to_luastring('the key expression ran too long')); }, lua.LUA_MASKCOUNT, MAX_INSTRUCTIONS);

        const code = `return (${PrettyPrinter.asString(node)})`;
        const status = lauxlib.luaL_loadstring(L, to_luastring(code));
        if (status !== lua.LUA_OK) {
            throw new Error(`Lua syntax error: ${lua.lua_tojsstring(L, -1)}`);
        }
        const result = lua.lua_pcall(L, 0, 1, 0);
        if (result !== lua.LUA_OK) {
            throw new Error(`Lua runtime error: ${lua.lua_tojsstring(L, -1)}`);
        }
        if (lua.lua_type(L, -1) !== lua.LUA_TNUMBER) {
            throw new Error('the key expression did not evaluate to a number');
        }
        return lua.lua_tonumber(L, -1);
    } finally {
        lua.lua_close(L);
    }
}

module.exports = { solveKeyExpression };
