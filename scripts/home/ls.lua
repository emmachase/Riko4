local args = {...}

--print("YO MA "..tostring(args[1]))
local dir = args[1] and "./scripts/"..args[1] or "./scripts"

for k, v in lfs.dir(dir) do
  --print(tostring(k))
  pushOutput(k)
  shell.redraw()
end
