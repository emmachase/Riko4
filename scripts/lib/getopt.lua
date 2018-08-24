local api = {}

api.noArgument = 0
api.requiredArgument = 1
api.optionalArgument = 2

api.notOpt = {}

--[[
longOpts format:
{
  name = {
    hasArg = 0|1|2,
    val = <something>
  }...
}

config:
{
  printErrors = true,
  noErrors = not printErrors
}
]]
function api.getopt(argTbl, optString, longOpts, config)
  config = config or {}

  local printErrors = true
  if config.printErrors == false or (not config.noErrors) then
    printErrors = false
  end
  longOpts = longOpts or {}

  local toParse = {}
  for i = 1, #argTbl do
    toParse[i] = argTbl[i]
  end

  local parseMode
  local shortOpts = {}
  parseMode, optString = optString:match("^([-+]?)(.*)")
  while #optString > 0 do
    local char, args
    char, args, optString = optString:match("^(.)([:]?[:]?)(.*)")

    if not char then
      error("Malformed optString", 2)
    end

    shortOpts[char] = {
      hasArg = (args == ":" and api.requiredArgument) or
               (args == "::" and api.optionalArgument) or api.noArgument
    }
  end

  local instance = {}
  instance.notOptions = {}

  function instance.evalNext()
    local opt = table.remove(toParse, 1)

    if opt == "--" then
      return -1
    end

    if opt:sub(1, 1) == "-" then
      if opt:sub(2, 2) == "-" then
        -- Long option
        opt = opt:sub(3)

        local optParams = longOpts[opt]
        if optParams then
          if optParams.hasArg == api.noArgument then
            return optParams.val or opt, nil
          else
            local nextElm = toParse[1]

            if optParams.hasArg == api.optionalArgument then
              if nextElm:sub(1, 1) == "-" then
                return optParams.val or opt, nil
              else
                table.remove(toParse, 1)
                return optParams.val or opt, nextElm
              end
            elseif optParams.hasArg == api.requiredArgument then
              if nextElm:sub(1, 1) == "-" then
                error(("Option '--%s' requires an argument"):format(opt), 0)
              else
                table.remove(toParse, 1)
                return optParams.val or opt, nextElm
              end
            else
              error(("Option Parameter 'hasArg' for '--%s' is invalid"):format(opt), 0)
            end
          end
        else
          if printErrors then
            print(("Unknown option '--%s'"):format(opt), 8)
          end

          return "?", opt
        end
      else
        if opt == "-" then
          return api.notOpt
        end

        -- Short option
        opt = opt:sub(2)

        local char
        char, opt = opt:match("^(.)(.*)")

        table.insert(toParse, 1, "-" .. opt)

        local optParams = shortOpts[char]
        if optParams then
          if optParams.hasArg == api.noArgument then
            return char, nil
          else
            local nextElm = toParse[2]
            if optParams.hasArg == api.optionalArgument then
              if #opt == 0 then
                if nextElm:sub(1, 1) == "-" then
                  return char, nil
                else
                  table.remove(toParse, 2)
                  return char, nextElm
                end
              else
                return char, nil
              end
            elseif optParams.hasArg == api.requiredArgument then
              if #opt == 0 then
                if nextElm:sub(1, 1) == "-" then
                  error(("Option '--%s' requires an argument"):format(opt), 0)
                else
                  table.remove(toParse, 2)
                  return char, nextElm
                end
              else
                local arg = opt
                table.remove(toParse, 1)

                return char, arg
              end
            else
              error(("Option Parameter 'hasArg' for '--%s' is invalid"):format(opt), 0)
            end
          end
        else
          if printErrors then
            print(("Unknown option '-%s'"):format(char), 8)
          end

          return "?", char
        end
      end
    else
      if parseMode == "+" then
        return -1, opt
      elseif parseMode == "-" then
        return 1, opt
      else
        instance.notOptions[#instance.notOptions + 1] = opt
        return api.notOpt
      end
    end
  end

  setmetatable(instance, {
    __call = function(self, switchTable)
      local val, arg = 0
      while #toParse > 0 and val ~= -1 do
        val, arg = instance.evalNext()
        if val ~= api.notOpt then
          if switchTable[val] then
            switchTable[val](arg)
          elseif switchTable.default then
            switchTable.default(val, arg)
          end
        end
      end

      for i = 1, #toParse do
        instance.notOptions[#instance.notOptions + 1] = toParse[i]
      end

      return instance
    end
  })

  return instance
end

setmetatable(api, {__call = function(self, ...) return api.getopt(...) end})
return api
