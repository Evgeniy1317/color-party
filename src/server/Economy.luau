--!strict
-- Монеты, победы, серии и сохранение прогресса.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local STORE_NAME = "ColorParty_v1"

type Profile = { coins: number, wins: number, rounds: number, best: number }

local Economy = {}
local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)

local function defaultProfile(): Profile
	return { coins = 0, wins = 0, rounds = 0, best = 0 }
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
		end
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
	local payload = {
		coins = profile.coins,
		wins = profile.wins,
		rounds = profile.rounds,
		best = profile.best,
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
	profile.coins = math.max(0, profile.coins + gain)
	push(player, gain, reason)
	queueSave(player)
end

function Economy.addWin(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.wins += 1
	push(player, 0, "win")
	queueSave(player)
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

return Economy
