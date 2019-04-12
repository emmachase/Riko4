--[[

  layout:
  XXX
  XXX
  ===

  Xs - Main window space, managed by layout manager
  =s - Command bar, changes contextually

  How are events passed to each container?
  First Command Center decides if it wants to capture the event, then gets passed on
  Focus Hierarchy?
  - Which tab is focused?
      - In this tab, which window is focused?

]]

return function(context)
  local term = context:get "term"
  local cursor = context:get "cursor"

  local commandBar = context:get "commandbar"
  do -- Load Built-in commands
    context:get "commands.base"
  end

  local application = {
    buffers = {},

    tabs = {},
    focusedTab = 1
  }

  local mousePos = {-5, -5}

  function application.processEvent(e, ...)
    if not commandBar.processEvent(e, ...) then
      -- TODO: Pass along
    end
  end

  function application.draw()
    -- First do all the rendering...
    commandBar.draw()

    -- Then rasterize everything
    gpu.clear()

    term.draw()
    cursor:render(unpack(mousePos))

    gpu.swap()
  end

  function application.update(dt)
    term.update(dt)
  end

  return application
end
