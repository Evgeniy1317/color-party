--!strict
-- Монеты, победы, серии и сохранение прогресса.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Shop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Shop"))

local STORE_NAME = "ColorParty_v1"

type Profile = {
	coins: number,
	wins: number,
	rounds: number,
	best: number,
	owned: { [string]: boolean },
	equipped: string,
	trail: string,
	receipts: { [string]: boolean },
	charges: { [string]: number },
	discount: number,
	spinDay: number,
	armed: string,
	live: { [string]: boolean },
	questDay: number,
	daily: { { id: string, taken: boolean, progress: number, claimed: boolean } },
	bpOwned: boolean,
	bp: { [string]: { progress: number, claimed: boolean } },
}

local Economy = {}
local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)

local function defaultProfile(): Profile
	return {
		coins = 0,
		wins = 0,
		rounds = 0,
		best = 0,
		owned = {},
		equipped = "",
		trail = "",
		receipts = {},
		charges = {},
		discount = 0,
		spinDay = 0,
		armed = "",
		live = {},
		questDay = 0,
		daily = {},
		bpOwned = false,
		bp = {},
	}
end

local function push(player: Player, delta: number, reason: string)
	local profile = profiles[player]
	if not profile then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local coins = stats:FindFirstChild("Монеты")
		if coins and coins:IsA("IntValue") then
			coins.Value = profile.coins
		end
		local wins = stats:FindFirstChild("Победы")
		if wins and wins:IsA("IntValue") then
			wins.Value = profile.wins
		end
	end
	Remotes.get("Economy"):FireClient(player, { coins = profile.coins, delta = delta, reason = reason })
end

local function load(player: Player)
	local profile = defaultProfile()
	if store then
		local ok, data = pcall(function()
			return (store :: DataStore):GetAsync("p_" .. player.UserId)
		end)
		if ok and typeof(data) == "table" then
			profile.coins = tonumber(data.coins) or 0
			profile.wins = tonumber(data.wins) or 0
			profile.rounds = tonumber(data.rounds) or 0
			profile.best = tonumber(data.best) or 0
			if typeof(data.equipped) == "string" then
				profile.equipped = data.equipped
			end
			if typeof(data.trail) == "string" then
				profile.trail = data.trail
			end
			if typeof(data.owned) == "table" then
				for _, id in data.owned do
					if typeof(id) == "string" then
						profile.owned[id] = true
					end
				end
			end
			if typeof(data.receipts) == "table" then
				for _, purchaseId in data.receipts do
					if typeof(purchaseId) == "string" then
						profile.receipts[purchaseId] = true
					end
				end
			end
			if typeof(data.charges) == "table" then
				for id, count in data.charges do
					if typeof(id) == "string" and typeof(count) == "number" and count > 0 then
						profile.charges[id] = math.floor(count)
					end
				end
			end
			profile.discount = math.clamp(tonumber(data.discount) or 0, 0, 90)
			profile.spinDay = math.floor(tonumber(data.spinDay) or 0)
			if typeof(data.armed) == "string" then
				profile.armed = data.armed
			end
			profile.questDay = math.floor(tonumber(data.questDay) or 0)
			profile.bpOwned = data.bpOwned == true
			if typeof(data.daily) == "table" then
				for _, item in data.daily do
					if typeof(item) == "table" and typeof(item.id) == "string" then
						table.insert(profile.daily, {
							id = item.id,
							taken = item.taken == true,
							progress = math.max(0, math.floor(tonumber(item.progress) or 0)),
							claimed = item.claimed == true,
						})
					end
				end
			end
			if typeof(data.bp) == "table" then
				for id, item in data.bp do
					if typeof(id) == "string" and typeof(item) == "table" then
						profile.bp[id] = {
							progress = math.max(0, math.floor(tonumber(item.progress) or 0)),
							claimed = item.claimed == true,
						}
					end
				end
			end
		end
	end
	-- Тестовый запас для владельца и для игры из Studio, чтобы можно было открыть дорогой магазин.
	if (RunService:IsStudio() or player.UserId == 11660290381) and profile.coins < 1000000 then
		profile.coins = 1000000
	end
	profiles[player] = profile

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Монеты"
	coins.Value = profile.coins
	coins.Parent = stats
	local wins = Instance.new("IntValue")
	wins.Name = "Победы"
	wins.Value = profile.wins
	wins.Parent = stats
	stats.Parent = player
	player:SetAttribute("Streak", 0)
	push(player, 0, "load")
end

local saveQueued: { [Player]: boolean } = {}

local function save(player: Player)
	local profile = profiles[player]
	if not profile or not store then
		return
	end
	local owned = {}
	for id in profile.owned do
		table.insert(owned, id)
	end
	local receipts = {}
	for purchaseId in profile.receipts do
		table.insert(receipts, purchaseId)
	end
	local payload = {
		coins = profile.coins,
		wins = profile.wins,
		rounds = profile.rounds,
		best = profile.best,
		equipped = profile.equipped,
		trail = profile.trail,
		owned = owned,
		receipts = receipts,
		charges = profile.charges,
		discount = profile.discount,
		spinDay = profile.spinDay,
		armed = profile.armed,
		questDay = profile.questDay,
		daily = profile.daily,
		bpOwned = profile.bpOwned,
		bp = profile.bp,
	}
	local key = "p_" .. player.UserId
	for _ = 1, 3 do
		local ok = pcall(function()
			(store :: DataStore):UpdateAsync(key, function()
				return payload
			end)
		end)
		if ok then
			return
		end
		task.wait(1)
	end
	warn("[ColorParty] не удалось сохранить монеты игрока " .. player.UserId)
end

local function queueSave(player: Player)
	if saveQueued[player] then
		return
	end
	saveQueued[player] = true
	task.delay(2, function()
		saveQueued[player] = nil
		if player.Parent then
			save(player)
		end
	end)
end

function Economy.save(player: Player)
	saveQueued[player] = nil
	save(player)
end

function Economy.init()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		saveQueued[player] = nil
		save(player)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		local left = 0
		for _, player in Players:GetPlayers() do
			left += 1
			task.spawn(function()
				save(player)
				left -= 1
			end)
		end
		local started = os.clock()
		while left > 0 and os.clock() - started < 8 do
			task.wait(0.1)
		end
	end)
end

function Economy.addCoins(player: Player, amount: number, reason: string)
	local profile = profiles[player]
	if not profile or amount == 0 then
		return
	end
	local gain = math.round(amount)
	if reason == "coin" and gain > 0 and player:GetAttribute("PerkCoins") == true then
		gain *= 2
	end
	profile.coins = math.max(0, profile.coins + gain)
	push(player, gain, reason)
	queueSave(player)
end

function Economy.wins(player: Player): number
	local profile = profiles[player]
	return if profile then profile.wins else 0
end

function Economy.addWin(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.wins += 1
	push(player, 0, "win")
	queueSave(player)
	task.defer(function()
		local module = script.Parent:FindFirstChild("Leaderboard")
		if module and module:IsA("ModuleScript") then
			require(module).changed(player)
		end
		local quests = script.Parent:FindFirstChild("Quests")
		if quests and quests:IsA("ModuleScript") then
			require(quests).progress(player, "wins", 1)
		end
	end)
end

function Economy.recordRounds(player: Player, rounds: number)
	local profile = profiles[player]
	if profile then
		profile.rounds += rounds
		profile.best = math.max(profile.best, rounds)
	end
end

function Economy.streakMultiplier(streak: number): number
	return 1 + streak * Config.ECONOMY.STREAK_STEP
end

function Economy.coins(player: Player): number
	local profile = profiles[player]
	return if profile then profile.coins else 0
end

function Economy.ownsSkin(player: Player, id: string): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.owned[id] == true
end

function Economy.equippedSkin(player: Player): string
	local profile = profiles[player]
	return if profile then profile.equipped else ""
end

function Economy.ownedSkins(player: Player): { string }
	local list = {}
	local profile = profiles[player]
	if profile then
		for id in profile.owned do
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

function Economy.grantSkin(player: Player, id: string)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.owned[id] = true
	queueSave(player)
end

function Economy.equipSkin(player: Player, id: string)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.equipped = id
	queueSave(player)
end

function Economy.equippedTrail(player: Player): string
	local profile = profiles[player]
	return if profile then profile.trail else ""
end

function Economy.equipTrail(player: Player, id: string)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.trail = id
	queueSave(player)
end

function Economy.seenReceipt(player: Player, purchaseId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.receipts[purchaseId] == true
end

function Economy.rememberReceipt(player: Player, purchaseId: string)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.receipts[purchaseId] = true
	local count = 0
	for _ in profile.receipts do
		count += 1
	end
	if count > 40 then
		for old in profile.receipts do
			if old ~= purchaseId then
				profile.receipts[old] = nil
				break
			end
		end
	end
	queueSave(player)
end

local function today(): number
	return math.floor(os.time() / 86400)
end

function Economy.charges(player: Player): { [string]: number }
	local profile = profiles[player]
	local copy = {}
	if profile then
		for id, count in profile.charges do
			copy[id] = count
		end
	end
	return copy
end

function Economy.chargeCount(player: Player, id: string): number
	local profile = profiles[player]
	return if profile then profile.charges[id] or 0 else 0
end

function Economy.addCharge(player: Player, id: string, amount: number)
	local profile = profiles[player]
	if not profile or amount == 0 then
		return
	end
	local nextCount = (profile.charges[id] or 0) + math.floor(amount)
	if nextCount <= 0 then
		profile.charges[id] = nil
	else
		profile.charges[id] = nextCount
	end
	queueSave(player)
end

function Economy.discount(player: Player): number
	local profile = profiles[player]
	return if profile then profile.discount else 0
end

function Economy.setDiscount(player: Player, percent: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.discount = math.clamp(math.floor(percent), 0, 90)
	queueSave(player)
end

function Economy.takeDiscount(player: Player, price: number): number
	local profile = profiles[player]
	if not profile or price <= 0 or profile.discount <= 0 then
		return price
	end
	return math.max(1, math.floor(price * (100 - profile.discount) / 100))
end

function Economy.spendDiscount(player: Player)
	local profile = profiles[player]
	if profile and profile.discount > 0 then
		profile.discount = 0
		queueSave(player)
	end
end

function Economy.freeSpin(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.spinDay ~= today()
end

function Economy.useFreeSpin(player: Player): boolean
	local profile = profiles[player]
	if not profile or profile.spinDay == today() then
		return false
	end
	profile.spinDay = today()
	queueSave(player)
	return true
end

function Economy.armed(player: Player): string
	local profile = profiles[player]
	return if profile then profile.armed else ""
end

function Economy.armPerk(player: Player, id: string)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.armed = id
	queueSave(player)
end

function Economy.refreshPerks(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	for _, item in Shop.perks() do
		local attr = Shop.perkAttribute(item.id)
		if attr then
			local on = profile.owned[item.id] == true or profile.live[item.id] == true
			player:SetAttribute(attr, on)
		end
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if player:GetAttribute("PerkSpeed") == true then 22 else 16
	end
end

function Economy.activateMatch(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.live = {}
	for _, item in Shop.perks() do
		local id = item.id
		if profile.owned[id] then
			continue
		elseif profile.armed == id then
			profile.live[id] = true
		elseif (profile.charges[id] or 0) > 0 then
			profile.charges[id] -= 1
			if profile.charges[id] <= 0 then
				profile.charges[id] = nil
			end
			profile.live[id] = true
		end
	end
	profile.armed = ""
	Economy.refreshPerks(player)
	queueSave(player)
end

function Economy.settleMatch(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	if next(profile.live) == nil then
		Economy.refreshPerks(player)
		return
	end
	profile.live = {}
	Economy.refreshPerks(player)
end

function Economy.questBoard(player: Player): (number?, { { id: string, taken: boolean, progress: number, claimed: boolean } }?, boolean?, { [string]: { progress: number, claimed: boolean } }?)
	local profile = profiles[player]
	if not profile then
		return nil, nil, nil, nil
	end
	return profile.questDay, profile.daily, profile.bpOwned, profile.bp
end

function Economy.setQuestBoard(player: Player, day: number, daily: { { id: string, taken: boolean, progress: number, claimed: boolean } })
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.questDay = day
	profile.daily = daily
	queueSave(player)
end

function Economy.setBattlePass(player: Player, owned: boolean)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.bpOwned = owned
	queueSave(player)
end

function Economy.saveQuests(player: Player)
	queueSave(player)
end

function Economy.pushShop(player: Player, notice: string?)
	local profile = profiles[player]
	Remotes.get("SkinState"):FireClient(player, {
		coins = Economy.coins(player),
		owned = Economy.ownedSkins(player),
		equipped = Economy.equippedSkin(player),
		trail = Economy.equippedTrail(player),
		charges = Economy.charges(player),
		discount = if profile then profile.discount else 0,
		armed = if profile then profile.armed else "",
		notice = notice,
	})
end

return Economy
