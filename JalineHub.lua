--[[
    Jaline Hub - Loop Dash v2 (Fully Fixed & Advanced)
    Author: Jaline
]]

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")

local player = Players.LocalPlayer

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local CONFIG = {
    loopReworkAnimDetectId = "10503381238",
    loopReworkBlockAnimId  = "10471478869",
}

----------------------------------------------------------------
-- STATE (fully initialized)
----------------------------------------------------------------
local STATE = {
    -- Core LoopDash
    loopRework              = false,
    loopReworkDebounce      = false,
    loopReworkBlocked       = false,
    loopReworkWaitDetect    = 0.3,   -- seconds
    loopReworkWaitJump      = 0.0,   -- seconds
    loopReworkWaitRemote    = 0.1,   -- seconds
    loopReworkLockDuration  = 1.5,   -- seconds
    loopReworkCooldown      = 1.0,   -- seconds
    loopReworkTargetRadius  = 50,
    loopReworkResponsiveness = 600,  -- higher = snappier

    -- Force Jump / Oreo
    ForceJumpEnabled        = false,
    ForceJumpUpwardVelocity = 52,
    ForceJumpDebounceTime   = 0.18,  -- real seconds
}

----------------------------------------------------------------
-- UI
----------------------------------------------------------------
local Win = WindUI:CreateWindow({
    Title               = "Jaline Hub",
    Icon                = "rbxassetid://88536674439005",
    Author              = "Jaline",
    Folder              = "JalineHub",
    Size                = UDim2.fromOffset(650, 550),
    Theme               = "Dark",
    HideSearchBar       = false,
    NewElements         = true,
    SideBarWidth        = 200,
    HidePanelBackground = false,
})

local Tabs = {
    LoopDashv2 = Win:Tab({
        Title  = "Loop Dash v2",
        Icon   = "lucide:refresh-ccw-dot",
        Opened = true
    }),
}

Tabs.LoopDashv2:Paragraph({
    Title     = "Loop Dash v2 / Rework",
    Desc      = "Advanced loop dash with force jump support (oreo tech ready).",
    Image     = "lucide:refresh-ccw-dot",
    ImageSize = 20,
    Color     = Color3.fromHex("#4ecdc4")
})

Tabs.LoopDashv2:Toggle({
    Title = "LoopDash v2 Enabled",
    Flag  = "Save23",
    Value = STATE.loopRework,
    Callback = function(state)
        STATE.loopRework = state
        if state then
            loopReworkSetup()
        else
            loopReworkUnload()
        end
        WindUI:Notify({
            Title    = "LoopDash v2",
            Content  = state and "ENABLED" or "DISABLED",
            Icon     = state and "lucide:check" or "lucide:x",
            Duration = 2
        })
    end
})

Tabs.LoopDashv2:Toggle({
    Title = "Jump Assist (Oreo)",
    Flag  = "Save24",
    Desc  = "Forces a strong upward velocity for oreo tech.",
    Value = STATE.ForceJumpEnabled,
    Callback = function(state)
        STATE.ForceJumpEnabled = state
        if state then
            forceJumpSetup()
        else
            forceJumpUnload()
        end
    end
})

Tabs.LoopDashv2:Slider({
    Title = "Jump Height",
    Flag  = "Save25",
    Value = { Min = 10, Max = 100, Default = STATE.ForceJumpUpwardVelocity },
    Callback = function(value)
        STATE.ForceJumpUpwardVelocity = value
    end
})

Tabs.LoopDashv2:Slider({
    Title = "Detect Delay (s)",
    Flag  = "Save26",
    Value = { Min = 0, Max = 2, Default = STATE.loopReworkWaitDetect },
    Callback = function(value)
        STATE.loopReworkWaitDetect = value
    end
})

Tabs.LoopDashv2:Slider({
    Title = "First Flick Delay (s)",
    Flag  = "Save27",
    Value = { Min = 0, Max = 1, Default = STATE.loopReworkWaitRemote },
    Callback = function(value)
        STATE.loopReworkWaitRemote = value
    end
})

Tabs.LoopDashv2:Slider({
    Title = "Lock Duration (s)",
    Flag  = "Save28",
    Value = { Min = 0.2, Max = 3, Default = STATE.loopReworkLockDuration },
    Callback = function(value)
        STATE.loopReworkLockDuration = value
    end
})

Tabs.LoopDashv2:Slider({
    Title = "Smoothness / Responsiveness",
    Flag  = "Save29",
    Value = { Min = 1, Max = 1000, Default = STATE.loopReworkResponsiveness },
    Callback = function(value)
        STATE.loopReworkResponsiveness = value
    end
})

----------------------------------------------------------------
-- INTERNAL STATE
----------------------------------------------------------------
local connections = {
    anim          = nil,
    blockChecker  = nil,
    charAdded     = nil,
    forceCharAdded = nil,
}

local activeLockCleanup = nil
local forceJumpCanUse   = true
local forceJumpChar     = nil
local forceJumpHum      = nil
local forceJumpHRP      = nil

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------
local function safeDestroy(obj)
    if obj and obj.Parent then
        pcall(function() obj:Destroy() end)
    end
end

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
        local args = {{
            Dash = Enum.KeyCode.W,
            Key  = Enum.KeyCode.Q,
            Goal = "KeyPress"
        }}
        pcall(function()
            comm:FireServer(unpack(args))
        end)
    end
end

----------------------------------------------------------------
-- TARGET FINDING
----------------------------------------------------------------
local function findBestTarget(maxRadius)
    maxRadius = maxRadius or STATE.loopReworkTargetRadius
    local live = Workspace:FindFirstChild("Live")
    if not live then return nil end

    local _, _, hrp = getCharParts()
    if not hrp then return nil end

    local bestRoot = nil
    local bestDist = maxRadius

    for _, model in ipairs(live:GetChildren()) do
        if model:IsA("Model") and model ~= player.Character then
            local root = model:FindFirstChild("HumanoidRootPart")
            local hum  = model:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local isValid = (model.Name == "Weakest Dummy") or (Players:GetPlayerFromCharacter(model) ~= nil)
                if isValid then
                    local dist = (root.Position - hrp.Position).Magnitude
                    if dist <= bestDist then
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
    if not model or not model.Parent then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return false end

    local ok, tracks = pcall(function()
        return hum:GetPlayingAnimationTracks()
    end)

    if ok and tracks then
        for _, t in ipairs(tracks) do
            if t and t.Animation then
                local aid = tostring(t.Animation.AnimationId or "")
                if aid:find(CONFIG.loopReworkBlockAnimId, 1, true) then
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
                return true, model
            end
        end
    end
    return false
end

----------------------------------------------------------------
-- HORIZONTAL LOCK (completely rewritten - clean & stable)
----------------------------------------------------------------
local function startHorizontalLock(targetRoot, duration)
    if not targetRoot or not targetRoot.Parent or duration <= 0 then
        return nil
    end

    local char, humanoid, hrp = getCharParts()
    if not hrp or not humanoid then return nil end

    local startTime = tick()
    local conn

    conn = RunService.RenderStepped:Connect(function(dt)
        if STATE.loopReworkBlocked or not STATE.loopRework then
            if conn then conn:Disconnect() end
            return
        end
        if not (targetRoot and targetRoot.Parent and hrp and hrp.Parent) then
            if conn then conn:Disconnect() end
            return
        end

        local hrpPos = hrp.Position
        local lookAt = Vector3.new(targetRoot.Position.X, hrpPos.Y, targetRoot.Position.Z)

        if (lookAt - hrpPos).Magnitude < 0.01 then
            -- already facing
        else
            local desired = CFrame.new(hrpPos, lookAt)
            local resp = math.clamp(STATE.loopReworkResponsiveness, 1, 10000)

            if resp >= 950 then
                -- instant
                pcall(function() hrp.CFrame = desired end)
            else
                local alpha = 1 - math.exp(-0.025 * resp * dt)
                alpha = math.clamp(alpha, 0, 1)
                pcall(function()
                    hrp.CFrame = hrp.CFrame:Lerp(desired, alpha)
                end)
            end
        end

        if tick() - startTime >= duration then
            if conn then conn:Disconnect() end
        end
    end)

    return function()
        if conn then
            pcall(function() conn:Disconnect() end)
        end
    end
end

local function cancelActiveLock()
    if activeLockCleanup then
        pcall(activeLockCleanup)
        activeLockCleanup = nil
    end

    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            pcall(function() humanoid.AutoRotate = true end)
        end
    end
end

----------------------------------------------------------------
-- FORCE JUMP SYSTEM
----------------------------------------------------------------
local function forceJumpUpdateCharacter(char)
    forceJumpChar = char
    if char then
        forceJumpHum = char:FindFirstChildOfClass("Humanoid")
        forceJumpHRP = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    else
        forceJumpHum = nil
        forceJumpHRP = nil
    end
end

local function forceJumpDoJump(humanoid, hrp)
    if not STATE.ForceJumpEnabled then return false end
    if not forceJumpCanUse then return true end

    forceJumpCanUse = false

    pcall(function()
        if humanoid and humanoid.Parent then
            humanoid.PlatformStand = false
            humanoid.Jump = true
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)

    if hrp and hrp.Parent then
        local upward = STATE.ForceJumpUpwardVelocity or 52
        pcall(function()
            local curr = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(curr.X, upward, curr.Z)
        end)
        -- fallback for older engines
        pcall(function()
            local v = hrp.Velocity
            hrp.Velocity = Vector3.new(v.X, upward, v.Z)
        end)
    end

    task.delay(STATE.ForceJumpDebounceTime, function()
        forceJumpCanUse = true
    end)

    return true
end

local function forceJumpSetup()
    if connections.forceCharAdded then return end

    connections.forceCharAdded = player.CharacterAdded:Connect(function(char)
        task.wait(0.6)
        forceJumpUpdateCharacter(char)
    end)

    if player.Character then
        forceJumpUpdateCharacter(player.Character)
    end
end

local function forceJumpUnload()
    if connections.forceCharAdded then
        pcall(function() connections.forceCharAdded:Disconnect() end)
        connections.forceCharAdded = nil
    end
    forceJumpChar = nil
    forceJumpHum  = nil
    forceJumpHRP  = nil
    forceJumpCanUse = true
end

----------------------------------------------------------------
-- MAIN SEQUENCE
----------------------------------------------------------------
local function runSequence()
    if STATE.loopReworkDebounce or not STATE.loopRework or STATE.loopReworkBlocked then
        return
    end
    STATE.loopReworkDebounce = true

    local waitDetect  = STATE.loopReworkWaitDetect
    local waitJump    = STATE.loopReworkWaitJump
    local waitRemote  = STATE.loopReworkWaitRemote
    local lockDur     = STATE.loopReworkLockDuration
    local cooldown    = STATE.loopReworkCooldown

    -- Detect delay
    local t0 = tick()
    while tick() - t0 < waitDetect do
        if not STATE.loopRework or STATE.loopReworkBlocked then
            STATE.loopReworkDebounce = false
            return
        end
        RunService.Heartbeat:Wait()
    end

    if not STATE.loopRework or STATE.loopReworkBlocked then
        STATE.loopReworkDebounce = false
        return
    end

    local char, humanoid, hrp = getCharParts()
    if not humanoid or not hrp then
        STATE.loopReworkDebounce = false
        return
    end

    local prevAuto = humanoid.AutoRotate
    pcall(function() humanoid.AutoRotate = false end)

    -- Jump
    if STATE.ForceJumpEnabled then
        forceJumpSetup()
        forceJumpUpdateCharacter(char)
        local handled = forceJumpDoJump(humanoid, hrp)
        if not handled then
            pcall(function()
                humanoid.Jump = true
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
        end
    else
        pcall(function()
            humanoid.Jump = true
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end

    -- Wait after jump
    local t1 = tick()
    while tick() - t1 < waitJump do
        if not STATE.loopRework or STATE.loopReworkBlocked then
            pcall(function() if humanoid.Parent then humanoid.AutoRotate = prevAuto end end)
            STATE.loopReworkDebounce = false
            return
        end
        RunService.Heartbeat:Wait()
    end

    if not STATE.loopRework or STATE.loopReworkBlocked then
        pcall(function() if humanoid.Parent then humanoid.AutoRotate = prevAuto end end)
        STATE.loopReworkDebounce = false
        return
    end

    -- Fire remote
    fireDashQW()

    -- Wait before lock
    local t2 = tick()
    while tick() - t2 < waitRemote do
        if not STATE.loopRework or STATE.loopReworkBlocked then
            pcall(function() if humanoid.Parent then humanoid.AutoRotate = prevAuto end end)
            STATE.loopReworkDebounce = false
            return
        end
        RunService.Heartbeat:Wait()
    end

    if not STATE.loopRework or STATE.loopReworkBlocked then
        pcall(function() if humanoid.Parent then humanoid.AutoRotate = prevAuto end end)
        STATE.loopReworkDebounce = false
        return
    end

    -- Start lock
    local target = findBestTarget()
    if target and not STATE.loopReworkBlocked then
        activeLockCleanup = startHorizontalLock(target, lockDur)
    end

    -- Keep AutoRotate off during lock
    task.spawn(function()
        local keepUntil = tick() + math.max(lockDur, 1.0)
        while tick() < keepUntil do
            if not STATE.loopRework or STATE.loopReworkBlocked then break end
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

    -- Cleanup lock after duration
    task.delay(lockDur, function()
        if activeLockCleanup then
            pcall(activeLockCleanup)
            activeLockCleanup = nil
        end
    end)

    -- Cooldown
    task.delay(cooldown, function()
        STATE.loopReworkDebounce = false
    end)
end

----------------------------------------------------------------
-- ANIMATION HOOK
----------------------------------------------------------------
local function onAnimationPlayed(track)
    if not STATE.loopRework or STATE.loopReworkDebounce or STATE.loopReworkBlocked then
        return
    end
    if not track or not track.Animation then return end

    local id = tostring(track.Animation.AnimationId or "")
    if id == CONFIG.loopReworkAnimDetectId or id:find(CONFIG.loopReworkAnimDetectId, 1, true) then
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

----------------------------------------------------------------
-- BLOCK CHECKER
----------------------------------------------------------------
local function startBlockChecker()
    if connections.blockChecker then
        pcall(function() connections.blockChecker:Disconnect() end)
        connections.blockChecker = nil
    end

    local lastCheck = 0
    connections.blockChecker = RunService.Heartbeat:Connect(function(dt)
        if not STATE.loopRework then return end

        lastCheck += dt
        if lastCheck < 0.12 then return end
        lastCheck = 0

        local found = scanForBlockingAnim()
        if found and not STATE.loopReworkBlocked then
            STATE.loopReworkBlocked = true
            cancelActiveLock()
            if connections.anim then
                pcall(function() connections.anim:Disconnect() end)
                connections.anim = nil
            end
        elseif not found and STATE.loopReworkBlocked then
            STATE.loopReworkBlocked = false
            if STATE.loopRework then
                hookCharacter()
            end
        end
    end)
end

----------------------------------------------------------------
-- SETUP / UNLOAD
----------------------------------------------------------------
function loopReworkSetup()
    hookCharacter()
    startBlockChecker()

    if connections.charAdded then
        pcall(function() connections.charAdded:Disconnect() end)
    end

    connections.charAdded = player.CharacterAdded:Connect(function()
        task.wait(0.8)
        if STATE.loopRework then
            hookCharacter()
        end
    end)

    forceJumpSetup()
end

function loopReworkUnload()
    -- Disconnect everything
    for _, conn in pairs(connections) do
        if conn then
            pcall(function() conn:Disconnect() end)
        end
    end
    connections.anim         = nil
    connections.blockChecker = nil
    connections.charAdded    = nil

    cancelActiveLock()
    forceJumpUnload()

    STATE.loopReworkDebounce = false
    STATE.loopReworkBlocked  = false
end

-- Safety: clean up when player leaves
player.CharacterRemoving:Connect(function()
    cancelActiveLock()
end)

print("[Jaline Hub] Loop Dash v2 fully loaded & fixed.")
