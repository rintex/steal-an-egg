--!strict
local Pathfinding = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.GuardianConfig)
local World = require(script.Parent.WorldService)
local Guardian = {}; Guardian.__index=Guardian
local stateLabels={IDLE="Отдыхает",PATROL="Патрулирует",SUSPICIOUS="Что за шум?",ALERT="ТРЕВОГА!",CHASE="ПОГОНЯ!",ATTACK="БЕРЕГИСЬ!",RETURN="Возвращается",RECOVER="Переводит дух"}
function Guardian.new(gameService)
    return setmetatable({Game=gameService, Actors={}},Guardian)
end
function Guardian:add(nest)
    local model=Instance.new("Model"); model.Name="Guardian_Hen"; model.Parent=self.Game.World.Map
    local body=World.part(model,"Body",Vector3.new(6,6,7),CFrame.new(nest.Home),Color3.fromRGB(255,231,172),nil,Enum.PartType.Ball)
    model.PrimaryPart=body
    World.part(model,"Head",Vector3.new(3.7,3.7,3.7),CFrame.new(nest.Home+Vector3.new(0,3,-2)),Color3.fromRGB(255,245,214),nil,Enum.PartType.Ball)
    World.part(model,"Comb",Vector3.new(1,2.2,3),CFrame.new(nest.Home+Vector3.new(0,5,-2)),Color3.fromRGB(231,100,98),nil,Enum.PartType.Ball)
    World.part(model,"Beak",Vector3.new(1.5,1.3,2),CFrame.new(nest.Home+Vector3.new(0,2.9,-4)),Color3.fromRGB(255,174,64))
    for _, x in ipairs({-1,1}) do
        World.part(model,"Eye",Vector3.new(.45,.6,.4),CFrame.new(nest.Home+Vector3.new(x,3.3,-3.5)),Color3.fromRGB(45,49,56),nil,Enum.PartType.Ball)
        World.part(model,"Wing",Vector3.new(1.5,4,4),CFrame.new(nest.Home+Vector3.new(x*3,0,0)),Color3.fromRGB(239,194,131),nil,Enum.PartType.Ball)
        World.part(model,"Foot",Vector3.new(1.6,.8,3),CFrame.new(nest.Home+Vector3.new(x*1.6,-2.6,-1)),Color3.fromRGB(255,174,64))
    end
    for _,part in ipairs(model:GetChildren()) do if part:IsA("BasePart") then part.CanCollide=false; part.CanTouch=false; part.CanQuery=false end end
    local text=World.label(body,"НАСЕДКА • Отдыхает")
    self.Actors[nest.Index]={Model=model, Home=nest.Home, Nest=nest, State="IDLE", Until=0,
        Target=nil, NextPath=0, Waypoints=nil, PathIndex=1, Computing=false, Label=text, Patrol=1}
end
function Guardian:set(actor,state,duration)
    actor.State=state; actor.Until=os.clock()+(duration or 0); actor.Label.Text="НАСЕДКА • "..(stateLabels[state] or state)
    actor.Model:SetAttribute("State",state)
end
function Guardian:alarm(index,player)
    local a=self.Actors[index]; if not a then return end
    a.Target=player; a.Waypoints=nil; a.PathEpoch=(a.PathEpoch or 0)+1; a.NeedsPathUntil=0
    self:set(a,"ALERT",1.2)
    self.Game:notify(player,"ХРАНИТЕЛЬ ПРОСНУЛСЯ! На золотую дорожку!","Alarm")
end
function Guardian:visible(actor,root)
    local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={actor.Model,self.Game.World.Eggs}
    local origin=actor.Model:GetPivot().Position+Vector3.new(0,2,0)
    local ray=workspace:Raycast(origin,root.Position-origin,params)
    return ray==nil or ray.Instance:IsDescendantOf(root.Parent)
end
function Guardian:collisionParams(actor)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.RespectCanCollide=true
    local excluded={actor.Model,self.Game.World.Eggs}
    for _,player in ipairs(Players:GetPlayers()) do
        if player.Character then table.insert(excluded,player.Character) end
    end
    params.FilterDescendantsInstances=excluded
    return params
end
function Guardian:walk(a,destination,dt,speed)
    local pos=a.Model:GetPivot().Position
    local delta=Vector3.new(destination.X-pos.X,0,destination.Z-pos.Z)
    if delta.Magnitude<.5 then return true,false end
    local move=delta.Unit*math.min(delta.Magnitude,math.max(0,dt)*speed)
    local params=self:collisionParams(a)
    -- The NPC's visible body must not tunnel through low walls even when eye-level LOS is clear.
    local obstruction=workspace:Blockcast(CFrame.new(pos),Vector3.new(4.5,4.5,4.5),move,params)
    if obstruction then return false,true end
    local nextPos=pos+move
    local ground=workspace:Raycast(nextPos+Vector3.new(0,7,0),Vector3.new(0,-18,0),params)
    if not ground then return false,true end
    a.Model:PivotTo(CFrame.lookAt(nextPos,nextPos+delta.Unit))
    return false,false
end
function Guardian:path(a,destination)
    if a.Computing or os.clock()<a.NextPath then return end
    a.NextPath=os.clock()+Config.PathInterval; a.Computing=true
    local epoch=a.PathEpoch or 0
    task.spawn(function()
        local path=Pathfinding:CreatePath({AgentRadius=3,AgentHeight=7,AgentCanJump=false,WaypointSpacing=5})
        local ok=pcall(function() path:ComputeAsync(a.Model:GetPivot().Position,destination) end)
        -- ComputeAsync yields. A new theft or return invalidates the previous destination.
        if epoch==(a.PathEpoch or 0) then
            if ok and path.Status==Enum.PathStatus.Success then
                a.Waypoints=path:GetWaypoints(); a.PathIndex=2
            else a.Waypoints=nil end
        end
        a.Computing=false
    end)
end
function Guardian:update(dt)
    local now=os.clock()
    for _,a in pairs(self.Actors) do
        local target=a.Target; local s=target and self.Game.Sessions[target]
        local root=target and self.Game:root(target)
        local pos=a.Model:GetPivot().Position
        local chasing=a.State=="CHASE" or a.State=="ATTACK" or a.State=="ALERT"
        if chasing and (not s or not root or not s.Carry or self.Game:isSafe(root.Position) or (root.Position-a.Home).Magnitude>Config.ChaseRadius) then
            a.Target=nil; self:set(a,"RETURN"); a.Waypoints=nil; a.PathEpoch=(a.PathEpoch or 0)+1; a.NextPath=0
        end
        if a.State=="ALERT" and now>=a.Until then self:set(a,"CHASE") end
        if a.State=="CHASE" and root then
            local dist=(root.Position-pos).Magnitude
            local visible=self:visible(a,root)
            if dist<=Config.AttackDistance and visible then
                a.AttackPoint=root.Position
                a.Warning=World.part(self.Game.World.Map,"AttackWarning",Vector3.new(15,.15,15),CFrame.new(root.Position.X,1,root.Position.Z),Color3.fromRGB(255,107,92),Enum.Material.Neon,Enum.PartType.Ball)
                a.Warning.CanCollide=false; a.Warning.Transparency=.35
                self:set(a,"ATTACK",Config.Windup)
            else
                if visible and now>=(a.NeedsPathUntil or 0) then
                    a.Waypoints=nil
                    local _,blocked=self:walk(a,root.Position,dt,Config.Speed)
                    if blocked then a.NeedsPathUntil=now+2.5; self:path(a,root.Position) end
                else
                    self:path(a,root.Position)
                    local waypoint=a.Waypoints and a.Waypoints[a.PathIndex]
                    if waypoint and self:walk(a,waypoint.Position,dt,Config.Speed) then a.PathIndex+=1 end
                end
            end
        elseif a.State=="ATTACK" and now>=a.Until then
            if a.Warning then a.Warning:Destroy(); a.Warning=nil end
            local aim=a.AttackPoint
            local from=a.Model:GetPivot().Position
            local delta=Vector3.new(aim.X-from.X,0,aim.Z-from.Z)
            local attackBlocked=false
            if delta.Magnitude>.1 then
                local _,blocked=self:walk(a,aim,1,math.min(7,delta.Magnitude))
                attackBlocked=blocked
            end
            local currentRoot=target and self.Game:root(target)
            if not attackBlocked and currentRoot and (currentRoot.Position-a.AttackPoint).Magnitude<8 and not self.Game:isSafe(currentRoot.Position) and self:visible(a,currentRoot) then
                self.Game:hit(target,Config.Damage)
            elseif s then s.Dodges+=1 end
            self:set(a,"RECOVER",Config.Recovery)
        elseif a.State=="RECOVER" and now>=a.Until then
            self:set(a,if a.Target then "CHASE" else "RETURN")
        elseif a.State=="RETURN" then
            if a.Warning then a.Warning:Destroy(); a.Warning=nil end
            self:path(a,a.Home)
            local waypoint=a.Waypoints and a.Waypoints[a.PathIndex]
            if waypoint then
                if self:walk(a,waypoint.Position,dt,Config.Speed) then a.PathIndex+=1 end
            elseif (pos-a.Home).Magnitude<5 then self:set(a,"IDLE",2)
            end
        elseif a.State=="IDLE" and now>=a.Until then self:set(a,"PATROL",4)
        elseif a.State=="PATROL" then
            local destination=a.Home+Vector3.new(math.sin(a.Patrol)*8,0,math.cos(a.Patrol)*8)
            local arrived,blocked=self:walk(a,destination,dt,5)
            if arrived or blocked then a.Patrol+=1; self:set(a,"IDLE",2) end
            for _,p in ipairs(Players:GetPlayers()) do
                local r=self.Game:root(p)
                if r and (r.Position-pos).Magnitude<Config.SuspicionRadius and self:visible(a,r) then self:set(a,"SUSPICIOUS",1.5); break end
            end
        elseif a.State=="SUSPICIOUS" and now>=a.Until then self:set(a,"PATROL",4) end
    end
end
return Guardian
