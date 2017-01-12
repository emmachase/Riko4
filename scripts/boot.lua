local font = dofile("scripts/font.lua")

local dataH = io.open("scripts/coreFont", "r")
local data = dataH:read("*a")
dataH:close()

local coreFont = font.new(data)
gpu.font = coreFont

function write(t, x, y, col)
  col = col or 1
  local xoff = 0
  for i=1, #t do
    local text = t:sub(i, i)
    local c = string.byte(text)
    if gpu.font.data[c] then
      for j=1, 7 do--#coolfont.data[c] do
        for k=1, 7 do--#coolfont.data[c][j] do
          if gpu.font.data[c][j][k] then
            local dx = x + xoff + k
            local dy = y + j
            gpu.drawPixel(dx, dy, col)
          end
        end
      end
    end
    xoff = xoff + 7
  end
end

function sleep(s)
  local stime = os.clock()
  while true do
    coroutine.yield()
    local ctime = os.clock()
    if ctime - stime >= s then
      break
    end
  end
end

local write = write

local function pullEvent(filter)
  local e
  while true do
    e = {coroutine.yield()}
    if not filter or e[1] == filter then
      break
    end
  end
  write(e[2])
  return unpack(e)
end

local prefix = "> "
local str = ""

local e, p1
local lastP = 0

local lastf = 0
local fps = 60

local function round(n, p)
  return math.floor(n / p) * p
end

local function split(str)
  local tab = {}
  for word in str:gmatch("%S+") do
    tab[#tab + 1] = word
  end
  return tab
end

while true do
  gpu.clear()

  local ctime = os.clock()
  local delta = ctime - lastf
  lastf = ctime
  fps = fps + (1 / delta - fps)*0.01

  write("FPS: " .. tostring(round(fps, 0.01)), 2, 190)

  write("rikoOS 1.0", 2, 2, 4)

  for i=0, 9 do
    gpu.drawRectangle(i*8 + 2, 100, 8, 8, i)
    write(tostring(i), i*8 + 1, 100, (i == 1 or i == 4 or i == 5) and 0 or 1)
  end

  -- love.timer.sleep(1)
  write(prefix, 2, 10, 4) write(str, 10, 10) write((math.floor((os.clock() * 2 - lastP) % 2) == 0 and "_" or ""), 10+(#str*7), 11)

  write(tostring(e), 2, 50)
  if e == "char" then
    str = str .. p1
    lastP = os.clock() * 2
  elseif e == "key" then
    write(tostring(p1), 2, 60)
    if p1 == "Backspace" then
      str = str:sub(1, #str - 1)
      lastP = os.clock() * 2
    elseif p1 == "Return" then
      local cc = coroutine.create(loadfile("scripts/home/"..str:match("%S+")..".lua"))
      local splitStr = split(str)
      table.remove(splitStr, 1)
      local e = splitStr or {}
      while coroutine.status(cc) ~= "dead" do
        coroutine.resume(cc, unpack(e))
        e = {coroutine.yield()}
      end
    end
  end
  e, p1 = coroutine.yield()

  gpu.swap()
end
