--[[
    Jaline Dash
    Premium Edition
    Black + Light Purple • Centered Star Crosshair • Falling Stars
]]

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")

local player = Players.LocalPlayer

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local CONFIG = {
    AnimDetectId = "10503381238",
    BlockAnimId  = "10471478869",

    BodyParts = {
        "Head",
        "Torso", "UpperTorso", "LowerTorso",
        "Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "Right Arm", "RightUpperArm", "RightLowerArm", "RightHand",
        "Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot",
    },

    ESPColor     = Color3.fromRGB(255, 255, 255),

    -- Visuals
    StarAssetId  = "rbxassetid://241594819",
    CrosshairId  = "rbxassetid://241594819",
    LightPurple  = Color3.fromRGB(190, 145, 255),
    LightPurple2 = Color3.fromRGB(160, 110, 255),
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
local connections = {
    anim         = nil,
    blockChecker = nil,
    charAdded    = nil,
    espLoop      = nil,
    starLoop     = nil,
}

local activeLockCleanup = nil
local espHighlights     = {}
local crosshairGui      = nil
local starGui           = nil

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------
local function getCharParts()
    local char = player.Character
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if humanoid and hrp then
        return char, humanoid, hrp
    end
    return nil
end

local function fireDashQW()
    local char = player.Character
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
local function findBestTarget(maxRadius)
    maxRadius = maxRadius or STATE.TargetRadius
    local live = Workspace:FindFirstChild("Live")
    if not live then return nil end

    local _, _, hrp = getCharParts()
    if not hrp then return nil end

    local bestRoot, bestDist = nil, maxRadius

    for _, model in ipairs(live:GetChildren()) do
        if model:IsA("Model") and model ~= player.Character then
            local root = model:FindFirstChild("HumanoidRootPart")
            local hum  = model:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local isValid = (model.Name == "Weakest Dummy") or (Players:GetPlayerFromCharacter(model) ~= nil)
                if isValid then
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
local function modelHasBlockingAnim(model)
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    if not hum then return false end

    local ok, tracks = pcall(function()
        return hum:GetPlayingAnimationTracks()
    end)

    if ok and tracks then
        for _, t in ipairs(tracks) do
            if t.Animation then
                local aid = tostring(t.Animation.AnimationId or "")
                if aid:find(CONFIG.BlockAnimId, 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

local function scanForBlockingAnim()
    local live = Workspace:FindFirstChild("Live")
    if not live then return false end

    for _, model in ipairs(live:GetChildren()) do
        if model:IsA("Model") and model ~= player.Character then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and modelHasBlockingAnim(model) then
                return true
            end
        end
    end
    return false
end

----------------------------------------------------------------
-- HORIZONTAL LOCK
----------------------------------------------------------------
local function startHorizontalLock(targetRoot, duration)
    if not targetRoot or not targetRoot.Parent or duration <= 0 then return nil end

    local _, humanoid, hrp = getCharParts()
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

local function cancelActiveLock()
    if activeLockCleanup then
        pcall(activeLockCleanup)
        activeLockCleanup = nil
    end
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.AutoRotate = true end) end
    end
end

----------------------------------------------------------------
-- MAIN SEQUENCE
----------------------------------------------------------------
local function runSequence()
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

    local char, humanoid, hrp = getCharParts()
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

    fireDashQW()

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

    local target = findBestTarget()
    if target and not STATE.Blocked then
        activeLockCleanup = startHorizontalLock(target, lockDur)
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
        if activeLockCleanup then
            pcall(activeLockCleanup)
            activeLockCleanup = nil
        end
    end)

    task.delay(cooldown, function()
        STATE.Debounce = false
    end)
end

----------------------------------------------------------------
-- ANIMATION + BLOCK
----------------------------------------------------------------
local function onAnimationPlayed(track)
    if not STATE.Enabled or STATE.Debounce or STATE.Blocked then return end
    if not track or not track.Animation then return end

    local id = tostring(track.Animation.AnimationId or "")
    if id == CONFIG.AnimDetectId or id:find(CONFIG.AnimDetectId, 1, true) then
        task.spawn(runSequence)
    end
end

local function hookCharacter()
    if connections.anim then
        pcall(function() connections.anim:Disconnect() end)
        connections.anim = nil
    end

    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        connections.anim = humanoid.AnimationPlayed:Connect(onAnimationPlayed)
    end
end

local function startBlockChecker()
    if connections.blockChecker then
        pcall(function() connections.blockChecker:Disconnect() end)
        connections.blockChecker = nil
    end

    local last = 0
    connections.blockChecker = RunService.Heartbeat:Connect(function(dt)
        if not STATE.Enabled then return end
        last += dt
        if last < 0.12 then return end
        last = 0

        local found = scanForBlockingAnim()
        if found and not STATE.Blocked then
            STATE.Blocked = true
            cancelActiveLock()
            if connections.anim then
                pcall(function() connections.anim:Disconnect() end)
                connections.anim = nil
            end
        elseif not found and STATE.Blocked then
            STATE.Blocked = false
            if STATE.Enabled then hookCharacter() end
        end
    end)
end

----------------------------------------------------------------
-- BODY ESP
----------------------------------------------------------------
local function clearESP()
    for model, list in pairs(espHighlights) do
        for _, h in ipairs(list) do
            pcall(function() h:Destroy() end)
        end
    end
    table.clear(espHighlights)
end

local function applyESPToModel(model)
    if not model or not model:IsA("Model") or model == player.Character then return end
    if espHighlights[model] then return end

    local list = {}
    for _, partName in ipairs(CONFIG.BodyParts) do
        local part = model:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            local highlight = Instance.new("Highlight")
            highlight.Name = "JalineBodyESP"
            highlight.Adornee = part
            highlight.FillColor = CONFIG.ESPColor
            highlight.OutlineColor = CONFIG.ESPColor
            highlight.FillTransparency = 0.55
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = part
            table.insert(list, highlight)
        end
    end

    if #list > 0 then
        espHighlights[model] = list
    end
end

local function removeESPFromModel(model)
    local list = espHighlights[model]
    if list then
        for _, h in ipairs(list) do
            pcall(function() h:Destroy() end)
        end
        espHighlights[model] = nil
    end
end

local function updateBodyESP()
    if not STATE.BodyESP then
        clearESP()
        return
    end

    local live = Workspace:FindFirstChild("Live")
    local targets = {}

    if live then
        for _, model in ipairs(live:GetChildren()) do
            if model:IsA("Model") and model ~= player.Character then
                local hum = model:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    targets[model] = true
                    applyESPToModel(model)
                end
            end
        end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                targets[plr.Character] = true
                applyESPToModel(plr.Character)
            end
        end
    end

    for model in pairs(espHighlights) do
        if not targets[model] or not model.Parent then
            removeESPFromModel(model)
        end
    end
end

local function startBodyESP()
    if connections.espLoop then return end

    connections.espLoop = RunService.Heartbeat:Connect(function()
        if STATE.BodyESP then
            updateBodyESP()
        end
    end)

    local function onCharAdded(char)
        task.wait(0.4)
        if STATE.BodyESP then applyESPToModel(char) end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            plr.CharacterAdded:Connect(onCharAdded)
            if plr.Character then onCharAdded(plr.Character) end
        end
    end

    Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(onCharAdded)
    end)
end

local function stopBodyESP()
    if connections.espLoop then
        pcall(function() connections.espLoop:Disconnect() end)
        connections.espLoop = nil
    end
    clearESP()
end

----------------------------------------------------------------
-- CENTERED STAR CROSSHAIR + FALLING STARS
----------------------------------------------------------------
local function createCrosshair()
    if crosshairGui then
        pcall(function() crosshairGui:Destroy() end)
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "JalineCrosshair"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 1000

    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then
        gui.Parent = player:WaitForChild("PlayerGui")
    end

    -- Perfect center crosshair
    local star = Instance.new("ImageLabel")
    star.Name = "Crosshair"
    star.AnchorPoint = Vector2.new(0.5, 0.5)
    star.Position = UDim2.fromScale(0.5, 0.5)
    star.Size = UDim2.fromOffset(22, 22)          -- small but not too small
    star.BackgroundTransparency = 1
    star.Image = CONFIG.CrosshairId
    star.ImageColor3 = CONFIG.LightPurple
    star.ImageTransparency = 0.08
    star.ScaleType = Enum.ScaleType.Fit
    star.ZIndex = 10
    star.Parent = gui

    -- Very subtle breathing so it feels alive but stays usable as crosshair
    task.spawn(function()
        while star and star.Parent do
            local t1 = TweenService:Create(star, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Size = UDim2.fromOffset(24, 24),
                ImageTransparency = 0.02
            })
            t1:Play()
            t1.Completed:Wait()

            local t2 = TweenService:Create(star, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Size = UDim2.fromOffset(20, 20),
                ImageTransparency = 0.14
            })
            t2:Play()
            t2.Completed:Wait()
        end
    end)

    crosshairGui = gui
end

local function createFallingStars()
    if starGui then
        pcall(function() starGui:Destroy() end)
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "JalineFallingStars"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 5          -- behind crosshair & most UI

    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then
        gui.Parent = player:WaitForChild("PlayerGui")
    end

    local container = Instance.new("Frame")
    container.Name = "StarContainer"
    container.Size = UDim2.fromScale(1, 1)
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.ClipsDescendants = true
    container.Parent = gui

    starGui = gui

    -- Refined falling stars (slower, fewer, prettier)
    connections.starLoop = RunService.Heartbeat:Connect(function()
        if not container or not container.Parent then return end

        -- lower spawn rate for elegance
        if math.random() > 0.028 then return end

        local star = Instance.new("ImageLabel")
        star.Name = "FallingStar"
        star.BackgroundTransparency = 1
        star.Image = CONFIG.StarAssetId
        star.ImageColor3 = CONFIG.LightPurple
        star.ImageTransparency = math.random(25, 60) / 100
        star.ScaleType = Enum.ScaleType.Fit
        star.ZIndex = 1

        local size = math.random(8, 16)
        star.Size = UDim2.fromOffset(size, size)

        local startX = math.random()
        star.Position = UDim2.new(startX, 0, -0.06, 0)
        star.Parent = container

        local duration = math.random(45, 90) / 10   -- slower fall
        local drift = (math.random() - 0.5) * 0.18

        local tween = TweenService:Create(star, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
            Position = UDim2.new(startX + drift, 0, 1.08, 0),
            ImageTransparency = 1,
            Rotation = math.random(-50, 50)
        })
        tween:Play()

        tween.Completed:Connect(function()
            if star then star:Destroy() end
        end)
    end)
end

----------------------------------------------------------------
-- SETUP / UNLOAD
----------------------------------------------------------------
local function dashSetup()
    hookCharacter()
    startBlockChecker()

    if connections.charAdded then
        pcall(function() connections.charAdded:Disconnect() end)
    end

    connections.charAdded = player.CharacterAdded:Connect(function()
        task.wait(0.7)
        if STATE.Enabled then hookCharacter() end
    end)
end

local function dashUnload()
    for name, conn in pairs(connections) do
        if name ~= "starLoop" and conn then
            pcall(function() conn:Disconnect() end)
            connections[name] = nil
        end
    end

    cancelActiveLock()
    STATE.Debounce = false
    STATE.Blocked  = false
end

player.CharacterRemoving:Connect(function()
    cancelActiveLock()
end)

----------------------------------------------------------------
-- CUSTOM THEME (Black + Light Purple)
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

-- Create crosshair + falling stars
task.defer(function()
    createCrosshair()
    createFallingStars()
end)

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
            dashSetup()
            Window:Notify({
                title = "Jaline Dash",
                content = "ENABLED",
                duration = 2.5,
            })
        else
            dashUnload()
            Window:Notify({
                title = "Jaline Dash",
                content = "DISABLED",
                duration = 2.5,
            })
        end
    end,
})

Tab:CreateToggle({
    name = "Body ESP",
    description = "White highlight on Head, Torso, Arms & Legs",
    flag = "BodyESP",
    value = false,
    callback = function(value)
        STATE.BodyESP = value
        if value then
            startBodyESP()
            updateBodyESP()
            Window:Notify({
                title = "Body ESP",
                content = "ENABLED • White",
                duration = 2,
            })
        else
            stopBodyESP()
            Window:Notify({
                title = "Body ESP",
                content = "DISABLED",
                duration = 2,
            })
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

print("[Jaline Dash] Loaded • Centered Crosshair + Falling Stars")
