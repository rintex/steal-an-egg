--!strict
local function describeError(failure) return debug.traceback(tostring(failure),2) end
-- Keep this entry point independent of the game UI until it has a player profile.
-- A visible status screen also covers missing remotes, failed modules and cameras.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local boot=playerGui:FindFirstChild("EggHeistStartup")
if not boot then
    boot=Instance.new("ScreenGui")
    boot.Name="EggHeistStartup"; boot.ResetOnSpawn=false; boot.DisplayOrder=200; boot.Parent=playerGui
end
local card=boot:FindFirstChild("Card")
if not card then
    card=Instance.new("Frame"); card.Name="Card"; card.AnchorPoint=Vector2.new(.5,0)
    card.Position=UDim2.new(.5,0,0,24); card.Size=UDim2.new(.9,0,0,116)
    card.BackgroundColor3=Color3.fromRGB(21,32,48); card.BorderSizePixel=0; card.Parent=boot
    local max=Instance.new("UISizeConstraint"); max.MaxSize=Vector2.new(640,180); max.Parent=card
    local round=Instance.new("UICorner"); round.CornerRadius=UDim.new(0,14); round.Parent=card
end
local status=card:FindFirstChild("Status")
if not status then
    status=Instance.new("TextLabel"); status.Name="Status"; status.BackgroundTransparency=1
    status.Position=UDim2.fromOffset(14,10); status.Size=UDim2.new(1,-28,1,-20)
    status.TextColor3=Color3.fromRGB(242,247,250); status.Font=Enum.Font.GothamBold
    status.TextSize=16; status.TextWrapped=true; status.Parent=card
end
local phase="CONNECT"
local complete=false
local started=os.clock()
local connections={}
-- StarterGui may be cloned after PlayerScripts have already started. Keep a
-- single loading screen so a late template cannot cover a successfully loaded HUD.
table.insert(connections,playerGui.ChildAdded:Connect(function(object)
    if object~=boot and object.Name=="EggHeistStartup" and object:IsA("ScreenGui") then object:Destroy() end
end))
local function report(code,message)
    phase=code; boot.Enabled=true
    status.Text="STUDIO-FIX-04 / "..code.."\n"..message
end
report("CONNECT","Подключаем игру…")
local function cameraFor(character)
    task.spawn(function()
        local humanoid=character:WaitForChild("Humanoid",10)
        local root=character:WaitForChild("HumanoidRootPart",10)
        if not humanoid or not root or player.Character~=character then return end
        local camera=workspace.CurrentCamera
        if camera then
            camera.CameraType=Enum.CameraType.Custom
            camera.CameraSubject=humanoid
            camera.CFrame=CFrame.lookAt(root.Position+Vector3.new(0,8,-18),root.Position+Vector3.new(0,2,0))
        end
    end)
end
table.insert(connections,player.CharacterAdded:Connect(cameraFor))
if player.Character then cameraFor(player.Character) end
local elapsed=0
table.insert(connections,RunService.Heartbeat:Connect(function(dt)
    if complete or phase=="CLIENT-ERROR" or phase=="WAIT-ERROR" then return end
    elapsed+=dt; if elapsed<.5 then return end; elapsed=0
    local state=workspace:GetAttribute("HeistServerState")
    if state=="Failed" then
        local detail=if RunService:IsStudio() then tostring(workspace:GetAttribute("HeistStartupError") or "") else "Попробуй перезапустить игру."
        report("SERVER-ERROR",detail)
    elseif os.clock()-started>12 then
        report("WAIT",if state=="Ready" then "Сервер готов. Ждём профиль игрока…" else "Сервер не запустился. Этап: "..tostring(workspace:GetAttribute("HeistServerStage") or "BOOT"))
    end
end))
local function initialize()
    local remotesFolder=ReplicatedStorage:WaitForChild("Remotes",15)
    if not remotesFolder then report("WAIT-ERROR","Не появились игровые подключения. Попробуй остановить Play и запустить снова."); return end
    local remotes={}
    for _,name in ipairs({"Action","State","Notice","Effect"}) do
        remotes[name]=remotesFolder:WaitForChild(name,15)
        if not remotes[name] then error("Missing game connection: "..name) end
    end
    phase="UI"
    local controllers=script.Parent.Controllers
    local ui=require(controllers.UIController).new(remotes)
    local effects,tutorial,movement
    local acknowledged=false
    -- Subscribe before optional controllers: a visual-effect failure cannot
    -- prevent the main UI from receiving its profile and finishing loading.
    table.insert(connections,remotes.State.OnClientEvent:Connect(function(state)
        local ok,failure=xpcall(function()
            ui:update(state)
            if state.Profile and not acknowledged then acknowledged=true; remotes.Action:FireServer("Ready") end
            if ui.Profile then
                complete=true; boot.Enabled=false
                if effects then effects:settings(ui.Profile.Settings) end
                if tutorial then tutorial:update(state,ui.Profile) end
            end
            if effects then effects:carry(state.Carry~=false and state.Carry~=nil) end
            if movement then movement:update(state) end
        end,describeError)
        if not ok then complete=false; report("CLIENT-ERROR",tostring(failure):sub(1,400)); warn(failure) end
    end))
    local function optional(name,constructor)
        local ok,result=pcall(constructor)
        if ok then return result end
        warn("EggHeist "..name..": "..tostring(result))
        return nil
    end
    effects=optional("effects",function() return require(controllers.EffectsController).new(ui) end)
    tutorial=optional("tutorial",function() return require(controllers.TutorialController).new() end)
    movement=optional("movement",function() return require(controllers.MovementController).start(remotes,ui) end)
    table.insert(connections,remotes.Notice.OnClientEvent:Connect(function(message,sound)
        ui:notice(message); if effects and sound then effects:sound(sound) end
    end))
    table.insert(connections,remotes.Effect.OnClientEvent:Connect(function(kind,id)
        if not effects then return end
        if kind=="Dash" then effects:dash() elseif kind=="Hatch" then effects:hatch(id) end
    end))
    table.insert(connections,script.Destroying:Connect(function()
        for _,connection in ipairs(connections) do connection:Disconnect() end
        if movement then movement:Destroy() end
        if effects then effects:Destroy() end
        if tutorial then tutorial:Destroy() end
        ui.Gui:Destroy(); boot:Destroy()
    end))
    report("PROFILE","Загружаем твой профиль…")
    remotes.Action:FireServer("Ready")
end
local ok,failure=xpcall(initialize,describeError)
if not ok then report("CLIENT-ERROR",tostring(failure):sub(1,400)); warn("EggHeist client startup failed: "..tostring(failure)) end
