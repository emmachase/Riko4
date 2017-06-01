local ox = os.exit
os.exit = function() error("Nope") end
if not riko4 then riko4 = {} end
riko4.exit = ox

local w, h = gpu.width, gpu.height

local write = write

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

local oldPrint = print

local pureHistory = {}
local pureHistoryPoint = 1

shell = {}
local shell = shell

local lineHistory = {{{"rikoOS 1.0"}, {13}}}

local function insLine(t, c)
  table.insert(lineHistory[#lineHistory][1], t)
  table.insert(lineHistory[#lineHistory][2], c)
end

local historyPoint = 2
local lineOffset = 0
local c = 4
function pushOutput(msg, ...)
  msg = tostring(msg)
  local ar = {...}
  for k,v in ipairs(ar) do
    msg = msg .. "  " .. tostring(v)
  end
  insLine(msg, 16)
  lineHistory[#lineHistory + 1] = {{}, {}}
  historyPoint = #lineHistory + 1
  if historyPoint - lineOffset >= 200 / 8 - 1 then
    lineOffset = historyPoint - (200 / 8 - 2)
  end
  shell.redraw(true)
end

function writeOutputC(msg, c, rd)
  msg = tostring(msg)

  while msg:find("\n") do
    local pos = msg:find("\n")
    local fsub = msg:sub(1, pos - 1)
    insLine(fsub, c or 16)
    msg = msg:sub(pos + 1)
    lineHistory[#lineHistory + 1] = {{}, {}}
    historyPoint = #lineHistory + 1
    if historyPoint - lineOffset >= 200 / 8 - 1 then
      lineOffset = historyPoint - (200 / 8 - 2)
    end
  end
  insLine(msg, c or 16)
  _ = rd and shell.redraw(true) or 1
end

local prefix = "> "
local str = ""
local path = ""

-- local e, p1, p2
local lastP = 0

local lastf = 0
local fps = 60

local mouseX, mouseY = 0, 0

function shell.redraw(swap)
  swap = (swap == nil) and swap or true -- just to be explicit

  gpu.clear()

  local ctime = os.clock()
  local delta = ctime - lastf
  lastf = ctime
  fps = fps + (1 / delta - fps)*0.01

  for i = math.max(lineOffset, 1), #lineHistory do
    local cpos = 2
    for j = 1, #lineHistory[i][1] do
      write(tostring(lineHistory[i][1][j]), cpos, (i - 1 - lineOffset)*8 + 2, lineHistory[i][2][j])
      cpos = cpos + #tostring(lineHistory[i][1][j])*7
    end
  end

  gpu.drawRectangle(0, h - 10, w, 10, 6)
  write("FPS: " .. tostring(round(fps, 0.01)), 2, 189)

  gpu.drawRectangle(mouseX, mouseY, 2, 1, 7)
  gpu.drawRectangle(mouseX, mouseY, 1, 2, 7)

  if swap then
    gpu.swap()
  end
end

local lastRun = ""
function shell.getRunningProgram()
  return lastRun:match("(.+)%.lua")
end

local function update()
  lineHistory[historyPoint] = {
    {path, prefix, str,
    (math.floor((os.clock() * 2 - lastP) % 2) == 0 and "_" or "")},
    {16, 10, 16, 16}
  }

  shell.redraw()
end

local function processEvent(e, ...)
  local args = {...}
  local p1, p2 = args[1], args[2]
  if e == "char" then
    str = str .. p1
    lastP = os.clock() * 2
  elseif e == "mouseMoved" then
    mouseX, mouseY = p1, p2
  elseif e == "key" then
    if p1 == "backspace" then
      str = str:sub(1, #str - 1)
      lastP = os.clock() * 2
    elseif p1 == "up" then
      pureHistoryPoint = pureHistoryPoint - 1
      if pureHistoryPoint < 1 then
        pureHistoryPoint = 1
      else
        str = pureHistory[pureHistoryPoint]
      end
    elseif p1 == "down" then
      pureHistoryPoint = pureHistoryPoint + 1
      if pureHistoryPoint > #pureHistory then
        pureHistoryPoint = #pureHistory + 1
        str = ""
      else
        str = pureHistory[pureHistoryPoint]
      end
    elseif p1 == "return" then
      if not str:match("%S+") then
        lineHistory[historyPoint][1][4] = "" -- Remove the "_" if it is there
        historyPoint = historyPoint + 1
        str = ""
      else
        lineHistory[historyPoint][1][4] = "" -- Remove the "_" if it is there
        pureHistoryPoint = #pureHistory + 2
        pureHistory[pureHistoryPoint - 1] = str

        local startPoint = historyPoint

        lineHistory[#lineHistory + 1] = {{}, {}}
        historyPoint = historyPoint + 1
        local cfunc
        lastRun = str
        local s, er = pcall(function() cfunc = loadfile(str:match("%S+")..".lua") end)
        if not s then
          c = 7
          if er then
            er = er:sub(er:find("%:") + 1)
            er = er:sub(er:find("%:") + 2)
            pushOutput("Error: " .. tostring(er))
          else
            pushOutput("Error: Unknown error")
          end
        else
          if cfunc then
            local cc = coroutine.create(cfunc)
            local splitStr = split(str)
            table.remove(splitStr, 1)
            local ev = splitStr or {}
            local upfunc = table.unpack and table.unpack or unpack
            while coroutine.status(cc) ~= "dead" do
              local su, eru = coroutine.resume(cc, upfunc(ev))
              if not su then
                print(eru)
              end
              ev = {coroutine.yield()}
            end
            --cc = nil
            collectgarbage("collect")

            print = oldPrint
          else
            c = 7
            writeOutputC("Unknown program `" .. str:match("%S+") .. "`", 8)
            historyPoint = #lineHistory + 1
          end
          historyPoint = #lineHistory + 1
        end
        str = ""
      end
      if historyPoint - lineOffset >= 200 / 8 - 1 then
        lineOffset = historyPoint - (200 / 8 - 2)
      end
    end
  end
end

local eventQueue = {}
local last = os.clock()
while true do
  while os.clock() - last < (1 / 60) do
    while true do
      local e, p1, p2, p3, p4 = coroutine.yield()
      if not e then break end
      table.insert(eventQueue, {e, p1, p2, p3, p4})
    end

    while #eventQueue > 0 do
      processEvent(unpack(eventQueue[1]))
      table.remove(eventQueue, 1)
    end
  end
  last = os.clock()
  update()
end
