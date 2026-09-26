--!strict
-- Раскладка плит арены: генерация схемы (формы разных размеров), постройка
-- частей и перекраска с гарантией, что целевой цвет распределён по площади.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GeometryService = game:GetService("GeometryService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local TILE = Config.ARENA.TILE
local GAP = Config.ARENA.TILE_GAP
local PITCH = TILE + GAP
local THICKNESS = Config.ARENA.TILE_THICKNESS
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

local function template(name: string): BasePart?
	local assets = ServerStorage:FindFirstChild("Assets")
	local item = assets and assets:FindFirstChild(name)
	return if item and item:IsA("BasePart") then item else nil
end

-- Генерация схемы ---------------------------------------------------------

local function cellCenter(i: number, j: number): (number, number)
	return (i + 0.5) * PITCH, (j + 0.5) * PITCH
end

local function pickShape(rng: Random): string
	local r = rng:NextNumber()
	if r < 0.4 then
		return "square"
	elseif r < 0.6 then
		return "circle"
	elseif r < 0.82 then
		return "hex"
	end
	return "tri"
end

function TileLayout.generate(seed: number, radius: number): { TileDesc }
	local rng = Random.new(seed)
	local descs: { TileDesc } = {}
	local used: { [string]: boolean } = {}
	local cells: { { i: number, j: number } } = {}
	local span = math.ceil(radius / PITCH) + 1

	local function key(i: number, j: number): string
		return i .. ":" .. j
	end
	local function inside(i: number, j: number): boolean
		local cx, cz = cellCenter(i, j)
		return math.sqrt(cx * cx + cz * cz) + TILE * 0.55 <= radius
	end
	local function free(i: number, j: number): boolean
		return inside(i, j) and not used[key(i, j)]
	end

	for i = -span, span - 1 do
		for j = -span, span - 1 do
			if inside(i, j) then
				table.insert(cells, { i = i, j = j })
			end
		end
	end
	-- Центральная плита-ловушка занимает 2×2 клетки вокруг центра.
	for _, c in { { -1, -1 }, { -1, 0 }, { 0, -1 }, { 0, 0 } } do
		used[key(c[1], c[2])] = true
	end
	table.insert(descs, { shape = "bigcircle", x = 0, z = 0, w = 2 * PITCH - GAP, d = 2 * PITCH - GAP, rot = 0, hub = true })

	-- Случайный порядок обхода.
	for n = #cells, 2, -1 do
		local m = rng:NextInteger(1, n)
		cells[n], cells[m] = cells[m], cells[n]
	end

	for _, cell in cells do
		local i, j = cell.i, cell.j
		if used[key(i, j)] then
			continue
		end
		local roll = rng:NextNumber()
		if roll < 0.12 and free(i + 1, j) and free(i, j + 1) and free(i + 1, j + 1) then
			for _, c in { { i, j }, { i + 1, j }, { i, j + 1 }, { i + 1, j + 1 } } do
				used[key(c[1], c[2])] = true
			end
			local cx, cz = (i + 1) * PITCH, (j + 1) * PITCH
			local size = 2 * PITCH - GAP
			table.insert(descs, {
				shape = if rng:NextNumber() < 0.55 then "big" else "bigcircle",
				x = cx,
				z = cz,
				w = size,
				d = size,
				rot = 0,
				hub = false,
			})
		elseif roll < 0.36 then
			local horizontal = rng:NextNumber() < 0.5
			local ni, nj = if horizontal then i + 1 else i, if horizontal then j else j + 1
			if free(ni, nj) then
				used[key(i, j)] = true
				used[key(ni, nj)] = true
				local ax, az = cellCenter(i, j)
				local bx, bz = cellCenter(ni, nj)
				table.insert(descs, {
					shape = "rect",
					x = (ax + bx) / 2,
					z = (az + bz) / 2,
					w = if horizontal then 2 * PITCH - GAP else TILE,
					d = if horizontal then TILE else 2 * PITCH - GAP,
					rot = 0,
					hub = false,
				})
			else
				used[key(i, j)] = true
				local cx, cz = cellCenter(i, j)
				table.insert(descs, { shape = pickShape(rng), x = cx, z = cz, w = TILE, d = TILE, rot = 0, hub = false })
			end
		else
			used[key(i, j)] = true
			local cx, cz = cellCenter(i, j)
			local shape = pickShape(rng)
			local rot = 0
			if shape == "tri" then
				rot = if rng:NextNumber() < 0.5 then 0 else 90
			elseif shape == "hex" then
				rot = if rng:NextNumber() < 0.5 then 0 else 30
			end
			table.insert(descs, { shape = shape, x = cx, z = cz, w = TILE, d = TILE, rot = rot, hub = false })
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

local function cylinder(cf: CFrame, diameter: number): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(THICKNESS, diameter, diameter)
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	return p
end

function TileLayout.build(parent: Instance, descs: { TileDesc }, center: Vector3)
	for _, desc in descs do
		local cf = CFrame.new(center + Vector3.new(desc.x, 0, desc.z)) * CFrame.Angles(0, math.rad(desc.rot), 0)
		if desc.shape == "circle" or desc.shape == "bigcircle" then
			finalize(cylinder(cf, desc.w), desc, parent)
		elseif desc.shape == "hex" then
			local source = template("TileHex")
			if source then
				local tile = source:Clone()
				tile.CFrame = cf
				finalize(tile, desc, parent)
			else
				finalize(cylinder(cf, desc.w), desc, parent)
			end
		elseif desc.shape == "tri" then
			-- Клетка делится по диагонали на два прямоугольных треугольника (WedgePart на боку).
			local leg = desc.w - 0.6
			for _, side in { 1, -1 } do
				local wedge = Instance.new("WedgePart")
				wedge.Size = Vector3.new(THICKNESS, leg, leg)
				wedge.CFrame = cf * CFrame.new(side * 0.3, 0, side * 0.3) * CFrame.Angles(0, if side == 1 then 0 else math.pi, 0) * CFrame.Angles(0, 0, math.rad(90))
				finalize(wedge, desc, parent)
			end
		else
			local p = Instance.new("Part")
			p.Size = Vector3.new(desc.w, THICKNESS, desc.d)
			p.CFrame = cf
			finalize(p, desc, parent)
		end
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
		if tile:GetAttribute("Hub") then
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

-- Нейтральная «выключенная» раскраска между матчами: мягкая пастель.
function TileLayout.idle(tiles: { BasePart }, rng: Random)
	local ids = {}
	for _, def in Config.COLORS do
		if def.id ~= "black" then
			table.insert(ids, def.id)
		end
	end
	for _, tile in tiles do
		local def = Config.COLOR_BY_ID[ids[rng:NextInteger(1, #ids)]]
		local h, s, v = def.color:ToHSV()
		tile.Color = Color3.fromHSV(h, s * 0.45, math.min(1, v * 1.05))
		tile:SetAttribute("ColorId", "")
		tile.CanCollide = true
		tile.Transparency = 0
	end
end

return TileLayout
