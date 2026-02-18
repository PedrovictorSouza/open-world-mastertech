local IntroRules = {}

local DEFAULT_DURATION_SECONDS = 4
local MIN_DURATION_SECONDS = 3
local MAX_DURATION_SECONDS = 5

local DEFAULT_BLEND_OUT_SECONDS = 0.55
local MIN_BLEND_OUT_SECONDS = 0.2
local MAX_BLEND_OUT_SECONDS = 1.2

local DEFAULT_HEIGHT_STUDS = 120
local MIN_HEIGHT_STUDS = 60

local DEFAULT_SUBJECT_Y_OFFSET = 2.8

function IntroRules.resolveDurationSeconds(introConfig)
    local duration = tonumber(introConfig.DurationSeconds) or DEFAULT_DURATION_SECONDS
    return math.clamp(duration, MIN_DURATION_SECONDS, MAX_DURATION_SECONDS)
end

function IntroRules.resolveBlendOutSeconds(introConfig)
    local blendOut = tonumber(introConfig.BlendOutSeconds) or DEFAULT_BLEND_OUT_SECONDS
    return math.clamp(blendOut, MIN_BLEND_OUT_SECONDS, MAX_BLEND_OUT_SECONDS)
end

function IntroRules.resolveSpawnHeightStuds(introConfig)
    local height = tonumber(introConfig.SpawnHeightStuds) or DEFAULT_HEIGHT_STUDS
    return math.max(height, MIN_HEIGHT_STUDS)
end

function IntroRules.resolveSubjectYOffset(introConfig)
    local offset = tonumber(introConfig.SubjectYOffset) or DEFAULT_SUBJECT_Y_OFFSET
    return math.max(offset, 1)
end

function IntroRules.createIntroSpawnCFrame(baseSpawnPosition, billboardPosition, spawnHeightStuds)
    local startPosition = baseSpawnPosition + Vector3.new(0, spawnHeightStuds, 0)
    local lookTarget = Vector3.new(billboardPosition.X, startPosition.Y - math.min(spawnHeightStuds * 0.22, 32), billboardPosition.Z)

    return CFrame.lookAt(startPosition, lookTarget)
end

function IntroRules.createClientPayload(introConfig)
    return {
        DurationSeconds = IntroRules.resolveDurationSeconds(introConfig),
        BlendOutSeconds = IntroRules.resolveBlendOutSeconds(introConfig),
        SubjectYOffset = IntroRules.resolveSubjectYOffset(introConfig),
        OrbitSeed = math.random(1000, 99999),
    }
end

return IntroRules
