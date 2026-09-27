--!strict
-- Раскладка плит арены: ровная сетка одинаковых квадратов без щелей
-- и перекраска, при которой целевой цвет занимает заданную долю каждого этажа.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GeometryService = game:GetService("GeometryService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local TILE = Config.ARENA.TILE
local THICKNESS = Config.ARENA.TILE_THICKNESS
-- Лёгкий нахлёст, чтобы на стыке не просвечивала щель.
local SEAM = 0.12
local SECTORS = 6

export type TileDesc = {
	shape: string, -- square | rect | big | circle | bigcircle | hex | tri
	x: number,
	z: number,
	w: number,
	d: number,
	rot: number, -- градусы вокруг Y
	hub: boolean,
}

export type Assignment = { id: string, fraction: number, spread: boolean }
export type RecolorPlan = {
	rng: Random,
	assign: { Assignment }, -- цвета с заданной долей (цели, обманка, исключённый)
	fillers: { string }, -- чем закрашивать остальное
	hubId: string, -- цвет центральной плиты-ловушки
}

local TileLayout = {}

-- Шаблоны сложных форм -----------------------------------------------------

local function assetsFolder(): Folder
	local assets = ServerStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ServerStorage
	end
	return assets :: Folder
end

local function makeBlock(size: Vector3, cf: CFrame): Part
	local block = Instance.new("Part")
	block.Anchored = true
	block.Size = size
	block.CFrame = cf
	block.Material = Enum.Material.SmoothPlastic
	block.TopSurface = Enum.SurfaceType.Smooth
	block.BottomSurface = Enum.SurfaceType.Smooth
	return block
end

local TEMPLATE_VERSION = 2

-- IntersectAsync пересекает часть с ОБЪЕДИНЕНИЕМ переданных частей, поэтому
-- пересечение с несколькими пластинами делаем последовательно.
local function intersect(name: string, base: BasePart, others: { BasePart }): BasePart?
	local current: BasePart = base
	for _, other in others do
		local ok, result = pcall(function()
			return GeometryService:IntersectAsync(current, { other }, { CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
		end)
		current:Destroy()
		other:Destroy()
		if not ok or typeof(result) ~= "table" or not result[1] then
			warn("[TileLayout] не удалось построить шаблон " .. name .. ": " .. tostring(result))
			return nil
		end
		current = result[1] :: BasePart
	end
	current.Name = name
	current.Anchored = true
	current.CanCollide = true
	current.Material = Enum.Material.SmoothPlastic
	if current:IsA("PartOperation") then
		current.UsePartColor = true
	end
	current.CFrame = CFrame.new()
	current:SetAttribute("Version", TEMPLATE_VERSION)
	return current
end

local function outdated(assets: Folder, name: string): boolean
	local existing = assets:FindFirstChild(name)
	if not existing then
		return true
	end
	if existing:GetAttribute("Version") ~= TEMPLATE_VERSION then
		existing:Destroy()
		return true
	end
	return false
end

-- Строит (один раз) UnionOperation-шаблоны шестиугольника и треугольника.
function TileLayout.ensureTemplates()
	local assets = assetsFolder()
	if outdated(assets, "TileHex") then
		-- Пересечение трёх пластин под 0/60/120° — правильный шестиугольник.
		local flat = TILE - 0.6
		local base = makeBlock(Vector3.new(24, THICKNESS, flat), CFrame.new())
		local b = makeBlock(Vector3.new(24, THICKNESS, flat), CFrame.Angles(0, math.rad(60), 0))
		local c = makeBlock(Vector3.new(24, THICKNESS, flat), CFrame.Angles(0, math.rad(120), 0))
		local hex = intersect("TileHex", base, { b, c })
		if hex then
			hex.Parent = assets
		end
	end
	-- Треугольники строятся из WedgePart (см. build), шаблон не нужен.
	local oldTri = assets:FindFirstChild("TileTri")
	if oldTri then
		oldTri:Destroy()
	end
end

-- Генерация схемы ---------------------------------------------------------

function TileLayout.generate(_seed: number, half: number): { TileDesc }
	local descs: { TileDesc } = {}
	local count = math.floor(half / TILE + 0.001)
	for i = -count, count - 1 do
		for j = -count, count - 1 do
			table.insert(descs, {
				shape = "square",
				x = (i + 0.5) * TILE,
				z = (j + 0.5) * TILE,
				w = TILE,
				d = TILE,
				rot = 0,
				hub = false,
			})
		end
	end
	return descs
end

-- Постройка ---------------------------------------------------------------

local NEUTRAL = Color3.fromRGB(226, 226, 234)

local function sectorOf(x: number, z: number): number
	local angle = math.atan2(z, x)
	if angle < 0 then
		angle += math.pi * 2
	end
	return math.floor(angle / (math.pi * 2 / SECTORS))
end

local function finalize(tile: BasePart, desc: TileDesc, parent: Instance)
	tile.Name = if desc.hub then "Hub" else "Tile"
	tile.Anchored = true
	tile.CanCollide = true
	tile.Material = Enum.Material.SmoothPlastic
	tile.Color = NEUTRAL
	tile.Reflectance = 0
	tile.TopSurface = Enum.SurfaceType.Smooth
	tile.BottomSurface = Enum.SurfaceType.Smooth
	tile:SetAttribute("ColorId", "")
	tile:SetAttribute("Shape", desc.shape)
	tile:SetAttribute("Hub", desc.hub)
	tile:SetAttribute("Sector", sectorOf(desc.x, desc.z))
	tile:SetAttribute("Dist", math.sqrt(desc.x * desc.x + desc.z * desc.z))
	tile.Parent = parent
end

function TileLayout.build(parent: Instance, descs: { TileDesc }, center: Vector3)
	for _, desc in descs do
		local p = Instance.new("Part")
		p.Size = Vector3.new(desc.w + SEAM, THICKNESS, desc.d + SEAM)
		p.CFrame = CFrame.new(center + Vector3.new(desc.x, 0, desc.z))
		finalize(p, desc, parent)
	end
end

function TileLayout.tiles(folder: Instance): { BasePart }
	local list = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and (child.Name == "Tile" or child.Name == "Hub") then
			table.insert(list, child)
		end
	end
	return list
end

-- Перекраска --------------------------------------------------------------

local function applyColor(tile: BasePart, id: string)
	local def = Config.COLOR_BY_ID[id]
	tile.Color = if def then def.color else NEUTRAL
	tile:SetAttribute("ColorId", id)
end

function TileLayout.recolor(tiles: { BasePart }, plan: RecolorPlan)
	local rng = plan.rng
	local pool: { BasePart } = {}
	for _, tile in tiles do
		if tile:GetAttribute("Hub") == true then
			applyColor(tile, plan.hubId)
		else
			table.insert(pool, tile)
		end
	end
	for n = #pool, 2, -1 do
		local m = rng:NextInteger(1, n)
		pool[n], pool[m] = pool[m], pool[n]
	end
	local total = #pool
	local taken: { [BasePart]: boolean } = {}

	local function take(tile: BasePart, id: string)
		taken[tile] = true
		applyColor(tile, id)
	end

	for _, assignment in plan.assign do
		local count = math.max(1, math.round(total * assignment.fraction))
		local placed = 0
		if assignment.spread then
			-- Минимум по одной плите в каждом секторе, чтобы бежать было куда из любой точки.
			for sector = 0, SECTORS - 1 do
				for _, tile in pool do
					if not taken[tile] and tile:GetAttribute("Sector") == sector then
						take(tile, assignment.id)
						placed += 1
						break
					end
				end
			end
		end
		for _, tile in pool do
			if placed >= count then
				break
			end
			if not taken[tile] then
				take(tile, assignment.id)
				placed += 1
			end
		end
	end

	local fillers = plan.fillers
	for _, tile in pool do
		if not taken[tile] then
			applyColor(tile, fillers[rng:NextInteger(1, #fillers)])
		end
	end
end

-- Раскраска между матчами: полная яркая палитра, без выцветания.
function TileLayout.idle(tiles: { BasePart }, rng: Random)
	local ids = {}
	for _, def in Config.COLORS do
		table.insert(ids, def.id)
	end
	for _, tile in tiles do
		local def = Config.COLOR_BY_ID[ids[rng:NextInteger(1, #ids)]]
		tile.Color = def.color
		tile:SetAttribute("ColorId", "")
		tile.CanCollide = true
		tile.Transparency = 0
	end
end

return TileLayout
