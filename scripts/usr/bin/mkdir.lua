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
