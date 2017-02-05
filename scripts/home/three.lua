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

local zBuffer = {}

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

  -- y3, y2, y1 <==> hi, mid, lo

  local handedness = (x3 - x1) * (y2 - y1) - (x2 - x1) * (y3 - y1)
  -- Same calculation as before but the vertices are sorted now so redo it

  if y1 == y2 then
    if x1 > x2 then
      local tx, ty = x1, y1
      x1, y1 = x2, y2
      x2, y2 = tx, ty
    end

    local leXStep = (x3 - x1) / (y3 - y1)
    local rXStep = (x3 - x2) / (y3 - y2)
    local clex = x1
    local crtx = x2
    for i = y1, y3 do
      local len = crtx - clex
      gpu.drawRectangle(clex, i, len < 0 and -len or len, 1, c)
      clex = clex + leXStep
      crtx = crtx + rXStep
    end
    return
  end

  if handedness < 0 then -- Right handed triangles
    -- So long edge is left
    local leXStep = (x3 - x1) / (y3 - y1)
    local rXStep = (x2 - x1) / (y2 - y1)
    local clex = x1
    local crtx = x1
    for i = y1, y3 do
      local len = math.ceil(crtx - clex)
      gpu.drawRectangle(clex, i, len < 0 and -len or len, 1, c)
      if i == y2 then
        rXStep = (x3 - x2) / (y3 - y2)
      end
      clex = clex + leXStep
      crtx = crtx + rXStep
    end
  else
    -- Long edge on right
    local rXStep = (x3 - x1) / (y3 - y1)
    local leXStep = (x2 - x1) / (y2 - y1)
    local clex = x1
    local ctrx = x1
    for i = y1, y3 do
      local len = math.ceil(ctrx - clex)
      gpu.drawRectangle(clex, i, len < 0 and -len or len, 1, c)
      if i == y2 then
        leXStep = (x3 - x2) / (y3 - y2)
      end
      clex = clex + leXStep
      ctrx = ctrx + rXStep
    end
  end
end

local function plotLine(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1

  local step = x1 > x2 and -1 or 1

  local D = 2*dy - (dx * step)
  local y = y1

  for x = x1, x2, step do
    gpu.drawPixel(x, y, 4)
    if D > 0 then
      y = y + 1
      D = D - (dx * step)
    end
    D = D + dy
  end
end

local function bresenhamTriangle(x1, y1, x2, y2, x3, y3)
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

  -- y3, y2, y1 <==> hi, mid, lo

  local handedness = (x3 - x1) * (y2 - y1) - (x2 - x1) * (y3 - y1)
  -- Same calculation as before but the vertices are sorted now so redo it

  if handedness < 0 then -- Right handed triangles
    -- So long edge is left

    local dx = x2 - x1
    local dy = y2 - y1

    local step = x1 > x2 and -1 or 1

    local D = 2*dy - (dx * step)
    local y = y1

    local sx = x1
    for x = x1, x2, step do
      if x < sx then sx = x end
      --gpu.drawPixel(x, y, 4)
      if D > 0 then
        y = y + 1
        D = D - (dx * step)
      end
      D = D + dy
    end

  else
    -- Long edge is right
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
  -- for i=1, #model do
  --   local v = model[i]
  --   local ang = math.atan2(2*(v[3] - 1.5), v[1])
  --   ang = ang + 0.01
  --   v[1] = math.cos(ang)
  --   v[3] = math.sin(ang) * 0.5 + 1.5
  -- end

  for i = 0, 340 * 200 do
    zBuffer[i] = math.huge
  end

  plotLine(15, 3, 3, 12)
  gpu.drawPixel(15, 3, 8)
  gpu.drawPixel(3, 12, 8)

  for i=1, #faces do
    local fc = faces[i]
    local v1 = model[fc[1]]
    local v2 = model[fc[2]]
    local v3 = model[fc[3]]

    --(x3 - x1) * (y2 - y1) - (x2 - x1) * (y3 - y1)

    drawFilledTriangle((80 * v1[1] + xoff) / v1[3] + 170, (-50 * v1[2] + yoff) / v1[3] + 100,
                       (80 * v2[1] + xoff) / v2[3] + 170, (-50 * v2[2] + yoff) / v2[3] + 100,
                       (80 * v3[1] + xoff) / v3[3] + 170, (-50 * v3[2] + yoff) / v3[3] + 100, i + 1)
  end
end

local function processEvent(e, p1, p2)
  if e == "key" then
    if p1 == "Escape" then
      running = false
    elseif p1 == "Left" then
      xoff = xoff - 5
    elseif p1 == "Right" then
      xoff = xoff + 5
    elseif p1 == "Up" then
      yoff = yoff - 5
    elseif p1 == "Down" then
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