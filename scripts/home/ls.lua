local args = {...}

-- Lua implementation of PHP scandir function
local function scandir(directory)
    local i, t, popen = 0, {}, io.popen
    local pfile = popen('ls -a "'..directory..'"')
    for filename in pfile:lines() do
        i = i + 1
        t[i] = filename
    end
    pfile:close()
    return t
end

local dir = args[1] and "./scripts/home/"..args[1] or "./scripts/home"

for _, v in next, scandir(dir) do
  pushOutput(v)
  shell.redraw()
end
