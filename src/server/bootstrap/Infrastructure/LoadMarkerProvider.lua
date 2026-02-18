local LoadMarkerProvider = {}
LoadMarkerProvider.__index = LoadMarkerProvider

function LoadMarkerProvider.new(container, markerName, recursiveSearch)
    return setmetatable({
        _container = container,
        _markerName = markerName,
        _recursiveSearch = recursiveSearch == true,
    }, LoadMarkerProvider)
end

function LoadMarkerProvider:markIfFirstLoad()
    local existingMarker = self:get()
    if existingMarker then
        return false
    end

    local marker = Instance.new("BoolValue")
    marker.Name = self._markerName
    marker.Value = true
    marker.Parent = self._container

    return true
end

function LoadMarkerProvider:get()
    return self._container:FindFirstChild(self._markerName, self._recursiveSearch)
end

return LoadMarkerProvider
