local running = true

local op = gpu.getPalette()
local pal = {{0, 0, 0}}
for i = 2, 15 do
  local v = i / 15
  pal[i] = {0 * v, 246 * v, 255 * v}
end
pal[16] = {255, 255, 255}

gpu.blitPalette(pal)

local size = 64

local sw, sh = gpu.width, gpu.height

local Vector = dofile("../lib/vector.lua")
local class = require("class")
local gpp = require("gpp")

local function cons(x, y)
  local dist = Vector(x, y):norm()
  local chkSz = (size * 0.75) + math.sin(os.clock() * 3) * (size * 0.25)

  -- if true then return x, y end

  if dist > chkSz then
    local vec = Vector(x, y):div(dist):mult(chkSz)
    return vec.x, vec.y
  else
    return x, y
  end
end

local Particle = class(nil, "part")

function Particle:__init(x, y)
  self.x = math.random(-size, size)
  self.y = math.random(-size, size)

  local ang = math.pi * math.random(0, 1000) / 500
  local mag = 1 * math.random(1000, 2000) / 1000

  self.vx = math.cos(ang) * mag
  self.vy = math.sin(ang) * mag
end

function Particle:update(dt)
  self.x = self.x + self.vx
  self.y = self.y + self.vy

  if math.abs(self.x) > size then
    self.vx = -self.vx
  end

  if math.abs(self.y) > size then
    self.vy = -self.vy
  end
end

function Particle:draw()
  local xp, yp = cons(self.x, self.y)

  gpu.drawRectangle(xp + sw / 2 - 1, yp + sh / 2 - 1, 1, 3, 16)
  gpu.drawRectangle(xp + sw / 2 + 1, yp + sh / 2 - 1, 1, 3, 16)
  gpu.drawRectangle(xp + sw / 2 - 1, yp + sh / 2 - 1, 3, 1, 16)
  gpu.drawRectangle(xp + sw / 2 - 1, yp + sh / 2 + 1, 3, 1, 16)
end

local particles = {}

local function explode()
  for i = 1, 25 do
    particles[#particles + 1] = Particle(sw / 2, 15)
  end
end
explode()

local function draw()
  -- gpu.clear()
  local ofx, ofy = (sw - size * 2) / 2, (sh - size * 2) / 2
  for i = 1, 400 do
    local x, y = math.random(0, size * 2), math.random(0, size * 2)
    gpu.drawPixel(x - 1 + ofx, y     + ofy, 1)
    gpu.drawPixel(x + 1 + ofx, y     + ofy, 1)
    gpu.drawPixel(x     + ofx, y - 1 + ofy, 1)
    gpu.drawPixel(x     + ofx, y + 1 + ofy, 1)
  end

  local pxo = sw / 2
  local pyo = sh / 2

  for i = 1, #particles do
    for j = 1, #particles do
      if i ~= j then
        local dist = Vector(particles[i].x, particles[i].y):minus(Vector(particles[j].x, particles[j].y)):sqNorm()
        if dist < 1000 then
          local xp, yp = cons(particles[i].x, particles[i].y)
          local xpo, ypo = cons(particles[j].x, particles[j].y)

          gpp.drawLine(xp + pxo, yp + pyo,
                       xpo + pxo, ypo + pyo, math.ceil((1000 - dist) * 15 / 1000) + 1)
        end
      end
    end
  end

  for i = 1, #particles do
    particles[i]:draw()
  end

  gpu.swap()
end

local function update(dt)
  for i = 1, #particles do
    particles[i]:update(dt)
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

gpu.clear()

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

gpu.blitPalette(op)
