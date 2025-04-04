fs.setCWD("/home/")

do
  if not riko4 then riko4 = {} end
  riko4.exit = os.exit

  -- os.exit is used as the exit method for some scripts,
  -- most notably, the Urn compiler. This prevents such
  -- scripts from exiting Riko4 entirely.
  os.exit = function() -- luacheck: globals os
    local r = coroutine.yield("killme")
    if r ~= "killed" then
      error("Failed to gracefully exit", 0)
    end

    coroutine.yield("done")
  end

  local counter = 0
  os.tmpname = function()
    counter = counter + 1
    return "/tmp/lua_" .. counter .. ".lua"
  end

  os.remove = fs.delete
  os.rename = fs.move
end


local scrnW, scrnH = gpu.width, gpu.height

-- Cursor
local cur
do
  local curRIF =
  "\82\73\86\2\0\6\0\7\1\0\0\0\0\0\0\0\0\0\0\1\0\0\31\16\0\31\241\0\31\255\16\31\255\241\31\241\16\1\31\16\61\14\131\0\24\2"
  local rif = dofile("/lib/rif.lua")
  local rifout, cw, ch = rif.decode1D(curRIF)
  cur = image.newImage(cw, ch)
  cur:blitPixels(0, 0, cw, ch, rifout)
  cur:flush()
end

-- Localizations
local write     = write
local font      = gpu.font.data
local fontW     = font.w + 1 -- TODO: This must be changed after fonts overhaul
local fontH     = font.h + 1
local rootPrint = print
debugTrace      = rootPrint -- Used for Debug builds of Riko4

local mousePos  = { -5, -5 }

-- Setup Extension Handlers
local handlers  = {}
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
local function shellSplit(str)
  local tab = { "" }

  local inStr = false
  for i = 1, #str do
    local c = str:sub(i, i)

    if not (c == "\\" and str:sub(i + 1, i + 1) == "\"") then
      if c == "\"" and str:sub(i - 1, i - 1) ~= "\\" then
        inStr = not inStr
      elseif inStr then
        tab[#tab] = tab[#tab] .. c
      elseif c:match("%s") and #(tab[#tab]) > 0 then
        tab[#tab + 1] = ""
      else
        tab[#tab] = tab[#tab] .. c
      end
    end
  end

  return tab
end

local function getDir()
  local dir = fs.getCWD():gsub("%\\", "/")
  if #dir > 1 and dir:sub(#dir) == "/" then dir = dir:sub(1, #dir - 1) end
  return dir
end

local config = dofile("/shellcfg.lua")
table.insert(config.path, 1, ".") -- Shell should be able to run files from the CWD ;)

-- Terminal
-- Character buffer
local term = {
  width     = math.floor(scrnW / fontW),
  height    = math.floor(scrnH / fontH),
  scrollAmt = 0,
  buffer    = {},
  x         = 1,
  y         = 1,
  blink     = -math.huge
}

for i = 1, term.height do
  term.buffer[i] = {}
  for j = 1, term.width do
    term.buffer[i][j] = { " ", 1, 16 } -- Char, BG, FG
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
      term.buffer[y][j] = { " ", 1, 16 }
    end
  end
end

local lastBG, lastFG = 1, 16
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
      if x > term.width then
        endC = text:sub(i)
        break
      end

      if term.buffer[y] then
        local ind = term.buffer[y][x]
        ind[1] = c
        ind[2] = bg or lastBG
        ind[3] = fg or lastFG
      else
        endC = text:sub(i)
        break
      end

      x = x + 1
    end
  end

  term.x = x

  lastBG = bg or lastBG
  lastFG = fg or lastFG

  return endC, nl
end

-- Shell Library
shell = { config = config, term = term }
local shell = shell               -- For performance
local currentRunningProgram = nil -- Track the currently running program

function shell.updateMouse(mx, my)
  mousePos = { mx, my }
end

function shell.getCoopMousePos()
  return mousePos[1], mousePos[2]
end

function shell.getRunningProgram()
  return currentRunningProgram
end

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

      local code, codeEnd = remainder:find("\27%[[%d;]+m")

      if code == 1 then
        local instructionStr = remainder:sub(3, codeEnd - 1)
        remainder = remainder:sub(codeEnd + 1)

        for instruction in instructionStr:gmatch("(%d*);?") do
          instruction = tonumber(instruction)
          if instruction == 0 then
            bg = 1; fg = 16
          elseif instruction == 30 then
            fg = 1
          elseif instruction == 40 then
            bg = 1
          elseif instruction == 31 then
            fg = 8
          elseif instruction == 41 then
            bg = 8
          elseif instruction == 32 then
            fg = 4
          elseif instruction == 42 then
            bg = 4
          elseif instruction == 33 then
            fg = 9
          elseif instruction == 43 then
            bg = 9
          elseif instruction == 34 then
            fg = 2
          elseif instruction == 44 then
            bg = 2
          elseif instruction == 35 then
            fg = 3
          elseif instruction == 45 then
            bg = 3
          elseif instruction == 36 then
            fg = 12
          elseif instruction == 46 then
            bg = 12
          elseif instruction == 37 then
            fg = 7
          elseif instruction == 47 then
            bg = 16
          elseif instruction == 90 then
            fg = 6
          elseif instruction == 100 then
            bg = 6
          elseif instruction == 91 then
            fg = 14
          elseif instruction == 101 then
            bg = 14
          elseif instruction == 92 then
            fg = 11
          elseif instruction == 102 then
            bg = 11
          elseif instruction == 93 then
            fg = 10
          elseif instruction == 103 then
            bg = 10
          elseif instruction == 94 then
            fg = 12
          elseif instruction == 104 then
            bg = 12
          elseif instruction == 95 then
            fg = 13
          elseif instruction == 105 then
            bg = 13
          elseif instruction == 96 then
            fg = 13
          elseif instruction == 106 then
            bg = 13
          elseif instruction == 97 then
            fg = 16
          elseif instruction == 107 then
            bg = 16
          elseif instruction == 39 then
            fg = 16
          elseif instruction == 49 then
            bg = 1
          end
        end
      elseif code then
        local rem = remainder:sub(1, code - 1)

        local arem
        arem, nl = term.write(rem, fg, bg, x, y)
        if nl or #arem > 0 then
          x = 1
          y = y + 1
        else
          x = x + #rem
        end

        remainder = arem .. remainder:sub(code)
      else
        remainder, nl = term.write(remainder, fg, bg, x, y)

        x = 1
        y = y + 1
      end
    until remainder == ""
  end

  if nl then
    term.x = x
    term.y = y
  end

  lastBG = bg or lastBG
  lastFG = fg or lastFG
end

function shell.tabulate(...)
  local all = { ... }

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

local function completeRead(str, strPos, forceFull)
  local subStrPos = 1
  local newStr = {}
  local matches = {}

  for subStr in str:gmatch("%S+") do
    if strPos >= subStrPos and strPos <= subStrPos + #subStr then
      local baseDir = fs.getBaseDir(subStr)
      if baseDir == "." and subStr:sub(1, 1) ~= "." then
        baseDir = ""
      end

      -- Normal path tab completion
      local file = baseDir == "" and subStr
          or baseDir == "/" and subStr:sub(2)
          or subStr:sub(#baseDir + 2)
      local listing = fs.list(baseDir)
      if listing and file ~= "" then
        for _, lfile in pairs(listing) do
          if lfile:sub(1, #file) == file then
            local newSubStr = baseDir .. ((baseDir == "" or baseDir == "/") and "" or "/") .. lfile

            if forceFull then
              subStr = newSubStr
              strPos = subStrPos + #subStr
              break
            else
              matches[#matches + 1] = newSubStr
            end
          end
        end
      end

      -- If this is the first argument and not an absolute path,
      -- look for programs in PATH and select the first one that matches
      if baseDir == "" and subStrPos == 1 then
        for _, pathDir in pairs(shell.config.path) do
          local listing = fs.list(pathDir)
          local found = false
          if listing then
            for _, program in pairs(listing) do
              local ext = program:match("^.+(%..+)$")
              for handlerExt, _ in pairs(handlers) do
                if ext == "." .. handlerExt then
                  if program:sub(1, #subStr) == subStr then
                    local newSubStr = program:sub(1, -(#ext + 1))

                    if forceFull then
                      subStr = newSubStr
                      strPos = subStrPos + #subStr
                      found = true
                      break
                    else
                      matches[#matches + 1] = newSubStr
                    end
                  end
                end
              end
              if found then
                break
              end
            end
          end
          if found then
            break
          end
        end
      end

      if not forceFull then
        if #matches > 1 then
          for i = 1, math.huge do
            local char = matches[1]:sub(i, i)
            local bad = false
            for j = 2, #matches do
              if matches[j]:sub(i, i) ~= char then
                subStr = matches[1]:sub(1, i - 1)
                strPos = subStrPos + #subStr
                bad = true
                break
              end
            end

            if bad then
              break
            end
          end
        elseif #matches == 1 then
          subStr = matches[1]
          strPos = subStrPos + #subStr
        end
      end
    end
    table.insert(newStr, subStr)
    subStrPos = subStrPos + #subStr + 1
  end
  return table.concat(newStr, " "), strPos, matches
end

function shell.read(replaceChar, size, history, colorFn, fileTabComplete)
  local maxW = term.width - term.x + 1
  size = size and math.min(size, maxW) or maxW

  term.blink = 0

  local x, y = term.x, term.y

  local str = ""
  local strPos = 1
  local strScrollAmt = 0

  history = history or {}
  local historyPt = #history + 1

  local alive = true
  local evFunc
  local cLine = { { "" } }

  local function checkBounds()
    if strPos - strScrollAmt > size then
      strScrollAmt = strPos - size
    elseif strPos - strScrollAmt < 1 then
      strScrollAmt = strPos - 1
    end
  end

  local function drawRead(drawCompletion)
    term.write((" "):rep(size), 16, 1, x, y)

    if colorFn then
      term.write((" "):rep(size), 16, 1, x, y)

      if #cLine > 0 then
        local cx = x
        local index, eaten = 1, 0
        while #cLine[index][1] < strScrollAmt + 1 - eaten and index < #cLine do
          eaten = eaten + #cLine[index][1]
          index = index + 1
        end

        local skipFirst = strScrollAmt - eaten + 1

        for j = index, #cLine do
          local chk = cLine[j]
          local drawStr = chk[1]:sub(skipFirst, skipFirst + size - (cx - x) - 1)
          term.write(drawStr, chk[2] or 16, chk[3] or 1, cx, y)

          cx = cx + #drawStr
          skipFirst = 1
        end
      end

      term.x = strPos - strScrollAmt + x - 1
    else
      local drawingStr = str
      if drawCompletion and strPos - 1 == #str then
        drawingStr = completeRead(str, strPos, true)
        for i = 1, drawCompletion and 2 or 1 do
          local strToDraw = drawingStr:sub(strScrollAmt + 1, strScrollAmt + size)
          if replaceChar then
            strToDraw = (replaceChar):rep(#strToDraw)
          end
          if drawCompletion then
            term.write(strToDraw, i == 1 and 6 or 16, 1, x, y)
          else
            term.write(strToDraw, 16, 1, x, y)
          end
          drawingStr = str
          term.x = strPos - strScrollAmt + x - 1
        end
      else
        local strToDraw = drawingStr:sub(strScrollAmt + 1, strScrollAmt + size)
        if replaceChar then
          strToDraw = (replaceChar):rep(#strToDraw)
        end
        term.write(strToDraw, 16, 1, x, y)
        term.x = strPos - strScrollAmt + x - 1
      end
    end
  end

  while alive do
    local fStr = str
    local modi = { ctrl = false }

    evFunc = evFunc or function(e, ...)
      if e == "char" then
        local c = ...
        str = str:sub(1, strPos - 1) .. c .. str:sub(strPos)
        strPos = strPos + 1
        term.blink = 0
      elseif e == "keyUp" then
        local k = ...
        if k == "leftCtrl" then
          modi.ctrl = false
        end
      elseif e == "key" then
        local k = ...
        if k == "leftCtrl" then
          modi.ctrl = true
        elseif k == "v" then
          if modi.ctrl then
            local val = fs.getClipboard() or ""
            str = str:sub(1, strPos - 1) .. val .. str:sub(strPos)
            strPos = strPos + #val
            term.blink = 0
          end
        elseif k == "left" and strPos > 1 then
          strPos = strPos - 1
          term.blink = 0
        elseif k == "right" then
          if strPos <= #str then
            strPos = strPos + 1
            term.blink = 0
          else
            if fileTabComplete then
              str, strPos = completeRead(str, strPos, true)
              term.blink = 0
            end
          end
        elseif k == "up" then
          if history and historyPt > 1 then
            historyPt = historyPt - 1
            str = history[historyPt]
            strPos = #str + 1
            term.blink = 0
          end
        elseif k == "down" then
          if history and historyPt < #history then
            historyPt = historyPt + 1
            str = history[historyPt]
            strPos = #str + 1
            term.blink = 0
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
        elseif k == "tab" and fileTabComplete then
          str, strPos = completeRead(str, strPos, false)
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
        local mx, my = ...
        mousePos = { mx, my }
      end

      if term.blink == 0 then
        term.scroll(#term.buffer - term.height - term.scrollAmt)
      end

      checkBounds()
    end
    shell.pumpEvents(evFunc)

    if fStr ~= str and colorFn then
      cLine = colorFn(str)
    end

    -- Draw
    drawRead(true)

    shell.draw()
  end

  drawRead(false)

  term.blink = -math.huge
  term.x = 1
  term.y = y + 1
  return str
end

local isFull = false
local pumpLast = os.clock()
function shell.pumpEvents(func)
  local eq = {}
  while true do
    local a = { coroutine.yield() }
    if not a[1] then break end
    table.insert(eq, a)
  end

  while #eq > 0 do
    local e = table.remove(eq, 1)
    if e[1] == "key" and e[2] == "f11" then
      isFull = not isFull
      gpu.setFullscreen(isFull)
    end
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

        if char[1] ~= " " then
          write(char[1], fontW * i, fontH * j, char[3])
        end
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

function shell.clear()
  local replace = {
    width  = math.floor(scrnW / fontW),
    height = math.floor(scrnH / fontH),
    buffer = {},
    x      = 1,
    y      = 1,
    blink  = -math.huge
  }

  for k, v in pairs(replace) do
    term[k] = v
  end

  term.scroll(-term.scrollAmt)
end

function print(text, fg, bg, x, y) -- luacheck: ignore
  if text ~= nil then
    shell.write(tostring(text), fg, bg, x, y)
  end

  term.x = 1
  term.y = term.y + 1
end

local function newEnv(...)
  local env = {}

  local requirePaths = { ... }
  table.insert(requirePaths, "/lib/")

  local function resolveFile(file)
    file = file:gsub("%.", "/") .. ".lua"
    if file:sub(1, 1) == "/" or file:sub(1, 1) == "\\" then
      return { file }
    else
      local paths = {}
      for i = 1, #requirePaths do
        paths[i] = fs.combine(requirePaths[i], file)
      end

      return paths
    end
  end

  local requireCache = {}
  local loadingStack = {}    -- Stack to track modules currently being loaded

  function env.require(file) -- luacheck: ignore
    local paths = resolveFile(file)

    for i = 1, #paths do
      local path = paths[i]

      if fs.isDir(path) and fs.exists(path .. "/init.lua") then
        path = path .. "/init.lua"
      end

      -- Check if we're in a circular import
      for j = 1, #loadingStack do
        if loadingStack[j] == path then
          -- Create error message showing the circular path
          local circularPath = ""
          for k = 1, #loadingStack do
            circularPath = circularPath .. loadingStack[k]
            if k < #loadingStack then
              circularPath = circularPath .. " -> "
            end
          end
          circularPath = circularPath .. " -> " .. path
          return error("Circular module dependency detected:\n" .. circularPath, 0)
        end
      end

      if requireCache[path] then
        return requireCache[path]
      elseif fs.exists(path) then
        if not fs.isDir(path) then
          -- Add this module to the loading stack
          table.insert(loadingStack, path)

          local chunk, err = env.loadfile(path, env)

          if chunk == nil then
            -- Remove from loading stack if there was an error
            table.remove(loadingStack)
            return error("Error loading file " .. path .. ":\n" .. (err or "N/A"), 0)
          end

          -- Execute the chunk with protection to ensure we clean up the stack
          local success, result = pcall(chunk)

          -- Remove this module from the loading stack
          table.remove(loadingStack)

          if not success then
            return error(result, 0)
          end

          requireCache[path] = result
          return result
        end
      end
    end

    -- Maybe it's a library?
    if _G[file] then
      return _G[file]
    end

    local errStr = "module '" .. file .. "' not found:"
    for i = 1, #paths do
      errStr = errStr .. "\n no file '" .. paths[i] .. "'"
    end

    return error(errStr)
  end

  function env.addRequirePath(path)
    table.insert(requirePaths, 1, path)
  end

  function env.loadstring(...)
    local chunk, e = loadstring(...)
    if chunk then
      setfenv(chunk, env)
    end

    return chunk, e
  end

  function env.load(...)
    local chunk, e = load(...)
    if chunk then
      setfenv(chunk, env)
    end

    return chunk, e
  end

  function env.loadfile(...)
    local chunk, e = loadfile(...)
    if chunk then
      setfenv(chunk, env)
    end

    return chunk, e
  end

  function env.dofile(...)
    local chunk, e = env.loadfile(...)
    if chunk then
      return chunk()
    else
      return error(e, 2)
    end
  end

  env._G = env
  return setmetatable(env, { __index = _G })
end

function shell.erun(cenv, name, ...)
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
    return false, "Cannot find file `" .. name .. "`"
  else
    local words = { ... }

    -- Set the currently running program
    local previousProgram = currentRunningProgram
    currentRunningProgram = name

    local env = newEnv(
      fs.getBaseDir(fs.combine(fs.getCWD(), name))
    )
    for k, v in pairs(cenv) do
      env[k] = v
    end

    env.arg = words

    local routine = coroutine.create(handlerFunc)
    local preEvents = {
      { "mouseMoved", mousePos[1], mousePos[2], 0, 0 }
    }
    local resumeArgs = { name, words, env }
    while coroutine.status(routine) ~= "dead" do
      if resumeArgs[1] == "mouseMoved" then
        shell.updateMouse(resumeArgs[2], resumeArgs[3])
      end

      local _, e, e2 = coroutine.resume(routine, unpack(resumeArgs))
      if e == "killme" then
        coroutine.resume(routine, "killed")
        break
      end

      if not e and e2 then
        -- Restore the previous running program
        currentRunningProgram = previousProgram
        return false, e2
      end

      if #preEvents > 0 then
        resumeArgs = table.remove(preEvents, 1)
      else
        resumeArgs = table.pack(coroutine.yield())
      end
    end

    -- Restore the previous running program
    currentRunningProgram = previousProgram
    return true
  end
end

function shell.run(...)
  local debugClone = {}
  for k, v in pairs(debug) do
    debugClone[k] = v
  end

  return shell.erun({
    ["debug"] = debugClone
  }, ...)
end

os.execute = shell.run

-- Execute .profile
if fs.exists(".profile.lua") then
  shell.run(".profile.lua")
end

local shellHistory = {}

print("rikoOS 1.0", 13)
while true do
  shell.write(getDir(), 13)
  shell.write("> ", 10)

  local input = shell.read(nil, nil, shellHistory, nil, true)
  if input:match("%S") then
    shellHistory[#shellHistory + 1] = input

    local words = shellSplit(input)
    local name = words[1]
    table.remove(words, 1) -- Get the name out of the argument list

    local s, e = shell.run(name, unpack(words))
    if not s then
      print(e, 8)
    end
  end
end
