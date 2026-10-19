--!strict
-- Pure authoritative rules. No Roblox services or client-provided prices/rewards.
local Rules = {}
function Rules.cost(base: number, level: number): number
    return math.floor(base * 1.7 ^ level)
end
function Rules.day(now: number): number return math.floor(now / 86400) end
function Rules.roll(catalog, biome: string, unit: number)
    local ids = {}
    for id, egg in pairs(catalog) do if egg.Biome == biome then table.insert(ids, id) end end
    table.sort(ids)
    local sum = 0
    for _, id in ipairs(ids) do sum += catalog[id].SpawnWeight end
    local cursor = math.clamp(unit, 0, 0.9999999) * sum
    for _, id in ipairs(ids) do
        cursor -= catalog[id].SpawnWeight
        if cursor < 0 then return id end
    end
    return ids[#ids]
end
function Rules.pickup(egg, player, now: number, distance: number)
    if distance~=distance or distance<0 or distance==math.huge or now~=now then return false, "Неверная позиция" end
    if not player.Alive or player.Carrying then return false, "Руки заняты" end
    if egg.State ~= "Nest" and egg.State ~= "Dropped" then return false, "Яйцо уже забрали" end
    if distance > 11 then return false, "Подойди ближе" end
    if now < egg.LockUntil then return false, "Подожди секунду" end
    if egg.Transfers >= 3 then return false, "Скорлупе нужен отдых" end
    return true, ""
end
function Rules.canIntercept(attacker, victim, now: number, distance: number)
    return attacker.Alive and victim.Alive and not attacker.Carrying and victim.Carrying
        and not attacker.Safe and not victim.Safe and not attacker.Protected and not victim.Protected
        and now >= attacker.InterceptAt and now >= victim.ShieldUntil and distance <= 7
end
function Rules.reward(value: number, combo: number, mutation: boolean, event: boolean): number
    return math.floor(value * (1 + math.min(combo, 5) * 0.05) * (if mutation then 1.1 else 1) * (if event then 1.25 else 1))
end
function Rules.rating(seconds: number, damage: number, dodges: number): string
    local score = 100 - seconds * 0.9 - damage * 0.7 + math.min(dodges, 3) * 4
    return if score >= 85 then "S+" elseif score >= 72 then "S" elseif score >= 55 then "A" elseif score >= 35 then "B" else "C"
end
function Rules.buy(profile, id: string, config)
    local def = config[id]
    if not def then return false, "Неизвестное улучшение" end
    local level = profile.Upgrades[id] or 0
    if level >= def.Max then return false, "Максимальный уровень" end
    local cost = Rules.cost(def.BaseCost, level)
    if profile.Coins < cost then return false, "Не хватает монет" end
    profile.Coins -= cost
    profile.Upgrades[id] = level + 1
    return true, "Улучшение куплено"
end
function Rules.newProfile(now: number)
    return {Version=1, Coins=0, XP=0, Level=1, UnlockedBiomes={Meadow=true}, OwnedEggs={}, Pets={},
        Upgrades={Speed=0, Stamina=0, Dash=0, Incubator=0, Ward=0}, Inventory={}, Achievements={},
        QuestProgress={Day=Rules.day(now), Deliveries=0, Hatches=0, Claimed=false},
        Settings={LowFX=false, Muted=false}, TotalDelivered=0, BestCombo=0, BestEscape=0, Tutorial=0}
end
function Rules.daily(profile, now: number)
    if profile.QuestProgress.Day ~= Rules.day(now) then
        profile.QuestProgress = {Day=Rules.day(now), Deliveries=0, Hatches=0, Claimed=false}
    end
    return profile.QuestProgress
end
function Rules.xp(profile: {XP:number, Level:number}, amount: number)
    profile.XP += amount
    while profile.XP >= profile.Level * 100 do
        profile.XP -= profile.Level * 100
        profile.Level += 1
    end
end
return Rules
