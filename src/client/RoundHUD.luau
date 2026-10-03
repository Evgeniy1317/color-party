--!strict
-- HUD матча: карточка цвета с таймером, жизни, серия, счётчик игроков,
-- лента событий, экран результатов, режим зрителя после выбывания.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local SpectatorCam = require(script.Parent:WaitForChild("SpectatorCam"))

local player = Players.LocalPlayer

local RoundHUD = {}

local PANEL = Color3.fromRGB(30, 28, 44)
local WHITE = Color3.fromRGB(255, 255, 255)
local MUTED = Color3.fromRGB(190, 194, 214)

local function corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: GuiObject, name: string, text: string, size: number, font: Enum.Font, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function colorOf(id: string): Color3
	local def = Config.COLOR_BY_ID[id]
	return if def then def.color else WHITE
end

local function nameOf(id: string): string
	local def = Config.COLOR_BY_ID[id]
	return if def then def.name else id
end

local function textOn(color: Color3): Color3
	local luminance = 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B
	return if luminance > 0.6 then Color3.fromRGB(40, 38, 54) else WHITE
end

-- Каркас --------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "ColorPartyHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 15
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Карточка цвета.
local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 0, 10)
card.Size = UDim2.fromOffset(392, 100)
card.BackgroundColor3 = PANEL
card.BackgroundTransparency = 0
card.BorderSizePixel = 0
card.Visible = false
card.Parent = gui
corner(card, 18)
local cardStroke = Instance.new("UIStroke")
cardStroke.Thickness = 2
cardStroke.Color = Color3.fromRGB(255, 255, 255)
cardStroke.Transparency = 0.82
cardStroke.Parent = card

local swatch = Instance.new("Frame")
swatch.Name = "Swatch"
swatch.Position = UDim2.fromOffset(10, 10)
swatch.Size = UDim2.fromOffset(80, 80)
swatch.BackgroundColor3 = WHITE
swatch.BorderSizePixel = 0
swatch.ClipsDescendants = true
swatch.Parent = card
corner(swatch, 16)
local swatchB = Instance.new("Frame")
swatchB.Name = "SwatchB"
swatchB.AnchorPoint = Vector2.new(1, 0)
swatchB.Position = UDim2.fromScale(1, 0)
swatchB.Size = UDim2.fromScale(0.5, 1)
swatchB.BackgroundColor3 = WHITE
swatchB.BorderSizePixel = 0
swatchB.Visible = false
swatchB.Parent = card
corner(swatchB, 20)
local swatchMark = label(swatch, "Mark", "", 32, Enum.Font.GothamBlack, WHITE)
swatchMark.Size = UDim2.fromScale(1, 1)
swatchMark.ZIndex = 2

local roundLabel = label(card, "Round", "РАУНД 1", 12, Enum.Font.GothamBold, MUTED)
roundLabel.Position = UDim2.fromOffset(102, 8)
roundLabel.Size = UDim2.fromOffset(180, 16)
roundLabel.TextXAlignment = Enum.TextXAlignment.Left

local nameLabel = label(card, "Name", "СИНИЙ", 22, Enum.Font.GothamBlack, WHITE)
nameLabel.Position = UDim2.fromOffset(102, 24)
nameLabel.Size = UDim2.fromOffset(200, 28)
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.TextYAlignment = Enum.TextYAlignment.Center
nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

local subLabel = label(card, "Sub", "Встань на этот цвет!", 13, Enum.Font.GothamMedium, MUTED)
subLabel.Position = UDim2.fromOffset(102, 52)
subLabel.Size = UDim2.fromOffset(210, 16)
subLabel.TextXAlignment = Enum.TextXAlignment.Left

local barBack = Instance.new("Frame")
barBack.Name = "BarBack"
barBack.Position = UDim2.fromOffset(102, 74)
barBack.Size = UDim2.fromOffset(200, 10)
barBack.BackgroundColor3 = Color3.fromRGB(60, 58, 80)
barBack.BorderSizePixel = 0
barBack.Parent = card
corner(barBack, 7)
local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.Size = UDim2.fromScale(1, 1)
bar.BackgroundColor3 = WHITE
bar.BorderSizePixel = 0
bar.Parent = barBack
corner(bar, 7)

local timeLabel = label(card, "Time", "7.0", 18, Enum.Font.GothamBlack, WHITE)
timeLabel.Position = UDim2.fromOffset(312, 66)
timeLabel.Size = UDim2.fromOffset(68, 24)
timeLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Статус под карточкой: игроки, жизни, серия.
local status = Instance.new("Frame")
status.Name = "Status"
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.new(0.5, 0, 0, 116)
status.Size = UDim2.fromOffset(392, 34)
status.BackgroundColor3 = PANEL
status.BackgroundTransparency = 0.08
status.BorderSizePixel = 0
status.Visible = false
status.Parent = gui
corner(status, 12)

local aliveLabel = label(status, "Alive", "Осталось 5 / 5", 14, Enum.Font.GothamBold, WHITE)
aliveLabel.Position = UDim2.fromOffset(12, 0)
aliveLabel.Size = UDim2.fromOffset(150, 34)
aliveLabel.TextXAlignment = Enum.TextXAlignment.Left

local livesLabel = label(status, "Lives", "♥  ♥", 16, Enum.Font.GothamBlack, Color3.fromRGB(255, 120, 145))
livesLabel.Position = UDim2.fromOffset(156, 0)
livesLabel.Size = UDim2.fromOffset(70, 34)

local streakLabel = label(status, "Streak", "Серия  ×1.0", 14, Enum.Font.GothamBold, Color3.fromRGB(255, 214, 120))
streakLabel.AnchorPoint = Vector2.new(1, 0)
streakLabel.Position = UDim2.new(1, -12, 0, 0)
streakLabel.Size = UDim2.fromOffset(140, 34)
streakLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Лента событий.
local feed = Instance.new("Frame")
feed.Name = "Feed"
feed.AnchorPoint = Vector2.new(0, 0.5)
feed.Position = UDim2.new(0, 16, 0.62, 0)
feed.Size = UDim2.fromOffset(360, 160)
feed.BackgroundTransparency = 1
feed.Parent = gui
local feedLayout = Instance.new("UIListLayout")
feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
feedLayout.Padding = UDim.new(0, 6)
feedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
feedLayout.Parent = feed

-- Монеты.
local coinsFrame = Instance.new("Frame")
coinsFrame.Name = "Coins"
coinsFrame.AnchorPoint = Vector2.new(0, 1)
coinsFrame.Position = UDim2.new(0, 18, 1, -18)
coinsFrame.Size = UDim2.fromOffset(190, 44)
coinsFrame.BackgroundColor3 = PANEL
coinsFrame.BackgroundTransparency = 0.25
coinsFrame.BorderSizePixel = 0
coinsFrame.Parent = gui
corner(coinsFrame, 14)
local coinIcon = Instance.new("Frame")
coinIcon.Position = UDim2.fromOffset(12, 11)
coinIcon.Size = UDim2.fromOffset(22, 22)
coinIcon.BackgroundColor3 = Color3.fromRGB(255, 206, 84)
coinIcon.BorderSizePixel = 0
coinIcon.Parent = coinsFrame
corner(coinIcon, 11)
local coinsLabel = label(coinsFrame, "Value", "0", 18, Enum.Font.GothamBlack, WHITE)
coinsLabel.Position = UDim2.fromOffset(44, 0)
coinsLabel.Size = UDim2.fromOffset(130, 44)
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Большой баннер (ПРИГОТОВЬТЕСЬ / СМЕНА ЦВЕТА / ВЫ ВЫБЫЛИ).
local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.36)
banner.Size = UDim2.fromOffset(560, 110)
banner.BackgroundColor3 = PANEL
banner.BackgroundTransparency = 0.2
banner.BorderSizePixel = 0
banner.Visible = false
banner.Parent = gui
corner(banner, 24)
local bannerMain = label(banner, "Main", "", 44, Enum.Font.GothamBlack, WHITE)
bannerMain.Position = UDim2.fromOffset(0, 10)
bannerMain.Size = UDim2.new(1, 0, 0, 56)
bannerMain.TextScaled = true
local bannerSub = label(banner, "Sub", "", 18, Enum.Font.GothamMedium, MUTED)
bannerSub.Position = UDim2.fromOffset(0, 68)
bannerSub.Size = UDim2.new(1, 0, 0, 30)

-- Результаты.
local results = Instance.new("Frame")
results.Name = "Results"
results.AnchorPoint = Vector2.new(0.5, 0.5)
results.Position = UDim2.fromScale(0.5, 0.5)
results.Size = UDim2.fromOffset(520, 420)
results.BackgroundColor3 = PANEL
results.BackgroundTransparency = 0.1
results.BorderSizePixel = 0
results.Visible = false
results.Parent = gui
corner(results, 24)
local resultsTitle = label(results, "Title", "ПОБЕДИТЕЛЬ", 22, Enum.Font.GothamBold, Color3.fromRGB(255, 214, 120))
resultsTitle.Position = UDim2.fromOffset(0, 18)
resultsTitle.Size = UDim2.new(1, 0, 0, 28)
local resultsWinner = label(results, "Winner", "", 40, Enum.Font.GothamBlack, WHITE)
resultsWinner.Position = UDim2.fromOffset(20, 48)
resultsWinner.Size = UDim2.new(1, -40, 0, 52)
resultsWinner.TextScaled = true
local resultsList = Instance.new("Frame")
resultsList.Name = "List"
resultsList.Position = UDim2.fromOffset(30, 112)
resultsList.Size = UDim2.new(1, -60, 1, -150)
resultsList.BackgroundTransparency = 1
resultsList.Parent = results
local resultsLayout = Instance.new("UIListLayout")
resultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
resultsLayout.Padding = UDim.new(0, 4)
resultsLayout.Parent = resultsList
local resultsHint = label(results, "Hint", "Возвращение в лобби…", 15, Enum.Font.GothamMedium, MUTED)
resultsHint.AnchorPoint = Vector2.new(0.5, 1)
resultsHint.Position = UDim2.new(0.5, 0, 1, -14)
resultsHint.Size = UDim2.new(1, 0, 0, 20)

-- Логика --------------------------------------------------------------------

local timerConnection: RBXScriptConnection? = nil

local function stopTimer()
	if timerConnection then
		timerConnection:Disconnect()
		timerConnection = nil
	end
end

local function startTimer(duration: number, color: Color3)
	stopTimer()
	local startAt = os.clock()
	bar.BackgroundColor3 = color
	timerConnection = RunService.RenderStepped:Connect(function()
		local left = math.max(0, duration - (os.clock() - startAt))
		bar.Size = UDim2.fromScale(left / duration, 1)
		timeLabel.Text = string.format("%.1f", left)
		if left <= 0 then
			stopTimer()
		end
	end)
end

local function pop(frame: GuiObject)
	local scale = frame:FindFirstChild("PopScale")
	if not scale or not scale:IsA("UIScale") then
		scale = Instance.new("UIScale")
		scale.Name = "PopScale"
		scale.Parent = frame
	end
	scale.Scale = 0.94
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function showBanner(main: string, sub: string, color: Color3, seconds: number)
	bannerMain.Text = main
	bannerMain.TextColor3 = color
	bannerSub.Text = sub
	banner.Visible = true
	pop(banner)
	task.delay(seconds, function()
		if bannerMain.Text == main then
			banner.Visible = false
		end
	end)
end

local function colorFrom(packed: { { number } }?, index: number, fallbackId: string): Color3
	local item = packed and packed[index]
	if typeof(item) == "table" and typeof(item[1]) == "number" then
		return Color3.new(item[1], item[2], item[3])
	end
	return colorOf(fallbackId)
end

local function setCard(shown: { string }, mode: string, round: number, excluded: string?, colors: { { number } }?)
	local primary = shown[1]
	local color = colorFrom(colors, 1, primary)
	swatch.Position = UDim2.fromOffset(10, 10)
	swatch.Size = UDim2.fromOffset(80, 80)
	swatch.BackgroundColor3 = color
	swatchB.Visible = false
	swatchMark.Text = ""
	roundLabel.Text = "РАУНД " .. round
	if mode == "exclude" then
		nameLabel.Text = "КРОМЕ: " .. nameOf(excluded or primary)
		subLabel.Text = "Встань на ЛЮБОЙ другой цвет!"
		swatchMark.Text = "✕"
		swatchMark.TextColor3 = textOn(color)
	elseif mode == "double" and shown[2] then
		swatch.Size = UDim2.fromOffset(38, 80)
		swatchB.Visible = true
		swatchB.AnchorPoint = Vector2.new(0, 0)
		swatchB.Position = UDim2.fromOffset(52, 10)
		swatchB.Size = UDim2.fromOffset(38, 80)
		swatchB.BackgroundColor3 = colorFrom(colors, 2, shown[2])
		nameLabel.Text = nameOf(shown[1]) .. " / " .. nameOf(shown[2])
		subLabel.Text = "Подойдёт любой из двух цветов"
	else
		nameLabel.Text = nameOf(primary)
		subLabel.Text = "Встань на этот цвет!"
	end
	nameLabel.TextColor3 = WHITE
	card.Visible = true
	status.Visible = true
	pop(card)
end

local function updateLives()
	local lives = player:GetAttribute("Lives")
	if typeof(lives) ~= "number" then
		livesLabel.Text = ""
		return
	end
	livesLabel.Text = if lives >= 2 then "♥   ♥" elseif lives == 1 then "♥   ♡" else "♡   ♡"
end

local function updateStreak()
	local streak = player:GetAttribute("Streak")
	local value = if typeof(streak) == "number" then streak else 0
	streakLabel.Text = string.format("Серия ×%.1f", 1 + value * Config.ECONOMY.STREAK_STEP)
	if value >= 3 then
		streakLabel.TextColor3 = Color3.fromRGB(255, 160, 80)
	else
		streakLabel.TextColor3 = Color3.fromRGB(255, 214, 120)
	end
end

player:GetAttributeChangedSignal("Lives"):Connect(function()
	local before = livesLabel.Text
	updateLives()
	if before ~= livesLabel.Text and player:GetAttribute("Lives") == 1 then
		Effects.play("fall")
		Effects.flash(Color3.fromRGB(255, 120, 120), 0.35, 0.6)
		showBanner("МИНУС ЖИЗНЬ", "Ты на нижнем этаже. Ещё одно падение — вылет!", Color3.fromRGB(255, 130, 140), 2.2)
	end
end)
player:GetAttributeChangedSignal("Streak"):Connect(updateStreak)
player:GetAttributeChangedSignal("Shield"):Connect(function()
	if player:GetAttribute("Shield") then
		Effects.flash(Color3.fromRGB(112, 176, 255), 0.25, 0.45)
	end
end)

local function addFeed(text: string, kind: string)
	local spawnNote = string.find(text, "подбери", 1, true) ~= nil
	if kind ~= "out" and not spawnNote then
		return
	end
	local dash = string.find(text, "молни", 1, true) ~= nil
	local accent = if kind == "out"
		then Color3.fromRGB(255, 96, 112)
		elseif dash then Color3.fromRGB(255, 168, 64)
		else Color3.fromRGB(96, 186, 255)
	local item = Instance.new("Frame")
	item.Name = "Note"
	item.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	item.BackgroundTransparency = 0.08
	item.BorderSizePixel = 0
	item.Size = UDim2.fromOffset(340, 40)
	item.LayoutOrder = os.clock() * 1000
	item.Parent = feed
	corner(item, 8)
	local bar = Instance.new("Frame")
	bar.Name = "Accent"
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(0, 6, 1, 0)
	bar.Parent = item
	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.BackgroundTransparency = 1
	caption.Position = UDim2.fromOffset(18, 0)
	caption.Size = UDim2.new(1, -28, 1, 0)
	caption.Font = Enum.Font.GothamBlack
	caption.TextSize = 16
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.TextYAlignment = Enum.TextYAlignment.Center
	caption.TextTruncate = Enum.TextTruncate.AtEnd
	caption.TextWrapped = false
	caption.TextStrokeTransparency = 1
	caption.TextColor3 = Color3.fromRGB(244, 246, 252)
	caption.Text = text
	caption.Parent = item
	if spawnNote then
		local title = if dash then "Рывок" else "Щит"
		Effects.play("bonus")
		showBanner(title, text, accent, 2.2)
	end
	local notes = 0
	for _, child in feed:GetChildren() do
		if child.Name == "Note" then
			notes += 1
		end
	end
	while notes > 3 do
		local oldest
		for _, child in feed:GetChildren() do
			if child.Name == "Note" and (not oldest or child.LayoutOrder < oldest.LayoutOrder) then
				oldest = child
			end
		end
		if oldest then
			oldest:Destroy()
			notes -= 1
		else
			break
		end
	end
	task.delay(6, function()
		if item.Parent then
			TweenService:Create(item, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(caption, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
			TweenService:Create(bar, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			task.wait(0.35)
			item:Destroy()
		end
	end)
end

local function hideAll()
	stopTimer()
	card.Visible = false
	status.Visible = false
	banner.Visible = false
	results.Visible = false
end

local function showResults(data: { [string]: any })
	local winners = data.winners :: { string }
	resultsWinner.Text = if #winners == 0 then "НИЧЬЯ" else table.concat(winners, ", ")
	resultsTitle.Text = if #winners > 1 then "ПОБЕДИТЕЛИ" elseif #winners == 0 then "МАТЧ ОКОНЧЕН" else "ПОБЕДИТЕЛЬ"
	for _, child in resultsList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for index, row in data.standings :: { { [string]: any } } do
		local line = Instance.new("TextLabel")
		line.BackgroundColor3 = if row.winner then Color3.fromRGB(255, 206, 84) else Color3.fromRGB(60, 58, 80)
		line.BackgroundTransparency = if row.winner then 0.15 else 0.4
		line.BorderSizePixel = 0
		line.Size = UDim2.new(1, 0, 0, 26)
		line.Font = Enum.Font.GothamBold
		line.TextSize = 15
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextColor3 = if row.winner then Color3.fromRGB(40, 38, 54) else WHITE
		line.Text = string.format("  %d.  %s   ·   раундов: %d", row.place, row.name, row.rounds)
		line.LayoutOrder = index
		line.Parent = resultsList
		corner(line, 8)
		if index >= 10 then
			break
		end
	end
	results.Visible = true
	pop(results)
	local mine = false
	for _, name in winners do
		if name == player.DisplayName then
			mine = true
		end
	end
	Effects.play(if mine then "win" else "go")
	if mine then
		Effects.flash(Color3.fromRGB(255, 214, 90), 0.4, 1.2)
	end
end

local knockedOut = false

Remotes.get("MatchState").OnClientEvent:Connect(function(data)
	local phase = data.phase
	if phase == "prepare" then
		knockedOut = false
		hideAll()
		SpectatorCam.stop(true)
		updateLives()
		updateStreak()
		showBanner("ПРИГОТОВЬТЕСЬ", "Игроков: " .. tostring(data.total) .. "  ·  встань на цвет с карточки до конца таймера", WHITE, data.timeLeft)
		status.Visible = true
		aliveLabel.Text = "Игроков " .. tostring(data.total)
	elseif phase == "show" then
		if knockedOut then
			return
		end
		banner.Visible = false
		results.Visible = false
		setCard(data.shown, data.mode, data.round, data.excluded, data.colors)
		aliveLabel.Text = "Осталось " .. tostring(data.alive) .. " / " .. tostring(data.total)
		startTimer(data.time, colorFrom(data.colors, 1, data.shown[1]))
		Effects.play("go")
		if data.mode == "exclude" then
			showBanner("ЛЮБОЙ, КРОМЕ " .. nameOf(data.excluded), "Не стой на этом цвете!", colorOf(data.excluded), 1.6)
		elseif data.mode == "double" then
			showBanner("ДВА ЦВЕТА", "Подойдёт любой из двух", WHITE, 1.4)
		end
	elseif phase == "fake" then
		if knockedOut then
			return
		end
		local id = data.shown[1]
		setCard(data.shown, "normal", tonumber(string.match(roundLabel.Text, "%d+")) or 0, nil, data.colors)
		subLabel.Text = "СМЕНА ЦВЕТА!"
		subLabel.TextColor3 = Color3.fromRGB(255, 110, 110)
		startTimer(data.time, colorOf(id))
		Effects.play("fake")
		Effects.alertBorder(1.2)
		Effects.shake(card, 10, 0.5)
		showBanner("СМЕНА ЦВЕТА!", "Теперь нужен: " .. nameOf(id), colorOf(id), 1.4)
		task.delay(1.5, function()
			subLabel.TextColor3 = MUTED
		end)
	elseif phase == "drop" then
		if knockedOut then
			return
		end
		stopTimer()
		bar.Size = UDim2.fromScale(0, 1)
		timeLabel.Text = "0.0"
		subLabel.Text = "Плиты падают…"
		Effects.play("drop")
	elseif phase == "eliminated" then
		knockedOut = true
		hideAll()
		Effects.play("out")
		Effects.flash(Color3.fromRGB(255, 80, 90), 0.45, 0.8)
		showBanner("ТЫ ВЫБЫЛ", "Место: " .. tostring(data.place) .. "  ·  смотри матч до конца или нажми X", Color3.fromRGB(255, 130, 140), 4)
		Remotes.get("Spectate"):FireServer("start")
	elseif phase == "results" then
		stopTimer()
		card.Visible = false
		banner.Visible = false
		showResults(data)
	elseif phase == "end" then
		knockedOut = false
		hideAll()
		SpectatorCam.stop(true)
		for _, child in feed:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
end)

Remotes.get("RoundEvent").OnClientEvent:Connect(function(text, kind)
	addFeed(text, kind)
	if kind == "out" and not string.find(text, player.DisplayName, 1, true) then
		Effects.play("tick", 0.7)
	end
end)

Remotes.get("Economy").OnClientEvent:Connect(function(data)
	coinsLabel.Text = tostring(data.coins)
	if data.delta and data.delta > 0 and data.reason ~= "load" then
		Effects.play("coin", 1.05 + math.random() * 0.08)
		local popLabel = label(gui, "Delta", "+" .. tostring(data.delta), 20, Enum.Font.GothamBlack, Color3.fromRGB(255, 206, 84))
		popLabel.AnchorPoint = Vector2.new(0, 1)
		popLabel.Position = UDim2.new(0, 220, 1, -30)
		popLabel.Size = UDim2.fromOffset(80, 30)
		popLabel.TextXAlignment = Enum.TextXAlignment.Left
		TweenService:Create(popLabel, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 220, 1, -80),
			TextTransparency = 1,
		}):Play()
		task.delay(1, function()
			popLabel:Destroy()
		end)
	end
end)

Remotes.get("Reaction").OnClientEvent:Connect(function(name, text)
	addFeed(name .. ": " .. text, "info")
end)

player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") == nil then
		knockedOut = true
		stopTimer()
		card.Visible = false
		status.Visible = false
	end
end)

updateLives()
updateStreak()

return RoundHUD
