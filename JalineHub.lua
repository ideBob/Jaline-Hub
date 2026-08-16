--[[
    Jaline Dash
    Premium Loop Dash + White Body ESP
    Fully advanced & polished
]]

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local CONFIG = {
    AnimDetectId = "10503381238",
    BlockAnimId  = "10471478869",

    -- Body parts we highlight
    BodyParts = {
        "Head",
        "Torso", "UpperTorso", "LowerTorso", -- R6 + R15
        "Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "Right Arm", "RightUpperArm", "RightLowerArm", "RightHand",
        "Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot",
    },

    ESPColor = Color3.fromRGB(255, 255, 255), -- Pure white
}

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local STATE = {
    -- Jaline Dash
    Enabled          = false,
    Debounce         = false,
    Blocked          = false,
    WaitDetect       = 0.30,
    WaitRemote       = 0.10,
    LockDuration     = 1.50,
    Cooldown         = 1.00,
    TargetRadius     = 50,
    Responsiveness   = 650,

    -- Body ESP
    BodyESP          = false,
}

----------------------------------------------------------------
-- INTERNAL
----------------------------------------------------------------
local connections = {
    anim         = nil,
    blockChecker = nil,
    charAdded    = nil,
    espLoop      = nil,
}

local activeLockCleanup = nil
local espHighlights     = {} -- [Model] = {Highlight instances}

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

    -- Jump
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
-- BODY ESP (Premium White)
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
    if espHighlights[model] then return end -- already has

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

    -- also players (in case Live is empty)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                targets[plr.Character] = true
                applyESPToModel(plr.Character)
            end
        end
    end

    -- cleanup dead / left
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

    -- also react to new characters
    local function onCharAdded(char)
        task.wait(0.4)
        if STATE.BodyESP then
            applyESPToModel(char)
        end
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
    for _, conn in pairs(connections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    connections.anim         = nil
    connections.blockChecker = nil
    connections.charAdded    = nil

    cancelActiveLock()
    STATE.Debounce = false
    STATE.Blocked  = false
end

player.CharacterRemoving:Connect(function()
    cancelActiveLock()
end)

----------------------------------------------------------------
-- UI (Rayfield Gen2)
----------------------------------------------------------------
local Window = Rayfield:CreateWindow({
    name = "Jaline Dash",
    subtitle = "Premium Edition",
    theme = "frost",
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "JalineDash",
    },
})

local Tab = Window:CreateTab({
    name = "Jaline Dash",
    icon = 93364949241311,
})

-- Main Toggle
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

-- Body ESP Button (Toggle style for proper on/off)
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

-- Settings
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

print("[Jaline Dash] Loaded • Premium Edition")
