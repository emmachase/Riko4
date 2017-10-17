--HELP: \b6Usage: \b16mv \b7[\b16src\b7] [\b16dest\b7] \n
-- \b6Description: \b7Moves \b16src \b7to \b17dest

local args = {...}
local from = args[1]
local to = args[2]

local mask = tonumber("11111111", 2)

local function er(t)
    if shell then
        shell.writeOutputC(t, 8)
    else
        error(t, 2)
    end
end

local function last(str)
    local estr
    for w in str:gmatch("[^/\\]+") do
        estr = w
    end

    return estr
end

if #from > 0 and #to > 0 then
    if fs.getAttr(from) == mask then
        er("`" .. from .. "' does not exist\n")
    else
        if fs.getAttr(to) == mask then
            fs.move(from, to)
        elseif bit.band(fs.getAttr(to), 2) ~= 2 then
            er("`" .. to .. "' already exists\n")
        else
            local nfn = to .. "/" .. last(from)
            if fs.getAttr(nfn) == mask then
                fs.move(from, nfn)
            else
                er("`" .. nfn .. "' already exists\n")
            end
        end
    end
else
    er("Syntax: mv <src> <dest>\n")
end
