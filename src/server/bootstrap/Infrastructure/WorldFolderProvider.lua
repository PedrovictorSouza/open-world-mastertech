local WorldFolderProvider = {}
WorldFolderProvider.__index = WorldFolderProvider

function WorldFolderProvider.new(workspaceService, folderName)
    return setmetatable({
        _workspace = workspaceService,
        _folderName = folderName,
    }, WorldFolderProvider)
end

function WorldFolderProvider:ensure()
    local worldFolder = self._workspace:FindFirstChild(self._folderName)
    if worldFolder then
        return worldFolder
    end

    worldFolder = Instance.new("Folder")
    worldFolder.Name = self._folderName
    worldFolder.Parent = self._workspace

    return worldFolder
end

function WorldFolderProvider:find(childName)
    return self:ensure():FindFirstChild(childName)
end

return WorldFolderProvider
