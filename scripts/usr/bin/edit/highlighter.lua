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
local state = {
  [0] = {mode = "normal"}
}

function highlighter.init(args)
  syntaxTheme = args.syntaxTheme
end

function highlighter.clear()
  state = {
    [0] = {mode = "normal"}
  }
end

function highlighter.setLine(lineNumber, newText)
  state[lineNumber] = {
    mode = "unparsed",
    colored = {},
    text = newText
  }

  for i = lineNumber, #state do
    state[i].mode = "unparsed"
  end
end

function highlighter.insertLine(lineNumber, text)
  tableInsert(state, lineNumber, {
    mode = "unparsed",
    colored = {},
    text = text
  })

  for i = lineNumber, #state do
    state[i].mode = "unparsed"
  end
end

function highlighter.removeLine(lineNumber)
  table.remove(state, lineNumber)

  for i = lineNumber, #state do
    state[i].mode = "unparsed"
  end
end

function highlighter.recolor(lineNumber)
  if state[lineNumber].mode ~= "unparsed" then
    return
  end

  local startParse = 1
  for i = lineNumber, 2, -1 do
    if state[i].mode ~= "unparsed" then
      startParse = i
      break
    end
  end

  for i = startParse, lineNumber do
    highlighter.parse(lineNumber)
  end
end

function highlighter.getColoredLine(lineNumber)
  if (not state[lineNumber]) or state[lineNumber].mode == "unparsed" then
    highlighter.recolor(lineNumber)
  end

  return state[lineNumber].colored
end



local function consumeWhitespace(text)
  return (text or ""):match("^(%s*)(.+)") or ""
end

local function insertColor(line, text, color)
  local c = line.colored
  c[#c + 1] = {text, color or 16}
end

local luaParsers = {
  parseIdentifier = function(toParse, curLine)
    local indentifier = toParse:match("^[%l_][%w_]*")
    if indentifier then
      local restToParse = toParse:sub(#indentifier + 1)
      local color = syntaxTheme.catch
      if wordPrims[indentifier] then
        color = syntaxTheme.primitive
      elseif keywords[indentifier] then
        color = syntaxTheme.keyword
      elseif specialVars[indentifier] then
        color = syntaxTheme.specialKeyword
      elseif restToParse:match("^%s-%(") then
        color = syntaxTheme.func
      end

      insertColor(curLine, indentifier, color)
      return restToParse
    end
  end,
  parseComment = function(toParse, curLine)
    if toParse:sub(1, 2) == "--" then
      if toParse:sub(3, 4) == "[[" then
        local _, closingComment = toParse:find("]]")
        if closingComment then
          insertColor(curLine, toParse:sub(1, closingComment), syntaxTheme.comment)
          return toParse:sub(closingComment + 1)
        else
          curLine.mode = "multi-comment"
          insertColor(curLine, toParse, syntaxTheme.comment)
          return ""
        end
      else
        insertColor(curLine, toParse, syntaxTheme.comment)
        return ""
      end
    end
  end,
  parseNumber = function(toParse, curLine)
    local number = toParse:match("^%d*%.?%d*")
    if number and tonumber(number) then
      insertColor(curLine, number, syntaxTheme.primitive)
      return toParse:sub(#number + 1)
    end
  end,
  parseString = function(toParse, curLine)
    local beginner = toParse:match("^[\"']")
    if beginner then
      insertColor(curLine, "\"", syntaxTheme.string)
      toParse = toParse:sub(2)

      repeat
        local nextMatch, endMatch = toParse:find("\\%d+")
        if not nextMatch then
          nextMatch, endMatch = toParse:find("\\.")
        end

        if nextMatch then
          insertColor(curLine, toParse:sub(1, nextMatch - 1), syntaxTheme.string)
          insertColor(curLine, toParse:sub(nextMatch, endMatch), syntaxTheme.stringEscape)
          toParse = toParse:sub(endMatch + 1)
        end
      until not nextMatch

      local strClose = toParse:find(beginner)
      if strClose then
        insertColor(curLine, toParse:sub(1, strClose), syntaxTheme.string)
        return toParse:sub(strClose + 1)
      else
        insertColor(curLine, toParse, syntaxTheme.string)
        return ""
      end
    end

    if toParse:sub(1, 2) == "[[" then
      local _, closingString = toParse:find("]]")
      if closingString then
        insertColor(curLine, toParse:sub(1, closingString), syntaxTheme.string)
        return toParse:sub(closingString + 1)
      else
        curLine.mode = "multi-string"
        insertColor(curLine, toParse, syntaxTheme.string)
        return ""
      end
    end
  end
}

function highlighter.parse(lineNumber)
  local prevLine = state[lineNumber - 1]
  local curLine = state[lineNumber]
  curLine.mode = prevLine.mode

  local toParse = curLine.text

  curLine.colored = {}

  local count = 0
  while #toParse > 0 do
    if curLine.mode == "normal" then
      local space, content = consumeWhitespace()
      if #space > 0 then
        insertColor(curLine, space)
        toParse = content
      end

      repeat -- Really just a loop construct we can 'break' out of as a 'continue' polyfill
        local n
        n = luaParsers.parseIdentifier(toParse, curLine); if n then toParse = n; break end
        n = luaParsers.parseNumber(toParse, curLine);     if n then toParse = n; break end
        n = luaParsers.parseString(toParse, curLine);     if n then toParse = n; break end
        n = luaParsers.parseComment(toParse, curLine);    if n then toParse = n; break end


        insertColor(curLine, toParse:sub(1, 1), syntaxTheme.catch)
        toParse = toParse:sub(2)
      until true
    elseif curLine.mode == "multi-comment" then
      local _, endComment = toParse:find("]]")
      if endComment then
        insertColor(curLine, toParse:sub(1, endComment), syntaxTheme.comment)
        toParse = toParse:sub(endComment + 1)
        curLine.mode = "normal"
      else
        insertColor(curLine, toParse, syntaxTheme.comment)
        toParse = ""
      end
    elseif curLine.mode == "multi-string" then
      local _, endString = toParse:find("]]")
      if endString then
        insertColor(curLine, toParse:sub(1, endString), syntaxTheme.string)
        toParse = toParse:sub(endString + 1)
        curLine.mode = "normal"
      else
        insertColor(curLine, toParse, syntaxTheme.string)
        toParse = ""
      end
    end

    count = count + 1

    if count > 1000 then
      curLine.mode = "normal"
      break
    end
  end
end

return highlighter
