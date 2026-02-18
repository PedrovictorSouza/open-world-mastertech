local BootstrapApplication = {}
BootstrapApplication.__index = BootstrapApplication

function BootstrapApplication.new(loadMarkerProvider, worldBootstrapService, playerSpawnService)
    return setmetatable({
        _loadMarkerProvider = loadMarkerProvider,
        _worldBootstrapService = worldBootstrapService,
        _playerSpawnService = playerSpawnService,
    }, BootstrapApplication)
end

function BootstrapApplication:run()
    if self._loadMarkerProvider:markIfFirstLoad() then
        self._worldBootstrapService:bootstrap()
    end

    self._playerSpawnService:bind()
end

return BootstrapApplication
