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
    if type(result) == "table" then
      self.cache[filename] = result
    else
      self.cache[filename] = result(self)
    end
  end

  return self.cache[filename]
end

function context:set(name, data)
  self.cache[name] = data
end

return context
