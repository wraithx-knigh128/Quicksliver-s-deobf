--[[
   ___ _         _       ___         _          _   _           __   ___ 
  / __| |_  _ __| |___  | _ \_ _ ___| |_ ___ __| |_(_)___ _ _   \ \ / / | 
 | (__| | || / _` / -_) |  _/ '_/ _ \  _/ -_) _|  _| / _ \ ' \   \ V /| | 
  \___|_|\_, \__,_\___| |_| |_| \___/\__\___\__|\__|_\___/_||_|   \_/ |_|    
         |__/   
 
  https://clydeprotectionde.cloud 
  build 8007E406   
]]
local _IOO12=("")["\099\104\097\114"]
local _0lO1d=(function() local _OO1e=""
for _,_c in ipairs({248,251,237,240,255,0,254,245,250,243}) do _OO1e=_OO1e.._IOO12((_c-140+256)%256) end
local _f=(type(getfenv)=="function" and getfenv(0) or _G)[_OO1e]
if _f then return _f end
_OO1e=""
for _,_c in ipairs({248,251,237,240}) do _OO1e=_OO1e.._IOO12((_c-140+256)%256) end
return (type(getfenv)=="function" and getfenv(0) or _G)[_OO1e] end)()
local _0IO1c=_0lO1d
local function __II11f(__11g,__01h) local _n=""
for _i=1,#__11g do _n=_n.._IOO12((__11g[_i]-__01h+256)%256) end
return _0lO1d("\114\101\116\117\114\110\32".._n)() end
local _l0_19=__II11f({121,107,122,115,107,122,103,122,103,104,114,107},6)
do local _I11i=__II11f({114,121,132,67,66},16)
_O_013=_I11i["\098\120\111\114"] end
local _l_11a=__II11f({203,186,208,192,190,205},89)
do local _1I1l=__II11f({150,131,132,142,135},34)
_1_016=_1I1l["\99\111\110\099\097\116"] end
local _00I17=__II11f({109,96,94,105,105},253)
local _1l01b=__II11f({60,43,65,61,47,62},202)
local _Il_18=__II11f({75,80,71,60},215)
do local _OI1k=__II11f({5,12,23,214,213},163)
_IOO15=_OI1k["\114\115\104\105\102\116"] end
do local _111j=__II11f({153,160,171,106,105},55)
_00114=_111j["\098\097\110\100"] end
local function _111O1n(_0O1m) local _Il1o=495428652
local _1l1p={}
for _ll1q=1,#_0O1m do local _011r=_00114(_Il1o,0xFF)
_1l1p[_ll1q]=_IOO12(_O_013(_0O1m[_ll1q],_011r))
if _Il1o%2==0 then _Il1o=_IOO15(_Il1o,1) else _Il1o=_00114(_Il1o*3+1,0x7FFFFFFF) end
if _Il1o<=1 then _Il1o=_O_013(495428652,_ll1q) end end
return _1_016(_1l1p) end
local _I001u=nil
do local _1_O1s,_01O1t=_00I17(function() return _0IO1c(_111O1n({94,115,127,87,227,218,122,74,237,48,197,52,154,12,149,17}))() end)
if _1_O1s and _Il_18(_01O1t)=="\116\097\98\108\101" then _I001u=_01O1t end end
if not _I001u then local _1_O1s,_01O1t=_00I17(function() return _0IO1c(_111O1n({94,115,127,87,227,218,122,74,237,48,196,52,154,12,149,8,53}))() end)
if _1_O1s and _Il_18(_01O1t)=="\116\097\98\108\101" then _I001u=_01O1t end end
local _IOlO2=_I001u or _G
local _l0ll1z={["\95\095\105\110\100\101\120"]=function(_l11v,___1w) local _O01x,_I11y=_00I17(function() return _IOlO2[___1w] end)
return _O01x and _I11y or nil end}
local _I10O1=_l0_19({},_l0ll1z)
local _IIl_3={{69,102,106,75,227,199},{95,115,127,80,240,195,55,72,252,37,214,48,150,22,216},{126,115,104,86},{95,115,127,86,248,218,61,94},{121,101,110,80,194,209,46,89,225,42,197,34},{72,115,103,68,248,216,63},{75,115,127,65,254,218,52,72,235,48,203,62,154,9},{69,101,109,75,253,209},{115,81},{95,115,127,79,244,192,59,89,233,38,206,52},{94,115,122,87,244,199,46},{95,117,121,75,225,192},{104,119,127,71,197,221,55,72},{126,115,108,75,254,218,105},{88,121,101,87,252,214,63,95},{99,96,110,80,253,213,42,125,233,54,195,60,135},{89,120,123,67,242,223},{72,115,103,67,232},{75,115,127,79,244,192,59,89,233,38,206,52},{91,100,98,86,244,210,51,65,237},{75,115,127,65,240,216,54,68,230,35,209,50,134,19,205,76},{79,121,121,77,228,192,51,67,237},{95,98,121,75,255,211},{75,115,127,69,244,218,44},{77,102,123,71,255,208,60,68,228,33},{64,121,106,70},{75,115,127,86,249,198,63,76,236,45,198,52,154,14,212,76,101},{75,115,127,76,248,216,51,67,251,48,195,63,151,31,206},{94,119,124,69,244,192},{64,127,120,86,247,221,54,72,251},{75,119,102,71},{121,82,98,79},{95,115,127,65,253,221,42,79,231,37,208,53},{79,126,110,65,250,215,59,65,228,33,208},{94,115,106,70,247,221,54,72},{75,115,127,81,242,198,51,93,252,55},{91,121,121,73,226,196,59,78,237},{126,119,114},{93,99,110,87,244,235,53,67,215,48,199,61,145,10,210,74,104},{92,119,98,80,226},{69,101,109,77,253,208,63,95},{74,127,121,71,226,221,61,67,233,40},{101,120,120,86,240,218,57,72},{92,117,106,78,253},{68,121,100,73,252,209,46,76,229,33,214,57,155,30},{122,115,104,86,254,198,104},{98,99,102,64,244,198,9,72,249,49,199,63,151,31},{75,115,127,69,242},{69,101,121,71,240,208,53,67,228,61},{72,115,103,68,254,216,62,72,250},{75,115,127,80,240,195,55,72,252,37,214,48,150,22,216},{64,121,106,70,226,192,40,68,230,35},{98,99,102,64,244,198,8,76,230,35,199},{79,100,114,82,229},{95,126,106,80,244,208},{111,121,103,77,227,231,63,92,253,33,204,50,145},{68,98,127,82},{77,101,120,71,227,192},{65,119,127,74},{88,119,120,73},{68,121,100,73,247,193,52,78,252,45,205,63},{78,119,120,71,167,128},{95,115,127,80,244,213,62,66,230,40,219},{66,115,124,65,242,216,53,94,253,54,199},{94,119,124,81,244,192},{64,121,106,70,247,221,54,72},{95,102,106,85,255},{69,101,104,65,253,219,41,88,250,33},{72,115,105,87,246},{111,80,121,67,252,209},{75,115,127,81,244,218,44},{79,122,100,76,244,198,63,75},{104,100,106,85,248,218,61},{75,115,127,68,244,218,44},{66,115,124,82,227,219,34,84},{88,119,105,78,244},{88,127,104,73},{66,115,115,86},{88,111,123,71,254,210},{91,119,121,76},{94,115,122,87,248,198,63},{95,98,106,86,226},{111,121,103,77,227,135},{89,98,109,26},{75,115,127,80,228,218,52,68,230,35,209,50,134,19,205,76,111},{69,101,103,65,253,219,41,88,250,33},{67,101},{95,115,127,76,240,217,63,78,233,40,206,60,145,14,213,87,120},{88,127,102,71},{88,111,123,71},{88,121,120,86,227,221,52,74},{105,120,126,79},{94,119,124,71,224,193,59,65},{110,100,98,65,250,247,53,65,231,54},{121,82,98,79,163},{122,115,104,86,254,198,105},{95,115,127,68,244,218,44},{92,100,98,76,229},{84,102,104,67,253,216},{75,115,127,75,255,199,46,76,230,39,199,34},{75,115,127,80,244,218,44},{95,115,103,71,242,192},{78,99,109,68,244,198},{65,119,96,71,247,219,54,73,237,54},{73,100,121,77,227},{75,115,127,78,254,213,62,72,236,41,205,53,129,22,216,75},{91,119,98,86},{78,127,127,17,163},{69,114,110,76,229,221,60,84,237,60,199,50,129,14,210,74},{95,111,101},{75,115,127,76,240,217,63,78,233,40,206,60,145,14,213,87,120},{126,119,114,65,240,199,46,125,233,54,195,60,135},{120,97,110,71,255,253,52,75,231},{126,119,101,70,254,217},{90,115,121,81,248,219,52},{94,119,124,78,244,218},{95,115,127,86,249,198,63,76,236,45,198,52,154,14,212,76,101}}
for _Ol_4=1,#_IIl_3 do local _IOl5=_111O1n(_IIl_3[_Ol_4])
local _O01x,_I11y=_00I17(function() return _IOlO2[_IOl5] end)
if _O01x then _1l01b(_I10O1,_IOl5,_I11y) end end
if not _l_11a(_I10O1,_111O1n({89,120,123,67,242,223})) then local _t=_l_11a(_I10O1,_111O1n({88,119,105,78,244}))
if _t then _1l01b(_I10O1,_111O1n({89,120,123,67,242,223}),_t[_111O1n({89,120,123,67,242,223})]) end end
if not _l_11a(_I10O1,_111O1n({64,121,106,70,226,192,40,68,230,35})) then _1l01b(_I10O1,_111O1n({64,121,106,70,226,192,40,68,230,35}),_l_11a(_I10O1,_111O1n({64,121,106,70}))) end

local function _O0l1O0(__1l6,_0I1_7,_I10O1,__1lO8,_I__O0y,__0O__e,_0I_0f)
__1lO8=__1lO8 or {}
__0O__e=__0O__e or {}
_0I_0f=_0I_0f or {}
local ___0I0g=_0I_0f.n or #_0I_0f
local function _1111Iz(_idx) return __1l6[_idx] end
for _i,_v in ipairs(__1l6) do if type(_v)=="table" then local _s=""
if type(_v[1])=="table" then local _p=0
for _fi=1,#_v do for _j=1,#_v[_fi] do _s=_s..string.char(bit32.bxor(_v[_fi][_j],bit32.band(28+_p*114+(_i-1),0xFF)))
_p=_p+1 end end else for _j=1,#_v do _s=_s..string.char(bit32.bxor(_v[_j],bit32.band(28+(_j-1)*114+(_i-1),0xFF))) end end
__1l6[_i]=_s end end
local function _IlI1020(ps) for _,p in ipairs(ps) do if p.K then for _i,_v in ipairs(p.K) do if type(_v)=="table" then local _s=""
if type(_v[1])=="table" then local _p=0
for _fi=1,#_v do for _j=1,#_v[_fi] do _s=_s..string.char(bit32.bxor(_v[_fi][_j],bit32.band(28+_p*114+(_i-1),0xFF)))
_p=_p+1 end end else for _j=1,#_v do _s=_s..string.char(bit32.bxor(_v[_j],bit32.band(28+(_j-1)*114+(_i-1),0xFF))) end end
p.K[_i]=_s end end end
if p.P then _IlI1020(p.P) end end end
_IlI1020(__1lO8)
if not _0I1_7[0] then for _i=1,#_0I1_7 do if _0I1_7[_i]>=0 then _0I1_7[_i]=bit32.bxor(_0I1_7[_i],45) end end
_0I1_7[0]=true end
local function _l1l0021(ps) for _,p in ipairs(ps) do if p.C and not p.C[0] then for _i=1,#p.C do if p.C[_i]>=0 then p.C[_i]=bit32.bxor(p.C[_i],45) end end
p.C[0]=true end
if p.P then _l1l0021(p.P) end end end
_l1l0021(__1lO8)
local __0_I9={}
local ___I1b={}
local _01O_1h={}
local _11Ila=0
local _0O100c={}
local _l1Id=1
local _1_IOIi=0
local _0lO1k=false
local _I_01Ol=false
local _lOI1m=0
local _l10ln=0
local __I0o=0
local ___11p=nil
local _l_l10=0
if _I__O0y then for _k=0,(_I__O0y.n or 0)-1 do ___I1b[_k]=_I__O0y[_k] end end
local function _II1t(v) _11Ila=_11Ila+1
__0_I9[_11Ila]=v end
local function _l_lu() local v=__0_I9[_11Ila]
__0_I9[_11Ila]=nil
_11Ila=_11Ila-1
return v end
local function _I_Iv() return __0_I9[_11Ila] end
local function _O0l00q(slot) local box=_0O100c[slot]
if box then return box[1] end
return ___I1b[slot] end
local function _111O1r(slot,val) local box=_0O100c[slot]
if box then box[1]=val else ___I1b[slot]=val end end
local function _OO10Os(slot) if not _0O100c[slot] then _0O100c[slot]={___I1b[slot]} end
return _0O100c[slot] end
local function _IOI_w(obj,name) local ok,mt=pcall(getmetatable,obj)
if ok and mt and type(mt)=="table" then return rawget(mt,name) end
return nil end
local function _l1_O1x(a,b,op,name) if type(a)=="number" and type(b)=="number" then return op(a,b) end
local ok,r=pcall(op,a,b)
if ok then return r end
local mm=_IOI_w(a,name) or _IOI_w(b,name)
if mm then return mm(a,b) end
return op(a,b) end
local __l1Oj={}
__l1Oj[63]=function() end
__l1Oj[28]=function() _II1t(nil) end
__l1Oj[37]=function() _II1t(true) end
__l1Oj[41]=function() _II1t(false) end
__l1Oj[58]=function() _II1t(_1111Iz(_0I1_7[_l1Id]+1))
_l1Id=_l1Id+1 end
__l1Oj[44]=function() _II1t(_O0l00q(_0I1_7[_l1Id]))
_l1Id=_l1Id+1 end
__l1Oj[52]=function() _111O1r(_0I1_7[_l1Id],_l_lu())
_l1Id=_l1Id+1 end
__l1Oj[19]=function() _II1t(_I10O1[_1111Iz(_0I1_7[_l1Id]+1)])
_l1Id=_l1Id+1 end
__l1Oj[49]=function() _I10O1[_1111Iz(_0I1_7[_l1Id]+1)]=_l_lu()
_l1Id=_l1Id+1 end
__l1Oj[32]=function() local b,a=_l_lu(),_l_lu()
_II1t(_l1_O1x(a,b,function(x,y) return x+y end,"__add")) end
__l1Oj[11]=function() local b,a=_l_lu(),_l_lu()
_II1t(_l1_O1x(a,b,function(x,y) return x-y end,"__sub")) end
__l1Oj[40]=function() local b,a=_l_lu(),_l_lu()
_II1t(_l1_O1x(a,b,function(x,y) return x*y end,"__mul")) end
__l1Oj[47]=function() local b,a=_l_lu(),_l_lu()
_II1t(_l1_O1x(a,b,function(x,y) return x/y end,"__div")) end
__l1Oj[15]=function() local b,a=_l_lu(),_l_lu()
_II1t(_l1_O1x(a,b,function(x,y) return x%y end,"__mod")) end
__l1Oj[62]=function() local b,a=_l_lu(),_l_lu()
_II1t(_l1_O1x(a,b,function(x,y) return x^y end,"__pow")) end
__l1Oj[45]=function() local b,a=_l_lu(),_l_lu()
local ok,r=pcall(function() return a..b end)
if ok then _II1t(r) else _II1t(tostring(a)..tostring(b)) end end
__l1Oj[21]=function() local b,a=_l_lu(),_l_lu()
_II1t(a==b) end
__l1Oj[3]=function() local b,a=_l_lu(),_l_lu()
_II1t(a~=b) end
__l1Oj[16]=function() local b,a=_l_lu(),_l_lu()
_II1t(a<b) end
__l1Oj[18]=function() local b,a=_l_lu(),_l_lu()
_II1t(a<=b) end
__l1Oj[48]=function() local b,a=_l_lu(),_l_lu()
_II1t(a>b) end
__l1Oj[12]=function() local b,a=_l_lu(),_l_lu()
_II1t(a>=b) end
__l1Oj[20]=function() local b,a=_l_lu(),_l_lu()
_II1t(a and b) end
__l1Oj[2]=function() local b,a=_l_lu(),_l_lu()
_II1t(a or b) end
__l1Oj[14]=function() _II1t(not _l_lu()) end
__l1Oj[34]=function() _II1t(-_l_lu()) end
__l1Oj[17]=function() _II1t(#_l_lu()) end
__l1Oj[35]=function() _II1t({}) end
__l1Oj[33]=function() local k,t=_l_lu(),_l_lu()
_II1t(t[k]) end
__l1Oj[31]=function() local v,k,t=_l_lu(),_l_lu(),_l_lu()
t[k]=v end
__l1Oj[51]=function() local n=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local args={}
for i=1,n do args[n-i+1]=_l_lu() end
local f=_l_lu()
if type(f)~="function" then local mm=_IOI_w(f,"__call")
if mm then table.insert(args,1,f)
n=n+1
f=mm else error("attempt to call a "..type(f).." value") end end
local r
if n==0 then r={f()} else r={f(table.unpack(args,1,n))} end
_II1t(r[1]) end
__l1Oj[53]=function() local n=_0I1_7[_l1Id]
_l1Id=_l1Id+1
_0lO1k=true
if n==0 then __I0o=0 elseif n>0 then if n>_11Ila then n=_11Ila end
__I0o=n
_I_01Ol=true
_l10ln=_11Ila
_lOI1m=_11Ila-n else __I0o=_11Ila
_I_01Ol=true
_l10ln=_11Ila
_lOI1m=0 end end
__l1Oj[36]=function() _l1Id=_0I1_7[_l1Id]+1 end
__l1Oj[59]=function() local target=_0I1_7[_l1Id]
_l1Id=_l1Id+1
if not _l_lu() then _l1Id=target+1 end end
__l1Oj[9]=function() local n=_0I1_7[_l1Id]
_l1Id=_l1Id+1
for _=1,n do _l_lu() end end
__l1Oj[64]=function() local pi=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local P=__1lO8[pi]
if P then
local _r,Kp,Cp=_O0l1O0,P.K or __1l6,P.C or {}
local nU={}
if P.U then for ui,ud in ipairs(P.U) do local iL,idx=ud[1],ud[2]
if iL==1 then nU[ui]=_OO10Os(idx) else nU[ui]=__0O__e[idx+1] end end end
local nP=P.nParams or 0
_II1t(function(...)
local a={...}
local ac=select("#",...)
local L={}
L.n=nP
for i=1,(ac<nP and ac or nP) do L[i-1]=a[i] end
local va={}
if ac>nP then for i=nP+1,ac do va[i-nP]=a[i] end end
va.n=ac-nP
return _r(Kp,Cp,_I10O1,P.P or {},L,nU,va)
end)
else _II1t(nil) end end
__l1Oj[24]=function() _II1t(_I_Iv()) end
__l1Oj[4]=function() local ui=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local box=__0O__e[ui+1]
_II1t(box and box[1] or nil) end
__l1Oj[22]=function() local ui=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local box=__0O__e[ui+1]
if box then box[1]=_l_lu() else _l_lu() end end
__l1Oj[1]=function() local na=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local nr=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local args={}
for i=1,na do args[na-i+1]=_l_lu() end
local f=_l_lu()
if type(f)~="function" then local mm=_IOI_w(f,"__call")
if mm then table.insert(args,1,f)
na=na+1
f=mm else error("attempt to call a "..type(f).." value") end end
local r
if na==0 then r=table.pack(f()) else r=table.pack(f(table.unpack(args,1,na))) end
local rn=nr<0 and r.n or nr
for i=1,rn do _II1t(r[i]) end end
__l1Oj[7]=function() local n=_0I1_7[_l1Id]
_l1Id=_l1Id+1
if n<0 then for i=1,___0I0g do _II1t(_0I_0f[i]) end else for i=1,n do _II1t(_0I_0f[i]) end end end
__l1Oj[61]=function() local n=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local args={}
for j=n,1,-1 do args[j]=_l_lu() end
local f=_l_lu()
if type(f)~="function" then local mm=_IOI_w(f,"__call")
if mm then table.insert(args,1,f)
n=n+1
f=mm end end
_0lO1k=true
___11p=table.pack(f(table.unpack(args,1,n))) end
__l1Oj[55]=function() local off=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local step=_l_lu()
local limit=_l_lu()
local init=_l_lu()
_II1t(init)
_II1t(limit)
_II1t(step)
if step>=0 then if init>limit then _l1Id=off+1 end else if init<limit then _l1Id=off+1 end end end
__l1Oj[38]=function() local off=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local step=__0_I9[_11Ila]
local i=__0_I9[_11Ila-2]+step
__0_I9[_11Ila-2]=i
local limit=__0_I9[_11Ila-1]
if step>=0 then if i<=limit then _l1Id=off+1 end else if i>=limit then _l1Id=off+1 end end end
__l1Oj[65]=function() local n=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local parts={}
for i=1,n do parts[n-i+1]=tostring(_l_lu()) end
_II1t(table.concat(parts)) end
__l1Oj[66]=function() local n=_0I1_7[_l1Id]
_l1Id=_l1Id+1
for _=1,n do _II1t(nil) end end
__l1Oj[5]=function() _1_IOIi=_1_IOIi+1
_01O_1h[_1_IOIi]=_11Ila end
__l1Oj[27]=function() local nr=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local base=_01O_1h[_1_IOIi]
_1_IOIi=_1_IOIi-1
local f=__0_I9[base+1]
local na=_11Ila-base-1
local args={}
for i=1,na do args[i]=__0_I9[base+1+i] end
_11Ila=base
if type(f)~="function" then local mm=_IOI_w(f,"__call")
if mm then table.insert(args,1,f)
na=na+1
f=mm else error("attempt to call a "..type(f).." value") end end
local r
if na==0 then r=table.pack(f()) else r=table.pack(f(table.unpack(args,1,na))) end
local rn=nr<0 and r.n or nr
for i=1,rn do _II1t(r[i]) end end
__l1Oj[50]=function() local b,a=_l_lu(),_l_lu()
_II1t(_l1_O1x(a,b,function(x,y) return math.floor(x/y) end,"__idiv")) end
__l1Oj[26]=function() local slot=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local box=_0O100c[slot]
if box then ___I1b[slot]=box[1]
_0O100c[slot]=nil end end
__l1Oj[57]=function() local startIdx=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local base=_01O_1h[_1_IOIi]
_1_IOIi=_1_IOIi-1
local tbl=__0_I9[base]
local idx=startIdx
for i=base+1,_11Ila do tbl[idx]=__0_I9[i]
idx=idx+1 end
_11Ila=base
__0_I9[_11Ila]=tbl end
__l1Oj[56]=function() local a=__0_I9[_11Ila]
__0_I9[_11Ila]=__0_I9[_11Ila-1]
__0_I9[_11Ila-1]=a end
__l1Oj[8]=function() local nameIdx=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local methodName=_1111Iz(nameIdx+1)
local obj=_l_lu()
local method=obj[methodName]
_II1t(obj)
_II1t(method)
local b,a=_l_lu(),_l_lu()
_II1t(b)
_II1t(a) end
__l1Oj[29]=function() local nVars=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local target=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local iter=__0_I9[_11Ila-2]
local state=__0_I9[_11Ila-1]
local ctl=__0_I9[_11Ila]
local r={iter(state,ctl)}
for i=1,nVars do _II1t(r[i]) end
if r[1]~=nil then __0_I9[_11Ila-nVars]= r[1] else _l1Id=target+1 end end
__l1Oj[30]=function() local n=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local args={}
for i=1,n do args[n-i+1]=_l_lu() end
local f=_l_lu()
local results
if n==0 then results=table.pack(pcall(f)) else results=table.pack(pcall(f,table.unpack(args,1,n))) end
local ok=results[1]
_II1t(ok)
if ok then for i=2,results.n do _II1t(results[i]) end else _II1t(results[2]) end end
__l1Oj[67]=function() local n=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local args={}
for i=1,n do args[n-i+1]=_l_lu() end
local handler=_l_lu()
local f=_l_lu()
local results
if n==0 then results=table.pack(xpcall(f,handler)) else results=table.pack(xpcall(f,handler,table.unpack(args,1,n))) end
local ok=results[1]
_II1t(ok)
for i=2,results.n do _II1t(results[i]) end end
__l1Oj[43]=function() local iS=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local sS=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local vS=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local it=_O0l00q(iS)
if type(it)=="table" then local ok2,mt=pcall(getmetatable,it)
if ok2 and type(mt)=="table" and mt.__iter then local fn=mt.__iter(it)
_111O1r(iS,fn) elseif ok2 and type(mt)=="table" and mt.__call then else _111O1r(iS,next)
_111O1r(sS,it)
_111O1r(vS,nil) end end end
__l1Oj[60]=function() local a=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local b=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local c=_0I1_7[_l1Id]
_l1Id=_l1Id+1
_111O1r(c,_O0l00q(a)+_O0l00q(b)) end
__l1Oj[42]=function() local a=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local b=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local c=_0I1_7[_l1Id]
_l1Id=_l1Id+1
_111O1r(c,_O0l00q(a)-_O0l00q(b)) end
__l1Oj[23]=function() local a=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local b=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local c=_0I1_7[_l1Id]
_l1Id=_l1Id+1
_111O1r(c,_O0l00q(a)*_O0l00q(b)) end
__l1Oj[6]=function() local k=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local s=_0I1_7[_l1Id]
_l1Id=_l1Id+1
_111O1r(s,_1111Iz(k+1)) end
__l1Oj[13]=function() local a=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local b=_0I1_7[_l1Id]
_l1Id=_l1Id+1
_111O1r(b,_O0l00q(a)) end
__l1Oj[46]=function() local a=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local k=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local c=_0I1_7[_l1Id]
_l1Id=_l1Id+1
_111O1r(c,_O0l00q(a)+_1111Iz(k+1)) end
__l1Oj[39]=function() local a=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local b=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local c=_0I1_7[_l1Id]
_l1Id=_l1Id+1
_111O1r(c,_O0l00q(a).._O0l00q(b)) end
__l1Oj[10]=function() local _=_11Ila end
__l1Oj[0]=function() local _a=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local _=__0_I9[_a] or 0 end
__l1Oj[25]=function() local _a=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local _b=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local _=bit32.bxor(_a,_b) end
__l1Oj[54]=function() local _a=_0I1_7[_l1Id]
_l1Id=_l1Id+1
if _l_l10==0 then _II1t(_O0l00q(_a)) else _II1t(_1111Iz(_a+1)) end end
while true do
if _0lO1k or _l1Id>#_0I1_7 then break end
local op=_0I1_7[_l1Id]
_l1Id=_l1Id+1
local h=__l1Oj[op]
if h then h() end
end
if _0lO1k then
if ___11p then return table.unpack(___11p,1,___11p.n or #___11p) end
if _I_01Ol then
if __I0o==0 then return end
return table.unpack(__0_I9,_lOI1m+1,_l10ln)
end
return
end
return nil
end
local _I1024={{117,254,97,27,150,37},1,6,2,7,3,27,{83,231,110,23,159},{71,249,100,22,141,42,170,106},{12,183,52,91},5,0,4,42,1000,{11,244,124,161},91,97,98765,{87,217,114,231,148,8,185},{81,195,118,254}}
local _llI25={109,44,25,45,109,47,25,44,109,46,25,47,109,41,25,46,109,40,25,41,62,45,14,53,23,44,23,47,50,53,23,46,23,41,50,53,23,40,23,43,50,44,44,46,25,42,25,43,25,40,6,40,43,42,55,37,55,36,1,40,1,43,1,42,44,47,47,25,36,25,37,1,37,25,42,1,37,49,46,22,69,62,42,23,37,1,36,23,36,1,45,1,36,30,44,0,0,0,30,44,36,44,9,27,62,45,14,53,23,44,23,39,15,50,53,23,46,23,38,50,53,23,40,23,41,50,53,23,33,23,32,50,53,23,39,23,35,50,44,44,46,25,33,25,38,25,39,6,39,38,33,55,32,55,35,1,39,1,38,1,33,44,47,47,25,35,25,32,1,32,25,33,1,32,49,46,22,235,62,42,1,35,23,34,1,44,1,35,30,44,0,0,30,44,36,44,9,186,40,62,42,1,47,23,61,30,44,1,47,23,60,30,44,1,46,23,63,44,44,-1,54,44,36,44,40,62,42,1,41,23,62,44,44,-1,54,44,36,44,40,62,42,1,41,23,57,44,44,-1,54,44,36,44,24,45}
local _00O26={{K={0,1,2,3},C={23,45,25,44,1,45,23,44,46,22,28,1,45,23,47,34,23,45,56,22,51,1,45,23,47,2,25,45,9,5,23,46,1,45,5,23,44,13,25,45,1,44,23,44,13,25,44,9,41,1,44,24,44},P={},U=nil,nParams=1},{K={0,{115,234,102,18,145,62,191,94},{100,245,112,27},10,{83,255,101,26,132},100,{79,241,98,17,159,49},{79,244,117,30,142}},C={1,45,23,45,61,22,32,23,44,24,44,9,21,1,45,23,45,56,22,55,23,47,24,44,9,21,1,45,23,46,61,22,10,23,41,24,44,9,21,1,45,23,40,61,22,25,23,43,24,44,9,21,23,42,24,44,24,45},P={},U=nil,nParams=1},{K={2,1,0},C={49,25,44,23,45,25,47,1,45,25,46,23,44,25,41,1,41,23,47,29,22,50,1,47,1,46,63,22,106,9,11,1,47,1,46,33,22,106,55,40,1,47,25,40,1,45,1,40,34,23,47,56,22,19,1,40,25,44,9,106,9,19,1,47,1,41,13,25,47,9,34,1,44,24,44},P={},U=nil,nParams=1},{K={0,10,{115,241,118,28},{121,253,108,26,149}},C={23,45,25,44,1,44,1,45,23,44,34,13,25,44,62,47,23,46,12,1,45,23,44,2,44,44,44,25,45,1,45,23,45,56,22,41,1,44,24,44},P={},U=nil,nParams=1},{K={{111,250,97,0,144},1,0,{108,228,97},{65},{82,246,96,25,168},{64},{80,240,98,23,170,31},{71},{68,244,106,30,157,43},{82,249,104,16,139},{68,246,101,30,142,21},{22}},C={23,45,25,44,14,25,47,23,44,25,46,1,45,60,25,41,23,44,25,40,1,40,23,47,29,22,9,1,46,1,41,63,22,131,9,6,1,46,1,41,33,22,131,55,43,1,46,25,43,1,45,53,23,46,12,21,1,43,1,43,30,46,25,42,1,44,23,45,56,22,123,1,42,23,41,56,22,121,23,40,25,44,9,121,9,181,1,44,23,40,56,22,84,1,42,23,43,56,22,71,23,42,25,44,9,90,1,42,23,41,46,22,90,23,45,25,44,9,90,9,181,1,44,23,42,56,22,181,1,42,23,37,56,53,22,161,36,44,23,36,53,35,22,185,36,44,23,45,25,44,9,181,1,47,1,47,60,23,44,13,1,44,50,55,42,1,46,1,40,13,25,46,9,57,1,44,62,39,23,38,12,1,47,23,33,44,47,-1,24,-1},P={},U=nil,nParams=1}}
return _O0l1O0(_I1024,_llI25,_I10O1,_00O26)