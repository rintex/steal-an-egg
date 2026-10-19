--!strict
local CAS = game:GetService("ContextActionService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.EconomyConfig)

local Movement = {}
Movement.__index = Movement
local actionNames = {"Sprint", "Dash", "Drop", "Intercept"}
local keyActions = {
    [Enum.KeyCode.Q] = "Dash", [Enum.KeyCode.ButtonB] = "Dash",
    [Enum.KeyCode.G] = "Drop", [Enum.KeyCode.DPadDown] = "Drop",
    [Enum.KeyCode.F] = "Intercept", [Enum.KeyCode.ButtonX] = "Intercept",
}

function Movement.start(remotes, ui)
    local self = setmetatable({
        Remotes = remotes, UI = ui, Connections = {}, Sources = {}, Sprint = false,
        State = nil, MenuOpen = GuiService.MenuIsOpen, LastBlocked = -math.huge, Destroyed = false,
    }, Movement)
    local function connect(signal, callback)
        table.insert(self.Connections, signal:Connect(callback))
    end
    local function blocked()
        return self.MenuOpen or Input:GetFocusedTextBox() ~= nil
            or ui.Gui:GetAttribute("ModalOpen") == true or ui.Gui:GetAttribute("HatchOpen") == true
    end
    self.IsBlocked = blocked
    local function sprint()
        local active = next(self.Sources) ~= nil and not blocked()
        if self.Sprint ~= active then
            self.Sprint = active
            remotes.Action:FireServer("Sprint", active)
            self:refresh()
        end
    end
    self.SyncSprint = sprint
    local function reset()
        table.clear(self.Sources)
        sprint()
    end
    self.ResetSprint = reset
    local function allowed()
        return not self.Destroyed and not blocked() and os.clock() - self.LastBlocked > .12
    end
    local function fire(action)
        if not allowed() then return end
        local state = self.State
        if state then
            if action == "Dash" and (state.Dash > 0 or state.Stamina < Config.DashCost) then return end
            if action == "Drop" and not state.Carry then return end
            if action == "Intercept" and (state.Carry or state.Safe or state.Protection > 0) then return end
        end
        remotes.Action:FireServer(action)
    end
    -- CAS owns only the on-screen buttons. Hardware uses gameProcessedEvent,
    -- so text fields, Roblox menus and modal UI receive their inputs first.
    for _, action in ipairs(actionNames) do
        CAS:BindAction("Heist" .. action, function(_, state, inputObject)
            if inputObject.UserInputType ~= Enum.UserInputType.Touch then
                return Enum.ContextActionResult.Pass
            end
            if state == Enum.UserInputState.Begin and allowed() then
                if action == "Sprint" then
                    self.Sources.Touch = if self.Sources.Touch then nil else true
                    sprint()
                else
                    fire(action)
                end
            end
            return Enum.ContextActionResult.Sink
        end, true)
    end
    connect(Input.InputBegan, function(inputObject, gameProcessedEvent)
        if gameProcessedEvent or not allowed() then return end
        local key = inputObject.KeyCode
        if key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift then
            self.Sources[key] = true
            sprint()
        elseif key == Enum.KeyCode.ButtonL3 then
            self.Sources.Gamepad = if self.Sources.Gamepad then nil else true
            sprint()
        elseif keyActions[key] then
            fire(keyActions[key])
        end
    end)
    connect(Input.InputEnded, function(inputObject)
        if self.Sources[inputObject.KeyCode] then
            self.Sources[inputObject.KeyCode] = nil
            sprint()
        end
    end)
    connect(Input.WindowFocusReleased, reset)
    connect(Input.TextBoxFocused, function() self.LastBlocked = os.clock(); reset() end)
    connect(Input.GamepadDisconnected, reset)
    connect(Input:GetPropertyChangedSignal("PreferredInput"), reset)
    connect(Players.LocalPlayer.CharacterAdded, reset)
    connect(GuiService.MenuOpened, function() self.MenuOpen = true; self.LastBlocked = os.clock(); reset(); self:refresh() end)
    connect(GuiService.MenuClosed, function() self.MenuOpen = false; self.LastBlocked = os.clock(); self:refresh() end)
    for _, attribute in ipairs({"ModalOpen", "HatchOpen"}) do
        connect(ui.Gui:GetAttributeChangedSignal(attribute), function()
            self.LastBlocked = os.clock()
            if blocked() then reset() end
            self:refresh()
        end)
    end
    connect(ui.Canvas:GetPropertyChangedSignal("AbsoluteSize"), function() self:refresh() end)
    connect(ui.Gui.Destroying, function() self:Destroy() end)
    self:refresh()
    return self
end

function Movement:refresh()
    if self.Destroyed then return end
    local size = self.UI.Canvas.AbsoluteSize
    local short = size.Y < 460
    local positions = if short then {
        Sprint = UDim2.new(1, -146, 1, -158), Dash = UDim2.new(1, -72, 1, -158),
        Drop = UDim2.new(1, -220, 1, -158), Intercept = UDim2.new(1, -220, 1, -158),
    } else {
        Sprint = UDim2.new(1, -74, 1, -218), Dash = UDim2.new(1, -74, 1, -290),
        Drop = UDim2.new(1, -148, 1, -218), Intercept = UDim2.new(1, -148, 1, -218),
    }
    local state = self.State
    for _, action in ipairs(actionNames) do
        CAS:SetPosition("Heist" .. action, positions[action])
        local title = ({Sprint = if self.Sprint then "БЕГ ●" else "БЕГ", Dash = "РЫВОК", Drop = "БРОСИТЬ", Intercept = "ПЕРЕХВАТ"})[action]
        local ready = true
        if action == "Dash" and state and state.Dash > 0 then
            title = string.format("%.1fс", state.Dash)
            ready = false
        end
        CAS:SetTitle("Heist" .. action, title)
        local button = CAS:GetButton("Heist" .. action)
        if button then
            button.Size = UDim2.fromOffset(62, 62)
            button.ImageColor3 = if self.Sprint and action == "Sprint" then Color3.fromRGB(121, 241, 206) else Color3.fromRGB(29, 37, 55)
            button.ImageTransparency = if ready then .12 else .5
            local show = not self.IsBlocked()
            if action == "Drop" then show = show and state ~= nil and state.Carry ~= false and state.Carry ~= nil end
            if action == "Intercept" then show = show and state ~= nil and not state.Carry and not state.Safe and state.Protection <= 0 end
            button.Visible = show
            local label = button:FindFirstChild("ActionTitle")
            if label and label:IsA("TextLabel") then
                label.Font = Enum.Font.GothamBold
                label.TextSize = if action == "Intercept" then 12 else 13
                label.TextColor3 = if self.Sprint and action == "Sprint" then Color3.fromRGB(19, 29, 41) else Color3.fromRGB(242, 246, 255)
            end
        end
    end
end

function Movement:update(state)
    self.State = state
    if state.Stamina <= 0 and self.Sprint then self.ResetSprint() end
    self:refresh()
end

function Movement:Destroy()
    if self.Destroyed then return end
    self.ResetSprint()
    self.Destroyed = true
    for _, connection in ipairs(self.Connections) do connection:Disconnect() end
    table.clear(self.Connections)
    for _, action in ipairs(actionNames) do CAS:UnbindAction("Heist" .. action) end
end
return Movement
