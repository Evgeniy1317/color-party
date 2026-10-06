--!strict
-- Колесо фортуны: панель у стойки, секции и шансы под колесом.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Wheel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Wheel"))

local player = Players.LocalPlayer

local INK = Color3.fromRGB(28, 24, 40)
local WHITE = Color3.fromRGB(244, 240, 255)
local MUTED = Color3.fromRGB(176, 168, 198)
local GOLD = Color3.fromRGB(255, 206, 84)
local GREEN = Color3.fromRGB(88, 206, 138)
local BLUE = Color3.fromRGB(88, 140, 255)

local open = false
local spinning = false
local prompt: ProximityPrompt? = nil
local free = true
local coins = 0
local queued: { [string]: any }? = nil

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
dim.BackgroundTransparency = 0.48
dim.Text = ""
dim.AutoButtonColor = false
dim.BorderSizePixel = 0
dim.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.62, 0.82)
panel.BackgroundColor3 = Color3.fromRGB(22, 18, 34)
panel.BorderSizePixel = 0
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 18)
panelCorner.Parent = panel
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(760, 760)
limit.MinSize = Vector2.new(460, 640)
limit.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(22, 14)
title.Size = UDim2.new(1, -160, 0, 32)
title.Font = Enum.Font.GothamBlack
title.TextSize = 26
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = WHITE
title.Text = "Колесо фортуны"
title.Parent = panel

local coinLabel = Instance.new("TextLabel")
coinLabel.AnchorPoint = Vector2.new(1, 0)
coinLabel.Position = UDim2.new(1, -56, 0, 16)
coinLabel.Size = UDim2.fromOffset(120, 28)
coinLabel.BackgroundColor3 = INK
coinLabel.Font = Enum.Font.GothamBold
coinLabel.TextSize = 15
coinLabel.TextColor3 = GOLD
coinLabel.Text = "0"
coinLabel.Parent = panel
local coinCorner = Instance.new("UICorner")
coinCorner.CornerRadius = UDim.new(0, 10)
coinCorner.Parent = coinLabel

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
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 10)
closeCorner.Parent = close

local stage = Instance.new("Frame")
stage.AnchorPoint = Vector2.new(0.5, 0)
stage.Position = UDim2.new(0.5, 0, 0, 58)
stage.Size = UDim2.fromOffset(280, 280)
stage.BackgroundTransparency = 1
stage.Parent = panel

local rim = Instance.new("Frame")
rim.Size = UDim2.fromScale(1, 1)
rim.BackgroundColor3 = Color3.fromRGB(255, 214, 140)
rim.BorderSizePixel = 0
rim.Parent = stage
local rimCorner = Instance.new("UICorner")
rimCorner.CornerRadius = UDim.new(1, 0)
rimCorner.Parent = rim

local disc = Instance.new("Frame")
disc.AnchorPoint = Vector2.new(0.5, 0.5)
disc.Position = UDim2.fromScale(0.5, 0.5)
disc.Size = UDim2.new(1, -16, 1, -16)
disc.BackgroundColor3 = INK
disc.BorderSizePixel = 0
disc.ClipsDescendants = true
disc.Parent = rim
local discCorner = Instance.new("UICorner")
discCorner.CornerRadius = UDim.new(1, 0)
discCorner.Parent = disc

local function slice(angle: number, color: Color3, wide: number)
	local piece = Instance.new("Frame")
	piece.AnchorPoint = Vector2.new(0.5, 1)
	piece.Position = UDim2.fromScale(0.5, 0.5)
	piece.Size = UDim2.new(0, wide, 0.52, 0)
	piece.Rotation = angle
	piece.BackgroundColor3 = color
	piece.BorderSizePixel = 0
	piece.Parent = disc
end

for index = 0, 119 do
	local angle = index * 3 + 1.5
	slice(angle, Wheel.colorAt(angle), 12)
end

local cursor = 0
for _, sector in Wheel.sectors() do
	slice(cursor, Color3.fromRGB(28, 22, 40), 4)
	local mid = cursor + sector.chance / 100 * 180
	local rad = math.rad(mid)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5 + math.sin(rad) * 0.32, 0.5 - math.cos(rad) * 0.32)
	label.Size = UDim2.fromOffset(64, 18)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(28, 18, 32)
	label.Text = sector.short
	label.ZIndex = 2
	label.Parent = disc
	cursor += sector.chance / 100 * 360
end

local hub = Instance.new("Frame")
hub.AnchorPoint = Vector2.new(0.5, 0.5)
hub.Position = UDim2.fromScale(0.5, 0.5)
hub.Size = UDim2.fromOffset(74, 74)
hub.BackgroundColor3 = Color3.fromRGB(42, 34, 62)
hub.BorderSizePixel = 0
hub.ZIndex = 4
hub.Parent = stage
local hubCorner = Instance.new("UICorner")
hubCorner.CornerRadius = UDim.new(1, 0)
hubCorner.Parent = hub
local hubText = Instance.new("TextLabel")
hubText.BackgroundTransparency = 1
hubText.Size = UDim2.fromScale(1, 1)
hubText.Font = Enum.Font.GothamBlack
hubText.TextSize = 13
hubText.TextColor3 = WHITE
hubText.Text = "Удача"
hubText.ZIndex = 5
hubText.Parent = hub

local pointer = Instance.new("TextLabel")
pointer.AnchorPoint = Vector2.new(0.5, 0)
pointer.Position = UDim2.new(0.5, 0, 0, -6)
pointer.Size = UDim2.fromOffset(28, 24)
pointer.BackgroundTransparency = 1
pointer.Font = Enum.Font.GothamBlack
pointer.TextSize = 22
pointer.TextColor3 = Color3.fromRGB(255, 236, 190)
pointer.Text = "▼"
pointer.ZIndex = 6
pointer.Parent = stage

local result = Instance.new("TextLabel")
result.AnchorPoint = Vector2.new(0, 1)
result.BackgroundTransparency = 1
result.Position = UDim2.new(0, 24, 1, -232)
result.Size = UDim2.new(1, -48, 0, 36)
result.Font = Enum.Font.GothamBold
result.TextSize = 16
result.TextColor3 = WHITE
result.Text = "Один раз в день бесплатно. Дальше за монеты или робуксы."
result.TextWrapped = true
result.Parent = panel

local chances = Instance.new("Frame")
chances.AnchorPoint = Vector2.new(0, 1)
chances.BackgroundTransparency = 1
chances.Position = UDim2.new(0, 24, 1, -66)
chances.Size = UDim2.new(1, -48, 0, 160)
chances.Parent = panel
local chanceLayout = Instance.new("UIListLayout")
chanceLayout.Padding = UDim.new(0, 2)
chanceLayout.Parent = chances

for _, sector in Wheel.sectors() do
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 20)
	row.Parent = chances
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(14, 14)
	dot.Position = UDim2.fromOffset(0, 4)
	dot.BackgroundColor3 = sector.color
	dot.BorderSizePixel = 0
	dot.Parent = row
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(22, 0)
	name.Size = UDim2.new(1, -70, 1, 0)
	name.Font = Enum.Font.Gotham
	name.TextSize = 14
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = WHITE
	name.Text = sector.name .. "  ·  " .. sector.detail
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Parent = row
	local percent = Instance.new("TextLabel")
	percent.BackgroundTransparency = 1
	percent.AnchorPoint = Vector2.new(1, 0)
	percent.Position = UDim2.fromScale(1, 0)
	percent.Size = UDim2.fromOffset(48, 22)
	percent.Font = Enum.Font.GothamBold
	percent.TextSize = 14
	percent.TextXAlignment = Enum.TextXAlignment.Right
	percent.TextColor3 = MUTED
	percent.Text = tostring(sector.chance) .. "%"
	percent.Parent = row
end

local buttons = Instance.new("Frame")
buttons.AnchorPoint = Vector2.new(0, 1)
buttons.Position = UDim2.new(0, 24, 1, -16)
buttons.Size = UDim2.new(1, -48, 0, 42)
buttons.BackgroundTransparency = 1
buttons.Parent = panel
local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.Padding = UDim.new(0, 8)
buttonLayout.Parent = buttons

local function spinButton(text: string, color: Color3, ink: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1 / 3, -6, 1, 0)
	button.BackgroundColor3 = color
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.TextColor3 = ink
	button.Text = text
	button.Parent = buttons
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	return button
end

local freeButton = spinButton("Бесплатно", GREEN, Color3.fromRGB(20, 40, 28))
local coinButton = spinButton(tostring(Wheel.SPIN_COINS), GOLD, Color3.fromRGB(40, 28, 12))
local robuxButton = spinButton(tostring(Wheel.SPIN_ROBUX) .. " R$", BLUE, WHITE)

local function paintFree()
	freeButton.Text = if free then "Бесплатно" else "Завтра"
	freeButton.BackgroundColor3 = if free then GREEN else Color3.fromRGB(70, 64, 88)
	freeButton.TextColor3 = if free then Color3.fromRGB(20, 40, 28) else WHITE
	coinLabel.Text = tostring(coins)
end

local function setOpen(on: boolean)
	open = on
	gui.Enabled = on
	if prompt then
		prompt.Enabled = not on
	end
end

local function land(data: { [string]: any })
	local angle = tonumber(data.angle) or 0
	local current = disc.Rotation
	local want = (-angle) % 360
	local delta = (want - (current % 360)) % 360
	local goal = current + delta + 360 * 5
	spinning = true
	freeButton.AutoButtonColor = false
	coinButton.AutoButtonColor = false
	robuxButton.AutoButtonColor = false
	result.Text = "Крутится..."
	local tween = TweenService:Create(disc, TweenInfo.new(4.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Rotation = goal,
	})
	tween.Completed:Connect(function()
		spinning = false
		freeButton.AutoButtonColor = true
		coinButton.AutoButtonColor = true
		robuxButton.AutoButtonColor = true
		local titleText = if typeof(data.title) == "string" then data.title else "Приз"
		local detail = if typeof(data.detail) == "string" then data.detail else ""
		result.Text = titleText .. " — " .. detail
		paintFree()
		if queued then
			local nextSpin = queued
			queued = nil
			land(nextSpin)
		end
	end)
	tween:Play()
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
