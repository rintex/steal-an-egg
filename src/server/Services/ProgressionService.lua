--!strict
local Shared=game:GetService("ReplicatedStorage").Shared
local Rules=require(Shared.Domain.Rules)
local Incubation=require(Shared.Domain.Incubation)
local Catalog=require(Shared.Config.EggConfig)
local Upgrades=require(Shared.Config.UpgradeConfig)
local Config=require(Shared.Config.EconomyConfig)
local World=require(script.Parent.WorldService)
local Progression={}; Progression.__index=Progression
function Progression.new(gameService) return setmetatable({Game=gameService},Progression) end
function Progression:hatch(player,uid)
    local s=self.Game.Sessions[player]; local root=self.Game:root(player)
    if not s or not root or not s.Base or (root.Position-s.Base.Incubator.Position).Magnitude>13 then
        self.Game:notify(player,"Подойди к своему инкубатору"); return
    end
    if not self.Game:lineOfSight(player,s.Base.Incubator) then
        self.Game:notify(player,"Подойди к инкубатору со стороны входа"); return
    end
    if #s.Profile.Pets>=Config.MaxPets then
        self.Game:notify(player,"Коллекция питомцев заполнена. Яйцо сохранено."); return
    end
    if Incubation.start(s.Profile,uid,os.time(),Catalog) then
        self.Game:notify(player,"Инкубация началась! Можно искать следующее яйцо.")
        s.Dirty=true
        s.LastActive=os.clock()
    else
        for _,egg in ipairs(s.Profile.OwnedEggs) do
            if egg.Uid==uid and egg.ReadyAt>0 then
                self.Game:notify(player,"Яйцо уже в инкубаторе — осталось "..math.max(0,egg.ReadyAt-os.time()).." сек."); return
            end
        end
    end
end
function Progression:firstEgg(player)
    local s=self.Game.Sessions[player]; if not s then return end
    for _,egg in ipairs(s.Profile.OwnedEggs) do
        if egg.ReadyAt==0 then self:hatch(player,egg.Uid); return end
    end
    self.Game:notify(player,if #s.Profile.OwnedEggs>0 then "Все яйца уже в инкубаторе. Можно искать следующее!" else "Принеси яйцо на свой круг доставки")
end
function Progression:display(player)
    local s=self.Game.Sessions[player]; if not s or not s.Base then return end
    if s.PetModel then s.PetModel:Destroy(); s.PetModel=nil end
    local pet=s.Profile.Pets[1]
    if not pet then return end
    local def=Catalog[pet.EggId]
    local model=Instance.new("Model"); model.Name="Pet_"..pet.Id; model.Parent=s.Base.Model
    local pos=s.Base.Display.Position+Vector3.new(0,2,0)
    local body=World.part(model,"Pet",Vector3.new(3,2.7,3),CFrame.new(pos),Color3.fromRGB(table.unpack(def.Color)),nil,Enum.PartType.Ball)
    for _,x in ipairs({-1,1}) do
        World.part(model,"Ear",Vector3.new(.9,1.9,.8),CFrame.new(pos+Vector3.new(x*.85,1.5,0))*CFrame.Angles(0,0,x*-.2),body.Color,nil,Enum.PartType.Ball)
        World.part(model,"Eye",Vector3.new(.35,.45,.2),CFrame.new(pos+Vector3.new(x*.65,.2,-1.4)),Color3.fromRGB(45,53,66),nil,Enum.PartType.Ball)
    end
    World.label(body,def.PetName.."\nАктивный питомец: +1 восстановление")
    s.PetModel=model
end
function Progression:buy(player,id)
    local s=self.Game.Sessions[player]; if not s then return end
    local ok,message=Rules.buy(s.Profile,id,Upgrades)
    if ok then
        s.Dirty=true
        s.LastActive=os.clock()
        if s.Base then
            s.Base.Ward.Size=Vector3.new(2,3+s.Profile.Upgrades.Ward*.7,2)
            s.Base.Incubator.Color=Color3.fromRGB(255,205,124):Lerp(Color3.fromRGB(255,246,207),s.Profile.Upgrades.Incubator/4)
        end
    end
    self.Game:notify(player,message)
end
function Progression:claim(player)
    local s=self.Game.Sessions[player]; if not s then return end
    local previousDay=s.Profile.QuestProgress.Day
    local q=Rules.daily(s.Profile,os.time())
    if previousDay~=q.Day then s.Dirty=true end
    if q.Claimed or q.Deliveries<Config.DailyDeliveryGoal or q.Hatches<Config.DailyHatchGoal then
        self.Game:notify(player,"Выполни обе ежедневные цели"); return
    end
    q.Claimed=true; self.Game:coins(player,Config.DailyReward); Rules.xp(s.Profile,50)
    self.Game:notify(player,"Ежедневная награда: +"..Config.DailyReward.." монет"); s.LastActive=os.clock(); s.Dirty=true
end
function Progression:update(player)
    local s=self.Game.Sessions[player]; if not s or not self.Game.Data:isActive(player) then return end
    local oldDay=s.Profile.QuestProgress.Day; Rules.daily(s.Profile,os.time())
    if oldDay~=s.Profile.QuestProgress.Day then s.Dirty=true end
    for _,egg in ipairs(Incubation.finish(s.Profile,os.time(),Config.MaxPets)) do
        s.Profile.QuestProgress.Hatches+=1; s.Profile.Tutorial=3; Rules.xp(s.Profile,20)
        local first=not s.Profile.Achievements[egg.Id]
        if first then s.Profile.Achievements[egg.Id]=true; self.Game:coins(player,15) end
        self.Game:notify(player,"ВЫЛУПИЛСЯ: "..Catalog[egg.Id].PetName,"Hatch")
        self.Game.Remotes.Effect:FireClient(player,"Hatch",egg.Id)
        self:display(player); s.Dirty=true
    end
    if os.clock()>=s.PassiveAt then
        s.PassiveAt=os.clock()+Config.PassiveInterval
        if #s.Profile.Pets>0 and os.clock()-s.LastActive<90 then
            self.Game:coins(player,math.min(Config.PassiveCap,#s.Profile.Pets*2)); s.Dirty=true
        end
    end
end
return Progression
