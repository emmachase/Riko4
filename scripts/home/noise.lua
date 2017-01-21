local t = os.clock()
local c = 0
local blit = gpu.blitPixels
for i=1, math.huge do
  gpu.clear()
  local id = {}
  for i=1, 340*200 do
    id[i] = c % 11
    c = c + 1
  end
  c = c + 1

  blit(0, 0, 340, 200, id)
  gpu.swap()
  coroutine.yield()
end
local xd = os.clock() - t

while true do
  gpu.clear()
  write(tostring(xd) or "Something happened", 2, 2)
  gpu.swap()
  coroutine.yield()
end
