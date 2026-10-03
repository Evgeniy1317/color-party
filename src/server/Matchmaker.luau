--!strict
-- Очередь готовых игроков и раздача по свободным аренам.
-- Пати (2–5) не стоит в общей очереди: «Готов» сразу сажает её на любую свободную арену.
-- Слот 0 (виден из окна лобби) заполняется первым.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local MatchController = require(script.Parent:WaitForChild("MatchController"))

local Matchmaker = {}

local controllers: { MatchController.MatchController } = {}
type Party = {
	leader: Player,
	members: { Player },
	launch: boolean,
}

local queue: { Player } = {}
local autoReady: { [Player]: boolean } = {}
local timerEnd: number? = nil
local consoleLabels: { [string]: TextLabel } = {}
local spectatorIndex: { [Player]: number } = {}
local parties: { [Player]: Party } = {}
local launchOrder: { Party } = {}
local invites: { [Player]: Player } = {}
local locatedFriends: { [Player]: { [number]: boolean } } = {}
local lastFoundList: { [Player]: { { id: number, name: string } } } = {}
local lastLocate: { [Player]: number } = {}
local inviteOptions: { [Player]: Instance } = {}

local function inQueue(player: Player): number?
	return table.find(queue, player)
end

local function partyMembers(player: Player): { Player }
	local party = parties[player]
	if not party then
		return { player }
	end
	local list = {}
	for _, member in party.members do
		if member.Parent then
			table.insert(list, member)
		end
	end
	if #list == 0 then
		return { player }
	end
	return list
end

local function lobbyMembers(player: Player): { Player }
	local list = {}
	for _, member in partyMembers(player) do
		if member.Parent and member:GetAttribute("InMatch") == nil then
			table.insert(list, member)
		end
	end
	return list
end

local function removeFromQueue(player: Player)
	local index = table.find(queue, player)
	if index then
		table.remove(queue, index)
	end
end

local function pushParty(party: Party)
	local members = {}
	for _, member in party.members do
		if member.Parent then
			table.insert(members, {
				id = member.UserId,
				name = member.DisplayName,
				leader = member == party.leader,
			})
		end
	end
	for _, member in party.members do
		if member.Parent then
			Remotes.get("PartyState"):FireClient(member, { members = members })
		end
	end
end

local function pushSolo(player: Player)
	if player.Parent then
		Remotes.get("PartyState"):FireClient(player, { members = {} })
	end
end

local function notice(player: Player, text: string)
	if player.Parent then
		Remotes.get("PartyState"):FireClient(player, { notice = text })
	end
end

local function partyBusy(player: Player): boolean
	local party = parties[player]
	if not party then
		return false
	end
	for _, member in party.members do
		if member.Parent and member:GetAttribute("InMatch") ~= nil then
			return true
		end
	end
	return false
end

local function queueParty(player: Player)
	if partyBusy(player) then
		return
	end
	local block = lobbyMembers(player)
	if #block == 0 then
		return
	end
	local insertAt = #queue + 1
	for _, member in block do
		local index = table.find(queue, member)
		if index and index < insertAt then
			insertAt = index
		end
	end
	local removedBefore = 0
	for _, member in block do
		local index = table.find(queue, member)
		if index then
			if index < insertAt then
				removedBefore += 1
			end
			table.remove(queue, index)
		end
	end
	insertAt = math.clamp(insertAt - removedBefore, 1, #queue + 1)
	for offset, member in block do
		table.insert(queue, insertAt + offset - 1, member)
		member:SetAttribute("Ready", true)
	end
end

local function leaveParty(player: Player)
	local party = parties[player]
	removeFromQueue(player)
	player:SetAttribute("Ready", nil)
	if not party then
		pushSolo(player)
		return
	end
	local rest = {}
	for _, member in party.members do
		if member ~= player and member.Parent then
			table.insert(rest, member)
		end
	end
	parties[player] = nil
	player:SetAttribute("PartyLaunch", nil)
	if #rest <= 1 then
		party.launch = false
		local launchIndex = table.find(launchOrder, party)
		if launchIndex then
			table.remove(launchOrder, launchIndex)
		end
		local last = rest[1]
		if last then
			parties[last] = nil
			last:SetAttribute("PartyLaunch", nil)
			last:SetAttribute("Ready", nil)
			pushSolo(last)
		end
	else
		if party.leader == player then
			party.leader = rest[1]
		end
		party.members = rest
		for _, member in rest do
			parties[member] = party
		end
		pushParty(party)
	end
	pushSolo(player)
end

-- host может быть лидером или участником: новый игрок встаёт в его пати.
local function addToParty(host: Player, target: Player): string?
	if not host.Parent or host == target then
		return "Друг уже вышел"
	end
	if host:GetAttribute("InMatch") ~= nil or target:GetAttribute("InMatch") ~= nil then
		return "Кто-то уже в матче"
	end
	local party = parties[host]
	if party and parties[target] == party then
		return nil
	end
	if party and #party.members >= Config.MAX_PLAYERS_PER_MATCH then
		return "Пати полное"
	end
	if parties[target] then
		leaveParty(target)
	end
	if not party or not parties[host] then
		party = { leader = host, members = { host }, launch = false }
		parties[host] = party
	end
	if table.find(party.members, target) then
		parties[target] = party
		pushParty(party)
		return nil
	end
	table.insert(party.members, target)
	parties[target] = party
	local anchor = if party.leader.Parent then party.leader else host
	if party.launch or inQueue(anchor) or inQueue(host) then
		party.launch = true
		if not table.find(launchOrder, party) then
			table.insert(launchOrder, party)
		end
		for _, member in party.members do
			if member.Parent and member:GetAttribute("InMatch") == nil then
				removeFromQueue(member)
				member:SetAttribute("Ready", true)
				member:SetAttribute("PartyLaunch", true)
			end
		end
	end
	pushParty(party)
	broadcast()
	return nil
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
		consoleLabels.Queue.Text = "Готовы к матчу    " .. #queue .. " / " .. Config.MAX_PLAYERS_PER_MATCH
	end
	for _, controller in controllers do
		local label = consoleLabels["C" .. (controller.slot + 1)]
		if label then
			local playing = if controller:isActive() then controller:info().alive else 0
			label.Text = if playing > 0 then tostring(playing) else "—"
			label.TextColor3 = if playing > 0 then Color3.fromRGB(255, 214, 120) else Color3.fromRGB(150, 156, 178)
		end
	end
end

-- Пати в очереди стоит подряд. В матч берём блок целиком или оставляем его ждать.
local function blockAt(index: number): { Player }
	local player = queue[index]
	local party = parties[player]
	if not party then
		return { player }
	end
	local block = {}
	local cursor = index
	while cursor <= #queue and parties[queue[cursor]] == party do
		table.insert(block, queue[cursor])
		cursor += 1
	end
	return block
end

-- "drop" — все вышли, "wait" — кто-то из пати ещё не может зайти, "ok" — можно брать целиком.
local function classify(block: { Player }): (string, { Player })
	local alive = {}
	local present = false
	for _, member in block do
		if member.Parent then
			present = true
			if not member.Character or member:GetAttribute("InMatch") ~= nil then
				return "wait", {}
			end
			table.insert(alive, member)
		end
	end
	if not present or #alive == 0 then
		return "drop", {}
	end
	return "ok", alive
end

local function queueBlocks(): { { Player } }
	local list = {}
	local index = 1
	while index <= #queue do
		local block = blockAt(index)
		local kind, alive = classify(block)
		if kind == "drop" then
			for _ = 1, #block do
				table.remove(queue, index)
			end
		else
			table.insert(list, if kind == "ok" then alive else {})
			index += #block
		end
	end
	return list
end

local function packFrom(blocks: { { Player } }, startAt: number, seats: number): { Player }
	local chosen = {}
	local left = seats
	for cursor = startAt, #blocks do
		local block = blocks[cursor]
		if #block > 0 and #block <= left then
			for _, member in block do
				table.insert(chosen, member)
			end
			left -= #block
		end
	end
	return chosen
end

local function dispatch(count: number)
	local controller = freeController()
	if not controller then
		return
	end
	local blocks = queueBlocks()
	local chosen = packFrom(blocks, 1, count)
	if #chosen < Config.MIN_PLAYERS then
		chosen = {}
		for startAt = 1, #blocks do
			local anchor = blocks[startAt]
			if #anchor >= Config.MIN_PLAYERS and #anchor <= count then
				chosen = packFrom(blocks, startAt, count)
				break
			end
		end
	end
	if #chosen < Config.MIN_PLAYERS then
		return
	end
	for _, member in chosen do
		removeFromQueue(member)
		member:SetAttribute("Ready", nil)
	end
	timerEnd = nil
	controller:start(chosen)
	broadcast()
end

local function beginPartyLaunch(party: Party)
	party.launch = true
	if not table.find(launchOrder, party) then
		table.insert(launchOrder, party)
	end
	for _, member in party.members do
		if member.Parent and member:GetAttribute("InMatch") == nil then
			removeFromQueue(member)
			member:SetAttribute("Ready", true)
			member:SetAttribute("PartyLaunch", true)
		end
	end
end

local function stopPartyLaunch(party: Party)
	party.launch = false
	local index = table.find(launchOrder, party)
	if index then
		table.remove(launchOrder, index)
	end
	for _, member in party.members do
		if member.Parent then
			removeFromQueue(member)
			member:SetAttribute("Ready", nil)
			member:SetAttribute("PartyLaunch", nil)
		end
	end
end

-- Пати забирает любую свободную арену целиком, без чужих игроков и без таймера.
local function sendPartyToArena(party: Party): boolean
	if not party.launch or partyBusy(party.leader) then
		return false
	end
	local block = {}
	for _, member in party.members do
		if member.Parent then
			if member:GetAttribute("InMatch") ~= nil or not member.Character then
				return false
			end
			table.insert(block, member)
		end
	end
	if #block < 2 then
		return false
	end
	local controller = freeController()
	if not controller then
		return false
	end
	controller:start(block)
	if not controller:isActive() then
		return false
	end
	party.launch = false
	local index = table.find(launchOrder, party)
	if index then
		table.remove(launchOrder, index)
	end
	for _, member in block do
		removeFromQueue(member)
		member:SetAttribute("Ready", nil)
		member:SetAttribute("PartyLaunch", nil)
	end
	return true
end

local function sendWaitingParties()
	local index = 1
	while index <= #launchOrder do
		local party = launchOrder[index]
		if not party.launch then
			table.remove(launchOrder, index)
		elseif sendPartyToArena(party) then
			-- эту пати уже убрали из списка
		elseif not freeController() then
			break
		else
			index += 1
		end
	end
end

function Matchmaker.setReady(player: Player, ready: boolean, auto: boolean?)
	if auto ~= nil then
		autoReady[player] = auto
	end
	if player:GetAttribute("InMatch") ~= nil then
		return
	end
	local party = parties[player]
	if party and #party.members >= 2 then
		if ready and partyBusy(player) then
			notice(player, "Ждём, пока вся пати выйдет из матча")
			return
		end
		if ready then
			beginPartyLaunch(party)
			sendPartyToArena(party)
		else
			stopPartyLaunch(party)
		end
		broadcast()
		return
	end
	if ready and partyBusy(player) then
		notice(player, "Ждём, пока вся пати выйдет из матча")
		return
	end
	if ready then
		queueParty(player)
	else
		for _, member in lobbyMembers(player) do
			removeFromQueue(member)
			member:SetAttribute("Ready", nil)
		end
		if auto == false then
			autoReady[player] = false
		end
	end
	broadcast()
end

function Matchmaker.toggle(player: Player)
	local party = parties[player]
	local launching = party ~= nil and party.launch
	Matchmaker.setReady(player, not launching and inQueue(player) == nil)
end

local function tick()
	sendWaitingParties()
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
	-- Авто-готовая пати сразу снова берёт свободную арену, а не хвост очереди.
	local seen: { [Player]: boolean } = {}
	for player, enabled in autoReady do
		if enabled and player.Parent and player:GetAttribute("InMatch") == nil and not seen[player] then
			local party = parties[player]
			if party and #party.members >= 2 then
				for _, member in party.members do
					seen[member] = true
				end
				local wants = false
				for _, member in lobbyMembers(player) do
					if autoReady[member] then
						wants = true
					end
				end
				if wants and not partyBusy(player) then
					beginPartyLaunch(party)
				end
			else
				seen[player] = true
				queueParty(player)
			end
		end
	end
	sendWaitingParties()
	broadcast()
end

export type SpectateEntry = { slot: number, center: Vector3, active: boolean }

function Matchmaker.allArenas(): { SpectateEntry }
	local list: { SpectateEntry } = {}
	for _, controller in controllers do
		table.insert(list, {
			slot = controller.slot,
			center = controller.center,
			active = controller:isActive(),
		})
	end
	table.sort(list, function(a, b)
		return a.slot < b.slot
	end)
	return list
end

-- action: "start" | "next" | "prev" — листаем все арены (1…6), в т.ч. пустые.
function Matchmaker.spectate(player: Player, action: string?)
	local list = Matchmaker.allArenas()
	local remote = Remotes.get("Spectate")
	if #list == 0 then
		spectatorIndex[player] = nil
		remote:FireClient(player, { ok = false, message = "Арены не найдены" })
		return
	end
	local idx = spectatorIndex[player] or 0
	if action == "next" then
		idx = (idx % #list) + 1
	elseif action == "prev" then
		idx = idx - 1
		if idx < 1 then
			idx = #list
		end
	else
		idx = 1
	end
	idx = math.clamp(idx, 1, #list)
	spectatorIndex[player] = idx
	local entry = list[idx]
	remote:FireClient(player, {
		ok = true,
		slot = entry.slot,
		center = entry.center,
		active = entry.active,
		index = idx,
		total = #list,
	})
end

function Matchmaker.clearSpectator(player: Player)
	spectatorIndex[player] = nil
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
		local screen = console:FindFirstChild("MatchSign", true)
		if screen then
			for _, label in screen:GetDescendants() do
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

	local function playerById(userId: any): Player?
		if typeof(userId) ~= "number" then
			return nil
		end
		return Players:GetPlayerByUserId(userId)
	end

	local function invite(from: Player, target: Player)
		if target == from or not target.Parent then
			return
		end
		if from:GetAttribute("InMatch") ~= nil or target:GetAttribute("InMatch") ~= nil then
			notice(from, "Игрок уже в матче")
			return
		end
		local party = parties[from]
		if party and party.leader ~= from then
			notice(from, "Приглашает только лидер")
			return
		end
		if party and parties[target] == party then
			notice(from, "Уже в пати")
			return
		end
		local size = if party then #party.members else 1
		if size >= Config.MAX_PLAYERS_PER_MATCH then
			notice(from, "Пати полное")
			return
		end
		invites[target] = from
		Remotes.get("PartyState"):FireClient(target, {
			invite = { id = from.UserId, name = from.DisplayName },
		})
		notice(from, "Приглашение отправлено")
	end

	local function accept(target: Player)
		local from = invites[target]
		invites[target] = nil
		Remotes.get("PartyState"):FireClient(target, { invite = false })
		if not from or not from.Parent or from == target then
			notice(target, "Приглашение уже не действует")
			return
		end
		local party = parties[from]
		if party and party.leader ~= from then
			notice(target, "Приглашение уже не действует")
			return
		end
		local err = addToParty(from, target)
		if err then
			notice(target, err)
		end
	end

	local function inviterFromJoin(player: Player): Player?
		local join = player:GetJoinData()
		local inviterId: number? = nil
		if typeof(join.LaunchData) == "string" then
			local digits = string.match(join.LaunchData, "^party:(%d+)$")
			inviterId = if digits then tonumber(digits) else nil
		end
		local data = join.TeleportData
		if not inviterId and typeof(data) == "table" and typeof(data.party) == "number" then
			inviterId = data.party
		end
		if not inviterId then
			return nil
		end
		return Players:GetPlayerByUserId(inviterId)
	end

	local function receivePartyJoin(player: Player)
		task.defer(function()
			if not player.Parent then
				return
			end
			local join = player:GetJoinData()
			local cameForParty = (typeof(join.LaunchData) == "string" and string.match(join.LaunchData, "^party:%d+$") ~= nil)
				or (typeof(join.TeleportData) == "table" and typeof(join.TeleportData.party) == "number")
			if not cameForParty then
				return
			end
			local host = inviterFromJoin(player)
			if not host or host == player then
				notice(player, "Друг уже вышел с сервера")
				return
			end
			local err = addToParty(host, player)
			if err then
				notice(player, err)
			else
				notice(player, "Ты в пати с " .. host.DisplayName)
				notice(host, player.DisplayName .. " теперь в пати")
			end
		end)
	end

	local function promptFriendInvite(player: Player)
		if player:GetAttribute("InMatch") ~= nil then
			return
		end
		local party = parties[player]
		if party and #party.members >= Config.MAX_PLAYERS_PER_MATCH then
			notice(player, "Пати полное")
			return
		end
		if #Players:GetPlayers() >= Players.MaxPlayers then
			notice(player, "Сервер полный. Если друг уже играет, нажми «К нему»")
			return
		end
		local allowed, canSend = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if not allowed or canSend ~= true then
			notice(player, "Приглашение друзей откроется в опубликованной игре")
			return
		end
		local created, options = pcall(function()
			return Instance.new("ExperienceInviteOptions")
		end)
		if not created or not options then
			local plain = pcall(function()
				SocialService:PromptGameInvite(player)
			end)
			if not plain then
				notice(player, "Не удалось открыть приглашение")
			end
			return
		end
		options.PromptMessage = "Заходи в Color Party, сыграем вместе"
		options.LaunchData = "party:" .. tostring(player.UserId)
		local old = inviteOptions[player]
		if old then
			old:Destroy()
		end
		inviteOptions[player] = options
		local prompted = pcall(function()
			SocialService:PromptGameInvite(player, options)
		end)
		if not prompted then
			inviteOptions[player] = nil
			options:Destroy()
			notice(player, "Не удалось открыть приглашение")
		end
	end

	local function friendName(item: any): string
		if typeof(item.DisplayName) == "string" and item.DisplayName ~= "" then
			return item.DisplayName
		end
		if typeof(item.Username) == "string" then
			return item.Username
		end
		return "Друг"
	end

	local function locateFriends(player: Player)
		local now = os.clock()
		if lastLocate[player] and now - lastLocate[player] < 8 then
			if player.Parent then
				Remotes.get("PartyState"):FireClient(player, { elsewhere = lastFoundList[player] or {} })
			end
			return
		end
		lastLocate[player] = now
		local found: { { id: number, name: string } } = {}
		local known: { [number]: boolean } = {}
		local ok, pages = pcall(function()
			return Players:GetFriendsAsync(player.UserId)
		end)
		if ok and pages then
			local checked = 0
			local pageCount = 0
			while player.Parent and checked < 8 and #found < 6 and pageCount < 4 do
				pageCount += 1
				for _, item in pages:GetCurrentPage() do
					if checked >= 8 or #found >= 6 then
						break
					end
					if typeof(item) == "table" and item.IsOnline == true and typeof(item.Id) == "number" then
						checked += 1
						local placeId: number? = nil
						local jobId: string? = nil
						local got = pcall(function()
							local foundPlace, foundJob = TeleportService:GetPlayerPlaceInstanceAsync(item.Id)
							placeId = foundPlace
							jobId = foundJob
						end)
						if got and placeId == game.PlaceId and typeof(jobId) == "string" and jobId ~= game.JobId then
							known[item.Id] = true
							table.insert(found, { id = item.Id, name = friendName(item) })
						end
					end
				end
				if pages.IsFinished or checked >= 8 or #found >= 6 then
					break
				end
				local advanced = pcall(function()
					pages:AdvanceToNextPageAsync()
				end)
				if not advanced then
					break
				end
			end
		end
		locatedFriends[player] = known
		lastFoundList[player] = found
		if player.Parent then
			Remotes.get("PartyState"):FireClient(player, { elsewhere = found })
		end
	end

	local function joinFriend(player: Player, friendId: number)
		if player:GetAttribute("InMatch") ~= nil then
			notice(player, "Сначала выйди из матча")
			return
		end
		local known = locatedFriends[player]
		if not known or not known[friendId] then
			notice(player, "Друг уже не на другом сервере")
			return
		end
		local placeId: number? = nil
		local jobId: string? = nil
		local got = pcall(function()
			local foundPlace, foundJob = TeleportService:GetPlayerPlaceInstanceAsync(friendId)
			placeId = foundPlace
			jobId = foundJob
		end)
		if not got or placeId ~= game.PlaceId or typeof(jobId) ~= "string" or jobId == game.JobId then
			notice(player, "Друг уже не на другом сервере")
			return
		end
		local options = Instance.new("TeleportOptions")
		options.ServerInstanceId = jobId
		options:SetTeleportData({ party = friendId })
		local teleported = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end)
		if not teleported then
			options:Destroy()
			notice(player, "Не удалось перейти к другу")
		end
	end

	Remotes.get("Party").OnServerEvent:Connect(function(player, action, userId)
		if typeof(action) ~= "string" then
			return
		end
		if action == "invite" then
			local target = playerById(userId)
			if target then
				invite(player, target)
			end
		elseif action == "accept" then
			accept(player)
		elseif action == "decline" then
			invites[player] = nil
			Remotes.get("PartyState"):FireClient(player, { invite = false })
		elseif action == "leave" then
			leaveParty(player)
			broadcast()
		elseif action == "kick" then
			local party = parties[player]
			local target = playerById(userId)
			if party and party.leader == player and target and parties[target] == party and target ~= player then
				leaveParty(target)
				notice(target, "Лидер убрал тебя из пати")
				broadcast()
			end
		elseif action == "robloxInvite" then
			promptFriendInvite(player)
		elseif action == "locate" then
			task.spawn(locateFriends, player)
		elseif action == "joinFriend" then
			local friendId = if typeof(userId) == "number" then userId else nil
			if friendId then
				joinFriend(player, friendId)
			end
		end
	end)

	SocialService.GameInvitePromptClosed:Connect(function(player)
		local options = inviteOptions[player]
		if options then
			inviteOptions[player] = nil
			options:Destroy()
		end
	end)

	local function arrived(player: Player)
		receivePartyJoin(player)
	end
	Players.PlayerAdded:Connect(arrived)
	for _, player in Players:GetPlayers() do
		arrived(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local dropped = {}
		for invitee, inviter in invites do
			if invitee == player or inviter == player then
				table.insert(dropped, invitee)
			end
		end
		for _, invitee in dropped do
			invites[invitee] = nil
			if invitee.Parent and invitee ~= player then
				Remotes.get("PartyState"):FireClient(invitee, { invite = false })
			end
		end
		if parties[player] then
			leaveParty(player)
		else
			removeFromQueue(player)
		end
		autoReady[player] = nil
		spectatorIndex[player] = nil
		locatedFriends[player] = nil
		lastFoundList[player] = nil
		lastLocate[player] = nil
		local options = inviteOptions[player]
		if options then
			inviteOptions[player] = nil
			options:Destroy()
		end
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
