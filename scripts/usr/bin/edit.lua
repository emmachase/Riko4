--HELP: \b6Usage: \b16edit \b7<\b16file\b7> \n
-- \b6Description: \b7Opens \b16file \b7in a code editor

local args = {...}
if #args < 1 then
  if shell then
    print("Syntax: edit <file> [line]\n", 9)
    return
  else
    error("Syntax: edit <file> [line]", 2)
  end
end

local running = true

local myPath = fs.getLastFile()
local workingDir = myPath:match(".+%/") .. "edit/"
addRequirePath(workingDir)

local editorTheme = {
  bg = 1,         -- black
  text = 16,      -- white
  selBar = 2,     -- dark blue
  selChar = 10,   -- yellow
  highlight = 3,  -- maroon
  scrollBar = 7,  -- light gray
  lineNumbers = 7 -- light gray
}
local syntaxTheme = {
  keyword = 13,        -- purple
  specialKeyword = 12, -- light blue
  func = 12,           -- light blue
  string = 8,          -- red
  stringEscape = 10,   -- orange
  primitive = 9,       -- orange also
  comment = 6,         -- dark gray
  catch = 16           -- everything else is white
}

local context = require("context").new()

context:set("mediator", context:get("mediator")())
local rif = require("rif")

local mposx, mposy = -5, -5

local cur, ibar
cur = rif.createImage(workingDir .. "curs.rif")
ibar = rif.createImage(workingDir .. "ibar.rif")


local filename = args[1]
if not fs.exists(filename) then
  if fs.exists(filename .. ".lua") then
    filename = filename .. ".lua"
  elseif fs.exists(filename .. ".rlua") then
    filename = filename .. ".rlua"
  end
end

local eventPriorityQueue
local insertionQueue = {}

local editor = context:get "editor"
editor.init({
  editorTheme = editorTheme,
  syntaxTheme = syntaxTheme,
  viewportWidth = gpu.width,
  viewportHeight = gpu.height - 10,
  initialLine = tonumber(args[2])
})

local menu = context:get "menu"
menu.init({
  editorTheme = editorTheme,
  filename = filename,
  quitFunc = function()
    running = false
  end,
  attacher = function(obj)
    insertionQueue[#insertionQueue + 1] = obj
  end,
  detacher = function(obj)
    for i = 1, #eventPriorityQueue do
      if eventPriorityQueue[i] == obj then
        table.remove(eventPriorityQueue, i)
        break
      end
    end
  end
})

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

do
  local content = {}
  if fs.exists(filename) then
    for line in fsLines(filename) do
      if line then
        content[#content + 1] = line
      end
    end
  end

  if #content == 0 then
    content[#content + 1] = ""
  end

  editor.setText(content)
end

local eventModifiers = {
  key = {
    ctrl = false,
    shift = false,
    alt = false
  }
}


eventPriorityQueue = {
  editor,
  menu
}

local function drawContent()
  gpu.clear(editorTheme.bg)

  editor.draw()
  menu.draw()

  local cursorName = "default"
  for i = 1, #eventPriorityQueue do
    local eventTarget = eventPriorityQueue[i]
    if eventTarget.assignMouseIcon then
      cursorName = eventTarget.assignMouseIcon(mposx, mposy) or cursorName
    end
  end

  if cursorName == "default" then
    cur:render(mposx, mposy)
  elseif cursorName == "ibar" then
    ibar:render(mposx, mposy - 4)
  end
end

local function update(dt)
  menu.update(dt)
end

local function capitalize(str)
  return str:sub(1, 1):upper() .. str:sub(2)
end

local function processEvent(e, p1, p2)
  if e == "key" then
    if p1 == "leftCtrl" or p1 == "rightCtrl" then
      eventModifiers.key.ctrl = true
    elseif p1 == "leftShift" or p1 == "rightShift" then
      eventModifiers.key.shift = true
    elseif p1 == "leftAlt" or p1 == "rightAlt" then
      eventModifiers.key.alt = true
    end
  elseif e == "keyUp" then
    if p1 == "leftCtrl" or p1 == "rightCtrl" then
      eventModifiers.key.ctrl = false
    elseif p1 == "leftShift" or p1 == "rightShift" then
      eventModifiers.key.shift = false
    elseif p1 == "leftAlt" or p1 == "rightAlt" then
      eventModifiers.key.alt = false
    end
  end

  local propName = "on" .. capitalize(e)
  for i = 1, #eventPriorityQueue do
    local eventTarget = eventPriorityQueue[i]
    if eventTarget[propName] then
      local capture, promote = eventTarget[propName](eventTarget, eventModifiers or {}, p1, p2)

      if promote ~= nil then
        table.remove(eventPriorityQueue, i)
        if promote then
          table.insert(eventPriorityQueue, 1, eventTarget)
        else
          local newIndex = i + 1
          newIndex = (newIndex - 1 > #eventPriorityQueue) and newIndex - 1 or newIndex
          table.insert(eventPriorityQueue, newIndex, eventTarget)
        end

        break
      end

      if capture then
        break
      end
    end
  end

  for i = #insertionQueue, 1, -1 do
    table.insert(eventPriorityQueue, 1, insertionQueue[i])
    insertionQueue[i] = nil
  end

  if e == "mouseMoved" then
    mposx, mposy = p1, p2
  end
end

local eventQueue = {}

local lastTime = os.clock()
drawContent()
while running do
  while true do
    local e, p1, p2 = coroutine.yield()
    if not e then break end
    table.insert(eventQueue, {e, p1, p2})
  end

  while #eventQueue > 0 do
    processEvent(unpack(eventQueue[1]))
    table.remove(eventQueue, 1)
  end

  if not running then break end

  update(os.clock() - lastTime)
  lastTime = os.clock()

  gpu.clear()

  drawContent()

  gpu.swap()
end
