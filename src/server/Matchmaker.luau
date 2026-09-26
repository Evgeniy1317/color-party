--!strict
-- Очередь готовых игроков и раздача по свободным аренам.
-- Слот 0 (виден из окна лобби) заполняется первым.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local MatchController = require(script.Parent:WaitForChild("MatchController"))

local Matchmaker = {}

local controllers: { MatchController.MatchController } = {}
local queue: { Player } = {}
local autoReady: { [Player]: boolean } = {}
local timerEnd: number? = nil
local consoleLabels: { [string]: TextLabel } = {}

local function inQueue(player: Player): number?
	return table.find(queue, player)
end

local function activeSlots(): { number }
	local list = {}
	for _, controller in controllers do
		if controller:isActive() then
			table.insert(list, controller.slot)
		end
	end
	return list
end

local function freeController(): MatchController.MatchController?
	for _, controller in controllers do
		if controller:isFree() then
			return controller
		end
	end
	return nil
end

local function waitTime(): number
	return if #Players:GetPlayers() > Config.BUSY_SERVER_PLAYERS then Config.QUEUE_WAIT_BUSY else Config.QUEUE_WAIT
end

local function broadcast()
	local timeLeft = if timerEnd then math.max(0, timerEnd - os.clock()) else nil
	local active = activeSlots()
	local waitingArena = #queue >= Config.MIN_PLAYERS and freeController() == nil
	Remotes.get("QueueUpdate"):FireAllClients({
		count = #queue,
		max = Config.MAX_PLAYERS_PER_MATCH,
		timeLeft = timeLeft,
		waitingArena = waitingArena,
		active = active,
		arenas = #controllers,
		queued = queue,
	})
	if consoleLabels.Queue then
		consoleLabels.Queue.Text = "В очереди: " .. #queue .. " / " .. Config.MAX_PLAYERS_PER_MATCH
	end
	if consoleLabels.Status then
		local text
		if waitingArena then
			text = "Все арены заняты — ждём свободную"
		elseif #active > 0 then
			text = "Идёт матчей: " .. #active .. " из " .. #controllers
		else
			text = "Арены свободны"
		end
		if timeLeft and #queue > 0 then
			text ..= "  ·  старт через " .. math.ceil(timeLeft) .. " с"
		end
		consoleLabels.Status.Text = text
	end
end

local function dispatch(count: number)
	local controller = freeController()
	if not controller then
		return
	end
	local players = {}
	for i = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent and player.Character then
			table.insert(players, player)
		end
	end
	if #players == 0 then
		return
	end
	for _, player in players do
		player:SetAttribute("Ready", nil)
	end
	timerEnd = nil
	controller:start(players)
	broadcast()
end

function Matchmaker.setReady(player: Player, ready: boolean, auto: boolean?)
	if auto ~= nil then
		autoReady[player] = auto
	end
	if player:GetAttribute("InMatch") ~= nil then
		return
	end
	local index = inQueue(player)
	if ready and not index then
		table.insert(queue, player)
		player:SetAttribute("Ready", true)
	elseif not ready and index then
		table.remove(queue, index)
		player:SetAttribute("Ready", nil)
		if not auto then
			autoReady[player] = false
		end
	end
	broadcast()
end

function Matchmaker.toggle(player: Player)
	Matchmaker.setReady(player, inQueue(player) == nil)
end

local function tick()
	if #queue >= Config.MAX_PLAYERS_PER_MATCH and freeController() then
		dispatch(Config.MAX_PLAYERS_PER_MATCH)
	elseif #queue >= Config.MIN_PLAYERS then
		if not timerEnd then
			timerEnd = os.clock() + waitTime()
		elseif os.clock() >= timerEnd then
			if freeController() then
				dispatch(Config.MAX_PLAYERS_PER_MATCH)
			else
				timerEnd = os.clock() + 5 -- арены заняты, проверим позже
			end
		end
	else
		timerEnd = nil
	end
	broadcast()
end

local function onMatchFinished(_controller: MatchController.MatchController)
	-- Авто-готовые игроки сразу возвращаются в очередь.
	for player, enabled in autoReady do
		if enabled and player.Parent and player:GetAttribute("InMatch") == nil and not inQueue(player) then
			table.insert(queue, player)
			player:SetAttribute("Ready", true)
		end
	end
	broadcast()
end

function Matchmaker.randomActiveSlot(): MatchController.MatchController?
	local active = {}
	for _, controller in controllers do
		if controller:isActive() then
			table.insert(active, controller)
		end
	end
	if #active == 0 then
		return controllers[1]
	end
	return active[math.random(1, #active)]
end

function Matchmaker.controller(slot: number): MatchController.MatchController?
	for _, controller in controllers do
		if controller.slot == slot then
			return controller
		end
	end
	return nil
end

function Matchmaker.init(arenasFolder: Folder, console: Instance?)
	for _, arena in arenasFolder:GetChildren() do
		if arena:IsA("Folder") and typeof(arena:GetAttribute("Slot")) == "number" then
			table.insert(controllers, MatchController.new(arena, onMatchFinished))
		end
	end
	table.sort(controllers, function(a, b)
		return a.slot < b.slot
	end)
	for _, controller in controllers do
		controller:idleLook()
	end

	if console then
		local screen = console:FindFirstChild("Screen")
		local gui = screen and screen:FindFirstChildOfClass("SurfaceGui")
		if gui then
			for _, label in gui:GetDescendants() do
				if label:IsA("TextLabel") then
					consoleLabels[label.Name] = label
				end
			end
		end
		local readyPrompt = console:FindFirstChild("ReadyPrompt", true)
		if readyPrompt and readyPrompt:IsA("ProximityPrompt") then
			readyPrompt.Triggered:Connect(Matchmaker.toggle)
		end
	end

	Remotes.get("SetReady").OnServerEvent:Connect(function(player, ready, auto)
		Matchmaker.setReady(player, ready == true, if typeof(auto) == "boolean" then auto else nil)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local index = inQueue(player)
		if index then
			table.remove(queue, index)
		end
		autoReady[player] = nil
		broadcast()
	end)

	task.spawn(function()
		while true do
			tick()
			task.wait(0.5)
		end
	end)
end

return Matchmaker
