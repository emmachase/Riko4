local t3d = dofile("/lib/t3d.lua")
local cubeMesh = { { 0.0, 0.0, 0.0,
                     1.0, 0.0, 0.0,
                     0.0, 0.0, 1.0, 2 },
                   { 1.0, 0.0, 0.0,
                     0.0, 0.0, 1.0,
                     1.0, 0.0, 1.0, 3 },
                   { 0.0, 1.0, 0.0,
                     1.0, 1.0, 0.0,
                     0.0, 1.0, 1.0, 5 },
                   { 1.0, 1.0, 0.0,
                     0.0, 1.0, 1.0,
                     1.0, 1.0, 1.0, 6 },
                   { 0.0, 0.0, 0.0,
                     1.0, 0.0, 0.0,
                     0.0, 1.0, 0.0, 7 },
                   { 1.0, 0.0, 0.0,
                     0.0, 1.0, 0.0,
                     1.0, 1.0, 0.0, 9 },
                   { 0.0, 0.0, 1.0,
                     1.0, 0.0, 1.0,
                     0.0, 1.0, 1.0, 10 },
                   { 1.0, 0.0, 1.0,
                     0.0, 1.0, 1.0,
                     1.0, 1.0, 1.0, 11 },
                   { 0.0, 0.0, 0.0,
                     0.0, 0.0, 1.0,
                     0.0, 1.0, 0.0, 12 },
                   { 0.0, 0.0, 1.0,
                     0.0, 1.0, 0.0,
                     0.0, 1.0, 1.0, 13 },
                   { 1.0, 0.0, 0.0,
                     1.0, 0.0, 1.0,
                     1.0, 1.0, 0.0, 14 },
                   { 1.0, 0.0, 1.0,
                     1.0, 1.0, 0.0,
                     1.0, 1.0, 1.0, 15 }  }

local quadMesh = { { 0.0, 0.0, 0.0,
                     1.0, 0.0, 0.0,
                     0.0, 1.0, 0.0, 2 },
                   { 1.0, 0.0, 0.0,
                     0.0, 1.0, 0.0,
                     1.0, 1.0, 0.0, 12 } }

local function waveSimulation(x, y, curTime)
  return math.sin(math.sqrt(x * x + y * y) - curTime * 2)
end

local demoNames = { "Spinning Cubes", "Waves" }

local running = true
local currentDemo = 2
local mousePressed = false
local rotationScale = 0.03
local xRotation, yRotation = 0, 0.5
local cameraDistance = 10
local cameraDistanceScale = 0.2

while running do
  while true do
    local event = {coroutine.yield()}
    if not event[1] then
      break
    elseif event[1] == "key" and event[2] == "escape" then
      running = false
      break
    elseif event[1] == "key" and event[2] == "left" then
      currentDemo = currentDemo - 1
    elseif event[1] == "key" and event[2] == "right" then
      currentDemo = currentDemo + 1
    elseif event[1] == "mousePressed" and event[4] == 1 then
      mousePressed = true
    elseif event[1] == "mouseMoved" and mousePressed then
      xRotation = xRotation + event[4] * rotationScale
      yRotation = yRotation + event[5] * rotationScale
    elseif event[1] == "mouseReleased" and event[4] == 1 then
      mousePressed = false
    elseif event[1] == "mouseWheel" then
      cameraDistance = cameraDistance + cameraDistance * cameraDistanceScale * -event[2]
    end
  end

  local curTime = os.clock()
  local triangles = {}
  if currentDemo == 1 then
    for i = 1, 10 do
      local cube = t3d.cloneTs(cubeMesh)
      t3d.translateTs(cube, -0.5, -0.5, -0.5)
      t3d.rotateTs(cube, curTime * 0.2, curTime * 1.0, curTime * 1.0)
      t3d.translateTs(cube, (i - 5) *  1.5, math.sin(curTime + i), 0)
      t3d.concatTs(triangles, cube, true)
    end
  elseif currentDemo == 2 then
    for j = -10, 10 do
      for i = -10, 10 do
        local quad = t3d.cloneTs(quadMesh)
        quad[1][3] = waveSimulation(i, j, curTime)
        quad[1][6] = waveSimulation(i + 1, j, curTime)
        quad[1][9] = waveSimulation(i, j + 1, curTime)
        quad[2][3] = waveSimulation(i + 1, j, curTime)
        quad[2][6] = waveSimulation(i, j + 1, curTime)
        quad[2][9] = waveSimulation(i + 1, j + 1, curTime)
        t3d.translateTs(quad, i, j, 0)
        t3d.concatTs(triangles, quad, true)
      end
    end
    t3d.scaleTs(triangles, 0.5, 0.5, 0.5)
  end
  t3d.rotateTs(triangles, 0, 0, xRotation)
  t3d.rotateTs(triangles, yRotation + math.pi / 2, 0, 0)
  t3d.translateTs(triangles, 0, 0, cameraDistance)

  gpu.clear(0)
  t3d.drawTs(triangles)
  write("3D " .. (demoNames[currentDemo] or "Nothing"), 8, 8, 16)
  write(("%.2f"):format((os.clock() - curTime) * 1000) .. " ms", 8, 16, 7)
  gpu.swap()
end
