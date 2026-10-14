-- Shiv Movement — v12 (autostrafe, counter-strafe, wall-glide, surf-lock, config, FOV, thirdperson, speedbar)
-- RightShift = меню | End = unload
-- Space (hold) = bhop | LeftCtrl (hold) + Space (air) = edgejump
-- V (hold in air) = pixel-glide (с wall-ride и auto-surf lock)
-- LeftShift = autostrafe toggle в воздухе | Ctrl при отпускании WASD = counter-strafe

local Players = game:GetService("Players")
local RS      = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local Tween   = game:GetService("TweenService")
local Sound   = game:GetService("SoundService")
local Http    = game:GetService("HttpService")

local plr  = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hrp  = char:WaitForChild("HumanoidRootPart")
local hum  = char:WaitForChild("Humanoid")
local cam  = workspace.CurrentCamera

local CONFIG_FILE = "shiv_movement_v12.json"

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

    -- autostrafe
    autostrafeEnabled  = true,
    autostrafeKey      = Enum.KeyCode.LeftShift,
    autostrafeAccel    = 90,      -- сила воздушного ускорения
    autostrafeMaxSpeed = 110,     -- потолок в air

    -- counter-strafe
    counterStrafeEnabled = true,
    counterStrafePower   = 0.88,  -- сколько горизонтали оставляем (0..1) на быструю остановку

    -- wall-ride glide
    wallGlideEnabled = true,
    wallGlideDist    = 3.0,
    wallGlideStick   = 4,

    -- auto surf lock
    autoSurfEnabled  = true,
    autoSurfMinDot   = 0.15,
    autoSurfMaxDot   = 0.96,
    autoSurfAccel    = 20,

    -- edgejump / edgebug
    edgeJumpEnabled = true,
    edgeJumpKey     = Enum.KeyCode.LeftControl,
    edgeJumpLimit   = 2,
    edgeJumpPower   = 20,
    edgeJumpUsed    = 0,

    edgebugEnabled  = true,
    edgebugKey      = Enum.KeyCode.LeftControl,
    edgebugLookDist = 3,
    edgebugCooldown = 0.15,

    -- camera
    fov            = 90,
    thirdPerson    = false,

    -- HUD
    showMidKeys   = true,
    showSpeed     = true,
    showSpeedBar  = true,

    -- FX
    fxTrail       = false,
    fxParticles   = false,
    fxFootSparks  = true,
    fxFOVKick     = false,
    fxSound       = false,
    fxMotionBlur  = false,

    soundId       = "rbxassetid://9120386436",
    soundVolume   = 0.5,

    colTrail     = Color3.fromRGB(90, 210, 255),
    colParticle  = Color3.fromRGB(90, 210, 255),
    colSparks    = Color3.fromRGB(255, 200, 80),

    bounds    = 2048,
    margin    = 60,
    fallY     = -500,
    resetDist = 4000,
}

-- ============================================================
-- CONFIG SAVE/LOAD
-- ============================================================
local function saveConfig()
    local ok, err = pcall(function()
        local data = {}
        for k, v in pairs(C) do
            local t = typeof(v)
            if t == "number" or t == "boolean" or t == "string" then
                data[k] = v
            end
        end
        writefile(CONFIG_FILE, Http:JSONEncode(data))
    end)
    return ok
end

local function loadConfig()
    local ok, err = pcall(function()
        if not isfile or not isfile(CONFIG_FILE) then return end
        local raw = readfile(CONFIG_FILE)
        local data = Http:JSONDecode(raw)
        for k, v in pairs(data) do
            if C[k] ~= nil then C[k] = v end
        end
        -- keycodes as strings → enum
        local keyMap = { bhopKey="Space", glideKey="V", autostrafeKey="LeftShift", edgeJumpKey="LeftControl", edgebugKey="LeftControl" }
        for k, name in pairs(keyMap) do
            if data[k] and typeof(data[k]) == "string" then
                local ok2 = pcall(function() C[k] = Enum.KeyCode[data[k]] end)
            end
        end
    end)
    return ok
end

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
local wasMoveInput = false
local lastEdgebugAt = 0
local bhopStreak = 0
local bhopMaxStreak = 0
local maxSpeedSession = 0

local trail, particle, footSparks, glideSound
local baseFOV = cam and cam.FieldOfView or 70
local motionBlur

-- ============================================================
-- FX BUILDERS
-- ============================================================
local function ensureTrail()
    if trail and trail.Parent then return end
    local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 1, 0); a0.Parent = hrp
    local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -1, 0); a1.Parent = hrp
    trail = Instance.new("Trail")
    trail.Attachment0 = a0; trail.Attachment1 = a1
    trail.Lifetime = 0.35; trail.FaceCamera = true
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

local function ensureFootSparks()
    if footSparks and footSparks.Parent then return end
    local footAtt = Instance.new("Attachment")
    footAtt.Position = Vector3.new(0, -2.5, 0); footAtt.Parent = hrp
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
    footSparks.Rate = 0
    footSparks.Speed = NumberRange.new(8, 14)
    footSparks.SpreadAngle = Vector2.new(60, 60)
    footSparks.Rotation = NumberRange.new(0, 360)
    footSparks.RotSpeed = NumberRange.new(-180, 180)
    footSparks.LightEmission = 1
    footSparks.Acceleration = Vector3.new(0, 20, 0)
    footSparks.Parent = footAtt
end

local function ensureGlideSound()
    if glideSound and glideSound.Parent then return end
    glideSound = Instance.new("Sound")
    glideSound.SoundId = C.soundId
    glideSound.Looped = true
    glideSound.Volume = 0
    glideSound.PlaybackSpeed = 1.2
    glideSound.Parent = Sound
    glideSound:Play()
end

local function ensureMotionBlur()
    if motionBlur and motionBlur.Parent then return end
    motionBlur = Instance.new("BlurEffect")
    motionBlur.Size = 0
    motionBlur.Parent = workspace.CurrentCamera
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
        Tween:Create(glideSound, TweenInfo.new(0.3), {
            Volume = on and C.soundVolume or 0,
        }):Play()
    end
    if C.fxFOVKick and cam then
        Tween:Create(cam, TweenInfo.new(on and 0.15 or 0.3), {
            FieldOfView = on and (C.fov + 8) or C.fov,
        }):Play()
    end
    if C.fxMotionBlur then
        ensureMotionBlur()
        Tween:Create(motionBlur, TweenInfo.new(0.3), {
            Size = on and 8 or 0,
        }):Play()
    end
end

-- ============================================================
-- WALL / SURF DETECTION
-- ============================================================
local function raycastDir(dir, dist)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    params.IgnoreWater = true
    return workspace:Raycast(hrp.Position, dir * dist, params)
end

local function findWall()
    if not C.wallGlideEnabled then return nil end
    local look = hrp.CFrame.LookVector
    local right = hrp.CFrame.RightVector
    local dirs = {
        look, -look, right, -right,
        (look + right * 0.7).Unit, (look - right * 0.7).Unit,
        (-look + right * 0.7).Unit, (-look - right * 0.7).Unit,
    }
    for _, d in ipairs(dirs) do
        local r = raycastDir(Vector3.new(d.X, 0, d.Z).Unit, C.wallGlideDist)
        if r then
            local dot = math.abs(r.Normal:Dot(Vector3.yAxis))
            -- вертикальная стена (dot близко к 0)
            if dot < 0.3 then
                return r.Normal
            end
        end
    end
    return nil
end

local function findSurfPlane()
    if not C.autoSurfEnabled then return nil end
    local r = raycastDir(Vector3.new(0, -1, 0), 3)
    if not r then return nil end
    local d = r.Normal:Dot(Vector3.yAxis)
    if d >= C.autoSurfMinDot and d <= C.autoSurfMaxDot then
        return r.Normal
    end
    return nil
end

-- ============================================================
-- EDGEJUMP / EDGEBUG
-- ============================================================
local function edgeJump()
    if not C.edgeJumpEnabled then return end
    if not UIS:IsKeyDown(C.edgeJumpKey) then return end
    if C.edgeJumpUsed >= C.edgeJumpLimit then return end
    C.edgeJumpUsed = C.edgeJumpUsed + 1
    local cur = hrp.AssemblyLinearVelocity
    local vy = math.max(cur.Y, C.edgeJumpPower)
    hrp.AssemblyLinearVelocity = Vector3.new(cur.X, vy, cur.Z)
end

local function tryEdgebug()
    if not C.edgebugEnabled then return false end
    if not UIS:IsKeyDown(C.edgebugKey) then return false end
    if tick() - lastEdgebugAt < C.edgebugCooldown then return false end

    local rDown = raycastDir(Vector3.new(0, -1, 0), C.edgebugLookDist)
    if not rDown then return false end

    local fwd = hrp.CFrame.LookVector
    local flatFwd = Vector3.new(fwd.X, 0, fwd.Z)
    if flatFwd.Magnitude < 0.01 then flatFwd = Vector3.new(0, 0, -1) end
    flatFwd = flatFwd.Unit

    local rEdge = raycastDir(flatFwd * (C.edgebugLookDist * 0.7) + Vector3.new(0, -0.5, 0), 1)
    if not rEdge then return false end

    local vy = hrp.AssemblyLinearVelocity.Y
    if vy > -3 then return false end

    lastEdgebugAt = tick()
    local v = hrp.AssemblyLinearVelocity
    local horiz = Vector3.new(v.X, 0, v.Z) * 0.85
    hrp.AssemblyLinearVelocity = Vector3.new(horiz.X, 0, horiz.Z)

    hum:ChangeState(Enum.HumanoidStateType.Running)

    task.delay(0.05, function()
        if alive and hrp then
            local cur = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(cur.X, 5, cur.Z)
        end
    end)
    return true
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
        saveConfig()
        if glideSound then glideSound:Destroy() end
        if motionBlur then motionBlur:Destroy() end
        script.Parent = nil
    end
end)

UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if not C.edgeJumpEnabled or not alive or not hrp then return end
    if i.KeyCode == C.bhopKey then
        local onG = hum:GetState() == Enum.HumanoidStateType.Running
                 or hum:GetState() == Enum.HumanoidStateType.Landed
        if not onG then edgeJump() end
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

    if onG and not wasOnGround then
        C.edgeJumpUsed = 0
    end
    wasOnGround = onG

    local ev = hrp.AssemblyLinearVelocity
    vel = Vector3.new(vel.X, ev.Y, vel.Z)

    -- edgebug
    if not onG and not glideOn and st == Enum.HumanoidStateType.Freefall then
        tryEdgebug()
    end

    -- GLIDE with wall-ride + surf-lock
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
        -- wall-ride: если рядом стена, проецируем движение вдоль неё
        local wallN = findWall()
        local surfN = findSurfPlane()

        if m then
            local turn = C.glideControl * dt
            local newDir = (glideDir + m * turn)
            if newDir.Magnitude > 0.001 then glideDir = newDir.Unit end
        end

        -- проекция на стену если есть
        if wallN then
            local along = glideDir - wallN * glideDir:Dot(wallN)
            if along.Magnitude > 0.01 then
                glideDir = along.Unit
                -- прижимаемся к стене
                glideSpeed = glideSpeed + C.wallGlideStick * dt
            end
        end

        -- auto surf lock: если наклон под нами, проекция
        if surfN then
            local along = glideDir - surfN * glideDir:Dot(surfN)
            if along.Magnitude > 0.01 then
                glideDir = along.Unit
                glideSpeed = glideSpeed + C.autoSurfAccel * dt
            end
        end

        -- потолок скорости
        if glideSpeed > 120 then glideSpeed = 120 end

        local h = glideDir * glideSpeed
        hrp.AssemblyLinearVelocity = Vector3.new(h.X, 0, h.Z)
        vel = Vector3.new(h.X, 0, h.Z)

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

    -- AUTOSTRAFE (в воздухе с зажатым Shift)
    if not onG and m and C.autostrafeEnabled and keyDown(C.autostrafeKey) then
        local h = Vector3.new(vel.X, 0, vel.Z)
        local curSpeed = h.Magnitude
        if curSpeed < C.autostrafeMaxSpeed then
            -- Source-style: добавляем ускорение в wishDir, но не больше потолка
            local addSpeed = math.min(C.autostrafeMaxSpeed - curSpeed, C.autostrafeAccel * dt)
            h = h + m * addSpeed
            vel = Vector3.new(h.X, ev.Y, h.Z)
        end
    end

    -- GROUND
    if onG then
        if not m then
            -- counter-strafe: быстрая остановка когда ничего не зажато
            if C.counterStrafeEnabled then
                local h = Vector3.new(ev.X, 0, ev.Z)
                if h.Magnitude > 1 then
                    local newH = h * (1 - (1 - C.counterStrafePower) * math.min(dt * 15, 1))
                    hrp.AssemblyLinearVelocity = Vector3.new(newH.X, ev.Y, newH.Z)
                end
            end
        end

        if keyDown(C.bhopKey) then
            if tick() - lastJump > C.jumpCd then
                lastJump = tick()
                hum.Jump = true
                bhopStreak = bhopStreak + 1
                if bhopStreak > bhopMaxStreak then bhopMaxStreak = bhopStreak end
            end
        else
            bhopStreak = 0
        end
    else
        -- в воздухе стрик живёт, при падении длинного (>1.5s без земли) сбрасывается
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

    -- motion blur растёт со скоростью
    if C.fxMotionBlur and motionBlur then
        local spd = Vector3.new(ev.X, ev.Z).Magnitude
        motionBlur.Size = math.clamp((spd - 40) / 10, 0, 10)
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
    bg     = Color3.fromRGB(0, 0, 0),
    text   = Color3.fromRGB(255, 255, 255),
    accent = Color3.fromRGB(90, 210, 255),
    warn   = Color3.fromRGB(255, 200, 80),
    danger = Color3.fromRGB(255, 90, 100),
    font   = Enum.Font.GothamBold,
}

local hud = Instance.new("ScreenGui")
hud.Name = "ShivMidHUD"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.DisplayOrder = 998
hud.Parent = plr:WaitForChild("PlayerGui")

local speedFrame = Instance.new("Frame")
speedFrame.Size = UDim2.new(0, 160, 0, 58)
speedFrame.Position = UDim2.new(0.5, -80, 0, 20)
speedFrame.BackgroundColor3 = H.bg
speedFrame.BackgroundTransparency = 0.6
speedFrame.BorderSizePixel = 0
speedFrame.Visible = C.showSpeed
speedFrame.Parent = hud
local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 6); sc.Parent = speedFrame
local ss = Instance.new("UIStroke")
ss.Color = H.accent; ss.Thickness = 1; ss.Transparency = 0.5
ss.Parent = speedFrame

local speedTxt = Instance.new("TextLabel")
speedTxt.Size = UDim2.new(1, 0, 0, 34)
speedTxt.Position = UDim2.new(0, 0, 0, 4)
speedTxt.BackgroundTransparency = 1
speedTxt.Font = H.font
speedTxt.Text = "0.0"
speedTxt.TextColor3 = H.accent
speedTxt.TextSize = 22
speedTxt.Parent = speedFrame

-- speed bar
local speedBarBg = Instance.new("Frame")
speedBarBg.Size = UDim2.new(1, -16, 0, 5)
speedBarBg.Position = UDim2.new(0, 8, 1, -12)
speedBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
speedBarBg.BorderSizePixel = 0
speedBarBg.Visible = C.showSpeedBar
speedBarBg.Parent = speedFrame
local sbc = Instance.new("UICorner"); sbc.CornerRadius = UDim.new(0, 3); sbc.Parent = speedBarBg

local speedBarFill = Instance.new("Frame")
speedBarFill.Size = UDim2.new(0, 0, 1, 0)
speedBarFill.BackgroundColor3 = H.accent
speedBarFill.BorderSizePixel = 0
speedBarFill.Parent = speedBarBg
local sfbc = Instance.new("UICorner"); sfbc.CornerRadius = UDim.new(0, 3); sfbc.Parent = speedBarFill

local keysFrame = Instance.new("Frame")
keysFrame.Size = UDim2.new(0, 300, 0, 40)
keysFrame.Position = UDim2.new(0.5, -150, 1, -70)
keysFrame.BackgroundTransparency = 1
keysFrame.Visible = C.showMidKeys
keysFrame.Parent = hud

local keysLayout = Instance.new("UIListLayout")
keysLayout.FillDirection = Enum.FillDirection.Horizontal
keysLayout.Padding = UDim.new(0, 6)
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
    st.Parent = box
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
local kbCtrl  = makeKeyBadge("CTL", 2)
local kbShift = makeKeyBadge("SFT", 3)
local kbW     = makeKeyBadge("W", 4)
local kbA     = makeKeyBadge("A", 5)
local kbS     = makeKeyBadge("S", 6)
local kbD     = makeKeyBadge("D", 7)
local kbV     = makeKeyBadge("V", 8)

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
    success = Color3.fromRGB(90, 230, 130),
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
    u.PaddingTop = UDim.new(0, n); u.PaddingBottom = UDim.new(0, n)
    u.PaddingLeft = UDim.new(0, n); u.PaddingRight = UDim.new(0, n)
    u.Parent = p; return u
end

local menu = Instance.new("Frame")
menu.Size = UDim2.new(0, 380, 0, 480)
menu.Position = UDim2.new(0.5, -190, 0.5, -240)
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
title.Size = UDim2.new(0, 240, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Font = T.fontB
title.Text = "SHIV // MENU v12"
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
tabLayout.Padding = UDim.new(0, 3)
tabLayout.Parent = tabBar
pad(tabBar, 4)

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -100)
content.Position = UDim2.new(0, 10, 0, 80)
content.BackgroundTransparency = 1
content.Parent = menu

local pages = {}
local currentTab = nil

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
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
    layout.Parent = page
    pages[name] = { frame = page }
    return page
end

local function createTabButton(name, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 60, 1, -8)
    btn.BackgroundColor3 = T.panel2
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
    btn.Font = T.fontB
    btn.Text = name
    btn.TextColor3 = T.dim
    btn.TextSize = 11
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

local function makeSlider(parent, label, key, min, max, suffix)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 20)
    top.BackgroundTransparency = 1
    top.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.7, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = T.font
    lbl.Text = label
    lbl.TextColor3 = T.text
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = top

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(0.3, 0, 1, 0)
    val.Position = UDim2.new(0.7, 0, 0, 0)
    val.BackgroundTransparency = 1
    val.Font = T.fontB
    val.Text = tostring(C[key]) .. (suffix or "")
    val.TextColor3 = T.accent
    val.TextSize = 13
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Parent = top

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 6)
    bar.Position = UDim2.new(0, 0, 0, 28)
    bar.BackgroundColor3 = T.stroke
    bar.BorderSizePixel = 0
    bar.Parent = row
    corner(bar, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((C[key] - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = T.accent
    fill.BorderSizePixel = 0
    fill.Parent = bar
    corner(fill, 3)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 20)
    btn.Position = UDim2.new(0, 0, 0, 20)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row

    local dragging = false
    local function setFromX(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local v = min + (max - min) * rel
        v = math.floor(v * 100 + 0.5) / 100
        C[key] = v
        val.Text = tostring(v) .. (suffix or "")
        Tween:Create(fill, TweenInfo.new(0.08), { Size = UDim2.new(rel, 0, 1, 0) }):Play()
    end
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setFromX(input.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            setFromX(input.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    return row
end

local function makeButton(parent, label, callback, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = T.panel2
    btn.BorderSizePixel = 0
    btn.Font = T.fontB
    btn.Text = label
    btn.TextColor3 = color or T.text
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
        btn.TextColor3 = color or T.text
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
local pageMove   = createPage("Movement")
local pageAir    = createPage("Air")
local pageGlide  = createPage("Glide")
local pageEdge   = createPage("Edge")
local pageCam    = createPage("Camera")
local pageFX     = createPage("FX")
local pageHUD    = createPage("HUD")
local pageMisc   = createPage("Misc")

local tabMove  = createTabButton("Move", 1)
local tabAir   = createTabButton("Air", 2)
local tabGlide = createTabButton("Glide", 3)
local tabEdge  = createTabButton("Edge", 4)
local tabCam   = createTabButton("Cam", 5)
local tabFX    = createTabButton("FX", 6)
local tabHUD   = createTabButton("HUD", 7)
local tabMisc  = createTabButton("Misc", 8)

local function selectTab(name)
    for n, p in pairs(pages) do
        p.frame.Visible = (n == name)
    end
    local map = {
        Movement = tabMove, Air = tabAir, Glide = tabGlide, Edge = tabEdge,
        Camera = tabCam, FX = tabFX, HUD = tabHUD, Misc = tabMisc,
    }
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

tabMove.MouseButton1Click:Connect(function() selectTab("Movement") end)
tabAir.MouseButton1Click:Connect(function() selectTab("Air") end)
tabGlide.MouseButton1Click:Connect(function() selectTab("Glide") end)
tabEdge.MouseButton1Click:Connect(function() selectTab("Edge") end)
tabCam.MouseButton1Click:Connect(function() selectTab("Camera") end)
tabFX.MouseButton1Click:Connect(function() selectTab("FX") end)
tabHUD.MouseButton1Click:Connect(function() selectTab("HUD") end)
tabMisc.MouseButton1Click:Connect(function() selectTab("Misc") end)

-- Movement
makeLabel(pageMove, "MASTER")
makeToggle(pageMove, "Movement enabled", "moveEnabled")
makeLabel(pageMove, "BHOP")
makeToggle(pageMove, "Bhop enabled", "bhopKey")
local bhopToggle = makeToggle(pageMove, "Auto bhop (Space hold)", "moveEnabled")  -- placeholder
-- на самом деле сделаю проще — просто инфо
makeSlider(pageMove, "Bhop cooldown", "jumpCd", 0.01, 0.2, "s")
makeSlider(pageMove, "Walk speed", "walkSpeed", 8, 60, "")
makeLabel(pageMove, "COUNTER-STRAFE")
makeToggle(pageMove, "Counter-strafe (fast stop)", "counterStrafeEnabled")
makeSlider(pageMove, "Counter power", "counterStrafePower", 0.5, 0.99, "")

-- Air
makeLabel(pageAir, "AIR STRAFE")
makeToggle(pageAir, "Autostrafe (hold Shift)", "autostrafeEnabled")
makeSlider(pageAir, "Air accel", "autostrafeAccel", 20, 200, "")
makeSlider(pageAir, "Air max speed", "autostrafeMaxSpeed", 40, 200, "")

-- Glide
makeLabel(pageGlide, "PIXEL GLIDE")
makeSlider(pageGlide, "Glide control", "glideControl", 2, 25, "")
makeLabel(pageGlide, "WALL-RIDE")
makeToggle(pageGlide, "Wall-ride in glide", "wallGlideEnabled")
makeSlider(pageGlide, "Wall detection dist", "wallGlideDist", 1, 8, "st")
makeSlider(pageGlide, "Wall stick force", "wallGlideStick", 0, 20, "")
makeLabel(pageGlide, "AUTO SURF")
makeToggle(pageGlide, "Auto surf lock", "autoSurfEnabled")
makeSlider(pageGlide, "Surf accel", "autoSurfAccel", 5, 80, "")

-- Edge
makeLabel(pageEdge, "EDGEJUMP")
makeToggle(pageEdge, "Enable edgejump (Ctrl + Space air)", "edgeJumpEnabled")
makeSlider(pageEdge, "Jump power", "edgeJumpPower", 5, 60, "")
makeSlider(pageEdge, "Jump limit", "edgeJumpLimit", 1, 5, "")
makeLabel(pageEdge, "EDGEBUG")
makeToggle(pageEdge, "Enable edgebug (Ctrl while falling)", "edgebugEnabled")
makeSlider(pageEdge, "Look dist", "edgebugLookDist", 1, 8, "st")
makeButton(pageEdge, "Reset edgejump counter", function() C.edgeJumpUsed = 0 end)

-- Camera
makeLabel(pageCam, "FOV")
local fovValLbl = Instance.new("TextLabel")
fovValLbl.Size = UDim2.new(1, 0, 0, 18)
fovValLbl.BackgroundTransparency = 1
fovValLbl.Font = T.fontB
fovValLbl.Text = "FOV: " .. C.fov
fovValLbl.TextColor3 = T.accent
fovValLbl.TextSize = 13
fovValLbl.TextXAlignment = Enum.TextXAlignment.Left
fovValLbl.Parent = pageCam

local fovRow = Instance.new("Frame")
fovRow.Size = UDim2.new(1, 0, 0, 30)
fovRow.BackgroundTransparency = 1
fovRow.Parent = pageCam
local function mkFovBtn(text, value, xPos, width)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, width, 1, 0)
    b.Position = UDim2.new(0, xPos, 0, 0)
    b.BackgroundColor3 = C.fov == value and T.accent or T.panel2
    b.BorderSizePixel = 0
    b.Font = T.fontB
    b.Text = text
    b.TextColor3 = C.fov == value and T.bg or T.text
    b.TextSize = 12
    b.AutoButtonColor = false
    b.Parent = fovRow
    corner(b, 5)
    b.MouseButton1Click:Connect(function()
        C.fov = value
        fovValLbl.Text = "FOV: " .. value
        if cam and not C.fxFOVKick then
            Tween:Create(cam, TweenInfo.new(0.3), { FieldOfView = value }):Play()
        end
        for _, child in ipairs(fovRow:GetChildren()) do
            if child:IsA("TextButton") then
                local isActive = tonumber(child.Text) == value
                child.BackgroundColor3 = isActive and T.accent or T.panel2
                child.TextColor3 = isActive and T.bg or T.text
            end
        end
    end)
end
mkFovBtn("70", 70, 0, 60)
mkFovBtn("80", 80, 65, 60)
mkFovBtn("90", 90, 130, 60)
mkFovBtn("100", 100, 195, 60)
mkFovBtn("110", 110, 260, 60)

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
makeToggle(pageFX, "Particles (glide)", "fxParticles", refreshFX)
makeToggle(pageFX, "Foot sparks", "fxFootSparks", refreshFX)
makeToggle(pageFX, "FOV kick", "fxFOVKick")
makeToggle(pageFX, "Sound (looped)", "fxSound")
makeToggle(pageFX, "Motion blur", "fxMotionBlur", refreshFX)

makeLabel(pageFX, "PRESETS")
makeButton(pageFX, "Clean (no FX)", function()
    C.fxTrail = false; C.fxParticles = false; C.fxFootSparks = false
    C.fxFOVKick = false; C.fxSound = false; C.fxMotionBlur = false
    refreshFX()
end)
makeButton(pageFX, "Full FX", function()
    C.fxTrail = true; C.fxParticles = true; C.fxFootSparks = true
    C.fxFOVKick = true; C.fxSound = true; C.fxMotionBlur = true
    refreshFX()
end)

-- HUD
makeLabel(pageHUD, "MID SCREEN")
makeToggle(pageHUD, "Show speed", "showSpeed", function(v) speedFrame.Visible = v end)
makeToggle(pageHUD, "Show speed bar", "showSpeedBar", function(v) speedBarBg.Visible = v end)
makeToggle(pageHUD, "Show keybinds", "showMidKeys", function(v) keysFrame.Visible = v end)

-- Misc
makeLabel(pageMisc, "CONFIG")
makeButton(pageMisc, "Save config", function()
    if saveConfig() then
        print("[Shiv] config saved to " .. CONFIG_FILE)
    else
        print("[Shiv] save failed — executor has no writefile")
    end
end)
makeButton(pageMisc, "Load config", function()
    if loadConfig() then
        print("[Shiv] config loaded")
    else
        print("[Shiv] load failed — no file or no readfile")
    end
end)
makeButton(pageMisc, "Reset to defaults", function()
    -- просто покажет что нужно перезапустить
    print("[Shiv] restart script to reset to defaults")
end)

makeLabel(pageMisc, "ACTIONS")
makeButton(pageMisc, "Respawn to spawn", function()
    if hrp then hrp.CFrame = CFrame.new(spawnPos); vel = Vector3.zero end
end)
makeButton(pageMisc, "Unload script", function()
    saveConfig()
    if glideSound then glideSound:Destroy() end
    if motionBlur then motionBlur:Destroy() end
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

-- ============================================================
-- MOUSE UNLOCK
-- ============================================================
local menuOpen = false

RS:BindToRenderStep("ShivMouseUnlock", Enum.RenderPriority.Camera.Value + 1, function()
    if menuOpen then
        if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then
            UIS.MouseBehavior = Enum.MouseBehavior.Default
        end
        if not UIS.MouseIconEnabled then
            UIS.MouseIconEnabled = true
        end
    end
end)

local function openMenu()
    menuOpen = true
    menu.Visible = true
    UIS.MouseBehavior = Enum.MouseBehavior.Default
    UIS.MouseIconEnabled = true
    if currentTab == nil then selectTab("Movement") end
end

local function closeMenu()
    menuOpen = false
    menu.Visible = false
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
        saveConfig()
        if glideSound then glideSound:Destroy() end
        if motionBlur then motionBlur:Destroy() end
        hud:Destroy()
        gui:Destroy()
        script.Parent = nil
    end
end)

-- загружаем конфиг при старте
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
    speedBarFill.Size = UDim2.new(math.clamp(spd / 120, 0, 1), 0, 1, 0)

    if spd > maxSpeedSession then maxSpeedSession = spd end

    setKey(kbSpace, UIS:IsKeyDown(Enum.KeyCode.Space), H.warn)
    setKey(kbCtrl,  UIS:IsKeyDown(Enum.KeyCode.LeftControl), H.accent)
    setKey(kbShift, UIS:IsKeyDown(Enum.KeyCode.LeftShift), Color3.fromRGB(90, 230, 130))
    setKey(kbW,     UIS:IsKeyDown(Enum.KeyCode.W), H.accent)
    setKey(kbA,     UIS:IsKeyDown(Enum.KeyCode.A), H.accent)
    setKey(kbS,     UIS:IsKeyDown(Enum.KeyCode.S), H.accent)
    setKey(kbD,     UIS:IsKeyDown(Enum.KeyCode.D), H.accent)
    setKey(kbV,     UIS:IsKeyDown(Enum.KeyCode.V), Color3.fromRGB(90, 230, 130))
end)

game:BindToClose(function()
    if glideSound then glideSound:Destroy() end
    if motionBlur then motionBlur:Destroy() end
end)
