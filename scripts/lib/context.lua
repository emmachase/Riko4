local context = {}

function context.new()
  local t = {
    cache = {},
    loading = {}
  }

  return setmetatable(t, {__index = context})
end

function context:get(filename)
  if not self.cache then error("no cache", 2) end

  if self.cache[filename] == nil then
    if self.loading[filename] then
      error("circular dependency detected!", 2)
    end

    self.loading[filename] = true

    local result = require(filename)
    if type(result) == "function" then
      self.cache[filename] = result(self)
    else
      self.cache[filename] = result
    end

    self.loading[filename] = false
  end

  return self.cache[filename]
end

function context:set(name, data)
  self.cache[name] = data
end

return context
