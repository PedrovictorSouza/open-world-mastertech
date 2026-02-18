local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AfterFallIntroController = {}
AfterFallIntroController.__index = AfterFallIntroController

local CAMERA_BLEND_SECONDS = 0.35
local DIALOG_CAMERA_FIELD_OF_VIEW = 54
local DIALOG_NEXT_SOUND_ID = "rbxassetid://115685733689380"
local DIALOG_POP_IN_SECONDS = 0.5
local DIALOG_TYPING_CHARACTERS_PER_SECOND = 30
local WHISPER_MOVE_TO_OUTDOOR_SECONDS = 1.2
local WHISPER_FLOAT_AMPLITUDE = 0.62
local WHISPER_FLOAT_SWAY = 0.24
local WHISPER_FLOAT_SPEED = 1.9

local function resolveOutdoorBoard()
    local worldFolder = Workspace:FindFirstChild("ExpedicaoWorld")
    if not worldFolder then
        return nil, nil
    end

    local outdoorModel = worldFolder:FindFirstChild("OutdoorExpedicao")
    if not outdoorModel or not outdoorModel:IsA("Model") then
        return nil, nil
    end

    local board = outdoorModel:FindFirstChild("Board")
    if board and board:IsA("BasePart") then
        return outdoorModel, board
    end

    return outdoorModel, nil
end

local function playUiAdvanceSound(sound)
    if not sound then
        return
    end

    if sound.IsPlaying then
        sound.TimePosition = 0
    else
        sound:Play()
    end
end

local function utf8Length(text)
    return utf8.len(text) or #text
end

local function utf8Slice(text, charCount)
    if charCount <= 0 then
        return ""
    end

    local endByte = utf8.offset(text, charCount + 1)
    if endByte then
        return string.sub(text, 1, endByte - 1)
    end

    return text
end

local function playTypewriterLine(bodyLabel, continueButton, line, charactersPerSecond, onAdvance)
    local waitSignal = Instance.new("BindableEvent")
    local shouldSkipTyping = false
    local isTyping = true

    local buttonConnection = continueButton.Activated:Connect(function()
        if isTyping then
            shouldSkipTyping = true
            return
        end

        if onAdvance then
            onAdvance()
        end

        waitSignal:Fire()
    end)

    bodyLabel.Text = ""

    local totalCharacters = utf8Length(line)
    local secondsPerCharacter = 1 / math.max(charactersPerSecond, 1)

    for characterIndex = 1, totalCharacters do
        if shouldSkipTyping then
            break
        end

        bodyLabel.Text = utf8Slice(line, characterIndex)
        task.wait(secondsPerCharacter)
    end

    if shouldSkipTyping then
        bodyLabel.Text = line
    end

    isTyping = false
    waitSignal.Event:Wait()

    buttonConnection:Disconnect()
    waitSignal:Destroy()
end

local function waitForCurrentCamera(timeoutSeconds)
    local camera = Workspace.CurrentCamera
    if camera then
        return camera
    end

    local startedAt = os.clock()
    repeat
        RunService.RenderStepped:Wait()
        camera = Workspace.CurrentCamera
    until camera or (os.clock() - startedAt) >= timeoutSeconds

    return camera
end

function AfterFallIntroController.new(localPlayer, introAfterFallEvent, expeditionStartEvent, introRules, controlLock, audioDirector)
    return setmetatable({
        _localPlayer = localPlayer,
        _introAfterFallEvent = introAfterFallEvent,
        _expeditionStartEvent = expeditionStartEvent,
        _introRules = introRules,
        _controlLock = controlLock,
        _audioDirector = audioDirector,
        _hasPlayed = false,
        _isRunning = false,
        _guideHighlight = nil,
        _guideBillboard = nil,
        _whisperVisual = nil,
        _whisperFloatConnection = nil,
        _whisperBasePosition = nil,
        _whisperFloatStartedAt = 0,
    }, AfterFallIntroController)
end

function AfterFallIntroController:start()
    self._introAfterFallEvent.OnClientEvent:Connect(function(payload)
        self:_run(payload)
    end)

    self._expeditionStartEvent.OnClientEvent:Connect(function()
        self._localPlayer:SetAttribute("ExpeditionStartedClient", true)
        self:_clearGuide()
    end)
end

function AfterFallIntroController:_run(payload)
    if self._isRunning or self._hasPlayed then
        return
    end

    self._isRunning = true

    local endConversation

    local ok, errorMessage = pcall(function()
        self:_spawnOrFocusWhisper(payload)
        endConversation = self:_startDialogueCinematic()
        self:_playDialogue()
    end)

    if endConversation then
        local cleanupOk, cleanupError = pcall(endConversation)
        if not cleanupOk then
            warn("AfterFall camera cleanup failed:", cleanupError)
        end
    end

    if ok then
        self:_moveWhisperToOutdoor()
        self:_guideToOutdoor()
    else
        warn("AfterFall intro failed:", errorMessage)
    end

    self._isRunning = false
    self._hasPlayed = true
end

function AfterFallIntroController:_resolveWhisperCFrame(payload)
    payload = payload or {}

    local whisperCFrame = payload.WhisperSpawnCFrame
    if typeof(whisperCFrame) == "CFrame" then
        return whisperCFrame
    end

    local whisperPosition = payload.WhisperSpawnPosition
    if typeof(whisperPosition) == "Vector3" then
        return CFrame.new(whisperPosition)
    end

    local character = self._localPlayer.Character
    if character then
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            return humanoidRootPart.CFrame * CFrame.new(0, 0, -10)
        end
    end

    return CFrame.new(0, 8, 0)
end

function AfterFallIntroController:_findExistingWhisper()
    local whisper = Workspace:FindFirstChild("Whisper")
    if not whisper then
        return nil
    end

    if whisper:IsA("BasePart") then
        return whisper
    end

    if whisper:IsA("Model") then
        return whisper
    end

    return nil
end

function AfterFallIntroController:_getWhisperCFrame()
    local whisper = self._whisperVisual
    if not whisper or not whisper.Parent then
        return nil
    end

    if whisper:IsA("BasePart") then
        return whisper.CFrame
    end

    if whisper:IsA("Model") then
        return whisper:GetPivot()
    end

    return nil
end

function AfterFallIntroController:_setWhisperCFrame(targetCFrame)
    local whisper = self._whisperVisual
    if not whisper or not whisper.Parent then
        return
    end

    if whisper:IsA("BasePart") then
        whisper.CFrame = targetCFrame
        return
    end

    if whisper:IsA("Model") then
        whisper:PivotTo(targetCFrame)
    end
end

function AfterFallIntroController:_removeWhisperNameLabel()
    local whisper = self._whisperVisual
    if not whisper or not whisper.Parent then
        return
    end

    if whisper:IsA("BillboardGui") and whisper.Name == "WhisperLabel" then
        whisper:Destroy()
        return
    end

    for _, descendant in ipairs(whisper:GetDescendants()) do
        if descendant:IsA("BillboardGui") and descendant.Name == "WhisperLabel" then
            descendant:Destroy()
        end
    end
end

function AfterFallIntroController:_stopWhisperFloating()
    if self._whisperFloatConnection then
        self._whisperFloatConnection:Disconnect()
        self._whisperFloatConnection = nil
    end
end

function AfterFallIntroController:_startWhisperFloating()
    self:_stopWhisperFloating()

    local whisperCFrame = self:_getWhisperCFrame()
    if not whisperCFrame then
        return
    end

    self._whisperBasePosition = whisperCFrame.Position
    self._whisperFloatStartedAt = os.clock()

    self._whisperFloatConnection = RunService.RenderStepped:Connect(function()
        local currentCFrame = self:_getWhisperCFrame()
        if not currentCFrame or not self._whisperBasePosition then
            return
        end

        local elapsed = os.clock() - self._whisperFloatStartedAt
        local verticalOffset = math.sin(elapsed * WHISPER_FLOAT_SPEED) * WHISPER_FLOAT_AMPLITUDE
        local lateralOffset = math.sin(elapsed * (WHISPER_FLOAT_SPEED * 0.62)) * WHISPER_FLOAT_SWAY

        local rotation = currentCFrame - currentCFrame.Position
        local targetPosition = self._whisperBasePosition + Vector3.new(lateralOffset, verticalOffset, 0)

        self:_setWhisperCFrame(CFrame.new(targetPosition) * rotation)
    end)
end

function AfterFallIntroController:_createWhisperParticles(parentAttachment)
    local ambience = Instance.new("ParticleEmitter")
    ambience.Name = "WhisperAmbience"
    ambience.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    ambience.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(145, 220, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(228, 245, 255)),
    })
    ambience.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.12),
        NumberSequenceKeypoint.new(0.65, 0.35),
        NumberSequenceKeypoint.new(1, 1),
    })
    ambience.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.24),
        NumberSequenceKeypoint.new(1, 0.06),
    })
    ambience.Lifetime = NumberRange.new(0.9, 1.4)
    ambience.Rate = 26
    ambience.Speed = NumberRange.new(0.2, 1.15)
    ambience.SpreadAngle = Vector2.new(32, 32)
    ambience.Acceleration = Vector3.new(0, 1.1, 0)
    ambience.LightEmission = 0.72
    ambience.Parent = parentAttachment

    local burst = Instance.new("ParticleEmitter")
    burst.Name = "WhisperBurst"
    burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    burst.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 235, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 252, 255)),
    })
    burst.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.08),
        NumberSequenceKeypoint.new(1, 1),
    })
    burst.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.32),
        NumberSequenceKeypoint.new(1, 0.02),
    })
    burst.Lifetime = NumberRange.new(0.35, 0.75)
    burst.Rate = 0
    burst.Speed = NumberRange.new(3, 8)
    burst.SpreadAngle = Vector2.new(360, 360)
    burst.LightEmission = 0.9
    burst.Parent = parentAttachment

    burst:Emit(48)

    return ambience
end

function AfterFallIntroController:_getWhisperPosition()
    local whisperCFrame = self:_getWhisperCFrame()
    if not whisperCFrame then
        return nil
    end

    return whisperCFrame.Position
end

function AfterFallIntroController:_lookAtWhisper(humanoidRootPart, whisperPosition)
    local flatTarget = Vector3.new(whisperPosition.X, humanoidRootPart.Position.Y, whisperPosition.Z)
    humanoidRootPart.CFrame = CFrame.lookAt(humanoidRootPart.Position, flatTarget)
end

function AfterFallIntroController:_lookAtPlayer(whisperPosition, playerPosition)
    local whisper = self._whisperVisual
    if not whisper or not whisper.Parent then
        return
    end

    local flatTarget = Vector3.new(playerPosition.X, whisperPosition.Y, playerPosition.Z)

    self:_setWhisperCFrame(CFrame.lookAt(whisperPosition, flatTarget))
end

function AfterFallIntroController:_alignActorsForDialogue(humanoidRootPart)
    local whisperPosition = self:_getWhisperPosition()
    if not whisperPosition then
        return
    end

    self:_lookAtWhisper(humanoidRootPart, whisperPosition)
    self:_lookAtPlayer(whisperPosition, humanoidRootPart.Position)
end

function AfterFallIntroController:_computeDialogueCameraCFrame(humanoidRootPart)
    local whisperPosition = self:_getWhisperPosition()
    if not whisperPosition then
        local fallbackSubject = humanoidRootPart.Position + Vector3.new(0, 2, 0)
        local fallbackPosition = fallbackSubject + Vector3.new(10, 2, 10)
        return CFrame.lookAt(fallbackPosition, fallbackSubject)
    end

    local playerPosition = humanoidRootPart.Position
    local betweenActors = whisperPosition - playerPosition
    local flatBetween = Vector3.new(betweenActors.X, 0, betweenActors.Z)

    if flatBetween.Magnitude < 0.01 then
        flatBetween = Vector3.new(0, 0, -1)
    end

    local forward = flatBetween.Unit
    local right = forward:Cross(Vector3.yAxis)
    if right.Magnitude < 0.01 then
        right = Vector3.new(1, 0, 0)
    else
        right = right.Unit
    end

    local actorDistance = flatBetween.Magnitude
    local stageDistance = math.clamp(actorDistance * 1.12, 8.8, 14)
    local sideDistance = stageDistance * 0.34
    local backDistance = stageDistance * 0.78

    local midpoint = (playerPosition + whisperPosition) * 0.5
    local cameraHeight = 2.05 + math.clamp(actorDistance * 0.08, 0, 0.7)

    local cameraPosition = midpoint + (right * sideDistance) - (forward * backDistance) + Vector3.new(0, cameraHeight, 0)
    -- Keep both actors above the bottom dialogue panel.
    local lookTarget = midpoint + Vector3.new(0, 1.7, 0)

    return CFrame.lookAt(cameraPosition, lookTarget)
end

function AfterFallIntroController:_blendCamera(camera, fromCFrame, toProvider, durationSeconds)
    local startedAt = os.clock()

    repeat
        local elapsed = os.clock() - startedAt
        local progress = math.clamp(elapsed / durationSeconds, 0, 1)
        local easedProgress = TweenService:GetValue(progress, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

        local targetCFrame = toProvider()
        camera.CFrame = fromCFrame:Lerp(targetCFrame, easedProgress)

        RunService.RenderStepped:Wait()
    until os.clock() - startedAt >= durationSeconds
end

function AfterFallIntroController:_startDialogueCinematic()
    local character = self._localPlayer.Character
    if not character then
        return function() end
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not humanoidRootPart then
        return function() end
    end

    local camera = waitForCurrentCamera(3)
    if not camera then
        return function() end
    end

    local originalWalkSpeed = humanoid.WalkSpeed
    local originalJumpPower = humanoid.JumpPower
    local originalAutoRotate = humanoid.AutoRotate

    local originalCameraSubject = camera.CameraSubject
    local originalFieldOfView = camera.FieldOfView

    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    humanoid.AutoRotate = false

    humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
    humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
    self:_alignActorsForDialogue(humanoidRootPart)

    if self._controlLock then
        self._controlLock:lock()
    end

    camera.CameraType = Enum.CameraType.Scriptable
    camera.FieldOfView = DIALOG_CAMERA_FIELD_OF_VIEW

    local fromCFrame = camera.CFrame
    self:_blendCamera(camera, fromCFrame, function()
        self:_alignActorsForDialogue(humanoidRootPart)
        return self:_computeDialogueCameraCFrame(humanoidRootPart)
    end, CAMERA_BLEND_SECONDS)

    local renderConnection = RunService.RenderStepped:Connect(function()
        if not character.Parent or not humanoidRootPart.Parent then
            return
        end

        humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
        humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
        self:_alignActorsForDialogue(humanoidRootPart)
        camera.CFrame = self:_computeDialogueCameraCFrame(humanoidRootPart)
        camera.FieldOfView = DIALOG_CAMERA_FIELD_OF_VIEW
    end)

    return function()
        if renderConnection then
            renderConnection:Disconnect()
            renderConnection = nil
        end

        if camera.Parent and character.Parent and humanoidRootPart.Parent then
            local blendFrom = camera.CFrame
            self:_blendCamera(camera, blendFrom, function()
                local subjectPosition = humanoidRootPart.Position + Vector3.new(0, 2.8, 0)
                local cameraPosition = subjectPosition - (humanoidRootPart.CFrame.LookVector * 9) + Vector3.new(0, 3.2, 0)
                return CFrame.lookAt(cameraPosition, subjectPosition)
            end, CAMERA_BLEND_SECONDS)
        end

        if humanoid.Parent then
            humanoid.WalkSpeed = originalWalkSpeed
            humanoid.JumpPower = originalJumpPower
            humanoid.AutoRotate = originalAutoRotate
        end

        if camera.Parent then
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = humanoid or originalCameraSubject
            camera.FieldOfView = originalFieldOfView
        end

        if self._controlLock then
            self._controlLock:unlock()
        end
    end
end

function AfterFallIntroController:_spawnOrFocusWhisper(payload)
    if self._audioDirector then
        self._audioDirector:playWhisperSummonSequence()
    end

    local existingWhisper = self:_findExistingWhisper()
    if existingWhisper then
        self._whisperVisual = existingWhisper
        self:_removeWhisperNameLabel()
        self:_startWhisperFloating()
        return
    end

    local whisperCFrame = self:_resolveWhisperCFrame(payload)

    local whisperPart = Instance.new("Part")
    whisperPart.Name = "WhisperClientVisual"
    whisperPart.Anchored = true
    whisperPart.CanCollide = false
    whisperPart.CanQuery = false
    whisperPart.CanTouch = false
    whisperPart.Material = Enum.Material.Neon
    whisperPart.Color = Color3.fromRGB(145, 220, 255)
    whisperPart.Shape = Enum.PartType.Ball
    whisperPart.Size = Vector3.new(0.25, 0.25, 0.25)
    whisperPart.Transparency = 1
    whisperPart.CFrame = whisperCFrame
    whisperPart.Parent = Workspace

    local attachment = Instance.new("Attachment")
    attachment.Name = "WhisperFxAttachment"
    attachment.Parent = whisperPart

    local ambienceEmitter = self:_createWhisperParticles(attachment)

    local glow = Instance.new("PointLight")
    glow.Name = "WhisperGlow"
    glow.Color = Color3.fromRGB(150, 225, 255)
    glow.Brightness = 0
    glow.Range = 0
    glow.Parent = whisperPart

    self._whisperVisual = whisperPart
    self:_removeWhisperNameLabel()

    local revealTween = TweenService:Create(whisperPart, TweenInfo.new(0.62, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 0.08,
        Size = Vector3.new(2.2, 2.2, 2.2),
    })
    local lightTween = TweenService:Create(glow, TweenInfo.new(0.62, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Brightness = 2.4,
        Range = 12,
    })

    revealTween:Play()
    lightTween:Play()
    revealTween.Completed:Wait()

    TweenService:Create(glow, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
        Brightness = 1.1,
        Range = 8.5,
    }):Play()

    ambienceEmitter.Rate = 16
    self:_startWhisperFloating()
end

function AfterFallIntroController:_playDialogue()
    local lines = self._introRules.getWhisperDialogueLines()
    if #lines == 0 then
        return
    end

    local playerGui = self._localPlayer:WaitForChild("PlayerGui")

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "WhisperDialogueGui"
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    local container = Instance.new("Frame")
    container.Size = UDim2.new(0, 760, 0, 210)
    container.AnchorPoint = Vector2.new(0.5, 1)
    container.Position = UDim2.new(0.5, 0, 1, -32)
    container.BackgroundColor3 = Color3.fromRGB(11, 18, 25)
    container.BorderSizePixel = 0
    container.Parent = screenGui

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(115, 196, 255)
    stroke.Parent = container

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -40, 0, 38)
    title.Position = UDim2.fromOffset(20, 16)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.GothamBold
    title.Text = "WHISPER"
    title.TextSize = 24
    title.TextColor3 = Color3.fromRGB(188, 230, 255)
    title.Parent = container

    local body = Instance.new("TextLabel")
    body.BackgroundTransparency = 1
    body.Size = UDim2.new(1, -40, 0, 92)
    body.Position = UDim2.fromOffset(20, 58)
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.Font = Enum.Font.Gotham
    body.TextSize = 22
    body.TextColor3 = Color3.fromRGB(236, 244, 250)
    body.Parent = container

    local continueButton = Instance.new("TextButton")
    continueButton.Size = UDim2.new(0, 170, 0, 44)
    continueButton.AnchorPoint = Vector2.new(1, 1)
    continueButton.Position = UDim2.new(1, -20, 1, -16)
    continueButton.BackgroundColor3 = Color3.fromRGB(0, 149, 116)
    continueButton.Font = Enum.Font.GothamBold
    continueButton.TextSize = 18
    continueButton.TextColor3 = Color3.fromRGB(241, 255, 250)
    continueButton.Parent = container

    local containerScale = Instance.new("UIScale")
    containerScale.Scale = 0
    containerScale.Parent = container

    local popInTween = TweenService:Create(
        containerScale,
        TweenInfo.new(DIALOG_POP_IN_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { Scale = 1 }
    )
    popInTween:Play()
    popInTween.Completed:Wait()

    local advanceSound = Instance.new("Sound")
    advanceSound.Name = "WhisperDialogueAdvance"
    advanceSound.SoundId = DIALOG_NEXT_SOUND_ID
    advanceSound.Volume = 0.7
    advanceSound.Parent = SoundService

    for lineIndex, line in ipairs(lines) do
        continueButton.Text = (lineIndex == #lines) and "Continuar" or "Proximo"
        playTypewriterLine(body, continueButton, line, DIALOG_TYPING_CHARACTERS_PER_SECOND, function()
            if lineIndex < #lines then
                playUiAdvanceSound(advanceSound)
            end
        end)
    end

    local popOutTween = TweenService:Create(
        containerScale,
        TweenInfo.new(DIALOG_POP_IN_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
        { Scale = 0 }
    )
    popOutTween:Play()
    popOutTween.Completed:Wait()

    advanceSound:Destroy()
    screenGui:Destroy()
end

function AfterFallIntroController:_computeOutdoorWhisperTargetCFrame(board)
    local boardCFrame = board.CFrame
    local sideOffset = boardCFrame.RightVector * ((board.Size.X * 0.5) + 6)
    local sidePosition = board.Position + sideOffset

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = self._whisperVisual and { self._whisperVisual } or {}

    local rayOrigin = sidePosition + Vector3.new(0, 90, 0)
    local rayDirection = Vector3.new(0, -220, 0)
    local groundRay = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

    local groundY = board.Position.Y - (board.Size.Y * 0.5) - 12
    if groundRay then
        groundY = groundRay.Position.Y
    end

    local targetPosition = Vector3.new(sidePosition.X, groundY + 4.2, sidePosition.Z)
    local lookTarget = board.Position + Vector3.new(0, board.Size.Y * 0.1, 0)
    return CFrame.lookAt(targetPosition, lookTarget)
end

function AfterFallIntroController:_moveWhisperToOutdoor()
    local whisperCFrame = self:_getWhisperCFrame()
    if not whisperCFrame then
        return
    end

    local _, board = resolveOutdoorBoard()
    if not board then
        return
    end

    local targetCFrame = self:_computeOutdoorWhisperTargetCFrame(board)

    self:_stopWhisperFloating()

    local cframeValue = Instance.new("CFrameValue")
    cframeValue.Value = whisperCFrame

    local moveConnection = cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
        self:_setWhisperCFrame(cframeValue.Value)
    end)

    local moveTween = TweenService:Create(
        cframeValue,
        TweenInfo.new(WHISPER_MOVE_TO_OUTDOOR_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        { Value = targetCFrame }
    )
    moveTween:Play()
    moveTween.Completed:Wait()

    moveConnection:Disconnect()
    cframeValue:Destroy()

    self:_startWhisperFloating()
end

function AfterFallIntroController:_guideToOutdoor()
    local outdoorModel, board = resolveOutdoorBoard()
    if not outdoorModel then
        return
    end

    self:_clearGuide()

    local highlight = Instance.new("Highlight")
    highlight.Name = "OutdoorGuideHighlight"
    highlight.Adornee = outdoorModel
    highlight.FillColor = Color3.fromRGB(52, 196, 255)
    highlight.FillTransparency = 0.84
    highlight.OutlineColor = Color3.fromRGB(214, 244, 255)
    highlight.OutlineTransparency = 0.12
    highlight.Parent = outdoorModel

    self._guideHighlight = highlight

    if board then
        local marker = Instance.new("BillboardGui")
        marker.Name = "OutdoorGuideMarker"
        marker.AlwaysOnTop = true
        marker.Size = UDim2.fromOffset(220, 78)
        marker.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
        marker.Parent = board

        local text = Instance.new("TextLabel")
        text.BackgroundTransparency = 1
        text.Size = UDim2.fromScale(1, 1)
        text.Font = Enum.Font.GothamBlack
        text.Text = "VA PARA O OUTDOOR"
        text.TextSize = 24
        text.TextColor3 = Color3.fromRGB(210, 245, 255)
        text.Parent = marker

        self._guideBillboard = marker
    end
end

function AfterFallIntroController:_clearGuide()
    if self._guideBillboard and self._guideBillboard.Parent then
        self._guideBillboard:Destroy()
    end
    self._guideBillboard = nil

    if self._guideHighlight and self._guideHighlight.Parent then
        self._guideHighlight:Destroy()
    end
    self._guideHighlight = nil
end

return AfterFallIntroController
