local gpp = dofile("/lib/gpp.lua")
local rif = dofile("/lib/rif.lua")

local width, height = gpu.width, gpu.height

local curs = rif.createImage("curs.rif")

local underlay = image.newImage(width, height)

local running = true

local mouseX, mouseY = -5, -5

local particles = {}
particles[1] = {80, height / 2, -18}
particles[2] = {width - 80, height / 2, 6}
-- particles[3] = {width / 2, 40, -3}
-- particles[1] = {width / 2 + 20, 130, 6}

local fieldParticles = {}

-- Force = K * (q1 * q2) / d^2
local K = .1-- * 10 ^ 9

local function calculateForces()
  for _ = 1, 10 do
    for i = #fieldParticles, 1, -1 do
      fieldParticles[i][1] = fieldParticles[i][1] + fieldParticles[i][4][1]
      fieldParticles[i][2] = fieldParticles[i][2] + fieldParticles[i][4][2]

      local force = {0, 0}
      local still = true
      for j = 1, #particles do
        local delta = {particles[j][1] - fieldParticles[i][1], particles[j][2] - fieldParticles[i][2]}
        local norm = math.sqrt(delta[1] * delta[1] + delta[2] * delta[2])
        if norm < math.abs(particles[j][3]) or norm > 500 then
          table.remove(fieldParticles, i)
          still = false
          break
        end

        local dir = {delta[1] / norm, delta[2] / norm}
        local iforc = K * (fieldParticles[i][3] * particles[j][3]) / norm
        force[1] = force[1] + dir[1] * iforc
        force[2] = force[2] + dir[2] * iforc
      end

      if still then
        fieldParticles[i][4][1] = force[1]
        fieldParticles[i][4][2] = force[2]

        local tx, ty = fieldParticles[i][1], fieldParticles[i][2]
        fieldParticles[i][1] = fieldParticles[i][1] + fieldParticles[i][4][1]
        fieldParticles[i][2] = fieldParticles[i][2] + fieldParticles[i][4][2]
        if math.floor(tx) ~= math.floor(fieldParticles[i][1]) or math.floor(ty) ~= math.floor(fieldParticles[i][2]) then
          underlay:drawPixel(math.floor(fieldParticles[i][1]), math.floor(fieldParticles[i][2]), fieldParticles[i][3] > 0 and 8 or 4)
        end
      end
    end
  end
  underlay:flush()
end

local function drawContent()
  underlay:render(0, 0)

  for i = 1, #particles do
    gpp.fillCircle(particles[i][1], particles[i][2], math.abs(particles[i][3]), 7)
  end

  for i = 1, #fieldParticles do
    gpp.fillCircle(fieldParticles[i][1], fieldParticles[i][2], math.abs(fieldParticles[i][3]), 16)
  end

  curs:render(mouseX, mouseY)
end

local function processEvent(e, ...)
  if e == "key" then
    local k = ...
    if k == "escape" then
      running = false
    end
  elseif e == "mouseMoved" then
    local x, y = ...
    mouseX, mouseY = x, y
  elseif e == "mousePressed" then
    local x, y, b = ...
    fieldParticles[#fieldParticles + 1] = {x, y, b == 1 and -2 or 2, {1, 0}}
  end
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

  calculateForces()

  gpu.clear()

  drawContent()

  gpu.swap()
end