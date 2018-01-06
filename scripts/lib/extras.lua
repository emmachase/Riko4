local rnd, range

do
  rnd = math.random

  range = function(a, b, step)
    local out = {}
    if b then
      for i = a, b, step or 1 do
        out[#out + 1] = i
      end
    else
      for i = 1, a do
        out[i] = i
      end
    end

    return out
  end
end