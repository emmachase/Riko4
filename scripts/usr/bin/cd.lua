--HELP: \b6Usage: \b16cd \b7<\b16dir\b7> \n
-- \b6Description: \b7Changes directory to \b16dir

local args = {...}

local mask = tonumber("11111111", 2)

local function er(t)
    if shell then
        print(t, 8)
    else
        error(t, 2)
    end
end

if #args > 0 then
    local arg = args[1]

    local val = fs.getAttr(arg)
    if val == mask then
        er("`" .. arg .. "' does not exist\n")
    elseif bit.band(val, 2) ~= 2 then
        er("`" .. arg .. "' is not a directory\n")
    else
        fs.setCWD(arg)
    end
else
    fs.setCWD("/home")
end
