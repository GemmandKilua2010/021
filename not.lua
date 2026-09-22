local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local NotificationSystem = {}
NotificationSystem.__index = NotificationSystem

local CONFIG = {
	MaxWidth = 420,
	MinWidth = 200,

	Padding = 14,
	IconSize = 40,
	TextIconGap = 12,
	VerticalSpacing = 4,
	QueueGap = 8,

	CornerRadius = UDim.new(0, 12),

	BackgroundColor = Color3.fromRGB(30, 30, 35),
	BackgroundTransp = 0.05,

	StrokeColor = Color3.fromRGB(60, 60, 68),

	TitleColor = Color3.fromRGB(255, 255, 255),
	TextColor = Color3.fromRGB(200, 200, 205),

	TitleFont = Enum.Font.GothamBold,
	TextFont = Enum.Font.Gotham,

	TitleSize = 16,
	TextSize = 14,

	DefaultDuration = 4,
	MaxVisible = 5,

	AnimTime = 0.35,
	CloseAnimTime = 0.28,

	AnimStyle = Enum.EasingStyle.Quint,
	AnimDirIn = Enum.EasingDirection.Out,
	AnimDirOut = Enum.EasingDirection.In,

	ScreenPaddingRightDesktop = 12,
	ScreenPaddingRightMobile = 10,

	ScreenPaddingBottomDesktop = 45,
	ScreenPaddingBottomMobile = 35,
}

local Global = getgenv()
local Shared = Global.SpecterX_NotificationSystem

if not Shared then
	Shared = {
		ActiveNotifications = {},
		Queue = {},

		ScreenGui = nil,
		Container = nil,
		UIScale = nil,

		OrderCounter = 0,

		Processing = false,
		Initialized = false,
	}

	Global.SpecterX_NotificationSystem = Shared
end

local function isMobile()
	return UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
end

local function isTenFoot()
	return GuiService:IsTenFootInterface()
end

local function getScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return 1
	end

	local shortSide = math.min(camera.ViewportSize.X, camera.ViewportSize.Y)

	if isTenFoot() then
		return 1.25
	end

	if isMobile() then
		return math.clamp(shortSide / 400, 0.85, 1.15)
	end

	return 1
end

local function updateContainerBounds()
	local container = Shared.Container
	if not container or not container.Parent then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local paddingRight = isMobile() and CONFIG.ScreenPaddingRightMobile or CONFIG.ScreenPaddingRightDesktop
	local paddingBottom = isMobile() and CONFIG.ScreenPaddingBottomMobile or CONFIG.ScreenPaddingBottomDesktop

	local maxAllowedWidth = math.max(camera.ViewportSize.X - (paddingRight * 2), 100)
	local width = math.min(CONFIG.MaxWidth * getScale(), maxAllowedWidth)

	container.AnchorPoint = Vector2.new(1, 1)
	container.Position = UDim2.new(1, -paddingRight, 1, -paddingBottom)
	container.Size = UDim2.new(0, width, 1, -(paddingBottom * 2))
end

local function ensureGui()
	if Shared.ScreenGui and Shared.ScreenGui.Parent then
		Shared.Container = Shared.ScreenGui:FindFirstChild("Container")
		Shared.UIScale = Shared.ScreenGui:FindFirstChildOfClass("UIScale")

		if Shared.Container then
			updateContainerBounds()
			return
		end
	end

	local existing = CoreGui:FindFirstChild("NotificationSystemGui")
		or playerGui:FindFirstChild("NotificationSystemGui")

	if existing then
		local existingContainer = existing:FindFirstChild("Container")

		if existingContainer then
			Shared.ScreenGui = existing
			Shared.Container = existingContainer
			Shared.UIScale = existing:FindFirstChildOfClass("UIScale")

			if not Shared.UIScale then
				Shared.UIScale = Instance.new("UIScale")
				Shared.UIScale.Scale = getScale()
				Shared.UIScale.Parent = existing
			end

			updateContainerBounds()
			return
		end

		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "NotificationSystemGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 1000

	local ok = pcall(function()
		screenGui.Parent = CoreGui
	end)

	if not ok or screenGui.Parent ~= CoreGui then
		screenGui.Parent = playerGui
	end

	Shared.ScreenGui = screenGui

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = getScale()
	uiScale.Parent = screenGui
	Shared.UIScale = uiScale

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.BackgroundTransparency = 1
	container.ClipsDescendants = false
	container.Parent = screenGui
	Shared.Container = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, CONFIG.QueueGap)
	layout.Parent = container

	updateContainerBounds()

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if Shared.UIScale then
				Shared.UIScale.Scale = getScale()
			end
			updateContainerBounds()
		end)
	end
end

local function calculateSize(title, text, hasIcon)
	local scale = getScale()
	local container = Shared.Container

	local maxWidth = (container and container.AbsoluteSize.X > 0)
		and container.AbsoluteSize.X
		or (CONFIG.MaxWidth * scale)

	local minWidth = math.min(CONFIG.MinWidth * scale, maxWidth)
	local padding = CONFIG.Padding * scale
	local iconSize = hasIcon and (CONFIG.IconSize * scale) or 0
	local gap = hasIcon and (CONFIG.TextIconGap * scale) or 0

	local availableTextWidth = math.max(maxWidth - (padding * 2) - iconSize - gap, 80)

	local titleBounds = TextService:GetTextSize(
		title or "", CONFIG.TitleSize * scale, CONFIG.TitleFont,
		Vector2.new(availableTextWidth, math.huge)
	)

	local textBounds = TextService:GetTextSize(
		text or "", CONFIG.TextSize * scale, CONFIG.TextFont,
		Vector2.new(availableTextWidth, math.huge)
	)

	local contentWidth = math.max(titleBounds.X, textBounds.X) + iconSize + gap + (padding * 2)
	local finalWidth = math.clamp(contentWidth, minWidth, maxWidth)
	local textBlockHeight = titleBounds.Y + CONFIG.VerticalSpacing * scale + textBounds.Y
	local finalHeight = math.max(textBlockHeight, iconSize) + (padding * 2)

	return finalWidth, finalHeight
end

local function buildNotification(data)
	local scale = getScale()
	local title = data.Title or "Notificação"
	local text = data.Text or ""
	local icon = data.Icon
	local hasIcon = icon ~= nil and icon ~= ""

	local width, height = calculateSize(title, text, hasIcon)
	local padding = CONFIG.Padding * scale

	local slot = Instance.new("Frame")
	slot.Name = "Slot"
	slot.BackgroundTransparency = 1
	slot.ClipsDescendants = true
	slot.Size = UDim2.new(0, width, 0, height)

	Shared.OrderCounter = Shared.OrderCounter - 1
	slot.LayoutOrder = Shared.OrderCounter

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.new(1, 0, 1, 0)
	card.BackgroundColor3 = CONFIG.BackgroundColor
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Parent = slot

	local corner = Instance.new("UICorner")
	corner.CornerRadius = CONFIG.CornerRadius
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = CONFIG.StrokeColor
	stroke.Thickness = 1
	stroke.Transparency = 1
	stroke.Parent = card

	local iconImage

	if hasIcon then
		iconImage = Instance.new("ImageLabel")
		iconImage.BackgroundTransparency = 1
		iconImage.Image = icon
		iconImage.Size = UDim2.new(0, CONFIG.IconSize * scale, 0, CONFIG.IconSize * scale)
		iconImage.Position = UDim2.new(0, padding, 0.5, 0)
		iconImage.AnchorPoint = Vector2.new(0, 0.5)
		iconImage.ImageTransparency = 1
		iconImage.Parent = card
	end

	local textOffsetX = padding + (hasIcon and (CONFIG.IconSize * scale + CONFIG.TextIconGap * scale) or 0)
	local textWidth = width - textOffsetX - padding

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = CONFIG.TitleFont
	titleLabel.TextSize = CONFIG.TitleSize * scale
	titleLabel.TextColor3 = CONFIG.TitleColor
	titleLabel.TextTransparency = 1
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextYAlignment = Enum.TextYAlignment.Top
	titleLabel.TextWrapped = true
	titleLabel.Text = title
	titleLabel.Position = UDim2.new(0, textOffsetX, 0, padding)
	titleLabel.Size = UDim2.new(0, textWidth, 0, 0)
	titleLabel.AutomaticSize = Enum.AutomaticSize.Y
	titleLabel.Parent = card

	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Font = CONFIG.TextFont
	textLabel.TextSize = CONFIG.TextSize * scale
	textLabel.TextColor3 = CONFIG.TextColor
	textLabel.TextTransparency = 1
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.TextWrapped = true
	textLabel.Text = text
	textLabel.Position = UDim2.new(0, textOffsetX, 0, padding + CONFIG.TitleSize * scale + CONFIG.VerticalSpacing * scale)
	textLabel.Size = UDim2.new(0, textWidth, 0, 0)
	textLabel.AutomaticSize = Enum.AutomaticSize.Y
	textLabel.Parent = card

	return slot, card, {
		icon = iconImage,
		title = titleLabel,
		text = textLabel,
		stroke = stroke,
	}
end

local function animateIn(slot, card, parts)
	local tweenInfo = TweenInfo.new(CONFIG.AnimTime, CONFIG.AnimStyle, CONFIG.AnimDirIn)

	card.Position = UDim2.new(1, 60, 0, 0)
	slot.Parent = Shared.Container

	TweenService:Create(card, tweenInfo, {
		BackgroundTransparency = CONFIG.BackgroundTransp,
		Position = UDim2.new(0, 0, 0, 0),
	}):Play()

	TweenService:Create(parts.stroke, tweenInfo, { Transparency = 0.4 }):Play()
	TweenService:Create(parts.title, tweenInfo, { TextTransparency = 0 }):Play()
	TweenService:Create(parts.text, tweenInfo, { TextTransparency = 0.1 }):Play()

	if parts.icon then
		TweenService:Create(parts.icon, tweenInfo, { ImageTransparency = 0 }):Play()
	end
end

local function animateOut(slot, card, parts, onComplete)
	local tweenInfo = TweenInfo.new(CONFIG.CloseAnimTime, CONFIG.AnimStyle, CONFIG.AnimDirOut)
	local collapseInfo = TweenInfo.new(CONFIG.CloseAnimTime, Enum.EasingStyle.Quad, CONFIG.AnimDirOut)

	TweenService:Create(card, tweenInfo, {
		BackgroundTransparency = 1,
		Position = UDim2.new(1, 60, 0, 0),
	}):Play()

	TweenService:Create(parts.stroke, tweenInfo, { Transparency = 1 }):Play()
	TweenService:Create(parts.title, tweenInfo, { TextTransparency = 1 }):Play()
	TweenService:Create(parts.text, tweenInfo, { TextTransparency = 1 }):Play()

	if parts.icon then
		TweenService:Create(parts.icon, tweenInfo, { ImageTransparency = 1 }):Play()
	end

	task.delay(CONFIG.CloseAnimTime * 0.4, function()
		if not slot or not slot.Parent then
			if onComplete then
				onComplete()
			end
			return
		end

		local collapseTween = TweenService:Create(slot, collapseInfo, {
			Size = UDim2.new(slot.Size.X.Scale, slot.Size.X.Offset, 0, 0),
		})

		collapseTween.Completed:Connect(function()
			if slot then
				slot:Destroy()
			end
			if onComplete then
				onComplete()
			end
		end)

		collapseTween:Play()
	end)
end

local function removeActive(slot)
	for i, activeSlot in ipairs(Shared.ActiveNotifications) do
		if activeSlot == slot then
			table.remove(Shared.ActiveNotifications, i)
			break
		end
	end
end

local function processQueue()
	if Shared.Processing then
		return
	end

	Shared.Processing = true

	while #Shared.ActiveNotifications < CONFIG.MaxVisible and #Shared.Queue > 0 do
		local nextData = table.remove(Shared.Queue, 1)
		if not nextData then
			break
		end

		ensureGui()

		if not Shared.Container or not Shared.Container.Parent then
			break
		end

		local slot, card, parts = buildNotification(nextData)
		table.insert(Shared.ActiveNotifications, slot)
		animateIn(slot, card, parts)

		local duration = nextData.Duration or CONFIG.DefaultDuration

		task.delay(duration, function()
			if not slot or not slot.Parent then
				removeActive(slot)
				task.defer(processQueue)
				return
			end

			animateOut(slot, card, parts, function()
				removeActive(slot)
				task.defer(processQueue)
			end)
		end)
	end

	Shared.Processing = false
end

function NotificationSystem:Notify(data)
	assert(type(data) == "table", "NotificationSystem:Notify espera uma tabela")
	ensureGui()

	table.insert(Shared.Queue, {
		Title = data.Title or "Notificação",
		Text = data.Text or "",
		Icon = (data.Icon and data.Icon ~= "") and data.Icon or nil,
		Duration = data.Duration or CONFIG.DefaultDuration,
	})

	task.defer(processQueue)
end

function NotificationSystem:SendNotification(data)
	self:Notify(data)
end

function NotificationSystem:Clear()
	table.clear(Shared.Queue)

	for _, slot in ipairs(Shared.ActiveNotifications) do
		if slot then
			slot:Destroy()
		end
	end

	table.clear(Shared.ActiveNotifications)
	Shared.Processing = false
end

function NotificationSystem:Configure(overrides)
	for key, value in pairs(overrides or {}) do
		if CONFIG[key] ~= nil then
			CONFIG[key] = value
		end
	end

	if Shared.UIScale then
		Shared.UIScale.Scale = getScale()
	end

	if Shared.Container then
		local layout = Shared.Container:FindFirstChildOfClass("UIListLayout")

		if layout then
			layout.Padding = UDim.new(0, CONFIG.QueueGap)
		end

		updateContainerBounds()
	end
end

ensureGui()
Shared.Initialized = true
return NotificationSystem
