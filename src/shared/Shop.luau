--!strict
-- Цены магазина в монетах и робуксах.
-- productId = 0, пока товар не создан в Creator Dashboard → Monetization → Developer Products.
-- После создания впиши сюда числовой id, и кнопка R$ начнёт открывать покупку.

local Shop = {}

export type Kind = "perk" | "trail"

export type Item = {
	id: string,
	name: string,
	kind: Kind,
	blurb: string,
	coins: number,
	robux: number,
	icon: string?,
	colors: { Color3 }?,
	onceCoins: number?,
	onceRobux: number?,
}

local PERKS: { Item } = {
	{
		id = "perk_jump",
		name = "Прыжок кота",
		kind = "perk",
		icon = "jump",
		blurb = "Второй прыжок в воздухе, в лобби и в матче",
		coins = 15000,
		robux = 49,
	},
	{
		id = "perk_shield",
		name = "Карманный купол",
		kind = "perk",
		icon = "shield",
		blurb = "Каждый матч начинаешь со щитом",
		coins = 20000,
		robux = 79,
	},
	{
		id = "perk_dash",
		name = "Искра",
		kind = "perk",
		icon = "dash",
		blurb = "Клавиша Q в матче: короткое спасение от падения",
		coins = 20000,
		robux = 79,
	},
	{
		id = "perk_life",
		name = "Девятая жизнь",
		kind = "perk",
		icon = "life",
		blurb = "На одну жизнь больше в каждом матче",
		coins = 30000,
		robux = 99,
	},
	{
		id = "perk_speed",
		name = "Попутный ветер",
		kind = "perk",
		icon = "speed",
		blurb = "Бежишь заметно быстрее",
		coins = 12000,
		robux = 49,
	},
	{
		id = "perk_coins",
		name = "Монетный магнит",
		kind = "perk",
		icon = "magnet",
		blurb = "Монетки на арене приносят вдвое больше",
		coins = 25000,
		robux = 99,
	},
	{
		id = "perk_revive",
		name = "Второе дыхание",
		kind = "perk",
		icon = "revive",
		blurb = "Один раз за матч возвращаешься на арену после выбывания",
		coins = 35000,
		robux = 129,
	},
	{
		id = "perk_lightning",
		name = "Громовой удар",
		kind = "perk",
		icon = "lightning",
		blurb = "В месте смерти бьёт молния с грохотом",
		coins = 22000,
		robux = 79,
	},
	{
		id = "perk_salute",
		name = "Салют",
		kind = "perk",
		icon = "salute",
		blurb = "Когда побеждаешь, над ареной вспыхивает большой салют",
		coins = 28000,
		robux = 99,
	},
}

local TRAILS: { Item } = {
	{
		id = "trail_rainbow",
		name = "Радужный след",
		kind = "trail",
		blurb = "За спиной тянется радуга",
		coins = 8000,
		robux = 25,
		colors = {
			Color3.fromRGB(255, 70, 70),
			Color3.fromRGB(255, 170, 40),
			Color3.fromRGB(255, 230, 60),
			Color3.fromRGB(70, 220, 90),
			Color3.fromRGB(50, 190, 255),
			Color3.fromRGB(150, 80, 255),
		},
	},
	{
		id = "trail_fire",
		name = "Огненный след",
		kind = "trail",
		blurb = "Горящий хвост",
		coins = 6000,
		robux = 25,
		colors = { Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 80, 20), Color3.fromRGB(120, 20, 10) },
	},
	{
		id = "trail_ice",
		name = "Ледяной след",
		kind = "trail",
		blurb = "Холодный голубой шлейф",
		coins = 6000,
		robux = 25,
		colors = { Color3.fromRGB(220, 250, 255), Color3.fromRGB(80, 190, 255), Color3.fromRGB(40, 80, 180) },
	},
	{
		id = "trail_gold",
		name = "Золотой след",
		kind = "trail",
		blurb = "Мягкое золото",
		coins = 10000,
		robux = 35,
		colors = { Color3.fromRGB(255, 236, 160), Color3.fromRGB(255, 186, 40), Color3.fromRGB(180, 110, 20) },
	},
	{
		id = "trail_toxic",
		name = "Ядовитый след",
		kind = "trail",
		blurb = "Кислотно-зелёный",
		coins = 7000,
		robux = 25,
		colors = { Color3.fromRGB(210, 255, 80), Color3.fromRGB(40, 200, 60), Color3.fromRGB(10, 80, 30) },
	},
	{
		id = "trail_candy",
		name = "Конфетный след",
		kind = "trail",
		blurb = "Розовый и белый",
		coins = 7000,
		robux = 25,
		colors = { Color3.fromRGB(255, 170, 210), Color3.fromRGB(255, 80, 160), Color3.fromRGB(255, 230, 245) },
	},
	{
		id = "trail_storm",
		name = "Грозовой след",
		kind = "trail",
		blurb = "Фиолетовые молнии",
		coins = 9000,
		robux = 35,
		colors = { Color3.fromRGB(180, 140, 255), Color3.fromRGB(80, 40, 180), Color3.fromRGB(230, 230, 255) },
	},
}

-- Крупные цены скинов и их цена в робуксах. Ванильный остаётся бесплатным.
local SKIN_COINS: { [string]: number } = {
	sakura = 12000,
	hoodie = 8000,
	gothic = 18000,
	night = 15000,
	neko = 14000,
	city = 11000,
	summer = 13000,
	specs = 15000,
	dood = 18000,
	emerald = 17000,
}

local SKIN_ROBUX: { [string]: number } = {
	sakura = 99,
	hoodie = 49,
	gothic = 149,
	night = 99,
	neko = 99,
	city = 79,
	summer = 79,
	specs = 99,
	dood = 129,
	emerald = 99,
}

-- Сюда вписываются id Developer Product. 0 = ещё не создан.
local PRODUCTS: { [string]: number } = {}

local ONCE: { [string]: { number } } = {
	perk_jump = { 1500, 9 },
	perk_shield = { 2000, 12 },
	perk_dash = { 2000, 12 },
	perk_life = { 2500, 15 },
	perk_speed = { 1200, 8 },
	perk_coins = { 2000, 12 },
	perk_revive = { 3000, 19 },
	perk_lightning = { 1800, 10 },
	perk_salute = { 2200, 12 },
}

local PERK_ATTR: { [string]: string } = {
	perk_jump = "PerkDoubleJump",
	perk_shield = "PerkShield",
	perk_dash = "PerkDash",
	perk_life = "PerkLife",
	perk_speed = "PerkSpeed",
	perk_coins = "PerkCoins",
	perk_revive = "PerkRevive",
	perk_lightning = "PerkLightning",
	perk_salute = "PerkSalute",
}

local BY_ID: { [string]: Item } = {}
for _, item in PERKS do
	BY_ID[item.id] = item
	local once = ONCE[item.id]
	if once then
		item.onceCoins = once[1]
		item.onceRobux = once[2]
	end
end
for _, item in TRAILS do
	BY_ID[item.id] = item
end

local function rememberProduct(id: string, productId: number)
	if productId > 0 then
		PRODUCTS[id] = productId
	end
end

function Shop.perks(): { Item }
	return PERKS
end

function Shop.trails(): { Item }
	return TRAILS
end

function Shop.get(id: string): Item?
	return BY_ID[id]
end

function Shop.coins(id: string, fallback: number): number
	if SKIN_COINS[id] then
		return SKIN_COINS[id]
	end
	local item = BY_ID[id]
	return if item then item.coins else fallback
end

function Shop.robux(id: string): number
	if SKIN_ROBUX[id] then
		return SKIN_ROBUX[id]
	end
	local item = BY_ID[id]
	return if item then item.robux else 0
end

function Shop.onceCoins(id: string): number
	local item = BY_ID[id]
	return if item and item.onceCoins then item.onceCoins else 0
end

function Shop.onceRobux(id: string): number
	local item = BY_ID[id]
	return if item and item.onceRobux then item.onceRobux else 0
end

function Shop.perkAttribute(id: string): string?
	return PERK_ATTR[id]
end

function Shop.onceKey(id: string): string
	return id .. "#once"
end

function Shop.productId(id: string): number
	return PRODUCTS[id] or 0
end

function Shop.itemByProduct(productId: number): string?
	for id, listed in PRODUCTS do
		if listed == productId then
			return id
		end
	end
	return nil
end

function Shop.setProduct(id: string, productId: number)
	rememberProduct(id, productId)
end

return Shop
