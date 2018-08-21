return function(superclass, name)
 local cls = {}
 cls.__name = name or ""
 cls.__super = superclass
 cls.__index = cls
 return setmetatable(cls, {__call = function (c, ...)
  local self = setmetatable({}, cls)
  local super = cls.__super
  while (super~=nil) do
   if super.__init then
    super.__init(self, ...)
   elseif super.init then
    super.init(self, ...)
   end
   super = super.__super
  end
  if cls.__init then
   cls.__init(self, ...)
  elseif cls.init then
   cls.init(self, ...)
  end
  return self
 end})
end
