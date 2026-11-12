--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
(function(...) local nToMJhcidNSu,amlYvSjELkxY,cXCAIeCyAquE
nToMJhcidNSu=math.floor;amlYvSjELkxY=string.char;cXCAIeCyAquE=table.concat;
local esahvaGEdsW = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function eJGJNYYuQ(text)
  local kGVDzihq, RJhQJexzoEs, FYtJIeYu = {}, 0, 0
  for i = 1, #text do
    local ZxdMMfaQSJ = text:sub(i, i)
    local NzteKqkRAPw = esahvaGEdsW:find(ZxdMMfaQSJ, 1, true)
    if NzteKqkRAPw then
      RJhQJexzoEs = RJhQJexzoEs * 64 + (NzteKqkRAPw - 1)
      FYtJIeYu = FYtJIeYu + 6
      if FYtJIeYu >= 8 then
        FYtJIeYu = FYtJIeYu - 8
        local dCTXLZowtL = 2 ^ FYtJIeYu
        kGVDzihq[#kGVDzihq + 1] = string.char(math.floor(RJhQJexzoEs / dCTXLZowtL))
        RJhQJexzoEs = RJhQJexzoEs % dCTXLZowtL
      end
    end
  end
  return table.concat(kGVDzihq)
end
local RMhhZOJR = (loadstring or load)(eJGJNYYuQ("LS0gczA3OiBSb2Jsb3gtc3R5bGUgc2NyaXB0IHdyaXR0ZW4gYWdhaW5zdCB0aGUgbW9jayBlbnZpcm9ubWVudCBpbiB0ZXN0cy9jb3JwdXMvdG9vbHMvcnVuX2x1YS5weS4KLS0gRXhlcmNpc2VzIGdsb2JhbCBBUEkgYWNjZXNzIHBhdHRlcm5zIHRoYXQgb2JmdXNjYXRvcnMgaGlkZSAoR2V0U2VydmljZSwgSW5zdGFuY2UubmV3LCBldmVudHMpLgpsb2NhbCBQbGF5ZXJzID0gZ2FtZTpHZXRTZXJ2aWNlKCJQbGF5ZXJzIikKbG9jYWwgUnVuU2VydmljZSA9IGdhbWU6R2V0U2VydmljZSgiUnVuU2VydmljZSIpCmxvY2FsIFJlcGxpY2F0ZWRTdG9yYWdlID0gZ2FtZTpHZXRTZXJ2aWNlKCJSZXBsaWNhdGVkU3RvcmFnZSIpCgpsb2NhbCBwbGF5ZXIgPSBQbGF5ZXJzLkxvY2FsUGxheWVyCmxvY2FsIHNldHRpbmdzID0geyBzcGVlZCA9IDI0LCBqdW1wID0gNTAsIGxhYmVsID0gIlF1aWNrU2lsdmVyIiB9Cgpsb2NhbCBmdW5jdGlvbiBjb25maWd1cmUoY2hhcmFjdGVyKQogIGxvY2FsIGh1bWFub2lkID0gY2hhcmFjdGVyOldhaXRGb3JDaGlsZCgiSHVtYW5vaWQiKQogIGh1bWFub2lkLldhbGtTcGVlZCA9IHNldHRpbmdzLnNwZWVkCiAgaHVtYW5vaWQuSnVtcFBvd2VyID0gc2V0dGluZ3MuanVtcAogIHJldHVybiBodW1hbm9pZAplbmQKCmxvY2FsIHBhcnQgPSBJbnN0YW5jZS5uZXcoIlBhcnQiKQpwYXJ0Lk5hbWUgPSBzZXR0aW5ncy5sYWJlbCAuLiAiTWFya2VyIgpwYXJ0LkFuY2hvcmVkID0gdHJ1ZQpwYXJ0LlBhcmVudCA9IHdvcmtzcGFjZQoKbG9jYWwgaHVtYW5vaWQgPSBjb25maWd1cmUocGxheWVyLkNoYXJhY3RlcikKcHJpbnQoImNvbmZpZ3VyZWQiLCBodW1hbm9pZC5XYWxrU3BlZWQsIGh1bWFub2lkLkp1bXBQb3dlciwgcGFydC5OYW1lKQoKbG9jYWwgdGlja3MgPSAwCmxvY2FsIGNvbm5lY3Rpb24KY29ubmVjdGlvbiA9IFJ1blNlcnZpY2UuSGVhcnRiZWF0OkNvbm5lY3QoZnVuY3Rpb24oZHQpCiAgdGlja3MgPSB0aWNrcyArIDEKICBpZiB0aWNrcyA+PSAzIHRoZW4KICAgIGNvbm5lY3Rpb246RGlzY29ubmVjdCgpCiAgICBwcmludCgiaGVhcnRiZWF0IGRvbmUiLCB0aWNrcykKICBlbmQKZW5kKQoKbG9jYWwgcmVtb3RlID0gUmVwbGljYXRlZFN0b3JhZ2U6V2FpdEZvckNoaWxkKCJSZW1vdGUiKQpyZW1vdGU6RmlyZVNlcnZlcigiaGVsbG8iLCA0MikK"))
RMhhZOJR()
 end)()