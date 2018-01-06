local xmlutils = {}


--[[

TODO:

 - Parse standard XML header

]]

local INVERSE_ESCAPE_MAP = {
    ["\\a"] = "\a", ["\\b"] = "\b", ["\\f"] = "\f", ["\\n"] = "\n", ["\\r"] = "\r",
    ["\\t"] = "\t", ["\\v"] = "\v", ["\\\\"] = "\\",
}

local function consumeWhitespace(wBuffer)
  local nPos = wBuffer:find("%S")
  return wBuffer:sub(nPos or #wBuffer + 1)
end

function xmlutils.parse(buffer)
  local hS = buffer:find("%<%?.+%?%>")
  if hS == 1 then
    local _, hE = buffer:find("%?%>")

    buffer = buffer:sub(hE + 1)
  end

  local tagStack = {children = {}}

  local parsePoint = tagStack

  local ntWhite = buffer:find("%S")

  while ntWhite do
    buffer = buffer:sub(ntWhite)

    local nxtLoc, _, capt = buffer:find("(%<%/?)%s*[a-zA-Z0-9_%:]+")
    if nxtLoc ~= 1 and buffer:sub(1,3) ~= "<![" then
      --Text node probably
      if nxtLoc ~= buffer:find("%<") then
        -- Syntax error
        return error("Unexpected character")
      end

      parsePoint.children[#parsePoint.children + 1] = {type = "text", content = buffer:sub(1, nxtLoc - 1), parent = parsePoint}
      buffer = buffer:sub(nxtLoc)
    elseif nxtLoc == 1 and capt == "</" then
      -- Closing tag
      local _, endC, closingName = buffer:find("%<%/%s*([a-zA-Z0-9%_%-%:]+)")
      if closingName == parsePoint.name then
        -- All good!
        parsePoint = parsePoint.parent
        
        local _, endTagPos = buffer:find("%s*>")
        if not endTagPos then
          -- Improperly terminated terminating tag... how?
          return error("Improperly terminated terminating tag...")
        end

        buffer = buffer:sub(endTagPos + 1)
      else
        -- BAD! Someone forgot to close their tag, gonna be strict and throw
        -- TODO?: Add stack unwind to attempt to still parse?
        return error("Unterminated '" .. tostring(parsePoint.name) .. "' tag")
      end
    else
      -- Proper node

      if buffer:sub(1, 9) == "<![CDATA[" then
        parsePoint.children[#parsePoint.children + 1] = {type = "cdata", parent = parsePoint}

        local ctepos = buffer:find("%]%]%>")
        if not ctepos then
          -- Syntax error
          return error("Unterminated CDATA")
        end

        parsePoint.children[#parsePoint.children].content = buffer:sub(10, ctepos - 1)

        buffer = buffer:sub(ctepos + 3)
      else

        parsePoint.children[#parsePoint.children + 1] = {type = "normal", children = {}, properties = {}, parent = parsePoint}
        parsePoint = parsePoint.children[#parsePoint.children]

        local _, eTp, tagName = buffer:find("%<%s*([a-zA-Z0-9%_%-%:]+)")
        parsePoint.name = tagName

        buffer = buffer:sub(eTp + 1)

        local sp, ep
        repeat
          buffer = consumeWhitespace(buffer)

          local nChar, eChar, propName = buffer:find("([a-zA-Z0-9%_%-%:]+)")
          if nChar == 1 then
            local nextNtWhite = buffer:find("%S", eChar + 1)
            if not nextNtWhite then
              return error("Unexpected EOF")
            end
            buffer = buffer:sub(nextNtWhite)

            buffer = consumeWhitespace(buffer)

            local eqP = buffer:find("%=")
            if eqP ~= 1 then
              return error("Expected '='")
            end

            buffer = buffer:sub(eqP + 1)

            local nextNtWhite, _, propMatch = buffer:find("(%S)")

            if tonumber(propMatch) then
              -- Gon be a num
              local _, endNP, wholeNum = buffer:find("([0-9%.]+)")

              if tonumber(wholeNum) then
                parsePoint.properties[propName] = tonumber(wholeNum)
              else
                return error("Unfinished number")
              end

              buffer = buffer:sub(endNP + 1)
            elseif propMatch == "\"" or propMatch == "'" then
              -- Gon be a string
              
              buffer = buffer:sub(nextNtWhite)

              local terminationPt = buffer:find("[^%\\]%" .. propMatch) + 1

              local buildStr = buffer:sub(2, terminationPt - 1)

              local repPl, _, repMatch = buildStr:find("(%\\.)")
              while repMatch do
                local replS = INVERSE_ESCAPE_MAP[repMatch] or repMatch:sub(2)
                buildStr = buildStr:sub(1, repPl - 1) .. replS .. buildStr:sub(repPl + 2)
                repPl, _, repMatch = buildStr:find("(%\\.)")
              end

              parsePoint.properties[propName] = buildStr

              buffer = buffer:sub(terminationPt + 1)
            else
              return error("Unexpected property, expected number or string")
            end
          end

          sp, ep = buffer:find("%s*%/?>")
          if not sp then
            return error("Unterminated tag")
          end
        until sp == 1

        local selfTerm = buffer:sub(ep - 1, ep - 1)
        if selfTerm == "/" then
          -- Self terminating tag
          parsePoint = parsePoint.parent
        end

        buffer = buffer:sub(ep + 1)
      end
    end

    ntWhite = buffer:find("%S")
  end

  return tagStack
end

local prettyXML
do
  local ESCAPE_MAP = {
    ["\a"] = "\\a", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r",
    ["\t"] = "\\t", ["\v"] = "\\v", ["\\"] = "\\\\",
  }

  local function escape(s)
      s = s:gsub("([%c\\])", ESCAPE_MAP)
      local dq = s:find("\"")
      if dq then
          return s:gsub("\"", "\\\"")
      else
          return s
      end
  end

  local root = false
  prettyXML = function(parsedXML, spPos)
    spPos = spPos or 0

    local amRoot
    if root then
      amRoot = false
    else
      amRoot = true
      root = true
    end

    local str = ""
    local newFlag = false
    for i = 1, #parsedXML.children do
      local elm = parsedXML.children[i]

      if elm.type == "normal" then
        str = str .. (" "):rep(spPos) .. "<" .. elm.name

        for k, v in pairs(elm.properties) do
          str = str .. " " .. k .. "="
          if type(v) == "number" then
            str = str .. v
          else
            str = str .. "\"" .. escape(v) .. "\""
          end
        end

        if elm.children and #elm.children ~= 0 then
          str = str .. ">\n"

          local ret, fl = prettyXML(elm, spPos + 2)
          if fl then
            str = str:sub(1, #str - 1) .. ret
          else
            str = str .. ret
          end

          str = str .. (fl and "" or (" "):rep(spPos)) .. "</" .. elm.name .. ">\n"
        else
          str = str .. "></" .. elm.name .. ">\n"
        end
      elseif elm.type == "cdata" then
        str = str .. (" "):rep(spPos) .. "<![CDATA[" .. elm.content .. "]]>\n"
      elseif elm.type == "text" then
        if #parsedXML.children == 1 then
          str = elm.content
          newFlag = true
        else
          str = str .. (" "):rep(spPos) .. elm.content .. "\n"
        end
      end
    end

    if amRoot then
      root = false
      return str
    else
      return str, newFlag
    end
  end
end

xmlutils.pretty = prettyXML

return xmlutils