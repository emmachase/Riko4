local rif = dofile("../lib/rif.lua")

-- local scrn = image.newImage(340, 200)

local block = {
  2,  12, 12, 12, 2,
  12, 12, 2,  12, 12,
  12, 2,  2,  2,  12,
  12, 12, 2,  12, 12,
  2,  12, 12, 12, 2
}
local blockIm = image.newImage(5, 5)
blockIm:blitPixels(0, 0, 5, 5, block)
blockIm:flush()

local pac = {
  1, 8, 8, 8, 1,
  8, 1, 8, 1, 8,
  8, 8, 8, 8, 8,
  8, 8, 8, 8, 8,
  8, 1, 8, 1, 8,
}
local pacIm = image.newImage(5, 5)
pacIm:blitPixels(0, 0, 5, 5, pac)
pacIm:flush()

-- local blocIm = rif.createImage("bloc.rif")
-- local blocIm2 = rif.createImage("bloc2.rif")
-- local blocIm3 = rif.createImage("bloc3.rif")

local uwot = rif.createImage("hi.rif")

-- local blocks = {blocIm, blocIm2, blocIm3}

local x = 7
local y = 7

local i = 1

local function round(n)
  local fp = n % 1
  if fp >= 0.5 then
    return math.ceil(n)
  else
    return math.floor(n)
  end
end

local function draw()
  -- scrn:clear()

  blockIm:render(2, 2) --blockIm:render(2, 2)
  blockIm:render(7, 2) --blockIm:render(7, 2)
  -- local frc = math.floor((i - 1) / 10)
  -- local ind = round(math.sin(frc*math.pi/2) + 2) -- floor for floating point precision errors
  -- Sin[n*Pi/2] + 2
  --pacIm:render(x, y)
  pacIm:render(x, y)
  -- blocks[ind]:render(24, 10) --blocks[ind]:render(24, 10)
  --pacIm:copy(scrn, x, y) --pacIm:render(x, y)
  i = i + 1

  uwot:render(5, 60)

  -- scrn:flush()
  -- scrn:render(0, 0)
end

while true do
  local e, p1 = coroutine.yield()

  if e == "key" then
    if p1 == "escape" then
      break
    elseif p1 == "left" then
      x = x - 5
    elseif p1 == "right" then
      x = x + 5
    elseif p1 == "up" then
      y = y - 5
    elseif p1 == "down" then
      y = y + 5
    end
  end

  gpu.clear()

  draw()

  gpu.swap()
end
