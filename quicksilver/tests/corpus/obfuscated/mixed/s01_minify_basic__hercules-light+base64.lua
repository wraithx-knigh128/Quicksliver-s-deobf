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
local run = (loadstring or load)(decode("LS1bT2JmdXNjYXRlZCBieSBIZXJjdWxlcyB2Mi4wLjAgfCBoZXJjdWxlcy1vYmZ1c2NhdG9yLnh5ei9kaXNjb3JkIHwgaGVyY3VsZXMtb2JmdXNjYXRvci54eXovc291cmNlXQpsb2NhbCBva2t2YkpEVHV4LGRCbXh6dEJlUVV3UCxNSlRVelpoSk4sQXF6dkZrcU5ZV0MsTWRSRXNuT01LLFlpdVBEUmtUS0Nzcztva2t2YkpEVHV4PXByaW50O2RCbXh6dEJlUVV3UD10b3N0cmluZztNSlRVelpoSk49bWF0aC5mbG9vcjtBcXp2RmtxTllXQz1tYXRoLnNxcnQ7TWRSRXNuT01LPXN0cmluZy5mb3JtYXQ7WWl1UERSa1RLQ3NzPXRhYmxlLmNvbmNhdDtsb2NhbCBmdW5jdGlvbiBrdWVkQkp2c2xqck4odmFsdWUsbG93LGhpZ2gpIGlmIHZhbHVlPGxvdyB0aGVuIHJldHVybiBsb3cgZWxzZWlmIHZhbHVlPmhpZ2ggdGhlbiByZXR1cm4gaGlnaCBlbmQgcmV0dXJuIHZhbHVlIGVuZCBsb2NhbCBmdW5jdGlvbiBseGRHZGFzZShhLGIpIHdoaWxlIGJ+PTAgZG8gYSxiPWIsYSViIGVuZCByZXR1cm4gYSBlbmQgbG9jYWwgZnVuY3Rpb24gSEJ6cU9teklrV2YobikgaWYgbjwyIHRoZW4gcmV0dXJuIGZhbHNlIGVuZCBmb3IgaT0yLG1hdGguZmxvb3IobWF0aC5zcXJ0KG4pKWRvIGlmIG4laT09MCB0aGVuIHJldHVybiBmYWxzZSBlbmQgZW5kIHJldHVybiB0cnVlIGVuZCBsb2NhbCBmdW5jdGlvbiBWa0VzQ3NRVChsaXN0LHNlcGFyYXRvcikgbG9jYWwgVVlETHJ5WHROa0F6PXt9O2ZvciBpbmRleD0xLCNsaXN0IGRvIFVZRExyeVh0TmtBelsjVVlETHJ5WHROa0F6KzFdPWRCbXh6dEJlUVV3UChsaXN0W2luZGV4XSkgZW5kIHJldHVybiB0YWJsZS5jb25jYXQoVVlETHJ5WHROa0F6LHNlcGFyYXRvcikgZW5kIGxvY2FsIE9UeXVEVGRRb3phPXt9O2ZvciBjYW5kaWRhdGU9MSw1MCBkbyBpZiBIQnpxT216SWtXZihjYW5kaWRhdGUpdGhlbiBPVHl1RFRkUW96YVsjT1R5dURUZFFvemErMV09Y2FuZGlkYXRlIGVuZCBlbmQgb2trdmJKRFR1eCgicHJpbWVzOiAiLi5Wa0VzQ3NRVChPVHl1RFRkUW96YSwiLCIpKTtva2t2YkpEVHV4KCJnY2QoODQsIDM2KSA9ICIuLmx4ZEdkYXNlKDg0LDM2KSk7b2trdmJKRFR1eCgiY2xhbXA6ICIuLmt1ZWRCSnZzbGpyTigxNSwwLDEwKS4uIiAiLi5rdWVkQkp2c2xqck4oLTMsMCwxMCkuLiIgIi4ua3VlZEJKdnNsanJOKDcsMCwxMCkpO29ra3ZiSkRUdXgoc3RyaW5nLmZvcm1hdCgiJTUuMmZ8JS02c3wlMDNkIiwzLjE0MTU5LCJhYiIsNykp"))
run()
