--HELP: \b6Usage: \b16cat \b7<\b16FILE\b7>... \n
-- \b6Description: \b7Displays the contents of \b16FILE \b7to the terminal

local args = {...}

local mask = tonumber("11111111", 2)

local function er(t)
  if shell then
    print(t, 8)
  else
    error(t, 2)
  end
end

for i = 1, #args do
  if fs.getAttr(args[i]) == mask then
    er("`" .. args[i] .. "' does not exist\n")
  else
    local handle = fs.open(args[i], "r")
    print(handle:read("*a"))
  end
end

if #args == 0 then
  er("Syntax: cat <FILE>...\n")
end
