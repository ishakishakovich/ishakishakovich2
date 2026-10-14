-- ============================================================
-- CUCUMBER Movement — v19 Public Release
-- Author: Shiv for He
-- RightShift = menu | Z = unlock mouse | End = unload
-- ============================================================
-- Features:
--   • Bhop / Auto-jump
--   • Autostrafe (Source-style)
--   • Pixel-glide (V)
--   • Edgejump / Edgebug (Ctrl)
--   • Counter-strafe (fast stop)
--   • Slide (C)
--   • Double-jump (optional)
--   • Skateboard with tricks (X)
--   • HUD: speed, keybinds, streak, FPS, ping
--   • Anti-AFK
--   • Config profiles + save/load
--   • Theme switcher
-- ============================================================

local Players = game:GetService("Players")
local RS      = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local Tween   = game:GetService("TweenService")
local Sound   = game:GetService("SoundService")
local Http    = game:GetService("HttpService")
local Debris  = game:GetService("Debris")

-- ── Environment guards ──────────────────────────────────────
if _G.__CUCUMBER_LOADED then
    warn("[CUCUMBER] already loaded, unloading previous instance")
    if _G.__CUCUMBER_UNLOAD then _G.__CUCUMBER_UNLOAD() end
end
_G.__CUCUMBER_LOADED = true

local plr  = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hrp  = char:WaitForChild("HumanoidRootPart")
local hum  = char:WaitForChild("Humanoid")
local cam  = workspace.CurrentCamera

local CONFIG_FILE = "cucumber_v19.json"
local HAS_FILE_IO = (typeof(writefile) == "function") and (typeof(readfile) == "function")
local HAS_HTTP    = pcall(function() return Http:JSONEncode({}) end)

-- ============================================================
-- CONFIG
-- ============================================================
local C = {
    -- master
    moveEnabled = true,
    theme       = "green",   -- green / cyan / red / purple / pink

    -- bhop
    bhopKey    = Enum.KeyCode.Space,
    jumpCd     = 0.04,
    walkSpeed  = 24,
    bhopIgnoreWalkSpeed = true,
    acSafeMode = true,       -- auto-slow if game filters

    -- air
    autostrafeEnabled  = true,
    autostrafeKey      = Enum.KeyCode.LeftShift,
    autostrafeAccel    = 90,
    autostrafeMaxSpeed = 110,

    -- glide
    glideKey     = Enum.KeyCode.V,
    glideControl = 10,
    autoSurfEnabled = true,

    -- edge
    edgeJumpEnabled = true,
    edgeJumpKey     = Enum.KeyCode.LeftControl,
    edgeJumpLimit   = 2,
    edgeJumpPower   = 20,
    edgeJumpUsed    = 0,
    edgebugEnabled  = true,
    edgebugKey      = Enum.KeyCode.LeftControl,
    edgebugLookDist = 3,
    edgebugCooldown = 0.15,

    -- counter-strafe
    counterStrafeEnabled = true,
    counterStrafePower   = 0.88,

    -- slide
    slideEnabled = true,
    slideKey     = Enum.KeyCode.C,
    slidePower   = 40,
    slideDuration = 0.5,
    slideCooldown = 1.0,

    -- double jump
    doubleJumpEnabled = false,
    doubleJumpPower   = 30,

    -- skate
    skateKey         = Enum.KeyCode.X,
    skateEnabled     = false,
    skatePopPower    = 30,
    skateFlipTime    = 0.45,
    skateCooldown    = 0.5,
    skateShoveKey    = Enum.KeyCode.Q,
    skateHeelKey     = Enum.KeyCode.E,
    skateManualKey   = Enum.KeyCode.S,
    skateUnderglow   = true,
    skateTrailEnabled = true,

    -- fx
    fxTrail      = false,
    fxParticles  = false,
    fxFootSparks = true,
    fxFOVKick    = false,
    fxSound      = false,
    fxMotionBlur = false,
    fxRainbow    = false,

    -- hud
    showSpeed    = true,
    showSpeedBar = true,
    showStreak   = true,
    showMidKeys  = true,
    showFPS      = true,
    showPing     = true,

    -- util
    antiAfkEnabled = true,

    -- keys
    menuKey      = Enum.KeyCode.RightShift,
    mouseKey     = Enum.KeyCode.Z,
    unloadKey    = Enum.KeyCode.End,

    -- colors (set by theme)
    colAccent  = Color3.fromRGB(120, 230, 100),
    colAccent2 = Color3.fromRGB(80, 180, 70),
    colTrail   = Color3.fromRGB(120, 230, 100),
    colSparks  = Color3.fromRGB(180, 255, 120),

    soundId = "rbxassetid://9120386436",
    soundVolume = 0.5,

    bounds    = 2048,
    margin    = 60,
    fallY     = -500,
    resetDist = 4000,
}

-- ============================================================
-- THEMES
-- ============================================================
local THEMES = {
    green  = {accent = Color3.fromRGB(120,230,100), accent2 = Color3.fromRGB(80,180,70),  trail = Color3.fromRGB(120,230,100), sparks = Color3.fromRGB(180,255,120)},
    cyan   = {accent = Color3.fromRGB(90,210,255),  accent2 = Color3.fromRGB(60,150,200), trail = Color3.fromRGB(90,210,255),  sparks = Color3.fromRGB(150,240,255)},
    red    = {accent = Color3.fromRGB(255,90,100),  accent2 = Color3.fromRGB(180,60,70),  trail = Color3.fromRGB(255,90,100),  sparks = Color3.fromRGB(255,150,150)},
    purple = {accent = Color3.fromRGB(180,120,255), accent2 = Color3.fromRGB(120,80,200), trail = Color3.fromRGB(180,120,255), sparks = Color3.fromRGB(220,180,255)},
    pink   = {accent = Color3.fromRGB(255,120,200), accent2 = Color3.fromRGB(200,80,160), trail = Color3.fromRGB(255,120,200), sparks = Color3.fromRGB(255,180,220)},
}
local function applyTheme(name)
    local t = THEMES[name] or THEMES.green
    C.colAccent  = t.accent
    C.colAccent2 = t.accent2
    C.colTrail   = t.trail
    C.colSparks  = t.sparks
    if trail then trail.Color = ColorSequence.new(C.colTrail) end
    if footSparks then footSparks.Color = ColorSequence.new(C.colSparks) end
    if particle then particle.Color = ColorSequence.new(C.colAccent) end
end

-- ============================================================
-- CONFIG SAVE / LOAD
-- ============================================================
local function saveConfig()
    if not HAS_FILE_IO then return false end
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
    if not HAS_FILE_IO then return false end
    return (pcall(function()
        if not isfile(CONFIG_FILE) then return end
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

local splashBg = Instance.new("Frame", splash)
splashBg.Size = UDim2.new(1,0,1,0)
splashBg.BackgroundColor3 = Color3.fromRGB(8,12,8)
splashBg.BorderSizePixel = 0

local splashTitle = Instance.new("TextLabel", splashBg)
splashTitle.Size = UDim2.new(1,0,0,80)
splashTitle.Position = UDim2.new(0,0,0.5,-60)
splashTitle.BackgroundTransparency = 1
splashTitle.Font = Enum.Font.GothamBlack
splashTitle.Text = "CUCUMBER"
splashTitle.TextColor3 = Color3.fromRGB(120,230,100)
splashTitle.TextSize = 72
splashTitle.TextTransparency = 1

local splashSub = Instance.new("TextLabel", splashBg)
splashSub.Size = UDim2.new(1,0,0,24)
splashSub.Position = UDim2.new(0,0,0.5,20)
splashSub.BackgroundTransparency = 1
splashSub.Font = Enum.Font.GothamBold
splashSub.Text = "v19  •  public release"
splashSub.TextColor3 = Color3.fromRGB(90,180,80)
splashSub.TextSize = 14
splashSub.TextTransparency = 1

local splashBarBg = Instance.new("Frame", splashBg)
splashBarBg.Size = UDim2.new(0,260,0,4)
splashBarBg.Position = UDim2.new(0.5,-130,0.5,60)
splashBarBg.BackgroundColor3 = Color3.fromRGB(30,40,30)
splashBarBg.BorderSizePixel = 0
Instance.new("UICorner", splashBarBg).CornerRadius = UDim.new(1,0)

local splashBarFill = Instance.new("Frame", splashBarBg)
splashBarFill.Size = UDim2.new(0,0,1,0)
splashBarFill.BackgroundColor3 = Color3.fromRGB(120,230,100)
splashBarFill.BorderSizePixel = 0
Instance.new("UICorner", splashBarFill).CornerRadius = UDim.new(1,0)

Tween:Create(splashTitle, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
Tween:Create(splashSub,   TweenInfo.new(0.4), {TextTransparency = 0}):Play()
Tween:Create(splashBarFill, TweenInfo.new(1.2), {Size = UDim2.new(1,0,1,0)}):Play()

task.delay(1.8, function()
    Tween:Create(splashBg,      TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
    Tween:Create(splashTitle,   TweenInfo.new(0.4), {TextTransparency = 1}):Play()
    Tween:Create(splashSub,     TweenInfo.new(0.4), {TextTransparency = 1}):Play()
    Tween:Create(splashBarBg,   TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    Tween:Create(splashBarFill, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    task.delay(0.5, function()
        if splash then splash:Destroy() end
    end)
end)

-- ============================================================
-- STATE
-- ============================================================
local vel          = Vector3.zero
local lastJump     = 0
local alive        = true
local spawnPos     = hrp.Position
local glideOn      = false
local glideSpeed   = 0
local glideDir     = Vector3.zero
local wasOnGround  = true
local lastEdgebugAt = 0
local bhopStreak   = 0
local maxSpeedSession = 0
local slideOn      = false
local slideEndAt   = 0
local lastSlideAt  = 0
local doubleJumpUsed = false

local trail, particle, footSparks, glideSound, motionBlur

-- ============================================================
-- FX BUILDERS (safe)
-- ============================================================
local function ensureTrail()
    if trail and trail.Parent then return end
    if not hrp then return end
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
    trail.Enabled = false
    trail.Parent = hrp
end

local function ensureParticles()
    if particle and particle.Parent then return end
    if not hrp then return end
    local a = Instance.new("Attachment", hrp)
    particle = Instance.new("ParticleEmitter")
    particle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particle.Color = ColorSequence.new(C.colAccent)
    particle.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0,0.4), NumberSequenceKeypoint.new(1,0)}
    particle.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0,0.1), NumberSequenceKeypoint.new(1,1)}
    particle.Lifetime = NumberRange.new(0.5,0.8); particle.Rate = 0
    particle.Speed = NumberRange.new(3,7); particle.SpreadAngle = Vector2.new(180,180)
    particle.LightEmission = 1
    particle.Parent = a
end

local function ensureFootSparks()
    if footSparks and footSparks.Parent then return end
    if not hrp then return end
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
    footSparks.LightEmission = 1
    footSparks.Acceleration = Vector3.new(0,20,0)
    footSparks.Parent = a
end

local function ensureGlideSound()
    if glideSound and glideSound.Parent then return end
    glideSound = Instance.new("Sound")
    glideSound.SoundId = C.soundId; glideSound.Looped = true
    glideSound.Volume = 0; glideSound.PlaybackSpeed = 1.2
    glideSound.Parent = Sound
    pcall(function() glideSound:Play() end)
end

local function ensureMotionBlur()
    if motionBlur and motionBlur.Parent then return end
    if not cam then return end
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
        if not C.fxRainbow then trail.Color = ColorSequence.new(C.colTrail) end
        trail.Enabled = on
    end
    if C.fxParticles then
        ensureParticles()
        if not C.fxRainbow then particle.Color = ColorSequence.new(C.colAccent) end
        particle.Rate = on and 40 or 0
    end
    if C.fxSound then
        ensureGlideSound()
        if glideSound then
            Tween:Create(glideSound, TweenInfo.new(0.3), {
                Volume = on and C.soundVolume or 0}):Play()
        end
    end
    if C.fxFOVKick and cam then
        local target = on and 98 or 90
        Tween:Create(cam, TweenInfo.new(on and 0.15 or 0.3), {
            FieldOfView = target}):Play()
    end
    if C.fxMotionBlur then
        ensureMotionBlur()
        if motionBlur then
            Tween:Create(motionBlur, TweenInfo.new(0.3), {
                Size = on and 8 or 0}):Play()
        end
    end
end

-- rainbow trail background loop
task.spawn(function()
    local hue = 0
    while _G.__CUCUMBER_LOADED do
        RS.Heartbeat:Wait()
        if C.fxRainbow then
            hue = (hue + 0.005) % 1
            local col = Color3.fromHSV(hue, 0.9, 1)
            if trail and trail.Parent then trail.Color = ColorSequence.new(col) end
            if particle and particle.Parent then particle.Color = ColorSequence.new(col) end
        end
    end
end)

-- ============================================================
-- SKATEBOARD
-- ============================================================
local Skate = {
    board = nil, weld = nil, lastFlipAt = 0,
    flipping = false, manualOn = false,
    underglowLight = nil, boardTrail = nil,
}

local function buildBoard()
    if Skate.board and Skate.board.Parent then return Skate.board end
    if not hrp then return nil end

    local m = Instance.new("Model"); m.Name = "CucumberSkate"

    local deck = Instance.new("Part")
    deck.Name = "Deck"
    deck.Size = Vector3.new(2.6, 0.15, 0.75)
    deck.Color = Color3.fromRGB(18, 18, 20)
    deck.Material = Enum.Material.Metal
    deck.Reflectance = 0.25
    deck.CanCollide = false; deck.Massless = true
    deck.TopSurface = Enum.SurfaceType.Smooth
    deck.BottomSurface = Enum.SurfaceType.Smooth
    deck.Parent = m

    local grip = Instance.new("Part")
    grip.Name = "Grip"
    grip.Size = Vector3.new(2.4, 0.03, 0.68)
    grip.Color = Color3.fromRGB(12, 12, 12)
    grip.Material = Enum.Material.Fabric
    grip.CanCollide = false; grip.Massless = true
    grip.Parent = m

    local stripL = Instance.new("Part")
    stripL.Name = "StripL"
    stripL.Size = Vector3.new(2.5, 0.08, 0.05)
    stripL.Color = C.colAccent
    stripL.Material = Enum.Material.Neon
    stripL.CanCollide = false; stripL.Massless = true
    stripL.Parent = m

    local stripR = stripL:Clone(); stripR.Name = "StripR"; stripR.Parent = m

    local nose = Instance.new("Part")
    nose.Name = "Nose"
    nose.Size = Vector3.new(0.15, 0.18, 0.7)
    nose.Color = C.colAccent
    nose.Material = Enum.Material.Neon
    nose.CanCollide = false; nose.Massless = true
    nose.Parent = m
    local tail = nose:Clone(); tail.Name = "Tail"; tail.Parent = m

    local tL = Instance.new("Part")
    tL.Name = "TruckL"
    tL.Size = Vector3.new(0.25, 0.18, 0.55)
    tL.Color = Color3.fromRGB(180,180,190)
    tL.Material = Enum.Material.Metal
    tL.Reflectance = 0.4
    tL.CanCollide = false; tL.Massless = true
    tL.Parent = m
    local tR = tL:Clone(); tR.Name = "TruckR"; tR.Parent = m

    local wheels = {}
    for i = 1, 4 do
        local w = Instance.new("Part")
        w.Name = "Wheel" .. i
        w.Shape = Enum.PartType.Cylinder
        w.Size = Vector3.new(0.22, 0.38, 0.38)
        w.Color = C.colAccent
        w.Material = Enum.Material.Neon
        w.CanCollide = false; w.Massless = true
        w.Orientation = Vector3.new(0,0,90)
        w.Parent = m
        wheels[i] = w

        local hub = Instance.new("Part")
        hub.Name = "Hub" .. i
        hub.Shape = Enum.PartType.Cylinder
        hub.Size = Vector3.new(0.24, 0.16, 0.16)
        hub.Color = Color3.fromRGB(30,30,35)
        hub.Material = Enum.Material.Metal
        hub.Reflectance = 0.3
        hub.CanCollide = false; hub.Massless = true
        hub.Orientation = Vector3.new(0,0,90)
        hub.Parent = m
    end

    local boltPositions = {
        Vector3.new(-1.0,0,0.25), Vector3.new(-1.0,0,-0.25),
        Vector3.new(1.0,0,0.25),  Vector3.new(1.0,0,-0.25),
        Vector3.new(-0.7,0,0.25), Vector3.new(-0.7,0,-0.25),
        Vector3.new(0.7,0,0.25),  Vector3.new(0.7,0,-0.25),
    }
    for i, _ in ipairs(boltPositions) do
        local bolt = Instance.new("Part")
        bolt.Name = "Bolt" .. i
        bolt.Shape = Enum.PartType.Cylinder
        bolt.Size = Vector3.new(0.05, 0.08, 0.08)
        bolt.Color = Color3.fromRGB(220,220,220)
        bolt.Material = Enum.Material.Metal
        bolt.Reflectance = 0.6
        bolt.CanCollide = false; bolt.Massless = true
        bolt.Orientation = Vector3.new(0,0,90)
        bolt.Parent = m
    end

    local lightAtt = Instance.new("Attachment", deck)
    lightAtt.Position = Vector3.new(0,-0.5,0)
    local light = Instance.new("PointLight", lightAtt)
    light.Color = C.colAccent
    light.Brightness = 3
    light.Range = 12
    light.Shadows = false
    if not C.skateUnderglow then light.Enabled = false end
    Skate.underglowLight = light

    m.PrimaryPart = deck

    local function weldTo(child, offset)
        child.CFrame = deck.CFrame * offset
        local w = Instance.new("WeldConstraint")
        w.Part0 = deck; w.Part1 = child; w.Parent = deck
    end

    weldTo(grip, CFrame.new(0,0.09,0))
    weldTo(stripL, CFrame.new(0,0,0.38))
    weldTo(stripR, CFrame.new(0,0,-0.38))
    weldTo(nose, CFrame.new(1.32,0.05,0))
    weldTo(tail, CFrame.new(-1.32,0.05,0))
    weldTo(tL, CFrame.new(-0.9,-0.15,0))
    weldTo(tR, CFrame.new(0.9,-0.15,0))
    weldTo(wheels[1], CFrame.new(-0.9,-0.32,0.42))
    weldTo(wheels[2], CFrame.new(-0.9,-0.32,-0.42))
    weldTo(wheels[3], CFrame.new(0.9,-0.32,0.42))
    weldTo(wheels[4], CFrame.new(0.9,-0.32,-0.42))

    for i = 1, 4 do
        local hub = m:FindFirstChild("Hub" .. i)
        if hub then
            hub.CFrame = wheels[i].CFrame
            local w = Instance.new("WeldConstraint")
            w.Part0 = wheels[i]; w.Part1 = hub; w.Parent = wheels[i]
        end
    end

    for i = 1, 8 do
        local bolt = m:FindFirstChild("Bolt" .. i)
        if bolt then
            weldTo(bolt, CFrame.new(boltPositions[i].X, 0.09, boltPositions[i].Z))
        end
    end

    if C.skateTrailEnabled then
        local a0 = Instance.new("Attachment", deck); a0.Position = Vector3.new(0.8,-0.4,0)
        local a1 = Instance.new("Attachment", deck); a1.Position = Vector3.new(-0.8,-0.4,0)
        local bt = Instance.new("Trail")
        bt.Attachment0 = a0; bt.Attachment1 = a1
        bt.Lifetime = 0.25; bt.MinLength = 0
        bt.FaceCamera = true
        bt.Color = ColorSequence.new(C.colAccent)
        bt.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0,0.3), NumberSequenceKeypoint.new(1,1)}
        bt.WidthScale = NumberSequence.new{
            NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0)}
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
    if not m or not m.PrimaryPart then return end
    local deck = m.PrimaryPart
    deck.CFrame = hrp.CFrame * CFrame.new(0, -3.0, 0)
    if Skate.weld then Skate.weld:Destroy() end
    local w = Instance.new("WeldConstraint")
    w.Part0 = hrp; w.Part1 = deck; w.Parent = hrp
    Skate.weld = w
    Skate.lastFlipAt = 0
    Skate.flipping = false
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
    if not Skate.board or not Skate.board.PrimaryPart then return end
    if tick() - Skate.lastFlipAt < C.skateCooldown then return end
    Skate.lastFlipAt = tick()
    Skate.flipping = true
    local deck = Skate.board.PrimaryPart
    local origWeld = Skate.weld
    task.spawn(function()
        local t = 0
        if origWeld then origWeld:Destroy(); Skate.weld = nil end
        while t < dur and Skate.flipping and deck.Parent and hrp and hrp.Parent do
            local dt = RS.Heartbeat:Wait()
            t = t + dt
            local a = math.clamp(t/dur, 0, 1)
            local rot
            if axis == "x" then
                rot = CFrame.Angles(math.rad(360*a),0,0)
            elseif axis == "y" then
                rot = CFrame.Angles(0,math.rad(360*a),0)
            elseif axis == "x-rev" then
                rot = CFrame.Angles(math.rad(-360*a),0,0)
            else
                rot = CFrame.new()
            end
            deck.CFrame = (hrp.CFrame * CFrame.new(0,-3.0,0)) * rot
        end
        if deck.Parent and hrp and hrp.Parent then
            deck.CFrame = hrp.CFrame * CFrame.new(0,-3.0,0)
            local w = Instance.new("WeldConstraint")
            w.Part0 = hrp; w.Part1 = deck; w.Parent = hrp
            Skate.weld = w
        end
        Skate.flipping = false
    end)
end

local function doKickflip() doTrick("x", C.skateFlipTime) end
local function doShoveit()  doTrick("y", C.skateFlipTime) end
local function doHeelflip() doTrick("x-rev", C.skateFlipTime) end

local function doPop()
    if not hrp then return end
    local cur = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = Vector3.new(cur.X, math.max(cur.Y, C.skatePopPower), cur.Z)
end

-- ============================================================
-- HELPERS
-- ============================================================
local function raycastDir(dir, dist)
    if not hrp then return nil end
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances = {char}
    p.IgnoreWater = true
    return workspace:Raycast(hrp.Position, dir * dist, p)
end

local function findSurfPlane()
    if not C.autoSurfEnabled then return nil end
    local r = raycastDir(Vector3.new(0,-1,0), 3)
    if not r then return nil end
    local d = r.Normal:Dot(Vector3.yAxis)
    if d >= 0.15 and d <= 0.96 then return r.Normal end
    return nil
end

local function mv()
    if not hum then return nil end
    local m = hum.MoveDirection
    if m.Magnitude < 0.01 then return nil end
    return Vector3.new(m.X, 0, m.Z).Unit
end

local function keyDown(k) return UIS:IsKeyDown(k) end

local function edgeJump()
    if not C.edgeJumpEnabled then return end
    if not keyDown(C.edgeJumpKey) then return end
    if C.edgeJumpUsed >= C.edgeJumpLimit then return end
    C.edgeJumpUsed = C.edgeJumpUsed + 1
    local cur = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = Vector3.new(cur.X, math.max(cur.Y, C.edgeJumpPower), cur.Z)
end

local function tryEdgebug()
    if not C.edgebugEnabled then return end
    if not keyDown(C.edgebugKey) then return end
    if tick() - lastEdgebugAt < C.edgebugCooldown then return end
    if not raycastDir(Vector3.new(0,-1,0), C.edgebugLookDist) then return end
    local fwd = hrp.CFrame.LookVector
    local f = Vector3.new(fwd.X, 0, fwd.Z)
    if f.Magnitude < 0.01 then f = Vector3.new(0,0,-1) end
    f = f.Unit
    if not raycastDir(f * (C.edgebugLookDist*0.7) + Vector3.new(0,-0.5,0), 1) then return end
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

-- ============================================================
-- CHARACTER HOOK
-- ============================================================
local function hookCharacter(c)
    -- cleanup previous
    if trail then trail:Destroy(); trail = nil end
    if particle then particle:Destroy(); particle = nil end
    if footSparks then footSparks:Destroy(); footSparks = nil end
    detachBoard()

    char = c
    hrp = c:WaitForChild("HumanoidRootPart")
    hum = c:WaitForChild("Humanoid")
    cam = workspace.CurrentCamera

    vel = Vector3.zero
    alive = true
    glideOn = false
    doubleJumpUsed = false
    slideOn = false
    C.edgeJumpUsed = 0
    spawnPos = hrp.Position
    hum.WalkSpeed = C.walkSpeed

    if hum.Died then
        hum.Died:Connect(function() alive = false end)
    end

    refreshFX()
    if C.skateEnabled then attachBoard() end
end

plr.CharacterAdded:Connect(hookCharacter)
if hum.Died then
    hum.Died:Connect(function() alive = false end)
end
hum.WalkSpeed = C.walkSpeed

-- ============================================================
-- ANTI-AFK
-- ============================================================
task.spawn(function()
    while _G.__CUCUMBER_LOADED do
        task.wait(60 * 15)
        if C.antiAfkEnabled and alive and hum and hum.Parent then
            pcall(function()
                local old = hum.JumpPower
                hum.JumpPower = 0
                task.wait(0.1)
                hum.JumpPower = old or 50
            end)
        end
    end
end)

-- ============================================================
-- INPUT
-- ============================================================
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == C.skateKey then
        toggleBoard()
    end
end)

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if not Skate.board then return end
    if input.KeyCode == C.skateShoveKey then
        doShoveit()
    elseif input.KeyCode == C.skateHeelKey then
        doHeelflip()
    end
end)

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode ~= Enum.KeyCode.Space then return end

    if Skate.board then
        if not hum then return end
        local st = hum:GetState()
        local onG = st == Enum.HumanoidStateType.Running or st == Enum.HumanoidStateType.Landed
        if onG then doPop() else doKickflip() end
        return
    end

    if not hum then return end
    local onG = hum:GetState() == Enum.HumanoidStateType.Running
             or hum:GetState() == Enum.HumanoidStateType.Landed
    if not onG then
        -- double jump
        if C.doubleJumpEnabled and not doubleJumpUsed and hrp then
            local cur = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(cur.X, math.max(cur.Y, C.doubleJumpPower), cur.Z)
            doubleJumpUsed = true
            return
        end
        edgeJump()
    end
end)

-- ============================================================
-- MAIN LOOP
-- ============================================================
RS.Heartbeat:Connect(function(dt)
    if not _G.__CUCUMBER_LOADED then return end
    if not alive or not hrp or not hrp.Parent or not hum or not hum.Parent then return end
    if not C.moveEnabled then return end

    local st = hum:GetState()
    local onG = st == Enum.HumanoidStateType.Running or st == Enum.HumanoidStateType.Landed
    local m = mv()

    if onG and not wasOnGround then
        C.edgeJumpUsed = 0
        doubleJumpUsed = false
        slideOn = false
    end
    wasOnGround = onG

    local ev = hrp.AssemblyLinearVelocity
    vel = Vector3.new(vel.X, ev.Y, vel.Z)

    -- bhop / walk speed handling
    if C.bhopIgnoreWalkSpeed then
        if onG then
            if hum.WalkSpeed ~= C.walkSpeed then hum.WalkSpeed = C.walkSpeed end
        else
            if hum.WalkSpeed ~= 0 then hum.WalkSpeed = 0 end
        end
    end

    -- edgebug
    if not onG and not glideOn and st == Enum.HumanoidStateType.Freefall then
        tryEdgebug()
    end

    -- slide (C)
    if C.slideEnabled and keyDown(C.slideKey) and onG and not slideOn
       and tick() - lastSlideAt > C.slideCooldown and m then
        slideOn = true
        slideEndAt = tick() + C.slideDuration
        lastSlideAt = tick()
        local dir = m
        hrp.AssemblyLinearVelocity = Vector3.new(dir.X, ev.Y, dir.Z) * C.slidePower
    end
    if slideOn and tick() > slideEndAt then
        slideOn = false
    end

    -- glide (V)
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
            local nd = glideDir + m * turn
            if nd.Magnitude > 0.001 then glideDir = nd.Unit end
        end
        if surfN then
            local along = glideDir - surfN * glideDir:Dot(surfN)
            if along.Magnitude > 0.01 then glideDir = along.Unit end
        end
        if glideSpeed > 120 then glideSpeed = 120 end
        local h = glideDir * glideSpeed
        hrp.AssemblyLinearVelocity = Vector3.new(h.X, 0, h.Z)
        vel = Vector3.new(h.X, 0, h.Z)

        if C.fxFootSparks then
            ensureFootSparks()
            if footSparks then footSparks.Rate = 60 end
        end

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

    -- autostrafe
    if not onG and m and C.autostrafeEnabled and keyDown(C.autostrafeKey) then
        local h = Vector3.new(vel.X, 0, vel.Z)
        local curSpeed = h.Magnitude
        if curSpeed < C.autostrafeMaxSpeed then
            local add = math.min(C.autostrafeMaxSpeed - curSpeed, C.autostrafeAccel * dt)
            h = h + m * add
            vel = Vector3.new(h.X, ev.Y, h.Z)
        end
    end

    -- ground
    if onG then
        if not m and C.counterStrafeEnabled then
            local h = Vector3.new(ev.X, 0, ev.Z)
            if h.Magnitude > 1 then
                local nh = h * (1 - (1 - C.counterStrafePower) * math.min(dt*15, 1))
                hrp.AssemblyLinearVelocity = Vector3.new(nh.X, ev.Y, nh.Z)
            end
        end

        if keyDown(C.bhopKey) then
            if tick() - lastJump > C.jumpCd then
                lastJump = tick()
                hum.Jump = true
                bhopStreak = bhopStreak + 1
            end
        else
            bhopStreak = 0
        end
    end

    -- foot sparks
    if C.fxFootSparks then
        ensureFootSparks()
        if footSparks then
            if onG then
                local spd = Vector3.new(ev.X, ev.Z).Magnitude
                footSparks.Rate = spd > 2 and 25 or 0
            else
                footSparks.Rate = 45
            end
        end
    end

    -- motion blur
    if C.fxMotionBlur and motionBlur then
        local spd = Vector3.new(ev.X, ev.Z).Magnitude
        motionBlur.Size = math.clamp((spd-40)/10, 0, 10)
    end

    -- underglow
    if Skate.underglowLight and Skate.board then
        local spd = Vector3.new(ev.X, ev.Z).Magnitude
        if C.skateUnderglow then
            Skate.underglowLight.Enabled = true
            Skate.underglowLight.Brightness = 2 + math.clamp(spd/20, 0, 4)
        else
            Skate.underglowLight.Enabled = false
        end
    end

    -- safety
    local pos = hrp.Position
    if pos.Y < C.fallY or pos.Magnitude > C.resetDist then
        hrp.CFrame = CFrame.new(spawnPos)
        vel = Vector3.zero
    end
end)

-- ============================================================
-- HUD
-- ============================================================
local hud = Instance.new("ScreenGui")
hud.Name = "CucumberHUD"; hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true; hud.DisplayOrder = 998
hud.Parent = plr:WaitForChild("PlayerGui")

-- speed panel
local speedFrame = Instance.new("Frame", hud)
speedFrame.Size = UDim2.new(0,170,0,64); speedFrame.Position = UDim2.new(0.5,-85,0,20)
speedFrame.BackgroundColor3 = Color3.fromRGB(8,12,8)
speedFrame.BackgroundTransparency = 0.35
speedFrame.BorderSizePixel = 0
speedFrame.Visible = C.showSpeed
Instance.new("UICorner", speedFrame).CornerRadius = UDim.new(0,8)

local speedStroke = Instance.new("UIStroke", speedFrame)
speedStroke.Color = C.colAccent; speedStroke.Thickness = 1.5; speedStroke.Transparency = 0.3

local speedTitle = Instance.new("TextLabel", speedFrame)
speedTitle.Size = UDim2.new(1,0,0,12); speedTitle.Position = UDim2.new(0,0,0,4)
speedTitle.BackgroundTransparency = 1; speedTitle.Font = Enum.Font.GothamBold
speedTitle.Text = "CUCUMBER"; speedTitle.TextColor3 = C.colAccent2
speedTitle.TextSize = 9

local speedTxt = Instance.new("TextLabel", speedFrame)
speedTxt.Size = UDim2.new(1,0,0,30); speedTxt.Position = UDim2.new(0,0,0,16)
speedTxt.BackgroundTransparency = 1
speedTxt.Font = Enum.Font.GothamBlack
speedTxt.Text = "0.0"; speedTxt.TextColor3 = C.colAccent; speedTxt.TextSize = 24

local speedBarBg = Instance.new("Frame", speedFrame)
speedBarBg.Size = UDim2.new(1,-16,0,5); speedBarBg.Position = UDim2.new(0,8,1,-12)
speedBarBg.BackgroundColor3 = Color3.fromRGB(20,30,20)
speedBarBg.BorderSizePixel = 0
speedBarBg.Visible = C.showSpeedBar
Instance.new("UICorner", speedBarBg).CornerRadius = UDim.new(1,0)

local speedBarFill = Instance.new("Frame", speedBarBg)
speedBarFill.Size = UDim2.new(0,0,1,0); speedBarFill.BackgroundColor3 = C.colAccent
speedBarFill.BorderSizePixel = 0
Instance.new("UICorner", speedBarFill).CornerRadius = UDim.new(1,0)

-- FPS / ping
local infoFrame = Instance.new("Frame", hud)
infoFrame.Size = UDim2.new(0,170,0,22); infoFrame.Position = UDim2.new(0.5,-85,0,88)
infoFrame.BackgroundColor3 = Color3.fromRGB(8,12,8)
infoFrame.BackgroundTransparency = 0.5
infoFrame.BorderSizePixel = 0
Instance.new("UICorner", infoFrame).CornerRadius = UDim.new(0,6)

local infoLbl = Instance.new("TextLabel", infoFrame)
infoLbl.Size = UDim2.new(1,0,1,0); infoLbl.BackgroundTransparency = 1
infoLbl.Font = Enum.Font.GothamBold
infoLbl.Text = "FPS -- | PING --"
infoLbl.TextColor3 = C.colAccent2
infoLbl.TextSize = 10

-- keybinds
local keysFrame = Instance.new("Frame", hud)
keysFrame.Size = UDim2.new(0,380,0,40); keysFrame.Position = UDim2.new(0.5,-190,1,-70)
keysFrame.BackgroundTransparency = 1
keysFrame.Visible = C.showMidKeys
local keysLayout = Instance.new("UIListLayout", keysFrame)
keysLayout.FillDirection = Enum.FillDirection.Horizontal
keysLayout.Padding = UDim.new(0,6)
keysLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function makeKeyBadge(text, order)
    local box = Instance.new("Frame", keysFrame)
    box.Size = UDim2.new(0,34,0,34); box.BackgroundColor3 = Color3.fromRGB(8,12,8)
    box.BackgroundTransparency = 0.45; box.BorderSizePixel = 0
    box.LayoutOrder = order
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)
    local st = Instance.new("UIStroke", box)
    st.Color = Color3.fromRGB(230,240,230); st.Thickness = 1.5; st.Transparency = 0.6
    local lbl = Instance.new("TextLabel", box)
    lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold; lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(230,240,230); lbl.TextSize = 13
    return {box = box, stroke = st, label = lbl}
end

local kbSpace = makeKeyBadge("SPC", 1)
local kbCtrl  = makeKeyBadge("CTL", 2)
local kbShift = makeKeyBadge("SFT", 3)
local kbW     = makeKeyBadge("W", 4)
local kbA     = makeKeyBadge("A", 5)
local kbS     = makeKeyBadge("S", 6)
local kbD     = makeKeyBadge("D", 7)
local kbV     = makeKeyBadge("V", 8)
local kbX     = makeKeyBadge("X", 9)

local function setKey(badge, on)
    if not badge then return end
    local c = C.colAccent
    badge.stroke.Color = on and c or Color3.fromRGB(230,240,230)
    badge.stroke.Transparency = on and 0 or 0.6
    badge.label.TextColor3 = on and c or Color3.fromRGB(230,240,230)
    badge.box.BackgroundTransparency = on and 0.25 or 0.45
end

-- ============================================================
-- MENU
-- ============================================================
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
    s.Color = col; s.Thickness = th or 1; s.Transparency = tr or 0
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
glow.BackgroundColor3 = C.colAccent; glow.BackgroundTransparency = 0.95
glow.BorderSizePixel = 0; glow.ZIndex = 0; glow.Visible = false
corner(glow, 16)

local menu = Instance.new("Frame", gui)
menu.Name = "MainFrame"
menu.Size = UDim2.new(0, MW, 0, MH)
menu.Position = UDim2.new(0.5, -MW/2, 0.5, -MH/2)
menu.BackgroundColor3 = Color3.fromRGB(10,14,10)
menu.BorderSizePixel = 0
menu.Visible = false; menu.ClipsDescendants = true; menu.ZIndex = 1
corner(menu, 10); stroke(menu, C.colAccent, 1.5, 0.3)

local topLine = Instance.new("Frame", menu)
topLine.Size = UDim2.new(1,0,0,3); topLine.BackgroundColor3 = C.colAccent
topLine.BorderSizePixel = 0

local headerBg = Instance.new("Frame", menu)
headerBg.Size = UDim2.new(1,0,0,56); headerBg.Position = UDim2.new(0,0,0,3)
headerBg.BackgroundColor3 = Color3.fromRGB(14,20,14)
headerBg.BorderSizePixel = 0

local title = Instance.new("TextLabel", headerBg)
title.Size = UDim2.new(1,-60,0,30); title.Position = UDim2.new(0,16,0,8)
title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBlack
title.Text = "CUCUMBER"; title.TextColor3 = C.colAccent; title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left

local subtitle = Instance.new("TextLabel", headerBg)
subtitle.Size = UDim2.new(1,-60,0,14); subtitle.Position = UDim2.new(0,16,0,34)
subtitle.BackgroundTransparency = 1; subtitle.Font = Enum.Font.Gotham
subtitle.Text = "v19 public release  •  RightShift menu"
subtitle.TextColor3 = C.colAccent2; subtitle.TextSize = 10
subtitle.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", headerBg)
closeBtn.Size = UDim2.new(0,30,0,30); closeBtn.Position = UDim2.new(1,-40,0,13)
closeBtn.BackgroundColor3 = Color3.fromRGB(20,28,20); closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold; closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(100,140,100); closeBtn.TextSize = 18
closeBtn.AutoButtonColor = false
corner(closeBtn, 6)

local titleBar = headerBg

local sidebar = Instance.new("Frame", menu)
sidebar.Size = UDim2.new(0,130,1,-59); sidebar.Position = UDim2.new(0,0,0,59)
sidebar.BackgroundColor3 = Color3.fromRGB(14,20,14)
sidebar.BorderSizePixel = 0
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
    page.ScrollBarThickness = 4; page.ScrollBarImageColor3 = C.colAccent
    page.CanvasSize = UDim2.new(0,0,0,0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false; page.Parent = content
    local layout = Instance.new("UIListLayout", page)
    layout.Padding = UDim.new(0,8)
    pages[name] = {frame = page}
    return page
end

local function createTabButton(name, order)
    local btn = Instance.new("TextButton", sidebar)
    btn.Name = name; btn.Size = UDim2.new(1,0,0,32)
    btn.BackgroundColor3 = Color3.fromRGB(20,28,20)
    btn.BackgroundTransparency = 1; btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold; btn.Text = name
    btn.TextColor3 = Color3.fromRGB(100,140,100); btn.TextSize = 12
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
            BackgroundColor3 = active and C.colAccent or Color3.fromRGB(20,28,20),
            BackgroundTransparency = active and 0 or 1,
            TextColor3 = active and Color3.fromRGB(10,14,10) or Color3.fromRGB(100,140,100),
        }):Play()
    end
    currentTab = name
end

local function makeToggle(parent, label, key, onChange)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,0,0,30); row.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1,-60,1,0); lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham; lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(230,240,230); lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(0,40,0,20); track.Position = UDim2.new(1,-40,0.5,-10)
    track.BackgroundColor3 = C[key] and C.colAccent or Color3.fromRGB(40,60,40)
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
            BackgroundColor3 = on and C.colAccent or Color3.fromRGB(40,60,40)}):Play()
        Tween:Create(knob, TweenInfo.new(0.2), {
            Position = on and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)}):Play()
    end
    btn.MouseButton1Click:Connect(function()
        C[key] = not C[key]
        update()
        if onChange then
            local ok, err = pcall(onChange, C[key])
            if not ok then warn("[CUCUMBER] toggle callback error: " .. tostring(err)) end
        end
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
    lbl.Font = Enum.Font.Gotham; lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(230,240,230); lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local val = Instance.new("TextLabel", top)
    val.Size = UDim2.new(0.3,0,1,0); val.Position = UDim2.new(0.7,0,0,0)
    val.BackgroundTransparency = 1; val.Font = Enum.Font.GothamBold
    val.Text = tostring(C[key]) .. (suffix or "")
    val.TextColor3 = C.colAccent; val.TextSize = 13
    val.TextXAlignment = Enum.TextXAlignment.Right
    local bar = Instance.new("Frame", row)
    bar.Size = UDim2.new(1,0,0,6); bar.Position = UDim2.new(0,0,0,28)
    bar.BackgroundColor3 = Color3.fromRGB(40,60,40); bar.BorderSizePixel = 0
    corner(bar, 3)
    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new((C[key]-min)/(max-min),0,1,0)
    fill.BackgroundColor3 = C.colAccent; fill.BorderSizePixel = 0
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
    btn.Size = UDim2.new(1,0,0,32)
    btn.BackgroundColor3 = Color3.fromRGB(20,28,20)
    btn.BorderSizePixel = 0; btn.Font = Enum.Font.GothamBold
    btn.Text = label; btn.TextColor3 = color or Color3.fromRGB(230,240,230)
    btn.TextSize = 12; btn.AutoButtonColor = false
    corner(btn, 5); stroke(btn, Color3.fromRGB(40,60,40), 1, 0.3)
    btn.MouseEnter:Connect(function()
        Tween:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = C.colAccent}):Play()
        btn.TextColor3 = Color3.fromRGB(10,14,10)
    end)
    btn.MouseLeave:Connect(function()
        Tween:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(20,28,20)}):Play()
        btn.TextColor3 = color or Color3.fromRGB(230,240,230)
    end)
    btn.MouseButton1Click:Connect(function()
        local ok, err = pcall(callback)
        if not ok then warn("[CUCUMBER] button error: " .. tostring(err)) end
    end)
    return btn
end

local function makeLabel(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(1,0,0,20); lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold; lbl.Text = text
    lbl.TextColor3 = C.colAccent2; lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    return lbl
end

-- ============ PAGES ============
local pageMove = createPage("Movement")
local pageAir  = createPage("Air")
local pageEdge = createPage("Edge")
local pageSkate = createPage("Skate")
local pageHUD  = createPage("HUD")
local pageKeys = createPage("Keybinds")
local pageMisc = createPage("Settings")

local tabMove  = createTabButton("Movement", 1)
local tabAir   = createTabButton("Air", 2)
local tabEdge  = createTabButton("Edge", 3)
local tabSkate = createTabButton("Skate", 4)
local tabHUD   = createTabButton("HUD", 5)
local tabKeys  = createTabButton("Keybinds", 6)
local tabMisc  = createTabButton("Settings", 7)

tabMove.MouseButton1Click:Connect(function() selectTab("Movement") end)
tabAir.MouseButton1Click:Connect(function() selectTab("Air") end)
tabEdge.MouseButton1Click:Connect(function() selectTab("Edge") end)
tabSkate.MouseButton1Click:Connect(function() selectTab("Skate") end)
tabHUD.MouseButton1Click:Connect(function() selectTab("HUD") end)
tabKeys.MouseButton1Click:Connect(function() selectTab("Keybinds") end)
tabMisc.MouseButton1Click:Connect(function() selectTab("Settings") end)

-- ===== Movement =====
makeLabel(pageMove, "MASTER")
makeToggle(pageMove, "Movement enabled", "moveEnabled")
makeLabel(pageMove, "BHOP")
makeSlider(pageMove, "Walk speed", "walkSpeed", 8, 60, "")
makeSlider(pageMove, "Bhop cooldown", "jumpCd", 0.01, 0.2, "s")
makeToggle(pageMove, "Counter-strafe (fast stop)", "counterStrafeEnabled")
makeLabel(pageMove, "SLIDE (C)")
makeToggle(pageMove, "Enable slide", "slideEnabled")
makeSlider(pageMove, "Slide power", "slidePower", 20, 100, "")
makeSlider(pageMove, "Slide duration", "slideDuration", 0.2, 2.0, "s")

-- ===== Air =====
makeLabel(pageAir, "AIR STRAFE")
makeToggle(pageAir, "Autostrafe (Shift)", "autostrafeEnabled")
makeSlider(pageAir, "Air accel", "autostrafeAccel", 20, 200, "")
makeSlider(pageAir, "Air max speed", "autostrafeMaxSpeed", 40, 200, "")
makeLabel(pageAir, "PIXEL GLIDE")
makeSlider(pageAir, "Glide control", "glideControl", 2, 25, "")
makeToggle(pageAir, "Auto surf lock", "autoSurfEnabled")
makeLabel(pageAir, "DOUBLE JUMP")
makeToggle(pageAir, "Enable double jump (Space in air)", "doubleJumpEnabled")
makeSlider(pageAir, "Double jump power", "doubleJumpPower", 10, 80, "")

-- ===== Edge =====
makeLabel(pageEdge, "EDGEJUMP")
makeToggle(pageEdge, "Enable edgejump", "edgeJumpEnabled")
makeSlider(pageEdge, "Jump power", "edgeJumpPower", 5, 60, "")
makeSlider(pageEdge, "Jump limit", "edgeJumpLimit", 1, 5, "")
makeLabel(pageEdge, "EDGEBUG")
makeToggle(pageEdge, "Enable edgebug", "edgebugEnabled")
makeSlider(pageEdge, "Look dist", "edgebugLookDist", 1, 8, "st")
makeButton(pageEdge, "Reset edgejump counter", function() C.edgeJumpUsed = 0 end)

-- ===== Skate =====
makeLabel(pageSkate, "SKATEBOARD")
makeButton(pageSkate, "TOGGLE BOARD (X)", function() toggleBoard() end)
makeToggle(pageSkate, "Underglow", "skateUnderglow", function(v)
    if Skate.underglowLight then Skate.underglowLight.Enabled = v end
end)
makeLabel(pageSkate, "CONTROLS")
local sInfo = Instance.new("TextLabel", pageSkate)
sInfo.Size = UDim2.new(1,0,0,80); sInfo.BackgroundTransparency = 1
sInfo.Font = Enum.Font.Gotham
sInfo.Text = "Space ground = OLLIE\nSpace air = KICKFLIP\nQ = SHOVE-IT | E = HEELFLIP"
sInfo.TextColor3 = Color3.fromRGB(100,140,100); sInfo.TextSize = 11
sInfo.TextXAlignment = Enum.TextXAlignment.Left
sInfo.TextYAlignment = Enum.TextYAlignment.Top
sInfo.TextWrapped = true
makeLabel(pageSkate, "TUNING")
makeSlider(pageSkate, "Pop power", "skatePopPower", 5, 60, "")
makeSlider(pageSkate, "Flip duration", "skateFlipTime", 0.2, 1.0, "s")

-- ===== HUD =====
makeLabel(pageHUD, "SPEED DISPLAY")
makeToggle(pageHUD, "Show speed", "showSpeed", function(v) speedFrame.Visible = v end)
makeToggle(pageHUD, "Show speed bar", "showSpeedBar", function(v) speedBarBg.Visible = v end)
makeLabel(pageHUD, "INFO")
makeToggle(pageHUD, "Show FPS + Ping", "showFPS", function(v) infoFrame.Visible = v end)
makeToggle(pageHUD, "Show keybinds", "showMidKeys", function(v) keysFrame.Visible = v end)

-- ===== Keybinds =====
makeLabel(pageKeys, "CLICK A BUTTON, THEN PRESS A KEY")

local function makeKeybindRow(parent, label, keyName)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,0,0,32); row.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1,-100,1,0); lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham; lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(230,240,230); lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0,90,0,26); btn.Position = UDim2.new(1,-90,0.5,-13)
    btn.BackgroundColor3 = Color3.fromRGB(20,28,20); btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.Text = C[keyName] and C[keyName].Name or "?"
    btn.TextColor3 = C.colAccent; btn.TextSize = 12; btn.AutoButtonColor = false
    corner(btn, 5); stroke(btn, Color3.fromRGB(40,60,40), 1, 0.3)
    btn.MouseButton1Click:Connect(function()
        btn.Text = "..."
        btn.TextColor3 = Color3.fromRGB(255,200,80)
        local conn
        conn = UIS.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                C[keyName] = input.KeyCode
                btn.Text = input.KeyCode.Name
                btn.TextColor3 = C.colAccent
                conn:Disconnect()
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                btn.Text = C[keyName].Name
                btn.TextColor3 = C.colAccent
                conn:Disconnect()
            end
        end)
    end)
    return row
end

makeKeybindRow(pageKeys, "Bhop", "bhopKey")
makeKeybindRow(pageKeys, "Glide", "glideKey")
makeKeybindRow(pageKeys, "Edgejump / Edgebug", "edgeJumpKey")
makeKeybindRow(pageKeys, "Autostrafe", "autostrafeKey")
makeKeybindRow(pageKeys, "Slide", "slideKey")
makeKeybindRow(pageKeys, "Skate toggle", "skateKey")
makeKeybindRow(pageKeys, "Skate shove-it", "skateShoveKey")
makeKeybindRow(pageKeys, "Skate heelflip", "skateHeelKey")
makeKeybindRow(pageKeys, "Menu", "menuKey")
makeKeybindRow(pageKeys, "Mouse unlock", "mouseKey")

-- ===== Settings =====
makeLabel(pageMisc, "THEME")
local themeRow = Instance.new("Frame", pageMisc)
themeRow.Size = UDim2.new(1,0,0,30); themeRow.BackgroundTransparency = 1
local themeNames = {"green","cyan","red","purple","pink"}
local tw = 62
for i, tname in ipairs(themeNames) do
    local b = Instance.new("TextButton", themeRow)
    b.Size = UDim2.new(0,tw,1,0); b.Position = UDim2.new(0,(i-1)*(tw+4),0,0)
    b.BackgroundColor3 = THEMES[tname].accent
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold; b.Text = string.sub(tname,1,3):upper()
    b.TextColor3 = Color3.fromRGB(10,14,10); b.TextSize = 11
    b.AutoButtonColor = false
    corner(b, 5)
    b.MouseButton1Click:Connect(function()
        C.theme = tname
        applyTheme(tname)
        -- update UI colors
        speedStroke.Color = C.colAccent
        speedTxt.TextColor3 = C.colAccent
        speedBarFill.BackgroundColor3 = C.colAccent
        speedTitle.TextColor3 = C.colAccent2
        infoLbl.TextColor3 = C.colAccent2
        title.TextColor3 = C.colAccent
        subtitle.TextColor3 = C.colAccent2
        topLine.BackgroundColor3 = C.colAccent
        glow.BackgroundColor3 = C.colAccent
        -- re-select tab to refresh colors
        if currentTab then selectTab(currentTab) end
    end)
end

makeLabel(pageMisc, "CONFIG")
makeButton(pageMisc, "Save config", function()
    if saveConfig() then
        print("[CUCUMBER] config saved")
    else
        warn("[CUCUMBER] config save failed (no file access)")
    end
end)
makeButton(pageMisc, "Load config", function()
    if loadConfig() then
        applyTheme(C.theme)
        print("[CUCUMBER] config loaded")
    else
        warn("[CUCUMBER] config load failed")
    end
end)

makeLabel(pageMisc, "PROFILES")
makeButton(pageMisc, "Minimal (bhop only)", function()
    C.fxTrail = false; C.fxParticles = false; C.fxFootSparks = false
    C.fxFOVKick = false; C.fxSound = false; C.fxMotionBlur = false
    C.fxRainbow = false
    C.autostrafeEnabled = false
    C.slideEnabled = false
    C.doubleJumpEnabled = false
    C.edgeJumpEnabled = false
    C.edgebugEnabled = false
    refreshFX()
end)
makeButton(pageMisc, "Balanced", function()
    C.fxTrail = false; C.fxParticles = false; C.fxFootSparks = true
    C.fxFOVKick = false; C.fxSound = false; C.fxMotionBlur = false
    C.fxRainbow = false
    C.autostrafeEnabled = true
    C.slideEnabled = true
    C.doubleJumpEnabled = false
    C.edgeJumpEnabled = true
    C.edgebugEnabled = true
    refreshFX()
end)
makeButton(pageMisc, "Full FX", function()
    C.fxTrail = true; C.fxParticles = true; C.fxFootSparks = true
    C.fxFOVKick = true; C.fxSound = true; C.fxMotionBlur = true
    C.fxRainbow = false
    C.autostrafeEnabled = true
    C.slideEnabled = true
    C.edgeJumpEnabled = true
    C.edgebugEnabled = true
    refreshFX()
end)

makeLabel(pageMisc, "UTILITIES")
makeToggle(pageMisc, "Anti-AFK", "antiAfkEnabled")
makeButton(pageMisc, "Respawn to spawn", function()
    if hrp then hrp.CFrame = CFrame.new(spawnPos); vel = Vector3.zero end
end)
makeButton(pageMisc, "Unload script", function()
    if _G.__CUCUMBER_UNLOAD then _G.__CUCUMBER_UNLOAD() end
end)

-- ============================================================
-- DRAG
-- ============================================================
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

-- ============================================================
-- MOUSE UNLOCK
-- ============================================================
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
    if input.KeyCode == C.mouseKey then
        mouseUnlocked = true
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        UIS.MouseIconEnabled = true
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.KeyCode == C.mouseKey then
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
    Tween:Create(closeBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(255,90,100),
        TextColor3 = Color3.new(1,1,1)}):Play()
end)
closeBtn.MouseLeave:Connect(function()
    Tween:Create(closeBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(20,28,20),
        TextColor3 = Color3.fromRGB(100,140,100)}):Play()
end)

-- menu key listener (dynamic)
UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == C.menuKey then
        toggleMenu()
    end
end)

-- unload key
UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == C.unloadKey then
        if _G.__CUCUMBER_UNLOAD then _G.__CUCUMBER_UNLOAD() end
    end
end)

-- ============================================================
-- UNLOAD FUNCTION
-- ============================================================
_G.__CUCUMBER_UNLOAD = function()
    _G.__CUCUMBER_LOADED = false
    pcall(function() saveConfig() end)
    pcall(function() detachBoard() end)
    pcall(function() if glideSound then glideSound:Destroy() end end)
    pcall(function() if motionBlur then motionBlur:Destroy() end end)
    pcall(function() if trail then trail:Destroy() end end)
    pcall(function() if particle then particle:Destroy() end end)
    pcall(function() if footSparks then footSparks:Destroy() end end)
    pcall(function() if hud then hud:Destroy() end end)
    pcall(function() if gui then gui:Destroy() end end)
    pcall(function() if splash then splash:Destroy() end end)
    print("[CUCUMBER] unloaded")
end

-- ============================================================
-- INIT
-- ============================================================
loadConfig()
applyTheme(C.theme)
if cam then cam.FieldOfView = 90 end
selectTab("Movement")

-- ============================================================
-- HUD UPDATE LOOP
-- ============================================================
local fpsCount = 0
local fpsTime = tick()
local currentFPS = 60
local lastPingUpdate = 0
local currentPing = 0

RS.RenderStepped:Connect(function()
    if not _G.__CUCUMBER_LOADED then return end
    if not hrp or not hrp.Parent then return end

    -- speed
    local v = hrp.AssemblyLinearVelocity
    local spd = Vector3.new(v.X, v.Z).Magnitude
    speedTxt.Text = string.format("%.1f", spd)

    local col = C.colAccent
    if spd > 50 then col = Color3.fromRGB(230,230,100) end
    if spd > 90 then col = Color3.fromRGB(255,90,100) end
    speedTxt.TextColor3 = col
    speedBarFill.BackgroundColor3 = col
    speedBarFill.Size = UDim2.new(math.clamp(spd/120, 0, 1), 0, 1, 0)

    if spd > maxSpeedSession then maxSpeedSession = spd end

    -- FPS counter
    fpsCount = fpsCount + 1
    local now = tick()
    if now - fpsTime >= 0.5 then
        currentFPS = math.floor(fpsCount / (now - fpsTime) + 0.5)
        fpsCount = 0
        fpsTime = now
    end

    -- ping
    if now - lastPingUpdate > 1 then
        lastPingUpdate = now
        pcall(function()
            currentPing = math.floor((plr:GetNetworkPing() or 0) * 1000)
        end)
    end

    if C.showFPS then
        infoLbl.Text = string.format("FPS %d | PING %d", currentFPS, currentPing)
    end

    -- keybinds
    setKey(kbSpace, UIS:IsKeyDown(C.bhopKey))
    setKey(kbCtrl,  UIS:IsKeyDown(C.edgeJumpKey))
    setKey(kbShift, UIS:IsKeyDown(C.autostrafeKey))
    setKey(kbW,     UIS:IsKeyDown(Enum.KeyCode.W))
    setKey(kbA,     UIS:IsKeyDown(Enum.KeyCode.A))
    setKey(kbS,     UIS:IsKeyDown(Enum.KeyCode.S))
    setKey(kbD,     UIS:IsKeyDown(Enum.KeyCode.D))
    setKey(kbV,     UIS:IsKeyDown(C.glideKey))
    setKey(kbX,     Skate.board ~= nil)
end)

game:BindToClose(function()
    if _G.__CUCUMBER_UNLOAD then _G.__CUCUMBER_UNLOAD() end
end)

print("[CUCUMBER] v19 loaded successfully")
