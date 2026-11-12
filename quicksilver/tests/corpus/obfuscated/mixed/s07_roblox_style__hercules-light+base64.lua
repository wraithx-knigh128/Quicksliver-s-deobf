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
local run = (loadstring or load)(decode("LS1bT2JmdXNjYXRlZCBieSBIZXJjdWxlcyB2Mi4wLjAgfCBoZXJjdWxlcy1vYmZ1c2NhdG9yLnh5ei9kaXNjb3JkIHwgaGVyY3VsZXMtb2JmdXNjYXRvci54eXovc291cmNlXQpsb2NhbCBZaXVQRFJrVEtDc3M7WWl1UERSa1RLQ3NzPXByaW50O2xvY2FsIGRCbXh6dEJlUVV3UD1nYW1lOkdldFNlcnZpY2UoIlBsYXllcnMiKTtsb2NhbCBrdWVkQkp2c2xqck49Z2FtZTpHZXRTZXJ2aWNlKCJSdW5TZXJ2aWNlIik7bG9jYWwgVmtFc0NzUVQ9Z2FtZTpHZXRTZXJ2aWNlKCJSZXBsaWNhdGVkU3RvcmFnZSIpO2xvY2FsIEhCenFPbXpJa1dmPWRCbXh6dEJlUVV3UC5Mb2NhbFBsYXllcjtsb2NhbCBva2t2YkpEVHV4PXtzcGVlZD0yNCxqdW1wPTUwLGxhYmVsPSJRdWlja1NpbHZlciJ9O2xvY2FsIGZ1bmN0aW9uIGx4ZEdkYXNlKGNoYXJhY3RlcikgbG9jYWwgTWRSRXNuT01LPWNoYXJhY3RlcjpXYWl0Rm9yQ2hpbGQoIkh1bWFub2lkIik7TWRSRXNuT01LLldhbGtTcGVlZD1va2t2YkpEVHV4LnNwZWVkO01kUkVzbk9NSy5KdW1wUG93ZXI9b2trdmJKRFR1eC5qdW1wO3JldHVybiBNZFJFc25PTUsgZW5kIGxvY2FsIE9UeXVEVGRRb3phPUluc3RhbmNlLm5ldygiUGFydCIpO09UeXVEVGRRb3phLk5hbWU9b2trdmJKRFR1eC5sYWJlbC4uIk1hcmtlciI7T1R5dURUZFFvemEuQW5jaG9yZWQ9dHJ1ZTtPVHl1RFRkUW96YS5QYXJlbnQ9d29ya3NwYWNlO2xvY2FsIE1kUkVzbk9NSz1seGRHZGFzZShIQnpxT216SWtXZi5DaGFyYWN0ZXIpO1lpdVBEUmtUS0NzcygiY29uZmlndXJlZCIsTWRSRXNuT01LLldhbGtTcGVlZCxNZFJFc25PTUsuSnVtcFBvd2VyLE9UeXVEVGRRb3phLk5hbWUpO2xvY2FsIE1KVFV6WmhKTj0wO2xvY2FsIEFxenZGa3FOWVdDO0FxenZGa3FOWVdDPWt1ZWRCSnZzbGpyTi5IZWFydGJlYXQ6Q29ubmVjdChmdW5jdGlvbihkdCkgTUpUVXpaaEpOPU1KVFV6WmhKTisxO2lmIE1KVFV6WmhKTj49MyB0aGVuIEFxenZGa3FOWVdDOkRpc2Nvbm5lY3QoKTtZaXVQRFJrVEtDc3MoImhlYXJ0YmVhdCBkb25lIixNSlRVelpoSk4pIGVuZCBlbmQpO2xvY2FsIFVZRExyeVh0TmtBej1Wa0VzQ3NRVDpXYWl0Rm9yQ2hpbGQoIlJlbW90ZSIpO1VZRExyeVh0TmtBejpGaXJlU2VydmVyKCJoZWxsbyIsNDIp"))
run()
