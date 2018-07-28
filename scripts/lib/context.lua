local context = {}

function context.new()
  local t = {
    cache = {}
  }

  return setmetatable(t, {__index = context})
end

function context:get(filename)
  if not self.cache then error("no cache", 2) end

  if not self.cache[filename] then
    local result = require(filename)
    if type(result) == "function" then
      self.cache[filename] = result(self)
    else
      self.cache[filename] = result
    end
  end

  return self.cache[filename]
end

function context:set(name, data)
  self.cache[name] = data
end

return context
