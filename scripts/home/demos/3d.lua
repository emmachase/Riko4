local function drawHLine(x1, x2, y, c)
  if x1 > x2 then
    local temp = x1
    x1 = x2
    x2 = temp
  end
  for x = x1, x2 do
    gpu.drawPixel(x, y, c)
  end
end

local function fillTriangle(x1, y1, x2, y2, x3, y3, c)
  if y1 > y2 then
    local tempx, tempy = x1, y1
    x1, y1 = x2, y2
    x2, y2 = tempx, tempy
  end
  if y1 > y3 then
    local tempx, tempy = x1, y1
    x1, y1 = x3, y3
    x3, y3 = tempx, tempy
  end
  if y2 > y3 then
    local tempx, tempy = x2, y2
    x2, y2 = x3, y3
    x3, y3 = tempx, tempy
  end
  if y1 == y2 and x1 > x2 then
    local temp = x1
    x1 = x2
    x2 = temp
  end
  if y2 == y3 and x2 > x3 then
    local temp = x2
    x2 = x3
    x3 = temp
  end

  local x4, y4
  if x1 <= x2 then
    x4 = x1 + (y2 - y1) / (y3 - y1) * (x3 - x1)
    y4 = y2
    local tempx, tempy = x2, y2
    x2, y2 = x4, y4
    x4, y4 = tempx, tempy
  else
    x4 = x1 + (y2 - y1) / (y3 - y1) * (x3 - x1)
    y4 = y2
  end

  local finvslope1 = (x2 - x1) / (y2 - y1)
  local finvslope2 = (x4 - x1) / (y4 - y1)
  local linvslope1 = (x3 - x2) / (y3 - y2)
  local linvslope2 = (x3 - x4) / (y3 - y4)

  local xstart, xend
  for y = math.ceil(y1 + 0.5) - 0.5, math.floor(y3 - 0.5) + 0.5, 1 do
    if y <= y2 then -- first half
      xstart = x1 + finvslope1 * (y - y1)
      xend = x1 + finvslope2 * (y - y1)
    else -- second half
      xstart = x3 - linvslope1 * (y3 - y)
      xend = x3 - linvslope2 * (y3 - y)
    end

    if xstart > xend then
      local temp = xstart
      xstart = xend
      xend = temp
    end
    local dxstart, dxend = math.ceil(xstart - 0.5), math.floor(xend - 0.5)
    if dxstart <= dxend then
      drawHLine(dxstart, dxend, y - 0.5, c)
    end
  end
end

local function generateTransformTs(transform3)
  return function (t, x, y, z)
    for i = 1, #t do
      t[i][1], t[i][2], t[i][3] = transform3(t[i][1], t[i][2], t[i][3], x, y, z)
      t[i][4], t[i][5], t[i][6] = transform3(t[i][4], t[i][5], t[i][6], x, y, z)
      t[i][7], t[i][8], t[i][9] = transform3(t[i][7], t[i][8], t[i][9], x, y, z)
    end
  end
end

local function translate3(x, y, z, sx, sy, sz)
  return x + sx, y + sy, z + sz
end

local function scale3(x, y, z, sx, sy, sz)
  return x * sx, y * sy, z * sz
end

local function rotate3(x, y, z, sx, sy, sz)
  local sinx, cosx, siny, cosy, sinz, cosz = math.sin(sx), math.cos(sx), math.sin(sy), math.cos(sy), math.sin(sz), math.cos(sz)
  -- rotate around x axis
  local x1, y1, z1 = x, y * cosx - z * sinx, y * sinx + z * cosx
  -- rotate around y axis
  local x2, y2, z2 = z1 * siny + x1 * cosy, y1, z1 * cosy - x1 * siny
  -- rotate around z axis
  local x3, y3, z3 = x2 * cosz - y2 * sinz, x2 * sinz + y2 * cosz, z2
  return x3, y3, z3
end

local function cloneTs(ts)
  local newTs = {}
  for i = 1, #ts do
    local newT = {}
    for j = 1, 10 do
      newT[j] = ts[i][j]
    end
    newTs[i] = newT
  end
  return newTs
end

local function compareT(t1, t2)
  return (t1[3] + t1[6] + t1[9]) > (t2[3] + t2[6] + t2[9])
end

local translateTs = generateTransformTs(translate3)
local scaleTs = generateTransformTs(scale3)
local rotateTs = generateTransformTs(rotate3)


local mesh = { { 0.0, 0.0, 0.0,
                 1.0, 0.0, 0.0,
                 0.0, 0.0, 1.0, 2 },
               { 1.0, 0.0, 0.0,
                 0.0, 0.0, 1.0,
                 1.0, 0.0, 1.0, 3 },
               { 0.0, 1.0, 0.0,
                 1.0, 1.0, 0.0,
                 0.0, 1.0, 1.0, 5 },
               { 1.0, 1.0, 0.0,
                 0.0, 1.0, 1.0,
                 1.0, 1.0, 1.0, 6 },
               { 0.0, 0.0, 0.0,
                 1.0, 0.0, 0.0,
                 0.0, 1.0, 0.0, 7 },
               { 1.0, 0.0, 0.0,
                 0.0, 1.0, 0.0,
                 1.0, 1.0, 0.0, 9 },
               { 0.0, 0.0, 1.0,
                 1.0, 0.0, 1.0,
                 0.0, 1.0, 1.0, 10 },
               { 1.0, 0.0, 1.0,
                 0.0, 1.0, 1.0,
                 1.0, 1.0, 1.0, 11 },
               { 0.0, 0.0, 0.0,
                 0.0, 0.0, 1.0,
                 0.0, 1.0, 0.0, 12 },
               { 0.0, 0.0, 1.0,
                 0.0, 1.0, 0.0,
                 0.0, 1.0, 1.0, 13 },
               { 1.0, 0.0, 0.0,
                 1.0, 0.0, 1.0,
                 1.0, 1.0, 0.0, 14 },
               { 1.0, 0.0, 1.0,
                 1.0, 1.0, 0.0,
                 1.0, 1.0, 1.0, 15 }  }


local running = true
local startTime = os.clock()
local prevTime = os.clock()

while running do
  while true do
    local event = {coroutine.yield()}
    if not event[1] then
      break
    elseif event[1] == "key" and event[2] == "escape" then
      running = false
      break
    end
  end

  local curTime = os.clock()
  local dTime = curTime - prevTime
  local runTime = curTime - startTime
  prevTime = curTime
  local triangles = cloneTs(mesh)
  translateTs(triangles, -0.5, -0.5, -0.5)
  rotateTs(triangles, runTime * 0.2, runTime * 1.0, runTime * 1.0)
  translateTs(triangles, 0, 0, 2)
  --scaleT(triangles, 1 + runTime * 0.2, 1, 1 - runTime * 0.05)
  table.sort(triangles, compareT)

  gpu.clear(0)
  local scale = gpu.width / 2
  local sx, sy = gpu.width / 2, gpu.height / 2
  for i = 1, #triangles do
    local z1, z2, z3 = triangles[i][3], triangles[i][6], triangles[i][9]
    local x1, y1 = (triangles[i][1] / z1) * scale + sx, (triangles[i][2] / z1) * scale + sy
    local x2, y2 = (triangles[i][4] / z2) * scale + sx, (triangles[i][5] / z2) * scale + sy
    local x3, y3 = (triangles[i][7] / z3) * scale + sx, (triangles[i][8] / z3) * scale + sy
    fillTriangle(x1, y1, x2, y2, x3, y3, triangles[i][10])
  end
  gpu.swap()
end
