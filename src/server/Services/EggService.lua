--!strict
local HttpService=game:GetService("HttpService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Rules=require(Shared.Domain.Rules)
local State=require(Shared.Domain.EggState)
local Catalog=require(Shared.Config.EggConfig)
local Config=require(Shared.Config.EconomyConfig)
local World=require(script.Parent.WorldService)
local Eggs={}; Eggs.__index=Eggs
function Eggs.new(gameService) return setmetatable({Game=gameService, Eggs={}, NestEggs={}},Eggs) end
function Eggs:spawn(nest, forced)
    if self.Game.Closing or self.NestEggs[nest.Index] then return nil end
    local id=forced or Rules.roll(Catalog,"Meadow",math.random())
    local def=Catalog[id]; local mutated=math.random()<.04
    local model=World.egg(self.Game.World.Eggs,def,nest.Part.Position+Vector3.new(0,2.2,0),mutated)
    local uid=HttpService:GenerateGUID(false)
    local egg={Uid=uid,Id=id,State="Nest",Owner=nil,LockUntil=0,Transfers=0,Model=model,Nest=nest,
        Mutation=mutated,Event=self.Game.EventActive,Original=nest.Part.Position}
    egg.Prompt=World.prompt(model.PrimaryPart,"Украсть",def.Name.." • "..def.Rarity,1,function(p) self:pickup(p,uid) end)
    World.label(model.PrimaryPart,def.Name.."\n"..def.Rarity,Color3.fromRGB(table.unpack(def.Color)))
    self.Eggs[uid]=egg; self.NestEggs[nest.Index]=uid
    return egg
end
function Eggs:replenish(egg)
    if not egg.Nest or self.NestEggs[egg.Nest.Index]~=egg.Uid then return end
    self.NestEggs[egg.Nest.Index]=nil
    if egg.Nest.Temporary then return end
    local nest=egg.Nest
    task.delay(Config.NestRespawn,function()
        if not self.Game.Closing and not self.NestEggs[nest.Index] then self:spawn(nest) end
    end)
end
function Eggs:pickup(player,uid)
    local s=self.Game.Sessions[player]; local egg=self.Eggs[uid]; local root=self.Game:root(player)
    if not s or not egg or not root or not egg.Model.PrimaryPart or not self.Game:allow(player,"pickup",.3) then return end
    if #s.Profile.OwnedEggs>=Config.MaxStoredEggs then self.Game:notify(player,"Инкубатор полон — вылупи яйца"); return end
    local ok=Rules.pickup(egg,{Alive=true,Carrying=s.Carry~=nil},os.clock(),(root.Position-egg.Model.PrimaryPart.Position).Magnitude)
    if not ok then return end
    if not self.Game:lineOfSight(player,egg.Model.PrimaryPart) then return end
    -- No yielding between validation, state claim and ownership assignment.
    if not State.claim(egg,player.UserId,os.clock()) then return end
    self:replenish(egg)
    s.Carry=uid; s.Started=os.clock(); s.Damage=0; s.Dodges=0; s.LastActive=os.clock(); s.Profile.Tutorial=math.max(s.Profile.Tutorial,1)
    egg.Prompt.Enabled=false
    egg.Model:PivotTo(root.CFrame*CFrame.new(0,.2,-2.6))
    egg.Model.PrimaryPart.Anchored=false
    local weld=Instance.new("WeldConstraint"); weld.Name="CarryWeld"; weld.Part0=root; weld.Part1=egg.Model.PrimaryPart; weld.Parent=egg.Model.PrimaryPart
    egg.Weld=weld
    self.Game.Guardians:alarm(egg.Nest.Index,player)
    self.Game:notify(player,"ЯЙЦО У ТЕБЯ! Вернись на свой зелёный круг","Pickup"); s.Dirty=true
end
function Eggs:drop(player,failed)
    local s=self.Game.Sessions[player]
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local egg=s and s.Carry and self.Eggs[s.Carry]
    if not egg then if s then s.Carry=nil end; return end
    if egg.Owner~=player.UserId or not State.drop(egg,os.clock()) then s.Carry=nil; return end
    s.Carry=nil; s.Sprint=false
    if failed then s.Combo=0; s.ShieldUntil=os.clock()+Config.LossProtection end
    if egg.Weld then egg.Weld:Destroy(); egg.Weld=nil end
    egg.Model.PrimaryPart.Anchored=true
    local pos=if root then root.Position+root.CFrame.LookVector*4 else egg.Original+Vector3.new(0,4,0)
    local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={egg.Model,player.Character or egg.Model}
    local floor=workspace:Raycast(pos+Vector3.new(0,8,0),Vector3.new(0,-40,0),params)
    if floor then pos=Vector3.new(pos.X,floor.Position.Y+2.2,pos.Z) else pos=egg.Original+Vector3.new(0,3,0) end
    egg.Model:PivotTo(CFrame.new(pos)); egg.Expires=os.clock()+Config.DropLifetime
    task.delay(Config.PickupProtection,function()
        if egg.State=="Dropped" and egg.Model.Parent then
            egg.Prompt.ActionText="Поднять"; egg.Prompt.Enabled=egg.Transfers<Config.MaxTransfers
        end
    end)
    self.Game:notify(player,if failed then "Яйцо потеряно. Прогресс коллекции в безопасности." else "Яйцо брошено"); s.Dirty=true
end
function Eggs:deliver(player)
    local s=self.Game.Sessions[player]; local root=self.Game:root(player)
    local egg=s and s.Carry and self.Eggs[s.Carry]
    if not egg or not root or not s.Base or (root.Position-s.Base.Pad.Position).Magnitude>9 then return end
    if #s.Profile.OwnedEggs>=Config.MaxStoredEggs then
        if self.Game:allow(player,"full-incubator",4) then self.Game:notify(player,"Инкубатор полон. Вылупи яйцо, чтобы освободить место.") end
        return
    end
    if not State.deliver(egg,player.UserId) then return end
    local def=Catalog[egg.Id]
    s.Carry=nil; s.Combo+=1
    local elapsed=math.max(0,os.clock()-(s.Started or os.clock()))
    local reward=Rules.reward(def.Value,s.Combo,egg.Mutation,egg.Event)
    self.Game:coins(player,reward); Rules.xp(s.Profile,25)
    table.insert(s.Profile.OwnedEggs,{Uid=egg.Uid,Id=egg.Id,Mutation=egg.Mutation,ReadyAt=0})
    s.Profile.TotalDelivered+=1; s.Profile.BestCombo=math.max(s.Profile.BestCombo,s.Combo)
    if s.Profile.BestEscape==0 or elapsed<s.Profile.BestEscape then s.Profile.BestEscape=math.floor(elapsed*100)/100 end
    Rules.daily(s.Profile,os.time()).Deliveries+=1
    s.Profile.Tutorial=math.max(s.Profile.Tutorial,2)
    s.Profile.Achievements.FirstDelivery=true
    self.Game:notify(player,string.format("ПОБЕГ %s • +%d монет • серия %d",Rules.rating(elapsed,s.Damage,s.Dodges),reward,s.Combo),"Delivery")
    egg.Model:Destroy(); self.Eggs[egg.Uid]=nil; s.LastActive=os.clock(); s.Dirty=true
end
function Eggs:update()
    for uid,egg in pairs(self.Eggs) do
        if egg.State=="Dropped" and os.clock()>egg.Expires then egg.Model:Destroy(); self.Eggs[uid]=nil end
    end
end
return Eggs
