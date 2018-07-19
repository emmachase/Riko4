local highlighter = {}

local tableInsert = table.insert

local keywords = {
  ["local"]  = true, ["function"] = true, ["for"]   = true, ["if"]     = true,
  ["then"]   = true, ["in"]       = true, ["do"]    = true, ["else"]   = true,
  ["elseif"] = true, ["end"]      = true, ["break"] = true, ["return"] = true,
  ["not"]    = true, ["and"]      = true, ["or"]    = true, ["while"]  = true,
  ["repeat"] = true, ["until"]    = true,
}

local specialVars = {
  ["io"]      = true, ["fs"]    = true, ["gpu"]       = true, ["image"]  = true,
  ["speaker"] = true, ["table"] = true, ["coroutine"] = true, ["string"] = true,
  ["_G"]      = true, ["math"]  = true, ["error"]     = true, ["os"]     = true
}

local wordPrims = {
  ["true"] = true, ["false"] = true, ["nil"] = true,
}


local syntaxTheme

function highlighter.init(args)
  syntaxTheme = args.syntaxTheme
end

function highlighter.colorizeLine(text)
  local coloredLine = {}

  local instr = false
  local laststr

  while #text > 0 do
    local beginp, endp = text:find("[a-zA-Z0-9%_]+")

    if not beginp then
      local lastun = ""
      local blastun = ""
      for i=1, #text do
        local unimp = text:sub(i, i)
        if unimp then
          if not instr and unimp == "-" and #text > i and text:sub(i + 1, i + 1) == "-" then
            tableInsert(coloredLine, {text:sub(i), syntaxTheme.comment})
            break
          elseif instr and ((lastun == "\\" and blastun ~= "\\") or unimp == "\\") then
            tableInsert(coloredLine, {unimp, syntaxTheme.special})
          elseif laststr and unimp == laststr and (lastun ~= "\\" or blastun == "\\") then
            laststr = nil
            instr = false
            tableInsert(coloredLine, {unimp, syntaxTheme.string})
          elseif not laststr and (unimp == "\"" or unimp == "'") then
            laststr = unimp
            instr = true
            tableInsert(coloredLine, {unimp, syntaxTheme.string})
          else
            tableInsert(coloredLine, {unimp, instr and syntaxTheme.string or syntaxTheme.catch})
          end

          blastun = lastun
          lastun = unimp
        end
      end
      break
    else
      local lastun = ""
      local blastun = ""
      local qt = false
      for i=1, beginp - 1 do
        local unimp = text:sub(i, i)
        if unimp then
          if not instr and unimp == "-" and #text > i and text:sub(i + 1, i + 1) == "-" then
            tableInsert(coloredLine, {text:sub(i), syntaxTheme.comment})
            qt = true
            break
          elseif instr and ((lastun == "\\" and blastun ~= "\\") or unimp == "\\") then
            tableInsert(coloredLine, {unimp, syntaxTheme.special})
          elseif laststr and unimp == laststr and (lastun ~= "\\" or blastun == "\\") then
            laststr = nil
            instr = false
            tableInsert(coloredLine, {unimp, syntaxTheme.string})
          elseif not laststr and (unimp == "\"" or unimp == "'") then
            laststr = unimp
            instr = true
            tableInsert(coloredLine, {unimp, syntaxTheme.string})
          else
            tableInsert(coloredLine, {unimp, instr and syntaxTheme.string or syntaxTheme.catch})
          end

          blastun = lastun
          lastun = unimp
        end
      end

      if qt then break end

      if lastun == "\\" and instr then
        tableInsert(coloredLine, {text:sub(beginp, beginp), syntaxTheme.special})
        text = text:sub(beginp + 1)
      else
        local word = text:sub(beginp, endp)
        do
          local nextX = text:sub(endp + 1):match("%S+")

          if instr then
            tableInsert(coloredLine, {word, syntaxTheme.string})
          elseif specialVars[word] then
            tableInsert(coloredLine, {word, syntaxTheme.specialKeyword})
          elseif keywords[word] then
            tableInsert(coloredLine, {word, syntaxTheme.keyword})
          elseif nextX and nextX:sub(1, 1) == "(" then
            tableInsert(coloredLine, {word, syntaxTheme.func})
          elseif tonumber(word) or wordPrims[word] then
            tableInsert(coloredLine, {word, syntaxTheme.primitive})
          else
            tableInsert(coloredLine, {word, syntaxTheme.catch})
          end
        end
        text = text:sub(endp + 1)
      end
    end
  end

  return coloredLine
end

return highlighter