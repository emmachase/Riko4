--HELP: \b6Usage: \b16edit \b7<\b16file\b7> \n
-- \b6Description: \b7Opens \b16file \b7in a code editor

local myPath = fs.getLastFile()

local editorTheme = {
  bg = 1,        -- black
  text = 16,     -- white
  selBar = 2,    -- dark blue
  selChar = 10,  -- yellow
  highlight = 3, -- maroon
  scrollBar = 7  -- light gray
}
local syntaxTheme = {
  keyword = 13,        -- purple
  specialKeyword = 12, -- light blue
  func = 12,           -- light blue
  special = 12,        -- also light blue ;)
  string = 8,          -- red
  primitive = 9,       -- orange
  comment = 6,         -- dark gray
  catch = 16           -- everything else is white
}

local oldFont = gpu.font
local fnt

do
  local font = dofile("/font.lua")

  local cDir = myPath:match(".+%/")

  local handle = fs.open(cDir .. "edit/smol.rff", "rb")
  local data = handle:read("*a")
  handle:close()

  local fnt2 = {data=font.parseFontdata2(data)}
  fnt = fnt2.data

  gpu.font = fnt2
end

local rif = dofile("/lib/rif.lua")

local width, height = gpu.width, gpu.height

local args = {...}
if #args < 1 then
  if shell then
    print("Syntax: edit <file>\n", 9)
    return
  else
    error("Syntax: edit <file>", 2)
  end
end

local mposx, mposy = -5, -5

local cur
do
  local curRIF = "\82\73\86\2\0\6\0\7\1\0\0\0\0\0\0\0\0\0\0\1\0\0\31\16\0\31\241\0\31\255\16\31\255\241\31\241\16\1\31\16\61\14\131\0\24\2"
  local rifout, cw, ch = rif.decode1D(curRIF)
  cur = image.newImage(cw, ch)
  cur:blitPixels(0, 0, cw, ch, rifout)
  cur:flush()
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

local function fsLines(fn)
  local handle = fs.open(fn, "rb")
  local i = 1

  return function()
    local c = handle:read("*l")
    i = i + 1

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

local function trimLines()
  for i = 1, #content do
    content[i] = content[i]:gsub("%s+$", "")
  end
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

local mouseDown = false
local modifiers = {
  ctrl = false,
  shift = false
}

local colorizedLines = {}

local tclc = tonumber(args[2])
local cursorLine = tclc and tclc or 1
local cursorPos = #content[cursorLine]
local blinkTimeCorrection = os.clock()

local selectionStart = {3, 1}
local selectionEnd = {1, 1}
local hasSelection = false

local running = true

local inMenu = false
local menuItems = { "Save", "Exit" }
local menuFunctions = {
  function() -- SAVE
    trimLines()
    cursorPos = #content[cursorLine]
    blinkTimeCorrection = os.clock()

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
  ["fs"] = true,
  ["gpu"] = true,
  ["image"] = true,
  ["speaker"] = true,
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
local lines = math.floor((height - 10) / (fnt.h + 1)) - 1
local hintText = "Press <esc> to open menu"

local function drawCursor(force, which)
  local ctime = math.floor(((os.clock() - blinkTimeCorrection) * 2)) % 2

  if ((ctime == 0 or force)) or which == 1 then
    write("_", (cursorPos + drawOffsets[1]) * (fnt.w + 1) + 1, (cursorLine - drawOffsets[2] - 1) * (fnt.h + 1) + 4, editorTheme.text)
  end
end

local function updateCursor(newPos, newLine)
  drawCursor(true, 2)
  if newLine > #content then
    cursorLine = #content
  else
    cursorLine = newLine
  end

  if newPos > #content[cursorLine] then
    cursorPos = #content[cursorLine]
  else
    cursorPos = newPos
  end
  blinkTimeCorrection = os.clock()
  drawCursor(true, 1)
end

local braceX = 2
local braceXGoal = 2
local braceWidth = (#menuItems[menuSelected] + 1)*(fnt.w + 1)
local braceWidthGoal = (#menuItems[menuSelected] + 1)*(fnt.w + 1)

local function updateHint()
  if inMenu then
    local hWidth = 0
    for i=1, #menuItems do
      if i == menuSelected then
        break
      end
      hWidth = hWidth + #menuItems[i] + 2
    end
    braceXGoal = 2 + hWidth * (fnt.w + 1)
    braceWidthGoal = (#menuItems[menuSelected] + 1) * (fnt.w + 1)

    hintText = " " .. table.concat(menuItems, "  ")
  else
    hintText = "Press <esc> to open menu"
  end
end

local lastI = os.clock()

local function drawContent()
  gpu.clear(editorTheme.bg)

  for i = 0, lines + 2 do
    local cy = i + drawOffsets[2]
    if cy > 0 then
      local dy = (i - 1) * (fnt.h + 1) + 2
      if not content[cy] then
        break
      end

      if not colorizedLines[cy] then
        colorizeLine(cy)
      end

      local hScrl = drawOffsets[1]*(fnt.w + 1)

      if hasSelection then
        local ss1, ss2 = selectionStart[1], selectionStart[2]
        local se1, se2 = selectionEnd[1], selectionEnd[2]

        if ss2 > se2 then
          local t = ss1
          ss1 = se1
          se1 = t
          t = ss2
          ss2 = se2
          se2 = t
        elseif ss2 == se2 and ss1 > se1 then
          local t = ss1
          ss1 = se1
          se1 = t
        end

        if ss2 == se2 then
          if cy == ss2 then
            if se1 == #content[cy] then
              gpu.drawRectangle((fnt.w + 1) * (ss1) + 1 + hScrl, dy, (fnt.w + 1) * (#content[cy] - ss1) + 1, 7, editorTheme.highlight)
            else
              gpu.drawRectangle((fnt.w + 1) * (ss1) + 1 + hScrl, dy, (fnt.w + 1) * (se1 - ss1 + 1) + 1, 7, editorTheme.highlight)
            end
          end
        else
          if cy == ss2 then
            gpu.drawRectangle((fnt.w + 1) * (ss1) + 1 + hScrl, dy, (fnt.w + 1) * (#content[cy] - ss1) + 1, 7, editorTheme.highlight)
          elseif cy == se2 then
            if se1 == #content[cy] then
              gpu.drawRectangle(hScrl, dy, (fnt.w + 1) * #content[cy] + 2, 7, editorTheme.highlight)
            else
              gpu.drawRectangle(hScrl, dy, (fnt.w + 1) * (se1 + 1) + 2, 7, editorTheme.highlight)
            end
          elseif cy > ss2 and cy < se2 then
            gpu.drawRectangle(hScrl, dy, (fnt.w + 1) * #content[cy] + 2, 7, editorTheme.highlight)
          end
        end
      end


      local cx = 1 + drawOffsets[1]*(fnt.w + 1)
      for j = 1, #colorizedLines[cy] do
        local chk = colorizedLines[cy][j]
        write(chk[1], cx, dy, chk[2])
        cx = cx + (fnt.w + 1) * #chk[1]
      end
    end
  end

  local vph = gpu.height - 12
  local barSize = vph * vph / ((#content + lines) * (fnt.h + 1) + 2)
  local barPos = vph * drawOffsets[2] / (#content + lines) + 1

  barSize = barSize < 10 and 10 or (barSize >= vph and vph - 1 or barSize)
  barPos = barPos > (vph - barSize) and (vph - barSize) or barPos

  barSize = math.floor(barSize)
  barPos = math.floor(barPos)

  do
    gpu.drawRectangle(width - 6, barPos, 5, 1,       editorTheme.scrollBar)
    gpu.drawRectangle(width - 6, barPos, 1, barSize, editorTheme.scrollBar)
    gpu.drawRectangle(width - 2, barPos, 1, barSize, editorTheme.scrollBar)
    gpu.drawRectangle(width - 6, barPos + barSize - 1, 5, 1, editorTheme.scrollBar)
  end

  gpu.drawRectangle(0, height - 10, width, 11, editorTheme.selBar)

  local delta = os.clock() - lastI

  braceX = braceX + (braceXGoal - braceX)*10*delta
  if math.abs(braceXGoal - braceX) < 0.1 then braceX = braceXGoal end

  braceWidth = braceWidth + (braceWidthGoal - braceWidth)*10*delta
  if math.abs(braceWidthGoal - braceWidth) < 0.1 then braceWidth = braceWidthGoal end

  write(hintText, 2, height - 9, editorTheme.text)

  if inMenu then
    write("[", braceX, height - 9, editorTheme.selChar)
    write("]", braceX + braceWidth, height - 9, editorTheme.selChar)
  end

  local locStr = "Ln "..cursorLine..", Col "..(cursorPos + 1)
  write(locStr, (width - 5) - (#locStr * (fnt.w + 1)), height - 9, editorTheme.text)

  lastI = os.clock()

  drawCursor()

  cur:render(mposx, mposy)
end

local function checkDrawBounds()
  if cursorPos > math.floor(width/(fnt.w + 1)) - drawOffsets[1] - 1 then
    drawOffsets[1] = math.floor(width/(fnt.w + 1)) - cursorPos - 1
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

local function checkSelectionOrder()
  local ss1, ss2 = selectionStart[1], selectionStart[2]
  local se1, se2 = selectionEnd[1], selectionEnd[2]

  if ss2 > se2 then
    selectionStart = {se1, se2}
    selectionEnd = {ss1, ss2}
  elseif ss2 == se2 and ss1 > se1 then
    selectionStart[1] = se1
    selectionEnd[1] = ss1
  end
end

local function removeSelection()
  if hasSelection then
    checkSelectionOrder()

    if selectionStart[2] == selectionEnd[2] then
      content[selectionStart[2]] = content[selectionStart[2]]:sub(1, selectionStart[1]) .. content[selectionStart[2]]:sub(selectionEnd[1] + 2)
      colorizeLine(selectionStart[2])
    else

      for _ = selectionStart[2] + 1, selectionEnd[2] - 1 do
        tabRemove(content, selectionStart[2] + 1)
        tabRemove(colorizedLines, selectionStart[2] + 1)
      end

      content[selectionStart[2]] = content[selectionStart[2]]:sub(1, selectionStart[1])
      content[selectionStart[2] + 1] = content[selectionStart[2] + 1]:sub(selectionEnd[1] + 2)

      content[selectionStart[2]] = content[selectionStart[2]] .. content[selectionStart[2] + 1]
      colorizeLine(selectionStart[2])

      tabRemove(content, selectionStart[2] + 1)
      tabRemove(colorizedLines, selectionStart[2] + 1)
    end

    hasSelection = false
    updateCursor(selectionStart[1], selectionStart[2])
  end
end

local function initSelection(left)
  if not hasSelection and modifiers.shift then
    local off = left and -1 or 0
    hasSelection = true
    selectionStart = {cursorPos + off, cursorLine}
    selectionEnd = {cursorPos + off, cursorLine}
  end
end

local function updateSelection(mouse)
  if modifiers.shift or mouse then
    if (cursorLine == selectionStart[2] and cursorPos <= selectionStart[1]) or cursorLine < selectionStart[2] then
      selectionEnd = {cursorPos, cursorLine}
    else
      selectionEnd = {cursorPos - 1, cursorLine}
    end
  else
    hasSelection = false
  end
end

local function processEvent(e, p1, p2)
  if e == "key" then
    if p1 == "leftCtrl" or p1 == "rightCtrl" then
      modifiers.ctrl = true
    elseif p1 == "leftShift" or p1 == "rightShift" then
      modifiers.shift = true
    elseif p1 == "escape" then
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
        initSelection()

        if modifiers.ctrl then
          if drawOffsets[2] > 0 then
            drawOffsets[2] = drawOffsets[2] - 1
          end
        else
          updateSelection()
          local nx, ny = cursorPos, cursorLine
          if cursorLine > 1 then ny = cursorLine - 1 else nx = 0 end
          if cursorPos > #content[ny] then nx = #content[ny] end
          updateCursor(nx, ny)
          updateSelection()
        end
        checkDrawBounds()
      elseif p1 == "down" then
        initSelection()

        if modifiers.ctrl then
          if drawOffsets[2] < #content - 1 then
            drawOffsets[2] = drawOffsets[2] + 1
          end
        else
          updateSelection()
          local nx, ny = cursorPos, cursorLine
          if cursorLine < #content then ny = cursorLine + 1 else nx = #content[ny] end
          if cursorPos > #content[ny] then nx = #content[ny] end
          updateCursor(nx, ny)
          updateSelection()
        end

        checkDrawBounds()
      elseif p1 == "left" then
        local nx, ny = cursorPos, cursorLine

        initSelection(true)

        if modifiers.ctrl then
          local charType = 0 -- 1 == Letter, 2 == Punctuation
          repeat
            local let = content[ny]:sub(nx, nx) or ""
            if charType == 0 then
              if let:match("%S") then
                if let:match("%w") then
                  charType = 1
                else
                  charType = 2
                end
              end
            end
            if nx > 0 then
              nx = nx - 1
            elseif ny > 1 then
              ny = ny - 1
              nx = #content[ny]
            end
          until (charType == 2 and let:match("[%w%s]"))
             or (charType == 1 and let:match("%W"))
             or nx == 0

          if nx ~= 0 then
            nx = nx + 1
          end
        else
          if cursorPos > 0 then
            nx = cursorPos - 1
          elseif ny > 1 then
            ny = ny - 1
            nx = #content[ny]
          end
        end

        updateCursor(nx, ny)
        updateSelection()

        checkDrawBounds()
      elseif p1 == "right" then
        local nx, ny = cursorPos, cursorLine

        initSelection()

        if modifiers.ctrl then
          local charType = 0 -- 1 == Letter, 2 == Punctuation
          repeat
            if nx < #content[ny] then
              nx = nx + 1
            elseif ny < #content then
              ny = ny + 1
              nx = 0
            end
            local let = content[ny]:sub(nx, nx) or ""
            if charType == 0 then
              if let:match("%S") then
                if let:match("%w") then
                  charType = 1
                else
                  charType = 2
                end
              end
            end
          until (charType == 2 and let:match("[%w%s]"))
             or (charType == 1 and let:match("%W"))
             or nx == #content[ny]

          if nx ~= #content[ny] then
            nx = nx - 1
          end
        else
          if cursorPos < #content[ny] then
            nx = cursorPos + 1
          elseif ny < #content then
            ny = ny + 1
            nx = 0
          end
        end

        updateCursor(nx, ny)
        updateSelection()

        checkDrawBounds()
      elseif p1 == "a" and modifiers.ctrl then
        updateCursor(#content[#content], #content)
        hasSelection = true
        selectionStart = {0, 1}
        selectionEnd = {#content[#content], #content}
      elseif p1 == "c" and modifiers.ctrl then
        if hasSelection then
          checkSelectionOrder()
          local clipboard = {}
          if selectionStart[2] == selectionEnd[2] then
            clipboard = {content[selectionStart[2]]:sub(selectionStart[1] + 1, selectionEnd[1] + 1)}
          else
            clipboard[1] = content[selectionStart[2]]:sub(selectionStart[1] + 1)
            for i = selectionStart[2] + 1, selectionEnd[2] - 1 do
              clipboard[#clipboard + 1] = content[i]
            end
            clipboard[#clipboard + 1] = content[selectionEnd[2]]:sub(1, selectionEnd[1] + 1)
          end

          fs.setClipboard(table.concat(clipboard, "\n"))
        end
      elseif p1 == "x" and modifiers.ctrl then
        if hasSelection then
          checkSelectionOrder()
          local clipboard = {}
          if selectionStart[2] == selectionEnd[2] then
            clipboard = {content[selectionStart[2]]:sub(selectionStart[1] + 1, selectionEnd[1] + 1)}
          else
            clipboard[1] = content[selectionStart[2]]:sub(selectionStart[1] + 1)
            for i = selectionStart[2] + 1, selectionEnd[2] - 1 do
              clipboard[#clipboard + 1] = content[i]
            end
            clipboard[#clipboard + 1] = content[selectionEnd[2]]:sub(1, selectionEnd[1] + 1)
          end

          fs.setClipboard(table.concat(clipboard, "\n"))

          removeSelection()
        end
      elseif p1 == "v" and modifiers.ctrl then
        local clipboardText = fs.getClipboard()
        if clipboardText then
          local clipboard = {}
          for line in clipboardText:gmatch("[^\n]+") do
            clipboard[#clipboard + 1] = line:gsub("\r", "")
          end

          if #clipboard == 1 then
            content[cursorLine] = content[cursorLine]:sub(1, cursorPos) .. clipboard[1] .. content[cursorLine]:sub(cursorPos + 1)
            updateCursor(cursorPos + #clipboard[1], cursorLine)
            colorizeLine(cursorLine)
          else
            local lastBit = content[cursorLine]:sub(cursorPos + 1)

            content[cursorLine] = content[cursorLine]:sub(1, cursorPos) .. clipboard[1]
            colorizeLine(cursorLine)

            for i = 2, #clipboard do
              tabInsert(content, cursorLine + i - 1, clipboard[i])
              tabInsert(colorizedLines, cursorLine + i - 1, {{clipboard[i], 1}})
              colorizeLine(cursorLine + i - 1)
            end

            updateCursor(#content[cursorLine + #clipboard - 1], cursorLine + #clipboard - 1)

            content[cursorLine] = content[cursorLine] .. lastBit
            colorizeLine(cursorLine)
          end
        end

        checkDrawBounds()
      elseif p1 == "backspace" then
        if hasSelection then
          removeSelection()
        else
          if modifiers.ctrl then
            local charType = 0 -- 1 == Letter, 2 == Punctuation
            repeat
              local let = content[cursorLine]:sub(cursorPos, cursorPos) or ""
              if charType == 0 then
                if let:match("%S") then
                  if let:match("%w") then
                    charType = 1
                  else
                    charType = 2
                  end
                end
              end

              if (charType == 2 and let:match("[%w%s]")) or (charType == 1 and let:match("%W")) then
                break
              end

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
            until (charType == 2 and let:match("[%w%s]"))
               or (charType == 1 and let:match("%W"))
               or cursorPos == 0
          else
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
          end
        end

        checkDrawBounds()
        blinkTimeCorrection = os.clock()
      elseif p1 == "delete" then
        if hasSelection then
          removeSelection()
        else
          if cursorPos < #content[cursorLine] then
            content[cursorLine] = content[cursorLine]:sub(1, cursorPos) .. content[cursorLine]:sub(cursorPos + 2)
            colorizeLine(cursorLine)
          elseif cursorLine < #content then
            content[cursorLine] = content[cursorLine] .. tabRemove(content, cursorLine + 1)
            tabRemove(colorizedLines, cursorLine + 1)
            colorizeLine(cursorLine)
          end
        end
        blinkTimeCorrection = os.clock()
      elseif p1 == "return" then
        if hasSelection then
          removeSelection()
        end

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
        initSelection()

        updateCursor(cursorPos - 1, cursorLine)
        updateSelection()

        local fpos, _ = content[cursorLine]:find("%S")
        if not fpos or cursorPos < fpos then
          updateCursor(0, cursorLine)
        else
          updateCursor(fpos - 1, cursorLine)
        end
        updateSelection()

        checkDrawBounds()
      elseif p1 == "end" then
        initSelection()

        updateSelection()

        updateCursor(#content[cursorLine], cursorLine)
        updateSelection()

        checkDrawBounds()
      elseif p1 == "tab" then
        if hasSelection then
          checkSelectionOrder()

          if modifiers.shift then
            for i = selectionStart[2], selectionEnd[2] do
              content[i] = content[i]:match("%s?%s?(.+)")
              colorizeLine(i)
            end
          else
            for i = selectionStart[2], selectionEnd[2] do
              content[i] = "  " .. content[i]
              colorizeLine(i)
            end
          end
        else
          if modifiers.shift then
            content[cursorLine] = content[cursorLine]:match("%s?%s?(.+)")
            updateCursor(cursorPos - 2, cursorLine)
            colorizeLine(cursorLine)
          else
            content[cursorLine] = content[cursorLine]:sub(1, cursorPos) .. "  " .. content[cursorLine]:sub(cursorPos + 1)
            updateCursor(cursorPos + 2, cursorLine)
            colorizeLine(cursorLine)
          end
        end
      elseif p1 == "pageDown" then
        checkDrawBounds()
        local y = -(gpu.height / (fnt.h + 1) - 1)
        local opos = cursorPos
        for _=1, math.abs(y) do
          if drawOffsets[2] < #content - 1 then
            drawOffsets[2] = drawOffsets[2] + 1
            updateCursor(opos, cursorLine + 1)
          end
        end
      elseif p1 == "pageUp" then
        checkDrawBounds()
        local y = gpu.height / (fnt.h + 1) - 1
        local opos = cursorPos
        for _=1, math.abs(y) do
          if drawOffsets[2] > 0 then
            drawOffsets[2] = drawOffsets[2] - 1
            updateCursor(opos, cursorLine - 1)
          end
        end
      end
    end
  elseif e == "keyUp" then
    if p1 == "leftCtrl" or p1 == "rightCtrl" then
      modifiers.ctrl = false
    elseif p1 == "leftShift" or p1 == "rightShift" then
      modifiers.shift = false
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
    mposx, mposy = p1, p2
    hasSelection = false
    local x, y = p1, p2
    local posX = math.floor((x - 2) / (fnt.w + 1)) - drawOffsets[1]
    local posY = math.floor((y - 2) / (fnt.h + 1)) + drawOffsets[2] + 1
    posY = posY < 1 and 1 or (posY > #content and #content or posY)
    posX = posX < 0 and 0 or (posX > #content[posY] and #content[posY] or posX)
    updateCursor(posX, posY)
    checkDrawBounds()
    if mouseDown then
      hasSelection = true
      updateSelection(true)
    else
      selectionStart = {posX, posY}
    end

    mouseDown = true
  elseif e == "mouseMoved" then
    mposx, mposy = p1, p2
  elseif e == "mouseReleased" then
    mouseDown = false
  elseif e == "char" then
    if hasSelection then
      removeSelection()
    end

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

gpu.font = oldFont
