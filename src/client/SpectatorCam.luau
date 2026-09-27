--!strict
-- Камера-трансляция: облёт арены, переключение только между активными матчами.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local SpectatorCam = {}

local connection: RBXScriptConnection? = nil
local inputConnection: RBXScriptConnection? = nil
local gui: ScreenGui? = nil
local titleLabel: TextLabel? = nil
local pageLabel: TextLabel? = nil
local onStop: (() -> ())? = nil
local active = false
local watchCenter: Vector3? = nil

local function ensureGui()
	if gui then
		return
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "ColorPartySpectator"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 20
	screen.Enabled = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 14)
	bar.Size = UDim2.fromOffset(680, 54)
	bar.BackgroundColor3 = Color3.fromRGB(30, 28, 44)
	bar.BackgroundTransparency = 0.25
	bar.BorderSizePixel = 0
	bar.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = bar

	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(14, 14)
	dot.Position = UDim2.new(0, 18, 0.5, -7)
	dot.BackgroundColor3 = Color3.fromRGB(255, 80, 90)
	dot.BorderSizePixel = 0
	dot.Parent = bar
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot
	task.spawn(function()
		while dot.Parent do
			TweenService:Create(dot, TweenInfo.new(0.6), { BackgroundTransparency = 0.7 }):Play()
			task.wait(0.6)
			TweenService:Create(dot, TweenInfo.new(0.6), { BackgroundTransparency = 0 }):Play()
			task.wait(0.6)
		end
	end)

	local prev = Instance.new("TextButton")
	prev.Name = "Prev"
	prev.Size = UDim2.fromOffset(44, 36)
	prev.Position = UDim2.new(0, 42, 0.5, -18)
	prev.BackgroundColor3 = Color3.fromRGB(60, 58, 80)
	prev.Font = Enum.Font.GothamBlack
	prev.TextSize = 22
	prev.TextColor3 = Color3.new(1, 1, 1)
	prev.Text = "‹"
	prev.Parent = bar
	local prevC = Instance.new("UICorner")
	prevC.CornerRadius = UDim.new(0, 10)
	prevC.Parent = prev
	prev.Activated:Connect(function()
		Remotes.get("Spectate"):FireServer("prev")
	end)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(96, 0)
	title.Size = UDim2.new(1, -280, 1, 0)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "ТРАНСЛЯЦИЯ"
	title.Parent = bar
	titleLabel = title

	local page = Instance.new("TextLabel")
	page.Name = "Page"
	page.BackgroundTransparency = 1
	page.AnchorPoint = Vector2.new(1, 0.5)
	page.Position = UDim2.new(1, -138, 0.5, 0)
	page.Size = UDim2.fromOffset(72, 36)
	page.Font = Enum.Font.GothamMedium
	page.TextSize = 15
	page.TextColor3 = Color3.fromRGB(200, 210, 240)
	page.Text = "1 / 1"
	page.Parent = bar
	pageLabel = page

	local nextBtn = Instance.new("TextButton")
	nextBtn.Name = "Next"
	nextBtn.AnchorPoint = Vector2.new(1, 0.5)
	nextBtn.Position = UDim2.new(1, -148, 0.5, 0)
	nextBtn.Size = UDim2.fromOffset(44, 36)
	nextBtn.BackgroundColor3 = Color3.fromRGB(60, 58, 80)
	nextBtn.Font = Enum.Font.GothamBlack
	nextBtn.TextSize = 22
	nextBtn.TextColor3 = Color3.new(1, 1, 1)
	nextBtn.Text = "›"
	nextBtn.Parent = bar
	local nextC = Instance.new("UICorner")
	nextC.CornerRadius = UDim.new(0, 10)
	nextC.Parent = nextBtn
	nextBtn.Activated:Connect(function()
		Remotes.get("Spectate"):FireServer("next")
	end)

	local back = Instance.new("TextButton")
	back.Name = "Back"
	back.AnchorPoint = Vector2.new(1, 0.5)
	back.Position = UDim2.new(1, -10, 0.5, 0)
	back.Size = UDim2.fromOffset(120, 36)
	back.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	back.Font = Enum.Font.GothamBold
	back.TextSize = 16
	back.TextColor3 = Color3.fromRGB(40, 38, 54)
	back.Text = "Назад  [X]"
	back.AutoButtonColor = true
	back.Parent = bar
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 12)
	backCorner.Parent = back
	back.Activated:Connect(function()
		SpectatorCam.stop()
	end)
	gui = screen
end

local function bindCamera(center: Vector3)
	watchCenter = center
	if connection then
		connection:Disconnect()
	end
	local start = os.clock()
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - start) * 0.18
		local radius = 230
		local pos = center + Vector3.new(math.cos(t) * radius, 42 + math.sin(t * 0.7) * 6, math.sin(t) * radius)
		camera.CFrame = CFrame.lookAt(pos, center + Vector3.new(0, -6, 0))
	end)
end

function SpectatorCam.isActive(): boolean
	return active
end

export type SpectatePayload = {
	ok: boolean,
	message: string?,
	slot: number?,
	center: Vector3?,
	active: boolean?,
	index: number?,
	total: number?,
}

function SpectatorCam.apply(payload: SpectatePayload)
	if not payload.ok then
		SpectatorCam.stop(true)
		if payload.message and gui then
			ensureGui()
			gui.Enabled = true
			if titleLabel then
				titleLabel.Text = payload.message
			end
			if pageLabel then
				pageLabel.Text = ""
			end
			task.delay(2.5, function()
				if gui and not active then
					gui.Enabled = false
				end
			end)
		end
		return
	end
	local center = payload.center
	local slot = payload.slot
	if typeof(center) ~= "Vector3" or typeof(slot) ~= "number" then
		return
	end
	ensureGui()
	if not active then
		active = true
		camera.CameraType = Enum.CameraType.Scriptable
		if gui then
			gui.Enabled = true
		end
		if not inputConnection then
			inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
				if processed then
					return
				end
				if input.KeyCode == Enum.KeyCode.X then
					SpectatorCam.stop()
				elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Right then
					Remotes.get("Spectate"):FireServer("next")
				elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Left then
					Remotes.get("Spectate"):FireServer("prev")
				end
			end)
		end
	end
	local idx = payload.index or 1
	local total = payload.total or 1
	if titleLabel then
		local state = if payload.active then "идёт матч" else "ожидание игроков"
		titleLabel.Text = string.format("ТРАНСЛЯЦИЯ  ·  АРЕНА %d  ·  %s", slot + 1, state)
	end
	if pageLabel then
		pageLabel.Text = string.format("%d / %d", idx, total)
	end
	bindCamera(center)
end

-- Совместимость со старым вызовом (выбыл из матча).
function SpectatorCam.start(center: Vector3, title: string, _stopCallback: (() -> ())?)
	SpectatorCam.apply({
		ok = true,
		slot = 0,
		center = center,
		index = 1,
		total = 1,
	})
	if titleLabel then
		titleLabel.Text = title
	end
end

function SpectatorCam.stop(silent: boolean?)
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if active then
		Remotes.get("Spectate"):FireServer("stop")
	end
	active = false
	watchCenter = nil
	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
	end
	if gui then
		gui.Enabled = false
	end
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	if not silent and onStop then
		local callback = onStop
		onStop = nil
		callback()
	end
end

Remotes.get("Spectate").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if player:GetAttribute("InMatch") == nil or SpectatorCam.isActive() then
		SpectatorCam.apply(payload :: SpectatePayload)
	end
end)

return SpectatorCam
