--!strict
-- Колесо фортуны: горизонтальная лента, как открытие кейса, и список призов ниже.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Shop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Shop"))
local Skins = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Skins"))
local Wheel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Wheel"))

local player = Players.LocalPlayer

local WHITE = Color3.fromRGB(244, 240, 255)
local MUTED = Color3.fromRGB(168, 160, 188)
local GOLD = Color3.fromRGB(255, 206, 84)
local GREEN = Color3.fromRGB(88, 206, 138)
local BLUE = Color3.fromRGB(88, 140, 255)
local INK = Color3.fromRGB(22, 20, 30)
local CARD = Color3.fromRGB(32, 29, 42)
local LINE = Color3.fromRGB(72, 66, 88)
local COIN_ICON = "rbxthumb://type=Asset&id=67225889&w=150&h=150"

local CELL = 188
local GAP = 10

local open = false
local spinning = false
local prompt: ProximityPrompt? = nil
local free = true
local coins = 0
local queued: { [string]: any }? = nil

local function money(amount: number): string
	local digits = tostring(math.floor(amount))
	local reversed = string.reverse(digits)
	local grouped = string.gsub(reversed, "(%d%d%d)", "%1 ")
	local pretty = string.reverse(grouped)
	return (string.gsub(pretty, "^ ", ""))
end

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function circle(parent: Instance)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(1, 0)
	ui.Parent = parent
end

local gui = Instance.new("ScreenGui")
gui.Name = "ColorPartyWheel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 37
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
panel.Size = UDim2.fromScale(0.78, 0.86)
panel.BackgroundColor3 = INK
panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Parent = gui
corner(panel, 22)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(920, 820)
limit.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 206, 120)
stroke.Transparency = 0.55
stroke.Thickness = 1.5
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(22, 14)
title.Size = UDim2.new(0.5, 0, 0, 32)
title.Font = Enum.Font.GothamBlack
title.TextSize = 24
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = WHITE
title.Text = "Колесо фортуны"
title.Parent = panel

local coinPill = Instance.new("Frame")
coinPill.AnchorPoint = Vector2.new(1, 0)
coinPill.Position = UDim2.new(1, -58, 0, 14)
coinPill.Size = UDim2.fromOffset(148, 32)
coinPill.BackgroundColor3 = Color3.fromRGB(32, 28, 44)
coinPill.Parent = panel
corner(coinPill, 10)
local coinImage = Instance.new("ImageLabel")
coinImage.BackgroundTransparency = 1
coinImage.Position = UDim2.fromOffset(8, 4)
coinImage.Size = UDim2.fromOffset(24, 24)
coinImage.Image = COIN_ICON
coinImage.ScaleType = Enum.ScaleType.Fit
coinImage.Parent = coinPill
local coinLabel = Instance.new("TextLabel")
coinLabel.BackgroundTransparency = 1
coinLabel.Position = UDim2.fromOffset(36, 0)
coinLabel.Size = UDim2.new(1, -42, 1, 0)
coinLabel.Font = Enum.Font.GothamBold
coinLabel.TextSize = 15
coinLabel.TextXAlignment = Enum.TextXAlignment.Left
coinLabel.TextColor3 = GOLD
coinLabel.Text = "0"
coinLabel.Parent = coinPill

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -14, 0, 14)
close.Size = UDim2.fromOffset(34, 34)
close.BackgroundColor3 = Color3.fromRGB(48, 42, 64)
close.Font = Enum.Font.GothamBold
close.TextSize = 18
close.TextColor3 = WHITE
close.Text = "×"
close.Parent = panel
corner(close, 10)

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(14, 58)
scroll.Size = UDim2.new(1, -28, 1, -136)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5
scroll.ScrollBarImageColor3 = Color3.fromRGB(120, 108, 150)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.Parent = panel

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -8, 0, 0)
content.AutomaticSize = Enum.AutomaticSize.Y
content.BackgroundTransparency = 1
content.Parent = scroll
local flow = Instance.new("UIListLayout")
flow.Padding = UDim.new(0, 14)
flow.SortOrder = Enum.SortOrder.LayoutOrder
flow.Parent = content

local CARD_W = 116
local STEP = 132
local REEL_COUNT = 46
local WIN_AT = 38

local wheelHold = Instance.new("Frame")
wheelHold.LayoutOrder = 1
wheelHold.Size = UDim2.new(1, 0, 0, 168)
wheelHold.BackgroundTransparency = 1
wheelHold.Parent = content

local reel = Instance.new("Frame")
reel.Size = UDim2.new(1, 0, 1, 0)
reel.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
reel.BorderSizePixel = 0
reel.ClipsDescendants = true
reel.Parent = wheelHold
corner(reel, 16)
local reelStroke = Instance.new("UIStroke")
reelStroke.Color = LINE
reelStroke.Thickness = 1.5
reelStroke.Parent = reel

local strip = Instance.new("Frame")
strip.BackgroundTransparency = 1
strip.Size = UDim2.fromOffset(REEL_COUNT * STEP, 168)
strip.Parent = reel

local function paintMark(parent: Instance, mark: string, big: boolean)
	local badge = Instance.new("TextLabel")
	badge.Name = "Mark"
	badge.BackgroundColor3 = Color3.fromRGB(16, 14, 22)
	badge.BackgroundTransparency = if big then 1 else 0.15
	badge.Font = Enum.Font.GothamBlack
	badge.Text = mark
	badge.TextColor3 = WHITE
	badge.ZIndex = 6
	if big then
		badge.Size = UDim2.fromScale(1, 1)
		badge.TextSize = 34
	else
		badge.AnchorPoint = Vector2.new(1, 1)
		badge.Position = UDim2.new(1, 2, 1, 2)
		badge.Size = UDim2.fromOffset(22, 22)
		badge.TextSize = 16
		circle(badge)
		local badgeStroke = Instance.new("UIStroke")
		badgeStroke.Color = GOLD
		badgeStroke.Thickness = 1.5
		badgeStroke.Parent = badge
	end
	badge.Parent = parent
end

local function glyph(parent: Instance, image: string, mark: string?, size: number, round: boolean): Frame
	local plate = Instance.new("Frame")
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.fromOffset(size, size)
	plate.BackgroundColor3 = Color3.fromRGB(18, 16, 26)
	plate.BorderSizePixel = 0
	plate.ClipsDescendants = true
	plate.Parent = parent
	if round then
		circle(plate)
	else
		corner(plate, 14)
	end
	local plateStroke = Instance.new("UIStroke")
	plateStroke.Color = LINE
	plateStroke.Thickness = 1
	plateStroke.Parent = plate
	if image ~= "" then
		local picture = Instance.new("ImageLabel")
		picture.BackgroundTransparency = 1
		picture.Size = UDim2.fromScale(1, 1)
		picture.Image = image
		picture.ScaleType = Enum.ScaleType.Fit
		picture.ZIndex = 5
		picture.Parent = plate
	end
	if mark and mark ~= "" then
		paintMark(plate, mark, image == "")
	end
	return plate
end

local function edgeFade(side: number)
	local fade = Instance.new("Frame")
	fade.AnchorPoint = Vector2.new(side, 0)
	fade.Position = UDim2.fromScale(side, 0)
	fade.Size = UDim2.new(0, 56, 1, 0)
	fade.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	fade.BorderSizePixel = 0
	fade.ZIndex = 6
	fade.Parent = reel
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if side == 0 then 0 else 1),
		NumberSequenceKeypoint.new(1, if side == 0 then 1 else 0),
	})
	gradient.Parent = fade
end

edgeFade(0)
edgeFade(1)

local function markerArrow(text: string, y: number)
	local arrow = Instance.new("TextLabel")
	arrow.AnchorPoint = Vector2.new(0.5, y)
	arrow.Position = UDim2.new(0.5, 0, y, 0)
	arrow.Size = UDim2.fromOffset(22, 16)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextSize = 13
	arrow.TextColor3 = GOLD
	arrow.Text = text
	arrow.ZIndex = 9
	arrow.Parent = reel
end

markerArrow("▼", 0)
markerArrow("▲", 1)

type ReelSlot = {
	stroke: UIStroke,
	color: Color3,
}

local function rarityFill(color: Color3): Color3
	return Color3.fromRGB(22, 20, 32):Lerp(color, if color == Wheel.rarityColor("gold") then 0.28 else 0.16)
end

local function rarityStripe(parent: Frame, color: Color3)
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0, 1)
	bar.Size = UDim2.new(1, 0, 0, 4)
	bar.BackgroundColor3 = color
	bar.BorderSizePixel = 0
	bar.ZIndex = 4
	bar.Parent = parent
end

local reelCards: { ReelSlot } = {}
local reelRng = Random.new()
local spinConn: RBXScriptConnection? = nil
local spinToken = 0

local function sectorById(id: string)
	for _, sector in ipairs(Wheel.sectors()) do
		if sector.id == id then
			return sector
		end
	end
	return Wheel.sectors()[1]
end

local function viewWidth(): number
	local width = reel.AbsoluteSize.X
	if width < 80 then
		width = math.max(panel.AbsoluteSize.X - 56, 520)
	end
	return width
end

local function centerX(index: number, width: number): number
	return width / 2 - ((index - 1) * STEP + CARD_W / 2)
end

local function makeReelCard(index: number, sector: any): ReelSlot
	local box = Instance.new("Frame")
	box.Position = UDim2.fromOffset((index - 1) * STEP, 16)
	box.Size = UDim2.fromOffset(CARD_W, 136)
	local tint = sector.color
	box.BackgroundColor3 = rarityFill(tint)
	box.BorderSizePixel = 0
	box.ClipsDescendants = true
	box.Parent = strip
	corner(box, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Color = tint
	stroke.Thickness = if sector.rarity == "gold" then 2 else 1.5
	stroke.Parent = box
	rarityStripe(box, tint)
	local iconHost = Instance.new("Frame")
	iconHost.AnchorPoint = Vector2.new(0.5, 0)
	iconHost.Position = UDim2.new(0.5, 0, 0, 12)
	iconHost.Size = UDim2.fromOffset(68, 68)
	iconHost.BackgroundTransparency = 1
	iconHost.Parent = box
	glyph(iconHost, sector.icon, sector.mark, 64, false)
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.new(0, 6, 0, 84)
	name.Size = UDim2.new(1, -12, 0, 28)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 13
	name.TextColor3 = WHITE
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = sector.short
	name.Parent = box
	local chance = Instance.new("TextLabel")
	chance.BackgroundTransparency = 1
	chance.Position = UDim2.new(0, 6, 0, 112)
	chance.Size = UDim2.new(1, -12, 0, 16)
	chance.Font = Enum.Font.GothamBold
	chance.TextSize = 12
	chance.TextColor3 = tint
	chance.Text = tostring(sector.chance) .. "%"
	chance.Parent = box
	return { stroke = stroke, color = tint }
end

local function buildReel(winId: string?)
	local sectors = Wheel.sectors()
	for _, child in strip:GetChildren() do
		child:Destroy()
	end
	table.clear(reelCards)
	for index = 1, REEL_COUNT do
		local sector = sectors[((index - 1) % #sectors) + 1]
		if winId ~= nil and index == WIN_AT then
			sector = sectorById(winId)
		end
		reelCards[index] = makeReelCard(index, sector)
	end
end

local function focusReel(stripX: number, width: number)
	local markerAt = width / 2
	local nearest = 1
	local nearestDist = math.huge
	for index, slot in reelCards do
		local at = stripX + (index - 1) * STEP + CARD_W / 2
		local dist = math.abs(at - markerAt)
		if dist < nearestDist then
			nearestDist = dist
			nearest = index
		end
		slot.stroke.Color = slot.color
		slot.stroke.Thickness = 1.5
	end
	local hot = reelCards[nearest]
	if hot then
		hot.stroke.Color = hot.color
		hot.stroke.Thickness = 2.5
	end
end

buildReel(nil)
strip.Position = UDim2.fromOffset(centerX(4, viewWidth()), 0)

local hint = Instance.new("TextLabel")
hint.LayoutOrder = 2
hint.Size = UDim2.new(1, 0, 0, 20)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 14
hint.TextColor3 = MUTED
hint.Text = "Один раз в день бесплатно. Дальше за монеты или робуксы."
hint.Parent = content

local result = Instance.new("TextLabel")
result.LayoutOrder = 3
result.Size = UDim2.new(1, 0, 0, 22)
result.BackgroundTransparency = 1
result.Font = Enum.Font.GothamBold
result.TextSize = 15
result.TextColor3 = WHITE
result.Text = ""
result.Parent = content

local function section(order: number, text: string)
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, 24)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = WHITE
	label.Text = text
	label.Parent = content
end

local function grid(order: number, count: number): Frame
	local rows = math.ceil(count / 3)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, rows * CELL + math.max(0, rows - 1) * GAP)
	frame.BackgroundTransparency = 1
	frame.Parent = content
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / 3, -8, 0, CELL)
	layout.CellPadding = UDim2.fromOffset(8, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

local function card(parent: Instance, order: number, image: string, mark: string?, name: string, detail: string, chanceText: string, tint: Color3)
	local box = Instance.new("Frame")
	box.LayoutOrder = order
	box.BackgroundColor3 = rarityFill(tint)
	box.BorderSizePixel = 0
	box.ClipsDescendants = true
	box.Parent = parent
	corner(box, 16)
	local boxStroke = Instance.new("UIStroke")
	boxStroke.Color = tint
	boxStroke.Thickness = if tint == Wheel.rarityColor("gold") then 2 else 1.5
	boxStroke.Parent = box
	rarityStripe(box, tint)
	local iconHost = Instance.new("Frame")
	iconHost.AnchorPoint = Vector2.new(0.5, 0)
	iconHost.Position = UDim2.new(0.5, 0, 0, 14)
	iconHost.Size = UDim2.fromOffset(78, 78)
	iconHost.BackgroundTransparency = 1
	iconHost.Parent = box
	glyph(iconHost, image, mark, 78, false)
	local chance = Instance.new("TextLabel")
	chance.AnchorPoint = Vector2.new(1, 0)
	chance.Position = UDim2.new(1, -10, 0, 10)
	chance.Size = UDim2.fromOffset(58, 20)
	chance.BackgroundColor3 = Color3.fromRGB(16, 14, 22)
	chance.Font = Enum.Font.GothamBold
	chance.TextSize = 12
	chance.TextColor3 = tint
	chance.Text = chanceText
	chance.Parent = box
	corner(chance, 8)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 10, 0, 100)
	nameLabel.Size = UDim2.new(1, -20, 0, 22)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 15
	nameLabel.TextColor3 = WHITE
	nameLabel.TextWrapped = true
	nameLabel.Text = name
	nameLabel.Parent = box
	local detailLabel = Instance.new("TextLabel")
	detailLabel.BackgroundTransparency = 1
	detailLabel.Position = UDim2.new(0, 10, 0, 124)
	detailLabel.Size = UDim2.new(1, -20, 0, 52)
	detailLabel.Font = Enum.Font.Gotham
	detailLabel.TextSize = 13
	detailLabel.TextColor3 = MUTED
	detailLabel.TextWrapped = true
	detailLabel.TextYAlignment = Enum.TextYAlignment.Top
	detailLabel.Text = detail
	detailLabel.Parent = box
end

section(4, "Призы")
local prizeGrid = grid(5, #Wheel.sectors())
for index, sector in ipairs(Wheel.sectors()) do
	card(prizeGrid, index, sector.icon, sector.mark, sector.name, sector.detail, tostring(sector.chance) .. "%", sector.color)
end

section(6, "Случайный скин")
local skinGrid = grid(7, #Skins.all())
for index, skin in Skins.all() do
	local thumb = "rbxthumb://type=Asset&id=" .. tostring(skin.asset) .. "&w=150&h=150"
	card(skinGrid, index, thumb, nil, skin.name, skin.blurb, "из 8%", Wheel.rarityColor("gold"))
end

section(8, "Случайный след")
local trailGrid = grid(9, #Shop.trails())
for index, item in Shop.trails() do
	card(trailGrid, index, Wheel.icon(item.id), nil, item.name, item.blurb, "из 7%", Wheel.rarityColor("purple"))
end

section(10, "Случайная плюшка")
local perkGrid = grid(11, #Shop.perks())
for index, item in Shop.perks() do
	card(perkGrid, index, Wheel.icon(item.id), nil, item.name, item.blurb, "из 5%", Wheel.rarityColor("secret"))
end

local reward = Instance.new("Frame")
reward.AnchorPoint = Vector2.new(0.5, 0.5)
reward.Position = UDim2.fromScale(0.5, 0.42)
reward.Size = UDim2.fromOffset(280, 176)
reward.BackgroundColor3 = Color3.fromRGB(24, 22, 34)
reward.Visible = false
reward.ZIndex = 12
reward.Parent = panel
corner(reward, 18)
local rewardStroke = Instance.new("UIStroke")
rewardStroke.Color = GOLD
rewardStroke.Thickness = 2
rewardStroke.Parent = reward
local rewardScale = Instance.new("UIScale")
rewardScale.Parent = reward
local rewardIconHost = Instance.new("Frame")
rewardIconHost.AnchorPoint = Vector2.new(0.5, 0)
rewardIconHost.Position = UDim2.new(0.5, 0, 0, 16)
rewardIconHost.Size = UDim2.fromOffset(64, 64)
rewardIconHost.BackgroundTransparency = 1
rewardIconHost.ZIndex = 13
rewardIconHost.Parent = reward
local rewardTitle = Instance.new("TextLabel")
rewardTitle.BackgroundTransparency = 1
rewardTitle.Position = UDim2.new(0, 16, 0, 88)
rewardTitle.Size = UDim2.new(1, -32, 0, 28)
rewardTitle.Font = Enum.Font.GothamBlack
rewardTitle.TextSize = 18
rewardTitle.TextColor3 = WHITE
rewardTitle.Text = ""
rewardTitle.ZIndex = 13
rewardTitle.Parent = reward
local rewardDetail = Instance.new("TextLabel")
rewardDetail.BackgroundTransparency = 1
rewardDetail.Position = UDim2.new(0, 16, 0, 116)
rewardDetail.Size = UDim2.new(1, -32, 0, 44)
rewardDetail.Font = Enum.Font.Gotham
rewardDetail.TextSize = 13
rewardDetail.TextWrapped = true
rewardDetail.TextColor3 = MUTED
rewardDetail.Text = ""
rewardDetail.ZIndex = 13
rewardDetail.Parent = reward
local rewardToken = 0

local buttons = Instance.new("Frame")
buttons.AnchorPoint = Vector2.new(0.5, 1)
buttons.Position = UDim2.new(0.5, 0, 1, -14)
buttons.Size = UDim2.new(1, -36, 0, 48)
buttons.BackgroundTransparency = 1
buttons.Parent = panel
local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.Padding = UDim.new(0, 8)
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.Parent = buttons

local function spinButton(text: string, color: Color3, textColor: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1 / 3, -8, 1, 0)
	button.BackgroundColor3 = color
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.TextColor3 = textColor
	button.Text = text
	button.Parent = buttons
	corner(button, 12)
	return button
end

local freeButton = spinButton("Бесплатно", GREEN, Color3.fromRGB(20, 40, 28))
local coinButton = spinButton(money(Wheel.SPIN_COINS), GOLD, Color3.fromRGB(40, 28, 12))
local robuxButton = spinButton(tostring(Wheel.SPIN_ROBUX) .. " R$", BLUE, WHITE)

local function paintFree()
	freeButton.Text = if free then "Бесплатно" else "Завтра"
	freeButton.BackgroundColor3 = if free then GREEN else Color3.fromRGB(70, 64, 88)
	freeButton.TextColor3 = if free then Color3.fromRGB(20, 40, 28) else WHITE
	coinLabel.Text = money(coins)
end

local function setOpen(on: boolean)
	open = on
	gui.Enabled = on
	if prompt then
		prompt.Enabled = not on
	end
	if on and not spinning then
		task.defer(function()
			if spinning then
				return
			end
			local x = centerX(4, viewWidth())
			strip.Position = UDim2.fromOffset(x, 0)
			focusReel(x, viewWidth())
		end)
	end
end

local CONFETTI = {
	Color3.fromRGB(255, 214, 96),
	Color3.fromRGB(255, 248, 230),
	Color3.fromRGB(88, 206, 138),
	Color3.fromRGB(120, 170, 255),
	Color3.fromRGB(255, 130, 168),
	Color3.fromRGB(255, 176, 72),
}

local function confetti()
	local layer = Instance.new("Frame")
	layer.Name = "Confetti"
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.Active = false
	layer.ZIndex = 20
	layer.Parent = panel
	local roll = Random.new()
	for _ = 1, 42 do
		local piece = Instance.new("Frame")
		local wide = roll:NextInteger(7, 12)
		local tall = roll:NextInteger(10, 16)
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(roll:NextNumber(0.08, 0.92), -0.04)
		piece.Size = UDim2.fromOffset(wide, tall)
		piece.BackgroundColor3 = CONFETTI[roll:NextInteger(1, #CONFETTI)]
		piece.Rotation = roll:NextNumber(0, 180)
		piece.BorderSizePixel = 0
		piece.ZIndex = 21
		piece.Parent = layer
		if roll:NextNumber() < 0.4 then
			circle(piece)
		else
			corner(piece, 2)
		end
		local fall = TweenService:Create(piece, TweenInfo.new(roll:NextNumber(0.85, 1.35), Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(piece.Position.X.Scale + roll:NextNumber(-0.08, 0.08), roll:NextNumber(0.72, 1.08)),
			Rotation = piece.Rotation + roll:NextNumber(-280, 280),
			BackgroundTransparency = 1,
		})
		fall:Play()
	end
	for _ = 1, 28 do
		local piece = Instance.new("Frame")
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(0.5, 0.4)
		piece.Size = UDim2.fromOffset(roll:NextInteger(6, 11), roll:NextInteger(6, 11))
		piece.BackgroundColor3 = CONFETTI[roll:NextInteger(1, #CONFETTI)]
		piece.Rotation = roll:NextNumber(0, 360)
		piece.BorderSizePixel = 0
		piece.ZIndex = 22
		piece.Parent = layer
		circle(piece)
		local burst = TweenService:Create(piece, TweenInfo.new(roll:NextNumber(0.55, 0.9), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5 + roll:NextNumber(-0.42, 0.42), 0.4 + roll:NextNumber(-0.28, 0.36)),
			Rotation = piece.Rotation + roll:NextNumber(-200, 200),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(4, 4),
		})
		burst:Play()
	end
	task.delay(1.45, function()
		layer:Destroy()
	end)
end

local land: ({ [string]: any }) -> ()

local function reveal(data: { [string]: any }, token: number)
	if token ~= spinToken then
		return
	end
	spinning = false
	scroll.ScrollingEnabled = true
	freeButton.AutoButtonColor = true
	coinButton.AutoButtonColor = true
	robuxButton.AutoButtonColor = true
	focusReel(centerX(WIN_AT, viewWidth()), viewWidth())
	local won = reelCards[WIN_AT]
	if won then
		won.stroke.Color = won.color
		won.stroke.Thickness = 2.5
	end
	local titleText = if typeof(data.title) == "string" then data.title else "Приз"
	local detail = if typeof(data.detail) == "string" then data.detail else ""
	local image = if typeof(data.icon) == "string" then data.icon else ""
	result.Text = titleText .. " — " .. detail
	for _, child in rewardIconHost:GetChildren() do
		child:Destroy()
	end
	glyph(rewardIconHost, image, nil, 64, false)
	rewardTitle.Text = titleText
	rewardDetail.Text = detail
	reward.Visible = true
	rewardScale.Scale = 0.55
	TweenService:Create(rewardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	confetti()
	rewardToken += 1
	local shown = rewardToken
	task.delay(2.4, function()
		if shown ~= rewardToken then
			return
		end
		local hide = TweenService:Create(rewardScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0.7,
		})
		hide.Completed:Connect(function()
			if shown == rewardToken then
				reward.Visible = false
			end
		end)
		hide:Play()
	end)
	paintFree()
	if queued then
		local nextSpin = queued
		queued = nil
		land(nextSpin)
	end
end

function land(data: { [string]: any })
	spinToken += 1
	local token = spinToken
	if spinConn then
		spinConn:Disconnect()
		spinConn = nil
	end
	local sectorId = if typeof(data.sectorId) == "string" then data.sectorId else "coins_s"
	buildReel(sectorId)
	local width = viewWidth()
	local startX = centerX(3, width)
	local exact = centerX(WIN_AT, width)
	local past = exact - reelRng:NextNumber(28, 62)
	strip.Position = UDim2.fromOffset(startX, 0)
	focusReel(startX, width)
	rewardToken += 1
	reward.Visible = false
	spinning = true
	scroll.ScrollingEnabled = false
	scroll.CanvasPosition = Vector2.zero
	freeButton.AutoButtonColor = false
	coinButton.AutoButtonColor = false
	robuxButton.AutoButtonColor = false
	result.Text = "Крутится..."
	local started = os.clock()
	local duration = 5.35
	spinConn = RunService.Heartbeat:Connect(function()
		if token ~= spinToken then
			return
		end
		local t = math.clamp((os.clock() - started) / duration, 0, 1)
		local eased = if t >= 1 then 1 else 1 - 2 ^ (-10 * t)
		local x = startX + (past - startX) * eased
		strip.Position = UDim2.fromOffset(x, 0)
		focusReel(x, width)
		if t < 1 then
			return
		end
		if spinConn then
			spinConn:Disconnect()
			spinConn = nil
		end
		local settle = TweenService:Create(strip, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(exact, 0),
		})
		settle.Completed:Connect(function()
			reveal(data, token)
		end)
		settle:Play()
	end)
end

local function apply(data: { [string]: any })
	if typeof(data.coins) == "number" then
		coins = data.coins
	end
	if typeof(data.free) == "boolean" then
		free = data.free
	end
	paintFree()
	if data.ok == false and typeof(data.notice) == "string" then
		result.Text = data.notice
		return
	end
	if data.ok == true and typeof(data.angle) == "number" then
		if not open then
			setOpen(true)
		end
		if spinning then
			queued = data
			return
		end
		land(data)
	end
end

freeButton.Activated:Connect(function()
	if spinning or not free then
		return
	end
	Remotes.get("Wheel"):FireServer("free")
end)
coinButton.Activated:Connect(function()
	if spinning then
		return
	end
	Remotes.get("Wheel"):FireServer("coins")
end)
robuxButton.Activated:Connect(function()
	if spinning then
		return
	end
	Remotes.get("Wheel"):FireServer("robux")
end)

close.Activated:Connect(function()
	if not spinning then
		setOpen(false)
	end
end)
dim.Activated:Connect(function()
	if not spinning then
		setOpen(false)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not open or processed or spinning then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.E then
		setOpen(false)
	end
end)

player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") ~= nil then
		setOpen(false)
	end
end)

Remotes.get("WheelState").OnClientEvent:Connect(function(data)
	if typeof(data) == "table" then
		apply(data)
	end
end)

task.spawn(function()
	local podium = workspace:WaitForChild("World"):WaitForChild("Lobby"):WaitForChild("Podiums"):WaitForChild("Wheel")
	local found: Instance? = nil
	local started = os.clock()
	while os.clock() - started < 20 do
		found = podium:FindFirstChild("WheelPrompt", true)
		if found then
			break
		end
		task.wait(0.25)
	end
	if found and found:IsA("ProximityPrompt") then
		prompt = found
		found.Triggered:Connect(function()
			if player:GetAttribute("InMatch") ~= nil then
				return
			end
			setOpen(true)
			Remotes.get("Wheel"):FireServer("state")
		end)
	end
end)

paintFree()

return {}
