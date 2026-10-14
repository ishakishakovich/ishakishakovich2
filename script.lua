-- Shiv Movement — v7 (menu + toggleable FX)
-- RightShift = открыть/закрыть меню
-- LeftShift = скрыть/показать HUD
-- End = unload
-- Space (держать) = bhop | V (держать в воздухе) = glide

local Players = game:GetService("Players")
local RS      = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local Tween   = game:GetService("TweenService")

local plr  = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hrp  = char:WaitForChild("HumanoidRootPart")
local hum  = char:WaitForChild("Humanoid")

-- ============================================================
-- CONFIG
-- ============================================================
local C = {
    -- movement
    moveEnabled = true,
    bhopKey     = Enum.KeyCode.Space,
    jumpCd      = 0.04,
    walkSpeed   = 20,
    glideKey    = Enum.KeyCode.V,
    glideControl= 10,

    -- effects (все выключены по дефолту)
    fxTrail        = false,
    fxParticles    = false,
    fxFOVKick      = false,
    fxSpeedlines   = false,
    fxSound        = false,
    fxFlash        = false,

    -- colors
    colTrail     = Color3.fromRGB(90, 210, 255),
    colParticle  = Color3.fromRGB(90, 210, 255),

    -- safety
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

-- ============================================================
-- MOVEMENT STATE / FX
-- ============================================================
local trail, particle, particleAttach
local baseFOV = 70
local cam = workspace.CurrentCamera
if cam then baseFOV = cam.FieldOfView end

local function ensureTrail()
    if trail then return end
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
    if particle then return end
    particleAttach = Instance.new("Attachment"); particleAttach.Parent = hrp
    particle = Instance.new("ParticleEmitter")
    particle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particle.Color = ColorSequence.new(C.colParticle)
    particle.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 0),
    }
    particle.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    }
    particle.Lifetime = NumberRange.new(0.4, 0.7)
    particle.Rate = 0
    particle.Speed = NumberRange.new(2, 5)
    particle.SpreadAngle = Vector2.new(180, 180)
    particle.LightEmission = 0.8
    particle.Parent = particleAttach
end

local function refreshFX()
    if C.fxTrail then ensureTrail() end
    if C.fxParticles then ensureParticles() end
    if not C.fxTrail and trail then trail.Enabled = false end
    if not C.fxParticles and particle then particle.Rate = 0 end
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
        particle.Rate = on and 30 or 0
    end
    if on and C.fxSound then
        local s = Instance.new("Sound")
        s.SoundId = "rbxasset://sounds/uuhhh.mp3"
        s.Volume = 0.35
        s.PlaybackSpeed = 1.4
        s.Parent = game:GetService("SoundService")
        s:Play()
        game:GetService("Debris"):AddItem(s, 2)
    end
    if on and C.fxFOVKick and cam then
        Tween:Create(cam, TweenInfo.new(0.15), { FieldOfView = baseFOV + 8 }):Play()
    end
    if not on and C.fxFOVKick and cam then
        Tween:Create(cam, TweenInfo.new(0.3), { FieldOfView = baseFOV }):Play()
    end
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
    spawnPos = hrp.Position
    hum.WalkSpeed = C.walkSpeed
    hum.Died:Connect(function() alive = false end)
    trail, particle, particleAttach = nil, nil, nil
    refreshFX()
end
plr.CharacterAdded:Connect(hookCharacter)
hum.Died:Connect(function() alive = false end)
hum.WalkSpeed = C.walkSpeed

UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.End then
        enabled = false
        script.Parent = nil
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

    local pos = hrp.Position
    if pos.Y < C.fallY or pos.Magnitude > C.resetDist then
        hrp.CFrame = CFrame.new(spawnPos); vel = Vector3.zero
    end
end)

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
    success = Color3.fromRGB(90, 230, 130),
    warn    = Color3.fromRGB(255, 200, 80),
    danger  = Color3.fromRGB(255, 90, 100),
    font    = Enum.Font.Gotham,
    fontB   = Enum.Font.GothamBold,
}

local gui = Instance.new("ScreenGui")
gui.Name = "ShivMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = plr:WaitForChild("PlayerGui")

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

-- MENU PANEL
local menu = Instance.new("Frame")
menu.Size = UDim2.new(0, 340, 0, 420)
menu.Position = UDim2.new(0.5, -170, 0.5, -210)
menu.BackgroundColor3 = T.bg
menu.BackgroundTransparency = 0.05
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

-- TITLE BAR
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

-- TAB BAR
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

-- CONTENT
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -100)
content.Position = UDim2.new(0, 10, 0, 80)
content.BackgroundTransparency = 1
content.Parent = menu

-- PAGES (container per tab)
local pages = {}
local currentTab = nil

local function createPage(name, order)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = T.accentDim or T.stroke
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

-- ============================================================
-- WIDGETS
-- ============================================================
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
        Tween:Create(track, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            BackgroundColor3 = on and T.accent or T.stroke,
        }):Play()
        Tween:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
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

-- ============================================================
-- PAGES
-- ============================================================
local pageMovement = createPage("Movement", 1)
local pageEffects  = createPage("Effects", 2)
local pageSafety   = createPage("Safety", 3)

local tabMovement = createTabButton("Movement", 1)
local tabEffects  = createTabButton("Effects", 2)
local tabSafety   = createTabButton("Safety", 3)

local function selectTab(name)
    for n, p in pairs(pages) do
        p.frame.Visible = (n == name)
    end
    local map = { Movement = tabMovement, Effects = tabEffects, Safety = tabSafety }
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
tabEffects.MouseButton1Click:Connect(function() selectTab("Effects") end)
tabSafety.MouseButton1Click:Connect(function() selectTab("Safety") end)

-- ============ MOVEMENT PAGE ============
makeLabel(pageMovement, "MASTER")
makeToggle(pageMovement, "Movement enabled", "moveEnabled")

makeLabel(pageMovement, "GLIDE")
makeToggle(pageMovement, "Glide enabled (V)", "glideEnabled", function(v)
    if v == nil then end
end)

makeLabel(pageMovement, "INFO")
local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, 0, 0, 60)
info.BackgroundTransparency = 1
info.Font = T.font
info.Text = "Space (hold) = bhop\nV (hold in air) = pixel-glide\nSpeed preserved on glide entry."
info.TextColor3 = T.dim
info.TextSize = 11
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.TextWrapped = true
info.Parent = pageMovement

-- ============ EFFECTS PAGE ============
makeLabel(pageEffects, "GLIDE FX")
makeToggle(pageEffects, "Trail", "fxTrail", refreshFX)
makeToggle(pageEffects, "Particles", "fxParticles", refreshFX)
makeToggle(pageEffects, "FOV kick", "fxFOVKick")
makeToggle(pageEffects, "Sound", "fxSound")
makeToggle(pageEffects, "Speedlines (HUD)", "fxSpeedlines")

makeLabel(pageEffects, "PRESETS")
makeButton(pageEffects, "Preset: Clean (no FX)", function()
    C.fxTrail = false; C.fxParticles = false; C.fxFOVKick = false
    C.fxSound = false; C.fxSpeedlines = false
    refreshFX()
    -- пересоздаём страницу эффектов, чтобы тогглы обновились
    selectTab("Movement"); task.wait(0.05); selectTab("Effects")
    -- проще: переоткрыть меню
end)
makeButton(pageEffects, "Preset: Full FX", function()
    C.fxTrail = true; C.fxParticles = true; C.fxFOVKick = true
    C.fxSound = true; C.fxSpeedlines = true
    refreshFX()
end)

-- ============ SAFETY PAGE ============
makeLabel(pageSafety, "BOUNDS")
local boundsInfo = Instance.new("TextLabel")
boundsInfo.Size = UDim2.new(1, 0, 0, 40)
boundsInfo.BackgroundTransparency = 1
boundsInfo.Font = T.font
boundsInfo.Text = "Fall respawn at Y < " .. C.fallY .. "\nBounds: ±" .. (C.bounds - C.margin) .. " studs"
boundsInfo.TextColor3 = T.dim
boundsInfo.TextSize = 11
boundsInfo.TextXAlignment = Enum.TextXAlignment.Left
boundsInfo.TextYAlignment = Enum.TextYAlignment.Top
boundsInfo.TextWrapped = true
boundsInfo.Parent = pageSafety

makeLabel(pageSafety, "ACTIONS")
makeButton(pageSafety, "Respawn to spawn point", function()
    if hrp then
        hrp.CFrame = CFrame.new(spawnPos)
        vel = Vector3.zero
    end
end)
makeButton(pageSafety, "Unload script", function()
    gui:Destroy()
    script.Parent = nil
end)

-- ============================================================
-- DRAG
-- ============================================================
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

-- ============================================================
-- OPEN / CLOSE
-- ============================================================
local menuOpen = false

local function openMenu()
    menuOpen = true
    menu.Visible = true
    menu.Size = UDim2.new(0, 340, 0, 0)
    Tween:Create(menu, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 340, 0, 420),
    }):Play()
    if currentTab == nil then selectTab("Movement") end
end

local function closeMenu()
    menuOpen = false
    Tween:Create(menu, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 340, 0, 0),
    }):Play()
    task.delay(0.18, function()
        if not menuOpen then menu.Visible = false end
    end)
end

local function toggleMenu()
    if menuOpen then closeMenu() else openMenu() end
end

closeBtn.MouseButton1Click:Connect(closeMenu)
closeBtn.MouseEnter:Connect(function()
    Tween:Create(closeBtn, TweenInfo.new(0.15), { BackgroundColor3 = T.danger, TextColor3 = Color3.new(1,1,1) }):Play()
end)
closeBtn.MouseLeave:Connect(function()
    Tween:Create(closeBtn, TweenInfo.new(0.15), { BackgroundColor3 = T.panel2, TextColor3 = T.dim }):Play()
end)

UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        toggleMenu()
    elseif i.KeyCode == Enum.KeyCode.End then
        gui:Destroy()
        script.Parent = nil
    end
end)

-- начальное состояние
selectTab("Movement")
