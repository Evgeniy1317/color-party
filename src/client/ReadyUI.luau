--!strict
-- Панель готовности: кнопка ГОТОВ, авто-готов, состояние очереди, кнопка «Смотреть».

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local player = Players.LocalPlayer

local ReadyUI = {}

local PANEL = Color3.fromRGB(30, 28, 44)
local ACCENT = Color3.fromRGB(120, 226, 160)
local ACCENT_OFF = Color3.fromRGB(255, 255, 255)

local ready = false
local auto = false

local function corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: GuiObject, text: string, size: number, font: Enum.Font, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local gui = Instance.new("ScreenGui")
gui.Name = "ColorPartyReady"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -18, 1, -18)
panel.Size = UDim2.fromOffset(300, 214)
panel.BackgroundColor3 = PANEL
panel.BackgroundTransparency = 0.22
panel.BorderSizePixel = 0
panel.Parent = gui
corner(panel, 18)

local title = label(panel, "COLOR PARTY", 16, Enum.Font.GothamBold, Color3.fromRGB(255, 214, 120))
title.Position = UDim2.fromOffset(18, 12)
title.Size = UDim2.new(1, -36, 0, 20)
title.TextXAlignment = Enum.TextXAlignment.Left

local queueText = label(panel, "В очереди: 0 / " .. Config.MAX_PLAYERS_PER_MATCH, 15, Enum.Font.GothamMedium, Color3.fromRGB(226, 228, 240))
queueText.Position = UDim2.fromOffset(18, 34)
queueText.Size = UDim2.new(1, -36, 0, 20)
queueText.TextXAlignment = Enum.TextXAlignment.Left

local statusText = label(panel, "Арены свободны", 13, Enum.Font.Gotham, Color3.fromRGB(180, 186, 210))
statusText.Position = UDim2.fromOffset(18, 54)
statusText.Size = UDim2.new(1, -36, 0, 18)
statusText.TextXAlignment = Enum.TextXAlignment.Left

local readyButton = Instance.new("TextButton")
readyButton.Name = "Ready"
readyButton.Position = UDim2.fromOffset(18, 78)
readyButton.Size = UDim2.new(1, -36, 0, 42)
readyButton.BackgroundColor3 = ACCENT_OFF
readyButton.Font = Enum.Font.GothamBlack
readyButton.TextSize = 22
readyButton.TextColor3 = Color3.fromRGB(40, 38, 54)
readyButton.Text = "ГОТОВ"
readyButton.AutoButtonColor = true
readyButton.Parent = panel
corner(readyButton, 14)

local autoButton = Instance.new("TextButton")
autoButton.Name = "Auto"
autoButton.Position = UDim2.fromOffset(18, 128)
autoButton.Size = UDim2.new(0.5, -22, 0, 28)
autoButton.BackgroundColor3 = Color3.fromRGB(60, 58, 80)
autoButton.Font = Enum.Font.GothamMedium
autoButton.TextSize = 13
autoButton.TextColor3 = Color3.fromRGB(226, 228, 240)
autoButton.Text = "☐  Авто-готов"
autoButton.Parent = panel
corner(autoButton, 10)

local watchButton = Instance.new("TextButton")
watchButton.Name = "Watch"
watchButton.AnchorPoint = Vector2.new(1, 0)
watchButton.Position = UDim2.new(1, -18, 0, 128)
watchButton.Size = UDim2.new(0.5, -22, 0, 28)

local partyButton = Instance.new("TextButton")
partyButton.Name = "Party"
partyButton.Position = UDim2.fromOffset(18, 164)
partyButton.Size = UDim2.new(1, -36, 0, 32)
partyButton.BackgroundColor3 = Color3.fromRGB(124, 112, 214)
partyButton.Font = Enum.Font.GothamBold
partyButton.TextSize = 15
partyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
partyButton.Text = "Пати"
partyButton.AutoButtonColor = true
partyButton.Parent = panel
corner(partyButton, 10)
watchButton.BackgroundColor3 = Color3.fromRGB(60, 58, 80)
watchButton.Font = Enum.Font.GothamMedium
watchButton.TextSize = 13
watchButton.TextColor3 = Color3.fromRGB(226, 228, 240)
watchButton.Text = "▶  Смотреть арену"
watchButton.Parent = panel
corner(watchButton, 10)

local function refreshButtons()
	local launching = player:GetAttribute("PartyLaunch") == true
	if launching then
		readyButton.Text = "ИЩЕМ АРЕНУ"
	else
		readyButton.Text = if ready then "ОТМЕНА" else "ГОТОВ"
	end
	local face = if launching then Color3.fromRGB(255, 196, 80) elseif ready then ACCENT else ACCENT_OFF
	TweenService:Create(readyButton, TweenInfo.new(0.2), { BackgroundColor3 = face }):Play()
	autoButton.Text = (if auto then "☑" else "☐") .. "  Авто-готов"
	autoButton.BackgroundColor3 = if auto then Color3.fromRGB(88, 150, 110) else Color3.fromRGB(60, 58, 80)
end

readyButton.Activated:Connect(function()
	ready = not ready
	Effects.play("click")
	Remotes.get("SetReady"):FireServer(ready, auto)
	refreshButtons()
end)

autoButton.Activated:Connect(function()
	auto = not auto
	Effects.play("click")
	if auto and not ready then
		ready = true
	end
	Remotes.get("SetReady"):FireServer(ready, auto)
	refreshButtons()
end)

watchButton.Activated:Connect(function()
	Effects.play("click")
	Remotes.get("Spectate"):FireServer("start")
end)

-- Сервер — источник истины о готовности (атрибут Ready).
player:GetAttributeChangedSignal("Ready"):Connect(function()
	ready = player:GetAttribute("Ready") == true
	refreshButtons()
end)

player:GetAttributeChangedSignal("PartyLaunch"):Connect(function()
	ready = player:GetAttribute("Ready") == true or player:GetAttribute("PartyLaunch") == true
	refreshButtons()
end)

type PartyMember = { id: number, name: string, leader: boolean }
type ElsewhereFriend = { id: number, name: string }

local partyMembers: { PartyMember } = {}
local elsewhere: { ElsewhereFriend } = {}
local searchingFriends = false
local listOpen = false
local noticeUntil = 0

local inviteBar = Instance.new("Frame")
inviteBar.Name = "Invite"
inviteBar.AnchorPoint = Vector2.new(1, 1)
inviteBar.Position = UDim2.new(1, -18, 1, -240)
inviteBar.Size = UDim2.fromOffset(300, 48)
inviteBar.BackgroundColor3 = Color3.fromRGB(48, 42, 78)
inviteBar.BackgroundTransparency = 0.08
inviteBar.BorderSizePixel = 0
inviteBar.Visible = false
inviteBar.Parent = gui
corner(inviteBar, 14)

local inviteText = label(inviteBar, "", 14, Enum.Font.GothamMedium, Color3.fromRGB(236, 232, 255))
inviteText.Position = UDim2.fromOffset(12, 0)
inviteText.Size = UDim2.new(1, -148, 1, 0)
inviteText.TextXAlignment = Enum.TextXAlignment.Left
inviteText.TextWrapped = false
inviteText.TextTruncate = Enum.TextTruncate.AtEnd

local function smallButton(parent: Instance, text: string, x: number, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Position = UDim2.fromOffset(x, 10)
	button.Size = UDim2.fromOffset(58, 28)
	button.BackgroundColor3 = color
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent
	corner(button, 8)
	return button
end

local acceptButton = smallButton(inviteBar, "Да", 168, Color3.fromRGB(70, 176, 112))
local declineButton = smallButton(inviteBar, "Нет", 230, Color3.fromRGB(196, 78, 92))

local partyList = Instance.new("Frame")
partyList.Name = "PartyList"
partyList.AnchorPoint = Vector2.new(1, 1)
partyList.Position = UDim2.new(1, -18, 1, -240)
partyList.Size = UDim2.fromOffset(300, 220)
partyList.BackgroundColor3 = PANEL
partyList.BackgroundTransparency = 0
partyList.BorderSizePixel = 0
partyList.Visible = false
partyList.Parent = gui
corner(partyList, 16)

partyList.Size = UDim2.fromOffset(300, 268)

local listTitle = label(partyList, "Пати", 15, Enum.Font.GothamBold, Color3.fromRGB(255, 214, 120))
listTitle.Position = UDim2.fromOffset(14, 8)
listTitle.Size = UDim2.new(1, -28, 0, 20)
listTitle.TextXAlignment = Enum.TextXAlignment.Left

local inviteFriend = Instance.new("TextButton")
inviteFriend.Name = "InviteFriend"
inviteFriend.Position = UDim2.fromOffset(14, 32)
inviteFriend.Size = UDim2.new(1, -28, 0, 34)
inviteFriend.BackgroundColor3 = Color3.fromRGB(70, 186, 112)
inviteFriend.Font = Enum.Font.GothamBold
inviteFriend.TextSize = 15
inviteFriend.TextColor3 = Color3.fromRGB(255, 255, 255)
inviteFriend.Text = "Пригласить друга"
inviteFriend.AutoButtonColor = true
inviteFriend.Parent = partyList
corner(inviteFriend, 10)

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Rows"
scroll.Position = UDim2.fromOffset(10, 74)
scroll.Size = UDim2.new(1, -20, 1, -84)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = partyList

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scroll

local function amLeader(): boolean
	if #partyMembers < 2 then
		return true
	end
	for _, member in partyMembers do
		if member.id == player.UserId then
			return member.leader
		end
	end
	return false
end

local function memberIds(): { [number]: boolean }
	local ids: { [number]: boolean } = {}
	for _, member in partyMembers do
		ids[member.id] = true
	end
	return ids
end

local function placePartyPopups()
	local lift = 240
	if inviteBar.Visible then
		inviteBar.Position = UDim2.new(1, -18, 1, -lift)
		lift += 56
	end
	partyList.Position = UDim2.new(1, -18, 1, -lift)
end

local function refreshPartyButton()
	if #partyMembers >= 2 then
		partyButton.Text = "Пати  ·  " .. #partyMembers
		partyButton.BackgroundColor3 = Color3.fromRGB(98, 86, 196)
	else
		partyButton.Text = "Пати"
		partyButton.BackgroundColor3 = Color3.fromRGB(124, 112, 214)
	end
end

local function clearRows()
	for _, child in scroll:GetChildren() do
		if child:IsA("GuiObject") and child ~= listLayout then
			child:Destroy()
		end
	end
end

local function addRow(order: number, titleText: string, actionText: string?, onAction: (() -> ())?)
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -4, 0, 28)
	row.BackgroundTransparency = 1
	row.Parent = scroll

	local nameLabel = label(row, titleText, 14, Enum.Font.GothamMedium, Color3.fromRGB(232, 230, 244))
	nameLabel.Size = UDim2.new(1, if actionText then -78 else -4, 1, 0)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextWrapped = false
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

	if actionText and onAction then
		local action = Instance.new("TextButton")
		action.AnchorPoint = Vector2.new(1, 0.5)
		action.Position = UDim2.new(1, 0, 0.5, 0)
		action.Size = UDim2.fromOffset(72, 24)
		action.BackgroundColor3 = Color3.fromRGB(70, 66, 98)
		action.Font = Enum.Font.GothamBold
		action.TextSize = 13
		action.TextColor3 = Color3.fromRGB(240, 238, 255)
		action.Text = actionText
		action.AutoButtonColor = true
		action.Parent = row
		corner(action, 8)
		action.Activated:Connect(function()
			Effects.play("click")
			onAction()
		end)
	end
end

local function refreshPartyList()
	if not listOpen then
		return
	end
	clearRows()
	local order = 1
	local ids = memberIds()
	if #partyMembers >= 2 then
		for _, member in partyMembers do
			local titleText = member.name .. (if member.leader then "  ·  лидер" else "")
			if member.id == player.UserId then
				titleText = "Ты" .. (if member.leader then "  ·  лидер" else "")
				addRow(order, titleText, nil, nil)
			elseif amLeader() then
				local userId = member.id
				addRow(order, titleText, "Убрать", function()
					Remotes.get("Party"):FireServer("kick", userId)
				end)
			else
				addRow(order, titleText, nil, nil)
			end
			order += 1
		end
		addRow(order, "Выйти из пати", "Выйти", function()
			Remotes.get("Party"):FireServer("leave")
			listOpen = false
			partyList.Visible = false
		end)
		order += 1
	end
	if #elsewhere > 0 then
		addRow(order, "Друзья на других серверах", nil, nil)
		order += 1
		for _, friend in elsewhere do
			if not ids[friend.id] then
				local userId = friend.id
				addRow(order, friend.name, "К нему", function()
					Remotes.get("Party"):FireServer("joinFriend", userId)
				end)
				order += 1
			end
		end
	elseif searchingFriends then
		addRow(order, "Ищем друзей в игре...", nil, nil)
		order += 1
	end
	if amLeader() then
		local found = false
		for _, other in Players:GetPlayers() do
			if other ~= player and not ids[other.UserId] and other:GetAttribute("InMatch") == nil then
				if not found then
					addRow(order, "Кто уже в этом лобби", nil, nil)
					order += 1
					found = true
				end
				local userId = other.UserId
				addRow(order, other.DisplayName, "Звать", function()
					Remotes.get("Party"):FireServer("invite", userId)
				end)
				order += 1
			end
		end
		if not found and #elsewhere == 0 and not searchingFriends then
			local hint = Instance.new("TextLabel")
			hint.Name = "Row"
			hint.LayoutOrder = order
			hint.Size = UDim2.new(1, -4, 0, 78)
			hint.BackgroundTransparency = 1
			hint.Font = Enum.Font.GothamMedium
			hint.TextSize = 14
			hint.TextColor3 = Color3.fromRGB(210, 206, 230)
			hint.TextXAlignment = Enum.TextXAlignment.Left
			hint.TextYAlignment = Enum.TextYAlignment.Top
			hint.TextWrapped = true
			hint.Text = "Нажми «Пригласить друга». Ему придёт уведомление Roblox, он зайдёт на этот сервер и сразу попадёт в пати."
			hint.Parent = scroll
		end
	elseif #partyMembers >= 2 then
		addRow(order, "Приглашает только лидер", nil, nil)
	end
end

local function setLobbyVisible(visible: boolean)
	panel.Visible = visible
	if not visible then
		listOpen = false
		partyList.Visible = false
		inviteBar.Visible = false
	end
	placePartyPopups()
end

player:GetAttributeChangedSignal("InMatch"):Connect(function()
	setLobbyVisible(player:GetAttribute("InMatch") == nil)
end)
setLobbyVisible(player:GetAttribute("InMatch") == nil)

partyButton.Activated:Connect(function()
	Effects.play("click")
	listOpen = not listOpen
	partyList.Visible = listOpen and panel.Visible
	if listOpen then
		searchingFriends = true
		Remotes.get("Party"):FireServer("locate")
	end
	refreshPartyList()
	placePartyPopups()
end)

inviteFriend.Activated:Connect(function()
	Effects.play("click")
	Remotes.get("Party"):FireServer("robloxInvite")
end)

acceptButton.Activated:Connect(function()
	Effects.play("click")
	inviteBar.Visible = false
	placePartyPopups()
	Remotes.get("Party"):FireServer("accept")
end)

declineButton.Activated:Connect(function()
	Effects.play("click")
	inviteBar.Visible = false
	placePartyPopups()
	Remotes.get("Party"):FireServer("decline")
end)

local function showNotice(text: string)
	noticeUntil = os.clock() + 3
	statusText.Text = text
end

Remotes.get("PartyState").OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end
	if data.members ~= nil then
		partyMembers = {}
		if typeof(data.members) == "table" then
			for _, member in data.members do
				if typeof(member) == "table" and typeof(member.id) == "number" and typeof(member.name) == "string" then
					table.insert(partyMembers, {
						id = member.id,
						name = member.name,
						leader = member.leader == true,
					})
				end
			end
		end
		refreshPartyButton()
		refreshPartyList()
	end
	if data.elsewhere ~= nil then
		elsewhere = {}
		searchingFriends = false
		if typeof(data.elsewhere) == "table" then
			for _, friend in data.elsewhere do
				if typeof(friend) == "table" and typeof(friend.id) == "number" and typeof(friend.name) == "string" then
					table.insert(elsewhere, { id = friend.id, name = friend.name })
				end
			end
		end
		refreshPartyList()
	end
	if data.invite == false then
		inviteBar.Visible = false
		placePartyPopups()
	elseif typeof(data.invite) == "table" and typeof(data.invite.name) == "string" then
		inviteText.Text = data.invite.name .. " зовёт в пати"
		inviteBar.Visible = panel.Visible
		placePartyPopups()
	end
	if typeof(data.notice) == "string" then
		showNotice(data.notice)
		ready = player:GetAttribute("Ready") == true
		refreshButtons()
	end
end)

Players.PlayerAdded:Connect(function()
	refreshPartyList()
end)
Players.PlayerRemoving:Connect(function()
	refreshPartyList()
end)

Remotes.get("QueueUpdate").OnClientEvent:Connect(function(data)
	if player:GetAttribute("PartyLaunch") == true then
		local count = math.max(#partyMembers, 2)
		queueText.Text = "Пати из " .. tostring(count) .. " · без очереди"
		if os.clock() >= noticeUntil then
			statusText.Text = "Ищем свободную арену"
		end
		refreshButtons()
		return
	end
	queueText.Text = "В очереди: " .. tostring(data.count) .. " / " .. tostring(data.max)
	local status
	if data.waitingArena then
		status = "Все арены заняты — ждём свободную"
	elseif #data.active > 0 then
		status = "Идёт матчей: " .. #data.active .. " из " .. tostring(data.arenas)
	else
		status = "Арены свободны"
	end
	if data.timeLeft and data.count > 0 then
		status ..= "  ·  старт через " .. math.ceil(data.timeLeft) .. " с"
	end
	if os.clock() >= noticeUntil then
		statusText.Text = status
	end
end)

return ReadyUI
