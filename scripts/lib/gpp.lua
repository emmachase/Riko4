local gpp = {}

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
    gpu.drawRectangle(x0 - x, y0 + y, 2 * x + 1, 1, c)
    gpu.drawRectangle(x0 - x, y0 - y, 2 * x + 1, 1, c)

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
    gpu.drawRectangle(x0 - x, y0 + y, 2 * x + 1, 1, c)
    gpu.drawRectangle(x0 - x, y0 - y, 2 * x + 1, 1, c)

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
    gpu.drawPixel(x0 + x, y0 + y, c)
    gpu.drawPixel(x0 - x, y0 + y, c)
    gpu.drawPixel(x0 - x, y0 - y, c)
    gpu.drawPixel(x0 + x, y0 - y, c)

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
    gpu.drawPixel(x0 + x, y0 + y, c)
    gpu.drawPixel(x0 - x, y0 + y, c)
    gpu.drawPixel(x0 - x, y0 - y, c)
    gpu.drawPixel(x0 + x, y0 - y, c)

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
    gpu.drawRectangle(x0 - x, y0 + y, 2 * x + 1, 1, c)
    gpu.drawRectangle(x0 - y, y0 + x, 2 * y + 1, 1, c)

    gpu.drawRectangle(x0 - x, y0 - y, 2 * x + 1, 1, c)
    gpu.drawRectangle(x0 - y, y0 - x, 2 * y + 1, 1, c)

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

    local ddY = deltaY > 1 and 1 or -1

    local deltaErr = 2 * deltaY * ddY - deltaX

    local y = y1

    local min = math.huge
    for x = x1, x2 do
      min = x < min and x or min

      if deltaErr > 0 then
        gpu.drawRectangle(min, y, x - min + 1, 1, c)
        min = math.huge
        y = y + ddY
        deltaErr = deltaErr - deltaX
      end
      deltaErr = deltaErr + deltaY * ddY
    end
    gpu.drawRectangle(min, y, x2 - min + 1, 1, c)
  else
    if y1 > y2 then
      local tx, ty = x1, y1
      x1, y1 = x2, y2
      x2, y2 = tx, ty

      deltaX = x2 - x1
      deltaY = y2 - y1
    end

    local ddX = deltaX > 1 and 1 or -1

    local deltaErr = 2 * deltaX * ddX - deltaY

    local x = x1

    local min = math.huge
    for y = y1, y2 do
      min = y < min and y or min

      if deltaErr > 0 then
        gpu.drawRectangle(x, min, 1, y - min + 1, c)
        min = math.huge
        x = x + ddX
        deltaErr = deltaErr - deltaY
      end
      deltaErr = deltaErr + deltaX * ddX
    end
    gpu.drawRectangle(x, min, 1, y2 - min + 1, c)
  end
end

return gpp
