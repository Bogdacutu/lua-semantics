
print("1..6")

if true then
    print("ok 1")
else
    print("not ok 1")
end

if not true then
    print("not ok 2")
else
    print("ok 2")
end

a = 12
b = 34
if a < b then
    print("ok 3")
else
    print("not ok 3")
end

a = 0
b = 4
if a < b then
    print("ok 4")
elseif a == b then
    print("not ok 4")
else
    print("not ok 4")
end

a = 5
b = 5
if a < b then
    print("not ok 5")
elseif a == b then
    print("ok 5")
else
    print("not ok 5")
end

a = 10
b = 6
if a < b then
    print("not ok 6")
elseif a == b then
    print("not ok 6")
else
    print("ok 6")
end
