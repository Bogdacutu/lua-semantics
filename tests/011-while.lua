print("1..11")

do
    local a = {}
    local i = 1
    while a[i] do
        i = i + 1
    end
    if i == 1 then
        print("ok 1 - while empty")
    else
        print("not ok 1 - " .. i)
    end
end

do
    local a = {"ok 2 - while ", "ok 3", "ok 4"}
    local i = 1
    while a[i] do
        print(a[i])
        i = i + 1
    end
end

do
    local a = {"ok 5 - with break", "ok 6", "stop", "more"}
    local i = 1
    while a[i] do
        if a[i] == "stop" then break end
        print(a[i])
        i = i + 1
    end
    if i == 3 then
        print("ok 7 - break")
    else
        print("not ok 7 - " .. i)
    end
end

do
    local x = 3
    local i = 1
    while i<=x do
        print("ok " .. 7+i)
        i = i + 1
    end
    if i == 4 then
        print("ok 11")
    else
        print("not ok 11 - " .. i)
    end
end
