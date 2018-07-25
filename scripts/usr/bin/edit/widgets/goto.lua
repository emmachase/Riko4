return function(context)
  local gotoWidget = {}

  local mediator = context:get "mediator"

  local popout = require("popout")
  local input = require("widgets/input")

  local fontH = gpu.font.data.h

  function gotoWidget.new()
    local self = setmetatable({
      popout = popout.new(80, fontH + 2),
      input = input.new(80, "%d")
    }, {__index = gotoWidget})

    self.popout.drawCallback = self.internalDraw
    self.popout.bind = self

    self.input.completeCallback = function(text)
      self:die()
      
      mediator:publish({"editor"}, "goto", tonumber(text))
    end

    return self
  end

  function gotoWidget:internalDraw(drawX, drawY)
    self.input:draw(drawX, drawY)
  end

  function gotoWidget:draw()
    self.popout:draw()
  end

  function gotoWidget:update(dt)
    self.popout:update(dt)
  end

  function gotoWidget:die()
    self.popout:animateOut(function()
      self:suicide()
    end)
    self:cleanup()
  end

  function gotoWidget:onMousePressed()
    return true
  end

  function gotoWidget:onChar(modifiers, char)
    self.input:onChar(modifiers, char)

    return true
  end

  function gotoWidget:onKey(modifiers, key)
    self.input:onKey(modifiers, key)

    if key == "escape" then
      self:die()
      return true
    end

    return true
  end

  return gotoWidget
end