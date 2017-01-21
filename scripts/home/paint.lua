local x, y = 0, 0

local zoom = 10

local color = 4

local down = -1

local image = {}
for i=1, 340 do
  image[i] = {}
  for j=1, 200 do
    image[i][j] = 0
  end
end

local e, p1, p2
while true do
  gpu.clear()

  for i=1, math.ceil(340 / zoom) do
    for j=1, math.ceil(200 / zoom) do
      gpu.drawRectangle((i - 1) * zoom, (j - 1) * zoom, zoom, zoom, image[i][j])
    end
  end


  e, p1, p2, p3 = coroutine.yield()
  if e == "mouseMoved" then
    x = p1
    y = p2
    if down > -1 then
      local xpos = math.floor(p1 / zoom) + 1
      local ypos = math.floor(p2 / zoom) + 1
      image[xpos][ypos] = down
    end
  elseif e == "mousePressed" then
    p3 = tonumber(p3)
    local xpos = math.floor(p1 / zoom) + 1
    local ypos = math.floor(p2 / zoom) + 1
    if p3 == 1 then
      image[xpos][ypos] = color
      down = color
    elseif p3 == 3 then
      image[xpos][ypos] = 0
      down = 0
    end
    --print("'"..p3.."' : " .. color .. " -> " .. image[xpos][ypos])
  elseif e == "mouseReleased" then
    if p3 == 1 then
      down = -1
    end
  elseif e == "char" then
    if p1 == "+" then
      zoom = zoom + 1
    elseif p1 == "-" then
      zoom = zoom - 1
    elseif tonumber(p1) then
      color = tonumber(p1)
    end
  elseif e == "key" then
    if p1 == "Escape" then
      break
    end
  end

  gpu.drawRectangle(math.floor(x / zoom) * zoom, math.floor(y / zoom) * zoom, zoom, zoom, color)

  gpu.swap()
end
