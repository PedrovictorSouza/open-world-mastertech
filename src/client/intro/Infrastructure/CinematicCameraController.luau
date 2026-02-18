local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CinematicCameraController = {}
CinematicCameraController.__index = CinematicCameraController

local function clampNumber(value, minValue, maxValue, fallback)
    local numericValue = tonumber(value)
    if numericValue == nil then
        return fallback
    end

    return math.clamp(numericValue, minValue, maxValue)
end

function CinematicCameraController.new()
    return setmetatable({}, CinematicCameraController)
end

function CinematicCameraController:_debugLog(isDebugEnabled, ...)
    if not isDebugEnabled then
        return
    end

    warn("[CameraProbe]", ...)
end

function CinematicCameraController:_createEffects()
    local blur = Instance.new("BlurEffect")
    blur.Name = "SpawnIntroBlur"
    blur.Size = 0
    blur.Parent = Lighting

    local colorCorrection = Instance.new("ColorCorrectionEffect")
    colorCorrection.Name = "SpawnIntroColor"
    colorCorrection.Brightness = 0
    colorCorrection.Contrast = 0
    colorCorrection.Saturation = 0
    colorCorrection.Parent = Lighting

    local depthOfField = Instance.new("DepthOfFieldEffect")
    depthOfField.Name = "SpawnIntroDof"
    depthOfField.InFocusRadius = 26
    depthOfField.NearIntensity = 0.05
    depthOfField.FarIntensity = 0.12
    depthOfField.Parent = Lighting

    return blur, colorCorrection, depthOfField
end

function CinematicCameraController:_destroyEffect(effect)
    if effect and effect.Parent then
        effect:Destroy()
    end
end

function CinematicCameraController:_calculateOffset(progress, easedProgress, orbitSeed)
    local seed = orbitSeed * 0.0001

    local baseAngle = progress * math.pi * 2
    local curveOffset = math.rad(20) * math.sin((progress + seed) * math.pi * 2.2)
    local angle = baseAngle + curveOffset

    local radiusX = 26 - (8 * easedProgress) + math.sin((progress + seed) * math.pi * 2.6) * 2.4
    local radiusZ = 14 + math.sin((progress + seed * 1.5) * math.pi) * 6 + math.sin((progress + seed) * math.pi * 3.2) * 1.5

    local lateralDrift = math.sin((progress + seed) * math.pi * 2) * 3.5

    -- Cinematic rise: starts below the subject and climbs through the shot.
    local baseRise = -14 + (24 * easedProgress)
    local verticalArc = math.sin(progress * math.pi) * 8
    local settle = 4 * easedProgress
    local height = baseRise + verticalArc - settle

    return Vector3.new(
        math.cos(angle) * radiusX + lateralDrift,
        height,
        math.sin(angle) * radiusZ
    )
end

function CinematicCameraController:_calculateFieldOfView(baseFieldOfView, progress, easedProgress)
    local cinematicKick = 10 * (1 - easedProgress)
    local pulse = math.sin(progress * math.pi * 3.5) * 1.5 * (1 - easedProgress)

    return math.clamp(baseFieldOfView + cinematicKick + pulse, 50, 95)
end

function CinematicCameraController:_applyEffects(blur, colorCorrection, depthOfField, easedProgress)
    blur.Size = 1 + ((1 - easedProgress) * 8)

    colorCorrection.Contrast = 0.04 + ((1 - easedProgress) * 0.14)
    colorCorrection.Saturation = 0.02 + ((1 - easedProgress) * 0.08)
    colorCorrection.Brightness = (1 - easedProgress) * 0.02

    depthOfField.FarIntensity = 0.1 + ((1 - easedProgress) * 0.25)
    depthOfField.InFocusRadius = 18 + (easedProgress * 18)
end

function CinematicCameraController:_blendToDefault(camera, humanoidRootPart, subjectYOffset, blendOutSeconds, baseFieldOfView)
    if not humanoidRootPart.Parent then
        return
    end

    local blendStart = os.clock()
    local initialCFrame = camera.CFrame

    repeat
        local elapsed = os.clock() - blendStart
        local progress = math.clamp(elapsed / blendOutSeconds, 0, 1)
        local easedProgress = TweenService:GetValue(progress, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

        if not humanoidRootPart.Parent then
            break
        end

        local subjectPosition = humanoidRootPart.Position + Vector3.new(0, subjectYOffset, 0)
        local desiredCameraPosition = subjectPosition - (humanoidRootPart.CFrame.LookVector * 9) + Vector3.new(0, 3.2, 0)
        local desiredCFrame = CFrame.lookAt(desiredCameraPosition, subjectPosition)

        camera.CFrame = initialCFrame:Lerp(desiredCFrame, easedProgress)
        camera.FieldOfView = baseFieldOfView + ((1 - easedProgress) * 1.2)

        RunService.RenderStepped:Wait()
    until os.clock() - blendStart >= blendOutSeconds
end

function CinematicCameraController:play(character, payload)
    payload = payload or {}

    local camera = Workspace.CurrentCamera
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 3)
    local isDebugEnabled = payload.DebugLogs == true

    if not camera then
        self:_debugLog(isDebugEnabled, "CurrentCamera not ready, waiting")

        local waitStarted = os.clock()
        repeat
            RunService.RenderStepped:Wait()
            camera = Workspace.CurrentCamera
        until camera or (os.clock() - waitStarted) >= 10
    end

    if not camera or not humanoidRootPart then
        self:_debugLog(
            isDebugEnabled,
            "Cannot play intro",
            "camera=", tostring(camera ~= nil),
            "hrp=", tostring(humanoidRootPart ~= nil)
        )
        return false
    end

    local durationSeconds = clampNumber(payload.DurationSeconds, 3, 5, 4)
    local blendOutSeconds = clampNumber(payload.BlendOutSeconds, 0.2, 1.2, 0.55)
    local subjectYOffset = math.max(tonumber(payload.SubjectYOffset) or 2.8, 1)
    local orbitSeed = tonumber(payload.OrbitSeed) or 1

    local originalCameraSubject = camera.CameraSubject
    local originalFieldOfView = camera.FieldOfView
    local originalCameraPosition = camera.CFrame.Position

    self:_debugLog(
        isDebugEnabled,
        "Starting cinematic",
        "cameraType=", camera.CameraType.Name,
        "duration=", durationSeconds,
        "blendOut=", blendOutSeconds,
        "seed=", orbitSeed
    )

    local blur, colorCorrection, depthOfField = self:_createEffects()
    local maxDisplacement = 0
    local minFieldOfView = originalFieldOfView
    local maxFieldOfView = originalFieldOfView
    local frameCount = 0

    local function cleanup()
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = humanoid or originalCameraSubject
        camera.FieldOfView = originalFieldOfView

        self:_destroyEffect(blur)
        self:_destroyEffect(colorCorrection)
        self:_destroyEffect(depthOfField)
    end

    local ok, errorMessage = pcall(function()
        camera.CameraType = Enum.CameraType.Scriptable

        local startedAt = os.clock()

        repeat
            local elapsed = os.clock() - startedAt
            local progress = math.clamp(elapsed / durationSeconds, 0, 1)
            local easedProgress = TweenService:GetValue(progress, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)

            if not character.Parent or not humanoidRootPart.Parent then
                break
            end

            local subjectPosition = humanoidRootPart.Position + Vector3.new(0, subjectYOffset, 0)
            local offset = self:_calculateOffset(progress, easedProgress, orbitSeed)

            local cameraPosition = subjectPosition + offset
            local roll = math.rad(math.sin(progress * math.pi * 4) * 1.7) * (1 - easedProgress)

            camera.CFrame = CFrame.lookAt(cameraPosition, subjectPosition) * CFrame.Angles(0, 0, roll)
            camera.FieldOfView = self:_calculateFieldOfView(originalFieldOfView, progress, easedProgress)
            frameCount += 1
            maxDisplacement = math.max(maxDisplacement, (camera.CFrame.Position - originalCameraPosition).Magnitude)
            minFieldOfView = math.min(minFieldOfView, camera.FieldOfView)
            maxFieldOfView = math.max(maxFieldOfView, camera.FieldOfView)

            self:_applyEffects(blur, colorCorrection, depthOfField, easedProgress)

            RunService.RenderStepped:Wait()
        until os.clock() - startedAt >= durationSeconds

        self:_blendToDefault(camera, humanoidRootPart, subjectYOffset, blendOutSeconds, originalFieldOfView)
    end)

    cleanup()

    self:_debugLog(
        isDebugEnabled,
        "Cinematic finished",
        "frames=", frameCount,
        "maxDisplacement=", string.format("%.2f", maxDisplacement),
        "fovMin=", string.format("%.2f", minFieldOfView),
        "fovMax=", string.format("%.2f", maxFieldOfView)
    )

    if not ok then
        error(errorMessage)
    end

    return true
end

return CinematicCameraController
