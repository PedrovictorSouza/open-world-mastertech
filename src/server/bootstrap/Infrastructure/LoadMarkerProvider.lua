local LoadMarkerProvider = {}
LoadMarkerProvider.__index = LoadMarkerProvider

function LoadMarkerProvider.new(replicatedStorage, markerName)
    return setmetatable({
        _replicatedStorage = replicatedStorage,
        _markerName = markerName,
    }, LoadMarkerProvider)
end

function LoadMarkerProvider:markIfFirstLoad()
    local existingMarker = self._replicatedStorage:FindFirstChild(self._markerName)
    if existingMarker then
        return false
    end

    local marker = Instance.new("BoolValue")
    marker.Name = self._markerName
    marker.Value = true
    marker.Parent = self._replicatedStorage

    return true
end

return LoadMarkerProvider
