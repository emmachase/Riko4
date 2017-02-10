--[[
  States

  1 - Paint screen          NYI
  2 - File creation         NYF
  3 - File open             NYI
  4 - File save             NYI
]]
local state = 1
local running = true
local DEBUG = true

local lang = "en"
local locale = {
  en = {
    title = "Wow look its Ink a really cool program",
    new = "New",
    load = "Load",
    exit = "Exit",
    newFile = "New File",
    fiName = "Filename",
    width = "Width",
    height = "Height",
    trans = "Tranparency",
    clrclr = "Clear color",
    ok = "OK",
    cancel = "Cancel",
    colors = "Colors",
    tools = "Tools",
    pencil = "Pencil"
  }
}

-- Baked images
local backMatte, transMatte
do
  backMatte = image.newImage(344, 200)
  local backBuffer = {}
  for i = 1, 200 do
    for j = 1, 344 do
      backBuffer[(i - 1)*344 + j] = ((i + (j / 2)) % 2 == 1) and 7 or 6
    end
  end
  backMatte:blitPixels(0, 0, 344, 200, backBuffer)
  backMatte:flush()

  transMatte = image.newImage(351, 211)
  local transBuffer = {}
  for i = 1, 351 do
    for j = 1, 211 do
      transBuffer[(j - 1)*351 + i] = ((math.floor((i - 1) / 6) + math.floor((j - 1) / 6)) % 2 == 1) and 16 or 7
    end
  end
  transMatte:blitPixels(0, 0, 351, 211, transBuffer)
  transMatte:flush()
end

local canvArea = image.newImage(340, 180)


-- Annnnd some inline helper classes ;)

local window = {}
do -- Little windows

  function window.new(title, w, h, x, y)
    x = x or 0
    y = y or 0

    local t = {x = x, y = y, title = title, w = w, h = h, canv = image.newImage(w, h),
    mdn = false}
    setmetatable(t, {__index = window})

    t.canv:clear()

    return t
  end

  function window:mousePressed(x, y, b)
    if x >= self.x and x < self.x + self.w + 2 then
      if y >= self.y then
        if y < self.y + 10 then
          -- Bar
          self.mdn = b == 1
          return true
        elseif y < self.y + self.h + 10 and x > self.x and x < self.x + self.w + 1 then
          -- Content
          if self.mousePressedCallback then
            self.mousePressedCallback(x - self.x - 1, y - self.y - 9, b)
          end
          return true
        end
      end
    end
    return false
  end

  function window:mouseReleased(x, y, b)
    if x >= self.x and x < self.x + self.w + 2 then
      if y >= self.y then
        if y < self.y + 10 then
          -- Bar
          self.mdn = false
          return true
        elseif y < self.y + self.h + 10 then
          -- Content
          if self.mouseReleasedCallback then
            self.mouseReleasedCallback(x - self.x - 1, y - self.y - 9, b)
          end
          return true
        end
      end
    end
    return false
  end

  function window:mouseMoved(x, y, dx, dy)
    if self.mdn then
      self.x = self.x + dx
      self.y = self.y + dy
      return true
    end
    return false
  end

  function window:drawSelf()
    gpu.drawRectangle(self.x, self.y, self.w + 2, self.h + 10, 1)
    write(self.title, self.x, self.y, 16)
    self.canv:render(self.x + 1, self.y + 9)
  end

  function window:flush()
    self.canv:flush()
  end

  function window:drawRectangle(x, y, w, h, c)
    self.canv:drawRectangle(x, y, w, h, c)
  end

  function window:free()
    self.canv:free()
  end
end

local function clamp(v, mi, mx)
  if mi and not mx then
    return v < mi and mi or v
  elseif mx and not mi then
    return v > mx and mx or v
  else
    return v < mi and mi or (v > mx and mx or v)
  end
end

local function rightWrite(text, x, y, c)
  write(text, x - (#text)*7, y, c)
end

---== State variables

local width = 32
local height = 32

local modalWid = 180
local modalHei = 100

local imgHeight = 30
local imgWidth = 42

local drawOffX = 145
local drawOffY = 75

local zoomFactor = 1

local mouseDown = {false, false, false}

local toolPalette = window.new(locale[lang].tools, 60, 80)
local colorPalette = window.new(locale[lang].colors, 6*4 + 20, 6*4)

local windows = {toolPalette, colorPalette}

local function wep(name, ...)
  for i = 1, #windows do
    local win = windows[i]
    if win[name] then
      if win[name](win, ...) then
        return
      end
    end
  end
end

local primColor = 4
local secColor = 9

local mousePosX = 0
local mousePosY = 0

local workingImage = {}

if DEBUG then
  -- Temp
  for i = 1, imgWidth do
    workingImage[i] = {}
    for j = 1, imgHeight do
      workingImage[i][j] = 0
    end
  end
end

colorPalette.mousePressedCallback = function(x, y, b)
  print(x)
  if x < 24 then
    local offs = math.floor(y / 6)
    local ind = (offs * 4) + math.floor(x / 6) + 1
    if b == 1 then
      primColor = ind
    elseif b == 3 then
      secColor = ind
    end
  end
end

local function convertScrn2I(x, y)
  return math.floor((x - drawOffX) / zoomFactor), math.floor((y - drawOffY - 10) / zoomFactor)
end

local function drawContent()
  if state == 1 then
    canvArea:clear()

    canvArea:drawRectangle(0, 0, 340, 200, 1)

    backMatte:copy(canvArea, drawOffX % 4 - 4, drawOffY % 2 - 2)

    transMatte:copy(canvArea,
      clamp(drawOffX, 0), clamp(drawOffY, 0),
        imgWidth * zoomFactor - clamp(-drawOffX, 0),
        imgHeight * zoomFactor - clamp(-drawOffY, 0),
      clamp(-drawOffX, 0) % 12, clamp(-drawOffY, 0) % 12 )

    canvArea:flush()
    canvArea:render(0, 10)

    -- Render painting here

    --gpu.blitPixels()

    for i = 1, imgWidth do
      for j = 1, imgHeight do
        if workingImage[i][j] ~= 0 then
          gpu.drawRectangle((i - 1) * zoomFactor + drawOffX, (j - 1) * zoomFactor + drawOffY + 10, zoomFactor, zoomFactor, workingImage[i][j])
        end
      end
    end

    local transX, transY = convertScrn2I(mousePosX, mousePosY)
    gpu.drawRectangle((transX * zoomFactor) + drawOffX, (transY * zoomFactor) + drawOffY + 10, zoomFactor, zoomFactor, primColor)

    -- Done

    gpu.drawRectangle(0, 0, 340, 10, 7)
    gpu.drawRectangle(0, 190, 340, 10, 7)

    rightWrite(tostring(zoomFactor * 100) .. "%", 338, 191)


    colorPalette:drawRectangle(0, 0, 6*4 + 20, 6*4, 7)
    --colorPalette:drawRectangle(24, 0, 1, 6*4, 7)

    for i=1, 16 do
      colorPalette:drawRectangle((i - 1) % 4 * 6, math.floor((i - 1) / 4) * 6, 6, 6, i)
    end

    colorPalette:drawRectangle(30, 6, 12, 12, 16)
    colorPalette:drawRectangle(27, 2, 12, 12, 16)

    colorPalette:drawRectangle(31, 7, 10, 10, secColor)
    colorPalette:drawRectangle(28, 3, 10, 10, primColor)

    colorPalette:flush()

    colorPalette:drawSelf()

    toolPalette:drawRectangle(0, 0, 60, 80, 7)

    toolPalette:drawRectangle(0, 1, 60, 10, 6)

    write(locale[lang].pencil, 2, 2, 16, toolPalette.canv)

    toolPalette:flush()

    toolPalette:drawSelf()
  elseif state == 2 then
    backMatte:render(0, 0)

    local tpb = (200 - modalHei) / 2 - 1
    local stx = (340 - modalWid) / 2 - 1
    gpu.drawRectangle(stx, tpb, modalWid, modalHei, 7)
    gpu.drawRectangle(stx, tpb - 10, modalWid, 10, 6)

    local xx = #locale[lang].newFile * 7
    write(locale[lang].newFile, (340 - xx) / 2 - 1, tpb - 9, 16)

    write(locale[lang].fiName, stx + 2, tpb + 4, 16)
    xx = #locale[lang].fiName * 7
    gpu.drawRectangle(stx + xx + 6, tpb + 4, modalWid - xx - 10, 8, 6)
    --[[ DEBUG ]] write("test.rif", stx + xx + 6, tpb + 4, 16)

    -- This part is mint
    xx = #locale[lang].width * 7
    write(locale[lang].width, stx + 2, tpb + 14, 16)
    gpu.drawRectangle(stx + xx + 6, tpb + 14, (modalWid / 2) - xx - 10, 8, 6)
    write(tostring(width), stx + xx + 6 + ((modalWid / 2) - xx - 10 - (#tostring(width) * 7)) / 2, tpb + 14, 16)

    xx = #locale[lang].height * 7
    write(locale[lang].height, stx + 2 + (modalWid) / 2, tpb + 14, 16)
    gpu.drawRectangle(stx + xx + 6 + (modalWid) / 2, tpb + 14, (modalWid / 2) - xx - 10, 8, 6)
    write(tostring(height), stx + xx + 6 + ((modalWid / 2) - xx - 10 - (#tostring(height) * 7)) / 2 + (modalWid) / 2, tpb + 14, 16)

    write(locale[lang].trans, stx + 3, tpb + 34, 16)
    xx = #locale[lang].trans * 7
    gpu.drawRectangle(stx + 11 + xx, tpb + 34, 8, 8, 6)
    write("X", stx + 10 + xx, tpb + 34, 16)

    write(locale[lang].clrclr, stx + 3, tpb + 44, 16)
    xx = #locale[lang].trans * 7
    gpu.drawRectangle(stx + 11 + xx, tpb + 44, 8, 8, 12)

    xx = #locale[lang].cancel * 7
    gpu.drawRectangle(stx + modalWid - xx - 6, tpb + modalHei - 12, xx + 4, 8, 6)
    write(locale[lang].cancel, stx + modalWid - xx - 4, tpb + modalHei - 12, 16)

    local xx2 = #locale[lang].ok * 7
    gpu.drawRectangle(stx + modalWid - xx2 - xx - 13, tpb + modalHei - 12, xx2 + 5, 8, 6)
    write(locale[lang].ok, stx + modalWid - xx2 - xx - 12, tpb + modalHei - 12, 16)
  end
end

local function drawQ(x, y, b)
  if b == 2 then
    return
  end

  local tx, ty = convertScrn2I(x, y)
  if tx >= 0 and ty >= 0 and tx < imgWidth and ty < imgHeight and (b == 1 or b == 3)then
    workingImage[tx + 1][ty + 1] = (b == 1) and primColor or (b == 3) and secColor
  end
end

local function processEvent(ev, p1, p2, p3, p4)
  if state == 1 then
    -- Painting

    if ev == "key" then
      if p1 == "Escape" then
        running = false
      elseif p1 == "Left" then
        drawOffX = drawOffX + 5
      elseif p1 == "Right" then
        drawOffX = drawOffX - 5
      elseif p1 == "Up" then
        drawOffY = drawOffY + 5
      elseif p1 == "Down" then
        drawOffY = drawOffY - 5
      end
    elseif ev == "mousePressed" then
      if mouseDown[2] or not wep("mousePressed", p1, p2, p3) then
        mouseDown[tonumber(p3)] = true
        drawQ(p1, p2, p3)
      end
    elseif ev == "mouseReleased" then
      if mouseDown[2] or not wep("mouseReleased", p1, p2, p3) then
        mouseDown[tonumber(p3)] = false
        drawQ(p1, p2, p3)
      end
    elseif ev == "mouseMoved" then
      if mouseDown[2] or not wep("mouseMoved", p1, p2, p3, p4) then
        if mouseDown[2] then
          -- Move draw offsets
          drawOffX = drawOffX + p3
          drawOffY = drawOffY + p4
        end
        drawQ(p1, p2, mouseDown[1] and 1 or (mouseDown[3] and 3 or 0))
      end

      mousePosX = p1
      mousePosY = p2
    elseif ev == "mouseWheel" then
      local px, py = convertScrn2I(mousePosX, mousePosY)
      zoomFactor = clamp(zoomFactor + p1, 1)
      drawOffX = mousePosX - px * zoomFactor
      drawOffY = mousePosY - py * zoomFactor
    end
  elseif state == 2 then
    -- File creation

    if ev == "key" then
      if p1 == "Escape" then
        running = false
      end
    end
  end
end

local eventQueue = {}

drawContent()
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

backMatte:free()
transMatte:free()
wep("free")