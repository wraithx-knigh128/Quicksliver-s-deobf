--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
(function(...) local nToMJhcidNSu,amlYvSjELkxY,cXCAIeCyAquE
nToMJhcidNSu=math.floor;amlYvSjELkxY=string.char;cXCAIeCyAquE=table.concat;
local kGVDzihq = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function esahvaGEdsW(text)
  local RMhhZOJR, ZxdMMfaQSJ, dCTXLZowtL = {}, 0, 0
  for i = 1, #text do
    local NzteKqkRAPw = text:sub(i, i)
    local FYtJIeYu = kGVDzihq:find(NzteKqkRAPw, 1, true)
    if FYtJIeYu then
      ZxdMMfaQSJ = ZxdMMfaQSJ * 64 + (FYtJIeYu - 1)
      dCTXLZowtL = dCTXLZowtL + 6
      if dCTXLZowtL >= 8 then
        dCTXLZowtL = dCTXLZowtL - 8
        local eJGJNYYuQ = 2 ^ dCTXLZowtL
        RMhhZOJR[#RMhhZOJR + 1] = string.char(math.floor(ZxdMMfaQSJ / eJGJNYYuQ))
        ZxdMMfaQSJ = ZxdMMfaQSJ % eJGJNYYuQ
      end
    end
  end
  return table.concat(RMhhZOJR)
end
local RJhQJexzoEs = (loadstring or load)(esahvaGEdsW("LS0gczAzOiBzdHJpbmctaGVhdnkgcHJvZ3JhbS4gVXNlZCB0byB0ZXN0IHN0cmluZyBkZWNvZGluZyBhbmQgY29uc3RhbnQgZm9sZGluZy4KbG9jYWwgZ3JlZXRpbmcgPSAiSGVsbG8sIFF1aWNrU2lsdmVyISIKbG9jYWwgc2VwYXJhdG9yID0gIi0tLS0tLS0tLS0tLS0tLS0tLS0tIgpsb2NhbCB3b3JkcyA9IHsgImFscGhhIiwgImJyYXZvIiwgImNoYXJsaWUiLCAiZGVsdGEiLCAiZWNobyIsICJmb3h0cm90IiB9CmxvY2FsIHRlbXBsYXRlID0gIlslMDJkXSAlcyAoJWQgY2hhcnMpIgoKcHJpbnQoZ3JlZXRpbmcpCnByaW50KHNlcGFyYXRvcikKCmZvciBpbmRleCwgd29yZCBpbiBpcGFpcnMod29yZHMpIGRvCiAgcHJpbnQoc3RyaW5nLmZvcm1hdCh0ZW1wbGF0ZSwgaW5kZXgsIHdvcmQ6dXBwZXIoKSwgI3dvcmQpKQplbmQKCnByaW50KHNlcGFyYXRvcikKCmxvY2FsIHNlbnRlbmNlID0gInRoZSBxdWljayBicm93biBmb3gganVtcHMgb3ZlciB0aGUgbGF6eSBkb2ciCmxvY2FsIGNvdW50cyA9IHt9CmZvciBsZXR0ZXIgaW4gc2VudGVuY2U6Z21hdGNoKCIlYSIpIGRvCiAgY291bnRzW2xldHRlcl0gPSAoY291bnRzW2xldHRlcl0gb3IgMCkgKyAxCmVuZAoKbG9jYWwgbGV0dGVycyA9IHt9CmZvciBsZXR0ZXIgaW4gcGFpcnMoY291bnRzKSBkbwogIGxldHRlcnNbI2xldHRlcnMgKyAxXSA9IGxldHRlcgplbmQKdGFibGUuc29ydChsZXR0ZXJzKQoKbG9jYWwgc3VtbWFyeSA9IHt9CmZvciBfLCBsZXR0ZXIgaW4gaXBhaXJzKGxldHRlcnMpIGRvCiAgc3VtbWFyeVsjc3VtbWFyeSArIDFdID0gbGV0dGVyIC4uICI9IiAuLiBjb3VudHNbbGV0dGVyXQplbmQKcHJpbnQodGFibGUuY29uY2F0KHN1bW1hcnksICIgIikpCnByaW50KHNlbnRlbmNlOnJldmVyc2UoKSkKcHJpbnQoKHNlbnRlbmNlOmdzdWIoIm8iLCAiMCIpKSkKcHJpbnQoKCJhYiIpOnJlcCgzKSkKcHJpbnQoc2VudGVuY2U6c3ViKDUsIDkpIC4uICJ8IiAuLiBzZW50ZW5jZTpmaW5kKCJmb3giLCAxLCB0cnVlKSkK"))
RJhQJexzoEs()
 end)()