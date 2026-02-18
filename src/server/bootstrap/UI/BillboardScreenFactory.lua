local BillboardScreenFactory = {}
BillboardScreenFactory.__index = BillboardScreenFactory

function BillboardScreenFactory.new()
    return setmetatable({}, BillboardScreenFactory)
end

function BillboardScreenFactory:ensure(board, config)
    local surface = board:FindFirstChild("OutdoorScreen")
    if surface and surface:IsA("SurfaceGui") then
        return surface
    end

    surface = Instance.new("SurfaceGui")
    surface.Name = "OutdoorScreen"
    surface.Face = Enum.NormalId.Front
    surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surface.PixelsPerStud = 40
    surface.AlwaysOnTop = false
    surface.LightInfluence = 0
    surface.Parent = board

    local frame = Instance.new("Frame")
    frame.Name = "Container"
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = Color3.fromRGB(15, 20, 24)
    frame.Parent = surface

    local frameStroke = Instance.new("UIStroke")
    frameStroke.Thickness = 8
    frameStroke.Color = Color3.fromRGB(244, 197, 70)
    frameStroke.Parent = frame

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 108)
    titleBar.BackgroundColor3 = Color3.fromRGB(28, 35, 42)
    titleBar.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -40, 1, -8)
    title.Position = UDim2.fromOffset(20, 4)
    title.Font = Enum.Font.GothamBlack
    title.TextColor3 = Color3.fromRGB(250, 252, 239)
    title.TextWrapped = true
    title.TextSize = 60
    title.Text = config.SignText
    title.Parent = titleBar

    local body = Instance.new("TextLabel")
    body.Name = "Body"
    body.BackgroundTransparency = 1
    body.Size = UDim2.new(1, -56, 0, 230)
    body.Position = UDim2.fromOffset(28, 120)
    body.Font = Enum.Font.GothamBold
    body.TextColor3 = Color3.fromRGB(231, 242, 232)
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.TextSize = 36
    body.Text = config.MarketingText
    body.Parent = frame

    local websiteCard = Instance.new("Frame")
    websiteCard.Name = "WebsiteCard"
    websiteCard.Size = UDim2.new(1, -56, 0, 64)
    websiteCard.Position = UDim2.new(0, 28, 1, -158)
    websiteCard.BackgroundColor3 = Color3.fromRGB(32, 46, 58)
    websiteCard.Parent = frame

    local websiteStroke = Instance.new("UIStroke")
    websiteStroke.Thickness = 2
    websiteStroke.Color = Color3.fromRGB(118, 191, 255)
    websiteStroke.Parent = websiteCard

    local websiteLabel = Instance.new("TextLabel")
    websiteLabel.BackgroundTransparency = 1
    websiteLabel.Size = UDim2.fromScale(1, 1)
    websiteLabel.Font = Enum.Font.GothamBlack
    websiteLabel.TextColor3 = Color3.fromRGB(187, 235, 255)
    websiteLabel.TextSize = 32
    websiteLabel.Text = "ACESSE: roblox.mastertech.com.br"
    websiteLabel.Parent = websiteCard

    local ctaButton = Instance.new("Frame")
    ctaButton.Name = "CtaGroup"
    ctaButton.Size = UDim2.new(1, -56, 0, 70)
    ctaButton.Position = UDim2.new(0, 28, 1, -82)
    ctaButton.BackgroundColor3 = Color3.fromRGB(0, 164, 130)
    ctaButton.Parent = frame

    local ctaStroke = Instance.new("UIStroke")
    ctaStroke.Thickness = 3
    ctaStroke.Color = Color3.fromRGB(232, 255, 248)
    ctaStroke.Parent = ctaButton

    local iconBadge = Instance.new("Frame")
    iconBadge.Name = "IconBadge"
    iconBadge.Size = UDim2.fromOffset(58, 58)
    iconBadge.Position = UDim2.fromOffset(6, 6)
    iconBadge.BackgroundColor3 = Color3.fromRGB(8, 28, 23)
    iconBadge.Parent = ctaButton

    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 10)
    iconCorner.Parent = iconBadge

    local iconText = Instance.new("TextLabel")
    iconText.BackgroundTransparency = 1
    iconText.Size = UDim2.fromScale(1, 1)
    iconText.Font = Enum.Font.GothamBlack
    iconText.TextColor3 = Color3.fromRGB(198, 255, 235)
    iconText.TextSize = 40
    iconText.Text = ">"
    iconText.Parent = iconBadge

    local ctaLabel = Instance.new("TextLabel")
    ctaLabel.BackgroundTransparency = 1
    ctaLabel.Size = UDim2.new(1, -74, 1, 0)
    ctaLabel.Position = UDim2.fromOffset(74, 0)
    ctaLabel.Font = Enum.Font.GothamBlack
    ctaLabel.TextColor3 = Color3.fromRGB(5, 30, 24)
    ctaLabel.TextSize = 29
    ctaLabel.TextXAlignment = Enum.TextXAlignment.Left
    ctaLabel.Text = "CLIQUE AQUI: ABRIR GRUPO NO ROBLOX"
    ctaLabel.Parent = ctaButton

    return surface
end

return BillboardScreenFactory
