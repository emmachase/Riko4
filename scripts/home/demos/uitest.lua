gpu.push()

local ui = dofile("/lib/ui.lua")

local running = true

local cur = ui.cursor()

local hov = image.newImage(8, 8)
local idl = image.newImage(8, 8)
local act = image.newImage(8, 8)

idl:drawRectangle(0, 0, 8, 8, 6)  idl:flush()
hov:drawRectangle(0, 0, 8, 8, 7)  hov:flush()
act:drawRectangle(0, 0, 8, 8, 16) act:flush()

local btn = ui.button.new({
  display = "image",
  active = act,
  hover = hov,
  idle = idl
}, 15, 15, 8, 8)

local i = 0
local function draw()
  i = i + 1

  gpu.clear()

  btn:draw()

  cur:render()

  write("WIP! Wayy more to come! ;)", 50, 16, i / 5 % 16)

  gpu.swap()
end

local function update(dt)
  -- Do nothing
end

local function event(e, ...)
  cur:event(e, ...)

  local evp = btn:event(e, ...)
  if not evp then
    if e == "key" then
      local k = ...
      if k == "escape" then
        running = false
      end
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

gpu.pop()
