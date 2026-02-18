local WorldRules = {}

function WorldRules.createPlayerSpawnCFrame(spawnPosition, billboardPosition)
    local lookTarget = Vector3.new(billboardPosition.X, spawnPosition.Y, billboardPosition.Z)
    return CFrame.lookAt(spawnPosition, lookTarget)
end

function WorldRules.createGroupLinkPayload(config)
    return {
        GroupUrl = config.GroupUrl,
        WebsiteUrl = config.WebsiteUrl,
    }
end

return WorldRules
