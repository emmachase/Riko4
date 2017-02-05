dofile("scripts/adaptIO.lua")

local font = dofile("../font.lua")

local dataH = io.open("../coreFont", "r")
local data = dataH:read("*a")
dataH:close()


local coreFont = font.new(data)
gpu.font = coreFont

function write(t, x, y, col)
  t = tostring(t)
  col = col or 16
  local xoff = 0
  for i=1, #t do
    local text = t:sub(i, i)
    local c = string.byte(text)
    if gpu.font.data[c] then
      for j=1, 7 do
        for k=1, 7 do
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

loadfile("../shell.lua")() -- dofile creates a seperate thread, so coroutines get messed up