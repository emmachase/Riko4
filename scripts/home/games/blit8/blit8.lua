--HELP: \b6Usage: \b16blit8 \b7<\b16file\b7> \n
-- \b6Description:            \n
-- Blit-8 by CrazedProgrammer \n
-- Chip-8 key mapping:        \n
-- 123C   1234                \n
-- 456D   QWER                \n
-- 789E   ASDF                \n
-- A0BF   ZXCV                \n
-- Enter: Restart             \n
-- Space: Pause/Continue      \n
-- Left/Right: Change clock speed

--[[
Blit-8 version 1.0
Copyright (c) 2016 CrazedProgrammer

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--

local getopt = require("getopt")
local args = {...}
local parseInstance = getopt(args, "", {
}) {
}
if #parseInstance.notOptions < 1 then
  print("Missing operand", 8)
  print("Try 'help blit8' for more information", 8)
  return
end
local filename = parseInstance.notOptions[1]

local speed = 10 -- Instructions per frame (60Hz)
local display, keys, keypress, RAM, stack, DT, ST, PC, SP, V, I -- luacheck: ignore

-- Load ROM into RAM

local function load()
  display = { }
  keys = { }
  RAM = {0xF0, 0x90, 0x90, 0x90, 0xF0, 0x20, 0x60, 0x20, 0x20, 0x70, 0xF0, 0x10, 0xF0, 0x80, 0xF0, 0xF0, 0x10, 0xF0, 0x10, 0xF0, 0x90, 0x90, 0xF0, 0x10, 0x10, 0xF0, 0x80, 0xF0, 0x10, 0xF0, 0xF0, 0x80, 0xF0, 0x90, 0xF0, 0xF0, 0x10, 0x20, 0x40, 0x40, 0xF0, 0x90, 0xF0, 0x90, 0xF0, 0xF0, 0x90, 0xF0, 0x10, 0xF0, 0xF0, 0x90, 0xF0, 0x90, 0x90, 0xE0, 0x90, 0xE0, 0x90, 0xE0, 0xF0, 0x80, 0x80, 0x80, 0xF0, 0xE0, 0x90, 0x90, 0x90, 0xE0, 0xF0, 0x80, 0xF0, 0x80, 0xF0, 0xF0, 0x80, 0xF0, 0x80, 0x80}
  stack = { } -- #stack = stack pointer
  DT, ST = 0, 0 -- Timers
  PC = 0x200 -- Program counter
  V, I = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}, 0 -- General purpose registers: V0 - VF, 12-bit memory register

  if not fs.exists(filename) then
    print("ROM file does not exist.")
    error()
  end
  local address = 0x200
  local handle = fs.open(filename, "rb")
  local byte = handle:read(1)
  while byte do
    RAM[address + 1] = byte:byte(1)
    byte = handle:read(1)
    address = address + 1
  end
  handle:close()
  for i = 1, 4096 do
    if not RAM[i] then
      RAM[i] = 0
    end
  end
end

local function doCycle()
  local opcode = RAM[PC + 1] * 256 + RAM[PC + 2]
  local opcode1 = math.floor(opcode / 4096)
  local opcode2 = math.floor((opcode % 4096) / 256)
  local opcode3 = math.floor((opcode % 256) / 16)
  local opcode4 = opcode % 16
  local nnn = opcode2 * 256 + opcode3 * 16 + opcode4
  local kk = opcode3 * 16 + opcode4
  local x = opcode2 + 1
  local y = opcode3 + 1

  if opcode1 + opcode2 + opcode4 == 0 and opcode3 == 0xE then
    for i = 1, 64 * 32 do
      display[i] = nil
    end
  elseif opcode1 + opcode2 == 0 and opcode3 == 0xE and opcode4 == 0xE then
    if #stack > 0 then
      PC = stack[#stack] - 2
      stack[#stack] = nil
    end
  elseif opcode1 == 1 then
    PC = nnn - 2
  elseif opcode1 == 2 then
    stack[#stack + 1] = PC + 2
    PC = nnn - 2
  elseif opcode1 == 3 then
    if V[x] == kk then
      PC = PC + 2
    end
  elseif opcode1 == 4 then
    if V[x] ~= kk then
      PC = PC + 2
    end
  elseif opcode1 == 5 and opcode4 == 0 then
    if V[x] == V[y] then
      PC = PC + 2
    end
  elseif opcode1 == 6 then
    V[x] = kk
  elseif opcode1 == 7 then
    V[x] = (V[x] + kk) % 256
  elseif opcode1 == 8 then
    if opcode4 == 0 then
      V[x] = V[y]
    elseif opcode4 == 1 then
      V[x] = bit.bor(V[x], V[y])
    elseif opcode4 == 2 then
      V[x] = bit.band(V[x], V[y])
    elseif opcode4 == 3 then
      V[x] = bit.bxor(V[x], V[y])
    elseif opcode4 == 4 then
      V[x] = V[x] + V[y]
      if V[x] > 255 then
        V[x] = V[x] % 256
        V[16] = 1
      else
        V[16] = 0
      end
    elseif opcode4 == 5 then
      V[x] = V[x] - V[y]
      if V[x] < 0 then
        V[16] = 0
        V[x] = V[x] % 256
      else
        V[16] = 1
      end
    elseif opcode4 == 6 then
      V[16] = V[x] % 2
      V[x] = math.floor(V[x] / 2)
    elseif opcode4 == 7 then
      V[x] = V[y] - V[x]
      if V[x] < 0 then
        V[16] = 0
        V[x] = V[x] % 256
      else
        V[16] = 1
      end
    elseif opcode4 == 0xE then
      V[16] = math.floor(V[x] / 128)
      V[x] = (V[x] * 2) % 256
    end
  elseif opcode1 == 9 and opcode4 == 0 then
    if V[x] ~= V[y] then
      PC = PC + 2
    end
  elseif opcode1 == 0xA then
    I = nnn
  elseif opcode1 == 0xB then
    PC = nnn + V[1] - 2
  elseif opcode1 == 0xC then
    V[x] = bit.band(math.floor(math.random() * 256), kk)
  elseif opcode1 == 0xD then
    local px, py = V[x] % 64, V[y] % 32
    V[16] = 0
    for j = 0, opcode4 - 1 do
      if py + j > 31 then
        break
      end
      local byte = RAM[I + j + 1]
      for i = 0, 7 do
        if px + i > 63 then
          break
        end
        if bit.band(byte, 2 ^ (7 - i)) > 0 then
          local index = (py + j) * 64 + px + i + 1
          display[index] = not display[index]
          if not display[index] then
            V[16] = 1
          end
        end
      end
    end
  elseif opcode1 == 0xE and opcode3 == 9 and opcode4 == 0xE then
    if keys[V[x] + 1] then
      PC = PC + 2
    end
  elseif opcode1 == 0xE and opcode3 == 0xA and opcode4 == 1 then
    if not keys[V[x] + 1] then
      PC = PC + 2
    end
  elseif opcode1 == 0xF then
    if opcode3 == 0 and opcode4 == 7 then
      V[x] = DT
    elseif opcode3 == 0 and opcode4 == 0xA then
      if not keypress then
        PC = PC - 2
      else
        V[x] = keypress
      end
    elseif opcode3 == 1 and opcode4 == 5 then
      DT = V[x]
    elseif opcode3 == 1 and opcode4 == 8 then
      ST = V[x]
      speaker.play({channel = 1, frequency = 523, time = ST / 60, shift = 0, volume = 0.1, attack = 0, release = 0})
    elseif opcode3 == 1 and opcode4 == 0xE then
      I = I + V[x]
    elseif opcode3 == 2 and opcode4 == 9 then
      I = V[x] * 5
    elseif opcode3 == 3 and opcode4 == 3 then
      RAM[I + 1] = math.floor(V[x] / 100)
      RAM[I + 2] = math.floor((V[x] % 100) / 10)
      RAM[I + 3] = V[x] % 10
    elseif opcode3 == 5 and opcode4 == 5 then
      for i = 1, x do
        RAM[I + i] = V[i]
      end
    elseif opcode3 == 6 and opcode4 == 5 then
      for i = 1, x do
        V[i] = RAM[I + i]
      end
    end
  end
  PC = (PC + 2) % 4096
end

local function doFrame()
  for i = 1, speed do
    doCycle()
  end
  if DT > 0 then
    DT = DT - 1
  end
  if ST > 0 then
    ST = ST - 1
  end
end

local running = true

local function drawFrame()
  local gpuWidth, gpuHeight = gpu.width, gpu.height - 10
  local screenScale = math.floor(math.min(gpuWidth / 64, gpuHeight / 32))
  local xOffset, yOffset = math.floor((gpuWidth - (64 * screenScale)) / 2), math.floor((gpuHeight - (32 * screenScale)) / 2)
  gpu.clear(0)
  write((running and "Running" or "Paused").." "..tostring(speed * 60).."Hz", 2, gpu.height - 9, 16)
  for j = 1, 32 do
    for i = 1, 64 do
      if display[(j - 1) * 64 + i] then
        gpu.drawRectangle(xOffset + i * screenScale, yOffset + j * screenScale, screenScale, screenScale, 16)
      end
    end
  end
  gpu.swap()
end


load()

local keyMapping = {"1", "2", "3", "q", "w", "e", "a", "s", "d", "x", "z", "c", "4", "r", "f", "v"}

local quit = false
while not quit do
  while true do
    local event = {coroutine.yield()}
    if event[1] == nil then
      break
    elseif event[1] == "terminate" then
      break
    elseif event[1] == "key" then
      if event[2] == "escape" then
        quit = true
        break
      elseif event[2] == "return" then
        load()
      elseif event[2] == "space" then
        running = not running
      elseif event[2] == "left" then
        if speed > 3 then
          speed = speed - 3
        end
      elseif event[2] == "right" then
        speed = speed + 3
      else
        for i = 1, 16 do
          if event[2] == keyMapping[i] then
            keys[i + 1] = true
            keypress = i
          end
        end
      end
    elseif event[1] == "keyUp" then
      for i = 1, 16 do
        if event[2] == keyMapping[i] then
          keys[i + 1] = false
        end
      end
    end
  end
  if running then
      doFrame()
      keypress = nil
  end
  drawFrame()
end
