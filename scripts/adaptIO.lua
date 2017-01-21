local funcs = {
  {io, "open"},
  {io, "lines"},
  {io, "input"},
  {_G, "dofile"},
  {_G, "loadfile"}
}

for i=1, #funcs do
  local ref = funcs[i][1][funcs[i][2]]

  funcs[i][1][funcs[i][2]] = function(fn, ...)
    if fn:sub(1, 1) == "/" then
      fn = fn:sub(2)
    end
    fn = "scripts/home/" .. fn

    return ref(fn, ...)
  end
end
