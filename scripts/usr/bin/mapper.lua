--HELP: \b6Usage: \b16mapper \n
-- \b6Description: \b7Map creation tool

local rif = dofile("/lib/rif.lua")

local running = true
local w, h = gpu.width, gpu.height

local sprsht = rif.createImage("/home/map.rif")

local selSheet = rif.createImage("/home/melon.rif")
local sheetPS = 8
local sheetPD = 0

local seling = false
local selSX = 0
local selSY = 0
local selEW = 0
local selEH = 0

local move = false
local moffx = 0
local moffy = 0

local selected = {img = image.newImage(0, 0)}

local objCache = {}
local objects = {}

local cur
do
  local curRIF = "\82\73\86\2\0\6\0\7\1\0\0\0\0\0\0\0\0\0\0\1\0\0\31\16\0\31\241\0\31\255\16\31\255\241\31\241\16\1\31\16\61\14\131\0\24\2"
  local rifout, cw, ch = rif.decode1D(curRIF)
  cur = image.newImage(cw, ch)
  cur:blitPixels(0, 0, cw, ch, rifout)
  cur:flush()
end

local mx, my = 0, 0

local selectMode = false
local currentPlaced = {}

local rectT = 0
local function outRect(x, y, w, h)
  rectT = (rectT + 1) % 16
  if w > 0 and h > 0 then
    gpu.drawRectangle(x, y, w, 1, 16)
    gpu.drawRectangle(x, y + h - 1, w, 1, 16)
    
    for i = math.floor(rectT / 4), w, 4 do
      gpu.drawPixel(x + i, y, 1)
      gpu.drawPixel(x + w - i, y + h - 1, 1)
    end

    gpu.drawRectangle(x, y, 1, h, 16)
    gpu.drawRectangle(x + w - 1, y, 1, h, 16)

    for i = math.floor(rectT / 4), h, 4 do
      gpu.drawPixel(x, y + h - i, 1)
      gpu.drawPixel(x + w - 1, y + i, 1)
    end
  end
end

local function getSStr()
  return selSX .. "x" .. selSY .. "x" .. selEW .. "x" .. selEH
end

local function activateSelection()
  selected = {}

  if objCache[getSStr()] then
    selected.img = objCache[getSStr()]
  else
    local outImg = image.newImage(sheetPS * selEW, sheetPS * selEH)

    for i = selSX, selSX + selEW - 1 do
      for j = selSY, selSY + selEH - 1 do
        selSheet:copy(outImg, (i - selSX) * sheetPS,
                              (j - selSY) * sheetPS,
                              sheetPS, sheetPS,
                              i * (sheetPS + sheetPD),
                              j * (sheetPS + sheetPD))
      end
    end

    outImg:flush()
    selected.img = outImg
    objCache[getSStr()] = outImg
  end
end

local function checkIntersect(a, b, c, d, w, h)
  if c >= a and c < a + w then
    if d >= b and d < b + h then
      return true
    end
  end

  if a >= c and a < c + w then
    if b >= d and b < d + h then
      return true
    end
  end

  return false
end

local function draw()
  gpu.clear()

  if selectMode then
    if selSheet then
      selSheet:render(0, 8)
    end

    outRect(selSX * (sheetPS + sheetPD), selSY * (sheetPS + sheetPD) + 8,
            selEW * (sheetPS + sheetPD), selEH * (sheetPS + sheetPD), 8)
  else
    for i = moffx % sheetPS, w, sheetPS do
      gpu.drawRectangle(i, 8, 1, h - 8, 6)
    end

    for i = moffy % sheetPS, h, sheetPS do
      gpu.drawRectangle(0, i + 8, w, 1, 6)
    end

    if (moffy + 8) % h ~= h - 1 then
      gpu.drawRectangle(0, (moffy + 8) % h, w, 1, 8)
    end
    
    if moffx % w ~= w - 1 then
      gpu.drawRectangle(moffx % w, 8, 1, h - 8, 8)
    end

    gpu.drawRectangle(0, moffy + 8, w, 1, 11)
    gpu.drawRectangle(moffx, 8, 1, h - 8, 11)

    for i = 1, #objects do
      local obj = objects[i]

      obj.obj:render(obj.x * sheetPS + moffx + 1, obj.y * sheetPS + 9 + moffy)
    end

    selected.img:render(math.floor((mx - moffx) / sheetPS) * sheetPS + moffx + 1,
                        math.floor((my - 8 - moffy) / sheetPS) * sheetPS + 9 + moffy)
  end

  gpu.drawRectangle(0, 0, w, 8, 7)

  sprsht:render(w - 8, 0, 0, 0, 8, 8)

  cur:render(mx, my)

  gpu.swap()
end

local function update(dt)

end

local function event(e, ...)
  if e == "key" then
    local k = ...
    if k == "escape" then
      running = false
    elseif k == "tab" then
      selectMode = true
    end
  elseif e == "keyUp" then
    local k = ...
    if k == "tab" then
      selectMode = false
    end
  elseif e == "mouseMoved" then
    local x, y, dx, dy = ...
    mx, my = x, y

    if move then
      moffx = moffx + dx
      moffy = moffy + dy
    end

    if selectMode and seling then
      y = y - 8

      local cx = math.floor(x / (sheetPS + sheetPD))
      local cy = math.floor(y / (sheetPS + sheetPD))

      selEW = cx - selSX + 1
      selEH = cy - selSY + 1
    elseif not selectMode then
      if #currentPlaced > 0 then
        x = x - moffx
        y = y - 8 - moffy

        local x = math.floor(x / sheetPS)
        local y = math.floor(y / sheetPS)

        local good = true
        for i = 1, #currentPlaced do
          if checkIntersect(x, y, currentPlaced[i].x, currentPlaced[i].y, selEW, selEH) then
            good = false
          end
        end

        if good then
          local obj = objCache[getSStr()]

          objects[#objects + 1] = {
            obj = obj,
            x = x,
            y = y
          }

          currentPlaced[#currentPlaced + 1] = {
            x = x,
            y = y
          }
        end
      end
    end
  elseif e == "mousePressed" then
    local x, y, b = ...
    if b == 1 then
      if selectMode then
        seling = true

        y = y - 8

        selSX = math.floor(x / (sheetPS + sheetPD))
        selSY = math.floor(y / (sheetPS + sheetPD))
        selEW = 1
        selEH = 1
      else
        x = x - moffx
        y = y - 8 - moffy

        local obj = objCache[getSStr()]

        objects[#objects + 1] = {
          obj = obj,
          x = math.floor(x / sheetPS),
          y = math.floor(y / sheetPS)
        }

        currentPlaced = {
          {
            x = math.floor(x / sheetPS),
            y = math.floor(y / sheetPS)
          }
        }
      end
    elseif b == 2 then
      move = true
    end
  elseif e == "mouseReleased" then
    local x, y, b = ...
    if b == 1 then
      seling = false
      currentPlaced = {}

      activateSelection()
    elseif b == 2 then
      move = false
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
