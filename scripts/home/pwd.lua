local running = true

local wordBank = {
  "about", "after", "again",
  "below",
  "could",
  "every",
  "first", "found",
  "great",
  "house",
  "large", "learn",
  "never",
  "other",
  "place", "plant", "point",
  "right",
  "small", "sound", "spell", "still", "study",
  "their", "there", "these", "thing", "think", "three",
  "water", "where", "which", "world", "would", "write"
}

local entered = {}
local length = 5
local keylen = 6
local pos = 1
for i = 1, length do
  entered[i] = {}
end

local poss = {}
for i = 1, #wordBank do
  poss[i] = wordBank[i]
end

local function calculate()
  poss = {}
  for i = 1, #wordBank do
    poss[i] = wordBank[i]
  end

  for i = #poss, 1, -1 do
    local wd = poss[i]
    for j = 1, length do
      local gud
      if #entered[j] == keylen then
        gud = false
        for k = 1, keylen do
          if entered[j][k] == wd:sub(j, j) then
            gud = true
            break
          end
        end
      else
        break
      end
      if not gud then
        table.remove(poss, i)
        break
      end
    end
  end
end

local function draw()
  for i = 1, math.min(#poss, 20) do
    write(poss[i], 2, 2 + (i - 1) * 10)
  end

  for i = 1, #entered do
    for j = 1, #entered[i] do
      write(entered[i][j], i * 20 + 50, j * 10)
    end
  end
end

local function processEvent(e, ...)
  if e == "key" then
    local k = ...
    if k == "escape" then
      running = false
    end
  elseif e == "char" then
    local c = ...
    table.insert(entered[pos], c)
    if #entered[pos] == keylen then
      pos = pos + 1
    end

    calculate()
  end
end

local eventQueue = {}
while running do

  while true do
    local e = {coroutine.yield()}
    if not e[1] then break end
    table.insert(eventQueue, e)
  end

  while #eventQueue > 0 do
    local e = table.remove(eventQueue, 1)
    processEvent(unpack(e))
  end

  gpu.clear()

  draw()

  gpu.swap()

end
