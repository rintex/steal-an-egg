--!strict
local function describeError(failure) return debug.traceback(tostring(failure),2) end
workspace:SetAttribute("HeistBuild","STUDIO-FIX-04")
workspace:SetAttribute("HeistServerState","Starting")
workspace:SetAttribute("HeistServerStage","BOOT")
local function initialize()
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local remotesFolder=Instance.new("Folder"); remotesFolder.Name="Remotes"; remotesFolder.Parent=ReplicatedStorage
local remotes={}
for _,name in ipairs({"Action","State","Notice","Effect"}) do
    local remote=Instance.new("RemoteEvent"); remote.Name=name; remote.Parent=remotesFolder; remotes[name]=remote
end
workspace:SetAttribute("HeistServerStage","DATA")
local data=require(script.Parent.Services.DataService).new()
workspace:SetAttribute("HeistServerStage","WORLD")
local gameService=require(script.Parent.Services.GameService).new(remotes,data)
remotes.Action.OnServerEvent:Connect(function(...) gameService:action(...) end)
Players.PlayerAdded:Connect(function(player) gameService:add(player) end)
Players.PlayerRemoving:Connect(function(player) gameService:remove(player) end)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(function() gameService:add(player) end) end
local errorTimes={}
local function step(name,callback)
    local ok,err=pcall(callback)
    if not ok and os.clock()>=(errorTimes[name] or 0) then
        errorTimes[name]=os.clock()+10
        warn("EggHeist "..name..": "..tostring(err))
    end
end
-- A single bounded scheduler for all gameplay actors. DataStore I/O runs independently.
task.spawn(function()
    local previous=os.clock(); local nextState=0; local nextProgress=0
    while not gameService.Closing do
        local now=os.clock(); local dt=math.min(.5,now-previous); previous=now
        for p in pairs(gameService.Sessions) do
            step("player update",function() gameService.Movement:update(p,dt); gameService.Eggs:deliver(p) end)
        end
        step("guardians",function() gameService.Guardians:update(dt) end)
        step("eggs",function() gameService.Eggs:update() end)
        step("events",function() gameService.Events:update() end)
        if now>=nextProgress then
            nextProgress=now+1
            for p in pairs(gameService.Sessions) do step("progression",function() gameService.Progression:update(p) end) end
        end
        if now>=nextState then
            nextState=now+.5
            for p in pairs(gameService.Sessions) do step("snapshot",function() gameService:snapshot(p) end) end
        end
        task.wait(.2)
    end
end)
task.spawn(function()
    while not gameService.Closing do
        task.wait(45)
        if gameService.Closing then break end
        for p in pairs(gameService.Sessions) do task.spawn(function() data:save(p,false) end) end
    end
end)
game:BindToClose(function()
    gameService.Closing=true
    local remaining=0
    for p in pairs(gameService.Sessions) do
        remaining+=1
        task.spawn(function() step("shutdown save",function() gameService:remove(p) end); remaining-=1 end)
    end
    local deadline=os.clock()+25
    while (remaining>0 or next(gameService.Joining)~=nil or next(gameService.Removing)~=nil) and os.clock()<deadline do task.wait(.1) end
end)

    workspace:SetAttribute("HeistServerStage","READY")
    workspace:SetAttribute("HeistServerState","Ready")
end
local ok,failure=xpcall(initialize,describeError)
if not ok then
    workspace:SetAttribute("HeistServerState","Failed")
    workspace:SetAttribute("HeistStartupError",string.sub(tostring(failure),1,400))
    warn("EggHeist startup failed: "..tostring(failure))
end
