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
local run = (loadstring or load)(decode("LS1bT2JmdXNjYXRlZCBieSBIZXJjdWxlcyB2Mi4wLjAgfCBoZXJjdWxlcy1vYmZ1c2NhdG9yLnh5ei9kaXNjb3JkIHwgaGVyY3VsZXMtb2JmdXNjYXRvci54eXovc291cmNlXQpsb2NhbCBNSlRVelpoSk4sQXF6dkZrcU5ZV0MsTWRSRXNuT01LLFlpdVBEUmtUS0NzcyxFVURzY2VaRyxHbHVJa253UmlJTTtNSlRVelpoSk49aXBhaXJzO0FxenZGa3FOWVdDPXBhaXJzO01kUkVzbk9NSz1wcmludDtZaXVQRFJrVEtDc3M9c3RyaW5nLmZvcm1hdDtFVURzY2VaRz10YWJsZS5jb25jYXQ7R2x1SWtud1JpSU09dGFibGUuc29ydDtsb2NhbCBVWURMcnlYdE5rQXo9IkhlbGxvLCBRdWlja1NpbHZlciEiO2xvY2FsIGRCbXh6dEJlUVV3UD0iLS0tLS0tLS0tLS0tLS0tLS0tLS0iO2xvY2FsIFZrRXNDc1FUPXsiYWxwaGEiLCJicmF2byIsImNoYXJsaWUiLCJkZWx0YSIsImVjaG8iLCJmb3h0cm90In07bG9jYWwgSEJ6cU9teklrV2Y9IlslMDJkXSAlcyAoJWQgY2hhcnMpIjtNZFJFc25PTUsoVVlETHJ5WHROa0F6KTtNZFJFc25PTUsoZEJteHp0QmVRVXdQKTtmb3IgaW5kZXgsd29yZCBpbiBNSlRVelpoSk4oVmtFc0NzUVQpZG8gTWRSRXNuT01LKHN0cmluZy5mb3JtYXQoSEJ6cU9teklrV2YsaW5kZXgsd29yZDp1cHBlcigpLCN3b3JkKSkgZW5kIE1kUkVzbk9NSyhkQm14enRCZVFVd1ApO2xvY2FsIG9ra3ZiSkRUdXg9InRoZSBxdWljayBicm93biBmb3gganVtcHMgb3ZlciB0aGUgbGF6eSBkb2ciO2xvY2FsIGt1ZWRCSnZzbGpyTj17fTtmb3IgbGV0dGVyIGluIG9ra3ZiSkRUdXg6Z21hdGNoKCIlYSIpZG8ga3VlZEJKdnNsanJOW2xldHRlcl09KGt1ZWRCSnZzbGpyTltsZXR0ZXJdb3IgMCkrMSBlbmQgbG9jYWwgT1R5dURUZFFvemE9e307Zm9yIGxldHRlciBpbiBBcXp2RmtxTllXQyhrdWVkQkp2c2xqck4pZG8gT1R5dURUZFFvemFbI09UeXVEVGRRb3phKzFdPWxldHRlciBlbmQgdGFibGUuc29ydChPVHl1RFRkUW96YSk7bG9jYWwgbHhkR2Rhc2U9e307Zm9yIF8sbGV0dGVyIGluIE1KVFV6WmhKTihPVHl1RFRkUW96YSlkbyBseGRHZGFzZVsjbHhkR2Rhc2UrMV09bGV0dGVyLi4iPSIuLmt1ZWRCSnZzbGpyTltsZXR0ZXJdIGVuZCBNZFJFc25PTUsodGFibGUuY29uY2F0KGx4ZEdkYXNlLCIgIikpO01kUkVzbk9NSyhva2t2YkpEVHV4OnJldmVyc2UoKSk7TWRSRXNuT01LKChva2t2YkpEVHV4OmdzdWIoIm8iLCIwIikpKTtNZFJFc25PTUsoKCJhYiIpOnJlcCgzKSk7TWRSRXNuT01LKG9ra3ZiSkRUdXg6c3ViKDUsOSkuLiJ8Ii4ub2trdmJKRFR1eDpmaW5kKCJmb3giLDEsdHJ1ZSkp"))
run()
