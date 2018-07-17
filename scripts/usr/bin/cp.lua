--HELP: \b6Usage: \b16cp \b7<\b16src\b7> \b7<\b16dest\b7> \n
-- \b6Description: \b7Copies \b16src \b7file to \b16dest

local args = {...}
if #args ~= 2 then
  return print("Syntax: cp <src> <dest>", 9)
end

local function try()
  fs.copy(args[1], args[2])
end

local s, e = pcall(try)

if not s then
  print(e, 8)
end
