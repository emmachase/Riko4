local pix = gpu.drawPixel
local rnd = math.random

local gw = 128 --gpu.width
local gh = 128 --gpu.height

local cls = gpu.clear
local swp = gpu.swap

local abc = ""

for i = 1, 60 do
    local t = os.clock()
    cls(0)

    for j = 1, gw do
        
        for k = 1, gh do
            -- abc = abc .. string.char((j + k * 1) % 16 + 1)
            pix(j, k, (j + k * i) % 16 + 1)
        end
    end

    -- for i = 1, 160 do
    -- cls(0)
    -- -- gpu.blitPixelsStr(0, 0, gw, gh, abc)
    swp()
    local t2 = os.clock() - t
    print(1 / t2)
    -- end

    
end