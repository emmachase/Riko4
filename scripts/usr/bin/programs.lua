--HELP: \b6Usage: \b16programs \n
-- \b6Description: \b7Lists readily acessible programs

local tbl = {}

for i = 1, #shell.config.path do
  if shell.config.path[i] ~= "." then
    local dir = fs.list(shell.config.path[i]) or ""
    for j = 1, #dir do
      local name = dir[j]
      if name:sub(1, 1) ~= "." then
        local ctp = name:find("%.")
        if ctp then name = name:sub(1, ctp - 1) end
        tbl[#tbl + 1] = name
      end
    end
  end
end

local tabular = {12, tbl}

shell.tabulate(unpack(tabular))

print()
