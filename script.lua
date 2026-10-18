-- ============================================================
-- CUCUMBER v29 — movement + aimbot + ESP (universal)
-- Menu: RightShift | Unlock mouse: Z | Unload: End
-- Bhop: Space | Pixel surf: V | Texture bug: H (hold)
-- Aim hold: Q | Aim toggle: X
-- ============================================================

local Players = game:GetService("Players")
local RS      = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local Tween   = game:GetService("TweenService")
local Http    = game:GetService("HttpService")
local VIM     = game:GetService("VirtualInputManager")

if _G.__CUCUMBER_LOADED then
    if _G.__CUCUMBER_UNLOAD then pcall(_G.__CUCUMBER_UNLOAD) end
end
_G.__CUCUMBER_LOADED = true

local plr   = Players.LocalPlayer
local char  = plr.Character or plr.CharacterAdded:Wait()
local hrp   = char:WaitForChild("HumanoidRootPart")
local hum   = char:WaitForChild("Humanoid")
local head  = char:WaitForChild("Head")
local cam   = workspace.CurrentCamera
local mouse = plr:GetMouse()

local CONFIG_FILE = "cucumber_v29.json"
local HAS_FILE_IO = (typeof(writefile) == "function") and (typeof(readfile) == "function")

-- ============================================================
-- AIM / ESP STATE
-- ============================================================
local Aim = {
    enabled      = true,
    silent       = true,
    wallCheck    = true,
    visibleOnly  = true,
    teamCheck    = true,
    aliveCheck   = true,
    fov          = 250,
    smoothness   = 0.35,
    prediction   = 0.06,
    targetPart   = "Head",
    drawFov      = true,
    key          = Enum.KeyCode.Q,
    toggleKey    = Enum.KeyCode.X,
    autoFire     = false,
    triggerbot   = false,
    triggerFov   = 4,
}

local Esp = {
    enabled    = true,
    box        = true,
    name       = true,
    health     = true,
    distance   = true,
    tracer     = true,
    chams      = false,
    maxDistance = 2500,
    color      = Color3.fromRGB(255, 80, 80),
    boxColor   = Color3.fromRGB(255, 80, 80),
    textSize   = 13,
}

-- ============================================================
-- CONFIG
-- ============================================================
local C = {
    moveEnabled = true,

    bhopKey = Enum.KeyCode.Space,
    jumpCd = 0.05,
    walkSpeed = 24,
    bhopIgnoreWalkSpeed = true,
    bhopMaxSpeed = 70,
    bhopPerfectBonus = 1.5,

    autostrafeEnabled = true,
    autostrafeKey = Enum.KeyCode.LeftShift,
    autostrafeAccel = 90,
    autostrafeMaxSpeed = 110,

    glideKey = Enum.KeyCode.V,
    glideControl = 10,

    textureBugEnabled = true,
    textureBugKey = Enum.KeyCode.H,
    textureBugMaxSpeed = 100,
    textureBugControl = 12,
    textureBugStick = 3,
    textureBugRange = 4,
    textureBugCamTilt = true,

    edgeJumpEnabled = true,
    edgeJumpKey = Enum.KeyCode.LeftControl,
    edgeJumpLimit = 2,
    edgeJumpPower = 20,
    edgeJumpUsed = 0,

    edgebugEnabled = true,
    edgebugMinFallSpeed = 20,
    edgebugCooldown = 0.4,

    counterStrafeEnabled = true,
    counterStrafePower = 0.88,

    doubleJumpEnabled = false,
    doubleJumpPower = 30,

    showSpeed = true,
    showSpeedBar = true,
    showStreak = true,
    showMidKeys = true,
    showFPS = true,
    showIndicators = true,

    antiAfkEnabled = true,

    menuKey = Enum.KeyCode.RightShift,
    mouseKey = Enum.KeyCode.Z,
    unloadKey = Enum.KeyCode.End,

    colAccent = Color3.fromRGB(120, 230, 100),
    colAccent2 = Color3.fromRGB(80, 180, 70),
    colSparks = Color3.fromRGB(180, 255, 120),

    bounds = 2048,
    margin = 60,
    fallY = -500,
    resetDist = 4000,
}

local function serialize(t, into)
    into = into or {}
    for k, v in pairs(t) do
        local tv = typeof(v)
        if tv == "number" or tv == "boolean" or tv == "string" then
            into[k] = v
        elseif tv == "EnumItem" then
            into[k] = tostring(v)
        end
    end
    return into
end

local function saveConfig()
    if not HAS_FILE_IO then return false end
    return (pcall(function()
        local d = serialize(C)
        d.aim = serialize(Aim)
        d.esp = serialize(Esp)
        writefile(CONFIG_FILE, Http:JSONEncode(d))
    end))
end

local function loadConfig()
    if not HAS_FILE_IO then return false end
    return (pcall(function()
        if not isfile(CONFIG_FILE) then return end
        local d = Http:JSONDecode(readfile(CONFIG_FILE))
        for k, v in pairs(d) do
            if C[k] ~= nil then
                local cur = C[k]
                if typeof(cur) == "boolean" then C[k] = (v == true or v == "true")
                elseif typeof(cur) == "number" then C[k] = tonumber(v) or cur
                elseif typeof(cur) == "EnumItem" then
                    local ok, ev = pcall(function() return Enum[typeof(cur).Name] end)
                else C[k] = v end
            end
        end
        if d.aim then for k, v in pairs(d.aim) do
            if Aim[k] ~= nil then
                local cur = Aim[k]
                if typeof(cur) == "boolean" then Aim[k] = (v == true or v == "true")
                elseif typeof(cur) == "number" then Aim[k] = tonumber(v) or cur end
            end
        end end
        if d.esp then for k, v in pairs(d.esp) do
            if Esp[k] ~= nil then
                local cur = Esp[k]
                if typeof(cur) == "boolean" then Esp[k] = (v == true or v == "true")
                elseif typeof(cur) == "number" then Esp[k] = tonumber(v) or cur end
            end
        end end
    end))
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
local lastEdgebugAt = 0
local bhopStreak = 0
local maxSpeedSession = 0
local doubleJumpUsed = false
local smoothedSpeed = 0

local bhopCacheVel = nil
local bhopChainVel = 0

local tbOn = false
local tbSpeed = 0
local tbDir = Vector3.zero
local tbHitSurface = false

local lastGlideTick = 0
local lastEdgebugTick = 0
local lastTbTick = 0

local footSparks
local menuOpen = false
local mouseUnlocked = false
local holdingAim = false
local aimTarget = nil
local hasDrawing = (typeof(Drawing) == "table")

-- ============================================================
-- FOOT SPARKS
-- ============================================================
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
    footSparks.Lifetime = NumberRange.new(0.4,0.7)
    footSparks.Rate = 0
    footSparks.Speed = NumberRange.new(8,14)
    footSparks.SpreadAngle = Vector2.new(60,60)
    footSparks.Rotation = NumberRange.new(0,360)
    footSparks.RotSpeed = NumberRange.new(-180,180)
    footSparks.LightEmission = 1
    footSparks.Acceleration = Vector3.new(0,20,0)
    footSparks.Parent = a
end

-- ============================================================
-- HELPERS
-- ============================================================
local function raycastDown(maxDist)
    if not hrp then return nil end
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances = {char}
    p.IgnoreWater = true
    return workspace:Raycast(hrp.Position, Vector3.new(0, -(maxDist or 20), 0), p)
end

local function findHeadSurface()
    if not head or not hrp then return nil end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    params.IgnoreWater = true
    local fwd = tbDir
    if fwd.Magnitude < 0.01 then
        local look = hrp.CFrame.LookVector
        fwd = Vector3.new(look.X, 0, look.Z).Unit
    end
    local right = Vector3.new(-fwd.Z, 0, fwd.X)
    local dirs = {
        fwd,
        (fwd + Vector3.new(0, -0.4, 0)).Unit,
        (fwd + Vector3.new(0, -0.8, 0)).Unit,
        (fwd + right * 0.7).Unit,
        (fwd - right * 0.7).Unit,
    }
    for _, d in ipairs(dirs) do
        local r = workspace:Raycast(head.Position, d * C.textureBugRange, params)
        if r then return r.Normal, r.Position end
    end
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
    if not C.edgebugEnabled then return false end
    local vy = hrp.AssemblyLinearVelocity.Y
    if vy > -C.edgebugMinFallSpeed then return false end
    local r = raycastDown(5)
    if not r then return false end
    local dist = (hrp.Position - r.Position).Magnitude
    if dist > 4 or dist < 0.5 then return false end
    if tick() - lastEdgebugAt < C.edgebugCooldown then return false end
    lastEdgebugAt = tick()
    lastEdgebugTick = tick()
    local v = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
    task.delay(0.03, function()
        if alive and hrp then
            local c = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(c.X, 2, c.Z)
        end
    end)
    return true
end

-- ============================================================
-- CHARACTER HOOK
-- ============================================================
local function hookCharacter(c)
    if footSparks then footSparks:Destroy(); footSparks = nil end
    char = c
    hrp = c:WaitForChild("HumanoidRootPart")
    hum = c:WaitForChild("Humanoid")
    head = c:WaitForChild("Head")
    cam = workspace.CurrentCamera
    mouse = plr:GetMouse()
    vel = Vector3.zero
    alive = true
    glideOn = false
    tbOn = false
    doubleJumpUsed = false
    bhopStreak = 0
    bhopCacheVel = nil
    bhopChainVel = 0
    C.edgeJumpUsed = 0
    spawnPos = hrp.Position
    smoothedSpeed = 0
    hum.WalkSpeed = C.walkSpeed
    if hum.Died then hum.Died:Connect(function() alive = false end) end
end

plr.CharacterAdded:Connect(hookCharacter)
if hum.Died then hum.Died:Connect(function() alive = false end) end
hum.WalkSpeed = C.walkSpeed

-- ============================================================
-- ANTI-AFK
-- ============================================================
task.spawn(function()
    while _G.__CUCUMBER_LOADED do
        task.wait(60 * 14)
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
-- INPUT — jump / double jump / aim keys
-- ============================================================
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Space then
        if not hum then return end
        local onG = hum:GetState() == Enum.HumanoidStateType.Running
                 or hum:GetState() == Enum.HumanoidStateType.Landed
        if not onG then
            if C.doubleJumpEnabled and not doubleJumpUsed and hrp then
                local cur = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = Vector3.new(cur.X, math.max(cur.Y, C.doubleJumpPower), cur.Z)
                doubleJumpUsed = true
                return
            end
            edgeJump()
        end
    end
    if input.KeyCode == Aim.key and Aim.enabled then
        holdingAim = true
    end
    if input.KeyCode == Aim.toggleKey then
        Aim.enabled = not Aim.enabled
        if not Aim.enabled then holdingAim = false end
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Aim.key then holdingAim = false end
end)

-- ============================================================
-- MOVEMENT LOOP
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
    end

    local ev = hrp.AssemblyLinearVelocity

    if not onG and st == Enum.HumanoidStateType.Freefall then
        bhopCacheVel = Vector3.new(ev.X, 0, ev.Z)
    end

    if onG and not wasOnGround then
        if bhopStreak > 0 and keyDown(C.bhopKey) and bhopCacheVel then
            local restored = bhopCacheVel
            if C.bhopPerfectBonus > 0 then
                local cur = Vector3.new(ev.X, 0, ev.Z)
                if cur.Magnitude > 1 then
                    local sameDir = cur.Unit:Dot(restored.Unit)
                    if sameDir > 0.7 then
                        bhopChainVel = math.min(
                            math.max(bhopChainVel, restored.Magnitude) + C.bhopPerfectBonus,
                            C.bhopMaxSpeed)
                    else
                        bhopChainVel = restored.Magnitude
                    end
                else
                    bhopChainVel = restored.Magnitude
                end
            else
                bhopChainVel = restored.Magnitude
            end
            hrp.AssemblyLinearVelocity = Vector3.new(restored.X, ev.Y, restored.Z)
        end
    end
    wasOnGround = onG

    if C.bhopIgnoreWalkSpeed then
        if onG then
            if hum.WalkSpeed ~= C.walkSpeed then hum.WalkSpeed = C.walkSpeed end
        else
            if hum.WalkSpeed ~= 0 then hum.WalkSpeed = 0 end
        end
    end

    if not onG and not glideOn and not tbOn and st == Enum.HumanoidStateType.Freefall then
        tryEdgebug()
    end

    -- TEXTURE BUG
    local wantTB = C.textureBugEnabled and keyDown(C.textureBugKey) and not onG
    if wantTB and not tbOn then
        tbOn = true
        local h = Vector3.new(ev.X, 0, ev.Z)
        tbSpeed = math.max(h.Magnitude, C.walkSpeed)
        if h.Magnitude > 0.5 then tbDir = h.Unit
        else
            local look = hrp.CFrame.LookVector
            tbDir = Vector3.new(look.X, 0, look.Z).Unit
        end
        tbHitSurface = false
        if C.textureBugCamTilt and cam then
            Tween:Create(cam, TweenInfo.new(0.15), {
                CFrame = cam.CFrame * CFrame.Angles(math.rad(8), 0, 0)}):Play()
        end
    elseif not wantTB and tbOn then
        tbOn = false
        if C.textureBugCamTilt and cam then
            Tween:Create(cam, TweenInfo.new(0.2), {
                CFrame = cam.CFrame * CFrame.Angles(math.rad(-8), 0, 0)}):Play()
        end
    end

    if tbOn then
        lastTbTick = tick()
        if m then
            local turn = C.textureBugControl * dt
            local nd = tbDir + m * turn
            if nd.Magnitude > 0.001 then tbDir = nd.Unit end
        end
        local normal = findHeadSurface()
        if normal then
            tbHitSurface = true
            local along = tbDir - normal * tbDir:Dot(normal)
            if along.Magnitude > 0.01 then tbDir = along.Unit end
            hrp.CFrame = hrp.CFrame + normal * C.textureBugStick * dt
        end
        if tbSpeed > C.textureBugMaxSpeed then tbSpeed = C.textureBugMaxSpeed end
        local h = tbDir * tbSpeed
        hrp.AssemblyLinearVelocity = Vector3.new(h.X, 0, h.Z)
        local pos = hrp.Position
        if pos.Y < C.fallY or pos.Magnitude > C.resetDist then
            hrp.CFrame = CFrame.new(spawnPos); vel = Vector3.zero; tbOn = false; return
        end
        return
    end

    -- PIXEL GLIDE
    local wantGlide = keyDown(C.glideKey) and not onG
    if wantGlide ~= glideOn then
        glideOn = wantGlide
        if glideOn then
            local h = Vector3.new(ev.X, 0, ev.Z)
            glideSpeed = h.Magnitude
            if glideSpeed > 0.1 then glideDir = h.Unit
            else
                local look = cam and cam.CFrame.LookVector or Vector3.new(0,0,-1)
                glideDir = Vector3.new(look.X, 0, look.Z).Unit
                glideSpeed = C.walkSpeed
            end
            hrp.AssemblyLinearVelocity = glideDir * glideSpeed
        end
    end

    if glideOn then
        lastGlideTick = tick()
        if m then
            local turn = C.glideControl * dt
            local nd = glideDir + m * turn
            if nd.Magnitude > 0.001 then glideDir = nd.Unit end
        end
        if glideSpeed > 120 then glideSpeed = 120 end
        local h = glideDir * glideSpeed
        hrp.AssemblyLinearVelocity = Vector3.new(h.X, 0, h.Z)
        ensureFootSparks()
        if footSparks then footSparks.Rate = 60 end
        local pos = hrp.Position
        if pos.Y < C.fallY or pos.Magnitude > C.resetDist then
            hrp.CFrame = CFrame.new(spawnPos); vel = Vector3.zero; glideOn = false; return
        end
        return
    end

    if not onG and m and C.autostrafeEnabled and keyDown(C.autostrafeKey) then
        local h = Vector3.new(ev.X, 0, ev.Z)
        local curSpeed = h.Magnitude
        if curSpeed < C.autostrafeMaxSpeed then
            local add = math.min(C.autostrafeMaxSpeed - curSpeed, C.autostrafeAccel * dt)
            local newH = h + m * add
            hrp.AssemblyLinearVelocity = Vector3.new(newH.X, ev.Y, newH.Z)
        end
    end

    if onG then
        if not m and C.counterStrafeEnabled and bhopStreak == 0 then
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
                if bhopStreak == 1 then
                    local h = Vector3.new(ev.X, 0, ev.Z)
                    bhopChainVel = math.max(h.Magnitude, C.walkSpeed)
                end
            end
        else
            bhopStreak = 0
            bhopChainVel = 0
            bhopCacheVel = nil
        end
    end

    ensureFootSparks()
    if footSparks then
        if onG then
            local spd = Vector3.new(ev.X, ev.Z).Magnitude
            footSparks.Rate = spd > 2 and 25 or 0
        else
            footSparks.Rate = 45
        end
    end

    local pos = hrp.Position
    if pos.Y < C.fallY or pos.Magnitude > C.resetDist then
        hrp.CFrame = CFrame.new(spawnPos); vel = Vector3.zero
    end
end)

-- ============================================================
-- AIM / ESP MODULE
-- ============================================================
local function getChar(p)
    local c = p.Character
    if not c then return nil end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return nil end
    local r = c:FindFirstChild("HumanoidRootPart")
    if not r then return nil end
    return c, h, r
end

local function getAimPart(character)
    if not character then return nil end
    local part = character:FindFirstChild(Aim.targetPart)
    if not part then
        part = character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("HumanoidRootPart")
    end
    return part
end

local function isVisible(part)
    if not part then return false end
    local camObj = workspace.CurrentCamera
    local origin = camObj.CFrame.Position
    local dir = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}   -- self only
    params.IgnoreWater = true
    local result = workspace:Raycast(origin, dir, params)
    if not result then return true end
    return result.Instance == part or result.Instance:IsDescendantOf(part.Parent)
end

local function predictPos(part)
    if not part then return Vector3.zero end
    local root = part.Parent and part.Parent:FindFirstChild("HumanoidRootPart")
    if not root then return part.Position end
    local v = root.AssemblyLinearVelocity
    local ping = 0
    pcall(function() ping = (plr:GetNetworkPing() or 0) end)
    local t = ping * 0.5 + (Aim.prediction or 0)
    return part.Position + v * t
end

local function getClosestTarget()
    local camObj = workspace.CurrentCamera
    local camPos = camObj.CFrame.Position
    local best, bestDist = nil, math.huge
    local mousePos = UIS:GetMouseLocation()

    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= plr then
            local c, h, r = getChar(other)
            if c and h and r then
                local skip = false
                if Aim.aliveCheck and h.Health <= 0 then skip = true end
                if Aim.teamCheck and plr.Team and other.Team and plr.Team == other.Team then skip = true end
                if not skip then
                    local part = getAimPart(c)
                    if part then
                        local predicted = predictPos(part)
                        local sp, on = camObj:WorldToViewportPoint(predicted)
                        if on and sp.Z > 0 then
                            local dx, dy = sp.X - mousePos.X, sp.Y - mousePos.Y
                            local d2 = math.sqrt(dx*dx + dy*dy)
                            if d2 <= Aim.fov then
                                local wd = (predicted - camPos).Magnitude
                                if wd < bestDist then
                                    if Aim.visibleOnly and Aim.wallCheck and not isVisible(part) then
                                        -- skip
                                    else
                                        best = {player = other, part = part, pos = predicted}
                                        bestDist = wd
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function fireAtTarget()
    if not aimTarget then return end
    pcall(function()
        VIM:SendMouseButtonEvent(mouse.X, mouse.Y, 0, true, game, 0)
        VIM:SendMouseButtonEvent(mouse.X, mouse.Y, 0, false, game, 0)
    end)
end

-- FOV circle
local fovCircle = nil
if hasDrawing then
    local ok, obj = pcall(Drawing.new, "Circle")
    if ok then
        fovCircle = obj
        pcall(function()
            fovCircle.Color = Color3.fromRGB(255, 80, 80)
            fovCircle.Thickness = 1.5
            fovCircle.Transparency = 0.4
            fovCircle.Filled = false
            fovCircle.Visible = false
        end)
    end
end

-- ESP storage (Drawing preferred; Billboard fallback)
local espCache = {}
local highlightCache = {}

local function newDraw(class, props)
    if not hasDrawing then return nil end
    local ok, obj = pcall(Drawing.new, class)
    if not ok then return nil end
    for k, v in pairs(props or {}) do
        pcall(function() obj[k] = v end)
    end
    return obj
end

local function cleanupEsp(p)
    local cache = espCache[p]
    if cache then
        for _, obj in pairs(cache) do
            if obj and obj.Remove then pcall(function() obj:Remove() end) end
        end
        espCache[p] = nil
    end
    local hl = highlightCache[p]
    if hl then pcall(function() hl:Destroy() end); highlightCache[p] = nil end
end

local function cleanupAllEsp()
    for p in pairs(espCache) do cleanupEsp(p) end
    for p in pairs(highlightCache) do cleanupEsp(p) end
end

local function updateEsp()
    if not Esp.enabled then
        if next(espCache) then cleanupAllEsp() end
        return
    end
    local camObj = workspace.CurrentCamera
    local camPos = camObj.CFrame.Position
    local viewport = camObj.ViewportSize
    local seen = {}

    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= plr then
            local c, h, r = getChar(other)
            if c and h and r and h.Health > 0 then
                local dist = (r.Position - camPos).Magnitude
                if dist <= Esp.maxDistance then
                    local headPos, on = camObj:WorldToViewportPoint(r.Position + Vector3.new(0, 1.5, 0))
                    local footPos = camObj:WorldToViewportPoint(r.Position - Vector3.new(0, 2.5, 0))
                    if on and headPos.Z > 0 and footPos.Z > 0 then
                        seen[other] = true
                        local cache = espCache[other]
                        if not cache and hasDrawing then
                            cache = {
                                box = newDraw("Square", {}),
                                name = newDraw("Text", {Size = Esp.textSize, Center = false, Outline = true}),
                                health = newDraw("Square", {}),
                                healthBg = newDraw("Square", {Color = Color3.fromRGB(0,0,0), Filled = true, Transparency = 0.4}),
                                tracer = newDraw("Line", {Thickness = 1, Transparency = 0.4}),
                            }
                            espCache[other] = cache
                        end
                        if cache then
                            local box, nm, hp, hpBg, tr = cache.box, cache.name, cache.health, cache.healthBg, cache.tracer
                            local x = math.min(headPos.X, footPos.X)
                            local y = math.min(headPos.Y, footPos.Y)
                            local w = math.max(math.abs(headPos.X - footPos.X), 4)
                            local hgt = math.max(math.abs(headPos.Y - footPos.Y), 6)
                            if box then
                                box.Visible = Esp.box
                                box.Color = Esp.boxColor
                                box.Thickness = 1
                                box.Position = Vector2.new(x, y)
                                box.Size = Vector2.new(w, hgt)
                            end
                            if nm then
                                nm.Visible = Esp.name
                                nm.Color = Esp.color
                                nm.Position = Vector2.new(headPos.X - 40, headPos.Y - 18)
                                local label = other.Name
                                if Esp.distance then label = label .. " [" .. math.floor(dist) .. "]" end
                                nm.Text = label
                            end
                            if hp and hpBg then
                                hpBg.Visible = Esp.health
                                hpBg.Position = Vector2.new(headPos.X - 60, math.min(headPos.Y, footPos.Y))
                                hpBg.Size = Vector2.new(3, hgt)
                                hp.Visible = Esp.health
                                hp.Color = Color3.fromRGB(80, 220, 80)
                                hp.Position = Vector2.new(headPos.X - 60, math.min(headPos.Y, footPos.Y) + hgt * (1 - h.Health / h.MaxHealth))
                                hp.Size = Vector2.new(3, hgt * (h.Health / h.MaxHealth))
                                hp.Filled = true
                            end
                            if tr then
                                tr.Visible = Esp.tracer
                                tr.Color = Esp.boxColor
                                tr.From = Vector2.new(viewport.X / 2, viewport.Y)
                                tr.To = Vector2.new(headPos.X, math.min(headPos.Y, footPos.Y) + 20)
                            end
                        end
                        -- chams via Highlight (works in Studio too)
                        if Esp.chams then
                            if not highlightCache[other] then
                                local hl = Instance.new("Highlight")
                                hl.Parent = c
                                hl.FillColor = Esp.color
                                hl.OutlineColor = Esp.color
                                hl.FillTransparency = 0.6
                                hl.OutlineTransparency = 0.2
                                highlightCache[other] = hl
                            else
                                local hl = highlightCache[other]
                                hl.FillColor = Esp.color
                                hl.OutlineColor = Esp.color
                            end
                        else
                            if highlightCache[other] then
                                highlightCache[other]:Destroy()
                                highlightCache[other] = nil
                            end
                        end
                    end
                end
            end
        end
    end

    for p in pairs(espCache) do
        if not seen[p] then cleanupEsp(p) end
    end
    for p in pairs(highlightCache) do
        if not seen[p] then
            if highlightCache[p] then highlightCache[p]:Destroy() end
            highlightCache[p] = nil
        end
    end
end

-- ============================================================
-- AIM RENDER STEP — respects bhop, respects menu
-- ============================================================
RS:BindToRenderStep("CucumberAim", Enum.RenderPriority.Camera.Value + 2, function(dt)
    if not _G.__CUCUMBER_LOADED then return end
    if not hrp or not hrp.Parent then return end

    updateEsp()

    -- bhop has priority: don't touch camera while chaining bhop midair
    local bhopActive = false
    if bhopStreak > 0 and hum then
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping then
            bhopActive = true
        end
    end

    local aimActive = Aim.enabled and holdingAim and not menuOpen
    if aimActive and not bhopActive then
        aimTarget = getClosestTarget()
    else
        aimTarget = nil
    end

    if aimTarget then
        local camObj = workspace.CurrentCamera
        local origin = camObj.CFrame.Position
        local direction = (aimTarget.pos - origin).Unit
        local currentLook = camObj.CFrame.LookVector

        if Aim.silent then
            -- micro-nudge: enough to steer raycast, too small to visibly snap
            if currentLook:Dot(direction) < 0.9999 then
                camObj.CFrame = camObj.CFrame:Lerp(
                    CFrame.lookAt(origin, origin + direction), 0.12)
            end
        else
            local lookCFrame = CFrame.lookAt(origin, origin + direction)
            camObj.CFrame = camObj.CFrame:Lerp(lookCFrame,
                math.clamp(Aim.smoothness, 0.01, 1))
        end
    end

    if aimTarget and Aim.autoFire and not bhopActive then
        fireAtTarget()
    end

    if Aim.triggerbot and not menuOpen then
        local camObj = workspace.CurrentCamera
        local mousePos = UIS:GetMouseLocation()
        for _, other in ipairs(Players:GetPlayers()) do
            if other ~= plr then
                local c2, h2, r2 = getChar(other)
                if c2 and h2 and r2 and h2.Health > 0 then
                    local part = getAimPart(c2)
                    if part then
                        local sp, on = camObj:WorldToViewportPoint(part.Position)
                        if on and sp.Z > 0 then
                            local d = math.sqrt((sp.X-mousePos.X)^2 + (sp.Y-mousePos.Y)^2)
                            if d <= Aim.triggerFov and isVisible(part) then
                                fireAtTarget()
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    if fovCircle then
        if Aim.drawFov and Aim.enabled then
            fovCircle.Visible = true
            local camObj = workspace.CurrentCamera
            fovCircle.Position = Vector2.new(camObj.ViewportSize.X / 2, camObj.ViewportSize.Y / 2)
            fovCircle.Radius = Aim.fov
        else
            fovCircle.Visible = false
        end
    end
end)

-- ============================================================
-- HUD
-- ============================================================
local hud = Instance.new("ScreenGui")
hud.Name = "CucumberHUD"; hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true; hud.DisplayOrder = 998
hud.Parent = plr:WaitForChild("PlayerGui")

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
speedTitle.BackgroundTransparency = 1
speedTitle.Font = Enum.Font.GothamBold
speedTitle.Text = "CUCUMBER"; speedTitle.TextColor3 = C.colAccent2; speedTitle.TextSize = 9

local speedTxt = Instance.new("TextLabel", speedFrame)
speedTxt.Size = UDim2.new(1,0,0,30); speedTxt.Position = UDim2.new(0,0,0,16)
speedTxt.BackgroundTransparency = 1
speedTxt.Font = Enum.Font.GothamBlack
speedTxt.Text = "0.0"; speedTxt.TextColor3 = C.colAccent; speedTxt.TextSize = 24

local speedBarBg = Instance.new("Frame", speedFrame)
speedBarBg.Size = UDim2.new(1,-16,0,5); speedBarBg.Position = UDim2.new(0,8,1,-12)
speedBarBg.BackgroundColor3 = Color3.fromRGB(20,30,20); speedBarBg.BorderSizePixel = 0
speedBarBg.Visible = C.showSpeedBar
Instance.new("UICorner", speedBarBg).CornerRadius = UDim.new(1,0)
local speedBarFill = Instance.new("Frame", speedBarBg)
speedBarFill.Size = UDim2.new(0,0,1,0); speedBarFill.BackgroundColor3 = C.colAccent
speedBarFill.BorderSizePixel = 0
Instance.new("UICorner", speedBarFill).CornerRadius = UDim.new(1,0)

local infoFrame = Instance.new("Frame", hud)
infoFrame.Size = UDim2.new(0,170,0,22); infoFrame.Position = UDim2.new(0.5,-85,0,88)
infoFrame.BackgroundColor3 = Color3.fromRGB(8,12,8); infoFrame.BackgroundTransparency = 0.5
infoFrame.BorderSizePixel = 0
Instance.new("UICorner", infoFrame).CornerRadius = UDim.new(0,6)
local infoLbl = Instance.new("TextLabel", infoFrame)
infoLbl.Size = UDim2.new(1,0,1,0); infoLbl.BackgroundTransparency = 1
infoLbl.Font = Enum.Font.GothamBold
infoLbl.Text = "FPS -- | PING --"
infoLbl.TextColor3 = C.colAccent2; infoLbl.TextSize = 10

local streakLbl = Instance.new("TextLabel", hud)
streakLbl.Size = UDim2.new(0,200,0,28); streakLbl.Position = UDim2.new(0.5,-100,0,116)
streakLbl.BackgroundTransparency = 1
streakLbl.Font = Enum.Font.GothamBlack
streakLbl.Text = ""; streakLbl.TextColor3 = C.colAccent; streakLbl.TextSize = 22
streakLbl.Visible = C.showStreak

local indicatorFrame = Instance.new("Frame", hud)
indicatorFrame.Size = UDim2.new(0,160,0,34)
indicatorFrame.Position = UDim2.new(0.5,-80,1,-115)
indicatorFrame.BackgroundColor3 = Color3.fromRGB(8,12,8)
indicatorFrame.BackgroundTransparency = 0.35
indicatorFrame.BorderSizePixel = 0
indicatorFrame.Visible = C.showIndicators
Instance.new("UICorner", indicatorFrame).CornerRadius = UDim.new(0,8)
local indStroke = Instance.new("UIStroke", indicatorFrame)
indStroke.Color = C.colAccent; indStroke.Thickness = 1.5; indStroke.Transparency = 0.4
local indLbl = Instance.new("TextLabel", indicatorFrame)
indLbl.Size = UDim2.new(1,0,1,0); indLbl.BackgroundTransparency = 1
indLbl.Font = Enum.Font.GothamBlack
indLbl.Text = "—"; indLbl.TextColor3 = C.colAccent2; indLbl.TextSize = 16
indLbl.TextTransparency = 0.6

local keysFrame = Instance.new("Frame", hud)
keysFrame.Size = UDim2.new(0,500,0,40); keysFrame.Position = UDim2.new(0.5,-250,1,-70)
keysFrame.BackgroundTransparency = 1
keysFrame.Visible = C.showMidKeys
local keysLayout = Instance.new("UIListLayout", keysFrame)
keysLayout.FillDirection = Enum.FillDirection.Horizontal
keysLayout.Padding = UDim.new(0,6)
keysLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function makeKeyBadge(text, order)
    local box = Instance.new("Frame", keysFrame)
    box.Size = UDim2.new(0,34,0,34)
    box.BackgroundColor3 = Color3.fromRGB(8,12,8); box.BackgroundTransparency = 0.45
    box.BorderSizePixel = 0; box.LayoutOrder = order
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)
    local st = Instance.new("UIStroke", box)
    st.Color = Color3.fromRGB(230,240,230); st.Thickness = 1.5; st.Transparency = 0.6
    local lbl = Instance.new("TextLabel", box)
    lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = text; lbl.TextColor3 = Color3.fromRGB(230,240,230); lbl.TextSize = 13
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
local kbH     = makeKeyBadge("H", 9)
local kbQ     = makeKeyBadge("Q", 10)
local kbX     = makeKeyBadge("X", 11)

local function setKey(b, on)
    if not b then return end
    local c = C.colAccent
    b.stroke.Color = on and c or Color3.fromRGB(230,240,230)
    b.stroke.Transparency = on and 0 or 0.6
    b.label.TextColor3 = on and c or Color3.fromRGB(230,240,230)
    b.box.BackgroundTransparency = on and 0.25 or 0.45
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

local MW, MH = 640, 480
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
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.Text = "CUCUMBER"; title.TextColor3 = C.colAccent; title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left

local subtitle = Instance.new("TextLabel", headerBg)
subtitle.Size = UDim2.new(1,-60,0,14); subtitle.Position = UDim2.new(0,16,0,34)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "v29 — aim + esp"
subtitle.TextColor3 = C.colAccent2; subtitle.TextSize = 10
subtitle.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", headerBg)
closeBtn.Size = UDim2.new(0,30,0,30); closeBtn.Position = UDim2.new(1,-40,0,13)
closeBtn.BackgroundColor3 = Color3.fromRGB(20,28,20)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "×"; closeBtn.TextColor3 = Color3.fromRGB(100,140,100)
closeBtn.TextSize = 18; closeBtn.AutoButtonColor = false
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
    btn.BackgroundColor3 = Color3.fromRGB(20,28,20); btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
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

-- generic toggle bound to any table
local function makeToggle(parent, label, tbl, key, onChange)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,0,0,30); row.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1,-60,1,0); lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham; lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(230,240,230); lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(0,40,0,20); track.Position = UDim2.new(1,-40,0.5,-10)
    track.BackgroundColor3 = tbl[key] and C.colAccent or Color3.fromRGB(40,60,40)
    track.BorderSizePixel = 0
    corner(track, 10)
    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0,16,0,16)
    knob.Position = tbl[key] and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
    knob.BackgroundColor3 = Color3.fromRGB(240,255,240)
    knob.BorderSizePixel = 0
    corner(knob, 8)
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""
    btn.MouseButton1Click:Connect(function()
        tbl[key] = not tbl[key]
        local on = tbl[key]
        Tween:Create(track, TweenInfo.new(0.18), {BackgroundColor3 = on and C.colAccent or Color3.fromRGB(40,60,40)}):Play()
        Tween:Create(knob, TweenInfo.new(0.18), {Position = on and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)}):Play()
        if onChange then pcall(onChange, on) end
    end)
    return row
end

-- generic slider bound to any table
local function makeSlider(parent, label, tbl, key, min, max, suffix)
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
    val.BackgroundTransparency = 1
    val.Font = Enum.Font.GothamBold
    val.Text = tostring(tbl[key]) .. (suffix or "")
    val.TextColor3 = C.colAccent; val.TextSize = 13
    val.TextXAlignment = Enum.TextXAlignment.Right
    local bar = Instance.new("Frame", row)
    bar.Size = UDim2.new(1,0,0,6); bar.Position = UDim2.new(0,0,0,28)
    bar.BackgroundColor3 = Color3.fromRGB(40,60,40); bar.BorderSizePixel = 0
    corner(bar, 3)
    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new(math.clamp((tbl[key]-min)/(max-min),0,1),0,1,0)
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
        tbl[key] = v
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
    btn.BackgroundColor3 = Color3.fromRGB(20,28,20); btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold; btn.Text = label
    btn.TextColor3 = color or Color3.fromRGB(230,240,230); btn.TextSize = 12
    btn.AutoButtonColor = false
    corner(btn, 5); stroke(btn, Color3.fromRGB(40,60,40), 1, 0.3)
    btn.MouseEnter:Connect(function()
        Tween:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = C.colAccent}):Play()
        btn.TextColor3 = Color3.fromRGB(10,14,10)
    end)
    btn.MouseLeave:Connect(function()
        Tween:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(20,28,20)}):Play()
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

local pageMove = createPage("Movement")
local pageAir  = createPage("Air")
local pageEdge = createPage("Edge")
local pageAim  = createPage("Aimbot")
local pageEsp  = createPage("Visuals")
local pageHUD  = createPage("HUD")
local pageKeys = createPage("Keybinds")
local pageMisc = createPage("Settings")

local tabMove  = createTabButton("Movement", 1)
local tabAir   = createTabButton("Air", 2)
local tabEdge  = createTabButton("Edge", 3)
local tabAim   = createTabButton("Aimbot", 4)
local tabEsp   = createTabButton("Visuals", 5)
local tabHUD   = createTabButton("HUD", 6)
local tabKeys  = createTabButton("Keybinds", 7)
local tabMisc  = createTabButton("Settings", 8)

tabMove.MouseButton1Click:Connect(function() selectTab("Movement") end)
tabAir.MouseButton1Click:Connect(function() selectTab("Air") end)
tabEdge.MouseButton1Click:Connect(function() selectTab("Edge") end)
tabAim.MouseButton1Click:Connect(function() selectTab("Aimbot") end)
tabEsp.MouseButton1Click:Connect(function() selectTab("Visuals") end)
tabHUD.MouseButton1Click:Connect(function() selectTab("HUD") end)
tabKeys.MouseButton1Click:Connect(function() selectTab("Keybinds") end)
tabMisc.MouseButton1Click:Connect(function() selectTab("Settings") end)

-- Movement
makeLabel(pageMove, "MASTER")
makeToggle(pageMove, "Movement enabled", C, "moveEnabled")
makeLabel(pageMove, "BHOP")
makeSlider(pageMove, "Walk speed", C, "walkSpeed", 8, 60, "")
makeSlider(pageMove, "Bhop cooldown", C, "jumpCd", 0.01, 0.15, "s")
makeSlider(pageMove, "Perfect bhop bonus", C, "bhopPerfectBonus", 0, 5, "")
makeSlider(pageMove, "Bhop max speed", C, "bhopMaxSpeed", 30, 150, "")
makeLabel(pageMove, "COUNTER-STRAFE")
makeToggle(pageMove, "Counter-strafe", C, "counterStrafeEnabled")
makeSlider(pageMove, "Counter power", C, "counterStrafePower", 0.5, 0.99, "")

-- Air
makeLabel(pageAir, "AIR STRAFE")
makeToggle(pageAir, "Autostrafe (Shift)", C, "autostrafeEnabled")
makeSlider(pageAir, "Air accel", C, "autostrafeAccel", 20, 200, "")
makeSlider(pageAir, "Air max speed", C, "autostrafeMaxSpeed", 40, 200, "")
makeLabel(pageAir, "GLIDE (PS — feet)")
makeSlider(pageAir, "Glide control", C, "glideControl", 2, 25, "")
makeLabel(pageAir, "DOUBLE JUMP")
makeToggle(pageAir, "Enable double jump", C, "doubleJumpEnabled")
makeSlider(pageAir, "Double jump power", C, "doubleJumpPower", 10, 80, "")

-- Edge
makeLabel(pageEdge, "EDGEJUMP")
makeToggle(pageEdge, "Enable edgejump", C, "edgeJumpEnabled")
makeSlider(pageEdge, "Jump power", C, "edgeJumpPower", 5, 60, "")
makeSlider(pageEdge, "Jump limit", C, "edgeJumpLimit", 1, 5, "")
makeLabel(pageEdge, "EDGEBUG (EB) — auto")
makeToggle(pageEdge, "Enable edgebug", C, "edgebugEnabled")
makeSlider(pageEdge, "Min fall speed", C, "edgebugMinFallSpeed", 10, 50, "")
makeLabel(pageEdge, "TEXTURE BUG (TB — head surf)")
makeToggle(pageEdge, "Enable texture bug", C, "textureBugEnabled")
makeSlider(pageEdge, "Max speed", C, "textureBugMaxSpeed", 40, 200, "")
makeSlider(pageEdge, "Control", C, "textureBugControl", 2, 25, "")
makeSlider(pageEdge, "Stick force", C, "textureBugStick", 0, 15, "")
makeSlider(pageEdge, "Head scan range", C, "textureBugRange", 2, 8, "st")
makeToggle(pageEdge, "Camera tilt", C, "textureBugCamTilt")
makeButton(pageEdge, "Reset edgejump counter", function() C.edgeJumpUsed = 0 end)

-- Aimbot
makeLabel(pageAim, "AIMBOT")
makeToggle(pageAim, "Enable aimbot", Aim, "enabled")
makeToggle(pageAim, "Silent aim (micro-nudge)", Aim, "silent")
makeToggle(pageAim, "Visible only", Aim, "visibleOnly")
makeToggle(pageAim, "Team check", Aim, "teamCheck")
makeToggle(pageAim, "Draw FOV circle", Aim, "drawFov")
makeSlider(pageAim, "FOV radius", Aim, "fov", 20, 800, "")
makeSlider(pageAim, "Smoothness (visual)", Aim, "smoothness", 0.01, 1, "")
makeSlider(pageAim, "Prediction", Aim, "prediction", 0, 0.3, "s")
makeLabel(pageAim, "AIM PART")
makeButton(pageAim, "Head", function() Aim.targetPart = "Head" end)
makeButton(pageAim, "Torso", function() Aim.targetPart = "Torso" end)
makeButton(pageAim, "HumanoidRootPart", function() Aim.targetPart = "HumanoidRootPart" end)
makeLabel(pageAim, "EXTRA")
makeToggle(pageAim, "Auto-fire", Aim, "autoFire")
makeToggle(pageAim, "Triggerbot", Aim, "triggerbot")
makeSlider(pageAim, "Triggerbot FOV", Aim, "triggerFov", 1, 20, "px")

-- Visuals
makeLabel(pageEsp, "ESP")
makeToggle(pageEsp, "Enable ESP", Esp, "enabled")
makeToggle(pageEsp, "Box", Esp, "box")
makeToggle(pageEsp, "Name", Esp, "name")
makeToggle(pageEsp, "Health bar", Esp, "health")
makeToggle(pageEsp, "Distance", Esp, "distance")
makeToggle(pageEsp, "Tracer", Esp, "tracer")
makeToggle(pageEsp, "Chams (Highlight)", Esp, "chams")
makeSlider(pageEsp, "Max distance", Esp, "maxDistance", 100, 5000, "")

-- HUD
makeLabel(pageHUD, "MID SCREEN")
makeToggle(pageHUD, "Show speed", C, "showSpeed", function(v) speedFrame.Visible = v end)
makeToggle(pageHUD, "Show speed bar", C, "showSpeedBar", function(v) speedBarBg.Visible = v end)
makeToggle(pageHUD, "Show FPS + Ping", C, "showFPS", function(v) infoFrame.Visible = v end)
makeToggle(pageHUD, "Show keybinds", C, "showMidKeys", function(v) keysFrame.Visible = v end)
makeToggle(pageHUD, "Show bhop streak", C, "showStreak", function(v) streakLbl.Visible = v end)
makeToggle(pageHUD, "Show indicators", C, "showIndicators", function(v) indicatorFrame.Visible = v end)

-- Keybinds
makeLabel(pageKeys, "CLICK A BUTTON, THEN PRESS A KEY")

local function makeKeybindRow(parent, label, tbl, keyName)
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
    btn.Text = tbl[keyName] and tbl[keyName].Name or "?"
    btn.TextColor3 = C.colAccent; btn.TextSize = 12
    btn.AutoButtonColor = false
    corner(btn, 5); stroke(btn, Color3.fromRGB(40,60,40), 1, 0.3)
    btn.MouseButton1Click:Connect(function()
        btn.Text = "..."; btn.TextColor3 = Color3.fromRGB(255,200,80)
        local conn
        conn = UIS.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                tbl[keyName] = input.KeyCode
                btn.Text = input.KeyCode.Name
                btn.TextColor3 = C.colAccent
                conn:Disconnect()
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                btn.Text = tbl[keyName].Name
                btn.TextColor3 = C.colAccent
                conn:Disconnect()
            end
        end)
    end)
    return row
end

makeKeybindRow(pageKeys, "Bhop", C, "bhopKey")
makeKeybindRow(pageKeys, "Pixel surf (V)", C, "glideKey")
makeKeybindRow(pageKeys, "Edgejump", C, "edgeJumpKey")
makeKeybindRow(pageKeys, "Autostrafe", C, "autostrafeKey")
makeKeybindRow(pageKeys, "Texture bug (H)", C, "textureBugKey")
makeKeybindRow(pageKeys, "Aim (hold)", Aim, "key")
makeKeybindRow(pageKeys, "Aim toggle", Aim, "toggleKey")
makeKeybindRow(pageKeys, "Menu", C, "menuKey")
makeKeybindRow(pageKeys, "Mouse unlock", C, "mouseKey")

-- Settings
makeLabel(pageMisc, "CONFIG")
makeButton(pageMisc, "Save config", function()
    if saveConfig() then print("[CUCUMBER] saved") else print("[CUCUMBER] save failed") end
end)
makeButton(pageMisc, "Load config", function()
    if loadConfig() then print("[CUCUMBER] loaded") else print("[CUCUMBER] load failed") end
end)
makeLabel(pageMisc, "UTILITY")
makeToggle(pageMisc, "Anti-AFK", C, "antiAfkEnabled")
makeButton(pageMisc, "Respawn to spawn", function()
    if hrp then hrp.CFrame = CFrame.new(spawnPos); vel = Vector3.zero end
end)
makeButton(pageMisc, "Unload script", function()
    if _G.__CUCUMBER_UNLOAD then _G.__CUCUMBER_UNLOAD() end
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

-- MOUSE UNLOCK + menu funcs
local function openMenu()
    menuOpen = true
    menu.Visible = true
    glow.Visible = true
    UIS.MouseBehavior = Enum.MouseBehavior.Default
    UIS.MouseIconEnabled = true
    if currentTab == nil then selectTab("Movement") end
end
local function closeMenu()
    menuOpen = false
    menu.Visible = false
    glow.Visible = false
    if not mouseUnlocked then
        UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
    end
end
local function toggleMenu()
    if menuOpen then closeMenu() else openMenu() end
end

RS:BindToRenderStep("CucumberMouseUnlock", Enum.RenderPriority.Camera.Value + 1, function()
    if menuOpen or mouseUnlocked then
        if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then
            UIS.MouseBehavior = Enum.MouseBehavior.Default
        end
        if not UIS.MouseIconEnabled then UIS.MouseIconEnabled = true end
    end
end)

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

UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == C.menuKey then toggleMenu() end
    if i.KeyCode == C.unloadKey then
        if _G.__CUCUMBER_UNLOAD then _G.__CUCUMBER_UNLOAD() end
    end
    if i.KeyCode == C.mouseKey then
        mouseUnlocked = true
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        UIS.MouseIconEnabled = true
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.KeyCode == C.mouseKey then
        mouseUnlocked = false
        if not menuOpen then UIS.MouseBehavior = Enum.MouseBehavior.LockCenter end
    end
end)

-- UNLOAD
_G.__CUCUMBER_UNLOAD = function()
    _G.__CUCUMBER_LOADED = false
    pcall(saveConfig)
    pcall(cleanupAllEsp)
    pcall(function() if fovCircle then fovCircle:Remove() end end)
    pcall(function() RS:UnbindFromRenderStep("CucumberAim") end)
    pcall(function() RS:UnbindFromRenderStep("CucumberMouseUnlock") end)
    pcall(function() if footSparks then footSparks:Destroy() end end)
    pcall(function() if hud then hud:Destroy() end end)
    pcall(function() if gui then gui:Destroy() end end)
    print("[CUCUMBER] unloaded")
end

-- INIT
loadConfig()
if cam then cam.FieldOfView = 90 end
selectTab("Movement")

-- HUD LOOP
local fpsCount = 0
local fpsTime = tick()
local currentFPS = 60
local lastPingUpdate = 0
local currentPing = 0

RS.RenderStepped:Connect(function(dt)
    if not _G.__CUCUMBER_LOADED then return end
    if not hrp or not hrp.Parent then return end

    local v = hrp.AssemblyLinearVelocity
    local spd = Vector3.new(v.X, v.Z).Magnitude
    smoothedSpeed = smoothedSpeed + (spd - smoothedSpeed) * math.min(dt * 12, 1)
    speedTxt.Text = string.format("%.1f", smoothedSpeed)
    local col = C.colAccent
    if spd > 50 then col = Color3.fromRGB(230,230,100) end
    if spd > 90 then col = Color3.fromRGB(255,90,100) end
    speedTxt.TextColor3 = col
    speedBarFill.BackgroundColor3 = col
    speedBarFill.Size = UDim2.new(math.clamp(spd/120, 0, 1), 0, 1, 0)

    fpsCount = fpsCount + 1
    local now = tick()
    if now - fpsTime >= 0.5 then
        currentFPS = math.floor(fpsCount / (now - fpsTime) + 0.5)
        fpsCount = 0; fpsTime = now
    end
    if now - lastPingUpdate > 1 then
        lastPingUpdate = now
        pcall(function() currentPing = math.floor((plr:GetNetworkPing() or 0) * 1000) end)
    end
    if C.showFPS then
        infoLbl.Text = string.format("FPS %d | PING %d", currentFPS, currentPing)
    end

    if C.showStreak and bhopStreak > 0 then
        streakLbl.Text = "x" .. bhopStreak
        local sc = C.colAccent
        if bhopStreak >= 10 then sc = Color3.fromRGB(230,230,100) end
        if bhopStreak >= 20 then sc = Color3.fromRGB(255,90,100) end
        streakLbl.TextColor3 = sc
    else
        streakLbl.Text = ""
    end

    if C.showIndicators then
        local tn = tick()
        local psActive = (tn - lastGlideTick) < 0.15
        local ebActive = (tn - lastEdgebugTick) < 1.0
        local tbActive = tbOn
        local parts = {}
        if psActive then table.insert(parts, "PS") end
        if ebActive then table.insert(parts, "EB") end
        if tbActive then
            table.insert(parts, tbHitSurface and "TB*" or "TB")
        end
        if Aim.enabled and holdingAim then table.insert(parts, "AIM") end
        if Aim.triggerbot then table.insert(parts, "TBOT") end
        if #parts == 0 then
            indLbl.Text = "—"; indLbl.TextColor3 = C.colAccent2; indStroke.Color = C.colAccent2
        elseif #parts == 1 then
            local c = C.colAccent
            local s = parts[1]
            if s:sub(1,2) == "EB" then c = Color3.fromRGB(255, 140, 90) end
            if s:sub(1,2) == "TB" then c = Color3.fromRGB(180, 140, 255) end
            if s:sub(1,3) == "AIM" then c = Color3.fromRGB(255, 80, 80) end
            indLbl.Text = s; indLbl.TextColor3 = c; indStroke.Color = c
        else
            indLbl.Text = table.concat(parts, " + ")
            indLbl.TextColor3 = Color3.fromRGB(255, 200, 80)
            indStroke.Color = Color3.fromRGB(255, 200, 80)
        end
    end

    setKey(kbSpace, UIS:IsKeyDown(C.bhopKey))
    setKey(kbCtrl,  UIS:IsKeyDown(C.edgeJumpKey))
    setKey(kbShift, UIS:IsKeyDown(C.autostrafeKey))
    setKey(kbW,     UIS:IsKeyDown(Enum.KeyCode.W))
    setKey(kbA,     UIS:IsKeyDown(Enum.KeyCode.A))
    setKey(kbS,     UIS:IsKeyDown(Enum.KeyCode.S))
    setKey(kbD,     UIS:IsKeyDown(Enum.KeyCode.D))
    setKey(kbV,     UIS:IsKeyDown(C.glideKey))
    setKey(kbH,     UIS:IsKeyDown(C.textureBugKey))
    setKey(kbQ,     UIS:IsKeyDown(Aim.key))
    setKey(kbX,     Aim.enabled)
end)

game:BindToClose(function()
    if _G.__CUCUMBER_UNLOAD then _G.__CUCUMBER_UNLOAD() end
end)

print("[CUCUMBER] v29 loaded")
