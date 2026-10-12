--!strict
-- Панель квестов: три бесплатных задания в ряд сверху, батл-пасс снизу.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

local Hub = require(script.Parent:WaitForChild("Hub"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local player = Players.LocalPlayer

local CREAM = Color3.fromRGB(236, 228, 214)
local INK = Color3.fromRGB(42, 36, 32)
local LINE = Color3.fromRGB(48, 42, 38)
local GOLD = Color3.fromRGB(186, 154, 96)

local ACCENT: { [string]: Color3 } = {
	parkour = Color3.fromRGB(78, 122, 104),
	wins = Color3.fromRGB(166, 116, 74),
	shields = Color3.fromRGB(74, 110, 148),
	dashes = Color3.fromRGB(150, 92, 88),
	coins = Color3.fromRGB(156, 136, 82),
}

type Row = {
	id: string,
	kind: string?,
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
dim.BackgroundTransparency = 0.42
dim.Text = ""
dim.AutoButtonColor = false
dim.BorderSizePixel = 0
dim.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 108)
panel.Size = UDim2.new(0.86, 0, 1, -120)
panel.BackgroundColor3 = Color3.fromRGB(32, 30, 36)
panel.BorderSizePixel = 0
panel.Active = true
panel.ClipsDescendants = true
panel.Parent = dim
local panelCap = Instance.new("UISizeConstraint")
panelCap.MaxSize = Vector2.new(1400, 820)
panelCap.Parent = panel
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 22)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = LINE
panelStroke.Thickness = 2.5
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(22, 12)
title.Size = UDim2.new(1, -80, 0, 32)
title.Font = Enum.Font.GothamBlack
title.TextSize = 28
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = CREAM
title.Text = Locale.t("Quests")
title.Parent = panel

local closeLip = Instance.new("Frame")
closeLip.AnchorPoint = Vector2.new(1, 0)
closeLip.Position = UDim2.new(1, -16, 0, 18)
closeLip.Size = UDim2.fromOffset(36, 36)
closeLip.BackgroundColor3 = Color3.fromRGB(110, 58, 54)
closeLip.BorderSizePixel = 0
closeLip.Parent = panel
local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -16, 0, 14)
close.Size = UDim2.fromOffset(36, 36)
close.BackgroundColor3 = Color3.fromRGB(150, 84, 78)
close.Font = Enum.Font.GothamBlack
close.TextSize = 18
close.TextColor3 = CREAM
close.Text = "×"
close.BorderSizePixel = 0
close.Parent = panel
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 10)
closeCorner.Parent = close
local closeLipCorner = Instance.new("UICorner")
closeLipCorner.CornerRadius = UDim.new(0, 10)
closeLipCorner.Parent = closeLip
local closeStroke = Instance.new("UIStroke")
closeStroke.Color = LINE
closeStroke.Thickness = 2.5
closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
closeStroke.Parent = close

local notice = Instance.new("TextLabel")
notice.BackgroundTransparency = 1
notice.Position = UDim2.fromOffset(22, 44)
notice.Size = UDim2.new(1, -180, 0, 18)
notice.Font = Enum.Font.Gotham
notice.TextSize = 14
notice.TextXAlignment = Enum.TextXAlignment.Left
notice.TextTruncate = Enum.TextTruncate.AtEnd
notice.TextColor3 = CREAM
notice.Text = ""
notice.Parent = panel

local dailyCaption = Instance.new("TextLabel")
dailyCaption.BackgroundTransparency = 1
dailyCaption.Position = UDim2.fromOffset(22, 48)
dailyCaption.Size = UDim2.new(0.5, 0, 0, 22)
dailyCaption.Font = Enum.Font.GothamBlack
dailyCaption.TextSize = 18
dailyCaption.TextXAlignment = Enum.TextXAlignment.Left
dailyCaption.TextColor3 = CREAM
dailyCaption.Text = Locale.t("Free")
dailyCaption.Parent = panel

local dailyHint = Instance.new("TextLabel")
dailyHint.BackgroundTransparency = 1
dailyHint.AnchorPoint = Vector2.new(1, 0)
dailyHint.Position = UDim2.new(1, -22, 0, 48)
dailyHint.Size = UDim2.new(0.5, -20, 0, 22)
dailyHint.Font = Enum.Font.Gotham
dailyHint.TextSize = 14
dailyHint.TextXAlignment = Enum.TextXAlignment.Right
dailyHint.TextColor3 = Color3.fromRGB(210, 206, 196)
dailyHint.Text = Locale.t("Tap Take, then do it")
dailyHint.Parent = panel

local column = Instance.new("Frame")
column.Name = "Column"
column.BackgroundTransparency = 1
column.Position = UDim2.fromOffset(18, 68)
column.Size = UDim2.new(1, -36, 1, -80)
column.Parent = panel
local columnLayout = Instance.new("UIListLayout")
columnLayout.FillDirection = Enum.FillDirection.Vertical
columnLayout.Padding = UDim.new(0, 8)
columnLayout.SortOrder = Enum.SortOrder.LayoutOrder
columnLayout.Parent = column

local dailyRow = Instance.new("Frame")
dailyRow.BackgroundTransparency = 1
dailyRow.Size = UDim2.new(1, 0, 0.5, -32)
dailyRow.LayoutOrder = 1
dailyRow.Parent = column
local dailyLayout = Instance.new("UIListLayout")
dailyLayout.FillDirection = Enum.FillDirection.Horizontal
dailyLayout.Padding = UDim.new(0, 12)
dailyLayout.SortOrder = Enum.SortOrder.LayoutOrder
dailyLayout.Parent = dailyRow

local mid = Instance.new("Frame")
mid.Name = "PassHead"
mid.BackgroundTransparency = 1
mid.Size = UDim2.new(1, 0, 0, 48)
mid.LayoutOrder = 2
mid.Parent = column

local divider = Instance.new("Frame")
divider.Position = UDim2.fromOffset(4, 0)
divider.Size = UDim2.new(1, -8, 0, 4)
divider.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
divider.BorderSizePixel = 0
divider.Parent = mid

local passCaption = Instance.new("TextLabel")
passCaption.BackgroundTransparency = 1
passCaption.Position = UDim2.fromOffset(4, 14)
passCaption.Size = UDim2.new(1, -230, 0, 36)
passCaption.Font = Enum.Font.GothamBlack
passCaption.TextSize = 20
passCaption.TextXAlignment = Enum.TextXAlignment.Left
passCaption.TextYAlignment = Enum.TextYAlignment.Center
passCaption.TextColor3 = CREAM
passCaption.Text = Locale.t("Battle Pass")
passCaption.Parent = mid

local buyLip = Instance.new("Frame")
buyLip.AnchorPoint = Vector2.new(1, 0)
buyLip.Position = UDim2.new(1, -4, 0, 12)
buyLip.Size = UDim2.fromOffset(210, 36)
buyLip.BackgroundColor3 = Color3.fromRGB(120, 96, 58)
buyLip.BorderSizePixel = 0
buyLip.Parent = mid
local buy = Instance.new("TextButton")
buy.AnchorPoint = Vector2.new(1, 0)
buy.Position = UDim2.new(1, -4, 0, 8)
buy.Size = UDim2.fromOffset(210, 36)
buy.BackgroundColor3 = GOLD
buy.Font = Enum.Font.GothamBlack
buy.TextSize = 20
buy.TextColor3 = INK
buy.TextStrokeTransparency = 1
buy.Text = Locale.fmt("Buy  %d R$", 300)
buy.BorderSizePixel = 0
buy.Parent = mid
local buyCorner = Instance.new("UICorner")
buyCorner.CornerRadius = UDim.new(0, 10)
buyCorner.Parent = buy
local buyLipCorner = Instance.new("UICorner")
buyLipCorner.CornerRadius = UDim.new(0, 10)
buyLipCorner.Parent = buyLip
local buyStroke = Instance.new("UIStroke")
buyStroke.Color = LINE
buyStroke.Thickness = 2.5
buyStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
buyStroke.Parent = buy

local passRow = Instance.new("Frame")
passRow.BackgroundTransparency = 1
passRow.Size = UDim2.new(1, 0, 0.5, -32)
passRow.LayoutOrder = 3
passRow.Parent = column
local passLayout = Instance.new("UIListLayout")
passLayout.FillDirection = Enum.FillDirection.Horizontal
passLayout.Padding = UDim.new(0, 12)
passLayout.SortOrder = Enum.SortOrder.LayoutOrder
passLayout.Parent = passRow

local remote = Remotes.get("Quests")

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function outline(parent: Instance, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = LINE
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

local function accentOf(row: Row): Color3
	local kind = row.kind
	if typeof(kind) ~= "string" then
		kind = "wins"
	end
	return ACCENT[kind] or GOLD
end

local function buttonText(action: string): string
	if action == "take" then
		return Locale.t("Take")
	elseif action == "claim" or action == "claimBp" then
		return Locale.t("Claim")
	elseif action == "done" then
		return Locale.t("Done")
	elseif action == "lock" then
		return Locale.t("Locked")
	end
	return Locale.t("Doing")
end

local function clear(frame: Frame)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function stackLabel(parent: Instance, text: string, font: Enum.Font, size: number, order: number, transparency: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, size + 2)
	label.Font = font
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextColor3 = CREAM
	label.TextTransparency = transparency
	label.LayoutOrder = order
	label.Text = text
	label.Parent = parent
	return label
end

local function addCard(parent: Frame, row: Row, order: number, count: number, _paid: boolean)
	local accent = accentOf(row)
	local slots = math.max(count, 1)
	local gap = 12
	local slot = Instance.new("Frame")
	slot.LayoutOrder = order
	slot.BackgroundTransparency = 1
	slot.Size = UDim2.new(1 / slots, -math.ceil(gap * (slots - 1) / slots), 1, 0)
	slot.Parent = parent

	local plate = Instance.new("Frame")
	plate.Position = UDim2.fromOffset(0, 4)
	plate.Size = UDim2.new(1, 0, 1, -4)
	plate.BackgroundColor3 = accent:Lerp(INK, 0.45)
	plate.BorderSizePixel = 0
	plate.Parent = slot
	corner(plate, 12)
	outline(plate, 2)

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 1, -4)
	card.BackgroundColor3 = accent
	card.BorderSizePixel = 0
	card.Parent = slot
	corner(card, 12)
	outline(card, 2)

	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = body
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.Parent = body

	stackLabel(body, Locale.translate(row.name), Enum.Font.GothamBlack, 18, 1, 0)
	stackLabel(body, Locale.translate(row.detail), Enum.Font.Gotham, 14, 2, 0.08)
	stackLabel(body, Locale.t("Prize: ") .. Locale.translate(row.reward), Enum.Font.GothamBold, 15, 3, 0)

	local goal = math.max(1, row.goal)
	local progressRow = Instance.new("Frame")
	progressRow.BackgroundTransparency = 1
	progressRow.Size = UDim2.new(1, 0, 0, 20)
	progressRow.LayoutOrder = 4
	progressRow.Parent = body
	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 0, 0.5, -4)
	track.Size = UDim2.new(1, -72, 0, 10)
	track.BackgroundColor3 = INK
	track.BackgroundTransparency = 0.45
	track.BorderSizePixel = 0
	track.Parent = progressRow
	corner(track, 4)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(row.progress / goal, 0, 1), 1)
	fill.BackgroundColor3 = CREAM
	fill.BackgroundTransparency = 0.15
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, 4)
	local progress = Instance.new("TextLabel")
	progress.BackgroundTransparency = 1
	progress.AnchorPoint = Vector2.new(1, 0.5)
	progress.Position = UDim2.new(1, 0, 0.5, 0)
	progress.Size = UDim2.fromOffset(64, 20)
	progress.Font = Enum.Font.GothamBold
	progress.TextSize = 14
	progress.TextXAlignment = Enum.TextXAlignment.Right
	progress.TextColor3 = CREAM
	progress.Text = Locale.fmt("%d of %d", math.min(row.progress, goal), goal)
	progress.Parent = progressRow

	local clickable = row.action == "take" or row.action == "claim" or row.action == "claimBp"
	local face = CREAM
	local buttonInk = INK
	if row.action == "wait" then
		face = accent:Lerp(CREAM, 0.55)
		buttonInk = INK
	elseif row.action == "done" then
		face = Color3.fromRGB(196, 214, 196)
	end

	local buttonSlot = Instance.new("Frame")
	buttonSlot.BackgroundTransparency = 1
	buttonSlot.Size = UDim2.new(1, 0, 0, 34)
	buttonSlot.LayoutOrder = 5
	buttonSlot.Parent = body
	local buttonLip = Instance.new("Frame")
	buttonLip.Position = UDim2.fromOffset(0, 3)
	buttonLip.Size = UDim2.new(1, 0, 0, 30)
	buttonLip.BackgroundColor3 = accent:Lerp(INK, 0.35)
	buttonLip.BorderSizePixel = 0
	buttonLip.Parent = buttonSlot
	corner(buttonLip, 8)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 30)
	button.BackgroundColor3 = face
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 16
	button.TextColor3 = buttonInk
	button.Text = buttonText(row.action)
	button.AutoButtonColor = clickable
	button.Active = clickable
	button.BorderSizePixel = 0
	button.Parent = buttonSlot
	corner(button, 8)
	outline(button, 2)
	button.MouseButton1Click:Connect(function()
		if clickable then
			remote:FireServer(row.action, row.id)
		end
	end)
end

local function render()
	clear(dailyRow)
	clear(passRow)
	local data = state
	if not data then
		notice.Text = Locale.t("Loading quests…")
		return
	end
	notice.Text = ""
	if data.notice ~= "" then
		dailyHint.Text = Locale.translate(data.notice)
	else
		dailyHint.Text = Locale.t("Tap Take, then do it")
	end
	passCaption.Text = if data.owned then Locale.t("Battle Pass unlocked") else Locale.t("Battle Pass — big prizes")
	buy.Text = if data.owned then Locale.t("Unlocked") else Locale.fmt("Buy  %d R$", data.price)
	buy.TextSize = if data.owned then 18 else 20
	buy.BackgroundColor3 = if data.owned then Color3.fromRGB(96, 140, 112) else GOLD
	buy.TextColor3 = INK
	buyLip.BackgroundColor3 = if data.owned then Color3.fromRGB(58, 90, 72) else Color3.fromRGB(120, 96, 58)
	buy.AutoButtonColor = not data.owned
	buy.Active = not data.owned
	for index, row in data.daily do
		addCard(dailyRow, row, index, #data.daily, false)
	end
	for index, row in data.pass do
		addCard(passRow, row, index, #data.pass, true)
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

local function present(on: boolean)
	setOpen(on)
end

Hub.bind("quests", present)

buy.MouseButton1Click:Connect(function()
	if state and not state.owned then
		remote:FireServer("robux")
	end
end)
dim.MouseButton1Click:Connect(function()
	Hub.close()
end)
close.MouseButton1Click:Connect(function()
	Hub.close()
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
			if who == player and player:GetAttribute("InMatch") == nil then
				Hub.show("quests")
			end
		end)
	end
end)

return {}
