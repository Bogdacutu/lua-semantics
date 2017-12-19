
local next = next
local getmetatable = getmetatable
local setmetatable = setmetatable
local tostring = tostring

setmetatable("", {
  __index = string
})

_G.setmetatable = function(t, mt)
  if mt ~= nil and type(mt) ~= "table" then
    error("bad argument #2 to 'setmetatable' (nil or table expected)")
  end
  if mt ~= nil and type(mt) ~= "table" then
    error("bad argument #1 to 'setmetatable' (table expected)")
  end
  return setmetatable(t, mt)
end

local iter = function(a, i)
  if i == nil then
    i = 1
  else
    i = i + 1
  end
  local v = a[i]
  if v then
    return i, v
  end
end

local ipairs = function(a)
  local mt = getmetatable(a)
  if mt ~= nil then
    local f = mt.__ipairs
    if f ~= nil then
      return f(a)
    end
  end
  return iter, a, 0
end
_G.ipairs = ipairs

local pairs = function(a)
  local mt = getmetatable(a)
  if mt ~= nil then
    local f = mt.__pairs
    if f ~= nil then
      return f(a)
    end
  end
  return next, a
end
_G.pairs = pairs

require = function() end

table.sort = function(t, cmp)
  if cmp == nil then
    cmp = function(a, b)
      return a < b
    end
  end

  local n, swapped = #t
  repeat
    swapped = false
    for i = 1, n - 1 do
      if cmp(t[i + 1], t[i]) then
        t[i], t[i + 1] = t[i + 1], t[i]
        swapped = true
      end
    end
    n = n - 1
  until not swapped
end

table.concat = function(t, sep, i, j)
  if sep == nil then
    sep = ""
  end
  if i == nil then
    i = 1
  end
  if j == nil then
    j = #t
    if type(j) ~= "number" then
      error("object length is not a number")
    end
  end
  local s = ""
  if i <= j then
    s = t[i]
  end
  while i < j do
    i = i + 1
    s = s .. sep .. t[i]
  end
  return s
end
