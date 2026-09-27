--!strict
-- Панель готовности: кнопка ГОТОВ, авто-готов, состояние очереди, кнопка «Смотреть».

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local player = Players.LocalPlayer

local ReadyUI = {}

local PANEL = Color3.fromRGB(30, 28, 44)
local ACCENT = Color3.fromRGB(120, 226, 160)
local ACCENT_OFF = Color3.fromRGB(255, 255, 255)

local ready = false
local auto = false

local function corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: GuiObject, text: string, size: number, font: Enum.Font, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local gui = Instance.new("ScreenGui")
gui.Name = "ColorPartyReady"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -18, 1, -18)
panel.Size = UDim2.fromOffset(300, 176)
panel.BackgroundColor3 = PANEL
panel.BackgroundTransparency = 0.22
panel.BorderSizePixel = 0
panel.Parent = gui
corner(panel, 18)

local title = label(panel, "COLOR PARTY", 16, Enum.Font.GothamBold, Color3.fromRGB(255, 214, 120))
title.Position = UDim2.fromOffset(18, 12)
title.Size = UDim2.new(1, -36, 0, 20)
title.TextXAlignment = Enum.TextXAlignment.Left

local queueText = label(panel, "В очереди: 0 / " .. Config.MAX_PLAYERS_PER_MATCH, 15, Enum.Font.GothamMedium, Color3.fromRGB(226, 228, 240))
queueText.Position = UDim2.fromOffset(18, 34)
queueText.Size = UDim2.new(1, -36, 0, 20)
queueText.TextXAlignment = Enum.TextXAlignment.Left

local statusText = label(panel, "Арены свободны", 13, Enum.Font.Gotham, Color3.fromRGB(180, 186, 210))
statusText.Position = UDim2.fromOffset(18, 54)
statusText.Size = UDim2.new(1, -36, 0, 18)
statusText.TextXAlignment = Enum.TextXAlignment.Left

local readyButton = Instance.new("TextButton")
readyButton.Name = "Ready"
readyButton.Position = UDim2.fromOffset(18, 80)
readyButton.Size = UDim2.new(1, -36, 0, 48)
readyButton.BackgroundColor3 = ACCENT_OFF
readyButton.Font = Enum.Font.GothamBlack
readyButton.TextSize = 22
readyButton.TextColor3 = Color3.fromRGB(40, 38, 54)
readyButton.Text = "ГОТОВ"
readyButton.AutoButtonColor = true
readyButton.Parent = panel
corner(readyButton, 14)

local autoButton = Instance.new("TextButton")
autoButton.Name = "Auto"
autoButton.Position = UDim2.fromOffset(18, 136)
autoButton.Size = UDim2.new(0.5, -22, 0, 28)
autoButton.BackgroundColor3 = Color3.fromRGB(60, 58, 80)
autoButton.Font = Enum.Font.GothamMedium
autoButton.TextSize = 13
autoButton.TextColor3 = Color3.fromRGB(226, 228, 240)
autoButton.Text = "☐  Авто-готов"
autoButton.Parent = panel
corner(autoButton, 10)

local watchButton = Instance.new("TextButton")
watchButton.Name = "Watch"
watchButton.AnchorPoint = Vector2.new(1, 0)
watchButton.Position = UDim2.new(1, -18, 0, 136)
watchButton.Size = UDim2.new(0.5, -22, 0, 28)
watchButton.BackgroundColor3 = Color3.fromRGB(60, 58, 80)
watchButton.Font = Enum.Font.GothamMedium
watchButton.TextSize = 13
watchButton.TextColor3 = Color3.fromRGB(226, 228, 240)
watchButton.Text = "▶  Смотреть арену"
watchButton.Parent = panel
corner(watchButton, 10)

local function refreshButtons()
	readyButton.Text = if ready then "ОТМЕНА" else "ГОТОВ"
	TweenService:Create(readyButton, TweenInfo.new(0.2), { BackgroundColor3 = if ready then ACCENT else ACCENT_OFF }):Play()
	autoButton.Text = (if auto then "☑" else "☐") .. "  Авто-готов"
	autoButton.BackgroundColor3 = if auto then Color3.fromRGB(88, 150, 110) else Color3.fromRGB(60, 58, 80)
end

readyButton.Activated:Connect(function()
	ready = not ready
	Effects.play("click")
	Remotes.get("SetReady"):FireServer(ready, auto)
	refreshButtons()
end)

autoButton.Activated:Connect(function()
	auto = not auto
	Effects.play("click")
	if auto and not ready then
		ready = true
	end
	Remotes.get("SetReady"):FireServer(ready, auto)
	refreshButtons()
end)

watchButton.Activated:Connect(function()
	Effects.play("click")
	Remotes.get("Spectate"):FireServer("start")
end)

-- Сервер — источник истины о готовности (атрибут Ready).
player:GetAttributeChangedSignal("Ready"):Connect(function()
	ready = player:GetAttribute("Ready") == true
	refreshButtons()
end)

player:GetAttributeChangedSignal("InMatch"):Connect(function()
	panel.Visible = player:GetAttribute("InMatch") == nil
end)
panel.Visible = player:GetAttribute("InMatch") == nil

Remotes.get("QueueUpdate").OnClientEvent:Connect(function(data)
	queueText.Text = "В очереди: " .. tostring(data.count) .. " / " .. tostring(data.max)
	local status
	if data.waitingArena then
		status = "Все арены заняты — ждём свободную"
	elseif #data.active > 0 then
		status = "Идёт матчей: " .. #data.active .. " из " .. tostring(data.arenas)
	else
		status = "Арены свободны"
	end
	if data.timeLeft and data.count > 0 then
		status ..= "  ·  старт через " .. math.ceil(data.timeLeft) .. " с"
	end
	statusText.Text = status
end)

return ReadyUI
