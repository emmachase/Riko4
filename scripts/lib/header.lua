local pix, rectFill, rect, cls, pal, pixb, cam, push, sheet, spr, pop, pget, swap, trans, _eventDefault, _cleanup
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
    sheetWidth = (sw - sheetMargin * 2 + sprSpacing) / (sprArea + sprSpacing)
  end

  function spr(x, y, dx, dy)
    sprSheet:render(dx, dy,
      sheetMargin + (x - 1) * (sprArea + sprSpacing),
      sheetMargin + (y - 1) * (sprArea + sprSpacing),
      sprArea, sprArea)
  end

  function rect(x, y, w, h, c)
    g_.drawRectangle(x, y        , w, 1, c)
    g_.drawRectangle(x, y + h - 1, w, 1, c)

    g_.drawRectangle(x        , y + 1, 1, h - 2, c)
    g_.drawRectangle(x + w - 1, y + 1, 1, h - 2, c)
  end

  pix = g_.drawPixel
  rectFill = g_.drawRectangle
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
