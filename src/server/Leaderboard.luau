--!strict
-- Топ побед. Глобальный OrderedDataStore плюс игроки этого сервера,
-- чтобы таблица у кубка не была пустой, пока облако ещё не ответило.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(script.Parent:WaitForChild("Economy"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Leaderboard = {}

local store: OrderedDataStore? = nil
pcall(function()
	store = DataStoreService:GetOrderedDataStore("ColorParty_Wins_v1")
end)

local names: { [number]: string } = {}
local published: { [number]: number } = {}
local refreshing = false
local again = false

local function username(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		local shown = if online.DisplayName ~= "" then online.DisplayName else online.Name
		names[userId] = shown
		return shown
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local shown = if ok and typeof(result) == "string" then result else "Игрок"
	names[userId] = shown
	return shown
end

local function collect(): { { userId: number, wins: number } }
	local byId: { [number]: number } = {}
	if store then
		local ok, pages = pcall(function()
			return (store :: OrderedDataStore):GetSortedAsync(false, 100)
		end)
		if ok and pages then
			for _, item in pages:GetCurrentPage() do
				local userId = tonumber(item.key)
				local wins = tonumber(item.value)
				if userId and wins then
					byId[userId] = math.max(byId[userId] or 0, math.floor(wins))
				end
			end
		end
	end
	for _, player in Players:GetPlayers() do
		local wins = Economy.wins(player)
		byId[player.UserId] = math.max(byId[player.UserId] or 0, wins)
	end
	local list = {}
	for userId, wins in byId do
		table.insert(list, { userId = userId, wins = wins })
	end
	table.sort(list, function(a, b)
		if a.wins ~= b.wins then
			return a.wins > b.wins
		end
		return a.userId < b.userId
	end)
	return list
end

local function broadcast()
	if refreshing then
		again = true
		return
	end
	refreshing = true
	local list = collect()
	local top = {}
	for index = 1, math.min(10, #list) do
		local entry = list[index]
		table.insert(top, {
			place = index,
			userId = entry.userId,
			name = username(entry.userId),
			wins = entry.wins,
		})
	end
	for _, player in Players:GetPlayers() do
		local place = 0
		local wins = Economy.wins(player)
		for index, entry in list do
			if entry.userId == player.UserId then
				place = index
				wins = entry.wins
				break
			end
		end
		local shown = if player.DisplayName ~= "" then player.DisplayName else player.Name
		Remotes.get("Leaderboard"):FireClient(player, {
			top = top,
			me = {
				place = place,
				userId = player.UserId,
				name = shown,
				wins = wins,
			},
		})
	end
	refreshing = false
	if again then
		again = false
		broadcast()
	end
end

local function publish(player: Player)
	if not store then
		return
	end
	local wins = Economy.wins(player)
	if published[player.UserId] == wins then
		return
	end
	published[player.UserId] = wins
	pcall(function()
		(store :: OrderedDataStore):SetAsync(tostring(player.UserId), wins)
	end)
end

function Leaderboard.changed(player: Player)
	task.spawn(function()
		publish(player)
		broadcast()
	end)
end

function Leaderboard.init()
	local function touch(player: Player)
		task.delay(3, function()
			if player.Parent then
				publish(player)
				broadcast()
			end
		end)
	end
	Players.PlayerAdded:Connect(touch)
	for _, player in Players:GetPlayers() do
		touch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		published[player.UserId] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(30)
			broadcast()
		end
	end)
	task.delay(4, broadcast)
end

return Leaderboard
