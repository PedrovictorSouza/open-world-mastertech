local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local rootFolder = script.Parent

local ApplicationFolder = rootFolder:WaitForChild("Application")
local InfrastructureFolder = rootFolder:WaitForChild("Infrastructure")

local AfterFallIntroController = require(ApplicationFolder:WaitForChild("AfterFallIntroController"))
local SpawnIntroClientService = require(ApplicationFolder:WaitForChild("SpawnIntroClientService"))
local AudioDirector = require(InfrastructureFolder:WaitForChild("AudioDirector"))
local CinematicCameraController = require(InfrastructureFolder:WaitForChild("CinematicCameraController"))
local ControlLock = require(InfrastructureFolder:WaitForChild("ControlLock"))
local OutdoorCameraAssist = require(InfrastructureFolder:WaitForChild("OutdoorCameraAssist"))

local CompositionRoot = {}

function CompositionRoot.start()
    local localPlayer = Players.LocalPlayer
    local introEvent = ReplicatedStorage:WaitForChild("PlaySpawnIntroCinematic")
    local introAfterFallEvent = ReplicatedStorage:WaitForChild("Intro_AfterFall")
    local expeditionStartEvent = ReplicatedStorage:WaitForChild("Expedition_Start")
    local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
    local introDefaults = require(sharedFolder:WaitForChild("IntroConfig"))
    local introRules = require(sharedFolder:WaitForChild("IntroRules"))
    local audioConfig = require(sharedFolder:WaitForChild("AudioConfig"))

    local controlLock = ControlLock.new(localPlayer)
    local audioDirector = AudioDirector.new(audioConfig)
    local cinematicCameraController = CinematicCameraController.new()
    local outdoorCameraAssist = OutdoorCameraAssist.new(localPlayer)

    local afterFallIntroController = AfterFallIntroController.new(
        localPlayer,
        introAfterFallEvent,
        expeditionStartEvent,
        introRules,
        controlLock,
        audioDirector
    )

    local spawnIntroClientService = SpawnIntroClientService.new(
        localPlayer,
        introEvent,
        controlLock,
        cinematicCameraController,
        introDefaults
    )

    audioDirector:startBackgroundLoop()
    afterFallIntroController:start()
    spawnIntroClientService:start()
    outdoorCameraAssist:start()
end

return CompositionRoot
