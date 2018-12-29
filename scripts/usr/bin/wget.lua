--HELP: \b6Usage: \b16wget \b7<\b16url\b7>... [\b16-o file\b7]... \n
-- \b6Description: \b7Downloads data from \b16url\b7 to \b16file\b7.

local fontWidth = gpu.font.data.w + 1
local scrnWidth = math.floor(gpu.width / fontWidth)

local getopt = require("getopt")
local args = {...}
local fileNames = {}
local parseInstance = getopt(args, "o:", {
}) {
  o = function(arg)
    fileNames[#fileNames + 1] = arg
  end
}
if #parseInstance.notOptions < 1 then
  print("Missing operand", 8)
  print("Try 'help wget' for more information", 8)
  return
end

for i = 1, #parseInstance.notOptions do
  local url, file = parseInstance.notOptions[i], fileNames[i]
  if not file then
    file = url:sub(#fs.getBaseDir(url) + 2)
  end

  shell.write(("Fetching url " .. url):sub(1, scrnWidth - 4) .. "...")

  local response

  local pX, pY = shell.term.x, shell.term.y
  local dX, dY = 1, pY + 1

  net.request(url)

  local function overwrite(str, newStr, pos)
    return str:sub(1, pos - 1) .. newStr .. str:sub(pos + #newStr)
  end

  local amtGot, amtToGet = 0, 0
  local last = os.clock()
  local barPos, barDir, barSpeed = 0, 1, 20
  local function drawStatus()
    local dt = os.clock() - last
    barPos = barPos + barDir * dt * barSpeed

    local base = (" "):rep(scrnWidth)

    local dispName = file
    local maxWidth = math.min(scrnWidth / 4, 50)
    if #file > maxWidth then
      dispName = file:sub(1, maxWidth - 3) .. ".."
    end

    base = overwrite(base, dispName, 1)


    local statusLen
    if amtToGet > 0 then
      -- Progress
      statusLen = #tostring(amtToGet) * 2 + 5

      base = overwrite(base, "[" .. amtGot .. " / " .. amtToGet .. "]", scrnWidth - statusLen + 1)
    else
      -- Indeterminate
      statusLen = #tostring(amtGot) + 2

      base = overwrite(base, "[" .. amtGot .. "]", scrnWidth - statusLen + 1)
    end

    local barLen = (3 * scrnWidth / 4) - statusLen - 1
    if barPos < 0 then
      barPos = 0
      barDir = 1
    elseif barPos > barLen - 7 then
      barPos = barLen - 7
      barDir = -1
    end

    base = overwrite(base, "[" .. (" "):rep(barLen - 2) .. "]", scrnWidth / 4 + 1)
    if amtToGet > 0 then
      -- Progress
      local pct = amtGot / amtToGet
      base = overwrite(base, ("="):rep(pct * (barLen - 2) - 1) .. ">", scrnWidth / 4 + 2)
    else
      -- Indeterminate
      base = overwrite(base, "<===>", scrnWidth / 4 + barPos + 2)
    end

    shell.write(base, 16, 1, dX, dY)
    last = os.clock()
  end

  local running = true
  while running do
    shell.pumpEvents(function(e, eUrl, handle, p2)
      if e == "netSuccess" and eUrl == url then
        response = handle
        running = false
        return
      elseif e == "netFailure" and eUrl == url then
        running = false
        return
      elseif e == "netProgress" and eUrl == url then
        amtGot, amtToGet = handle, p2
      elseif e == "mouseMoved" then
        shell.updateMouse(eUrl, handle)
      end
    end)

    drawStatus()
    shell.draw()
  end

  if not response then
    shell.write(" Failed.\n", 8, 1, pX, pY)
    return
  end
  local data = response:readAll()

  local handle = fs.open(file, "wb")
  handle:write(data)
  handle:close()

  shell.write("\nWrote to " .. file .. "\n", 12, 1, 1, pY + 2)
end
