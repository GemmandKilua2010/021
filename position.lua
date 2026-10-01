local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local Player = Players.LocalPlayer
local Clipboard = setclipboard or toclipboard
local Env = typeof(getgenv) == "function" and getgenv() or _G

local Theme = {
	Background = Color3.fromRGB(15, 16, 20),
	Surface = Color3.fromRGB(21, 23, 28),
	Surface2 = Color3.fromRGB(29, 32, 39),
	Hover = Color3.fromRGB(38, 42, 51),
	Stroke = Color3.fromRGB(47, 51, 61),

	Accent = Color3.fromRGB(91, 131, 255),
	AccentHover = Color3.fromRGB(108, 146, 255),

	Text = Color3.fromRGB(238, 239, 243),
	Muted = Color3.fromRGB(133, 139, 153),
	Danger = Color3.fromRGB(241, 93, 104),
	Success = Color3.fromRGB(91, 207, 137),

	CodeKeyword = "#C678DD",
	CodeString = "#98C379",
	CodeNumber = "#D19A66",
	CodeBuiltin = "#61AFEF",
	CodeComment = "#5C6370",
}

local IconAssets = {
	Close = "rbxassetid://7743878857",
	Minimize = "rbxassetid://7734000129",
	Restore = "rbxassetid://7743872181",
	Plus = "rbxassetid://7734042071",
	Copy = "rbxassetid://7733764083",
	List = "rbxassetid://7743869612",
}

local White = Color3.new(1, 1, 1)

local FontRegular = Enum.Font.BuilderSans
local FontMedium = Enum.Font.BuilderSansMedium
local FontBold = Enum.Font.BuilderSansBold

local HAlign = Enum.HorizontalAlignment
local VAlign = Enum.VerticalAlignment
local TAlign = Enum.TextXAlignment

local HEADER_H = 42
local INPUT_H = 38
local OPTION_H = 32
local LABEL_H = 18
local ROW_H = 36
local EMPTY_H = 24
local GAP = 10
local CONTENT_PAD = 14
local CODE_BTN_W = 102
local ICON_BTN = 28
local SCROLLBAR = 4
local MARGIN = 8
local WINDOW_GAP = 8
local CARET_H = 15

local MAIN_MIN_W, MAIN_MAX_W, MAIN_MAX_H = 240, 376, 400
local CODE_MIN_W, CODE_MAX_W, CODE_MAX_H = 280, 540, 380

local TOP_H = INPUT_H * 2 + OPTION_H + LABEL_H + GAP * 4

local TweenFast = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local MeasureBounds = Vector2.new(100000, 100000)

local CodeText = {
	Font = Enum.Font.Code,
	TextSize = 13,
	LineHeight = 1.2,
	TextWrapped = false,
	TextXAlignment = TAlign.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}

local Destroyed = false
local Minimized = false
local Editing = false
local Precision = 2

local PreviousCleanup = Env.SpecterXPositionsCleanup

if typeof(PreviousCleanup) == "function" then
	pcall(PreviousCleanup)
end

local Connections = {}

local function Track(signal, callback)
	local connection = signal:Connect(callback)
	Connections[#Connections + 1] = connection
	return connection
end

local function With(base, extra)
	local result = table.clone(base)

	for key, value in pairs(extra or {}) do
		result[key] = value
	end

	return result
end

local Defaults = {
	TextLabel = { Font = FontMedium, TextColor3 = Theme.Text, TextSize = 13 },
	TextButton = {
		Font = FontMedium,
		TextColor3 = Theme.Text,
		TextSize = 13,
		AutoButtonColor = false,
		Text = "",
	},
	TextBox = {
		Font = FontRegular,
		TextColor3 = Theme.Text,
		TextSize = 14,
		ClearTextOnFocus = false,
	},
	ImageButton = { AutoButtonColor = false, ScaleType = Enum.ScaleType.Fit },
	ImageLabel = { ScaleType = Enum.ScaleType.Fit },
}

local function Create(class, parent, props)
	props = props or {}

	local object = Instance.new(class)

	if object:IsA("GuiObject") then
		object.BorderSizePixel = 0

		if props.BackgroundColor3 == nil and props.BackgroundTransparency == nil then
			object.BackgroundTransparency = 1
		end
	end

	for key, value in pairs(Defaults[class] or {}) do
		object[key] = value
	end

	for key, value in pairs(props) do
		object[key] = value
	end

	object.Parent = parent
	return object
end

local function Skin(object, radius, strokeColor)
	Create("UICorner", object, { CornerRadius = UDim.new(0, radius) })

	if strokeColor then
		return Create("UIStroke", object, {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = strokeColor,
			Thickness = 1,
		})
	end
end

local function Pad(parent, left, right, top, bottom)
	right = right or left
	top = top or left
	bottom = bottom or top

	return Create("UIPadding", parent, {
		PaddingLeft = UDim.new(0, left),
		PaddingRight = UDim.new(0, right),
		PaddingTop = UDim.new(0, top),
		PaddingBottom = UDim.new(0, bottom),
	})
end

local function List(parent, gap, horizontal, hAlign, vAlign)
	return Create("UIListLayout", parent, {
		FillDirection = horizontal and Enum.FillDirection.Horizontal
			or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = hAlign or HAlign.Left,
		VerticalAlignment = vAlign or VAlign.Top,
	})
end

local function Hover(object, property, normal, active, onSignal, offSignal)
	local on = TweenService:Create(object, TweenFast, { [property] = active })
	local off = TweenService:Create(object, TweenFast, { [property] = normal })

	Track(onSignal or object.MouseEnter, function()
		off:Cancel()
		on:Play()
	end)

	Track(offSignal or object.MouseLeave, function()
		on:Cancel()
		off:Play()
	end)
end

local function MakeStatus(label)
	local token = 0

	return function(text, danger)
		token += 1

		local current = token

		label.Text = text
		label.TextColor3 = danger and Theme.Danger or Theme.Success

		task.delay(2.4, function()
			if not Destroyed and token == current then
				label.Text = ""
			end
		end)
	end
end

local function TryCopy(text)
	if typeof(Clipboard) ~= "function" then
		return false
	end

	return (pcall(Clipboard, text))
end

local function IconButton(parent, name, order, size, plain)
	local button = Create("ImageButton", parent, {
		Image = IconAssets[name],
		ImageColor3 = Theme.Muted,
		LayoutOrder = order,
		Size = UDim2.fromOffset(size or ICON_BTN, size or ICON_BTN),
	})

	if not plain then
		Hover(button, "ImageColor3", Theme.Muted, Theme.Text)
	end

	return button
end

local function Button(parent, text, icon, primary, props)
	local normal = primary and Theme.Accent or Theme.Surface2
	local hovered = primary and Theme.AccentHover or Theme.Hover
	local foreground = primary and White or Theme.Text

	local button = Create(
		"TextButton",
		parent,
		With(props, { BackgroundColor3 = normal })
	)

	local stroke = Skin(button, 8, not primary and Theme.Stroke or nil)

	List(button, 7, true, HAlign.Center, VAlign.Center)

	if icon then
		Create("ImageLabel", button, {
			Image = IconAssets[icon],
			ImageColor3 = foreground,
			LayoutOrder = 1,
			Size = UDim2.fromOffset(16, 16),
		})
	end

	local label = Create("TextLabel", button, {
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Size = UDim2.fromScale(0, 1),
		Text = text,
		TextColor3 = foreground,
		TextSize = 14,
	})

	Hover(button, "BackgroundColor3", normal, hovered)

	return button, label, stroke
end

local function GetGuiParent()
	if typeof(gethui) == "function" then
		local success, result = pcall(gethui)

		if success and typeof(result) == "Instance" then
			return result
		end
	end

	return Player:WaitForChild("PlayerGui")
end

local function RandomName(length)
	local charset =
		"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@*#$%&"
	local rng = Random.new()
	local chars = table.create(length)

	for index = 1, length do
		local position = rng:NextInteger(1, #charset)
		chars[index] = charset:sub(position, position)
	end

	return table.concat(chars)
end

local Screen = Create("ScreenGui", GetGuiParent(), {
	DisplayOrder = 9999,
	IgnoreGuiInset = false,
	Name = RandomName(12),
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local function CreateWindow(title, buttonCount, padding)
	local window = Create("Frame", Screen, {
		BackgroundColor3 = Theme.Background,
		ClipsDescendants = true,
	})

	Skin(window, 11, Theme.Stroke)

	local header = Create("Frame", window, {
		Name = "Header",
		Active = true,
		BackgroundColor3 = Theme.Surface,
		Size = UDim2.new(1, 0, 0, HEADER_H),
	})

	Skin(header, 11)

	Create("Frame", header, {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Theme.Surface,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 11),
	})

	local accent = Create("Frame", header, {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Accent,
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(3, 16),
	})

	Skin(accent, 2)

	local buttonsWidth = buttonCount * ICON_BTN + (buttonCount - 1) * 4

	Create("TextLabel", header, {
		Name = "Title",
		Font = FontBold,
		Position = UDim2.fromOffset(27, 0),
		Size = UDim2.new(1, -(27 + buttonsWidth + 16), 1, 0),
		Text = title,
		TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = TAlign.Left,
	})

	local buttons = Create("Frame", header, {
		Name = "WindowButtons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(buttonsWidth, ICON_BTN),
	})

	List(buttons, 4, true, HAlign.Right, VAlign.Center)

	Create("Frame", window, {
		BackgroundColor3 = Theme.Stroke,
		Position = UDim2.fromOffset(0, HEADER_H - 1),
		Size = UDim2.new(1, 0, 0, 1),
	})

	local content = Create("Frame", window, {
		Name = "Content",
		Position = UDim2.fromOffset(0, HEADER_H),
		Size = UDim2.new(1, 0, 1, -HEADER_H),
	})

	Pad(content, padding)
	List(content, GAP)

	return window, header, buttons, content
end

local Main, Header, MainButtons, Content =
	CreateWindow("SpecterX · Positions", 2, CONTENT_PAD)

Main.Name = "MainWindow"

local MinimizeButton = IconButton(MainButtons, "Minimize", 1)
local CloseButton = IconButton(MainButtons, "Close", 2)

local NameBox = Create("TextBox", Content, {
	Name = "NameInput",
	BackgroundColor3 = Theme.Surface,
	LayoutOrder = 1,
	PlaceholderColor3 = Theme.Muted,
	PlaceholderText = "Nome da posição",
	Size = UDim2.new(1, 0, 0, INPUT_H),
	Text = "",
	TextXAlignment = TAlign.Left,
})

local NameStroke = Skin(NameBox, 8, Theme.Stroke)
Pad(NameBox, 12, 12, 0, 0)
Hover(NameStroke, "Color", Theme.Stroke, Theme.Accent, NameBox.Focused, NameBox.FocusLost)

local SaveButton = Button(Content, "Salvar e copiar posição", "Copy", true, {
	Name = "SaveButton",
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, INPUT_H),
})

local Options = Create("Frame", Content, {
	Name = "Options",
	LayoutOrder = 3,
	Size = UDim2.new(1, 0, 0, OPTION_H),
})

List(Options, 8, true)

local Segmented = Create("Frame", Options, {
	Name = "PrecisionSelector",
	BackgroundColor3 = Theme.Surface,
	LayoutOrder = 1,
	Size = UDim2.new(1, -(CODE_BTN_W + 8), 1, 0),
})

Skin(Segmented, 8, Theme.Stroke)
Pad(Segmented, 3)

local Indicator = Create("Frame", Segmented, {
	Name = "Indicator",
	BackgroundColor3 = Theme.Accent,
	Position = UDim2.fromScale((Precision - 2) / 3, 0),
	Size = UDim2.fromScale(1 / 3, 1),
})

Skin(Indicator, 6)

local PrecisionButtons = {}
local IndicatorTweens = {}

for value = 2, 4 do
	PrecisionButtons[value] = Create("TextButton", Segmented, {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale((value - 2) / 3, 0),
		Size = UDim2.fromScale(1 / 3, 1),
		Text = tostring(value),
		TextColor3 = value == Precision and White or Theme.Muted,
		TextSize = 12,
	})

	IndicatorTweens[value] = TweenService:Create(Indicator, TweenFast, {
		Position = UDim2.fromScale((value - 2) / 3, 0),
	})
end

local CodeButton = Button(Options, "Código", "List", false, {
	Name = "CodeButton",
	LayoutOrder = 2,
	Size = UDim2.new(0, CODE_BTN_W, 1, 0),
})

local ListHeader = Create("Frame", Content, {
	Name = "ListHeader",
	LayoutOrder = 4,
	Size = UDim2.new(1, 0, 0, LABEL_H),
})

local CountLabel = Create("TextLabel", ListHeader, {
	Size = UDim2.fromScale(0.4, 1),
	Text = "SALVOS · 0",
	TextColor3 = Theme.Muted,
	TextSize = 11,
	TextXAlignment = TAlign.Left,
})

local StatusLabel = Create("TextLabel", ListHeader, {
	AnchorPoint = Vector2.new(1, 0),
	Font = FontRegular,
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromScale(0.6, 1),
	TextColor3 = Theme.Muted,
	TextSize = 12,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextXAlignment = TAlign.Right,
})

local MainStatus = MakeStatus(StatusLabel)

local EmptyLabel = Create("TextLabel", Content, {
	Name = "Empty",
	Font = FontRegular,
	LayoutOrder = 5,
	Size = UDim2.new(1, 0, 0, EMPTY_H),
	Text = "Nenhuma posição salva",
	TextColor3 = Theme.Muted,
	TextXAlignment = TAlign.Left,
})

local PositionList = Create("ScrollingFrame", Content, {
	Name = "PositionList",
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Theme.Surface,
	CanvasSize = UDim2.new(),
	LayoutOrder = 5,
	ScrollBarImageColor3 = Theme.Hover,
	ScrollBarImageTransparency = 0.2,
	ScrollBarThickness = 3,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	Size = UDim2.new(1, 0, 1, -TOP_H),
	Visible = false,
})

Skin(PositionList, 8, Theme.Stroke)
Pad(PositionList, 5, 8, 5, 5)
List(PositionList, 3)

local CodeWindow, _, CodeButtons, CodeContent =
	CreateWindow("SpecterX · Code", 1, 12)

CodeWindow.Name = "CodeWindow"
CodeWindow.Visible = false

local CodeClose = IconButton(CodeButtons, "Close", 1)

local CodeArea = Create("Frame", CodeContent, {
	Name = "CodeArea",
	BackgroundColor3 = Theme.Surface,
	ClipsDescendants = true,
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 1, -(34 + GAP)),
})

Skin(CodeArea, 8, Theme.Stroke)
List(CodeArea, 0, true)

local Gutter = Create("Frame", CodeArea, {
	Name = "Gutter",
	ClipsDescendants = true,
	LayoutOrder = 1,
	Size = UDim2.new(0, 42, 1, 0),
})

Create("Frame", Gutter, {
	AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = Theme.Stroke,
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0, 1, 1, 0),
})

local LineNumbers = Create("TextLabel", Gutter, With(CodeText, {
	Name = "LineNumbers",
	Size = UDim2.new(1, 0, 0, 100),
	Text = "1",
	TextColor3 = Theme.Muted,
	TextXAlignment = TAlign.Right,
}))

Pad(LineNumbers, 0, 8, 8, 0)

local CodeScroll = Create("ScrollingFrame", CodeArea, {
	Name = "CodeScroll",
	CanvasSize = UDim2.new(),
	LayoutOrder = 2,
	ScrollBarImageColor3 = Theme.Hover,
	ScrollBarImageTransparency = 0.15,
	ScrollBarThickness = SCROLLBAR,
	ScrollingDirection = Enum.ScrollingDirection.XY,
	Size = UDim2.new(1, -42, 1, 0),
})

local Editor = Create("TextBox", CodeScroll, With(CodeText, {
	Name = "Editor",
	MultiLine = true,
	Position = UDim2.fromOffset(10, 8),
	Size = UDim2.fromOffset(400, 100),
	Text = "",
	TextEditable = false,
	TextTransparency = 1,
}))

local Highlight = Create("TextLabel", Editor, With(CodeText, {
	Name = "Highlight",
	RichText = true,
	Size = UDim2.fromScale(1, 1),
}))

local Caret = Create("Frame", Editor, {
	Name = "Caret",
	BackgroundColor3 = Theme.Text,
	Size = UDim2.fromOffset(2, CARET_H),
	Visible = false,
	ZIndex = 3,
})

local BlinkTween = TweenService:Create(
	Caret,
	TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, -1, true),
	{ BackgroundTransparency = 1 }
)

local Footer = Create("Frame", CodeContent, {
	Name = "Footer",
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 34),
})

List(Footer, 8, true, HAlign.Left, VAlign.Center)

local CopyCodeButton = Button(Footer, "Copiar código", "Copy", true, {
	LayoutOrder = 1,
	Size = UDim2.new(0, 124, 1, 0),
})

local EditButton, EditLabel, EditStroke = Button(Footer, "Edit", nil, false, {
	LayoutOrder = 2,
	Size = UDim2.new(0, 64, 1, 0),
})

local CodeStatusLabel = Create("TextLabel", Footer, {
	Font = FontRegular,
	LayoutOrder = 3,
	Size = UDim2.new(1, -(124 + 64 + 16), 1, 0),
	TextColor3 = Theme.Muted,
	TextSize = 12,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextXAlignment = TAlign.Right,
})

local CodeStatus = MakeStatus(CodeStatusLabel)

local Positions = {}
local PositionIndex = {}

local function FormatNumber(number)
	if math.abs(number) < 0.5 * 10 ^ -Precision then
		number = 0
	end

	return string.format("%." .. Precision .. "f", number)
end

local function Format(entry)
	local position = entry.Position

	entry.Vec = string.format(
		"%s, %s, %s",
		FormatNumber(position.X),
		FormatNumber(position.Y),
		FormatNumber(position.Z)
	)

	entry.Line = string.format("    [%q] = Vector3.new(%s),", entry.Name, entry.Vec)
end

local function GenerateCode()
	local lines = table.create(#Positions + 4)

	lines[1] = "local Locates = {"

	for index, entry in ipairs(Positions) do
		lines[index + 1] = entry.Line
	end

	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "return Locates"

	return table.concat(lines, "\n")
end

local function GetRootPosition()
	local character = Player.Character

	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")

	if not root then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		root = humanoid and humanoid.RootPart
	end

	return root and root.Position
end

local MainX, MainY, MainW, MainH = 0, 0, 0, 0
local MainTween

local function ViewSize()
	local size = Screen.AbsoluteSize

	if size.X > 0 and size.Y > 0 then
		return size
	end

	local camera = workspace.CurrentCamera

	return camera and camera.ViewportSize or Vector2.new(800, 600)
end

local function TargetHeight(view)
	if Minimized then
		return HEADER_H
	end

	local count = #Positions
	local body = count == 0 and EMPTY_H or count * (ROW_H + 3) + 7
	local height = HEADER_H + CONTENT_PAD * 2 + TOP_H + body

	return math.min(height, MAIN_MAX_H, view.Y * 0.9)
end

local function LayoutCode()
	if not CodeWindow.Visible then
		return
	end

	local view = ViewSize()
	local rightSpace = view.X - (MainX + MainW + WINDOW_GAP) - MARGIN
	local leftSpace = MainX - WINDOW_GAP - MARGIN
	local width, x

	if rightSpace >= CODE_MIN_W then
		width = math.min(CODE_MAX_W, rightSpace)
		x = MainX + MainW + WINDOW_GAP
	elseif leftSpace >= CODE_MIN_W then
		width = math.min(CODE_MAX_W, leftSpace)
		x = MainX - WINDOW_GAP - width
	else
		width = math.min(CODE_MAX_W, view.X - MARGIN * 2)
		x = view.X - width - MARGIN
	end

	local height = math.min(CODE_MAX_H, view.Y - MARGIN * 2)
	local y = math.clamp(MainY, MARGIN, math.max(MARGIN, view.Y - height - MARGIN))

	CodeWindow.Size = UDim2.fromOffset(width, height)
	CodeWindow.Position = UDim2.fromOffset(x, y)
end

local function Apply(animate)
	local view = ViewSize()

	MainW = math.clamp(view.X * 0.92, MAIN_MIN_W, MAIN_MAX_W)
	MainH = TargetHeight(view)
	MainX = math.clamp(MainX, MARGIN, math.max(MARGIN, view.X - MainW - MARGIN))
	MainY = math.clamp(MainY, MARGIN, math.max(MARGIN, view.Y - MainH - MARGIN))

	local size = UDim2.fromOffset(MainW, MainH)
	local position = UDim2.fromOffset(MainX, MainY)

	if MainTween then
		MainTween:Cancel()
		MainTween = nil
	end

	if animate then
		MainTween = TweenService:Create(Main, TweenFast, {
			Size = size,
			Position = position,
		})

		MainTween.Completed:Once(function()
			Content.Visible = not Minimized
		end)

		MainTween:Play()
	else
		Main.Size, Main.Position = size, position
		Content.Visible = not Minimized
	end

	LayoutCode()
end

local function MoveMain(x, y)
	local view = ViewSize()

	MainX = math.clamp(x, MARGIN, math.max(MARGIN, view.X - MainW - MARGIN))
	MainY = math.clamp(y, MARGIN, math.max(MARGIN, view.Y - MainH - MARGIN))

	Main.Position = UDim2.fromOffset(MainX, MainY)
	LayoutCode()
end

local function Set(words)
	local set = {}

	for _, word in ipairs(words) do
		set[word] = true
	end

	return set
end

local Keywords = Set(
	(
		"and break continue do else elseif end false for function if in "
		.. "local nil not or repeat return then true until while"
	):split(" ")
)

local Builtins = Set(
	(
		"Vector3 Vector2 CFrame Color3 UDim UDim2 Enum Instance game workspace "
		.. "script task math string table pairs ipairs type typeof tostring tonumber"
	):split(" ")
)

local RichEscape = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }

local function Escape(text)
	return (text:gsub("[&<>]", RichEscape))
end

local function Paint(text, color)
	return `<font color="{color}">{Escape(text)}</font>`
end

local function HighlightLine(line)
	local out, length, index = {}, #line, 1

	while index <= length do
		local char = line:sub(index, index)

		if char == "-" and line:sub(index + 1, index + 1) == "-" then
			out[#out + 1] = Paint(line:sub(index), Theme.CodeComment)
			break
		elseif char == '"' or char == "'" then
			local finish = index + 1

			repeat
				local found = line:find("[\\" .. char .. "]", finish)
				local escaped = false

				if found then
					escaped = line:sub(found, found) == "\\"
					finish = found + (escaped and 2 or 1)
				else
					finish = length + 1
				end
			until not escaped

			out[#out + 1] = Paint(line:sub(index, finish - 1), Theme.CodeString)
			index = finish
		else
			local start, finish = line:find("^[%a_][%w_]*", index)

			if start then
				local word = line:sub(index, finish)

				out[#out + 1] = Keywords[word] and Paint(word, Theme.CodeKeyword)
					or Builtins[word] and Paint(word, Theme.CodeBuiltin)
					or Escape(word)
			else
				start, finish = line:find("^%.?%d[%w%.]*", index)

				if start then
					out[#out + 1] = Paint(line:sub(index, finish), Theme.CodeNumber)
				else
					start, finish = line:find("^[^%a_%d\"'%-%.]+", index)
					finish = finish or index
					out[#out + 1] = Escape(line:sub(index, finish))
				end
			end

			index = finish + 1
		end
	end

	return table.concat(out)
end

local LineCache, CacheSize = {}, 0
local LastText, LineCount = nil, 0
local LineHeightPx = CodeText.TextSize * CodeText.LineHeight
local EditorWidth, EditorHeight = 0, 0
local RenderPending = false
local CodeStale = true

local function ResizeEditor()
	local view, bounds = CodeScroll.AbsoluteSize, Editor.TextBounds
	local width = math.max(view.X - 20 - SCROLLBAR, bounds.X + 28)
	local height = math.max(view.Y - 16 - SCROLLBAR, bounds.Y + 24)

	if width == EditorWidth and height == EditorHeight then
		return
	end

	EditorWidth, EditorHeight = width, height

	Editor.Size = UDim2.fromOffset(width, height)
	CodeScroll.CanvasSize = UDim2.fromOffset(width + 20, height + 16)
	LineNumbers.Size = UDim2.new(1, 0, 0, height + 16)
end

local function UpdateCaret()
	local cursor = Editor.CursorPosition

	if not Editing or cursor < 1 or not Editor:IsFocused() then
		BlinkTween:Cancel()
		Caret.Visible = false
		return
	end

	local before = Editor.Text:sub(1, cursor - 1)
	local _, lines = before:gsub("\n", "")
	local column = before:match("[^\n]*$")

	local x = TextService:GetTextSize(
		column,
		CodeText.TextSize,
		CodeText.Font,
		MeasureBounds
	).X

	local y = lines * LineHeightPx + (LineHeightPx - CARET_H) / 2

	Caret.Position = UDim2.fromOffset(x, y)

	local pointX = Editor.Position.X.Offset + x
	local pointY = Editor.Position.Y.Offset + y
	local window, canvas = CodeScroll.AbsoluteWindowSize, CodeScroll.CanvasPosition
	local targetX, targetY = canvas.X, canvas.Y

	if pointX < canvas.X + 10 then
		targetX = pointX - 10
	elseif pointX > canvas.X + window.X - 14 then
		targetX = pointX - window.X + 14
	end

	if pointY < canvas.Y then
		targetY = pointY - 4
	elseif pointY + CARET_H > canvas.Y + window.Y - 4 then
		targetY = pointY + CARET_H - window.Y + 4
	end

	if targetX ~= canvas.X or targetY ~= canvas.Y then
		CodeScroll.CanvasPosition = Vector2.new(math.max(targetX, 0), math.max(targetY, 0))
	end

	BlinkTween:Cancel()
	Caret.BackgroundTransparency = 0
	Caret.Visible = true
	BlinkTween:Play()
end

local function RenderEditor()
	RenderPending = false

	local text = Editor.Text

	if text == LastText then
		return
	end

	LastText = text

	local parts, count = {}, 0

	for line in (text .. "\n"):gmatch("(.-)\n") do
		count += 1

		local painted = LineCache[line]

		if not painted then
			painted = HighlightLine(line)
			LineCache[line] = painted
			CacheSize += 1
		end

		parts[count] = painted
	end

	if CacheSize > 2000 then
		LineCache, CacheSize = {}, 0
	end

	Highlight.Text = table.concat(parts, "\n")

	if count ~= LineCount then
		LineCount = count

		local numbers = table.create(count)

		for number = 1, count do
			numbers[number] = number
		end

		LineNumbers.Text = table.concat(numbers, "\n")

		local bounds = LineNumbers.TextBounds.Y

		if bounds > 0 then
			LineHeightPx = bounds / count
		end
	end

	ResizeEditor()

	if Editing then
		UpdateCaret()
	end
end

local function QueueRender()
	if RenderPending then
		return
	end

	RenderPending = true

	task.defer(function()
		if not Destroyed then
			RenderEditor()
		end
	end)
end

local function PushCode()
	CodeStale = false
	Editor.Text = GenerateCode()
	RenderEditor()
end

local function SetEditing(enabled)
	Editing = enabled
	Editor.TextEditable = enabled
	EditStroke.Color = enabled and Theme.Accent or Theme.Stroke
	EditLabel.TextColor3 = enabled and Theme.Accent or Theme.Text

	if enabled then
		Editor:CaptureFocus()
	else
		Editor:ReleaseFocus()
	end

	UpdateCaret()
end

local function SetCodeVisible(visible)
	if not visible and Editing then
		SetEditing(false)
	end

	CodeWindow.Visible = visible

	if visible then
		if CodeStale then
			PushCode()
		end

		LayoutCode()

		task.defer(function()
			if not Destroyed then
				ResizeEditor()
			end
		end)
	end
end

local function MarkCodeStale()
	CodeStale = true

	if CodeWindow.Visible then
		PushCode()
	end
end

local Rows = {}
local RenderList

local function RemoveAt(index)
	local removed = table.remove(Positions, index)

	if not removed then
		return
	end

	PositionIndex[removed.Name] = nil

	for position = index, #Positions do
		PositionIndex[Positions[position].Name] = position
	end

	RenderList(index)
	Apply(true)
	MarkCodeStale()
	MainStatus("Posição removida.")
end

local function CreateRow(index)
	local frame = Create("TextButton", PositionList, {
		BackgroundColor3 = Theme.Surface2,
		BackgroundTransparency = 0.45,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, ROW_H),
		Visible = false,
	})

	Skin(frame, 7)
	Pad(frame, 10, 4, 0, 0)
	List(frame, 6, true, HAlign.Left, VAlign.Center)

	local name = Create("TextLabel", frame, {
		LayoutOrder = 1,
		Size = UDim2.new(0.4, -14, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = TAlign.Left,
	})

	local vec = Create("TextLabel", frame, {
		Font = Enum.Font.Code,
		LayoutOrder = 2,
		Size = UDim2.new(0.6, -20, 1, 0),
		TextColor3 = Theme.Muted,
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = TAlign.Right,
	})

	local remove = IconButton(frame, "Close", 3, 22, true)

	Hover(frame, "BackgroundTransparency", 0.45, 0)

	Track(frame.Activated, function()
		local entry = Positions[index]

		if not entry then
			return
		end

		if TryCopy(entry.Line) then
			MainStatus("Linha copiada.")
		else
			MainStatus("Clipboard indisponível.", true)
		end
	end)

	Track(remove.Activated, function()
		RemoveAt(index)
	end)

	local row = { Frame = frame, Name = name, Vec = vec }
	Rows[index] = row

	return row
end

local function RenderRow(index)
	local entry, row = Positions[index], Rows[index]

	if entry and not row then
		row = CreateRow(index)
	end

	if not row then
		return
	end

	row.Frame.Visible = entry ~= nil

	if entry then
		row.Name.Text = entry.Name
		row.Vec.Text = entry.Vec
	end
end

function RenderList(from)
	for index = from, math.max(#Positions, #Rows) do
		RenderRow(index)
	end

	local empty = #Positions == 0

	CountLabel.Text = "SALVOS · " .. #Positions
	EmptyLabel.Visible = empty
	PositionList.Visible = not empty
end

local function SavePosition()
	local name = NameBox.Text:match("^%s*(.-)%s*$")

	if not name or name == "" then
		MainStatus("Digite um nome.", true)
		return
	end

	local position = GetRootPosition()

	if not position then
		MainStatus("Personagem não encontrado.", true)
		return
	end

	local index = PositionIndex[name]
	local existing = index ~= nil

	if existing then
		local entry = Positions[index]
		entry.Position = position
		Format(entry)
		RenderRow(index)
	else
		index = #Positions + 1

		local entry = { Name = name, Position = position }
		Format(entry)

		Positions[index] = entry
		PositionIndex[name] = index

		RenderList(index)
		Apply(true)
	end

	MarkCodeStale()

	local copied = TryCopy(Positions[index].Line)

	if existing then
		MainStatus(copied and "Atualizada e copiada." or "Posição atualizada.")
	else
		MainStatus(copied and "Salva e copiada." or "Posição salva.")
	end

	NameBox.Text = ""

	if not existing then
		task.defer(function()
			if not Destroyed then
				PositionList.CanvasPosition =
					Vector2.new(0, PositionList.AbsoluteCanvasSize.Y)
			end
		end)
	end
end

local function SetPrecision(value)
	if value == Precision then
		return
	end

	PrecisionButtons[Precision].TextColor3 = Theme.Muted
	Precision = value
	PrecisionButtons[value].TextColor3 = White
	IndicatorTweens[value]:Play()

	for _, entry in ipairs(Positions) do
		Format(entry)
	end

	RenderList(1)
	MarkCodeStale()
end

local function ToggleMinimize()
	Minimized = not Minimized

	if Minimized then
		SetCodeVisible(false)
	else
		Content.Visible = true
	end

	MinimizeButton.Image = Minimized and IconAssets.Restore or IconAssets.Minimize
	Apply(true)
end

local Drag

local function StopDrag()
	if Drag then
		Drag[1]:Disconnect()
		Drag[2]:Disconnect()
		Drag = nil
	end
end

local function Cleanup(destroyScreen)
	if Destroyed then
		return
	end

	Destroyed = true
	Env.SpecterXPositionsCleanup = nil

	StopDrag()
	BlinkTween:Cancel()

	if MainTween then
		MainTween:Cancel()
	end

	for _, connection in ipairs(Connections) do
		connection:Disconnect()
	end

	table.clear(Connections)

	if destroyScreen then
		Screen:Destroy()
	end
end

Track(Header.InputBegan, function(input)
	local kind = input.UserInputType

	if
		Drag
		or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch)
	then
		return
	end

	local startPosition, originX, originY = input.Position, MainX, MainY

	local move = UserInputService.InputChanged:Connect(function(changed)
		if
			changed ~= input
			and changed.UserInputType ~= Enum.UserInputType.MouseMovement
		then
			return
		end

		local delta = changed.Position - startPosition

		MoveMain(originX + delta.X, originY + delta.Y)
	end)

	local finish = input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End then
			StopDrag()
		end
	end)

	Drag = { move, finish }
end)

Track(SaveButton.Activated, SavePosition)

Track(NameBox.FocusLost, function(enterPressed)
	if enterPressed then
		SavePosition()
	end
end)

for value, button in pairs(PrecisionButtons) do
	Track(button.Activated, function()
		SetPrecision(value)
	end)
end

Track(CodeButton.Activated, function()
	SetCodeVisible(not CodeWindow.Visible)
end)

Track(CodeClose.Activated, function()
	SetCodeVisible(false)
end)

Track(CopyCodeButton.Activated, function()
	if TryCopy(Editor.Text) then
		CodeStatus("Código copiado.")
	else
		CodeStatus("Clipboard indisponível.", true)
	end
end)

Track(EditButton.Activated, function()
	SetEditing(not Editing)
end)

Track(MinimizeButton.Activated, ToggleMinimize)

Track(CloseButton.Activated, function()
	Cleanup(true)
end)

Track(Screen.Destroying, function()
	Cleanup(false)
end)

Track(Editor:GetPropertyChangedSignal("Text"), QueueRender)
Track(Editor:GetPropertyChangedSignal("CursorPosition"), UpdateCaret)
Track(Editor.Focused, UpdateCaret)
Track(Editor.FocusLost, UpdateCaret)

Track(CodeScroll:GetPropertyChangedSignal("CanvasPosition"), function()
	LineNumbers.Position = UDim2.fromOffset(0, -CodeScroll.CanvasPosition.Y)
end)

Track(CodeScroll:GetPropertyChangedSignal("AbsoluteSize"), function()
	task.defer(function()
		if not Destroyed then
			ResizeEditor()
		end
	end)
end)

local ResizePending = false

Track(Screen:GetPropertyChangedSignal("AbsoluteSize"), function()
	if ResizePending then
		return
	end

	ResizePending = true

	task.defer(function()
		ResizePending = false

		if not Destroyed then
			Apply(false)
		end
	end)
end)

local view = ViewSize()

MainX = (view.X - math.clamp(view.X * 0.92, MAIN_MIN_W, MAIN_MAX_W)) / 2
MainY = (view.Y - TargetHeight(view)) / 2

RenderList(1)
Apply(false)

Env.SpecterXPositionsCleanup = function()
	Cleanup(true)
end
