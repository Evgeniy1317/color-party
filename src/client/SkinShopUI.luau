--!strict
-- Магазин по центру экрана: примерка персонажа, скины, плюшки и следы.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Shop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Shop"))
local Skins = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Skins"))

local player = Players.LocalPlayer

local INK = Color3.fromRGB(18, 16, 28)
local PANEL = Color3.fromRGB(28, 25, 40)
local CARD = Color3.fromRGB(38, 34, 54)
local WHITE = Color3.fromRGB(255, 248, 242)
local MUTED = Color3.fromRGB(176, 168, 190)
local GOLD = Color3.fromRGB(255, 196, 80)
local GREEN = Color3.fromRGB(78, 196, 122)
local BLUE = Color3.fromRGB(0, 162, 255)
local ROBUX_ICON = "rbxasset://textures/ui/common/robux.png"
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

local sections = {
	{ id = "skins", title = "Скины" },
	{ id = "perks", title = "Плюшки" },
	{ id = "trails", title = "Следы" },
}
local filters = {
	{ id = "all", title = "Все" },
	{ id = "female", title = "Женские" },
	{ id = "male", title = "Мужские" },
	{ id = "unisex", title = "Общие" },
}

local section = "skins"
local filter = "all"
local query = ""
local open = false
local prompt: ProximityPrompt? = nil
local selectedId = "sakura"
local shownKey = ""
local spin = 0
local previewFocus = Vector3.new(0, 2.4, 0)
local previewDist = 9
local shownModel: Model? = nil
local previewToken = 0
local robuxBalance: number? = nil

local state = {
	coins = 0,
	owned = {} :: { [string]: boolean },
	equipped = "",
	trail = "",
	notice = "",
	charges = {} :: { [string]: number },
	discount = 0,
	armed = "",
}

local gui = Instance.new("ScreenGui")
gui.Name = "ColorPartySkins"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 36
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local dim = Instance.new("TextButton")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.48
dim.Text = ""
dim.AutoButtonColor = false
dim.BorderSizePixel = 0
dim.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.82, 0.78)
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.Parent = gui
local panelLimit = Instance.new("UISizeConstraint")
panelLimit.MaxSize = Vector2.new(1080, 700)
panelLimit.Parent = panel
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 22)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(255, 214, 170)
panelStroke.Transparency = 0.72
panelStroke.Thickness = 1.5
panelStroke.Parent = panel

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function money(amount: number): string
	local text = tostring(math.floor(amount))
	local grouped = ""
	while #text > 3 do
		grouped = " " .. string.sub(text, -3) .. grouped
		text = string.sub(text, 1, -4)
	end
	return text .. grouped
end

local function coinBadge(parent: Instance, px: number): Frame
	local coin = Instance.new("Frame")
	coin.Name = "Coin"
	coin.Size = UDim2.fromOffset(px, px)
	coin.BackgroundColor3 = Color3.fromRGB(255, 186, 48)
	coin.BorderSizePixel = 0
	coin.Parent = parent
	corner(coin, px)
	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.62, 0.62)
	inner.BackgroundColor3 = Color3.fromRGB(255, 224, 120)
	inner.BorderSizePixel = 0
	inner.Parent = coin
	corner(inner, px)
	local mark = Instance.new("TextLabel")
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.fromScale(1, 1)
	mark.Font = Enum.Font.GothamBlack
	mark.TextSize = math.floor(px * 0.55)
	mark.TextColor3 = Color3.fromRGB(166, 104, 16)
	mark.Text = "C"
	mark.Parent = inner
	return coin
end

local function robuxBadge(parent: Instance, px: number): ImageLabel
	local icon = Instance.new("ImageLabel")
	icon.Name = "Robux"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(px, px)
	icon.Image = ROBUX_ICON
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = parent
	return icon
end

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(22, 14)
title.Size = UDim2.fromOffset(220, 34)
title.Font = Enum.Font.GothamBlack
title.TextSize = 28
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = WHITE
title.Text = "Магазин"
title.Parent = panel

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -16, 0, 14)
close.Size = UDim2.fromOffset(34, 34)
close.BackgroundColor3 = Color3.fromRGB(48, 42, 64)
close.Font = Enum.Font.GothamBold
close.TextSize = 18
close.TextColor3 = WHITE
close.Text = "×"
close.Parent = panel
corner(close, 10)

local function balancePill(offset: number, kind: string): TextLabel
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.new(1, offset, 0, 14)
	pill.Size = UDim2.fromOffset(168, 34)
	pill.BackgroundColor3 = INK
	pill.BorderSizePixel = 0
	pill.Parent = panel
	corner(pill, 12)
	if kind == "coin" then
		local badge = coinBadge(pill, 18)
		badge.Position = UDim2.fromOffset(10, 8)
	else
		local badge = robuxBadge(pill, 18)
		badge.Position = UDim2.fromOffset(10, 8)
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(34, 0)
	label.Size = UDim2.new(1, -42, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = if kind == "coin" then GOLD else WHITE
	label.Text = "—"
	label.Parent = pill
	return label
end

local coinLabel = balancePill(-58, "coin")
local robuxLabel = balancePill(-236, "robux")

local body = Instance.new("Frame")
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(16, 60)
body.Size = UDim2.new(1, -32, 1, -76)
body.Parent = panel

local preview = Instance.new("Frame")
preview.BackgroundColor3 = INK
preview.Size = UDim2.new(0.36, -8, 1, 0)
preview.BorderSizePixel = 0
preview.Parent = body
corner(preview, 16)

local viewport = Instance.new("ViewportFrame")
viewport.BackgroundColor3 = Color3.fromRGB(22, 20, 34)
viewport.Position = UDim2.fromOffset(10, 10)
viewport.Size = UDim2.new(1, -20, 1, -168)
viewport.Ambient = Color3.fromRGB(190, 190, 200)
viewport.LightColor = Color3.fromRGB(255, 244, 230)
viewport.LightDirection = Vector3.new(-0.4, -1, -0.3)
viewport.BorderSizePixel = 0
viewport.ZIndex = 1
viewport.Parent = preview
corner(viewport, 12)
local perkStage = Instance.new("Frame")
perkStage.Name = "Perk"
perkStage.BackgroundColor3 = Color3.fromRGB(22, 20, 34)
perkStage.Position = UDim2.fromOffset(10, 10)
perkStage.Size = UDim2.new(1, -20, 1, -168)
perkStage.Visible = false
perkStage.ZIndex = 4
perkStage.BorderSizePixel = 0
perkStage.Parent = preview
corner(perkStage, 12)
local perkHost = Instance.new("Frame")
perkHost.BackgroundTransparency = 1
perkHost.AnchorPoint = Vector2.new(0.5, 0.5)
perkHost.Position = UDim2.fromScale(0.5, 0.5)
perkHost.Size = UDim2.fromScale(0.72, 0.72)
perkHost.Parent = perkStage
local world = Instance.new("WorldModel")
world.Parent = viewport
local camera = Instance.new("Camera")
camera.FieldOfView = 30
camera.CFrame = CFrame.new(Vector3.new(0, 0.4, 8.4), Vector3.new(0, 0.15, 0))
camera.Parent = viewport
viewport.CurrentCamera = camera

local loading = Instance.new("TextLabel")
loading.BackgroundTransparency = 1
loading.Size = UDim2.fromScale(1, 1)
loading.Font = Enum.Font.Gotham
loading.TextSize = 14
loading.TextColor3 = MUTED
loading.Text = ""
loading.ZIndex = 2
loading.Parent = viewport

local previewName = Instance.new("TextLabel")
previewName.BackgroundTransparency = 1
previewName.AnchorPoint = Vector2.new(0, 1)
previewName.Position = UDim2.new(0, 14, 1, -108)
previewName.Size = UDim2.new(1, -28, 0, 26)
previewName.Font = Enum.Font.GothamBlack
previewName.TextSize = 20
previewName.TextXAlignment = Enum.TextXAlignment.Left
previewName.TextColor3 = WHITE
previewName.Text = "Магазин"
previewName.Parent = preview

local previewBlurb = Instance.new("TextLabel")
previewBlurb.BackgroundTransparency = 1
previewBlurb.AnchorPoint = Vector2.new(0, 1)
previewBlurb.Position = UDim2.new(0, 14, 1, -78)
previewBlurb.Size = UDim2.new(1, -28, 0, 28)
previewBlurb.Font = Enum.Font.Gotham
previewBlurb.TextSize = 13
previewBlurb.TextWrapped = true
previewBlurb.TextXAlignment = Enum.TextXAlignment.Left
previewBlurb.TextYAlignment = Enum.TextYAlignment.Top
previewBlurb.TextColor3 = MUTED
previewBlurb.Text = ""
previewBlurb.Parent = preview

local buyRow = Instance.new("Frame")
buyRow.BackgroundTransparency = 1
buyRow.AnchorPoint = Vector2.new(0, 1)
buyRow.Position = UDim2.new(0, 12, 1, -12)
buyRow.Size = UDim2.new(1, -24, 0, 42)
buyRow.Parent = preview
local buyLayout = Instance.new("UIListLayout")
buyLayout.FillDirection = Enum.FillDirection.Horizontal
buyLayout.Padding = UDim.new(0, 8)
buyLayout.Parent = buyRow

local catalog = Instance.new("Frame")
catalog.BackgroundTransparency = 1
catalog.Position = UDim2.new(0.36, 8, 0, 0)
catalog.Size = UDim2.new(0.64, -8, 1, 0)
catalog.Parent = body

local toolbar = Instance.new("Frame")
toolbar.BackgroundTransparency = 1
toolbar.Size = UDim2.new(1, 0, 0, 36)
toolbar.Parent = catalog
local toolLayout = Instance.new("UIListLayout")
toolLayout.FillDirection = Enum.FillDirection.Horizontal
toolLayout.Padding = UDim.new(0, 8)
toolLayout.VerticalAlignment = Enum.VerticalAlignment.Center
toolLayout.Parent = toolbar

local filterRow = Instance.new("Frame")
filterRow.BackgroundTransparency = 1
filterRow.Position = UDim2.fromOffset(0, 42)
filterRow.Size = UDim2.new(1, 0, 0, 30)
filterRow.Parent = catalog
local filterLayout = Instance.new("UIListLayout")
filterLayout.FillDirection = Enum.FillDirection.Horizontal
filterLayout.Padding = UDim.new(0, 6)
filterLayout.VerticalAlignment = Enum.VerticalAlignment.Center
filterLayout.Parent = filterRow

local notice = Instance.new("TextLabel")
notice.BackgroundTransparency = 1
notice.Position = UDim2.fromOffset(0, 74)
notice.Size = UDim2.new(1, 0, 0, 16)
notice.Font = Enum.Font.Gotham
notice.TextSize = 13
notice.TextXAlignment = Enum.TextXAlignment.Left
notice.TextColor3 = MUTED
notice.Text = "Нажми на карточку — персонаж появится слева до покупки"
notice.Parent = catalog

local scroll = Instance.new("ScrollingFrame")
scroll.BackgroundTransparency = 1
scroll.Position = UDim2.fromOffset(0, 94)
scroll.Size = UDim2.new(1, 0, 1, -94)
scroll.ScrollBarThickness = 5
scroll.ScrollBarImageColor3 = Color3.fromRGB(180, 160, 200)
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.BorderSizePixel = 0
scroll.Parent = catalog
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(148, 180)
grid.CellPadding = UDim2.fromOffset(8, 8)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = scroll
local gridPad = Instance.new("UIPadding")
gridPad.PaddingBottom = UDim.new(0, 8)
gridPad.Parent = scroll

local sectionButtons: { [string]: TextButton } = {}
local filterButtons: { [string]: TextButton } = {}
local drawPerkIcon: (Instance, string, number) -> ()

local function setOpen(on: boolean)
	open = on
	gui.Enabled = on
	if prompt then
		prompt.Enabled = not on
	end
end

local function owns(id: string): boolean
	return state.owned[id] == true
end

local function stock(id: string): number
	local count = state.charges[id] or 0
	if state.armed == id then
		count += 1
	end
	return count
end

local function matches(name: string): boolean
	if query == "" then
		return true
	end
	return string.find(string.lower(name), query, 1, true) ~= nil
end

local function clearWorld()
	shownModel = nil
	for _, child in world:GetChildren() do
		child:Destroy()
	end
end

local function visualCenter(model: Model): (Vector3, Vector3)
	local root = model:FindFirstChild("HumanoidRootPart")
	local origin = if root and root:IsA("BasePart") then root.Position else model:GetPivot().Position
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	local count = 0
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item.Transparency < 0.98 and item.Name ~= "HumanoidRootPart" then
			if (item.Position - origin).Magnitude < 16 and item.Size.Magnitude < 20 then
				local half = item.Size * 0.5
				local p = item.Position
				minV = Vector3.new(math.min(minV.X, p.X - half.X), math.min(minV.Y, p.Y - half.Y), math.min(minV.Z, p.Z - half.Z))
				maxV = Vector3.new(math.max(maxV.X, p.X + half.X), math.max(maxV.Y, p.Y + half.Y), math.max(maxV.Z, p.Z + half.Z))
				count += 1
			end
		end
	end
	if count == 0 then
		local cf, size = model:GetBoundingBox()
		return cf.Position, size
	end
	return (minV + maxV) * 0.5, maxV - minV
end

local function placeModel(model: Model)
	clearWorld()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
		elseif part:IsA("Trail") then
			part:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.PlatformStand = true
	end
	model.Parent = world
	local center, size = visualCenter(model)
	local height = math.clamp(size.Y, 3, 9)
	local focus = Vector3.new(0, height * 0.48, 0)
	model:PivotTo(model:GetPivot() + (focus - center))
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local look = root.CFrame.LookVector
		local yaw = math.atan2(look.X, look.Z)
		model:PivotTo(CFrame.new(focus) * CFrame.Angles(0, -yaw, 0) * CFrame.new(-focus) * model:GetPivot())
		root.Anchored = true
	end
	local span = math.max(size.X, height, size.Z)
	local fit = (span * 0.55) / math.tan(math.rad(camera.FieldOfView * 0.5))
	previewFocus = focus
	previewDist = math.clamp(fit * 1.2, 6, 20)
	spin = 0
	shownModel = model
	loading.Text = ""
end

local function colorKeys(colors: { Color3 }): { ColorSequenceKeypoint }
	local keys = {}
	for index, color in colors do
		local at = if #colors == 1 then 0 else (index - 1) / (#colors - 1)
		table.insert(keys, ColorSequenceKeypoint.new(at, color))
	end
	return keys
end

local function addPreviewTrail(model: Model, colors: { Color3 })
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or #colors < 2 then
		return
	end
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 1.1, 1.1)
	top.Parent = root
	local tail = Instance.new("Attachment")
	tail.Position = Vector3.new(0, -1.5, 4.8)
	tail.Parent = root
	local beam = Instance.new("Beam")
	beam.Attachment0 = top
	beam.Attachment1 = tail
	beam.FaceCamera = true
	beam.LightEmission = 0.75
	beam.Width0 = 1.7
	beam.Width1 = 0.35
	beam.Color = ColorSequence.new(colorKeys(colors))
	beam.Transparency = NumberSequence.new(0.04)
	beam.Parent = root
end

local function showLook(kind: string, id: string)
	previewToken += 1
	local token = previewToken
	local key = kind .. ":" .. id
	if key == shownKey and shownModel then
		return
	end
	shownKey = key
	loading.Text = ""
	local sourceId = if kind == "skin" then id else if state.equipped ~= "" then state.equipped else "sakura"
	local template = Skins.model(sourceId)
	if not template then
		loading.Text = "Модель ещё не в игре"
		return
	end
	local model = template:Clone()
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Sound") or item:IsA("BillboardGui") or item:IsA("Camera") then
			item:Destroy()
		end
	end
	if kind == "trail" then
		local trailItem = Shop.get(id)
		if trailItem and trailItem.colors then
			addPreviewTrail(model, trailItem.colors)
		end
	end
	if token ~= previewToken then
		model:Destroy()
		return
	end
	placeModel(model)
end

local function priceButton(text: string, color: Color3, textColor: Color3, kind: string?, amount: number?, wide: boolean, callback: () -> ())
	local button = Instance.new("TextButton")
	button.Size = if wide then UDim2.fromScale(1, 1) else UDim2.new(0.5, -4, 1, 0)
	button.BackgroundColor3 = color
	button.AutoButtonColor = true
	button.Text = ""
	button.Parent = buyRow
	corner(button, 12)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(0, 22)
	holder.AutomaticSize = Enum.AutomaticSize.X
	holder.Parent = button
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.Padding = UDim.new(0, 6)
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Parent = holder
	if kind == "coin" then
		coinBadge(holder, 16)
	elseif kind == "robux" then
		local icon = robuxBadge(holder, 16)
		icon.ImageColor3 = textColor
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 22)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = textColor
	label.Text = if amount then money(amount) else text
	label.Parent = holder
	button.Activated:Connect(callback)
end

local function perkLine(title: string, order: number, id: string, coins: number, robux: number, once: boolean)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Parent = buyRow
	local caption = Instance.new("TextLabel")
	caption.BackgroundTransparency = 1
	caption.Size = UDim2.fromOffset(78, 40)
	caption.Font = Enum.Font.GothamBold
	caption.TextSize = 13
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.TextColor3 = WHITE
	caption.Text = title
	caption.Parent = row
	local function mini(kind: string, amount: number, position: UDim2, action: string)
		local button = Instance.new("TextButton")
		button.Position = position
		button.Size = UDim2.new(0.5, -44, 1, -4)
		button.BackgroundColor3 = if kind == "coin" then GOLD else BLUE
		button.AutoButtonColor = true
		button.Text = ""
		button.Parent = row
		corner(button, 10)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.Size = UDim2.fromOffset(0, 20)
		holder.AutomaticSize = Enum.AutomaticSize.X
		holder.Parent = button
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, 5)
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Parent = holder
		if kind == "coin" then
			coinBadge(holder, 15)
		else
			local icon = robuxBadge(holder, 15)
			icon.ImageColor3 = WHITE
		end
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, 20)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.TextColor3 = if kind == "coin" then Color3.fromRGB(40, 28, 12) else WHITE
		label.Text = money(amount)
		label.Parent = holder
		button.Activated:Connect(function()
			Remotes.get("Skins"):FireServer(action, id)
		end)
	end
	mini("coin", coins, UDim2.fromOffset(78, 2), if once then "buyOnce" else "buy")
	mini("robux", robux, UDim2.new(0.5, 38, 0, 2), if once then "robuxOnce" else "robux")
end

local function sale(price: number): number
	if state.discount > 0 and price > 0 then
		return math.max(1, math.floor(price * (100 - state.discount) / 100))
	end
	return price
end

local function resetBuyChrome()
	buyLayout.FillDirection = Enum.FillDirection.Horizontal
	buyLayout.Padding = UDim.new(0, 8)
	buyRow.Size = UDim2.new(1, -24, 0, 42)
	viewport.Size = UDim2.new(1, -20, 1, -168)
	perkStage.Size = UDim2.new(1, -20, 1, -168)
	previewName.Position = UDim2.new(0, 14, 1, -108)
	previewBlurb.Position = UDim2.new(0, 14, 1, -78)
end

local function expandBuyChrome()
	buyLayout.FillDirection = Enum.FillDirection.Vertical
	buyLayout.Padding = UDim.new(0, 6)
	buyRow.Size = UDim2.new(1, -24, 0, 86)
	viewport.Size = UDim2.new(1, -20, 1, -214)
	perkStage.Size = UDim2.new(1, -20, 1, -214)
	previewName.Position = UDim2.new(0, 14, 1, -158)
	previewBlurb.Position = UDim2.new(0, 14, 1, -128)
end

local function clearBuy()
	for _, child in buyRow:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function fillPerk(id: string, ownedForever: boolean)
	clearBuy()
	if ownedForever then
		resetBuyChrome()
		priceButton("Навсегда", Color3.fromRGB(70, 64, 88), WHITE, nil, nil, true, function() end)
		return
	end
	expandBuyChrome()
	local item = Shop.get(id)
	if not item then
		return
	end
	local stored = stock(id)
	if stored > 0 then
		buyRow.Size = UDim2.new(1, -24, 0, 110)
		perkStage.Size = UDim2.new(1, -20, 1, -238)
		previewName.Position = UDim2.new(0, 14, 1, -182)
		previewBlurb.Position = UDim2.new(0, 14, 1, -152)
		local have = Instance.new("TextLabel")
		have.BackgroundTransparency = 1
		have.Size = UDim2.new(1, 0, 0, 18)
		have.Font = Enum.Font.GothamBold
		have.TextSize = 13
		have.TextColor3 = GOLD
		have.Text = "В запасе на матч: " .. tostring(stored)
		have.LayoutOrder = 0
		have.Parent = buyRow
	end
	perkLine("1 матч", 1, id, sale(Shop.onceCoins(id)), Shop.onceRobux(id), true)
	perkLine("Навсегда", 2, id, sale(item.coins), item.robux, false)
end

local function fillBuy(kind: string, id: string, price: number, robux: number, ownedItem: boolean, equipped: boolean)
	clearBuy()
	resetBuyChrome()
	price = sale(price)
	if ownedItem and kind == "perk" then
		priceButton("Куплено", Color3.fromRGB(70, 64, 88), WHITE, nil, nil, true, function() end)
		return
	end
	if ownedItem or price <= 0 then
		priceButton(if equipped then "Надето" else "Надеть", if equipped then Color3.fromRGB(70, 64, 88) else GREEN, if equipped then WHITE else Color3.fromRGB(20, 32, 24), nil, nil, true, function()
			if equipped and kind == "skin" then
				Remotes.get("Skins"):FireServer("clear")
			elseif equipped and kind == "trail" then
				Remotes.get("Skins"):FireServer("clearTrail")
			elseif not equipped then
				Remotes.get("Skins"):FireServer("equip", id)
			end
		end)
		return
	end
	priceButton("", GOLD, Color3.fromRGB(40, 28, 12), "coin", price, false, function()
		Remotes.get("Skins"):FireServer("buy", id)
	end)
	priceButton("", BLUE, WHITE, "robux", robux, false, function()
		Remotes.get("Skins"):FireServer("robux", id)
	end)
end

function drawPerkIcon(parent: Instance, id: string, px: number)
	for _, child in parent:GetChildren() do
		child:Destroy()
	end
	local image = Instance.new("ImageLabel")
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromOffset(px, px)
	image.BackgroundTransparency = 1
	image.Image = PERK_ICONS[id] or PERK_ICONS.perk_jump
	image.ScaleType = Enum.ScaleType.Fit
	image.BorderSizePixel = 0
	image.Parent = parent
	corner(image, math.floor(px * 0.22))
end

local function showPerk(id: string)
	previewToken += 1
	shownKey = ""
	clearWorld()
	viewport.Visible = false
	perkStage.Visible = true
	loading.Text = ""
	drawPerkIcon(perkHost, id, 220)
	local image = perkHost:FindFirstChildOfClass("ImageLabel")
	if image then
		image.Size = UDim2.fromScale(1, 1)
	end
	local old = perkStage:FindFirstChild("Count")
	if old then
		old:Destroy()
	end
	local badge = Instance.new("TextLabel")
	badge.Name = "Count"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -10, 0, 10)
	badge.Size = UDim2.fromOffset(42, 22)
	badge.BackgroundColor3 = GOLD
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 14
	badge.TextColor3 = Color3.fromRGB(40, 28, 12)
	badge.Text = if state.owned[id] then "∞" else tostring(stock(id))
	badge.ZIndex = 6
	badge.Parent = perkStage
	corner(badge, 8)
end

local function showAvatar()
	viewport.Visible = true
	perkStage.Visible = false
end

local function describeSelection()
	if section == "skins" then
		local skin = Skins.get(selectedId)
		if not skin then
			return
		end
		local price = Shop.coins(skin.id, skin.price)
		previewName.Text = skin.name
		previewBlurb.Text = skin.blurb
		local ownedItem = owns(skin.id) or price <= 0
		fillBuy("skin", skin.id, price, Shop.robux(skin.id), ownedItem, state.equipped == skin.id)
		showAvatar()
		showLook("skin", skin.id)
	elseif section == "perks" then
		viewport.Visible = false
		perkStage.Visible = true
		local item = Shop.get(selectedId)
		if not item or item.kind ~= "perk" then
			return
		end
			previewName.Text = item.name
		previewBlurb.Text = item.blurb
		fillPerk(item.id, owns(item.id))
		showPerk(item.id)
	else
		local item = Shop.get(selectedId)
		if not item then
			return
		end
		previewName.Text = item.name
		previewBlurb.Text = item.blurb
		fillBuy("trail", item.id, item.coins, item.robux, owns(item.id), state.trail == item.id)
		showAvatar()
		showLook("trail", item.id)
	end
end

local function paintTabs()
	for id, button in sectionButtons do
		local on = id == section
		button.BackgroundColor3 = if on then Color3.fromRGB(255, 186, 120) else Color3.fromRGB(48, 42, 64)
		button.TextColor3 = if on then Color3.fromRGB(40, 28, 24) else WHITE
	end
	for id, button in filterButtons do
		local on = id == filter
		button.Visible = section == "skins"
		button.BackgroundColor3 = if on then Color3.fromRGB(255, 214, 160) else Color3.fromRGB(48, 42, 64)
		button.TextColor3 = if on then Color3.fromRGB(40, 28, 24) else WHITE
	end
end

local function card(id: string, order: number, nameText: string, image: string?, colors: { Color3 }?): TextButton
	local button = Instance.new("TextButton")
	button.Name = id
	button.LayoutOrder = order
	button.BackgroundColor3 = if id == selectedId then Color3.fromRGB(54, 46, 72) else CARD
	button.AutoButtonColor = true
	button.Text = ""
	button.BorderSizePixel = 0
	button.Parent = scroll
	corner(button, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = if id == selectedId then GOLD else Color3.fromRGB(70, 62, 88)
	stroke.Transparency = if id == selectedId then 0.15 else 0.45
	stroke.Thickness = if id == selectedId then 1.5 else 1
	stroke.Parent = button
	if image then
		local thumb = Instance.new("ImageLabel")
		thumb.BackgroundColor3 = INK
		thumb.Position = UDim2.fromOffset(10, 10)
		thumb.Size = UDim2.new(1, -20, 0, 92)
		thumb.Image = image
		thumb.ScaleType = Enum.ScaleType.Fit
		thumb.BorderSizePixel = 0
		thumb.Parent = button
		corner(thumb, 10)
	elseif colors then
		local bar = Instance.new("Frame")
		bar.BackgroundTransparency = 1
		bar.Position = UDim2.fromOffset(10, 28)
		bar.Size = UDim2.new(1, -20, 0, 36)
		bar.Parent = button
		local row = Instance.new("UIListLayout")
		row.FillDirection = Enum.FillDirection.Horizontal
		row.Padding = UDim.new(0, 3)
		row.Parent = bar
		for _, color in colors do
			local chip = Instance.new("Frame")
			chip.Size = UDim2.new(1 / math.max(#colors, 1), -3, 1, 0)
			chip.BackgroundColor3 = color
			chip.BorderSizePixel = 0
			chip.Parent = bar
			corner(chip, 8)
		end
	else
		local host = Instance.new("Frame")
		host.BackgroundTransparency = 1
		host.Position = UDim2.fromOffset(0, 8)
		host.Size = UDim2.new(1, 0, 0, 88)
		host.Parent = button
		drawPerkIcon(host, id, 52)
	end
	if section == "perks" then
		local badge = Instance.new("TextLabel")
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -8, 0, 8)
		badge.Size = UDim2.fromOffset(34, 18)
		badge.BackgroundColor3 = GOLD
		badge.Font = Enum.Font.GothamBold
		badge.TextSize = 12
		badge.TextColor3 = Color3.fromRGB(40, 28, 12)
		badge.Text = if state.owned[id] then "∞" else tostring(stock(id))
		badge.ZIndex = 5
		badge.Parent = button
		corner(badge, 8)
	end
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(10, if section == "skins" then 100 else 108)
	name.Size = UDim2.new(1, -20, 0, 40)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.TextWrapped = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.TextColor3 = WHITE
	name.Text = nameText
	name.Parent = button
	button.Activated:Connect(function()
		selectedId = id
		state.notice = ""
		-- rebuild selection highlight without dropping the typed search
		for _, child in scroll:GetChildren() do
			if child:IsA("TextButton") then
				local on = child.Name == id
				child.BackgroundColor3 = if on then Color3.fromRGB(54, 46, 72) else CARD
				local line = child:FindFirstChildOfClass("UIStroke")
				if line then
					line.Color = if on then GOLD else Color3.fromRGB(70, 62, 88)
					line.Transparency = if on then 0.15 else 0.45
					line.Thickness = if on then 1.5 else 1
				end
			end
		end
		describeSelection()
	end)
	return button
end

local function firstVisible(): string?
	if section == "skins" then
		for _, skin in Skins.all() do
			if (filter == "all" or skin.category == filter) and matches(skin.name) then
				return skin.id
			end
		end
	elseif section == "perks" then
		for _, item in Shop.perks() do
			if matches(item.name) then
				return item.id
			end
		end
	else
		for _, item in Shop.trails() do
			if matches(item.name) then
				return item.id
			end
		end
	end
	return nil
end

local function rebuild()
	for _, child in scroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	coinLabel.Text = money(state.coins)
	robuxLabel.Text = if robuxBalance then money(robuxBalance) else "—"
	if state.notice ~= "" then
		notice.Text = state.notice
	elseif state.discount > 0 then
		notice.Text = "Скидка " .. tostring(state.discount) .. "% на следующую покупку за монеты"
	end
	paintTabs()
	local seen = false
	local function mark(id: string)
		if id == selectedId then
			seen = true
		end
	end
	if section == "skins" then
		for _, skin in Skins.all() do
			if (filter == "all" or skin.category == filter) and matches(skin.name) then
				mark(skin.id)
			end
		end
	elseif section == "perks" then
		for _, item in Shop.perks() do
			if matches(item.name) then
				mark(item.id)
			end
		end
	else
		for _, item in Shop.trails() do
			if matches(item.name) then
				mark(item.id)
			end
		end
	end
	if not seen then
		local fallback = firstVisible()
		if fallback then
			selectedId = fallback
		end
	end
	local order = 0
	if section == "skins" then
		for _, skin in Skins.all() do
			if filter ~= "all" and skin.category ~= filter then
				continue
			end
			if not matches(skin.name) then
				continue
			end
			order += 1
			card(skin.id, order, skin.name, "rbxthumb://type=Asset&id=" .. tostring(skin.asset) .. "&w=150&h=150", nil)
		end
	elseif section == "perks" then
		for _, item in Shop.perks() do
			if not matches(item.name) then
				continue
			end
			order += 1
			card(item.id, order, item.name, PERK_ICONS[item.id], nil)
		end
	else
		for _, item in Shop.trails() do
			if not matches(item.name) then
				continue
			end
			order += 1
			card(item.id, order, item.name, TRAIL_ICONS[item.id], nil)
		end
	end
	describeSelection()
end

for index, category in sections do
	local button = Instance.new("TextButton")
	button.LayoutOrder = index
	button.Size = UDim2.fromOffset(108, 32)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Text = category.title
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Parent = toolbar
	corner(button, 10)
	sectionButtons[category.id] = button
	button.Activated:Connect(function()
		section = category.id
		state.notice = ""
		local fallback = firstVisible()
		if fallback then
			selectedId = fallback
		end
		shownKey = ""
		rebuild()
	end)
end

local search = Instance.new("TextBox")
search.LayoutOrder = 0
search.Size = UDim2.fromOffset(150, 26)
search.BackgroundColor3 = INK
search.Font = Enum.Font.Gotham
search.TextSize = 13
search.PlaceholderText = "Поиск"
search.PlaceholderColor3 = MUTED
search.TextColor3 = WHITE
search.Text = ""
search.ClearTextOnFocus = false
search.Parent = filterRow
corner(search, 10)
search:GetPropertyChangedSignal("Text"):Connect(function()
	query = string.lower(search.Text)
	rebuild()
end)

for index, category in filters do
	local button = Instance.new("TextButton")
	button.LayoutOrder = index
	button.Size = UDim2.fromOffset(96, 26)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.Text = category.title
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Parent = filterRow
	corner(button, 8)
	filterButtons[category.id] = button
	button.Activated:Connect(function()
		filter = category.id
		state.notice = ""
		rebuild()
	end)
end

RunService.RenderStepped:Connect(function(dt)
	if section == "perks" then
		viewport.Visible = false
		perkStage.Visible = true
		return
	end
	if not open or not shownModel or not shownModel.Parent then
		return
	end
	spin += dt * 0.45
	local eye = previewFocus + Vector3.new(math.sin(spin) * previewDist, previewDist * 0.12, math.cos(spin) * previewDist)
	camera.CFrame = CFrame.lookAt(eye, previewFocus)
end)

local function applyPayload(data)
	if typeof(data) ~= "table" then
		return
	end
	state.coins = tonumber(data.coins) or state.coins
	state.equipped = if typeof(data.equipped) == "string" then data.equipped else ""
	state.trail = if typeof(data.trail) == "string" then data.trail else state.trail
	state.owned = {}
	if typeof(data.owned) == "table" then
		for _, id in data.owned do
			if typeof(id) == "string" then
				state.owned[id] = true
			end
		end
	end
	if typeof(data.notice) == "string" then
		state.notice = data.notice
	end
	state.charges = {}
	if typeof(data.charges) == "table" then
		for id, count in data.charges do
			if typeof(id) == "string" then
				state.charges[id] = tonumber(count) or 0
			end
		end
	end
	state.discount = tonumber(data.discount) or 0
	state.armed = if typeof(data.armed) == "string" then data.armed else ""
	coinLabel.Text = money(state.coins)
	if open then
		rebuild()
	end
end

Remotes.get("SkinState").OnClientEvent:Connect(applyPayload)
Remotes.get("Economy").OnClientEvent:Connect(function(data)
	if typeof(data) == "table" and typeof(data.coins) == "number" then
		state.coins = data.coins
		coinLabel.Text = money(state.coins)
	end
end)

task.spawn(function()
	local ok, balance = pcall(function()
		return MarketplaceService:GetRobuxBalance()
	end)
	if ok and typeof(balance) == "number" then
		robuxBalance = balance
		robuxLabel.Text = money(balance)
	end
end)

dim.Activated:Connect(function()
	setOpen(false)
end)
close.Activated:Connect(function()
	setOpen(false)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not open then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape or (input.KeyCode == Enum.KeyCode.E and not search:IsFocused()) then
		setOpen(false)
	end
end)

player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") ~= nil then
		setOpen(false)
	end
end)

task.spawn(function()
	local podium = workspace:WaitForChild("World"):WaitForChild("Lobby"):WaitForChild("Podiums"):WaitForChild("Skins")
	local found: Instance? = nil
	local started = os.clock()
	while os.clock() - started < 20 do
		found = podium:FindFirstChild("ShopPrompt", true)
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
			state.notice = ""
			setOpen(true)
			shownKey = ""
			rebuild()
			Remotes.get("Skins"):FireServer("state")
		end)
	end
end)

rebuild()

return {}
