local running = true

local eventQueue = {}

local function processEvent(e, ...)
  local data = {...}
  if e == "key" then
    local key = data[1]
    
    if key == "Return" then
      pushOutput("Waddup")
    elseif key == "escape" then
      running = false
    end
  end
end

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

  shell.redraw()
end
