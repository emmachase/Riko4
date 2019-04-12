-- Terminal

return function(context)
  local scrnW, scrnH = gpu.width, gpu.height

  local font  = gpu.font.data
  local fontW = font.w + 1 -- TODO: This must be changed after fonts overhaul
  local fontH = font.h + 1

  -- Character buffer
  local term = {
    width  = math.floor(scrnW / fontW),
    height = math.floor(scrnH / fontH),
    buffer = {},
    x = 1,
    y = 1,
    blinker = -math.huge
  }

  for i = 1, term.height do
    term.buffer[i] = {}
    for j = 1, term.width do
      term.buffer[i][j] = {" ", 1, 16} -- Char, BG, FG
    end
  end


  function term.blink(on)
    -- Not `not on` because we want term.blink() to start blinking,
    -- only explicit term.blink(false) should stop the cursor blink
    if on == false then
      term.blinker = -math.huge
    else
      term.blinker = 0
    end
  end

  function term.clearLine(y)
    for j = 1, term.width do
      term.buffer[y][j] = {" ", 1, 16} -- Char, BG, FG
    end
  end

  function term.write(x, y, str, fg, bg)
    fg = fg or 16
    bg = bg or 1

    local row = term.buffer[y]
    for i = x, x + #str - 1 do
      if row[i] then
        local idx = i - x + 1
        row[i] = {str:sub(idx, idx), bg, fg}
      else
        break
      end
    end
  end

  function term.draw()
    -- Draw Character Buffer
    for i = 0, term.width - 1 do
      for j = 0, term.height do
        local row = term.buffer[j + 1]
        if row then
          local char = row[i + 1]
          if char[2] > 1 then
            gpu.drawRectangle(fontW * i, fontH * j, fontW, fontH, char[2])
          end

          if char[1] ~= " " then
            write(char[1], fontW * i, fontH * j, char[3])
          end
        end
      end
    end

    -- Blinking cursor
    if term.blinker % 1 < 0.5 then
      write("_", (term.x - 1) * fontW, (term.y - 1) * fontH + 2, 16)
    end
  end

  function term.update(dt)
    term.blinker = term.blinker + dt
  end

  return term
end
