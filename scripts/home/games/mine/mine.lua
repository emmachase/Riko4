local rif = dofile("/lib/rif.lua")

local mineBloc = rif.createImage("mineBloc.rif")
local curs = rif.createImage("curs.rif")
local mine = rif.createImage("mine.rif")
local flag = rif.createImage("flag.rif")

local running = true
local gameLost = false
local scrnWidth, scrnHeight = gpu.width, gpu.height

local gridWidth = 30
local gridHeight = 20
local bombCount = 90

local numColor = {
  1,
  4,
  8,
  13,
  3,
  9,
  1,
  5
}

local mouseX, mouseY = -5, -5
local mouse2Down = false
local doX, doY = 1, 1

local grid
local bomSpc
local function regenBoard()
  grid = {}
  bomSpc = {}
  for i = 1, gridWidth do
    grid[i] = {}
    for j = 1, gridHeight do
      grid[i][j] = {false, 0, false}
      bomSpc[#bomSpc + 1] = {i, j}
    end
  end

  for _ = 1, bombCount do
    local rnd = math.random(1, #bomSpc)
    local ind = table.remove(bomSpc, rnd)
    grid[ind[1]][ind[2]][2] = -1
  end
end
regenBoard()

local function checkNeighbor(gx, gy)
  local cnt = 0

  if grid[gx] and grid[gx][gy] and grid[gx][gy][2] == -1 then
    return -1
  end

  for x = gx - 1, gx + 1 do
    if grid[x] then
      for y = gy - 1, gy + 1 do
        if grid[x][y] and grid[x][y][2] == -1 then
          cnt = cnt + 1
        end
      end
    end
  end

  return cnt
end

local function floodZero(gx, gy)
  local zeroQueue = {{gx, gy}}
  local compl = {}

  while #zeroQueue > 0 do
    local pop = table.remove(zeroQueue, #zeroQueue)
    local px, py = pop[1], pop[2]

    grid[px][py][1] = true
    local val = checkNeighbor(px, py)
    grid[px][py][2] = val

    if not compl[px] then compl[px] = {} end
    compl[px][py] = true

    if val == 0 then
      if px < gridWidth  and not (compl[px + 1] and compl[px + 1][py]) then zeroQueue[#zeroQueue + 1] = {px + 1, py} end
      if px > 1          and not (compl[px - 1] and compl[px - 1][py]) then zeroQueue[#zeroQueue + 1] = {px - 1, py} end
      if py < gridHeight and not (compl[px] and compl[px][py + 1])     then zeroQueue[#zeroQueue + 1] = {px, py + 1} end
      if py > 1          and not (compl[px] and compl[px][py - 1])     then zeroQueue[#zeroQueue + 1] = {px, py - 1} end

      if px > 1 and py > 1                  and not (compl[px - 1] and compl[px - 1][py - 1]) then
        zeroQueue[#zeroQueue + 1] = {px - 1, py - 1} end
      if px < gridWidth and py > 1          and not (compl[px + 1] and compl[px + 1][py - 1]) then
        zeroQueue[#zeroQueue + 1] = {px + 1, py - 1} end
      if px > 1 and py < gridHeight         and not (compl[px - 1] and compl[px - 1][py + 1]) then
        zeroQueue[#zeroQueue + 1] = {px - 1, py + 1} end
      if px < gridWidth and py < gridHeight and not (compl[px + 1] and compl[px + 1][py + 1]) then
        zeroQueue[#zeroQueue + 1] = {px + 1, py + 1} end
    end
  end
end

local dirty = true
local function drawContent()
  if dirty then
    gpu.clear()

    for i = 1, gridWidth do
      for j = 1, gridHeight do
        if grid[i][j][1] then
          -- mine:render((i - 1) * 14, (j - 1) * 14)
          gpu.drawRectangle((i - 1) * 14 + doX, (j - 1) * 14 + doY, 13, 13, 7)

          if grid[i][j][2] ~= 0 then
            write(tostring(grid[i][j][2]), (i - 1) * 14 + 2 + doX, (j - 1) * 14 + 2 + doY, numColor[grid[i][j][2]])
          end
        else
          mineBloc:render((i - 1) * 14 + doX, (j - 1) * 14 + doY)

          if grid[i][j][2] == -1 and gameLost then
            mine:render((i - 1) * 14 + 1 + doX, (j - 1) * 14 + 1 + doY)
          end
          if grid[i][j][3] then
            flag:render((i - 1) * 14 + 2 + doX, (j - 1) * 14 + 2 + doY)
          end
        end
      end
    end

    curs:render(mouseX, mouseY)

    gpu.swap()

    dirty = false
  end
end

local firstClick = true
local function processEvent(e, ...)
  if e == "key" then
    local k = ...
    if k == "escape" then
      running = false
    end
  elseif e == "mouseMoved" then
    local x, y, dx, dy = ...
    mouseX = x
    mouseY = y
    if mouse2Down then
      doX = doX + dx
      doY = doY + dy
      doX = doX > 1 and 1 or (doX < -(gridWidth * 14 - scrnWidth) and -(gridWidth * 14 - scrnWidth) or doX)
      doY = doY > 1 and 1 or (doY < -(gridHeight * 14 - scrnHeight) and -(gridHeight * 14 - scrnHeight) or doY)
    end
    dirty = true
  elseif e == "mousePressed" then
    local x, y, b = ...
    local gx, gy = math.floor((x - doX) / 14) + 1, math.floor((y - doY) / 14) + 1

    if b == 1 and not gameLost then
      repeat
        if (not firstClick) and grid[gx][gy][2] == -1 then
          gameLost = true
          dirty = true
          return
        end

        grid[gx][gy][1] = true
        local val = checkNeighbor(gx, gy)
        grid[gx][gy][2] = val
        if val == 0 then
          floodZero(gx, gy)
        else
          regenBoard()
        end
      until (not firstClick) or val == 0

      firstClick = false
      dirty = true
    elseif b == 3 and not gameLost then
      grid[gx][gy][3] = true
      dirty = true
    elseif b == 2 then
      mouse2Down = true
    end
  elseif e == "mouseReleased" then
    local _, _, b = ...
    if b == 2 then
      mouse2Down = false
    end
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

  drawContent()
end
