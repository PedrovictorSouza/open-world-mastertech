local CharacterSafetyGuard = {}
CharacterSafetyGuard.__index = CharacterSafetyGuard

function CharacterSafetyGuard.new()
    return setmetatable({}, CharacterSafetyGuard)
end

function CharacterSafetyGuard:activate(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return function() end
    end

    local isActive = true

    local originalWalkSpeed = humanoid.WalkSpeed
    local originalJumpPower = humanoid.JumpPower
    local originalAutoRotate = humanoid.AutoRotate
    local originalBreakJointsOnDeath = humanoid.BreakJointsOnDeath

    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    humanoid.AutoRotate = false
    humanoid.BreakJointsOnDeath = false

    character:SetAttribute("IntroProtected", true)

    local forceField = Instance.new("ForceField")
    forceField.Visible = false
    forceField.Parent = character

    local healthConnection = humanoid.HealthChanged:Connect(function()
        if not isActive then
            return
        end

        if humanoid.Health < humanoid.MaxHealth then
            humanoid.Health = humanoid.MaxHealth
        end
    end)

    return function()
        if not isActive then
            return
        end

        isActive = false

        if healthConnection then
            healthConnection:Disconnect()
            healthConnection = nil
        end

        if forceField.Parent then
            forceField:Destroy()
        end

        if humanoid.Parent then
            humanoid.WalkSpeed = originalWalkSpeed
            humanoid.JumpPower = originalJumpPower
            humanoid.AutoRotate = originalAutoRotate
            humanoid.BreakJointsOnDeath = originalBreakJointsOnDeath
            humanoid.Health = humanoid.MaxHealth
        end

        if character.Parent then
            character:SetAttribute("IntroProtected", false)
        end
    end
end

return CharacterSafetyGuard
