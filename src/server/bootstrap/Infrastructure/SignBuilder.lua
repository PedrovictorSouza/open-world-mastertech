local SignBuilder = {}
SignBuilder.__index = SignBuilder

function SignBuilder.new(config, billboardScreenFactory)
    return setmetatable({
        _config = config,
        _billboardScreenFactory = billboardScreenFactory,
    }, SignBuilder)
end

function SignBuilder:ensure(worldFolder)
    local signModel = worldFolder:FindFirstChild("OutdoorExpedicao")
    if signModel then
        return signModel
    end

    signModel = Instance.new("Model")
    signModel.Name = "OutdoorExpedicao"
    signModel.Parent = worldFolder

    local board = Instance.new("Part")
    board.Name = "Board"
    board.Anchored = true
    board.CanCollide = false
    board.Material = Enum.Material.CorrodedMetal
    board.Color = Color3.fromRGB(27, 31, 36)
    board.Size = self._config.BillboardSize
    board.CFrame = CFrame.new(self._config.BillboardPosition) * CFrame.Angles(0, math.rad(180), 0)
    board.Parent = signModel

    local leftPost = Instance.new("Part")
    leftPost.Name = "LeftPost"
    leftPost.Anchored = true
    leftPost.Material = Enum.Material.Metal
    leftPost.Color = Color3.fromRGB(69, 74, 84)
    leftPost.Size = Vector3.new(2.5, 20, 2.5)
    leftPost.Position = board.Position + Vector3.new(-13, -17, 0)
    leftPost.Parent = signModel

    local rightPost = Instance.new("Part")
    rightPost.Name = "RightPost"
    rightPost.Anchored = true
    rightPost.Material = Enum.Material.Metal
    rightPost.Color = Color3.fromRGB(69, 74, 84)
    rightPost.Size = Vector3.new(2.5, 20, 2.5)
    rightPost.Position = board.Position + Vector3.new(13, -17, 0)
    rightPost.Parent = signModel

    local topBeam = Instance.new("Part")
    topBeam.Name = "TopBeam"
    topBeam.Anchored = true
    topBeam.Material = Enum.Material.Metal
    topBeam.Color = Color3.fromRGB(83, 90, 101)
    topBeam.Size = Vector3.new(30, 1.2, 1.2)
    topBeam.Position = board.Position + Vector3.new(0, -8, 0)
    topBeam.Parent = signModel

    local spotlightLeft = Instance.new("Part")
    spotlightLeft.Name = "SpotlightLeft"
    spotlightLeft.Anchored = true
    spotlightLeft.CanCollide = false
    spotlightLeft.Material = Enum.Material.Metal
    spotlightLeft.Color = Color3.fromRGB(44, 47, 54)
    spotlightLeft.Size = Vector3.new(1, 1, 1.5)
    spotlightLeft.Position = board.Position + Vector3.new(-9, -7.2, 1.25)
    spotlightLeft.Parent = signModel

    local spotLightLeftBeam = Instance.new("SpotLight")
    spotLightLeftBeam.Angle = 70
    spotLightLeftBeam.Brightness = 3
    spotLightLeftBeam.Range = 32
    spotLightLeftBeam.Face = Enum.NormalId.Back
    spotLightLeftBeam.Color = Color3.fromRGB(255, 235, 175)
    spotLightLeftBeam.Parent = spotlightLeft

    local spotlightRight = Instance.new("Part")
    spotlightRight.Name = "SpotlightRight"
    spotlightRight.Anchored = true
    spotlightRight.CanCollide = false
    spotlightRight.Material = Enum.Material.Metal
    spotlightRight.Color = Color3.fromRGB(44, 47, 54)
    spotlightRight.Size = Vector3.new(1, 1, 1.5)
    spotlightRight.Position = board.Position + Vector3.new(9, -7.2, 1.25)
    spotlightRight.Parent = signModel

    local spotLightRightBeam = Instance.new("SpotLight")
    spotLightRightBeam.Angle = 70
    spotLightRightBeam.Brightness = 3
    spotLightRightBeam.Range = 32
    spotLightRightBeam.Face = Enum.NormalId.Back
    spotLightRightBeam.Color = Color3.fromRGB(255, 235, 175)
    spotLightRightBeam.Parent = spotlightRight

    local frontLight = Instance.new("SurfaceLight")
    frontLight.Face = Enum.NormalId.Front
    frontLight.Brightness = self._config.BillboardBrightness
    frontLight.Range = 28
    frontLight.Angle = 110
    frontLight.Color = Color3.fromRGB(0, 255, 175)
    frontLight.Parent = board

    local backLight = Instance.new("SurfaceLight")
    backLight.Face = Enum.NormalId.Back
    backLight.Brightness = self._config.BillboardBrightness * 0.4
    backLight.Range = 10
    backLight.Angle = 65
    backLight.Color = Color3.fromRGB(0, 125, 255)
    backLight.Parent = board

    self._billboardScreenFactory:ensure(board, self._config)

    return signModel
end

return SignBuilder
