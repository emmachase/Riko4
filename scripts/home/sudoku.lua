local rif = dofile("../lib/rif.lua")

local running = true
local won = false
local winText = "Thou hast won le puzzle"

local w, h = gpu.width, gpu.height

local cx, cy = math.floor(w / 2), math.floor(h / 2)

local tlx, tly = cx - 11 * 4 - 5, cy - 11 * 4 - 5
local msX, msY = -5, -5

local cursor = rif.createImage("curs.rif")

local sodGrid = {}
local totalGrid = {}

-- Returns still valid numbers for any given gridspace as elemnts of a table
local function getAvaNum(gx, gy)
  local poss = {}
  for i = 1, 9 do poss[i] = true end

  -- Row validation
  for i = 1, 9 do
    poss[sodGrid[i][gy]] = false
    poss[sodGrid[gx][i]] = false
  end

  -- Subgrid validation
  local sgx = math.floor((gx - 1) / 3)
  local sgy = math.floor((gy - 1) / 3)
  for i = 1, 3 do
    for j = 1, 3 do
      poss[sodGrid[i + sgx * 3][j + sgy * 3]] = false
    end
  end

  local out = {}
  for i = 1, 9 do
    if poss[i] then
      out[#out + 1] = i
    end
  end

  return out
end

local function randSelect(tab)
  if #tab > 0 then
    local key = math.random(1, #tab)
    return tab[key], key
  else
    return 0
  end
end

for i = 1, 9 do
  sodGrid[i] = {}
  for j = 1, 9 do
    sodGrid[i][j] = 0 --((i - 1) * 9 + j - 1) % 9 + 1
  end
end

repeat
  local good = true
  for i = 1, 9 do
    for j = 1, 9 do
      sodGrid[i][j] = 0 --((i - 1) * 9 + j - 1) % 9 + 1
    end
  end

  for i = 1, 9 do
    for j = 1, 9 do
      local val = randSelect(getAvaNum(i, j))
      if val == 0 then
        good = false
        break
      end
      sodGrid[i][j] = val
    end
    if not good then break end
  end
until good

local pickings = {}
for i = 1, 9 do
  for j = 1, 9 do
    pickings[#pickings + 1] = {i, j}
  end
end

while #pickings > 0 do
  local t, k = randSelect(pickings)
  local i, j = t[1], t[2]
  table.remove(pickings, k)

  local ov = sodGrid[i][j]
  sodGrid[i][j] = 0
  local can = #getAvaNum(i, j) < 2
  if can then
    sodGrid[i][j] = 0
  else
    sodGrid[i][j] = ov
  end
end

for i = 1, 9 do
  totalGrid[i] = {}
  for j = 1, 9 do
    totalGrid[i][j] = sodGrid[i][j]
  end
end

local selBX, selBY = 5, 5
local written = {}

local errorRows = {}
for i = 1, 9 do errorRows[i] = false end
local errorColumns = {}
for i = 1, 9 do errorColumns[i] = false end
local errorQuads = {}
for i = 1, 9 do errorQuads[i] = false end

local function draw()
  for i = 1, 9 do
    if errorRows[i] then
      gpu.drawRectangle(tlx, tly + 11 * (i - 1) + 1, 9 * 11, 10, 12)
    end

    if errorColumns[i] then
      gpu.drawRectangle(tlx + 11 * (i - 1) + 1, tly, 10, 9 * 11, 12)
    end

    if errorQuads[i] then
      gpu.drawRectangle(tlx + 33 * ((i - 1) % 3), tly + 33 * math.floor((i - 1) / 3), 33, 33, 12)
    end
  end

  gpu.drawRectangle(tlx + 11 * (selBX - 1) + 1, tly + 11 * (selBY - 1) + 1, 10, 1, 10)
  gpu.drawRectangle(tlx + 11 * (selBX - 1) + 1, tly + 11 * (selBY - 1) + 1, 1, 10, 10)
  gpu.drawRectangle(tlx + 11 * (selBX - 1) + 1, tly + 11 * (selBY - 1) + 10, 10, 1, 10)
  gpu.drawRectangle(tlx + 11 * (selBX - 1) + 10, tly + 11 * (selBY - 1) + 1, 1, 10, 10)

  for i = 1, 8 do
    gpu.drawRectangle(tlx, tly + 11 * i, 9 * 11, 1, 13)
    gpu.drawRectangle(tlx + 11 * i, tly, 1, 9 * 11, 13)
  end

  for i = 1, 2 do
    gpu.drawRectangle(tlx, tly + 33 * i, 9 * 11, 1, 8)
    gpu.drawRectangle(tlx + 33 * i, tly, 1, 9 * 11, 8)
  end

  for i = 1, 9 do
    for j = 1, 9 do
      if sodGrid[i][j] > 0 then
        write(tostring(sodGrid[i][j]), (i - 1) * 11 + tlx + 1, (j - 1) * 11 + tly + 2)
      end
    end
  end

  for i = 1, #written do
    write(written[i][1], (written[i][2] - 1) * 11 + tlx + 1, (written[i][3] - 1) * 11 + tly + 2, 10)
  end

  if won then
    write(winText, math.floor(cx - (#winText / 2) * 7), h - 20)
  end

  cursor:render(msX, msY)
end

local function validateCurrent()
  -- Validation
  local ev = {}
  local Egood = true
  for i = 1, 9 do
    if ev[totalGrid[i][selBY]] and totalGrid[i][selBY] > 0 then
      Egood = false
      break
    end
    ev[totalGrid[i][selBY]] = true
  end
  errorRows[selBY] = not Egood

  Egood = true
  for i = 1, 9 do ev[i] = false end
  for i = 1, 9 do
    if ev[totalGrid[selBX][i]] and totalGrid[selBX][i] > 0 then
      Egood = false
      break
    end
    ev[totalGrid[selBX][i]] = true
  end
  errorColumns[selBX] = not Egood

  Egood = true
  for i = 1, 9 do ev[i] = false end
  local qdX = math.floor((selBX - 1) / 3)
  local qdY = math.floor((selBY - 1) / 3)
  local qd  = qdY * 3 + qdX + 1
  for i = 1, 9 do
    if ev[totalGrid[(i - 1) % 3 + qdX * 3 + 1][math.floor((i - 1) / 3) + qdY * 3 + 1]] and
      totalGrid[(i - 1) % 3 + qdX * 3 + 1][math.floor((i - 1) / 3) + qdY * 3 + 1] > 0 then
      Egood = false
      break
    end
    ev[totalGrid[(i - 1) % 3 + qdX * 3 + 1][math.floor((i - 1) / 3) + qdY * 3 + 1]] = true
  end
  errorQuads[qd] = not Egood
end

local function processEvent(e, ...)
  if e == "key" then
    local key = ...
    if key == "escape" then
      running = false
    elseif key == "left" then
      selBX = selBX - 1
    elseif key == "right" then
      selBX = selBX + 1
    elseif key == "up" then
      selBY = selBY - 1
    elseif key == "down" then
      selBY = selBY + 1
    elseif key == "backspace" or key == "return" or key == "delete" then
      if not ((selBX < 1 or selBX > 9) or (selBY < 1 or selBY > 9)) then
        if sodGrid[selBX][selBY] == 0 then
          for i = 1, #written do
            if written[i][2] == selBX and written[i][3] == selBY then
              table.remove(written, i)
              break
            end
          end
          totalGrid[selBX][selBY] = 0
          validateCurrent()
          won = false
        end
      end
    end
  elseif e == "char" then
    local ch = ...
    if tonumber(ch) then
      if not ((selBX < 1 or selBX > 9) or (selBY < 1 or selBY > 9)) then
        if sodGrid[selBX][selBY] == 0 then
          for i = 1, #written do
            if written[i][2] == selBX and written[i][3] == selBY then
              table.remove(written, i)
              break
            end
          end
          totalGrid[selBX][selBY] = tonumber(ch)
          validateCurrent()

          if tonumber(ch) > 0 then
            written[#written + 1] = {ch, selBX, selBY}
          end

          local fin = true
          for i = 1, 9 do
            if errorColumns[i] then fin = false break end
            if errorRows[i] then fin = false break end
            if errorQuads[i] then fin = false break end
            for j = 1, 9 do
              if totalGrid[i][j] == 0 then
                fin = false
                break
              end
            end
          end
          won = fin
        end
      end
    end
  elseif e == "mouseMoved" then
    local x, y = ...
    msX, msY = x, y
    selBX = math.floor((x - tlx) / 11) + 1
    selBY = math.floor((y - tly) / 11) + 1
  elseif e == "mousePressed" then
    local x, y = ...
    selBX = math.floor((x - tlx) / 11) + 1
    selBY = math.floor((y - tly) / 11) + 1
  end
end

local eventQueue = {}
while running do
  while true do
    local e = {coroutine.yield()}
    if #e == 0 then break end
    eventQueue[#eventQueue + 1] = e
  end

  while #eventQueue > 0 do
    processEvent(unpack(
      table.remove(eventQueue, 1)))
  end

  gpu.clear()

  draw()

  gpu.swap()
end