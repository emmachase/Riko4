if jit.os == "Linux" or jit.os == "OSX" or jit.os == "BSD" or jit.os == "POSIX" or jit.os == "Other" then
  local ffi = require("ffi")

  ffi.cdef [[
    struct timeval {
      long tv_sec;
      long tv_usec;
    };
    struct timezone {
      int tz_minuteswest;
      int tz_dsttime;
    };
    int gettimeofday(struct timeval *tv, struct timezone *tz);
  ]]

  local start
  do
    local a = ffi.new("struct timeval") ffi.C.gettimeofday(a, nil)
    start = (tonumber(a.tv_sec) + (tonumber(a.tv_usec) / 1000000))
  end

  function os.clock()
    local Time = ffi.new("struct timeval")
    ffi.C.gettimeofday(Time, nil)
    return tonumber(Time.tv_sec) + (tonumber(Time.tv_usec) / 1000000) - start;
  end
end

net.get = function(url)
  net.request(url)

  while true do
    local e, eUrl, handle = coroutine.yield()
    if e == "netSuccess" and eUrl == url then
      return handle
    elseif e == "netFailure" and eUrl == url then
      return
    end
  end
end

fs.copy = function(file, newFile)
  local handle = fs.open(file, "rb")
  if not handle then
    return error("could not open '" .. file .. "' for reading", 8)
  end
  local data = handle:read("*a")
  handle:close()

  handle = fs.open(newFile, "wb")
  if not handle then
    return error("could not open '" .. newFile .. "' for writing", 8)
  end
  handle:write(data)
  handle:close()
end

fs.exists = function(file)
  return fs.getAttr(file) ~= tonumber("11111111", 2)
end

fs.isDir = function(file)
  return fs.exists(file) and bit.band(fs.getAttr(file), 2) == 2
end

loadfile = function(inp)
  local handle = fs.open(inp, "r")

  local cont
  if handle then
    cont = handle:read("*a")
  else
    return nil
  end

  handle:close()

  return load(cont)
end

dofile = function(inp)
  local f = loadfile(inp)
  if f then
    return f()
  else
    error("cannot open " .. inp .. ": No such file", 2)
  end
end

local font = dofile("font.lua")

local dataH = fs.open("smol.rff", "rb")
local data = dataH:read("*a")
dataH:close()

local coreFont = font.new(data)
gpu.font = coreFont


write = function(t, x, y, col, target)
  local fnt = gpu.font.data

  t = tostring(t)
  col = col or 16
  local xoff = 0
  for i=1, #t do
    local text = t:sub(i, i)
    local c = string.byte(text)
    if fnt[c] then
      for j=1, fnt.w do
        for k=1, fnt.h do
          if fnt[c][j][k] then
            local dx = x + xoff + j
            local dy = y + k
            if target then
              target:drawPixel(dx, dy, col)
            else
              gpu.drawPixel(dx, dy, col)
            end
          end
        end
      end
    end
    xoff = xoff + fnt.w + 1
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

dofile("shell.lua")
