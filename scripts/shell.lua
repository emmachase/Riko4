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

local pureHistory = {}
local pureHistoryPoint = 1

local lineHistory = {{{"rikoOS 1.0"}, {13}}}
local historyPoint = 2
local lineOffset = 0
function pushOutput(msg, c)
  lineHistory[#lineHistory + 1] = {{msg}, {c or 16}}
  historyPoint = #lineHistory + 1
  if historyPoint >= 200 / 8 - 1 then
    lineOffset = lineOffset + 1
  end
end

local prefix = "> "
local str = ""
local path = ""

local e, p1, p2
local lastP = 0

local lastf = 0
local fps = 60

local mouseX, mouseY = 0, 0

shell = {}
local shell = shell
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

  gpu.drawRectangle(0, 190, 340, 10, 6)
  write("FPS: " .. tostring(round(fps, 0.01)), 2, 191)

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

while true do
  lineHistory[historyPoint] = {
    {path, prefix, str,
    (math.floor((os.clock() * 2 - lastP) % 2) == 0 and "_" or "")},
    {16, 10, 16, 16}
  }

  shell.redraw()

  if e == "char" then
    str = str .. p1
    lastP = os.clock() * 2
  elseif e == "mouseMoved" then
    mouseX, mouseY = p1, p2
  elseif e == "key" then
    if p1 == "Backspace" then
      str = str:sub(1, #str - 1)
      lastP = os.clock() * 2
    elseif p1 == "Up" then
      pureHistoryPoint = pureHistoryPoint - 1
      if pureHistoryPoint < 1 then
        pureHistoryPoint = 1
      else
        str = pureHistory[pureHistoryPoint]
      end
    elseif p1 == "Down" then
      pureHistoryPoint = pureHistoryPoint + 1
      if pureHistoryPoint > #pureHistory then
        pureHistoryPoint = #pureHistory + 1
        str = ""
      else
        str = pureHistory[pureHistoryPoint]
      end
    elseif p1 == "Return" then
      if not str:match("%S+") then
        lineHistory[historyPoint][1][4] = "" -- Remove the "_" if it is there
        historyPoint = historyPoint + 1
        str = ""
      else
        lineHistory[historyPoint][1][4] = "" -- Remove the "_" if it is there
        pureHistoryPoint = #pureHistory + 2
        pureHistory[pureHistoryPoint - 1] = str

        local startPoint = historyPoint
        local cfunc
        lastRun = str
        local s, er = pcall(function() cfunc = loadfile(str:match("%S+")..".lua") end)
        if not s then
          if er then
            er = er:sub(er:find("%:") + 1)
            er = er:sub(er:find("%:") + 2)
            pushOutput("Error: " .. tostring(er), 7)
          else
            pushOutput("Error: Unknown error", 7)
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
          else
            pushOutput("Unknown program `"..str:match("%S+").."`", 7)
          end
          if historyPoint == startPoint then
            historyPoint = historyPoint + 1
          end
        end
        str = ""
      end
      if historyPoint >= 200 / 8 - 1 then
        lineOffset = lineOffset + 1
      end
    end
  end
  e, p1, p2 = coroutine.yield()
end
