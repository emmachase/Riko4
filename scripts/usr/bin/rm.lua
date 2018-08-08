--HELP: \b6Usage: \b16rm \b7[\b16option\b7]... <\b16file\b7>... \n
-- \b6Description: \b7Deletes \b16file\b7(s)

local getopt = require("getopt")

local args = {...}

local recurse = false
local emptyDirs = false

local operands = {}

getopt(args, "-rd", {
  recurse   = {hasArg = getopt.noArgument, val = "r"},
  directory = {hasArg = getopt.noArgument, val = "d"}
}) {
  [1] = function(val) -- non-option
    operands[#operands + 1] = val
  end,
  r = function()
    recurse = true
  end,
  d = function()
    emptyDirs = true
  end
}

if #operands == 0 then
  print("Missing operand", 8)
  print("Try 'help rm' for more information", 8)
  return print()
end

local function isDirEmpty(path)
  local listing = fs.list(path)
  for i = 1, #listing do
    local item = listing[i]
    if item ~= "." and item ~= ".." then
      return false
    end
  end

  return true
end

local function performDelete(path)
  if not fs.exists(path) then
    return print(("Cannot remove '%s': No such file or directory"):format(path), 8)
  end

  if fs.isDir(path) then
    if recurse then
      if isDirEmpty(path) then
        fs.delete(path)
      else
        for k, v in ipairs(fs.list(path)) do
          if v ~= "." and v ~= ".." then
            local subpath = fs.combine(path, v)
            if fs.isDir(subpath) then
              performDelete(subpath)
            end

            fs.delete(subpath)
          end
        end

        fs.delete(path)
      end
    elseif emptyDirs then
      if isDirEmpty(path) then
        fs.delete(path)
      else
        return print(("Cannot remove '%s': Directory not empty"):format(path), 8)
      end
    else
      return print(("Cannot remove '%s': Is a directory"):format(path), 8)
    end
  else
    fs.delete(path)
  end
end

for i = 1, #operands do
  performDelete(operands[i])
end
