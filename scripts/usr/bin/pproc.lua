--HELP: \b6Usage: \b16pproc \b7<\b16input\b7> [\b16outfile\b7] \n
-- \b6Description: \b7Preprocesses \b16input\b7, writing \b7to \b17outfile \b7or \b16input \b7plus \b16.lua

local args = {...}

if not args[1] then
  if shell then
    local prog = shell.getRunningProgram()
    shell.writeOutputC("Syntax: " .. (prog or "pproc") .. " <input> [outfile]\n", 8)
    return
  else
    error("Syntax: pproc <input> [outfile]")
  end
end

local fn = args[1]

local handle = fs.open(fn, "r")
local data = handle:read("*all") .. "\n"
handle:close()

local function trimS(s)
  return s:match("%s*(.+)")
end

local function sw(str, swr)
  return str:sub(1, #swr) == swr
end

local final = ""

local scope = {}

local multiline = false
local i = 0
for line in data:gmatch("([^\n]*)\n") do
  i = i + 1
  if multiline then
    local endS = line:find("]]")
    if endS then
      final = final .. line:sub(1, endS + 1)
      line = line:sub(endS + 2)
      multiline = false
    else
      final = final .. line .. "\n"
      line = ""
    end
  else
    local trim = trimS(line) or ""
    if trim:sub(1, 1) == "#" then
      -- Preprocessor instruction
      local inst = trimS(trim:sub(2))

      if sw(inst, "define") then
        local command = trimS(inst:sub(7))
        local name = command:match("%S+")
        local rest = command:sub(#name + 2)

        scope[#scope + 1] = {name, rest}
      elseif sw(inst, "undef") then
        local command = trimS(inst:sub(6))
        local name = command:match("%S+")

        for i = 1, #scope do
          if scope[i][1] == name then
            table.remove(scope, i)
            break
          end
        end
      else
        shell.writeOutputC("Preprocessor parse error: (Line " .. i .. ")\nUnknown instruction `" .. inst:match("%S+") .. "'\n", 8)
      end
    else
      local lineP = ""

      while #line > 0 do
        local c = line:sub(1, 1); line = line:sub(2)
        local p = line:sub(1, 1)

        if c == "\"" or c == "'" then
          lineP = lineP .. c

          local escaping = false
          for char in line:gmatch(".") do
            lineP = lineP .. char
            line = line:sub(2)
            if char == c and not escaping then  
              break
            elseif char == "\\" then
              escaping = true
            else
              escaping = false
            end
          end
        elseif c == "[" and p == "[" then
          multiline = true

          local endS = line:find("]]")
          if endS then
            lineP = lineP .. line:sub(1, endS + 1)
            line = line:sub(endS + 2)
            multiline = false
          else
            lineP = lineP .. c .. line
            line = ""
          end
        else
          local nextS = line:find("[\"']")
          local nextM = line:find("%[%[")
          local next = math.min(nextS or #line + 1, nextM or #line + 1)

          local safe = c .. line:sub(1, next - 1)

          while #safe > 0 do
            local nextPKW, endPKW, Pstr = safe:find("([%a_][%w_]*)")
            if nextPKW then
              lineP = lineP .. safe:sub(1, nextPKW - 1)
              safe = safe:sub(endPKW + 1)
              
              local found = false
              for i = 1, #scope do
                if scope[i][1] == Pstr then
                  lineP = lineP .. scope[i][2]
                  found = true
                  break
                end
              end

              if not found then
                lineP = lineP .. Pstr
              end
            else
              lineP = lineP .. safe
              safe = ""
            end
          end

          line = line:sub(next)
        end
      end

      final = final .. lineP .. "\n"

      -- for i = 1, #scope do
      --   if scope[i][1] == name then
      --     table.remove(scope, i)
      --     break
      --   end
      -- end
    end
  end
end

-- print("BEGIN\n" .. final .. "\nEND")
local outFN = args[2] or (args[1] .. ".lua")
local outHandle = fs.open(outFN, "w")
outHandle:write(final)
outHandle:close()
