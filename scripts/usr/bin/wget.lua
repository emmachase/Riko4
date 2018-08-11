--HELP: \b6Usage: \b16wget \b7<\b16url\b7> [\b16file\b7] \n
-- \b6Description: \b7Downloads data from \b16url\b7 to \b16file\b7.

local getopt = require("getopt")
local args = {...}
local parseInstance = getopt(args, "", {
}) {
}
if #parseInstance.notOptions < 1 then
  print("Missing operand", 8)
  print("Try 'help wget' for more information", 8)
  return
end

local url, file = parseInstance.notOptions[1], parseInstance.notOptions[2]
if not file then
  file = url:sub(#fs.getBaseDir(url) + 2)
end

shell.write("Fetching url " .. url .. "...")
local response = net.get(url)
if not response then
  print(" Failed.", 8)
  return
end
local data = response:readAll()

local handle = fs.open(file, "wb" )
handle:write(data)
handle:close()

print("\nWritten to " .. file, 12 )
