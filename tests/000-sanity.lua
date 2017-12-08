
function f (n)
  return n + 1
end

function g (m, p)
  return m + p
end

print("1..9")
print("ok 1 -")
print("ok", 2, "- list")
print("ok " .. 3 .. " - concatenation")
i = 4
print("ok " .. i .. " - var")
i = i + 1
print("ok " .. i .. " - var incr")
print("ok " .. i+1 .. " - expr")
j = f(i + 1)
print("ok " .. j .. " - call f")
k = g(i, 3)
print("ok " .. k .. " - call g")
local print = print
print("ok 9 - local")
