local input = {}

local fontW, fontH = gpu.font.data.w, gpu.font.data.h

function input.new(w, hint, charset, pattern)
  return setmetatable({
    text = "",
    scrollX = 0,
    cursorPos = 0,
    blinkTime = os.clock(),
    hint = hint,
    w=w,charset=charset,pattern=pattern,
    bg = 6
  }, {__index = input})
end

function input:draw(x, y)
  gpu.clip(x, y, self.w, fontH + 2)

  gpu.drawRectangle(x, y, self.w, fontH + 2, self.bg)
  local str, c = self.text, 16
  if #str == 0 then
    str = self.hint or ""
    c = 7
  end
  write(str, x + self.scrollX*(fontW + 1), y, c)

  if (os.clock() - self.blinkTime) % 1 < 0.5 then
    write("_", x - (-self.scrollX - self.cursorPos)*(fontW + 1), y + 1)
  end

  gpu.clip()
end

function input:checkDrawBounds()
  if self.cursorPos > math.floor(self.w/(fontW + 1)) - self.scrollX - 1 then
    self.scrollX = math.floor(self.w/(fontW + 1)) - self.cursorPos - 1
  elseif self.cursorPos < 1 - self.scrollX then
    self.scrollX = 1 - self.cursorPos
    if self.scrollX > 0 then
      self.scrollX = 0
    end
  end
end

function input:setText(text)
  self.text = ""
  self.scrollX = 0
  self.cursorPos = 0

  for i = 1, #text do
    self:onChar({}, text:sub(i, i))
  end
end

function input:onChar(modifiers, char)
  if char:match(self.charset) then
    self.text = self.text:sub(1, self.cursorPos) .. char .. self.text:sub(self.cursorPos + 1)
    self.cursorPos = self.cursorPos + 1
  end

  self:checkDrawBounds()

  self.blinkTime = os.clock()
end

function input:onKey(modifiers, key)
  if key == "return" or key == "keypadEnter" then
    if (not self.pattern) or self.text:match("^" .. self.pattern .. "$") then
      self.completeCallback(self.text)
      self.bg = 6
    else
      self.bg = 8
    end
  elseif key == "backspace" then
    if self.cursorPos > 0 then
      self.text = self.text:sub(1, self.cursorPos - 1) .. self.text:sub(self.cursorPos + 1)
      self.cursorPos = self.cursorPos - 1
    end

    self.blinkTime = os.clock()
  elseif key == "delete" then
    self.text = self.text:sub(1, self.cursorPos) .. self.text:sub(self.cursorPos + 2)
    self.blinkTime = os.clock()
  elseif key == "left" then
    if self.cursorPos > 0 then
      self.cursorPos = self.cursorPos - 1
    end

    self.blinkTime = os.clock()
  elseif key == "right" then
    if self.cursorPos < #self.text then
      self.cursorPos = self.cursorPos + 1
    end

    self.blinkTime = os.clock()
  elseif key == "home" then
    self.cursorPos = 0
    self.blinkTime = os.clock()
  elseif key == "end" then
    self.cursorPos = #self.text
    self.blinkTime = os.clock()
  end

  self:checkDrawBounds()
end

return input