local SpawnIntroClientService = {}
SpawnIntroClientService.__index = SpawnIntroClientService

function SpawnIntroClientService.new(localPlayer, introEvent, controlLock, cinematicCameraController, introDefaults)
    local defaults = introDefaults or {}

    return setmetatable({
        _localPlayer = localPlayer,
        _introEvent = introEvent,
        _controlLock = controlLock,
        _cinematicCameraController = cinematicCameraController,
        _introDefaults = defaults,
        _debugLogs = defaults.DebugLogs == true,
        _isPlaying = false,
        _playedByCharacter = {},
    }, SpawnIntroClientService)
end

function SpawnIntroClientService:_debugLog(...)
    if not self._debugLogs then
        return
    end

    warn("[SpawnIntroDebug]", ...)
end

function SpawnIntroClientService:start()
    self:_debugLog("SpawnIntroClientService started")

    self._introEvent.OnClientEvent:Connect(function(payload)
        local character = self._localPlayer.Character or self._localPlayer.CharacterAdded:Wait()
        payload = payload or {}
        if payload.DebugLogs == nil then
            payload.DebugLogs = self._debugLogs
        end

        self:_debugLog("RemoteEvent received", "character=", character.Name)
        self:_play(character, payload)
    end)

    self._localPlayer.CharacterAdded:Connect(function(character)
        self:_debugLog("CharacterAdded", character.Name)
        self:_bindCharacter(character)
    end)

    if self._localPlayer.Character then
        self:_bindCharacter(self._localPlayer.Character)
    end
end

function SpawnIntroClientService:_buildPayloadFromCharacter(character)
    local defaults = self._introDefaults

    return {
        DurationSeconds = character:GetAttribute("SpawnIntroDurationSeconds") or defaults.DurationSeconds,
        BlendOutSeconds = character:GetAttribute("SpawnIntroBlendOutSeconds") or defaults.BlendOutSeconds,
        SubjectYOffset = character:GetAttribute("SpawnIntroSubjectYOffset") or defaults.SubjectYOffset,
        OrbitSeed = character:GetAttribute("SpawnIntroOrbitSeed") or math.random(1000, 99999),
        DebugLogs = self._debugLogs,
    }
end

function SpawnIntroClientService:_bindCharacter(character)
    local function tryPlayFromAttribute()
        local hasCinematicFlag = character:GetAttribute("SpawnIntroCinematic")
        local isProtected = character:GetAttribute("IntroProtected")
        local isSkyValidated = character:GetAttribute("SkySpawnValidated")

        self:_debugLog(
            "Attribute trigger",
            "SpawnIntroCinematic=", tostring(hasCinematicFlag),
            "IntroProtected=", tostring(isProtected),
            "SkySpawnValidated=", tostring(isSkyValidated)
        )

        if not hasCinematicFlag and not isProtected then
            return
        end

        if isSkyValidated ~= true then
            self:_debugLog("Ignored attribute trigger: character is not in sky yet")
            return
        end

        local payload = self:_buildPayloadFromCharacter(character)
        self:_play(character, payload)
    end

    character:GetAttributeChangedSignal("SpawnIntroCinematic"):Connect(function()
        tryPlayFromAttribute()
    end)

    character:GetAttributeChangedSignal("IntroProtected"):Connect(function()
        tryPlayFromAttribute()
    end)

    character:GetAttributeChangedSignal("SkySpawnValidated"):Connect(function()
        tryPlayFromAttribute()
    end)

    task.defer(function()
        tryPlayFromAttribute()
    end)

    task.spawn(function()
        for _ = 1, 80 do
            if not character.Parent or self._playedByCharacter[character] then
                return
            end

            if character:GetAttribute("SpawnIntroCinematic") or character:GetAttribute("IntroProtected") then
                tryPlayFromAttribute()
            end

            task.wait(0.1)
        end
    end)
end

function SpawnIntroClientService:_play(character, payload)
    if self._isPlaying then
        self:_debugLog("Ignored play: intro already running")
        return
    end

    if self._playedByCharacter[character] then
        self:_debugLog("Ignored play: character already played", character.Name)
        return
    end

    if not character or not character.Parent then
        self:_debugLog("Ignored play: invalid character")
        return
    end

    if character:GetAttribute("SkySpawnValidated") ~= true then
        self:_debugLog("Ignored play: sky gate not validated")
        return
    end

    payload = payload or {}
    if payload.DebugLogs == nil then
        payload.DebugLogs = self._debugLogs
    end

    self._isPlaying = true

    self:_debugLog(
        "Play started",
        "Duration=", tostring(payload.DurationSeconds),
        "BlendOut=", tostring(payload.BlendOutSeconds),
        "SubjectYOffset=", tostring(payload.SubjectYOffset)
    )

    local ok, errorMessage = pcall(function()
        self._controlLock:lock()
        local hasPlayed = self._cinematicCameraController:play(character, payload)
        if hasPlayed then
            self._playedByCharacter[character] = true
            self:_debugLog("Play finished with camera movement")
        else
            self:_debugLog("Play finished without camera movement")
        end
    end)

    self._controlLock:unlock()
    self._isPlaying = false

    if not ok then
        warn("Failed to run spawn intro cinematic:", errorMessage)
        self:_debugLog("Play failed", errorMessage)
    end
end

return SpawnIntroClientService
