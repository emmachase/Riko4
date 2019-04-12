-- Cursor

local curRIF = "\82\73\86\2\0\6\0\7\1\0\0\0\0\0\0\0\0\0\0\1\0\0\31\16\0\31\241\0\31\255\16\31\255\241\31\241\16\1\31\16\61\14\131\0\24\2"
local rif = dofile("/lib/rif.lua")
local rifout, cw, ch = rif.decode1D(curRIF)
local cur = image.newImage(cw, ch)
cur:blitPixels(0, 0, cw, ch, rifout)
cur:flush()

return cur
