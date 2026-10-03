--!strict
-- Контроллер одного матча на одной арене: телепорт, раунды, падения,
-- две жизни, обманки, сжатие арены, монеты, бонусы, итоги.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local TileLayout = require(script.Parent:WaitForChild("TileLayout"))
local RoundRules = require(script.Parent:WaitForChild("RoundRules"))
local Economy = require(script.Parent:WaitForChild("Economy"))

local A = Config.ARENA
local IDLE_GLOW = Color3.fromRGB(196, 186, 255)
local GOLD = Color3.fromRGB(255, 206, 84)

local function playerGroup(player: Player): string
	return "CP" .. player.UserId
end

local function catchGroup(player: Player): string
	return "CC" .. player.UserId
end

local function ensureGroups(player: Player)
	local pg, cg = playerGroup(player), catchGroup(player)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(pg)
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(cg)
	end)
	PhysicsService:CollisionGroupSetCollidable(cg, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(pg, "Default", true)
	for _, other in Players:GetPlayers() do
		local otherGroup = playerGroup(other)
		local otherCatch = catchGroup(other)
		pcall(function()
			PhysicsService:RegisterCollisionGroup(otherGroup)
		end)
		pcall(function()
			PhysicsService:RegisterCollisionGroup(otherCatch)
		end)
		PhysicsService:CollisionGroupSetCollidable(cg, otherGroup, other == player)
		PhysicsService:CollisionGroupSetCollidable(pg, otherCatch, other == player)
	end
end

local function tagCharacter(player: Player, character: Model)
	local pg = playerGroup(player)
	for _, desc in character:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.CollisionGroup = pg
		end
	end
end

export type Participant = {
	player: Player,
	alive: boolean,
	floor: string, -- upper | lower
	lives: number,
	streak: number,
	rounds: number,
	shield: boolean,
	place: number?, -- порядок выбывания (1 = выбыл первым)
	left: boolean,
	catchPad: BasePart?,
	shieldPad: BasePart?,
	spawnPad: BasePart?,
	arrived: boolean,
	stable: boolean,
	placedAt: number,
	shieldAt: number,
	dashUntil: number,
	lastSafe: Vector3?,
	catchHold: number,
}

local MatchController = {}
MatchController.__index = MatchController

export type MatchController = typeof(setmetatable({} :: {
	slot: number,
	arena: Folder,
	center: Vector3,
	upperY: number,
	lowerY: number,
	state: string,
	round: number,
	rng: Random,
	participants: { Participant },
	spectators: { [Player]: boolean },
	eliminatedCount: number,
	connections: { RBXScriptConnection },
	pickups: Folder?,
	onFinished: ((MatchController) -> ())?,
	roundStartAlive: { Participant },
	palette: { string },
	dropGen: number,
}, MatchController))

-- Создание ---------------------------------------------------------------

function MatchController.new(arena: Folder, onFinished: ((MatchController) -> ())?): MatchController
	local self = setmetatable({}, MatchController) :: MatchController
	self.slot = arena:GetAttribute("Slot") :: number
	self.arena = arena
	self.center = arena:GetAttribute("Center") :: Vector3
	self.upperY = arena:GetAttribute("UpperY") :: number
	self.lowerY = arena:GetAttribute("LowerY") :: number
	self.state = "idle"
	self.round = 0
	self.rng = Random.new()
	self.participants = {}
	self.spectators = {}
	self.eliminatedCount = 0
	self.connections = {}
	self.onFinished = onFinished
	self.roundStartAlive = {}
	self.palette = {}
	self.dropGen = 0
	return self
end

function MatchController:isFree(): boolean
	return self.state == "idle"
end

function MatchController:isActive(): boolean
	return self.state == "running"
end

function MatchController:aliveList(): { Participant }
	local list = {}
	for _, p in self.participants do
		if p.alive then
			table.insert(list, p)
		end
	end
	return list
end

function MatchController:audience(): { Player }
	local list = {}
	for _, p in self.participants do
		if not p.left and p.player.Parent then
			table.insert(list, p.player)
		end
	end
	for player in self.spectators do
		if player.Parent and not table.find(list, player) then
			table.insert(list, player)
		end
	end
	return list
end

function MatchController:send(payload: { [string]: any })
	payload.slot = self.slot
	local remote = Remotes.get("MatchState")
	for _, player in self:audience() do
		remote:FireClient(player, payload)
	end
end

function MatchController:feed(text: string, kind: string?)
	local remote = Remotes.get("RoundEvent")
	for _, player in self:audience() do
		remote:FireClient(player, text, kind or "info")
	end
end

function MatchController:info(): { alive: number, total: number, round: number }
	return { alive = #self:aliveList(), total = #self.participants, round = self.round }
end

-- Визуал арены -------------------------------------------------------------

function MatchController:setBeacons(color: Color3)
	local beacons = self.arena:FindFirstChild("Beacons")
	if not beacons then
		return
	end
	for _, beacon in beacons:GetChildren() do
		if beacon:IsA("BasePart") then
			TweenService:Create(beacon, TweenInfo.new(0.35), { Color = color }):Play()
		end
	end
end

function MatchController:setScreen(main: string, sub: string, fill: Color3)
	local screen = self.arena:FindFirstChild("Screen")
	if not screen then
		return
	end
	for _, gui in screen:GetChildren() do
		if gui:IsA("SurfaceGui") then
			local frame = gui:FindFirstChild("Fill")
			if frame and frame:IsA("Frame") then
				TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundColor3 = fill }):Play()
				local panel = frame:FindFirstChild("Panel")
				local host = if panel and panel:IsA("Frame") then panel else frame
				local chip = host:FindFirstChild("Chip")
				if chip and chip:IsA("Frame") then
					chip.BackgroundColor3 = fill
				end
				local mainLabel = host:FindFirstChild("Main")
				if mainLabel and mainLabel:IsA("TextLabel") then
					mainLabel.Text = main
					mainLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
				local subLabel = host:FindFirstChild("Sub")
				if subLabel and subLabel:IsA("TextLabel") then
					subLabel.Text = sub
					subLabel.TextColor3 = Color3.fromRGB(220, 224, 240)
				end
			end
		end
	end
end

function MatchController:tiles(): { BasePart }
	local list = TileLayout.tiles(self.arena:WaitForChild("Upper"))
	for _, tile in TileLayout.tiles(self.arena:WaitForChild("Lower")) do
		table.insert(list, tile)
	end
	return list
end

function MatchController:rebuildTiles()
	local seed = self.rng:NextInteger(1, 1_000_000)
	for _, floor in { { name = "Upper", r = A.UPPER_RADIUS, y = self.upperY }, { name = "Lower", r = A.LOWER_RADIUS, y = self.lowerY } } do
		local holder = self.arena:FindFirstChild(floor.name)
		if holder then
			holder:ClearAllChildren()
		else
			holder = Instance.new("Folder")
			holder.Name = floor.name
			holder.Parent = self.arena
		end
		TileLayout.build(holder, TileLayout.generate(seed, floor.r), Vector3.new(self.center.X, floor.y, self.center.Z))
		seed += 7
	end
end

function MatchController:idleLook()
	TileLayout.idle(self:tiles(), self.rng)
	self:setBeacons(IDLE_GLOW)
	self:setScreen("ОЖИДАНИЕ ИГРОКОВ", "Нажми ГОТОВ в лобби, чтобы сыграть", Color3.fromRGB(44, 42, 58))
end

-- Плиты нужного цвета остаются на обоих этажах. Остальные пропадают.
function MatchController:dropTiles(rule: RoundRules.Rule, protected: { [BasePart]: boolean })
	local function stays(tile: BasePart): boolean
		if protected[tile] or tile:GetAttribute("ShieldHeld") == true then
			return true
		end
		local id = tile:GetAttribute("ColorId")
		if RoundRules.isSafe(rule, if typeof(id) == "string" then id else nil, false) then
			return true
		end
		for _, targetId in rule.targets do
			local def = Config.COLOR_BY_ID[targetId]
			if def then
				local color = tile.Color
				if math.abs(color.R - def.color.R) < 0.004
					and math.abs(color.G - def.color.G) < 0.004
					and math.abs(color.B - def.color.B) < 0.004
				then
					tile:SetAttribute("ColorId", targetId)
					return true
				end
			end
		end
		return false
	end

	local tiles = self:tiles()
	local staying: { [BasePart]: boolean } = {}
	local falling: { BasePart } = {}
	for _, tile in tiles do
		if stays(tile) then
			staying[tile] = true
		else
			table.insert(falling, tile)
		end
	end
	if next(staying) == nil then
		warn("[ColorParty] no safe tiles this round, floor stays")
		return
	end

	for tile in staying do
		tile.CanCollide = true
		tile.Transparency = 0
	end
	for _, tile in falling do
		tile.CanCollide = false
		if typeof(tile:GetAttribute("HomeCF")) ~= "CFrame" then
			tile:SetAttribute("HomeCF", tile.CFrame)
		end
	end

	-- Падение задаётся прямым свойством, без TweenService: массовый твин
	-- прозрачности на клиенте гасил и те плиты, которые должны остаться.
	self.dropGen += 1
	local gen = self.dropGen
	task.spawn(function()
		local steps = 8
		for step = 1, steps do
			if self.dropGen ~= gen then
				return
			end
			local alpha = step / steps
			for _, tile in falling do
				if tile.Parent and tile:GetAttribute("ShieldHeld") == true then
					local home = tile:GetAttribute("HomeCF")
					if typeof(home) == "CFrame" then
						tile.CFrame = home
					end
					tile.CanCollide = true
					tile.Transparency = 0
				elseif tile.Parent then
					local home = tile:GetAttribute("HomeCF")
					if typeof(home) == "CFrame" then
						tile.CFrame = home * CFrame.new(0, -18 * alpha, 0)
					end
					tile.Transparency = alpha
				end
			end
			for tile in staying do
				if tile.Parent then
					tile.Transparency = 0
					tile.CanCollide = true
				end
			end
			task.wait(0.04)
		end
	end)
end

function MatchController:restoreTiles()
	self.dropGen += 1
	for _, tile in self:tiles() do
		local home = tile:GetAttribute("HomeCF")
		if typeof(home) == "CFrame" then
			tile.CFrame = home
		end
		tile.CanCollide = true
		tile.Transparency = 0
		tile:SetAttribute("ShieldHeld", nil)
	end
	self:clearCatchPads()
	self:clearShieldPads()
end

function MatchController:shrink(count: number)
	if count <= 0 then
		return
	end
	local removed = 0
	for _, floorName in { "Upper", "Lower" } do
		local holder = self.arena:FindFirstChild(floorName)
		if not holder then
			continue
		end
		local list = TileLayout.tiles(holder)
		table.sort(list, function(a, b)
			return (a:GetAttribute("Dist") :: number) > (b:GetAttribute("Dist") :: number)
		end)
		local quota = if floorName == "Upper" then count else math.ceil(count / 2)
		for i = 1, math.min(quota, #list - 6) do
			local tile = list[i]
			if tile:GetAttribute("Hub") or (tile:GetAttribute("Dist") :: number) < 0 then
				continue
			end
			tile.CanCollide = false
			local tween = TweenService:Create(tile, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
				CFrame = tile.CFrame * CFrame.new(0, -12, 0),
			})
			tween.Completed:Connect(function()
				tile:Destroy()
			end)
			tween:Play()
			removed += 1
		end
	end
	if removed > 0 then
		self:feed("Арена сжимается! Исчезло плит: " .. removed, "warn")
	end
end

-- Монеты и бонусы -----------------------------------------------------------

function MatchController:pickupFolder(): Folder
	local existing = self.arena:FindFirstChild("Pickups")
	if existing then
		return existing :: Folder
	end
	local folder = Instance.new("Folder")
	folder.Name = "Pickups"
	folder.Parent = self.arena
	return folder
end

function MatchController:clearPickups()
	local folder = self.arena:FindFirstChild("Pickups")
	if folder then
		folder:ClearAllChildren()
	end
end

function MatchController:participantOf(player: Player): Participant?
	for _, p in self.participants do
		if p.player == player then
			return p
		end
	end
	return nil
end

function MatchController:randomFloorTiles(floorName: string, count: number): { BasePart }
	local holder = self.arena:FindFirstChild(floorName)
	if not holder then
		return {}
	end
	local list = {}
	for _, tile in TileLayout.tiles(holder) do
		if tile:GetAttribute("Hub") ~= true then
			table.insert(list, tile)
		end
	end
	for n = #list, 2, -1 do
		local m = self.rng:NextInteger(1, n)
		list[n], list[m] = list[m], list[n]
	end
	local chosen = {}
	for i = 1, math.min(count, #list) do
		chosen[i] = list[i]
	end
	return chosen
end

local function dressPart(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Anchored = false
end

function MatchController:showShieldRing(p: Participant)
	local character = p.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	self:clearShieldRing(p)
	local bubble = Instance.new("Part")
	bubble.Name = "ShieldRing"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.new(7.2, 7.2, 7.2)
	bubble.Color = Color3.fromRGB(110, 186, 255)
	bubble.Material = Enum.Material.ForceField
	bubble.Transparency = 0.25
	dressPart(bubble)
	bubble.CFrame = root.CFrame * CFrame.new(0, 0.2, 0)
	bubble.Parent = character
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = bubble
	weld.Parent = bubble
end

function MatchController:poseShield(_root: BasePart, _now: number)
end

function MatchController:clearShieldRing(p: Participant)
	local character = p.player.Character
	if not character then
		return
	end
	local ring = character:FindFirstChild("ShieldRing")
	if ring then
		ring:Destroy()
	end
	local aura = character:FindFirstChild("ShieldAura")
	if aura then
		aura:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local glow = root and root:FindFirstChild("ShieldGlow")
	if glow then
		glow:Destroy()
	end
end

function MatchController:playerFloorY(p: Participant, rootY: number): number
	local upperTop = self.upperY + A.TILE_THICKNESS * 0.5
	local lowerTop = self.lowerY + A.TILE_THICKNESS * 0.5
	if math.abs(rootY - upperTop) <= 18 then
		return self.upperY
	end
	if math.abs(rootY - lowerTop) <= 18 then
		return self.lowerY
	end
	return if p.floor == "lower" then self.lowerY else self.upperY
end

function MatchController:tilesNear(origin: Vector3, floorY: number, radius: number): { BasePart }
	local found = {}
	local limit = radius * radius
	for _, tile in self:tiles() do
		local home = tile:GetAttribute("HomeCF")
		local pos = if typeof(home) == "CFrame" then home.Position else tile.Position
		if math.abs(pos.Y - floorY) > 3 then
			continue
		end
		local dx = origin.X - pos.X
		local dz = origin.Z - pos.Z
		if dx * dx + dz * dz <= limit then
			table.insert(found, tile)
		end
	end
	return found
end

function MatchController:floorSupported(origin: Vector3, floorY: number): boolean
	local under: BasePart? = nil
	local best = math.huge
	for _, tile in self:tilesNear(origin, floorY, 8) do
		local home = tile:GetAttribute("HomeCF")
		local pos = if typeof(home) == "CFrame" then home.Position else tile.Position
		local dx = origin.X - pos.X
		local dz = origin.Z - pos.Z
		if math.abs(dx) <= tile.Size.X * 0.5 and math.abs(dz) <= tile.Size.Z * 0.5 then
			local dist = dx * dx + dz * dz
			if dist < best then
				best = dist
				under = tile
			end
		end
	end
	return under ~= nil and under.CanCollide
end

function MatchController:standingIsSafe(root: BasePart, rule: RoundRules.Rule, floorY: number): boolean
	local near = self:tilesNear(root.Position, floorY, 7)
	if #near == 0 then
		return true
	end
	for _, tile in near do
		local id = tile:GetAttribute("ColorId")
		if not RoundRules.isSafe(rule, if typeof(id) == "string" then id else nil, false) then
			return false
		end
	end
	return true
end

function MatchController:holdIsland(origin: Vector3, floorY: number, protected: { [BasePart]: boolean }?)
	for _, tile in self:tilesNear(origin, floorY, 15) do
		if protected then
			protected[tile] = true
		end
		tile:SetAttribute("ShieldHeld", true)
		local home = tile:GetAttribute("HomeCF")
		if typeof(home) ~= "CFrame" then
			tile:SetAttribute("HomeCF", tile.CFrame)
			home = tile.CFrame
		end
		if typeof(home) == "CFrame" then
			tile.CFrame = home
		end
		tile.CanCollide = true
		tile.Transparency = 0
	end
end

function MatchController:giveShieldPad(p: Participant, root: BasePart, floorY: number, spot: Vector3?)
	local at = spot or root.Position
	local top = floorY + A.TILE_THICKNESS * 0.5 - 0.15
	local pad = p.shieldPad
	if not pad or not pad.Parent then
		pad = Instance.new("Part")
		pad.Name = "ShieldPad"
		pad.Size = Vector3.new(18, 2, 18)
		pad.Anchored = true
		pad.CanCollide = true
		pad.CanQuery = false
		pad.CanTouch = false
		pad.Transparency = 1
		pad.CastShadow = false
		pad.CollisionGroup = "Default"
		pad.Parent = self.arena
		p.shieldPad = pad
	end
	pad.CollisionGroup = "Default"
	pad.CanCollide = true
	pad.CFrame = CFrame.new(at.X, top - 1, at.Z)
end

function MatchController:clearShieldPads()
	for _, p in self.participants do
		if p.shieldPad then
			p.shieldPad:Destroy()
			p.shieldPad = nil
		end
	end
	if self.arena then
		for _, child in self.arena:GetChildren() do
			if child.Name == "ShieldPad" then
				child:Destroy()
			end
		end
	end
end

function MatchController:spendShield(p: Participant, root: BasePart, floorY: number, protected: { [BasePart]: boolean }?, placeAt: Vector3?)
	if not p.shield then
		return
	end
	p.shield = false
	p.player:SetAttribute("Shield", nil)
	local spot = placeAt or root.Position
	self:holdIsland(spot, floorY, protected)
	self:giveShieldPad(p, root, floorY, spot)
	local character = p.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 2
	local stand = floorY + A.TILE_THICKNESS * 0.5 + hip + root.Size.Y * 0.5 + 0.2
	local away = (Vector3.new(root.Position.X - spot.X, 0, root.Position.Z - spot.Z)).Magnitude
	if character and (root.Position.Y < stand - 1.2 or away > 2.5) then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		character:PivotTo(CFrame.new(spot.X, stand, spot.Z) * (root.CFrame - root.Position))
	end
	self:clearShieldRing(p)
end

function MatchController:showDashTrail(p: Participant)
	local root = p.player.Character and p.player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local previous = root:FindFirstChild("DashTrail")
	if previous then
		previous:Destroy()
	end
	local top = Instance.new("Attachment")
	top.Name = "DashTop"
	top.Position = Vector3.new(0, 0.9, 0.5)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "DashBottom"
	bottom.Position = Vector3.new(0, -1.2, 0.5)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "DashTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.5
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.LightEmission = 0.3
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 196, 90), Color3.fromRGB(255, 120, 40))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(1, 0.15)
	trail.Parent = root
	task.delay(3.5, function()
		trail:Destroy()
		top:Destroy()
		bottom:Destroy()
	end)
end

local PICKUP_LOOK = {
	Coin = { spin = 140, lift = 2.6, scale = 2.6 },
	Shield = { spin = 46, lift = 3.2, scale = 3.5 },
	Dash = { spin = 80, lift = 3.4, scale = 4.4 },
}

function MatchController:takePickup(item: Instance, p: Participant)
	if item:GetAttribute("Taken") or not p.alive then
		return
	end
	item:SetAttribute("Taken", true)
	local kind = item:GetAttribute("Pickup")
	if kind == "Coin" then
		Economy.addCoins(p.player, 10, "coin")
	elseif kind == "Shield" then
		p.shield = true
		p.player:SetAttribute("Shield", true)
		local root = p.player.Character and p.player.Character:FindFirstChild("HumanoidRootPart")
		p.shieldAt = os.clock()
		if root and root:IsA("BasePart") then
			p.lastSafe = root.Position
			self:giveShieldPad(p, root, self:playerFloorY(p, root.Position.Y), root.Position)
		end
		self:showShieldRing(p)
	elseif kind == "Dash" then
		local humanoid = p.player.Character and p.player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			p.dashUntil = os.clock() + 3.5
			humanoid.WalkSpeed = 27
			self:showDashTrail(p)
			if p.shield then
				self:showShieldRing(p)
			end
			task.delay(3.5, function()
				if humanoid.Parent then
					humanoid.WalkSpeed = 16
				end
			end)
		end
	end
	item:Destroy()
end

function MatchController:spawnPickup(kind: string, worldPos: Vector3)
	local look = PICKUP_LOOK[kind]
	local templates = ServerStorage:FindFirstChild("PickupModels")
	local source = templates and templates:FindFirstChild(kind)
	if not source or not source:IsA("Model") or not look then
		return
	end
	local model = source:Clone()
	for _, desc in model:GetDescendants() do
		if desc:IsA("LuaSourceContainer") or desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
			desc:Destroy()
		end
	end
	model.Parent = self:pickupFolder()
	local size = model:GetExtentsSize()
	local largest = math.max(size.X, size.Y, size.Z, 0.05)
	model:ScaleTo(look.scale / largest)
	size = model:GetExtentsSize()
	local cf = CFrame.new(worldPos + Vector3.new(0, look.lift, 0))
	if size.Z < size.X * 0.45 and size.Z < size.Y * 0.45 then
		cf *= CFrame.Angles(math.rad(90), 0, 0)
	end
	model:PivotTo(cf)
	model.Name = kind
	model:SetAttribute("Pickup", kind)
	model:SetAttribute("BaseCF", model:GetPivot())
	model:SetAttribute("Spin", look.spin)
	local host: BasePart? = nil
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
			if not host then
				host = desc
			end
		end
	end
	if host then
		local arrow = Instance.new("BillboardGui")
		arrow.Name = "Arrow"
		arrow.Size = UDim2.fromOffset(26, 26)
		arrow.StudsOffset = Vector3.new(0, 2.2, 0)
		arrow.AlwaysOnTop = false
		arrow.MaxDistance = 90
		arrow.LightInfluence = 0
		arrow.Adornee = host
		arrow.Parent = host
		local mark = Instance.new("TextLabel")
		mark.BackgroundTransparency = 1
		mark.Size = UDim2.fromScale(1, 1)
		mark.Font = Enum.Font.BuilderSansBold
		mark.TextScaled = true
		mark.Text = if kind == "Coin" then "10" else "▼"
		mark.TextColor3 = if kind == "Coin" then GOLD elseif kind == "Shield" then Color3.fromRGB(120, 186, 255) else Color3.fromRGB(255, 170, 70)
		mark.Parent = arrow
	end
end

function MatchController:spawnCoins()
	local folder = self:pickupFolder()
	local existing = 0
	for _, child in folder:GetChildren() do
		if child:GetAttribute("Pickup") == "Coin" then
			existing += 1
		end
	end
	if existing >= 18 then
		return
	end
	local count = self.rng:NextInteger(Config.COINS_ON_FIELD[1], Config.COINS_ON_FIELD[2])
	for _, floorName in { "Upper", "Lower" } do
		for _, tile in self:randomFloorTiles(floorName, count) do
			self:spawnPickup("Coin", tile.Position)
		end
	end
end

function MatchController:spawnBonus()
	if self.round < Config.BONUS_FROM_ROUND or self.rng:NextNumber() > Config.BONUS_CHANCE then
		return
	end
	local kind = if self.rng:NextNumber() < 0.5 then "Shield" else "Dash"
	local spawned = false
	for _, floorName in { "Upper", "Lower" } do
		local tiles = self:randomFloorTiles(floorName, 1)
		if tiles[1] then
			self:spawnPickup(kind, tiles[1].Position)
			spawned = true
		end
	end
	if spawned then
		self:feed(if kind == "Shield" then "На арене щит — подбери его" else "На арене рывок — подбери молнию", "bonus")
	end
end

-- Игроки -------------------------------------------------------------------

local function lobbySpawn(): CFrame
	local world = workspace:FindFirstChild("World")
	local lobby = world and world:FindFirstChild("Lobby")
	local spawn = lobby and lobby:FindFirstChild("LobbySpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 4, 0)
	end
	return CFrame.new(0, 64, -180)
end

local function clearWornEffects(player: Player)
	local character = player.Character
	if not character then
		return
	end
	for _, name in { "ShieldRing", "ShieldAura" } do
		local item = character:FindFirstChild(name)
		if item then
			item:Destroy()
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, name in { "DashTrail", "DashTop", "DashBottom", "ShieldGlow" } do
			local item = root:FindFirstChild(name)
			if item then
				item:Destroy()
			end
		end
	end
end

local function toLobby(player: Player)
	clearWornEffects(player)
	local character = player.Character
	if character then
		character:PivotTo(lobbySpawn())
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16
		end
	end
end

function MatchController:clearPlayerState(player: Player)
	player:SetAttribute("InMatch", nil)
	player:SetAttribute("Lives", nil)
	player:SetAttribute("Shield", nil)
	player:SetAttribute("Streak", 0)
end

function MatchController:eliminate(p: Participant, reason: string)
	if not p.alive then
		return
	end
	p.alive = false
	p.streak = 0
	self.eliminatedCount += 1
	p.place = self.eliminatedCount
	if p.shieldPad then
		p.shieldPad:Destroy()
		p.shieldPad = nil
	end
	self:clearShieldRing(p)
	self:clearPlayerState(p.player)
	if not p.left then
		self.spectators[p.player] = true
		toLobby(p.player)
		Economy.recordRounds(p.player, p.rounds)
		local info = self:info()
		self:feed(p.player.DisplayName .. (if reason == "left" then " покинул матч" else " выбыл!") .. "  Осталось: " .. info.alive, "out")
		Remotes.get("MatchState"):FireClient(p.player, {
			phase = "eliminated",
			slot = self.slot,
			center = self.center,
			place = #self.participants - p.place + 1,
			round = self.round,
		})
	end
end

function MatchController:plantOnLower(p: Participant, root: BasePart)
	local character = root.Parent
	if not character or not character:IsA("Model") then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 2
	local stand = self.lowerY + A.TILE_THICKNESS * 0.5 + hip + root.Size.Y * 0.5 + 0.35
	local half = A.LOWER_RADIUS - 8
	local x = math.clamp(root.Position.X, self.center.X - half, self.center.X + half)
	local z = math.clamp(root.Position.Z, self.center.Z - half, self.center.Z + half)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(CFrame.new(x, stand, z) * (root.CFrame - root.Position))
	if os.clock() < p.catchHold then
		return
	end
	p.catchHold = os.clock() + 0.5
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	task.delay(0.55, function()
		if root.Parent and p.alive and os.clock() >= p.catchHold then
			pcall(function()
				root:SetNetworkOwner(p.player)
			end)
		end
	end)
end

function MatchController:beginCatch(p: Participant, root: BasePart)
	if p.catchPad and p.catchPad.Parent then
		return
	end
	p.floor = "lower"
	p.lives = 1
	p.streak = 0
	p.catchHold = 0
	p.player:SetAttribute("Lives", 1)
	p.player:SetAttribute("Streak", 0)
	self:feed(p.player.DisplayName .. " упал на нижний этаж!", "fall")
	ensureGroups(p.player)
	PhysicsService:CollisionGroupSetCollidable(playerGroup(p.player), catchGroup(p.player), true)
	if p.player.Character then
		tagCharacter(p.player, p.player.Character)
	end
	-- Поле на весь нижний этаж: дыры в плитах не пробивают вторую жизнь в том же падении.
	local thickness = 8
	local top = self.lowerY + A.TILE_THICKNESS * 0.5
	local pad = Instance.new("Part")
	pad.Name = "CatchPad"
	pad.Size = Vector3.new(A.LOWER_RADIUS * 2 - 6, thickness, A.LOWER_RADIUS * 2 - 6)
	pad.Anchored = true
	pad.CanCollide = true
	pad.CanQuery = false
	pad.CanTouch = false
	pad.Transparency = 1
	pad.CastShadow = false
	pad.CFrame = CFrame.new(self.center.X, top - thickness * 0.5, self.center.Z)
	pad.Parent = self.arena
	pad.CollisionGroup = catchGroup(p.player)
	p.catchPad = pad
	if root.Position.Y < self.lowerY + 1 then
		self:plantOnLower(p, root)
	end
end

function MatchController:clearCatchPads()
	for _, p in self.participants do
		if p.catchPad then
			p.catchPad:Destroy()
			p.catchPad = nil
		end
	end
end

function MatchController:watch()
	-- Первое падение снимает одну жизнь и ловит игрока личной площадкой.
	-- Второе падение ниже нижнего этажа выбивает из матча.
	table.insert(self.connections, RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, p in self.participants do
			if not p.alive then
				continue
			end
			local character = p.player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not p.arrived then
				self:placeOnArena(p)
				continue
			end
			if not root or not root:IsA("BasePart") then
				continue
			end
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				if not p.stable then
					p.arrived = false
				else
					self:eliminate(p, "died")
				end
				continue
			end
			local y = root.Position.Y
			local dx = math.abs(root.Position.X - self.center.X)
			local dz = math.abs(root.Position.Z - self.center.Z)
			if p.arrived and p.placedAt > 0 and os.clock() - p.placedAt >= 4 and dx <= A.LOWER_RADIUS + 24 and dz <= A.LOWER_RADIUS + 24 then
				p.stable = true
			end
			if (dx > A.LOWER_RADIUS + 36 or dz > A.LOWER_RADIUS + 36) then
				if not p.stable then
					p.arrived = false
				else
					self:eliminate(p, "fell")
				end
				continue
			end
			self:poseShield(root, now)
			local savedByShield = false
			if p.shield then
				local floorY = self:playerFloorY(p, y)
				local top = floorY + A.TILE_THICKNESS * 0.5
				local supported = self:floorSupported(root.Position, floorY)
				if supported and y >= top - 1.5 then
					p.lastSafe = Vector3.new(root.Position.X, floorY, root.Position.Z)
				end
				local spot = root.Position
				local back = p.lastSafe
				if not supported and back then
					local hopX = root.Position.X - back.X
					local hopZ = root.Position.Z - back.Z
					if hopX * hopX + hopZ * hopZ > 40 * 40 then
						spot = Vector3.new(back.X, root.Position.Y, back.Z)
					end
				end
				self:giveShieldPad(p, root, floorY, spot)
				-- Рывок не тратит щит. Щит сгорает только от настоящей дыры под ногами.
				if not supported and now >= p.dashUntil then
					self:spendShield(p, root, floorY, nil, spot)
					savedByShield = true
				elseif not supported then
					savedByShield = true
				end
			end
			if not savedByShield then
				if p.floor == "upper" and y < self.upperY - 8 then
					if root.AssemblyLinearVelocity.Y < -42 then
						root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -42, root.AssemblyLinearVelocity.Z)
					end
					self:beginCatch(p, root)
				end
				local pad = p.catchPad
				if pad and pad.Parent then
					-- Поле держит до конца раунда. Сквозь него жизнь больше не снимается.
					if y < self.lowerY + 1 then
						self:plantOnLower(p, root)
					end
				elseif y < self.lowerY - A.FALL_LIMIT then
					self:eliminate(p, "fell")
					continue
				end
			end
			local pickups = self.arena:FindFirstChild("Pickups")
			if pickups then
				for _, item in pickups:GetChildren() do
					if item:GetAttribute("Taken") then
						continue
					end
					local base = item:GetAttribute("BaseCF")
					local spin = item:GetAttribute("Spin")
					if item:IsA("Model") and typeof(base) == "CFrame" and typeof(spin) == "number" then
						local bob = math.sin(now * 2.2 + base.Position.X * 0.2) * 0.35
						item:PivotTo(CFrame.new(base.Position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, math.rad(spin * now), 0) * (base - base.Position))
					end
					local pos = if item:IsA("Model") then item:GetPivot().Position elseif item:IsA("BasePart") then item.Position else nil
					if pos and (pos - root.Position).Magnitude <= 7 then
						self:takePickup(item, p)
					end
				end
			end
		end
	end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		local p = self:participantOf(player)
		if p then
			p.left = true
			self:eliminate(p, "left")
		end
		self.spectators[player] = nil
	end))
end

function MatchController:hookCharacter(p: Participant)
	local character = p.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	table.insert(self.connections, humanoid.Died:Connect(function()
		if not p.alive then
			return
		end
		if not p.stable then
			p.arrived = false
			return
		end
		self:eliminate(p, "died")
	end))
end

function MatchController:placeOnArena(p: Participant): boolean
	if p.arrived then
		return true
	end
	local pad = p.spawnPad
	local character = p.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not pad or not character or not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return false
	end
	if humanoid:GetState() == Enum.HumanoidStateType.Dead then
		return false
	end
	ensureGroups(p.player)
	tagCharacter(p.player, character)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(pad.CFrame + Vector3.new(0, 3, 0))
	local field = Instance.new("ForceField")
	field.Visible = true
	field.Parent = character
	task.delay(Config.PREPARE_TIME, function()
		if field.Parent then
			field:Destroy()
		end
	end)
	p.arrived = true
	p.stable = false
	p.placedAt = os.clock()
	p.floor = "upper"
	p.lives = Config.LIVES
	p.player:SetAttribute("Lives", Config.LIVES)
	self:hookCharacter(p)
	if p.shield then
		self:showShieldRing(p)
	end
	return true
end

function MatchController:teleportIn()
	local spawns = self.arena:WaitForChild("Spawns"):GetChildren()
	table.sort(spawns, function(a, b)
		return (a:GetAttribute("Index") :: number) < (b:GetAttribute("Index") :: number)
	end)
	for index, p in self.participants do
		local pad = spawns[((index - 1) % #spawns) + 1]
		if pad:IsA("BasePart") then
			p.spawnPad = pad
		end
		p.player:SetAttribute("InMatch", self.slot)
		p.player:SetAttribute("Lives", Config.LIVES)
		p.player:SetAttribute("Streak", 0)
		p.player:SetAttribute("Shield", nil)
		self:placeOnArena(p)
		table.insert(self.connections, p.player.CharacterAdded:Connect(function()
			if self.state ~= "running" and self.state ~= "results" then
				return
			end
			if not p.alive then
				task.defer(function()
					if p.player.Parent then
						toLobby(p.player)
					end
				end)
				return
			end
			if not p.stable then
				p.arrived = false
				task.defer(function()
					if p.alive then
						self:placeOnArena(p)
					end
				end)
				return
			end
			self:eliminate(p, "died")
			task.defer(function()
				if p.player.Parent then
					toLobby(p.player)
				end
			end)
		end))
	end
end

-- Матч ---------------------------------------------------------------------

function MatchController:start(players: { Player })
	if self.state ~= "idle" then
		return
	end
	self.state = "running"
	self.round = 0
	self.eliminatedCount = 0
	self.participants = {}
	self.spectators = {}
	self.palette = RoundRules.matchPalette(self.rng)
	for _, player in players do
		table.insert(self.participants, {
			player = player,
			alive = true,
			floor = "upper",
			lives = Config.LIVES,
			streak = 0,
			rounds = 0,
			shield = false,
			left = false,
			catchPad = nil,
			shieldPad = nil,
			spawnPad = nil,
			arrived = false,
			stable = false,
			placedAt = 0,
			shieldAt = 0,
			dashUntil = 0,
			lastSafe = nil,
			catchHold = 0,
		})
	end
	if #self.participants == 0 then
		self.state = "idle"
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			self:run()
		end)
		if not ok then
			warn("[Match " .. self.slot .. "] ошибка: " .. tostring(err))
		end
		self:finish()
	end)
end

function MatchController:matchOver(): boolean
	local alive = #self:aliveList()
	if alive == 0 then
		return true
	end
	if alive == 1 and #self.participants > 1 then
		return true
	end
	return self.round >= Config.MAX_ROUNDS
end

local function colorOf(id: string): Color3
	local def = Config.COLOR_BY_ID[id]
	return if def then def.color else Color3.new(1, 1, 1)
end

local function nameOf(id: string): string
	local def = Config.COLOR_BY_ID[id]
	return if def then def.name else id
end

local function packColor(id: string): { number }
	local color = colorOf(id)
	return { color.R, color.G, color.B }
end

local function packShown(ids: { string }): { { number } }
	local packed = {}
	for _, id in ids do
		table.insert(packed, packColor(id))
	end
	return packed
end

function MatchController:paintRound(rule: RoundRules.Rule)
	self.dropGen += 1
	local hidden = self:tiles()
	for _, tile in hidden do
		tile.Transparency = 1
	end
	local plan = { rng = self.rng, assign = rule.assign, fillers = rule.fillers, hubId = rule.hubId }
	for _, floorName in { "Upper", "Lower" } do
		local folder = self.arena:FindFirstChild(floorName)
		if not folder then
			continue
		end
		local tiles = TileLayout.tiles(folder)
		TileLayout.recolor(tiles, plan)
		if rule.mode == "exclude" then
			continue
		end
		local safe = 0
		for _, tile in tiles do
			local id = tile:GetAttribute("ColorId")
			if RoundRules.isSafe(rule, if typeof(id) == "string" then id else nil, false) then
				safe += 1
			end
		end
		local need = math.max(8, math.floor(#tiles * 0.22))
		local id = rule.targets[1]
		local def = id and Config.COLOR_BY_ID[id]
		if def then
			for _, tile in tiles do
				if safe >= need then
					break
				end
				local current = tile:GetAttribute("ColorId")
				if not RoundRules.isSafe(rule, if typeof(current) == "string" then current else nil, false) then
					tile.Color = def.color
					tile:SetAttribute("ColorId", id)
					tile:SetAttribute("Hub", false)
					safe += 1
				end
			end
		end
	end
	RunService.Heartbeat:Wait()
	for _, tile in hidden do
		if tile.Parent then
			local home = tile:GetAttribute("HomeCF")
			if typeof(home) == "CFrame" then
				tile.CFrame = home
			end
			tile.CanCollide = true
			tile.Transparency = 0
			tile:SetAttribute("ShieldHeld", nil)
		end
	end
	self:clearCatchPads()
	self:clearShieldPads()
end

function MatchController:run()
	self:rebuildTiles()
	TileLayout.idle(self:tiles(), self.rng)
	self:teleportIn()
	self:watch()

	self:setBeacons(Color3.fromRGB(255, 255, 255))
	self:setScreen("ПРИГОТОВЬТЕСЬ", "Игроков: " .. #self.participants, Color3.fromRGB(44, 42, 58))
	self:send({ phase = "prepare", timeLeft = Config.PREPARE_TIME, total = #self.participants })
	self:feed("Матч начинается! Игроков: " .. #self.participants, "info")
	task.wait(Config.PREPARE_TIME)

	local lastTarget: string? = nil
	while not self:matchOver() do
		self.round += 1
		self.roundStartAlive = self:aliveList()
		local rule = RoundRules.pick(self.round, self.palette, self.rng, lastTarget)
		lastTarget = rule.targets[1]

		-- Раскраска поля и подсказки.
		self:paintRound(rule)
		local shownId = rule.shown[1]
		if rule.mode == "exclude" then
			self:setScreen("КРОМЕ: " .. nameOf(shownId), "Раунд " .. self.round .. " · встань на ЛЮБОЙ другой цвет", colorOf(shownId))
		elseif rule.mode == "double" then
			self:setScreen(nameOf(rule.shown[1]) .. " или " .. nameOf(rule.shown[2]), "Раунд " .. self.round .. " · два цвета", colorOf(rule.shown[1]))
		else
			self:setScreen(nameOf(shownId), "Раунд " .. self.round .. " · встань на этот цвет!", colorOf(shownId))
		end
		self:setBeacons(colorOf(shownId))
		self:spawnCoins()
		self:spawnBonus()

		local info = self:info()
		self:send({
			phase = "show",
			round = self.round,
			time = rule.time,
			mode = rule.mode,
			shown = rule.shown,
			colors = packShown(rule.shown),
			excluded = rule.excluded,
			alive = info.alive,
			total = info.total,
		})

		-- Ожидание с возможной обманкой.
		if rule.mode == "fake" and rule.fakeTo then
			task.wait(math.max(0.2, rule.time - Config.FAKE_BEFORE_END))
			self:setScreen(nameOf(rule.fakeTo), "СМЕНА ЦВЕТА!", colorOf(rule.fakeTo))
			self:setBeacons(colorOf(rule.fakeTo))
			self:send({ phase = "fake", shown = { rule.fakeTo }, colors = { packColor(rule.fakeTo) }, time = Config.FAKE_BEFORE_END })
			task.wait(Config.FAKE_BEFORE_END)
		else
			task.wait(rule.time)
		end

		-- Щит оставляет островок под ногами и личную площадку, даже если поиск одной плиты промахнулся.
		local protected: { [BasePart]: boolean } = {}
		for _, p in self:aliveList() do
			if not p.shield then
				continue
			end
			local root = p.player.Character and p.player.Character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") then
				continue
			end
			local floorY = self:playerFloorY(p, root.Position.Y)
			if not self:standingIsSafe(root, rule, floorY) then
				self:spendShield(p, root, floorY, protected)
			end
		end

		local before: { [Participant]: string } = {}
		for _, p in self:aliveList() do
			before[p] = p.floor
		end
		self:dropTiles(rule, protected)
		self:send({ phase = "drop", round = self.round })
		task.wait(Config.DROP_TIME)

		-- Кто остался на своём этаже — пережил раунд. Монеты только с подбора.
		for p, floorBefore in before do
			if p.alive and p.floor == floorBefore then
				p.rounds += 1
				p.streak += 1
				p.player:SetAttribute("Streak", p.streak)
			end
		end
	end
end

function MatchController:finish()
	if self.state ~= "running" then
		return
	end
	self.state = "results"

	local winners: { Participant } = self:aliveList()
	if #winners == 0 then
		winners = self.roundStartAlive
	end
	for _, w in winners do
		w.alive = false
		w.place = self.eliminatedCount + 1
	end

	-- Итоговая таблица: победители первые, далее по порядку выбывания.
	local standings = {}
	for _, p in self.participants do
		local eliminatedBefore = (p.place or 1) - 1
		local place = #self.participants - eliminatedBefore
		table.insert(standings, { name = p.player.DisplayName, rounds = p.rounds, place = place, winner = table.find(winners, p) ~= nil })
	end
	table.sort(standings, function(a, b)
		return a.place < b.place
	end)

	local names = {}
	for _, w in winners do
		table.insert(names, w.player.DisplayName)
		if not w.left and w.player.Parent then
			Economy.addWin(w.player)
			Economy.recordRounds(w.player, w.rounds)
			w.player:SetAttribute("Crown", os.time() + Config.ECONOMY.CROWN_SECONDS)
			local character = w.player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local burst = Instance.new("ParticleEmitter")
				burst.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 214, 90)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 130, 200)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 200, 255)),
				})
				burst.Size = NumberSequence.new(0.6)
				burst.Lifetime = NumberRange.new(1.2, 2)
				burst.Speed = NumberRange.new(14, 22)
				burst.SpreadAngle = Vector2.new(180, 180)
				burst.Rate = 0
				burst.Parent = root
				burst:Emit(180)
				task.delay(3, function()
					burst:Destroy()
				end)
			end
		end
	end
	local world = workspace:FindFirstChild("World")
	if world and #names > 0 then
		world:SetAttribute("LastWinner", table.concat(names, ", "))
	end

	local winnerText = if #names == 0 then "НИЧЬЯ" elseif #names == 1 then names[1] else "ПОБЕДИТЕЛИ: " .. #names
	self:setScreen(if #names == 1 then "ПОБЕДИТЕЛЬ: " .. names[1] else winnerText, "Раундов сыграно: " .. self.round, GOLD)
	self:setBeacons(GOLD)
	self:send({ phase = "results", winners = names, standings = standings, timeLeft = Config.RESULTS_TIME, round = self.round })
	self:feed((if #names == 1 then names[1] .. " побеждает!" else "Матч окончен!"), "win")
	for _, p in self.participants do
		if p.player.Parent then
			task.spawn(Economy.save, p.player)
		end
	end
	task.wait(Config.RESULTS_TIME)

	for _, p in self.participants do
		if not p.left and p.player.Parent then
			self:clearPlayerState(p.player)
			toLobby(p.player)
		end
	end
	self:send({ phase = "end" })

	for _, connection in self.connections do
		connection:Disconnect()
	end
	self.connections = {}
	self:clearPickups()
	self.participants = {}
	self.spectators = {}
	self.round = 0
	self:restoreTiles()
	self:idleLook()
	self.state = "idle"
	if self.onFinished then
		self.onFinished(self)
	end
end

return MatchController
