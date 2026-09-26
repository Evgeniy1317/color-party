--!strict
-- Контроллер одного матча на одной арене: телепорт, раунды, падения,
-- две жизни, обманки, сжатие арены, монеты, бонусы, итоги.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local TileLayout = require(script.Parent:WaitForChild("TileLayout"))
local RoundRules = require(script.Parent:WaitForChild("RoundRules"))
local Economy = require(script.Parent:WaitForChild("Economy"))

local A = Config.ARENA
local IDLE_GLOW = Color3.fromRGB(196, 186, 255)
local GOLD = Color3.fromRGB(255, 206, 84)

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

local function readable(on: Color3): Color3
	local _, _, v = on:ToHSV()
	local luminance = 0.2126 * on.R + 0.7152 * on.G + 0.0722 * on.B
	return if luminance > 0.62 or v > 0.9 and luminance > 0.5 then Color3.fromRGB(40, 38, 54) else Color3.fromRGB(255, 255, 255)
end

function MatchController:setScreen(main: string, sub: string, fill: Color3)
	local screen = self.arena:FindFirstChild("Screen")
	if not screen then
		return
	end
	local textColor = readable(fill)
	for _, gui in screen:GetChildren() do
		if gui:IsA("SurfaceGui") then
			local frame = gui:FindFirstChild("Fill")
			if frame and frame:IsA("Frame") then
				TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundColor3 = fill }):Play()
				for _, name in { "Title", "Main", "Sub" } do
					local label = frame:FindFirstChild(name)
					if label and label:IsA("TextLabel") then
						label.TextColor3 = textColor
						if name == "Main" then
							label.Text = main
						elseif name == "Sub" then
							label.Text = sub
						end
					end
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

-- Плиты: падение и восстановление -----------------------------------------

-- Верхний этаж: падают все «неправильные» плиты. Нижний этаж: только плиты
-- под игроками, которые стоят не там — иначе упавшие сверху пролетели бы сквозь
-- нижний этаж и потеряли бы вторую жизнь.
function MatchController:dropTiles(rule: RoundRules.Rule, protected: { [BasePart]: boolean }, lowerDrop: { [BasePart]: boolean })
	local function fall(tile: BasePart)
		tile.CanCollide = false
		TweenService:Create(tile, TweenInfo.new(0.3), { Transparency = 0.8 }):Play()
	end
	for _, tile in TileLayout.tiles(self.arena:WaitForChild("Upper")) do
		local safe = RoundRules.isSafe(rule, tile:GetAttribute("ColorId") :: string, tile:GetAttribute("Hub") == true)
		if not safe and not protected[tile] then
			fall(tile)
		end
	end
	for tile in lowerDrop do
		if not protected[tile] then
			fall(tile)
		end
	end
end

function MatchController:restoreTiles()
	for _, tile in self:tiles() do
		tile.CanCollide = true
		TweenService:Create(tile, TweenInfo.new(0.3), { Transparency = 0 }):Play()
	end
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
			if tile:GetAttribute("Hub") then
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

local function sparkle(target: BasePart, color: Color3)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Rate = 14
	emitter.Speed = NumberRange.new(1, 2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = target
end

function MatchController:randomUpperTiles(count: number): { BasePart }
	local list = {}
	for _, tile in TileLayout.tiles(self.arena:WaitForChild("Upper")) do
		if not tile:GetAttribute("Hub") then
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

function MatchController:spawnCoins()
	local folder = self:pickupFolder()
	local count = self.rng:NextInteger(Config.COINS_ON_FIELD[1], Config.COINS_ON_FIELD[2])
	for _, tile in self:randomUpperTiles(count) do
		local coin = Instance.new("Part")
		coin.Name = "Coin"
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.5, 2.6, 2.6)
		coin.Color = GOLD
		coin.Material = Enum.Material.SmoothPlastic
		coin.Anchored = true
		coin.CanCollide = false
		coin.CFrame = CFrame.new(tile.Position + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, self.rng:NextNumber() * math.pi, 0)
		coin:SetAttribute("Spin", 140)
		sparkle(coin, GOLD)
		coin.Parent = folder
		local taken = false
		coin.Touched:Connect(function(hit)
			if taken then
				return
			end
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			local p = player and self:participantOf(player)
			if p and p.alive then
				taken = true
				Economy.addCoins(player :: Player, Config.COIN_VALUE, "coin")
				coin:Destroy()
			end
		end)
	end
end

function MatchController:spawnBonus()
	if self.round < Config.BONUS_FROM_ROUND or self.rng:NextNumber() > Config.BONUS_CHANCE then
		return
	end
	local tiles = self:randomUpperTiles(1)
	if #tiles == 0 then
		return
	end
	local kind = if self.rng:NextNumber() < 0.5 then "Shield" else "Dash"
	local color = if kind == "Shield" then Color3.fromRGB(112, 176, 255) else Color3.fromRGB(255, 150, 60)
	local orb = Instance.new("Part")
	orb.Name = kind
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(2.6, 2.6, 2.6)
	orb.Color = color
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	orb.CFrame = CFrame.new(tiles[1].Position + Vector3.new(0, 3, 0))
	orb:SetAttribute("Bob", 2.2)
	sparkle(orb, color)
	orb.Parent = self:pickupFolder()
	self:feed(if kind == "Shield" then "На поле появился ЩИТ!" else "На поле появился РЫВОК!", "bonus")
	local taken = false
	orb.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local p = player and self:participantOf(player)
		if not p or not p.alive then
			return
		end
		taken = true
		orb:Destroy()
		if kind == "Shield" then
			p.shield = true
			p.player:SetAttribute("Shield", true)
			self:feed(p.player.DisplayName .. " взял щит", "bonus")
		else
			local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = 27
				task.delay(3.5, function()
					if humanoid.Parent then
						humanoid.WalkSpeed = 16
					end
				end)
			end
			self:feed(p.player.DisplayName .. " ускорился", "bonus")
		end
	end)
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

local function toLobby(player: Player)
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

function MatchController:watch()
	-- Следим за высотой: верхний этаж → нижний = минус жизнь; ниже нижнего = выбыл.
	table.insert(self.connections, RunService.Heartbeat:Connect(function()
		for _, p in self.participants do
			if not p.alive then
				continue
			end
			local character = p.player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") then
				continue
			end
			local y = root.Position.Y
			if p.floor == "upper" and y < self.upperY - 14 then
				p.floor = "lower"
				p.lives = 1
				p.streak = 0
				p.player:SetAttribute("Lives", 1)
				p.player:SetAttribute("Streak", 0)
				self:feed(p.player.DisplayName .. " упал на нижний этаж!", "fall")
			end
			if y < self.lowerY - A.FALL_LIMIT then
				self:eliminate(p, "fell")
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
	if humanoid then
		table.insert(self.connections, humanoid.Died:Connect(function()
			self:eliminate(p, "died")
		end))
	end
end

function MatchController:teleportIn()
	local spawns = self.arena:WaitForChild("Spawns"):GetChildren()
	table.sort(spawns, function(a, b)
		return (a:GetAttribute("Index") :: number) < (b:GetAttribute("Index") :: number)
	end)
	for index, p in self.participants do
		local pad = spawns[((index - 1) % #spawns) + 1]
		local character = p.player.Character
		if character and pad:IsA("BasePart") then
			character:PivotTo(pad.CFrame + Vector3.new(0, 2.5, 0))
			local field = Instance.new("ForceField")
			field.Visible = true
			field.Parent = character
			task.delay(Config.PREPARE_TIME, function()
				field:Destroy()
			end)
		end
		p.player:SetAttribute("InMatch", self.slot)
		p.player:SetAttribute("Lives", Config.LIVES)
		p.player:SetAttribute("Streak", 0)
		p.player:SetAttribute("Shield", nil)
		self:hookCharacter(p)
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
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			table.insert(self.participants, {
				player = player,
				alive = true,
				floor = "upper",
				lives = Config.LIVES,
				streak = 0,
				rounds = 0,
				shield = false,
				left = false,
			})
		end
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
		TileLayout.recolor(self:tiles(), { rng = self.rng, assign = rule.assign, fillers = rule.fillers, hubId = rule.hubId })
		self:restoreTiles()
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
			excluded = rule.excluded,
			alive = info.alive,
			total = info.total,
		})

		-- Ожидание с возможной обманкой.
		if rule.mode == "fake" and rule.fakeTo then
			task.wait(math.max(0.2, rule.time - Config.FAKE_BEFORE_END))
			self:setScreen(nameOf(rule.fakeTo), "СМЕНА ЦВЕТА!", colorOf(rule.fakeTo))
			self:setBeacons(colorOf(rule.fakeTo))
			self:send({ phase = "fake", shown = { rule.fakeTo }, time = Config.FAKE_BEFORE_END })
			task.wait(Config.FAKE_BEFORE_END)
		else
			task.wait(rule.time)
		end

		-- Дедлайн: смотрим, на чём стоит каждый. Щит защищает плиту под игроком;
		-- на нижнем этаже падают только плиты под теми, кто стоит не там.
		local protected: { [BasePart]: boolean } = {}
		local lowerDrop: { [BasePart]: boolean } = {}
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { self.arena:WaitForChild("Upper"), self.arena:WaitForChild("Lower") }
		for _, p in self:aliveList() do
			local root = p.player.Character and p.player.Character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") then
				continue
			end
			local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
			if not hit or not hit.Instance then
				continue
			end
			local tile = hit.Instance :: BasePart
			local safe = RoundRules.isSafe(rule, tile:GetAttribute("ColorId") :: string, tile:GetAttribute("Hub") == true)
			if safe then
				continue
			end
			if p.shield then
				protected[tile] = true
				p.shield = false
				p.player:SetAttribute("Shield", nil)
				self:feed("Щит спас " .. p.player.DisplayName .. "!", "bonus")
			elseif p.floor == "lower" then
				lowerDrop[tile] = true
			end
		end

		local before: { [Participant]: string } = {}
		for _, p in self:aliveList() do
			before[p] = p.floor
		end
		self:clearPickups()
		self:dropTiles(rule, protected, lowerDrop)
		self:send({ phase = "drop", round = self.round })
		task.wait(Config.DROP_TIME)

		-- Кто остался на своём этаже — пережил раунд: монеты и серия.
		for p, floorBefore in before do
			if p.alive and p.floor == floorBefore then
				p.rounds += 1
				p.streak += 1
				p.player:SetAttribute("Streak", p.streak)
				Economy.addCoins(p.player, Config.ECONOMY.ROUND_SURVIVED * Economy.streakMultiplier(p.streak - 1), "round")
			end
		end

		self:restoreTiles()
		self:shrink(RoundRules.shrinkCount(self.round, self.rng))
		task.wait(0.5)
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
		if not p.left and p.player.Parent then
			Economy.addCoins(p.player, Config.ECONOMY.PER_ELIMINATED_BEFORE * eliminatedBefore, "outlast")
			if place <= 3 then
				Economy.addCoins(p.player, Config.ECONOMY.TOP3, "top3")
			end
		end
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
	self:idleLook()
	self.state = "idle"
	if self.onFinished then
		self.onFinished(self)
	end
end

return MatchController
