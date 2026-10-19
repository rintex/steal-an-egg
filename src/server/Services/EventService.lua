--!strict
local Shared=game:GetService("ReplicatedStorage").Shared
local Config=require(Shared.Config.EconomyConfig)
local World=require(script.Parent.WorldService)
local Events={}; Events.__index=Events
function Events.new(gameService)
    local self=setmetatable({Game=gameService,NextAt=os.clock()+Config.EventInterval,Ends=0,Active=false,Egg=nil},Events)
    local part=World.part(gameService.World.Map,"GoldenNest",Vector3.new(8,1,8),CFrame.new(60,1,160),Color3.fromRGB(216,175,86))
    self.Nest={Part=part,Home=Vector3.new(71,4,164),Index=4,Temporary=true}
    gameService.Guardians:add(self.Nest)
    return self
end
function Events:update()
    local now=os.clock()
    if not self.Active and now>=self.NextAt then
        self.Active=true; self.Game.EventActive=true; self.Ends=now+Config.EventDuration
        self.Egg=self.Game.Eggs:spawn(self.Nest,"sunseed")
        for p,s in pairs(self.Game.Sessions) do s.Dirty=true; self.Game:notify(p,"ЗОЛОТАЯ ЛИХОРАДКА! Особое гнездо справа в лугах.","Alarm") end
    elseif self.Active and now>=self.Ends then
        self.Active=false; self.Game.EventActive=false; self.NextAt=now+Config.EventInterval
        if self.Egg and self.Egg.State=="Nest" then self.Egg.Model:Destroy(); self.Game.Eggs.Eggs[self.Egg.Uid]=nil end
        self.Game.Eggs.NestEggs[4]=nil
        self.Egg=nil
        for _,s in pairs(self.Game.Sessions) do s.Dirty=true end
    end
end
return Events
