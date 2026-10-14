-- Shiv Movement — v8 (fixes + edgejump + mid-HUD + looped sound)
-- RightShift = меню
-- Space (hold) = bhop | Space (tap in air) = edgejump
-- V (hold in air) = pixel-glide
-- End = unload

local Players = game:GetService("Players")
local RS      = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local Tween   = game:GetService("TweenService")
local Sound   = game:GetService("SoundService")
local Debris  = game:GetService("Debris")

local plr  = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hrp  = char:WaitForChild("HumanoidRootPart")
local hum  = char:WaitForChild("Humanoid")

-- ============================================================
-- CONFIG
-- ============================================================
local C = {
    moveEnabled = true,
    bhopKey     = Enum.KeyCode.Space,
    jumpCd      = 0.04,
    walkSpeed   = 20,

    glideKey     = Enum.KeyCode.V,
    glideControl = 10,

    -- edgejump / jumpbug
    edgeJumpEnabled = true,
    edgeJumpLimit   = 2,      -- сколько доп. прыжков в воздухе
    edgeJumpPower   = 32,     -- вертикальный импульс (стуds/s), не сильно
    edgeJumpUsed    = 0,

    -- fx
    fxTrail       = false,
    fxParticles   = false,
    fxFootSparks  = true,
    fxFOVKick     = false,
    fxSound       = false,
    fxSpeedlines  = false,

    -- hud
    showMidKeys   = true,
    showSpeed     = true,

    -- sound
    soundId       = "rbxassetid://9120386436",  -- ветер, looped
    soundVolume   = 0.5,

    -- colors
    colTrail     = Color3.fromRGB(90, 210, 255),
    colParticle  = Color3.fromRGB(90, 210, 255),
    colSparks    = Color3.fromRGB(255, 200, 80),

    bounds    = 2048,
    margin    = 60,
    fallY     = -500,
    resetDist = 4000,
}

local vel = Vector3.zero
local lastJump = 0
local alive = true
local spawnPos = hrp.Position
local glideOn = false
local glideSpeed = 0
local glideDir = Vector3.zero
local wasOnGround = true

-- FX refs
local trail, particle, footSparks, glideSound
local baseFOV = 70
local cam = workspace.CurrentCamera
if cam then baseFOV = cam.FieldOfView end

-- ============================================================
-- FX BUILDERS
-- ============================================================
local function ensureTrail()
    if trail and trail.Parent then return end
    local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 1, 0); a0.Parent = hrp
    local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -1, 0); a1.Parent = hrp
    trail = Instance.new("Trail")
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.Lifetime = 0.35
    trail.FaceCamera = true
    trail.Color = ColorSequence.new(C.colTrail)
    trail.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    }
    trail.WidthScale = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(1, 0),
    }
    trail.Enabled = false
    trail.Parent = hrp
end

local function ensureParticles()
    if particle and particle.Parent then return end
    local att = Instance.new("Attachment"); att.Parent = hrp
    particle = Instance.new("ParticleEmitter")
    particle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particle.Color = ColorSequence.new(C.colParticle)
    particle.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 0),
    }
    particle.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    }
    particle.Lifetime = NumberRange.new(0.5, 0.8)
    particle.Rate = 0
    particle.Speed = NumberRange.new(3, 7)
    particle.SpreadAngle = Vector2.new(180, 180)
    particle.LightEmission = 1
    particle.Parent = att
end

-- искры под ногами — низкий attachment, живой фонтан
local function ensureFootSparks()
    if footSparks and footSparks.Parent then return end
    local footAtt = Instance.new("Attachment")
    footAtt.Name = "FootSparksAtt"
    footAtt.Position = Vector3.new(0, -2.5, 0)
    footAtt.Parent = hrp
    footSparks = Instance.new("ParticleEmitter")
    footSparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    footSparks.Color = ColorSequence.new(C.colSparks)
    footSparks.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(1, 0),
    }
    footSparks.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    }
    footSparks.Lifetime = NumberRange.new(0.4, 0.7)
    footSparks.Rate = 0                    -- управляется в main loop
    footSparks.Speed = NumberRange.new(8, 14)   -- вверх в стороны
    footSparks.SpreadAngle = Vector2.new(60, 60)
    footSparks.Rotation = NumberRange.new(0, 360)
    footSparks.RotSpeed = NumberRange.new(-180, 180)
    footSparks.LightEmission = 1
    footSparks.Acceleration = Vector3.new(0, 20, 0)
    footSparks.Parent = footAtt
end

-- looped glide sound
local function ensureGlideSound()
    if glideSound and glideSound.Parent then return end
    glideSound = Instance.new("Sound")
    glideSound.Name = "ShivGlideSound"
    glideSound.SoundId = C.soundId
    glideSound.Looped = true
    glideSound.Volume = 0
    glideSound.PlaybackSpeed = 1.2
    glideSound.Parent = Sound
    glideSound:Play()
end

local function refreshFX()
    if C.fxTrail then ensureTrail() end
    if C.fxParticles then ensureParticles() end
    if C.fxFootSparks then ensureFootSparks() end
    if not C.fxTrail and trail then trail.Enabled = false end
    if not C.fxParticles and particle then particle.Rate = 0 end
    if not C.fxFootSparks and footSparks then footSparks.Rate = 0 end
end

local function setGlideFX(on)
    if C.fxTrail then
        ensureTrail()
        trail.Color = ColorSequence.new(C.colTrail)
        trail.Enabled = on
    end
    if C.fxParticles then
        ensureParticles()
        particle.Color = ColorSequence.new(C.colParticle)
        particle.Rate = on and 40 or 0
    end
    if C.fxSound then
        ensureGlideSound()
        local targetVol = on and C.soundVolume or 0
        Tween:Create(glideSound, TweenInfo.new(0.3), { Volume = targetVol }):Play()
    end
    if on and C.fxFOVKick and cam then
        Tween:Create(cam, TweenInfo.new(0.15), { FieldOfView = baseFOV + 8 }):Play()
    end
    if not on and C.fxFOVKick and cam then
        Tween:Create(cam, TweenInfo.new(0.3), { FieldOfView = baseFOV }):Play()
    end
end

local function edgeJump()
    if not C.edgeJumpEnabled then return end
    if C.edgeJumpUsed >= C.edgeJumpLimit then return end
    C.edgeJumpUsed = C.edgeJumpUsed + 1
    local cur = hrp.AssemblyLinearVelocity
    local vy = math.max(cur.Y, C.edgeJumpPower)
    hrp.AssemblyLinearVelocity = Vector3.new(cur.X, vy, cur.Z)
end

-- ============================================================
-- INPUT
-- ============================================================
local function mv()
    local m = hum.MoveDirection
    if m.Magnitude < 0.01 then return nil end
    return Vector3.new(m.X, 0, m.Z).Unit
end
local function keyDown(k) return UIS:IsKeyDown(k) end

local function hookCharacter(c)
    char = c
    hrp = c:WaitForChild("HumanoidRootPart")
    hum = c:WaitForChild("Humanoid")
    vel = Vector3.zero
    alive = true
    glideOn = false
    C.edgeJumpUsed = 0
    spawnPos = hrp.Position
    hum.WalkSpeed = C.walkSpeed
    hum.Died:Connect(function() alive = false end)
    trail, particle, footSparks = nil, nil, nil
    refreshFX()
end
plr.CharacterAdded:Connect(hookCharacter)
hum.Died:Connect(function() alive = false end)
hum.WalkSpeed = C.walkSpeed

UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.End then
        if glideSound then glideSound:Destroy() end
        script.Parent = nil
    end
end)

-- отдельный listener для edgejump: Space нажат в воздухе
UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if not C.edgeJumpEnabled or not alive or not hrp then return end
    if i.KeyCode == C.bhopKey then
        local onG = hum:GetState() == Enum.HumanoidStateType.Running
                 or hum:GetState() == Enum.HumanoidStateType.Landed
        if not onG then
            edgeJump()
        end
    end
end)

-- ============================================================
-- MAIN
-- ============================================================
RS.Heartbeat:Connect(function(dt)
    if not alive or not hrp or not hum or not C.moveEnabled then return end

    local st = hum:GetState()
    local onG = st == Enum.HumanoidStateType.Running
             or st == Enum.HumanoidStateType.Landed
    local m = mv()

    -- edgejump counter reset при касании земли
    if onG and not wasOnGround then
        C.edgeJumpUsed = 0
    end
    wasOnGround = onG

    local ev = hrp.AssemblyLinearVelocity
    vel = Vector3.new(vel.X, ev.Y, vel.Z)

    -- GLIDE
    local wantGlide = keyDown(C.glideKey) and not onG
    if wantGlide ~= glideOn then
        glideOn = wantGlide
        if glideOn then
            local h = Vector3.new(vel.X, 0, vel.Z)
            glideSpeed = h.Magnitude
            if glideSpeed > 0.1 then
                glideDir = h.Unit
            else
                local look = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
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
        if m then
            local turn = C.glideControl * dt
            local newDir = (glideDir + m * turn)
            if newDir.Magnitude > 0.001 then
                glideDir = newDir.Unit
            end
        end
        local h = glideDir * glideSpeed
        hrp.AssemblyLinearVelocity = Vector3.new(h.X, 0, h.Z)
        vel = Vector3.new(h.X, 0, h.Z)

        -- foot sparks работают и в glide
        if C.fxFootSparks then
            ensureFootSparks()
            footSparks.Rate = 60
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
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
        return
    end

    -- BHOP
    if onG then
        if keyDown(C.bhopKey) then
            if tick() - lastJump > C.jumpCd then
                lastJump = tick()
                hum.Jump = true
            end
        end
    end

    -- foot sparks на земле/в воздухе — разные rate
    if C.fxFootSparks then
        ensureFootSparks()
        if onG then
            -- на земле лёгкий шлейф, только если бежишь
            local spd = Vector3.new(ev.X, ev.Z).Magnitude
            footSparks.Rate = spd > 2 and 25 or 0
        else
            -- в воздухе искры фонтаном
            footSparks.Rate = 45
        end
    end

    local pos = hrp.Position
    if pos.Y < C.fallY or pos.Magnitude > C.resetDist then
        hrp.CFrame = CFrame.new(spawnPos); vel = Vector3.zero
    end
end)

-- ============================================================
-- MID-SCREEN HUD (keybinds + speed)
-- ============================================================
local H = {
    bg     = Color3.fromRGB(0, 0, 0),
    text   = Color3.fromRGB(255, 255, 255),
    accent = Color3.fromRGB(90, 210, 255),
    warn   = Color3.fromRGB(255, 200, 80),
    font   = Enum.Font.GothamBold,
}

local hud = Instance.new("ScreenGui")
hud.Name = "ShivMidHUD"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.DisplayOrder = 998
hud.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
hud.Parent = plr:WaitForChild("PlayerGui")

-- speed counter (сверху центр)
local speedFrame = Instance.new("Frame")
speedFrame.Size = UDim2.new(0, 140, 0, 36)
speedFrame.Position = UDim2.new(0.5, -70, 0, 20)
speedFrame.BackgroundColor3 = H.bg
speedFrame.BackgroundTransparency = 0.6
speedFrame.BorderSizePixel = 0
speedFrame.Visible = C.showSpeed
speedFrame.Parent = hud
local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 6); sc.Parent = speedFrame
local ss = Instance.new("UIStroke")
ss.Color = H.accent; ss.Thickness = 1; ss.Transparency = 0.5
ss.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; ss.Parent = speedFrame

local speedTxt = Instance.new("TextLabel")
speedTxt.Size = UDim2.new(1, 0, 1, 0)
speedTxt.BackgroundTransparency = 1
speedTxt.Font = H.font
speedTxt.Text = "0.0"
speedTxt.TextColor3 = H.accent
speedTxt.TextSize = 20
speedTxt.Parent = speedFrame

-- keybinds (середина, под скоростью, полупрозрачные)
local keysFrame = Instance.new("Frame")
keysFrame.Size = UDim2.new(0, 260, 0, 40)
keysFrame.Position = UDim2.new(0.5, -130, 1, -70)
keysFrame.BackgroundTransparency = 1
keysFrame.Visible = C.showMidKeys
keysFrame.Parent = hud

local keysLayout = Instance.new("UIListLayout")
keysLayout.FillDirection = Enum.FillDirection.Horizontal
keysLayout.Padding = UDim.new(0, 6)
keysLayout.SortOrder = Enum.SortOrder.LayoutOrder
keysLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
keysLayout.Parent = keysFrame

local function makeKeyBadge(text, order)
    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 34, 0, 34)
    box.BackgroundColor3 = H.bg
    box.BackgroundTransparency = 0.55
    box.BorderSizePixel = 0
    box.LayoutOrder = order
    box.Parent = keysFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = box
    local st = Instance.new("UIStroke")
    st.Color = H.text; st.Thickness = 1.5; st.Transparency = 0.6
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = box
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = H.font
    lbl.Text = text
    lbl.TextColor3 = H.text
    lbl.TextSize = 14
    lbl.Parent = box
    return { box = box, stroke = st, label = lbl }
end

local kbSpace = makeKeyBadge("SPC", 1)
local kbA     = makeKeyBadge("A", 2)
local kbW     = makeKeyBadge("W", 3)
local kbD     = makeKeyBadge("D", 4)
local kbV     = makeKeyBadge("V", 5)

local function setKey(badge, on, color)
    color = color or H.accent
    badge.stroke.Color = on and color or H.text
    badge.stroke.Transparency = on and 0 or 0.6
    badge.label.TextColor3 = on and color or H.text
    badge.box.BackgroundTransparency = on and 0.25 or 0.55
end

-- ============================================================
-- MENU
-- ============================================================
local T = {
    bg      = Color3.fromRGB(12, 12, 16),
    panel   = Color3.fromRGB(18, 18, 24),
    panel2  = Color3.fromRGB(24, 24, 32),
    stroke  = Color3.fromRGB(40, 40, 52),
    text    = Color3.fromRGB(230, 230, 240),
    dim     = Color3.fromRGB(120, 120, 140),
    accent  = Color3.fromRGB(90, 210, 255),
    danger  = Color3.fromRGB(255, 90, 100),
    font    = Enum.Font.Gotham,
    fontB   = Enum.Font.GothamBold,
}

local plrGui = plr:WaitForChild("PlayerGui")
local old = plrGui:FindFirstChild("ShivMenu")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "ShivMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = plrGui

local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = p; return c
end
local function stroke(p, col, th, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or T.stroke; s.Thickness = th or 1; s.Transparency = tr or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s
end
local function pad(p, n)
    local u = Instance.new("UIPadding")
    u.PaddingTop = UDim.new(0, n); u.PaddingBottom = UDim.new(0, n)
    u.PaddingLeft = UDim.new(0, n); u.PaddingRight = UDim.new(0, n)
    u.Parent = p; return u
end

local menu = Instance.new("Frame")
menu.Name = "MainFrame"
menu.Size = UDim2.new(0, 340, 0, 420)
menu.Position = UDim2.new(0.5, -170, 0.5, -210)
menu.BackgroundColor3 = T.bg
menu.BorderSizePixel = 0
menu.Visible = false
menu.ClipsDescendants = true
menu.Parent = gui
corner(menu, 10)
stroke(menu, T.accent, 1, 0.4)

local topLine = Instance.new("Frame")
topLine.Size = UDim2.new(1, 0, 0, 2)
topLine.BackgroundColor3 = T.accent
topLine.BorderSizePixel = 0
topLine.Parent = menu

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 38)
titleBar.Position = UDim2.new(0, 0, 0, 2)
titleBar.BackgroundColor3 = T.panel
titleBar.BorderSizePixel = 0
titleBar.Parent = menu

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 200, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Font = T.fontB
title.Text = "SHIV // MENU"
title.TextColor3 = T.accent
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -34, 0.5, -13)
closeBtn.BackgroundColor3 = T.panel2
closeBtn.BorderSizePixel = 0
closeBtn.Font = T.fontB
closeBtn.Text = "×"
closeBtn.TextColor3 = T.dim
closeBtn.TextSize = 16
closeBtn.AutoButtonColor = false
closeBtn.Parent = titleBar
corner(closeBtn, 6)

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 32)
tabBar.Position = UDim2.new(0, 0, 0, 40)
tabBar.BackgroundColor3 = T.panel
tabBar.BorderSizePixel = 0
tabBar.Parent = menu

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar
pad(tabBar, 4)

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -100)
content.Position = UDim2.new(0, 10, 0, 80)
content.BackgroundTransparency = 1
content.Parent = menu

local pages = {}
local currentTab = nil

local function createPage(name, order)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = content
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page
    pages[name] = { frame = page, order = order }
    return page
end

local function createTabButton(name, order)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, 80, 1, -8)
    btn.BackgroundColor3 = T.panel2
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
    btn.Font = T.fontB
    btn.Text = name
    btn.TextColor3 = T.dim
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.LayoutOrder = order
    btn.Parent = tabBar
    corner(btn, 5)
    return btn
end

local function makeToggle(parent, label, key, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    row.Parent = parent
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = T.font
    lbl.Text = label
    lbl.TextColor3 = T.text
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 36, 0, 18)
    track.Position = UDim2.new(1, -36, 0.5, -9)
    track.BackgroundColor3 = C[key] and T.accent or T.stroke
    track.BorderSizePixel = 0
    track.Parent = row
    corner(track, 9)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = C[key] and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, 7)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row
    local function update()
        local on = C[key]
        Tween:Create(track, TweenInfo.new(0.2), {
            BackgroundColor3 = on and T.accent or T.stroke,
        }):Play()
        Tween:Create(knob, TweenInfo.new(0.2), {
            Position = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
        }):Play()
    end
    btn.MouseButton1Click:Connect(function()
        C[key] = not C[key]
        update()
        if onChange then onChange(C[key]) end
    end)
    return row
end

local function makeButton(parent, label, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = T.panel2
    btn.BorderSizePixel = 0
    btn.Font = T.fontB
    btn.Text = label
    btn.TextColor3 = T.text
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.Parent = parent
    corner(btn, 5)
    stroke(btn, T.stroke, 1, 0.3)
    btn.MouseEnter:Connect(function()
        Tween:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = T.accent }):Play()
        btn.TextColor3 = T.bg
    end)
    btn.MouseLeave:Connect(function()
        Tween:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = T.panel2 }):Play()
        btn.TextColor3 = T.text
    end)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function makeLabel(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Font = T.fontB
    lbl.Text = text
    lbl.TextColor3 = T.dim
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
    return lbl
end

-- pages
local pageMovement = createPage("Movement", 1)
local pageEdge     = createPage("Edge", 2)
local pageEffects  = createPage("Effects", 3)
local pageHUD      = createPage("HUD", 4)
local pageSafety   = createPage("Safety", 5)

local tabMovement = createTabButton("Move", 1)
local tabEdge     = createTabButton("Edge", 2)
local tabEffects  = createTabButton("FX", 3)
local tabHUD      = createTabButton("HUD", 4)
local tabSafety   = createTabButton("Safe", 5)

local function selectTab(name)
    for n, p in pairs(pages) do
        p.frame.Visible = (n == name)
    end
    local map = { Movement = tabMovement, Edge = tabEdge, Effects = tabEffects, HUD = tabHUD, Safety = tabSafety }
    for n, btn in pairs(map) do
        local active = n == name
        Tween:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = active and T.accent or T.panel2,
            BackgroundTransparency = active and 0 or 1,
            TextColor3 = active and T.bg or T.dim,
        }):Play()
    end
    currentTab = name
end

tabMovement.MouseButton1Click:Connect(function() selectTab("Movement") end)
tabEdge.MouseButton1Click:Connect(function() selectTab("Edge") end)
tabEffects.MouseButton1Click:Connect(function() selectTab("Effects") end)
tabHUD.MouseButton1Click:Connect(function() selectTab("HUD") end)
tabSafety.MouseButton1Click:Connect(function() selectTab("Safety") end)

-- Movement
makeLabel(pageMovement, "MASTER")
makeToggle(pageMovement, "Movement enabled", "moveEnabled")
makeLabel(pageMovement, "INFO")
local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, 0, 0, 60)
info.BackgroundTransparency = 1
info.Font = T.font
info.Text = "Space (hold) = bhop\nSpace (tap in air) = edgejump\nV (hold in air) = glide"
info.TextColor3 = T.dim
info.TextSize = 11
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.TextWrapped = true
info.Parent = pageMovement

-- Edge
makeLabel(pageEdge, "EDGEJUMP")
makeToggle(pageEdge, "Enable edgejump (Space in air)", "edgeJumpEnabled")
makeLabel(pageEdge, "Settings via script — C.edgeJumpLimit, C.edgeJumpPower")
makeButton(pageEdge, "Reset edgejump counter", function()
    C.edgeJumpUsed = 0
end)

-- Effects
makeLabel(pageEffects, "GLIDE FX")
makeToggle(pageEffects, "Trail", "fxTrail", refreshFX)
makeToggle(pageEffects, "Particles (glide)", "fxParticles", refreshFX)
makeToggle(pageEffects, "Foot sparks", "fxFootSparks", refreshFX)
makeToggle(pageEffects, "FOV kick", "fxFOVKick")
makeToggle(pageEffects, "Sound (looped)", "fxSound")
makeLabel(pageEffects, "PRESETS")
makeButton(pageEffects, "Clean (no FX)", function()
    C.fxTrail = false; C.fxParticles = false; C.fxFootSparks = false
    C.fxFOVKick = false; C.fxSound = false
    refreshFX()
end)
makeButton(pageEffects, "Full FX", function()
    C.fxTrail = true; C.fxParticles = true; C.fxFootSparks = true
    C.fxFOVKick = true; C.fxSound = true
    refreshFX()
end)

-- HUD
makeLabel(pageHUD, "MID SCREEN")
makeToggle(pageHUD, "Show speed", "showSpeed", function(v)
    speedFrame.Visible = v
end)
makeToggle(pageHUD, "Show keybinds", "showMidKeys", function(v)
    keysFrame.Visible = v
end)

-- Safety
makeLabel(pageSafety, "ACTIONS")
makeButton(pageSafety, "Respawn to spawn", function()
    if hrp then hrp.CFrame = CFrame.new(spawnPos); vel = Vector3.zero end
end)
makeButton(pageSafety, "Unload script", function()
    if glideSound then glideSound:Destroy() end
    hud:Destroy()
    gui:Destroy()
    script.Parent = nil
end)

-- drag
do
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = menu.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            menu.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

local menuOpen = false
local function openMenu()
    menuOpen = true
    menu.Visible = true
    if currentTab == nil then selectTab("Movement") end
end
local function closeMenu() menuOpen = false; menu.Visible = false end
local function toggleMenu() if menuOpen then closeMenu() else openMenu() end end

closeBtn.MouseButton1Click:Connect(closeMenu)
UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        toggleMenu()
    elseif i.KeyCode == Enum.KeyCode.End then
        if glideSound then glideSound:Destroy() end
        hud:Destroy()
        gui:Destroy()
        script.Parent = nil
    end
end)

selectTab("Movement")

-- ============================================================
-- MID-HUD UPDATE
-- ============================================================
RS.RenderStepped:Connect(function()
    if not hrp or not hrp.Parent then return end
    local v = hrp.AssemblyLinearVelocity
    local spd = Vector3.new(v.X, v.Z).Magnitude
    speedTxt.Text = string.format("%.1f", spd)
    local col = H.accent
    if spd > 50 then col = H.warn end
    if spd > 90 then col = Color3.fromRGB(255, 90, 100) end
    speedTxt.TextColor3 = col

    setKey(kbSpace, UIS:IsKeyDown(Enum.KeyCode.Space), H.warn)
    setKey(kbA,     UIS:IsKeyDown(Enum.KeyCode.A), H.accent)
    setKey(kbW,     UIS:IsKeyDown(Enum.KeyCode.W), H.accent)
    setKey(kbD,     UIS:IsKeyDown(Enum.KeyCode.D), H.accent)
    setKey(kbV,     UIS:IsKeyDown(Enum.KeyCode.V), Color3.fromRGB(90, 230, 130))
end)

-- чистим звук при выходе из игры
game:BindToClose(function()
    if glideSound then glideSound:Destroy() end
end)
