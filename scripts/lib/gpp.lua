local gpp = {}

local gpuDrawPixel = gpu.drawPixel
local gpuDrawRectangle = gpu.drawRectangle
local gpuBlitImage = function(a, ...)
  a:render(...)
end

local gpuWidth = gpu.width
local gpuHeight = gpu.height
local cos, sin = math.cos, math.sin
local min, max = math.min, math.max

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

function gpp.drawLine(x1, y1, x2, y2, c, thickness)
  thickness = thickness or 1
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
        gpuDrawRectangle(min, y, x - min + 1, thickness, c)
        min = math.huge
        y = y + ddY
        deltaErr = deltaErr - deltaX
      end
      deltaErr = deltaErr + deltaY * ddY
    end
    gpuDrawRectangle(min, y, x2 - min + 1, thickness, c)
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
        gpuDrawRectangle(x, min, thickness, y - min + 1, c)
        min = math.huge
        x = x + ddX
        deltaErr = deltaErr - deltaY
      end
      deltaErr = deltaErr + deltaX * ddX
    end
    gpuDrawRectangle(x, min, thickness, y2 - min + 1, c)
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

local rotCache = {}

-- Make sure that the rotCache has weak keys so that when cached sprites
-- are dropped, the cache doesn't stop them from being garbage collected
setmetatable(rotCache, { __mode = "k" })

function gpp.bakeRotation(spr, r, cx, cy)
  local w, h = spr:getWidth(), spr:getHeight()
  cx, cy = cx or w / 2, cy or h / 2

  -- Get rotation matrix
  local cosr, sinr = cos(r), sin(r)
  local rm11, rm12, rm21, rm22 = cosr, -sinr, sinr, cosr

  -- Initialize rect vectors
  local n1x, n1y = -cx    , -cy
  local n2x, n2y = n1x + w, n1y
  local n3x, n3y = n2x    , n1y + h
  local n4x, n4y = n1x    , n3y

  -- Now rotate them
  n1x, n1y = n1x*rm11 + n1y*rm12, n1x*rm21 + n1y*rm22
  n2x, n2y = n2x*rm11 + n2y*rm12, n2x*rm21 + n2y*rm22
  n3x, n3y = n3x*rm11 + n3y*rm12, n3x*rm21 + n3y*rm22
  n4x, n4y = n4x*rm11 + n4y*rm12, n4x*rm21 + n4y*rm22

  local minX = min(n1x, n2x, n3x, n4x)
  local maxX = max(n1x, n2x, n3x, n4x)
  local minY = min(n1y, n2y, n3y, n4y)
  local maxY = max(n1y, n2y, n3y, n4y)

  -- local img = image.newImage(maxX - minX + 1, maxY - minY + 1)
  -- local poly = {
  --   {n1x - minX, n1y - minY},
  --   {n2x - minX, n2y - minY},
  --   {n3x - minX, n3y - minY},
  --   {n4x - minX, n4y - minY}
  -- }

  -- local tempBlit = gpuBlitImage
  -- gpuBlitImage = function(a, ...)
  --   a:copy(img, ...)
  -- end

  -- gpp.fillPolygon(poly, spr)

  -- print(n1x .. ", " .. n1y)
  -- print(n2x .. ", " .. n2y)
  -- print(n3x .. ", " .. n3y)
  -- print(n4x .. ", " .. n4y)

  for sy = minY, maxY do

  end

end

function gpp.blitRotated(spr, x, y, r, cx, cy)
  gpp.bakeRotation(spr, r, cx, cy)

  local cake = rotCache[spr][r]
  gpuBlitImage(cake.im, cake.ox + x, cake.oy + y)
end

return gpp
