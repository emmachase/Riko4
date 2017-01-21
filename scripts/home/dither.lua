-- Implements Burkes Dithering algorithm

--     X 8 4
-- 2 4 8 4 2
--
--  (1/32)

local bitmap = dofile("../lib/bitmap.lua")

local tucan = bitmap.createBitmapFromFile("lenna.bmp")

local palette = {
  -- { 24, 24, 24 },     -- Black
  -- 	{ 85, 85, 85 },     -- Dark Gray
  -- 	{ 170, 170, 170 },  -- Light Gray
  -- 	{ 239, 239, 239 },  -- White
  -- 	{ 127, 72, 5 },     -- Brown
  -- 	{ 230, 10, 10 },    -- Red
  -- 	{ 245, 106, 10 },   -- Orange
  -- 	{ 255, 255, 0 },    -- Yellow
  -- 	{ 0, 255, 33 },     -- Lime Green
  -- 	{ 87, 165, 77 },    -- Dark Green
  -- 	{ 0, 147, 141 },    -- Cyan
  -- 	{ 10, 142, 255 },   -- Light Blue
  -- 	{ 0, 38, 255 },     -- Blue
  -- 	{ 178, 0, 255 },    -- Magenta
  -- 	{ 255, 0, 110 },    -- Pink
  -- 	{ 255, 102, 107}
  {24, 24, 24},
	{100, 100, 100},
	{0, 18, 144},
	{0, 39, 251},
	{0, 143, 21},
	{0, 249, 44},
	{0, 144, 146},
	{0, 252, 254},
	{155, 23, 8},
	{255, 48, 22},
	{154, 32, 145},
	{255, 63, 252},
	{148, 145, 25},
	{255, 253, 51},
	{184, 184, 184},
	{235, 235, 235},
};

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
      pick = i - 1
      error = dist
      e1, e2, e3 = erR, erG, erB
    end
  end
  return pick, e1, e2, e3
end

local tucanCol = {}

for i=1, tucan.width do
  for j=1, tucan.height do
    tucanCol[(j-1)*tucan.width + i] = closestRGB(unpack(tucan.components[(j-1)*tucan.width + i]))
  end
end

local forwardArray = {}
for i=1, 3 do
  forwardArray[i] = {}
  for j=1, tucan.width do
    forwardArray[i][j] = 0
  end
end

local dithered = {}

local function getPos(x, y)
  return (y-1)*tucan.width + x
end

local function addToFA(tb, x, y, er, eg, eb)
  if x > 1 and x <= tucan.width and y < tucan.height then
    local index = getPos(x, y)
    if not tb[index] then tb[index] = {0, 0, 0} end
    tb[index][1] = tb[index][1] + er
    tb[index][2] = tb[index][2] + eg
    tb[index][3] = tb[index][3] + eb
    -- error()
  end
  return tb
end

for i=1, tucan.height do
  for j=1, tucan.width do
    local r, g, b = unpack(tucan.components[getPos(j, i)])
    -- tucan.components[(i-1)*tucan.width + j]

    local col, a, b, c = closestRGB(r, g, b)
    dithered[#dithered + 1] = col

    local pa = a / 32
    local pb = b / 32
    local pc = c / 32

    local t = tucan.components
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

  write(tostring(tucan.components[5]), 0, 180)
  -- gpu.blitPixels(0, 0, tucan.width, tucan.height, tucanCol)
  gpu.blitPixels(0, 0, tucan.width, tucan.height, dithered)

  gpu.swap()
  local e, p1 = coroutine.yield()
  if e == "key" and p1 == "Escape" then break end
end
