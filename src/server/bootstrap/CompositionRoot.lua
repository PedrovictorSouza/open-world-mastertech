local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local rootFolder = script.Parent

local DomainFolder = rootFolder:WaitForChild("Domain")
local ApplicationFolder = rootFolder:WaitForChild("Application")
local InfrastructureFolder = rootFolder:WaitForChild("Infrastructure")
local UIFolder = rootFolder:WaitForChild("UI")

local WorldRules = require(DomainFolder:WaitForChild("WorldRules"))
local IntroRules = require(DomainFolder:WaitForChild("IntroRules"))
local BootstrapApplication = require(ApplicationFolder:WaitForChild("BootstrapApplication"))
local BoardInteractionService = require(ApplicationFolder:WaitForChild("BoardInteractionService"))
local PlayerSpawnService = require(ApplicationFolder:WaitForChild("PlayerSpawnService"))
local SpawnIntroService = require(ApplicationFolder:WaitForChild("SpawnIntroService"))
local ArmsPoseController = require(InfrastructureFolder:WaitForChild("ArmsPoseController"))
local CharacterSafetyGuard = require(InfrastructureFolder:WaitForChild("CharacterSafetyGuard"))
local WorldBootstrapService = require(ApplicationFolder:WaitForChild("WorldBootstrapService"))
local EnvironmentBuilder = require(InfrastructureFolder:WaitForChild("EnvironmentBuilder"))
local LoadMarkerProvider = require(InfrastructureFolder:WaitForChild("LoadMarkerProvider"))
local RemoteEventProvider = require(InfrastructureFolder:WaitForChild("RemoteEventProvider"))
local SignBuilder = require(InfrastructureFolder:WaitForChild("SignBuilder"))
local TerrainBuilder = require(InfrastructureFolder:WaitForChild("TerrainBuilder"))
local WorldFolderProvider = require(InfrastructureFolder:WaitForChild("WorldFolderProvider"))
local BillboardScreenFactory = require(UIFolder:WaitForChild("BillboardScreenFactory"))

local CompositionRoot = {}

function CompositionRoot.start()
    local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
    local config = require(sharedFolder:WaitForChild("WorldConfig"))
    local introConfig = require(sharedFolder:WaitForChild("IntroConfig"))

    local worldFolderProvider = WorldFolderProvider.new(Workspace, "ExpedicaoWorld")
    local remoteEventProvider = RemoteEventProvider.new(ReplicatedStorage)
    local loadMarkerProvider = LoadMarkerProvider.new(ReplicatedStorage, "ExpedicaoLoaded")
    local whisperSpawnMarkerProvider = LoadMarkerProvider.new(Workspace, "WhisperSpawn", true)

    local linkEvent = remoteEventProvider:ensure("OpenGroupLinkPrompt")
    local introEvent = remoteEventProvider:ensure("PlaySpawnIntroCinematic")
    local introAfterFallEvent = remoteEventProvider:ensure("Intro_AfterFall")
    local expeditionStartEvent = remoteEventProvider:ensure("Expedition_Start")

    local billboardScreenFactory = BillboardScreenFactory.new()
    local armsPoseController = ArmsPoseController.new(RunService)
    local characterSafetyGuard = CharacterSafetyGuard.new()

    local environmentBuilder = EnvironmentBuilder.new(Lighting, Workspace, config)
    local terrainBuilder = TerrainBuilder.new(config)
    local signBuilder = SignBuilder.new(config, billboardScreenFactory)
    local spawnIntroService = SpawnIntroService.new(
        introEvent,
        introAfterFallEvent,
        introConfig,
        IntroRules,
        config,
        armsPoseController,
        characterSafetyGuard,
        whisperSpawnMarkerProvider
    )

    local boardInteractionService = BoardInteractionService.new(
        linkEvent,
        expeditionStartEvent,
        config,
        WorldRules
    )
    local playerSpawnService = PlayerSpawnService.new(
        Players,
        worldFolderProvider,
        config,
        WorldRules,
        spawnIntroService
    )
    local worldBootstrapService = WorldBootstrapService.new(
        worldFolderProvider,
        environmentBuilder,
        terrainBuilder,
        signBuilder,
        boardInteractionService
    )

    local bootstrapApplication = BootstrapApplication.new(
        loadMarkerProvider,
        worldBootstrapService,
        playerSpawnService
    )

    bootstrapApplication:run()
end

return CompositionRoot
