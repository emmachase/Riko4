--[[

  Random fun little thing
  ... I don't even know

  Inspired by @egordorichev

]]

local running = true
gpu.clear()

local w, h = gpu.width, gpu.height

local gpp = dofile("/lib/gpp.lua")

local sin, cos = math.sin, math.cos

local timer = 0
local vel = 0
local off = 0
local loff = 0
local function update(dt)
  timer = timer + dt
  vel = 10 * sin(2 * timer)
  loff = off
  off = off + vel * dt
end

local function round(n)
  if n % 1 >= 0.5 then
    return n % 1 + 1
  else
    return n % 1
  end
end

local gr = 50

local function cfunc(i, j)
  if round(i / (math.pi / 2)) % 2 == 0 then
    return 16
  else
    if j % 2 == 0 then
      return 9
    else
      return 8
    end
  end
end

local function draw()
  for i = 1, 1499 do
    local x, y = math.random(1, w), math.random(1, h)
    gpu.drawPixel(x - 1, y, 1)
    gpu.drawPixel(x + 1, y, 1)
    gpu.drawPixel(x, y - 1, 1)
    gpu.drawPixel(x, y + 1, 1)
  end
  -- gpu.clear()

  for j = 1, 7 do
    for i = 0, 2 * math.pi, math.pi / 4 do
      local r = (sin((timer + j / 3) * 1.5) + 1.25) * (35 + j * 10)
      -- local cloff = loff * (j % 2 == 0 and 1 or -1)
      -- local coff = off * (j % 2 == 0 and 1 or -1)

      for k = math.min(off, loff), math.max(off, loff), 0.05 do
        local coff = k * (j % 2 == 0 and 1 or -1)
        gpp.fillEllipse(w / 2 + math.cos(coff + i) * r, h / 2 + math.sin(coff + i) * r, 10, 10, cfunc(i, j))
        --math.floor((i + j) * 12) % 15 + 2)
      end
    end
  end

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