--!strict
-- Инвентарь: что уже куплено. Магазин, колесо и квесты открываются вкладками, не копией окон.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

local Hub = require(script.Parent:WaitForChild("Hub"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Shop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Shop"))
local Skins = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Skins"))

local player = Players.LocalPlayer

local CREAM = Color3.fromRGB(236, 228, 214)
local INK = Color3.fromRGB(32, 28, 24)
local MUTED = Color3.fromRGB(176, 166, 150)
local CARD = Color3.fromRGB(42, 38, 34)
local LINE = Color3.fromRGB(48, 42, 38)

local PERK_ICONS: { [string]: string } = {
	perk_jump = "rbxassetid://91298870492601",
	perk_shield = "rbxassetid://82788513509598",
	perk_dash = "rbxassetid://91669812184269",
	perk_life = "rbxassetid://75191507217586",
	perk_speed = "rbxassetid://93356796691553",
	perk_coins = "rbxassetid://88068529364286",
	perk_revive = "rbxassetid://88404567308271",
	perk_lightning = "rbxassetid://104667034338901",
	perk_salute = "rbxassetid://96849720546650",
}
local TRAIL_ICONS: { [string]: string } = {
	trail_rainbow = "rbxassetid://107949754436781",
	trail_fire = "rbxassetid://75226922089625",
	trail_ice = "rbxassetid://98546609363845",
	trail_gold = "rbxassetid://114531965952754",
	trail_toxic = "rbxassetid://95927643957313",
	trail_candy = "rbxassetid://127263746228320",
	trail_storm = "rbxassetid://120645531130115",
}

type Bag = {
	owned: { [string]: boolean },
	equipped: string,
	trail: string,
	charges: { [string]: number },
	armed: string,
}

local bag: Bag = {
	owned = {},
	equipped = "",
	trail = "",
	charges = {},
	armed = "",
}

local gui = Instance.new("ScreenGui")
gui.Name = "ColorPartyInventory"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 39
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
panel.Position = UDim2.new(0.5, 0, 0.56, 8)
panel.Size = UDim2.fromScale(0.72, 0.74)
panel.BackgroundColor3 = INK
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = dim
local cap = Instance.new("UISizeConstraint")
cap.MaxSize = Vector2.new(980, 640)
cap.Parent = panel
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 18)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = LINE
panelStroke.Thickness = 2
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(22, 16)
title.Size = UDim2.new(1, -44, 0, 28)
title.Font = Enum.Font.GothamBlack
title.TextSize = 24
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = CREAM
title.Text = Locale.t("My stuff")
title.Parent = panel

local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 1
hint.Position = UDim2.fromOffset(22, 46)
hint.Size = UDim2.new(1, -44, 0, 18)
hint.Font = Enum.Font.Gotham
hint.TextSize = 14
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextColor3 = MUTED
hint.Text = Locale.t("Only what you already bought")
hint.Parent = panel

local scroll = Instance.new("ScrollingFrame")
scroll.BackgroundTransparency = 1
scroll.Position = UDim2.fromOffset(16, 74)
scroll.Size = UDim2.new(1, -32, 1, -90)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(186, 154, 96)
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 8)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = scroll
local pad = Instance.new("UIPadding")
pad.PaddingBottom = UDim.new(0, 12)
pad.Parent = scroll

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function heading(text: string, order: number)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 24)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = CREAM
	label.Text = text
	label.LayoutOrder = order
	label.Parent = scroll
end

local function row(order: number, name: string, status: string, image: string?)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 64)
	card.BackgroundColor3 = CARD
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.Parent = scroll
	corner(card, 12)
	local icon = Instance.new("ImageLabel")
	icon.BackgroundColor3 = Color3.fromRGB(28, 24, 22)
	icon.Position = UDim2.fromOffset(10, 8)
	icon.Size = UDim2.fromOffset(48, 48)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = image or ""
	icon.Parent = card
	corner(icon, 10)
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(70, 10)
	titleLabel.Size = UDim2.new(1, -84, 0, 22)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 16
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.TextColor3 = CREAM
	titleLabel.Text = name
	titleLabel.Parent = card
	local statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.Position = UDim2.fromOffset(70, 34)
	statusLabel.Size = UDim2.new(1, -84, 0, 18)
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 14
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextColor3 = MUTED
	statusLabel.Text = status
	statusLabel.Parent = card
end

local function stock(id: string): number
	local count = bag.charges[id] or 0
	if bag.armed == id then
		count += 1
	end
	return count
end

local function render()
	for _, child in scroll:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	local order = 1
	local any = false

	heading(Locale.t("Skins"), order)
	order += 1
	local skinCount = 0
	for _, skin in Skins.all() do
		if bag.owned[skin.id] then
			skinCount += 1
			any = true
			local status = if bag.equipped == skin.id then Locale.t("Equipped") else Locale.t("Owned")
			row(order, Locale.t(skin.name), status, "rbxthumb://type=Asset&id=" .. tostring(skin.asset) .. "&w=150&h=150")
			order += 1
		end
	end
	if skinCount == 0 then
		row(order, Locale.t("No skins yet"), Locale.t("You can get them in the shop"), nil)
		order += 1
	end

	heading(Locale.t("Perks"), order)
	order += 1
	local perkCount = 0
	for _, item in Shop.perks() do
		local forever = bag.owned[item.id] == true
		local matches = stock(item.id)
		if forever or matches > 0 then
			perkCount += 1
			any = true
			local status = if forever then Locale.t("Forever") else Locale.fmt("For a match: %d", matches)
			if forever and matches > 0 then
				status = Locale.fmt("Forever, plus %d for a match", matches)
			end
			row(order, Locale.t(item.name), status, PERK_ICONS[item.id])
			order += 1
		end
	end
	if perkCount == 0 then
		row(order, Locale.t("No perks yet"), Locale.t("Match and forever perks are in the shop"), nil)
		order += 1
	end

	heading(Locale.t("Trails"), order)
	order += 1
	local trailCount = 0
	for _, item in Shop.trails() do
		if bag.owned[item.id] then
			trailCount += 1
			any = true
			local status = if bag.trail == item.id then Locale.t("Equipped") else Locale.t("Owned")
			row(order, Locale.t(item.name), status, TRAIL_ICONS[item.id])
			order += 1
		end
	end
	if trailCount == 0 then
		row(order, Locale.t("No trails yet"), Locale.t("You can get them in the shop"), nil)
		order += 1
	end
	if not any then
		hint.Text = Locale.t("Nothing yet. Open the Shop tab")
	else
		hint.Text = Locale.t("Only what you already bought")
	end
end

local function apply(data: { [string]: any })
	bag.owned = {}
	if typeof(data.owned) == "table" then
		for _, id in data.owned do
			if typeof(id) == "string" then
				bag.owned[id] = true
			end
		end
	end
	bag.equipped = if typeof(data.equipped) == "string" then data.equipped else ""
	bag.trail = if typeof(data.trail) == "string" then data.trail else ""
	bag.armed = if typeof(data.armed) == "string" then data.armed else ""
	bag.charges = {}
	if typeof(data.charges) == "table" then
		for id, count in data.charges do
			if typeof(id) == "string" then
				bag.charges[id] = tonumber(count) or 0
			end
		end
	end
	if gui.Enabled then
		render()
	end
end

local function present(on: boolean)
	gui.Enabled = on
	if on then
		render()
		Remotes.get("Skins"):FireServer("state")
	end
end

Hub.bind("inventory", present)

dim.Activated:Connect(function()
	Hub.close()
end)

Remotes.get("SkinState").OnClientEvent:Connect(function(data)
	if typeof(data) == "table" then
		apply(data)
	end
end)

return {}
