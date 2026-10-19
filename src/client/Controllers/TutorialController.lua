--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Tutorial = {}
Tutorial.__index = Tutorial
local mint = Color3.fromRGB(121, 241, 206)
local gold = Color3.fromRGB(255, 217, 137)

function Tutorial.new()
    local self = setmetatable({Connections = {}, Target = nil, TargetPosition = nil, Stage = "", Completed = false, Elapsed = 0, LowFX = false}, Tutorial)
    local marker = Instance.new("Part")
    marker.Name = "LocalObjective"; marker.Anchored = true; marker.Transparency = 1
    marker.CanCollide = false; marker.CanTouch = false; marker.CanQuery = false
    marker.Size = Vector3.one; marker.Parent = workspace
    local gui = Instance.new("BillboardGui")
    gui.Name = "ObjectiveWaypoint"; gui.Size = UDim2.fromOffset(200, 78); gui.AlwaysOnTop = true
    gui.StudsOffset = Vector3.new(0, 4, 0); gui.MaxDistance = 600; gui.Enabled = false; gui.Parent = marker
    local label = Instance.new("TextLabel")
    label.Name = "Objective"; label.BackgroundTransparency = 1; label.Size = UDim2.fromScale(1, .72)
    label.TextColor3 = gold; label.TextStrokeTransparency = .35
    label.Font = Enum.Font.GothamBold; label.TextSize = 15; label.TextWrapped = true; label.Parent = gui
    local arrow = Instance.new("TextLabel")
    arrow.Name = "Pointer"; arrow.BackgroundTransparency = 1; arrow.Position = UDim2.fromScale(0, .68)
    arrow.Size = UDim2.fromScale(1, .32); arrow.Text = "▼"; arrow.TextSize = 22
    arrow.TextColor3 = gold; arrow.TextStrokeTransparency = .5; arrow.Font = Enum.Font.GothamBold; arrow.Parent = gui
    local highlight = Instance.new("Highlight")
    highlight.Name = "LocalObjectiveHighlight"; highlight.FillColor = mint; highlight.FillTransparency = .94
    highlight.OutlineColor = mint; highlight.OutlineTransparency = .28
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; highlight.Enabled = false; highlight.Parent = marker
    self.Marker = marker; self.Gui = gui; self.Label = label; self.Arrow = arrow; self.Highlight = highlight
    table.insert(self.Connections, RunService.Heartbeat:Connect(function(dt)
        self.Elapsed += dt
        if self.Elapsed < .12 then return end
        self.Elapsed = 0
        self:refresh()
    end))
    return self
end

function Tutorial:refresh()
    if not self.TargetPosition then self.Gui.Enabled = false; self.Highlight.Enabled = false; return end
    local character = Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local target = self.Target
    local position = if target and target.Parent then target.Position else self.TargetPosition
    local distance = if root then (root.Position - position).Magnitude else 0
    -- Keep a subtle home waypoint after onboarding without covering nearby play.
    self.Gui.Enabled = not self.Completed or distance > 35
    self.Marker.Position = position
    self.Highlight.Enabled = not self.Completed and target ~= nil and target.Parent ~= nil
    self.Highlight.Adornee = if target and target.Parent then target else nil
    local color = if self.Completed then mint else gold
    self.Label.TextColor3 = color; self.Arrow.TextColor3 = color
    self.Label.Text = self.Stage .. (if root then "\n" .. math.floor(distance) .. " studs" else "")
    local reduced = self.LowFX or GuiService.ReducedMotionEnabled
    self.Gui.StudsOffset = Vector3.new(0, 4 + (if reduced then 0 else math.sin(os.clock() * 2.5) * .12), 0)
end

local function findBasePart(name)
    local map = workspace:FindFirstChild("Map")
    local bases = map and map:FindFirstChild("PlayerBases")
    local base = bases and bases:FindFirstChild("Base_" .. Players.LocalPlayer.UserId)
    local part = base and base:FindFirstChild(name)
    return if part and part:IsA("BasePart") then part else nil
end

local function nearestEgg()
    local map = workspace:FindFirstChild("Map")
    local eggs = map and map:FindFirstChild("Eggs")
    local character = Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not eggs or not root then return nil end
    local nearest, best = nil, math.huge
    for _, model in ipairs(eggs:GetChildren()) do
        if model:IsA("Model") and model.PrimaryPart then
            local prompt = model.PrimaryPart:FindFirstChildWhichIsA("ProximityPrompt")
            local distance = (model.PrimaryPart.Position - root.Position).Magnitude
            if prompt and prompt.Enabled and distance < best then nearest = model.PrimaryPart; best = distance end
        end
    end
    return nearest
end

function Tutorial:update(state, profile)
    if not state.Base or not profile then return end
    self.LowFX = profile.Settings.LowFX == true
    local target, position, stage
    self.Completed = profile.Tutorial >= 3
    if state.Carry then
        target = findBasePart("DeliveryPad")
        position = Vector3.new(state.Base.X, 2, state.Base.Z + 5)
        stage = "02 / 03 • ДОСТАВЬ ЯЙЦО"
        self.Completed = false
    elseif #profile.OwnedEggs > 0 and profile.Tutorial < 3 then
        target = findBasePart("Incubator")
        position = Vector3.new(state.Base.X - 8, 2.5, state.Base.Z - 5)
        local incubating = false
        for _, egg in ipairs(profile.OwnedEggs) do
            if egg.ReadyAt > 0 then incubating = true; break end
        end
        stage = if incubating then "03 / 03 • ПИТОМЕЦ СКОРО" else "03 / 03 • ЗАПУСТИ ИНКУБАТОР"
    elseif self.Completed then
        target = findBasePart("DeliveryPad")
        position = Vector3.new(state.Base.X, 2, state.Base.Z + 5)
        stage = "ТВОЁ УБЕЖИЩЕ"
    else
        target = nearestEgg()
        position = Vector3.new(0, 3, 132)
        stage = "01 / 03 • ВОЗЬМИ ЯЙЦО"
    end
    self.Target = target; self.TargetPosition = position; self.Stage = stage
    self:refresh()
end

function Tutorial:Destroy()
    for _, connection in ipairs(self.Connections) do connection:Disconnect() end
    table.clear(self.Connections)
    self.Marker:Destroy()
end
return Tutorial
