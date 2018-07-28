return function(context)
  local infoWidget = {}

  local popout = require("popout")
-- rip input

  local fontH = gpu.font.data.h

  function infoWidget.new(text, timeout)
    local self = setmetatable({
      popout = popout.new(80, fontH + 1, 6),
      text = text,
      timeout = timeout or 1
-- rip input
    }, {__index = infoWidget})

    self.popout.drawCallback = self.internalDraw
    self.popout.bind = self

-- rip input
    --   self:die()
      
    --   mediator:publish({"editor"}, "goto", tonumber(text))
    -- end

    return self
  end

  function infoWidget:internalDraw(drawX, drawY)
-- rip input
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

--   function infoWidget:onMousePressed()
--     return true
--   end

--   function infoWidget:onChar(modifiers, char)
-- -- rip input

--     return true
--   end

--   function infoWidget:onKey(modifiers, key)
-- -- rip input

--     if key == "escape" then
--       self:die()
--       return true
--     end

--     return true
--   end

  return infoWidget
end