-- GhostsBenchmark by MonstersGoBoom
-- Adapted for Riko4
local rif = dofile("/lib/rif.lua")

local w, h = gpu.width, gpu.height

local running = true

local fl = math.floor

local spsheet = rif.createImage("ghost.rif")

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

local function Sprite(id, x, y)
  local spx = id % 4
  local spy = fl(id / 4)

  spsheet:render(x, y, spx * 8, spy * 8, 8, 8)
end

local Items = {}

local Item = class(nil,"Stuff")

function Item:__init()
 self.x = math.random(10, w - 8)
 self.y = math.random(10, h - 20)
 self.vx = math.random(-10,10) / 10.0
 self.vy = math.random(-10,10) / 10.0
 self.color = math.random(15)
 table.insert(Items,self)
end

function Item:update()
 self.x = self.x + self.vx
 self.y = self.y + self.vy

 if self.x<0 or self.x>w - 8 then
  self.vx = -self.vx
 end
 if self.y > h - 20 then
  self.y = h - 32
  self.vy = -(math.random(100)/25.0)
 end

 Sprite(self.color,self.x,self.y)
 self.vy = self.vy + 0.05
end



for _=1,500 do
 Item()
end

local fps = 60

local function _update(dt)
 fps = 1 / dt

 gpu.clear(0)

 for x=1,#Items do
  Items[x]:update()
 end

 write("Dots :" .. #Items, 8,9, 1)
 write("Dots :" .. #Items, 8,8, 8)
 write("FPS :" .. fps, 8,17, 1)
 write("FPS :" .. fps, 8,16, 8)

 -- add 500 more
 write("press A to add 500 more", 8, h - 12)



--  if btnp(5) then
--    for x=1,500 do
--     bunny = Item()
--    end
--  end
end

local function event(e, ...)
  if e == "key" then
    local k = ...
    if k == "escape" then
      running = false
    elseif k == "a" then
      for _=1,500 do
        Item()
      end
    end
  end
end

local eventQueue = {}
local last = os.clock()
while running do
  while true do
    local e = {coroutine.yield()}
    if not e[1] then break end
    eventQueue[#eventQueue + 1] = e
  end

  for _ = #eventQueue, 1, -1 do
    local e = table.remove(eventQueue, 1)
    event(unpack(e))
  end

  local stf = os.clock() - last
  last = os.clock()
  _update(stf)


  gpu.swap()
  -- draw()
end