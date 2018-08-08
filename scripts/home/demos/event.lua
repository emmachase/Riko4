while true do
  local e = {coroutine.yield()}

  if e[1] == "key" and e[2] == "escape" then
    break
  end

  if e[1] then
    print(table.concat(e, " "))
  end
  shell.draw()
end
