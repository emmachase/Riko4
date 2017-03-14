local RIF = dofile("../lib/rif.lua")

local running = true

local lang = "en"
local locale = {
  en = {
    new = "New",
    save = "Save",
    saveas = "Save As",
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
    pencil = "Pencil",
    eraser = "Eraser",
    file = "File",
    edit = "Edit",
    view = "View",
    undo = "Undo",
    redo = "Redo",
    cut = "Cut",
    copy = "Copy",
    paste = "Paste",
    settings = "Settings",
    fill = "Fill",
    saved = "Saved",
    failSave = "Failure saving",
    loaded = "Loaded",
    failLoad = "Failure loading"
  }
}

-- Baked images
local backMatte, transMatte
do
  backMatte = image.newImage(344, 200)
  local backBuffer = {}
  for i = 1, 200 do
    for j = 1, 344 do
      backBuffer[(i - 1)*344 + j] = ((i + (j / 2)) % 2 == 1) and 6 or 1
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

  function window:mousePressedInternal(x, y, b)
    local out = true
    if self.mousePA then
      out = self.mousePA(x - self.x - 1, y - self. y - 9, b)
    end

    if out and x >= self.x and x < self.x + self.w + 2 then
      if y >= self.y then
        if y < self.y + 9 then
          -- Bar
          self.mdn = b == 1
          return true
        elseif y < self.y + self.h + 10 and x > self.x and x < self.x + self.w + 1 then
          -- Content
          if self.mousePressed then
            self.mousePressed(x - self.x - 1, y - self.y - 9, b)
          end
          return true
        end
      end
    end

    return false
  end

  function window:mouseReleased(x, y, b)
    local out = true
    if self.mouseRA then
      out = self.mouseRA(x - self.x - 1, y - self. y - 9, b)
    end

    if out and x >= self.x and x < self.x + self.w + 2 then
      if y >= self.y then
        if y < self.y + 9 then
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

  function window:mouseMoved(_, _, dx, dy)
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

local imgHeight = 30
local imgWidth = 42

local drawOffX = 145
local drawOffY = 75

local zoomFactor = 1

local mouseDown = {false, false, false}

local toolPalette = window.new(locale[lang].tools, 60, 80, 340 - 65, 60)
local colorPalette = window.new(locale[lang].colors, 6*4 + 20, 6*4, 4, 60)
local pathDialog = window.new(locale[lang].save, 100, 20, 6, 200 - 46)
local newDialog = window.new(locale[lang].new, 99, 24, 6, 200 - 50)

local pathVars = {
  str = "",
  cpos = 0,
  visible = false,
  time = os.clock(),
  focus = false,
  mode = 1
}

local newVars = {
  wnum = "",
  hnum = "",
  cposw = 0,
  cposh = 0,
  visible = false,
  time = os.clock(),
  focus = false,
  mode = 1
}

local windows = {newDialog, pathDialog, toolPalette, colorPalette }

local function wep(name, ...)
  for i = 1, #windows do
    local win = windows[i]
    if win[name] then
      if win[name](win, ...) then
        return true
      end
    end
  end
end

local primColor = 4
local secColor = 9

local workingImage = {}
local dispImage

local function constructImage()
  for i = 1, imgWidth do
    workingImage[i] = {}
    for j = 1, imgHeight do
      workingImage[i][j] = 0
    end
  end
  dispImage = image.newImage(imgWidth, imgHeight)
end
constructImage()

local function exists(filename)
  local handle = io.open(filename, "r")
  if handle then
    handle:close()
    return true
  end

  return false
end

local csaved
local keyMods = {ctrl = false, shift = false, alt = false}
local status = ""
local statusPos = 0
local statusRest = -9
local statusTime = os.clock()

local function saveImage(name)
  if exists(name) then
    --TODO: Warn user about to overwrite
    print("TODO: Warn user about to overwrite through a modal or soemthign")
  end

  local oData = RIF.encode(workingImage, imgWidth, imgHeight)
  local handle = io.open(name, "w")
  if not handle then
    status = locale[lang].failSave
    statusPos = statusRest
    statusTime = os.clock()
    return false
  end
  handle:write(oData)
  handle:close()

  csaved = name
  status = locale[lang].saved
  statusPos = statusRest
  statusTime = os.clock()
end

local function toBlitTable(bData)
  local out = {}
  for i = 1, #bData[1] do
    for j = 1, #bData do
      out[#out + 1] = bData[j][i] == 0 and -1 or bData[j][i]
    end
  end

  return out
end

local function loadImage(name)
  if exists(name) then
    local handle = io.open(name, "rb")
    -- Dont need to check handle integrity, as that is done in `exists`
    local data = handle:read("*a")
    handle:close()

    local rifData, w, h
    local s = pcall(function()
      rifData, w, h = RIF.decode1D(data)
    end)
    if not s then
      status = locale[lang].failLoad
      statusPos = statusRest
      statusTime = os.clock()
      return false
    end

    imgWidth = w
    imgHeight = h

    workingImage = {}

    local c = 1
    for i = 1, h do
      for j = 1, w do
        if not workingImage[j] then
          workingImage[j] = {}
        end
        workingImage[j][i] = rifData[c]
        if workingImage[j][i] == -1 then
          workingImage[j][i] = 0
        end
        c = c + 1
      end
    end

    dispImage = image.newImage(w, h)
    dispImage:blitPixels(0, 0, w, h, rifData)
    dispImage:flush()

    csaved = name
    status = locale[lang].loaded
    statusPos = statusRest
    statusTime = os.clock()
  else
    status = locale[lang].failLoad
    statusPos = statusRest
    statusTime = os.clock()
    return false
  end
end

local function convertScrn2I(x, y)
  return math.floor((x - drawOffX) / zoomFactor), math.floor((y - drawOffY - 10) / zoomFactor)
end

local function drawQ(x, y, b)
  if b == 2 then
    return
  end

  local tx, ty = convertScrn2I(x, y)
  if tx >= 0 and ty >= 0 and tx < imgWidth and ty < imgHeight and (b == 1 or b == 3)then
    workingImage[tx + 1][ty + 1] = (b == 1) and primColor or (b == 3) and secColor
    dispImage:blitPixels(0, 0, imgWidth, imgHeight, toBlitTable(workingImage))
    dispImage:flush()
  end
end

local function floodFill(x, y, c)
  local control = workingImage[x][y]
  local fillQueue = {{x, y}}
  local ct = 0 -- Sanity check
  while #fillQueue > 0 and ct < 10000 do
    ct = ct + 1
    local pop = table.remove(fillQueue, #fillQueue)
    local px, py = pop[1], pop[2]
    workingImage[px][py] = c

    if px < imgWidth  and workingImage[px + 1][py] == control then fillQueue[#fillQueue + 1] = {px + 1, py} end
    if px > 1         and workingImage[px - 1][py] == control then fillQueue[#fillQueue + 1] = {px - 1, py} end
    if py < imgHeight and workingImage[px][py + 1] == control then fillQueue[#fillQueue + 1] = {px, py + 1} end
    if py > 1         and workingImage[px][py - 1] == control then fillQueue[#fillQueue + 1] = {px, py - 1} end
  end

  dispImage:blitPixels(0, 0, imgWidth, imgHeight, toBlitTable(workingImage))
  dispImage:flush()
end

local closeHover = false

local mousePosX = 0
local mousePosY = 0
local selectedTool = 1
local toolVars = {
  pencil = {
    mouseDown = { false, false, false },
    mposx = -1,
    mposy = -1
  },
  eraser = {
    mouseDown = { false, false, false },
    mposx = -1,
    mposy = -1,
    state = 1
  },
  fill = {
    mposx = -1,
    mposy = -1,
    locx = -1,
    locy = -1,
    state = 1
  }
}
local toolList = {
  {
    name = locale[lang].pencil,
    mouseDown = function(x, y, b)
      toolVars.pencil.mouseDown[b] = true
      drawQ(x, y, b)
    end,
    mouseUp = function(x, y, b)
      toolVars.pencil.mouseDown[b] = false
      drawQ(x, y, b)
    end,
    mouseMoved = function(x, y)
      toolVars.pencil.mposx = x
      toolVars.pencil.mposy = y

      drawQ(x, y, toolVars.pencil.mouseDown[1] and 1 or (toolVars.pencil.mouseDown[3] and 3 or 0))
    end,
    draw = function()
      local transX, transY = convertScrn2I(toolVars.pencil.mposx, toolVars.pencil.mposy)
      gpu.drawRectangle((transX * zoomFactor) + drawOffX, (transY * zoomFactor) + drawOffY + 10, zoomFactor, zoomFactor,
        toolVars.pencil.mouseDown[3] and secColor or primColor)
    end
  },
  {
    name = locale[lang].eraser,
    mouseDown = function(x, y, b)
      toolVars.eraser.mouseDown[b] = true
      local tx, ty = convertScrn2I(x, y)
      if tx >= 0 and ty >= 0 and tx < imgWidth and ty < imgHeight and b == 1 then
        workingImage[tx + 1][ty + 1] = 0
        dispImage:clear()
        dispImage:blitPixels(0, 0, imgWidth, imgHeight, toBlitTable(workingImage))
        dispImage:flush()
      end
    end,
    mouseUp = function(x, y, b)
      toolVars.eraser.mouseDown[b] = false
      local tx, ty = convertScrn2I(x, y)
      if tx >= 0 and ty >= 0 and tx < imgWidth and ty < imgHeight and b == 1 then
        workingImage[tx + 1][ty + 1] = 0
        dispImage:clear()
        dispImage:blitPixels(0, 0, imgWidth, imgHeight, toBlitTable(workingImage))
        dispImage:flush()
      end
    end,
    mouseMoved = function(x, y)
      toolVars.eraser.mposx = x
      toolVars.eraser.mposy = y

      if toolVars.eraser.mouseDown[1] then
        local tx, ty = convertScrn2I(x, y)
        if tx >= 0 and ty >= 0 and tx < imgWidth and ty < imgHeight then
          workingImage[tx + 1][ty + 1] = 0
          dispImage:clear()
          dispImage:blitPixels(0, 0, imgWidth, imgHeight, toBlitTable(workingImage))
          dispImage:flush()
        end
      end
    end,
    draw = function()
      local transX, transY = convertScrn2I(toolVars.eraser.mposx, toolVars.eraser.mposy)
      gpu.drawRectangle((transX * zoomFactor) + drawOffX, (transY * zoomFactor) + drawOffY + 10, zoomFactor, zoomFactor, toolVars.eraser.state)
      toolVars.eraser.state = (toolVars.eraser.state) % 16 + 1
    end
  },
  {
    name = locale[lang].fill,
    mouseDown = function(x, y)
      local tx, ty = convertScrn2I(x, y)
      toolVars.fill.locx = tx
      toolVars.fill.locy = ty
    end,
    mouseUp = function(x, y, b)
      if b % 2 == 1 then
        local tx, ty = convertScrn2I(x, y)
        if toolVars.fill.locx == tx and toolVars.fill.locy == ty then
          if tx >= 0 and ty >= 0 and tx < imgWidth and ty < imgHeight then
            floodFill(tx + 1, ty + 1, b == 3 and secColor or primColor)
          end
        end
      end
    end,
    mouseMoved = function(x, y)
      toolVars.fill.mposx = x
      toolVars.fill.mposy = y
    end,
    draw = function()
      local transX, transY = convertScrn2I(toolVars.fill.mposx, toolVars.fill.mposy)
      local fstate = math.floor(toolVars.fill.state / 4)
      gpu.drawRectangle((transX * zoomFactor) + drawOffX - fstate, (transY * zoomFactor) + drawOffY + 10 - fstate,
        zoomFactor + fstate * 2, zoomFactor + fstate * 2, primColor)
      toolVars.fill.state = (toolVars.fill.state) % 16 + 1
    end
  }
}

colorPalette.mousePressed = function(x, y, b)
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

toolPalette.mousePressed = function(_, y)
  if y == 0 then return end
  local newInd = math.floor((y - 1) / 10) + 1
  if newInd <= #toolList then
    selectedTool = newInd
  end
end

pathDialog.mousePA = function(x, y)
  pathVars.focus = x > 0 and x < pathDialog.w
               and y > 0 and y < pathDialog.h
  return pathVars.visible
end

pathDialog.mouseRA = function()
  return pathVars.visible
end

newDialog.mousePA = function(x, y)
  newVars.focus = x > 0 and x < newDialog.w
              and y > 0 and y < newDialog.h
  return newVars.visible
end

newDialog.mousePressed = function(x)
  local n = x > math.floor(newDialog.w / 2) and 2 or 1
  if newVars.mode ~= n then
    newVars.mode = n
    newVars.time = os.clock()
  end
end

newDialog.mouseRA = function()
  return newVars.visible
end

local function openPath(mode, str)
  pathVars.visible = true
  pathVars.focus = true
  pathVars.mode = mode
  pathVars.str = csaved or ""
  pathVars.cpos = #pathVars.str
  pathDialog.title = locale[lang][str]

  newVars.visible = false
  newVars.focus = false
end

local function openNew()
  newVars.visible = true
  newVars.focus = true
  newVars.mode = 1
  newVars.str = csaved or ""
  newVars.cpos = #newVars.str

  pathVars.visible = false
  pathVars.focus = false
end

local selToolbar = 1
local toolbarActive = false
local toolbar = {
  {
    name = locale[lang].file,
    actions = {
      {locale[lang].new, function() openNew() end},
      {locale[lang].save, function() if csaved then saveImage(csaved) else openPath(1, "save") end end},
      {locale[lang].saveas, function() openPath(1, "save") end},
      {locale[lang].load, function() openPath(2, "load") end},
      {locale[lang].exit, function() running = false end}
    }
  },
  {
    name = locale[lang].edit,
    actions = {
      {locale[lang].undo},
      {locale[lang].redo},
      {locale[lang].cut},
      {locale[lang].copy},
      {locale[lang].paste}
    }
  },
  {
    name = locale[lang].view,
    actions = {
      {locale[lang].tools},
      {locale[lang].colors},
      {locale[lang].settings}
    }
  }
}

do
  local cx = 10
  for i=1, #toolbar do
    local intmax = 0
    local ptl = toolbar[i]
    local pt = ptl.actions

    for j=1, #pt do
      if #pt[j][1] > intmax then
        intmax = #pt[j][1]
      end
    end
    toolbar[i].maxACL = intmax

    toolbar[i].offset = cx
    cx = cx + #ptl.name * 7 + 16
  end
end

local function drawContent()
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

    -- for i = 1, imgWidth do
    --   for j = 1, imgHeight do
    --     if workingImage[i][j] ~= 0 then
    --       gpu.drawRectangle((i - 1) * zoomFactor + drawOffX, (j - 1) * zoomFactor + drawOffY + 10, zoomFactor, zoomFactor, workingImage[i][j])
    --     end
    --   end
    -- end

    dispImage:render(drawOffX, drawOffY + 10, 0, 0, imgWidth, imgHeight, zoomFactor)

    toolList[selectedTool].draw()

    -- Done

    colorPalette:drawRectangle(0, 0, 6*4 + 20, 6*4, 6)

    for i=1, 16 do
      colorPalette:drawRectangle((i - 1) % 4 * 6, math.floor((i - 1) / 4) * 6, 6, 6, i)
    end

    colorPalette:drawRectangle(30, 6, 12, 12, 16)
    colorPalette:drawRectangle(27, 2, 12, 12, 16)

    colorPalette:drawRectangle(31, 7, 10, 10, secColor)
    colorPalette:drawRectangle(28, 3, 10, 10, primColor)

    colorPalette:flush()

    colorPalette:drawSelf()

    toolPalette:drawRectangle(0, 0, 60, 80, 6)

    toolPalette:drawRectangle(0, 1 + (10 * (selectedTool - 1)), 60, 10, 1)

    for i=1, #toolList do
      write(toolList[i].name, 2, 2 + (10 * (i - 1)), 16, toolPalette.canv)
    end

    toolPalette:flush()

    toolPalette:drawSelf()

    if pathVars.visible then
      pathDialog:drawRectangle(0, 0, 100, 26, 6)

      pathDialog:drawRectangle(1, 1, 98, 10, 1)
      write(pathVars.str, 1, 2, 16, pathDialog.canv)
      if pathVars.focus and math.floor(((os.clock() - pathVars.time) * 2) % 2) == 0 then
        pathDialog:drawRectangle(pathVars.cpos * 7 + 3, 9, 4, 1, 16)
      end

      pathDialog:flush()

      pathDialog:drawSelf()
    end

    if newVars.visible then
      newDialog:drawRectangle(0, 0, 100, 26, 6)

      write(locale[lang].width, 1, 2, 16, newDialog.canv)
      newDialog:drawRectangle(1, 13, 48, 10, 1)
      write(newVars.wnum, 1, 14, 16, newDialog.canv)

      write(locale[lang].height, 50, 2, 16, newDialog.canv)
      newDialog:drawRectangle(50, 13, 48, 10, 1)
      write(newVars.hnum, 50, 14, 16, newDialog.canv)

      if newVars.focus and math.floor(((os.clock() - newVars.time) * 2) % 2) == 0 then
        local off = newVars.mode == 1 and 3 or 3 + 49
        local dof = newVars.mode == 1 and newVars.cposw or newVars.cposh
        newDialog:drawRectangle(dof * 7 + off, 21, 4, 1, 16)
      end

      newDialog:flush()

      newDialog:drawSelf()
    end

    gpu.drawRectangle(0, 0, 340, 10, 6)

    local acp
    for i=1, #toolbar do
      local pt = toolbar[i]
      if toolbarActive and i == selToolbar then
        gpu.drawRectangle(pt.offset - 4, 0, #pt.name * 7 + 10, 10, 1)
        acp = pt.offset - 4
      end
      write(pt.name, pt.offset, 1, 16)
    end

    if closeHover then
      gpu.drawRectangle(330, 0, 10, 10, 8)
    end
    write("X", 330, 1, 16)

    if toolbarActive then
      gpu.drawRectangle(acp, 10, toolbar[selToolbar].maxACL * 7 + 16, #toolbar[selToolbar].actions * 10, 7)
      for i=1, #toolbar[selToolbar].actions do
        write(toolbar[selToolbar].actions[i][1], acp + 4, i * 10, 1)
      end
    end

    gpu.drawRectangle(0, 190, 340, 10, 6)

    rightWrite(tostring(zoomFactor * 100) .. "%", 338, 191)

    local transX, transY = convertScrn2I(mousePosX, mousePosY)
    rightWrite(transX .. ", " .. transY, 280, 191)

    if statusPos < 0 then
      write(status, 2, statusPos + 200)
      if os.clock() - statusTime > 0.3 then
        statusPos = statusPos + 1
      end
    end

    gpu.drawRectangle(mousePosX + 1, mousePosY + 1, 3, 3, 1)
    gpu.drawRectangle(mousePosX + 2, mousePosY + 2, 3, 3, 1)
    gpu.drawRectangle(mousePosX + 3, mousePosY + 3, 3, 3, 1)
    gpu.drawPixel(mousePosX + 2, mousePosY + 2, 16)
    gpu.drawPixel(mousePosX + 3, mousePosY + 3, 16)
    gpu.drawPixel(mousePosX + 4, mousePosY + 4, 16)
end

local function processEvent(ev, p1, p2, p3, p4)
  if ev == "char" then
    local c = p1
    if pathVars.focus then
      pathVars.str = pathVars.str:sub(1, pathVars.cpos) .. c .. pathVars.str:sub(pathVars.cpos + 1)
      pathVars.cpos = pathVars.cpos + 1
      pathVars.time = os.clock()
    elseif newVars.focus and tonumber(c) then
      if newVars.mode == 1 then
        newVars.wnum = newVars.wnum:sub(1, newVars.cposw) .. c .. newVars.wnum:sub(newVars.cposw + 1)
        newVars.cposw = newVars.cposw + 1
      else
        newVars.hnum = newVars.hnum:sub(1, newVars.cposh) .. c .. newVars.hnum:sub(newVars.cposh + 1)
        newVars.cposh = newVars.cposh + 1
      end
      newVars.time = os.clock()
    end
  elseif ev == "keyUp" then
    local k = p1
    if k == "Left Ctrl" then
      keyMods.ctrl = false
    elseif k == "Left Shift" then
      keyMods.shift = false
    elseif k == "Left Alt" then
      keyMods.alt = false
    end
  elseif ev == "key" then
    if p1 == "Tab" then
      if newVars.visible and newVars.focus then
        newVars.mode = (newVars.mode % 2) + 1
        newVars.time = os.clock()
      end
    elseif p1 == "S" then
      if keyMods.ctrl then
        if keyMods.shift then
          openPath(1, "save")
        else
          if csaved then
            saveImage(csaved)
          else
            openPath(1, "save")
          end
        end
      end
    elseif p1 == "N" then
      if keyMods.ctrl then
        openNew()
      end
    elseif p1 == "O" then
      if keyMods.ctrl then
        openPath(2, "load")
      end
    elseif p1 == "W" then
      if keyMods.ctrl and keyMods.alt then
        running = false
      end
    elseif p1 == "Left Ctrl" then
      keyMods.ctrl = true
    elseif p1 == "Left Shift" then
      keyMods.shift = true
    elseif p1 == "Left Alt" then
      keyMods.alt = true
    elseif p1 == "Return" then
      if pathVars.focus then
        if pathVars.mode == 1 then
          saveImage(pathVars.str)
        else
          loadImage(pathVars.str)
        end
        pathVars.visible = false
        pathVars.focus = false
      elseif newVars.visible and newVars.focus then
        if tonumber(newVars.wnum) and tonumber(newVars.hnum) then
          imgWidth  = tonumber(newVars.wnum)
          imgHeight = tonumber(newVars.hnum)
          constructImage()
        end
        newVars.visible = false
        newVars.focus = false
      end
    elseif p1 == "Delete" then
      if pathVars.focus then
        if pathVars.cpos < #pathVars.str then
          pathVars.str = pathVars.str:sub(1, pathVars.cpos) .. pathVars.str:sub(pathVars.cpos + 2)
          pathVars.time = os.clock()
        end
      end
    elseif p1 == "Backspace" then
      if pathVars.visible and pathVars.focus then
        if pathVars.cpos > 0 then
          pathVars.str = pathVars.str:sub(1, pathVars.cpos - 1) .. pathVars.str:sub(pathVars.cpos + 1)
          pathVars.cpos = pathVars.cpos - 1
        end
        pathVars.time = os.clock()
      elseif newVars.visible and newVars.focus then
        local woh = newVars.mode == 1 and "w" or "h"
        local pos = newVars["cpos" .. woh]
        local str = newVars[woh ..  "num"]
        if pos > 0 then
          newVars[woh ..  "num"] = str:sub(1, pos - 1) .. str:sub(pos + 1)
          newVars["cpos" .. woh] = pos - 1
        end
      end
    elseif p1 == "Left" then
      if pathVars.focus then
        pathVars.cpos = pathVars.cpos - 1
        if pathVars.cpos < 0 then
          pathVars.cpos = 0
        end
        pathVars.time = os.clock()
      else
        drawOffX = drawOffX + 5
      end
    elseif p1 == "Right" then
      if pathVars.focus then
        pathVars.cpos = pathVars.cpos + 1
        if pathVars.cpos > #pathVars.str then
          pathVars.cpos = #pathVars.str
        end
        pathVars.time = os.clock()
      else
        drawOffX = drawOffX - 5
      end
    elseif p1 == "Up" then
      drawOffY = drawOffY + 5
    elseif p1 == "Down" then
      drawOffY = drawOffY - 5
    end
  elseif ev == "mousePressed" then
    local x, y, _ = p1, p2, p3
    local tBar = toolbarActive
    toolbarActive = false

    if tBar then
      local i = selToolbar

      if x > toolbar[i].offset - 5 and x < toolbar[i].maxACL * 7 + toolbar[i].offset + 12 then
        local action = math.floor(y / 10)
        if toolbar[i].actions[action] then
          local f = toolbar[i].actions[action][2]
          if f then f() end
        end
        return
      end
    end

    if y < 10 then
      if x > 330 and x < 340 then
        running = false
        return
      end

      for i=1, #toolbar do
        if x > toolbar[i].offset - 5 and x < #toolbar[i].name * 7 + toolbar[i].offset + 6 then
          if not (tBar and i == selToolbar) then
            toolbarActive = true
            selToolbar = i
          end
        end
      end
      return
    end

    if mouseDown[2] or not wep("mousePressedInternal", p1, p2, p3) then
      mouseDown[tonumber(p3)] = true
      toolList[selectedTool].mouseDown(p1, p2, p3)
    end
  elseif ev == "mouseReleased" then
    if mouseDown[2] or not wep("mouseReleased", p1, p2, p3) then
      mouseDown[tonumber(p3)] = false
      toolList[selectedTool].mouseUp(p1, p2, p3)
    end
  elseif ev == "mouseMoved" then
    closeHover = false
    if p2 < 10 then
      if p1 > 330 and p1 < 340 then
        closeHover = true
      end
    end

    if mouseDown[2] or not wep("mouseMoved", p1, p2, p3, p4) then
      if mouseDown[2] then
        -- Move draw offsets
        drawOffX = drawOffX + p3
        drawOffY = drawOffY + p4
      end

      toolList[selectedTool].mouseMoved(p1, p2, p3, p4)
    end

    mousePosX = p1
    mousePosY = p2
  elseif ev == "mouseWheel" then
    local px, py = convertScrn2I(mousePosX, mousePosY)
    zoomFactor = clamp(zoomFactor + p1, 1)
    drawOffX = mousePosX - px * zoomFactor
    drawOffY = (mousePosY - 10) - py * zoomFactor
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
