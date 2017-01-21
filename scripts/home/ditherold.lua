-- Implements Burkes Dithering algorithm

--     X 8 4
-- 2 4 8 4 2
--
--  (1/32)

local bitmap = dofile("scripts/lib/bitmap.lua")

local tucan = bitmap.createBitmapFromFile("scripts/home/land.bmp")

local palette = {
  {24, 24, 24},
	{127, 127, 127},
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
  local error = sqrt(255*255 + 255*255 + 255*255)
  local e1, e2, e3 = 255, 255, 255
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

local function addToFA(tb, index, er, eg, eb)
  if index > 1 and index <= tucan.width then
    if not tb[index] then tb[index] = {0, 0, 0} end
    tb[index][1] = tb[index][1] + er
    tb[index][2] = tb[index][2] + eg
    tb[index][3] = tb[index][3] + eb
    -- error()
  end
  return tb
end

for i=1, tucan.height do
  local nextError = {0, 0, 0}
  local afterError = {0, 0, 0}

  local myError = {}
  for i=1, 3 do
    myError[i] = {}
    for j=1, tucan.width do
      myError[i][j] = 0
    end
  end

  for j=1, tucan.width do
    local r, g, b = unpack(tucan.components[(i-1)*tucan.width + j])
    local orr = r
    r = r + forwardArray[1][j] + nextError[1]
    -- if forwardArray[2][j] > 0 then write(tostring(forwardArray[2][j]), 2, 170) error() end
    g = g + forwardArray[2][j] + nextError[2]
    b = b + forwardArray[3][j] + nextError[3]

    if forwardArray[1][j] > 0 then
      error()
    end

    nextError = afterError
    afterError = {0, 0, 0}

    local col, e1, e2, e3 = closestRGB(r, g, b)

    dithered[#dithered + 1] = col

    local portionR = e1 / 32
    local portionG = e2 / 32
    local portionB = e3 / 32

    nextError[1] = nextError[1] + portionR*8
      nextError[2] = nextError[2] + portionG*8
      nextError[3] = nextError[3] + portionB*8

    afterError[1] = afterError[1] + portionR*4
      afterError[2] = afterError[2] + portionR*4
      afterError[3] = afterError[3] + portionR*4

    myError = addToFA(myError, j-2, portionR*2, portionG*2, portionB*2)
    myError = addToFA(myError, j-1, portionR*4, portionG*4, portionB*4)
    myError = addToFA(myError, j  , portionR*8, portionG*8, portionB*8)
    myError = addToFA(myError, j+1, portionR*4, portionG*4, portionB*4)
    myError = addToFA(myError, j+2, portionR*2, portionG*2, portionB*2)
  end

  forwardArray = myError
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
