--!strict
local Profile = {}
local function copy(value: any): any
    if type(value) ~= "table" then return value end
    local result = {}
    for k,v in pairs(value) do result[k] = copy(v) end
    return result
end
Profile.copy = copy
local function integer(v, minimum, maximum)
    return type(v)=="number" and v==v and v>=minimum and v<=maximum and v%1==0
end
-- Dynamic input is validated field by field before becoming an in-memory profile.
function Profile.validate(data: any, catalog: any)
    if type(data)~="table" or data.Version~=1 then return false end
    if not integer(data.Coins,0,10000000) or not integer(data.Level,1,1000000)
        or not integer(data.XP,0,100000000) or not integer(data.TotalDelivered,0,100000000)
        or not integer(data.BestCombo,0,100000000) or not integer(data.Tutorial,0,3) then return false end
    if type(data.BestEscape)~="number" or data.BestEscape~=data.BestEscape or data.BestEscape<0 or data.BestEscape>10000000 then return false end
    for _, key in ipairs({"OwnedEggs", "Pets", "Upgrades", "QuestProgress", "Settings", "Achievements", "UnlockedBiomes", "Inventory"}) do
        if type(data[key]) ~= "table" then return false end
    end
    if #data.OwnedEggs>12 or #data.Pets>100 then return false end
    for key,max in pairs({Speed=4,Stamina=4,Dash=3,Incubator=4,Ward=3}) do
        if not integer(data.Upgrades[key],0,max) then return false end
    end
    local q=data.QuestProgress
    if not integer(q.Day,0,10000000) or not integer(q.Deliveries,0,100000000)
        or not integer(q.Hatches,0,100000000) or type(q.Claimed)~="boolean" then return false end
    if type(data.Settings.LowFX)~="boolean" or type(data.Settings.Muted)~="boolean" then return false end
    local ids = {}
    for _, list in ipairs({data.OwnedEggs, data.Pets}) do
        for _, item in ipairs(list) do
            if type(item)~="table" or type(item.Uid)~="string" or #item.Uid==0 or #item.Uid>64 or ids[item.Uid] then return false end
            ids[item.Uid] = true
            if type(item.Id)~="string" or type(item.Mutation)~="boolean" then return false end
        end
    end
    for _,egg in ipairs(data.OwnedEggs) do
        if not integer(egg.ReadyAt,0,100000000000) or (catalog and not catalog[egg.Id]) then return false end
    end
    for _,pet in ipairs(data.Pets) do
        if type(pet.EggId)~="string" or pet.Id~=pet.EggId.."_pet" or (catalog and not catalog[pet.EggId]) then return false end
    end
    return true
end
return Profile
