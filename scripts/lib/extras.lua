-- luacheck: ignore 231 211

local rnd, range, elip, elipFill, circ, circFill, line, poly, class, all
local PI, cos, sin, tan, atan2
local flr, ceil, abs

do
  local gpp = dofile("/lib/gpp.lua")

  rnd = math.random

  elip = gpp.drawEllipse
  elipFill = gpp.fillEllipse
  circ = function(x, y, r, c)
    gpp.drawEllipse(x, y, r, r, c)
  end
  circFill = gpp.fillCircle
  line = gpp.drawLine
  poly = gpp.drawPolygon

  range = function(a, b, step)
    local out = {}
    if b then
      for i = a, b, step or 1 do
        out[#out + 1] = i
      end
    else
      for i = 1, a do
        out[i] = i
      end
    end

    return out
  end

  class = function(superclass, name)
    local cls = {}
    cls.__name = name or ""
    cls.__super = superclass
    cls.__index = cls
    return setmetatable(cls, {__call = function (c, ...)
     local self = setmetatable({}, cls)
     local super = cls.__super
     while (super~=nil) do
      if super.__init then
       super.__init(self, ...)
      end
      super = super.__super
     end
     if cls.__init then
      cls.__init(self, ...)
     elseif cls.init then
      cls.init(self, ...)
     end
     return self
    end})
  end

  all = function(t)
    local i = 0
    return function()
      i = i + 1
      return t[i]
    end
  end

  PI, cos, sin, tan, atan2 = math.pi, math.cos, math.sin, math.tan, math.atan2
  flr = function(...)
    local src = {...}
    for i = 1, #src do
      src[i] = math.floor(src[i])
    end

    return unpack(src)
  end

  ceil = function(...)
    local src = {...}
    for i = 1, #src do
      src[i] = math.ceil(src[i])
    end

    return unpack(src)
  end

  abs = math.abs
end
