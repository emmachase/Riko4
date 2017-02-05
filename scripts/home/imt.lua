local myImage = image.newImage(48, 12)

local free = false

myImage:flush()

local i = 0

while true do
  gpu.clear()

  write(type(myImage), 2, 2)
  write(tostring(myImage), 2, 10)

  if not free then
    myImage:drawPixel(i, 1, 5)
    myImage:drawRectangle(20, 2, i, i, 7)
    i = i + 1
    myImage:flush()

    myImage:render(50, 50 + i)
 end

  gpu.drawRectangle(50, 64, 24, 12, 5)
  gpu.drawRectangle(24, 50, 24, 12, 5)

  gpu.swap()
  local e, p1 = coroutine.yield()

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
