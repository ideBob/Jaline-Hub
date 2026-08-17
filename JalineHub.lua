--[[
    Jaline Dash
    Premium Edition
    ESP Preview: zoomed out, idle, natural colors
]]

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")
local Workspace          = game:GetService("Workspace")
local CoreGui            = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

if Workspace:GetAttribute("NoDashCooldown") == nil then
    Workspace:SetAttribute("NoDashCooldown", false)
end

local CONFIG = {
    AnimDetectId = "10503381238",
    BlockAnimId  = "10471478869",
    StarAssetId  = "rbxassetid://241594819",
    GifAssetId   = "rbxassetid://5860841663",
    LightPurple  = Color3.fromRGB(190, 145, 255),
    LightPurple2 = Color3.fromRGB(160, 110, 255),
    ESPColor     = Color3.fromRGB(255, 255, 255),
    ESPUpdateRate = 0.20,
}

local STATE = {
    Enabled = false, Debounce = false, Blocked = false,
    WaitDetect = 0.30, WaitRemote = 0.10, LockDuration = 1.50, Cooldown = 1.00,
    TargetRadius = 50, Responsiveness = 650,
    BodyESP = false, InfDash = false,
    AutoBlock = false, M1AfterBlock = false, M1Catch = false,
    NormalRange = 30, SpecialRange = 50, SkillRange = 50, SkillDelay = 1.2,
}

local Connections = {}
local ActiveLockCleanup = nil
local ESPObjects = {}
local VisualGui = nil
local PreviewGui = nil
local LastCatch = 0

local ComboIDs = {10480793962, 10480796021}
local AllIDs = {
    Saitama = {10469493270, 10469630950, 10469639222, 10469643643, special = 10479335397},
    Garou = {13532562418, 13532600125, 13532604085, 13294471966, special = 10479335397},
    Cyborg = {13491635433, 13296577783, 13295919399, 13295936866, special = 10479335397},
    Sonic = {13370310513, 13390230973, 13378751717, 13378708199, special = 13380255751},
    Metal = {14004222985, 13997092940, 14001963401, 14136436157, special = 13380255751},
    Blade = {15259161390, 15240216931, 15240176873, 15162694192, special = 13380255751},
    Tatsumaki = {16515503507, 16515520431, 16515448089, 16552234590, special = 10479335397},
    Dragon = {17889458563, 17889461810, 17889471098, 17889290569, special = 10479335397},
    Tech = {123005629431309, 100059874351664, 104895379416342, 134775406437626, special = 10479335397},
}
local SkillIDs = {
    [10468665991] = true, [10466974800] = true, [10471336737] = true, [12510170988] = true,
    [12272894215] = true, [12296882427] = true, [12307656616] = true,
    [101588604872680] = true, [105442749844047] = true, [109617620932970] = true,
    [131820095363270] = true, [135289891173395] = true, [125955606488863] = true,
    [12534735382] = true, [12502664044] = true, [12509505723] = true, [12618271998] = true, [12684390285] = true,
    [13376869471] = true, [13294790250] = true, [13376962659] = true, [13501296372] = true, [13556985475] = true,
    [145162735010] = true, [14046756619] = true, [14299135500] = true, [14351441234] = true,
    [15290930205] = true, [15145462680] = true, [15295895753] = true, [15295336270] = true,
    [16139108718] = true, [16515850153] = true, [16431491215] = true, [16597322398] = true, [16597912086] = true,
    [17799224866] = true, [17838006839] = true, [17857788598] = true, [18179181663] = true,
    [113166426814229] = true, [116753755471636] = true, [116153572280464] = true, [114095570398448] = true, [77509627104305] = true
}

local function GetCharParts()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if humanoid and hrp then return char, humanoid, hrp end
    return nil, nil, nil
end

local function FireDashQW()
    local char = LocalPlayer.Character
    if not char then return end
    local comm = char:FindFirstChild("Communicate")
    if comm and typeof(comm.FireServer) == "function" then
        pcall(function() comm:FireServer({ Dash = Enum.KeyCode.W, Key = Enum.KeyCode.Q, Goal = "KeyPress" }) end)
    end
end

local function FireRemote(goal, mobile)
    local char = LocalPlayer.Character
    if not char then return end
    local comm = char:FindFirstChild("Communicate")
    if not comm then return end
    pcall(function()
        comm:FireServer({{ Goal = goal, Key = (goal == "KeyPress" or goal == "KeyRelease") and Enum.KeyCode.F or nil, Mobile = mobile or nil }})
    end)
end

local function GetCameraFlatLook()
    local cam = Workspace.CurrentCamera
    if not cam then return Vector3.new(0, 0, -1) end
    local look = cam.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.001 then return Vector3.new(0, 0, -1) end
    return flat.Unit
end

local function FindBestTarget()
    local live = Workspace:FindFirstChild("Live")
    if not live then return nil end
    local _, _, hrp = GetCharParts()
    if not hrp then return nil end
    local bestRoot, bestDist = nil, STATE.TargetRadius
    for _, model in ipairs(live:GetChildren()) do
        if model:IsA("Model") and model ~= LocalPlayer.Character then
            local root = model:FindFirstChild("HumanoidRootPart")
            local hum = model:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local valid = (model.Name == "Weakest Dummy") or (Players:GetPlayerFromCharacter(model) ~= nil)
                if valid then
                    local dist = (root.Position - hrp.Position).Magnitude
                    if dist < bestDist then bestDist = dist bestRoot = root end
                end
            end
        end
    end
    return bestRoot
end

local function HasBlockingAnim(model)
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local ok, tracks = pcall(function() return hum:GetPlayingAnimationTracks() end)
    if ok and tracks then
        for _, track in ipairs(tracks) do
            if track.Animation then
                local id = tostring(track.Animation.AnimationId or "")
                if id:find(CONFIG.BlockAnimId, 1, true) then return true end
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
            if hum and hum.Health > 0 and HasBlockingAnim(model) then return true end
        end
    end
    return false
end

local function StartHorizontalLock(targetRoot, duration)
    if duration <= 0 then return nil end
    local _, humanoid, hrp = GetCharParts()
    if not hrp or not humanoid then return nil end
    local cam = Workspace.CurrentCamera
    local startTime = tick()
    local conn
    conn = RunService.RenderStepped:Connect(function(dt)
        if STATE.Blocked or not STATE.Enabled then if conn then conn:Disconnect() end return end
        if not hrp.Parent then if conn then conn:Disconnect() end return end
        local hrpPos = hrp.Position
        local desiredLook
        if targetRoot and targetRoot.Parent then
            local toTarget = Vector3.new(targetRoot.Position.X - hrpPos.X, 0, targetRoot.Position.Z - hrpPos.Z)
            desiredLook = toTarget.Magnitude > 0.05 and toTarget.Unit or GetCameraFlatLook()
        else
            desiredLook = GetCameraFlatLook()
        end
        local camLook = GetCameraFlatLook()
        local blended = (desiredLook * 0.7 + camLook * 0.3)
        blended = blended.Magnitude < 0.001 and desiredLook or blended.Unit
        local desiredChar = CFrame.new(hrpPos, hrpPos + blended)
        local resp = math.clamp(STATE.Responsiveness, 1, 10000)
        if resp >= 900 then pcall(function() hrp.CFrame = desiredChar end)
        else
            local alpha = 1 - math.exp(-0.028 * resp * dt)
            pcall(function() hrp.CFrame = hrp.CFrame:Lerp(desiredChar, math.clamp(alpha, 0, 1)) end)
        end
        if cam then
            local camPos = cam.CFrame.Position
            local lookTarget = (targetRoot and targetRoot.Parent) and (targetRoot.Position + Vector3.new(0, 1.5, 0)) or (camPos + blended * 20)
            pcall(function() cam.CFrame = cam.CFrame:Lerp(CFrame.new(camPos, lookTarget), math.clamp(1 - math.exp(-12 * dt), 0, 1)) end)
        end
        if tick() - startTime >= duration then if conn then conn:Disconnect() end end
    end)
    return function() if conn then pcall(function() conn:Disconnect() end) end end
end

local function CancelActiveLock()
    if ActiveLockCleanup then pcall(ActiveLockCleanup) ActiveLockCleanup = nil end
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.AutoRotate = true end) end
    end
end

local function RunSequence()
    if STATE.Debounce or not STATE.Enabled or STATE.Blocked then return end
    STATE.Debounce = true
    local waitDetect, waitRemote, lockDur, cooldown = STATE.WaitDetect, STATE.WaitRemote, STATE.LockDuration, STATE.Cooldown
    local t0 = tick()
    while tick() - t0 < waitDetect do
        if not STATE.Enabled or STATE.Blocked then STATE.Debounce = false return end
        RunService.Heartbeat:Wait()
    end
    if not STATE.Enabled or STATE.Blocked then STATE.Debounce = false return end
    local char, humanoid, hrp = GetCharParts()
    if not humanoid or not hrp then STATE.Debounce = false return end
    local prevAuto = humanoid.AutoRotate
    pcall(function() humanoid.AutoRotate = false end)
    do
        local camLook = GetCameraFlatLook()
        pcall(function() hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + camLook) end)
        local cam = Workspace.CurrentCamera
        if cam then local camPos = cam.CFrame.Position pcall(function() cam.CFrame = CFrame.new(camPos, camPos + camLook * 20) end) end
    end
    pcall(function() humanoid.Jump = true humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
    FireDashQW()
    local t2 = tick()
    while tick() - t2 < waitRemote do
        if not STATE.Enabled or STATE.Blocked then
            pcall(function() if humanoid.Parent then humanoid.AutoRotate = prevAuto end end)
            STATE.Debounce = false return
        end
        RunService.Heartbeat:Wait()
    end
    if not STATE.Enabled or STATE.Blocked then
        pcall(function() if humanoid.Parent then humanoid.AutoRotate = prevAuto end end)
        STATE.Debounce = false return
    end
    local target = FindBestTarget()
    if not STATE.Blocked then ActiveLockCleanup = StartHorizontalLock(target, lockDur) end
    task.spawn(function()
        local keepUntil = tick() + math.max(lockDur, 1.0)
        while tick() < keepUntil do
            if not STATE.Enabled or STATE.Blocked then break end
            pcall(function() if humanoid and humanoid.Parent then humanoid.AutoRotate = false end end)
            RunService.Heartbeat:Wait()
        end
        pcall(function() if humanoid and humanoid.Parent then humanoid.AutoRotate = prevAuto end end)
    end)
    task.delay(lockDur, function() if ActiveLockCleanup then pcall(ActiveLockCleanup) ActiveLockCleanup = nil end end)
    task.delay(cooldown, function() STATE.Debounce = false end)
end

local function OnAnimationPlayed(track)
    if not track or not track.Animation then return end
    local id = tostring(track.Animation.AnimationId or "")
    if STATE.Enabled and not STATE.Debounce and not STATE.Blocked then
        if id == CONFIG.AnimDetectId or id:find(CONFIG.AnimDetectId, 1, true) then task.spawn(RunSequence) end
    end
end

local function HookCharacter()
    if Connections.Anim then pcall(function() Connections.Anim:Disconnect() end) Connections.Anim = nil end
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then Connections.Anim = humanoid.AnimationPlayed:Connect(OnAnimationPlayed) end
end

local function StartBlockChecker()
    if Connections.BlockChecker then pcall(function() Connections.BlockChecker:Disconnect() end) Connections.BlockChecker = nil end
    local last = 0
    Connections.BlockChecker = RunService.Heartbeat:Connect(function(dt)
        if not STATE.Enabled then return end
        last += dt
        if last < 0.12 then return end
        last = 0
        local found = IsAnyoneBlocking()
        if found and not STATE.Blocked then
            STATE.Blocked = true CancelActiveLock()
            if Connections.Anim then pcall(function() Connections.Anim:Disconnect() end) Connections.Anim = nil end
        elseif not found and STATE.Blocked then
            STATE.Blocked = false
            if STATE.Enabled then HookCharacter() end
        end
    end)
end

local function DoAfterBlock(hrp)
    if not STATE.M1AfterBlock or not hrp or not LocalPlayer.Character then return end
    local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if (hrp.Position - root.Position).Magnitude <= 10 then
        FireRemote("LeftClick", true)
        task.delay(0.3, function() if (hrp.Position - root.Position).Magnitude <= 10 then FireRemote("LeftClickRelease", true) end end)
    end
end

local function CheckAnims()
    local live = Workspace:FindFirstChild("Live")
    if not live then return end
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character.Parent == live then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character:FindFirstChildWhichIsA("Humanoid")
            if hrp and hum then
                local dist = (hrp.Position - myHRP.Position).Magnitude
                local animator = hum:FindFirstChildOfClass("Animator")
                if animator then
                    local anims = {}
                    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                        local id = tonumber(tostring(track.Animation.AnimationId):match("%d+"))
                        if id then anims[id] = true end
                    end
                    local comboCount = 0
                    for _, id in ipairs(ComboIDs) do if anims[id] then comboCount += 1 end end
                    for _, group in pairs(AllIDs) do
                        local normalHits, special = 0, anims[group.special]
                        for i = 1, 4 do if anims[group[i]] then normalHits += 1 end end
                        if comboCount == 2 and normalHits >= 2 and dist <= STATE.SpecialRange then
                            FireRemote("KeyPress") task.wait(0.7) FireRemote("KeyRelease") break
                        elseif normalHits > 0 and dist <= STATE.NormalRange then
                            FireRemote("KeyPress") task.wait(0.15) FireRemote("KeyRelease") DoAfterBlock(hrp) break
                        elseif special and dist <= STATE.SpecialRange and not STATE.M1Catch then
                            FireRemote("KeyPress") task.delay(1, function() FireRemote("KeyRelease") end) break
                        end
                    end
                    for animId in pairs(anims) do
                        if SkillIDs[animId] and dist <= STATE.SkillRange then
                            FireRemote("KeyPress") task.delay(STATE.SkillDelay, function() FireRemote("KeyRelease") end) break
                        end
                    end
                end
            end
        end
    end
end

local function CheckM1Catch()
    if not STATE.M1Catch then return end
    local live = Workspace:FindFirstChild("Live")
    if not live then return end
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character.Parent == live then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character:FindFirstChildWhichIsA("Humanoid")
            if hrp and hum then
                local dist1 = (hrp.Position - myHRP.Position).Magnitude
                if dist1 <= 30 then
                    local animator = hum:FindFirstChildOfClass("Animator")
                    if animator then
                        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                            local id = tonumber(tostring(track.Animation.AnimationId):match("%d+"))
                            if id == 10479335397 then
                                task.delay(0.1, function()
                                    local dist2 = (hrp.Position - myHRP.Position).Magnitude
                                    if dist2 < dist1 - 0.5 and tick() - LastCatch >= 5 then
                                        LastCatch = tick()
                                        FireRemote("LeftClick", true)
                                        task.delay(0.2, function() FireRemote("LeftClickRelease", true) end)
                                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.D, false, game)
                                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                                        task.delay(1, function()
                                            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
                                            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.D, false, game)
                                        end)
                                    end
                                end)
                                return
                            end
                        end
                    end
                end
            end
        end
    end
end

local function StartAutoBlock()
    if Connections.AutoBlock then return end
    Connections.AutoBlock = RunService.Heartbeat:Connect(function()
        if not STATE.AutoBlock then return end
        pcall(CheckAnims) pcall(CheckM1Catch)
    end)
end

local function StopAutoBlock()
    if Connections.AutoBlock then pcall(function() Connections.AutoBlock:Disconnect() end) Connections.AutoBlock = nil end
end

local function ClearAllESP()
    for model, highlight in pairs(ESPObjects) do pcall(function() highlight:Destroy() end) end
    table.clear(ESPObjects)
end

local function ApplyESP(model)
    if not model or model == LocalPlayer.Character then return end
    if ESPObjects[model] and ESPObjects[model].Parent then return end
    if ESPObjects[model] then pcall(function() ESPObjects[model]:Destroy() end) ESPObjects[model] = nil end
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
    local conn
    conn = model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            if ESPObjects[model] then pcall(function() ESPObjects[model]:Destroy() end) ESPObjects[model] = nil end
            if conn then conn:Disconnect() end
        end
    end)
end

local function RemoveESP(model)
    if ESPObjects[model] then pcall(function() ESPObjects[model]:Destroy() end) ESPObjects[model] = nil end
end

local function UpdateBodyESP()
    if not STATE.BodyESP then ClearAllESP() return end
    local active = {}
    local live = Workspace:FindFirstChild("Live")
    if live then
        for _, model in ipairs(live:GetChildren()) do
            if model:IsA("Model") and model ~= LocalPlayer.Character then
                local hum = model:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then active[model] = true ApplyESP(model) end
            end
        end
    else
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then active[plr.Character] = true ApplyESP(plr.Character) end
            end
        end
    end
    for model in pairs(ESPObjects) do
        if not active[model] or not model.Parent then RemoveESP(model) end
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
        task.delay(0.4, function() if STATE.BodyESP and char and char.Parent then ApplyESP(char) end end)
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            plr.CharacterAdded:Connect(onChar)
            if plr.Character then onChar(plr.Character) end
        end
    end
    Players.PlayerAdded:Connect(function(plr) plr.CharacterAdded:Connect(onChar) end)
    UpdateBodyESP()
end

local function StopBodyESP()
    if Connections.ESP then pcall(function() Connections.ESP:Disconnect() end) Connections.ESP = nil end
    ClearAllESP()
end

----------------------------------------------------------------
-- ESP PREVIEW: zoomed out, IDLE, natural colors (no white)
----------------------------------------------------------------
local function MakePart(name, size, cf, parent)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Anchored = true
    p.CanCollide = false
    p.Material = Enum.Material.SmoothPlastic
    p.Color = Color3.fromRGB(90, 90, 100) -- neutral, not white
    p.Transparency = 0
    p.Parent = parent
    return p
end

local function BuildFallbackMannequin()
    local model = Instance.new("Model")
    model.Name = "ESPHologram"
    local root = MakePart("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), model)
    model.PrimaryPart = root
    MakePart("Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 4.6, 0), model)
    MakePart("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), model)
    MakePart("Left Arm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0), model)
    MakePart("Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3, 0), model)
    MakePart("Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0), model)
    MakePart("Right Leg", Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0), model)
    local hl = Instance.new("Highlight")
    hl.FillColor = CONFIG.LightPurple
    hl.OutlineColor = CONFIG.LightPurple
    hl.FillTransparency = 0.85
    hl.OutlineTransparency = 0.2
    hl.Parent = model
    return model
end

local function TryCloneCharacter()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local wasArchivable = char.Archivable
    char.Archivable = true
    local ok, clone = pcall(function() return char:Clone() end)
    char.Archivable = wasArchivable
    if not ok or not clone then return nil end

    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("LocalScript") or d:IsA("Script") or d:IsA("Tool") or d:IsA("Sound") then
            pcall(function() d:Destroy() end)
        end
    end

    -- Keep natural colors — only anchor, no white / ForceField
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
        end
    end

    -- Soft purple outline only (no white fill)
    local hl = Instance.new("Highlight")
    hl.FillColor = CONFIG.LightPurple
    hl.OutlineColor = CONFIG.LightPurple
    hl.FillTransparency = 0.9
    hl.OutlineTransparency = 0.15
    hl.Parent = clone

    local cloneHRP = clone:FindFirstChild("HumanoidRootPart")
    if cloneHRP then
        local offset = cloneHRP.Position
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("BasePart") then
                d.CFrame = d.CFrame - offset + Vector3.new(0, 3, 0)
            end
        end
    end
    return clone
end

local function CreateESPPreview()
    if PreviewGui then pcall(function() PreviewGui:Destroy() end) PreviewGui = nil end

    local gui = Instance.new("ScreenGui")
    gui.Name = "JalineESPPreview"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 25

    local pg = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
    if pg then gui.Parent = pg else pcall(function() gui.Parent = CoreGui end) end
    PreviewGui = gui

    local panel = Instance.new("Frame")
    panel.Name = "PreviewPanel"
    panel.Size = UDim2.fromOffset(210, 300)
    panel.Position = UDim2.new(0, 20, 0.5, -150)
    panel.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    panel.BorderSizePixel = 0
    panel.Active = true
    panel.Draggable = true
    panel.Parent = gui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = CONFIG.LightPurple
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3
    stroke.Parent = panel

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 10, 18)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 12, 28)),
    })
    grad.Rotation = 90
    grad.Parent = panel

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 0, 26)
    title.Position = UDim2.fromOffset(10, 8)
    title.BackgroundTransparency = 1
    title.Text = "ESP Preview"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextColor3 = CONFIG.LightPurple
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panel

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -16, 0, 16)
    sub.Position = UDim2.fromOffset(10, 30)
    sub.BackgroundTransparency = 1
    sub.Text = "Idle preview"
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 11
    sub.TextColor3 = Color3.fromRGB(170, 160, 200)
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = panel

    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "Hologram"
    viewport.Size = UDim2.new(1, -20, 1, -58)
    viewport.Position = UDim2.fromOffset(10, 50)
    viewport.BackgroundColor3 = Color3.fromRGB(6, 6, 10)
    viewport.BorderSizePixel = 0
    viewport.Ambient = Color3.fromRGB(140, 140, 160)
    viewport.LightColor = Color3.fromRGB(220, 220, 230)
    viewport.LightDirection = Vector3.new(0, -1, -1)
    viewport.Parent = panel
    Instance.new("UICorner", viewport).CornerRadius = UDim.new(0, 8)

    local vStroke = Instance.new("UIStroke")
    vStroke.Color = CONFIG.LightPurple2
    vStroke.Thickness = 1
    vStroke.Transparency = 0.45
    vStroke.Parent = viewport

    local world = Instance.new("WorldModel")
    world.Parent = viewport

    local cam = Instance.new("Camera")
    cam.FieldOfView = 30 -- slightly tighter FOV + far distance = zoomed out look
    cam.Parent = viewport
    viewport.CurrentCamera = cam

    local cloneRef = nil

    -- ZOOMED OUT + IDLE (no orbit)
    local function setCameraIdle(model)
        local pp = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
        if not pp then return end
        local center = pp.Position
        -- Farther distance = zoomed out
        cam.CFrame = CFrame.new(center + Vector3.new(0, 2.2, 14), center + Vector3.new(0, 1.0, 0))
    end

    local function rebuild()
        if cloneRef then pcall(function() cloneRef:Destroy() end) cloneRef = nil end
        local clone = TryCloneCharacter()
        if not clone then clone = BuildFallbackMannequin() end
        clone.Parent = world
        cloneRef = clone
        setCameraIdle(clone)
    end

    task.spawn(function()
        for i = 1, 8 do
            rebuild()
            if cloneRef and cloneRef:FindFirstChildWhichIsA("BasePart") then break end
            task.wait(0.5)
        end
    end)

    -- NO rotation loop — stays idle
    if Connections.PreviewRot then
        pcall(function() Connections.PreviewRot:Disconnect() end)
        Connections.PreviewRot = nil
    end

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1.2)
        rebuild()
    end)

    task.spawn(function()
        while panel and panel.Parent do
            local a = TweenService:Create(stroke, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.12 })
            a:Play() a.Completed:Wait()
            local b = TweenService:Create(stroke, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.4 })
            b:Play() b.Completed:Wait()
        end
    end)
end

local function CreateVisuals()
    if VisualGui then pcall(function() VisualGui:Destroy() end) VisualGui = nil end
    local gui = Instance.new("ScreenGui")
    gui.Name = "JalineVisuals"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 8
    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    VisualGui = gui
    local container = Instance.new("Frame")
    container.Size = UDim2.fromScale(1, 1)
    container.BackgroundTransparency = 1
    container.ClipsDescendants = true
    container.Parent = gui
    local decor = Instance.new("ImageLabel")
    decor.AnchorPoint = Vector2.new(0.5, 0.5)
    decor.Position = UDim2.new(0.92, 0, 0.09, 0)
    decor.Size = UDim2.fromOffset(88, 88)
    decor.BackgroundTransparency = 1
    decor.Image = CONFIG.GifAssetId
    decor.ImageColor3 = CONFIG.LightPurple
    decor.ImageTransparency = 0.22
    decor.Parent = container
    task.spawn(function()
        while decor and decor.Parent do
            local up = TweenService:Create(decor, TweenInfo.new(1.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Size = UDim2.fromOffset(102, 102), ImageTransparency = 0.06 })
            up:Play() up.Completed:Wait()
            local down = TweenService:Create(decor, TweenInfo.new(1.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Size = UDim2.fromOffset(84, 84), ImageTransparency = 0.35 })
            down:Play() down.Completed:Wait()
        end
    end)
    if Connections.StarLoop then pcall(function() Connections.StarLoop:Disconnect() end) end
    Connections.StarLoop = RunService.Heartbeat:Connect(function()
        if not container.Parent or math.random() > 0.031 then return end
        local star = Instance.new("ImageLabel")
        star.BackgroundTransparency = 1
        star.Image = CONFIG.StarAssetId
        star.ImageColor3 = CONFIG.LightPurple
        star.ImageTransparency = math.random(18, 52) / 100
        local size = math.random(9, 17)
        star.Size = UDim2.fromOffset(size, size)
        star.Position = UDim2.new(math.random(), 0, -0.05, 0)
        star.Parent = container
        local duration = math.random(42, 88) / 10
        local drift = (math.random() - 0.5) * 0.18
        local tw = TweenService:Create(star, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
            Position = UDim2.new(star.Position.X.Scale + drift, 0, 1.08, 0),
            ImageTransparency = 1, Rotation = math.random(-55, 55)
        })
        tw:Play()
        tw.Completed:Connect(function() star:Destroy() end)
    end)
end

local function DashSetup()
    HookCharacter()
    StartBlockChecker()
    if Connections.CharAdded then pcall(function() Connections.CharAdded:Disconnect() end) end
    Connections.CharAdded = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.65)
        if STATE.Enabled then HookCharacter() end
    end)
end

local function DashUnload()
    for name, conn in pairs(Connections) do
        if name ~= "StarLoop" and name ~= "AutoBlock" and conn then
            pcall(function() conn:Disconnect() end)
            Connections[name] = nil
        end
    end
    CancelActiveLock()
    STATE.Debounce = false
    STATE.Blocked = false
end

LocalPlayer.CharacterRemoving:Connect(CancelActiveLock)

local CustomTheme = {
    WindowColor = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 8, 12)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 10, 22)),
    }),
    ShadowColor = Color3.fromRGB(0, 0, 0),
    LiveAnimation = true,
    ContentColor = Color3.fromRGB(230, 225, 255),
    TitlingColor = Color3.fromRGB(210, 185, 255),
    ActionColor = CONFIG.LightPurple,
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

local Window = Rayfield:CreateWindow({
    Name = "Jaline Dash",
    subtitle = "Premium Edition",
    theme = CustomTheme,
    configuration = { autoSave = true, autoLoad = true, fileName = "JalineDash" },
})

task.defer(CreateVisuals)
task.defer(CreateESPPreview)

local Tab = Window:CreateTab({ Name = "Jaline Dash", icon = 93364949241311 })
local AutoBlockTab = Window:CreateTab({ Name = "Auto Block", icon = 93364949241311 })

Tab:CreateToggle({
    Name = "Jaline Dash",
    description = "Camera CFrame driven loop dash",
    flag = "JalineDashEnabled",
    value = false,
    callback = function(value)
        STATE.Enabled = value
        if value then DashSetup() Window:Notify({ title = "Jaline Dash", content = "ENABLED", duration = 2.5 })
        else DashUnload() Window:Notify({ title = "Jaline Dash", content = "DISABLED", duration = 2.5 }) end
    end,
})

Tab:CreateToggle({
    Name = "Activate Inf Dash",
    description = "Removes dash cooldown",
    flag = "InfDash",
    value = false,
    callback = function(value)
        STATE.InfDash = value
        Workspace:SetAttribute("NoDashCooldown", value)
        Window:Notify({ title = "Inf Dash", content = value and "ACTIVATED" or "DEACTIVATED", duration = 2 })
    end,
})

Tab:CreateToggle({
    Name = "Body ESP",
    description = "White body highlight",
    flag = "BodyESP",
    value = false,
    callback = function(value)
        STATE.BodyESP = value
        if value then StartBodyESP() Window:Notify({ title = "Body ESP", content = "ENABLED", duration = 2 })
        else StopBodyESP() Window:Notify({ title = "Body ESP", content = "DISABLED", duration = 2 }) end
    end,
})

Tab:CreateSlider({ Name = "Detect Delay", flag = "DetectDelay", range = {0, 1.5}, increment = 0.05, value = STATE.WaitDetect, suffix = "s", callback = function(v) STATE.WaitDetect = v end })
Tab:CreateSlider({ Name = "Flick Delay", flag = "FlickDelay", range = {0, 0.8}, increment = 0.05, value = STATE.WaitRemote, suffix = "s", callback = function(v) STATE.WaitRemote = v end })
Tab:CreateSlider({ Name = "Lock Duration", flag = "LockDuration", range = {0.3, 3}, increment = 0.1, value = STATE.LockDuration, suffix = "s", callback = function(v) STATE.LockDuration = v end })
Tab:CreateSlider({ Name = "Smoothness", flag = "Smoothness", range = {50, 1000}, increment = 10, value = STATE.Responsiveness, callback = function(v) STATE.Responsiveness = v end })

AutoBlockTab:CreateToggle({
    Name = "Activate Auto Block",
    description = "Detects enemy attacks and auto blocks",
    flag = "AutoBlock",
    value = false,
    callback = function(value)
        STATE.AutoBlock = value
        if value then StartAutoBlock() Window:Notify({ title = "Auto Block", content = "ACTIVATED", duration = 2.5 })
        else StopAutoBlock() Window:Notify({ title = "Auto Block", content = "DEACTIVATED", duration = 2.5 }) end
    end,
})

AutoBlockTab:CreateToggle({ Name = "M1 After Block", flag = "M1AfterBlock", value = false, callback = function(v) STATE.M1AfterBlock = v end })
AutoBlockTab:CreateToggle({ Name = "M1 Catch", flag = "M1Catch", value = false, callback = function(v) STATE.M1Catch = v end })
AutoBlockTab:CreateSlider({ Name = "Normal Range", flag = "NormalRange", range = {10, 80}, increment = 1, value = STATE.NormalRange, callback = function(v) STATE.NormalRange = v end })
AutoBlockTab:CreateSlider({ Name = "Special Range", flag = "SpecialRange", range = {10, 100}, increment = 1, value = STATE.SpecialRange, callback = function(v) STATE.SpecialRange = v end })
AutoBlockTab:CreateSlider({ Name = "Skill Range", flag = "SkillRange", range = {10, 100}, increment = 1, value = STATE.SkillRange, callback = function(v) STATE.SkillRange = v end })
AutoBlockTab:CreateSlider({ Name = "Skill Hold Delay", flag = "SkillDelay", range = {0.3, 3}, increment = 0.1, value = STATE.SkillDelay, suffix = "s", callback = function(v) STATE.SkillDelay = v end })

print("[Jaline Dash] Loaded • ESP Preview zoomed out + idle + natural colors")
