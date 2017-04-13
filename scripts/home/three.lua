local width, height = gpu.width, gpu.height

-- Vector class

local function newVector(x, y, z)
  if not y then
    return {x[1], x[2], x[3]}
  else
    return {x, y, z}
  end
end

local function vectorCross(a, b)
  return newVector(
    a[2] * b[3] - a[3] * b[2],
    a[3] * b[1] - a[1] * b[3],
    a[1] * b[2] - a[2] * b[1]
  )
end

local function vectorMagSq(v)
  return v[1] * v[1] + v[2] * v[2] + v[3] * v[3]
end

local function vectorDot(a, b)
  return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function round(n)
  if n % 1 >= 0.5 then
    return n - n % 1 + 1
  else
    return n - n % 1
  end
end

local function fillBottomFlatTriangle(x1, y1, x2, y2, x3, y3, c)
  local invslope1 = (x2 - x1) / (y2 - y1);
  local invslope2 = (x3 - x1) / (y3 - y1);

  local curx1 = x1;
  local curx2 = x1;

  for scanlineY = y1, y2 do
    gpu.drawRectangle(round(curx1), scanlineY, round(curx2 - curx1 + 1), 1, c)
    curx1 = curx1 + invslope1;
    curx2 = curx2 + invslope2;
  end
end

local function fillTopFlatTriangle(x1, y1, x2, y2, x3, y3, c)
  local invslope1 = (x3 - x1) / (y3 - y1);
  local invslope2 = (x3 - x2) / (y3 - y2);

  local curx1 = x3;
  local curx2 = x3;

  for scanlineY = y3, y1, -1 do
    gpu.drawRectangle(round(curx1), scanlineY, round(curx2 - curx1 + 1), 1, c)
    curx1 = curx1 - invslope1;
    curx2 = curx2 - invslope2;
  end
end

local function drawFilledTriangle(x1, y1, x2, y2, x3, y3, c)
  local ar = (x3 - x1) * (y2 - y1) - (x2 - x1) * (y3 - y1)

  if ar >= 0 then
    -- Backface culling
    return
  end

  -- First sort the vertices
  if y1 > y2 then
    local tx, ty = x1, y1
    x1, y1 = x2, y2
    x2, y2 = tx, ty
  end
  if y1 > y3 then
    local tx, ty = x1, y1
    x1, y1 = x3, y3
    x3, y3 = tx, ty
  end
  if y2 > y3 then
    local tx, ty = x2, y2
    x2, y2 = x3, y3
    x3, y3 = tx, ty
  end

  if y2 == y3 then
    fillBottomFlatTriangle(x1, y1, x2, y2, x3, y3, c)
  elseif y1 == y2 then
    fillTopFlatTriangle(x1, y1, x2, y2, x3, y3, c)
  else
    local x4 = x1 + ((y2 - y1) / (y3 - y1)) * (x3 - x1)
    fillBottomFlatTriangle(x1, y1, x2, round(y2), x4, round(y2), c)
    fillTopFlatTriangle(x2, round(y2), x4, round(y2), x3, y3, c)
  end
end

local eventQueue = {}
local running = true

local x, y = 20, 10

local model = {
  {-1, -1, 1},
  {-1, -1, 2},
  {1, -1, 2},
  {1, -1, 1},
  {-1, 1, 1},
  {-1, 1, 2},
  {1, 1, 2},
  {1, 1, 1}
}

local faces = {
  {3, 2, 1}, -- Bott
  {4, 3, 1},
  {2, 5, 1}, -- Left
  {6, 5, 2},
  {3, 4, 7}, -- Right
  {8, 7, 4},
  {5, 4, 1}, -- Front
  {4, 5, 8},
  {2, 3, 6}, -- Back
  {7, 6, 3},
  {5, 6, 8}, -- Top
  {6, 7, 8}
}

local xoff = 0
local yoff = 0

-- local ang = 0

local function drawContent()
  for i=1, #model do
    local v = model[i]
    local ang = math.atan2(2*(v[3] - 1.5), v[1])
    ang = ang + 0.01
    v[1] = math.cos(ang)
    v[3] = math.sin(ang) * 0.5 + 1.5
  end

  -- plotLine(15, 3, 3, 12)
  -- gpu.drawPixel(15, 3, 8)
  -- gpu.drawPixel(3, 12, 8)

  for i=1, #faces do
    local fc = faces[i]
    local v1 = model[fc[1]]
    local v2 = model[fc[2]]
    local v3 = model[fc[3]]

    --(x3 - x1) * (y2 - y1) - (x2 - x1) * (y3 - y1)

    drawFilledTriangle(((width / 4) * v1[1] + xoff) / v1[3] + (width / 2), (-(height / 4) * v1[2] + yoff) / v1[3] + (height / 2),
                       ((width / 4) * v2[1] + xoff) / v2[3] + (width / 2), (-(height / 4) * v2[2] + yoff) / v2[3] + (height / 2),
                       ((width / 4) * v3[1] + xoff) / v3[3] + (width / 2), (-(height / 4) * v3[2] + yoff) / v3[3] + (height / 2), i + 1)
  end
end

local function processEvent(e, p1, p2)
  if e == "key" then
    if p1 == "escape" then
      running = false
    elseif p1 == "left" then
      xoff = xoff - 5
    elseif p1 == "right" then
      xoff = xoff + 5
    elseif p1 == "up" then
      yoff = yoff - 5
    elseif p1 == "down" then
      yoff = yoff + 5
    end
  elseif e == "mouseMoved" then
    x, y = p1, p2
  end
end

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