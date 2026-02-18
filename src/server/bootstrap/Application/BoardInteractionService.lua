local BoardInteractionService = {}
BoardInteractionService.__index = BoardInteractionService

function BoardInteractionService.new(linkEvent, config, worldRules)
    return setmetatable({
        _linkEvent = linkEvent,
        _config = config,
        _worldRules = worldRules,
    }, BoardInteractionService)
end

function BoardInteractionService:bind(signModel)
    local board = signModel:FindFirstChild("Board")
    if not board or not board:IsA("BasePart") then
        return
    end

    local clickDetector = board:FindFirstChild("GroupLinkClick")
    if not clickDetector then
        clickDetector = Instance.new("ClickDetector")
        clickDetector.Name = "GroupLinkClick"
        clickDetector.MaxActivationDistance = 32
        clickDetector.Parent = board
    end

    if clickDetector:GetAttribute("Bound") then
        return
    end

    clickDetector.MouseClick:Connect(function(player)
        local payload = self._worldRules.createGroupLinkPayload(self._config)
        self._linkEvent:FireClient(player, payload)
    end)

    clickDetector:SetAttribute("Bound", true)
end

return BoardInteractionService
