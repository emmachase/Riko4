--HELP: \b6Usage: \b16ls \b7[\b16dir\b7]\b16\n
-- \b6Description: \b7List the contents of \b16dir\b7 or if not specified, the current directory

local args = {...}

local dir = args[1] and args[1] or "./"

local outTbl = {9, {}, 16, {}}

local list = fs.list(dir)

for _, v in pairs(list) do
  if (v:sub(1, 1) == "." and (not v:match("%w"))) or v:sub(1, 1) ~= "." then
    pcall(function()
      if bit.band(fs.getAttr(dir .. "/" .. v), 2) == 2 then
        table.insert(outTbl[2], v)
      else
        table.insert(outTbl[4], v)
      end
    end)
  end
end

table.sort(outTbl[2])
table.sort(outTbl[4])

shell.tabulate(unpack(outTbl))

shell.writeOutputC("\n")
