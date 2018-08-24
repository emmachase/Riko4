local gpp = {}

local gpuDrawPixel = gpu.drawPixel
local gpuDrawRectangle = gpu.drawRectangle
local gpuBlitImage = function(a, ...)
  a:render(...)
end

local gpuWidth = gpu.width
local gpuHeight = gpu.height

local function round(n)
  if n % 1 >= 0.5 then
    return math.ceil(n)
  else
    return math.floor(n)
  end
end

function gpp.target(targetBuffer, selfInd)
  if selfInd then
    gpuDrawPixel = function(...) targetBuffer:drawPixel(...) end
    gpuDrawRectangle = function(...) targetBuffer:drawRectangle(...) end
    gpuBlitImage = function(a, ...)
      a:copy(targetBuffer, ...)
    end
  else
    gpuDrawPixel = targetBuffer.drawPixel
    gpuDrawRectangle = targetBuffer.drawRectangle
    gpuBlitImage = function(a, ...)
      a:render(...)
    end
  end
end

function gpp.fillEllipse(x0, y0, rx, ry, c)
  local twoASquare = 2 * rx * rx
  local twoBSquare = 2 * ry * ry
  local x = rx
  local y = 0
  local dx = ry * ry * (1 - 2 * rx)
  local dy = rx * rx
  local err = 0
  local stopX = twoBSquare * rx
  local stopY = 0

  while stopX >= stopY do
    gpuDrawRectangle(x0 - x, y0 + y, 2 * x + 1, 1, c)
    gpuDrawRectangle(x0 - x, y0 - y, 2 * x + 1, 1, c)

    y = y + 1
    stopY = stopY + twoASquare
    err = err + dy
    dy = dy + twoASquare

    if 2 * err + dx > 0  then
      x = x - 1
      stopX = stopX - twoBSquare
      err = err + dx
      dx = dx + twoBSquare
    end
  end

  x = 0
  y = ry
  dx = ry * ry
  dy = rx * rx * (1 - 2 * ry)
  err = 0
  stopX = 0
  stopY = twoASquare * ry

  while stopX <= stopY do
    gpuDrawRectangle(x0 - x, y0 + y, 2 * x + 1, 1, c)
    gpuDrawRectangle(x0 - x, y0 - y, 2 * x + 1, 1, c)

    x = x + 1
    stopX = stopX + twoBSquare
    err = err + dx
    dx = dx + twoBSquare

    if 2 * err + dy > 0 then
      y = y - 1
      stopY = stopY - twoASquare
      err = err + dy
      dy = dy + twoASquare
    end
  end
end

function gpp.drawEllipse(x0, y0, rx, ry, c)
  local twoASquare = 2 * rx * rx
  local twoBSquare = 2 * ry * ry
  local x = rx
  local y = 0
  local dx = ry * ry * (1 - 2 * rx)
  local dy = rx * rx
  local err = 0
  local stopX = twoBSquare * rx
  local stopY = 0

  while stopX >= stopY do
    gpuDrawPixel(x0 + x, y0 + y, c)
    gpuDrawPixel(x0 - x, y0 + y, c)
    gpuDrawPixel(x0 - x, y0 - y, c)
    gpuDrawPixel(x0 + x, y0 - y, c)

    y = y + 1
    stopY = stopY + twoASquare
    err = err + dy
    dy = dy + twoASquare

    if 2 * err + dx > 0  then
      x = x - 1
      stopX = stopX - twoBSquare
      err = err + dx
      dx = dx + twoBSquare
    end
  end

  x = 0
  y = ry
  dx = ry * ry
  dy = rx * rx * (1 - 2 * ry)
  err = 0
  stopX = 0
  stopY = twoASquare * ry

  while stopX <= stopY do
    gpuDrawPixel(x0 + x, y0 + y, c)
    gpuDrawPixel(x0 - x, y0 + y, c)
    gpuDrawPixel(x0 - x, y0 - y, c)
    gpuDrawPixel(x0 + x, y0 - y, c)

    x = x + 1
    stopX = stopX + twoBSquare
    err = err + dx
    dx = dx + twoBSquare

    if 2 * err + dy > 0 then
      y = y - 1
      stopY = stopY - twoASquare
      err = err + dy
      dy = dy + twoASquare
    end
  end
end

function gpp.fillCircle(x0, y0, r, c)
  local x = r
  local y = 0
  local err = 0

  while x >= y do
    gpuDrawRectangle(x0 - x, y0 + y, 2 * x + 1, 1, c)
    gpuDrawRectangle(x0 - y, y0 + x, 2 * y + 1, 1, c)

    gpuDrawRectangle(x0 - x, y0 - y, 2 * x + 1, 1, c)
    gpuDrawRectangle(x0 - y, y0 - x, 2 * y + 1, 1, c)

    y = y + 1
    if err <= 0 then
      err = err + 2 * y + 1
    else
      x = x - 1
      err = err + 2 * (y - x) + 1
    end
  end
end

function gpp.drawLine(x1, y1, x2, y2, c)
  local deltaX = x2 - x1
  local deltaY = y2 - y1

  if (deltaX < 0 and -deltaX or deltaX) >= (deltaY < 0 and -deltaY or deltaY) then
    if x1 > x2 then
      local tx, ty = x1, y1
      x1, y1 = x2, y2
      x2, y2 = tx, ty

      deltaX = x2 - x1
      deltaY = y2 - y1
    end

    local ddY = deltaY > 0 and 1 or -1

    local deltaErr = 2 * deltaY * ddY - deltaX

    local y = y1

    local min = math.huge
    for x = x1, x2 do
      min = x < min and x or min

      if deltaErr > 0 then
        gpuDrawRectangle(min, y, x - min + 1, 1, c)
        min = math.huge
        y = y + ddY
        deltaErr = deltaErr - deltaX
      end
      deltaErr = deltaErr + deltaY * ddY
    end
    gpuDrawRectangle(min, y, x2 - min + 1, 1, c)
  else
    if y1 > y2 then
      local tx, ty = x1, y1
      x1, y1 = x2, y2
      x2, y2 = tx, ty

      deltaX = x2 - x1
      deltaY = y2 - y1
    end

    local ddX = deltaX > 0 and 1 or -1

    local deltaErr = 2 * deltaX * ddX - deltaY

    local x = x1

    local min = math.huge
    for y = y1, y2 do
      min = y < min and y or min

      if deltaErr > 0 then
        gpuDrawRectangle(x, min, 1, y - min + 1, c)
        min = math.huge
        x = x + ddX
        deltaErr = deltaErr - deltaY
      end
      deltaErr = deltaErr + deltaX * ddX
    end
    gpuDrawRectangle(x, min, 1, y2 - min + 1, c)
  end
end

function gpp.fillPolygon(poly, c)
  local j, swap, nodes
  local nodeX = {}

  local imgTop, imgBot = gpuHeight, 0
  for i = 1, #poly do
    local pp = poly[i]
    if pp[2] < imgTop then
      imgTop = pp[2]
    end

    if pp[2] > imgBot then
      imgBot = pp[2]
    end
  end

  local typeNum = type(c) == "number"

  for pixelY = imgTop, imgBot do
    -- Build a list of nodes
    nodes = 0; j = #poly
    for i = 1, #poly do
      local pp = poly[i]
      local pn = poly[j]

      if (pp[2] < pixelY and pn[2] >= pixelY
       or pn[2] < pixelY and pp[2] >= pixelY) then
        nodes = nodes + 1
        nodeX[nodes] = round((pp[1] + (pixelY - pp[2]) / (pn[2] - pp[2]) * (pn[1] - pp[1])))
      end

      j = i
    end

    -- Bubble Sort the nodes
    do
      local i = 1;
      while (i < nodes) do
        if (nodeX[i] > nodeX[i+1]) then
          swap = nodeX[i];
          nodeX[i] = nodeX[i+1];
          nodeX[i+1] = swap;
          if i > 1 then i = i - 1 end
        else
          i = i + 1
        end
      end
    end

    --  Fill the pixels between node pairs.
    for i = 1, nodes - 1, 2 do
      if   (nodeX[i    ] >= gpuWidth) then break end
      if   (nodeX[i + 1] >  0 ) then
        if (nodeX[i    ] <  0 ) then nodeX[i] = 0 end
        if (nodeX[i + 1] >  gpuWidth) then nodeX[i + 1] = gpuWidth end

        if typeNum then
          gpuDrawRectangle(nodeX[i], pixelY, round(nodeX[i + 1] - nodeX[i] + 1), 1, c)
        else
          gpuBlitImage(c, nodeX[i], pixelY, nodeX[i], pixelY, round(nodeX[i + 1] - nodeX[i] + 1), 1)
        end
      end
    end
  end
end

return gpp
