--!strict
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage").Shared
local Rules=require(Shared.Domain.Rules)
local Catalog=require(Shared.Config.EggConfig)
local Config=require(Shared.Config.EconomyConfig)
local World=require(script.Parent.WorldService)
local Game={}; Game.__index=Game
local ACTION_INTERVALS={Ready=.5,Sprint=.05,Dash=.15,Drop=.3,Intercept=.3,Buy=.2,Hatch=.2,Quest=.5,Equip=.2,Setting=.2}
function Game.new(remotes,data)
    local self=setmetatable({Remotes=remotes,Data=data,Sessions={},Joining={},Removing={},Closing=false,Slots={},EventActive=false},Game)
    self.World=World.build()
    self.Guardians=require(script.Parent.GuardianService).new(self)
    self.Eggs=require(script.Parent.EggService).new(self)
    self.Progression=require(script.Parent.ProgressionService).new(self)
    self.Movement=require(script.Parent.MovementService).new(self)
    for _,nest in ipairs(self.World.Nests) do self.Guardians:add(nest); self.Eggs:spawn(nest,if nest.Index==1 then "clover" else nil) end
    self.Events=require(script.Parent.EventService).new(self)
    World.prompt(self.World.Secret,"Исследовать","Тропа тихих шагов",.6,function(player)
        local s=self.Sessions[player]; local root=self:root(player)
        if s and root and (root.Position-self.World.Secret.Position).Magnitude<12 and not s.Profile.Achievements.SecretRoute then
            s.Profile.Achievements.SecretRoute=true; self:coins(player,40); Rules.xp(s.Profile,30); s.Dirty=true
            self:notify(player,"СЕКРЕТ НАЙДЕН! +40 монет")
        end
    end)
    return self
end
function Game:root(player)
    if self.Sessions[player] and not self.Data:isActive(player) then return nil end
    local c=player.Character; local h=c and c:FindFirstChildOfClass("Humanoid")
    if not h or h.Health<=0 then return nil end
    return c:FindFirstChild("HumanoidRootPart")
end
function Game:isSafe(pos) return pos.Z<94 end
function Game:allow(player,key,interval)
    local s=self.Sessions[player]; if not s then return false end
    if self.Closing or not self.Data:isActive(player) then return false end
    local now=os.clock()
    if now<s.InvalidAt+1 then return false end
    if now<(s.Limits[key] or 0) then return false end
    s.Limits[key]=now+interval
    return true
end
function Game:lineOfSight(player,part)
    local root=self:root(player); if not root then return false end
    local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={player.Character}
    local ray=workspace:Raycast(root.Position,part.Position-root.Position,params)
    -- A shared Folder contains other walls and buildings; those cannot count as
    -- a clear hit on the target. Only the target's own Model may be accepted.
    return ray==nil or ray.Instance==part or (part.Parent:IsA("Model") and ray.Instance:IsDescendantOf(part.Parent))
end
function Game:notify(player,text,sound)
    if player.Parent==Players then self.Remotes.Notice:FireClient(player,text,sound) end
end
function Game:coins(player,amount)
    local s=self.Sessions[player]; if not s then return end
    s.Profile.Coins=math.min(Config.MaxCoins,s.Profile.Coins+math.max(0,math.floor(amount))); s.Dirty=true
end
function Game:hit(player,damage)
    local s=self.Sessions[player]; local root=self:root(player)
    if not s or not root or self:isSafe(root.Position) then return end
    local hum=player.Character:FindFirstChildOfClass("Humanoid")
    s.Damage+=damage; hum:TakeDamage(damage)
    self.Eggs:drop(player,true)
end
function Game:intercept(player)
    local s=self.Sessions[player]; local root=self:root(player)
    if not s or not root or not self:allow(player,"intercept",1) then return end
    local now=os.clock()
    for victim,other in pairs(self.Sessions) do
        local r=self:root(victim)
        if r and victim~=player and Rules.canIntercept(
            {Alive=true,Carrying=s.Carry~=nil,Safe=self:isSafe(root.Position),Protected=now<s.Joined+Config.NewPlayerProtection,InterceptAt=s.InterceptAt},
            {Alive=true,Carrying=other.Carry~=nil,Safe=self:isSafe(r.Position),Protected=now<other.Joined+Config.NewPlayerProtection,ShieldUntil=other.ShieldUntil},now,(root.Position-r.Position).Magnitude)
            and self:lineOfSight(player,r) then
            local uid=other.Carry; local egg=self.Eggs.Eggs[uid]
            if egg and egg.Transfers<Config.MaxTransfers then
                self.Eggs:drop(victim,true)
                s.InterceptAt=now+12
                self:notify(player,"Перехват! Яйцо можно поднять через секунду.")
                return
            end
        end
    end
    self:notify(player,"Перехват: нужен незащищённый носитель рядом вне хаба")
end
function Game:character(player,character)
    local s=self.Sessions[player]; if not s then return end
    local hum=character:WaitForChild("Humanoid",10); local root=character:WaitForChild("HumanoidRootPart",10)
    if not hum or not root or self.Sessions[player]~=s or player.Character~=character then return end
    self.Eggs:drop(player,true)
    s.Character=character; s.LastPosition=root.Position; s.AirSince=nil; s.GroundedPosition=root.Position
    s.SpawnGrace=os.clock()+3; s.MoveBudget=10; s.Stamina=Config.BaseStamina+s.Profile.Upgrades.Stamina*12; s.Sprint=false
    s.MovementStrikes=0; s.InvalidAt=-100
    if s.DeathConnection then s.DeathConnection:Disconnect() end
    s.DeathConnection=hum.Died:Connect(function()
        if self.Sessions[player]==s and s.Character==character then self.Eggs:drop(player,true); s.Sprint=false end
    end)
end
function Game:add(player)
    if self.Closing or self.Sessions[player] or self.Joining[player] or self.Removing[player] then return end
    self.Joining[player]=true
    local profile=self.Data:load(player)
    self.Joining[player]=nil
    if not profile then player:Kick("Данные недоступны или открыты на другом сервере. Повтори вход позже."); return end
    if player.Parent~=Players or self.Closing then self.Data:save(player,true); return end
    local slot
    for i=1,8 do if not self.Slots[i] then slot=i; break end end
    if not slot then self.Data:save(player,true); player:Kick("Восемь убежищ заняты. Выбери другой сервер."); return end
    self.Slots[slot]=player
    local s={Profile=profile,Joined=os.clock(),ShieldUntil=0,InterceptAt=0,Carry=nil,Combo=0,Damage=0,Dodges=0,
        Stamina=100,Sprint=false,DashAt=0,MoveBudget=7,SpawnGrace=os.clock()+3,LastPosition=nil,
        Limits={},InvalidAt=-100,LastActive=os.clock(),PassiveAt=os.clock()+Config.PassiveInterval,Dirty=true,ClientReady=false,Base=nil}
    self.Sessions[player]=s
    s.Base=World.base(self.World,slot,player)
    World.prompt(s.Base.Incubator,"Инкубировать","Убежище "..player.DisplayName,.5,function(p) if p==player then self.Progression:firstEgg(p) end end)
    World.prompt(s.Base.Ward,"Включить щит","Колокольчик",.5,function(p)
        local r=self:root(p)
        if p==player and r and (r.Position-s.Base.Ward.Position).Magnitude<12 and self:allow(p,"ward",30) then
            s.ShieldUntil=os.clock()+5+profile.Upgrades.Ward*2
            self:notify(p,"Щит активен ненадолго — можно выйти из хаба"); s.Dirty=true
        end
    end)
    self.Progression:display(player)
    local stats=Instance.new("Folder"); stats.Name="leaderstats"; stats.Parent=player
    for _,name in ipairs({"Coins","Eggs","Level"}) do local v=Instance.new("IntValue"); v.Name=name; v.Parent=stats end
    s.CharacterConnection=player.CharacterAdded:Connect(function(c) self:character(player,c) end)
    s.CharacterRemovingConnection=player.CharacterRemoving:Connect(function(c)
        if self.Sessions[player]==s and (s.Character==c or player.Character==c) then
            self.Eggs:drop(player,true); s.Sprint=false; s.Character=nil
        end
    end)
    if player.Character then task.spawn(function() self:character(player,player.Character) end) end
end
function Game:remove(player)
    if self.Removing[player] then return end
    self.Removing[player]=true
    local s=self.Sessions[player]
    if s then
        self.Eggs:drop(player,true)
        if s.CharacterConnection then s.CharacterConnection:Disconnect() end
        if s.CharacterRemovingConnection then s.CharacterRemovingConnection:Disconnect() end
        if s.DeathConnection then s.DeathConnection:Disconnect() end
        self.Slots[s.Base.Index]=nil; s.Base.Model:Destroy(); self.Sessions[player]=nil
    end
    self.Data:save(player,true)
    self.Removing[player]=nil
end
function Game:action(player,action,arg)
    if type(action)~="string" or not ACTION_INTERVALS[action] then return end
    local s=self.Sessions[player]; if not s or self.Closing then return end
    -- Releasing sprint must not be discarded by an unrelated button's throttle.
    if action=="Sprint" and arg==false then s.Sprint=false; return end
    if not self:allow(player,"action:"..action,ACTION_INTERVALS[action]) then return end
    if action=="Ready" then s.ClientReady=true; s.Dirty=true
    elseif action=="Sprint" and type(arg)=="boolean" then s.Sprint=arg
    elseif action=="Dash" then self.Movement:dash(player)
    elseif action=="Drop" then self.Eggs:drop(player,false)
    elseif action=="Intercept" then self:intercept(player)
    elseif action=="Buy" and type(arg)=="string" and #arg<40 then self.Progression:buy(player,arg)
    elseif action=="Hatch" and type(arg)=="string" and #arg<50 then self.Progression:hatch(player,arg)
    elseif action=="Quest" then self.Progression:claim(player)
    elseif action=="Equip" and type(arg)=="string" and #arg<50 then
        for i,pet in ipairs(s.Profile.Pets) do
            if pet.Uid==arg then table.remove(s.Profile.Pets,i); table.insert(s.Profile.Pets,1,pet); self.Progression:display(player); s.Dirty=true; break end
        end
    elseif action=="Setting" and (arg=="LowFX" or arg=="Muted") then s.Profile.Settings[arg]=not s.Profile.Settings[arg]; s.Dirty=true end
end
function Game:snapshot(player)
    local s=self.Sessions[player]; if not s then return end
    local root=self:root(player); local egg=s.Carry and self.Eggs.Eggs[s.Carry]
    self.Remotes.State:FireClient(player,{
        Profile=if s.Dirty or not s.ClientReady then s.Profile else nil, Stamina=s.Stamina, MaxStamina=Config.BaseStamina+s.Profile.Upgrades.Stamina*12,
        Carry=if egg then {Id=egg.Id,Mutation=egg.Mutation} else false,
        Safe=if root then self:isSafe(root.Position) else true, Combo=s.Combo,
        Protection=math.max(0,math.ceil(s.Joined+Config.NewPlayerProtection-os.clock())),
        Shield=math.max(0,math.ceil(s.ShieldUntil-os.clock())),Dash=math.max(0,s.DashAt-os.clock()),
        Intercept=math.max(0,s.InterceptAt-os.clock()),Sprint=s.Sprint,ServerTime=workspace:GetServerTimeNow(),
        InIncubatorRange=root~=nil and (root.Position-s.Base.Incubator.Position).Magnitude<=13,
        Event=self.EventActive, EventSeconds=math.max(0,math.ceil((if self.EventActive then self.Events.Ends else self.Events.NextAt)-os.clock())),
        Base={X=s.Base.Center.X,Z=s.Base.Center.Z,
            PadX=s.Base.Pad.Position.X,PadY=s.Base.Pad.Position.Y,PadZ=s.Base.Pad.Position.Z,
            IncubatorX=s.Base.Incubator.Position.X,IncubatorY=s.Base.Incubator.Position.Y,IncubatorZ=s.Base.Incubator.Position.Z}, Memory=self.Data.Memory,
    })
    s.Dirty=false
    local stats=player:FindFirstChild("leaderstats")
    if stats then stats.Coins.Value=s.Profile.Coins; stats.Eggs.Value=s.Profile.TotalDelivered; stats.Level.Value=s.Profile.Level end
end
return Game
