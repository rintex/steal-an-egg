--!strict
local Shared=game:GetService("ReplicatedStorage").Shared
local Config=require(Shared.Config.EconomyConfig)
local Catalog=require(Shared.Config.EggConfig)
local Movement={}; Movement.__index=Movement
function Movement.new(gameService) return setmetatable({Game=gameService},Movement) end
function Movement:speed(s)
    local speed=Config.BaseSpeed+s.Profile.Upgrades.Speed*.65
    if s.Carry then
        local egg=self.Game.Eggs.Eggs[s.Carry]
        if egg then speed-=Catalog[egg.Id].Weight*Config.CarrySlowPerWeight end
    end
    if s.Sprint and s.Stamina>0 then speed+=Config.SprintBonus end
    return math.max(10,speed)
end
function Movement:dash(player)
    local s=self.Game.Sessions[player]; local root=self.Game:root(player)
    if not s or not root or os.clock()<s.DashAt or s.Stamina<Config.DashCost then return end
    local hum=player.Character:FindFirstChildOfClass("Humanoid")
    local dir=hum.MoveDirection
    if dir.Magnitude<.1 then dir=root.CFrame.LookVector end
    dir=Vector3.new(dir.X,0,dir.Z)
    if dir.Magnitude<.1 then return end
    dir=dir.Unit
    local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={player.Character,self.Game.World.Eggs}
    local distance=Config.DashDistance
    for _,offset in ipairs({Vector3.new(0,0,0),Vector3.new(0,2,0),Vector3.new(0,-1.5,0)}) do
        local hit=workspace:Raycast(root.Position+offset,dir*distance,params)
        if hit then distance=math.max(0,hit.Distance-2.5) end
    end
    local destination=root.Position+dir*distance
    -- A dash cannot cross unsupported gaps or turn into a flight mechanic.
    local floor=workspace:Raycast(destination,Vector3.new(0,-9,0),params)
    if not floor or distance<1 then return end
    s.Stamina-=Config.DashCost; s.DashAt=os.clock()+Config.DashCooldown-s.Profile.Upgrades.Dash*.25
    root.CFrame=root.CFrame+dir*distance
    s.LastPosition=root.Position; s.MoveBudget=10; s.LastActive=os.clock(); s.MovementAt=os.clock()
    s.GroundedPosition=root.Position; s.AirSince=nil
    self.Game.Remotes.Effect:FireClient(player,"Dash")
end
function Movement:update(player,dt)
    local s=self.Game.Sessions[player]; local root=self.Game:root(player)
    if not s or not root then return end
    local hum=player.Character:FindFirstChildOfClass("Humanoid")
    local maxStamina=Config.BaseStamina+s.Profile.Upgrades.Stamina*12
    local moving=hum.MoveDirection.Magnitude>.1
    if s.Sprint and moving then s.Stamina=math.max(0,s.Stamina-Config.StaminaDrain*dt)
    else s.Stamina=math.min(maxStamina,s.Stamina+(Config.StaminaRegen+(if #s.Profile.Pets>0 then 1 else 0))*dt) end
    if s.Stamina<=0 then s.Sprint=false end
    local speed=self:speed(s); hum.WalkSpeed=speed
    local now=os.clock(); local pos=root.Position
    -- Replication arrives in bursts. Keep a bounded travel allowance and refill
    -- it using actual elapsed server time, including an occasional scheduler stall.
    local elapsed=math.clamp(now-(s.MovementAt or (now-dt)),0,2)
    s.MovementAt=now
    if s.LastPosition then
        local delta=Vector3.new(pos.X-s.LastPosition.X,0,pos.Z-s.LastPosition.Z).Magnitude
        s.MoveBudget=math.min(math.max(12,(speed+3)*1.5),s.MoveBudget+(speed+3)*elapsed)
        if delta>s.MoveBudget and os.clock()>s.SpawnGrace then
            root.CFrame=CFrame.new(s.LastPosition)*root.CFrame.Rotation
            root.AssemblyLinearVelocity=Vector3.zero
            pos=s.LastPosition; s.InvalidAt=now
        else
            s.MoveBudget=math.max(0,s.MoveBudget-delta)
            if delta>.3 then s.LastActive=os.clock() end
        end
    end
    -- Record only validated ground positions; a teleport must never become a
    -- future anti-flight recovery point.
    local groundParams=RaycastParams.new(); groundParams.FilterType=Enum.RaycastFilterType.Exclude
    groundParams.FilterDescendantsInstances={player.Character,self.Game.World.Eggs}
    local ground=workspace:Raycast(pos,Vector3.new(0,-6,0),groundParams)
    if ground then s.AirSince=nil; s.GroundedPosition=pos
    elseif not s.AirSince then s.AirSince=now
    elseif now-s.AirSince>3 and now>s.SpawnGrace then
        self.Game.Eggs:drop(player,true)
        root.CFrame=CFrame.new(s.GroundedPosition or Vector3.new(0,5,0))
        root.AssemblyLinearVelocity=Vector3.zero
        pos=root.Position; s.AirSince=nil; s.MoveBudget=10; s.SpawnGrace=now+1
    end
    s.LastPosition=pos
    if pos.Y>65 or pos.Y< -30 then
        self.Game.Eggs:drop(player,true); root.CFrame=CFrame.new(0,5,0)
        root.AssemblyLinearVelocity=Vector3.zero
        s.LastPosition=root.Position; s.GroundedPosition=root.Position; s.AirSince=nil; s.MoveBudget=10; s.SpawnGrace=now+2
    end
end
return Movement
