fs.setCWD("/home/")

-- os.exit is used as the exit method for some scripts,
-- most notably, the Urn compiler. This prevents such
-- scripts from exiting Riko4 entirely.
do
  if not riko4 then riko4 = {} end
  riko4.exit = os.exit

  os.exit = function() error("User requested programmatic exit", 2) end
end


local scrnW, scrnH = gpu.width, gpu.height

-- Cursor
local cur
do
  local curRIF = "\82\73\86\2\0\6\0\7\1\0\0\0\0\0\0\0\0\0\0\1\0\0\31\16\0\31\241\0\31\255\16\31\255\241\31\241\16\1\31\16\61\14\131\0\24\2"
  local rif = dofile("/lib/rif.lua")
  local rifout, cw, ch = rif.decode1D(curRIF)
  cur = image.newImage(cw, ch)
  cur:blitPixels(0, 0, cw, ch, rifout)
  cur:flush()
end

-- Localizations
local write = write
local floor = math.floor
local font  = gpu.font.data
local fontW = font.w + 1 -- TODO: This must be changed after fonts overhaul
local fontH = font.h + 1
local rootPrint = print
debugTrace = rootPrint -- Used for Debug builds of Riko4

local mousePos = {-5, -5}

-- Setup Extension Handlers
local handlers = {}
do
  local shellItems = fs.list("/usr/shell")

  for i = 1, #shellItems do
    local name = shellItems[i]
    if name:sub(1, 5) == "_ext_" then
      -- Extension handler
      handlers[name:match("_ext_(.+)%.lua")] = dofile("/usr/shell/" .. name)
      print("Loaded " .. name:match("_ext_(.+)%.lua"))
    end
  end
end

-- Utility Functions
local function round(n, p)
  return floor(n / p) * p
end

local function shellSplit(str)
  local tab = {""}

  local inStr = false
  for i = 1, #str do
    local c = str:sub(i, i)
    
    if c == "\\" and str:sub(i + 1, i + 1) == "\"" then
      -- Do nothing
    elseif c == "\"" and str:sub(i - 1, i - 1) ~= "\\" then
      inStr = not inStr
    elseif inStr then
      tab[#tab] = tab[#tab] .. c
    elseif c:match("%s") and #(tab[#tab]) > 0 then
      tab[#tab + 1] = ""
    else
      tab[#tab] = tab[#tab] .. c
    end
  end

  return tab
end

local function getDir()
  local dir = fs.getCWD():gsub("%\\", "/")
  if dir:sub(#dir) == "/" then dir = dir:sub(1, #dir - 1) end
  return dir
end

local config = dofile("/shellcfg.lua")
table.insert(config.path, 1, ".") -- Shell should be able to run files from the CWD ;)

-- Terminal
-- Character buffer
local term = {
  width  = math.floor(scrnW / fontW),
  height = math.floor(scrnH / fontH),
  scrollAmt = 0,
  buffer = {},
  x = 1,
  y = 1,
  blink = -math.huge
}

for i = 1, term.height do
  term.buffer[i] = {}
  for j = 1, term.width do
    term.buffer[i][j] = {" ", 1, 16} -- Char, BG, FG
  end
end

function term.scroll(n)
  term.scrollAmt = term.scrollAmt + n

  if term.scrollAmt < 0 then
    term.scrollAmt = 0
  end

  for i = 1, term.height + term.scrollAmt - #term.buffer do
    local y = #term.buffer + 1
    term.buffer[y] = {}
    for j = 1, term.width do
      term.buffer[y][j] = {" ", 1, 16}
    end
  end
end

function term.write(text, fg, bg, x, y)
  text = tostring(text)
  x = x or term.x
  y = y or term.y

  local endC = ""
  local nl = false
  for i = 1, #text do
    local c = text:sub(i, i)
    if c == "\n" then
      endC = text:sub(i + 1)
      nl = true
      break
    else
      if x > term.width then endC = text:sub(i) break end

      if term.buffer[y] then
        local ind = term.buffer[y][x]
        ind[1] = c
        ind[2] = bg or ind[2]
        ind[3] = fg or ind[3]
      else
        endC = text:sub(i)
        break
      end

      x = x + 1
    end
  end

  term.x = x

  return endC, nl
end


-- Shell Library
shell = {config = config, term = term}
local shell = shell -- For performance

function shell.write(text, fg, bg, x, y)
  x = x or term.x
  y = y or term.y

  local nl

  if text then
    local remainder = text
    repeat
      term.y = y

      if y > term.height + term.scrollAmt then
        term.scroll(y - (term.height + term.scrollAmt))
      end

      remainder, nl = term.write(remainder, fg, bg, x, y)

      x = 1
      y = y + 1
    until remainder == ""
  end

  if nl then
    term.x = x
    term.y = y
  end
end

function shell.tabulate(...)
  local all = {...}

  local maxLen = term.width / 7
  for i = 1, #all do
    local t = all[i]
    if type(t) == "table" then
      for k, v in pairs(t) do
        maxLen = math.max(maxLen, #v + 1)
      end
    end
  end

  local cols = math.floor(term.width / maxLen)

  local color = nil
  for i = 1, #all do
    local t = all[i]
    if type(t) == "table" then
      if #t > 0 then
        
        local col = 1
        for j = 1, #t do
          local item = t[j]

          if col > cols then
            col = 1
            print()
          end

          shell.write((" "):rep((col - 1) * (maxLen + 1) - term.x) .. item, color)

          col = col + 1
        end

        if i < #all then
          print()
        end
      end
    elseif type(t) == "number" then
      color = t
    end
  end

  print()
end

function shell.read(replaceChar, size, history)
  local maxW = term.width - term.x + 1
  size = size and math.min(size, maxW) or maxW

  term.blink = 0

  local x, y = term.x, term.y

  local str = ""
  local strPos = 1
  local strScrollAmt = 0

  local historyPt = #history + 1

  local function checkBounds()
    if strPos - strScrollAmt > size then
      strScrollAmt = strPos - size
    elseif strPos - strScrollAmt < 1 then
      strScrollAmt = strPos - 1
    end
  end

  local alive = "ham"
  local evFunc
  while alive do
    evFunc = evFunc or function(e, ...)
      if e == "char" then
        local c = ...
        str = str:sub(1, strPos - 1) .. c .. str:sub(strPos)
        strPos = strPos + 1
        term.blink = 0
      elseif e == "key" then
        local k = ...
        if k == "left" and strPos > 1 then
          strPos = strPos - 1
          term.blink = 0
        elseif k == "right" and strPos <= #str then
          strPos = strPos + 1
          term.blink = 0
        elseif k == "up" then
          if history and historyPt > 1 then
            historyPt = historyPt - 1
            str = history[historyPt]
            strPos = #str + 1
          end
        elseif k == "down" then
          if history and historyPt < #history then
            historyPt = historyPt + 1
            str = history[historyPt]
            strPos = #str + 1
          end
        elseif k == "backspace" and strPos > 1 then
          str = str:sub(1, strPos - 2) .. str:sub(strPos)
          strPos = strPos - 1
          term.blink = 0
        elseif k == "delete" then
          str = str:sub(1, strPos - 1) .. str:sub(strPos + 1)
          term.blink = 0
        elseif k == "home" then
          strPos = 1
          term.blink = 0
        elseif k == "end" then
          strPos = #str + 1
          term.blink = 0
        elseif k == "return" then
          alive = false
        end
      elseif e == "mouseWheel" then
        local dir = -(...)
        if term.scrollAmt + dir > #term.buffer - term.height then
          term.scroll(#term.buffer - term.height - term.scrollAmt)
        else
          term.scroll(dir)
        end
      elseif e == "mouseMoved" then
        local x, y = ...
        mousePos = {x, y}
      end

      checkBounds()
    end
    shell.pumpEvents(evFunc)

    -- Draw
    local strToDraw = str:sub(strScrollAmt + 1, strScrollAmt + size)
    if replaceChar then
      strToDraw = (replaceChar):rep(#strToDraw)
    end
    term.write(strToDraw .. (" "):rep(size - #strToDraw), 16, 1, x, y)

    term.x = strPos - strScrollAmt + x - 1
    shell.draw()
  end

  term.blink = -math.huge
  term.x = 1
  term.y = y + 1
  return str
end

local pumpLast = os.clock()
function shell.pumpEvents(func)
  local eq = {}
  while true do
    local a = {coroutine.yield()}
    if not a[1] then break end
    table.insert(eq, a)
  end

  while #eq > 0 do
    local e = table.remove(eq, 1)
    func(unpack(e))
  end

  term.blink = term.blink + os.clock() - pumpLast
  pumpLast = os.clock()
end

-- Main Event Handlers
function shell.draw()
  gpu.clear()

  -- Draw Character Buffer
  for i = 0, term.width - 1 do
    for j = 0, term.height do
      local row = term.buffer[j + term.scrollAmt + 1]
      if row then
        local char = row[i + 1]
        if char[2] > 1 then
          gpu.drawRectangle(fontW * i, fontH * j, fontW, fontH, char[2])
        end

        write(char[1], fontW * i, fontH * j, char[3])
      end
    end
  end

  -- Blinking cursor
  if term.blink % 1 < 0.5 then
    write("_", (term.x - 1) * fontW, (term.y - term.scrollAmt - 1) * fontH + 2, 16)
  end

  cur:render(unpack(mousePos))

  gpu.swap()
end

function print(text, fg, bg, x, y)
  shell.write(text, fg, bg, x, y)

  term.x = 1
  term.y = term.y + 1
end

local shellHistory = {}

print("rikoOS 1.0", 13)
while true do
  ::loop::
  shell.write(getDir(), 13)
  shell.write("> ", 10)

  local input = shell.read(nil, nil, shellHistory)
  if not input:match("%S") then
    goto loop
  end

  shellHistory[#shellHistory + 1] = input

  local words = shellSplit(input)
  local name = words[1]
  local ex = name:reverse():match("([^%.]+)%.")

  local handlerFunc
  if ex and fs.exists(name) then
    ex = ex:reverse()
    handlerFunc = handlers[ex]
  end

  if not handlerFunc then
    for i = 1, #config.path do
      local pre = config.path[i]
      for ext, handler in pairs(handlers) do
        local tname = pre .. "/" .. name .. "." .. ext

        if fs.exists(tname) then
          handlerFunc = handler
          name = tname
          break
        end
      end

      if handlerFunc then break end
    end
  end

  if not handlerFunc then
    print("Cannot find file `" .. name .. "`", 8)
  else
    for i = 1, #words do
      words[i] = words[i + 1]
    end

    handlerFunc(name, words)
  end
end