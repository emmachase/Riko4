local funcs = {
  {fs, "open"},
  {fs, "list"},
  {fs, "getAttr"},
  {fs, "delete"}
}

-- This bit isn't technically needed as the sandbox is also
-- enforced by the low level C functions, but it provides
-- a nicer error, so why not

-- local function checkBounds(path)
--   local level = 0
--   for word in path:gmatch("[^%/^%\\]+") do
--     if word == ".." then
--       level = level - 1
--       if level < 0 then
--         return false
--       end
--     else
--       level = level + 1
--     end
--   end
--   return true
-- end

-- for i=1, #funcs do
--   local ref = funcs[i][1][funcs[i][2]]

--   funcs[i][1][funcs[i][2]] = function(fn, ...)
--     if fn:sub(1, 1) == "/" then
--       fn = fn:sub(2)
--     end
--     fn = "home/" .. fn

--     if checkBounds(tostring(fn)) then
--       return ref(fn, ...)
--     else
--       error("Attempt to leave sandbox", 2)
--     end
--   end
-- end

fs.setCWD("/home/")