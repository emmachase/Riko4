local Vector = {}

function Vector.new(xov, y, z)
  local vd
  if type(xov) == "number" then
    vd = {x = xov, y = y or 0, z = z or 0}
  else
    vd = {xov.x, xov.y, xov.z}
  end

  setmetatable(vd, {__index = Vector, __tostring = function(t) return "v{" .. t.x .. "," .. t.y .. "," .. t.z .. "}" end})
  return vd
end

function Vector:plus(other)
  return Vector(self.x + other.x, self.y + other.y, self.z + other.z)
end

function Vector:add(other)
  self.x, self.y, self.z = self.x + other.x, self.y + other.y, self.z + other.z
  return self
end

function Vector:minus(other)
  return Vector(self.x - other.x, self.y - other.y, self.z - other.z)
end

function Vector:sub(other)
  self.x, self.y, self.z = self.x - other.x, self.y - other.y, self.z - other.z
  return self
end

function Vector:times(other)
  if type(other) == "number" then
    return Vector(self.x * other, self.y * other, self.z * other)
  else
    return Vector(self.x * other.x, self.y * other.y, self.z * other.z)
  end
end

function Vector:mult(other)
  if type(other) == "number" then
    self.x, self.y, self.z = self.x * other, self.y * other, self.z * other
  else
    self.x, self.y, self.z = self.x * other.x, self.y * other.y, self.z * other.z
  end
  return self
end

function Vector:over(other)
  if type(other) == "number" then
    return Vector(self.x / other, self.y / other, self.z / other)
  else
    return Vector(self.x / other.x, self.y / other.y, self.z / other.z)
  end
end

function Vector:div(other)
  if type(other) == "number" then
    self.x, self.y, self.z = self.x / other, self.y / other, self.z / other
  else
    self.x, self.y, self.z = self.x / other.x, self.y / other.y, self.z / other.z
  end
  return self
end

function Vector:dot(other)
  return self.x * other.x + self.y * other.y + self.z * other.z
end

function Vector:cross(other)
  return Vector(self.y * other.z - self.z * other.y,
                self.z * other.x - self.x * other.z,
                self.x * other.y - self.y * other.x)
end

function Vector:sqNorm()
  return self.x * self.x + self.y * self.y + self.z * self.z
end

function Vector:norm()
  return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end

function Vector:normalize()
  return self:over(self:norm())
end

setmetatable(Vector, {__call = function(c, ...) return Vector.new(...) end})
return Vector