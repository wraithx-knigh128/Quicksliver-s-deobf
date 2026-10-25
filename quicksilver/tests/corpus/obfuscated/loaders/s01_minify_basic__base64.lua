local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function decode(text)
  local out, acc, bits = {}, 0, 0
  for i = 1, #text do
    local ch = text:sub(i, i)
    local v = alphabet:find(ch, 1, true)
    if v then
      acc = acc * 64 + (v - 1)
      bits = bits + 6
      if bits >= 8 then
        bits = bits - 8
        local div = 2 ^ bits
        out[#out + 1] = string.char(math.floor(acc / div))
        acc = acc % div
      end
    end
  end
  return table.concat(out)
end
local run = (loadstring or load)(decode("LS0gczAxOiBhcml0aG1ldGljIGFuZCBzdHJpbmcgdXRpbGl0aWVzLiBVc2VkIGZvciBtaW5pZmljYXRpb24gLyBmb3JtYXR0aW5nIHRlc3RzLgpsb2NhbCBmdW5jdGlvbiBjbGFtcCh2YWx1ZSwgbG93LCBoaWdoKQogIGlmIHZhbHVlIDwgbG93IHRoZW4KICAgIHJldHVybiBsb3cKICBlbHNlaWYgdmFsdWUgPiBoaWdoIHRoZW4KICAgIHJldHVybiBoaWdoCiAgZW5kCiAgcmV0dXJuIHZhbHVlCmVuZAoKbG9jYWwgZnVuY3Rpb24gZ2NkKGEsIGIpCiAgd2hpbGUgYiB+PSAwIGRvCiAgICBhLCBiID0gYiwgYSAlIGIKICBlbmQKICByZXR1cm4gYQplbmQKCmxvY2FsIGZ1bmN0aW9uIGlzUHJpbWUobikKICBpZiBuIDwgMiB0aGVuCiAgICByZXR1cm4gZmFsc2UKICBlbmQKICBmb3IgaSA9IDIsIG1hdGguZmxvb3IobWF0aC5zcXJ0KG4pKSBkbwogICAgaWYgbiAlIGkgPT0gMCB0aGVuCiAgICAgIHJldHVybiBmYWxzZQogICAgZW5kCiAgZW5kCiAgcmV0dXJuIHRydWUKZW5kCgpsb2NhbCBmdW5jdGlvbiBqb2luKGxpc3QsIHNlcGFyYXRvcikKICBsb2NhbCBwYXJ0cyA9IHt9CiAgZm9yIGluZGV4ID0gMSwgI2xpc3QgZG8KICAgIHBhcnRzWyNwYXJ0cyArIDFdID0gdG9zdHJpbmcobGlzdFtpbmRleF0pCiAgZW5kCiAgcmV0dXJuIHRhYmxlLmNvbmNhdChwYXJ0cywgc2VwYXJhdG9yKQplbmQKCmxvY2FsIHByaW1lcyA9IHt9CmZvciBjYW5kaWRhdGUgPSAxLCA1MCBkbwogIGlmIGlzUHJpbWUoY2FuZGlkYXRlKSB0aGVuCiAgICBwcmltZXNbI3ByaW1lcyArIDFdID0gY2FuZGlkYXRlCiAgZW5kCmVuZAoKcHJpbnQoInByaW1lczogIiAuLiBqb2luKHByaW1lcywgIiwiKSkKcHJpbnQoImdjZCg4NCwgMzYpID0gIiAuLiBnY2QoODQsIDM2KSkKcHJpbnQoImNsYW1wOiAiIC4uIGNsYW1wKDE1LCAwLCAxMCkgLi4gIiAiIC4uIGNsYW1wKC0zLCAwLCAxMCkgLi4gIiAiIC4uIGNsYW1wKDcsIDAsIDEwKSkKcHJpbnQoc3RyaW5nLmZvcm1hdCgiJTUuMmZ8JS02c3wlMDNkIiwgMy4xNDE1OSwgImFiIiwgNykpCg=="))
run()
