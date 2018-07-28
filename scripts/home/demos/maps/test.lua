local pix, rect, cls, pal, pixb, cam, push, sheet, spr, pop, pget, swap, trans, _eventDefault
local _w, _h = gpu.width, gpu.height
local _running = true

do
  local g_ = gpu
  local rif = dofile("/lib/rif.lua")

  function pal(cot, r, g, b)
    if tonumber(cot) then
      g_.setPaletteColor(cot, r, g, b)
    elseif cot then
      g_.blitPalette(cot)
    else
      return g_.getPalette()
    end
  end

  function cam(x, y)
    g_.translate(-x, -y)
  end

  local sprSheet = image.newImage(8, 8)
  local sheetWidth = 1
  local sheetMargin = 0
  local sprArea = 8
  local sprSpacing = 0

  function sheet(file, a, m, s)
    sprArea = a or 8
    sprSpacing = s or 0
    sheetMargin = m or 0

    local sw, sh
    sprSheet, sw, sh = rif.createImage(file)
    sheetWidth = (sw - sheetMargin * 2 + sprSpacing) / (a + sprSpacing)
  end

  function spr(x, y, dx, dy)
    sprSheet:render(dx, dy,
      sheetMargin + (x - 1) * (sprArea + sprSpacing),
      sheetMargin + (y - 1) * (sprArea + sprSpacing),
      sprArea, sprArea)
  end

  pix = g_.drawPixel
  rect = g_.drawRectangle
  cls = g_.clear
  pixb = g_.blitPixels
  push = g_.push
  pop = g_.pop
  pget = g_.getPixel
  swap = g_.swap
  trans = g_.translate

  function _eventDefault(e, k)
    if e == "key" and k == "escape" then
      _running = false
    end
  end
end

local opl = pal()

local palette = {}

local palStr = [[
  8   8   8 255	Untitled
 15  15  15 255	Untitled
 18  18  18 255	Untitled
 24  24  24 255	Untitled
 36  36  36 255	Untitled
 86  86  86 255	Untitled
157 157 157 255	Untitled
236 236 236 255	Untitled
 14  20  15 255	Untitled
 35  43  17 255	Untitled
 45  54  23 255	Untitled
 33  11  33 255	Untitled
]]
local i = 0
for n in palStr:gmatch("%d+%s+%d+%s+%d+") do
  local ri = 1
  palette[i] = {}
  for j in n:gmatch("%d+") do
    palette[i][ri] = tonumber(j)
    ri = ri + 1
  end

--  print("Pal[" .. i .."] = {" .. table.concat(palette[i], ", ") .. "}")

  i = i + 1
end

pal(palette)





local rif = dofile("/lib/rif.lua")
local maps = dofile("/lib/map.lua")

local sheet = rif.createImage("jam.rif")

local map = maps.parse("jam.tmx", {sheet})

function _draw()
  cls()

  maps.render(map)

  swap()
end

local eq = {}
local last = os.clock()
while _running do
  while true do
    local a = {coroutine.yield()}
    if not a[1] then break end
    table.insert(eq, a)
  end

  while #eq > 0 do
    local e = table.remove(eq, 1)
    if _event then
      _event(unpack(e))
    end

    _eventDefault(unpack(e))
  end

  if _update then
    _update(os.clock() - last)
    last = os.clock()
  end

  if _draw then
    _draw()
  end
end

pal(opl)
