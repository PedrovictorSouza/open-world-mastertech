local ArmsPoseController = {}
ArmsPoseController.__index = ArmsPoseController

function ArmsPoseController.new(runService)
    return setmetatable({
        _runService = runService,
    }, ArmsPoseController)
end

local function findShoulderMotors(character)
    local leftShoulder
    local rightShoulder

    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("Motor6D") then
            if descendant.Name == "LeftShoulder" then
                leftShoulder = descendant
            elseif descendant.Name == "RightShoulder" then
                rightShoulder = descendant
            end
        end
    end

    return leftShoulder, rightShoulder
end

function ArmsPoseController:apply(character)
    local leftShoulder, rightShoulder = findShoulderMotors(character)
    if not leftShoulder or not rightShoulder then
        return function() end
    end

    local originalLeftTransform = leftShoulder.Transform
    local originalRightTransform = rightShoulder.Transform

    local isActive = true
    local elapsed = 0

    local connection = self._runService.Heartbeat:Connect(function(deltaTime)
        if not isActive then
            return
        end

        if not leftShoulder.Parent or not rightShoulder.Parent then
            return
        end

        elapsed += deltaTime
        local sway = math.sin(elapsed * 7) * 0.08
        local liftAngle = math.rad(-105)

        leftShoulder.Transform = CFrame.Angles(liftAngle + sway, 0, math.rad(-12))
        rightShoulder.Transform = CFrame.Angles(liftAngle - sway, 0, math.rad(12))
    end)

    return function()
        if not isActive then
            return
        end

        isActive = false

        if connection then
            connection:Disconnect()
            connection = nil
        end

        if leftShoulder.Parent then
            leftShoulder.Transform = originalLeftTransform
        end

        if rightShoulder.Parent then
            rightShoulder.Transform = originalRightTransform
        end
    end
end

return ArmsPoseController
