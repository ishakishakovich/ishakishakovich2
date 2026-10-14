-- CUCUMBER Movement — v18 (X = toggle skate, обновлённый дизайн)
-- RightShift = меню | X = спавн/убрать скейт | Z = unlock mouse | End = unload
-- Space = bhop / ollie / kickflip | Ctrl = edgejump/edgebug
-- V = glide | Shift = autostrafe | Q = shove-it | E = heelflip

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Tween = game:GetService("TweenService")
local Sound = game:GetService("SoundService")
local Http = game:GetService("HttpService")
local Debris = game:GetService("Debris")

local plr = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")
local cam = workspace.CurrentCamera
local CONFIG_FILE = "cucumber_v18.json"

-- ============================================================
-- CONFIG
-- ============================================================
local C = {
    moveEnabled = true,
    bhopKey = Enum.KeyCode.Space,
    jumpCd = 0.04,
    walkSpeed = 24,
    jumpPower = 50,
    gravity = 196.2,

    glideKey = Enum.KeyCode.V,
    glideControl = 10,

    autostrafeEnabled = true,
    autostrafeKey = Enum.KeyCode.LeftShift,
    autostrafeAccel = 90,
    autostrafeMaxSpeed = 110,

    counterStrafeEnabled = true,
    counterStrafePower = 0.88,

    autoSurfEnabled = true,
    autoSurfMinDot = 0.15,
    autoSurfMaxDot = 0.96,

    edgeJumpEnabled = true,
    edgeJumpKey = Enum.KeyCode.LeftControl,
    edgeJumpLimit = 2,
    edgeJumpPower = 20,
    edgeJumpUsed = 0,

    edgebugEnabled = true,
    edgebugKey = Enum.KeyCode.LeftControl,
    edgebugLookDist = 3,
    edgebugCooldown = 0.15,

    bhopIgnoreWalkSpeed = true,

    -- skate
    skateKey = Enum.KeyCode.X,
    skateEnabled = false,
    skatePopPower = 30,
    skateFlipTime = 0.45,
    skateCooldown = 0.5,
    skateShoveKey = Enum.KeyCode.Q,
    skateHeelKey = Enum.KeyCode.E,
    skateUnderglow = true,
    skateUnderglowColor = Color3.fromRGB(120, 230, 100),
    skateTrailEnabled = true,

    fov = 90,
    thirdPerson = false,

    showMidKeys = true,
    showSpeed = true,
    showSpeedBar = true,
    showStreak = true,
    showFPS = false,
    showKillfeed = false,

    fxTrail = false,
    fxParticles = false,
    fxFootSparks = true,
    fxFOVKick = false,
    fxSound = false,
    fxMotionBlur = false,
    fxRainbowTrail = false,

    soundId = "rbxassetid://9120386436",
    soundVolume = 0.5,

    colTrail = Color3.fromRGB(120, 230, 100),
    colParticle = Color3.fromRGB(120, 230, 100),
    colSparks = Color3.fromRGB(180, 255, 120),

    bounds = 2048,
    margin = 60,
    fallY = -500,
    resetDist = 4000,
}

local function saveConfig()
    return (pcall(function()
        local d = {}
        for k, v in pairs(C) do
            local t = typeof(v)
            if t == "number" or t == "boolean" or t == "string" then d[k] = v end
        end
        writefile(CONFIG_FILE, Http:JSONEncode(d))
    end))
end
local function loadConfig()
    return (pcall(function()
        if not isfile or not isfile(CONFIG_FILE) then return end
        local d = Http:JSONDecode(readfile(CONFIG_FILE))
        for k, v in pairs(d) do if C[k] ~= nil then C[k] = v end end
    end))
end

-- ============================================================
-- SPLASH
-- ============================================================
local splash = Instance.new("ScreenGui")
splash.Name = "CucumberSplash"; splash.ResetOnSpawn = false
splash.IgnoreGuiInset = true; splash.DisplayOrder = 10000
splash.Parent = plr:WaitForChild("PlayerGui")
local sb = Instance.new("Frame", splash)
sb.Size = UDim2.new(1,0,1,0); sb.BackgroundColor3 = Color3.fromRGB(8,12,8); sb.BorderSizePixel = 0
local sLbl = Instance.new("TextLabel", sb)
sLbl.Size = UDim2.new(1,0,0,80); sLbl.Position = UDim2.new(0,0,0.5,-60)
sLbl.BackgroundTransparency = 1; sLbl.Font = Enum.Font.GothamBlack
sLbl.Text = "CUCUMBER"; sLbl.TextColor3 = Color3.fromRGB(120,230,100)
sLbl.TextSize = 72; sLbl.TextTransparency = 1
local sSub = Instance.new("TextLabel", sb)
sSub.Size = UDim2.new(1,0,0,24); sSub.Position = UDim2.new(0,0,0.5,20)
sSub.BackgroundTransparency = 1; sSub.Font = Enum.Font.GothamBold
sSub.Text = "v18"; sSub.TextColor3 = Color3.fromRGB(90,180,80)
sSub.TextSize = 14; sSub.TextTransparency = 1
local sBB = Instance.new("Frame", sb)
sBB.Size = UDim2.new(0,240,0,4); sBB.Position = UDim2.new(0.5,-120,0.5,60)
sBB.BackgroundColor3 = Color3.fromRGB(30,40,30); sBB.BorderSizePixel = 0
Instance.new("UICorner", sBB).CornerRadius = UDim.new(1,0)
local sBF = Instance.new("Frame", sBB)
sBF.Size = UDim2.new(0,0,1,0); sBF.BackgroundColor3 = Color3.fromRGB(120,230,100); sBF.BorderSizePixel = 0
Instance.new("UICorner", sBF).CornerRadius = UDim.new(1,0)
Tween:Create(sLbl, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
Tween:Create(sSub, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
Tween:Create(sBF, TweenInfo.new(1.2), {Size = UDim2.new(1,0,1,0)}):Play()
task.delay(1.8, function()
    Tween:Create(sb, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
    Tween:Create(sLbl, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
    Tween:Create(sSub, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
    Tween:Create(sBB, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    Tween:Create(sBF, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    task.delay(0.5, function() splash:Destroy() end)
end)

-- ============================================================
-- STATE
-- ============================================================
local vel = Vector3.zero
local lastJump = 0
local alive = true
local spawnPos = hrp.Position
local glideOn = false
local glideSpeed = 0
local glideDir = Vector3.zero
local wasOnGround = true
local lastEdgebugAt = 0
local bhopStreak = 0
local bhopMaxStreak = 0
local maxSpeedSession = 0
local trail, particle, footSparks, glideSound
local motionBlur
local baseFOV = cam and cam.FieldOfView or 70

-- ============================================================
-- SKATEBOARD (обновлённый дизайн)
-- ============================================================
local Skate = {
    board = nil,
    weld = nil,
    lastFlipAt = 0,
    flipping = false,
    manualOn = false,
    underglowLight = nil,
    boardTrail = nil,
    accentParts = {},
}

local function buildBoard()
    if Skate.board and Skate.board.Parent then return Skate.board end
    Skate.accentParts = {}

    local m = Instance.new("Model"); m.Name = "CucumberSkate"

    -- DECK — carbon fiber
    local deck = Instance.new("Part")
    deck.Name = "Deck"
    deck.Size = Vector3.new(2.6, 0.15, 0.75)
    deck.Color = Color3.fromRGB(18, 18, 20)
    deck.Material = Enum.Material.Metal
    deck.Reflectance = 0.25
    deck.CanCollide = false
    deck.Massless = true
    deck.TopSurface = Enum.SurfaceType.Smooth
    deck.BottomSurface = Enum.SurfaceType.Smooth
    deck.Parent = m

    -- GRIP TAPE (сверху)
    local grip = Instance.new("Part")
    grip.Name = "Grip"
    grip.Size = Vector3.new(2.4, 0.03, 0.68)
    grip.Color = Color3.fromRGB(12, 12, 12)
    grip.Material = Enum.Material.Fabric
    grip.CanCollide = false
    grip.Massless = true
    grip.Parent = m

    -- NEON SIDE STRIPS (две светящиеся полосы по бортам)
    local stripL = Instance.new("Part")
    stripL.Name = "StripL"
    stripL.Size = Vector3.new(2.5, 0.08, 0.05)
    stripL.Color = C.skateUnderglowColor
    stripL.Material = Enum.Material.Neon
    stripL.CanCollide = false
    stripL.Massless = true
    stripL.Parent = m
    table.insert(Skate.accentParts, stripL)

    local stripR = stripL:Clone()
    stripR.Name = "StripR"
    stripR.Parent = m
    table.insert(Skate.accentParts, stripR)

    -- NOSE + TAIL (загнутые вверх концы, сделаны из узких неоновых полос)
    local nose = Instance.new("Part")
    nose.Name = "Nose"
    nose.Size = Vector3.new(0.15, 0.18, 0.7)
    nose.Color = C.skateUnderglowColor
    nose.Material = Enum.Material.Neon
    nose.CanCollide = false
    nose.Massless = true
    nose.Parent = m
    table.insert(Skate.accentParts, nose)

    local tail = nose:Clone()
    tail.Name = "Tail"
    tail.Parent = m
    table.insert(Skate.accentParts, tail)

    -- TRUCKS (хром металл)
    local tL = Instance.new("Part")
    tL.Name = "TruckL"
    tL.Size = Vector3.new(0.25, 0.18, 0.55)
    tL.Color = Color3.fromRGB(180, 180, 190)
    tL.Material = Enum.Material.Metal
    tL.Reflectance = 0.4
    tL.CanCollide = false
    tL.Massless = true
    tL.Parent = m

    local tR = tL:Clone()
    tR.Name = "TruckR"
    tR.Parent = m

    -- WHEELS (неоновые, с ободами)
    local wheels = {}
    for i = 1, 4 do
        local w = Instance.new("Part")
        w.Name = "Wheel" .. i
        w.Shape = Enum.PartType.Cylinder
        w.Size = Vector3.new(0.22, 0.38, 0.38)
        w.Color = C.skateUnderglowColor
        w.Material = Enum.Material.Neon
        w.CanCollide = false
        w.Massless = true
        w.Orientation = Vector3.new(0, 0, 90)
        w.Parent = m
        wheels[i] = w
        table.insert(Skate.accentParts, w)

        -- обод колеса (тёмное кольцо)
        local hub = Instance.new("Part")
        hub.Name = "Hub" .. i
        hub.Shape = Enum.PartType.Cylinder
        hub.Size = Vector3.new(0.24, 0.16, 0.16)
        hub.Color = Color3.fromRGB(30, 30, 35)
        hub.Material = Enum.Material.Metal
        hub.Reflectance = 0.3
        hub.CanCollide = false
        hub.Massless = true
        hub.Orientation = Vector3.new(0, 0, 90)
        hub.Parent = m
    end

    -- BOLTS на деке (маленькие точки)
    local boltPositions = {
        Vector3.new(-1.0, 0, 0.25), Vector3.new(-1.0, 0, -0.25),
        Vector3.new(1.0, 0, 0.25),  Vector3.new(1.0, 0, -0.25),
        Vector3.new(-0.7, 0, 0.25), Vector3.new(-0.7, 0, -0.25),
        Vector3.new(0.7, 0, 0.25),  Vector3.new(0.7, 0, -0.25),
    }
    for i, pos in ipairs(boltPositions) do
        local bolt = Instance.new("Part")
        bolt.Name = "Bolt" .. i
        bolt.Shape = Enum.PartType.Cylinder
        bolt.Size = Vector3.new(0.05, 0.08, 0.08)
        bolt.Color = Color3.fromRGB(220, 220, 220)
        bolt.Material = Enum.Material.Metal
        bolt.Reflectance = 0.6
        bolt.CanCollide = false
        bolt.Massless = true
        bolt.Orientation = Vector3.new(0, 0, 90)
        bolt.Parent = m
    end

    -- POINT LIGHT под доской (underglow)
    local lightAtt = Instance.new("Attachment", deck)
    lightAtt.Position = Vector3.new(0, -0.5, 0)
    local light = Instance.new("PointLight", lightAtt)
    light.Color = C.skateUnderglowColor
    light.Brightness = 3
    light.Range = 12
    light.Shadows = false
    if not C.skateUnderglow then light.Enabled = false end
    Skate.underglowLight = light

    m.PrimaryPart = deck

    local function weldTo(child, offset, rot)
        local base = deck.CFrame * offset
        if rot then base = base * rot end
        child.CFrame = base
        local w = Instance.new("WeldConstraint")
        w.Part0 = deck
        w.Part1 = child
        w.Parent = deck
    end

    weldTo(grip,   CFrame.new(0, 0.09, 0))
    weldTo(stripL, CFrame.new(0, 0, 0.38))
    weldTo(stripR, CFrame.new(0, 0, -0.38))
    weldTo(nose,   CFrame.new(1.32, 0.05, 0))
    weldTo(tail,   CFrame.new(-1.32, 0.05, 0))
    weldTo(tL,     CFrame.new(-0.9, -0.15, 0))
    weldTo(tR,     CFrame.new(0.9, -0.15, 0))
    weldTo(wheels[1], CFrame.new(-0.9, -0.32, 0.42))
    weldTo(wheels[2], CFrame.new(-0.9, -0.32, -0.42))
    weldTo(wheels[3], CFrame.new(0.9, -0.32, 0.42))
    weldTo(wheels[4], CFrame.new(0.9, -0.32, -0.42))

    -- hubs — приварим к соответствующим колёсам
    for i = 1, 4 do
        local hub = m:FindFirstChild("Hub" .. i)
        if hub then
            hub.CFrame = wheels[i].CFrame
            local w = Instance.new("WeldConstraint")
            w.Part0 = wheels[i]; w.Part1 = hub; w.Parent = wheels[i]
        end
    end

    -- bolts приварим к deck
    for i = 1, 8 do
        local bolt = m:FindFirstChild("Bolt" .. i)
        if bolt then
            weldTo(bolt, CFrame.new(boltPositions[i].X, 0.09, boltPositions[i].Z))
        end
    end

    -- BOARD TRAIL (под доской когда движется)
    if C.skateTrailEnabled then
        local a0 = Instance.new("Attachment", deck)
        a0.Position = Vector3.new(0.8, -0.4, 0)
        local a1 = Instance.new("Attachment", deck)
        a1.Position = Vector3.new(-0.8, -0.4, 0)
        local bt = Instance.new("Trail")
        bt.Attachment0 = a0
        bt.Attachment1 = a1
        bt.Lifetime = 0.25
        bt.MinLength = 0
        bt.FaceCamera = true
        bt.Color = ColorSequence.new(C.skateUnderglowColor)
        bt.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 1),
        }
        bt.WidthScale = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }
        bt.LightEmission = 1
        bt.Parent = deck
        Skate.boardTrail = bt
    end

    Skate.board = m
    m.Parent = workspace
    return m
end

local function attachBoard()
    if not hrp then return end
    local m = buildBoard()
    local deck = m.PrimaryPart
    deck.CFrame = hrp.CFrame * CFrame.new(0, -3.0, 0)
    if Skate.weld then Skate.weld:Destroy() end
    local w = Instance.new("WeldConstraint")
    w.Part0 = hrp; w.Part1 = deck; w.Parent = hrp
    Skate.weld = w
    Skate.lastFlipAt = 0; Skate.flipping = false
    C.skateEnabled = true
end

local function detachBoard()
    if Skate.weld then Skate.weld:Destroy(); Skate.weld = nil end
    if Skate.board then Skate.board:Destroy(); Skate.board = nil end
    Skate.underglowLight = nil
    Skate.boardTrail = nil
    Skate.manualOn = false
    C.skateEnabled = false
end

local function toggleBoard()
    if Skate.board and Skate.board.Parent then
        detachBoard()
    else
        attachBoard()
    end
end

local function doTrick(axis, dur)
    if not Skate.board then return end
    if tick() - Skate.lastFlipAt < C.skateCooldown then return end
    Skate.lastFlipAt = tick()
    Skate.flipping = true
    local deck = Skate.board.PrimaryPart
    if not deck then return end
    local origWeld = Skate.weld
    task.spawn(function()
        local t = 0
        if origWeld then origWeld:Destroy(); Skate.weld = nil end
        while t < dur and Skate.flipping and deck.Parent do
            local dt = RS.Heartbeat:Wait()
            t = t + dt
            local a = math.clamp(t/dur, 0, 1)
            local rot
            if axis == "x" then
                rot = CFrame.Angles(math.rad(360*a), 0, 0)
            elseif axis == "y" then
                rot = CFrame.Angles(0, math.rad(360*a), 0)
            elseif axis == "x-rev" then
                rot = CFrame.Angles(math.rad(-360*a), 0, 0)
            end
            local base = hrp.CFrame * CFrame.new(0, -3.0, 0)
            deck.CFrame = base * rot
            if a >= 1 then
                deck.CFrame = hrp.CFrame * CFrame.new(0, -3.0, 0)
                local w = Instance.new("WeldConstraint")
                w.Part0 = hrp; w.Part1 = deck; w.Parent = hrp
                Skate.weld = w
                Skate.flipping = false
                return
            end
        end
        if deck.Parent then
            deck.CFrame = hrp.CFrame * CFrame.new(0, -3.0, 0)
            local w = Instance.new("WeldConstraint")
            w.Part0 = hrp; w.Part1 = deck; w.Parent = hrp
            Skate.weld = w
            Skate.flipping = false
        end
    end)
end
local function doKickflip() doTrick("x", C.skateFlipTime) end
local function doShoveit() doTrick("y", C.skateFlipTime) end
local function doHeelflip() doTrick("x-rev", C.skateFlipTime) end
local function doPop()
    if not hrp then return end
    local cur = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = Vector3.new(cur.X, math.max(cur.Y, C.skatePopPower), cur.Z)
end

-- ============================================================
-- FX (glide)
-- ============================================================
local function ensureTrail()
    if trail and trail.Parent then return end
    local a0 = Instance.new("Attachment", hrp); a0.Position = Vector3.new(0,1,0)
    local a1 = Instance.new("Attachment", hrp); a1.Position = Vector3.new(0,-1,0)
    trail = Instance.new("Trail")
    trail.Attachment0 = a0; trail.Attachment1 = a1
    trail.Lifetime = 0.35; trail.FaceCamera = true
    trail.Color = ColorSequence.new(C.colTrail)
    trail.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0,0.1), NumberSequenceKeypoint.new(1,1)}
    trail.WidthScale = NumberSequence.new{
        NumberSequenceKeypoint.new(0,0.6), NumberSequenceKeypoint.new(1,0)}
    trail.Enabled = false; trail.Parent = hrp
end

local function ensureParticles()
    if particle and particle.Parent then return end
    local a = Instance.new("Attachment", hrp)
    particle = Instance.new("ParticleEmitter")
    particle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particle.Color = ColorSequence.new(C.colParticle)
    particle.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0,0.4), NumberSequenceKeypoint.new(1,0)}
    particle.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0,0.1), NumberSequenceKeypoint.new(1,1)}
    particle.Lifetime = NumberRange.new(0.5,0.8); particle.Rate = 0
    particle.Speed = NumberRange.new(3,7); particle.SpreadAngle = Vector2.new(180,180)
    particle.LightEmission = 1; particle.Parent = a
end

local function ensureFootSparks()
    if footSparks and footSparks.Parent then return end
    local a = Instance.new("Attachment", hrp); a.Position = Vector3.new(0,-2.5,0)
    footSparks = Instance.new("ParticleEmitter")
    footSparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    footSparks.Color = ColorSequence.new(C.colSparks)
    footSparks.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0,0.6), NumberSequenceKeypoint.new(1,0)}
    footSparks.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0,0.1), NumberSequenceKeypoint.new(1,1)}
    footSparks.Lifetime = NumberRange.new(0.4,0.7); footSparks.Rate = 0
    footSparks.Speed = NumberRange.new(8,14); footSparks.SpreadAngle = Vector2.new(60,60)
    footSparks.Rotation = NumberRange.new(0,360); footSparks.RotSpeed = NumberRange.new(-180,180)
    footSparks.LightEmission = 1; footSparks.Acceleration = Vector3.new(0,20,0)
    footSparks.Parent = a
end

local function ensureGlideSound()
    if glideSound and glideSound.Parent then return end
    glideSound = Instance.new("Sound")
    glideSound.SoundId = C.soundId; glideSound.Looped = true
    glideSound.Volume = 0; glideSound.PlaybackSpeed = 1.2
    glideSound.Parent = Sound; glideSound:Play()
end

local function ensureMotionBlur()
    if motionBlur and motionBlur.Parent then return end
    motionBlur = Instance.new("BlurEffect", cam); motionBlur.Size = 0
end

local function refreshFX()
    if C.fxTrail then ensureTrail() end
    if C.fxParticles then ensureParticles() end
    if C.fxFootSparks then ensureFootSparks() end
    if C.fxMotionBlur then ensureMotionBlur() end
    if not C.fxTrail and trail then trail.Enabled = false end
    if not C.fxParticles and particle then particle.Rate = 0 end
    if not C.fxFootSparks and footSparks then footSparks.Rate = 0 end
    if not C.fxMotionBlur and motionBlur then motionBlur.Size = 0 end
end

local function setGlideFX(on)
    if C.fxTrail then
        ensureTrail()
        if not C.fxRainbowTrail then trail.Color = ColorSequence.new(C.colTrail) end
        trail.Enabled = on
    end
    if C.fxParticles then
        ensureParticles()
        if not C.fxRainbowTrail then particle.Color = ColorSequence.new(C.colParticle) end
        particle.Rate = on and 40 or 0
    end
    if C.fxSound then
        ensureGlideSound()
        Tween:Create(glideSound, TweenInfo.new(0.3), {Volume = on and C.soundVolume or 0}):Play()
    end
    if C.fxFOVKick and cam then
        Tween:Create(cam, TweenInfo.new(on and 0.15 or 0.3), {FieldOfView = on and (C.fov+8) or C.fov}):Play()
    end
    if C.fxMotionBlur then
        ensureMotionBlur()
        Tween:Create(motionBlur, TweenInfo.new(0.3), {Size = on and 8 or 0}):Play()
    end
end

-- rainbow trail
task.spawn(function()
    local hue = 0
    while true do
        RS.Heartbeat:Wait()
        if C.fxRainbowTrail then
            hue = (hue + 0.005) % 1
            local col = Color3.fromHSV(hue, 0.9, 1)
            if trail and trail.Parent then trail.Color = ColorSequence.new(col) end
            if particle and particle.Parent then particle.Color = ColorSequence.new(col) end
            if Skate.boardTrail and Skate.boardTrail.Parent then
                Skate.boardTrail.Color = ColorSequence.new(col)
            end
        end
    end
end)

-- ============================================================
-- SURF / EDGEBUG
-- ============================================================
local function raycastDir(dir, dist)
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances = {char}; p.IgnoreWater = true
    return workspace:Raycast(hrp.Position, dir * dist, p)
end

local function findSurfPlane()
    if not C.autoSurfEnabled then return nil end
    local r = raycastDir(Vector3.new(0,-1,0), 3)
    if not r then return nil end
    local d = r.Normal:Dot(Vector3.yAxis)
    if d >= C.autoSurfMinDot and d <= C.autoSurfMaxDot then return r.Normal end
    return nil
end

local function edgeJump()
    if not C.edgeJumpEnabled then return end
    if not UIS:IsKeyDown(C.edgeJumpKey) then return end
    if C.edgeJumpUsed >= C.edgeJumpLimit then return end
    C.edgeJumpUsed = C.edgeJumpUsed + 1
    local cur = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = Vector3.new(cur.X, math.max(cur.Y, C.edgeJumpPower), cur.Z)
end

local function tryEdgebug()
    if not C.edgebugEnabled then return end
    if not UIS:IsKeyDown(C.edgebugKey) then return end
    if tick() - lastEdgebugAt < C.edgebugCooldown then return end
    if not raycastDir(Vector3.new(0,-1,0), C.edgebugLookDist) then return end
    local fwd = hrp.CFrame.LookVector
    local f = Vector3.new(fwd.X, 0, fwd.Z)
    if f.Magnitude < 0.01 then f = Vector3.new(0,0,-1) end
    f = f.Unit
    if not raycastDir(f * (C.edgebugLookDist * 0.7) + Vector3.new(0,-0.5,0), 1) then return end
    if hrp.AssemblyLinearVelocity.Y > -3 then return end
    lastEdgebugAt = tick()
    local v = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = Vector3.new(v.X * 0.85, 0, v.Z * 0.85)
    hum:ChangeState(Enum.HumanoidStateType.Running)
    task.delay(0.05, function()
        if alive and hrp then
            local c = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(c.X, 5, c.Z)
        end
    end)
end

local function mv()
    local m = hum.MoveDirection
    if m.Magnitude < 0.01 then return nil end
    return Vector3.new(m.X, 0, m.Z).Unit
end
local function keyDown(k) return UIS:IsKeyDown(k) end

-- ============================================================
-- CHARACTER
-- ============================================================
local function hookCharacter(c)
    char = c
    hrp = c:WaitForChild("HumanoidRootPart")
    hum = c:WaitForChild("Humanoid")
    vel = Vector3.zero; alive = true; glideOn = false
    C.edgeJumpUsed = 0
    spawnPos = hrp.Position
    hum.WalkSpeed = C.walkSpeed
    hum.JumpPower = C.jumpPower
    hum.UseJumpPower = true
    hum.Died:Connect(function() alive = false end)
    trail, particle, footSparks = nil, nil, nil
    Skate.board = nil; Skate.weld = nil
    refreshFX()
    if C.skateEnabled then attachBoard() end
end
plr.CharacterAdded:Connect(hookCharacter)
hum.Died:Connect(function() alive = false end)
hum.WalkSpeed = C.walkSpeed
hum.JumpPower = C.jumpPower
hum.UseJumpPower = true

-- ============================================================
-- INPUT
-- ============================================================
-- X = toggle skate
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == C.skateKey then
        toggleBoard()
    end
end)

-- Q = shove-it, E = heelflip (только когда скейт есть)
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if not Skate.board then return end
    if input.KeyCode == C.skateShoveKey then
        doShoveit()
    elseif input.KeyCode == C.skateHeelKey then
        doHeelflip()
    end
end)

-- Space = pop/kickflip (со скейтом) или edgejump (в воздухе без скейта)
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode ~= Enum.KeyCode.Space then return end

    -- если скейт заспавнен — Space делает трюки
    if Skate.board then
        local st = hum:GetState()
        local onG = st == Enum.HumanoidStateType.Running or st == Enum.HumanoidStateType.Landed
        if onG then doPop() else doKickflip() end
        return
    end

    -- иначе — edgejump (если Ctrl зажат)
    if C.edgeJumpEnabled and alive and hrp then
        local onG = hum:GetState() == Enum.HumanoidStateType.Running
                 or hum:GetState() == Enum.HumanoidStateType.Landed
        if not onG then edgeJump() end
    end
end)

-- End
UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.End then
        saveConfig()
        detachBoard()
        if glideSound then glideSound:Destroy() end
        if motionBlur then motionBlur:Destroy() end
        script.Parent = nil
    end
end)

-- ============================================================
-- MAIN
-- ============================================================
RS.Heartbeat:Connect(function(dt)
    if not alive or not hrp or not hum or not C.moveEnabled then return end

    local st = hum:GetState()
    local onG = st == Enum.HumanoidStateType.Running or st == Enum.HumanoidStateType.Landed
    local m = mv()

    if onG and not wasOnGround then C.edgeJumpUsed = 0 end
    wasOnGround = onG

    local ev = hrp.AssemblyLinearVelocity
    vel = Vector3.new(vel.X, ev.Y, vel.Z)

    if C.bhopIgnoreWalkSpeed then
        if onG then
            if hum.WalkSpeed ~= C.walkSpeed then hum.WalkSpeed = C.walkSpeed end
        else
            if hum.WalkSpeed ~= 0 then hum.WalkSpeed = 0 end
        end
    end

    if not onG and not glideOn and st == Enum.HumanoidStateType.Freefall then
        tryEdgebug()
    end

    local wantGlide = keyDown(C.glideKey) and not onG
    if wantGlide ~= glideOn then
        glideOn = wantGlide
        if glideOn then
            local h = Vector3.new(vel.X, 0, vel.Z)
            glideSpeed = h.Magnitude
            if glideSpeed > 0.1 then
                glideDir = h.Unit
            else
                local look = cam and cam.CFrame.LookVector or Vector3.new(0,0,-1)
                glideDir = Vector3.new(look.X, 0, look.Z).Unit
                glideSpeed = C.walkSpeed
            end
            hrp.AssemblyLinearVelocity = glideDir * glideSpeed
            vel = Vector3.new(glideDir.X * glideSpeed, 0, glideDir.Z * glideSpeed)
            setGlideFX(true)
        else
            setGlideFX(false)
        end
    end

    if glideOn then
        local surfN = findSurfPlane()
        if m then
            local turn = C.glideControl * dt
            local newDir = (glideDir + m * turn)
            if newDir.Magnitude > 0.001 then glideDir = newDir.Unit end
        end
        if surfN then
            local along = glideDir - surfN * glideDir:Dot(surfN)
            if along.Magnitude > 0.01 then glideDir = along.Unit end
        end
        if glideSpeed > 120 then glideSpeed = 120 end
        local h = glideDir * glideSpeed
        hrp.AssemblyLinearVelocity = Vector3.new(h.X, 0, h.Z)
        vel = Vector3.new(h.X, 0, h.Z)

        if C.fxFootSparks then ensureFootSparks(); footSparks.Rate = 60 end

        local pos = hrp.Position
        if pos.Y < C.fallY or pos.Magnitude > C.resetDist then
            hrp.CFrame = CFrame.new(spawnPos); vel = Vector3.zero
            glideOn = false; setGlideFX(false); return
        end
        local b = C.bounds - C.margin
        local cx = math.clamp(pos.X, -b, b)
        local cz = math.clamp(pos.Z, -b, b)
        if cx ~= pos.X or cz ~= pos.Z then
            hrp.CFrame = CFrame.new(cx, pos.Y, cz) * (hrp.CFrame - hrp.CFrame.Position)
            hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
        end
        return
    end

    if not onG and m and C.autostrafeEnabled and keyDown(C.autostrafeKey) then
        local h = Vector3.new(vel.X, 0, vel.Z)
        local curSpeed = h.Magnitude
        if curSpeed < C.autostrafeMaxSpeed then
            local addSpeed = math.min(C.autostrafeMaxSpeed - curSpeed, C.autostrafeAccel * dt)
            h = h + m * addSpeed
            vel = Vector3.new(h.X, ev.Y, h.Z)
        end
    end

    if onG then
        if not m and C.counterStrafeEnabled then
            local h = Vector3.new(ev.X, 0, ev.Z)
            if h.Magnitude > 1 then
                local newH = h * (1 - (1 - C.counterStrafePower) * math.min(dt*15, 1))
                hrp.AssemblyLinearVelocity = Vector3.new(newH.X, ev.Y, newH.Z)
            end
        end

        if keyDown(C.bhopKey) and not Skate.board then
            if tick() - lastJump > C.jumpCd then
                lastJump = tick()
                hum.Jump = true
                bhopStreak = bhopStreak + 1
                if bhopStreak > bhopMaxStreak then bhopMaxStreak = bhopStreak end
            end
        elseif keyDown(C.bhopKey) and Skate.board then
            if tick() - lastJump > C.jumpCd then
                lastJump = tick()
                bhopStreak = bhopStreak + 1
                if bhopStreak > bhopMaxStreak then bhopMaxStreak = bhopStreak end
            end
        else
            bhopStreak = 0
        end

        -- Manual: зажать S на скейте
        if Skate.board and C.skateManualEnabled and keyDown(Enum.KeyCode.S) then
            if not Skate.manualOn then
                Skate.manualOn = true
            end
        else
            if Skate.manualOn then Skate.manualOn = false end
        end
    end

    if C.fxFootSparks then
        ensureFootSparks()
        if onG then
            local spd = Vector3.new(ev.X, ev.Z).Magnitude
            footSparks.Rate = spd > 2 and 25 or 0
        else
            footSparks.Rate = 45
        end
    end

    if C.fxMotionBlur and motionBlur then
        local spd = Vector3.new(ev.X, ev.Z).Magnitude
        motionBlur.Size = math.clamp((spd-40)/10, 0, 10)
    end

    -- подсветка скейта когда движется
    if Skate.underglowLight and Skate.board then
        local spd = Vector3.new(ev.X, ev.Z).Magnitude
        if C.skateUnderglow then
            Skate.underglowLight.Enabled = true
            Skate.underglowLight.Brightness = 2 + math.clamp(spd/20, 0, 4)
        else
            Skate.underglowLight.Enabled = false
        end
    end

    local pos = hrp.Position
    if pos.Y < C.fallY or pos.Magnitude > C.resetDist then
        hrp.CFrame = CFrame.new(spawnPos); vel = Vector3.zero
    end
end)

-- ============================================================
-- HUD
-- ============================================================
local H = {
    bg = Color3.fromRGB(8,12,8), text = Color3.fromRGB(230,240,230),
    accent = Color3.fromRGB(120,230,100), dim = Color3.fromRGB(90,140,90),
    warn = Color3.fromRGB(230,230,100), danger = Color3.fromRGB(255,90,100),
    font = Enum.Font.GothamBold,
}

local hud = Instance.new("ScreenGui")
hud.Name = "CucumberHUD"; hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true; hud.DisplayOrder = 998
hud.Parent = plr:WaitForChild("PlayerGui")

local speedFrame = Instance.new("Frame", hud)
speedFrame.Size = UDim2.new(0,170,0,64); speedFrame.Position = UDim2.new(0.5,-85,0,20)
speedFrame.BackgroundColor3 = H.bg; speedFrame.BackgroundTransparency = 0.35
speedFrame.BorderSizePixel = 0; speedFrame.Visible = C.showSpeed
Instance.new("UICorner", speedFrame).CornerRadius = UDim.new(0,8)
local ss = Instance.new("UIStroke", speedFrame)
ss.Color = H.accent; ss.Thickness = 1.5; ss.Transparency = 0.3

local speedTitle = Instance.new("TextLabel", speedFrame)
speedTitle.Size = UDim2.new(1,0,0,12); speedTitle.Position = UDim2.new(0,0,0,4)
speedTitle.BackgroundTransparency = 1; speedTitle.Font = Enum.Font.GothamBold
speedTitle.Text = "CUCUMBER"; speedTitle.TextColor3 = H.dim; speedTitle.TextSize = 9

local speedTxt = Instance.new("TextLabel", speedFrame)
speedTxt.Size = UDim2.new(1,0,0,30); speedTxt.Position = UDim2.new(0,0,0,16)
speedTxt.BackgroundTransparency = 1; speedTxt.Font = Enum.Font.GothamBlack
speedTxt.Text = "0.0"; speedTxt.TextColor3 = H.accent; speedTxt.TextSize = 24

local speedBarBg = Instance.new("Frame", speedFrame)
speedBarBg.Size = UDim2.new(1,-16,0,5); speedBarBg.Position = UDim2.new(0,8,1,-12)
speedBarBg.BackgroundColor3 = Color3.fromRGB(20,30,20); speedBarBg.BorderSizePixel = 0
speedBarBg.Visible = C.showSpeedBar
Instance.new("UICorner", speedBarBg).CornerRadius = UDim.new(1,0)
local speedBarFill = Instance.new("Frame", speedBarBg)
speedBarFill.Size = UDim2.new(0,0,1,0); speedBarFill.BackgroundColor3 = H.accent
speedBarFill.BorderSizePixel = 0
Instance.new("UICorner", speedBarFill).CornerRadius = UDim.new(1,0)

local streakLbl = Instance.new("TextLabel", hud)
streakLbl.Size = UDim2.new(0,100,0,20); streakLbl.Position = UDim2.new(0.5,-50,0,88)
streakLbl.BackgroundTransparency = 1; streakLbl.Font = Enum.Font.GothamBlack
streakLbl.Text = ""; streakLbl.TextColor3 = H.accent; streakLbl.TextSize = 18
streakLbl.Visible = C.showStreak

local keysFrame = Instance.new("Frame", hud)
keysFrame.Size = UDim2.new(0,380,0,40); keysFrame.Position = UDim2.new(0.5,-190,1,-70)
keysFrame.BackgroundTransparency = 1; keysFrame.Visible = C.showMidKeys
local keysLayout = Instance.new("UIListLayout", keysFrame)
keysLayout.FillDirection = Enum.FillDirection.Horizontal
keysLayout.Padding = UDim.new(0,6)
keysLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function makeKeyBadge(text, order)
    local box = Instance.new("Frame")
    box.Size = UDim2.new(0,34,0,34); box.BackgroundColor3 = H.bg
    box.BackgroundTransparency = 0.45; box.BorderSizePixel = 0
    box.LayoutOrder = order; box.Parent = keysFrame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)
    local st = Instance.new("UIStroke", box)
    st.Color = H.text; st.Thickness = 1.5; st.Transparency = 0.6
    local lbl = Instance.new("TextLabel", box)
    lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Font = H.font; lbl.Text = text; lbl.TextColor3 = H.text; lbl.TextSize = 14
    return {box=box, stroke=st, label=lbl}
end

local kbSpace = makeKeyBadge("SPC", 1)
local kbCtrl  = makeKeyBadge("CTL", 2)
local kbShift = makeKeyBadge("SFT", 3)
local kbW     = makeKeyBadge("W", 4)
local kbA     = makeKeyBadge("A", 5)
local kbS     = makeKeyBadge("S", 6)
local kbD     = makeKeyBadge("D", 7)
local kbV     = makeKeyBadge("V", 8)
local kbZ     = makeKeyBadge("Z", 9)
local kbX     = makeKeyBadge("X", 10)

local function setKey(badge, on, color)
    color = color or H.accent
    badge.stroke.Color = on and color or H.text
    badge.stroke.Transparency = on and 0 or 0.6
    badge.label.TextColor3 = on and color or H.text
    badge.box.BackgroundTransparency = on and 0.25 or 0.45
end

-- ============================================================
-- MENU
-- ============================================================
local T = {
    bg = Color3.fromRGB(10,14,10), panel = Color3.fromRGB(14,20,14),
    panel2 = Color3.fromRGB(20,28,20), stroke = Color3.fromRGB(40,60,40),
    text = Color3.fromRGB(230,240,230), dim = Color3.fromRGB(100,140,100),
    accent = Color3.fromRGB(120,230,100), accent2 = Color3.fromRGB(80,180,70),
    danger = Color3.fromRGB(255,90,100),
    font = Enum.Font.Gotham, fontB = Enum.Font.GothamBold, fontBlack = Enum.Font.GothamBlack,
}

local plrGui = plr:WaitForChild("PlayerGui")
local old = plrGui:FindFirstChild("CucumberMenu")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "CucumberMenu"; gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true; gui.DisplayOrder = 999
gui.Parent = plrGui

local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = p; return c
end
local function stroke(p, col, th, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or T.stroke; s.Thickness = th or 1; s.Transparency = tr or 0
    s.Parent = p; return s
end
local function pad(p, n)
    local u = Instance.new("UIPadding")
    u.PaddingTop = UDim.new(0,n); u.PaddingBottom = UDim.new(0,n)
    u.PaddingLeft = UDim.new(0,n); u.PaddingRight = UDim.new(0,n)
    u.Parent = p; return u
end

local MW, MH = 720, 500

local glow = Instance.new("Frame", gui)
glow.Size = UDim2.new(0, MW+20, 0, MH+20)
glow.Position = UDim2.new(0.5, -(MW+20)/2, 0.5, -(MH+20)/2)
glow.BackgroundColor3 = T.accent; glow.BackgroundTransparency = 0.95
glow.BorderSizePixel = 0; glow.ZIndex = 0; glow.Visible = false
corner(glow, 16)

local menu = Instance.new("Frame", gui)
menu.Name = "MainFrame"
menu.Size = UDim2.new(0, MW, 0, MH)
menu.Position = UDim2.new(0.5, -MW/2, 0.5, -MH/2)
menu.BackgroundColor3 = T.bg; menu.BorderSizePixel = 0
menu.Visible = false; menu.ClipsDescendants = true; menu.ZIndex = 1
corner(menu, 10); stroke(menu, T.accent, 1.5, 0.3)

local topLine = Instance.new("Frame", menu)
topLine.Size = UDim2.new(1,0,0,3); topLine.BackgroundColor3 = T.accent
topLine.BorderSizePixel = 0

local headerBg = Instance.new("Frame", menu)
headerBg.Size = UDim2.new(1,0,0,56); headerBg.Position = UDim2.new(0,0,0,3)
headerBg.BackgroundColor3 = T.panel; headerBg.BorderSizePixel = 0

local title = Instance.new("TextLabel", headerBg)
title.Size = UDim2.new(1,-60,0,30); title.Position = UDim2.new(0,16,0,8)
title.BackgroundTransparency = 1; title.Font = T.fontBlack
title.Text = "CUCUMBER"; title.TextColor3 = T.accent; title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left

local subtitle = Instance.new("TextLabel", headerBg)
subtitle.Size = UDim2.new(1,-60,0,14); subtitle.Position = UDim2.new(0,16,0,34)
subtitle.BackgroundTransparency = 1; subtitle.Font = T.font
subtitle.Text = "movement suite  •  v18  •  X = skate, Z = mouse"
subtitle.TextColor3 = T.dim; subtitle.TextSize = 10
subtitle.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", headerBg)
closeBtn.Size = UDim2.new(0,30,0,30); closeBtn.Position = UDim2.new(1,-40,0,13)
closeBtn.BackgroundColor3 = T.panel2; closeBtn.BorderSizePixel = 0
closeBtn.Font = T.fontB; closeBtn.Text = "×"; closeBtn.TextColor3 = T.dim
closeBtn.TextSize = 18; closeBtn.AutoButtonColor = false
corner(closeBtn, 6)

local titleBar = headerBg

local sidebar = Instance.new("Frame", menu)
sidebar.Size = UDim2.new(0,130,1,-59); sidebar.Position = UDim2.new(0,0,0,59)
sidebar.BackgroundColor3 = T.panel; sidebar.BorderSizePixel = 0
local sidebarLayout = Instance.new("UIListLayout", sidebar)
sidebarLayout.Padding = UDim.new(0,2)
sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
pad(sidebar, 6)

local content = Instance.new("Frame", menu)
content.Size = UDim2.new(1,-130,1,-59); content.Position = UDim2.new(0,130,0,59)
content.BackgroundTransparency = 1
pad(content, 12)

local pages = {}
local currentTab = nil
local tabButtons = {}

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name; page.Size = UDim2.new(1,0,1,0)
    page.BackgroundTransparency = 1; page.BorderSizePixel = 0
    page.ScrollBarThickness = 4; page.ScrollBarImageColor3 = T.accent
    page.CanvasSize = UDim2.new(0,0,0,0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false; page.Parent = content
    local layout = Instance.new("UIListLayout", page)
    layout.Padding = UDim.new(0,8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    pages[name] = {frame = page}
    return page
end

local function createTabButton(name, order)
    local btn = Instance.new("TextButton", sidebar)
    btn.Name = name; btn.Size = UDim2.new(1,0,0,32)
    btn.BackgroundColor3 = T.panel2; btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0; btn.Font = T.fontB
    btn.Text = name; btn.TextColor3 = T.dim; btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false; btn.LayoutOrder = order
    corner(btn, 5); pad(btn, 10)
    tabButtons[name] = btn
    return btn
end

local function selectTab(name)
    for n, p in pairs(pages) do p.frame.Visible = (n == name) end
    for n, btn in pairs(tabButtons) do
        local active = n == name
        Tween:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = active and T.accent or T.panel2,
            BackgroundTransparency = active and 0 or 1,
            TextColor3 = active and T.bg or T.dim,
        }):Play()
    end
    currentTab = name
end

local function makeToggle(parent, label, key, onChange)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,0,0,30); row.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1,-60,1,0); lbl.BackgroundTransparency = 1
    lbl.Font = T.font; lbl.Text = label; lbl.TextColor3 = T.text; lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(0,40,0,20); track.Position = UDim2.new(1,-40,0.5,-10)
    track.BackgroundColor3 = C[key] and T.accent or T.stroke
    track.BorderSizePixel = 0
    corner(track, 10)
    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0,16,0,16)
    knob.Position = C[key] and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
    knob.BackgroundColor3 = Color3.fromRGB(240,255,240)
    knob.BorderSizePixel = 0
    corner(knob, 8)
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""
    local function update()
        local on = C[key]
        Tween:Create(track, TweenInfo.new(0.2), {
            BackgroundColor3 = on and T.accent or T.stroke}):Play()
        Tween:Create(knob, TweenInfo.new(0.2), {
            Position = on and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)}):Play()
    end
    btn.MouseButton1Click:Connect(function()
        C[key] = not C[key]
        update()
        if onChange then onChange(C[key]) end
    end)
    return row
end

local function makeSlider(parent, label, key, min, max, suffix)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,0,0,44); row.BackgroundTransparency = 1
    local top = Instance.new("Frame", row)
    top.Size = UDim2.new(1,0,0,20); top.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", top)
    lbl.Size = UDim2.new(0.7,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Font = T.font; lbl.Text = label; lbl.TextColor3 = T.text; lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local val = Instance.new("TextLabel", top)
    val.Size = UDim2.new(0.3,0,1,0); val.Position = UDim2.new(0.7,0,0,0)
    val.BackgroundTransparency = 1; val.Font = T.fontB
    val.Text = tostring(C[key]) .. (suffix or "")
    val.TextColor3 = T.accent; val.TextSize = 13
    val.TextXAlignment = Enum.TextXAlignment.Right
    local bar = Instance.new("Frame", row)
    bar.Size = UDim2.new(1,0,0,6); bar.Position = UDim2.new(0,0,0,28)
    bar.BackgroundColor3 = T.stroke; bar.BorderSizePixel = 0
    corner(bar, 3)
    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new((C[key]-min)/(max-min),0,1,0)
    fill.BackgroundColor3 = T.accent; fill.BorderSizePixel = 0
    corner(fill, 3)
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1,0,0,20); btn.Position = UDim2.new(0,0,0,20)
    btn.BackgroundTransparency = 1; btn.Text = ""
    local dragging = false
    local function setFromX(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local v = min + (max-min) * rel
        v = math.floor(v*100 + 0.5) / 100
        C[key] = v
        val.Text = tostring(v) .. (suffix or "")
        Tween:Create(fill, TweenInfo.new(0.08), {Size = UDim2.new(rel,0,1,0)}):Play()
    end
    btn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; setFromX(i.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            setFromX(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    return row
end

local function makeButton(parent, label, callback, color)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1,0,0,32); btn.BackgroundColor3 = T.panel2
    btn.BorderSizePixel = 0; btn.Font = T.fontB
    btn.Text = label; btn.TextColor3 = color or T.text; btn.TextSize = 12
    btn.AutoButtonColor = false
    corner(btn, 5); stroke(btn, T.stroke, 1, 0.3)
    btn.MouseEnter:Connect(function()
        Tween:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = T.accent}):Play()
        btn.TextColor3 = T.bg
    end)
    btn.MouseLeave:Connect(function()
        Tween:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = T.panel2}):Play()
        btn.TextColor3 = color or T.text
    end)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function makeLabel(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(1,0,0,20); lbl.BackgroundTransparency = 1
    lbl.Font = T.fontB; lbl.Text = text; lbl.TextColor3 = T.accent2; lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    return lbl
end

-- pages
local pageMove = createPage("Movement")
local pageAir = createPage("Air")
local pageGlide = createPage("Glide")
local pageEdge = createPage("Edge")
local pageSkate = createPage("Skate")
local pageCam = createPage("Camera")
local pageFX = createPage("FX")
local pageHUD = createPage("HUD")
local pageMisc = createPage("Misc")

local tabMove = createTabButton("Movement", 1)
local tabAir = createTabButton("Air", 2)
local tabGlide = createTabButton("Glide", 3)
local tabEdge = createTabButton("Edge", 4)
local tabSkate = createTabButton("Skate", 5)
local tabCam = createTabButton("Camera", 6)
local tabFX = createTabButton("Effects", 7)
local tabHUD = createTabButton("HUD", 8)
local tabMisc = createTabButton("Misc", 9)

tabMove.MouseButton1Click:Connect(function() selectTab("Movement") end)
tabAir.MouseButton1Click:Connect(function() selectTab("Air") end)
tabGlide.MouseButton1Click:Connect(function() selectTab("Glide") end)
tabEdge.MouseButton1Click:Connect(function() selectTab("Edge") end)
tabSkate.MouseButton1Click:Connect(function() selectTab("Skate") end)
tabCam.MouseButton1Click:Connect(function() selectTab("Camera") end)
tabFX.MouseButton1Click:Connect(function() selectTab("Effects") end)
tabHUD.MouseButton1Click:Connect(function() selectTab("HUD") end)
tabMisc.MouseButton1Click:Connect(function() selectTab("Misc") end)

-- Movement
makeLabel(pageMove, "MASTER")
makeToggle(pageMove, "Movement enabled", "moveEnabled")
makeLabel(pageMove, "BHOP")
makeSlider(pageMove, "Walk speed", "walkSpeed", 8, 60, "")
makeSlider(pageMove, "Jump power", "jumpPower", 30, 150, "")
makeSlider(pageMove, "Bhop cooldown", "jumpCd", 0.01, 0.2, "s")
makeLabel(pageMove, "COUNTER-STRAFE")
makeToggle(pageMove, "Counter-strafe", "counterStrafeEnabled")
makeSlider(pageMove, "Counter power", "counterStrafePower", 0.5, 0.99, "")

-- Air
makeLabel(pageAir, "AIR STRAFE")
makeToggle(pageAir, "Autostrafe (Shift)", "autostrafeEnabled")
makeSlider(pageAir, "Air accel", "autostrafeAccel", 20, 200, "")
makeSlider(pageAir, "Air max speed", "autostrafeMaxSpeed", 40, 200, "")

-- Glide
makeLabel(pageGlide, "PIXEL GLIDE")
makeSlider(pageGlide, "Glide control", "glideControl", 2, 25, "")
makeToggle(pageGlide, "Auto surf lock", "autoSurfEnabled")
makeLabel(pageGlide, "INFO")
local gi = Instance.new("TextLabel", pageGlide)
gi.Size = UDim2.new(1,0,0,50); gi.BackgroundTransparency = 1
gi.Font = T.font; gi.Text = "V (hold in air) = glide\nSpeed preserved on entry"
gi.TextColor3 = T.dim; gi.TextSize = 11
gi.TextXAlignment = Enum.TextXAlignment.Left
gi.TextYAlignment = Enum.TextYAlignment.Top; gi.TextWrapped = true

-- Edge
makeLabel(pageEdge, "EDGEJUMP")
makeToggle(pageEdge, "Enable edgejump", "edgeJumpEnabled")
makeSlider(pageEdge, "Jump power", "edgeJumpPower", 5, 60, "")
makeSlider(pageEdge, "Jump limit", "edgeJumpLimit", 1, 5, "")
makeLabel(pageEdge, "EDGEBUG")
makeToggle(pageEdge, "Enable edgebug", "edgebugEnabled")
makeSlider(pageEdge, "Look dist", "edgebugLookDist", 1, 8, "st")

-- Skate
makeLabel(pageSkate, "SKATEBOARD")
makeButton(pageSkate, "TOGGLE BOARD (X)", function() toggleBoard() end)
makeToggle(pageSkate, "Underglow", "skateUnderglow", function(v)
    if Skate.underglowLight then Skate.underglowLight.Enabled = v end
end)
makeToggle(pageSkate, "Board trail", "skateTrailEnabled")
makeToggle(pageSkate, "Manual (hold S)", "skateManualEnabled")
makeLabel(pageSkate, "CONTROLS")
local si = Instance.new("TextLabel", pageSkate)
si.Size = UDim2.new(1,0,0,80); si.BackgroundTransparency = 1
si.Font = T.font
si.Text = "Space ground = OLLIE\nSpace air = KICKFLIP\nQ = SHOVE-IT | E = HEELFLIP\nHold S = MANUAL"
si.TextColor3 = T.dim; si.TextSize = 11
si.TextXAlignment = Enum.TextXAlignment.Left
si.TextYAlignment = Enum.TextYAlignment.Top; si.TextWrapped = true
makeLabel(pageSkate, "TUNING")
makeSlider(pageSkate, "Pop power", "skatePopPower", 5, 60, "")
makeSlider(pageSkate, "Flip duration", "skateFlipTime", 0.2, 1.0, "s")

-- Camera
makeLabel(pageCam, "FOV")
local fovValLbl = Instance.new("TextLabel", pageCam)
fovValLbl.Size = UDim2.new(1,0,0,18); fovValLbl.BackgroundTransparency = 1
fovValLbl.Font = T.fontB; fovValLbl.Text = "FOV: " .. C.fov
fovValLbl.TextColor3 = T.accent; fovValLbl.TextSize = 13
fovValLbl.TextXAlignment = Enum.TextXAlignment.Left

local fovRow = Instance.new("Frame", pageCam)
fovRow.Size = UDim2.new(1,0,0,30); fovRow.BackgroundTransparency = 1
local fovBtns = {}
local function mkFovBtn(text, value, xPos, width)
    local b = Instance.new("TextButton", fovRow)
    b.Size = UDim2.new(0,width,1,0); b.Position = UDim2.new(0,xPos,0,0)
    b.BackgroundColor3 = C.fov == value and T.accent or T.panel2
    b.BorderSizePixel = 0; b.Font = T.fontB
    b.Text = text; b.TextColor3 = C.fov == value and T.bg or T.text
    b.TextSize = 12; b.AutoButtonColor = false
    corner(b, 5)
    table.insert(fovBtns, b)
    b.MouseButton1Click:Connect(function()
        C.fov = value; fovValLbl.Text = "FOV: " .. value
        if cam then Tween:Create(cam, TweenInfo.new(0.3), {FieldOfView = value}):Play() end
        for _, c in ipairs(fovBtns) do
            local a = tonumber(c.Text) == value
            c.BackgroundColor3 = a and T.accent or T.panel2
            c.TextColor3 = a and T.bg or T.text
        end
    end)
end
mkFovBtn("70", 70, 0, 64)
mkFovBtn("80", 80, 69, 64)
mkFovBtn("90", 90, 138, 64)
mkFovBtn("100", 100, 207, 64)
mkFovBtn("110", 110, 276, 64)

makeLabel(pageCam, "VIEW")
makeToggle(pageCam, "Third person", "thirdPerson", function(v)
    if v then
        plr.CameraMode = Enum.CameraMode.Classic
        plr.CameraMaxZoomDistance = 24
        plr.CameraMinZoomDistance = 8
    else
        plr.CameraMode = Enum.CameraMode.LockFirstPerson
        plr.CameraMaxZoomDistance = 0.5
        plr.CameraMinZoomDistance = 0.5
    end
end)

-- FX
makeLabel(pageFX, "GLIDE FX")
makeToggle(pageFX, "Trail", "fxTrail", refreshFX)
makeToggle(pageFX, "Particles", "fxParticles", refreshFX)
makeToggle(pageFX, "Foot sparks", "fxFootSparks", refreshFX)
makeToggle(pageFX, "FOV kick", "fxFOVKick")
makeToggle(pageFX, "Sound", "fxSound")
makeToggle(pageFX, "Motion blur", "fxMotionBlur", refreshFX)
makeToggle(pageFX, "Rainbow trail", "fxRainbowTrail")

-- HUD
makeLabel(pageHUD, "MID SCREEN")
makeToggle(pageHUD, "Show speed", "showSpeed", function(v) speedFrame.Visible = v end)
makeToggle(pageHUD, "Show speed bar", "showSpeedBar", function(v) speedBarBg.Visible = v end)
makeToggle(pageHUD, "Show keybinds", "showMidKeys", function(v) keysFrame.Visible = v end)
makeToggle(pageHUD, "Show bhop streak", "showStreak", function(v) streakLbl.Visible = v end)

-- Misc
makeLabel(pageMisc, "CONFIG")
makeButton(pageMisc, "Save config", function()
    print(saveConfig() and "[CUCUMBER] saved" or "[CUCUMBER] save failed")
end)
makeButton(pageMisc, "Load config", function()
    print(loadConfig() and "[CUCUMBER] loaded" or "[CUCUMBER] load failed")
end)
makeLabel(pageMisc, "ACTIONS")
makeButton(pageMisc, "Respawn to spawn", function()
    if hrp then hrp.CFrame = CFrame.new(spawnPos); vel = Vector3.zero end
end)
makeButton(pageMisc, "Unload script", function()
    saveConfig(); detachBoard()
    if glideSound then glideSound:Destroy() end
    if motionBlur then motionBlur:Destroy() end
    hud:Destroy(); gui:Destroy()
    script.Parent = nil
end)

-- drag
do
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = menu.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragStart
            menu.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

-- MOUSE UNLOCK (Z + menu)
local menuOpen = false
local mouseUnlocked = false

RS:BindToRenderStep("CucumberMouseUnlock", Enum.RenderPriority.Camera.Value + 1, function()
    if menuOpen or mouseUnlocked then
        if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then
            UIS.MouseBehavior = Enum.MouseBehavior.Default
        end
        if not UIS.MouseIconEnabled then UIS.MouseIconEnabled = true end
    end
end)

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Z then
        mouseUnlocked = true
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        UIS.MouseIconEnabled = true
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Z then
        mouseUnlocked = false
        if not menuOpen then
            UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
        end
    end
end)

local function openMenu()
    menuOpen = true; menu.Visible = true; glow.Visible = true
    UIS.MouseBehavior = Enum.MouseBehavior.Default
    UIS.MouseIconEnabled = true
    if currentTab == nil then selectTab("Movement") end
end
local function closeMenu()
    menuOpen = false; menu.Visible = false; glow.Visible = false
    if not mouseUnlocked then
        UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
    end
end
local function toggleMenu()
    if menuOpen then closeMenu() else openMenu() end
end

closeBtn.MouseButton1Click:Connect(closeMenu)
closeBtn.MouseEnter:Connect(function()
    Tween:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = T.danger, TextColor3 = Color3.new(1,1,1)}):Play()
end)
closeBtn.MouseLeave:Connect(function()
    Tween:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = T.panel2, TextColor3 = T.dim}):Play()
end)

UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        toggleMenu()
    end
end)

loadConfig()
if cam then cam.FieldOfView = C.fov end
selectTab("Movement")

-- ============================================================
-- HUD UPDATE
-- ============================================================
RS.RenderStepped:Connect(function()
    if not hrp or not hrp.Parent then return end
    local v = hrp.AssemblyLinearVelocity
    local spd = Vector3.new(v.X, v.Z).Magnitude
    speedTxt.Text = string.format("%.1f", spd)

    local col = H.accent
    if spd > 50 then col = H.warn end
    if spd > 90 then col = H.danger end
    speedTxt.TextColor3 = col
    speedBarFill.BackgroundColor3 = col
    speedBarFill.Size = UDim2.new(math.clamp(spd/120, 0, 1), 0, 1, 0)

    if spd > maxSpeedSession then maxSpeedSession = spd end

    if C.showStreak and bhopStreak > 0 then
        streakLbl.Text = "x" .. bhopStreak
        local sc = H.accent
        if bhopStreak >= 10 then sc = H.warn end
        if bhopStreak >= 20 then sc = H.danger end
        streakLbl.TextColor3 = sc
    else
        streakLbl.Text = ""
    end

    setKey(kbSpace, UIS:IsKeyDown(Enum.KeyCode.Space), H.warn)
    setKey(kbCtrl,  UIS:IsKeyDown(Enum.KeyCode.LeftControl), H.accent)
    setKey(kbShift, UIS:IsKeyDown(Enum.KeyCode.LeftShift), H.accent)
    setKey(kbW,     UIS:IsKeyDown(Enum.KeyCode.W), H.accent)
    setKey(kbA,     UIS:IsKeyDown(Enum.KeyCode.A), H.accent)
    setKey(kbS,     UIS:IsKeyDown(Enum.KeyCode.S), H.accent)
    setKey(kbD,     UIS:IsKeyDown(Enum.KeyCode.D), H.accent)
    setKey(kbV,     UIS:IsKeyDown(Enum.KeyCode.V), H.accent)
    setKey(kbZ,     UIS:IsKeyDown(Enum.KeyCode.Z), Color3.fromRGB(255,200,80))
    setKey(kbX,     Skate.board ~= nil, Color3.fromRGB(120,230,100))
end)

game:BindToClose(function()
    detachBoard()
    if glideSound then glideSound:Destroy() end
    if motionBlur then motionBlur:Destroy() end
end)
