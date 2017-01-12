while true do
  gpu.clear()
  for i=0, 339 do
    for j=0, 199 do
      gpu.drawPixel(i, j, math.random(0, 10))
    end
  end
  gpu.swap()
  coroutine.yield()
end
