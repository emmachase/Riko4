local editorTheme = {
  bg = 1,
  text = 16,
  selBar = 2,
  selChar = 10
}
local syntaxTheme = {
  keyword = 13,    -- purple
  specialKeyword = 12,
  func = 12,       -- cyanish
  special = 12,
  string = 8,     -- lime green
  primitive = 9,   -- orange,
  comment = 6,     -- gray
  catch = 16       -- everything else is white
}

local width, height = gpu.width, gpu.height

local args = {...}
if #args < 1 then
  if shell then
    shell.writeOutputC("Syntax: edit <filename>\n", 9)
    return
  else
    error("Syntax: edit <filename>", 2)
  end
end

local tabInsert = table.insert
local tabRemove = table.remove

local function exists(filename)
  local handle = fs.open(filename, "rb")
  if handle then
    handle:close()
    return true
  end
  return false
end

local filename = args[1]

local content = {}

local function fsLines(filename)
  local handle = fs.open(filename, "rb")
  local i = 1

  return function()
    local c = handle:read("*l")
    i = i + 1

    print(c)

    if c then
      return c
    else
      handle:close()
      return nil
    end
  end
end

local function ccat(tbl, sep)
  local estr = ""
  for i = 1, #tbl do
    estr = estr .. tbl[i]
    if i ~= #tbl then
      estr = estr .. sep
    end
  end

  return estr
end

if exists(filename) then
  for line in fsLines(filename) do
    if line then
      content[#content + 1] = line
    end
  end
end

if #content == 0 then
  content[#content + 1] = ""
end

local colorizedLines = {}

local tclc = tonumber(args[2])
local cursorLine = tclc and tclc or 1
local cursorPos = #content[cursorLine]
local blinkTimeCorrection = os.clock()

local running = true

local inMenu = false
local menuItems = { "Save", "Exit" }
local menuFunctions = {
  function() -- SAVE
    local handle = fs.open(filename, "w")
    handle:write(ccat(content, "\n"))
    handle:close()
  end,
  function() -- EXIT
    running = false
  end
}
local menuSelected = 1

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

local specialVars = {
  ["io"] = true,
  ["table"] = true,
  ["coroutine"] = true,
  ["string"] = true,
  ["_G"] = true,
  ["math"] = true,
  ["error"] = true,
  ["os"] = true
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
          elseif specialVars[word] then
            tabInsert(colorizedLines[line], {word, syntaxTheme.specialKeyword})
          elseif keywords[word] then
            tabInsert(colorizedLines[line], {word, syntaxTheme.keyword})
          elseif nextX and nextX:sub(1, 1) == "(" then
            tabInsert(colorizedLines[line], {word, syntaxTheme.func})
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
local lines = math.floor((height - 10) / 8) - 1
local hintText = "Press <ctrl> to open menu"

local function drawCursor(force, which)
  local ctime = math.floor(((os.clock() - blinkTimeCorrection) * 2)) % 2

  if ((ctime == 0 or force)) or which == 1 then
    write("_", (cursorPos + drawOffsets[1]) * 7 + 2, (cursorLine - drawOffsets[2] - 1) * 8 + 4, editorTheme.text)
  end
end

local function updateCursor(newPos, newLine)
  drawCursor(true, 2)
  cursorPos = newPos
  cursorLine = newLine
  blinkTimeCorrection = os.clock()
  drawCursor(true, 1)
end

local braceX = 2
local braceXGoal = 2
local braceWidth = (#menuItems[menuSelected] + 1)*7
local braceWidthGoal = (#menuItems[menuSelected] + 1)*7

local function updateHint()
  if inMenu then
    local width = 0
    for i=1, #menuItems do
      if i == menuSelected then
        break
      end
      width = width + #menuItems[i] + 2
    end
    braceXGoal = 2 + width * 7
    braceWidthGoal = (#menuItems[menuSelected] + 1) * 7

    hintText = " " .. table.concat(menuItems, "  ")
  else
    hintText = "Press <ctrl> to open menu"
  end
end

local lastI = os.clock()

local function drawContent()
  gpu.clear(editorTheme.bg)

  for i = 1, lines + 1 do
    local cy = i + drawOffsets[2]
    local dy = (i - 1) * 8 + 2
    if not content[cy] then
      break
    end

    if not colorizedLines[cy] then
      colorizeLine(cy)
    end

    local cx = 1 + drawOffsets[1]*7
    for j = 1, #colorizedLines[cy] do
      local chk = colorizedLines[cy][j]
      write(chk[1], cx, dy, chk[2])
      cx = cx + 7 * #chk[1]
    end

    gpu.drawRectangle(0, height - 11, width, 12, editorTheme.selBar)

    local delta = os.clock() - lastI

    braceX = braceX + (braceXGoal - braceX)*10*delta
    if math.abs(braceXGoal - braceX) < 0.1 then braceX = braceXGoal end

    braceWidth = braceWidth + (braceWidthGoal - braceWidth)*10*delta
    if math.abs(braceWidthGoal - braceWidth) < 0.1 then braceWidth = braceWidthGoal end

    write(hintText, 2, height - 10, editorTheme.text)

    if inMenu then
      write("[", braceX, height - 10, editorTheme.selChar)
      write("]", braceX + braceWidth, height - 10, editorTheme.selChar)
    end

    local locStr = "Ln "..cursorLine..", Col "..(cursorPos + 1)
    write(locStr, (width - 5) - (#locStr * 7), height - 10, editorTheme.text)

    lastI = os.clock()
  end

  drawCursor()
end

local function checkDrawBounds()
  if cursorPos > math.floor(width/7) - drawOffsets[1] - 1 then
    drawOffsets[1] = math.floor(width/7) - cursorPos - 1
  elseif cursorPos < -drawOffsets[1] then
    drawOffsets[1] = -cursorPos
  end

  if cursorLine > lines + drawOffsets[2] then
    drawOffsets[2] = cursorLine - lines
  elseif cursorLine < drawOffsets[2] + 1 then
    drawOffsets[2] = cursorLine - 1
  end
end
checkDrawBounds()

local mouseDown = false

local function processEvent(e, p1, p2)
  if e == "key" then
    if p1 == "leftCtrl" then
      inMenu = not inMenu
      updateHint()
    elseif inMenu then
      if p1 == "left" then
        menuSelected = menuSelected == 1 and #menuItems or menuSelected - 1
        updateHint()
      elseif p1 == "right" then
        menuSelected = menuSelected == #menuItems and 1 or menuSelected + 1
        updateHint()
      elseif p1 == "return" then
        menuFunctions[menuSelected]()
        inMenu = false
        updateHint()
      end
    else
      if p1 == "up" then
        local nx, ny = cursorPos, cursorLine
        if cursorLine > 1 then ny = cursorLine - 1 else nx = 0 end
        if cursorPos > #content[ny] then nx = #content[ny] end
        updateCursor(nx, ny)
        checkDrawBounds()
      elseif p1 == "down" then
        local nx, ny = cursorPos, cursorLine
        if cursorLine < #content then ny = cursorLine + 1 else nx = #content[ny] end
        if cursorPos > #content[ny] then nx = #content[ny] end
        updateCursor(nx, ny)
        checkDrawBounds()
      elseif p1 == "left" then
        local nx, ny = cursorPos, cursorLine
        if cursorPos > 0 then
          nx = cursorPos - 1
        elseif ny > 1 then
          ny = ny - 1
          nx = #content[ny]
        end
        updateCursor(nx, ny)
        checkDrawBounds()
      elseif p1 == "right" then
        local nx, ny = cursorPos, cursorLine
        if cursorPos < #content[ny] then
          nx = cursorPos + 1
        elseif ny < #content then
          ny = ny + 1
          nx = 0
        end
        updateCursor(nx, ny)
        checkDrawBounds()
      elseif p1 == "backspace" then
        if cursorPos > 0 then
          content[cursorLine] = content[cursorLine]:sub(1, cursorPos - 1) .. content[cursorLine]:sub(cursorPos + 1)
          updateCursor(cursorPos - 1, cursorLine)
          colorizeLine(cursorLine)
        elseif cursorLine > 1 then
          local ox = #content[cursorLine - 1]
          content[cursorLine - 1] = content[cursorLine - 1] .. tabRemove(content, cursorLine)
          tabRemove(colorizedLines, cursorLine)
          updateCursor(ox, cursorLine - 1)
          colorizeLine(cursorLine)
        end
        checkDrawBounds()
      elseif p1 == "delete" then
        if cursorPos < #content[cursorLine] then
          content[cursorLine] = content[cursorLine]:sub(1, cursorPos) .. content[cursorLine]:sub(cursorPos + 2)
          colorizeLine(cursorLine)
        elseif cursorLine < #content then
          content[cursorLine] = content[cursorLine] .. tabRemove(content, cursorLine + 1)
          tabRemove(colorizedLines, cursorLine + 1)
          colorizeLine(cursorLine)
        end
        blinkTimeCorrection = os.clock()
      elseif p1 == "return" then
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
      elseif p1 == "home" then
        local fpos, _ = content[cursorLine]:find("%S")
        if not fpos or cursorPos < fpos then
          updateCursor(0, cursorLine)
        else
          updateCursor(fpos - 1, cursorLine)
        end
        checkDrawBounds()
      elseif p1 == "end" then
        updateCursor(#content[cursorLine], cursorLine)
        checkDrawBounds()
      elseif p1 == "tab" then
        content[cursorLine] = content[cursorLine]:sub(1, cursorPos) .. "  " .. content[cursorLine]:sub(cursorPos + 1)
        updateCursor(cursorPos + 2, cursorLine)
        colorizeLine(cursorLine)
      end
    end
  elseif e == "mouseWheel" then
    local y = p1
    for _=1, math.abs(y) do
      if y > 0 then
        if drawOffsets[2] > 0 then
          drawOffsets[2] = drawOffsets[2] - 1
        end
      else
        if drawOffsets[2] < #content - 1 then
          drawOffsets[2] = drawOffsets[2] + 1
        end
      end
    end
  elseif e == "mousePressed" or (e == "mouseMoved" and mouseDown) then
    mouseDown = true
    local x, y = p1, p2
    local posX = math.floor((x - 2) / 7) - drawOffsets[1]
    local posY = math.floor((y - 2) / 8) + drawOffsets[2] + 1
    posY = posY < 1 and 1 or (posY > #content and #content or posY)
    posX = posX < 0 and 0 or (posX > #content[posY] and #content[posY] or posX)
    updateCursor(posX, posY)
    checkDrawBounds()
  elseif e == "mouseReleased" then
    mouseDown = false
  elseif e == "char" then
    content[cursorLine] = content[cursorLine]:sub(1, cursorPos) .. p1 .. content[cursorLine]:sub(cursorPos + 1)
    updateCursor(cursorPos + 1, cursorLine)
    colorizeLine(cursorLine)
    checkDrawBounds()
  end
end

local eventQueue = {}

drawContent()
while running do
  while true do
    local e, p1, p2 = pullEvent()
    if not e then break end
    table.insert(eventQueue, {e, p1, p2})
  end

  while #eventQueue > 0 do
    processEvent(unpack(eventQueue[1]))
    table.remove(eventQueue, 1)
  end

  gpu.clear()

  drawContent()

  gpu.swap()
end



