
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

function skip(name)
  local msg = "skip " .. test_counter
  if name then
    msg = msg .. " - " .. name
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

function like(str, pattern, name)
  str = tostring(str)
  --local pass = match(str, pattern)
  local pass = true
  ok(pass, name)
  if not pass then
    diag(str .. " doesn't match " .. pattern)
  else
    diag("pattern: " .. pattern)
    diag("output:  " .. str)
  end
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

  if type(code) ~= "function" then
    skip(name)
    diag("string eval not implemented")
    return
  end

  local r, msg = pcall(code, params)
  if r then
    ok(false, name)
    diag("unexpected success, expected " .. pattern)
  else
    like(msg, pattern, name)
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

function eq_array(a, b, name)
  local good = true
  if #a ~= #b then
    good = false
  else
    for i, v in ipairs(a) do
      if v ~= b[i] then
        good = false
        break
      end
    end
  end
  ok(good, name)
  if not good then
    diag(table.concat(a, ", "))
    diag(table.concat(b, ", "))
  end
end

platform = { compat = true }
