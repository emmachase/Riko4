local running = true
local simulating = false

local turn = 1

local width, height = 340, 200
local cx, cy = 170, 100

local axis = math.min(width, height) - 50

local radius = 5
local maxvel = 300
local velscale = 5

local teams = {
  -1,
  7,
  15,
  2,
  3,
  16,
  5,
  6,
  1,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
}

local function vecMulScalar(v, s)
  return {v[1] * s, v[2] * s}
end

local objects = {}

local peng = {}

function peng.new(team)
  local t = {
    x = math.random(-axis / 2, axis / 2),
    y = math.random(-axis / 2, axis / 2),
    team = team,
    vel = {0, 0}
  }
  setmetatable(t, {__index = peng})

  return t
end

function peng:checkCol(other, delta)
  delta = delta or 0.02
  local normalX = other.x - self.x
  local normalY = other.y - self.y
  local mag = math.sqrt(normalX * normalX + normalY * normalY)

  if mag < 2*radius then
    -- collision
    local vel1X = self.vel[1]
    local vel1Y = self.vel[2]
    local vel2X = other.vel[1]
    local vel2Y = other.vel[2]

    local nXOverMag = normalX / mag
    local nYOverMag = normalY / mag

    local nXOM2 = nXOverMag * nXOverMag
    local nYOM2 = nYOverMag * nYOverMag
    local nCros = nXOverMag * nYOverMag

    self.vel[1]  = nYOM2 * vel1X + nXOM2 * vel2X +
                   nCros * (vel2Y - vel1Y)

    self.vel[2]  = nXOM2 * vel1Y + nYOM2 * vel2Y +
                   nCros * (vel2X - vel1X)

    other.vel[1] = nXOM2 * vel1X + nYOM2 * vel2X +
                   nCros * (vel1Y - vel2Y)

    other.vel[2] = nYOM2 * vel1Y + nXOM2 * vel2Y +
                   nCros * (vel1X - vel2X)

    self.x  = self.x  + self.vel[1]  * delta
    self.y  = self.y  + self.vel[2]  * delta
    other.x = other.x + other.vel[1] * delta
    other.y = other.y + other.vel[2] * delta

    return true
  end

  return false
end

function peng:update(delta)
  self.x = self.x + self.vel[1] * delta
  self.y = self.y + self.vel[2] * delta

  local rv = false
  if math.abs(self.x) > axis / 2 + 50 - radius then
    self.vel[1] = -self.vel[1]
    -- rv = true
  end

  if math.abs(self.y) > axis / 2 - radius then
    self.vel[2] = -self.vel[2]
    -- rv = true
  end

  self.vel = vecMulScalar(self.vel, 0.98)
  return rv
end

function peng:collide(delta)
  delta = delta or 0.02
  local collision = false

  for i = 1, #objects do
    if objects[i] ~= self then
      local other = objects[i]
      if self:checkCol(other, delta) then
        collision = true
        if self:checkCol(other, delta) then
          -- Still inside, must be tiny debind force, applying virtual force..

          local normalX = other.x - self.x
          local normalY = other.y - self.y

          self.vel[1] = self.vel[1] - normalX
          self.vel[2] = self.vel[2] - normalY
          other.vel[1] = other.vel[1] + normalX
          other.vel[2] = other.vel[2] + normalY

          self.x  = self.x  + self.vel[1]  * delta
          self.y  = self.y  + self.vel[2]  * delta
          other.x = other.x + other.vel[1] * delta
          other.y = other.y + other.vel[2] * delta
        end
      end
    end
  end

  return collision
end

local function init()
  objects = {
    peng.new(1),
    peng.new(2),
    peng.new(3),
    peng.new(4),
    peng.new(5),
    peng.new(6),
    peng.new(7),
    peng.new(8),
    peng.new(9),
    peng.new(10),
    peng.new(11),
    peng.new(12),
    peng.new(13),
    peng.new(14),
    peng.new(15),
    peng.new(16)
  }

  objects[1].x = -50
  objects[1].y = 0

  local ind = 1
  for i=1, 5 do
    for j=1, i do
      ind = ind + 1
      objects[ind].x = i * 10
      objects[ind].y = (j / i) * (i * 10) - ((i * 10) / 2) - 5
    end
  end
end

local beginSumVel = 0
local lSumVel = 0
local function updateframe(delta)
  local i = 1
  while i <= #objects do
    if not objects[i]:update(delta) then
      i = i + 1
    end
  end

  local cnt = 0 -- sanity check
  repeat
    local collision = false
    for j = 1, #objects do
      if objects[j]:collide(delta) then
        collision = true
      end
    end
    cnt = cnt + 1
  until not collision or cnt > 100

  local sumVel = 0
  for j=1, #objects do
    local xp = objects[j].vel[1]
    xp = xp < 0 and -xp or xp
    local yp = objects[j].vel[2]
    yp = yp < 0 and -yp or yp
    sumVel = sumVel + xp + yp
  end

  lSumVel = sumVel

  if sumVel < 0.1 then
    simulating = false
  end
end

local function round(n)
  local dec = n - math.floor(n)
  return dec >= 0.5 and math.ceil(n) or math.floor(n)
end

local function fillCircle(x, y, r, c)
  for i = y - r, y + r do
    local ydist = i - y
    local sx = round(math.sqrt(r*r - ydist*ydist))
    if c == -1 then
      gpu.drawRectangle(x - sx, i, sx * 2, 1, 9)
      if sx > 0 then
        gpu.drawRectangle(x - sx, i, r, 1, 10)
      end
    else
      gpu.drawRectangle(x - sx, i, sx * 2, 1, c)
    end
  end
end

local function drawLine(x1, y1, x2, y2, c)
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

local function drawframe()
  gpu.clear(2)

  gpu.drawRectangle(cx - axis / 2 - 51, cy - axis / 2 - 1, axis + 102, axis + 2, 5)
  gpu.drawRectangle(cx - axis / 2 - 50, cy - axis / 2, axis + 100, axis, 4)

  for i=1, #objects do
    fillCircle(
      math.floor(objects[i].x + cx),
      math.floor(objects[i].y + cy),
      radius, teams[objects[i].team]
    )
  end

  for i=1, #objects do
    if simulating or turn == objects[i].team then
     drawLine(math.floor(objects[i].x + cx), math.floor(objects[i].y + cy),
       math.floor(objects[i].x + cx + (objects[i].vel[1] / velscale)), math.floor(objects[i].y + cy + (objects[i].vel[2] / velscale)), 7)
    end
  end

  if simulating then
    write("Simulating...", 2, 2, 16)
    local frac = tostring(100 * (1 - lSumVel / beginSumVel)).."."
    write("(".. frac:sub(1, frac:find(".") + 3) .."% Done)", 2, 10, 16)
  else
    write("Player "..turn.."'s turn", 12, 3, 16)

    fillCircle(6, 6, 4, teams[turn])
  end

  gpu.swap()
end

local function calcBeginVel()
  local sumVel = 0
  for i=1, #objects do
    local xp = objects[i].vel[1]
    xp = xp < 0 and -xp or xp
    local yp = objects[i].vel[2]
    yp = yp < 0 and -yp or yp
    sumVel = sumVel + xp + yp
  end
  beginSumVel = sumVel
end

local dragging = -1
local function processEvent(e, ...)
  local args = {...}
  if e == "key" then
    local key = args[1]
    if key == "Escape" then
      running = false
    elseif key == "Space" then
      if not simulating then
        turn = 1--(turn % #teams) + 1
        if turn == 1 then
          simulating = true
          calcBeginVel()
        end
      end
    end
  elseif e == "mousePressed" then
    local x, y = args[1], args[2]

    for i=1, #objects do
      if objects[i].team == turn then
        local dx = objects[i].x - (x - cx)
        local dy = objects[i].y - (y - cy)
        if math.sqrt(dx * dx + dy * dy) <= radius then
          dragging = i
          break
        end
      end
    end
  elseif e == "mouseMoved" then
    local x, y = args[1], args[2]
    if dragging > 0 then
      local xv = ((x - cx) - objects[dragging].x) * velscale
      local yv = ((y - cy) - objects[dragging].y) * velscale
      local smag = xv*xv + yv*yv
      if xv*xv + yv*yv > maxvel*maxvel then
        objects[dragging].vel[1] = xv / math.sqrt(smag) * maxvel
        objects[dragging].vel[2] = yv / math.sqrt(smag) * maxvel
      else
        objects[dragging].vel[1] = xv
        objects[dragging].vel[2] = yv
      end
    end
  elseif e == "mouseReleased" then
    dragging = -1
  end
end

local function mainloop()
  local delta = os.clock()
  local eventQueue = {}
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

    local t0 = os.clock()
    if simulating then
      updateframe(t0 - delta)
    end
    delta = os.clock()
    drawframe()
  end
end

local function main()
  init()
  mainloop()
end

main()
