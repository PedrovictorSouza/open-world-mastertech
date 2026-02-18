local WorldBootstrapService = {}
WorldBootstrapService.__index = WorldBootstrapService

function WorldBootstrapService.new(worldFolderProvider, environmentBuilder, terrainBuilder, signBuilder, boardInteractionService)
    return setmetatable({
        _worldFolderProvider = worldFolderProvider,
        _environmentBuilder = environmentBuilder,
        _terrainBuilder = terrainBuilder,
        _signBuilder = signBuilder,
        _boardInteractionService = boardInteractionService,
    }, WorldBootstrapService)
end

function WorldBootstrapService:bootstrap()
    local worldFolder = self._worldFolderProvider:ensure()

    self._environmentBuilder:apply()
    self._terrainBuilder:build(worldFolder)

    local signModel = self._signBuilder:ensure(worldFolder)
    self._boardInteractionService:bind(signModel)

    task.spawn(function()
        self:_playIntroAnimation(signModel)
    end)
end

function WorldBootstrapService:_playIntroAnimation(signModel)
    local board = signModel:FindFirstChild("Board")
    if not board then
        return
    end

    board.Transparency = 0
end

return WorldBootstrapService
