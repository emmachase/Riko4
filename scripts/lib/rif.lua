--[[

    Library to make working with RIF (Riko Image Format) easier

]]

local rif = {}

local version = 2

local stub = "RIV"
-- Encodes a RIF string from a 1D or 2D array of colors
function rif.encode(pixels, w, h)
  local output = stub
  .. string.char(version) -- RIF Version
  .. string.char(  bit.rshift(bit.band(w, 65280), 8)  )  -- width/256
  .. string.char(  bit.band(w, 255)                   )  -- width/1
  .. string.char(  bit.rshift(bit.band(h, 65280), 8)  )  -- height/256
  .. string.char(  bit.band(h, 255)                   )  -- height/1
  .. string.char(1) -- Transparency flag
  .. (string.char(0)):rep(10) -- Leave extra room for future headers


  local transmap = {}
  if tonumber(pixels[1]) then
    for i = 1, w * h, 2 do
      local fp = pixels[i]
      local sp = pixels[i + 1]

      if not fp then
        error("Not enough pixel data to construct RIF", 2)
      end

      if not sp then
        -- We have enough pixels, but we've an odd number of pixels so
        -- add a padding buffer, doesn't really matter what color it is.
        sp = 1
      end

      transmap[#transmap + 1] = fp < 0
      transmap[#transmap + 1] = sp < 0
      fp = fp < 0 and 0 or fp - 1
      sp = sp < 0 and 0 or sp - 1

      local cstr = bit.bor(bit.lshift(fp, 4), sp)
      output = output .. string.char(cstr)
    end
  else
    local pad = false
    for i = 1, w * h, 2 do
      local ind = (i - 1) % w + 1
      local indh = math.floor((i - 1) / w) + 1
      local ind2 = i % w + 1
      local indh2 = math.floor(i / w) + 1
      local fp = pixels[ind][indh]
      local sp = pixels[ind2][indh2]

      if not fp then
        error("Not enough pixel data to construct RIF", 2)
      end
      fp = fp - 1

      if not sp then
        -- We have enough pixels, but we've an odd number of pixels so
        -- add a padding buffer, doesn't really matter what color it is.
        sp = 1
        if pad then
          error("More than one padding occurred!", 2)
        end
        pad = true
      end
      sp = sp - 1

      transmap[#transmap + 1] = fp < 0
      transmap[#transmap + 1] = sp < 0
      fp = fp < 0 and 0 or fp
      sp = sp < 0 and 0 or sp

      local cstr = bit.bor(bit.lshift(fp, 4), sp)
      output = output .. string.char(cstr)
    end
  end

  local bytes = {}
  for i = 1, math.ceil(#transmap / 8) do
    local byte = 0
    for j = 1, 8 do
      if transmap[(i - 1) * 8 + j] then
        byte = byte + 2 ^ (j - 1)
      end
    end

    bytes[#bytes + 1] = string.char(byte)
  end

  return output .. table.concat(bytes, "")
end

-- Decodes a RIF to a 1D blit table
function rif.decode1D(rifData)
  if rifData:sub(1, 3) ~= stub then
    error("Data does not contain correct RIF signature, possibly corrupted data", 2)
  end

  if string.byte(rifData:sub(4, 4)) ~= version then
    print("WARN: RIF data has different version, image may not look right")
  end

  local outTable = {}

  local w = string.byte(rifData:sub(5, 5))*256 + string.byte(rifData:sub(6, 6))
  local h = string.byte(rifData:sub(7, 7))*256 + string.byte(rifData:sub(8, 8))

  for i = 1, math.ceil(w * h / 2) do
    local byte = string.byte(rifData:sub(19 + i, 19 + i))
    local fp = bit.rshift(bit.band(byte, 240), 4)
    local sp = bit.band(byte, 15)

    outTable[#outTable + 1] = fp + 1
    outTable[#outTable + 1] = sp + 1
  end

  if (w * h) % 2 == 1 then
    outTable[#outTable] = nil -- Remove padding
  end

  if string.byte(rifData:sub(9, 9)) == 1 then
    -- Transparency map
    local max = 19 + (w * h / 2)
    for i = 1, math.ceil(w * h / 8) do
      local byte = string.byte(rifData:sub(max + i, max + i))
      for j = 1, 8 do
        if bit.band(byte, 2 ^ (j - 1)) ~= 0 then
          outTable[(i - 1) * 8 + j] = -1
        end
      end
    end
  end

  return outTable, w, h
end

-- Streamline process of loading images
function rif.createImage(filenameOrRifData, wa, ha)
  local rifData, w, h
  if type(filenameOrRifData) == "table" then
    rifData, w, h = filenameOrRifData, wa, ha
  elseif type(filenameOrRifData) == "string" then
    local handle = io.open(filenameOrRifData, "rb")
    local data = handle:read("*a")
    handle:close()

    rifData, w, h = rif.decode1D(data)
  else
    error("Argument is not a filename or rifdata", 2)
  end

  local image = image.newImage(w, h)
  image:blitPixels(0, 0, w, h, rifData)
  image:flush()

  return image
end

return rif