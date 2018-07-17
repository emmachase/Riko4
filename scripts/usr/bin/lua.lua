print("Type exit() to return to the shell.")
local running = true
exit = function() running = false end

while running do
  shell.write("> ")
  local ip = shell.read()
  local s, e = loadstring("return " .. ip)

  if not s then
    s, e = loadstring(ip)
  end

  if s then
    local r = s()
    if r ~= nil then
      print(tostring(r))
    end
  end
end

exit = nil