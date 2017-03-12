local rif = dofile("../lib/rif.lua")

-- 2d terrain demo
-- by @powersaurus
local running = true

local width=128
local height=128

local terrain={}
local per_pixel_terrain={}

local function time()
  return os.clock() * 1000
end

local lines=1
local textured=2
local per_pixel=3
local drawmode=per_pixel
local drawmodes={"lines", "textured", "per-pixel"}
local texture = rif.createImage("tex.rif")

local global_randomness=30
local initial_height=60
local current_seed=time()

local function line(x1, y1, x2, y2, c)
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

local function generate_height_at_midpoint(left,right,randomness)
 terrain[math.floor((left+right)/2)]=
  (terrain[left]+
   terrain[right])/2
    +(math.random()*randomness-(randomness/2))
end


local function generate_terrain(randomness)
 for i=1,width do
  terrain[i]=initial_height
 end

 local step=math.floor(width/2)

 while(step>=1) do
  local segmentstart=1
  while(segmentstart<=width) do
   local left=segmentstart
   local right=left+step
   if right>width then
    right = right - width
   end
   generate_height_at_midpoint(left,right,randomness)
   segmentstart = segmentstart + step
  end
  randomness = randomness / 2
  step = step / 2
 end
end

local function copy_terrain_to_per_pixel_terrain()
 local c
 for x=1,width do
  local ground_thickness=math.floor(math.random()*3)
  per_pixel_terrain[x]={}
  for y=1,terrain[x] do
    local height_here=terrain[x]
    if y>height_here-1 then
     c=4
    elseif y>height_here-(2+ground_thickness) then
     c=11
    elseif y>height_here-(3+ground_thickness) then
     c=4
    elseif y>height_here-(5+ground_thickness) then
     c=2
    elseif y>height_here-(7+ground_thickness) then
     c=3
    elseif math.floor(math.random(0, 2))==0 then
     c=5
    else
     c=3
    end
    per_pixel_terrain[x][y]=c
  end
 end
end

local function regenerate(randomness)
 math.randomseed(current_seed)
 generate_terrain(randomness)
 copy_terrain_to_per_pixel_terrain()
end

local function draw_with_lines()
 for i=1,width do
  line(i-1,128,i-1,128-terrain[i],3)
 end
end

local function draw_textured()
 for i=1,width do
  -- sspr(i%32,0,1,32,i-1,128-terrain[i])
  texture:render(i - 1, 128 - terrain[i], i % 22, 0, 1, 30)

  line(i-1,128,i-1,math.floor(128-(terrain[i]-30)),2)
 end
end

local function draw_per_pixel_terrain()
 for x=1,width do
  for y=1,height do
   if per_pixel_terrain[x][y] ~= nil then
    gpu.drawPixel(
     x-1,
     (height)-y,
     per_pixel_terrain[x][y])
   end
  end
 end
end

local function _init()
 current_seed=time()
 regenerate(global_randomness)
end

-- left, right, up, down, x
local prd = {false, false, false, false, false}
local lst = {false, false, false, false, false}
local function btnp(b)
  local v = prd[b] and not lst[b]
  lst[b] = prd[b]
  return v
end

local function _update()
 if btnp(5) then
  current_seed=time()
  regenerate(global_randomness)
 end
 if btnp(2) then
  drawmode=math.max(1,(drawmode+1) % (#drawmodes+1))
 elseif btnp(1) then
  drawmode=drawmode-1
  if drawmode==0 then
   drawmode=3
  end
 end

 if btnp(4) then
  global_randomness=math.max(0,global_randomness-5)
  regenerate(global_randomness)
 elseif btnp(3) then
  global_randomness=math.min(200,global_randomness+5)
  regenerate(global_randomness)
 end
end

local function _draw()
  gpu.drawRectangle(0,0,128,128,12)
  if drawmode==lines then
   draw_with_lines()
  elseif drawmode==textured then
   draw_textured()
  elseif drawmode==per_pixel then
   draw_per_pixel_terrain()
  end
  write("< draw mode: "..drawmodes[drawmode].. " >",1,128,16)
  write("< randomness range: "..global_randomness.." >",1,136,16)
  write("X regenerate",1,144,16)
end

local function processEvent(e, ...)
  local args = {...}
  if e == "key" or e == "keyUp" then
    local key = args[1]
    if key == "Escape" then
      running = false
    elseif key == "Left" then
      prd[1] = e == "key"
    elseif key == "Right" then
      prd[2] = e == "key"
    elseif key == "Up" then
      prd[3] = e == "key"
    elseif key == "Down" then
      prd[4] = e == "key"
    elseif key == "X" then
      prd[5] = e == "key"
    end
  end
end

local eventQueue = {}
_init()
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

  _update()

  gpu.clear()

  _draw()

  gpu.swap()
end
