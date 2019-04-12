return function(context)
  local term = context:get "term"
  local util = context:get "util"

  local cb = {
    mode = "normal",
    text = "",
    textBg = 1,
    textFg = 16
  }


  function cb.displayMessage(text, fg, bg)
    cb.text = text
    cb.textFg = fg or 16
    cb.textBg = bg or 1
  end


  local commands = {}
  function cb.registerCommand(names, func)
    for i = 1, #names do
      commands[names[i]] = func
    end
  end

  function cb.invokeCommand(name, ...)
    if commands[name] then
      commands[name](...)
    else
      cb.displayMessage("Not an editor command: " .. name, 16, 8)
    end
  end

  local movements = {}
  function cb.registerMovement(char, func)
    movements[char] = func
  end

  local actions = {}
  function cb.registerAction(char, flags, func)
    actions[char] = {flags = flags, func = func}
  end


  local command = {
    partial = ""
  }

  local function parseCommand()
    local str = command.partial

    local function c()
      return str:sub(1, 1)
    end

    local function cc()
      str = str:sub(2)
    end

    local function parseNumber()
      local num, rest = str:match("(%d+)(.*)")
      str = rest

      return num
    end

    local function parseMovement()
      local move = movements[c()]
      if move then
        cc()
      end

      return move
    end

    local function parseAction()
      local action = actions[c()]
      if action then
        cc()
      end

      return action
    end

    local rep = 1
    if c():match("%d") then
      rep = parseNumber()
    end

    local move = parseMovement()
    if move then
      return {type="movement", actor = move, rep = rep}
    end

    local action = parseAction()
    if action then
      local data = {}

      if action.flags.needsMove then
        local move = parseMovement()
        if move then
          data.move = move
        else
          -- Invalid
          return false, false
        end
      end

      if action.flags.needsChar then
        local char = c()
        if char ~= "" then
          data.char = char
        else
          -- Invalid
          return false, false
        end
      end

      return {type = "action", actor = action, rep = rep, data = data}
    end

    if #str == 0 then
      -- Partial
      return false, true
    else
      -- Invalid
      return false, false
    end
  end

  local input = {
    typing = false,
    cursor = 1,
    text = ""
  }

  local function beginTyping()
    input.typing = true
    input.cursor = 1
    input.text = ""

    term.blink()
  end

  local function stopTyping(success)
    cb.text = ":" .. input.text

    input.typing = false
    term.blink(false)

    if success and #input.text > 0 then
      local args, n = {}, 1
      for arg in input.text:gmatch("%S+") do
        args[n] = arg
        n = n + 1
      end

      cb.invokeCommand(unpack(args))
    end
  end

  local function insertChars(chars)
    input.text = input.text:sub(1, input.cursor - 1) .. chars .. input.text:sub(input.cursor)
    input.cursor = input.cursor + #chars
  end

  -- Returns true/false whether the event should
  -- be forwarded down the focus hierarchy.
  function cb.processEvent(e, ...)
    if input.typing then
      if e == "char" then
        local c = ...
        insertChars(c)
      elseif e == "key" then
        local k = ...
        if k == "escape" then
          stopTyping(false)
        elseif k == "return" then
          stopTyping(true)
        end
      end

      return true
    elseif cb.mode == "normal" then
      if e == "char" then
        local c = ...
        if c == ":" then
          beginTyping()
          return true
        else
          -- Try to add it to command partial
          command.partial = command.partial .. c

          -- Check if we're done
          local parsedCommand, partialFlag = parseCommand()
          if parsedCommand then
            -- TODO
          else
            if not partialFlag then
              -- Totally invalid, clear it out
              command.partial = ""
            end
          end
        end
      end

      return false
    end
  end

  function cb.draw()
    local myLine = term.height

    term.clearLine(myLine)

    if input.typing then
      term.write(1, myLine, ":" .. input.text)
      term.x = input.cursor + 1
      term.y = myLine
    else
      term.write(1, myLine, cb.text, cb.textFg, cb.textBg)

      local rhs = " "

      rhs = util.padStr(command.partial, 10) .. rhs

      term.write(term.width - #rhs + 1, myLine, rhs, 16, 1)
    end
  end

  return cb
end
