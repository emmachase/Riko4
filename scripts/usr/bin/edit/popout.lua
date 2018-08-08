local popout = {}

local padding = 10
local animSpeed = 15

local floor, ceil = math.floor, math.ceil
local scrnWidth, scrnHeight = gpu.width, gpu.height

local function round(n)
  if n % 1 >= 0.5 then
    return ceil(n)
  else
    return floor(n)
  end
end

function popout.new(width, height, bg)
  local self = {
    width = width + 2,
    height = height + 2,
    animState = 0,
    goingOut = false,
    bg = bg or 7
  }

  return setmetatable(self, {__index = popout})
end

function popout:update(dt)
  if self.goingOut then
    self.vy = (self.vy or 0) + (animSpeed ^ 2.5)*dt
    self.animState = self.animState - self.vy*dt

    if self.animState <= 0 then
      self:suicide()
    end
  else
    self.animState = self.animState + animSpeed*(self.height - self.animState)*dt

    if self.animState >= self.height then
      self.animState = self.height
    end
  end
end

function popout:draw()
  local xpos = scrnWidth - self.width - padding

  gpu.drawRectangle(
    xpos, round(self.animState - self.height),
    self.width, self.height, self.bg)

  gpu.drawRectangle(
    xpos + 1, round(self.animState),
    self.width - 2, 1, self.bg)

  if self.drawCallback then
    self.drawCallback(self.bind or {}, xpos + 1, round(self.animState - self.height + 1))
  end
end

function popout:animateOut(suicide)
  self.goingOut = true
  self.suicide = suicide
end

return popout
