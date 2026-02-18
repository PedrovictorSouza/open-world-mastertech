local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OutdoorCameraAssist = {}
OutdoorCameraAssist.__index = OutdoorCameraAssist

local RENDER_STEP_NAME = "OutdoorCameraAssist"
local TRIGGER_AREA_SCALE = 1.3
local TRIGGER_RADIUS_SCALE = math.sqrt(TRIGGER_AREA_SCALE)
local FULL_EFFECT_DISTANCE = 19 * TRIGGER_RADIUS_SCALE
local FADE_OUT_DISTANCE = 40 * TRIGGER_RADIUS_SCALE
local BLEND_TIME_SECONDS = 0.25
local BOARD_TARGET_FOV = 50
local BOARD_FRAME_MARGIN_STUDS = 1.2
local BOARD_LOCK_BLEND_MULTIPLIER = 1.25
local MOVEMENT_EXIT_THRESHOLD = 0.05
local MIN_EFFECT_BLEND = 0.001

local function smoothstep(value)
    local clamped = math.clamp(value, 0, 1)
    return clamped * clamped * (3 - (2 * clamped))
end

function OutdoorCameraAssist.new(localPlayer)
    return setmetatable({
        _localPlayer = localPlayer,
        _isBound = false,
        _blend = 0,
        _baseFieldOfView = nil,
        _cachedBoard = nil,
    }, OutdoorCameraAssist)
end

function OutdoorCameraAssist:_resolveBoard()
    local cachedBoard = self._cachedBoard
    if cachedBoard and cachedBoard.Parent and cachedBoard:IsA("BasePart") then
        return cachedBoard
    end

    local worldFolder = Workspace:FindFirstChild("ExpedicaoWorld")
    if not worldFolder then
        self._cachedBoard = nil
        return nil
    end

    local outdoorModel = worldFolder:FindFirstChild("OutdoorExpedicao")
    if not outdoorModel or not outdoorModel:IsA("Model") then
        self._cachedBoard = nil
        return nil
    end

    local board = outdoorModel:FindFirstChild("Board")
    if not board or not board:IsA("BasePart") then
        self._cachedBoard = nil
        return nil
    end

    self._cachedBoard = board
    return board
end

function OutdoorCameraAssist:_resolveHumanoidRootPart()
    local character = self._localPlayer.Character
    if not character then
        return nil
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart or not humanoidRootPart:IsA("BasePart") then
        return nil
    end

    return humanoidRootPart
end

function OutdoorCameraAssist:_resolveHumanoid()
    local character = self._localPlayer.Character
    if not character then
        return nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return nil
    end

    return humanoid
end

function OutdoorCameraAssist:_computeTargetBlend(humanoidRootPart, humanoid, board)
    if not humanoidRootPart or not board then
        return 0
    end

    if humanoid and humanoid.MoveDirection.Magnitude > MOVEMENT_EXIT_THRESHOLD then
        return 0
    end

    local distance = (humanoidRootPart.Position - board.Position).Magnitude

    if distance >= FADE_OUT_DISTANCE then
        return 0
    end

    if distance <= FULL_EFFECT_DISTANCE then
        return 1
    end

    local normalized = (FADE_OUT_DISTANCE - distance) / (FADE_OUT_DISTANCE - FULL_EFFECT_DISTANCE)
    return smoothstep(normalized)
end

function OutdoorCameraAssist:_computeBoardShot(camera, board, humanoidRootPart, baseFieldOfView)
    local boardCenter = board.Position
    local towardPlayer = humanoidRootPart.Position - boardCenter

    local boardNormal = board.CFrame.LookVector
    if towardPlayer:Dot(boardNormal) < 0 then
        boardNormal = -boardNormal
    end

    local targetFov = math.clamp(math.min(baseFieldOfView, BOARD_TARGET_FOV), 35, baseFieldOfView)
    local verticalFovRadians = math.rad(targetFov)
    local tangent = math.tan(verticalFovRadians * 0.5)
    local safeTangent = math.max(tangent, 0.001)

    local viewport = camera.ViewportSize
    local aspectRatio = viewport.X / math.max(viewport.Y, 1)

    local halfHeight = (board.Size.Y * 0.5) + BOARD_FRAME_MARGIN_STUDS
    local halfWidth = (board.Size.X * 0.5) + BOARD_FRAME_MARGIN_STUDS

    local distanceForHeight = halfHeight / safeTangent
    local distanceForWidth = halfWidth / (safeTangent * math.max(aspectRatio, 0.1))
    local shotDistance = math.max(distanceForHeight, distanceForWidth)

    local shotPosition = boardCenter + (boardNormal * shotDistance)
    return shotPosition, boardCenter, targetFov
end

function OutdoorCameraAssist:_step(deltaTime)
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    if camera.CameraType ~= Enum.CameraType.Custom then
        self._blend = 0
        self._baseFieldOfView = nil
        return
    end

    local humanoidRootPart = self:_resolveHumanoidRootPart()
    local humanoid = self:_resolveHumanoid()
    local board = self:_resolveBoard()
    local targetBlend = self:_computeTargetBlend(humanoidRootPart, humanoid, board)

    local safeDeltaTime = math.max(deltaTime, 1 / 240)
    local alpha = 1 - math.exp(-safeDeltaTime / BLEND_TIME_SECONDS)
    self._blend += (targetBlend - self._blend) * alpha

    if self._blend <= MIN_EFFECT_BLEND then
        self._baseFieldOfView = camera.FieldOfView
        return
    end

    if self._baseFieldOfView == nil then
        self._baseFieldOfView = camera.FieldOfView
    end

    if not board or not humanoidRootPart then
        self._blend = 0
        self._baseFieldOfView = camera.FieldOfView
        return
    end

    local baseFieldOfView = self._baseFieldOfView or camera.FieldOfView
    local defaultPosition = camera.CFrame.Position
    local defaultLookTarget = defaultPosition + (camera.CFrame.LookVector * 30)

    local boardShotPosition, boardLookTarget, boardTargetFov = self:_computeBoardShot(
        camera,
        board,
        humanoidRootPart,
        baseFieldOfView
    )

    local effectBlend = self._blend
    local boardLockBlend = smoothstep(math.clamp(effectBlend * BOARD_LOCK_BLEND_MULTIPLIER, 0, 1))

    local finalPosition = defaultPosition:Lerp(boardShotPosition, boardLockBlend)
    local finalLookTarget = defaultLookTarget:Lerp(boardLookTarget, boardLockBlend)
    local finalFov = baseFieldOfView + ((boardTargetFov - baseFieldOfView) * boardLockBlend)

    camera.CFrame = CFrame.lookAt(finalPosition, finalLookTarget)
    camera.FieldOfView = finalFov
end

function OutdoorCameraAssist:start()
    if self._isBound then
        return
    end

    self._isBound = true
    RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
        self:_step(deltaTime)
    end)
end

return OutdoorCameraAssist
