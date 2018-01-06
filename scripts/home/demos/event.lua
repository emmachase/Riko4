while true do
  local e = {coroutine.yield()}
  
  if e[1] == "key" and e[2] == "escape" then
    break
  end
  
  print(unpack(e))
  shell.redraw(true)
end