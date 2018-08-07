return function(context)
  local infoWidget = {}

  local popout = require("popout")

  local fontW, fontH = gpu.font.data.w, gpu.font.data.h

  function infoWidget.new(text, timeout)
    local w = 80
    local tw = #text*(fontW + 1)
    if tw > 76 then
      if tw > 160 then
        text = text:sub(1, math.floor(160 / (fontW + 1)) - 2) .. ".."
        tw = #text*(fontW + 1)
      end

      w = tw + 4
    end

    local self = setmetatable({
      popout = popout.new(w, fontH + 1, 6),
      text = text,
      timeout = timeout or 1
    }, {__index = infoWidget})

    self.popout.drawCallback = self.internalDraw
    self.popout.bind = self

    return self
  end

  function infoWidget:internalDraw(drawX, drawY)
    write(self.text, drawX + 1, drawY, 16)
  end

  function infoWidget:draw()
    self.popout:draw()
  end

  function infoWidget:update(dt)
    self.timeout = self.timeout - dt

    if self.timeout <= 0 then
      self:die()
    end

    self.popout:update(dt)
  end

  function infoWidget:die()
    self.popout:animateOut(function()
      self:suicide()
    end)
    self:cleanup()
  end

  return infoWidget
end