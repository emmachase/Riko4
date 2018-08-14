-- luacheck: globals os getfenv setfenv net table.pack loadfile dofile bit32

local ffi
if jit then
  ffi = require("ffi")
  _G.ffi = ffi
  _G.require = nil
end

if jit and (jit.os == "Linux" or jit.os == "OSX" or jit.os == "BSD" or jit.os == "POSIX" or jit.os == "Other") then
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

if not getfenv then
  function getfenv(fn)
    if type(fn) == "number" then
      fn = debug.getinfo(fn).func
    end

    local i = 1
    while true do
      local name, val = debug.getupvalue(fn, i)
      if name == "_ENV" then
        return val
      elseif not name then
        break
      end
      i = i + 1
    end
  end

  function setfenv(fn, env)
    local i = 1
    while true do
      local name = debug.getupvalue(fn, i)
      if name == "_ENV" then
        debug.upvaluejoin(fn, i, (function()
          return env
        end), 1)
        break
      elseif not name then
        break
      end

      i = i + 1
    end

    return fn
  end
end

local function trim(str)
  return str:match("^%s*(.*)"):match("^(.-)%s*$")
end

net.post = function(url, postData)
  net.request(url, postData)

  while true do
    local e, eUrl, handle = coroutine.yield()
    if e == "netSuccess" and eUrl == url then
      return handle
    elseif e == "netFailure" and eUrl == url then
      return
    end
  end
end

net.get = function(url)
  net.request(url)
  while true do
    local e, eUrl, handle = coroutine.yield()
    if e == "netSuccess" and eUrl == url then
      return handle
    elseif e == "netFailure" and eUrl == url then
      return false,  handle
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

fs.getBaseDir = function(path)
  path:gsub("\\", "/")
  if fs.isDir(path) then
    return path
  else
    local reversed = path:reverse():match("/(.+)")
    if reversed then
      return reversed:reverse()
    else
      if path:sub(1, 1) == "/" then
        return "/"
      else
        return "."
      end
    end
  end
end

fs.combine = function(path1, path2, hardJoin)
  path1 = trim(path1); path2 = trim(path2)
  path1 = path1:gsub("\\", "/")
  path2 = path2:gsub("\\", "/")

  local fromRoot = false

  local begin = path1:sub(1, 1)
  local begin2 = path2:sub(1, 1)
  if begin2 == "/" then
    if not hardJoin then
      return path2
    end

    fromRoot = true
  elseif begin == "/" then
    fromRoot = true
  end

  local negativeDepth = 0
  local builtPath = {}
  for pathPart in path1:gmatch("[^/]+") do
    if pathPart == ".." then
      if #builtPath > 0 then
        builtPath[#builtPath] = nil
      else
        negativeDepth = negativeDepth + 1
      end
    elseif pathPart ~= "." then
      builtPath[#builtPath + 1] = pathPart
    end
  end

  for pathPart in path2:gmatch("[^/]+") do
    if pathPart == ".." then
      if #builtPath > 0 then
        builtPath[#builtPath] = nil
      else
        negativeDepth = negativeDepth + 1
      end
    elseif pathPart ~= "." then
      builtPath[#builtPath + 1] = pathPart
    end
  end

  return (fromRoot and "/" or "") .. ("../"):rep(negativeDepth) .. table.concat(builtPath, "/")
end

io = setmetatable({}, {__index = fs})
local pipeMeta = {__index = io}

io.write = function(file, ...)
  if type(file) ~= "userdata" then
    if type(file) == "table" and getmetatable(file) == pipeMeta then
      return file.writeToStream("inStream", ...)
    else
      local method = shell.write
      if getfenv(2).outPipe then
        method = getfenv(2).outPipe
      end

      if file == io then
        method(...)
      else
        method(file, ...)
      end
    end
  else
    file:write(...)
  end
end
io.read = function(file, ...)
  if type(file) ~= "userdata" then
    if type(file) == "table" and getmetatable(file) == pipeMeta then
      return file.readFromStream("outStream", ...)
    else
      local method = function()
        return shell.read()
      end
      if getfenv(2).inPipe then
        method = getfenv(2).inPipe
      end

      if file == io then
        return method(...)
      else
        return method(file, ...)
      end
    end
  else
    file:read(...)
  end
end
io.close = function(handle)
  if type(handle) == "table" and getmetatable(handle) == pipeMeta then
    return true
  elseif type(handle) == "userdata" then
    handle:close()
  end
end
io.popen = function(fstr, mode)
  mode = mode or "r"

  local pipe = setmetatable({inStream = "", outStream = ""}, pipeMeta)
  local function readFromStream(streamKey, mode)
    if tonumber(mode) then
      local n = tonumber(mode)
      local data = pipe[streamKey]:sub(1, n)
      pipe[streamKey] = pipe[streamKey]:sub(n + 1)

      return data
    else
      mode = mode:match("%*?(.+)")
      if mode:sub(1, 1) == "a" then
        local data = pipe[streamKey]
        pipe[streamKey] = ""

        return data
      elseif mode:sub(1, 1) == "l" then
        local data, rest = pipe[streamKey]:match("(^[^\n]+)(.+)")
        pipe[streamKey] = rest
        
        return data
      end
    end
  end

  local function writeToStream(streamKey, ...)
    local dataV = table.pack(...)
    local data = ""
    for i = 1, dataV.n do
      data = data .. tostring(dataV[i]) .. " "
    end

    data = data:sub(1, -2)

    pipe[streamKey] = pipe[streamKey] .. data
  end

  pipe.writeToStream = writeToStream
  pipe.readFromStream = readFromStream

  local fargs, fname = {}
  fname, fstr = fstr:match("(%S+)%s*(.+)$")
  for arg in fstr:gmatch("%S+") do
    fargs[#fargs + 1] = arg
  end
  

  shell.erun({
    inPipe = function(m)
      readFromStream("inStream", m)
    end,
    outPipe = function(...)
      writeToStream("outStream", ...)
    end
  }, fname, unpack(fargs))

  return pipe
end
io.open = function(name, mode)
  return fs.open(name, mode or "r")
end
io.flush = function(file)
  if type(file) == "userdata" then
    file:flush()
  end
end
io.stderr = io
io.stdout = io
io.type = function(obj)
  if type(obj) == "userdata" then
    return "file"
  end

  return nil
end

table.pack = function(...)
  local t = {...}
  t.n = select("#", ...)

  return t
end

local strload = loadstring or load
loadfile = function(inp)
  local handle = fs.open(inp, "r")

  local cont
  if handle then
    cont = handle:read("*a")
  else
    return nil, "cannot open " .. inp .. ": No such file"
  end

  handle:close()

  local chunk, e = strload(cont, "@" .. fs.combine(fs.getCWD(), inp))
  if chunk then
    setfenv(chunk, getfenv(2))
  end

  return chunk, e
end

dofile = function(inp)
  local f, e = loadfile(inp)
  if f then
    return f()
  else
    return false, e
  end
end

if not bit then
  _G.bit = bit32
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

local function deleteRecursive(dir)
  for k, v in ipairs(fs.list(dir)) do
    if v ~= "." and v ~= ".." then
      local path = fs.combine(dir, v)
      if fs.isDir(path) then
        deleteRecursive(path)
      end

      fs.delete(path)
    end
  end
end

if fs.exists("/tmp") then
  deleteRecursive("/tmp")
end

fs.mkdir("/tmp")

dofile("shell.lua")
