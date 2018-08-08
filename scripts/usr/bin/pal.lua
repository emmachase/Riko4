gpu.clear()

for i = 1, 16 do
  gpu.drawRectangle(((i - 1) % 4) * 24 + 24, math.floor((i - 1) / 4) * 24 + 24, 24, 24, i)
end

gpu.swap()

while coroutine.yield() ~= "key" do end
