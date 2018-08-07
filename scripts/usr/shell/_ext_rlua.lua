-- TODO: Line numbers are wrong with rlua files, fix this..

return function(filename, args, env)
  local processor = loadfile("/usr/bin/pproc.lua")

  local s, retFile = pcall(processor, filename, "--sout", "--nopt")

  if s then
    local func, e = loadstring(retFile)
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
    end

    return unpack(ret)
  else
    if retFile then
      return false, retFile
    else
      return false, "Unknown Error Occurred"
    end
  end
end