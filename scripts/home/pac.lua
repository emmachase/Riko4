local rif = dofile("../lib/rif.lua")

local running = true

local sprS = rif.createImage("pactex.rif")

local c = 1
local x = 1
local xp = 12
local d = 1
local function draw()
  local o = (4+c)*24
  sprS:render(xp, 12, o, 0, 24, 24)
  xp = xp + 2
  x = x + 1
  if x % 4 == 0 then
    c = c + d
    if c == 3 or c == 1 then
      d = -d
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
