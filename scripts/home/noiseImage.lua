local noiseIm = image.newImage(352, 200)

for j=1, 200 do
  for i=1, 352 do
    noiseIm:drawPixel(i - 1, j - 1, (i + j) % 11)
  end
end

noiseIm:flush()

for i=1, math.huge do
  gpu.clear()
  -- local id = {}
  noiseIm:render(i%12 - 12, 0)
  -- blit(0, 0, 340, 200, id)
  gpu.swap()
  local e, p1, p2 = coroutine.yield()
  if e == "key" and p1 == "Escape" then
    break
  end
end

noiseIm:free()
