--[[

Part(icle test)

A neat demo set in space where you control a ship with the arrow
keys, demonstrating how a particle system can be used to create
various effects in an efficient and beautiful manner.

]]

local rif = require "rif"
local gpp = require "gpp"

local sw, sh = gpu.width, gpu.height
local fl = math.floor

local sqrt, atan2 = math.sqrt, math.atan2
local sin, cos = math.sin, math.cos
local sec = function(x) return 1 / cos(x) end

-- I'm not sure where this function came from but I didn't write it
local function class(superclass, name)
 local cls = {}
 cls.__name = name or ""
 cls.__super = superclass
 cls.__index = cls
 return setmetatable(cls, {__call = function (c, ...)
  local self = setmetatable({}, cls)
  local super = cls.__super
  while (super~=nil) do
   if super.__init then
    super.__init(self, ...)
   end
   super = super.__super
  end
  if cls.__init then
   cls.__init(self, ...)
  end
  return self
 end})
end

local running = true

local clc = 0

local op = gpu.getPalette()
local pal = {
    {13,  8,   13 },
    {79,  43,  36 },
    {109, 69,  52 },
    {4,   255, 255},
    {141, 4,   4  },
    {251, 0,   0  },
    {255, 137, 4  },
    {255, 255, 0  },
    {0,   153, 0  },
    {105, 137, 187},
    {48,  105, 160},
    {16,  32,  95 },
    {23,  0,   33 },
    {255, 0,   0  },
    {255, 0,   255},
    {255, 255, 255}
}

gpu.blitPalette(pal)

local circH = fs.open("part.rif", "rb")
local circData = circH:read("*all")
circH:close()

local circ, w, h = rif.decode1D(circData)

local circles = {}
for i = 0, (w + 1) / 7 - 1 do
  circles[i + 1] = {}

  for j = 0, h - 1 do
    for k = 1, h do
      circles[i + 1][j * h + k] = circ[i * 7 + j * w + k]
    end
  end
end

local curs, cw, ch = rif.createImage("target.rif")

local mouse = {sw / 2, sh / 2}

local pmap = {
  [0]  = 5,
  [5]  = 6,
  [6]  = 7,
  [7]  = 8,
  [8]  = 4,
  [4]  = 16,
  [16] = 16
}

local bmap = {
  [0]  = 12,
  [12] = 11,
  [11] = 10,
  [10] = 4,
  [4]  = 4
}

local partCyc = {
  8, 16, 0, 8, 16, 2
}

local ship = {0, 0, -3 * math.pi / 4, 0, 0}
local missiles = {}

local fbo = {}
for i = 1, sw * sh do
  fbo[i] = 1
end

local stars = {}

for _ = 1, 100 do
  local zsp = math.random(1000, 2000) / 1000
  local vpx = (sw / 2) * zsp
  local vpy = (sh / 2) * zsp
  local star = {math.random(-vpx, vpx) - (sw / 2),
                math.random(-vpy, vpy) - (sh / 2), zsp}
  stars[#stars + 1] = star
end

local parts = {}
local exparts = {}

local asts = {}

local Destructable = class(nil, "DeObj")

function Destructable:__init(x, y, poly, vx, vy)
  self.x = x
  self.y = y
  self.vx = vx or 0
  self.vy = vy or 0
  self.rotation = 0
  self.poly = poly

  local polyR = 0
  for i = 1, #poly do
    polyR = polyR + math.sqrt(poly[i][1] * poly[i][1] + poly[i][2] * poly[i][2])
  end

  self.polyR = polyR / #poly
end

function Destructable:update(dt)
  self.rotation = self.rotation + dt

  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt

  self.vx = self.vx + self.vx * -dt
  self.vy = self.vy + self.vy * -dt

  self.vy = self.vy * 0.99
end

function Destructable:draw()
  local offsetX = ship[1] - sw / 2
  local offsetY = ship[2] - sh / 2

  local rot = self.rotation
  local plist = self.poly

  local drawFigure = {}
  for i = 1, #plist do
    local ppos = plist[i]

    local ang = math.atan2(ppos[2], ppos[1])
    local dst = math.sqrt(ppos[1] * ppos[1] + ppos[2] * ppos[2])

    drawFigure[#drawFigure + 1] = {-offsetX + math.cos(rot + ang) * dst + self.x, -offsetY + math.sin(rot + ang) * dst + self.y}
  end

  -- For debugging collision circles
  -- gpp.fillCircle(-offsetX + self.x, -offsetY + self.y, self.polyR, 16)

  gpp.fillPolygon(drawFigure, 2)
end

function Destructable:destruct(maxSplit)
  local newPolys = {}

  maxSplit = maxSplit or math.huge

  local splitSeg = math.min(maxSplit, #self.poly / 2)
  local amount = math.floor(#self.poly / splitSeg)

  for i = 0, splitSeg - 1 do
    if i == splitSeg - 1 then
      amount = #self.poly
    end

    if amount <= 2 then
      break
    end

    local myPoly = {{0, 0}}
    for _ = 1, amount do
      local npp = table.remove(self.poly, 1)
      myPoly[#myPoly + 1] = npp
    end

    local ax, ay = 0, 0
    for j = 1, #myPoly do
      ax = ax + myPoly[j][1]
      ay = ay + myPoly[j][2]
    end

    local cx, cy = ax / #myPoly, ay / #myPoly

    for j = 1, #myPoly do
      myPoly[j] = {myPoly[j][1] - cx, myPoly[j][2] - cy}
    end

    newPolys[#newPolys + 1] = Destructable(self.x, self.y, myPoly, cx * 8 + math.random(-30, 30), cy * 8 + math.random(-30, 30))
  end

  return newPolys
end

local function genAst()
  local lst = {}
  for i = 1, 16 do
    local dst = math.random(9, 12)
    lst[i] = {
      math.cos(math.pi * i / 8) * dst,
      math.sin(math.pi * i / 8) * dst
    }
  end

  return lst
end

asts[1] = Destructable(60, 60, genAst())
asts[2] = Destructable(-40, -80, genAst())

local function switch(val)
  return function(tbl)
    if tbl[val] then
      tbl[val]()
    elseif tbl.default then
      tbl.default()
    end
  end
end

local shake = 0

local function draw()
  local offsetX = ship[1] - sw / 2
  local offsetY = ship[2] - sh / 2

  if shake > 0 then
    offsetX = offsetX + math.random(-shake, shake)
    offsetY = offsetY + math.random(-shake, shake)
    shake = shake - 1
  end

  gpu.clear()

  for i = 1, #stars do
    local star = stars[i]
    local x = (star[1] - offsetX) / star[3] + (sw / 2)
    local y = (star[2] - offsetY) / star[3] + (sh / 2)

    if x < 0 then
      star[1] = (2 * offsetX + star[3] * sw) / 2
      x = sw
    elseif x >= sw then
      star[1] = (2 * offsetX - star[3] * sw) / 2
      x = 0
    end

    if y < 0 then
      star[2] = (2 * offsetY + star[3] * sh) / 2
      y = sh
    elseif y >= sh then
      star[2] = (2 * offsetY - star[3] * sh) / 2
      y = 0
    end

    gpu.drawPixel(x, y, 16)
  end

  for i = 1, sw * sh do
    fbo[i] = 0
  end

  for i = 1, #parts do
    local part = parts[i]
    local stage = circles[part[3]]

    for j = 1, h do
      for k = 1, h do
        local xv = fl(part[1] - offsetX) + j - 1
        local yv = fl(part[2] - offsetY) + k - 1
        if xv <= sw and xv >= 1 and yv <= sh and yv >= 1 then
          if stage[(k - 1) * h + j] == 1 then
            local index = xv + (yv - 1) * sw
            local prev = fbo[index]
            if part[6] == 1 then
              fbo[index] = pmap[prev] or pmap[0]
            else
              fbo[index] = bmap[prev] or bmap[0]
            end
          end
        end
      end
    end
  end

  gpu.blitPixels(0, 0, sw, sh, fbo)

  local verts = {
    {0, -3},
    {0, 3},
    {-10, 0}
  }

  local tverts = {}

  for i = 1, #verts do
    local x, y = verts[i][1], verts[i][2]

    local mag = math.sqrt(x * x + y * y)
    local ang = math.atan2(y, x)
    x, y = math.cos(ship[3] + ang) * mag + ship[1], math.sin(ship[3] + ang) * mag + ship[2]
    x, y = math.floor(x - offsetX), math.floor(y - offsetY)

    tverts[#tverts + 1] = {x, y}

    if i > 1 then
      gpp.drawLine(tverts[i - 1][1], tverts[i - 1][2], x, y, 16)

      if i == #verts then
        gpp.drawLine(x, y, tverts[1][1], tverts[1][2], 16)
      end
    end
  end

  for i = 1, #asts do
    asts[i]:draw()
  end

  for i = #exparts, 1, -1 do
    gpp.fillCircle(math.floor(-offsetX + exparts[i][1]), math.floor(-offsetY + exparts[i][2]), math.floor(exparts[i][3] - exparts[i][4]), partCyc[math.floor(exparts[i][4] / 0.4)] or 2)
    exparts[i][4] = exparts[i][4] + 0.4
    if exparts[i][3] - exparts[i][4] <= 0 then
      table.remove(exparts, i)
    end
  end

  curs:render(mouse[1] - cw / 2, mouse[2] - ch / 2, 0, 0, 16, 16, 1)

  gpu.swap()
end

local kd = {}

local acc = 0
local function update(dt)
  clc = clc + dt
  acc = acc + dt
  if acc > 0.1 then
    acc = 0

    for i = #parts, 1, -1 do
      parts[i][3] = parts[i][3] + 1
      if parts[i][3] > #circles then
        table.remove(parts, i)
      end
    end
  end

  for i = 1, #asts do
    asts[i]:update(dt)
  end

  for i = #missiles, 1, -1 do
    local missile = missiles[i]

    local sdx = missile[1] - ship[1]
    local sdy = missile[2] - ship[2]
    local dist = sdx * sdx + sdy * sdy
    if dist > 100000000 then
      table.remove(missiles, i)
    else
      missile[4] = missile[4] + math.cos(missile[3]) * dt * 80
      missile[5] = missile[5] + math.sin(missile[3]) * dt * 80

      missile[1] = missile[1] + dt * missile[4]
      missile[2] = missile[2] + dt * missile[5]

      local good = true
      for fi = 1, #asts do
        local ast = asts[fi]
        local distX = missile[1] - ast.x
        local distY = missile[2] - ast.y
        if math.sqrt(distX * distX + distY * distY) <= ast.polyR then
          local opr = ast.polyR
          local dd = table.remove(asts, fi):destruct(math.random(3, 5))
          for xi = 1, #dd do
            asts[#asts + 1] = dd[xi]
          end

          local p1, p2 = missile[1], missile[2]
          exparts[#exparts + 1] = {p1, p2, 12, 1}
          p1, p2 = p1 + math.random(-6, 6), p2 + math.random(-6, 6)
          exparts[#exparts + 1] = {p1, p2, 8, 0}
          p1, p2 = p1 + math.random(-3, 3), p2 + math.random(-3, 3)
          exparts[#exparts + 1] = {p1, p2, 4, -1}

          shake = math.sqrt(opr) * 3

          speaker.stopAll()
          speaker.play({channel = 5, frequency = 600, time = 0.5, shift = -550, volume = 0.28, attack = 0, release = 0.4})

          table.remove(missiles, i)
          good = false

          break
        end
      end

      if good then
        parts[#parts + 1] = {missile[1] + math.random(-2, 2), missile[2] + math.random(-2, 2), 1, missile[4] / 2 * math.cos(missile[3]), missile[4] / 2 * math.sin(missile[3]), 2}
      end
    end
  end

  for i = 1, #parts do
    parts[i][1] = parts[i][1] + parts[i][4] * dt
    parts[i][2] = parts[i][2] + parts[i][5] * dt
    parts[i][4] = parts[i][4] * 0.99
    parts[i][5] = parts[i][5] * 0.99
  end

  if kd.left then
    ship[3] = ship[3] - 4 * dt
  elseif kd.right then
    ship[3] = ship[3] + 4 * dt
  end

  if kd.up then
    ship[4] = ship[4] + math.cos(ship[3]) * dt * 80
    ship[5] = ship[5] + math.sin(ship[3]) * dt * 80
    if ship[4] > 100 then
      ship[4] = 100
    end
  end

  ship[1] = ship[1] - dt * ship[4]
  ship[2] = ship[2] - dt * ship[5]

  ship[4] = ship[4] * 0.98
  ship[5] = ship[5] * 0.98

  if kd.up then
    parts[#parts + 1] = {ship[1] + math.random(-2, 2), ship[2] + math.random(-2, 2), 1,
      40 * math.cos(ship[3]), 40 * math.sin(ship[3]), 1}
  end
end

local function event(e, ...)
  if e == "key" then
    local k = ...
    switch(k) {
      escape = function()
        running = false
      end
    }

    kd[k] = true

    if k == "up" then
      speaker.play({channel = 5, frequency = 300, time = 50, shift = 0, volume = 0.1, attack = 0, release = 0})
    elseif k == "left" or k == "right" then

      speaker.play({channel = 3, frequency = 50, time = 0.1, shift = 0, volume = 0.08, attack = 0.1, release = 0})

      for _ = 1, 10 do
        speaker.play({channel = 3, frequency = 50, time = 0.1, shift = -5, volume = 0.08, attack = 0, release = 0})
        speaker.play({channel = 3, frequency = 45, time = 0.1, shift = 5, volume = 0.08, attack = 0, release = 0})
      end
    end
  elseif e == "keyUp" then
    local k = ...
    kd[k] = false

    if k == "up" then
      speaker.stopChannel(5)
    elseif k == "left" or k == "right" then
      speaker.stopChannel(3)
      speaker.play({channel = 3, frequency = 50, time = 0.1, shift = 0, volume = 0.08, attack = 0, release = 0.1})
    end
  elseif e == "mouseMoved" then
    local x, y = ...
    mouse = {x, y}
  elseif e == "mousePressed" then
    local mx, my, _ = ...

    local theta = 0
    local dist = math.huge

    local x, y = mx - sw / 2, my - sh / 2
    local a = 80
    local vx0, vy0 = -ship[4], -ship[5]

    local v0 = sqrt(vx0 * vx0 + vy0 * vy0)
    local i0 = atan2(vy0, vx0)

    local x0, y0 = 0, 0

    for i = 0, math.pi * 2, 0.001 do
      local tm = (((-v0)*cos(i0) + sqrt(2*a*(x-x0)*cos(i) + v0*v0*cos(i0)*cos(i0))) * sec(i))/a
      local tm2 = -(((v0*cos(i0) + sqrt(2*a*(x-x0)*cos(i) + v0*v0*cos(i0)*cos(i0))) * sec(i))/a)

      local tch = tm == tm and tm or nil
      local tch2 = tm2 == tm2 and tm2 or nil

      if tch then
        local test = {tch, tch2}
        for j = 1, 2 do
          local tnum = test[j]
          if tnum >= 0 then
            local fx = ((a * cos(i) * tnum * tnum) / 2) + (v0 * cos(i0) * tnum) + x0
            local fy = ((a * sin(i) * tnum * tnum) / 2) + (v0 * sin(i0) * tnum) + y0

            local dd = math.sqrt((x - fx) * (x - fx) + (y - fy) * (y - fy))
            if dd < dist then
              theta = i
              dist = dd
            end
          end
        end
      end
    end

    local missile = {ship[1], ship[2], theta, -ship[4], -ship[5]}
    missiles[#missiles + 1] = missile

    speaker.play({channel = 5, frequency = 7000, time = 1.2, shift = -500, volume = 0.1, attack = 0.1, release = 0.5})
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

gpu.blitPalette(op)
speaker.stopAll()