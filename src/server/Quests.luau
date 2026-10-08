--!strict
-- Ежедневные квесты и батл-пасс. Прогресс копится с реальных событий матча и паркура.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(script.Parent:WaitForChild("Economy"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Shop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Shop"))
local Skins = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Skins"))
local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quests"))

local Quests = {}

type DailyRow = { id: string, taken: boolean, progress: number, claimed: boolean }
type BpRow = { progress: number, claimed: boolean }
type Board = { daily: { DailyRow }, owned: boolean, bp: { [string]: BpRow } }

local finished: { [Player]: boolean } = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

local function money(amount: number): string
	local digits = tostring(math.floor(amount))
	local reversed = string.reverse(digits)
	local grouped = string.gsub(reversed, "(%d%d%d)", "%1 ")
	return (string.gsub(string.reverse(grouped), "^ ", ""))
end

local function nameOf(id: string): string
	local skin = Skins.get(id)
	if skin then
		return skin.name
	end
	local item = Shop.get(id)
	return if item then item.name else id
end

local function board(player: Player): Board?
	local day, daily, owned, bp = Economy.questBoard(player)
	if day == nil or daily == nil or owned == nil or bp == nil then
		return nil
	end
	local fresh = today()
	local valid = day == fresh and #daily == 3
	if valid then
		local used: { [string]: boolean } = {}
		for _, row in daily do
			local def = Catalog.dailyById(row.id)
			if not def or used[def.kind] then
				valid = false
				break
			end
			used[def.kind] = true
		end
	end
	if not valid then
		local rows: { DailyRow } = {}
		for _, def in Catalog.roll(player.UserId, fresh) do
			table.insert(rows, { id = def.id, taken = false, progress = 0, claimed = false })
		end
		Economy.setQuestBoard(player, fresh, rows)
		day, daily, owned, bp = Economy.questBoard(player)
		if day == nil or daily == nil or owned == nil or bp == nil then
			return nil
		end
	end
	local dirty = false
	for _, def in Catalog.passList() do
		if bp[def.id] == nil then
			bp[def.id] = { progress = 0, claimed = false }
			dirty = true
		end
	end
	if dirty then
		Economy.saveQuests(player)
	end
	return { daily = daily, owned = owned, bp = bp }
end

local function push(player: Player, notice: string?)
	local data = board(player)
	if not data then
		return
	end
	local daily = data.daily
	local owned = data.owned
	local bp = data.bp
	local free = {}
	for _, row in daily do
		local def = Catalog.dailyById(row.id)
		if def then
			local action = "take"
			if row.claimed then
				action = "done"
			elseif row.taken and row.progress >= def.goal then
				action = "claim"
			elseif row.taken then
				action = "wait"
			end
			table.insert(free, {
				id = row.id,
				name = def.name,
				detail = def.detail,
				goal = def.goal,
				progress = row.progress,
				claimed = row.claimed,
				reward = money(def.coins) .. " монет",
				action = action,
			})
		end
	end
	local premium = {}
	for _, def in Catalog.passList() do
		local row = bp[def.id]
		local progress = if row then row.progress else 0
		local claimed = row ~= nil and row.claimed
		local action = "lock"
		if claimed then
			action = "done"
		elseif owned and progress >= def.goal then
			action = "claimBp"
		elseif owned then
			action = "wait"
		end
		table.insert(premium, {
			id = def.id,
			name = def.name,
			detail = def.detail,
			goal = def.goal,
			progress = progress,
			claimed = claimed,
			reward = def.reward,
			action = action,
		})
	end
	Remotes.get("QuestState"):FireClient(player, {
		daily = free,
		pass = premium,
		owned = owned,
		price = Catalog.PASS_PRICE,
		notice = notice or "",
	})
end

local function unowned(player: Player, ids: { string }): { string }
	local pool = {}
	for _, id in ids do
		if not Economy.ownsSkin(player, id) then
			table.insert(pool, id)
		end
	end
	return pool
end

local function grantItem(player: Player, id: string): string
	require(script.Parent:WaitForChild("SkinShop")).grant(player, id)
	Economy.pushShop(player)
	return nameOf(id)
end

local function grantPassReward(player: Player, grant: Catalog.Grant): string
	if grant == "skin" then
		local ids = {}
		for _, skin in Skins.all() do
			table.insert(ids, skin.id)
		end
		local pool = unowned(player, ids)
		if #pool == 0 then
			Economy.addCoins(player, 20000, "quest")
			return "20 000 монет — все скины уже есть"
		end
		local id = pool[Random.new():NextInteger(1, #pool)]
		return "Скин: " .. grantItem(player, id)
	elseif grant == "trail" then
		local ids = {}
		for _, item in Shop.trails() do
			table.insert(ids, item.id)
		end
		local pool = unowned(player, ids)
		if #pool == 0 then
			Economy.addCoins(player, 12000, "quest")
			return "12 000 монет — все следы уже есть"
		end
		local id = pool[Random.new():NextInteger(1, #pool)]
		return "След: " .. grantItem(player, id)
	elseif grant == "perk_shield" or grant == "perk_speed" then
		local id = if grant == "perk_shield" then "perk_shield" else "perk_speed"
		if Economy.ownsSkin(player, id) then
			Economy.addCoins(player, 15000, "quest")
			return "15 000 монет — плюшка уже есть"
		end
		return "Плюшка: " .. grantItem(player, id)
	end
	local ids = {}
	for _, item in Shop.perks() do
		table.insert(ids, item.id)
	end
	local pool = unowned(player, ids)
	if #pool == 0 then
		Economy.addCoins(player, 25000, "quest")
		return "25 000 монет — все плюшки уже есть"
	end
	local id = pool[Random.new():NextInteger(1, #pool)]
	return "Плюшка: " .. grantItem(player, id)
end

local function finishIndex(): number
	local world = workspace:FindFirstChild("World")
	local parkour = world and world:FindFirstChild("Parkour")
	local pads = parkour and parkour:FindFirstChild("Checkpoints")
	local best = 1
	if pads then
		for _, pad in pads:GetChildren() do
			local index = pad:GetAttribute("Index")
			if typeof(index) == "number" and index > best then
				best = index
			end
		end
	end
	return best
end

local function hookParkour(player: Player)
	player:GetAttributeChangedSignal("ParkourCheckpoint"):Connect(function()
		local index = player:GetAttribute("ParkourCheckpoint")
		if typeof(index) ~= "number" then
			finished[player] = nil
			return
		end
		if index >= finishIndex() and not finished[player] then
			finished[player] = true
			Quests.progress(player, "parkour", 1)
		end
	end)
end

function Quests.progress(player: Player, kind: string, amount: number)
	local data = board(player)
	if not data or amount <= 0 then
		return
	end
	local daily = data.daily
	local bp = data.bp
	local changed = false
	for _, row in daily do
		local def = Catalog.dailyById(row.id)
		if def and def.kind == kind and row.taken and not row.claimed and row.progress < def.goal then
			row.progress = math.min(def.goal, row.progress + amount)
			changed = true
		end
	end
	for _, def in Catalog.passList() do
		local row = bp[def.id]
		if def.kind == kind and row and not row.claimed and row.progress < def.goal then
			row.progress = math.min(def.goal, row.progress + amount)
			changed = true
		end
	end
	if changed then
		Economy.saveQuests(player)
		push(player)
	end
end

function Quests.grantPass(player: Player)
	local data = board(player)
	if data and data.owned then
		push(player, "Батл-пасс уже открыт")
		return
	end
	Economy.setBattlePass(player, true)
	push(player, "Батл-пасс открыт")
end

local function attachPrompt()
	local world = workspace:WaitForChild("World", 60)
	if not world then
		return
	end
	local podium = world:WaitForChild("Lobby"):WaitForChild("Podiums"):WaitForChild("Quest", 60)
	if not podium then
		return
	end
	local host = podium:FindFirstChild("Sign") or podium:FindFirstChildWhichIsA("BasePart", true)
	if not host or not host:IsA("BasePart") then
		return
	end
	local existing = podium:FindFirstChild("QuestPrompt", true)
	if existing then
		existing:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "QuestPrompt"
	prompt.ActionText = "Открыть"
	prompt.ObjectText = "Квесты"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = host
end

function Quests.init()
	local remote = Remotes.get("Quests")
	remote.OnServerEvent:Connect(function(player, action, id)
		if typeof(action) ~= "string" then
			return
		end
		if action == "state" then
			push(player)
			return
		end
		if action == "robux" then
			local data = board(player)
			if not data then
				return
			end
			if data.owned then
				push(player, "Батл-пасс уже открыт")
				return
			end
			local productId = Shop.productId(Catalog.PRODUCT_KEY)
			if productId <= 0 then
				push(player, "Робуксы: создай Developer Product на 300 R$ и впиши id в Shop под ключом battlepass")
				return
			end
			MarketplaceService:PromptProductPurchase(player, productId)
			return
		end
		if typeof(id) ~= "string" then
			return
		end
		local data = board(player)
		if not data then
			return
		end
		local daily = data.daily
		local owned = data.owned
		local bp = data.bp
		if action == "take" then
			for _, row in daily do
				if row.id == id and not row.taken and not row.claimed then
					row.taken = true
					Economy.saveQuests(player)
					push(player, "Задание взято")
					return
				end
			end
		elseif action == "claim" then
			for _, row in daily do
				local def = Catalog.dailyById(row.id)
				if row.id == id and def and row.taken and not row.claimed and row.progress >= def.goal then
					row.claimed = true
					Economy.addCoins(player, def.coins, "quest")
					Economy.saveQuests(player)
					push(player, "Награда: " .. money(def.coins) .. " монет")
					return
				end
			end
		elseif action == "claimBp" then
			if not owned then
				push(player, "Сначала открой батл-пасс")
				return
			end
			local def = Catalog.passById(id)
			local row = bp[id]
			if def and row and not row.claimed and row.progress >= def.goal then
				row.claimed = true
				Economy.saveQuests(player)
				local reward = grantPassReward(player, def.grant)
				push(player, reward)
			end
		end
	end)
	Players.PlayerAdded:Connect(hookParkour)
	for _, player in Players:GetPlayers() do
		hookParkour(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		finished[player] = nil
	end)
	task.spawn(attachPrompt)
end

return Quests
