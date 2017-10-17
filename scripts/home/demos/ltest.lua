local running = true

local rif = dofile("/lib/rif.lua")

local file = ({...})[1] or "logo.rif"
local handle = fs.open(file, "rb")
local data = handle:read("*a")
handle:close()

local rifData, w, h = rif.decode1D(data)

local rifImg = rif.createImage(rifData, w, h)

local track = {}

local c = 1
for i = 1, h do
  for j = 1, w do
    local d = rifData[c]
    if d ~= -1 then
      track[#track + 1] = {c = d, dx = j + (gpu.width - w) / 2, dy = i + (gpu.height - h) / 2}
      --x = j + 140 + math.random(-40, 40), y = i + 85 + math.random(-40, 40)}
    end
    c = c + 1
  end
end

local function processEvent(e, ...)
  local args = {...}
  if e == "key" then
    local key = args[1]
    if key == "escape" then
      running = false
    end
  end
end

local round = function(x)
  local frac = x - math.floor(x)
  if frac >= 0.5 then
    return math.ceil(x)
  else
    return math.floor(x)
  end
end

-- local lookup = {}
-- for i = 1, #track do
--   lookup[i] = i
-- end
-- local dorder = {}
-- for i = 1, #track do
--   dorder[i] = table.remove(lookup, math.random(1, #lookup))
-- end

local frms = 0
local function drawContent()
  frms = frms + 1
  local brkpt = w
  gpu.clear()
  -- local min = math.huge
  for i=math.max(0, math.floor((frms - 90)/1.4) * w) + 1, #track do
    -- local i = dorder[pt]
    if not track[i].x then
      track[i].x = track[i].dx + math.random(-40, 40)
      track[i].y = track[i].dy + math.random(-40, 40)
      brkpt = brkpt - 1
      if brkpt == 0 then break end
    end

    -- if min > i then min = i end

    if math.abs(track[i].x - track[i].dx) < 1 then
      gpu.drawPixel(track[i].dx, track[i].dy, track[i].c)
    else
      gpu.drawPixel(round(track[i].x), round(track[i].y), track[i].c)
    end

    track[i].x = (track[i].dx - track[i].x) * 0.04 + track[i].x
    track[i].y = (track[i].dy - track[i].y) * 0.04 + track[i].y
  end

  if math.max(0, math.floor((frms - 90)/1.4)) + 1 > 1 then
    rifImg:render((gpu.width - w) / 2 + 1, (gpu.height - h) / 2 + 1, w, math.min(h, math.max(0, math.floor((frms - 90)/1.4)) + 1))
  end
  
  -- print(min)

  -- rifImg:render(1, 1)
end

local eventQueue = {}
while running do
  while true do
    local e, p1, p2, p3, p4 = coroutine.yield()
    if not e then break end
    table.insert(eventQueue, {e, p1, p2, p3, p4})
  end

  while #eventQueue > 0 do
    processEvent(unpack(eventQueue[1]))
    table.remove(eventQueue, 1)
  end

  gpu.clear()

  drawContent()

  gpu.swap()
end