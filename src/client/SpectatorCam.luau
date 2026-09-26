--!strict
-- Камера-трансляция: облёт арены. Используется из лобби («Смотреть арену»)
-- и после выбывания из матча.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local SpectatorCam = {}

local connection: RBXScriptConnection? = nil
local inputConnection: RBXScriptConnection? = nil
local gui: ScreenGui? = nil
local titleLabel: TextLabel? = nil
local onStop: (() -> ())? = nil
local active = false

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
	bar.Size = UDim2.fromOffset(620, 54)
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

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(42, 0)
	title.Size = UDim2.new(1, -170, 1, 0)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "ТРАНСЛЯЦИЯ"
	title.Parent = bar
	titleLabel = title

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

function SpectatorCam.isActive(): boolean
	return active
end

function SpectatorCam.start(center: Vector3, title: string, stopCallback: (() -> ())?)
	ensureGui()
	SpectatorCam.stop(true)
	active = true
	onStop = stopCallback
	if titleLabel then
		titleLabel.Text = title
	end
	if gui then
		gui.Enabled = true
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local start = os.clock()
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - start) * 0.18
		local radius = 78
		local pos = center + Vector3.new(math.cos(t) * radius, 42 + math.sin(t * 0.7) * 6, math.sin(t) * radius)
		camera.CFrame = CFrame.lookAt(pos, center + Vector3.new(0, -6, 0))
	end)
	inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.X then
			SpectatorCam.stop()
		end
	end)
end

function SpectatorCam.stop(silent: boolean?)
	if not active then
		return
	end
	active = false
	if connection then
		connection:Disconnect()
		connection = nil
	end
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

return SpectatorCam
