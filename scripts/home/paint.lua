local args = {...}
local filename = args[1]

local rif = dofile("../lib/rif.lua")

local theme = {
  text = 16,
  selBar = 2,
  selChar = 10
}

local x, y = 0, 0

local zoom = 10

local color = 5

local down = -1
local pdown = false

local image = {}
for i=1, 340 do
  image[i] = {}
  for j=1, 200 do
    image[i][j] = 1
  end
end

local biggestX = 0
local biggestY = 0

local function big(xp, yp)
  if xp > biggestX then biggestX = xp end
  if yp > biggestY then biggestY = yp end
end

local running = true

local function toRIF()
  return rif.encode(image, biggestX, biggestY)
end

local inMenu, menuItems, menuFunctions, menuSelected
local hintText = "Press <ctrl> to open menu"
local lastI = os.clock()
if filename then
  inMenu = false
  menuItems = { "Save", "Exit" }
  menuFunctions = {
    function() -- SAVE
      local handle = io.open(filename, "w")
      handle:write(toRIF(), "\n")
      handle:close()
    end,
    function() -- EXIT
      running = false
    end,
  }
  menuSelected = 1
else
  inMenu = false
  menuItems = { "Exit" }
  menuFunctions = {
    function() -- EXIT
      running = false
    end,
  }
  menuSelected = 1
end

local braceX = 2
local braceXGoal = 2
local braceWidth = (#menuItems[menuSelected] + 1)*7
local braceWidthGoal = (#menuItems[menuSelected] + 1)*7

local function draw()
  gpu.clear()

  for i=1, math.ceil(340 / zoom) do
    for j=1, math.ceil(200 / zoom) do
      gpu.drawRectangle((i - 1) * zoom, (j - 1) * zoom, zoom, zoom, image[i][j])
    end
  end

  gpu.drawRectangle(math.floor(x / zoom) * zoom, math.floor(y / zoom) * zoom, zoom, zoom, color)

  gpu.drawRectangle(318, 0, 22, 200, 7)
  gpu.drawRectangle(318, (color - 1)*11 + 1, 22, 11, 9)
  for i=1, 16 do
    gpu.drawRectangle(319, (i - 1)*11 + 1, 20, 11, i)
  end

  gpu.drawRectangle(0, 189, 340, 12, theme.selBar)

  local delta = os.clock() - lastI

  braceX = braceX + (braceXGoal - braceX)*10*delta
  if math.abs(braceXGoal - braceX) < 0.1 then braceX = braceXGoal end

  braceWidth = braceWidth + (braceWidthGoal - braceWidth)*10*delta
  if math.abs(braceWidthGoal - braceWidth) < 0.1 then braceWidth = braceWidthGoal end

  write(hintText, 2, 190, theme.text)

  if inMenu then
    write("[", braceX, 190, theme.selChar)
    write("]", braceX + braceWidth, 190, theme.selChar)
  end

  local xpos = math.floor(x / zoom) + 1
  local ypos = math.floor(y / zoom) + 1

  local locStr = "("..xpos..", "..ypos..")"
  write(locStr, 335 - (#locStr * 7), 190, theme.text)

  lastI = os.clock()

  gpu.swap()
end

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

local eventQueue = {}

while running do
  draw()

  while true do
    local e, p1, p2, p3 = coroutine.yield()
    if e == nil then
      break
    end
    table.insert(eventQueue, {e, p1, p2, p3})
  end

  while #eventQueue > 0 do
    local e, p1, p2, p3 = unpack(eventQueue[1])
    table.remove(eventQueue, 1)

    if e == "mouseMoved" then
      if p1 >= 318 then
        if pdown then
          color = math.ceil(p2 / 11)
          color = color < 1 and 1 or (color > 16 and 16 or color)
        end
      else
        x = p1
        y = p2
        if down > -1 then
          local xpos = math.floor(p1 / zoom) + 1
          local ypos = math.floor(p2 / zoom) + 1
          image[xpos][ypos] = down
          big(xpos, ypos)
        end
      end
    elseif e == "mousePressed" then
      p3 = tonumber(p3)

      if p1 >= 318 then
        color = math.ceil(p2 / 11)
        color = color < 1 and 1 or (color > 16 and 16 or color)
        pdown = true
      else
        local xpos = math.floor(p1 / zoom) + 1
        local ypos = math.floor(p2 / zoom) + 1
        if p3 == 1 then
          image[xpos][ypos] = color
          big(xpos, ypos)
          down = color
        elseif p3 == 3 then
          image[xpos][ypos] = 1
          big(xpos, ypos)
          down = 1
        end
      end
    elseif e == "mouseReleased" then
      if p3 == 1 then
        down = -1
      end
      pdown = false
    elseif e == "char" then
      if p1 == "+" then
        zoom = zoom + 1
      elseif p1 == "-" then
        zoom = zoom - 1
      elseif tonumber(p1) then
        color = tonumber(p1 + 1)
      end
    elseif e == "key" then
      if p1 == "Left Ctrl" then
        inMenu = not inMenu
        updateHint()
      elseif inMenu then
        if p1 == "Left" then
          menuSelected = menuSelected == 1 and #menuItems or menuSelected - 1
          updateHint()
        elseif p1 == "Right" then
          menuSelected = menuSelected == #menuItems and 1 or menuSelected + 1
          updateHint()
        elseif p1 == "Return" then
          menuFunctions[menuSelected]()
          inMenu = false
          updateHint()
        end
      else
        if p1 == "Up" then
          color = color > 1 and color - 1 or color
        elseif p1 == "Down" then
          color = color < 16 and color + 1 or color
        end
      end
    end
  end
end
