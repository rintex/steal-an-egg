-- The harness injects Roblox boundaries into the real controller sources.
local passed = 0
local function check(name, callback)
    callback()
    passed += 1
    print("PASS client: " .. name)
end
local function signal()
    local listeners = {}
    return {
        Connect = function(_, callback)
            local connection = {Connected = true}
            function connection:Disconnect() self.Connected = false end
            table.insert(listeners, {Connection = connection, Callback = callback})
            return connection
        end,
        Fire = function(_, ...)
            for _, listener in ipairs(listeners) do
                if listener.Connection.Connected then listener.Callback(...) end
            end
        end,
    }
end
local function enums()
    return setmetatable({}, {__index = function(self, category)
        local values = setmetatable({}, {__index = function(items, key) rawset(items, key, key); return key end})
        rawset(self, category, values)
        return values
    end})
end
local enum = enums()
local udim = {new = function(...) return {...} end, fromOffset = function(...) return {...} end}
local color = {fromRGB = function(...) return {...} end}
local function environment()
    local input = {
        InputBegan = signal(), InputEnded = signal(), WindowFocusReleased = signal(),
        TextBoxFocused = signal(), GamepadDisconnected = signal(), TouchEnabled = true,
        PreferredInput = enum.PreferredInput.KeyboardAndMouse, Focus = nil, Changed = signal(),
    }
    function input:GetFocusedTextBox() return self.Focus end
    function input:GetPropertyChangedSignal() return self.Changed end
    local guiService = {MenuIsOpen = false, MenuOpened = signal(), MenuClosed = signal(), ReducedMotionEnabled = false, ReducedChanged = signal()}
    function guiService:GetPropertyChangedSignal() return self.ReducedChanged end
    local player = {CharacterAdded = signal(), CharacterRemoving = signal()}
    local cas = {Actions = {}, Removed = 0}
    function cas:BindAction(name, callback) self.Actions[name] = callback end
    function cas:UnbindAction(name) self.Actions[name] = nil; self.Removed += 1 end
    function cas:SetPosition() end
    function cas:SetTitle() end
    function cas:GetButton() return nil end
    local gui = {Attributes = {}, Signals = {}, Destroying = signal(), Parent = true}
    function gui:GetAttribute(name) return self.Attributes[name] end
    function gui:GetAttributeChangedSignal(name)
        if not self.Signals[name] then self.Signals[name] = signal() end
        return self.Signals[name]
    end
    function gui:SetAttribute(name, value)
        self.Attributes[name] = value
        self:GetAttributeChangedSignal(name):Fire()
    end
    local canvas = {AbsoluteSize = {X = 390, Y = 744}, Changed = signal()}
    function canvas:GetPropertyChangedSignal() return self.Changed end
    local action = {Sent = {}}
    function action:FireServer(...) table.insert(self.Sent, {...}) end
    local services = {
        ContextActionService = cas, UserInputService = input, GuiService = guiService,
        Players = {LocalPlayer = player}, ReplicatedStorage = {Shared = {Config = {EconomyConfig = {DashCost = 25}}}},
        SoundService = {}, Debris = {}, RunService = {PreSimulation = signal()},
    }
    local gameMock = {GetService = function(_, name) return assert(services[name], name) end}
    return {Input = input, GuiService = guiService, Player = player, CAS = cas, UI = {Gui = gui, Canvas = canvas},
        Remotes = {Action = action}, Game = gameMock, Services = services, Sent = action.Sent}
end
local function input(key, kind) return {KeyCode = key, UserInputType = kind or enum.UserInputType.Keyboard} end
local function movementEnv()
    local env = environment()
    local controller = makeMovement(env.Game, function(value) return value end, enum, udim, color).start(env.Remotes, env.UI)
    controller:update({Dash = 0, Stamina = 100, Carry = false, Safe = true, Protection = 180})
    return env, controller
end
check("keyboard sprint stays hold-to-run on touch-capable devices", function()
    local env, controller = movementEnv()
    env.Input.InputBegan:Fire(input(enum.KeyCode.LeftShift), false)
    assert(controller.Sprint and env.Sent[#env.Sent][2] == true)
    env.Input.InputBegan:Fire(input(enum.KeyCode.RightShift), false)
    env.Input.InputEnded:Fire(input(enum.KeyCode.LeftShift))
    assert(controller.Sprint, "second held Shift must continue sprint")
    env.Input.InputEnded:Fire(input(enum.KeyCode.RightShift))
    assert(not controller.Sprint and env.Sent[#env.Sent][2] == false)
    controller:Destroy()
end)
check("processed hardware inputs do not trigger gameplay", function()
    local env, controller = movementEnv()
    env.Input.InputBegan:Fire(input(enum.KeyCode.LeftShift), true)
    env.Input.InputBegan:Fire(input(enum.KeyCode.Q), true)
    assert(#env.Sent == 0)
    env.Input.InputBegan:Fire(input(enum.KeyCode.Q), false)
    assert(#env.Sent == 1 and env.Sent[1][1] == "Dash")
    controller:Destroy()
end)
check("touch sprint toggles and focus loss clears its state", function()
    local env, controller = movementEnv()
    env.CAS.Actions.HeistSprint("HeistSprint", enum.UserInputState.Begin, input("", enum.UserInputType.Touch))
    assert(controller.Sprint)
    env.Input.WindowFocusReleased:Fire()
    assert(not controller.Sprint and next(controller.Sources) == nil)
    controller:Destroy()
end)
check("opening either modal cancels sprint and closing B cannot dash", function()
    for _, attribute in ipairs({"ModalOpen", "HatchOpen"}) do
        local env, controller = movementEnv()
        env.Input.InputBegan:Fire(input(enum.KeyCode.LeftShift), false)
        env.UI.Gui:SetAttribute(attribute, true)
        assert(not controller.Sprint)
        local before = #env.Sent
        env.Input.InputBegan:Fire(input(enum.KeyCode.Q), false)
        env.UI.Gui:SetAttribute(attribute, false)
        env.Input.InputBegan:Fire(input(enum.KeyCode.ButtonB, enum.UserInputType.Gamepad1), false)
        assert(#env.Sent == before, "modal dismissal must not also dash")
        controller:Destroy()
    end
end)
check("respawn, depleted stamina and text entry clear sprint", function()
    local env, controller = movementEnv()
    env.Input.InputBegan:Fire(input(enum.KeyCode.LeftShift), false)
    env.Player.CharacterAdded:Fire({})
    assert(not controller.Sprint)
    env.Input.InputBegan:Fire(input(enum.KeyCode.LeftShift), false)
    controller:update({Dash = 0, Stamina = 0, Carry = false, Safe = true, Protection = 180})
    assert(not controller.Sprint)
    env.Input.InputBegan:Fire(input(enum.KeyCode.LeftShift), false)
    env.Input.Focus = {}; env.Input.TextBoxFocused:Fire()
    assert(not controller.Sprint)
    local before = #env.Sent
    env.Input.InputBegan:Fire(input(enum.KeyCode.Q), false)
    assert(#env.Sent == before)
    controller:Destroy()
end)
check("destroy unbinds all actions and hardware listeners", function()
    local env, controller = movementEnv()
    controller:Destroy(); controller:Destroy()
    local before = #env.Sent
    env.Input.InputBegan:Fire(input(enum.KeyCode.Q), false)
    assert(#env.Sent == before and env.CAS.Removed == 4 and next(env.CAS.Actions) == nil)
end)

local function effectsEnv()
    local env = environment()
    local camera = {FieldOfView = 70, Parent = true}
    local world = {CurrentCamera = camera, DescendantAdded = signal(), CameraChanged = signal()}
    function world:GetPropertyChangedSignal() return self.CameraChanged end
    function world:GetDescendants() return {} end
    local queue, tweens = {}, {}
    local taskMock = {delay = function(_, callback) table.insert(queue, callback) end}
    local tweenService = {}
    function tweenService:Create(target, _, goal)
        local tween = {Cancelled = false}
        function tween:Cancel() self.Cancelled = true end
        function tween:Play() for key, value in pairs(goal) do target[key] = value end end
        table.insert(tweens, tween)
        return tween
    end
    env.Services.TweenService = tweenService
    env.Services.ReplicatedStorage.Shared.Config = {EggConfig = {}, AudioConfig = {Dash = ""}}
    local function cf(values) return setmetatable(values, {__mul = function(base, rotation) return cf({Base = base, Rotation = rotation}) end}) end
    local cframe = {Angles = function(x, y, z) return cf({X = x, Y = y, Z = z}) end}
    local controller = makeEffects(env.Game, world, function(value) return value end, color, enum,
        taskMock, {new = function(...) return {...} end}, cframe).new(env.UI)
    return env, controller, world, queue, tweens
end
check("consecutive dash effects restore the original FOV", function()
    local _, controller, world, queue, tweens = effectsEnv()
    controller:dash(); controller:dash()
    assert(world.CurrentCamera.FieldOfView == 75, "overlapping feedback must not accumulate FOV")
    assert(tweens[1].Cancelled)
    queue[1]()
    assert(world.CurrentCamera.FieldOfView == 75, "stale dash callback must not change current feedback")
    queue[2](); queue[3]()
    assert(world.CurrentCamera.FieldOfView == 70 and controller.DashCamera == nil)
    controller:Destroy()
end)
check("camera replacement and reduced motion cancel FOV feedback", function()
    local env, controller, world, queue = effectsEnv()
    local previous = world.CurrentCamera
    controller:dash()
    world.CurrentCamera = {FieldOfView = 82, Parent = true}; world.CameraChanged:Fire()
    assert(previous.FieldOfView == 70 and world.CurrentCamera.FieldOfView == 82)
    queue[1]()
    assert(world.CurrentCamera.FieldOfView == 82)
    controller:dash()
    env.GuiService.ReducedMotionEnabled = true; env.GuiService.ReducedChanged:Fire()
    assert(world.CurrentCamera.FieldOfView == 82)
    controller:dash()
    assert(world.CurrentCamera.FieldOfView == 82)
    controller:Destroy()
end)
check("R6 and R15 carry joints do not drift and restore on respawn", function()
    local env, controller = effectsEnv()
    local motors = {}
    for _, name in ipairs({"Right Shoulder", "Left Shoulder", "RightShoulder", "LeftShoulder"}) do
        local base = {Original = name}
        setmetatable(base, {__mul = function(original, rotation) return {Base = original, Rotation = rotation} end})
        local motor = {Name = name, C0 = base, Parent = true, Original = base}
        function motor:IsA(kind) return kind == "Motor6D" end
        table.insert(motors, motor)
    end
    env.Player.Character = {GetDescendants = function() return motors end}
    controller:carry(true)
    for _ = 1, 30 do controller:poseArms() end
    for _, motor in ipairs(motors) do assert(motor.C0.Base == motor.Original, "pose must use original joint C0") end
    env.Player.CharacterRemoving:Fire()
    for _, motor in ipairs(motors) do assert(motor.C0 == motor.Original) end
    assert(not controller.Carrying and #controller.Arms == 0)
    controller:Destroy()
end)
print(string.format("PASS client regression tests: %d", passed))
