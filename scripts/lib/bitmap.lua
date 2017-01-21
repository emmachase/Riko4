local Bitmap = {}
local sb = string.byte
do
  function Bitmap.createBitmapFromFile(filename)
    local handle = io.open(filename, "rb")
    local header = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}

    local cx = 0
    for i=1,54 do
      local byteVal = sb(handle:read(1))
      header[i] = byteVal
      -- if i > 16 then
      --   write("["..i.."]"..header[i], cx*7, 180)
      --   cx = cx + #("["..i.."]"..header[i])
      -- end
    end
    -- error()
    --print("\nFile size = "..header[5]*65536 + header[4]*256 + header[3].."\n")
    local offset = header[12]*256+header[11]
    --print("Offset to image = "..offset)
    local width = header[20]*256+header[19]
    local height = header[24]*256+header[23]

    local size = 3 * width * height

    local outdata = {}
    local padding = (4-((width*3)%4))%4
    for i=1,size do
      outdata[i] = sb(handle:read(1))
      if i%(width*3)==0 then
        for i=1,padding do
          sb(handle:read(1)) --padding data we dont need or want
        end
      end
    end
    --
    handle:close()
    --
    for i=1, size, 3 do
      local tmp = outdata[i]
      outdata[i] = outdata[i+2]
      outdata[i+2] = tmp
    end

    local outmap = Bitmap.__init__(nil, width, height)
    --
    for i=1,width do
      for j=1,height do
      --write("{"..happy[i]..","..happy[i+1]..","..happy[i+2].."},")
        local poff = (j-1)*width*3 + (i-1)*3
        outmap:drawPixel(i-1,outmap.height - j,outdata[poff + 1],outdata[poff + 2],outdata[poff + 3]) --for some reason the bmps were inverted vertically?
      end
    end

    return outmap
  end

  function Bitmap.__init__(_, nWidth, nHeight, bg)
      local self
    if type(nWidth)~="number" then
        self = {width = nWidth:getWidth(),
            height = nWidth:getHeight(),
            components = nWidth,
            outcan = love.graphics.newImage(nWidth)}
    else
        self = {width = nWidth, height = nHeight,
      components = {}}
      --self.outcan = love.graphics.newImage(self.components)
    end
    setmetatable(self, {__index=Bitmap})
    return self
  end

  setmetatable(Bitmap, {__call=Bitmap.__init__})

  --takes in a byte
  function Bitmap:clear(shade)
    self.components:mapPixel(function() return shade,shade,shade,1 end, 1, 1, self.width, self.height)
  end

  function Bitmap:clearRGB(r, g, b)
      self.components:mapPixel(function() return r,g,b,1 end, 0, 0, self.width, self.height)
  end

  function Bitmap:setBG_C(bg)
    self.bg = bg
  end

  function Bitmap:setBG_RGB(r,g,b)
    self.bg = colors.fromRGB(r,g,b)
  end

  function Bitmap:drawPixel(x,y,r,g,b)
    x,y = math.floor(x),math.floor(y)
    if x > self.width or x < 0 or y < 0 or y > self.height then
     return
    end
    self.components[y*self.width + x + 1] = {r, g, b}--:setPixel(x, y, r, g, b)
  end
end

return Bitmap
