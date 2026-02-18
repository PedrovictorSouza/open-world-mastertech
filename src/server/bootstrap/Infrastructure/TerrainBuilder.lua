local TerrainBuilder = {}
TerrainBuilder.__index = TerrainBuilder

function TerrainBuilder.new(config)
    return setmetatable({
        _config = config,
    }, TerrainBuilder)
end

function TerrainBuilder:build(worldFolder)
    self:_ensureGround(worldFolder)
    self:_ensureSpawn(worldFolder)
end

function TerrainBuilder:_ensureGround(worldFolder)
    local ground = worldFolder:FindFirstChild("Ground")
    if ground then
        return ground
    end

    ground = Instance.new("Part")
    ground.Name = "Ground"
    ground.Anchored = true
    ground.Material = Enum.Material.Grass
    ground.Color = Color3.fromRGB(79, 140, 76)
    ground.Size = self._config.GroundSize
    ground.Position = self._config.GroundPosition
    ground.TopSurface = Enum.SurfaceType.Smooth
    ground.BottomSurface = Enum.SurfaceType.Smooth
    ground.Parent = worldFolder

    return ground
end

function TerrainBuilder:_ensureSpawn(worldFolder)
    local spawnPart = worldFolder:FindFirstChild("SpawnLocation")
    if spawnPart then
        return spawnPart
    end

    spawnPart = Instance.new("SpawnLocation")
    spawnPart.Name = "SpawnLocation"
    spawnPart.Anchored = true
    spawnPart.Neutral = true
    spawnPart.Material = Enum.Material.Neon
    spawnPart.Color = Color3.fromRGB(66, 167, 255)
    spawnPart.Size = Vector3.new(8, 1, 8)
    spawnPart.Position = self._config.SpawnPosition
    spawnPart.Parent = worldFolder

    return spawnPart
end

return TerrainBuilder
