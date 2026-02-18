local EnvironmentBuilder = {}
EnvironmentBuilder.__index = EnvironmentBuilder

function EnvironmentBuilder.new(lightingService, workspaceService, config)
    return setmetatable({
        _lighting = lightingService,
        _workspace = workspaceService,
        _config = config,
    }, EnvironmentBuilder)
end

function EnvironmentBuilder:apply()
    self._lighting.Brightness = 2.5
    self._lighting.ClockTime = 17.5
    self._lighting.OutdoorAmbient = Color3.fromRGB(120, 140, 165)
    self._lighting.Ambient = Color3.fromRGB(95, 105, 130)

    if not self._lighting:FindFirstChildOfClass("Atmosphere") then
        local atmosphere = Instance.new("Atmosphere")
        atmosphere.Density = 0.35
        atmosphere.Offset = 0.1
        atmosphere.Color = Color3.fromRGB(199, 221, 255)
        atmosphere.Decay = Color3.fromRGB(95, 125, 170)
        atmosphere.Glare = 0.15
        atmosphere.Haze = 0.6
        atmosphere.Parent = self._lighting
    end

    if self._config.RemoveDefaultBaseplate then
        local baseplate = self._workspace:FindFirstChild("Baseplate")
        if baseplate and baseplate:IsA("BasePart") then
            baseplate:Destroy()
        end
    end
end

return EnvironmentBuilder
