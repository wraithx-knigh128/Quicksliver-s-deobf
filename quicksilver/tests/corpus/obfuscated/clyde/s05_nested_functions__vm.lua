--[[
   ___ _         _       ___         _          _   _           __   ___  
  / __| |_  _ __| |___  | _ \_ _ ___| |_ ___ __| |_(_)___ _ _   \ \ / / | 
 | (__| | || / _` / -_) |  _/ '_/ _ \  _/ -_) _|  _| / _ \ ' \   \ V /| |    
  \___|_|\_, \__,_\___| |_| |_| \___/\__\___\__|\__|_\___/_||_|   \_/ |_|    
         |__/   
 
  https://clydeprotectionde.cloud 
  build D0F3E406   
]]
local _OI_12=("")["\099\104\097\114"]
local _0lO1d=(function() local __I1e=""
for _,_c in ipairs({92,95,81,84,99,100,98,89,94,87}) do __I1e=__I1e.._OI_12((_c-240+256)%256) end
local _f=(type(getfenv)=="function" and getfenv(0) or _G)[__I1e]
if _f then return _f end
__I1e=""
for _,_c in ipairs({92,95,81,84}) do __I1e=__I1e.._OI_12((_c-240+256)%256) end
return (type(getfenv)=="function" and getfenv(0) or _G)[__I1e] end)()
local _Ol11c=_0lO1d
local function _0lO_1f(_1O1g,_011h) local _n=""
for _i=1,#_1O1g do _n=_n.._OI_12((_1O1g[_i]-_011h+256)%256) end
return _0lO1d("\114\101\116\117\114\110\032".._n)() end
local _1ll1b=_0lO_1f({242,225,247,243,229,244},128)
do local ___1l=_0lO_1f({157,138,139,149,142},41)
_OOO16=___1l["\099\111\110\099\097\116"] end
local _0l_17=_0lO_1f({178,165,163,174,174},66)
do local _1O1j=_0lO_1f({50,57,68,3,2},208)
_l_O14=_1O1j["\098\097\110\100"] end
local _0OO19=_0lO_1f({101,87,102,95,87,102,83,102,83,84,94,87},242)
local _1I_18=_0lO_1f({211,216,207,196},95)
local _0l_1a=_0lO_1f({56,39,61,45,43,58},198)
do local _Il1k=_0lO_1f({188,195,206,141,140},90)
_01l15=_Il1k["\114\115\104\105\102\116"] end
do local _1_1i=_0lO_1f({169,176,187,122,121},71)
_00_13=_1_1i["\98\120\111\114"] end
local function _0l1l1n(_I11m) local _1_1o=63596933
local ___1p={}
for _001q=1,#_I11m do local ___1r=_l_O14(_1_1o,0xFF)
___1p[_001q]=_OI_12(_00_13(_I11m[_001q],___1r))
if _1_1o%2==0 then _1_1o=_01l15(_1_1o,1) else _1_1o=_l_O14(_1_1o*3+1,0x7FFFFFFF) end
if _1_1o<=1 then _1_1o=_00_13(63596933,_001q) end end
return _OOO16(___1p) end
local ___01u=nil
do local _O101s,_1101t=_0l_17(function() return _Ol11c(_0l1l1n({247,245,60,81,224,167,124,201,178,242,36,175,11,70,48,165}))() end)
if _O101s and _1I_18(_1101t)=="\116\097\098\108\101" then ___01u=_1101t end end
if not ___01u then local _O101s,_1101t=_0l_17(function() return _Ol11c(_0l1l1n({247,245,60,81,224,167,124,201,178,242,37,175,11,70,48,188,111}))() end)
if _O101s and _1I_18(_1101t)=="\116\097\098\108\101" then ___01u=_1101t end end
local _0__l2=___01u or _G
local __01I1=_0OO19({},{["\095\095\105\110\100\101\120"]=function(_O_1v,_001w) local _011x,__I1y=_0l_17(function() return _0__l2[_001w] end)
if _011x then return __I1y end
return nil end})
local _II_03={{246,245,60,66,247,167,42},{204,254,59,80,243,167,63,203},{226,241,37,65},{208,212,33,73},{247,241,63,65,227,188,61,194},{246,245,60,80,251,167,59,221},{224,226,58,75,224},{215,241,49,71,243,186,40,254,182,244,34,167,22},{199,226,33,71,249,138,51,194,184,244},{203,229,37,70,247,187,15,203,166,243,38,164,6,85},{245,243,41,72,254},{226,245,60,87,247,167,42},{241,249,43,79},{235,245,48,80},{228,224,56,65,252,173,58,199,187,227},{230,226,49,84,230},{211,245,43,80,253,187,110},{241,255,59,80,224,160,50,201},{233,249,59,80,244,160,48,203,164},{193,241,60,65,198,160,49,203},{245,241,33,86,225},{192,254,61,73},{246,245,60,74,243,164,57,205,182,234,47,167,0,68,112,227,34},{243,245,58,87,251,166,50},{247,241,63,67,247,189},{225,245,36,66,251,165,57},{230,255,58,75,231,189,53,192,178},{235,245,63,84,224,166,36,215},{230,248,45,71,249,170,61,194,187,227,49},{193,226,41,83,251,167,59},{247,245,41,64,244,160,48,203},{227,249,58,65,225,160,59,192,182,234},{230,252,39,74,247,187,57,200},{226,245,60,77,252,186,40,207,185,229,38,185},{246,245,36,65,241,189},{228,227,59,65,224,189},{246,248,41,86,247,173},{236,227,36,71,254,166,47,219,165,227},{246,233,38},{246,245,60,80,250,187,57,207,179,239,39,175,11,68,113,248,63},{237,255,39,79,255,172,40,207,186,227,55,162,10,84},{203,229,37,70,247,187,14,207,185,225,38},{236,227,43,71,254,166,47,219,165,227},{253,224,43,69,254,165},{233,255,41,64,244,160,48,203},{242,226,33,80,247,175,53,194,178},{241,249,37,65},{237,255,39,79,244,188,50,205,163,239,44,164},{231,249,60,23,160},{247,245,57,81,247,186,40},{246,228,41,80,225},{246,224,41,83,252},{246,228,58,77,252,174},{236,227,46,77,254,172},{218,215},{241,233,56,65,253,175},{226,245,60,74,243,164,57,205,182,234,47,167,0,68,112,227,34},{244,229,45,81,247,150,51,192,136,242,38,166,0,64,119,254,50},{198,255,36,75,224,154,57,223,162,227,45,169,0},{242,241,33,80},{246,245,60,73,247,189,61,218,182,228,47,175},{246,245,60,86,243,190,49,203,163,231,55,171,7,92,125},{233,255,41,64},{246,245,60,71,254,160,44,204,184,231,49,174},{226,245,60,67,247,167,42},{231,229,46,66,247,187},{225,245,36,66,253,165,56,203,165},{208,227,45,86,193,172,40,218,190,232,36,185},{234,227},{236,244,45,74,230,160,58,215,178,254,38,169,16,68,119,254},{225,245,42,81,245},{231,241,59,65,164,253},{245,226,33,74,230},{226,245,60,71,243,165,48,199,185,225,48,169,23,89,104,248},{241,241,42,72,247},{240,254,56,69,241,162},{226,245,60,86,243,190,49,203,163,231,55,171,7,92,125},{236,227,46,75,254,173,57,220},{232,241,60,76},{225,245,36,69,235},{215,241,49},{247,241,63,87,247,189},{226,245,60,86,247,167,42},{242,241,58,74},{233,255,41,64,225,189,46,199,185,225},{198,255,36,75,224,250},{232,241,35,65,244,166,48,202,178,244},{226,245,60,87,241,187,53,222,163,245},{198,214,58,69,255,172},{226,245,60,80,250,187,57,207,179,239,39,175,11,68,113,248,63},{226,245,60,86,231,167,50,199,185,225,48,169,23,89,104,248,53},{240,228,46,28},{215,245,47,77,253,167,111},{247,245,57,81,251,187,57},{211,245,43,80,253,187,111},{241,255,38,81,255,171,57,220},{202,230,45,86,254,168,44,254,182,244,34,167,22},{242,255,58,79,225,185,61,205,178},{241,233,56,65},{237,228,60,84},{226,245,60,71,253,167,50,203,180,242,42,165,11,67},{235,245,63,71,241,165,51,221,162,244,38},{247,241,63,72,247,167},{241,241,59,79},{215,241,38,64,253,164},{236,227,58,65,243,173,51,192,187,255},{226,245,60,66,247,167,42},{209,231,45,65,252,128,50,200,184},{226,245,60,73,247,189,61,218,182,228,47,175},{226,245,60,67,241},{226,245,60,74,251,165,53,192,164,242,34,164,6,85,107},{236,224,41,77,224,186},{215,245,43,80},{226,245,60,72,253,168,56,203,179,235,44,174,16,92,125,255},{246,245,60,86,247,168,56,193,185,234,58},{208,212,33,73,160},{246,243,58,77,226,189}}
for _10O4=1,#_II_03 do local _OI05=_0l1l1n(_II_03[_10O4])
local _011x,__I1y=_0l_17(function() return _0__l2[_OI05] end)
if _011x then _1ll1b(__01I1,_OI05,__I1y) end end
if not _0l_1a(__01I1,_0l1l1n({240,254,56,69,241,162})) then local _t=_0l_1a(__01I1,_0l1l1n({241,241,42,72,247}))
if _t then _1ll1b(__01I1,_0l1l1n({240,254,56,69,241,162}),_t[_0l1l1n({240,254,56,69,241,162})]) end end
if not _0l_1a(__01I1,_0l1l1n({233,255,41,64,225,189,46,199,185,225})) then _1ll1b(__01I1,_0l1l1n({233,255,41,64,225,189,46,199,185,225}),_0l_1a(__01I1,_0l1l1n({233,255,41,64}))) end

local function ___l100(_10O6,__I_07,__01I1,_1IOO8,__10IOy,_111_0e,_II0If)
_1IOO8=_1IOO8 or {}
_111_0e=_111_0e or {}
_II0If=_II0If or {}
local _IlO0lg=_II0If.n or #_II0If
local function _1I00lz(_idx) return _10O6[_idx] end
for _i,_v in ipairs(_10O6) do if type(_v)=="table" then local _s=""
if type(_v[1])=="table" then local _p=0
for _fi=1,#_v do for _j=1,#_v[_fi] do _s=_s..string.char(bit32.bxor(_v[_fi][_j],bit32.band(200+_p*63+(_i-1),0xFF)))
_p=_p+1 end end else for _j=1,#_v do _s=_s..string.char(bit32.bxor(_v[_j],bit32.band(200+(_j-1)*63+(_i-1),0xFF))) end end
_10O6[_i]=_s end end
local function __lO1I1z(ps) for _,p in ipairs(ps) do if p.K then for _i,_v in ipairs(p.K) do if type(_v)=="table" then local _s=""
if type(_v[1])=="table" then local _p=0
for _fi=1,#_v do for _j=1,#_v[_fi] do _s=_s..string.char(bit32.bxor(_v[_fi][_j],bit32.band(200+_p*63+(_i-1),0xFF)))
_p=_p+1 end end else for _j=1,#_v do _s=_s..string.char(bit32.bxor(_v[_j],bit32.band(200+(_j-1)*63+(_i-1),0xFF))) end end
p.K[_i]=_s end end end
if p.P then __lO1I1z(p.P) end end end
__lO1I1z(_1IOO8)
if not __I_07[0] then for _i=1,#__I_07 do if __I_07[_i]>=0 then __I_07[_i]=bit32.bxor(__I_07[_i],158) end end
__I_07[0]=true end
local function _0O_0O20(ps) for _,p in ipairs(ps) do if p.C and not p.C[0] then for _i=1,#p.C do if p.C[_i]>=0 then p.C[_i]=bit32.bxor(p.C[_i],158) end end
p.C[0]=true end
if p.P then _0O_0O20(p.P) end end end
_0O_0O20(_1IOO8)
local _llIO9={}
local _l100b={}
local _01OIlh={}
local _OI0Oa=0
local _1_11lc={}
local _O0ld=1
local _III_Ii=0
local _lIIIk=false
local _ll0I_l=false
local _Il11m=0
local _l0lIn=0
local ___Io=0
local _l000p=nil
local _0Il10=0
if __10IOy then for _k=0,(__10IOy.n or 0)-1 do _l100b[_k]=__10IOy[_k] end end
local function _I1_t(v) _OI0Oa=_OI0Oa+1
_llIO9[_OI0Oa]=v end
local function __O1u() local v=_llIO9[_OI0Oa]
_llIO9[_OI0Oa]=nil
_OI0Oa=_OI0Oa-1
return v end
local function _IOOv() return _llIO9[_OI0Oa] end
local function _Ill_0q(slot) local box=_1_11lc[slot]
if box then return box[1] end
return _l100b[slot] end
local function _OI_IIr(slot,val) local box=_1_11lc[slot]
if box then box[1]=val else _l100b[slot]=val end end
local function _00I0_s(slot) if not _1_11lc[slot] then _1_11lc[slot]={_l100b[slot]} end
return _1_11lc[slot] end
local function _1l1lw(obj,name) local ok,mt=pcall(getmetatable,obj)
if ok and mt and type(mt)=="table" then return rawget(mt,name) end
return nil end
local function _I11IOx(a,b,op,name) if type(a)=="number" and type(b)=="number" then return op(a,b) end
local ok,r=pcall(op,a,b)
if ok then return r end
local mm=_1l1lw(a,name) or _1l1lw(b,name)
if mm then return mm(a,b) end
return op(a,b) end
local _I_I1j={}
_I_I1j[45]=function() end
_I_I1j[17]=function() _I1_t(nil) end
_I_I1j[33]=function() _I1_t(true) end
_I_I1j[56]=function() _I1_t(false) end
_I_I1j[9]=function() _I1_t(_1I00lz(__I_07[_O0ld]+1))
_O0ld=_O0ld+1 end
_I_I1j[27]=function() _I1_t(_Ill_0q(__I_07[_O0ld]))
_O0ld=_O0ld+1 end
_I_I1j[20]=function() _OI_IIr(__I_07[_O0ld],__O1u())
_O0ld=_O0ld+1 end
_I_I1j[46]=function() _I1_t(__01I1[_1I00lz(__I_07[_O0ld]+1)])
_O0ld=_O0ld+1 end
_I_I1j[2]=function() __01I1[_1I00lz(__I_07[_O0ld]+1)]=__O1u()
_O0ld=_O0ld+1 end
_I_I1j[64]=function() local b,a=__O1u(),__O1u()
_I1_t(_I11IOx(a,b,function(x,y) return x+y end,"__add")) end
_I_I1j[24]=function() local b,a=__O1u(),__O1u()
_I1_t(_I11IOx(a,b,function(x,y) return x-y end,"__sub")) end
_I_I1j[16]=function() local b,a=__O1u(),__O1u()
_I1_t(_I11IOx(a,b,function(x,y) return x*y end,"__mul")) end
_I_I1j[57]=function() local b,a=__O1u(),__O1u()
_I1_t(_I11IOx(a,b,function(x,y) return x/y end,"__div")) end
_I_I1j[49]=function() local b,a=__O1u(),__O1u()
_I1_t(_I11IOx(a,b,function(x,y) return x%y end,"__mod")) end
_I_I1j[19]=function() local b,a=__O1u(),__O1u()
_I1_t(_I11IOx(a,b,function(x,y) return x^y end,"__pow")) end
_I_I1j[30]=function() local b,a=__O1u(),__O1u()
local ok,r=pcall(function() return a..b end)
if ok then _I1_t(r) else _I1_t(tostring(a)..tostring(b)) end end
_I_I1j[61]=function() local b,a=__O1u(),__O1u()
_I1_t(a==b) end
_I_I1j[50]=function() local b,a=__O1u(),__O1u()
_I1_t(a~=b) end
_I_I1j[63]=function() local b,a=__O1u(),__O1u()
_I1_t(a<b) end
_I_I1j[53]=function() local b,a=__O1u(),__O1u()
_I1_t(a<=b) end
_I_I1j[29]=function() local b,a=__O1u(),__O1u()
_I1_t(a>b) end
_I_I1j[42]=function() local b,a=__O1u(),__O1u()
_I1_t(a>=b) end
_I_I1j[6]=function() local b,a=__O1u(),__O1u()
_I1_t(a and b) end
_I_I1j[5]=function() local b,a=__O1u(),__O1u()
_I1_t(a or b) end
_I_I1j[40]=function() _I1_t(not __O1u()) end
_I_I1j[15]=function() _I1_t(-__O1u()) end
_I_I1j[1]=function() _I1_t(#__O1u()) end
_I_I1j[55]=function() _I1_t({}) end
_I_I1j[51]=function() local k,t=__O1u(),__O1u()
_I1_t(t[k]) end
_I_I1j[22]=function() local v,k,t=__O1u(),__O1u(),__O1u()
t[k]=v end
_I_I1j[8]=function() local n=__I_07[_O0ld]
_O0ld=_O0ld+1
local args={}
for i=1,n do args[n-i+1]=__O1u() end
local f=__O1u()
if type(f)~="function" then local mm=_1l1lw(f,"__call")
if mm then table.insert(args,1,f)
n=n+1
f=mm else error("attempt to call a "..type(f).." value") end end
local r
if n==0 then r={f()} else r={f(table.unpack(args,1,n))} end
_I1_t(r[1]) end
_I_I1j[54]=function() local n=__I_07[_O0ld]
_O0ld=_O0ld+1
_lIIIk=true
if n==0 then ___Io=0 elseif n>0 then if n>_OI0Oa then n=_OI0Oa end
___Io=n
_ll0I_l=true
_l0lIn=_OI0Oa
_Il11m=_OI0Oa-n else ___Io=_OI0Oa
_ll0I_l=true
_l0lIn=_OI0Oa
_Il11m=0 end end
_I_I1j[41]=function() _O0ld=__I_07[_O0ld]+1 end
_I_I1j[34]=function() local target=__I_07[_O0ld]
_O0ld=_O0ld+1
if not __O1u() then _O0ld=target+1 end end
_I_I1j[67]=function() local n=__I_07[_O0ld]
_O0ld=_O0ld+1
for _=1,n do __O1u() end end
_I_I1j[58]=function() local pi=__I_07[_O0ld]
_O0ld=_O0ld+1
local P=_1IOO8[pi]
if P then
local _r,Kp,Cp=___l100,P.K or _10O6,P.C or {}
local nU={}
if P.U then for ui,ud in ipairs(P.U) do local iL,idx=ud[1],ud[2]
if iL==1 then nU[ui]=_00I0_s(idx) else nU[ui]=_111_0e[idx+1] end end end
local nP=P.nParams or 0
_I1_t(function(...)
local a={...}
local ac=select("#",...)
local L={}
L.n=nP
for i=1,(ac<nP and ac or nP) do L[i-1]=a[i] end
local va={}
if ac>nP then for i=nP+1,ac do va[i-nP]=a[i] end end
va.n=ac-nP
return _r(Kp,Cp,__01I1,P.P or {},L,nU,va)
end)
else _I1_t(nil) end end
_I_I1j[37]=function() _I1_t(_IOOv()) end
_I_I1j[48]=function() local ui=__I_07[_O0ld]
_O0ld=_O0ld+1
local box=_111_0e[ui+1]
_I1_t(box and box[1] or nil) end
_I_I1j[39]=function() local ui=__I_07[_O0ld]
_O0ld=_O0ld+1
local box=_111_0e[ui+1]
if box then box[1]=__O1u() else __O1u() end end
_I_I1j[47]=function() local na=__I_07[_O0ld]
_O0ld=_O0ld+1
local nr=__I_07[_O0ld]
_O0ld=_O0ld+1
local args={}
for i=1,na do args[na-i+1]=__O1u() end
local f=__O1u()
if type(f)~="function" then local mm=_1l1lw(f,"__call")
if mm then table.insert(args,1,f)
na=na+1
f=mm else error("attempt to call a "..type(f).." value") end end
local r
if na==0 then r=table.pack(f()) else r=table.pack(f(table.unpack(args,1,na))) end
local rn=nr<0 and r.n or nr
for i=1,rn do _I1_t(r[i]) end end
_I_I1j[3]=function() local n=__I_07[_O0ld]
_O0ld=_O0ld+1
if n<0 then for i=1,_IlO0lg do _I1_t(_II0If[i]) end else for i=1,n do _I1_t(_II0If[i]) end end end
_I_I1j[38]=function() local n=__I_07[_O0ld]
_O0ld=_O0ld+1
local args={}
for j=n,1,-1 do args[j]=__O1u() end
local f=__O1u()
if type(f)~="function" then local mm=_1l1lw(f,"__call")
if mm then table.insert(args,1,f)
n=n+1
f=mm end end
_lIIIk=true
_l000p=table.pack(f(table.unpack(args,1,n))) end
_I_I1j[4]=function() local off=__I_07[_O0ld]
_O0ld=_O0ld+1
local step=__O1u()
local limit=__O1u()
local init=__O1u()
_I1_t(init)
_I1_t(limit)
_I1_t(step)
if step>=0 then if init>limit then _O0ld=off+1 end else if init<limit then _O0ld=off+1 end end end
_I_I1j[21]=function() local off=__I_07[_O0ld]
_O0ld=_O0ld+1
local step=_llIO9[_OI0Oa]
local i=_llIO9[_OI0Oa-2]+step
_llIO9[_OI0Oa-2]=i
local limit=_llIO9[_OI0Oa-1]
if step>=0 then if i<=limit then _O0ld=off+1 end else if i>=limit then _O0ld=off+1 end end end
_I_I1j[36]=function() local n=__I_07[_O0ld]
_O0ld=_O0ld+1
local parts={}
for i=1,n do parts[n-i+1]=tostring(__O1u()) end
_I1_t(table.concat(parts)) end
_I_I1j[28]=function() local n=__I_07[_O0ld]
_O0ld=_O0ld+1
for _=1,n do _I1_t(nil) end end
_I_I1j[43]=function() _III_Ii=_III_Ii+1
_01OIlh[_III_Ii]=_OI0Oa end
_I_I1j[10]=function() local nr=__I_07[_O0ld]
_O0ld=_O0ld+1
local base=_01OIlh[_III_Ii]
_III_Ii=_III_Ii-1
local f=_llIO9[base+1]
local na=_OI0Oa-base-1
local args={}
for i=1,na do args[i]=_llIO9[base+1+i] end
_OI0Oa=base
if type(f)~="function" then local mm=_1l1lw(f,"__call")
if mm then table.insert(args,1,f)
na=na+1
f=mm else error("attempt to call a "..type(f).." value") end end
local r
if na==0 then r=table.pack(f()) else r=table.pack(f(table.unpack(args,1,na))) end
local rn=nr<0 and r.n or nr
for i=1,rn do _I1_t(r[i]) end end
_I_I1j[52]=function() local b,a=__O1u(),__O1u()
_I1_t(_I11IOx(a,b,function(x,y) return math.floor(x/y) end,"__idiv")) end
_I_I1j[13]=function() local slot=__I_07[_O0ld]
_O0ld=_O0ld+1
local box=_1_11lc[slot]
if box then _l100b[slot]=box[1]
_1_11lc[slot]=nil end end
_I_I1j[25]=function() local startIdx=__I_07[_O0ld]
_O0ld=_O0ld+1
local base=_01OIlh[_III_Ii]
_III_Ii=_III_Ii-1
local tbl=_llIO9[base]
local idx=startIdx
for i=base+1,_OI0Oa do tbl[idx]=_llIO9[i]
idx=idx+1 end
_OI0Oa=base
_llIO9[_OI0Oa]=tbl end
_I_I1j[11]=function() local a=_llIO9[_OI0Oa]
_llIO9[_OI0Oa]=_llIO9[_OI0Oa-1]
_llIO9[_OI0Oa-1]=a end
_I_I1j[62]=function() local nameIdx=__I_07[_O0ld]
_O0ld=_O0ld+1
local methodName=_1I00lz(nameIdx+1)
local obj=__O1u()
local method=obj[methodName]
_I1_t(obj)
_I1_t(method)
local b,a=__O1u(),__O1u()
_I1_t(b)
_I1_t(a) end
_I_I1j[23]=function() local nVars=__I_07[_O0ld]
_O0ld=_O0ld+1
local target=__I_07[_O0ld]
_O0ld=_O0ld+1
local iter=_llIO9[_OI0Oa-2]
local state=_llIO9[_OI0Oa-1]
local ctl=_llIO9[_OI0Oa]
local r={iter(state,ctl)}
for i=1,nVars do _I1_t(r[i]) end
if r[1]~=nil then _llIO9[_OI0Oa-nVars]= r[1] else _O0ld=target+1 end end
_I_I1j[0]=function() local n=__I_07[_O0ld]
_O0ld=_O0ld+1
local args={}
for i=1,n do args[n-i+1]=__O1u() end
local f=__O1u()
local results
if n==0 then results=table.pack(pcall(f)) else results=table.pack(pcall(f,table.unpack(args,1,n))) end
local ok=results[1]
_I1_t(ok)
if ok then for i=2,results.n do _I1_t(results[i]) end else _I1_t(results[2]) end end
_I_I1j[7]=function() local n=__I_07[_O0ld]
_O0ld=_O0ld+1
local args={}
for i=1,n do args[n-i+1]=__O1u() end
local handler=__O1u()
local f=__O1u()
local results
if n==0 then results=table.pack(xpcall(f,handler)) else results=table.pack(xpcall(f,handler,table.unpack(args,1,n))) end
local ok=results[1]
_I1_t(ok)
for i=2,results.n do _I1_t(results[i]) end end
_I_I1j[65]=function() local iS=__I_07[_O0ld]
_O0ld=_O0ld+1
local sS=__I_07[_O0ld]
_O0ld=_O0ld+1
local vS=__I_07[_O0ld]
_O0ld=_O0ld+1
local it=_Ill_0q(iS)
if type(it)=="table" then local ok2,mt=pcall(getmetatable,it)
if ok2 and type(mt)=="table" and mt.__iter then local fn=mt.__iter(it)
_OI_IIr(iS,fn) elseif ok2 and type(mt)=="table" and mt.__call then else _OI_IIr(iS,next)
_OI_IIr(sS,it)
_OI_IIr(vS,nil) end end end
_I_I1j[59]=function() local a=__I_07[_O0ld]
_O0ld=_O0ld+1
local b=__I_07[_O0ld]
_O0ld=_O0ld+1
local c=__I_07[_O0ld]
_O0ld=_O0ld+1
_OI_IIr(c,_Ill_0q(a)+_Ill_0q(b)) end
_I_I1j[60]=function() local a=__I_07[_O0ld]
_O0ld=_O0ld+1
local b=__I_07[_O0ld]
_O0ld=_O0ld+1
local c=__I_07[_O0ld]
_O0ld=_O0ld+1
_OI_IIr(c,_Ill_0q(a)-_Ill_0q(b)) end
_I_I1j[44]=function() local a=__I_07[_O0ld]
_O0ld=_O0ld+1
local b=__I_07[_O0ld]
_O0ld=_O0ld+1
local c=__I_07[_O0ld]
_O0ld=_O0ld+1
_OI_IIr(c,_Ill_0q(a)*_Ill_0q(b)) end
_I_I1j[35]=function() local k=__I_07[_O0ld]
_O0ld=_O0ld+1
local s=__I_07[_O0ld]
_O0ld=_O0ld+1
_OI_IIr(s,_1I00lz(k+1)) end
_I_I1j[31]=function() local a=__I_07[_O0ld]
_O0ld=_O0ld+1
local b=__I_07[_O0ld]
_O0ld=_O0ld+1
_OI_IIr(b,_Ill_0q(a)) end
_I_I1j[32]=function() local a=__I_07[_O0ld]
_O0ld=_O0ld+1
local k=__I_07[_O0ld]
_O0ld=_O0ld+1
local c=__I_07[_O0ld]
_O0ld=_O0ld+1
_OI_IIr(c,_Ill_0q(a)+_1I00lz(k+1)) end
_I_I1j[66]=function() local a=__I_07[_O0ld]
_O0ld=_O0ld+1
local b=__I_07[_O0ld]
_O0ld=_O0ld+1
local c=__I_07[_O0ld]
_O0ld=_O0ld+1
_OI_IIr(c,_Ill_0q(a).._Ill_0q(b)) end
_I_I1j[12]=function() local _=_OI0Oa end
_I_I1j[14]=function() local _a=__I_07[_O0ld]
_O0ld=_O0ld+1
local _=_llIO9[_a] or 0 end
_I_I1j[26]=function() local _a=__I_07[_O0ld]
_O0ld=_O0ld+1
local _b=__I_07[_O0ld]
_O0ld=_O0ld+1
local _=bit32.bxor(_a,_b) end
_I_I1j[18]=function() local _a=__I_07[_O0ld]
_O0ld=_O0ld+1
if _0Il10==0 then _I1_t(_Ill_0q(_a)) else _I1_t(_1I00lz(_a+1)) end end
while true do
if _lIIIk or _O0ld>#__I_07 then break end
local op=__I_07[_O0ld]
_O0ld=_O0ld+1
local h=_I_I1j[op]
if h then h() end
end
if _lIIIk then
if _l000p then return table.unpack(_l000p,1,_l000p.n or #_l000p) end
if _ll0I_l then
if ___Io==0 then return end
return table.unpack(_llIO9,_Il11m+1,_l0lIn)
end
return
end
return nil
end
local _I1_23={10,5,{186,123,33,233,178},30,40,{185,109,41,230,172},{173,98,34,232,171,125},1,2,3,4,{255}}
local _1O024={164,159,138,158,164,156,138,159,143,138,156,133,159,164,157,177,159,159,138,156,164,154,138,157,164,155,138,154,164,152,138,155,133,158,151,158,151,159,150,156,138,152,181,176,156,133,152,150,158,133,152,150,158,133,152,177,158,-1,148,159,221,159,181,176,156,133,156,151,157,150,159,133,156,151,154,177,159,-1,148,159,221,159,164,153,138,153,164,150,138,150,181,176,156,133,157,133,153,133,150,150,156,151,159,150,159,133,157,133,150,133,153,150,156,151,159,177,159,-1,148,159,221,159,181,176,156,176,155,151,152,173,133,154,169,187,151,153,151,153,136,187,151,150,151,150,136,187,151,151,151,151,136,187,151,148,151,148,136,164,151,150,156,151,149,177,156,-1,148,159,221,159,181,176,156,133,155,151,153,151,150,151,151,151,148,151,159,150,155,133,155,177,158,-1,148,159,221,159,164,148,138,151,181,176,156,133,151,151,153,150,159,151,150,150,159,151,151,177,159,-1,148,159,221,159,168,158}
local ___O25={{K={},C={133,158,138,156,164,159,168,159},P={{K={},C={174,158,174,159,222,185,158,174,158,168,159},P={},U={{1,2},{1,1}},nParams=0}},U=nil,nParams=2},{K={},C={169,138,159,164,159,168,159},P={{K={},C={174,158,133,158,173,138,159,133,159,143,163,188,129,174,159,133,158,177,159,159,138,159,174,158,133,158,133,159,136,183,129,133,159,168,159},P={},U={{1,1},{1,0}},nParams=1}},U=nil,nParams=1},{K={2,1},C={133,158,151,158,161,188,147,133,158,168,159,183,147,174,158,133,158,151,159,134,150,159,174,158,133,158,151,158,134,150,159,222,168,159},P={},U={{1,2}},nParams=1},{K={},C={169,181,157,-1,135,159,138,158,164,159,168,159},P={{K={1,0},C={174,158,159,138,159,151,158,138,156,151,158,145,138,157,133,157,151,159,131,188,128,133,159,133,156,171,188,222,183,187,133,159,133,156,180,188,222,147,154,133,159,138,154,174,158,133,154,173,133,158,177,159,159,138,158,133,159,133,157,222,138,159,183,144,133,158,168,159},P={},U={{1,0}},nParams=1}},U=nil,nParams=0},{K={{161,119,39,236,182,112}},C={169,138,156,176,158,133,158,177,159,157,138,155,138,154,138,157,223,157,154,155,147,152,147,153,133,157,133,154,133,155,177,156,156,138,153,138,152,133,152,138,155,133,152,143,172,188,160,133,156,133,152,133,159,133,153,133,152,150,156,136,183,138,133,156,168,159},P={},U=nil,nParams=2},{K={0,1,{185,108,36,226,165,113},{232}},C={151,158,138,158,151,159,138,159,181,176,156,151,157,157,-1,148,159,138,156,151,159,138,157,133,157,151,158,131,188,185,133,159,133,156,171,188,213,183,176,133,159,133,156,180,188,213,147,154,133,159,138,154,133,158,181,176,156,133,154,157,-1,148,159,222,138,158,133,159,133,157,222,138,159,183,137,133,158,168,159},P={},U=nil,nParams=0},{K={1},C={133,158,151,158,222,168,159},P={},U=nil,nParams=1},{K={2},C={133,158,151,158,142,168,159},P={},U=nil,nParams=1},{K={},C={133,158,133,159,142,168,159},P={},U=nil,nParams=2},{K={},C={164,159,138,159,133,159,168,159},P={{K={},C={164,159,138,159,133,159,168,159},P={{K={100,10},C={174,158,151,158,142,174,159,151,159,142,222,133,158,222,168,159},P={},U={{0,0},{1,0}},nParams=1}},U={{1,0}},nParams=1}},U=nil,nParams=1}}
return ___l100(_I1_23,_1O024,__01I1,___O25)