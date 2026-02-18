local PlayerSpawnService = {}
PlayerSpawnService.__index = PlayerSpawnService

function PlayerSpawnService.new(players, worldFolderProvider, config, worldRules, spawnIntroService)
    return setmetatable({
        _players = players,
        _worldFolderProvider = worldFolderProvider,
        _config = config,
        _worldRules = worldRules,
        _spawnIntroService = spawnIntroService,
        _isBound = false,
        _hasPlayedIntro = {},
    }, PlayerSpawnService)
end

function PlayerSpawnService:bind()
    if self._isBound then
        return
    end

    self._isBound = true

    self._players.PlayerAdded:Connect(function(player)
        self:_bindPlayer(player)
    end)

    self._players.PlayerRemoving:Connect(function(player)
        self._hasPlayedIntro[player] = nil
    end)

    for _, player in ipairs(self._players:GetPlayers()) do
        self:_bindPlayer(player)
    end
end

function PlayerSpawnService:_bindPlayer(player)
    player.CharacterAdded:Connect(function(character)
        self:_positionCharacter(player, character)
    end)

    if player.Character then
        self:_positionCharacter(player, player.Character)
    end
end

function PlayerSpawnService:_positionCharacter(player, character)
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
    local spawnPart = self._worldFolderProvider:find("SpawnLocation")

    if not humanoidRootPart or not spawnPart or not spawnPart:IsA("BasePart") then
        return
    end

    local spawnPosition = spawnPart.Position + Vector3.new(0, 4, 0)

    if not self._hasPlayedIntro[player] then
        local hasStartedIntro = self._spawnIntroService:play(player, character, spawnPosition)
        if hasStartedIntro then
            self._hasPlayedIntro[player] = true
            return
        end
    end

    local spawnCFrame = self._worldRules.createPlayerSpawnCFrame(spawnPosition, self._config.BillboardPosition)
    humanoidRootPart.CFrame = spawnCFrame
end

return PlayerSpawnService
