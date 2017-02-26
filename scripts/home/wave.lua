local noiseIm = image.newImage(356, 200)

for j=1, 200 do
  for i=1, 356 do
    noiseIm:drawPixel(i - 1, j - 1, math.floor((i + j)/2) % 7 + 8)
  end
end

noiseIm:flush()

for i=1, math.huge do
  gpu.clear()
  noiseIm:render((math.floor(i / 2) % 15) - 14, 0)
  gpu.swap()
  local e, p1 = coroutine.yield()
  if e == "key" and p1 == "Escape" then
    break
  end
end

noiseIm:free()
