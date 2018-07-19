local editor = {}

local tableInsert = table.insert
local tableRemove = table.remove


local highlighter = require("highlighter.lua")

local editorTheme

local fontW = gpu.font.data.w
local fontH = gpu.font.data.h

local viewportWidth
local viewportHeight
local heightInLines

-- In the form of an array of lines
local editorContent = {}
local colorizedLines = {}

local cursorBlinkTimer = os.clock()
local cursorLine = 1
local cursorPos = 0

local mouseDown, scrolling = false, false
local scrollX, scrollY = 0, 0

local selection = {
  active = false,
  start = {1, 1}, -- {cursorPos, cursorLine}
  stop = {1, 1}   -- {cursorPos, cursorLine}
}

-- Resorts selection if necessary
local function checkSelectionOrder()
  local ss1, ss2 = selection.start[1], selection.start[2]
  local se1, se2 = selection.stop[1], selection.stop[2]

  if ss2 > se2 then
    selection.start = {se1, se2}
    selection.stop = {ss1, ss2}
  elseif ss2 == se2 and ss1 > se1 then
    selection.start[1] = se1
    selection.stop[1] = ss1
  end
end

-- Returns selection beginnings and ends
-- Automatically sorts based on which piece is actually first in the file
-- Returns (beginCharacterPos, beginLine,
--          endCharacterPos,   endLine)
local function getSortedSelection()
  local ss1, ss2 = selection.start[1], selection.start[2]
  local se1, se2 = selection.stop[1],  selection.stop[2]

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

  return ss1, ss2,
         se1, se2
end

-- Make sure that the editor cursor position is within the viewport
local function checkDrawBounds()
  if cursorPos > math.floor(viewportWidth/(fontW + 1)) - scrollX - 1 then
    scrollX = math.floor(viewportWidth/(fontW + 1)) - cursorPos - 1
  elseif cursorPos < -scrollX then
    scrollX = -cursorPos
  end

  if cursorLine > heightInLines + scrollY then
    scrollY = cursorLine - heightInLines
  elseif cursorLine < scrollY + 1 then
    scrollY = cursorLine - 1
  end
end

local function drawCursor(force, which)
  local ctime = math.floor(((os.clock() - cursorBlinkTimer) * 2)) % 2

  if ((ctime == 0 or force)) or which == 1 then
    write("_", (cursorPos + scrollX) * (fontW + 1) + 1, (cursorLine - scrollY - 1) * (fontH + 1) + 4, editorTheme.text)
  end
end

-- Move cursor to new position
local function updateCursor(newPos, newLine)
  drawCursor(true, 2)
  if newLine > #editorContent then
    cursorLine = #editorContent
  else
    cursorLine = newLine
  end

  if newPos > #editorContent[cursorLine] then
    cursorPos = #editorContent[cursorLine]
  else
    cursorPos = newPos
  end
  cursorBlinkTimer = os.clock()
  drawCursor(true, 1)
end

-- Check if we should start selecting, and if so begin the selection
local function initSelection(modifiers, left)
  if not selection.active and modifiers.shift then
    local offset = left and -1 or 0
    selection.active = true
    selection.start = {cursorPos + offset, cursorLine}
    selection.stop  = {cursorPos + offset, cursorLine}
  end
end

-- Update the selection beginning and end to new cursor position
-- Also terminate selection capturing if required modifiers are no longer present
local function updateSelection(modifiers, mouse)
  if modifiers.shift or mouse then
    if (cursorLine == selection.start[2] and cursorPos <= selection.start[1]) or cursorLine < selection.start[2] then
      selection.stop = {cursorPos, cursorLine}
    else
      selection.stop = {cursorPos - 1, cursorLine}
    end
  else
    selection.active = false
  end
end

-- Delete the content in a selection and move the cursor appropriately
local function removeSelection()
  if selection.active then
    checkSelectionOrder()

    if selection.start[2] == selection.stop[2] then
      editorContent[selection.start[2]] = editorContent[selection.start[2]]:sub(1, selection.start[1]) .. editorContent[selection.start[2]]:sub(selection.stop[1] + 2)
      colorizedLines[selection.start[2]] = highlighter.colorizeLine(editorContent[selection.start[2]])
    else

      for _ = selection.start[2] + 1, selection.stop[2] - 1 do
        tableRemove(editorContent, selection.start[2] + 1)
        tableRemove(colorizedLines, selection.start[2] + 1)
      end

      editorContent[selection.start[2]] = editorContent[selection.start[2]]:sub(1, selection.start[1])
      editorContent[selection.start[2] + 1] = editorContent[selection.start[2] + 1]:sub(selection.stop[1] + 2)

      editorContent[selection.start[2]] = editorContent[selection.start[2]] .. editorContent[selection.start[2] + 1]
      colorizedLines[selection.start[2]] = highlighter.colorizeLine(editorContent[selection.start[2]])

      tableRemove(editorContent, selection.start[2] + 1)
      tableRemove(colorizedLines, selection.start[2] + 1)
    end

    selection.active = false
    updateCursor(selection.start[1], selection.start[2])
  end
end



function editor.init(args)
  editorTheme = args.editorTheme
  highlighter.init({
    syntaxTheme = args.syntaxTheme
  })

  viewportWidth = args.viewportWidth
  viewportHeight = args.viewportHeight

  heightInLines = math.floor(viewportHeight / (fontH + 1)) - 1

  cursorLine = args.initialLine or 1
  checkDrawBounds()
end

-- newLines: An array of lines to be set as the new data
function editor.setText(newLines)
  editorContent = newLines
end

function editor.getText()
  return editorContent
end

function editor.trimLines()
  for i = 1, #editorContent do
    editorContent[i] = editorContent[i]:gsub("%s+$", "")
  end
end

function editor.getCursorPosition()
  return cursorPos, cursorLine
end

editor.updateCursor = updateCursor

function editor.draw()
  for i = 0, heightInLines + 2 do
    local cy = i + scrollY
    if cy > 0 then
      local dy = (i - 1) * (fontH + 1) + 2
      if not editorContent[cy] then
        break
      end

      if not colorizedLines[cy] then
        colorizedLines[cy] = highlighter.colorizeLine(editorContent[cy])
      end

      local hScrl = scrollX*(fontW + 1)

      if selection.active then
        local selBeginPos, selBeginLine,
              selStopPos,  selStopLine = getSortedSelection()

        if selBeginLine == selStopLine then
          if cy == selBeginLine then
            if selStopPos == #editorContent[cy] then
              gpu.drawRectangle((fontW + 1) * (selBeginPos) + 1 + hScrl, dy, (fontW + 1) * (#editorContent[cy] - selBeginPos) + 1, 7, editorTheme.highlight)
            else
              gpu.drawRectangle((fontW + 1) * (selBeginPos) + 1 + hScrl, dy, (fontW + 1) * (selStopPos - selBeginPos + 1) + 1, 7, editorTheme.highlight)
            end
          end
        else
          if cy == selBeginLine then
            gpu.drawRectangle((fontW + 1) * (selBeginPos) + 1 + hScrl, dy, (fontW + 1) * (#editorContent[cy] - selBeginPos) + 1, 7, editorTheme.highlight)
          elseif cy == selStopLine then
            if selStopPos == #editorContent[cy] then
              gpu.drawRectangle(hScrl, dy, (fontW + 1) * #editorContent[cy] + 2, 7, editorTheme.highlight)
            else
              gpu.drawRectangle(hScrl, dy, (fontW + 1) * (selStopPos + 1) + 2, 7, editorTheme.highlight)
            end
          elseif cy > selBeginLine and cy < selStopLine then
            gpu.drawRectangle(hScrl, dy, (fontW + 1) * #editorContent[cy] + 2, 7, editorTheme.highlight)
          end
        end
      end


      local cx = 1 + scrollX*(fontW + 1)
      for j = 1, #colorizedLines[cy] do
        local chk = colorizedLines[cy][j]
        write(chk[1], cx, dy, chk[2])
        cx = cx + (fontW + 1) * #chk[1]
      end
    end
  end

  local vph = gpu.height - 12
  local barSize = vph * vph / ((#editorContent + heightInLines) * (fontH + 1) + 2)
  local barPos = vph * scrollY / (#editorContent + heightInLines) + 1

  barSize = barSize < 10 and 10 or (barSize >= vph and vph - 1 or barSize)
  barPos = barPos > (vph - barSize) and (vph - barSize) or barPos

  barSize = math.floor(barSize)
  barPos = math.floor(barPos)

  do
    gpu.drawRectangle(viewportWidth - 6, barPos,               5,       1, editorTheme.scrollBar)
    gpu.drawRectangle(viewportWidth - 6, barPos,               1, barSize, editorTheme.scrollBar)
    gpu.drawRectangle(viewportWidth - 2, barPos,               1, barSize, editorTheme.scrollBar)
    gpu.drawRectangle(viewportWidth - 6, barPos + barSize - 1, 5,       1, editorTheme.scrollBar)
  end

  drawCursor()
end

function editor.assignMouseIcon(x, y)
  if y <= viewportHeight and x <= viewportWidth - 7 and not scrolling then
    return "ibar"
  end
end

local function onArrowKeys(modifiers, key)
  if key == "up" then
    initSelection(modifiers)

    if modifiers.ctrl then
      if scrollY > 0 then
        scrollY = scrollY - 1
      end
    else
      updateSelection(modifiers)
      local nx, ny = cursorPos, cursorLine
      if cursorLine > 1 then ny = cursorLine - 1 else nx = 0 end
      if cursorPos > #editorContent[ny] then nx = #editorContent[ny] end
      updateCursor(nx, ny)
      updateSelection(modifiers)
    end
    checkDrawBounds()
  elseif key == "down" then
    initSelection(modifiers)

    if modifiers.ctrl then
      if scrollY < #editorContent - 1 then
        scrollY = scrollY + 1
      end
    else
      updateSelection(modifiers)
      local nx, ny = cursorPos, cursorLine
      if cursorLine < #editorContent then ny = cursorLine + 1 else nx = #editorContent[ny] end
      if cursorPos > #editorContent[ny] then nx = #editorContent[ny] end
      updateCursor(nx, ny)
      updateSelection(modifiers)
    end

    checkDrawBounds()
  elseif key == "left" then
    local nx, ny = cursorPos, cursorLine

    initSelection(modifiers, true)

    if modifiers.ctrl then
      local charType = 0 -- 1 == Letter, 2 == Punctuation
      repeat
        local let = editorContent[ny]:sub(nx, nx) or ""
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
          nx = #editorContent[ny]
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
        nx = #editorContent[ny]
      end
    end

    updateCursor(nx, ny)
    updateSelection(modifiers)

    checkDrawBounds()
  elseif key == "right" then
    local nx, ny = cursorPos, cursorLine

    initSelection(modifiers)

    if modifiers.ctrl then
      local charType = 0 -- 1 == Letter, 2 == Punctuation
      repeat
        if nx < #editorContent[ny] then
          nx = nx + 1
        elseif ny < #editorContent then
          ny = ny + 1
          nx = 0
        end
        local let = editorContent[ny]:sub(nx, nx) or ""
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
          or nx == #editorContent[ny]

      if nx ~= #editorContent[ny] then
        nx = nx - 1
      end
    else
      if cursorPos < #editorContent[ny] then
        nx = cursorPos + 1
      elseif ny < #editorContent then
        ny = ny + 1
        nx = 0
      end
    end

    updateCursor(nx, ny)
    updateSelection(modifiers)

    checkDrawBounds()
  end
end

local function onShortcuts(modifiers, key)
  if key == "a" and modifiers.ctrl then
    updateCursor(#editorContent[#editorContent], #editorContent)
    selection.active = true
    selection.start = {0, 1}
    selection.stop = {#editorContent[#editorContent], #editorContent}
  elseif key == "c" and modifiers.ctrl then
    if selection.active then
      checkSelectionOrder()
      local clipboard = {}
      if selection.start[2] == selection.stop[2] then
        clipboard = {editorContent[selection.start[2]]:sub(selection.start[1] + 1, selection.stop[1] + 1)}
      else
        clipboard[1] = editorContent[selection.start[2]]:sub(selection.start[1] + 1)
        for i = selection.start[2] + 1, selection.stop[2] - 1 do
          clipboard[#clipboard + 1] = editorContent[i]
        end
        clipboard[#clipboard + 1] = editorContent[selection.stop[2]]:sub(1, selection.stop[1] + 1)
      end

      fs.setClipboard(table.concat(clipboard, "\n"))
    end
  elseif key == "x" and modifiers.ctrl then
    if selection.active then
      checkSelectionOrder()
      local clipboard = {}
      if selection.start[2] == selection.stop[2] then
        clipboard = {editorContent[selection.start[2]]:sub(selection.start[1] + 1, selection.stop[1] + 1)}
      else
        clipboard[1] = editorContent[selection.start[2]]:sub(selection.start[1] + 1)
        for i = selection.start[2] + 1, selection.stop[2] - 1 do
          clipboard[#clipboard + 1] = editorContent[i]
        end
        clipboard[#clipboard + 1] = editorContent[selection.stop[2]]:sub(1, selection.stop[1] + 1)
      end

      fs.setClipboard(table.concat(clipboard, "\n"))

      removeSelection()
    end
  elseif key == "v" and modifiers.ctrl then
    local clipboardText = fs.getClipboard()
    if clipboardText then
      if selection.active then
        removeSelection()
      end

      local clipboard = {}
      for line in clipboardText:gmatch("[^\n]+") do
        clipboard[#clipboard + 1] = line:gsub("\r", "")
      end

      if #clipboard == 1 then
        editorContent[cursorLine] = editorContent[cursorLine]:sub(1, cursorPos) .. clipboard[1] .. editorContent[cursorLine]:sub(cursorPos + 1)
        updateCursor(cursorPos + #clipboard[1], cursorLine)
        colorizedLines[cursorLine] = highlighter.colorizeLine(editorContent[cursorLine])
      else
        local lastBit = editorContent[cursorLine]:sub(cursorPos + 1)

        editorContent[cursorLine] = editorContent[cursorLine]:sub(1, cursorPos) .. clipboard[1]
        colorizedLines[cursorLine] = highlighter.colorizeLine(editorContent[cursorLine])

        for i = 2, #clipboard do
          tableInsert(editorContent, cursorLine + i - 1, clipboard[i])
          tableInsert(colorizedLines, cursorLine + i - 1, {{clipboard[i], 1}})
          colorizedLines[cursorLine + i - 1] = highlighter.colorizeLine(editorContent[cursorLine + i - 1])
        end

        updateCursor(#editorContent[cursorLine + #clipboard - 1], cursorLine + #clipboard - 1)

        editorContent[cursorLine] = editorContent[cursorLine] .. lastBit
        colorizedLines[cursorLine] = highlighter.colorizeLine(editorContent[cursorLine])
      end
    end

    checkDrawBounds()
  end
end

local function onMiscNavigation(modifiers, key)
  if key == "home" then
    initSelection(modifiers)

    updateCursor(cursorPos - 1, cursorLine)
    updateSelection(modifiers)

    local fpos, _ = editorContent[cursorLine]:find("%S")
    if not fpos or cursorPos < fpos then
      updateCursor(0, cursorLine)
    else
      updateCursor(fpos - 1, cursorLine)
    end
    updateSelection(modifiers)

    checkDrawBounds()
  elseif key == "end" then
    initSelection(modifiers)

    updateSelection(modifiers)

    updateCursor(#editorContent[cursorLine], cursorLine)
    updateSelection(modifiers)

    checkDrawBounds()
  elseif key == "pageDown" then
    initSelection(modifiers)

    updateSelection(modifiers)

    checkDrawBounds()
    local y = -(viewportHeight / (fontH + 1) - 1)
    local opos = cursorPos
    for _=1, math.abs(y) do
      if scrollY < #editorContent - 1 then
        scrollY = scrollY + 1
        updateCursor(opos, cursorLine + 1)
      end
    end

    updateSelection(modifiers)
  elseif key == "pageUp" then
    initSelection(modifiers)

    updateSelection(modifiers)

    checkDrawBounds()
    local y = viewportHeight / (fontH + 1) - 1
    local opos = cursorPos
    for _=1, math.abs(y) do
      if scrollY > 0 then
        scrollY = scrollY - 1
        updateCursor(opos, cursorLine - 1)
      end
    end

    updateSelection(modifiers)
  end
end

local function onMutateKeys(modifiers, key)
  if key == "backspace" then
    if selection.active then
      removeSelection()
    else
      if modifiers.ctrl then
        local charType = 0 -- 1 == Letter, 2 == Punctuation
        repeat
          local let = editorContent[cursorLine]:sub(cursorPos, cursorPos) or ""
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
            editorContent[cursorLine] = editorContent[cursorLine]:sub(1, cursorPos - 1) .. editorContent[cursorLine]:sub(cursorPos + 1)
            updateCursor(cursorPos - 1, cursorLine)
            colorizedLines[cursorLine] = highlighter.colorizeLine(editorContent[cursorLine])
          elseif cursorLine > 1 then
            local ox = #editorContent[cursorLine - 1]
            editorContent[cursorLine - 1] = editorContent[cursorLine - 1] .. tableRemove(editorContent, cursorLine)
            tableRemove(colorizedLines, cursorLine)
            updateCursor(ox, cursorLine - 1)
            colorizedLines[cursorLine] = highlighter.colorizeLine(editorContent[cursorLine])
          end
        until (charType == 2 and let:match("[%w%s]"))
            or (charType == 1 and let:match("%W"))
            or cursorPos == 0
      else
        if cursorPos > 0 then
          editorContent[cursorLine] = editorContent[cursorLine]:sub(1, cursorPos - 1) .. editorContent[cursorLine]:sub(cursorPos + 1)
          updateCursor(cursorPos - 1, cursorLine)
          colorizedLines[cursorLine] = highlighter.colorizeLine(editorContent[cursorLine])
        elseif cursorLine > 1 then
          local ox = #editorContent[cursorLine - 1]
          editorContent[cursorLine - 1] = editorContent[cursorLine - 1] .. tableRemove(editorContent, cursorLine)
          tableRemove(colorizedLines, cursorLine)
          updateCursor(ox, cursorLine - 1)
          colorizedLines[cursorLine] = highlighter.colorizeLine(editorContent[cursorLine])
        end
      end
    end

    checkDrawBounds()
    cursorBlinkTimer = os.clock()
  elseif key == "delete" then
    if selection.active then
      removeSelection()
    else
      if cursorPos < #editorContent[cursorLine] then
        editorContent[cursorLine] = editorContent[cursorLine]:sub(1, cursorPos) .. editorContent[cursorLine]:sub(cursorPos + 2)
        colorizedLines[cursorLine] = highlighter.colorizeLine(editorContent[cursorLine])
      elseif cursorLine < #editorContent then
        editorContent[cursorLine] = editorContent[cursorLine] .. tableRemove(editorContent, cursorLine + 1)
        tableRemove(colorizedLines, cursorLine + 1)
        colorizedLines[cursorLine] = highlighter.colorizeLine(editorContent[cursorLine])
      end
    end
    cursorBlinkTimer = os.clock()
  elseif key == "return" then
    if selection.active then
      removeSelection()
    end

    local cont = editorContent[cursorLine]:sub(cursorPos + 1)
    local localIndent = editorContent[cursorLine]:find("%S")
    localIndent = localIndent and localIndent - 1 or #editorContent[cursorLine]
    editorContent[cursorLine] = editorContent[cursorLine]:sub(1, cursorPos)
    tableInsert(editorContent, cursorLine + 1, (" "):rep(localIndent)..cont)
    tableInsert(colorizedLines, cursorLine + 1, {{cont, 1}})
    updateCursor(localIndent, cursorLine + 1)
    colorizedLines[cursorLine - 1] = highlighter.colorizeLine(editorContent[cursorLine - 1])
    colorizedLines[cursorLine] = highlighter.colorizeLine(editorContent[cursorLine])
    checkDrawBounds()
  elseif key == "tab" then
    if selection.active then
      checkSelectionOrder()

      if modifiers.shift then
        for i = selection.start[2], selection.stop[2] do
          editorContent[i] = editorContent[i]:match("%s?%s?(.+)")
          colorizedLines[i] = highlighter.colorizeLine(editorContent[i])
        end
      else
        for i = selection.start[2], selection.stop[2] do
          editorContent[i] = "  " .. editorContent[i]
          colorizedLines[i] = highlighter.colorizeLine(editorContent[i])
        end
      end
    else
      if modifiers.shift then
        editorContent[cursorLine] = editorContent[cursorLine]:match("%s?%s?(.+)")
        updateCursor(cursorPos - 2, cursorLine)
        colorizedLines[cursorLine] = highlighter.colorizeLine(editorContent[cursorLine])
      else
        editorContent[cursorLine] = editorContent[cursorLine]:sub(1, cursorPos) .. "  " .. editorContent[cursorLine]:sub(cursorPos + 1)
        updateCursor(cursorPos + 2, cursorLine)
        colorizedLines[cursorLine] = highlighter.colorizeLine(editorContent[cursorLine])
      end
    end
  end
end

local function handleMouse(modifiers, x, y)
  if x < viewportWidth - 6 and not scrolling then
    selection.active = false
    local posX = math.floor((x - 2) / (fontW + 1)) - scrollX
    local posY = math.floor((y - 2) / (fontH + 1)) + scrollY + 1
    posY = posY < 1 and 1 or (posY > #editorContent and #editorContent or posY)
    posX = posX < 0 and 0 or (posX > #editorContent[posY] and #editorContent[posY] or posX)
    updateCursor(posX, posY)
    checkDrawBounds()
    if mouseDown then
      selection.active = true
      updateSelection(modifiers, true)
    else
      selection.start = {posX, posY}
    end
  else
    -- Scrollbar
    if y < viewportHeight then
      local vph = gpu.height - 12
      local barSize = vph * vph / ((#editorContent + heightInLines) * (fontH + 1) + 2)
      barSize = barSize < 10 and 10 or (barSize >= vph and vph - 1 or barSize)
      barSize = math.floor(barSize)

      local wouldBeBarPos = y - barSize / 2 + 1
      local newDrawOffset = math.floor((wouldBeBarPos - 1) * (#editorContent + heightInLines) / vph)

      scrollY = newDrawOffset

      if scrollY < 0 then
        scrollY = 0
      end

      if scrollY > #editorContent - 1 then
        scrollY = #editorContent - 1
      end

      scrolling = true
    end
  end

  mouseDown = true
end

function editor.onKey(modifiers, key)
  onArrowKeys(modifiers, key)
  onShortcuts(modifiers, key)
  onMiscNavigation(modifiers, key)
  onMutateKeys(modifiers, key)
end

function editor.onChar(modifiers, char)
  if selection.active then
    removeSelection()
  end

  editorContent[cursorLine] = editorContent[cursorLine]:sub(1, cursorPos) .. char .. editorContent[cursorLine]:sub(cursorPos + 1)
  updateCursor(cursorPos + 1, cursorLine)
  colorizedLines[cursorLine] = highlighter.colorizeLine(editorContent[cursorLine])
  checkDrawBounds()
end

function editor.onMouseWheel(modifiers, direction)
  for _ = 1, math.abs(direction) do
    if direction > 0 then
      if scrollY > 0 then
        scrollY = scrollY - 1
      end
    else
      if scrollY < #editorContent - 1 then
        scrollY = scrollY + 1
      end
    end
  end
end

function editor.onMousePressed(modifiers, x, y)
  handleMouse(modifiers, x, y)
end

function editor.onMouseReleased(modifiers, x, y)
  mouseDown = false
  scrolling = false
end

function editor.onMouseMoved(modifiers, x, y)
  if mouseDown then
    handleMouse(modifiers, x, y)
  end
end

return editor
