return function(filename, args)
  local func, e = loadfile(filename)
  if not func then
    if e then
      local xt = e:match("%[.+%]:(.+)")
      if xt then
        print("Error: " .. xt, 8)
      else
        print("Error: " .. e, 8)
      end
    else
      print("Unknown Error Occurred", 8)
    end

    return
  end

  local s, e = pcall(func, unpack(args))
  if not s then
    if e then
      local xt = e:match("%[.+%](.+)")
      if xt then
        print("Error: [" .. filename .. "]" .. xt, 8)
      else
        print("Error: " .. e, 8)
      end
    else
      print("Unknown Error Occurred", 8)
    end
  end
end