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
    local val = fs.getAttr(args)
    if val == mask then
        er("`" .. args .. "' does not exist\n")
    elseif bit.band(val, 2) ~= 2 then
        er("`" .. args .. "' is not a directory\n")
    else
        fs.setCWD(args)
    end
end
