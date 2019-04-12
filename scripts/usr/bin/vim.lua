--HELP: \b6Usage: \b16vim \b7<\b16file\b7> \n
-- \b6Description: \b7Opens \b16file \b7in a vimlike code editor

local running = true

local myPath = fs.getLastFile()
local editLibs = myPath:match(".+%/") .. "edit/"
addRequirePath(editLibs)

local workingDir = myPath:match(".+%/") .. "vim/"
addRequirePath(workingDir)

local context = require("context").new()
context:set("mediator", context:get("mediator")())
context:set("running", true)

local application = context:get "application"


local eq = {}
local lastUpdate = os.clock()
while context:get "running" do
  while true do
    local a = {coroutine.yield()}
    if not a[1] then break end
    table.insert(eq, a)
  end

  while #eq > 0 do
    application.processEvent(unpack(table.remove(eq, 1)))
  end

  -- Avoid unnecesary flashing
  if not context:get "running" then
    break
  end

  local time = os.clock()

  application.update(time - lastUpdate)
  lastUpdate = time

  application.draw()
end
