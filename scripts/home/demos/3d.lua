local t3d = dofile("/lib/t3d.lua")
local mesh = { { 0.0, 0.0, 0.0,
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


local running = true
local startTime = os.clock()
local prevTime = os.clock()

while running do
  while true do
    local event = {coroutine.yield()}
    if not event[1] then
      break
    elseif event[1] == "key" and event[2] == "escape" then
      running = false
      break
    end
  end

  local curTime = os.clock()
  local dTime = curTime - prevTime
  local runTime = curTime - startTime
  prevTime = curTime
  local triangles = t3d.cloneTs(mesh)
  t3d.translateTs(triangles, -0.5, -0.5, -0.5)
  t3d.rotateTs(triangles, runTime * 0.2, runTime * 1.0, runTime * 1.0)
  t3d.translateTs(triangles, 0, 0, 2)

  gpu.clear(0)
  t3d.drawTs(triangles)
  gpu.swap()
end
