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

local lineHistory = {{{"rikoOS 1.0"}, {13}}}
local historyPoint = 2
function pushOutput(msg, c)
  lineHistory[#lineHistory + 1] = {{msg}, {c or 15}}
  historyPoint = #lineHistory + 1
end

local prefix = "> "
local str = ""

local e, p1, p2
local lastP = 0

local lastf = 0
local fps = 60

while true do
  gpu.clear()

  local ctime = os.clock()
  local delta = ctime - lastf
  lastf = ctime
  fps = fps + (1 / delta - fps)*0.01

  write("FPS: " .. tostring(round(fps, 0.01)), 2, 190)

  for i=1, 16 do
    gpu.drawRectangle(i*8 + 2, 100, 8, 8, i)
    write(tostring(i):sub(#tostring(i)), i*8 + 1, 100, (20 % i == 0) and 0 or 1)
  end

  lineHistory[historyPoint] = {
    {prefix, str,
    (math.floor((os.clock() * 2 - lastP) % 2) == 0 and "_" or "")},
    {10, 16, 16}
  }

  for i=1, #lineHistory do
    local cpos = 2
    for j=1, #lineHistory[i][1] do
      write(tostring(lineHistory[i][1][j]), cpos, (i - 1)*8 + 2, lineHistory[i][2][j])
      cpos = cpos + #tostring(lineHistory[i][1][j])*7
    end
  end

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
      if str == "" then
        lineHistory[historyPoint][1][3] = "" -- Remove the "_" if it is there
        historyPoint = historyPoint + 1
      else
        lineHistory[historyPoint][1][3] = "" -- Remove the "_" if it is there
        local startPoint = historyPoint
        local cfunc = loadfile(str:match("%S+")..".lua")
        if cfunc then
          local cc = coroutine.create(cfunc)
          local splitStr = split(str)
          table.remove(splitStr, 1)
          local ev = splitStr or {}
          local upfunc = table.unpack and table.unpack or unpack
          while coroutine.status(cc) ~= "dead" do
            local s, er = coroutine.resume(cc, upfunc(ev))
            if not s then
              print(er)
            end
            ev = {coroutine.yield()}
          end
        else
          pushOutput("Unknown program `"..str:match("%S+").."`", 7)
        end
        if historyPoint == startPoint then
          historyPoint = historyPoint + 1
        end
        str = ""
      end
    end
  elseif e == "mouseWheel" then
    write(tostring(p1), 2, 60)
    write(tostring(p2), 2, 70)
  end
  e, p1, p2 = coroutine.yield()

  gpu.swap()
end
