local song = {
  "C-3", "C#3", "D-3", "E-3", "F-3", "F#3", "G-3", "G#3", "A-3", "A#3", "B-3", "C-4",
  "B-3", "A#3", "A-3", "G#3", "G-3", "F#3", "F-3", "E-3", "D-3", "C#3", "C-3"
}

local geometricCst = 1.05946309436
local C0 = 32.70

local notes = {
  C0
}

for i = 2, 8 * 12 do
  notes[i] = notes[i - 1] * geometricCst
end

local lookup = {
  ["C-"] = 1,
  ["C#"] = 2,
  ["D-"] = 3,
  ["D#"] = 4,
  ["E-"] = 5,
  ["F-"] = 6,
  ["F#"] = 7,
  ["G-"] = 8,
  ["G#"] = 9,
  ["A-"] = 10,
  ["A#"] = 11,
  ["B-"] = 12
}

local tempo = 140
local periodicTime = 8 / tempo

for i=1, #song do
  local item = song[i]
  local fr = 1
  if item ~= "===" then
    fr = notes[tonumber(item:sub(3, 3)) * 12 + lookup[item:sub(1, 2)]]
  end
  speaker.play({channel = 5, frequency = fr, time = periodicTime, shift = 0, volume = 0.015, attack = 0, release = 0})
end

-- Down below is half fledged pacman audio

-- for i = 1, 6 do
--   speaker.play({channel = 1, frequency = 200, time = 0.1, shift = 160, volume = 0.06, attack = 0, release = 0})
--   speaker.play({channel = 1, frequency = 360, time = 0.05, shift = -160, volume = 0, attack = 0, release = 0})
--   speaker.play({channel = 1, frequency = 360, time = 0.1, shift = -160, volume = 0.06, attack = 0, release = 0})
--   speaker.play({channel = 1, frequency = 360, time = 0.05, shift = -160, volume = 0, attack = 0, release = 0})
-- end

-- 4.48
-- for i = 1, 2 do
--   speaker.play({channel = 3, frequency = 700, time = 0.5, shift = 200, volume = 0.09, attack = 0, release = 0})
--   speaker.play({channel = 3, frequency = 900, time = 0.5, shift = -200, volume = 0.09, attack = 0, release = 0})
-- end
