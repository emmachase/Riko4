--HELP: \b6Usage: \b16help \b7[\b16program\b7] \n
-- \b6Description: \b7When \b16program \b7is given, displays help for that program, otherwise displays general help

local args = {...}

local w, h = gpu.width, gpu.height

local function writeICWrap(str, preserveWordsQ, strLitQ, start, hang)
  local color = 16
  start = start or 0
  hang = hang or 1

  local pw = preserveWordsQ
  if strLitQ then
    str = str:gsub("\n", "")
    str = str:gsub("\\b", "\b")
  end

  local maxW = function() return math.floor(w / (gpu.font.data.w + 1) - start) - 1 end

  while #str > 0 do
    local nextB, bEnd, nCol = str:find("\b([%d]+)")

    local sect
    local newL = false

    if nextB and nextB <= maxW() then
      sect = str:sub(1, nextB - 1)
      str = str:sub(bEnd + 1)

      newL = nextB - 1 >= maxW()
    else
      nCol = color

      local len = math.min(#str, maxW())

      local nnl = false
      if pw then
        if str:sub(len, len + 1):match("%S%S") then
          len = len - (str:sub(1, len):reverse():find("%s") - 1) or 0
          nnl = true
        end
      end

      sect = str:sub(1, len)
      str = str:sub(len + 1)

      newL = (len >= maxW()) or nnl
    end

    if #sect > 0 then
      if newL then
        print(sect, color)
      elseif sect:find("\n") then
        local ssect = sect
        while ssect and ssect:find("\n") do
          print(ssect:match("[^\n]+"), color)
          ssect = ssect:match("\n(.+)")
        end

        if ssect then
          shell.write(ssect, color)
        end
      else
        shell.write(sect, color)
      end
    end
    
    if newL then
      shell.write((" "):rep(hang))
      start = hang * (gpu.font.data.w + 1)
    else
      start = start + #sect
    end

    color = tonumber(nCol)
  end
end

if #args == 0 then
  writeICWrap("\b8System: \b7Riko4\n")
  writeICWrap("\b8Version: \b12v0.0.1\n\n")

  writeICWrap([[\b7For a list of programs, type \b16programs\b7 into the shell.]], true, true)

  writeICWrap("\n")
  writeICWrap([[\b7For help with a specific program, type \b16help <<program>>\b7.]], true, true)
  writeICWrap("\n")
else
  local handleName = ""
  local DONE = false
  for i = 1, #shell.config.path do
    local dir = fs.list(shell.config.path[i]) or {}
    for j = 1, #dir do
      local name = dir[j]
      if name ~= "." and name ~= ".." then
        local ctp = name:find("%.")
        local fnm = name
        if ctp then fnm = name:sub(1, ctp - 1) end
        if fnm == args[1] then
          handleName = shell.config.path[i] .. "/" .. name
          if bit.band(fs.getAttr(handleName), 2) == 2 then
            -- Is a directory
            handleName = ""
          else
            DONE = true
            break
          end
        end
      end
    end
    
    if DONE then
      break
    end
  end

  if handleName == "" then
    writeICWrap("\b7No program called \b16" .. args[1] .. "\b7 was found\n", true)
    return
  end

  local handle = fs.open(handleName, "rb")

  if not handle then
    writeICWrap("\b8An unexpected error occured\n", true)
    return
  end
  local first = handle:read("*line")
  
  if first:sub(1, 7) == "--HELP:" then
    first = "--" .. first:sub(8)
    while true do
      local bit = first:sub(4)

      if bit:sub(#bit - 1, #bit) == "\\n" then
        writeICWrap(bit:sub(1, #bit - 3), true, true)
        writeICWrap("\n")

        first = handle:read("*line")
      else
        writeICWrap(bit, true, true)
        writeICWrap("\n")

        break
      end
    end
  else
    writeICWrap("\b7No help information was found for this program\n", true)
  end

  handle:close()
end

print()
