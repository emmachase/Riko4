local cursor = {}

local rif = dofile("/lib/rif.lua")

local cur
do
  local curRIF = "\82\73\86\2\0\6\0\7\1\0\0\0\0\0\0\0\0\0\0\1\0\0\31\16\0\31\241\0\31\255\16\31\255\241\31\241\16\1\31\16\61\14\131\0\24\2"
  local rifout, cw, ch = rif.decode1D(curRIF)
  cur = image.newImage(cw, ch)
  cur:blitPixels(0, 0, cw, ch, rifout)
  cur:flush()
end

function cursor.new()
  local t = {x = -5, y = -5}

  setmetatable(t, {__index = cursor})
  return t
end

setmetatable(cursor, {__call = cursor.new})

function cursor:render(x, y)
  x = x or self.x
  y = y or self.y

  cur:render(x, y)
end

function cursor:event(e, ...)
  if e == "mouseMoved" then
    self.x, self.y = ...
  end
end

return cursor
