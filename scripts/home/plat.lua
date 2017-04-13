local rif = dofile("../lib/rif.lua")

local running = true

local sprS = rif.createImage("fbtex.rif")

local map = {}
local mapWidth = 8
local mapHeight = 8

for i = 1, mapWidth do
  map[i] = {}
  for j = 1, mapHeight do
    map[i][j] = {j == 1 and 1 or 2, math.random(1, 5)}
  end
end

local function draw()
  for i = 1, mapWidth do
    for j = 1, mapHeight do
      sprS:render((i - 1) * 16, (j - 1) * 16, (map[i][j][2] - 1) * 16, (map[i][j][1] - 1) * 16, 16, 16)
    end
  end
end

local function processEvent(e, ...)
  local args = {...}
  if e == "key" then
    local k = args[1]
    if k == "escape" then
      running = false
    end
  end
end

local eventQueue = {}
while running do

  while true do
    local e = {coroutine.yield()}
    if not e[1] then break end
    table.insert(eventQueue, e)
  end

  while #eventQueue > 0 do
    local e = table.remove(eventQueue, 1)
    processEvent(unpack(e))
  end

  gpu.clear()

  draw()

  gpu.swap()

end
