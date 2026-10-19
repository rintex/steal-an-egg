--!strict
local Tween = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Theme = require(script.Parent.UITheme)
local C = {}
local function round(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 14)
    corner.Parent = object
end
function C.stroke(object, color, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Theme.Stroke
    stroke.Transparency = transparency or 0.45
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = object
    return stroke
end
function C.frame(parent, name, color, radius)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.BackgroundColor3 = color or Theme.Surface
    frame.BorderSizePixel = 0
    frame.Parent = parent
    round(frame, radius)
    return frame
end
function C.surface(parent, name, color)
    local frame = C.frame(parent, name, color)
    frame:SetAttribute("BaseTransparency", 0.08)
    frame.BackgroundTransparency = 0.08 * GuiService.PreferredTransparency
    C.stroke(frame)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(202, 213, 229))
    gradient.Rotation = 100
    gradient.Parent = frame
    return frame
end
function C.text(parent, name, value, size, color)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.Text = value
    label.Font = Enum.Font.GothamMedium
    label.TextSize = size or 15
    label.TextColor3 = color or Theme.Text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextWrapped = true
    label.Parent = parent
    return label
end
function C.strong(parent, name, value, size, color)
    local label = C.text(parent, name, value, size, color)
    label.Font = Enum.Font.GothamBold
    return label
end
function C.button(parent, name, value, callback, tone)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Text = value
    button.Font = Enum.Font.GothamBold
    button.TextSize = 14
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.TextWrapped = true
    button:SetAttribute("Enabled", true)
    button:SetAttribute("Tone", tone or "primary")
    button.Parent = parent
    round(button, 11)
    local ring = C.stroke(button, Theme.Teal, 0.95)
    ring.Name = "FocusRing"
    local hover = false
    local selected = false
    local function emphasis()
        local enabled = button:GetAttribute("Enabled") == true
        ring.Transparency = if selected then 0 elseif hover and enabled then 0.2 else 0.95
        ring.Thickness = if selected then 2 else 1
    end
    button.MouseEnter:Connect(function() hover = true; emphasis() end)
    button.MouseLeave:Connect(function() hover = false; emphasis() end)
    button.SelectionGained:Connect(function() selected = true; emphasis() end)
    button.SelectionLost:Connect(function() selected = false; emphasis() end)
    button.MouseButton1Down:Connect(function()
        if button:GetAttribute("Enabled") then
            if GuiService.ReducedMotionEnabled then button.BackgroundTransparency = 0.23 * GuiService.PreferredTransparency
            else Tween:Create(button, TweenInfo.new(0.08), {BackgroundTransparency = 0.23 * GuiService.PreferredTransparency}):Play() end
        end
    end)
    button.MouseButton1Up:Connect(function()
        if GuiService.ReducedMotionEnabled then button.BackgroundTransparency = 0
        else Tween:Create(button, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play() end
    end)
    button.Activated:Connect(function()
        if button:GetAttribute("Enabled") then callback() end
    end)
    C.setButton(button, true, value, tone)
    return button
end
function C.setButton(button, enabled, value, tone)
    button:SetAttribute("Enabled", enabled)
    button.Active = enabled
    button.Selectable = enabled
    button.Text = value
    local kind = tone or button:GetAttribute("Tone")
    button.BackgroundColor3 = if not enabled then Theme.Disabled elseif kind == "primary" then Theme.Teal elseif kind == "amber" then Theme.Amber else Theme.Raised
    button.TextColor3 = if enabled and (kind == "primary" or kind == "amber") then Theme.Background elseif enabled then Theme.Text else Theme.Muted
end
function C.progress(parent, name, color)
    local track = C.frame(parent, name, Theme.Disabled, 4)
    local fill = C.frame(track, "Fill", color or Theme.Teal, 4)
    fill.Size = UDim2.fromScale(0, 1)
    fill:SetAttribute("Fraction", 0)
    return track, fill
end
function C.fill(fill, fraction, animate)
    local value = math.clamp(fraction, 0, 1)
    if fill:GetAttribute("Fraction") == value then return end
    fill:SetAttribute("Fraction", value)
    local size = UDim2.fromScale(value, 1)
    if animate then Tween:Create(fill, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {Size = size}):Play()
    else fill.Size = size end
end
function C.place(object, x, y, width, height)
    object.Position = UDim2.fromOffset(math.round(x), math.round(y))
    object.Size = UDim2.fromOffset(math.max(0, math.round(width)), math.max(0, math.round(height)))
end
return C
