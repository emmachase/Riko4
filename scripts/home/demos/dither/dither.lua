--HELP: \b16Dither Demo\b7 \n
-- \b6Implements \b7Burkes \b6Dithering algorithm \n
-- \b6Also utilizes automatic palette selection via: \n
--   \b6- \b7K-Means Clustering \b6and \b7Probabalistic Centroid Initialization \n
--  \n
--       \b6X\b7 8 4 \n
--  \b7 2 4 8 4 2 \n
--  \n
--     \b6(1/32) \n
--  \n
-- \b6-----------------------------------------------------------------\n
-- \b6Usage: \b16dither \b7<\b16file.bmp\b7> \n
-- \b6Description: \b7Opens and dithers \b16file.bmp \b7 \n
-- \b6Commands: \n
--   \b16d \b6- \b7Toggle dithering \n
--   \b16r \b6- \b7Restart with new centroids \n
--   \b16h \b6- \b7Hides onscreen elements \n
--   \b16c \b6- \b7Use Riko4 palette \n
--   \b16<click> \b6- \b7Use selected pixel as initial centroid \n

local bitmap = dofile("/lib/bitmap.lua")
local rif = dofile("/lib/rif.lua")

local file = ({...})[1] or "land.bmp"

local ditherImage = bitmap.createBitmapFromFile(file)

local originalPalette = {
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

local palette

local sqrt = math.sqrt
local function closestRGB(pal, r, g, b)
  local error = math.huge --sqrt(255*255 + 255*255 + 255*255)
  local e1, e2, e3 = math.huge, math.huge, math.huge -- 255, 255, 255
  local pick = 0
  for i=1, #pal do
    local erR = r - pal[i][1]
    local erG = g - pal[i][2]
    local erB = b - pal[i][3]
    local dist = erR*erR + erG*erG + erB*erB
    if dist < error then
      pick = i
      error = dist
      e1, e2, e3 = erR, erG, erB
    end
  end
  return pick, e1, e2, e3
end

local function getPos(x, y)
  return (y-1)*ditherImage.width + x
end

local function round(x)
  if x < 0.5 then
    return math.floor(x)
  else
    return math.ceil(x)
  end
end

local function avgRGB(list)
  local cr, cg, cb = 0, 0, 0
  local count = #list
  for i=1, count do
    cr = cr + list[i][1]
    cg = cg + list[i][2]
    cb = cb + list[i][3]
  end

  return cr / count, cg / count, cb / count
end

local function pickCentroids(x, y)
  local imW, imH = ditherImage.width, ditherImage.height

  local initial = ditherImage.components[math.random(1, #ditherImage.components)]
  if x and y then
    local i = getPos(x, y)
    if i > 0 and i <= #ditherImage.components then
      initial = ditherImage.components[i]
    end
  end

  local centroids = { initial }

  for p=2, #originalPalette do
    local distribution = {}
    local counter = 0

    -- local maxErr = 0
    -- local maxValue = {}

    for i=1, ditherImage.height do
      for j=1, ditherImage.width do
        local rp, gp, bp = unpack(ditherImage.components[getPos(j, i)])  
        local _nearest, er, eg, eb = closestRGB(centroids, rp, gp, bp)
        local sqError = er*er + eg*eg + eb*eb
        -- if sqError > maxErr then
        --   maxValue = {rp, gp, bp}
        -- end
        table.insert(distribution, { 
          place = sqError + counter,
          value = {rp, gp, bp}
        })

        counter = sqError + counter
      end
    end

    -- table.insert(centroids, maxValue)

    -- Pick from the distribution
    local pick = math.random(1, counter)
    local which = 1
    while pick > distribution[which].place do
      which = which + 1
    end

    table.insert(centroids, distribution[which].value)
  end

  return centroids
end

palette = pickCentroids()
-- palette = originalPalette

-- for i=1, #newCentroids do
--   print(newCentroids[i][1] .. ";" .. newCentroids[i][2] .. ";" .. newCentroids[i][3])
-- end
-- os.exit()

local reachedEqual = false
local function iterateKMeans()
  local clustering = {}
  for i=1, #palette do
    clustering[i] = {}

    -- print("PRE" .. palette[i][1] .. ";" .. palette[i][2] .. ";" .. palette[i][3])
  end

  for i=1, ditherImage.height do
    for j=1, ditherImage.width do
      local rp, gp, bp = unpack(ditherImage.components[getPos(j, i)])  
      local col, a, b, c = closestRGB(palette, rp, gp, bp)
      table.insert(clustering[col], {rp, gp, bp})
    end
  end

  local lastPal = {}
  for i=1, #palette do
    lastPal[i] = {palette[i][1], palette[i][2], palette[i][3]}
  end

  local differs = false
  for i=1, #palette do
    if #clustering[i] > 0 then
      local nr, ng, nb = avgRGB(clustering[i])
      palette[i] = { nr, ng, nb }

      local cr, cg, cb = unpack(lastPal[i])
      local r = round
      if cr ~= r(nr) or cg ~= r(ng) or cb ~= r(nb) then
        differs = true
      end
    end
  end

  if not differs then
    reachedEqual = true
  end
end

-- for i=1, 20 do
--   iterateKMeans()
-- end

function normalizePalette()
  local blitPalette = {}
  for i=1, #palette do
    palette[i][1] = round(palette[i][1])
    palette[i][2] = round(palette[i][2])
    palette[i][3] = round(palette[i][3])
    blitPalette[i] = {palette[i][1], palette[i][2], palette[i][3]}
    -- print(palette[i][1] .. ";" .. palette[i][2] .. ";" .. palette[i][3])
  end



  gpu.blitPalette(blitPalette)
end

normalizePalette()

-- os.exit()

local dithered = {}

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

local shouldDither = true
function redither()
  dithered = {}

  local dp = {
    components = {}
  }
  for i = 1, #ditherImage.components do
    local src = ditherImage.components[i]
    dp.components[i] = {src[1], src[2], src[3]}
  end

  for i=1, ditherImage.height do
    for j=1, ditherImage.width do
      local rp, gp, bp = unpack(dp.components[getPos(j, i)])
      -- ditherImage.components[(i-1)*ditherImage.width + j]

      local col, a, b, c = closestRGB(palette, rp, gp, bp)
      dithered[#dithered + 1] = col

      local pa = a / 32
      local pb = b / 32
      local pc = c / 32

      local t = dp.components
      if shouldDither then
        addToFA(t, j + 1, i, pa*8, pb*8, pc*8)
        addToFA(t, j + 2, i, pa*4, pb*4, pc*4)
        
        addToFA(t, j - 2, i + 1, pa*2, pb*2, pc*2)
        addToFA(t, j - 1, i + 1, pa*4, pb*4, pc*4)
        addToFA(t, j    , i + 1, pa*8, pb*8, pc*8)
        addToFA(t, j + 1, i + 1, pa*4, pb*4, pc*4)
        addToFA(t, j + 2, i + 1, pa*2, pb*2, pc*2)
      end
    end
  end
end

redither()

-- local handle = fs.open(file .. ".rif", "w")
-- handle:write(rif.encode(dithered, ditherImage.width, ditherImage.height))
-- handle:close()

local iter = 1
-- local maxIter = 50

local function cond()
  return not reachedEqual -- and iter < maxIter
end

local mx, my = -1, -1

local solo = false

local running = true
local eventQueue = {}
while running do
  gpu.clear()

  local centerX = (gpu.width - ditherImage.width) / 2
  local centerY = (gpu.height - ditherImage.height) / 2

  gpu.blitPixels(centerX, centerY, ditherImage.width, ditherImage.height, dithered)
  -- gpu.blitPixels(1, 1, 2, 2, {5, 6, 7, 8})

  
  local white = closestRGB(palette, 255, 255, 255)
  local black = closestRGB(palette, 0, 0, 0)
  
  if not solo then
    local palX, palY = gpu.width - 24, gpu.height - 32
    gpu.drawRectangle(palX + 3, palY + 3, 16, 16, black)

    for i = 1, 16 do
      gpu.drawRectangle(palX + ((i - 1) % 4) * 4 + 4, palY + math.floor((i - 1) / 4) * 4 + 4, 4, 4, i)
    end

    local function cute(t, x, y)
      for dx = -1, 1 do
        for dy = -1, 1 do
          write(t, x+dx, y+dy, black)
        end
      end
      write(t, x, y, white)
    end

    cute("Pal", palX + 5, palY + 22)

    
    if cond() then
      -- cute(math.floor(100*iter / maxIter) .. "%", 4, 4)
      cute(iter, 4, 4)
    elseif reachedEqual then
      cute("Minima I:" .. iter, 4, 4)
    end

    -- Mouse
    gpu.drawPixel(mx - 1, my    , white)
    gpu.drawPixel(mx    , my - 1, white)
    gpu.drawPixel(mx + 1, my    , white)
    gpu.drawPixel(mx    , my + 1, white)

    gpu.drawPixel(mx - 1, my - 1, black)
    gpu.drawPixel(mx + 1, my - 1, black)
    gpu.drawPixel(mx + 1, my + 1, black)
    gpu.drawPixel(mx - 1, my + 1, black)
  end

  gpu.swap()

  if not reachedEqual then
    iter = iter + 1
  end

  while true do
    local e = {coroutine.yield()}
    if #e == 0 then break end
    eventQueue[#eventQueue + 1] = e
  end

  while #eventQueue > 0 do
    local e, p1, p2 = unpack(table.remove(eventQueue, 1))
    if e == "key" then
      if p1 == "escape" then
        running = false
      elseif p1 == "d" then
        shouldDither = not shouldDither
        redither()
      elseif p1 == "r" then
        iter = 1
        palette = pickCentroids()
        reachedEqual = false
      elseif p1 == "c" then
        iter = 1
        palette = {}
        for i = 1, #originalPalette do
          palette[i] = {originalPalette[i][1], originalPalette[i][2], originalPalette[i][3]}
        end

        reachedEqual = false
      elseif p1 == "h" then
        solo = not solo
      end
    elseif e == "mouseMoved" then
      mx, my = p1, p2
    elseif e == "mousePressed" then
      local x, y = p1, p2
      iter = 1
      palette = pickCentroids(math.floor(x - centerX), math.floor(y - centerY))
      reachedEqual = false
    end
  end

  if not reachedEqual then
    iterateKMeans()
    normalizePalette()
    redither()
  end
end

gpu.blitPalette(originalPalette)
