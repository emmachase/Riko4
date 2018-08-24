local button = require("ui.button")

local window = {}

window.defaults = {
  backColor = 6,
  outlineColor = 7,
  titleColor = 16,
  title = "Window"
}

function window.new(x, y, w, h, meta)
  meta = meta or {}
  for k, v in pairs(button.defaults) do
    meta[k] = meta[k] or v
  end

  local t = {x = x or 10, y = y or 10, w or 100, h or 60, meta = meta, children = {}}

  setmetatable(t, {__index = window})
  return t
end

setmetatable(window, {__call = window.new})

function window:attach(child)
  self.children[#self.children + 1] = child
end

function window:render()
  gpu.drawRectangle(self.x, self.y, self.w + 2, self.h + 9, self.meta.outlineColor)
end

function window:event(e, ...)
  if e == "mouseMoved" then
    self.x, self.y = ...
  end
end

return window
