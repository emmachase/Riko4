local menu = {}

local fontW = gpu.font.data.w
-- local fontH = gpu.font.data.h

local viewportWidth = gpu.width
local viewportHeight = gpu.height


local editor = require("editor.lua")
local editorTheme
local quitFunc
local filename


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

local inMenu = false
local menuItems = { "Save", "Goto", "Exit" }
local menuFunctions = {
  function() -- SAVE
    editor.trimLines()
    editor.updateCursor(editor.getCursorPosition())

    local handle = fs.open(filename, "w")
    handle:write(ccat(editor.getText(), "\n"))
    handle:close()
  end,
  function() -- GOTO
    -- TODO
  end,
  function() -- EXIT
    quitFunc()
  end
}
local menuSelected = 1

local hintText = "Press <esc> to open menu"

local braceX = 2
local braceXGoal = 2
local braceWidth = (#menuItems[menuSelected] + 1)*(fontW + 1)
local braceWidthGoal = (#menuItems[menuSelected] + 1)*(fontW + 1)

local function updateHint()
  if inMenu then
    local hWidth = 0
    for i=1, #menuItems do
      if i == menuSelected then
        break
      end
      hWidth = hWidth + #menuItems[i] + 2
    end
    braceXGoal = 2 + hWidth * (fontW + 1)
    braceWidthGoal = (#menuItems[menuSelected] + 1) * (fontW + 1)

    hintText = " " .. table.concat(menuItems, "  ")
  else
    hintText = "Press <esc> to open menu"
  end
end


function menu.init(args)
  editorTheme = args.editorTheme
  quitFunc = args.quitFunc
  filename = args.filename
end

local lastI = os.clock()
function menu.draw()
  gpu.drawRectangle(0, viewportHeight - 10, viewportWidth, 11, editorTheme.selBar)

  local delta = os.clock() - lastI

  braceX = braceX + (braceXGoal - braceX)*10*delta
  if math.abs(braceXGoal - braceX) < 0.1 then braceX = braceXGoal end

  braceWidth = braceWidth + (braceWidthGoal - braceWidth)*10*delta
  if math.abs(braceWidthGoal - braceWidth) < 0.1 then braceWidth = braceWidthGoal end

  write(hintText, 2, viewportHeight - 9, editorTheme.text)

  if inMenu then
    write("[", braceX, viewportHeight - 9, editorTheme.selChar)
    write("]", braceX + braceWidth, viewportHeight - 9, editorTheme.selChar)
  end

  local cursorPos, cursorLine = editor.getCursorPosition()
  local locStr = "Ln "..cursorLine..", Col "..(cursorPos + 1)
  write(locStr, (viewportWidth - 5) - (#locStr * (fontW + 1)), viewportHeight - 9, editorTheme.text)

  lastI = os.clock()
end

function menu.onKey(modifiers, key)
  if key == "escape" then
    inMenu = not inMenu
    updateHint()

    return true, true
  elseif inMenu then
    if key == "left" then
      menuSelected = menuSelected == 1 and #menuItems or menuSelected - 1
      updateHint()
    elseif key == "right" then
      menuSelected = menuSelected == #menuItems and 1 or menuSelected + 1
      updateHint()
    elseif key == "return" then
      menuFunctions[menuSelected]()
      inMenu = false
      updateHint()

      return true, false
    end

    return true, true
  end
end

return menu