--[[

  Random fun little thing
  ... I don't even know

  
  Inspired by @egordorichev

]]

local running = true
gpu.clear()

local w, h = gpu.width, gpu.height

local gpp = dofile("/lib/gpp.lua")

local timer = 0
local function update(dt)
  timer = timer + (2 * dt)
end

local gr = 50

local function draw()
  for i = 1, 1499 do
    local x, y = math.random(1, w), math.random(1, h)
    -- gpu.drawRectangle(x - 1, y, 3, 1, 1)
    -- gpu.drawRectangle(x, y - 1, 1, 3, 1)
    gpu.drawPixel(x - 1, y, 1)
    gpu.drawPixel(x + 1, y, 1)
    gpu.drawPixel(x, y - 1, 1)
    gpu.drawPixel(x, y + 1, 1)
  end

  for j = 0.5, 4, 0.5 do
    for i = 0, 2 * math.pi, math.pi / 4 do
      local r = (math.sin(4 * timer + i) * gr + gr) * j
      gpp.fillEllipse(w / 2 + math.cos(timer + i + (10 * j)) * r, h / 2 + math.sin(timer + i + (10 * j)) * r, 10, 10, math.floor(i * 12 + timer) % 15 + 2)
    end
  end

  -- for i = 0, 2 * math.pi, math.pi / 2 do
  --   local r = (4 * gr) - (math.sin(4 * timer + i) * (4 * gr) + (4 * gr))
  --   gpp.fillEllipse(w / 2 + math.cos(timer + i) * r, h / 2 + math.sin(timer + i) * r, 10, 10, math.floor(i * 12 + timer) % 15 + 2)
  -- end

  gpu.swap()
end

local function event(e, ...)
  if e == "key" then
    local k = ...
    if k == "escape" then
      running = false
    end
  end
end

local eq = {}
local last = os.clock()
while running do
  while true do
    local a = {coroutine.yield()}
    if not a[1] then break end
    table.insert(eq, a)
  end

  while #eq > 0 do
    event(unpack(table.remove(eq, 1)))
  end

  update(os.clock() - last)
  last = os.clock()

  draw()
end