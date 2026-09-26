--!strict
-- Точка входа сервера Color Party.
-- Геометрия лобби и арен запечена в место (LobbyBuilder / ArenaBuilder — только из Command Bar).
-- Здесь запускается игровая логика: экономика, матчмейкинг, матчи, трансляции.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Economy = require(script:WaitForChild("Economy"))
local Matchmaker = require(script:WaitForChild("Matchmaker"))
local ArenaFx = require(script:WaitForChild("ArenaFx"))

Remotes.init()
Economy.init()

local world = workspace:WaitForChild("World", 30)
if not world then
	warn("[ColorParty] World не найден: соберите лобби из Command Bar (LobbyBuilder.build())")
	return
end
local arenas = world:FindFirstChild("Arenas")
if not arenas then
	warn("[ColorParty] Arenas не найдены: выполните ArenaBuilder.build()")
	return
end

ArenaFx.init(arenas :: Folder)

local lobby = world:FindFirstChild("Lobby")
local console = lobby and lobby:FindFirstChild("Console")
Matchmaker.init(arenas :: Folder, console)

-- Трансляция: игрок в лобби смотрит случайную активную арену.
local spectate = Remotes.get("Spectate")
local function sendSpectate(player: Player)
	local controller = Matchmaker.randomActiveSlot()
	if controller then
		spectate:FireClient(player, controller.slot, controller.center, controller:isActive())
	end
end
spectate.OnServerEvent:Connect(function(player)
	if player:GetAttribute("InMatch") == nil then
		sendSpectate(player)
	end
end)
if console then
	local watchPrompt = console:FindFirstChild("WatchPrompt", true)
	if watchPrompt and watchPrompt:IsA("ProximityPrompt") then
		watchPrompt.Triggered:Connect(sendSpectate)
	end
end

-- Реакции зрителей: короткий текст всем в радиусе слышимости чата матча.
local reaction = Remotes.get("Reaction")
local lastReaction: { [Player]: number } = {}
reaction.OnServerEvent:Connect(function(player, text)
	if typeof(text) ~= "string" or #text > 6 then
		return
	end
	local now = os.clock()
	if lastReaction[player] and now - lastReaction[player] < 1.5 then
		return
	end
	lastReaction[player] = now
	reaction:FireAllClients(player.DisplayName, text)
end)
Players.PlayerRemoving:Connect(function(player)
	lastReaction[player] = nil
end)

-- Корона победителя: сияние над головой пока действует Crown.
local function crownLoop(player: Player)
	player:GetAttributeChangedSignal("Crown"):Connect(function()
		local until_ = player:GetAttribute("Crown")
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if typeof(until_) ~= "number" or not head then
			return
		end
		local old = head:FindFirstChild("CrownGlow")
		if old then
			old:Destroy()
		end
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "CrownGlow"
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 214, 90))
		emitter.LightEmission = 0.8
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
		emitter.Lifetime = NumberRange.new(0.6, 1.1)
		emitter.Rate = 10
		emitter.Speed = NumberRange.new(1, 2)
		emitter.SpreadAngle = Vector2.new(60, 60)
		emitter.Parent = head
		task.delay(math.max(0, until_ - os.time()), function()
			emitter:Destroy()
		end)
	end)
end
Players.PlayerAdded:Connect(crownLoop)
for _, player in Players:GetPlayers() do
	crownLoop(player)
end

print("[ColorParty] сервер запущен: арен " .. #arenas:GetChildren())
