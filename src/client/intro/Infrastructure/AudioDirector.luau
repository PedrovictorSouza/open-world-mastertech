local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local AudioDirector = {}
AudioDirector.__index = AudioDirector

local SOUND_SEARCH_TIMEOUT_SECONDS = 8
local SOUND_SEARCH_RETRY_SECONDS = 0.12

local BACKGROUND_SOUND_NAMES = {
    "Soundtrack-background",
    "Soundtrack-background.mp3",
}

local WHISPER_INTRO_SOUND_NAMES = {
    "fairy-1",
    "fairy-1.wav",
}

local WHISPER_LOOP_SOUND_NAMES = {
    "fairy-loop",
    "fairy-loop.aiff",
}

local function normalizeName(name)
    local lowerName = string.lower(name or "")
    return string.gsub(lowerName, "%.%w+$", "")
end

local function buildNameLookup(names)
    local lookup = {}

    for _, name in ipairs(names) do
        lookup[normalizeName(name)] = true
    end

    return lookup
end

local function isSoundNameMatch(soundName, nameLookup)
    return nameLookup[normalizeName(soundName)] == true
end

function AudioDirector.new(audioConfig)
    return setmetatable({
        _cache = {},
        _backgroundStarted = false,
        _whisperTransitionId = 0,
        _whisperEndedConnection = nil,
        _audioConfig = audioConfig or {},
    }, AudioDirector)
end

function AudioDirector:_getSearchRoots()
    local roots = {
        SoundService,
        ReplicatedStorage,
        Workspace,
        game,
    }

    local mediaFolder = ReplicatedStorage:FindFirstChild("midia")
        or ReplicatedStorage:FindFirstChild("Midia")
        or ReplicatedStorage:FindFirstChild("Media")

    if mediaFolder then
        table.insert(roots, 2, mediaFolder)
    end

    return roots
end

function AudioDirector:_normalizeSoundId(rawSoundId)
    if typeof(rawSoundId) == "number" then
        rawSoundId = tostring(rawSoundId)
    end

    if typeof(rawSoundId) ~= "string" then
        return nil
    end

    local trimmed = string.gsub(rawSoundId, "^%s*(.-)%s*$", "%1")
    if trimmed == "" then
        return nil
    end

    if string.match(trimmed, "^rbxassetid://") then
        return trimmed
    end

    if string.match(trimmed, "^%d+$") then
        return "rbxassetid://" .. trimmed
    end

    return trimmed
end

function AudioDirector:_ensureConfiguredSound(cacheKey, names, configuredSoundId)
    local normalizedSoundId = self:_normalizeSoundId(configuredSoundId)
    if not normalizedSoundId then
        return nil
    end

    local sound = self:_findSound(cacheKey, names)
    if not sound then
        sound = Instance.new("Sound")
        sound.Name = names[1]
        sound.Parent = SoundService
        self._cache[cacheKey] = sound
    end

    if sound.SoundId ~= normalizedSoundId then
        sound.SoundId = normalizedSoundId
    end

    return sound
end

function AudioDirector:_findSound(cacheKey, names)
    local cached = self._cache[cacheKey]
    if cached and cached.Parent and cached:IsA("Sound") then
        return cached
    end

    local nameLookup = buildNameLookup(names)

    for _, root in ipairs(self:_getSearchRoots()) do
        for _, rawName in ipairs(names) do
            local directMatch = root:FindFirstChild(rawName, true)
            if directMatch and directMatch:IsA("Sound") then
                self._cache[cacheKey] = directMatch
                return directMatch
            end
        end

        for _, descendant in ipairs(root:GetDescendants()) do
            if descendant:IsA("Sound") and isSoundNameMatch(descendant.Name, nameLookup) then
                self._cache[cacheKey] = descendant
                return descendant
            end
        end
    end

    return nil
end

function AudioDirector:_waitForSound(cacheKey, names, timeoutSeconds)
    local startedAt = os.clock()

    repeat
        local sound = self:_findSound(cacheKey, names)
        if sound then
            return sound
        end

        task.wait(SOUND_SEARCH_RETRY_SECONDS)
    until os.clock() - startedAt >= timeoutSeconds

    return nil
end

function AudioDirector:_disconnectWhisperEnded()
    if self._whisperEndedConnection then
        self._whisperEndedConnection:Disconnect()
        self._whisperEndedConnection = nil
    end
end

function AudioDirector:startBackgroundLoop()
    if self._backgroundStarted then
        return
    end

    self._backgroundStarted = true

    task.spawn(function()
        local backgroundSound = self:_ensureConfiguredSound(
            "background_loop",
            BACKGROUND_SOUND_NAMES,
            self._audioConfig.BackgroundSoundId
        )
            or self:_waitForSound("background_loop", BACKGROUND_SOUND_NAMES, SOUND_SEARCH_TIMEOUT_SECONDS)
        if not backgroundSound then
            warn("Background soundtrack not found. Configure shared/AudioConfig.luau or add a Sound named Soundtrack-background.")
            return
        end

        backgroundSound.Looped = true
        if not backgroundSound.IsPlaying then
            backgroundSound:Play()
        end
    end)
end

function AudioDirector:playWhisperSummonSequence()
    self._whisperTransitionId += 1
    local transitionId = self._whisperTransitionId

    self:_disconnectWhisperEnded()

    task.spawn(function()
        local introSound = self:_ensureConfiguredSound(
            "whisper_intro",
            WHISPER_INTRO_SOUND_NAMES,
            self._audioConfig.WhisperIntroSoundId
        )
            or self:_waitForSound("whisper_intro", WHISPER_INTRO_SOUND_NAMES, SOUND_SEARCH_TIMEOUT_SECONDS)
        local loopSound = self:_ensureConfiguredSound(
            "whisper_loop",
            WHISPER_LOOP_SOUND_NAMES,
            self._audioConfig.WhisperLoopSoundId
        )
            or self:_waitForSound("whisper_loop", WHISPER_LOOP_SOUND_NAMES, SOUND_SEARCH_TIMEOUT_SECONDS)

        if transitionId ~= self._whisperTransitionId then
            return
        end

        local function startWhisperLoop()
            if transitionId ~= self._whisperTransitionId then
                return
            end

            if not loopSound then
                warn("Whisper loop sound not found. Configure shared/AudioConfig.luau or add a Sound named fairy-loop.")
                return
            end

            loopSound.Looped = true
            if not loopSound.IsPlaying then
                loopSound:Play()
            end
        end

        if loopSound and loopSound.IsPlaying then
            loopSound:Stop()
        end

        if not introSound then
            warn("Whisper intro sound not found. Configure shared/AudioConfig.luau or add a Sound named fairy-1.")
            startWhisperLoop()
            return
        end

        if introSound.IsPlaying then
            introSound:Stop()
        end

        introSound.Looped = false

        self._whisperEndedConnection = introSound.Ended:Connect(function()
            self:_disconnectWhisperEnded()
            startWhisperLoop()
        end)

        introSound:Play()

        if introSound.TimeLength <= 0 then
            task.delay(1.4, function()
                if transitionId ~= self._whisperTransitionId then
                    return
                end

                self:_disconnectWhisperEnded()
                startWhisperLoop()
            end)
        end
    end)
end

return AudioDirector
