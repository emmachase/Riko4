local syntaxTheme = {
  keyword = 8,     -- purple
  func = 6,        -- cyanish
  special = 6,
  string = 5,      -- lime green
  primitive = 3,   -- orange,
  catch = 1,       -- everything else is white
  comment = 10
}

local sleep = sleep
local tabInsert = table.insert
local tabRemove = table.remove

local content = {
  "local function pullEvent(filter)",
  "  local e",
  "  while true do",
  "    e = {coroutine.yield()}",
  "    if not filter or e[1] == filter then",
  "      break",
  "    end -- a random comment",
  "  end",
  "  write(\"Done!\\n\", 2, 2, 7)",
  "  return unpack(e)",
  "end"
}

local colorizedLines = {}

local needsRedraw = true
local cursorLine = 4
local cursorPos = #content[4]
local blinkTimeCorrection = os.clock()

local keywords = {
  ["local"] = true,
  ["function"] = true,
  ["for"] = true,
  ["if"] = true,
  ["then"] = true,
  ["in"] = true,
  ["do"] = true,
  ["else"] = true,
  ["elseif"] = true,
  ["end"] = true,
  ["break"] = true,
  ["return"] = true,
  ["not"] = true,
  ["and"] = true,
  ["or"] = true,
  ["while"] = true,
  ["repeat"] = true,
  ["until"] = true,
}

local wordPrims = {
  ["true"] = true,
  ["false"] = true,
  ["nil"] = true,
}

local function colorizeLine(line)
  local text = content[line]
  colorizedLines[line] = {}

  local instr = false
  local laststr

  while #text > 0 do
    local beginp, endp = text:find("[a-zA-Z0-9%_]+")
    --"[^ ^%;^%,^%(^%)^%.^%\"^%\\^%{^%}^%[^%]^%+^%-^%=^%%^%#^%^^%*]+")

    if not beginp then
      local lastun = ""
      local blastun = ""
      for i=1, #text do
        local unimp = text:sub(i, i)
        if unimp then
          if not instr and unimp == "-" and #text > i and text:sub(i + 1, i + 1) == "-" then
            tabInsert(colorizedLines[line], {text:sub(i), syntaxTheme.comment})
            break
          elseif instr and ((lastun == "\\" and blastun ~= "\\") or unimp == "\\") then
            tabInsert(colorizedLines[line], {unimp, syntaxTheme.special})
          elseif laststr and unimp == laststr and (lastun ~= "\\" or blastun == "\\") then
            laststr = nil
            instr = false
            tabInsert(colorizedLines[line], {unimp, syntaxTheme.string})
          elseif not laststr and (unimp == "\"" or unimp == "'") then
            laststr = unimp
            instr = true
            tabInsert(colorizedLines[line], {unimp, syntaxTheme.string})
          else
            tabInsert(colorizedLines[line], {unimp, instr and syntaxTheme.string or syntaxTheme.catch})
          end

          blastun = lastun
          lastun = unimp
        end
      end
      break
    else
      local lastun = ""
      local blastun = ""
      local qt = false
      for i=1, beginp - 1 do
        local unimp = text:sub(i, i)
        if unimp then
          if not instr and unimp == "-" and #text > i and text:sub(i + 1, i + 1) == "-" then
            tabInsert(colorizedLines[line], {text:sub(i), syntaxTheme.comment})
            qt = true
            break
          elseif instr and ((lastun == "\\" and blastun ~= "\\") or unimp == "\\") then
            tabInsert(colorizedLines[line], {unimp, syntaxTheme.special})
          elseif laststr and unimp == laststr and (lastun ~= "\\" or blastun == "\\") then
            laststr = nil
            instr = false
            tabInsert(colorizedLines[line], {unimp, syntaxTheme.string})
          elseif not laststr and (unimp == "\"" or unimp == "'") then
            laststr = unimp
            instr = true
            tabInsert(colorizedLines[line], {unimp, syntaxTheme.string})
          else
            tabInsert(colorizedLines[line], {unimp, instr and syntaxTheme.string or syntaxTheme.catch})
          end

          blastun = lastun
          lastun = unimp
        end
      end

      if qt then break end

      if lastun == "\\" and instr then
        tabInsert(colorizedLines[line], {text:sub(beginp, beginp), syntaxTheme.special})
        text = text:sub(beginp + 1)
      else
        local word = text:sub(beginp, endp)
        do
          local nextX = text:sub(endp + 1):match("%S+")

          if instr then
            tabInsert(colorizedLines[line], {word, syntaxTheme.string})
          elseif nextX and nextX:sub(1, 1) == "(" then
            tabInsert(colorizedLines[line], {word, syntaxTheme.func})
          elseif keywords[word] then
            tabInsert(colorizedLines[line], {word, syntaxTheme.keyword})
          elseif tonumber(word) or wordPrims[word] then
            tabInsert(colorizedLines[line], {word, syntaxTheme.primitive})
          else
            tabInsert(colorizedLines[line], {word, syntaxTheme.catch})
          end
        end
        text = text:sub(endp + 1)
      end
    end
  end
end

local function pullEvent(filter)
  local e
  while true do
    e = {coroutine.yield()}
    if not filter or e[1] == filter then
      break
    end
  end
  return unpack(e)
end

local drawOffsets = {0, 0}
local lines = math.floor(224 / 8) - 1
local hintText = "Press <ctrl> to open menu"

local function drawCursor(force, which)
  local ctime = math.floor(((os.clock() - blinkTimeCorrection) * 2)) % 2

  if ((ctime == 0 or force)) or which == 1 then
    -- Place cursor
    write("_", (cursorPos + drawOffsets[1]) * 7 + 2, (cursorLine + drawOffsets[2] - 1) * 8 + 4, 1)
  elseif ((ctime == 1 or force)) or which == 2 then
    -- Remove cursor
    write("_", (cursorPos + drawOffsets[1]) * 7 + 2, (cursorLine + drawOffsets[2] - 1) * 8 + 4, 0)
  end
end

local function updateCursor(newPos, newLine)
  drawCursor(true, 2)
  cursorPos = newPos
  cursorLine = newLine
  blinkTimeCorrection = os.clock()
  drawCursor(true, 1)
end

local function drawContent()
  gpu.clear()

  for i = 1, lines do
    local cy = i + drawOffsets[2]*8
    local dy = (cy - 1) * 8 + 2
    if not content[cy] then
      break
    end
    --colorizeLine(content[cy], 1 + drawOffsets[1], dy)
    if not colorizedLines[cy] then
      colorizeLine(cy)
    end
    local cx = 1 + drawOffsets[1]*7
    for j = 1, #colorizedLines[cy] do
      local chk = colorizedLines[cy][j]
      write(chk[1], cx, dy, chk[2])
      cx = cx + 7 * #chk[1]
    end

    gpu.drawRectangle(0, lines * 7 - 1, 340, 12, 10)
    write(hintText, 2, lines * 7 + 1, 4)
  end

  drawCursor()
end

local function checkDrawBounds()
  if cursorPos > math.floor(340/7) - drawOffsets[1] - 1 then
    drawOffsets[1] = math.floor(340/7) - cursorPos - 1
    needsRedraw = true
  elseif cursorPos < -drawOffsets[1] then
    drawOffsets[1] = -cursorPos
    needsRedraw = true
  end
end

drawContent()
while true do
  local e, p1, p2 = pullEvent()

  gpu.clear()

  if e == "key" then
    if p1 == "Up" then
      local nx, ny = cursorPos, cursorLine
      if cursorLine > 1 then ny = cursorLine - 1 else nx = 0 end
      if cursorPos > #content[ny] then nx = #content[ny] end
      updateCursor(nx, ny)
      checkDrawBounds()
    elseif p1 == "Down" then
      local nx, ny = cursorPos, cursorLine
      if cursorLine < #content then ny = cursorLine + 1 else nx = #content[ny] end
      if cursorPos > #content[ny] then nx = #content[ny] end
      updateCursor(nx, ny)
      checkDrawBounds()
    elseif p1 == "Left" then
      local nx, ny = cursorPos, cursorLine
      if cursorPos > 0 then
        nx = cursorPos - 1
      elseif ny > 1 then
        ny = ny - 1
        nx = #content[ny]
      end
      updateCursor(nx, ny)
      checkDrawBounds()
    elseif p1 == "Right" then
      local nx, ny = cursorPos, cursorLine
      if cursorPos < #content[ny] then
        nx = cursorPos + 1
      elseif ny < #content then
        ny = ny + 1
        nx = 0
      end
      updateCursor(nx, ny)
      checkDrawBounds()
    elseif p1 == "Backspace" then
      if cursorPos > 0 then
        content[cursorLine] = content[cursorLine]:sub(1, cursorPos - 1) .. content[cursorLine]:sub(cursorPos + 1)
        updateCursor(cursorPos - 1, cursorLine)
        colorizeLine(cursorLine)
        needsRedraw = true
      elseif cursorLine > 1 then
        local ox = #content[cursorLine - 1]
        content[cursorLine - 1] = content[cursorLine - 1] .. tabRemove(content, cursorLine)
        tabRemove(colorizedLines, cursorLine)
        updateCursor(ox, cursorLine - 1)
        colorizeLine(cursorLine)
        needsRedraw = true
      end
      checkDrawBounds()
    elseif p1 == "Delete" then
      if cursorPos < #content[cursorLine] then
        content[cursorLine] = content[cursorLine]:sub(1, cursorPos) .. content[cursorLine]:sub(cursorPos + 2)
        colorizeLine(cursorLine)
        needsRedraw = true
      elseif cursorLine < #content then
        content[cursorLine] = content[cursorLine] .. tabRemove(content, cursorLine + 1)
        tabRemove(colorizedLines, cursorLine + 1)
        colorizeLine(cursorLine)
        needsRedraw = true
      end
      blinkTimeCorrection = os.clock()
    elseif p1 == "Return" then
      local cont = content[cursorLine]:sub(cursorPos + 1)
      local localIndent = content[cursorLine]:find("%S")
      localIndent = localIndent and localIndent - 1 or #content[cursorLine]
      content[cursorLine] = content[cursorLine]:sub(1, cursorPos)
      tabInsert(content, cursorLine + 1, (" "):rep(localIndent)..cont)
      tabInsert(colorizedLines, cursorLine + 1, {{cont, 1}})
      updateCursor(localIndent, cursorLine + 1)
      colorizeLine(cursorLine - 1)
      colorizeLine(cursorLine)
      checkDrawBounds()
      needsRedraw = true
    elseif p1 == "Home" then
      local fpos, _ = content[cursorLine]:find("%S")
      if not fpos or cursorPos < fpos then
        updateCursor(0, cursorLine)
      else
        updateCursor(fpos - 1, cursorLine)
      end
      checkDrawBounds()
    elseif p1 == "End" then
      updateCursor(#content[cursorLine], cursorLine)
      checkDrawBounds()
    elseif p1 == "Tab" then
      content[cursorLine] = content[cursorLine]:sub(1, cursorPos) .. "  " .. content[cursorLine]:sub(cursorPos + 1)
      updateCursor(cursorPos + 2, cursorLine)
      colorizeLine(cursorLine)
      needsRedraw = true
    end
  elseif e == "char" then
    content[cursorLine] = content[cursorLine]:sub(1, cursorPos) .. p1 .. content[cursorLine]:sub(cursorPos + 1)
    updateCursor(cursorPos + 1, cursorLine)
    colorizeLine(cursorLine)
    checkDrawBounds()
    needsRedraw = true
  end

  drawContent()

  gpu.swap()
end
