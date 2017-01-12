local btest = bit32 and bit32.btest or false
local sbyte = string.byte
local schar = string.char

if not btest then
  btest = function(a, b)
    if not a or not b then return false end
    local result = 0
    local bitval = 1
    while a > 0 and b > 0 do
      if a % 2 == 1 and b % 2 == 1 then -- test the rightmost bits
          result = result + bitval      -- set the current bit
      end
      bitval = bitval * 2 -- shift left
      a = math.floor(a/2) -- shift right
      b = math.floor(b/2)
    end
    return result > 0
  end
end

local font = {}

local startf = 33
local endf = 127
local function parseFontdata(fontdata)
  local res = {}

  for i = startf, endf  do
    res[i] = {}

    for j = 1, 7 do
      local char = fontdata:sub(1, 1)
      fontdata = fontdata:sub(2)

      res[i][j] = {}
      local pos = res[i][j]
      for k = 1, 7 do
        pos[k] = btest(sbyte(char), 2^(k-1))
      end
    end
  end

  return res
end

function font.encodeFontdata(fontdata)
  local endS = ""
  local ct = 0
  local i = 1
  for c in fontdata:gmatch("[%.%/]") do
    if c == "/" then
      ct = ct + i
    end
    i = i * 2
    if i == 128 then
      endS = endS .. schar(ct)
      ct = 0
      i = 1
    end
  end

  return endS
end

function font.new(fontdata)
  local t = {data = parseFontdata(fontdata)}
  setmetatable(t, {__index = font})

  return t
end

return font
