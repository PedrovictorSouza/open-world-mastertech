local function resolveIntroFolder()
    local introInScript = script:FindFirstChild("intro")
    if introInScript then
        return introInScript
    end

    local introInParent = script.Parent:FindFirstChild("intro")
    if introInParent then
        return introInParent
    end

    introInScript = script:WaitForChild("intro", 5)
    if introInScript then
        return introInScript
    end

    return script.Parent:WaitForChild("intro", 5)
end

local introFolder = resolveIntroFolder()
if not introFolder then
    warn("[SpawnIntroDebug] init.client failed", "intro folder not found")
    return
end

local CompositionRoot = require(introFolder:WaitForChild("CompositionRoot"))

warn("[SpawnIntroDebug] init.client started", script:GetFullName())

local ok, errorMessage = pcall(function()
    CompositionRoot.start()
end)

if not ok then
    warn("[SpawnIntroDebug] init.client failed", errorMessage)
end
