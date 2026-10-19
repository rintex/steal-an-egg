--!strict
local State = {}
function State.claim(egg, userId: number, now: number)
    if egg.State ~= "Nest" and egg.State ~= "Dropped" then return false end
    if now < egg.LockUntil or egg.Transfers >= 3 then return false end
    if egg.State == "Dropped" then egg.Transfers += 1 end
    egg.State = "Carried"; egg.Owner = userId
    return true
end
function State.drop(egg, now: number)
    if egg.State ~= "Carried" then return false end
    egg.State = "Dropped"; egg.Owner = nil; egg.LockUntil = now + 1.5
    return true
end
function State.deliver(egg, userId: number)
    if egg.State ~= "Carried" or egg.Owner ~= userId then return false end
    egg.State = "Delivered"; egg.Owner = nil
    return true
end
return State
