--!strict
local Players = game:GetService("Players")
local Tween = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.Config.EggConfig)
local Audio = require(Shared.Config.AudioConfig)
local Effects = {}
Effects.__index = Effects
local palette = {
    Surface = Color3.fromRGB(21, 28, 44), Text = Color3.fromRGB(245, 248, 255),
    Muted = Color3.fromRGB(164, 178, 202), Mint = Color3.fromRGB(121, 241, 206),
}
local rarityNames = {
    COMMON = "ОБЫЧНЫЙ", UNCOMMON = "НЕОБЫЧНЫЙ", RARE = "РЕДКИЙ", EPIC = "ЭПИЧЕСКИЙ",
    LEGENDARY = "ЛЕГЕНДАРНЫЙ", MYTHIC = "МИФИЧЕСКИЙ", SECRET = "СЕКРЕТНЫЙ", DIVINE = "БОЖЕСТВЕННЫЙ",
}
local function corner(parent, radius)
    local item = Instance.new("UICorner")
    item.CornerRadius = UDim.new(0, radius)
    item.Parent = parent
end
local function text(parent, name, content, size, position, dimensions, color)
    local label = Instance.new("TextLabel")
    label.Name = name; label.BackgroundTransparency = 1; label.Text = content
    label.Font = Enum.Font.GothamBold; label.TextSize = size; label.TextColor3 = color or palette.Text
    label.TextWrapped = true; label.Position = position; label.Size = dimensions; label.ZIndex = 102
    label.Parent = parent
    return label
end

function Effects.new(ui)
    local self = setmetatable({
        UI = ui, LowFX = false, Muted = false, ReducedMotion = GuiService.ReducedMotionEnabled,
        Originals = setmetatable({}, {__mode = "k"}), Arms = {}, Connections = {},
        Carrying = false, Character = nil, Hatch = nil, HatchSerial = 0, DashSerial = 0,
        DashTween = nil, DashCamera = nil, DashFOV = nil, Destroyed = false,
    }, Effects)
    local function connect(signal, callback)
        table.insert(self.Connections, signal:Connect(callback))
    end
    connect(workspace.DescendantAdded, function(item) self:quality(item) end)
    connect(Players.LocalPlayer.CharacterRemoving, function() self:restoreArms(); self:resetDash(); self.Carrying = false end)
    connect(Players.LocalPlayer.CharacterAdded, function(character)
        self:restoreArms()
        self.Character = character
        self.Carrying = false
    end)
    connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function() self:resetDash() end)
    connect(GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"), function()
        self.ReducedMotion = GuiService.ReducedMotionEnabled
        if self.ReducedMotion then self:resetDash() end
    end)
    -- Transform is set by the Animator every frame. C0 is captured once, so
    -- applying the carry pose cannot accumulate rotations or retain old joints.
    connect(RunService.PreSimulation, function()
        if self.Carrying then self:poseArms() end
    end)
    connect(ui.Gui.Destroying, function() self:Destroy() end)
    self.Character = Players.LocalPlayer.Character
    return self
end

function Effects:quality(item)
    if item:IsA("ParticleEmitter") or item:IsA("PointLight") then
        if self.Originals[item] == nil then self.Originals[item] = item.Enabled end
        item.Enabled = not self.LowFX and self.Originals[item]
    end
end

function Effects:settings(settings)
    self.Muted = settings.Muted == true
    if self.LowFX ~= (settings.LowFX == true) then
        self.LowFX = settings.LowFX == true
        for _, item in ipairs(workspace:GetDescendants()) do self:quality(item) end
        if self.LowFX then self:resetDash() end
    end
end

function Effects:sound(key)
    local id = Audio[key]
    if self.Muted or not id or id == "" then return end
    local sound = Instance.new("Sound")
    sound.SoundId = id; sound.Volume = .3; sound.Parent = SoundService
    sound:Play()
    Debris:AddItem(sound, 8)
end

function Effects:restoreArms()
    for _, arm in ipairs(self.Arms) do
        if arm.Motor.Parent then arm.Motor.C0 = arm.C0 end
    end
    table.clear(self.Arms)
end

function Effects:poseArms()
    local character = Players.LocalPlayer.Character
    if not character then return end
    if self.Character ~= character then
        self:restoreArms()
        self.Character = character
    end
    if #self.Arms == 0 then
        for _, motor in ipairs(character:GetDescendants()) do
            if motor:IsA("Motor6D") and (motor.Name == "RightShoulder" or motor.Name == "LeftShoulder"
                or motor.Name == "Right Shoulder" or motor.Name == "Left Shoulder") then
                table.insert(self.Arms, {Motor = motor, C0 = motor.C0})
            end
        end
    end
    for _, arm in ipairs(self.Arms) do
        if arm.Motor.Parent then
            local left = string.find(arm.Motor.Name, "Left") ~= nil
            local r6 = string.find(arm.Motor.Name, " ") ~= nil
            local pose = if r6 then CFrame.Angles(0, 0, math.rad(if left then -65 else 65))
                else CFrame.Angles(math.rad(62), 0, math.rad(if left then -12 else 12))
            arm.Motor.C0 = arm.C0 * pose
        end
    end
end

function Effects:carry(carrying)
    if self.Carrying == carrying then return end
    self.Carrying = carrying
    if carrying then self:poseArms() else self:restoreArms() end
end

function Effects:resetDash()
    self.DashSerial += 1
    if self.DashTween then self.DashTween:Cancel(); self.DashTween = nil end
    if self.DashCamera and self.DashCamera.Parent and self.DashFOV then
        self.DashCamera.FieldOfView = self.DashFOV
    end
    self.DashCamera = nil; self.DashFOV = nil
end

function Effects:dash()
    self:sound("Dash")
    if self.LowFX or self.ReducedMotion or self.Destroyed then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local baseline = if self.DashCamera == camera then self.DashFOV else camera.FieldOfView
    self:resetDash()
    self.DashCamera = camera; self.DashFOV = baseline
    local serial = self.DashSerial
    self.DashTween = Tween:Create(camera, TweenInfo.new(.08, Enum.EasingStyle.Quad), {FieldOfView = math.min(baseline + 5, 110)})
    self.DashTween:Play()
    task.delay(.1, function()
        if self.Destroyed or serial ~= self.DashSerial or workspace.CurrentCamera ~= camera then return end
        self.DashTween = Tween:Create(camera, TweenInfo.new(.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = baseline})
        self.DashTween:Play()
        task.delay(.26, function()
            if not self.Destroyed and serial == self.DashSerial then self:resetDash() end
        end)
    end)
end

function Effects:closeHatch()
    self.HatchSerial += 1
    local hatch = self.Hatch
    self.Hatch = nil
    if hatch then
        for _, connection in ipairs(hatch.Connections) do connection:Disconnect() end
        for _, tween in ipairs(hatch.Tweens) do tween:Cancel() end
        hatch.Root:Destroy()
        if hatch.PreviousSelection and hatch.PreviousSelection.Parent then
            GuiService.SelectedObject = hatch.PreviousSelection
        elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(hatch.Root) then
            GuiService.SelectedObject = nil
        end
    end
    if self.UI.Gui.Parent then self.UI.Gui:SetAttribute("HatchOpen", false) end
end

function Effects:hatch(id)
    local def = Catalog[id]
    if not def or self.Destroyed then return end
    self:closeHatch()
    self.UI.Gui:SetAttribute("HatchOpen", true)
    self:resetDash()
    local serial = self.HatchSerial
    local reduced = self.LowFX or self.ReducedMotion
    local color = Color3.fromRGB(table.unpack(def.Color))
    local overlay = Instance.new("TextButton")
    overlay.Name = "HatchReveal"; overlay.Size = UDim2.fromScale(1, 1); overlay.Text = ""
    overlay.AutoButtonColor = false; overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = .28; overlay.BorderSizePixel = 0; overlay.ZIndex = 100
    overlay.Active = true; overlay.Selectable = false; overlay.Modal = true; overlay.Parent = self.UI.Canvas
    local card = Instance.new("Frame")
    card.Name = "RevealCard"; card.AnchorPoint = Vector2.new(.5, .5); card.Position = UDim2.fromScale(.5, .5)
    card.BackgroundColor3 = palette.Surface; card.BorderSizePixel = 0; card.ZIndex = 101; card.Parent = overlay
    corner(card, 24)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color; stroke.Transparency = .35; stroke.Thickness = 1.5; stroke.Parent = card
    local glow = Instance.new("UIGradient")
    glow.Color = ColorSequence.new(palette.Surface:Lerp(color, .13), palette.Surface); glow.Rotation = 90; glow.Parent = card
    local kicker = text(card, "Kicker", "НОВЫЙ ПИТОМЕЦ", 13, UDim2.fromOffset(16, 16), UDim2.new(1, -32, 0, 22), color)
    local title = text(card, "Title", "Маленькое чудо внутри…", 25, UDim2.fromOffset(16, 40), UDim2.new(1, -32, 0, 36))
    local subtitle = text(card, "Subtitle", "Скорлупа вот-вот раскроется", 14, UDim2.new(0, 16, 1, -102), UDim2.new(1, -32, 0, 38), palette.Muted)
    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "PetPortrait"; viewport.BackgroundTransparency = 1; viewport.Position = UDim2.fromOffset(16, 78)
    viewport.Size = UDim2.new(1, -32, 1, -198); viewport.ZIndex = 102
    viewport.Ambient = Color3.fromRGB(165, 177, 199); viewport.LightColor = Color3.fromRGB(255, 243, 221)
    viewport.LightDirection = Vector3.new(-1, -1, -1); viewport.Parent = card
    local world = Instance.new("WorldModel"); world.Name = "RevealScene"; world.Parent = viewport
    local camera = Instance.new("Camera")
    camera.FieldOfView = 38; camera.CFrame = CFrame.lookAt(Vector3.new(0, 1, -10), Vector3.new(0, .2, 0))
    camera.Parent = viewport; viewport.CurrentCamera = camera
    local model = Instance.new("Model"); model.Name = "RevealModel"; model.Parent = world
    local function ball(name, size, position, partColor)
        local part = Instance.new("Part")
        part.Name = name; part.Shape = Enum.PartType.Ball; part.Size = size; part.CFrame = CFrame.new(position)
        part.Anchored = true; part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
        part.Material = Enum.Material.SmoothPlastic; part.Color = partColor; part.Parent = model
        return part
    end
    local egg = ball("Egg", Vector3.new(2.2, 3, 2.2), Vector3.zero, color)
    for index = 1, 5 do
        local angle = index * math.pi * .4
        ball("Speckle", Vector3.new(.25, .38, .18), Vector3.new(math.cos(angle) * .9, (index % 3 - 1) * .55, -math.abs(math.sin(angle)) * .92), color:Lerp(Color3.new(1, 1, 1), .65))
    end
    local close = Instance.new("TextButton")
    close.Name = "Continue"; close.AnchorPoint = Vector2.new(.5, 1); close.Position = UDim2.new(.5, 0, 1, -18)
    close.Size = UDim2.new(1, -48, 0, 44); close.BackgroundColor3 = palette.Mint; close.Text = "Пропустить раскрытие"
    close.Font = Enum.Font.GothamBold; close.TextSize = 15; close.TextColor3 = palette.Surface
    close.AutoButtonColor = true; close.BorderSizePixel = 0; close.ZIndex = 103; close.Parent = card; corner(close, 12)
    local hatch = {Root = overlay, Connections = {}, Tweens = {}, PreviousSelection = GuiService.SelectedObject}
    self.Hatch = hatch
    local function alive() return not self.Destroyed and self.Hatch == hatch and serial == self.HatchSerial and overlay.Parent ~= nil end
    local function connect(signal, callback) table.insert(hatch.Connections, signal:Connect(callback)) end
    local function animate(instance, info, goal)
        local tween = Tween:Create(instance, info, goal)
        table.insert(hatch.Tweens, tween); tween:Play()
    end
    local function resize()
        local available = self.UI.Canvas.AbsoluteSize
        local short = available.Y < 440
        card.Size = UDim2.fromOffset(math.min(432, math.max(240, available.X - 24)), math.min(if short then 308 else 438, math.max(260, available.Y - 24)))
        title.TextSize = if short then 21 else 25
        title.Position = UDim2.fromOffset(16, if short then 30 else 40)
        kicker.Position = UDim2.fromOffset(16, if short then 8 else 16)
        viewport.Position = UDim2.fromOffset(16, if short then 66 else 78)
        viewport.Size = UDim2.new(1, -32, 1, if short then -180 else -198)
    end
    connect(self.UI.Canvas:GetPropertyChangedSignal("AbsoluteSize"), resize); resize()
    connect(close.Activated, function() if alive() then self:closeHatch() end end)
    local input = game:GetService("UserInputService")
    connect(input.InputBegan, function(object, gameProcessedEvent)
        if gameProcessedEvent or not alive() or input:GetFocusedTextBox() then return end
        if object.KeyCode == Enum.KeyCode.Escape or object.KeyCode == Enum.KeyCode.ButtonB then self:closeHatch() end
    end)
    if input.PreferredInput == Enum.PreferredInput.Gamepad then GuiService.SelectedObject = close end
    local started = os.clock()
    if not reduced then
        connect(RunService.RenderStepped, function()
            if not alive() then return end
            local elapsed = os.clock() - started
            if elapsed < 1.1 then
                model:PivotTo(CFrame.new(0, math.sin(elapsed * 6) * .07, 0) * CFrame.Angles(0, 0, math.sin(elapsed * 26) * .08))
            else
                model:PivotTo(CFrame.new(0, math.sin(elapsed * 2) * .08, 0) * CFrame.Angles(0, math.sin(elapsed * .8) * .16, 0))
            end
        end)
    end
    task.delay(if reduced then .15 else 1.1, function()
        if not alive() then return end
        model:ClearAllChildren(); model:PivotTo(CFrame.new())
        local body = ball("Body", Vector3.new(2.5, 2.1, 2.2), Vector3.zero, color)
        ball("Chest", Vector3.new(1.5, 1.3, .35), Vector3.new(0, -.2, -1), color:Lerp(Color3.new(1, 1, 1), .55))
        for _, side in ipairs({-1, 1}) do
            ball("Ear", Vector3.new(.6, 1.45, .65), Vector3.new(side * .72, 1.4, .05), color)
            ball("InnerEar", Vector3.new(.27, .9, .18), Vector3.new(side * .72, 1.48, -.26), color:Lerp(Color3.fromRGB(255, 190, 210), .65))
            ball("Eye", Vector3.new(.29, .36, .18), Vector3.new(side * .53, .27, -1.03), Color3.fromRGB(23, 32, 48))
            ball("Catchlight", Vector3.new(.085, .1, .05), Vector3.new(side * .53 - .035, .35, -1.12), Color3.new(1, 1, 1))
            ball("Paw", Vector3.new(.7, .44, .85), Vector3.new(side * .72, -.97, -.55), color)
        end
        ball("Nose", Vector3.new(.2, .15, .14), Vector3.new(0, -.05, -1.18), Color3.fromRGB(114, 78, 105))
        title.Text = def.PetName
        kicker.Text = rarityNames[def.Rarity] or def.Rarity
        subtitle.Text = "Уже в коллекции • первый активный питомец помогает восстанавливать выносливость"
        close.Text = "Продолжить ограбление"
        self:sound("Hatch")
        if not reduced then
            body.Size = Vector3.new(1.6, 1.3, 1.4)
            animate(body, TweenInfo.new(.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = Vector3.new(2.5, 2.1, 2.2)})
        end
    end)
    -- Every delayed callback is scoped to this reveal. Skip, replacement and
    -- destruction invalidate the token and cannot close a later hatch.
    task.delay(if reduced then 5 else 7, function() if alive() then self:closeHatch() end end)
end

function Effects:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self:closeHatch(); self:resetDash(); self:restoreArms()
    for _, connection in ipairs(self.Connections) do connection:Disconnect() end
    table.clear(self.Connections)
    for item, enabled in pairs(self.Originals) do if item.Parent then item.Enabled = enabled end end
end
return Effects
