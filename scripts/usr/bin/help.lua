--HELP: \b6Usage: \b16help \b7[\b16program\b7] \n
-- \b6Description: \b7When \b16program \b7is given, displays help for that program, otherwise displays general help

local args = {...}

local w, h = gpu.width, gpu.height

local function writeICWrap(str, preserveWordsQ, strLitQ, start)
  local color = 16
  start = start or 0

  local pw = preserveWordsQ
  if strLitQ then
    str = str:gsub("\n", "")
    str = str:gsub("\\b", "\b")
  end

  str = "\b16" .. str

  for part in str:gmatch("\b?[^\b]+") do
    if tonumber(part:sub(3, 3)) then
      color = tonumber(part:sub(2, 3))
      part = part:sub(4)
    else
      color = tonumber(part:sub(2, 2))
      part = part:sub(3)
    end

    local endP = function() return math.floor((w - start - 3) / 7) end

    if #part > endP() then
      local max = math.floor(w / 7)

      if pw then
        while #part > 0 do
          local sec = part:sub(1, endP() + 1) .. (" "):rep(endP() - #part)
          local wp = sec:sub(endP(), endP() + 1)
          if wp:match("%S%S") then
            local rev = sec:reverse()
            local fpw = #sec - (rev:find("%s") or #rev)
            local left = part:sub(fpw + 1):match("%s*(.+)")
            part = part:sub(1, fpw)

            shell.writeOutputC(part .. "\n ", color)
            start = 7

            part = left
          else
            shell.writeOutputC(part:sub(1, endP()), color)
            local ep = #part:sub(1, endP())
            part = part:sub(ep + 1)
            start = start + ep * 7
            if start >= (max - 1) * 7 then
              shell.writeOutputC("\n ")
              part = part:match("%s*(.+)") or ""
              start = 7
            end
          end
        end
      else
        shell.writeOutputC(part:sub(1, endP()), color)
        
        part = part:sub(endP() + 1)
        start = 7

        while #part > 0 do
          shell.writeOutputC("\n " .. part:sub(1, endP()), color)

          part = part:sub(endP() + 1)
          start = 7
        end
      end
    else
      shell.writeOutputC(part, color)
      start = start + #part * 8
    end
  end
end

if #args == 0 then
  writeICWrap("\b8System: \b7Riko4\n")
  writeICWrap("\b8Version: \b12v0.0.1\n\n")

  writeICWrap([[\b7For a list of readily accessible programs, type \b16programs\b7 into the shell.]], true, true)

  writeICWrap("\n\n")
  writeICWrap([[\b7For help with a specific program, type \b16help <<program>>\b7 into the shell.]], true, true)
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
          DONE = true
          break
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