local button = {}

button.defaults = {
  backColor = 7,
  textColor = 16,
  hoverBack = 6,
  hoverText = 16,
  activeBack = 16,
  activeText = 7
}

local function checkBounds(x, y, w, h, cx, cy)
  return cx >= x and cx < x + w and cy >= y and cy < y + h
end

function button.new(data, x, y, w, h)
  local meta
  if type(data) == "string" then
    meta = {
      display = "text",
      text = data
    }
    
    for k, v in pairs(button.defaults) do
      meta[k] = v
    end
    
    if not w then
      w = #data * 7 + 6
    end
  elseif type(data) == "userdata" and tostring(data):sub(1, 5) == "Image" then
    meta = {
      display = "image",
      idle = data,
      hover = data,
      active = data
    }
  elseif type(data) == "table" then
    meta = data
  end
  
  local t = {x = x, y = y, w = w, h = h, meta = meta,
    state = {
      hover = false,
      active = false
    }}
  
  setmetatable(t, {__index = button})
  return t
end

setmetatable(button, {__call = button.new})

function button:draw()
  if self.meta.display == "image" then
    if self.state.active then
      self.meta.active:render(self.x, self.y)
    elseif self.state.hover then
      self.meta.hover:render(self.x, self.y)
    else
      self.meta.idle:render(self.x, self.y)
    end
  end
end

function button:event(e, ...)
  if e == "mouseMoved" then
    local mx, my = ...

    if checkBounds(self.x, self.y, self.w, self.h, mx, my) then
      self.state.hover = true
      return true
    else
      self.state.hover = false
    end
  elseif e == "mousePressed" then
    local mx, my = ...

    if checkBounds(self.x, self.y, self.w, self.h, mx, my) then
      self.state.active = true
      self.state.hover = true
      return true
    else
      self.state.active = false
      self.state.hover = false
      return false
    end
  elseif e == "mouseReleased" then
    local mx, my = ...

    if checkBounds(self.x, self.y, self.w, self.h, mx, my) then
      self.state.active = false
      self.state.hover = true
      
      if self.callback then
        self.callback(self)
      end
      
      return true
    else
      self.state.active = false
      self.state.hover = false
      return false
    end
  end
  
  return false
end

return button
