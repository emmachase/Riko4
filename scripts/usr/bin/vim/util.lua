return function(context)
  local util = {}

  function util.padStr(str, n, blank)
    local inner = str:sub(math.max(1, #str - n + 1), #str)

    return inner .. (blank or " "):rep(n - #inner)
  end

  return util
end
