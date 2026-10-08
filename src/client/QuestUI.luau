--!strict
-- Панель квестов: три бесплатных задания дня и батл-пасс ниже.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local player = Players.LocalPlayer

local WHITE = Color3.fromRGB(244, 240, 255)
local MUTED = Color3.fromRGB(168, 160, 188)
local GOLD = Color3.fromRGB(255, 206, 84)
local GREEN = Color3.fromRGB(88, 206, 138)
local BLUE = Color3.fromRGB(88, 140, 255)
local INK = Color3.fromRGB(22, 20, 30)
local CARD = Color3.fromRGB(32, 29, 42)
local LINE = Color3.fromRGB(72, 66, 88)

type Row = {
	id: string,
	name: string,
	detail: string,
	goal: number,
	progress: number,
	claimed: boolean,
	reward: string,
	action: string,
}

type Payload = {
	daily: { Row },
	pass: { Row },
	owned: boolean,
	price: number,
	notice: string,
}

local open = false
local prompt: ProximityPrompt? = nil
local state: Payload? = nil

local gui = Instance.new("ScreenGui")
gui.Name = "ColorPartyQuests"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 38
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local dim = Instance.new("TextButton")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.45
dim.Text = ""
dim.AutoButtonColor = false
dim.BorderSizePixel = 0
dim.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(620, 640)
panel.BackgroundColor3 = INK
	panel.BorderSizePixel = 0
	panel.Active = true
	panel.Parent = dim
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 18)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = GOLD
panelStroke.Transparency = 0.4
panelStroke.Thickness = 1.5
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(24, 16)
title.Size = UDim2.new(1, -80, 0, 36)
title.Font = Enum.Font.GothamBlack
title.TextSize = 28
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = WHITE
title.Text = "Квесты"
title.Parent = panel

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -16, 0, 16)
close.Size = UDim2.fromOffset(36, 36)
close.BackgroundColor3 = CARD
close.Font = Enum.Font.GothamBold
close.TextSize = 18
close.TextColor3 = WHITE
close.Text = "×"
close.BorderSizePixel = 0
close.Parent = panel
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = close

local notice = Instance.new("TextLabel")
notice.BackgroundTransparency = 1
notice.Position = UDim2.fromOffset(24, 52)
notice.Size = UDim2.new(1, -48, 0, 22)
notice.Font = Enum.Font.Gotham
notice.TextSize = 15
notice.TextXAlignment = Enum.TextXAlignment.Left
notice.TextColor3 = GOLD
notice.Text = ""
notice.Parent = panel

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(16, 82)
scroll.Size = UDim2.new(1, -32, 1, -98)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = GOLD
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 8)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = scroll
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 4)
pad.PaddingBottom = UDim.new(0, 12)
pad.PaddingLeft = UDim.new(0, 4)
pad.PaddingRight = UDim.new(0, 8)
pad.Parent = scroll

local remote = Remotes.get("Quests")

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function label(parent: Instance, text: string, size: number, color: Color3, height: number, order: number): TextLabel
	local row = Instance.new("TextLabel")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, height)
	row.Font = Enum.Font.GothamBold
	row.TextSize = size
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextColor3 = color
	row.Text = text
	row.LayoutOrder = order
	row.Parent = parent
	return row
end

local function buttonText(action: string): string
	if action == "take" then
		return "Взять"
	elseif action == "claim" or action == "claimBp" then
		return "Забрать"
	elseif action == "done" then
		return "Готово"
	elseif action == "lock" then
		return "Пасс"
	end
	return "Идёт"
end

local function buttonColor(action: string): Color3
	if action == "take" then
		return BLUE
	elseif action == "claim" or action == "claimBp" then
		return GOLD
	end
	return LINE
end

local function addCard(row: Row, order: number)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 96)
	card.BackgroundColor3 = CARD
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.Parent = scroll
	corner(card, 12)

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(14, 10)
	name.Size = UDim2.new(1, -150, 0, 22)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 18
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = WHITE
	name.Text = row.name
	name.Parent = card

	local detail = Instance.new("TextLabel")
	detail.BackgroundTransparency = 1
	detail.Position = UDim2.fromOffset(14, 32)
	detail.Size = UDim2.new(1, -150, 0, 18)
	detail.Font = Enum.Font.Gotham
	detail.TextSize = 14
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextColor3 = MUTED
	detail.Text = row.detail
	detail.Parent = card

	local reward = Instance.new("TextLabel")
	reward.BackgroundTransparency = 1
	reward.Position = UDim2.fromOffset(14, 68)
	reward.Size = UDim2.new(1, -150, 0, 18)
	reward.Font = Enum.Font.GothamBold
	reward.TextSize = 14
	reward.TextXAlignment = Enum.TextXAlignment.Left
	reward.TextColor3 = GOLD
	reward.Text = row.reward
	reward.Parent = card

	local goal = math.max(1, row.goal)
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromOffset(14, 54)
	bar.Size = UDim2.new(1, -164, 0, 8)
	bar.BackgroundColor3 = LINE
	bar.BorderSizePixel = 0
	bar.Parent = card
	corner(bar, 4)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(row.progress / goal, 0, 1), 1)
	fill.BackgroundColor3 = if row.claimed then GREEN else GOLD
	fill.BorderSizePixel = 0
	fill.Parent = bar
	corner(fill, 4)

	local count = Instance.new("TextLabel")
	count.BackgroundTransparency = 1
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -118, 0, 48)
	count.Size = UDim2.fromOffset(48, 18)
	count.Font = Enum.Font.Gotham
	count.TextSize = 13
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.TextColor3 = MUTED
	count.Text = tostring(math.min(row.progress, goal)) .. "/" .. tostring(goal)
	count.Parent = card

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -12, 0.5, 0)
	button.Size = UDim2.fromOffset(108, 36)
	button.BackgroundColor3 = buttonColor(row.action)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.TextColor3 = if row.action == "claim" or row.action == "claimBp" then INK else WHITE
	button.Text = buttonText(row.action)
	button.AutoButtonColor = row.action == "take" or row.action == "claim" or row.action == "claimBp"
	button.Active = button.AutoButtonColor
	button.BorderSizePixel = 0
	button.Parent = card
	corner(button, 10)
	button.MouseButton1Click:Connect(function()
		if row.action == "take" or row.action == "claim" or row.action == "claimBp" then
			remote:FireServer(row.action, row.id)
		end
	end)
end

local function render()
	for _, child in scroll:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	local data = state
	if not data then
		label(scroll, "Задания загружаются…", 16, MUTED, 28, 1)
		return
	end
	notice.Text = data.notice
	label(scroll, "Сегодня бесплатно", 16, WHITE, 24, 1)
	label(scroll, "Три задания в день. Возьми их, потом выполни.", 14, MUTED, 20, 2).Font = Enum.Font.Gotham
	local order = 3
	for _, row in data.daily do
		addCard(row, order)
		order += 1
	end

	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(1, 0, 0, 2)
	divider.BackgroundColor3 = GOLD
	divider.BackgroundTransparency = 0.35
	divider.BorderSizePixel = 0
	divider.LayoutOrder = order
	divider.Parent = scroll
	order += 1

	local head = Instance.new("Frame")
	head.Size = UDim2.new(1, 0, 0, 40)
	head.BackgroundTransparency = 1
	head.LayoutOrder = order
	head.Parent = scroll
	order += 1
	local passTitle = Instance.new("TextLabel")
	passTitle.BackgroundTransparency = 1
	passTitle.Size = UDim2.new(1, -180, 1, 0)
	passTitle.Font = Enum.Font.GothamBlack
	passTitle.TextSize = 20
	passTitle.TextXAlignment = Enum.TextXAlignment.Left
	passTitle.TextColor3 = GOLD
	passTitle.Text = if data.owned then "Батл-пасс открыт" else "Батл-пасс"
	passTitle.Parent = head
	local buy = Instance.new("TextButton")
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, 0, 0.5, 0)
	buy.Size = UDim2.fromOffset(168, 34)
	buy.BackgroundColor3 = if data.owned then GREEN else GOLD
	buy.Font = Enum.Font.GothamBold
	buy.TextSize = 15
	buy.TextColor3 = INK
	buy.Text = if data.owned then "Открыт" else tostring(data.price) .. " R$"
	buy.AutoButtonColor = not data.owned
	buy.Active = not data.owned
	buy.BorderSizePixel = 0
	buy.Parent = head
	corner(buy, 10)
	buy.MouseButton1Click:Connect(function()
		if not data.owned then
			remote:FireServer("robux")
		end
	end)

	label(scroll, "Те же дела, только награды — скины и плюшки.", 14, MUTED, 20, order).Font = Enum.Font.Gotham
	order += 1
	for _, row in data.pass do
		addCard(row, order)
		order += 1
	end
end

local function setOpen(on: boolean)
	open = on
	gui.Enabled = on
	if prompt then
		prompt.Enabled = not on
	end
	if on then
		render()
		remote:FireServer("state")
	end
end

dim.MouseButton1Click:Connect(function()
	setOpen(false)
end)
close.MouseButton1Click:Connect(function()
	setOpen(false)
end)

Remotes.get("QuestState").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	state = payload :: Payload
	if open then
		render()
	end
end)

task.spawn(function()
	local world = workspace:WaitForChild("World", 60)
	local lobby = world and world:WaitForChild("Lobby", 30)
	local podiums = lobby and lobby:WaitForChild("Podiums", 30)
	local podium = podiums and podiums:WaitForChild("Quest", 30)
	if not podium then
		return
	end
	local found = podium:FindFirstChild("QuestPrompt", true)
	local started = os.clock()
	while not found and os.clock() - started < 20 do
		task.wait(0.5)
		found = podium:FindFirstChild("QuestPrompt", true)
	end
	if found and found:IsA("ProximityPrompt") then
		prompt = found
		found.Triggered:Connect(function(who)
			if who == player then
				setOpen(true)
			end
		end)
	end
end)

return {}
