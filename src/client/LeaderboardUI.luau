--!strict
-- Прозрачная таблица у кубка: топ-10 побед и своя строка, если ты ниже.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local player = Players.LocalPlayer

local WHITE = Color3.fromRGB(255, 248, 242)
local MUTED = Color3.fromRGB(186, 178, 204)
local GOLD = Color3.fromRGB(255, 206, 96)
local SILVER = Color3.fromRGB(210, 216, 228)
local BRONZE = Color3.fromRGB(214, 150, 96)
local INK = Color3.fromRGB(14, 12, 22)

local function winsWord(amount: number): string
	local n10 = amount % 10
	local n100 = amount % 100
	if n10 == 1 and n100 ~= 11 then
		return "победа"
	elseif n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14) then
		return "победы"
	end
	return "побед"
end

local function rankColor(place: number): Color3
	if place == 1 then
		return GOLD
	elseif place == 2 then
		return SILVER
	elseif place == 3 then
		return BRONZE
	end
	return MUTED
end

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function placePanel(): BasePart?
	local board = workspace:FindFirstChild("World")
	board = board and board:FindFirstChild("Lobby")
	board = board and board:FindFirstChild("Podiums")
	board = board and board:FindFirstChild("Board")
	if not board or not board:IsA("Model") then
		return nil
	end
	local sign = board:FindFirstChild("Sign")
	if not sign or not sign:IsA("BasePart") then
		return nil
	end
	local stray = board:FindFirstChild("LeaderPanel")
	if stray then
		stray:Destroy()
	end
	for _, child in sign:GetChildren() do
		if child:IsA("SurfaceGui") and child.Name ~= "Leaderboard" then
			child:Destroy()
		end
	end
	if sign:GetAttribute("LeaderHost") ~= true then
		local rotation = sign.CFrame.Rotation
		local bottom = sign.Position.Y - sign.Size.Y * 0.5
		local width = 20
		local height = 18
		sign.Size = Vector3.new(width, height, 0.2)
		sign.CFrame = CFrame.new(sign.Position.X, bottom + height * 0.5, sign.Position.Z) * rotation
		sign.Transparency = 1
		sign.CanCollide = false
		sign.CanQuery = false
		sign.CastShadow = false
		sign:SetAttribute("LeaderHost", true)
	end
	return sign
end

local surface: SurfaceGui? = nil
local list: Frame? = nil
local footer: Frame? = nil
local mounted = false

local function avatar(parent: Instance, userId: number, size: number)
	local image = Instance.new("ImageLabel")
	image.BackgroundColor3 = Color3.fromRGB(32, 28, 44)
	image.Size = UDim2.fromOffset(size, size)
	image.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=48&h=48"
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = parent
	corner(image, size)
end

local function row(parent: Instance, place: number, userId: number, name: string, wins: number, mine: boolean, order: number)
	local box = Instance.new("Frame")
	box.LayoutOrder = order
	box.Size = UDim2.new(1, 0, 0, if mine then 52 else 46)
	box.BackgroundColor3 = if mine then Color3.fromRGB(48, 38, 18) else Color3.fromRGB(255, 255, 255)
	box.BackgroundTransparency = if mine then 0.35 else 1
	box.BorderSizePixel = 0
	box.Parent = parent
	corner(box, 10)
	if mine then
		local stroke = Instance.new("UIStroke")
		stroke.Color = GOLD
		stroke.Transparency = 0.25
		stroke.Thickness = 1.25
		stroke.Parent = box
	end
	local placeLabel = Instance.new("TextLabel")
	placeLabel.BackgroundTransparency = 1
	placeLabel.Position = UDim2.fromOffset(8, 0)
	placeLabel.Size = UDim2.fromOffset(40, box.Size.Y.Offset)
	placeLabel.Font = Enum.Font.GothamBlack
	placeLabel.TextSize = if place <= 3 then 28 else 22
	placeLabel.TextColor3 = rankColor(place)
	placeLabel.Text = if place > 0 then tostring(place) else "—"
	placeLabel.Parent = box
	local head = Instance.new("Frame")
	head.BackgroundTransparency = 1
	head.Position = UDim2.fromOffset(46, if mine then 8 else 6)
	head.Size = UDim2.fromOffset(if mine then 36 else 34, if mine then 36 else 34)
	head.Parent = box
	avatar(head, userId, if mine then 36 else 34)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(90, 0)
	nameLabel.Size = UDim2.new(1, -230, 1, 0)
	nameLabel.Font = if mine then Enum.Font.GothamBold else Enum.Font.GothamMedium
	nameLabel.TextSize = 22
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.TextColor3 = if mine or place == 1 then GOLD else WHITE
	nameLabel.Text = name
	nameLabel.Parent = box
	local score = Instance.new("TextLabel")
	score.BackgroundTransparency = 1
	score.AnchorPoint = Vector2.new(1, 0)
	score.Position = UDim2.new(1, -8, 0, 0)
	score.Size = UDim2.fromOffset(130, box.Size.Y.Offset)
	score.Font = Enum.Font.GothamBold
	score.TextSize = 20
	score.TextXAlignment = Enum.TextXAlignment.Right
	score.TextColor3 = if place <= 3 or mine then GOLD else WHITE
	score.Text = tostring(wins) .. " " .. winsWord(wins)
	score.Parent = box
end

local function mount(host: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Leaderboard"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.25
	gui.MaxDistance = 140
	gui.Parent = host

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = INK
	root.BackgroundTransparency = 0.28
	root.BorderSizePixel = 0
	root.Parent = gui
	corner(root, 18)
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Transparency = 0.45
	stroke.Thickness = 1.5
	stroke.Parent = root

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(22, 16)
	title.Size = UDim2.new(1, -44, 0, 72)
	title.Font = Enum.Font.BuilderSansExtraBold
	title.TextSize = 60
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "Лидеры"
	title.Parent = root
	local titleTint = Instance.new("UIGradient")
	titleTint.Rotation = 90
	titleTint.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 248, 214)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 196, 72)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 122, 64)),
	})
	titleTint.Parent = title

	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(24, 90)
	subtitle.Size = UDim2.new(1, -48, 0, 26)
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 20
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.TextColor3 = MUTED
	subtitle.Text = "Победы в матчах"
	subtitle.Parent = root

	local line = Instance.new("Frame")
	line.Position = UDim2.fromOffset(22, 124)
	line.Size = UDim2.new(1, -44, 0, 2)
	line.BackgroundColor3 = GOLD
	line.BackgroundTransparency = 0.55
	line.BorderSizePixel = 0
	line.Parent = root

	local rows = Instance.new("Frame")
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(16, 138)
	rows.Size = UDim2.new(1, -32, 1, -210)
	rows.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows

	local mine = Instance.new("Frame")
	mine.AnchorPoint = Vector2.new(0, 1)
	mine.Position = UDim2.new(0, 16, 1, -16)
	mine.Size = UDim2.new(1, -32, 0, 52)
	mine.BackgroundTransparency = 1
	mine.Visible = false
	mine.Parent = root

	surface = gui
	list = rows
	footer = mine
end

local function show(data: { [string]: any })
	if not list or not footer then
		return
	end
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	for _, child in footer:GetChildren() do
		child:Destroy()
	end
	local top = data.top
	local me = data.me
	local myPlace = if typeof(me) == "table" and typeof(me.place) == "number" then me.place else 0
	if typeof(top) == "table" then
		local count = 0
		for _, entry in top do
			if typeof(entry) == "table" then
				count += 1
				local place = if typeof(entry.place) == "number" then entry.place else count
				local userId = if typeof(entry.userId) == "number" then entry.userId else 0
				local name = if typeof(entry.name) == "string" then entry.name else "Игрок"
				local wins = if typeof(entry.wins) == "number" then entry.wins else 0
				local mine = userId == player.UserId
				row(list, place, userId, name, wins, mine, place)
			end
		end
		if count == 0 then
			local empty = Instance.new("TextLabel")
			empty.BackgroundTransparency = 1
			empty.Size = UDim2.new(1, 0, 0, 36)
			empty.Font = Enum.Font.Gotham
			empty.TextSize = 14
			empty.TextColor3 = MUTED
			empty.Text = "Пока нет побед"
			empty.Parent = list
		end
	end
	footer.Visible = typeof(me) == "table" and myPlace > 10
	if footer.Visible and typeof(me) == "table" then
		local name = if typeof(me.name) == "string" then me.name else player.DisplayName
		local wins = if typeof(me.wins) == "number" then me.wins else 0
		row(footer, myPlace, player.UserId, name .. "  ·  ты", wins, true, 1)
	end
end

local function ensure()
	if mounted then
		return
	end
	local host = placePanel()
	if not host then
		return
	end
	mounted = true
	mount(host)
end

task.spawn(function()
	local started = os.clock()
	while not mounted and os.clock() - started < 30 do
		ensure()
		if not mounted then
			task.wait(0.5)
		end
	end
end)

Remotes.get("Leaderboard").OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end
	ensure()
	show(data)
end)

return {}
