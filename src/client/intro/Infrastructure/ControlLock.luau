local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")

local CONTROL_LOCK_ACTION = "SpawnIntroControlLock"

local BLOCKED_ACTIONS = {
    Enum.PlayerActions.CharacterForward,
    Enum.PlayerActions.CharacterBackward,
    Enum.PlayerActions.CharacterLeft,
    Enum.PlayerActions.CharacterRight,
    Enum.PlayerActions.CharacterJump,
}

local function sinkAction()
    return Enum.ContextActionResult.Sink
end

local ControlLock = {}
ControlLock.__index = ControlLock

function ControlLock.new(localPlayer)
    return setmetatable({
        _localPlayer = localPlayer,
        _controls = nil,
        _isLocked = false,
    }, ControlLock)
end

function ControlLock:_setResetEnabled(isEnabled)
    task.spawn(function()
        for _ = 1, 8 do
            local ok = pcall(function()
                StarterGui:SetCore("ResetButtonCallback", isEnabled)
            end)

            if ok then
                break
            end

            task.wait(0.1)
        end
    end)
end

function ControlLock:_getControls()
    if self._controls then
        return self._controls
    end

    local playerScripts = self._localPlayer:WaitForChild("PlayerScripts", 5)
    if not playerScripts then
        return nil
    end

    local playerModule = playerScripts:WaitForChild("PlayerModule", 5)
    if not playerModule then
        return nil
    end

    local ok, module = pcall(require, playerModule)
    if not ok or type(module) ~= "table" or type(module.GetControls) ~= "function" then
        return nil
    end

    local controls = module:GetControls()
    self._controls = controls

    return controls
end

function ControlLock:lock()
    if self._isLocked then
        return
    end

    self._isLocked = true

    local controls = self:_getControls()
    if controls and type(controls.Disable) == "function" then
        controls:Disable()
    end

    ContextActionService:BindActionAtPriority(
        CONTROL_LOCK_ACTION,
        sinkAction,
        false,
        Enum.ContextActionPriority.High.Value,
        table.unpack(BLOCKED_ACTIONS)
    )

    self:_setResetEnabled(false)
end

function ControlLock:unlock()
    if not self._isLocked then
        return
    end

    self._isLocked = false

    ContextActionService:UnbindAction(CONTROL_LOCK_ACTION)

    local controls = self:_getControls()
    if controls and type(controls.Enable) == "function" then
        controls:Enable()
    end

    self:_setResetEnabled(true)
end

return ControlLock
