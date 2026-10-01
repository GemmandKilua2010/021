local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Clipboard = setclipboard or toclipboard

--------------------------------------------------------------------
-- ÍCONES
-- Por padrão os ícones são desenhados com Frames (sempre nítidos e
-- nunca quebram). Se quiser usar imagens do Roblox, coloque o
-- asset aqui, ex: Close = "rbxassetid://123456789"
--------------------------------------------------------------------
local IconAssets = {
	Close = nil,
	Minimize = nil,
	Restore = nil,
	Plus = nil,
	Copy = nil,
	List = nil,
}

local Theme = {
	Background = Color3.fromRGB(17, 18, 22),
	Surface = Color3.fromRGB(24, 26, 31),
	Surface2 = Color3.fromRGB(32, 35, 42),
	Hover = Color3.fromRGB(42, 46, 55),
	Stroke = Color3.fromRGB(44, 47, 56),

	Accent = Color3.fromRGB(88, 130, 255),
	AccentHover = Color3.fromRGB(110, 148, 255),

	Text = Color3.fromRGB(232, 234, 240),
	Muted = Color3.fromRGB(128, 134, 148),
	Danger = Color3.fromRGB(240, 96, 96),
	Success = Color3.fromRGB(96, 200, 140),

	CodeKeyword = "#C678DD",
	CodeString = "#98C379",
	CodeNumber = "#D19A66",
	CodeBuiltin = "#61AFEF",
	CodeComment = "#5C6370",
}

local FontRegular = Enum.Font.BuilderSans
local FontMedium = Enum.Font.BuilderSansMedium
local FontBold = Enum.Font.BuilderSansBold

local Keywords = {}
for _, word in ipairs({
	"and", "break", "continue", "do", "else", "elseif", "end", "false",
	"for", "function", "if", "in", "local", "nil", "not", "or", "repeat",
	"return", "then", "true", "until", "while",
}) do
	Keywords[word] = true
end

local Builtins = {}
for _, word in ipairs({
	"Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "Enum",
	"Instance", "game", "workspace", "script", "task", "math", "string",
	"table", "pairs", "ipairs", "type", "typeof", "tostring", "tonumber",
}) do
	Builtins[word] = true
end

local Connections = {}
local Positions = {}
local PositionIndex = {}

local Precision = 2
local Minimized = false
local Destroyed = false
local GeneratedCode = ""

local MAIN_HEIGHT = 332
local HEADER_HEIGHT = 40

--------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------
local function Connect(signal, callback)
	local connection = signal:Connect(callback)
	Connections[#Connections + 1] = connection
	return connection
end

local function Create(class, parent, properties)
	local object = Instance.new(class)

	for property, value in pairs(properties or {}) do
		object[property] = value
	end

	object.Parent = parent
	return object
end

local function Round(object, radius)
	return Create("UICorner", object, {
		CornerRadius = UDim.new(0, radius),
	})
end

local function Stroke(object, color, thickness)
	return Create("UIStroke", object, {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function Tween(object, properties, time)
	TweenService:Create(
		object,
		TweenInfo.new(time or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		properties
	):Play()
end

local function Hover(button, normal, hovered)
	Connect(button.MouseEnter, function()
		Tween(button, { BackgroundColor3 = hovered })
	end)

	Connect(button.MouseLeave, function()
		Tween(button, { BackgroundColor3 = normal })
	end)
end

--------------------------------------------------------------------
-- ÍCONES (vetor desenhado com Frames, ou imagem se IconAssets definido)
--------------------------------------------------------------------
local function MakeIcon(name, parent, color, background)
	local holder = Create("Frame", parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
	})

	local asset = IconAssets[name]

	if asset then
		Create("ImageLabel", holder, {
			BackgroundTransparency = 1,
			Image = asset,
			ImageColor3 = color,
			Size = UDim2.fromScale(1, 1),
		})

		return holder
	end

	local function Bar(width, height, rotation, offsetX, offsetY)
		local bar = Create("Frame", holder, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, offsetX or 0, 0.5, offsetY or 0),
			Rotation = rotation or 0,
			Size = UDim2.fromOffset(width, height),
		})

		Round(bar, 1)
		return bar
	end

	local function Box(size, offsetX, offsetY, fill)
		local box = Create("Frame", holder, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = background or Theme.Surface2,
			BackgroundTransparency = fill and 0 or 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, offsetX, 0.5, offsetY),
			Size = UDim2.fromOffset(size, size),
		})

		Round(box, 2)
		Stroke(box, color, 1.5)
		return box
	end

	if name == "Close" then
		Bar(14, 2, 45)
		Bar(14, 2, -45)
	elseif name == "Minimize" then
		Bar(10, 2, 0)
	elseif name == "Restore" then
		Box(9, 0, 0, false)
	elseif name == "Plus" then
		Bar(10, 2, 0)
		Bar(2, 10, 0)
	elseif name == "Copy" then
		Box(8, 2, -2, false)
		Box(8, -2, 2, true)
	elseif name == "List" then
		Bar(12, 2, 0, 0, -4)
		Bar(12, 2, 0, 0, 0)
		Bar(8, 2, 0, -2, 4)
	end

	return holder
end

local function CreateIconButton(parent, iconName, color)
	local button = Create("TextButton", parent, {
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Size = UDim2.fromOffset(28, 28),
	})

	Round(button, 6)

	local icon = MakeIcon(iconName, button, color or Theme.Muted, Theme.Surface)

	Connect(button.MouseEnter, function()
		Tween(button, { BackgroundTransparency = 0, BackgroundColor3 = Theme.Surface2 })
	end)

	Connect(button.MouseLeave, function()
		Tween(button, { BackgroundTransparency = 1 })
	end)

	return button, icon
end

local function CreateButton(parent, text, iconName, primary)
	local normal = primary and Theme.Accent or Theme.Surface2
	local hovered = primary and Theme.AccentHover or Theme.Hover
	local contentColor = primary and Color3.fromRGB(255, 255, 255) or Theme.Text

	local button = Create("TextButton", parent, {
		AutoButtonColor = false,
		BackgroundColor3 = normal,
		BorderSizePixel = 0,
		Text = "",
	})

	Round(button, 7)

	if not primary then
		Stroke(button)
	end

	local layout = Create("UIListLayout", button, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	if iconName then
		local slot = Create("Frame", button, {
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.fromOffset(14, 14),
		})

		MakeIcon(iconName, slot, contentColor, normal)
	end

	Create("TextLabel", button, {
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = FontMedium,
		LayoutOrder = 2,
		Size = UDim2.new(0, 0, 1, 0),
		Text = text,
		TextColor3 = contentColor,
		TextSize = 14,
	})

	Hover(button, normal, hovered)

	return button
end

--------------------------------------------------------------------
-- GUI BASE
--------------------------------------------------------------------
local function GetParent()
	if typeof(gethui) == "function" then
		local success, result = pcall(gethui)

		if success and typeof(result) == "Instance" then
			return result
		end
	end

	return Player:WaitForChild("PlayerGui")
end

local Parent = GetParent()

local Previous = Parent:FindFirstChild("SpecterXPositions")
if Previous then
	Previous:Destroy()
end

local Screen = Create("ScreenGui", Parent, {
	Name = "SpecterXPositions",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local function CreateWindow(title, width, height)
	local window = Create("Frame", Screen, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
	})

	Round(window, 10)
	Stroke(window)

	local header = Create("Frame", window, {
		Active = true,
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
	})

	Create("Frame", header, {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Theme.Stroke,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
	})

	Create("Frame", header, {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(3, 14),
	}).Parent = header

	Create("TextLabel", header, {
		BackgroundTransparency = 1,
		Font = FontBold,
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -110, 1, 0),
		Text = title,
		TextColor3 = Theme.Text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local buttons = Create("Frame", header, {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(64, 28),
	})

	Create("UIListLayout", buttons, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	return window, header, buttons
end

local Main, Header, HeaderButtons = CreateWindow("SpecterX  ·  Posições", 360, MAIN_HEIGHT)

local MinimizeButton, MinimizeIcon = CreateIconButton(HeaderButtons, "Minimize")
MinimizeButton.LayoutOrder = 1

local CloseButton = CreateIconButton(HeaderButtons, "Close")
CloseButton.LayoutOrder = 2

local Content = Create("Frame", Main, {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, HEADER_HEIGHT),
	Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
})

local NameBox = Create("TextBox", Content, {
	BackgroundColor3 = Theme.Surface,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	Font = FontRegular,
	PlaceholderColor3 = Theme.Muted,
	PlaceholderText = "Nome da posição",
	Position = UDim2.fromOffset(14, 14),
	Size = UDim2.new(1, -28, 0, 36),
	Text = "",
	TextColor3 = Theme.Text,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
})

Round(NameBox, 7)

local NameStroke = Stroke(NameBox)

Create("UIPadding", NameBox, {
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
})

Connect(NameBox.Focused, function()
	Tween(NameStroke, { Color = Theme.Accent })
end)

Connect(NameBox.FocusLost, function()
	Tween(NameStroke, { Color = Theme.Stroke })
end)

local SaveButton = CreateButton(Content, "Salvar e copiar", "Copy", true)
SaveButton.Position = UDim2.fromOffset(14, 58)
SaveButton.Size = UDim2.new(1, -28, 0, 36)

-- Linha: precisão (segmentado) + botão código
local OptionsRow = Create("Frame", Content, {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 102),
	Size = UDim2.new(1, -28, 0, 30),
})

local Segmented = Create("Frame", OptionsRow, {
	BackgroundColor3 = Theme.Surface,
	BorderSizePixel = 0,
	Size = UDim2.new(0, 132, 1, 0),
})

Round(Segmented, 7)
Stroke(Segmented)

Create("UIPadding", Segmented, {
	PaddingBottom = UDim.new(0, 3),
	PaddingLeft = UDim.new(0, 3),
	PaddingRight = UDim.new(0, 3),
	PaddingTop = UDim.new(0, 3),
})

Create("UIListLayout", Segmented, {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 3),
	SortOrder = Enum.SortOrder.LayoutOrder,
})

local PrecisionButtons = {}

local function RefreshPrecision()
	for value, button in pairs(PrecisionButtons) do
		local selected = value == Precision

		Tween(button, {
			BackgroundColor3 = selected and Theme.Accent or Theme.Surface,
			TextColor3 = selected and Color3.fromRGB(255, 255, 255) or Theme.Muted,
		})
	end
end

for value = 2, 4 do
	local button = Create("TextButton", Segmented, {
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		Font = FontMedium,
		LayoutOrder = value,
		Size = UDim2.new(1 / 3, -2, 1, 0),
		Text = value .. " casas",
		TextColor3 = Theme.Muted,
		TextSize = 12,
	})

	Round(button, 5)
	PrecisionButtons[value] = button
end

local CodeButton = CreateButton(OptionsRow, "Código", "List", false)
CodeButton.AnchorPoint = Vector2.new(1, 0)
CodeButton.Position = UDim2.fromScale(1, 0)
CodeButton.Size = UDim2.new(1, -144, 1, 0)

-- Lista
local ListHeader = Create("Frame", Content, {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 144),
	Size = UDim2.new(1, -28, 0, 18),
})

local CountLabel = Create("TextLabel", ListHeader, {
	BackgroundTransparency = 1,
	Font = FontMedium,
	Size = UDim2.new(0, 90, 1, 0),
	Text = "SALVOS · 0",
	TextColor3 = Theme.Muted,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local StatusLabel = Create("TextLabel", ListHeader, {
	AnchorPoint = Vector2.new(1, 0),
	BackgroundTransparency = 1,
	Font = FontRegular,
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(1, -96, 1, 0),
	Text = "",
	TextColor3 = Theme.Muted,
	TextSize = 12,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextXAlignment = Enum.TextXAlignment.Right,
})

local ListFrame = Create("ScrollingFrame", Content, {
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Theme.Surface,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	Position = UDim2.fromOffset(14, 166),
	ScrollBarImageColor3 = Theme.Hover,
	ScrollBarThickness = 3,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	Size = UDim2.new(1, -28, 1, -180),
})

Round(ListFrame, 7)
Stroke(ListFrame)

Create("UIPadding", ListFrame, {
	PaddingBottom = UDim.new(0, 4),
	PaddingLeft = UDim.new(0, 4),
	PaddingRight = UDim.new(0, 7),
	PaddingTop = UDim.new(0, 4),
})

Create("UIListLayout", ListFrame, {
	Padding = UDim.new(0, 3),
	SortOrder = Enum.SortOrder.LayoutOrder,
})

local EmptyLabel = Create("TextLabel", ListFrame, {
	BackgroundTransparency = 1,
	Font = FontRegular,
	Size = UDim2.new(1, 0, 0, 60),
	Text = "Nenhuma posição salva ainda",
	TextColor3 = Theme.Muted,
	TextSize = 13,
})

--------------------------------------------------------------------
-- JANELA DE CÓDIGO
--------------------------------------------------------------------
local CodeWindow, CodeHeader, CodeHeaderButtons = CreateWindow("SpecterX  ·  Código", 520, 360)
CodeWindow.Visible = false

local CodeClose = CreateIconButton(CodeHeaderButtons, "Close")

local CodeArea = Create("Frame", CodeWindow, {
	BackgroundColor3 = Theme.Surface,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Position = UDim2.fromOffset(12, HEADER_HEIGHT + 10),
	Size = UDim2.new(1, -24, 1, -(HEADER_HEIGHT + 66)),
})

Round(CodeArea, 7)
Stroke(CodeArea)

local Gutter = Create("Frame", CodeArea, {
	BackgroundColor3 = Theme.Surface2,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Size = UDim2.new(0, 40, 1, 0),
})

local LineNumbers = Create("TextLabel", Gutter, {
	BackgroundTransparency = 1,
	Font = Enum.Font.Code,
	LineHeight = 1.2,
	Size = UDim2.new(1, 0, 0, 100),
	Text = "1",
	TextColor3 = Theme.Muted,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Top,
})

Create("UIPadding", LineNumbers, {
	PaddingTop = UDim.new(0, 8),
})

local CodeScroll = Create("ScrollingFrame", CodeArea, {
	AutomaticCanvasSize = Enum.AutomaticSize.None,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	Position = UDim2.fromOffset(40, 0),
	ScrollBarImageColor3 = Theme.Hover,
	ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.XY,
	Size = UDim2.new(1, -40, 1, 0),
})

local Highlight = Create("TextLabel", CodeScroll, {
	BackgroundTransparency = 1,
	Font = Enum.Font.Code,
	LineHeight = 1.2,
	Position = UDim2.fromOffset(8, 8),
	RichText = true,
	Size = UDim2.fromOffset(400, 100),
	Text = "",
	TextColor3 = Theme.Text,
	TextSize = 13,
	TextWrapped = false,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
})

-- O editor fica por cima com texto invisível: o cursor e a seleção
-- aparecem, e o destaque colorido continua ao vivo por baixo.
local Editor = Create("TextBox", CodeScroll, {
	BackgroundTransparency = 1,
	ClearTextOnFocus = false,
	Font = Enum.Font.Code,
	LineHeight = 1.2,
	MultiLine = true,
	Position = UDim2.fromOffset(8, 8),
	Size = UDim2.fromOffset(400, 100),
	Text = "",
	TextColor3 = Theme.Text,
	TextSize = 13,
	TextTransparency = 1,
	TextWrapped = false,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 2,
})

local CopyCodeButton = CreateButton(CodeWindow, "Copiar código", "Copy", true)
CopyCodeButton.AnchorPoint = Vector2.new(0, 1)
CopyCodeButton.Position = UDim2.new(0, 12, 1, -12)
CopyCodeButton.Size = UDim2.fromOffset(140, 32)

local ResetCodeButton = CreateButton(CodeWindow, "Restaurar", nil, false)
ResetCodeButton.AnchorPoint = Vector2.new(0, 1)
ResetCodeButton.Position = UDim2.new(0, 160, 1, -12)
ResetCodeButton.Size = UDim2.fromOffset(100, 32)

local CodeStatus = Create("TextLabel", CodeWindow, {
	AnchorPoint = Vector2.new(1, 1),
	BackgroundTransparency = 1,
	Font = FontRegular,
	Position = UDim2.new(1, -14, 1, -19),
	Size = UDim2.new(1, -290, 0, 18),
	Text = "",
	TextColor3 = Theme.Muted,
	TextSize = 12,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextXAlignment = Enum.TextXAlignment.Right,
})

--------------------------------------------------------------------
-- DESTAQUE DE SINTAXE
--------------------------------------------------------------------
local function EscapeRich(text)
	text = text:gsub("&", "&amp;")
	text = text:gsub("<", "&lt;")
	text = text:gsub(">", "&gt;")
	return text
end

local function Paint(text, color)
	return '<font color="' .. color .. '">' .. EscapeRich(text) .. "</font>"
end

local function HighlightCode(source)
	local result = {}
	local length = #source
	local index = 1

	while index <= length do
		local character = source:sub(index, index)
		local nextCharacter = source:sub(index + 1, index + 1)

		if character == "-" and nextCharacter == "-" then
			local lineEnd = source:find("\n", index, true)

			if lineEnd then
				result[#result + 1] = Paint(source:sub(index, lineEnd - 1), Theme.CodeComment)
				result[#result + 1] = "\n"
				index = lineEnd + 1
			else
				result[#result + 1] = Paint(source:sub(index), Theme.CodeComment)
				break
			end
		elseif character == '"' or character == "'" then
			local finish = index + 1
			local escaped = false

			while finish <= length do
				local current = source:sub(finish, finish)

				if escaped then
					escaped = false
				elseif current == "\\" then
					escaped = true
				elseif current == character or current == "\n" then
					if current == character then
						finish += 1
					end

					break
				end

				finish += 1
			end

			result[#result + 1] = Paint(source:sub(index, finish - 1), Theme.CodeString)
			index = finish
		elseif character:match("[%a_]") then
			local finish = index + 1

			while finish <= length and source:sub(finish, finish):match("[%w_]") do
				finish += 1
			end

			local word = source:sub(index, finish - 1)

			if Keywords[word] then
				result[#result + 1] = Paint(word, Theme.CodeKeyword)
			elseif Builtins[word] then
				result[#result + 1] = Paint(word, Theme.CodeBuiltin)
			else
				result[#result + 1] = EscapeRich(word)
			end

			index = finish
		elseif character:match("%d") or (character == "." and nextCharacter:match("%d")) then
			local finish = index + 1

			while finish <= length and source:sub(finish, finish):match("[%d%.eE]") do
				finish += 1
			end

			result[#result + 1] = Paint(source:sub(index, finish - 1), Theme.CodeNumber)
			index = finish
		else
			result[#result + 1] = EscapeRich(character)
			index += 1
		end
	end

	return table.concat(result)
end

--------------------------------------------------------------------
-- STATUS / CLIPBOARD / FORMATAÇÃO
--------------------------------------------------------------------
local StatusToken = 0

local function SetStatus(text, danger)
	StatusToken += 1
	local token = StatusToken

	StatusLabel.Text = text
	StatusLabel.TextColor3 = danger and Theme.Danger or Theme.Success

	task.delay(2.5, function()
		if token == StatusToken and not Destroyed then
			StatusLabel.Text = ""
		end
	end)
end

local CodeStatusToken = 0

local function SetCodeStatus(text, danger)
	CodeStatusToken += 1
	local token = CodeStatusToken

	CodeStatus.Text = text
	CodeStatus.TextColor3 = danger and Theme.Danger or Theme.Success

	task.delay(2.5, function()
		if token == CodeStatusToken and not Destroyed then
			CodeStatus.Text = ""
		end
	end)
end

local function Copy(text)
	if typeof(Clipboard) ~= "function" then
		return false
	end

	return (pcall(Clipboard, text))
end

local function FormatNumber(number)
	local threshold = 0.5 * 10 ^ -Precision

	if math.abs(number) < threshold then
		number = 0
	end

	return string.format("%." .. Precision .. "f", number)
end

local function FormatVector(position)
	return string.format(
		"%s, %s, %s",
		FormatNumber(position.X),
		FormatNumber(position.Y),
		FormatNumber(position.Z)
	)
end

local function MakeLine(name, position)
	return string.format("    [%q] = Vector3.new(%s),", name, FormatVector(position))
end

local function GenerateCode()
	local lines = { "local Locates = {" }

	for _, data in ipairs(Positions) do
		lines[#lines + 1] = MakeLine(data.Name, data.Position)
	end

	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "return Locates"

	GeneratedCode = table.concat(lines, "\n")
	return GeneratedCode
end

--------------------------------------------------------------------
-- EDITOR
--------------------------------------------------------------------
local function CountLines(text)
	local count = 1

	for _ in text:gmatch("\n") do
		count += 1
	end

	return count
end

local function UpdateEditor()
	local text = Editor.Text
	local count = CountLines(text)
	local numbers = table.create(count)

	for index = 1, count do
		numbers[index] = tostring(index)
	end

	LineNumbers.Text = table.concat(numbers, "\n")
	Highlight.Text = HighlightCode(text)

	local bounds = Editor.TextBounds
	local width = math.max(CodeScroll.AbsoluteSize.X, bounds.X + 32)
	local height = math.max(CodeScroll.AbsoluteSize.Y, bounds.Y + 24)

	CodeScroll.CanvasSize = UDim2.fromOffset(width, height)
	Editor.Size = UDim2.fromOffset(width - 16, height - 16)
	Highlight.Size = Editor.Size
	LineNumbers.Size = UDim2.new(1, 0, 0, height)
end

--------------------------------------------------------------------
-- LISTA DE POSIÇÕES
--------------------------------------------------------------------
local function RebuildIndex()
	table.clear(PositionIndex)

	for index, data in ipairs(Positions) do
		PositionIndex[data.Name] = index
	end
end

local function SetGeneratedCode()
	Editor.Text = GenerateCode()
	UpdateEditor()
end

local RefreshList

local function RemoveAt(index)
	table.remove(Positions, index)
	RebuildIndex()
	SetGeneratedCode()
	RefreshList()
	SetStatus("Posição removida.")
end

function RefreshList()
	for _, child in ipairs(ListFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	CountLabel.Text = "SALVOS · " .. #Positions
	EmptyLabel.Visible = #Positions == 0

	for index, data in ipairs(Positions) do
		local row = Create("TextButton", ListFrame, {
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Surface2,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 32),
			Text = "",
		})

		Round(row, 6)

		Create("TextLabel", row, {
			BackgroundTransparency = 1,
			Font = FontMedium,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(0.4, -8, 1, 0),
			Text = data.Name,
			TextColor3 = Theme.Text,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
		})

		Create("TextLabel", row, {
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			Position = UDim2.new(0.4, 0, 0, 0),
			Size = UDim2.new(0.6, -36, 1, 0),
			Text = FormatVector(data.Position),
			TextColor3 = Theme.Muted,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Right,
		})

		local remove = CreateIconButton(row, "Close", Theme.Muted)
		remove.AnchorPoint = Vector2.new(1, 0.5)
		remove.Position = UDim2.new(1, -2, 0.5, 0)
		remove.Size = UDim2.fromOffset(26, 26)

		Connect(row.MouseEnter, function()
			Tween(row, { BackgroundTransparency = 0 })
		end)

		Connect(row.MouseLeave, function()
			Tween(row, { BackgroundTransparency = 1 })
		end)

		Connect(row.Activated, function()
			if Copy(MakeLine(data.Name, data.Position)) then
				SetStatus("Linha copiada.")
			else
				SetStatus("Clipboard indisponível.", true)
			end
		end)

		Connect(remove.Activated, function()
			RemoveAt(index)
		end)
	end
end

--------------------------------------------------------------------
-- AÇÕES
--------------------------------------------------------------------
local function GetCurrentPosition()
	local character = Player.Character

	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")

	if not root then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		root = humanoid and humanoid.RootPart
	end

	return root and root.Position or nil
end

local function SavePosition()
	local name = NameBox.Text:match("^%s*(.-)%s*$")

	if not name or name == "" then
		SetStatus("Digite um nome.", true)
		return
	end

	local position = GetCurrentPosition()

	if not position then
		SetStatus("Personagem não encontrado.", true)
		return
	end

	local index = PositionIndex[name]

	if index then
		Positions[index].Position = position
	else
		Positions[#Positions + 1] = { Name = name, Position = position }
		PositionIndex[name] = #Positions
	end

	SetGeneratedCode()
	RefreshList()

	local copied = Copy(MakeLine(name, position))

	if index then
		SetStatus(copied and "Atualizada e copiada." or "Posição atualizada.")
	else
		SetStatus(copied and "Salva e copiada." or "Posição salva.")
	end

	ListFrame.CanvasPosition = Vector2.new(0, math.huge)
end

--------------------------------------------------------------------
-- ARRASTAR JANELAS
--------------------------------------------------------------------
local Drag = { Frame = nil, Input = nil, Start = nil, Position = nil }

local function StartDrag(frame, input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch
	then
		return
	end

	Drag.Frame = frame
	Drag.Input = input
	Drag.Start = input.Position
	Drag.Position = frame.Position
end

Connect(Header.InputBegan, function(input)
	StartDrag(Main, input)
end)

Connect(CodeHeader.InputBegan, function(input)
	StartDrag(CodeWindow, input)
end)

Connect(UserInputService.InputChanged, function(input)
	if not Drag.Frame then
		return
	end

	if Drag.Input.UserInputType == Enum.UserInputType.Touch then
		if input ~= Drag.Input then
			return
		end
	elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end

	local delta = input.Position - Drag.Start

	Drag.Frame.Position = UDim2.new(
		Drag.Position.X.Scale,
		Drag.Position.X.Offset + delta.X,
		Drag.Position.Y.Scale,
		Drag.Position.Y.Offset + delta.Y
	)
end)

Connect(UserInputService.InputEnded, function(input)
	if not Drag.Frame then
		return
	end

	if Drag.Input.UserInputType == Enum.UserInputType.Touch then
		if input ~= Drag.Input then
			return
		end
	elseif input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	Drag.Frame = nil
	Drag.Input = nil
end)

--------------------------------------------------------------------
-- TAMANHO RESPONSIVO
--------------------------------------------------------------------
local function ApplySizing()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)

	local mainWidth = math.min(360, math.max(240, viewport.X - 20))
	local codeWidth = math.min(520, math.max(240, viewport.X - 20))
	local codeHeight = math.min(360, math.max(200, viewport.Y - 40))

	Tween(Main, {
		Size = UDim2.fromOffset(mainWidth, Minimized and HEADER_HEIGHT or MAIN_HEIGHT),
	}, 0.18)

	CodeWindow.Size = UDim2.fromOffset(codeWidth, codeHeight)
	UpdateEditor()
end

--------------------------------------------------------------------
-- EVENTOS
--------------------------------------------------------------------
Connect(SaveButton.Activated, SavePosition)

Connect(NameBox.FocusLost, function(enterPressed)
	if enterPressed then
		SavePosition()
	end
end)

for value, button in pairs(PrecisionButtons) do
	Connect(button.Activated, function()
		Precision = value
		RefreshPrecision()
		SetGeneratedCode()
		RefreshList()
	end)
end

Connect(CodeButton.Activated, function()
	CodeWindow.Visible = not CodeWindow.Visible
	UpdateEditor()
end)

Connect(CodeClose.Activated, function()
	CodeWindow.Visible = false
end)

Connect(CopyCodeButton.Activated, function()
	if Copy(Editor.Text) then
		SetCodeStatus("Código copiado.")
	else
		SetCodeStatus("Clipboard indisponível.", true)
	end
end)

Connect(ResetCodeButton.Activated, function()
	Editor.Text = GeneratedCode
	UpdateEditor()
	SetCodeStatus("Texto restaurado.")
end)

Connect(Editor:GetPropertyChangedSignal("Text"), UpdateEditor)

Connect(CodeScroll:GetPropertyChangedSignal("CanvasPosition"), function()
	LineNumbers.Position = UDim2.fromOffset(0, -CodeScroll.CanvasPosition.Y)
end)

Connect(CodeScroll:GetPropertyChangedSignal("AbsoluteSize"), UpdateEditor)

Connect(MinimizeButton.Activated, function()
	Minimized = not Minimized
	Content.Visible = not Minimized

	if Minimized then
		CodeWindow.Visible = false
	end

	for _, child in ipairs(MinimizeButton:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	MinimizeIcon = MakeIcon(Minimized and "Restore" or "Minimize", MinimizeButton, Theme.Muted, Theme.Surface)
	ApplySizing()
end)

local function Cleanup()
	if Destroyed then
		return
	end

	Destroyed = true

	for _, connection in ipairs(Connections) do
		connection:Disconnect()
	end

	table.clear(Connections)
end

Connect(CloseButton.Activated, function()
	Cleanup()
	Screen:Destroy()
end)

Connect(Screen.Destroying, Cleanup)

local Camera = workspace.CurrentCamera

if Camera then
	Connect(Camera:GetPropertyChangedSignal("ViewportSize"), ApplySizing)
end

RefreshPrecision()
SetGeneratedCode()
RefreshList()
ApplySizing()
