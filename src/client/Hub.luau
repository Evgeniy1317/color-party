--!strict
-- Общие вкладки: инвентарь, магазин, колесо и квесты.
-- Сами окна остаются своими. Здесь только переключение.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

local Hub = {}

local player = Players.LocalPlayer

type OpenFn = (boolean) -> ()

local handlers: { [string]: OpenFn } = {}
local listeners: { (string) -> () } = {}
local current = ""

local TABS = {
	{ id = "inventory", title = "Inventory" },
	{ id = "shop", title = "Shop" },
	{ id = "wheel", title = "Wheel" },
	{ id = "quests", title = "Quests" },
}

local INK = Color3.fromRGB(32, 28, 24)
local CREAM = Color3.fromRGB(236, 228, 214)
local GOLD = Color3.fromRGB(186, 154, 96)
local MUTED = Color3.fromRGB(64, 56, 50)

local gui = Instance.new("ScreenGui")
gui.Name = "ColorPartyHub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 48
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.new(0.5, 0, 0, 52)
bar.Size = UDim2.fromOffset(560, 44)
bar.BackgroundColor3 = Color3.fromRGB(24, 22, 28)
bar.BorderSizePixel = 0
bar.Parent = gui
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 14)
barCorner.Parent = bar
local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(48, 42, 38)
barStroke.Thickness = 2
barStroke.Parent = bar
local barPad = Instance.new("UIPadding")
barPad.PaddingLeft = UDim.new(0, 6)
barPad.PaddingRight = UDim.new(0, 6)
barPad.Parent = bar
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.Parent = bar

local buttons: { [string]: TextButton } = {}

local function paint()
	for id, button in buttons do
		local on = id == current
		button.BackgroundColor3 = if on then GOLD else MUTED
		button.TextColor3 = if on then INK else CREAM
	end
	gui.Enabled = current ~= ""
end

local function notify()
	paint()
	for _, listener in listeners do
		listener(current)
	end
end

function Hub.bind(id: string, openFn: OpenFn)
	handlers[id] = openFn
end

function Hub.current(): string
	return current
end

function Hub.onChange(listener: (string) -> ())
	table.insert(listeners, listener)
end

function Hub.show(id: string)
	if player:GetAttribute("InMatch") ~= nil then
		return
	end
	if not handlers[id] then
		return
	end
	for name, openFn in handlers do
		if name ~= id then
			openFn(false)
		end
	end
	current = id
	handlers[id](true)
	notify()
end

function Hub.close()
	if current == "" then
		return
	end
	current = ""
	for _, openFn in handlers do
		openFn(false)
	end
	notify()
end

for _, tab in TABS do
	local button = Instance.new("TextButton")
	button.Name = tab.id
	button.Size = UDim2.fromOffset(132, 32)
	button.BackgroundColor3 = MUTED
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.TextColor3 = CREAM
	button.Text = Locale.t(tab.title)
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Parent = bar
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	button.Activated:Connect(function()
		Hub.show(tab.id)
	end)
	buttons[tab.id] = button
end

player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") ~= nil then
		Hub.close()
	end
end)

return Hub
