local width, height = gpu.width, gpu.height
local noiseIm = image.newImage(width + 16, height)

for j=1, height do
  for i=1, width + 16 do
    noiseIm:drawPixel(i - 1, j - 1, math.floor((i + j)/2) % 7 + 8)
  end
end

noiseIm:flush()

for i=1, math.huge do
  gpu.clear()
  noiseIm:render((math.floor(i / 2) % 14) - 13, 0)
  gpu.swap()
  local e, p1 = coroutine.yield()
  if e == "key" and p1 == "escape" then
    break
  end
end
