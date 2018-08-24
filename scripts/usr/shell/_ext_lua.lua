return function(filename, args, env)
  local func, e = loadfile(filename)
  if not func then
    if e then
      local xt = e:match("%[.+%]:(.+)")
      if xt then
        return false, "Error: " .. xt
      else
        return false, "Error: " .. e
      end
    else
      return false, "Unknown Error Occurred"
    end
  end

  setfenv(func, env)
  local ret = {pcall(func, unpack(args))}
  local s
  s, e = ret[1], ret[2]

  if not s then
    if e then
      local xt = e:match("%[.+%](.+)")
      if xt then
        return false, "Error: [" .. filename .. "]" .. xt
      else
        return false, "Error: " .. e
      end
    else
      return false, "Unknown Error Occurred"
    end
  else
    return unpack(ret)
  end
end
