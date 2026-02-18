local RemoteEventProvider = {}
RemoteEventProvider.__index = RemoteEventProvider

function RemoteEventProvider.new(replicatedStorage)
    return setmetatable({
        _replicatedStorage = replicatedStorage,
    }, RemoteEventProvider)
end

function RemoteEventProvider:ensure(eventName)
    local remoteEvent = self._replicatedStorage:FindFirstChild(eventName)
    if remoteEvent and remoteEvent:IsA("RemoteEvent") then
        return remoteEvent
    end

    remoteEvent = Instance.new("RemoteEvent")
    remoteEvent.Name = eventName
    remoteEvent.Parent = self._replicatedStorage

    return remoteEvent
end

return RemoteEventProvider
