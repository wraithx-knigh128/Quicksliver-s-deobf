-- written for this project's tests: a script that only downloads and runs code (the URL is an example address that does not exist)
getgenv().Settings = { Key = "demo" }
loadstring(game:HttpGet("https://example.invalid/scripts/hub/main.lua"))()
