local complex = {}
do
  function complex.init(a, b)
    local c = {real = a, imag = b}
    setmetatable(c, {__index = complex,
      __add = complex.add,
      __sub = complex.sub,
      __mul = complex.mul,
      __div = complex.div,
      __pow = complex.pow,
      __unm = complex.unm})

    return c
  end

  local function scalarDiff(a, b, tf, sf)
    if type(b) == "table" then
      local c = b
      b = a
      a = c
    end

    if type(b) == "table" then
      return tf(a, b)
    else
      return sf(a, b)
    end
  end

  local function reciprocate(z)
    local mag = z.real * z.real + z.imag * z.imag
    return complex(z.real / mag, -z.imag / mag)
  end

  function complex.add(a, b)
    return scalarDiff(a, b, function(c, d)
      return complex(c.real + d.real, c.imag + d.imag)
    end, function(c, d)
      return complex(c.real + d, c.imag)
    end)
  end

  function complex.sub(a, b)
    return complex.add(a, -b)
  end

  function complex.mul(a, b)
    return scalarDiff(a, b, function(c, d)
      return complex(c.real * d.real - c.imag * d.imag, c.real * d.imag + c.imag * d.real)
    end, function(c, d)
      return complex(c.real * d, c.imag * d)
    end)
  end

  function complex.div(a, b)
    if type(b) == "table" then
      return complex.mul(a, reciprocate(b))
    else
      return complex.mul(a, 1 / b)
    end
  end

  function complex.pow(a, b)
    if type(a) == "table" then
      if type(b) ~= "table" then
        b = complex(b, 0)
      end

      local arg = math.atan(a.imag / a.real)
      local sqMag = a.real * a.real + a.imag * a.imag

      local iC = math.pow(sqMag, b.real / 2) * math.exp(-b.imag * arg)
      local tP = b.real * arg + 0.5 * b.imag * math.log(sqMag)
      return complex(iC * math.cos(tP), iC * math.sin(tP))
    else
      -- x^(a+bI) == x^a * E^bI == x^a * (cos(b) + Isin(b))
      local xa = math.pow(a, b.real)
      return complex(xa * math.cos(b.imag), xa * math.sin(b.imag))
    end
  end

  function complex.unm(a)
    return complex(-a.real, -a.imag)
  end

  setmetatable(complex, {__call=function(_, ...) return complex.init(...) end})
end

return complex
