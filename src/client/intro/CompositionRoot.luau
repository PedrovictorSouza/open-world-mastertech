local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local rootFolder = script.Parent

local ApplicationFolder = rootFolder:WaitForChild("Application")
local InfrastructureFolder = rootFolder:WaitForChild("Infrastructure")

local SpawnIntroClientService = require(ApplicationFolder:WaitForChild("SpawnIntroClientService"))
local CinematicCameraController = require(InfrastructureFolder:WaitForChild("CinematicCameraController"))
local ControlLock = require(InfrastructureFolder:WaitForChild("ControlLock"))

local CompositionRoot = {}

function CompositionRoot.start()
    local localPlayer = Players.LocalPlayer
    local introEvent = ReplicatedStorage:WaitForChild("PlaySpawnIntroCinematic")
    local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
    local introDefaults = require(sharedFolder:WaitForChild("IntroConfig"))

    local controlLock = ControlLock.new(localPlayer)
    local cinematicCameraController = CinematicCameraController.new()

    local spawnIntroClientService = SpawnIntroClientService.new(
        localPlayer,
        introEvent,
        controlLock,
        cinematicCameraController,
        introDefaults
    )

    spawnIntroClientService:start()
end

return CompositionRoot
