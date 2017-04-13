local running = true

local rif = dofile("../lib/rif.lua")

local width, height = gpu.width, gpu.height

-- local curRIF = "\82\73\86\2\0\5\0\5\1\0\0\0\0\0\0\0\0\0\0\0\0\0\240\0\0\240\0\0\240\0\0\0\24\130\48\0"
-- local cur = image.newImage(5, 5)
-- cur:blitPixels(0, 0, 5, 5, rif.decode1D(curRIF))

local cur = rif.createImage("curs.rif")

local sheet = rif.createImage("pactex.rif")
local shw = 8
local shh = 5
local pxs = 24

local barW = 4

local mouse = {-10, -10}
local winScroll = 0

local mstate = 1
local off = width - pxs * barW
local sel = {1, 1}

local board = {}

local function transformSSC()
  local lin = (sel[2] - 1) * barW + sel[1]
  local expX = ((lin - 1) % shw)
  local expY = math.floor((lin - 1) / shw)
  return expX * pxs, expY * pxs
end

local function processEvent(e, ...)
  if e == "key" then
    local key = ...
    if key == "escape" then
      running = false
    elseif key == "tab" then
      mstate = (mstate % 2) + 1
    end
  elseif e == "mouseMoved" then
    local x, y = ...
    mouse[1] = x; mouse[2] = y
  elseif e == "mousePressed" then
    local x, y, b = ...
    if x >= off - 5 and x < off then
      mstate = (mstate % 2) + 1
    elseif x >= off then
      local transX = x - off
      local indexX = math.ceil(transX / 24)
      local indexY = math.ceil((y - winScroll) / 24)
      sel = {indexX, indexY}
    else
      if b == 1 then
        local p, p2 = transformSSC()
        board[#board + 1] = {x = math.floor(x / 24), y = math.floor(y / 24), spx = p, spy = p2}
      elseif b == 3 then
        for i = 1, #board do
          if board[i].x == math.floor(x / 24) and board[i].y == math.floor(y / 24) then
            table.remove(board, i)
            break
          end
        end
      end
    end
  elseif e == "mouseWheel" then
    local wheelY, _, x = ...
    if x >= off then
      winScroll = winScroll + wheelY * (pxs / 2)
      if winScroll > 0 then
        winScroll = 0
      elseif winScroll < (1 - math.ceil((shw * shh) / barW)) * pxs then
        winScroll = (1 - math.ceil((shw * shh) / barW)) * pxs
      end
    end
  end
end

-- sel(x, y) -> (sel[2] - 1) * barW + sel[1] == l
-- sel(l) -> <((l - 1) % shw) + 1, math.floor((l - 1) / shw) + 1>
-- expanded: <((((sel[2] - 1) * barW + sel[1]) - 1) % shw) + 1, math.floor((((sel[2] - 1) * barW + sel[1]) - 1) / shw) + 1>

local function draw()
  for i = 1, #board do
    sheet:render(board[i].x * 24, board[i].y * 24, board[i].spx, board[i].spy, pxs, pxs)
  end

  local p, p2 = transformSSC()
  sheet:render(math.floor(mouse[1] / 24) * 24, math.floor(mouse[2] / 24) * 24, p, p2, pxs, pxs)

  gpu.drawRectangle(off, 0, pxs * barW, height, 7)
  gpu.drawRectangle(off - 5, 0, 5, height, 6)
  if off < width then
    gpu.drawPixel(off - 4, 98, 7)
    gpu.drawPixel(off - 3, 99, 7)
    gpu.drawPixel(off - 2, 100, 7)
    gpu.drawPixel(off - 3, 101, 7)
    gpu.drawPixel(off - 4, 102, 7)
  else
    gpu.drawPixel(off - 2, 98, 7)
    gpu.drawPixel(off - 3, 99, 7)
    gpu.drawPixel(off - 4, 100, 7)
    gpu.drawPixel(off - 3, 101, 7)
    gpu.drawPixel(off - 2, 102, 7)
  end

  local bpX, bpY = 1, 1
  for j = 1, shh do
    for i = 1, shw do
      -- print(off + (bpX - 1) * pxs, (bpY - 1) * pxs, (i - 1) * pxs, (j - 1) * pxs, pxs, pxs)
      sheet:render(off + (bpX - 1) * pxs, (bpY - 1) * pxs + winScroll, (i - 1) * pxs, (j - 1) * pxs, pxs, pxs)
      if bpX == sel[1] and bpY == sel[2] then
        gpu.drawRectangle(off + (bpX - 1) * pxs, (bpY - 1) * pxs + winScroll, pxs, 1, 6)
        gpu.drawRectangle(off + (bpX - 1) * pxs, (bpY - 1) * pxs + winScroll, 1, pxs, 6)
        gpu.drawRectangle(off + (bpX - 1) * pxs, (bpY) * pxs - 1 + winScroll, pxs, 1, 6)
        gpu.drawRectangle(off + (bpX) * pxs - 1, (bpY - 1) * pxs + winScroll, 1, pxs, 6)
      end

      bpX = (bpX % barW) + 1
      if bpX == 1 then
        bpY = bpY + 1
      end
    end
  end

  if mstate == 2 then
    off = off + 8
    if off > width then
      off = width
    end
  else
    off = off - 8
    if off < width - pxs * barW then
      off = width - pxs * barW
    end
  end

  cur:render(mouse[1], mouse[2])
end

local eventQueue = {}
while running do
  while true do
    local e = {coroutine.yield()}
    if #e == 0 then break end
    eventQueue[#eventQueue + 1] = e
  end

  while #eventQueue > 0 do
    processEvent(unpack(
      table.remove(eventQueue, 1)))
  end

  gpu.clear()

  draw()

  gpu.swap()
end