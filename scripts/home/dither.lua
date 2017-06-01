-- Implements Burkes Dithering algorithm

--     X 8 4
-- 2 4 8 4 2
--
--  (1/32)

local bitmap = dofile("../lib/bitmap.lua")

local ditherImage = bitmap.createBitmapFromFile("land.bmp")

local palette = {
    {24,   24,   24 },
    {29,   43,   82 },
    {126,  37,   83 },
    {0,    134,  81 },
    {171,  81,   54 },
    {86,   86,   86 },
    {157,  157,  157},
    {255,  0,    76 },
    {255,  163,  0  },
    {255,  240,  35 },
    {0,    231,  85 },
    {41,   173,  255},
    {130,  118,  156},
    {255,  119,  169},
    {254,  204,  169},
    {236,  236,  236}
}

local sqrt = math.sqrt
local function closestRGB(r, g, b)
  local error = math.huge --sqrt(255*255 + 255*255 + 255*255)
  local e1, e2, e3 = math.huge, math.huge, math.huge -- 255, 255, 255
  local pick = 0
  for i=1, #palette do
    local erR = r - palette[i][1]
    local erG = g - palette[i][2]
    local erB = b - palette[i][3]
    local dist = sqrt(erR*erR + erG*erG + erB*erB)
    if dist < error then
      pick = i
      error = dist
      e1, e2, e3 = erR, erG, erB
    end
  end
  return pick, e1, e2, e3
end

local dithered = {}

local function getPos(x, y)
  return (y-1)*ditherImage.width + x
end

local function addToFA(tb, x, y, er, eg, eb)
  if x > 1 and x <= ditherImage.width and y < ditherImage.height then
    local index = getPos(x, y)
    if not tb[index] then tb[index] = {0, 0, 0} end
    tb[index][1] = tb[index][1] + er
    tb[index][2] = tb[index][2] + eg
    tb[index][3] = tb[index][3] + eb
    -- error()
  end
  return tb
end

for i=1, ditherImage.height do
  for j=1, ditherImage.width do
    local rp, gp, bp = unpack(ditherImage.components[getPos(j, i)])
    -- ditherImage.components[(i-1)*ditherImage.width + j]

    local col, a, b, c = closestRGB(rp, gp, bp)
    dithered[#dithered + 1] = col

    local pa = a / 32
    local pb = b / 32
    local pc = c / 32

    local t = ditherImage.components
    addToFA(t, j + 1, i, pa*8, pb*8, pc*8)
    addToFA(t, j + 2, i, pa*4, pb*4, pc*4)
    --
    addToFA(t, j - 2, i + 1, pa*2, pb*2, pc*2)
    addToFA(t, j - 1, i + 1, pa*4, pb*4, pc*4)
    addToFA(t, j    , i + 1, pa*8, pb*8, pc*8)
    addToFA(t, j + 1, i + 1, pa*4, pb*4, pc*4)
    addToFA(t, j + 2, i + 1, pa*2, pb*2, pc*2)
  end
end

while true do
  gpu.clear()

  write(tostring(ditherImage.components[5]), 0, 180)

  gpu.blitPixels(0, 0, ditherImage.width, ditherImage.height, dithered)
  -- gpu.blitPixels(1, 1, 2, 2, {5, 6, 7, 8})

  gpu.swap()
  local e, p1 = coroutine.yield()
  if e == "key" and p1 == "escape" then break end
end
