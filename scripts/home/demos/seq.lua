local a = {loop = 1}
for i = 1, 9 do
  a[i] = 2
end
for i = 10, 18 do
  a[i] = 1
end
for i = 19, 27 do
  a[i] = 0
end
for i = 28, 36 do
  a[i] = 3
end
speaker.loadSequence(a, 1)

local b = {0, 0, 1, 1, 3, 3, loop = 1}
speaker.loadSequence(b, 2)

local c = {3, 10, 15, 15, 6, 2, loop = 1}
speaker.loadSequence(c, 3)

speaker.play({channel = 1, frequency = 261, time = 1.5, duty = 1, arpeggio = 2, volSlide = 3})