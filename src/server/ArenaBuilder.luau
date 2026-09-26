--!strict
-- Сборщик небесных арен. Геометрия запекается в место (Command Bar):
-- require(game.ServerScriptService.Server.ArenaBuilder).build()
-- Плиты пересобираются на старте каждого матча (TileLayout), декор — статичен.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local TileLayout = require(script.Parent:WaitForChild("TileLayout"))

local A = Config.ARENA

local WHITE = Color3.fromRGB(242, 242, 248)
local DARK = Color3.fromRGB(64, 60, 80)
local CLOUD = Color3.fromRGB(234, 234, 244)
local GLOW_IDLE = Color3.fromRGB(196, 186, 255)

local ORB_COLORS = {
	Color3.fromRGB(255, 176, 186),
	Color3.fromRGB(255, 222, 150),
	Color3.fromRGB(170, 236, 206),
	Color3.fromRGB(160, 206, 255),
	Color3.fromRGB(206, 184, 255),
	Color3.fromRGB(255, 196, 228),
}

local ArenaBuilder = {}

-- Помощники --------------------------------------------------------------

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function part(props: {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Parent: Instance,
	Shape: Enum.PartType?,
	CanCollide: boolean?,
	Transparency: number?,
}): Part
	local p = Instance.new("Part")
	p.Name = props.Name
	p.Anchored = true
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Transparency = props.Transparency or 0
	p.Reflectance = 0
	p.CastShadow = p.Material ~= Enum.Material.Neon
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Parent = props.Parent
	return p
end

local function ring(parent: Instance, name: string, center: Vector3, radius: number, y: number, height: number, thickness: number, color: Color3, material: Enum.Material, segs: number, transparency: number?)
	for index = 0, segs - 1 do
		local a0 = (index / segs) * math.pi * 2
		local a1 = ((index + 1) / segs) * math.pi * 2
		local mid = (a0 + a1) / 2
		local chord = 2 * radius * math.sin((a1 - a0) / 2)
		local position = Vector3.new(center.X + math.cos(mid) * radius, y, center.Z + math.sin(mid) * radius)
		local tangent = Vector3.new(-math.sin(mid), 0, math.cos(mid))
		part({
			Name = name,
			Size = Vector3.new(thickness, height, chord + 0.6),
			CFrame = CFrame.lookAt(position, position + tangent),
			Color = color,
			Material = material,
			Transparency = transparency,
			CanCollide = false,
			Parent = parent,
		})
	end
end

local function label(parent: Instance, name: string, position: UDim2, size: UDim2, text: string, textSize: number, color: Color3, font: Enum.Font): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = position
	l.Size = size
	l.Font = font
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = false
	l.TextSize = textSize
	l.TextWrapped = true
	l.Parent = parent
	return l
end

-- Экран над ареной: цвет раунда, название, подпись. Обе стороны одинаковы.
local function screenFace(screen: Part, face: Enum.NormalId, slot: number)
	local gui = Instance.new("SurfaceGui")
	gui.Name = face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0.2
	gui.Brightness = 1.4
	gui.Parent = screen

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(44, 42, 58)
	fill.BorderSizePixel = 0
	fill.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.08, 0)
	corner.Parent = fill

	label(fill, "Title", UDim2.fromScale(0.03, 0.04), UDim2.fromScale(0.94, 0.18), "COLOR PARTY  ·  АРЕНА " .. (slot + 1), 34, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	local main = label(fill, "Main", UDim2.fromScale(0.03, 0.24), UDim2.fromScale(0.94, 0.46), "ОЖИДАНИЕ ИГРОКОВ", 92, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack)
	main.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(30, 28, 40)
	stroke.Transparency = 0.35
	stroke.Parent = main
	label(fill, "Sub", UDim2.fromScale(0.03, 0.72), UDim2.fromScale(0.94, 0.22), "Нажми ГОТОВ в лобби, чтобы сыграть", 36, Color3.fromRGB(240, 240, 248), Enum.Font.GothamMedium)
end

-- Одна арена ---------------------------------------------------------------

function ArenaBuilder.buildArena(parent: Instance, slot: number, center: Vector3): Folder
	local arena = folder(parent, "Arena" .. slot)
	arena:SetAttribute("Slot", slot)
	arena:SetAttribute("Center", center)
	local upperY = center.Y
	local lowerY = center.Y - A.FLOOR_GAP
	arena:SetAttribute("UpperY", upperY)
	arena:SetAttribute("LowerY", lowerY)

	local decor = folder(arena, "Decor")
	local beacons = folder(arena, "Beacons")
	local upper = folder(arena, "Upper")
	local lower = folder(arena, "Lower")
	local spawns = folder(arena, "Spawns")

	-- Плиты (стартовая раскладка; на старте матча пересобираются).
	local seed = 1000 + slot * 17
	TileLayout.build(upper, TileLayout.generate(seed, A.UPPER_RADIUS), Vector3.new(center.X, upperY, center.Z))
	TileLayout.build(lower, TileLayout.generate(seed + 7, A.LOWER_RADIUS), Vector3.new(center.X, lowerY, center.Z))
	TileLayout.idle(TileLayout.tiles(upper), Random.new(seed))
	TileLayout.idle(TileLayout.tiles(lower), Random.new(seed + 1))

	-- Обод каждого этажа: тёмное кольцо, светлая кромка и светящееся кольцо снизу.
	for _, floor in { { r = A.UPPER_RADIUS, y = upperY }, { r = A.LOWER_RADIUS, y = lowerY } } do
		ring(decor, "Rim", center, floor.r + 2.4, floor.y - 1.1, 1.6, 2.6, DARK, Enum.Material.SmoothPlastic, 56)
		ring(decor, "Edge", center, floor.r + 1.0, floor.y - 0.3, 0.5, 1.2, WHITE, Enum.Material.SmoothPlastic, 56)
		ring(beacons, "Beacon", center, floor.r + 1.7, floor.y - 2.5, 0.5, 1.8, GLOW_IDLE, Enum.Material.Neon, 56)
	end

	-- Столпы-лучи вокруг арены: белая колонна, неоновая полоса внутри, неоновая капитель.
	local pillarRadius = A.LOWER_RADIUS + 16
	local bottom = lowerY - 24
	local top = upperY + 26
	local height = top - bottom
	for k = 0, 7 do
		local angle = (k / 8) * math.pi * 2 + math.pi / 8
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local base = Vector3.new(center.X, 0, center.Z) + dir * pillarRadius
		local cf = CFrame.lookAt(Vector3.new(base.X, (top + bottom) / 2, base.Z), Vector3.new(center.X, (top + bottom) / 2, center.Z))
		part({ Name = "Pillar", Size = Vector3.new(3.4, height, 3.4), CFrame = cf, Color = WHITE, Parent = decor })
		part({ Name = "PillarBase", Size = Vector3.new(5.2, 2.2, 5.2), CFrame = cf * CFrame.new(0, -height / 2 - 1.1, 0), Color = DARK, Parent = decor })
		part({ Name = "PillarCap", Size = Vector3.new(4.6, 1.2, 4.6), CFrame = cf * CFrame.new(0, height / 2 + 0.6, 0), Color = DARK, Parent = decor })
		part({ Name = "Beacon", Size = Vector3.new(0.9, height * 0.82, 1.4), CFrame = cf * CFrame.new(0, 0, -1.55), Color = GLOW_IDLE, Material = Enum.Material.Neon, Parent = beacons, CanCollide = false })
		part({ Name = "Beacon", Size = Vector3.new(3.6, 3.6, 3.6), CFrame = cf * CFrame.new(0, height / 2 + 3, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0), Color = GLOW_IDLE, Material = Enum.Material.Neon, Parent = beacons, CanCollide = false })
	end

	-- Орбиты пастельных сфер: верхняя и нижняя, крутятся в разные стороны.
	for _, orbit in { { n = 14, r = A.UPPER_RADIUS + 10, y = upperY + 15, spin = 9, size = 1.9 }, { n = 10, r = A.LOWER_RADIUS + 8, y = lowerY + 12, spin = -7, size = 1.5 } } do
		local spinCenter = Vector3.new(center.X, orbit.y, center.Z)
		for k = 0, orbit.n - 1 do
			local angle = (k / orbit.n) * math.pi * 2
			local pos = spinCenter + Vector3.new(math.cos(angle) * orbit.r, math.sin(k * 1.7) * 2.5, math.sin(angle) * orbit.r)
			local orb = part({
				Name = "Orb",
				Size = Vector3.new(orbit.size, orbit.size, orbit.size),
				CFrame = CFrame.new(pos),
				Color = ORB_COLORS[(k % #ORB_COLORS) + 1],
				Shape = Enum.PartType.Ball,
				CanCollide = false,
				Parent = decor,
			})
			orb:SetAttribute("Spin", orbit.spin)
			orb:SetAttribute("SpinCenter", spinCenter)
		end
	end

	-- Облачный постамент далеко внизу: красиво из окна, игроки пролетают сквозь.
	local cloudY = lowerY - 58
	for _, layer in { { r = A.LOWER_RADIUS + 34, h = 6, t = 0.1 }, { r = A.LOWER_RADIUS + 22, h = 10, t = 0.05 }, { r = A.LOWER_RADIUS + 8, h = 14, t = 0 } } do
		part({
			Name = "Cloud",
			Size = Vector3.new(layer.h, layer.r * 2, layer.r * 2),
			CFrame = CFrame.new(center.X, cloudY - layer.h / 2, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = CLOUD,
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
			Transparency = layer.t,
			Parent = decor,
		})
	end

	-- Экран над центром: смотрит в сторону лобби (−Z) и назад.
	local screen = part({
		Name = "Screen",
		Size = Vector3.new(34, 12, 1.4),
		CFrame = CFrame.new(center.X, upperY + 40, center.Z),
		Color = WHITE,
		Parent = arena,
		CanCollide = false,
	})
	screen:SetAttribute("Bob", 0.6)
	screenFace(screen, Enum.NormalId.Front, slot)
	screenFace(screen, Enum.NormalId.Back, slot)
	for _, side in { -1, 1 } do
		part({ Name = "ScreenRod", Size = Vector3.new(0.5, 14, 0.5), CFrame = CFrame.new(center.X + side * 12, upperY + 53, center.Z), Color = WHITE, CanCollide = false, Parent = decor })
	end
	local bar = part({ Name = "ScreenBar", Size = Vector3.new(40, 1.4, 1.4), CFrame = CFrame.new(center.X, upperY + 60.5, center.Z), Color = WHITE, CanCollide = false, Parent = decor })
	bar:SetAttribute("Bob", 0.6)

	-- Точки появления: кольцо радиуса SPAWN_RADIUS, лицом к центру.
	for k = 0, Config.MAX_PLAYERS_PER_MATCH - 1 do
		local angle = (k / Config.MAX_PLAYERS_PER_MATCH) * math.pi * 2
		local pos = Vector3.new(center.X + math.cos(angle) * A.SPAWN_RADIUS, upperY + 3.5, center.Z + math.sin(angle) * A.SPAWN_RADIUS)
		local spawn = part({
			Name = "Spawn" .. k,
			Size = Vector3.new(2, 2, 2),
			CFrame = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)),
			Color = WHITE,
			Transparency = 1,
			CanCollide = false,
			Parent = spawns,
		})
		spawn:SetAttribute("Index", k)
	end

	return arena
end

-- Все арены ----------------------------------------------------------------

function ArenaBuilder.build(world: Folder?): Folder
	local root = world or Workspace:FindFirstChild("World")
	if not root then
		error("World не найден: сначала соберите лобби (LobbyBuilder.build())")
	end
	local existing = root:FindFirstChild("Arenas")
	if existing then
		existing:Destroy()
	end
	TileLayout.ensureTemplates()

	local arenas = folder(root, "Arenas")
	for index, center in Config.ARENA_SLOTS do
		ArenaBuilder.buildArena(arenas, index - 1, center)
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("Build Color Party arenas")
	end)
	return arenas
end

return ArenaBuilder
