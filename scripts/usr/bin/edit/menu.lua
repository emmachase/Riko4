return function(context)
  local menu = {}

  local fontW = gpu.font.data.w
  -- local fontH = gpu.font.data.h

  local viewportWidth = gpu.width
  local viewportHeight = gpu.height

  local mediator = context:get "mediator"

  local attacher, detacher

  local widgets = {
    gotoLine = context:get "widgets/goto",
    infoBox = context:get "widgets/info",
    findNext = context:get "widgets/find"
  }

  local editor = context:get "editor"
  local editorTheme
  local quitFunc
  local filename

  local function ccat(tbl, sep)
    local estr = ""
    for i = 1, #tbl do
      estr = estr .. tbl[i]
      if i ~= #tbl then
        estr = estr .. sep
      end
    end

    return estr
  end

  local currentPopout
  local function constructWidget(name, focus, ...)
    if currentPopout then
      currentPopout:cleanup()
      currentPopout:die()
    end

    local widget = widgets[name].new(...)
    if focus then
      attacher(widget)
    end
    currentPopout = widget
    local cleanedUp = false
    widget.cleanup = function(me)
      if focus and not cleanedUp then
        cleanedUp = true
        detacher(me)
        mediator:publish({"editor"}, "startBlink")
      end
    end
    widget.suicide = function()
      currentPopout = nil
    end
  end

  local inMenu = false
  local menuItems = { "Save", "Find", "Goto", "Exit" }
  local menuFunctions = {
    function() -- SAVE
      editor.trimLines()
      editor.updateCursor(editor.getCursorPosition())

      local handle = fs.open(filename, "w")
      handle:write(ccat(editor.getText(), "\n"))
      handle:close()

      constructWidget("infoBox", false, "Saved!")
    end,
    function() -- FIND
      mediator:publish({"editor"}, "openFind")
    end,
    function() -- GOTO
      constructWidget("gotoLine", true)
    end,
    function() -- EXIT
      quitFunc()
    end
  }
  local menuSelected = 1

  local hintText = "Press <esc> to open menu"

  local braceX = 2
  local braceXGoal = 2
  local braceWidth = (#menuItems[menuSelected] + 1)*(fontW + 1)
  local braceWidthGoal = (#menuItems[menuSelected] + 1)*(fontW + 1)

  local function updateHint()
    if inMenu then
      local hWidth = 0
      for i=1, #menuItems do
        if i == menuSelected then
          break
        end
        hWidth = hWidth + #menuItems[i] + 2
      end
      braceXGoal = 2 + hWidth * (fontW + 1)
      braceWidthGoal = (#menuItems[menuSelected] + 1) * (fontW + 1)

      hintText = " " .. table.concat(menuItems, "  ")
    else
      hintText = "Press <esc> to open menu"
    end
  end


  function menu.init(args)
    editorTheme = args.editorTheme
    quitFunc = args.quitFunc
    filename = args.filename
    attacher = args.attacher
    detacher = args.detacher

    mediator:subscribe({"menu", "execute"}, function(cmd, ...)
      for i = 1, #menuItems do
        if menuItems[i] == cmd then
          menuFunctions[i](...)
          break
        end
      end
    end)

    mediator:subscribe({"menu", "misc"}, function(cmd, p1, p2)
      if cmd == "info" then
        constructWidget("infoBox", false, p1, p2)
      elseif cmd == "openFind" then
        constructWidget("findNext", true, p1)
      end
    end)
  end

  function menu.update(dt)
    if currentPopout then
      currentPopout:update(dt)
    end
  end

  local lastI = os.clock()
  function menu.draw()
    gpu.drawRectangle(0, viewportHeight - 10, viewportWidth, 11, editorTheme.selBar)

    local delta = os.clock() - lastI

    braceX = braceX + (braceXGoal - braceX)*10*delta
    if math.abs(braceXGoal - braceX) < 0.1 then braceX = braceXGoal end

    braceWidth = braceWidth + (braceWidthGoal - braceWidth)*10*delta
    if math.abs(braceWidthGoal - braceWidth) < 0.1 then braceWidth = braceWidthGoal end

    write(hintText, 2, viewportHeight - 9, editorTheme.text)

    if inMenu then
      write("[", braceX, viewportHeight - 9, editorTheme.selChar)
      write("]", braceX + braceWidth, viewportHeight - 9, editorTheme.selChar)
    end

    local cursorPos, cursorLine = editor.getCursorPosition()
    local locStr = "Ln "..cursorLine..", Col "..(cursorPos + 1)
    write(locStr, (viewportWidth - 5) - (#locStr * (fontW + 1)), viewportHeight - 9, editorTheme.text)

    if currentPopout then
      currentPopout:draw()
    end

    lastI = os.clock()
  end

  function menu:onKey(modifiers, key)
    if key == "escape" then
      inMenu = not inMenu
      if inMenu then
        mediator:publish({"editor"}, "stopBlink")
      else
        mediator:publish({"editor"}, "startBlink")
      end
      updateHint()

      return true, true
    elseif inMenu then
      if key == "left" then
        menuSelected = menuSelected == 1 and #menuItems or menuSelected - 1
        updateHint()
      elseif key == "right" then
        menuSelected = menuSelected == #menuItems and 1 or menuSelected + 1
        updateHint()
      elseif key == "return" then
        menuFunctions[menuSelected]()
        inMenu = false
        updateHint()

        return true, false
      end

      return true, true
    end
  end

  return menu
end