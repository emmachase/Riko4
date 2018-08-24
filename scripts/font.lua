local btest = bit32 and bit32.btest or false -- luacheck: globals bit32
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

function font.parseFontdata2(fontdata)
  if fontdata:sub(1, 3) ~= "FNT" then
    error("Corrupted Font File", 2)
  end

  if fontdata:sub(4, 4) ~= "\1" then
    print("Invalid font file version (F:" .. fontdata:sub(4, 4) .. ", CV:1), results may vary")
  end

  local charW  = sbyte(fontdata:sub(5, 5))
  local charH  = sbyte(fontdata:sub(6, 6))
  local rngLow = sbyte(fontdata:sub(7, 7))
  local rngHi  = sbyte(fontdata:sub(8, 8))

  local rest = fontdata:sub(13)

  local srq = math.ceil(charW / 8)

  local outFont = {w = charW, h = charH}
  for i = rngLow, rngHi do
    outFont[i] = {}

    for x = 1, charW do
      outFont[i][x] = {}
    end

    for y = 1, charH do
      local section = rest:sub(1, srq)
      rest = rest:sub(srq + 1)

      for x = 1, charW do
        local ch = math.ceil(x / 8)
        local cp = section:sub(ch, ch)
        outFont[i][x][y] = btest(sbyte(cp), bit.lshift(1, charW - (x - 1) % 8 - 1))
      end
    end
  end

  return outFont
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

function font.encodeFontdata2(fontdata)
  local endS = "FNT" -- Signature
  endS = endS .. "\1" -- Version

  local aaid = next(fontdata)
  local fntH = #fontdata[aaid][1]
  local fntW = #fontdata[aaid]

  local srq = math.ceil(fntW / 8)

  endS = endS .. schar(fntW)
  endS = endS .. schar(fntH)

  local ids = {}
  local min, max = math.huge, -math.huge

  for k, _ in next, fontdata do
    local v = sbyte(k)
    ids[v] = true
    min = v < min and v or min
    max = max < v and v or max
  end

  endS = endS .. schar(min)
  endS = endS .. schar(max)

  endS = endS .. ("\0"):rep(4) -- Fill header

  local charTbl = {}

  for i = min, max do
    if ids[i] then
      local chdata = fontdata[schar(i)]
      local apStr = ""
      for y = 1, fntH do
        local n = 0
        for x = 1, fntW do
          n = n + (chdata[x][y] and bit.lshift(1, fntW - x) or 0)
        end

        local str = ""
        for j = 1, srq do
          str = schar(bit.rshift(n, (j - 1) * 8) % 256) .. str
        end

        apStr = apStr .. str
      end

      charTbl[#charTbl + 1] = apStr
    else
      charTbl[#charTbl + 1] = ("0"):rep(fntH * srq)
    end
  end

  endS = endS .. table.concat(charTbl, "")

  return endS
end

function font.encodeFromImage(image, stchar, echar)
  local cw = 0
  local ch = image:getHeight() - 1

  repeat
    cw = cw + 1
  until image:getPixel(cw, ch) ~= 1

  stchar = stchar or "\0"
  echar = echar or schar(sbyte(stchar) + (image:getWidth() + 1) / (cw + 1) - 1)

  local fnt = {}

  local cnt = 0
  for i = sbyte(stchar), sbyte(echar) do
    fnt[schar(i)] = {}
    local chr = fnt[schar(i)]
    for x = 1, cw do
      chr[x] = {}
      for y = 1, ch do
        chr[x][y] = image:getPixel(x + cnt * (cw + 1) - 1, y - 1) > 0
        --print(image:getPixel(x + cnt * (cw + 1) - 1, y - 1))
      end
    end

    cnt = cnt + 1
  end

  return font.encodeFontdata2(fnt)
end

function font.new(fontdata)
  local t = {data = font.parseFontdata2(fontdata)}
  setmetatable(t, {__index = font})

  return t
end

return font
