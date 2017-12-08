print("1..8")

a = {"ok 1", "ok 2", "ok 3"}
print(a[1])
i = 2
print(a[i])
print(a[i+1])
if #a == 3 then
    print("ok 4 - len")
else
    print("not ok 4")
end
if a[7] == nil then
    print("ok 5")
else
    print("not ok 5")
end

t = {a=10, b=100}
if t["a"] == 10 then
    print("ok 6")
else
    print("not ok 6")
end
if t.b == 100 then
    print("ok 7")
else
    print("not ok 7")
end
if t.z == nil then
    print("ok 8")
else
    print("not ok 8")
end
