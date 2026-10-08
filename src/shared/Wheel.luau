--!strict
-- Секции колеса фортуны. Шансы в процентах, сумма 100.
-- productId спина за робуксы лежит в Shop под ключом "wheel" и пока равен 0.

local Shop = require(script.Parent:WaitForChild("Shop"))

local Wheel = {}

export type Rarity = "common" | "purple" | "secret" | "gold"

export type Sector = {
	id: string,
	name: string,
	short: string,
	detail: string,
	chance: number,
	color: Color3,
	rarity: Rarity,
	icon: string,
	mark: string?,
}

local RARITY_COLOR: { [Rarity]: Color3 } = {
	common = Color3.fromRGB(176, 195, 217),
	purple = Color3.fromRGB(149, 86, 255),
	secret = Color3.fromRGB(226, 70, 78),
	gold = Color3.fromRGB(255, 196, 64),
}

local function thumb(id: number): string
	return "rbxthumb://type=Asset&id=" .. tostring(id) .. "&w=150&h=150"
end

-- Крупные и мелкие секторы чередуются, чтобы иконки не слипались.
local SECTORS: { Sector } = {
	{
		id = "coins_s",
		name = "1 500 монет",
		short = "1500",
		detail = "Одна монета на счёт",
		chance = 24,
		color = RARITY_COLOR.common,
		rarity = "common",
		icon = thumb(67225889),
	},
	{
		id = "perk",
		name = "Случайная плюшка",
		short = "Плюшка",
		detail = "Плюшка навсегда. Самый редкий приз",
		chance = 5,
		color = RARITY_COLOR.secret,
		rarity = "secret",
		icon = thumb(15928895043),
	},
	{
		id = "coins_m",
		name = "4 000 монет",
		short = "4000",
		detail = "Небольшая пачка монет",
		chance = 16,
		color = RARITY_COLOR.common,
		rarity = "common",
		icon = thumb(132769554),
	},
	{
		id = "trail",
		name = "Случайный след",
		short = "След",
		detail = "След, которого ещё нет. Редкий приз",
		chance = 7,
		color = RARITY_COLOR.purple,
		rarity = "purple",
		icon = "rbxassetid://107949754436781",
	},
	{
		id = "match",
		name = "Эффект на матч",
		short = "Матч",
		detail = "Случайная плюшка на один матч, потом гаснет",
		chance = 16,
		color = RARITY_COLOR.common,
		rarity = "common",
		icon = thumb(12600837104),
	},
	{
		id = "skin",
		name = "Случайный скин",
		short = "Скин",
		detail = "Скин, которого ещё нет. На манекене знак вопроса",
		chance = 8,
		color = RARITY_COLOR.gold,
		rarity = "gold",
		icon = thumb(16747135211),
		mark = "?",
	},
	{
		id = "discount",
		name = "Скидка 30%",
		short = "−30%",
		detail = "Следующая покупка в магазине за монеты дешевле на 30%",
		chance = 16,
		color = RARITY_COLOR.purple,
		rarity = "purple",
		icon = thumb(5235040472),
	},
	{
		id = "coins_l",
		name = "12 000 монет",
		short = "12000",
		detail = "Большая стопка монет",
		chance = 8,
		color = RARITY_COLOR.purple,
		rarity = "purple",
		icon = thumb(9341850496),
	},
}

Wheel.SPIN_COINS = 2500
Wheel.SPIN_ROBUX = 15
Wheel.PRODUCT_KEY = "wheel"

local ITEM_ICONS: { [string]: string } = {
	perk_jump = "rbxassetid://91298870492601",
	perk_shield = "rbxassetid://82788513509598",
	perk_dash = "rbxassetid://91669812184269",
	perk_life = "rbxassetid://75191507217586",
	perk_speed = "rbxassetid://93356796691553",
	perk_coins = "rbxassetid://88068529364286",
	perk_revive = "rbxassetid://88404567308271",
	perk_lightning = "rbxassetid://104667034338901",
	perk_salute = "rbxassetid://96849720546650",
	trail_rainbow = "rbxassetid://107949754436781",
	trail_fire = "rbxassetid://75226922089625",
	trail_ice = "rbxassetid://98546609363845",
	trail_gold = "rbxassetid://114531965952754",
	trail_toxic = "rbxassetid://95927643957313",
	trail_candy = "rbxassetid://127263746228320",
	trail_storm = "rbxassetid://120645531130115",
}

function Wheel.rarityColor(rarity: Rarity): Color3
	return RARITY_COLOR[rarity]
end

function Wheel.sectors(): { Sector }
	return SECTORS
end

function Wheel.icon(id: string): string
	if ITEM_ICONS[id] then
		return ITEM_ICONS[id]
	end
	for _, sector in SECTORS do
		if sector.id == id then
			return sector.icon
		end
	end
	return ""
end

function Wheel.colorAt(angle: number): Color3
	local at = angle % 360
	local cursor = 0
	for _, sector in SECTORS do
		local span = sector.chance / 100 * 360
		if at < cursor + span - 0.001 then
			return sector.color
		end
		cursor += span
	end
	return SECTORS[#SECTORS].color
end

function Wheel.productId(): number
	return Shop.productId(Wheel.PRODUCT_KEY)
end

return Wheel
