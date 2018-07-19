local pix = gpu.drawPixel

local gw = 128 --gpu.width
local gh = 128 --gpu.height

local cls = gpu.clear
local swp = gpu.swap

for i = 1, 60 do
    local t = os.clock()
    cls(0)

    for j = 1, gw do
        for k = 1, gh do
            pix(j, k, (j + k * i) % 16 + 1)
        end
    end

    swp()
    local t2 = os.clock() - t
    print(1 / t2)
end