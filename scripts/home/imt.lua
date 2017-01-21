local myImage = image.newImage(48, 12)

local free = false

myImage:flush()

local i = 0

while true do
  gpu.clear()

  write(type(myImage), 2, 2)
  write(tostring(myImage), 2, 10)

  if not free then
    myImage:drawPixel(i, 1, 4)
    myImage:drawRectangle(20, 2, i, i, 6)
    i = i + 1
    myImage:flush()

    myImage:render(50, 50 + i)
 end

  gpu.drawRectangle(50, 64, 24, 12, 4)
  gpu.drawRectangle(24, 50, 24, 12, 4)

  gpu.swap()
  local e, p1, p2 = coroutine.yield()

  if e == "key" then
    if p1 == "Escape" then
      break
    elseif p1 == "Return" then
      -- myImage:freeImage()
      -- image.freeImage(myImage);
      myImage:free();
      free = true
    end
  end
end
