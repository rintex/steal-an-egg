--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {}
for _, name in ipairs({"Action", "State", "Notice", "Effect"}) do
    remotes[name] = remotesFolder:WaitForChild(name)
end
local controllers = script.Parent.Controllers
local ui = require(controllers.UIController).new(remotes)
local effects = require(controllers.EffectsController).new(ui)
local tutorial = require(controllers.TutorialController).new()
local movement = require(controllers.MovementController).start(remotes, ui)
local connections = {}
local profileAcknowledged = false
table.insert(connections, remotes.State.OnClientEvent:Connect(function(state)
    ui:update(state)
    if state.Profile and not profileAcknowledged then
        profileAcknowledged = true
        -- The first Ready may precede a slow profile load. Acknowledge receipt
        -- so the server can stop resending the full inventory every snapshot.
        remotes.Action:FireServer("Ready")
    end
    if ui.Profile then
        effects:settings(ui.Profile.Settings)
        tutorial:update(state, ui.Profile)
    end
    effects:carry(state.Carry ~= false and state.Carry ~= nil)
    movement:update(state)
end))
table.insert(connections, remotes.Notice.OnClientEvent:Connect(function(message, sound)
    ui:notice(message)
    if sound then effects:sound(sound) end
end))
table.insert(connections, remotes.Effect.OnClientEvent:Connect(function(kind, id)
    if kind == "Dash" then effects:dash() elseif kind == "Hatch" then effects:hatch(id) end
end))
script.Destroying:Connect(function()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    movement:Destroy(); effects:Destroy(); tutorial:Destroy()
    if ui.Destroy then ui:Destroy() else ui.Gui:Destroy() end
end)
remotes.Action:FireServer("Ready")
