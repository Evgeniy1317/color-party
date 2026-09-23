--!strict

local Workspace = game:GetService("Workspace")

local RADIUS = 50
local TREE_COUNT = math.random(20, 30)
local ROCK_COUNT = math.random(8, 14)
local MIN_TREE_SPACING = 7
local MIN_ROCK_SPACING = 4
local GROUND_Y = 0

local CROWN_GREENS = {
	Color3.fromRGB(34, 139, 34),
	Color3.fromRGB(46, 139, 87),
	Color3.fromRGB(60, 179, 113),
	Color3.fromRGB(85, 107, 47),
	Color3.fromRGB(107, 142, 35),
	Color3.fromRGB(50, 205, 50),
	Color3.fromRGB(0, 128, 0),
	Color3.fromRGB(69, 160, 73),
}

local TRUNK_BROWNS = {
	Color3.fromRGB(101, 67, 33),
	Color3.fromRGB(80, 50, 20),
	Color3.fromRGB(120, 81, 45),
	Color3.fromRGB(92, 64, 41),
}

local ROCK_GREYS = {
	Color3.fromRGB(96, 96, 100),
	Color3.fromRGB(120, 120, 118),
	Color3.fromRGB(80, 82, 86),
	Color3.fromRGB(140, 138, 132),
	Color3.fromRGB(110, 108, 105),
}

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

local function randomInRadius(radius: number): Vector3
	local angle = math.random() * math.pi * 2
	local distance = radius * math.sqrt(math.random())
	return Vector3.new(math.cos(angle) * distance, GROUND_Y, math.sin(angle) * distance)
end

local function isFarEnough(point: Vector3, occupied: { Vector3 }, minDistance: number): boolean
	for _, other in occupied do
		local dx = point.X - other.X
		local dz = point.Z - other.Z
		if (dx * dx + dz * dz) < (minDistance * minDistance) then
			return false
		end
	end
	return true
end

local function placePoint(radius: number, occupied: { Vector3 }, minDistance: number): Vector3?
	for _ = 1, 40 do
		local candidate = randomInRadius(radius)
		if isFarEnough(candidate, occupied, minDistance) then
			table.insert(occupied, candidate)
			return candidate
		end
	end
	return nil
end

local function makePart(props: {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material,
	Shape: Enum.PartType?,
	Parent: Instance,
}): Part
	local part = Instance.new("Part")
	part.Name = props.Name
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = props.Material
	part.Color = props.Color
	part.Size = props.Size
	part.CFrame = props.CFrame
	if props.Shape then
		part.Shape = props.Shape
	end
	part.Parent = props.Parent
	return part
end

local meadow = Instance.new("Folder")
meadow.Name = "Meadow"

-- Cylinder axis is local X; rotate so it lies flat as a grass disk.
makePart({
	Name = "Grass",
	Size = Vector3.new(0.4, RADIUS * 2 + 8, RADIUS * 2 + 8),
	CFrame = CFrame.new(0, GROUND_Y + 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(76, 153, 62),
	Material = Enum.Material.Grass,
	Shape = Enum.PartType.Cylinder,
	Parent = meadow,
})

local occupied: { Vector3 } = {}

local function createTree(position: Vector3, index: number)
	local tree = Instance.new("Model")
	tree.Name = `Tree_{index}`

	local trunkHeight = 5 + math.random() * 5
	local trunkWidth = 0.7 + math.random() * 0.7
	local trunk = makePart({
		Name = "Trunk",
		Size = Vector3.new(trunkWidth, trunkHeight, trunkWidth),
		CFrame = CFrame.new(position.X, GROUND_Y + trunkHeight / 2, position.Z),
		Color = pick(TRUNK_BROWNS),
		Material = Enum.Material.Wood,
		Parent = tree,
	})

	local crownCount = math.random(1, 3)
	local baseCrownSize = 5 + math.random() * 4
	for i = 1, crownCount do
		local size = if i == 1 then baseCrownSize else baseCrownSize * (0.55 + math.random() * 0.3)
		local offsetX = if i == 1 then 0 else (math.random() - 0.5) * baseCrownSize * 0.55
		local offsetZ = if i == 1 then 0 else (math.random() - 0.5) * baseCrownSize * 0.55
		local offsetY = trunkHeight + size * 0.28 + (if i == 1 then 0 else math.random() * size * 0.2)

		makePart({
			Name = if i == 1 then "Crown" else `Crown_{i}`,
			Size = Vector3.new(size, size, size),
			CFrame = CFrame.new(position.X + offsetX, GROUND_Y + offsetY, position.Z + offsetZ),
			Color = pick(CROWN_GREENS),
			Material = Enum.Material.LeafyGrass,
			Shape = Enum.PartType.Ball,
			Parent = tree,
		})
	end

	tree.PrimaryPart = trunk
	tree.Parent = meadow
end

local function createRock(position: Vector3, index: number)
	local width = 1.4 + math.random() * 2.4
	local height = 0.7 + math.random() * 1.4
	local depth = 1.2 + math.random() * 2.2
	local yaw = math.random() * math.pi * 2
	local tiltX = math.rad((math.random() - 0.5) * 24)
	local tiltZ = math.rad((math.random() - 0.5) * 24)

	makePart({
		Name = `Rock_{index}`,
		Size = Vector3.new(width, height, depth),
		CFrame = CFrame.new(position.X, GROUND_Y + height * 0.35, position.Z)
			* CFrame.Angles(tiltX, yaw, tiltZ),
		Color = pick(ROCK_GREYS),
		Material = Enum.Material.Slate,
		Parent = meadow,
	})
end

for i = 1, TREE_COUNT do
	local point = placePoint(RADIUS, occupied, MIN_TREE_SPACING)
	if point then
		createTree(point, i)
	end
end

for i = 1, ROCK_COUNT do
	local point = placePoint(RADIUS * 0.92, occupied, MIN_ROCK_SPACING)
	if point then
		createRock(point, i)
	end
end

meadow.Parent = Workspace
