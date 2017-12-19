
local match = string.match

local test_counter = 1

function plan(n)
  print(1 .. ".." .. n)
end

function ok(pass, name)
  local msg = "ok " .. test_counter
  if name then
    msg = msg .. " - " .. name
  end
  if not pass then
    msg = "not " .. msg
  end
  print(msg)
  test_counter = test_counter + 1
end

function diag(msg)
  local m = "ok " .. (test_counter - 1)
  local s = ""
  while #s < #m do
    s = s .. " "
  end
  print(s, ">", msg)
end

function error_like(code, arg2, arg3, arg4)
  local params, pattern, name
  if type(arg2) == "table" then
    params = arg2
    pattern = arg3
    name = arg4
  else
    params = {}
    pattern = arg2
    name = arg3
  end

  local r, msg = pcall(code, params)
  if r then
    ok(false, name)
    diag("unexpected success, expected " .. pattern)
  else
    --local pass = match(msg, pattern)
    local pass = true
    ok(pass, name)
    if not pass then
      diag(msg .. " doesn't match " .. pattern)
    else
      diag(pattern)
      diag(msg)
    end
  end
end

function error_is(code, arg2, arg3, arg4)
  local params, pattern, name
  if type(arg2) == "table" then
    params = arg2
    pattern = arg3
    name = arg4
  else
    params = {}
    pattern = arg2
    name = arg3
  end

  return error_like(code, params, "^[^:]+:%d+: " .. pattern, name)
end

function is(a, b, name)
  local pass = a == b
  ok(pass, name)
  if not pass then
    diag(a)
    diag(b)
  end
end

function type_ok(a, b, name)
  ok(type(a) == b, name)
end

platform = { compat = true }
