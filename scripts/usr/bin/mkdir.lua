--HELP: \b6Usage: \b16mkdir \b7[\b16dir\b7] \n
-- \b6Description: \b7Creates new directory \b16dir

local args = ({...})[1]

local mask = tonumber("11111111", 2)

local function er(t)
    if shell then
        shell.writeOutputC(t, 8)
    else
        error(t, 2)
    end
end

if #args > 0 then
    if fs.getAttr(args) == mask then
        fs.mkdir(args)
    else
        er("`" .. args .. "' exists\n")
    end
end
