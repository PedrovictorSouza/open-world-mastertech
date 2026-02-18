local SpawnIntroService = {}
SpawnIntroService.__index = SpawnIntroService

function SpawnIntroService.new(introEvent, introConfig, introRules, worldConfig, armsPoseController, characterSafetyGuard)
    return setmetatable({
        _introEvent = introEvent,
        _introConfig = introConfig,
        _introRules = introRules,
        _worldConfig = worldConfig,
        _armsPoseController = armsPoseController,
        _characterSafetyGuard = characterSafetyGuard,
    }, SpawnIntroService)
end

function SpawnIntroService:play(player, character, baseSpawnPosition)
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")

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

    humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

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
        releaseArmsPose()
        releaseSafety()

        if character.Parent then
            character:SetAttribute("SpawnIntroCinematic", false)
        end
    end)

    return true
end

return SpawnIntroService
