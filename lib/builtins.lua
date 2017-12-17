
local next = next

local iter = function(a, i)
  i = i + 1
  local v = a[i]
  if v then
    return i, v
  end
end

ipairs = function(a)
  return iter, a, 0
end

pairs = function(a)
  return next, a, nil
end

require = function() end
