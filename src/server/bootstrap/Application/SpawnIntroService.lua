local SpawnIntroService = {}
SpawnIntroService.__index = SpawnIntroService

local LANDING_WAIT_TIMEOUT_SECONDS = 6
local SKY_VALIDATION_TIMEOUT_SECONDS = 1.25
local SKY_VALIDATION_MIN_HEIGHT_DELTA = 22

local function extractMarkerPositionAndCFrame(marker)
    if not marker then
        return nil, nil
    end

    if marker:IsA("Attachment") then
        local worldCFrame = marker.WorldCFrame
        return worldCFrame.Position, worldCFrame
    end

    if marker:IsA("BasePart") then
        return marker.Position, marker.CFrame
    end

    if marker:IsA("Model") then
        if marker.PrimaryPart then
            return marker.PrimaryPart.Position, marker.PrimaryPart.CFrame
        end

        local pivot = marker:GetPivot()
        return pivot.Position, pivot
    end

    return nil, nil
end

local function isCharacterLanded(character, humanoid)
    if not character.Parent or not humanoid or not humanoid.Parent then
        return false
    end

    if humanoid.FloorMaterial ~= Enum.Material.Air then
        return true
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart and math.abs(rootPart.AssemblyLinearVelocity.Y) < 0.6 then
        return true
    end

    return false
end

local function waitForLanding(character, humanoid, timeoutSeconds)
    if isCharacterLanded(character, humanoid) then
        return true
    end

    local resolved = false
    local landed = false

    local connection = humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running then
            landed = true
            resolved = true
        end
    end)

    local startedAt = os.clock()
    repeat
        if isCharacterLanded(character, humanoid) then
            landed = true
            break
        end

        task.wait(0.05)
    until resolved or (os.clock() - startedAt) >= timeoutSeconds

    connection:Disconnect()
    return landed
end

local function isCharacterInSky(character, spawnGroundY)
    if not character.Parent then
        return false
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return false
    end

    if humanoidRootPart.Position.Y <= (spawnGroundY + SKY_VALIDATION_MIN_HEIGHT_DELTA) then
        return false
    end

    -- FloorMaterial can stay stale for a few frames after server teleport.
    -- Height is the reliable gate for sky-spawn validation.
    return true
end

local function waitForSkyValidation(character, spawnGroundY, timeoutSeconds)
    if isCharacterInSky(character, spawnGroundY) then
        return true
    end

    local startedAt = os.clock()
    repeat
        if isCharacterInSky(character, spawnGroundY) then
            return true
        end

        task.wait(0.03)
    until (os.clock() - startedAt) >= timeoutSeconds

    return false
end

local function forceFreefall(humanoid)
    if humanoid and humanoid.Parent then
        humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
    end
end

function SpawnIntroService.new(
    introEvent,
    introAfterFallEvent,
    introConfig,
    introRules,
    worldConfig,
    armsPoseController,
    characterSafetyGuard,
    whisperSpawnMarkerProvider
)
    return setmetatable({
        _introEvent = introEvent,
        _introAfterFallEvent = introAfterFallEvent,
        _introConfig = introConfig,
        _introRules = introRules,
        _worldConfig = worldConfig,
        _armsPoseController = armsPoseController,
        _characterSafetyGuard = characterSafetyGuard,
        _whisperSpawnMarkerProvider = whisperSpawnMarkerProvider,
    }, SpawnIntroService)
end

function SpawnIntroService:RunAfterFall(player)
    if not player.Parent then
        return
    end

    if player:GetAttribute("IntroSeen") then
        return
    end

    local character = player.Character
    if not character or not character:GetAttribute("SkySpawnValidated") then
        return
    end

    local whisperSpawnMarker = self._whisperSpawnMarkerProvider:get()
    local whisperSpawnPosition, whisperSpawnCFrame = extractMarkerPositionAndCFrame(whisperSpawnMarker)

    self._introAfterFallEvent:FireClient(player, {
        WhisperSpawnPosition = whisperSpawnPosition,
        WhisperSpawnCFrame = whisperSpawnCFrame,
    })

    player:SetAttribute("IntroSeen", true)

    if character.Parent then
        character:SetAttribute("SpawnIntroLifecycleState", "after_fall_dispatched")
    end
end

function SpawnIntroService:play(player, character, baseSpawnPosition)
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        humanoid = character:WaitForChild("Humanoid", 5)
    end

    if not humanoidRootPart or not humanoid then
        return false
    end

    local durationSeconds = self._introRules.resolveDurationSeconds(self._introConfig)
    local blendOutSeconds = self._introRules.resolveBlendOutSeconds(self._introConfig)
    local spawnHeightStuds = self._introRules.resolveSpawnHeightStuds(self._introConfig)

    local introSpawnCFrame = self._introRules.createIntroSpawnCFrame(
        baseSpawnPosition,
        self._worldConfig.BillboardPosition,
        spawnHeightStuds
    )

    humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
    humanoidRootPart.CFrame = introSpawnCFrame
    character:SetAttribute("SpawnIntroLifecycleState", "waiting_for_sky")
    character:SetAttribute("SkySpawnActive", true)
    character:SetAttribute("SkySpawnValidated", false)
    forceFreefall(humanoid)
    task.defer(function()
        forceFreefall(humanoid)
    end)

    -- Lifecycle gate: if the character is still grounded, abort intro pipeline.
    if not waitForSkyValidation(character, baseSpawnPosition.Y, SKY_VALIDATION_TIMEOUT_SECONDS) then
        character:SetAttribute("SpawnIntroLifecycleState", "blocked_on_ground")
        character:SetAttribute("SkySpawnActive", false)
        return false
    end

    character:SetAttribute("SpawnIntroLifecycleState", "running")
    character:SetAttribute("SkySpawnValidated", true)

    forceFreefall(humanoid)

    local releaseArmsPose = self._armsPoseController:apply(character)
    local releaseSafety = self._characterSafetyGuard:activate(character)

    local payload = self._introRules.createClientPayload(self._introConfig)
    payload.BlendOutSeconds = blendOutSeconds

    character:SetAttribute("SpawnIntroDurationSeconds", payload.DurationSeconds)
    character:SetAttribute("SpawnIntroBlendOutSeconds", payload.BlendOutSeconds)
    character:SetAttribute("SpawnIntroSubjectYOffset", payload.SubjectYOffset)
    character:SetAttribute("SpawnIntroOrbitSeed", payload.OrbitSeed)
    character:SetAttribute("SpawnIntroCinematic", true)

    task.delay(0.1, function()
        if player.Parent then
            self._introEvent:FireClient(player, payload)
        end
    end)

    task.delay(durationSeconds + blendOutSeconds + 0.15, function()
        local humanoidAtEnd = character:FindFirstChildOfClass("Humanoid")

        releaseArmsPose()
        releaseSafety()

        if character.Parent then
            character:SetAttribute("SpawnIntroCinematic", false)
            character:SetAttribute("SkySpawnActive", false)
            character:SetAttribute("SpawnIntroLifecycleState", "finished")
        end

        if humanoidAtEnd and character.Parent then
            waitForLanding(character, humanoidAtEnd, LANDING_WAIT_TIMEOUT_SECONDS)
        end

        self:RunAfterFall(player)
    end)

    return true
end

return SpawnIntroService
