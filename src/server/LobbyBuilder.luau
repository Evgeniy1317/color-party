--!strict
-- Одноразовый сборщик лобби. Это ModuleScript: при Play он сам не запускается.
-- Вся геометрия запекается в место одним вызовом из Command Bar:
-- require(game.ServerScriptService.Server.LobbyBuilder).build()

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local InsertService = game:GetService("InsertService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Модели из Creator Store (бесплатные), кэшируются в ServerStorage.Assets при bake.
local TOOLBOX = {
	ConsoleKiosk = 12705353460, -- binkNYC kiosk
	LobbySpyglass = 126082088402161, -- Binoculars Spyglass Telescope Viewfinder
}

-- Текстуры, загруженные в Roblox (сгенерированы под этот проект).
local DOME_TEXTURE = "rbxassetid://101100163595514" -- бесшовная мягкая радуга
local FLOOR_TEXTURE = "rbxassetid://97432180622762" -- приглушённая пастельная мозаика
local SKY_SIDE_TEXTURE = "rbxassetid://127910635163308" -- градиент: периванкль → розовый горизонт
local SKY_UP_TEXTURE = "rbxassetid://102022452025820"
local SKY_DOWN_TEXTURE = "rbxassetid://92401397459718"

local SURFACE = 58
local LOBBY_RADIUS = 112
local LOBBY_Z = -180
local LOBBY_CENTER = Vector3.new(0, 0, LOBBY_Z)
local ARENA_RADIUS = 42
local FOREST_RADIUS = 84
local FOREST_Z = -408

local PALETTE = {
	stone = Color3.fromRGB(196, 184, 168),
	stoneDark = Color3.fromRGB(118, 106, 94),
	stoneDeep = Color3.fromRGB(78, 70, 64),
	trim = Color3.fromRGB(92, 84, 76),
	wood = Color3.fromRGB(124, 86, 58),
	woodDark = Color3.fromRGB(86, 60, 42),
	metal = Color3.fromRGB(176, 180, 186),
	metalDark = Color3.fromRGB(92, 96, 102),
	glass = Color3.fromRGB(186, 214, 224),
	neonWarm = Color3.fromRGB(255, 186, 122),
	neonCool = Color3.fromRGB(142, 196, 214),
	grass = Color3.fromRGB(96, 122, 78),
	dirt = Color3.fromRGB(122, 96, 72),
	water = Color3.fromRGB(92, 164, 186),
	gold = Color3.fromRGB(212, 168, 86),
	spawn = Color3.fromRGB(214, 202, 184),
	lava = Color3.fromRGB(186, 78, 36),
}

local ARENA_COLORS = {
	Color3.fromRGB(196, 72, 68),
	Color3.fromRGB(214, 146, 52),
	Color3.fromRGB(214, 196, 78),
	Color3.fromRGB(72, 156, 98),
	Color3.fromRGB(58, 132, 186),
	Color3.fromRGB(86, 92, 176),
	Color3.fromRGB(156, 86, 164),
	Color3.fromRGB(204, 104, 132),
}

local ZONES = {
	{ id = "Skins", title = "Магазин скинов", angle = 18, accent = Color3.fromRGB(212, 164, 96) },
	{ id = "Wheel", title = "Колесо фортуны", angle = 342, accent = Color3.fromRGB(164, 132, 196) },
	{ id = "Pets", title = "Магазин питомцев", angle = 150, accent = Color3.fromRGB(96, 168, 156) },
	{ id = "Board", title = "Лидерборд", angle = 198, accent = Color3.fromRGB(206, 146, 78) },
	{ id = "Quest", title = "Квесты", angle = 238, accent = Color3.fromRGB(112, 148, 186) },
}

local CHECKPOINT_SCRIPT = [=[
local Players = game:GetService("Players")
local pads = {}
for _, pad in script.Parent:GetChildren() do
	if pad:IsA("BasePart") and typeof(pad:GetAttribute("Index")) == "number" then
		local index = pad:GetAttribute("Index")
		pads[index] = pad
		pad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then
				return
			end
			local current = player:GetAttribute("ParkourCheckpoint")
			if typeof(current) == "number" and current >= index then
				return
			end
			player:SetAttribute("ParkourCheckpoint", index)
		end)
	end
end

local lobbyFloor = workspace:WaitForChild("World"):WaitForChild("Lobby"):WaitForChild("Floor")
lobbyFloor.Touched:Connect(function(hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if player and player:GetAttribute("ParkourCheckpoint") ~= nil then
		player:SetAttribute("ParkourCheckpoint", nil)
	end
end)

local function watch(player)
	player.CharacterAdded:Connect(function(character)
		local index = player:GetAttribute("ParkourCheckpoint")
		local pad = if typeof(index) == "number" then pads[index] else nil
		if not pad then
			return
		end
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root then
			task.wait(0.1)
			character:PivotTo(pad.CFrame + Vector3.new(0, 4, 0))
		end
	end)
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end
]=]

local RETURN_SCRIPT = [=[
local Players = game:GetService("Players")
local pad = script.Parent
local target = workspace:WaitForChild("World"):WaitForChild("Lobby"):WaitForChild("LobbySpawn")
local busy = {}
pad.Touched:Connect(function(hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player or busy[player] then
		return
	end
	busy[player] = true
	player:SetAttribute("ParkourCheckpoint", nil)
	hit.Parent:PivotTo(target.CFrame + Vector3.new(0, 4, 0))
	task.delay(1, function()
		busy[player] = nil
	end)
end)
]=]

local OBSTACLE_SCRIPT = [=[
local folder = script.Parent

local function bindDisappear(part)
	local restore = part:GetAttribute("Restore")
	if typeof(restore) ~= "number" then
		restore = 1.4
	end
	local busy = false
	part.Touched:Connect(function(hit)
		if busy or not hit.Parent:FindFirstChildOfClass("Humanoid") then
			return
		end
		busy = true
		local transparency = part.Transparency
		part.CanCollide = false
		part.Transparency = 0.88
		task.wait(restore)
		part.CanCollide = true
		part.Transparency = transparency
		task.wait(0.3)
		busy = false
	end)
end

local lastBounce = {}
local function bindBounce(part)
	local power = part:GetAttribute("Bounce")
	if typeof(power) ~= "number" then
		power = 86
	end
	part.Touched:Connect(function(hit)
		local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
		local root = hit.Parent:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root then
			return
		end
		local now = os.clock()
		if lastBounce[humanoid] and now - lastBounce[humanoid] < 0.45 then
			return
		end
		lastBounce[humanoid] = now
		root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X * 0.25, power, root.AssemblyLinearVelocity.Z * 0.25)
	end)
end

for _, child in folder:GetChildren() do
	if child:IsA("BasePart") then
		if child:GetAttribute("Disappear") == true then
			bindDisappear(child)
		end
		if typeof(child:GetAttribute("Bounce")) == "number" then
			bindBounce(child)
		end
	end
end
]=]

local SWING_SCRIPT = [=[
local RunService = game:GetService("RunService")
local hinges = {}
for _, descendant in script.Parent:GetDescendants() do
	if descendant:IsA("HingeConstraint") and descendant.Name == "SwingHinge" then
		table.insert(hinges, descendant)
	end
end

local direction = 1
while true do
	direction *= -1
	for _, hinge in hinges do
		local angle = hinge:GetAttribute("Swing")
		if typeof(angle) ~= "number" then
			angle = 40
		end
		hinge.TargetAngle = angle * direction
	end
	task.wait(3.1)
	if not RunService:IsRunning() then
		break
	end
end
]=]

local VOID_SCRIPT = [=[
local pad = script.Parent:WaitForChild("Void")

pad.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end)
]=]

local DAY_SCRIPT = [=[
local Lighting = game:GetService("Lighting")
local elapsed = 0
game:GetService("RunService").Heartbeat:Connect(function(dt)
	elapsed += dt
	Lighting.ClockTime = 14.2 + math.sin(elapsed / 90) * 0.35
end)
]=]

local MOTION_SCRIPT = [=[
local RunService = game:GetService("RunService")
local elapsed = 0
local bases = {}

RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	for _, item in script.Parent:GetDescendants() do
		if not item:IsA("BasePart") then
			continue
		end
		local bob = item:GetAttribute("Bob")
		if typeof(bob) == "number" then
			local base = bases[item]
			if not base then
				base = item.CFrame
				bases[item] = base
			end
			local offset = math.sin(elapsed * bob + base.Position.X * 0.15) * 0.45
			item.CFrame = base + Vector3.new(0, offset, 0)
		end
		local spin = item:GetAttribute("Spin")
		if typeof(spin) == "number" then
			local base = bases[item]
			if not base then
				base = item.CFrame
				bases[item] = base
			end
			local yaw = math.rad(spin * elapsed)
			local center = item:GetAttribute("SpinCenter")
			if typeof(center) == "Vector3" then
				item.CFrame = CFrame.new(center) * CFrame.Angles(0, yaw, 0) * (CFrame.new(center):Inverse() * base)
			else
				item.CFrame = CFrame.new(base.Position) * CFrame.Angles(0, yaw, 0) * (base - base.Position)
			end
		end
		local hueSpeed = item:GetAttribute("HueCycle")
		if typeof(hueSpeed) == "number" then
			local start = item:GetAttribute("Hue0")
			if typeof(start) ~= "number" then
				start = 0
			end
			item.Color = Color3.fromHSV((elapsed * hueSpeed + start) % 1, 0.9, 1)
			local light = item:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = item.Color
			end
		end
		local pulse = item:GetAttribute("Pulse")
		if typeof(pulse) == "number" then
			local base = bases[item]
			if not base then
				base = item.CFrame
				bases[item] = base
			end
			local tall = 1.4 + math.abs(math.sin(elapsed * pulse + base.Position.X)) * 7
			item.Size = Vector3.new(item.Size.X, tall, item.Size.Z)
			item.CFrame = CFrame.new(base.Position.X, 58 + tall / 2, base.Position.Z) * (base - base.Position)
		end
	end
end)
]=]

local TITLE_SCRIPT = [=[
-- Радуга бежит по буквам: градиент из 8 цветов, оттенок сдвигается каждый кадр.
local label = script.Parent:WaitForChild("Title"):WaitForChild("Title")
label.TextColor3 = Color3.new(1, 1, 1)
local gradient = label:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
gradient.Rotation = 0
gradient.Parent = label

local STEPS = 8
local shift = 0
local function build(offset)
	local keypoints = table.create(STEPS + 1)
	for index = 0, STEPS do
		local hue = (index / STEPS + offset) % 1
		keypoints[index + 1] = ColorSequenceKeypoint.new(index / STEPS, Color3.fromHSV(hue, 0.85, 1))
	end
	return ColorSequence.new(keypoints)
end

local accumulator = 0
game:GetService("RunService").Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 1 / 30 then
		return
	end
	shift = (shift + accumulator * 0.35) % 1
	accumulator = 0
	gradient.Color = build(shift)
end)
]=]

local REWARD_SCRIPT = [=[
local prompt = script.Parent:WaitForChild("Open")
local burst = script.Parent:FindFirstChild("Burst")
prompt.Triggered:Connect(function(player)
	if player:GetAttribute("ParkourReward") == true then
		return
	end
	player:SetAttribute("ParkourReward", true)
	prompt.ActionText = "Claimed"
	if burst and burst:IsA("ParticleEmitter") then
		burst.Enabled = true
		task.delay(1.4, function()
			burst.Enabled = false
		end)
	end
end)
]=]

local function subfolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function part(props: {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material,
	Parent: Instance,
	Shape: Enum.PartType?,
	CanCollide: boolean?,
	Transparency: number?,
}): Part
	local item = Instance.new("Part")
	item.Name = props.Name
	item.Anchored = true
	item.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Material = props.Material
	item.Color = props.Color
	item.Size = props.Size
	item.CFrame = props.CFrame
	item.Transparency = props.Transparency or 0
	item.Reflectance = 0
	item.CastShadow = props.Material ~= Enum.Material.Neon and props.Material ~= Enum.Material.Glass
	if props.Shape then
		item.Shape = props.Shape
	end
	item.Parent = props.Parent
	return item
end

local function disc(name: string, radius: number, thickness: number, center: Vector3, color: Color3, material: Enum.Material, parent: Instance, canCollide: boolean?): Part
	return part({
		Name = name,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
		Shape = Enum.PartType.Cylinder,
		Parent = parent,
		CanCollide = canCollide,
	})
end

local function pointOnLobby(angleDegrees: number, radius: number, y: number): Vector3
	local angle = math.rad(angleDegrees)
	return Vector3.new(LOBBY_CENTER.X + math.cos(angle) * radius, y, LOBBY_CENTER.Z + math.sin(angle) * radius)
end

local function lobbyAssets(): Folder
	local assets = ServerStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ServerStorage
	end
	return assets :: Folder
end

local function stripToolScripts(root: Instance)
	for _, item in root:GetDescendants() do
		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then
			item:Destroy()
		end
	end
end

local function ensureToolboxTemplate(name: string, assetId: number): Model?
	local assets = lobbyAssets()
	local existing = assets:FindFirstChild(name)
	if existing and existing:IsA("Model") then
		return existing
	end
	local ok, loaded = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not loaded then
		warn("[LobbyBuilder] не удалось загрузить toolbox " .. name .. ": " .. tostring(loaded))
		return nil
	end
	local model: Model? = nil
	for _, child in loaded:GetChildren() do
		if child:IsA("Model") then
			model = child
			break
		end
	end
	loaded:Destroy()
	if not model then
		return nil
	end
	stripToolScripts(model)
	model.Name = name
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	model.Parent = assets
	return model
end

local function cloneToolbox(name: string, assetId: number): Model?
	local template = ensureToolboxTemplate(name, assetId)
	return if template then template:Clone() else nil
end

local function pivotModelBottom(model: Model, cf: CFrame)
	local _, size = model:GetBoundingBox()
	model:PivotTo(cf * CFrame.new(0, size.Y / 2, 0))
end

-- Табло на стене: фиксированный размер в студах, текст не раздувается с дистанцией.
local function buildArenaBoard(parent: Instance, cf: CFrame): BasePart
	local white = Color3.fromRGB(248, 248, 252)
	local dark = Color3.fromRGB(28, 26, 40)
	local gold = Color3.fromRGB(255, 214, 120)
	local muted = Color3.fromRGB(176, 182, 206)
	part({
		Name = "MatchSignFrame",
		Size = Vector3.new(14.4, 16.6, 0.22),
		CFrame = cf * CFrame.new(0, 0, 0.08),
		Color = white,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = parent,
	})
	local sign = part({
		Name = "MatchSign",
		Size = Vector3.new(13.6, 15.8, 0.2),
		CFrame = cf,
		Color = dark,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 36
	gui.LightInfluence = 0.1
	gui.Brightness = 1.3
	gui.Parent = sign

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0.14, 0)
	header.BackgroundColor3 = gold
	header.BorderSizePixel = 0
	header.Parent = gui
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 1)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 42
	title.TextColor3 = dark
	title.Text = "КТО СЕЙЧАС ИГРАЕТ"
	title.Parent = header

	local function columnHead(labelName: string, x: number, text: string, align: Enum.TextXAlignment)
		local l = Instance.new("TextLabel")
		l.Name = labelName
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(x, 0.145)
		l.Size = UDim2.fromScale(0.42, 0.07)
		l.Font = Enum.Font.GothamBold
		l.TextSize = 22
		l.TextXAlignment = align
		l.TextColor3 = muted
		l.Text = text
		l.Parent = gui
	end
	columnHead("HeadArena", 0.08, "АРЕНА", Enum.TextXAlignment.Left)
	columnHead("HeadPlayers", 0.5, "ИГРОКИ", Enum.TextXAlignment.Right)

	for index = 1, 6 do
		local row = Instance.new("Frame")
		row.Name = "Row" .. index
		row.Position = UDim2.new(0.05, 0, 0.22 + (index - 1) * 0.1, 0)
		row.Size = UDim2.new(0.9, 0, 0.09, 0)
		row.BackgroundColor3 = if index % 2 == 0 then Color3.fromRGB(46, 44, 62) else Color3.fromRGB(38, 36, 52)
		row.BorderSizePixel = 0
		row.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.28, 0)
		corner.Parent = row
		local name = Instance.new("TextLabel")
		name.Name = "A" .. index
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromScale(0.05, 0)
		name.Size = UDim2.fromScale(0.5, 1)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 30
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = white
		name.Text = "Арена  " .. index
		name.Parent = row
		local count = Instance.new("TextLabel")
		count.Name = "C" .. index
		count.BackgroundTransparency = 1
		count.Position = UDim2.fromScale(0.52, 0)
		count.Size = UDim2.fromScale(0.42, 1)
		count.Font = Enum.Font.GothamBlack
		count.TextSize = 32
		count.TextXAlignment = Enum.TextXAlignment.Right
		count.TextColor3 = muted
		count.Text = "—"
		count.Parent = row
	end

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.Position = UDim2.fromScale(0, 0.84)
	footer.Size = UDim2.fromScale(1, 0.16)
	footer.BackgroundColor3 = Color3.fromRGB(22, 48, 40)
	footer.BorderSizePixel = 0
	footer.Parent = gui
	local queue = Instance.new("TextLabel")
	queue.Name = "Queue"
	queue.BackgroundTransparency = 1
	queue.Size = UDim2.fromScale(1, 1)
	queue.Font = Enum.Font.GothamBold
	queue.TextSize = 26
	queue.TextColor3 = Color3.fromRGB(186, 236, 206)
	queue.Text = "Готовы к матчу    0 / 5"
	queue.Parent = footer
	return sign
end

local function addScript(parent: Instance, name: string, source: string)
	local runtime = Instance.new("Script")
	runtime.Name = name
	runtime.Source = source
	runtime.Parent = parent
end

local function marker(parent: BasePart, text: string, color: Color3, offset: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Marker"
	billboard.Size = UDim2.fromOffset(120, 48)
	billboard.StudsOffset = Vector3.new(0, offset, 0)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0.4
	billboard.MaxDistance = 180
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.45
	label.Parent = billboard
end

local function arcSegment(
	parent: Instance,
	name: string,
	midAngle: number,
	chord: number,
	radius: number,
	y: number,
	height: number,
	thickness: number,
	color: Color3,
	material: Enum.Material,
	transparency: number,
	canCollide: boolean
)
	local position = pointOnLobby(math.deg(midAngle), radius, y)
	local tangent = Vector3.new(-math.sin(midAngle), 0, math.cos(midAngle))
	part({
		Name = name,
		Size = Vector3.new(thickness, height, chord + 1.1),
		CFrame = CFrame.lookAt(position, position + tangent),
		Color = color,
		Material = material,
		Transparency = transparency,
		CanCollide = canCollide,
		Parent = parent,
	})
end

local LobbyBuilder = {}

function LobbyBuilder.buildArena(world: Folder)
	local arena = subfolder(world, "Arena")
	local top = 2
	disc("Floor", ARENA_RADIUS, 2.2, Vector3.new(0, top - 1.1, 0), PALETTE.stoneDark, Enum.Material.Slate, arena)
	disc("Rim", ARENA_RADIUS + 1.4, 0.35, Vector3.new(0, top + 0.15, 0), PALETTE.stoneDeep, Enum.Material.Cobblestone, arena, false)

	for index, color in ARENA_COLORS do
		local angle = (index - 1) * math.pi / 4
		local position = Vector3.new(math.cos(angle) * 20, top + 0.35, math.sin(angle) * 20)
		part({
			Name = "Tile" .. index,
			Size = Vector3.new(12, 0.45, 12),
			CFrame = CFrame.new(position) * CFrame.Angles(0, angle, 0),
			Color = color,
			Material = Enum.Material.Concrete,
			Parent = arena,
		})
	end

	disc("Center", 8, 0.4, Vector3.new(0, top + 0.45, 0), PALETTE.stone, Enum.Material.Marble, arena)
end

function LobbyBuilder.buildLobby(world: Folder)
	local lobby = subfolder(world, "Lobby")
	local thickness = 3.2
	local floor = disc("Floor", LOBBY_RADIUS, thickness, Vector3.new(0, SURFACE - thickness / 2, LOBBY_Z), Color3.fromRGB(196, 190, 200), Enum.Material.SmoothPlastic, lobby)
	disc("Trim", LOBBY_RADIUS + 1.2, 0.6, Vector3.new(0, SURFACE - thickness - 0.2, LOBBY_Z), Color3.fromRGB(78, 70, 86), Enum.Material.SmoothPlastic, lobby)

	-- Пол расписан мягкой мозаикой: одна текстура вместо отдельных плиток.
	-- Диск повёрнут так, что его верхняя крышка — локальная грань Right.
	local mosaic = Instance.new("Texture")
	mosaic.Name = "Mosaic"
	mosaic.Texture = FLOOR_TEXTURE
	mosaic.Face = Enum.NormalId.Right
	mosaic.StudsPerTileU = 48
	mosaic.StudsPerTileV = 48
	mosaic.Parent = floor

	-- Отметка спавна: медальон из пастельных колец, вращающийся ореол с жемчужинами и лёгкие искры.
	local center = Vector3.new(0, SURFACE, LOBBY_Z)
	local pearl = Color3.fromRGB(250, 250, 253)
	disc("SpawnBase", 9.5, 0.22, center + Vector3.new(0, 0.11, 0), pearl, Enum.Material.SmoothPlastic, lobby, false)
	local rings = {
		{ 8.6, Color3.fromHSV(0.62, 0.22, 0.86) },
		{ 7.1, pearl },
		{ 6.4, Color3.fromHSV(0.86, 0.22, 0.88) },
		{ 4.9, pearl },
		{ 4.2, Color3.fromHSV(0.12, 0.22, 0.9) },
		{ 2.6, pearl },
		{ 1.9, Color3.fromHSV(0.42, 0.22, 0.88) },
	}
	for index, ring in rings do
		disc("SpawnRing" .. index, ring[1], 0.06, center + Vector3.new(0, 0.26 + index * 0.02, 0), ring[2], Enum.Material.SmoothPlastic, lobby, false)
	end
	local halo = disc("SpawnHalo", 10.3, 0.12, center + Vector3.new(0, 0.6, 0), pearl, Enum.Material.SmoothPlastic, lobby, false)
	halo.Transparency = 1
	for index = 0, 11 do
		local angle = (index / 12) * math.pi * 2
		local pos = center + Vector3.new(math.cos(angle) * 10.3, 0.7, math.sin(angle) * 10.3)
		local bead = part({
			Name = "SpawnBead",
			Size = Vector3.new(0.9, 0.9, 0.9),
			CFrame = CFrame.new(pos),
			Color = Color3.fromHSV(index / 12, 0.24, 0.96),
			Material = Enum.Material.SmoothPlastic,
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			Parent = lobby,
		})
		bead:SetAttribute("Spin", 18)
		bead:SetAttribute("SpinCenter", center)
	end
	local sparkAnchor = part({
		Name = "SpawnSparks",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(center + Vector3.new(0, 1.5, 0)),
		Color = pearl,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 1,
		CanCollide = false,
		Parent = lobby,
	})
	local sparks = Instance.new("ParticleEmitter")
	sparks.Rate = 6
	sparks.Lifetime = NumberRange.new(1.8, 3)
	sparks.Speed = NumberRange.new(1, 2.2)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.Acceleration = Vector3.new(0, 0.4, 0)
	sparks.LightEmission = 0.3
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 244, 250), Color3.fromRGB(214, 226, 255))
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new(0.2, 1)
	sparks.Parent = sparkAnchor

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(6, 0.3, 6)
	spawn.Transparency = 1
	-- Лицом к окну: арены лежат в +Z от центра лобби.
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, SURFACE + 0.6, LOBBY_Z), Vector3.new(0, SURFACE + 0.6, 0))
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby
	for _, child in spawn:GetChildren() do
		if child:IsA("Decal") then
			child.Transparency = 1
		end
	end
	return lobby
end

function LobbyBuilder.buildPodiums(world: Folder)
	local lobby = world:FindFirstChild("Lobby")
	if not lobby then
		lobby = LobbyBuilder.buildLobby(world)
	end
	local podiums = subfolder(lobby, "Podiums")

	for _, zone in ZONES do
		local model = Instance.new("Model")
		model.Name = zone.id
		model:SetAttribute("ZoneId", zone.id)
		model.Parent = podiums

		local base = pointOnLobby(zone.angle, 58, 0)
		local top = SURFACE + 1.55
		disc(zone.id .. "Base", 11, 1.55, Vector3.new(base.X, SURFACE + 0.78, base.Z), zone.accent, Enum.Material.SmoothPlastic, model)
		disc(zone.id .. "Glow", 12.05, 0.18, Vector3.new(base.X, top - 0.08, base.Z), zone.accent, Enum.Material.SmoothPlastic, model, false)
		local plinth = disc(zone.id .. "Plinth", 4.4, 0.7, Vector3.new(base.X, top + 0.35, base.Z), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, model)
		plinth:SetAttribute("Placeholder", true)
		local halo = disc(zone.id .. "Halo", 3.1, 0.18, Vector3.new(base.X, top + 2.6, base.Z), zone.accent, Enum.Material.SmoothPlastic, model, false)
		halo:SetAttribute("Spin", 22)

		local inward = (LOBBY_CENTER - base).Unit
		local signAt = base + inward * 10.5
		local sign = part({
			Name = "Sign",
			Size = Vector3.new(11, 3.4, 0.45),
			CFrame = CFrame.lookAt(Vector3.new(signAt.X, top + 2.3, signAt.Z), Vector3.new(LOBBY_CENTER.X, top + 2.3, LOBBY_CENTER.Z)),
			Color = Color3.fromRGB(255, 255, 255),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})

		local gui = Instance.new("SurfaceGui")
		gui.Name = "Label"
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.Brightness = 1.4
		gui.PixelsPerStud = 42
		gui.Parent = sign

		local label = Instance.new("TextLabel")
		label.BackgroundColor3 = Color3.fromRGB(36, 30, 26)
		label.BackgroundTransparency = 0.12
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 236, 214)
		label.Text = zone.title
		label.Parent = gui

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0.06, 0)
		padding.PaddingRight = UDim.new(0.06, 0)
		padding.Parent = label

		marker(plinth, zone.title, zone.accent, 8)
	end
end

function LobbyBuilder.buildBarrier(world: Folder)
	local lobby = world:FindFirstChild("Lobby")
	if not lobby then
		lobby = LobbyBuilder.buildLobby(world)
	end
	local barrier = subfolder(lobby, "Barrier")
	local hall = subfolder(lobby, "Hall")
	local segments = 36
	-- Границы проёмов кратны шагу основной стены (10°), чтобы панели шли ровно по кругу.
	local wallStart = math.rad(60)
	local wallEnd = math.rad(120)
	local winStart = math.rad(70)
	local winEnd = math.rad(110)
	local exitWallStart = math.rad(250)
	local exitWallEnd = math.rad(290)
	local doorStart = math.rad(265)
	local doorEnd = math.rad(275)
	local radius = LOBBY_RADIUS - 2.5
	local domeHeight = 60
	local evenTop = SURFACE + 20
	local windowBottom = SURFACE + 3
	local windowTop = SURFACE + 15
	local doorTop = SURFACE + 12
	local white = Color3.fromRGB(250, 250, 253)
	-- Панели: шесть подобранных цветов, повторяются по кругу в одном порядке. Ярче пола.
	local PANEL_PALETTE = {
		Color3.fromRGB(255, 138, 150), -- коралл
		Color3.fromRGB(255, 208, 110), -- тёплый жёлтый
		Color3.fromRGB(122, 222, 176), -- мята
		Color3.fromRGB(112, 186, 255), -- небо
		Color3.fromRGB(184, 150, 255), -- лаванда
		Color3.fromRGB(255, 170, 214), -- розовый
	}
	local function panelColor(index: number): Color3
		return PANEL_PALETTE[(index % #PANEL_PALETTE) + 1]
	end
	local bandColor = panelColor(0)

	for index = 0, segments - 1 do
		local a0 = (index / segments) * math.pi * 2
		local a1 = ((index + 1) / segments) * math.pi * 2
		local mid = (a0 + a1) / 2
		local chord = 2 * radius * math.sin((a1 - a0) / 2)
		if math.abs(math.deg(mid) - 270) >= 13 then
			arcSegment(barrier, "Wall" .. index, mid, chord * 1.2, LOBBY_RADIUS - 0.6, SURFACE + 10, 20, 2.4, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1, true)
		end
		-- Стена из цветных панелей до купола: два ряда, панели перекрывают друг друга,
		-- чтобы не осталось ни одной щели. Проёмы окна и двери строит evenWall ниже.
		-- Пропускаем только панели, целиком лежащие внутри ровного участка; краевые строим,
		-- чтобы они перекрывали стык и не оставляли щели.
		local inWindow = a0 >= wallStart - 0.001 and a1 <= wallEnd + 0.001
		local inExit = a0 >= exitWallStart - 0.001 and a1 <= exitWallEnd + 0.001
		if not inWindow and not inExit then
			local rowH = (evenTop - SURFACE) / 2
			-- Одна панель на всю высоту, один цвет на сегмент.
			-- Панель уходит на студ ниже уровня пола: стык скрыт, отдельный цоколь не нужен.
			arcSegment(hall, "Panel" .. index, mid, chord * 1.15, radius, SURFACE + rowH - 0.5, evenTop - SURFACE + 1.6, 5, panelColor(index), Enum.Material.SmoothPlastic, 0, true)
			arcSegment(hall, "PanelBack" .. index, mid, chord * 1.3, radius + 2.2, SURFACE + rowH, evenTop - SURFACE + 1, 2, panelColor(index), Enum.Material.SmoothPlastic, 0, true)
		end
		arcSegment(hall, "Cornice" .. index, mid, chord * 1.15, radius - 0.6, evenTop + 0.6, 2.2, 4.8, white, Enum.Material.SmoothPlastic, 0, false)
	end

	-- Купол: один меш-полусфера с бесшовной радужной текстурой, видимый изнутри.
	local domeSource = ServerStorage:FindFirstChild("Assets") and ServerStorage.Assets:FindFirstChild("DomeA")
	local domeMesh = domeSource and domeSource:FindFirstChildWhichIsA("MeshPart", true)
	if domeMesh then
		local dome = domeMesh:Clone()
		dome.Name = "Dome"
		dome.Anchored = true
		dome.CanCollide = false
		dome.CanTouch = false
		dome.CanQuery = false
		dome.CastShadow = false
		dome.DoubleSided = true
		dome.Size = Vector3.new(radius * 2, domeHeight, radius * 2)
		dome.CFrame = CFrame.new(0, evenTop + domeHeight / 2, LOBBY_Z)
		dome.Material = Enum.Material.SmoothPlastic
		dome.Color = Color3.new(1, 1, 1)
		dome.Reflectance = 0
		dome.TextureID = DOME_TEXTURE
		dome.Parent = hall
	else
		warn("LobbyBuilder: ServerStorage.Assets.DomeA не найден — купол не построен")
	end

	-- Диско-шар на нитке под самой вершиной купола.
	local apexY = evenTop + domeHeight
	local ballY = apexY - 22
	local ballCenter = Vector3.new(0, ballY, LOBBY_Z)
	part({
		Name = "DiscoString",
		Size = Vector3.new(0.18, apexY - ballY - 3.6, 0.18),
		CFrame = CFrame.new(0, (apexY + ballY + 3.6) / 2, LOBBY_Z),
		Color = white,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = hall,
	})
	local ball = part({
		Name = "DiscoBall",
		Size = Vector3.new(7.6, 7.6, 7.6),
		CFrame = CFrame.new(ballCenter),
		Color = Color3.fromRGB(232, 236, 248),
		Material = Enum.Material.Glass,
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		Parent = hall,
	})
	ball.Reflectance = 0.35
	ball:SetAttribute("Spin", 40)
	-- Зеркальные грани: пастельные квадратики, вращаются вокруг центра шара.
	local facetIndex = 0
	for row = -2, 2 do
		local pitch = row * math.rad(28)
		local count = if math.abs(row) == 2 then 8 else 14
		for i = 0, count - 1 do
			local yaw = (i / count) * math.pi * 2 + row * 0.2
			local dir = Vector3.new(math.cos(pitch) * math.cos(yaw), math.sin(pitch), math.cos(pitch) * math.sin(yaw))
			local pos = ballCenter + dir * 3.75
			local facet = part({
				Name = "Facet",
				Size = Vector3.new(1.15, 1.15, 0.22),
				CFrame = CFrame.lookAt(pos, ballCenter) * CFrame.Angles(0, math.pi, 0),
				Color = Color3.fromHSV((facetIndex % 12) / 12, 0.22, 0.98),
				Material = Enum.Material.Glass,
				CanCollide = false,
				Parent = hall,
			})
			facet.Reflectance = 0.5
			facet:SetAttribute("Spin", 40)
			facet:SetAttribute("SpinCenter", ballCenter)
			facetIndex += 1
		end
	end
	local glints = Instance.new("ParticleEmitter")
	glints.Name = "Glints"
	glints.Rate = 14
	glints.Lifetime = NumberRange.new(1.4, 2.6)
	glints.Speed = NumberRange.new(2, 5)
	glints.SpreadAngle = Vector2.new(180, 180)
	glints.Acceleration = Vector3.new(0, -1.5, 0)
	glints.LightEmission = 0.6
	glints.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(214, 226, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 222, 240)),
	})
	glints.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	glints.Transparency = NumberSequence.new(0.1, 1)
	glints.Parent = ball

	local frameColor = Color3.fromRGB(244, 244, 248)

	-- Ровный участок стены с прямоугольным проёмом (окно или дверь).
	local function evenWall(prefix: string, spanStart: number, spanEnd: number, holeStart: number, holeEnd: number, holeBottom: number, holeTop: number, segs: number)
		local span = spanEnd - spanStart
		for index = 0, segs - 1 do
			local a0 = spanStart + span * (index / segs)
			local a1 = spanStart + span * ((index + 1) / segs)
			local mid = (a0 + a1) / 2
			local chord = 2 * radius * math.sin((a1 - a0) / 2) * 1.15
			-- Цвет берём по глобальному сегменту круга, чтобы последовательность не сбивалась.
			local color = panelColor(math.floor(mid / (math.pi * 2 / segments)))
			local fullH = evenTop - SURFACE + 0.6
			local fullY = SURFACE + (evenTop - SURFACE) / 2
			if mid >= holeStart and mid <= holeEnd then
				if holeBottom > SURFACE + 0.5 then
					arcSegment(hall, prefix .. "Under" .. index, mid, chord, radius, (SURFACE + holeBottom) / 2, holeBottom - SURFACE + 0.8, 5, color, Enum.Material.SmoothPlastic, 0, true)
				end
				local upperH = evenTop - holeTop + 0.6
				local upperY = holeTop + (evenTop - holeTop) / 2
				arcSegment(hall, prefix .. "Over" .. index, mid, chord, radius, upperY, upperH, 5, color, Enum.Material.SmoothPlastic, 0, true)
				arcSegment(hall, prefix .. "OverSeal" .. index, mid, chord, radius - 3.2, upperY, upperH, 3.2, color, Enum.Material.SmoothPlastic, 0, true)
			else
				arcSegment(hall, prefix .. "Even" .. index, mid, chord, radius, fullY, fullH, 5, color, Enum.Material.SmoothPlastic, 0, true)
				arcSegment(hall, prefix .. "Seal" .. index, mid, chord, radius - 3.2, fullY, fullH, 3.2, color, Enum.Material.SmoothPlastic, 0, true)
			end
		end

		local holeMid = (holeBottom + holeTop) / 2
		local holeH = holeTop - holeBottom
		local centerDeg = math.deg((holeStart + holeEnd) / 2)
		local pos = pointOnLobby(centerDeg, radius, holeMid)
		local frameCF = CFrame.lookAt(pos, Vector3.new(LOBBY_CENTER.X, holeMid, LOBBY_CENTER.Z))
		local width = 2 * radius * math.sin((holeEnd - holeStart) / 2)
		part({
			Name = prefix .. "Lintel",
			Size = Vector3.new(width + 4, 3.2, 5),
			CFrame = frameCF * CFrame.new(0, holeH / 2, 0),
			Color = frameColor,
			Material = Enum.Material.SmoothPlastic,
			Parent = hall,
		})
		for _, side in { -1, 1 } do
			part({
				Name = prefix .. "Jamb",
				Size = Vector3.new(3.4, holeH + 3, 5),
				CFrame = frameCF * CFrame.new(side * width / 2, 0, 0),
				Color = frameColor,
				Material = Enum.Material.SmoothPlastic,
				Parent = hall,
			})
		end
		return frameCF, width, holeH
	end

	local winCF, winWidth, windowHeight = evenWall("Window", wallStart, wallEnd, winStart, winEnd, windowBottom, windowTop, 6)
	part({
		Name = "WindowGlass",
		Size = Vector3.new(winWidth, windowHeight, 0.4),
		CFrame = winCF,
		Color = Color3.fromRGB(186, 214, 232),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.55,
		CanCollide = false,
		Parent = hall,
	})
	part({
		Name = "WindowSill",
		Size = Vector3.new(winWidth + 4, 2.2, 4.5),
		CFrame = winCF * CFrame.new(0, -windowHeight / 2, 0),
		Color = frameColor,
		Material = Enum.Material.SmoothPlastic,
		Parent = hall,
	})

	evenWall("Exit", exitWallStart, exitWallEnd, doorStart, doorEnd, SURFACE, doorTop, 8)
end

function LobbyBuilder.buildBridge(world: Folder)
	local bridge = subfolder(world, "Bridge")
	local startZ = LOBBY_Z - LOBBY_RADIUS + 2
	local endZ = FOREST_Z + FOREST_RADIUS - 2
	local length = math.abs(endZ - startZ)
	local midZ = (startZ + endZ) / 2

	part({
		Name = "Deck",
		Size = Vector3.new(16, 1.1, length),
		CFrame = CFrame.new(0, SURFACE - 0.55, midZ),
		Color = PALETTE.wood,
		Material = Enum.Material.WoodPlanks,
		Parent = bridge,
	})

	for _, side in { -8.2, 8.2 } do
		part({
			Name = if side < 0 then "RailLeft" else "RailRight",
			Size = Vector3.new(0.7, 7.2, length),
			CFrame = CFrame.new(side, SURFACE + 3.6, midZ),
			Color = PALETTE.woodDark,
			Material = Enum.Material.Wood,
			Parent = bridge,
		})
	end
end

local function walkPart(parent: Instance, name: string, size: Vector3, x: number, walkY: number, z: number, color: Color3, material: Enum.Material): Part
	return part({
		Name = name,
		Size = size,
		CFrame = CFrame.new(x, walkY - size.Y / 2, z),
		Color = color,
		Material = material,
		Parent = parent,
	})
end

local function checkpoint(folder: Folder, index: number, x: number, walkY: number, z: number, depth: number): Part
	local hue = 0.33 - ((index - 1) / 10) * 0.33
	local color = Color3.fromHSV(hue, 0.62, 0.9)
	local pad = walkPart(folder, "CP" .. index, Vector3.new(math.max(depth, 8), 1, depth), x, walkY, z, PALETTE.stone, Enum.Material.Slate)
	pad:SetAttribute("Index", index)
	part({
		Name = "Trim",
		Size = Vector3.new(pad.Size.X + 0.4, 0.18, pad.Size.Z + 0.4),
		CFrame = CFrame.new(x, walkY + 0.08, z),
		Color = color,
		Material = Enum.Material.Wood,
		CanCollide = false,
		Parent = folder,
	})
	marker(pad, tostring(index), color, 5)
	return pad
end

local function hingeMotor(parent: Instance, name: string, axis: Vector3, angularVelocity: number, anchoredCF: CFrame, moving: Part, movingAttachmentLocal: Vector3)
	local pivot = part({
		Name = name .. "Pivot",
		Size = Vector3.new(1, 1, 1),
		CFrame = anchoredCF,
		Color = PALETTE.metalDark,
		Material = Enum.Material.Metal,
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "Hinge"
	attachment0.Axis = axis
	attachment0.Parent = pivot

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "Hinge"
	attachment1.Axis = axis
	attachment1.Position = movingAttachmentLocal
	attachment1.Parent = moving

	local hinge = Instance.new("HingeConstraint")
	hinge.Name = name
	hinge.Attachment0 = attachment0
	hinge.Attachment1 = attachment1
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity = angularVelocity
	hinge.MotorMaxTorque = 10000000
	hinge.Parent = pivot
	moving.Anchored = false
	moving.CustomPhysicalProperties = PhysicalProperties.new(0.55, 0.85, 0.1, 1, 1)
	return hinge
end

-- Мотор вращения вокруг мировой оси через центр; работает для любых повёрнутых частей (диски, брёвна).
local function spinMotor(parent: Instance, name: string, worldAxis: Vector3, angularVelocity: number, center: Vector3, moving: BasePart): HingeConstraint
	local pivot = part({
		Name = name .. "Pivot",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(center),
		Color = PALETTE.metalDark,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})
	local attachment0 = Instance.new("Attachment")
	attachment0.Axis = worldAxis
	attachment0.Parent = pivot
	local attachment1 = Instance.new("Attachment")
	attachment1.Position = moving.CFrame:PointToObjectSpace(center)
	attachment1.Axis = moving.CFrame:VectorToObjectSpace(worldAxis)
	attachment1.Parent = moving
	local hinge = Instance.new("HingeConstraint")
	hinge.Name = name
	hinge.Attachment0 = attachment0
	hinge.Attachment1 = attachment1
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity = angularVelocity
	hinge.MotorMaxTorque = 10000000
	hinge.Parent = pivot
	moving.Anchored = false
	moving.CustomPhysicalProperties = PhysicalProperties.new(0.55, 0.85, 0.1, 1, 1)
	return hinge
end

local function weldTo(base: BasePart, item: BasePart)
	item.Anchored = false
	item.Massless = true
	item.CustomPhysicalProperties = PhysicalProperties.new(0.55, 0.85, 0.1, 1, 1)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = item
	weld.Parent = item
end

local function wedge(props: {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Parent: Instance,
	Friction: number?,
}): WedgePart
	local item = Instance.new("WedgePart")
	item.Name = props.Name
	item.Anchored = true
	item.Size = props.Size
	item.CFrame = props.CFrame
	item.Color = props.Color
	item.Material = Enum.Material.SmoothPlastic
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Reflectance = 0
	if props.Friction then
		item.CustomPhysicalProperties = PhysicalProperties.new(0.7, props.Friction, 0, 1, 1)
	end
	item.Parent = props.Parent
	return item
end

local function sparkle(target: BasePart, color: Color3, rate: number, size: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(1.2, 2.2)
	emitter.Speed = NumberRange.new(0.6, 1.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 0.6, 0)
	emitter.LightEmission = 0.25
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Parent = target
	return emitter
end

-- Скай-паркур: начинается за выходом напротив окна (270°) и уходит в сторону -Z.
function LobbyBuilder.buildParkour(world: Folder)
	local parkour = subfolder(world, "Parkour")
	local checkpoints = subfolder(parkour, "Checkpoints")
	local obstacles = subfolder(parkour, "Obstacles")
	local props = subfolder(parkour, "Props")

	local white = Color3.fromRGB(244, 244, 248)
	local function hue(index: number, sat: number?, val: number?): Color3
		return Color3.fromHSV((index % 12) / 12, sat or 0.58, val or 0.95)
	end

	local y = SURFACE
	local edge = LOBBY_Z - LOBBY_RADIUS + 1
	local cp = 0
	local tone = 0

	local function advance(gap: number, depth: number): number
		local centerZ = edge - gap - depth / 2
		edge = centerZ - depth / 2
		return centerZ
	end

	local function nextTone(): Color3
		tone += 1
		return hue(tone)
	end

	local function mark(radius: number, gap: number, x: number): Part
		cp += 1
		local centerZ = advance(gap, radius * 2)
		local color = hue(cp * 2, 0.5, 0.95)
		local pad = disc("CP" .. cp, radius, 1, Vector3.new(x, y - 0.5, centerZ), white, Enum.Material.SmoothPlastic, checkpoints)
		pad:SetAttribute("Index", cp)
		disc("Ring" .. cp, radius + 0.7, 0.3, Vector3.new(x, y - 0.85, centerZ), color, Enum.Material.SmoothPlastic, props)
		disc("Dot" .. cp, 1.6, 0.16, Vector3.new(x, y + 0.08, centerZ), color, Enum.Material.SmoothPlastic, props, false)
		sparkle(pad, color, 4, 0.5)
		marker(pad, tostring(cp), color, 5)
		return pad
	end

	local function block(name: string, gap: number, size: Vector3, x: number, color: Color3, yaw: number?): Part
		local centerZ = advance(gap, size.Z)
		return part({
			Name = name,
			Size = size,
			CFrame = CFrame.new(x, y - size.Y / 2, centerZ) * CFrame.Angles(0, yaw or 0, 0),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Parent = obstacles,
		})
	end

	local function slide(name: string, width: number, drop: number, length: number, color: Color3)
		local centerZ = advance(0.2, length)
		wedge({
			Name = name,
			Size = Vector3.new(width, drop, length),
			CFrame = CFrame.new(0, y - drop / 2, centerZ),
			Color = color,
			Parent = obstacles,
			Friction = 0.02,
		})
		local slope = math.atan(drop / length)
		local railLength = math.sqrt(drop * drop + length * length) + 1
		for _, side in { -1, 1 } do
			part({
				Name = name .. "Rail",
				Size = Vector3.new(0.7, 2.6, railLength),
				CFrame = CFrame.new(side * (width / 2 + 0.35), y - drop / 2 + 0.9, centerZ) * CFrame.Angles(-slope, 0, 0),
				Color = white,
				Material = Enum.Material.SmoothPlastic,
				Parent = obstacles,
			})
		end
		y -= drop
	end

	local function orbDecor(x: number, z: number, height: number, color: Color3, size: number)
		local orb = part({
			Name = "Orb",
			Size = Vector3.new(size, size, size),
			CFrame = CFrame.new(x, y + height, z),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			Parent = props,
		})
		orb:SetAttribute("Bob", 0.6 + (x % 3) * 0.2)
	end

	-- Стартовая площадка перед выходом.
	local startZ = advance(0, 18)
	disc("Start", 9, 1.2, Vector3.new(0, y - 0.6, startZ), white, Enum.Material.SmoothPlastic, props)
	disc("StartRing", 9.6, 0.3, Vector3.new(0, y - 0.95, startZ), hue(7), Enum.Material.SmoothPlastic, props)
	cp += 1
	local startPad = disc("CP" .. cp, 5, 0.3, Vector3.new(0, y + 0.1, startZ), hue(7, 0.35, 0.98), Enum.Material.SmoothPlastic, checkpoints)
	startPad:SetAttribute("Index", cp)
	for _, side in { -1, 1 } do
		part({
			Name = "StartGuard",
			Size = Vector3.new(1, 14, 26),
			CFrame = CFrame.new(side * 10.2, y + 7, startZ + 3),
			Color = white,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 1,
			Parent = props,
		})
	end

	-- Арка с табличкой.
	local archZ = startZ - 6
	for _, side in { -1, 1 } do
		part({
			Name = "ArchPillar",
			Size = Vector3.new(1.6, 9, 1.6),
			CFrame = CFrame.new(side * 8, y + 4.5, archZ),
			Color = white,
			Material = Enum.Material.SmoothPlastic,
			Parent = props,
		})
		local top = part({
			Name = "ArchBall",
			Size = Vector3.new(2.4, 2.4, 2.4),
			CFrame = CFrame.new(side * 8, y + 10.2, archZ),
			Color = hue(if side < 0 then 0 else 8),
			Material = Enum.Material.SmoothPlastic,
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			Parent = props,
		})
		top:SetAttribute("Bob", 0.9)
	end
	local sign = part({
		Name = "ParkourSign",
		Size = Vector3.new(17.6, 4.6, 0.8),
		CFrame = CFrame.lookAt(Vector3.new(0, y + 8.2, archZ), Vector3.new(0, y + 8.2, archZ + 10)),
		Color = Color3.fromRGB(38, 34, 52),
		Material = Enum.Material.SmoothPlastic,
		Parent = props,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.Brightness = 1
		gui.PixelsPerStud = 40
		gui.Parent = sign
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 0.58)
		title.Font = Enum.Font.GothamBlack
		title.TextScaled = true
		title.Text = "PARKOUR"
		title.TextColor3 = Color3.fromRGB(255, 226, 120)
		title.Parent = gui
		local subtitle = Instance.new("TextLabel")
		subtitle.BackgroundTransparency = 1
		subtitle.Position = UDim2.fromScale(0, 0.58)
		subtitle.Size = UDim2.fromScale(1, 0.36)
		subtitle.Font = Enum.Font.GothamMedium
		subtitle.TextScaled = true
		subtitle.Text = "Reach the end & get a reward"
		subtitle.TextColor3 = Color3.fromRGB(236, 236, 246)
		subtitle.Parent = gui
	end

	-- 1. Парящие шары: шаг вверх, стоять неудобно.
	for index = 1, 6 do
		y += 1.6
		local size = 5.4
		local centerZ = advance(6.5, size)
		local x = if index % 2 == 0 then 3.8 else -3.8
		local orb = part({
			Name = "Orb" .. index,
			Size = Vector3.new(size, size, size),
			CFrame = CFrame.new(x, y - size / 2, centerZ),
			Color = nextTone(),
			Material = Enum.Material.SmoothPlastic,
			Shape = Enum.PartType.Ball,
			Parent = obstacles,
		})
		if index % 3 == 0 then
			orb:SetAttribute("Bob", 1.1)
		end
	end
	mark(5, 6.5, 0)

	-- 2. Исчезающие плитки.
	for index = 1, 5 do
		local tile = block("Vanish" .. index, 4.4, Vector3.new(5, 1, 4.2), if index % 2 == 0 then 2.4 else -2.4, nextTone())
		tile:SetAttribute("Disappear", true)
		tile:SetAttribute("Restore", 1.6)
	end
	mark(5, 5, 0)

	-- 3. Вращающийся диск с метлой над ним: надо перепрыгивать.
	local wheelZ = advance(4.5, 18)
	local wheel = disc("Wheel", 9, 1, Vector3.new(0, y - 0.5, wheelZ), nextTone(), Enum.Material.SmoothPlastic, obstacles)
	for index = 0, 3 do
		local angle = index * math.pi / 2
		local dot = disc("WheelDot" .. index, 1.4, 0.24, Vector3.new(math.cos(angle) * 6, y + 0.1, wheelZ + math.sin(angle) * 6), white, Enum.Material.SmoothPlastic, obstacles, false)
		weldTo(wheel, dot)
	end
	spinMotor(obstacles, "WheelSpin", Vector3.new(0, 1, 0), 0.75, Vector3.new(0, y - 0.5, wheelZ), wheel)
	local sweeper = part({
		Name = "Sweeper",
		Size = Vector3.new(19, 0.9, 0.9),
		CFrame = CFrame.new(0, y + 1.25, wheelZ),
		Color = white,
		Material = Enum.Material.SmoothPlastic,
		Parent = obstacles,
	})
	spinMotor(obstacles, "SweeperSpin", Vector3.new(0, 1, 0), -1.25, Vector3.new(0, y + 1.25, wheelZ), sweeper)
	mark(5, 4.5, 0)

	-- 4. Горка вниз.
	slide("SlideA", 12, 12, 30, hue(2, 0.5, 0.96))
	block("LandingA", 0, Vector3.new(14, 1, 8), 0, white)

	-- 5. Трамплин на высокую площадку.
	local spring = block("Spring", 2.5, Vector3.new(6, 0.6, 6), 0, hue(4, 0.7, 0.95))
	spring:SetAttribute("Bounce", 96)
	marker(spring, "JUMP", hue(4, 0.7, 0.95), 3)
	sparkle(spring, hue(4, 0.7, 0.95), 6, 0.4)
	y += 19
	block("Catch", 7, Vector3.new(10, 1, 8), 0, white)

	-- 6. Ромбы: повёрнутые кубы, часть крутится.
	for index = 1, 6 do
		y += 1
		local diamond = block("Diamond" .. index, 5.6, Vector3.new(5, 1.2, 5), if index % 2 == 0 then 4.2 else -4.2, nextTone(), math.rad(45))
		if index % 2 == 0 then
			diamond:SetAttribute("Spin", 35)
		end
	end
	mark(5, 5.5, 0)

	-- 7. Катящиеся брёвна.
	for index = 1, 3 do
		local size = Vector3.new(12, 3.6, 3.6)
		local centerZ = advance(2.6, size.Z)
		local log = part({
			Name = "Log" .. index,
			Size = size,
			CFrame = CFrame.new(0, y - size.Y / 2, centerZ),
			Color = nextTone(),
			Material = Enum.Material.SmoothPlastic,
			Shape = Enum.PartType.Cylinder,
			Parent = obstacles,
		})
		spinMotor(obstacles, "LogSpin" .. index, Vector3.new(1, 0, 0), if index % 2 == 0 then -2.1 else 2.1, Vector3.new(0, y - size.Y / 2, centerZ), log)
	end
	block("LandingB", 2.5, Vector3.new(10, 1, 6), 0, white)
	mark(5, 4, 0)

	-- 8. Крест-карусель: едем на лопасти на другую сторону.
	local crossZ = advance(4, 30)
	local hub = disc("Hub", 3, 1, Vector3.new(0, y - 0.5, crossZ), white, Enum.Material.SmoothPlastic, obstacles)
	local armA = part({
		Name = "ArmA",
		Size = Vector3.new(30, 0.9, 3),
		CFrame = CFrame.new(0, y - 0.45, crossZ),
		Color = hue(9),
		Material = Enum.Material.SmoothPlastic,
		Parent = obstacles,
	})
	local armB = part({
		Name = "ArmB",
		Size = Vector3.new(3, 0.9, 30),
		CFrame = CFrame.new(0, y - 0.45, crossZ),
		Color = hue(3),
		Material = Enum.Material.SmoothPlastic,
		Parent = obstacles,
	})
	weldTo(hub, armA)
	weldTo(hub, armB)
	spinMotor(obstacles, "CrossSpin", Vector3.new(0, 1, 0), 0.55, Vector3.new(0, y - 0.5, crossZ), hub)
	block("LandingC", 4, Vector3.new(10, 1, 7), 0, white)
	mark(5, 4, 0)

	-- 9. Тонкие качающиеся балки зигзагом.
	for index = 1, 7 do
		local x = ({ 0, 5, -5, 0, 6, -6, 0 })[index]
		local beam = block("Beam" .. index, 3.2, Vector3.new(1.5, 0.8, 7), x, nextTone())
		if index % 2 == 0 then
			beam:SetAttribute("Bob", 1.0)
		end
	end
	mark(5, 4, 0)

	-- 10. Маятник над мостом.
	local bridgeLen = 28
	local bridgeZ = advance(3, bridgeLen)
	block("PendulumBridge", -bridgeLen, Vector3.new(3.2, 1, bridgeLen), 0, hue(6))
	edge = bridgeZ - bridgeLen / 2
	local pivotPos = Vector3.new(0, y + 17, bridgeZ)
	local hammer = part({
		Name = "Hammer",
		Size = Vector3.new(6, 6, 6),
		CFrame = CFrame.new(0, y + 3.2, bridgeZ),
		Color = hue(0, 0.65, 0.95),
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Ball,
		Parent = obstacles,
	})
	local rodSpan = pivotPos - hammer.Position
	local rod = part({
		Name = "HammerRod",
		Size = Vector3.new(0.5, rodSpan.Magnitude, 0.5),
		CFrame = CFrame.new((pivotPos + hammer.Position) / 2),
		Color = white,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = obstacles,
	})
	weldTo(hammer, rod)
	local swing = hingeMotor(obstacles, "SwingHinge", Vector3.new(0, 0, 1), 0, CFrame.new(pivotPos), hammer, hammer.CFrame:PointToObjectSpace(pivotPos))
	swing.ActuatorType = Enum.ActuatorType.Servo
	swing.AngularSpeed = 1.1
	swing.ServoMaxTorque = 10000000
	swing.TargetAngle = 0
	swing:SetAttribute("Swing", 55)
	swing.LimitsEnabled = true
	swing.LowerAngle = -60
	swing.UpperAngle = 60
	mark(5, 3, 0)

	-- 11. Длинная финальная горка.
	slide("SlideB", 14, 16, 38, hue(10, 0.5, 0.96))

	-- Финиш и награда.
	local finishZ = advance(0, 22)
	disc("Finish", 11, 1.2, Vector3.new(0, y - 0.6, finishZ), white, Enum.Material.SmoothPlastic, props)
	disc("FinishRing", 11.6, 0.3, Vector3.new(0, y - 0.95, finishZ), hue(1), Enum.Material.SmoothPlastic, props)
	cp += 1
	local finishPad = disc("CP" .. cp, 6, 0.3, Vector3.new(0, y + 0.1, finishZ), hue(1, 0.3, 0.98), Enum.Material.SmoothPlastic, checkpoints)
	finishPad:SetAttribute("Index", cp)

	local reward = subfolder(parkour, "Reward")
	disc("Pedestal", 2.4, 1.6, Vector3.new(0, y + 0.8, finishZ - 5), white, Enum.Material.SmoothPlastic, reward)
	local crystal = part({
		Name = "Crystal",
		Size = Vector3.new(2.6, 2.6, 2.6),
		CFrame = CFrame.new(0, y + 4, finishZ - 5) * CFrame.Angles(math.rad(45), math.rad(45), 0),
		Color = PALETTE.gold,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = reward,
	})
	crystal:SetAttribute("Spin", 45)
	crystal:SetAttribute("Bob", 1.2)
	sparkle(crystal, Color3.fromRGB(255, 232, 160), 10, 0.5)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Open"
	prompt.ActionText = "Claim"
	prompt.ObjectText = "Reward"
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 12
	prompt.Parent = crystal
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "Burst"
	burst.Enabled = false
	burst.Rate = 60
	burst.Lifetime = NumberRange.new(0.6, 1.2)
	burst.Speed = NumberRange.new(6, 12)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.LightEmission = 0.5
	burst.Color = ColorSequence.new(PALETTE.gold, Color3.fromRGB(255, 240, 200))
	burst.Size = NumberSequence.new(0.6, 0)
	burst.Parent = crystal
	marker(crystal, "REWARD", PALETTE.gold, 3)
	addScript(crystal, "Reward", REWARD_SCRIPT)

	local back = disc("BackToLobby", 3, 0.4, Vector3.new(7, y + 0.15, finishZ + 4), hue(8, 0.5, 0.95), Enum.Material.SmoothPlastic, reward)
	marker(back, "BACK TO LOBBY", hue(8, 0.5, 0.95), 3)
	addScript(back, "Return", RETURN_SCRIPT)

	-- Декор: парящие шарики вдоль трассы.
	local zStart = LOBBY_Z - LOBBY_RADIUS - 20
	for index = 0, 14 do
		local z = zStart - index * 22
		local side = if index % 2 == 0 then 1 else -1
		orbDecor(side * (16 + (index % 3) * 4), z, 6 + (index % 4) * 3, hue(index, 0.45, 0.98), 1.6 + (index % 3) * 0.5)
	end

	addScript(checkpoints, "Checkpoints", CHECKPOINT_SCRIPT)
	addScript(obstacles, "Obstacles", OBSTACLE_SCRIPT)
	addScript(parkour, "Swings", SWING_SCRIPT)
	addScript(parkour, "Motion", MOTION_SCRIPT)
end

function LobbyBuilder.buildLighting(world: Folder)
	Lighting.ClockTime = 12
	Lighting.Brightness = 0
	Lighting.GeographicLatitude = 18
	Lighting.GlobalShadows = false
	Lighting.Ambient = Color3.fromRGB(188, 192, 204)
	Lighting.OutdoorAmbient = Color3.fromRGB(176, 182, 196)
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0
	Lighting.ExposureCompensation = 0.08

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.18
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(198, 214, 232)
	atmosphere.Decay = Color3.fromRGB(170, 186, 210)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.35

	local function effect(className: string, name: string): Instance
		local existing = Lighting:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
		local created = Instance.new(className)
		created.Name = name
		created.Parent = Lighting
		return created
	end

	for _, name in { "LobbyBloom", "LobbySun" } do
		local leftover = Lighting:FindFirstChild(name)
		if leftover then
			leftover:Destroy()
		end
	end

	local color = effect("ColorCorrectionEffect", "LobbyColor") :: ColorCorrectionEffect
	color.TintColor = Color3.fromRGB(245, 244, 238)
	color.Saturation = 0.04
	color.Contrast = 0.02
	color.Brightness = 0.04

	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Parent = Workspace.Terrain
	end
	clouds.Cover = 0.28
	clouds.Density = 0.22
	clouds.Color = Color3.fromRGB(232, 236, 242)

	local systems = world:FindFirstChild("Systems")
	if not systems then
		systems = subfolder(world, "Systems")
	end
	local oldCycle = systems:FindFirstChild("DayCycle")
	if oldCycle then
		oldCycle:Destroy()
	end
end

function LobbyBuilder.buildSkySign(world: Folder)
	local lobby = world:FindFirstChild("Lobby")
	if not lobby then
		lobby = LobbyBuilder.buildLobby(world)
	end
	local existing = lobby:FindFirstChild("SkySign")
	if existing then
		existing:Destroy()
	end

	local anchor = part({
		Name = "SkySign",
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(0, SURFACE + 18, LOBBY_Z),
		Color = PALETTE.stone,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 1,
		CanCollide = false,
		Parent = lobby,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Title"
	billboard.Size = UDim2.fromOffset(980, 170)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 1200
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "COLOR PARTY"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromRGB(40, 32, 52)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard

	local gradient = Instance.new("UIGradient")
	local keypoints = {}
	for index = 0, 8 do
		table.insert(keypoints, ColorSequenceKeypoint.new(index / 8, Color3.fromHSV((index / 8) % 1, 0.85, 1)))
	end
	gradient.Color = ColorSequence.new(keypoints)
	gradient.Parent = label

	addScript(anchor, "Rainbow", TITLE_SCRIPT)
end

function LobbyBuilder.buildDecor(world: Folder)
	local lobby = world:FindFirstChild("Lobby")
	if not lobby then
		lobby = LobbyBuilder.buildLobby(world)
	end
	local decor = subfolder(lobby, "Decor")
	for index = 0, 11 do
		local angle = index * 30
		if angle >= 60 and angle <= 120 then
			continue
		end
		local color = Color3.fromHSV(index / 12, 0.85, 1)
		local spot = pointOnLobby(angle, 78, SURFACE + 8)
		part({
			Name = "Lantern" .. index,
			Size = Vector3.new(1.6, 2.2, 1.6),
			CFrame = CFrame.new(spot),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = decor,
		})
	end

	local fountainAt = pointOnLobby(200, 70, SURFACE)
	disc("Basin", 9, 1.3, Vector3.new(fountainAt.X, SURFACE + 0.7, fountainAt.Z), Color3.fromRGB(120, 210, 230), Enum.Material.SmoothPlastic, decor)
	disc("Water", 7.2, 0.25, Vector3.new(fountainAt.X, SURFACE + 1.45, fountainAt.Z), PALETTE.water, Enum.Material.SmoothPlastic, decor, false).Transparency = 0.25
	local jet = part({
		Name = "Jet",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(fountainAt.X, SURFACE + 1.8, fountainAt.Z),
		Color = PALETTE.water,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 1,
		CanCollide = false,
		Parent = decor,
	})
	local spray = Instance.new("ParticleEmitter")
	spray.Rate = 28
	spray.Lifetime = NumberRange.new(0.8, 1.25)
	spray.Speed = NumberRange.new(11, 15)
	spray.SpreadAngle = Vector2.new(8, 8)
	spray.Acceleration = Vector3.new(0, -32, 0)
	spray.LightEmission = 0.1
	spray.Color = ColorSequence.new(Color3.fromRGB(210, 236, 244))
	spray.Size = NumberSequence.new(0.35, 0.1)
	spray.Transparency = NumberSequence.new(0.15, 0.7)
	spray.Parent = jet

	for index = 1, 4 do
		local moteAt = pointOnLobby(40 + index * 70, 40, SURFACE + 6)
		local mote = part({
			Name = "Motes" .. index,
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(moteAt),
			Color = PALETTE.neonWarm,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 1,
			CanCollide = false,
			Parent = decor,
		})
		local dust = Instance.new("ParticleEmitter")
		dust.Rate = 1
		dust.Lifetime = NumberRange.new(6, 10)
		dust.Speed = NumberRange.new(0.15, 0.4)
		dust.SpreadAngle = Vector2.new(180, 180)
		dust.Acceleration = Vector3.new(0, 0.2, 0)
		dust.LightEmission = 0.15
		dust.Color = ColorSequence.new(PALETTE.neonWarm)
		dust.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(1, 0.45),
		})
		dust.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		dust.Parent = mote
	end

	local source = Workspace:FindFirstChild("Low Poly Tree")
	if source and source:IsA("Model") then
		local spots = {
			pointOnLobby(42, 94, SURFACE),
			pointOnLobby(318, 94, SURFACE),
			pointOnLobby(168, 96, SURFACE),
		}
		for index, spot in spots do
			local tree = source:Clone()
			tree.Name = "GardenTree" .. index
			for _, descendant in tree:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.Anchored = true
				end
			end
			pcall(function()
				tree:ScaleTo(0.28)
			end)
			tree.Parent = decor
			local bounds, boundsSize = tree:GetBoundingBox()
			local bottom = bounds.Position.Y - boundsSize.Y / 2
			tree:PivotTo(tree:GetPivot() + Vector3.new(spot.X - bounds.Position.X, spot.Y - bottom, spot.Z - bounds.Position.Z))
		end
		source:Destroy()
	end

	local oldMotion = lobby:FindFirstChild("Motion")
	if oldMotion then
		oldMotion:Destroy()
	end
	addScript(lobby, "Motion", MOTION_SCRIPT)
end

function LobbyBuilder.buildSystems(world: Folder)
	local systems = subfolder(world, "Systems")
	-- Плоскость смерти под лобби и паркуром. До арен (Z > 0) не доходит:
	-- падения на аренах обрабатывает MatchController.
	part({
		Name = "Void",
		Size = Vector3.new(520, 6, 1260),
		CFrame = CFrame.new(0, 6, -690),
		Color = PALETTE.stoneDeep,
		Material = Enum.Material.Slate,
		Transparency = 1,
		CanCollide = false,
		Parent = systems,
	})
	addScript(systems, "VoidTeleport", VOID_SCRIPT)
	local oldCycle = systems:FindFirstChild("DayCycle")
	if oldCycle then
		oldCycle:Destroy()
	end
end

-- Консоль у окна: модели из Toolbox + Billboard с очередью (всегда читается).
function LobbyBuilder.buildConsole(world: Folder)
	local lobby = world:FindFirstChild("Lobby") or subfolder(world, "Lobby")
	local old = lobby:FindFirstChild("Console")
	if old then
		old:Destroy()
	end
	local console = Instance.new("Model")
	console.Name = "Console"
	console.Parent = lobby

	local function wallFrame(angleDeg: number, radius: number, y: number): CFrame
		local pos = pointOnLobby(angleDeg, radius, y)
		return CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(LOBBY_CENTER.X, y, LOBBY_CENTER.Z))
	end

	-- Коралловая панель сразу слева от стекла (сектор 60–70°).
	local boardCf = wallFrame(65, 103, SURFACE + 11)
	local sign = buildArenaBoard(console, boardCf)
	local ready = Instance.new("ProximityPrompt")
	ready.Name = "ReadyPrompt"
	ready.ActionText = "Готов к матчу"
	ready.ObjectText = "Табло арен"
	ready.HoldDuration = 0
	ready.MaxActivationDistance = 12
	ready.RequiresLineOfSight = false
	ready.Parent = sign

	-- Бинокль у самого стекла, справа в проёме: подходишь и смотришь в окуляры наружу.
	-- Взгляд модели — локальная −X (деталь View).
	local scopePos = pointOnLobby(104, 106, SURFACE)
	local lookTarget = pointOnLobby(90, 160, SURFACE + 5)
	local scopeModel = cloneToolbox("LobbySpyglass", TOOLBOX.LobbySpyglass)
	local scopeRoot: BasePart
	if scopeModel then
		scopeModel.Name = "Spyglass"
		scopeModel:ScaleTo(1.25)
		local stand = Vector3.new(scopePos.X, SURFACE + 5, scopePos.Z)
		local lookCf = CFrame.lookAt(stand, Vector3.new(lookTarget.X, stand.Y, lookTarget.Z))
		scopeModel:PivotTo(lookCf * CFrame.Angles(0, math.rad(-90), 0))
		local lowest = math.huge
		for _, item in scopeModel:GetDescendants() do
			if item:IsA("BasePart") then
				lowest = math.min(lowest, item.Position.Y - item.Size.Y / 2)
			end
		end
		-- Ножки на полу, окуляры на высоте глаз (~5 студов).
		local lift = SURFACE + 0.15 - lowest
		scopeModel:PivotTo(scopeModel:GetPivot() + Vector3.new(0, lift + 1.1, 0))
		part({
			Name = "ScopePedestal",
			Size = Vector3.new(3.2, 1.15, 3.2),
			CFrame = CFrame.new(scopePos.X, SURFACE + 0.55, scopePos.Z),
			Color = Color3.fromRGB(246, 246, 250),
			Material = Enum.Material.SmoothPlastic,
			Parent = console,
		})
		scopeModel.Parent = console
		local bounds = scopeModel:GetBoundingBox()
		scopeRoot = part({
			Name = "ScopePromptHost",
			Size = Vector3.new(2.2, 2.2, 2.2),
			CFrame = CFrame.new(bounds.Position),
			Color = Color3.new(1, 1, 1),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 1,
			CanCollide = false,
			Parent = console,
		})
	else
		warn("[LobbyBuilder] LobbySpyglass не загружен")
		scopeRoot = part({
			Name = "ScopePromptHost",
			Size = Vector3.new(2.2, 2.2, 2.2),
			CFrame = CFrame.new(scopePos + Vector3.new(0, 3, 0)),
			Color = Color3.new(1, 1, 1),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 1,
			CanCollide = false,
			Parent = console,
		})
	end

	local watch = Instance.new("ProximityPrompt")
	watch.Name = "WatchPrompt"
	watch.ActionText = "Смотреть арены"
	watch.ObjectText = "Подзорная труба"
	watch.HoldDuration = 0
	watch.MaxActivationDistance = 12
	watch.RequiresLineOfSight = false
	watch.Parent = scopeRoot
end

function LobbyBuilder.build()
	local existing = Workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "World"
	world:SetAttribute("SurfaceY", SURFACE)
	world:SetAttribute("LobbyRadius", LOBBY_RADIUS)
	world:SetAttribute("ArenaRadius", ARENA_RADIUS)
	world.Parent = Workspace

	LobbyBuilder.buildLobby(world)
	LobbyBuilder.buildPodiums(world)
	LobbyBuilder.buildBarrier(world)
	LobbyBuilder.buildParkour(world)
	LobbyBuilder.buildDecor(world)
	LobbyBuilder.buildSkySign(world)
	LobbyBuilder.buildLighting(world)
	LobbyBuilder.buildSystems(world)
	LobbyBuilder.buildConsole(world)
	require(script.Parent:WaitForChild("ArenaBuilder")).build(world)

	for _, name in { "Baseplate", "SpawnLocation", "Grid", "Ground", "TestDome" } do
		local leftover = Workspace:FindFirstChild(name)
		if leftover and leftover ~= world then
			leftover:Destroy()
		end
	end
	pcall(function()
		Workspace.Terrain:Clear()
	end)
	pcall(function()
		settings().Studio["Show Grid"] = false
	end)

	-- Небо: один Sky с мягким градиентом (сгенерированные текстуры), лишние
	-- Sky и постэффекты (лучи, блум, размытие дали) убираем — за окном должно быть чётко.
	local sky: Sky? = nil
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") then
			if sky then
				child:Destroy()
			else
				sky = child
			end
		elseif child:IsA("SunRaysEffect") or child:IsA("BloomEffect") or child:IsA("DepthOfFieldEffect") then
			child:Destroy()
		end
	end
	if not sky then
		sky = Instance.new("Sky")
		sky.Parent = Lighting
	end
	local skyInstance = sky :: Sky
	for _, face in { "SkyboxBk", "SkyboxFt", "SkyboxLf", "SkyboxRt" } do
		(skyInstance :: any)[face] = SKY_SIDE_TEXTURE
	end
	skyInstance.SkyboxUp = SKY_UP_TEXTURE
	skyInstance.SkyboxDn = SKY_DOWN_TEXTURE
	skyInstance.CelestialBodiesShown = false
	skyInstance.StarCount = 0
	skyInstance.MoonAngularSize = 0
	skyInstance.SunAngularSize = 0

	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") and descendant.Name ~= "LobbySpawn" then
			descendant.Enabled = false
		end
	end

	ChangeHistoryService:SetWaypoint("Build Color Party lobby")
	return world
end

return LobbyBuilder
