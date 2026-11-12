--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
(function(...) local nToMJhcidNSu,amlYvSjELkxY,cXCAIeCyAquE
nToMJhcidNSu=math.floor;amlYvSjELkxY=string.char;cXCAIeCyAquE=table.concat;
local FYtJIeYu = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function NzteKqkRAPw(text)
  local ZxdMMfaQSJ, eJGJNYYuQ, dCTXLZowtL = {}, 0, 0
  for i = 1, #text do
    local esahvaGEdsW = text:sub(i, i)
    local RJhQJexzoEs = FYtJIeYu:find(esahvaGEdsW, 1, true)
    if RJhQJexzoEs then
      eJGJNYYuQ = eJGJNYYuQ * 64 + (RJhQJexzoEs - 1)
      dCTXLZowtL = dCTXLZowtL + 6
      if dCTXLZowtL >= 8 then
        dCTXLZowtL = dCTXLZowtL - 8
        local RMhhZOJR = 2 ^ dCTXLZowtL
        ZxdMMfaQSJ[#ZxdMMfaQSJ + 1] = string.char(math.floor(eJGJNYYuQ / RMhhZOJR))
        eJGJNYYuQ = eJGJNYYuQ % RMhhZOJR
      end
    end
  end
  return table.concat(ZxdMMfaQSJ)
end
local kGVDzihq = (loadstring or load)(NzteKqkRAPw("LS0gczAxOiBhcml0aG1ldGljIGFuZCBzdHJpbmcgdXRpbGl0aWVzLiBVc2VkIGZvciBtaW5pZmljYXRpb24gLyBmb3JtYXR0aW5nIHRlc3RzLgpsb2NhbCBmdW5jdGlvbiBjbGFtcCh2YWx1ZSwgbG93LCBoaWdoKQogIGlmIHZhbHVlIDwgbG93IHRoZW4KICAgIHJldHVybiBsb3cKICBlbHNlaWYgdmFsdWUgPiBoaWdoIHRoZW4KICAgIHJldHVybiBoaWdoCiAgZW5kCiAgcmV0dXJuIHZhbHVlCmVuZAoKbG9jYWwgZnVuY3Rpb24gZ2NkKGEsIGIpCiAgd2hpbGUgYiB+PSAwIGRvCiAgICBhLCBiID0gYiwgYSAlIGIKICBlbmQKICByZXR1cm4gYQplbmQKCmxvY2FsIGZ1bmN0aW9uIGlzUHJpbWUobikKICBpZiBuIDwgMiB0aGVuCiAgICByZXR1cm4gZmFsc2UKICBlbmQKICBmb3IgaSA9IDIsIG1hdGguZmxvb3IobWF0aC5zcXJ0KG4pKSBkbwogICAgaWYgbiAlIGkgPT0gMCB0aGVuCiAgICAgIHJldHVybiBmYWxzZQogICAgZW5kCiAgZW5kCiAgcmV0dXJuIHRydWUKZW5kCgpsb2NhbCBmdW5jdGlvbiBqb2luKGxpc3QsIHNlcGFyYXRvcikKICBsb2NhbCBwYXJ0cyA9IHt9CiAgZm9yIGluZGV4ID0gMSwgI2xpc3QgZG8KICAgIHBhcnRzWyNwYXJ0cyArIDFdID0gdG9zdHJpbmcobGlzdFtpbmRleF0pCiAgZW5kCiAgcmV0dXJuIHRhYmxlLmNvbmNhdChwYXJ0cywgc2VwYXJhdG9yKQplbmQKCmxvY2FsIHByaW1lcyA9IHt9CmZvciBjYW5kaWRhdGUgPSAxLCA1MCBkbwogIGlmIGlzUHJpbWUoY2FuZGlkYXRlKSB0aGVuCiAgICBwcmltZXNbI3ByaW1lcyArIDFdID0gY2FuZGlkYXRlCiAgZW5kCmVuZAoKcHJpbnQoInByaW1lczogIiAuLiBqb2luKHByaW1lcywgIiwiKSkKcHJpbnQoImdjZCg4NCwgMzYpID0gIiAuLiBnY2QoODQsIDM2KSkKcHJpbnQoImNsYW1wOiAiIC4uIGNsYW1wKDE1LCAwLCAxMCkgLi4gIiAiIC4uIGNsYW1wKC0zLCAwLCAxMCkgLi4gIiAiIC4uIGNsYW1wKDcsIDAsIDEwKSkKcHJpbnQoc3RyaW5nLmZvcm1hdCgiJTUuMmZ8JS02c3wlMDNkIiwgMy4xNDE1OSwgImFiIiwgNykpCg=="))
kGVDzihq()
 end)()