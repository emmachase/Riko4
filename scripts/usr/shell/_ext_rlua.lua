-- TODO: Line numbers are wrong with rlua files, fix this..

return function(filename, args, env)
  local processor = loadfile("/usr/bin/pproc.lua")

  local s, retFile = pcall(processor, filename, "--sout")

  if s then
    local func, e = loadstring(retFile)
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

    setfenv(func, env)
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
  else
    if retFile then
      print(retFile, 8)
    else
      print("Unknown Error Occurred", 8)
    end
  end
end