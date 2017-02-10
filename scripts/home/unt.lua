local running = true

local write = write

local buffer = {}

local width = 20
local height = 20

for i = 1, width do
  buffer[i] = {}
  for j = 1, height do
    buffer[i][j] = {"a", 16, 1}
  end
end

local function processEvent(e, ...)
  local data = {...}
  if e == "key" then
    local k = data[1]
    
    if k == "Escape" then
      running = false
    end
  end
end

local function drawContent()
  for i = 1, width do
    for j = 1, height do
      local ind = buffer[i][j]

      gpu.drawRectangle((i - 1) * 7, (j - 1) * 7, 7, 7, ind[3])
      write(ind[1], (i - 1) * 7, (j - 1) * 7, ind[2])
    end
  end
end

local eventQueue = {}
while running do
  while true do
    local e = {coroutine.yield()}
    if not e[1] then break end
    eventQueue[#eventQueue + 1] = e
  end
  
  while #eventQueue > 0 do
    processEvent(unpack(eventQueue[1]))
    table.remove(eventQueue, 1)
  end
  
  gpu.clear()
  
  drawContent()
  
  gpu.swap()
end
