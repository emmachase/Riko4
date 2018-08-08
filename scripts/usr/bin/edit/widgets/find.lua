return function(context)
  local findWidget = {}

  local mediator = context:get "mediator"

  local popout = require("popout")
  local input = require("widgets/input")

  local fontH = gpu.font.data.h

  function findWidget.new(text)
    local self = setmetatable({
      popout = popout.new(80, fontH + 2),
      input = input.new(80, "Find", ".")
    }, {__index = findWidget})

    if text then
      self.input:setText(text)
    end

    self.popout.drawCallback = self.internalDraw
    self.popout.bind = self

    self.input.completeCallback = function(text)
      self:die()
      
      mediator:publish({"editor"}, "findNext", text)
    end

    return self
  end

  function findWidget:internalDraw(drawX, drawY)
    self.input:draw(drawX, drawY)
  end

  function findWidget:draw()
    self.popout:draw()
  end

  function findWidget:update(dt)
    self.popout:update(dt)
  end

  function findWidget:die()
    self.popout:animateOut(function()
      self:suicide()
    end)
    self:cleanup()
  end

  function findWidget:onMousePressed()
    return true
  end

  function findWidget:onChar(modifiers, char)
    self.input:onChar(modifiers, char)

    return true
  end

  function findWidget:onKey(modifiers, key)
    self.input:onKey(modifiers, key)

    if key == "escape" then
      self:die()
      return true
    end

    return true
  end

  return findWidget
end
