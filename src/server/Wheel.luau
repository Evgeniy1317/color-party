--!strict
-- Колесо фортуны: один бесплатный спин в сутки, дальше за монеты или робуксы.
-- Приз выбирает сервер. Клиент только крутит картинку до уже выданного сектора.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(script.Parent:WaitForChild("Economy"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Shop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Shop"))
local WheelConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Wheel"))

local Wheel = {}

local rng = Random.new()
local busy: { [Player]: boolean } = {}

local function pack(player: Player, extra: { [string]: any }?)
	local payload: { [string]: any } = {
		coins = Economy.coins(player),
		free = Economy.freeSpin(player),
		discount = Economy.discount(player),
		armed = Economy.armed(player),
		spinCoins = WheelConfig.SPIN_COINS,
		spinRobux = WheelConfig.SPIN_ROBUX,
	}
	if extra then
		for key, value in extra do
			payload[key] = value
		end
	end
	Remotes.get("WheelState"):FireClient(player, payload)
end

local function grant(player: Player, sectorId: string): (string, string)
	if sectorId == "coins_s" then
		Economy.addCoins(player, 1500, "wheel")
		return "1 500 монет", "Монеты уже на счету"
	elseif sectorId == "coins_m" then
		Economy.addCoins(player, 4000, "wheel")
		return "4 000 монет", "Монеты уже на счету"
	elseif sectorId == "coins_l" then
		Economy.addCoins(player, 12000, "wheel")
		return "12 000 монет", "Монеты уже на счету"
	elseif sectorId == "discount" then
		Economy.setDiscount(player, math.max(Economy.discount(player), 30))
		return "Скидка 30%", "Следующая покупка за монеты в магазине дешевле"
	elseif sectorId == "match" then
		local open = {}
		for _, item in Shop.perks() do
			if not Economy.ownsSkin(player, item.id) then
				table.insert(open, item)
			end
		end
		if #open == 0 then
			Economy.addCoins(player, 4000, "wheel")
			return "4 000 монет", "Все плюшки уже навсегда, вместо эффекта — монеты"
		end
		local item = open[rng:NextInteger(1, #open)]
		Economy.armPerk(player, item.id)
		return item.name, "Сработает в следующем матче и потом выключится"
	elseif sectorId == "trail" then
		local open = {}
		for _, item in Shop.trails() do
			if not Economy.ownsSkin(player, item.id) then
				table.insert(open, item)
			end
		end
		if #open == 0 then
			Economy.addCoins(player, 4000, "wheel")
			return "4 000 монет", "Все следы уже есть, вместо следа — монеты"
		end
		local item = open[rng:NextInteger(1, #open)]
		Economy.grantSkin(player, item.id)
		return item.name, "След в магазине, во вкладке «Следы»"
	end
	local open = {}
	for _, item in Shop.perks() do
		if not Economy.ownsSkin(player, item.id) then
			table.insert(open, item)
		end
	end
	if #open == 0 then
		Economy.addCoins(player, 6000, "wheel")
		return "6 000 монет", "Все плюшки уже навсегда, вместо приза — монеты"
	end
	local item = open[rng:NextInteger(1, #open)]
	Economy.grantSkin(player, item.id)
	Economy.refreshPerks(player)
	return item.name, "Плюшка остаётся навсегда"
end

local function rollAngle(index: number): number
	local sectors = WheelConfig.sectors()
	local sector = sectors[index]
	local cursor = 0
	for at, item in sectors do
		if at == index then
			break
		end
		cursor += item.chance
	end
	local span = sector.chance / 100 * 360
	local start = cursor / 100 * 360
	return start + span * rng:NextNumber(0.18, 0.82)
end

local function spin(player: Player): { [string]: any }?
	local ticket = rng:NextNumber() * 100
	local cursor = 0
	local index = #WheelConfig.sectors()
	for at, sector in WheelConfig.sectors() do
		cursor += sector.chance
		if ticket <= cursor then
			index = at
			break
		end
	end
	local sector = WheelConfig.sectors()[index]
	local title, detail = grant(player, sector.id)
	Economy.pushShop(player)
	return {
		ok = true,
		angle = rollAngle(index),
		title = title,
		detail = detail,
		sector = sector.name,
		free = Economy.freeSpin(player),
		coins = Economy.coins(player),
	}
end

local function begin(player: Player, mode: string)
	if player:GetAttribute("InMatch") ~= nil then
		pack(player, { ok = false, notice = "Колесо только в лобби" })
		return
	end
	if busy[player] then
		pack(player, { ok = false, notice = "Колесо ещё крутится" })
		return
	end
	if mode == "free" then
		if not Economy.useFreeSpin(player) then
			pack(player, { ok = false, notice = "Бесплатный спин уже был сегодня" })
			return
		end
	elseif mode == "coins" then
		if Economy.coins(player) < WheelConfig.SPIN_COINS then
			pack(player, { ok = false, notice = "Не хватает монет" })
			return
		end
		Economy.addCoins(player, -WheelConfig.SPIN_COINS, "wheel")
	else
		pack(player, { ok = false, notice = "Так крутить нельзя" })
		return
	end
	busy[player] = true
	task.delay(4.6, function()
		busy[player] = nil
	end)
	local result = spin(player)
	if result then
		pack(player, result)
	end
end

function Wheel.grantPaid(player: Player)
	if busy[player] then
		task.delay(4.8, function()
			if player.Parent then
				Wheel.grantPaid(player)
			end
		end)
		return
	end
	busy[player] = true
	task.delay(4.6, function()
		busy[player] = nil
	end)
	local result = spin(player)
	if result then
		result.detail = "Оплачено робуксами. " .. tostring(result.detail)
		pack(player, result)
	end
end

local function buyRobux(player: Player)
	if player:GetAttribute("InMatch") ~= nil then
		pack(player, { ok = false, notice = "Колесо только в лобби" })
		return
	end
	local productId = WheelConfig.productId()
	if productId <= 0 then
		pack(player, {
			ok = false,
			notice = "Робуксы: создай Developer Product и впиши id в Shop под ключом wheel. Цена " .. tostring(WheelConfig.SPIN_ROBUX) .. " R$",
		})
		return
	end
	MarketplaceService:PromptProductPurchase(player, productId)
end

local function attachPrompt()
	local world = workspace:WaitForChild("World", 60)
	if not world then
		return
	end
	local podium = world:WaitForChild("Lobby"):WaitForChild("Podiums"):WaitForChild("Wheel", 60)
	if not podium then
		return
	end
	local host = podium:FindFirstChild("Sign") or podium:FindFirstChildWhichIsA("BasePart", true)
	if not host or not host:IsA("BasePart") then
		return
	end
	local existing = podium:FindFirstChild("WheelPrompt", true)
	if existing then
		existing:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WheelPrompt"
	prompt.ActionText = "Крутить"
	prompt.ObjectText = "Колесо"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = host
end

function Wheel.init()
	local remote = Remotes.get("Wheel")
	remote.OnServerEvent:Connect(function(player, action)
		if typeof(action) ~= "string" then
			return
		end
		if action == "state" then
			pack(player)
		elseif action == "free" or action == "coins" then
			begin(player, action)
		elseif action == "robux" then
			buyRobux(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
	task.spawn(attachPrompt)
end

return Wheel
