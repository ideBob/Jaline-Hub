--[[
    Jaline Dash
    Premium Edition
    Black + Light Purple • Falling Stars • Decorative Pulsing Star
    Optimized Highlight Performance
]]

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace    = game:GetService("Workspace")
local CoreGui      = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local CONFIG = {
    AnimDetectId = "10503381238",
    BlockAnimId  = "10471478869",

    StarAssetId  = "rbxassetid://241594819",
    GifAssetId   = "rbxassetid://5860841663",

    LightPurple  = Color3.fromRGB(190, 145, 255),
    LightPurple2 = Color3.fromRGB(160, 110, 255),
    ESPColor     = Color3.fromRGB(255, 255, 255),

    ESPUpdateRate = 0.20, -- seconds between full ESP scans
}

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local STATE = {
    Enabled        = false,
    Debounce       = false,
    Blocked        = false,
    WaitDetect     = 0.30,
    WaitRemote     = 0.10,
    LockDuration   = 1.50,
    Cooldown       = 1.00,
    TargetRadius   = 50,
    Responsiveness = 650,
    BodyESP        = false,
}

----------------------------------------------------------------
-- INTERNAL
----------------------------------------------------------------
local Connections = {}
local ActiveLockCleanup = nil
local ESPObjects = {} -- [Model] = Highlight
local VisualGui = nil

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------
local function GetCharParts()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if humanoid and hrp then
        return char, humanoid, hrp
    end
    return nil, nil, nil
end

local function FireDashQW()
    local char = LocalPlayer.Character
    if not char then return end
    local comm = char:FindFirstChild("Communicate")
    if comm and typeof(comm.FireServer) == "function" then
        pcall(function()
            comm:FireServer({
                Dash = Enum.KeyCode.W,
                Key  = Enum.KeyCode.Q,
                Goal = "KeyPress"
            })
        end)
    end
end

----------------------------------------------------------------
-- TARGET FINDING
----------------------------------------------------------------
local function FindBestTarget()
    local live = Workspace:FindFirstChild("Live")
    if not live then return nil end

    local _, _, hrp = GetCharParts()
    if not hrp then return nil end

    local bestRoot, bestDist = nil, STATE.TargetRadius

    for _, model in ipairs(live:GetChildren()) do
        if model:IsA("Model") and model ~= LocalPlayer.Character then
            local root = model:FindFirstChild("HumanoidRootPart")
            local hum  = model:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local valid = (model.Name == "Weakest Dummy") or (Players:GetPlayerFromCharacter(model) ~= nil)
                if valid then
                    local dist = (root.Position - hrp.Position).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        bestRoot = root
                    end
                end
            end
        end
    end
    return bestRoot
end

----------------------------------------------------------------
-- BLOCK DETECTION
----------------------------------------------------------------
local function HasBlockingAnim(model)
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    if not hum then return false end

    local ok, tracks = pcall(function()
        return hum:GetPlayingAnimationTracks()
    end)

    if ok and tracks then
        for _, track in ipairs(tracks) do
            if track.Animation then
                local id = tostring(track.Animation.AnimationId or "")
                if id:find(CONFIG.BlockAnimId, 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

local function IsAnyoneBlocking()
    local live = Workspace:FindFirstChild("Live")
    if not live then return false end

    for _, model in ipairs(live:GetChildren()) do
        if model:IsA("Model") and model ~= LocalPlayer.Character then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and HasBlockingAnim(model) then
                return true
            end
        end
    end
    return false
end

----------------------------------------------------------------
-- HORIZONTAL LOCK
----------------------------------------------------------------
local function StartHorizontalLock(targetRoot, duration)
    if not targetRoot or not targetRoot.Parent or duration <= 0 then return nil end

    local _, humanoid, hrp = GetCharParts()
    if not hrp or not humanoid then return nil end

    local startTime = tick()
    local conn

    conn = RunService.RenderStepped:Connect(function(dt)
        if STATE.Blocked or not STATE.Enabled then
            if conn then conn:Disconnect() end
            return
        end
        if not (targetRoot.Parent and hrp.Parent) then
            if conn then conn:Disconnect() end
            return
        end

        local hrpPos = hrp.Position
        local lookAt = Vector3.new(targetRoot.Position.X, hrpPos.Y, targetRoot.Position.Z)

        if (lookAt - hrpPos).Magnitude >= 0.015 then
            local desired = CFrame.new(hrpPos, lookAt)
            local resp = math.clamp(STATE.Responsiveness, 1, 10000)

            if resp >= 900 then
                pcall(function() hrp.CFrame = desired end)
            else
                local alpha = 1 - math.exp(-0.028 * resp * dt)
                pcall(function()
                    hrp.CFrame = hrp.CFrame:Lerp(desired, math.clamp(alpha, 0, 1))
                end)
            end
        end

        if tick() - startTime >= duration then
            if conn then conn:Disconnect() end
        end
    end)

    return function()
        if conn then pcall(function() conn:Disconnect() end) end
    end
end

local function CancelActiveLock()
    if ActiveLockCleanup then
        pcall(ActiveLockCleanup)
        ActiveLockCleanup = nil
    end
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum.AutoRotate = true end)
        end
    end
end

----------------------------------------------------------------
-- MAIN SEQUENCE
----------------------------------------------------------------
local function RunSequence()
    if STATE.Debounce or not STATE.Enabled or STATE.Blocked then return end
    STATE.Debounce = true

    local waitDetect = STATE.WaitDetect
    local waitRemote = STATE.WaitRemote
    local lockDur    = STATE.LockDuration
    local cooldown   = STATE.Cooldown

    local t0 = tick()
    while tick() - t0 < waitDetect do
        if not STATE.Enabled or STATE.Blocked then
            STATE.Debounce = false
            return
        end
        RunService.Heartbeat:Wait()
    end

    if not STATE.Enabled or STATE.Blocked then
        STATE.Debounce = false
        return
    end

    local char, humanoid, hrp = GetCharParts()
    if not humanoid or not hrp then
        STATE.Debounce = false
        return
    end

    local prevAuto = humanoid.AutoRotate
    pcall(function() humanoid.AutoRotate = false end)

    pcall(function()
        humanoid.Jump = true
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end)

    FireDashQW()

    local t2 = tick()
    while tick() - t2 < waitRemote do
        if not STATE.Enabled or STATE.Blocked then
            pcall(function() if humanoid.Parent then humanoid.AutoRotate = prevAuto end end)
            STATE.Debounce = false
            return
        end
        RunService.Heartbeat:Wait()
    end

    if not STATE.Enabled or STATE.Blocked then
        pcall(function() if humanoid.Parent then humanoid.AutoRotate = prevAuto end end)
        STATE.Debounce = false
        return
    end

    local target = FindBestTarget()
    if target and not STATE.Blocked then
        ActiveLockCleanup = StartHorizontalLock(target, lockDur)
    end

    task.spawn(function()
        local keepUntil = tick() + math.max(lockDur, 1.0)
        while tick() < keepUntil do
            if not STATE.Enabled or STATE.Blocked then break end
            pcall(function()
                if humanoid and humanoid.Parent then
                    humanoid.AutoRotate = false
                end
            end)
            RunService.Heartbeat:Wait()
        end
        pcall(function()
            if humanoid and humanoid.Parent then
                humanoid.AutoRotate = prevAuto
            end
        end)
    end)

    task.delay(lockDur, function()
        if ActiveLockCleanup then
            pcall(ActiveLockCleanup)
            ActiveLockCleanup = nil
        end
    end)

    task.delay(cooldown, function()
        STATE.Debounce = false
    end)
end

----------------------------------------------------------------
-- ANIMATION + BLOCK
----------------------------------------------------------------
local function OnAnimationPlayed(track)
    if not STATE.Enabled or STATE.Debounce or STATE.Blocked then return end
    if not track or not track.Animation then return end

    local id = tostring(track.Animation.AnimationId or "")
    if id == CONFIG.AnimDetectId or id:find(CONFIG.AnimDetectId, 1, true) then
        task.spawn(RunSequence)
    end
end

local function HookCharacter()
    if Connections.Anim then
        pcall(function() Connections.Anim:Disconnect() end)
        Connections.Anim = nil
    end

    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        Connections.Anim = humanoid.AnimationPlayed:Connect(OnAnimationPlayed)
    end
end

local function StartBlockChecker()
    if Connections.BlockChecker then
        pcall(function() Connections.BlockChecker:Disconnect() end)
        Connections.BlockChecker = nil
    end

    local last = 0
    Connections.BlockChecker = RunService.Heartbeat:Connect(function(dt)
        if not STATE.Enabled then return end
        last += dt
        if last < 0.12 then return end
        last = 0

        local found = IsAnyoneBlocking()
        if found and not STATE.Blocked then
            STATE.Blocked = true
            CancelActiveLock()
            if Connections.Anim then
                pcall(function() Connections.Anim:Disconnect() end)
                Connections.Anim = nil
            end
        elseif not found and STATE.Blocked then
            STATE.Blocked = false
            if STATE.Enabled then HookCharacter() end
        end
    end)
end

----------------------------------------------------------------
-- BODY ESP (OPTIMIZED)
----------------------------------------------------------------
local function ClearAllESP()
    for model, highlight in pairs(ESPObjects) do
        pcall(function() highlight:Destroy() end)
    end
    table.clear(ESPObjects)
end

local function ApplyESP(model)
    if not model or model == LocalPlayer.Character then return end
    if ESPObjects[model] and ESPObjects[model].Parent then return end

    if ESPObjects[model] then
        pcall(function() ESPObjects[model]:Destroy() end)
        ESPObjects[model] = nil
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "JalineESP"
    highlight.Adornee = model
    highlight.FillColor = CONFIG.ESPColor
    highlight.OutlineColor = CONFIG.ESPColor
    highlight.FillTransparency = 0.55
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = model

    ESPObjects[model] = highlight

    -- Auto-clean when model leaves the game
    local conn
    conn = model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            if ESPObjects[model] then
                pcall(function() ESPObjects[model]:Destroy() end)
                ESPObjects[model] = nil
            end
            if conn then conn:Disconnect() end
        end
    end)
end

local function RemoveESP(model)
    local highlight = ESPObjects[model]
    if highlight then
        pcall(function() highlight:Destroy() end)
        ESPObjects[model] = nil
    end
end

local function UpdateBodyESP()
    if not STATE.BodyESP then
        ClearAllESP()
        return
    end

    local active = {}

    local live = Workspace:FindFirstChild("Live")
    if live then
        for _, model in ipairs(live:GetChildren()) do
            if model:IsA("Model") and model ~= LocalPlayer.Character then
                local hum = model:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    active[model] = true
                    ApplyESP(model)
                end
            end
        end
    else
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    active[plr.Character] = true
                    ApplyESP(plr.Character)
                end
            end
        end
    end

    for model in pairs(ESPObjects) do
        if not active[model] or not model.Parent then
            RemoveESP(model)
        end
    end
end

local function StartBodyESP()
    if Connections.ESP then return end

    local timer = 0
    Connections.ESP = RunService.Heartbeat:Connect(function(dt)
        if not STATE.BodyESP then return end

        timer += dt
        if timer < CONFIG.ESPUpdateRate then return end
        timer = 0

        UpdateBodyESP()
    end)

    local function onChar(char)
        task.delay(0.4, function()
            if STATE.BodyESP and char and char.Parent then
                ApplyESP(char)
            end
        end)
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            plr.CharacterAdded:Connect(onChar)
            if plr.Character then onChar(plr.Character) end
        end
    end

    Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(onChar)
    end)

    UpdateBodyESP()
end

local function StopBodyESP()
    if Connections.ESP then
        pcall(function() Connections.ESP:Disconnect() end)
        Connections.ESP = nil
    end
    ClearAllESP()
end

----------------------------------------------------------------
-- FALLING STARS + DECORATIVE PULSING STAR
----------------------------------------------------------------
local function CreateVisuals()
    if VisualGui then
        pcall(function() VisualGui:Destroy() end)
        VisualGui = nil
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "JalineVisuals"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 8

    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.fromScale(1, 1)
    container.BackgroundTransparency = 1
    container.ClipsDescendants = true
    container.Parent = gui

    VisualGui = gui

    local decor = Instance.new("ImageLabel")
    decor.Name = "DecorStar"
    decor.AnchorPoint = Vector2.new(0.5, 0.5)
    decor.Position = UDim2.new(0.92, 0, 0.09, 0)
    decor.Size = UDim2.fromOffset(88, 88)
    decor.BackgroundTransparency = 1
    decor.Image = CONFIG.GifAssetId
    decor.ImageColor3 = CONFIG.LightPurple
    decor.ImageTransparency = 0.22
    decor.ScaleType = Enum.ScaleType.Fit
    decor.ZIndex = 3
    decor.Parent = container

    task.spawn(function()
        while decor and decor.Parent do
            local up = TweenService:Create(decor, TweenInfo.new(1.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Size = UDim2.fromOffset(102, 102),
                ImageTransparency = 0.06
            })
            up:Play()
            up.Completed:Wait()

            local down = TweenService:Create(decor, TweenInfo.new(1.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Size = UDim2.fromOffset(84, 84),
                ImageTransparency = 0.35
            })
            down:Play()
            down.Completed:Wait()
        end
    end)

    if Connections.StarLoop then
        pcall(function() Connections.StarLoop:Disconnect() end)
    end

    Connections.StarLoop = RunService.Heartbeat:Connect(function()
        if not container or not container.Parent then return end
        if math.random() > 0.031 then return end

        local star = Instance.new("ImageLabel")
        star.Name = "FallingStar"
        star.BackgroundTransparency = 1
        star.Image = CONFIG.StarAssetId
        star.ImageColor3 = CONFIG.LightPurple
        star.ImageTransparency = math.random(18, 52) / 100
        star.ScaleType = Enum.ScaleType.Fit
        star.ZIndex = 1

        local size = math.random(9, 17)
        star.Size = UDim2.fromOffset(size, size)
        star.Position = UDim2.new(math.random(), 0, -0.05, 0)
        star.Parent = container

        local duration = math.random(42, 88) / 10
        local drift = (math.random() - 0.5) * 0.18

        local tw = TweenService:Create(star, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
            Position = UDim2.new(star.Position.X.Scale + drift, 0, 1.08, 0),
            ImageTransparency = 1,
            Rotation = math.random(-55, 55)
        })
        tw:Play()
        tw.Completed:Connect(function()
            star:Destroy()
        end)
    end)
end

----------------------------------------------------------------
-- SETUP / UNLOAD
----------------------------------------------------------------
local function DashSetup()
    HookCharacter()
    StartBlockChecker()

    if Connections.CharAdded then
        pcall(function() Connections.CharAdded:Disconnect() end)
    end

    Connections.CharAdded = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.65)
        if STATE.Enabled then HookCharacter() end
    end)
end

local function DashUnload()
    for name, conn in pairs(Connections) do
        if name ~= "StarLoop" and conn then
            pcall(function() conn:Disconnect() end)
            Connections[name] = nil
        end
    end
    CancelActiveLock()
    STATE.Debounce = false
    STATE.Blocked  = false
end

LocalPlayer.CharacterRemoving:Connect(CancelActiveLock)

----------------------------------------------------------------
-- THEME
----------------------------------------------------------------
local CustomTheme = {
    WindowColor = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 8, 12)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 10, 22)),
    }),
    ShadowColor = Color3.fromRGB(0, 0, 0),
    LiveAnimation = true,

    ContentColor = Color3.fromRGB(230, 225, 255),
    TitlingColor = Color3.fromRGB(210, 185, 255),
    ActionColor  = CONFIG.LightPurple,

    TabColor = Color3.fromRGB(220, 200, 255),
    TabBackground = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 14, 28)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 18, 42)),
    }),
    TabStroke = ColorSequence.new(CONFIG.LightPurple, CONFIG.LightPurple2),

    ElementGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 14, 24)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 16, 34)),
    }),
    ElementStroke = Color3.fromRGB(70, 50, 110),
    ElementStrokeHover = CONFIG.LightPurple,

    AccentColor = CONFIG.LightPurple,
    AccentStroke = CONFIG.LightPurple2,
    AccentGlow = 0.35,

    SliderBackground = Color3.fromRGB(25, 20, 40),
    SliderProgress = ColorSequence.new(CONFIG.LightPurple, CONFIG.LightPurple2),
    SliderHandle = Color3.fromRGB(235, 220, 255),

    ToggleTrack = Color3.fromRGB(30, 25, 45),
    ToggleKnobOff = Color3.fromRGB(90, 80, 120),
}

----------------------------------------------------------------
-- UI
----------------------------------------------------------------
local Window = Rayfield:CreateWindow({
    name = "Jaline Dash",
    subtitle = "Premium Edition",
    theme = CustomTheme,
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "JalineDash",
    },
})

task.defer(CreateVisuals)

local Tab = Window:CreateTab({
    name = "Jaline Dash",
    icon = 93364949241311,
})

Tab:CreateToggle({
    name = "Jaline Dash",
    description = "Advanced loop dash system",
    flag = "JalineDashEnabled",
    value = false,
    callback = function(value)
        STATE.Enabled = value
        if value then
            DashSetup()
            Window:Notify({ title = "Jaline Dash", content = "ENABLED", duration = 2.5 })
        else
            DashUnload()
            Window:Notify({ title = "Jaline Dash", content = "DISABLED", duration = 2.5 })
        end
    end,
})

Tab:CreateToggle({
    name = "Body ESP",
    description = "Optimized white body highlight (one Highlight per character)",
    flag = "BodyESP",
    value = false,
    callback = function(value)
        STATE.BodyESP = value
        if value then
            StartBodyESP()
            Window:Notify({ title = "Body ESP", content = "ENABLED • White", duration = 2 })
        else
            StopBodyESP()
            Window:Notify({ title = "Body ESP", content = "DISABLED", duration = 2 })
        end
    end,
})

Tab:CreateSlider({
    name = "Detect Delay",
    flag = "DetectDelay",
    range = {0, 1.5},
    increment = 0.05,
    value = STATE.WaitDetect,
    suffix = "s",
    callback = function(v) STATE.WaitDetect = v end,
})

Tab:CreateSlider({
    name = "Flick Delay",
    flag = "FlickDelay",
    range = {0, 0.8},
    increment = 0.05,
    value = STATE.WaitRemote,
    suffix = "s",
    callback = function(v) STATE.WaitRemote = v end,
})

Tab:CreateSlider({
    name = "Lock Duration",
    flag = "LockDuration",
    range = {0.3, 3},
    increment = 0.1,
    value = STATE.LockDuration,
    suffix = "s",
    callback = function(v) STATE.LockDuration = v end,
})

Tab:CreateSlider({
    name = "Smoothness",
    description = "Higher = snappier lock",
    flag = "Smoothness",
    range = {50, 1000},
    increment = 10,
    value = STATE.Responsiveness,
    callback = function(v) STATE.Responsiveness = v end,
})

print("[Jaline Dash] Loaded • Optimized Highlight Performance")
