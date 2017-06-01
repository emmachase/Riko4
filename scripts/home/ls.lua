local args = {...}

local function tabulateCommon(...)
    local tAll = {...}
    
    local w = (gpu.width - 4) / 8
    local nMaxLen = w / 8
    for n, t in ipairs(tAll) do
        if type(t) == "table" then
            for n, sItem in pairs(t) do
                nMaxLen = math.max(string.len( sItem ) + 1, nMaxLen)
            end
        end
    end
    local nCols = math.floor(w / nMaxLen)
    local nLines = 0

    local cx = 0

    local function newLine()
        writeOutputC("\n", nil, false)
        cx = 0
        nLines = nLines + 1
    end
    
    local cc = nil
    local function drawCols(_t)
        local nCol = 1
        for n, s in ipairs(_t) do
            if nCol > nCols then
                nCol = 1
                newLine()
            end

	    writeOutputC((" "):rep(((nCol - 1) * nMaxLen) - cx) .. s, cc, false)
            cx = ((nCol - 1) * nMaxLen) + #s

            nCol = nCol + 1      
        end
    end
    for n, t in ipairs(tAll) do
        if type(t) == "table" then
            if #t > 0 then
                drawCols(t)
                if n < #tAll then
                  writeOutputC("\n", nil, false)
                end
            end
        elseif type(t) == "number" then
--            term.setTextColor( t )
	    cc = t
        end
    end    
end

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

local dir = args[1] and "./home/"..args[1] or "./home/"

--local avW = (gpu.width - 4) / 8

--local cx = 0

local outTbl = {9, {}, 16, {}}

local list = fs.list(dir)

for _, v in pairs(list) do
--  shell.redraw(
  if (v:sub(1, 1) == "." and (not v:match("%w"))) or v:sub(1, 1) ~= "." then
    if fs.isDir(dir .. "/" .. v) then
      table.insert(outTbl[2], v)
    else
      table.insert(outTbl[4], v)
    end
  end
end

table.sort(outTbl[2])
table.sort(outTbl[4])

tabulateCommon(unpack(outTbl))

shell.redraw()