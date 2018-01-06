local running = true

local sw, sh = gpu.width, gpu.height

local Vector = dofile("../lib/vector.lua")
local class = dofile("../lib/class.lua")

local Particle = class(nil, "part")

function Particle:__init(x, y)
  self.x = x
  self.y = y
  self.life = math.random(30, 40)

  local ang = math.pi * math.random(0, 1000) / 500
  local mag = 2 * math.random(0, 1000) / 1000

  self.vx = math.cos(ang) * mag
  self.vy = math.sin(ang) * mag
end

function Particle:update(dt)
  self.x = self.x + self.vx
  self.y = self.y + self.vy

  self.life = self.life - 1

  self.vy = self.vy + 9.8 * dt

  if self.y > sh or self.life == 0 then
    return true
  end
end

function Particle:draw()
  local c = self.life > 20 and 16 or (self.life > 10 and 7 or 6)
  gpu.drawPixel(self.x, self.y, c)
end

local particles = {}

local function explode()
  for i = 1, 30 do
    particles[#particles + 1] = Particle(sw / 2, 15)
  end
end
explode()

local function draw()
  gpu.clear()

  for i = 1, #particles do
    particles[i]:draw()
  end

  gpu.swap()
end

local function update(dt)
  for i = #particles, 1, -1 do
    if particles[i]:update(dt) then
      table.remove(particles, i)
    end
  end
end

local function event(e, ...)
  if e == "key" then
    local k = ...
    if k == "escape" then
      running = false
    elseif k == "space" then
      explode()
    end
  end
end

local eq = {}
local last = os.clock()
while running do
  while true do
    local a = {coroutine.yield()}
    if not a[1] then break end
    table.insert(eq, a)
  end

  while #eq > 0 do
    event(unpack(table.remove(eq, 1)))
  end

  update(os.clock() - last)
  last = os.clock()

  draw()
end
