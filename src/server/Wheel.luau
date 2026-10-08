--!strict
-- Колесо фортуны: один бесплатный спин в сутки, дальше за монеты или робуксы.
-- Приз выбирает сервер. Клиент только крутит картинку до уже выданного сектора.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(script.Parent:WaitForChild("Economy"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Shop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Shop"))
local SkinShop = require(script.Parent:WaitForChild("SkinShop"))
local Skins = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Skins"))
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

local function grant(player: Player, sectorId: string): (string, string, string)
	if sectorId == "coins_s" then
		Economy.addCoins(player, 1500, "wheel")
		return "1 500 монет", "Монеты уже на счету", WheelConfig.icon("coins_s")
	elseif sectorId == "coins_m" then
		Economy.addCoins(player, 4000, "wheel")
		return "4 000 монет", "Монеты уже на счету", WheelConfig.icon("coins_m")
	elseif sectorId == "coins_l" then
		Economy.addCoins(player, 12000, "wheel")
		return "12 000 монет", "Монеты уже на счету", WheelConfig.icon("coins_l")
	elseif sectorId == "discount" then
		Economy.setDiscount(player, math.max(Economy.discount(player), 30))
		return "Скидка 30%", "Следующая покупка за монеты в магазине дешевле", WheelConfig.icon("discount")
	elseif sectorId == "skin" then
		local open = {}
		for _, skin in Skins.all() do
			if not Economy.ownsSkin(player, skin.id) then
				table.insert(open, skin)
			end
		end
		if #open == 0 then
			Economy.addCoins(player, 4000, "wheel")
			return "4 000 монет", "Все скины уже есть, вместо скина — монеты", WheelConfig.icon("coins_m")
		end
		local skin = open[rng:NextInteger(1, #open)]
		SkinShop.grant(player, skin.id)
		local thumb = "rbxthumb://type=Asset&id=" .. tostring(skin.asset) .. "&w=150&h=150"
		return skin.name, "Скин надет. Он в магазине, во вкладке скинов", thumb
	elseif sectorId == "match" then
		local open = {}
		for _, item in Shop.perks() do
			if not Economy.ownsSkin(player, item.id) then
				table.insert(open, item)
			end
		end
		if #open == 0 then
			Economy.addCoins(player, 4000, "wheel")
			return "4 000 монет", "Все плюшки уже навсегда, вместо эффекта — монеты", WheelConfig.icon("coins_m")
		end
		local item = open[rng:NextInteger(1, #open)]
		Economy.addCharge(player, item.id, 1)
		return item.name, "Заряд на один матч уже в магазине, на иконке плюшки", WheelConfig.icon(item.id)
	elseif sectorId == "trail" then
		local open = {}
		for _, item in Shop.trails() do
			if not Economy.ownsSkin(player, item.id) then
				table.insert(open, item)
			end
		end
		if #open == 0 then
			Economy.addCoins(player, 4000, "wheel")
			return "4 000 монет", "Все следы уже есть, вместо следа — монеты", WheelConfig.icon("coins_m")
		end
		local item = open[rng:NextInteger(1, #open)]
		SkinShop.grant(player, item.id)
		return item.name, "След надет. Он в магазине, во вкладке «Следы»", WheelConfig.icon(item.id)
	end
	local open = {}
	for _, item in Shop.perks() do
		if not Economy.ownsSkin(player, item.id) then
			table.insert(open, item)
		end
	end
	if #open == 0 then
		Economy.addCoins(player, 6000, "wheel")
		return "6 000 монет", "Все плюшки уже навсегда, вместо приза — монеты", WheelConfig.icon("coins_l")
	end
	local item = open[rng:NextInteger(1, #open)]
	SkinShop.grant(player, item.id)
	return item.name, "Плюшка уже в магазине и включена", WheelConfig.icon(item.id)
end

local function rollAngle(index: number): number
	local sectors = WheelConfig.sectors()
	local sector = sectors[index]
	local cursor = 0
	for at, item in ipairs(sectors) do
		if at == index then
			break
		end
		cursor += item.chance
	end
	local span = sector.chance / 100 * 360
	local start = cursor / 100 * 360
	return start + span * 0.5
end

local function spin(player: Player): { [string]: any }?
	local ticket = rng:NextNumber() * 100
	local cursor = 0
	local index = #WheelConfig.sectors()
	for at, sector in ipairs(WheelConfig.sectors()) do
		cursor += sector.chance
		if ticket <= cursor then
			index = at
			break
		end
	end
	local sector = WheelConfig.sectors()[index]
	local title, detail, icon = grant(player, sector.id)
	Economy.pushShop(player)
	return {
		ok = true,
		angle = rollAngle(index),
		title = title,
		detail = detail,
		icon = icon,
		sectorId = sector.id,
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
	task.delay(6.6, function()
		busy[player] = nil
	end)
	local result = spin(player)
	if result then
		pack(player, result)
	end
end

function Wheel.grantPaid(player: Player)
	if busy[player] then
		task.delay(6.8, function()
			if player.Parent then
				Wheel.grantPaid(player)
			end
		end)
		return
	end
	busy[player] = true
	task.delay(6.6, function()
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
