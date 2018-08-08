if _init then
  _init()
end

--#ifndef NOLOOP

local eq = {}
local last = os.clock()
while _running do
  while true do
    local a = {coroutine.yield()}
    if not a[1] then break end
    table.insert(eq, a)
  end

  while #eq > 0 do
    local e = table.remove(eq, 1)
    if _event then
      _event(unpack(e))
    end

    _eventDefault(unpack(e))
  end

  if _update then
    _update(os.clock() - last)
    last = os.clock()
  end

  if _draw then
    _draw()
  end
end

if _cleanup then
  _cleanup()
end

--#endif
