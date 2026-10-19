--!strict
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Tween = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Config.EggConfig)
local Upgrades = require(Shared.Config.UpgradeConfig)
local Economy = require(Shared.Config.EconomyConfig)
local Rules = require(Shared.Domain.Rules)
local Theme = require(script.Parent.UITheme)
local Layout = require(script.Parent.UILayout)
local C = require(script.Parent.UIComponents)
local UI = {}
UI.__index = UI
local tabs = {
    {Id = "Collection", Label = "Коллекция", Short = "Яйца и питомцы"},
    {Id = "Upgrades", Label = "Снаряжение", Short = "Постоянные бонусы"},
    {Id = "Quests", Label = "Задания", Short = "Ежедневная награда"},
    {Id = "Achievements", Label = "Рекорды", Short = "Твои достижения"},
    {Id = "Settings", Label = "Настройки", Short = "Под себя"},
}
local upgradeCopy = {
    Speed = {Tag = "01 / ДВИЖЕНИЕ", Detail = "+0,65 к скорости за уровень. Быстрее добирайся до своего убежища."},
    Stamina = {Tag = "02 / ЭНЕРГИЯ", Detail = "+12 к запасу выносливости за уровень. Продли свой побег."},
    Dash = {Tag = "03 / РЫВОК", Detail = "Перезарядка короче на 0,25 сек. за уровень. Рывок стоит 25 энергии."},
    Incubator = {Tag = "04 / ПИТОМЦЫ", Detail = "Инкубация быстрее на 10% за уровень. Работает у твоего инкубатора."},
    Ward = {Tag = "05 / ЗАЩИТА", Detail = "+2 секунды щита за уровень. Активируй колокольчик у своего убежища."},
}
local function touch(): boolean return Input.PreferredInput == Enum.PreferredInput.Touch end
local function gamepad(): boolean return Input.PreferredInput == Enum.PreferredInput.Gamepad end
local function reduced(): boolean return GuiService.ReducedMotionEnabled end
local function scroller(parent, name)
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = name
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Theme.Muted
    scroll.CanvasSize = UDim2.new()
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
    scroll.Parent = parent
    return scroll
end
local function list(parent, padding)
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, padding or 12)
    layout.Parent = parent
    return layout
end
local function now(self)
    if self.ServerClock then return self.ServerClock + (os.clock() - self.ClockReceived) end
    return os.time()
end
function UI.new(remotes)
    local self = setmetatable({
        Remotes = remotes, Profile = nil, State = nil, Tab = nil, ModalOpen = false,
        Views = {}, Nav = {}, Pending = {}, Cards = {}, Timers = {}, NoticeSerial = 0,
        Filter = "All", Query = "", LastInventory = "", Connections = {},
    }, UI)
    local gui = Instance.new("ScreenGui")
    gui.Name = "EggHeistHUD"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
    gui.DisplayOrder = 10
    gui:SetAttribute("ModalOpen", false)
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = gui
    local canvas = C.frame(gui, "Canvas", Theme.Background)
    canvas.BackgroundTransparency = 1
    canvas.Size = UDim2.fromScale(1, 1)
    self.Canvas = canvas

    self.Top = C.surface(canvas, "ProfileCard")
    self.Brand = C.strong(self.Top, "Brand", "STEAL AN EGG", 12, Theme.Teal)
    self.Balance = C.strong(self.Top, "Balance", "Подключаем профиль…", 23)
    self.Level = C.strong(self.Top, "Level", "LV 01", 13, Theme.Amber)
    self.XPTrack, self.XP = C.progress(self.Top, "XP", Theme.Amber)
    self.Combo = C.text(self.Top, "Combo", "Первое ограбление впереди", 12, Theme.Muted)

    self.EventCard = C.surface(canvas, "WorldStatus")
    self.Event = C.strong(self.EventCard, "Event", "ЛУГА / GREEN MEADOW", 12, Theme.Amber)
    self.Zone = C.text(self.EventCard, "Zone", "Соединение с сервером…", 13, Theme.Muted)
    self.EventBar, self.EventFill = C.progress(self.EventCard, "EventProgress", Theme.Amber)

    self.ObjectiveCard = C.surface(canvas, "Objective")
    self.ObjectiveTag = C.strong(self.ObjectiveCard, "Eyebrow", "ТВОЯ ЦЕЛЬ", 10, Theme.Teal)
    self.Objective = C.strong(self.ObjectiveCard, "Title", "Готовим ограбление", 16)
    self.Subtitle = C.text(self.ObjectiveCard, "Description", "Загрузка данных игрока…", 13, Theme.Muted)
    self.Menu = C.button(canvas, "OpenMenu", "☰  Коллекция", function() self:open("Collection") end, "secondary")
    self.MenuHint = C.text(canvas, "MenuHint", "M / меню", 11, Theme.Muted)

    self.Energy = C.surface(canvas, "Energy")
    self.StaminaLabel = C.strong(self.Energy, "Title", "ЭНЕРГИЯ", 10, Theme.Muted)
    self.EnergyValue = C.text(self.Energy, "Value", "— / —", 11)
    self.StaminaTrack, self.Stamina = C.progress(self.Energy, "Stamina", Theme.Teal)
    self.Dash = C.strong(self.Energy, "Dash", "РЫВОК / ЗАГРУЗКА", 12, Theme.Muted)
    self.Controls = C.text(canvas, "Controls", "", 11, Theme.Muted)
    self.Controls.TextXAlignment = Enum.TextXAlignment.Center
    self.SaveMode = C.text(canvas, "SaveMode", "", 10, Theme.Amber)

    self.Notice = C.surface(canvas, "Toast", Theme.Raised)
    self.Notice.Visible = false
    self.Notice.ZIndex = 20
    self.NoticeText = C.strong(self.Notice, "Message", "", 14)
    self.NoticeText.ZIndex = 21
    self.NoticeText.TextXAlignment = Enum.TextXAlignment.Center

    local backdrop = Instance.new("TextButton")
    backdrop.Name = "ModalBackdrop"
    backdrop.Text = ""
    backdrop.AutoButtonColor = false
    backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
    backdrop:SetAttribute("BaseTransparency", 0.38)
    backdrop.BackgroundTransparency = 0.38 * GuiService.PreferredTransparency
    backdrop.BorderSizePixel = 0
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.ZIndex = 30
    backdrop.Visible = false
    backdrop.Selectable = false
    backdrop.Parent = canvas
    backdrop.Activated:Connect(function() self:close() end)
    self.Backdrop = backdrop
    self.Panel = C.surface(canvas, "MenuDrawer", Theme.Background)
    self.Panel.AnchorPoint = Vector2.new(0.5, 0.5)
    self.Panel.Position = UDim2.fromScale(0.5, 0.5)
    self.Panel.ZIndex = 31
    self.Panel.Visible = false
    self.Panel.Active = true
    self.Title = C.strong(self.Panel, "Title", "Коллекция", 23)
    self.Title.ZIndex = 32
    self.PanelSubtitle = C.text(self.Panel, "Subtitle", "Яйца и питомцы", 13, Theme.Muted)
    self.PanelSubtitle.ZIndex = 32
    self.Close = C.button(self.Panel, "Close", "×", function() self:close() end, "secondary")
    self.Close.TextSize = 24
    self.Close.ZIndex = 32
    self.NavFrame = scroller(self.Panel, "Navigation")
    self.NavFrame.ZIndex = 32
    self.NavFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
    self.NavFrame.ScrollBarThickness = 0
    for i, tab in ipairs(tabs) do
        local b = C.button(self.NavFrame, tab.Id, tab.Label, function() self:open(tab.Id, true) end, "secondary")
        b.ZIndex = 33
        self.Nav[tab.Id] = b
        b.LayoutOrder = i
    end
    self.Body = C.frame(self.Panel, "Body")
    self.Body.BackgroundTransparency = 1
    self.Body.ZIndex = 32
    self.Loading = C.strong(self.Body, "Loading", "Подключаем профиль…\nПодожди немного", 17, Theme.Muted)
    self.Loading.Size = UDim2.fromScale(1, 1)
    self.Loading.TextXAlignment = Enum.TextXAlignment.Center
    self.Loading.ZIndex = 33

    table.insert(self.Connections, canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:resize() end))
    table.insert(self.Connections, Input:GetPropertyChangedSignal("PreferredInput"):Connect(function() self:resize(); self:refreshHUD() end))
    table.insert(self.Connections, GuiService:GetPropertyChangedSignal("PreferredTransparency"):Connect(function()
        for _, object in ipairs(gui:GetDescendants()) do
            local base = object:GetAttribute("BaseTransparency")
            if base and object:IsA("GuiObject") then object.BackgroundTransparency = base * GuiService.PreferredTransparency end
        end
    end))
    table.insert(self.Connections, gui:GetAttributeChangedSignal("HatchOpen"):Connect(function()
        if gui:GetAttribute("HatchOpen") and self.ModalOpen then self:close() end
    end))
    table.insert(self.Connections, Input.InputBegan:Connect(function(key, processed)
        if Input:GetFocusedTextBox() then return end
        if self.ModalOpen and (key.KeyCode == Enum.KeyCode.Escape or key.KeyCode == Enum.KeyCode.ButtonB) then self:close(); return end
        if not processed and (key.KeyCode == Enum.KeyCode.M or key.KeyCode == Enum.KeyCode.ButtonSelect) then
            if self.ModalOpen then self:close() else self:open("Collection") end
        end
    end))
    local elapsed = 0
    table.insert(self.Connections, RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.25 then return end
        elapsed = 0
        if not gui.Parent then return end
        self:refreshDynamic()
    end))
    gui.Destroying:Connect(function()
        for _, connection in ipairs(self.Connections) do connection:Disconnect() end
    end)
    self:resize()
    return self
end
function UI:IsModalOpen(): boolean return self.ModalOpen end
function UI:resize()
    local size = self.Canvas.AbsoluteSize
    if size.X < 1 or size.Y < 1 then return end
    local m = Layout.measure(size.X, size.Y)
    self.Measure = m
    self.Compact = m.Portrait
    local margin = m.Margin
    local topH = if m.Short then 60 else 78
    C.place(self.Top, margin, margin, m.TopWidth, topH)
    C.place(self.Brand, 14, 8, m.TopWidth - 90, 15)
    C.place(self.Balance, 14, if m.Short then 24 else 25, m.TopWidth - 90, 29)
    self.Balance.TextSize = if m.TopWidth < 300 then 17 else 23
    C.place(self.Level, m.TopWidth - 73, 10, 60, 20)
    C.place(self.XPTrack, m.TopWidth - 73, 35, 59, 4)
    C.place(self.Combo, 14, 55, m.TopWidth - 28, 15)
    self.Combo.Visible = not m.Short
    local eventX = if m.Portrait then margin else m.Width - margin - m.EventWidth
    local eventY = if m.Portrait then margin + topH + 8 else margin
    local eventH = if m.Portrait or m.Short then 46 else 66
    C.place(self.EventCard, eventX, eventY, m.EventWidth, eventH)
    C.place(self.Event, 12, 7, m.EventWidth - 24, 16)
    C.place(self.Zone, 12, 25, m.EventWidth - 24, 16)
    C.place(self.EventBar, 12, eventH - 7, m.EventWidth - 24, 3)
    self.EventBar.Visible = not m.Portrait and not m.Short
    local objectiveY = if m.Portrait then eventY + eventH + 8 else margin + topH + 10
    C.place(self.ObjectiveCard, margin, objectiveY, m.ObjectiveWidth, 88)
    self.ObjectiveCard.Visible = not m.Short or not self.ModalOpen
    C.place(self.ObjectiveTag, 14, 8, m.ObjectiveWidth - 28, 13)
    C.place(self.Objective, 14, 23, m.ObjectiveWidth - 28, 24)
    C.place(self.Subtitle, 14, 50, m.ObjectiveWidth - 28, 32)
    self.Objective.TextSize = if m.ObjectiveWidth < 300 then 14 else 16
    C.place(self.Menu, margin, m.Height - (if m.Short then 64 else 122), 154, 48)
    C.place(self.MenuHint, margin + 2, m.Height - 70, 154, 16)
    self.MenuHint.Visible = not touch() and not m.Short
    local energyW = if m.Portrait then math.min(218, m.Width - 32) else 268
    if m.Short and touch() then C.place(self.Energy, margin, objectiveY + 98, energyW, 57)
    else C.place(self.Energy, (m.Width - energyW) / 2, m.Height - (if touch() then 72 else 82), energyW, 57) end
    C.place(self.StaminaLabel, 12, 7, 110, 14)
    C.place(self.EnergyValue, energyW - 86, 7, 74, 14)
    self.EnergyValue.TextXAlignment = Enum.TextXAlignment.Right
    C.place(self.StaminaTrack, 12, 25, energyW - 24, 5)
    C.place(self.Dash, 12, 34, energyW - 24, 16)
    C.place(self.Controls, (m.Width - math.min(600, m.Width - 16)) / 2, m.Height - 23, math.min(600, m.Width - 16), 15)
    self.Controls.Visible = not touch()
    C.place(self.SaveMode, margin, m.Height - (if touch() then 17 else 40), m.Width - margin * 2, 14)
    self.SaveMode.TextXAlignment = if m.Portrait then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
    local noticeW = math.min(520, m.Width - margin * 2)
    C.place(self.Notice, (m.Width - noticeW) / 2, m.Height - (if m.Portrait then 192 else 156), noticeW, 62)
    C.place(self.NoticeText, 14, 7, noticeW - 28, 48)
    self.Panel.Size = UDim2.fromOffset(m.PanelWidth, m.PanelHeight)
    C.place(self.Title, 20, 14, m.PanelWidth - 92, 32)
    C.place(self.PanelSubtitle, 20, 48, m.PanelWidth - 92, 22)
    C.place(self.Close, m.PanelWidth - 62, 16, 44, 44)
    if m.SideNav then
        C.place(self.NavFrame, 16, 90, 148, m.PanelHeight - 106)
        self.NavFrame.CanvasSize = UDim2.fromOffset(148, #tabs * 54)
        self.NavFrame.ScrollingDirection = Enum.ScrollingDirection.Y
        for i, tab in ipairs(tabs) do C.place(self.Nav[tab.Id], 0, (i - 1) * 54, 148, 46) end
    else
        C.place(self.NavFrame, 16, 82, m.PanelWidth - 32, 48)
        self.NavFrame.CanvasSize = UDim2.fromOffset(#tabs * 126 - 8, 48)
        self.NavFrame.ScrollingDirection = Enum.ScrollingDirection.X
        for i, tab in ipairs(tabs) do C.place(self.Nav[tab.Id], (i - 1) * 126, 0, 118, 46) end
    end
    C.place(self.Body, m.NavWidth + 16, if m.SideNav then 86 else 140, m.BodyWidth, m.BodyHeight)
    for _, view in pairs(self.Views) do self:layoutView(view) end
    self:updateViewports()
end
function UI:open(tab, keepOpen)
    if self.Gui:GetAttribute("HatchOpen") then return end
    if self.Tab == tab and self.ModalOpen and not keepOpen then self:close(); return end
    local known = false
    for _, item in ipairs(tabs) do
        if item.Id == tab then self.Title.Text = item.Label; self.PanelSubtitle.Text = item.Short; known = true end
    end
    if not known then return end
    local wasOpen = self.ModalOpen
    self.Tab = tab
    self.ModalOpen = true
    self.Gui:SetAttribute("ModalOpen", true)
    self.Backdrop.Visible = true
    self.Panel.Visible = true
    self:render()
    for id, button in pairs(self.Nav) do C.setButton(button, true, button.Text, if id == tab then "primary" else "secondary") end
    if not wasOpen and not reduced() then
        self.Panel.Position = UDim2.new(0.5, 0, 0.5, 12)
        Tween:Create(self.Panel, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.fromScale(0.5, 0.5)}):Play()
    end
    if gamepad() then GuiService.SelectedObject = self.Nav[tab] end
    self:resize()
end
function UI:close()
    self.ModalOpen = false
    self.Tab = nil
    self.Gui:SetAttribute("ModalOpen", false)
    self.Panel.Visible = false
    self.Backdrop.Visible = false
    for _, card in pairs(self.Cards) do self:clearViewport(card) end
    if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.Panel) then
        GuiService.SelectedObject = if gamepad() then self.Menu else nil
    end
    self:resize()
end
function UI:notice(message)
    self.NoticeSerial += 1
    local serial = self.NoticeSerial
    self.NoticeText.Text = tostring(message)
    self.Notice.Visible = true
    if not reduced() then
        self.Notice.BackgroundTransparency = 0.6
        Tween:Create(self.Notice, TweenInfo.new(0.18), {BackgroundTransparency = 0.08 * GuiService.PreferredTransparency}):Play()
    end
    task.delay(4, function()
        if self.Gui.Parent and serial == self.NoticeSerial then self.Notice.Visible = false end
    end)
end
function UI:send(action, argument, key)
    local pendingKey = key or action
    if self.Pending[pendingKey] and self.Pending[pendingKey] > os.clock() then return end
    self.Pending[pendingKey] = os.clock() + 1.5
    self.Remotes.Action:FireServer(action, argument)
    self:refreshDynamic()
end
function UI:isPending(key): boolean return (self.Pending[key] or 0) > os.clock() end
function UI:nearIncubator(): boolean
    local state = self.State
    if not state or not state.Base then return false end
    local character = Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then return false end
    local pos, base = state.Incubator, state.Base
    local target = if pos then Vector3.new(pos.X, pos.Y, pos.Z)
        elseif base.IncubatorX then Vector3.new(base.IncubatorX, base.IncubatorY, base.IncubatorZ)
        else Vector3.new(base.X - 8, 2.5, base.Z - 5)
    return (root.Position - target).Magnitude <= 13
end
function UI:newView(id)
    local root = C.frame(self.Body, id)
    root.Size = UDim2.fromScale(1, 1)
    root.BackgroundTransparency = 1
    root.Visible = false
    local view = {Id = id, Root = root, Rows = {}}
    self.Views[id] = view
    if id == "Collection" then
        local search = Instance.new("TextBox")
        search.Name = "Search"
        search.BackgroundColor3 = Theme.Raised
        search.BorderSizePixel = 0
        search.Font = Enum.Font.GothamMedium
        search.TextSize = 15
        search.TextColor3 = Theme.Text
        search.PlaceholderColor3 = Theme.Muted
        search.PlaceholderText = "Поиск по имени или редкости…"
        search.Text = ""
        search.ClearTextOnFocus = false
        search.TextXAlignment = Enum.TextXAlignment.Left
        search.Parent = root
        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 14)
        padding.PaddingRight = UDim.new(0, 14)
        padding.Parent = search
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 11)
        corner.Parent = search
        C.stroke(search)
        search:GetPropertyChangedSignal("Text"):Connect(function()
            self.Query = search.Text
            self:filterCollection()
        end)
        view.Search = search
        view.Filters = {}
        for i, filter in ipairs({{"All", "Все"}, {"Eggs", "Яйца"}, {"Pets", "Питомцы"}}) do
            local b = C.button(root, filter[1], filter[2], function()
                self.Filter = filter[1]
                self:filterCollection()
            end, "secondary")
            view.Filters[filter[1]] = b
            b.LayoutOrder = i
        end
        view.Scroll = scroller(root, "Inventory")
        local grid = Instance.new("UIGridLayout")
        grid.CellPadding = UDim2.fromOffset(12, 12)
        grid.SortOrder = Enum.SortOrder.LayoutOrder
        grid.Parent = view.Scroll
        view.Grid = grid
        view.Empty = C.text(root, "Empty", "", 16, Theme.Muted)
        view.Empty.TextXAlignment = Enum.TextXAlignment.Center
        view.Scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:updateViewports() end)
    else
        view.Scroll = scroller(root, "Content")
        view.Layout = list(view.Scroll, 12)
    end
    self:layoutView(view)
    return view
end
function UI:layoutView(view)
    local m = self.Measure
    if not m then return end
    local w, h = m.BodyWidth, m.BodyHeight
    if view.Id == "Collection" then
        C.place(view.Search, 0, 0, w - 6, 44)
        local filterW = math.floor((w - 18) / 3)
        for _, b in pairs(view.Filters) do C.place(b, (b.LayoutOrder - 1) * (filterW + 6), 52, filterW, 44) end
        C.place(view.Scroll, 0, 108, w, math.max(28, h - 108))
        C.place(view.Empty, 16, 114, w - 38, math.max(40, h - 132))
        view.Grid.CellSize = UDim2.fromOffset(m.CardWidth, m.CardHeight)
        for _, card in pairs(self.Cards) do self:layoutCard(card) end
    else
        C.place(view.Scroll, 0, 0, w, h)
        for _, row in pairs(view.Rows) do
            local rw = w - 10
            row.Frame.Size = UDim2.fromOffset(rw, row.Height or 144)
            if row.Tag then C.place(row.Tag, 16, 12, rw - 32, 16) end
            if row.Title then C.place(row.Title, 16, if row.Tag then 34 else 14, rw - 32, 30) end
            if row.Description then C.place(row.Description, 16, if row.Tag then 68 else 50, rw - 32, row.DescriptionHeight or 40) end
            if row.Button then C.place(row.Button, rw - 166, (row.Height or 144) - 56, 150, 44) end
            if row.Status then C.place(row.Status, 16, (row.Height or 144) - 52, math.max(58, rw - 198), 36) end
            if row.Track then C.place(row.Track, 16, (row.Height or 144) - 20, rw - 32, 6) end
        end
    end
end
function UI:row(view, key, title, detail, height, action)
    local row = view.Rows[key]
    if row then return row end
    row = {Frame = C.surface(view.Scroll, key), Height = height or 144}
    row.Frame.LayoutOrder = #view.Scroll:GetChildren()
    row.Title = C.strong(row.Frame, "Title", title, 17)
    row.Description = C.text(row.Frame, "Description", detail, 14, Theme.Muted)
    if action then
        row.Button = C.button(row.Frame, "Action", action.Label, action.Callback, action.Tone)
        row.Status = C.text(row.Frame, "Status", "", 12, Theme.Muted)
    end
    view.Rows[key] = row
    self:layoutView(view)
    return row
end
function UI:render()
    self.Loading.Visible = not self.Profile
    for id, view in pairs(self.Views) do view.Root.Visible = self.ModalOpen and self.Tab == id and self.Profile ~= nil end
    if not self.Tab or not self.Profile then return end
    local view = self.Views[self.Tab] or self:newView(self.Tab)
    view.Root.Visible = true
    self.List = view.Scroll
    local p = self.Profile
    if self.Tab == "Collection" then
        self:syncCollection(view)
        self.PanelSubtitle.Text = string.format("%d / %d яиц · %d / %d питомцев", #p.OwnedEggs, Economy.MaxStoredEggs, #p.Pets, Economy.MaxPets)
    elseif self.Tab == "Upgrades" then
        for _, id in ipairs({"Speed", "Stamina", "Dash", "Incubator", "Ward"}) do
            local def, copy = Upgrades[id], upgradeCopy[id]
            local row = self:row(view, id, def.Name, copy.Detail, 180, {
                Label = "Купить", Callback = function() self:send("Buy", id, "Buy:" .. id) end,
            })
            if not row.Tag then row.Tag = C.strong(row.Frame, "Eyebrow", copy.Tag, 10, Theme.Teal) end
        end
    elseif self.Tab == "Quests" then
        local deliveries = self:row(view, "Deliveries", "Доставь яйца", "Верни добычу на зелёный круг своего убежища.", 138)
        local hatches = self:row(view, "Hatches", "Вылупи питомца", "Запусти инкубацию у себя на базе и дождись вылупления.", 138)
        for _, row in ipairs({deliveries, hatches}) do
            if not row.Track then row.Track, row.Fill = C.progress(row.Frame, "Progress", Theme.Teal) end
        end
        self:row(view, "Reward", Layout.number(Economy.DailyReward) .. " монет + 50 XP", "Выполни обе цели. Новый маршрут каждый день в 00:00 UTC.", 166, {
            Label = "Забрать награду", Tone = "amber", Callback = function() self:send("Quest") end,
        })
    elseif self.Tab == "Achievements" then
        self:row(view, "Deliveries", "Доставлено яиц", "", 100)
        self:row(view, "Combo", "Лучшая серия", "", 100)
        self:row(view, "Escape", "Самый быстрый побег", "", 100)
        self:row(view, "Route", "Тропа тихих шагов", "", 114)
    elseif self.Tab == "Settings" then
        self:row(view, "LowFX", "Меньше эффектов", "Убирает частицы и локальный свет. Помогает на слабых устройствах.", 182, {
            Label = "", Callback = function() self:send("Setting", "LowFX", "Setting:LowFX") end, Tone = "secondary",
        })
        self:row(view, "Muted", "Звук игры", "Управляет игровыми звуковыми эффектами.", 160, {
            Label = "", Callback = function() self:send("Setting", "Muted", "Setting:Muted") end, Tone = "secondary",
        })
        self:row(view, "Input", "Твоё управление", "", 150)
        self:row(view, "Intercept", "Честный перехват", "Подойди к носителю вне хаба. У новичков есть защита первые 3 минуты. После перехвата жертва получает щит.", 152)
        self:row(view, "Save", "Сохранение прогресса", "", 132)
        self:row(view, "Accessibility", "Комфорт", "Интерфейс учитывает системные настройки размера текста, прозрачности и уменьшения анимаций Roblox.", 132)
    end
    self:layoutView(view)
    self:refreshDynamic()
    self:updateViewports()
end
function UI:makeCard(item, kind)
    local def = Catalog[if kind == "Eggs" then item.Id else item.EggId]
    if not def then return nil end
    local view = self.Views.Collection
    local card = {Uid = item.Uid, Item = item, Kind = kind, Def = def}
    card.Frame = C.surface(view.Scroll, item.Uid)
    card.RarityLine = C.frame(card.Frame, "Rarity", Theme.Rarity[def.Rarity] or Theme.Teal, 2)
    card.Preview = C.frame(card.Frame, "Preview", Theme.Background, 10)
    card.Preview.BackgroundTransparency = 0.15
    card.Preview.ClipsDescendants = true
    card.PreviewLabel = C.strong(card.Preview, "Fallback", if kind == "Eggs" then "ЯЙЦО" else "ПИТОМЕЦ", 10, Theme.Muted)
    card.PreviewLabel.TextXAlignment = Enum.TextXAlignment.Center
    card.PreviewLabel.Size = UDim2.fromScale(1, 1)
    card.Name = C.strong(card.Frame, "Name", if kind == "Eggs" then def.Name else def.PetName, 16)
    card.Rarity = C.strong(card.Frame, "RarityLabel", def.Rarity .. (if item.Mutation then " / ЛУННОЕ" else ""), 10, Theme.Rarity[def.Rarity])
    card.Detail = C.text(card.Frame, "Detail", "", 12, Theme.Muted)
    card.Button = C.button(card.Frame, "Action", "", function()
        self:send(if kind == "Eggs" then "Hatch" else "Equip", card.Uid, "Item:" .. card.Uid)
    end, "secondary")
    self.Cards[item.Uid] = card
    self:layoutCard(card)
    return card
end
function UI:layoutCard(card)
    if not self.Measure then return end
    local m = self.Measure
    local w, h = m.CardWidth, m.CardHeight
    card.Frame.Size = UDim2.fromOffset(w, h)
    C.place(card.RarityLine, 12, 0, math.min(46, w - 24), 3)
    if m.Columns == 1 then
        C.place(card.Preview, 12, 14, 100, 100)
        C.place(card.Name, 126, 15, w - 138, 40)
        C.place(card.Rarity, 126, 57, w - 138, 28)
        C.place(card.Detail, 126, 88, w - 138, 27)
        C.place(card.Button, 12, h - 50, w - 24, 44)
    else
        C.place(card.Preview, 12, 12, w - 24, 94)
        C.place(card.Name, 12, 114, w - 24, 38)
        C.place(card.Rarity, 12, 153, w - 24, 18)
        C.place(card.Detail, 12, 174, w - 24, 16)
        C.place(card.Button, 12, h - 50, w - 24, 44)
    end
end
function UI:syncCollection(view)
    local keep = {}
    local order = 0
    for _, kind in ipairs({"Eggs", "Pets"}) do
        local items = if kind == "Eggs" then self.Profile.OwnedEggs else self.Profile.Pets
        for index, item in ipairs(items) do
            order += 1
            local card = self.Cards[item.Uid]
            -- Hatching preserves UID. Rebuild only the changed presentation type,
            -- otherwise an egg's action closure/timer would survive into its pet card.
            if card and card.Kind ~= kind then
                if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(card.Frame) then GuiService.SelectedObject = self.Nav.Collection end
                card.Frame:Destroy()
                self.Cards[item.Uid] = nil
                card = nil
            end
            card = card or self:makeCard(item, kind)
            if card then
                keep[item.Uid] = true
                card.Item = item
                card.Index = index
                card.Frame.LayoutOrder = order
            end
        end
    end
    for uid, card in pairs(self.Cards) do
        if not keep[uid] then
            if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(card.Frame) then GuiService.SelectedObject = self.Nav.Collection end
            card.Frame:Destroy()
            self.Cards[uid] = nil
        end
    end
    self:filterCollection()
end
function UI:filterCollection()
    local view = self.Views.Collection
    if not view or not self.Profile then return end
    local count = 0
    for _, card in pairs(self.Cards) do
        local match = (self.Filter == "All" or self.Filter == card.Kind)
            and Layout.matches(card.Def.Name .. " " .. card.Def.PetName .. " " .. card.Def.Rarity, self.Query)
        card.Frame.Visible = match
        if match then count += 1 else self:clearViewport(card) end
    end
    for id, b in pairs(view.Filters) do C.setButton(b, true, b.Text, if id == self.Filter then "primary" else "secondary") end
    view.Empty.Visible = count == 0
    view.Empty.Text = if #self.Profile.OwnedEggs + #self.Profile.Pets == 0 then "Твоя история начинается с яйца.\n\nУкради его из гнезда и доставь на свою базу — оно появится здесь." else "Ничего не найдено.\nПопробуй другое имя или фильтр."
    -- Let UIGridLayout settle before testing the cells against the scroll window.
    task.defer(function() if self.Gui.Parent then self:updateViewports() end end)
end
function UI:clearViewport(card)
    if card.Viewport then card.Viewport:Destroy(); card.Viewport = nil end
    card.PreviewLabel.Visible = true
end
function UI:makeViewport(card)
    if card.Viewport then return end
    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "ModelPreview"
    viewport.BackgroundTransparency = 1
    viewport.Size = UDim2.fromScale(1, 1)
    viewport.Ambient = Color3.fromRGB(183, 193, 212)
    viewport.LightColor = Color3.fromRGB(255, 233, 200)
    viewport.LightDirection = Vector3.new(-1, -1, -2)
    viewport.Parent = card.Preview
    local camera = Instance.new("Camera")
    camera.FieldOfView = 32
    camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.8, -9), Vector3.new(0, 0.25, 0))
    camera.Parent = viewport
    viewport.CurrentCamera = camera
    local world = Instance.new("WorldModel")
    world.Parent = viewport
    local color = Color3.fromRGB(table.unpack(card.Def.Color))
    local function ball(name, size, position, tint)
        local part = Instance.new("Part")
        part.Name = name
        part.Shape = Enum.PartType.Ball
        part.Size = size
        part.Position = position
        part.Color = tint
        part.Material = Enum.Material.SmoothPlastic
        part.Anchored = true
        part.CanCollide = false
        part.CastShadow = false
        part.Parent = world
        return part
    end
    if card.Kind == "Eggs" then
        ball("Egg", Vector3.new(1.85, 2.5, 1.85), Vector3.zero, color)
        for _, spot in ipairs({Vector3.new(-0.48, 0.38, -0.75), Vector3.new(0.48, -0.2, -0.82), Vector3.new(0.12, 0.88, -0.54)}) do
            ball("Spot", Vector3.new(0.36, 0.4, 0.1), spot, color:Lerp(Theme.Background, 0.26))
        end
    else
        ball("Pet", Vector3.new(2, 1.75, 1.9), Vector3.zero, color)
        for _, x in ipairs({-1, 1}) do
            ball("Ear", Vector3.new(0.5, 1.2, 0.55), Vector3.new(x * 0.55, 1.03, 0), color)
            ball("Eye", Vector3.new(0.22, 0.3, 0.1), Vector3.new(x * 0.4, 0.15, -0.9), Theme.Background)
            ball("Glint", Vector3.new(0.065, 0.075, 0.055), Vector3.new(x * 0.4 - 0.035, 0.22, -0.97), Theme.Text)
        end
    end
    card.Viewport = viewport
    card.PreviewLabel.Visible = false
end
function UI:updateViewports()
    local view = self.Views.Collection
    if not view then return end
    local candidates = {}
    if self.ModalOpen and self.Tab == "Collection" then
        local top = view.Scroll.AbsolutePosition.Y
        local bottom = top + view.Scroll.AbsoluteSize.Y
        for _, card in pairs(self.Cards) do
            local y = card.Frame.AbsolutePosition.Y
            if card.Frame.Visible and y + card.Frame.AbsoluteSize.Y > top and y < bottom then table.insert(candidates, card) end
        end
    end
    table.sort(candidates, function(a, b) return a.Frame.LayoutOrder < b.Frame.LayoutOrder end)
    local active = {}
    -- Only the first eight visible cells own 3D worlds. Hidden menus own none.
    for i = 1, math.min(8, #candidates) do active[candidates[i].Uid] = true end
    for uid, card in pairs(self.Cards) do
        if active[uid] then self:makeViewport(card) else self:clearViewport(card) end
    end
end
function UI:refreshDynamic()
    local p = self.Profile
    if not p then return end
    local time = now(self)
    local near = self:nearIncubator()
    for _, card in pairs(self.Cards) do
        if card.Kind == "Eggs" then
            local egg = card.Item
            local enabled, label = Layout.eggAction(egg.ReadyAt, time, near, self:isPending("Item:" .. card.Uid))
            C.setButton(card.Button, enabled, label, if enabled then "primary" else "secondary")
            card.Detail.Text = if egg.ReadyAt > 0 then "Инкубация · " .. Layout.clock(egg.ReadyAt - time) else tostring(card.Def.HatchTime) .. " сек. · " .. Layout.number(card.Def.Value) .. " монет"
        else
            local active = card.Index == 1
            local pending = self:isPending("Item:" .. card.Uid)
            C.setButton(card.Button, not active and not pending, if active then "✓ Активен" elseif pending then "Выбираем…" else "Выбрать", "secondary")
            card.Detail.Text = if active then "+1 к восстановлению" else "Бонус активного питомца"
        end
    end
    local upgrades = self.Views.Upgrades
    if upgrades then
        for id, row in pairs(upgrades.Rows) do
            local def, level = Upgrades[id], p.Upgrades[id]
            local cost = Rules.cost(def.BaseCost, level)
            local enabled, label, reason = Layout.upgrade(level, def.Max, p.Coins, cost, self:isPending("Buy:" .. id))
            C.setButton(row.Button, enabled, label)
            row.Status.Text = "Уровень " .. level .. " / " .. def.Max .. (if reason == "funds" then "\nНужно ещё " .. Layout.number(cost - p.Coins) elseif reason == "max" then "\nВсе уровни открыты" else "")
        end
    end
    local quests = self.Views.Quests
    if quests then
        local q = p.QuestProgress
        local d, h, reward = quests.Rows.Deliveries, quests.Rows.Hatches, quests.Rows.Reward
        if d and h and reward then
            d.Title.Text = "Доставь яйца · " .. math.min(Economy.DailyDeliveryGoal, q.Deliveries) .. " / " .. Economy.DailyDeliveryGoal
            h.Title.Text = "Вылупи питомца · " .. math.min(Economy.DailyHatchGoal, q.Hatches) .. " / " .. Economy.DailyHatchGoal
            C.fill(d.Fill, q.Deliveries / Economy.DailyDeliveryGoal, not reduced())
            C.fill(h.Fill, q.Hatches / Economy.DailyHatchGoal, not reduced())
            local ready = Layout.daily(q.Deliveries, q.Hatches, q.Claimed, Economy.DailyDeliveryGoal, Economy.DailyHatchGoal)
            local pending = self:isPending("Quest")
            C.setButton(reward.Button, ready and not pending, if q.Claimed then "✓ Получено" elseif pending then "Получаем…" else "Забрать награду", "amber")
            reward.Status.Text = if q.Claimed then "До завтра!" elseif ready then "Награда готова" else "Выполни обе цели"
        end
    end
    local records = self.Views.Achievements
    if records then
        records.Rows.Deliveries.Description.Text = Layout.number(p.TotalDelivered) .. " успешных доставок"
        records.Rows.Combo.Description.Text = tostring(p.BestCombo) .. " яиц в серии"
        records.Rows.Escape.Description.Text = if p.BestEscape > 0 then string.format("%.1f сек.", p.BestEscape) else "Доставь первое яйцо и установи рекорд"
        records.Rows.Route.Description.Text = if p.Achievements.SecretRoute then "✓ Секретная тропа найдена" else "Поищи проход за поваленным деревом в лугах"
    end
    local settings = self.Views.Settings
    if settings then
        for _, key in ipairs({"LowFX", "Muted"}) do
            local row = settings.Rows[key]
            local pending = self:isPending("Setting:" .. key)
            local enabled = if key == "Muted" then not p.Settings.Muted else p.Settings.LowFX
            C.setButton(row.Button, not pending, if pending then "Сохраняем…" elseif enabled then "Включено" else "Выключено", "secondary")
            row.Status.Text = if key == "Muted" then "Звуковые эффекты" else "Экономия ресурсов"
        end
        settings.Rows.Input.Description.Text = if touch() then "Кнопки действий справа: бег, рывок и перехват. Взаимодействуй с гнёздами через подсказку на экране." elseif gamepad() then "L3 — бег · B — рывок · X — перехват\nD-pad ↓ — бросить · Select — меню\nA — выбрать · B — закрыть меню" else "Shift — бег · Q — рывок · E — взаимодействие\nG — бросить · F — перехват · M — меню\nEsc — закрыть меню"
        settings.Rows.Input.DescriptionHeight = 80
        settings.Rows.Save.Description.Text = if self.State and self.State.Memory then "Временная сессия: прогресс хранится в памяти сервера. Для постоянного сохранения нужна опубликованная игра с доступным DataStore." else "Прогресс сохраняется сервером каждые 45 секунд и при выходе из игры."
    end
end
function UI:refreshHUD()
    local p, state = self.Profile, self.State
    if not p or not state then return end
    self.Balance.Text = Layout.number(p.Coins) .. " монет"
    self.Level.Text = "LV " .. string.format("%02d", p.Level)
    self.Combo.Text = if (state.Combo or 0) > 0 then "СЕРИЯ ×" .. state.Combo .. "  /  БОНУС К ДОСТАВКЕ" else "Уровень " .. p.Level .. "  ·  " .. p.XP .. " / " .. (p.Level * 100) .. " XP"
    C.fill(self.XP, p.XP / (p.Level * 100), not reduced())
    local stamina, maximum = state.Stamina or 0, math.max(1, state.MaxStamina or 100)
    C.fill(self.Stamina, stamina / maximum, not reduced())
    self.Stamina.BackgroundColor3 = if stamina < Economy.DashCost then Theme.Amber else Theme.Teal
    self.EnergyValue.Text = math.floor(stamina) .. " / " .. maximum
    self.StaminaLabel.Text = if state.Sprint then "БЕГ / ЭНЕРГИЯ" else "ЭНЕРГИЯ"
    local dashKey = if touch() then "РЫВОК" elseif gamepad() then "B / РЫВОК" else "Q / РЫВОК"
    self.Dash.Text = dashKey .. (if (state.Dash or 0) > 0 then string.format("  %.1f сек.", state.Dash) elseif stamina < Economy.DashCost then " / НУЖНО 25" else " / ГОТОВ")
    self.Dash.TextColor3 = if (state.Dash or 0) > 0 or stamina < Economy.DashCost then Theme.Muted else Theme.Teal
    local protection, shield = state.Protection or 0, state.Shield or 0
    self.Zone.Text = if state.Safe then "● Хаб · безопасная зона" elseif protection > 0 then "Защита новичка · " .. Layout.clock(protection) elseif shield > 0 then "Щит от перехвата · " .. Layout.clock(shield) else "Луга · перехваты включены"
    self.Zone.TextColor3 = if state.Safe or protection > 0 or shield > 0 then Theme.Teal else Theme.Muted
    self.Event.Text = if state.Event then "ЗОЛОТАЯ ЛИХОРАДКА / " .. Layout.clock(state.EventSeconds or 0) else "ДО ЛИХОРАДКИ / " .. Layout.clock(state.EventSeconds or 0)
    C.fill(self.EventFill, (state.EventSeconds or 0) / (if state.Event then Economy.EventDuration else Economy.EventInterval), false)
    if state.Carry then
        local def = Catalog[state.Carry.Id]
        self.ObjectiveTag.Text = "ДОБЫЧА У ТЕБЯ"
        self.Objective.Text = if def then def.Name .. " · " .. def.Rarity else "Верни яйцо в убежище"
        self.Subtitle.Text = "На свой зелёный круг. Не попадайся хранителю!"
    elseif p.Tutorial == 0 then
        self.ObjectiveTag.Text = "ПЕРВОЕ ОГРАБЛЕНИЕ"
        self.Objective.Text = "Укради яйцо из гнезда"
        self.Subtitle.Text = if touch() then "Иди по золотой тропе. Удерживай подсказку у яйца." else "Иди по золотой тропе. Удерживай E у яйца."
    elseif #p.OwnedEggs > 0 and p.Tutorial < 3 then
        self.ObjectiveTag.Text = "НОВЫЙ ДРУГ"
        self.Objective.Text = "Вылупи первого питомца"
        self.Subtitle.Text = "Подойди к своему инкубатору. Яйца — в коллекции."
    else
        self.ObjectiveTag.Text = "СЛЕДУЮЩИЙ ПОБЕГ"
        self.Objective.Text = "Найди яйцо пореже"
        self.Subtitle.Text = if state.Event then "Лихорадка активна: +25% монет за доставку." else "Три гнезда, секретная тропа и бонус за серию."
    end
    self.MenuHint.Text = if gamepad() then "Select / меню" else "M / меню"
    local intercept = if (state.Intercept or 0) > 0 then "F перехват " .. math.ceil(state.Intercept) .. "с" else "F перехват"
    self.Controls.Text = if gamepad() then "L3 бег    B рывок    X перехват    ↓ бросить    Select меню" else "Shift бег    Q рывок    E взять    G бросить    " .. intercept
    self.SaveMode.Text = if state.Memory then "ВРЕМЕННАЯ СЕССИЯ · прогресс не сохранится после закрытия сервера" else ""
end
function UI:update(state)
    self.State = state
    if state.ServerTime then self.ServerClock = state.ServerTime; self.ClockReceived = os.clock() end
    if state.Profile then
        self.Profile = state.Profile
        -- Views and keyed inventory cells survive coin ticks, purchases, and tab changes.
        -- This preserves scroll positions, focused controls, and in-flight input.
        if self.ModalOpen then self:render() end
    end
    self:refreshHUD()
    self:refreshDynamic()
end
return UI
