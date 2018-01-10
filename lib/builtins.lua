
local _coroutineCreate = coroutine.create
local _coroutineResume = coroutine.resume
local coroutineRunning = coroutine.running
local _coroutineStatus = coroutine.status
local error = error
local getmetatable = getmetatable
local next = next
local pcall = pcall
local setmetatable = setmetatable
local stringByte = string.byte
local tostring = tostring
local type = type



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

xpcall = function(f, h, ...)
  return pcall(f, ...)
end



require = function() end

load = function()
  return nil, "[script]:1: cannot evaluate strings"
end



local coroutineCreate = function(f)
  if type(f) ~= "function" then
    error("bad argument #1 to 'create' (function expected, got " .. type(f) .. ")")
  end
  local t = _coroutineCreate(f)
  -- the first yield gets the coroutine ready to take parameters
  _coroutineResume(t)
  return t
end
coroutine.create = coroutineCreate

local coroutineResume = function(t, ...)
  if type(t) ~= "thread" then
    error("bad argument #1 to 'resume' (thread expected)")
  end
  local s = _coroutineStatus(t)
  if s == "suspended" then
    return _coroutineResume(t, ...)
  else
    return false, "cannot resume " .. s .. " coroutine"
  end
end
coroutine.resume = coroutineResume

local coroutineStatus = function(t)
  if type(t) ~= "thread" then
    error("bad argument #1 to 'status' (thread expected)")
  end
  return _coroutineStatus(t)
end
coroutine.status = coroutineStatus

coroutine.wrap = function(f)
  if type(f) ~= "function" then
    error("bad argument #1 to 'wrap' (function expected, got " .. type(f) .. ")")
  end
  local t = coroutineCreate(f)
  local ret = function(r, ...)
    if r then
      return ...
    else
      error(...)
    end
  end
  return function(...)
    return ret(_coroutineResume(t, ...))
  end
end

coroutine.isyieldable = function()
  local t, main = coroutineRunning()
  return not main
end



math.pi = 3.141592653589793

math.huge = 1 / 0

math.maxinteger = ~0 >> 1

math.mininteger = ~math.maxinteger

math.abs = function (x)
  if x < 0 then
    return -x
  else
    return x
  end
end



string.byte = function(s, i, j)
  i = i or 1
  if i <= 0 then
    i = #s + i + 1
  end
  j = j or i
  return stringByte(s, i, j)
end

string.len = function(s)
  return #s
end

string.rep = function(s, n)
  local r = ""
  while n > 0 do
    r = r .. s
    n = n - 1
  end
  return r
end



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
    s = tostring(t[i])
  end
  while i < j do
    i = i + 1
    s = s .. sep .. tostring(t[i])
  end
  return s
end
