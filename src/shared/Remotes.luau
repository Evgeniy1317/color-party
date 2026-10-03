--!strict
-- Единая точка получения RemoteEvent'ов. Сервер создаёт, клиент ждёт.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"SetReady", -- клиент → сервер: (ready: boolean, auto: boolean)
	"QueueUpdate", -- сервер → все: { count, timeLeft, waitingArena, active = {slot...} }
	"Party", -- клиент → сервер: invite | accept | decline | leave | kick | robloxInvite | locate | joinFriend
	"PartyState", -- сервер → клиент: { members, invite, notice, elsewhere }
	"MatchState", -- сервер → участники/зрители: { phase, slot, ... }
	"RoundEvent", -- сервер → участники/зрители: (text: string, kind: string)
	"Spectate", -- клиент → сервер: "start" | "next" | "prev" | "stop"; сервер → клиент: { ok, slot, center, index, total, message? }
	"Economy", -- сервер → клиент: { coins, delta, reason }
	"Reaction", -- клиент → сервер → всем: (emoji: string)
}

local Remotes = {}

local function folder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing then
			return existing :: Folder
		end
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.get(name: string): RemoteEvent
	local root = folder()
	if RunService:IsServer() then
		local existing = root:FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = root
		return remote
	end
	return root:WaitForChild(name) :: RemoteEvent
end

function Remotes.init()
	for _, name in NAMES do
		Remotes.get(name)
	end
end

return Remotes
