--!strict
-- Секции колеса фортуны. Шансы в процентах, сумма 100.
-- productId спина за робуксы лежит в Shop под ключом "wheel" и пока равен 0.

local Shop = require(script.Parent:WaitForChild("Shop"))

local Wheel = {}

export type Sector = {
	id: string,
	name: string,
	short: string,
	detail: string,
	chance: number,
	color: Color3,
}

local SECTORS: { Sector } = {
	{
		id = "coins_s",
		name = "1 500 монет",
		short = "1500",
		detail = "Небольшая пачка монет",
		chance = 28,
		color = Color3.fromRGB(255, 214, 96),
	},
	{
		id = "coins_m",
		name = "4 000 монет",
		short = "4000",
		detail = "Средняя пачка монет",
		chance = 18,
		color = Color3.fromRGB(255, 164, 64),
	},
	{
		id = "coins_l",
		name = "12 000 монет",
		short = "12000",
		detail = "Крупная пачка монет",
		chance = 8,
		color = Color3.fromRGB(255, 112, 72),
	},
	{
		id = "match",
		name = "Эффект на матч",
		short = "Матч",
		detail = "Случайная плюшка на один матч, потом гаснет",
		chance = 18,
		color = Color3.fromRGB(168, 124, 255),
	},
	{
		id = "discount",
		name = "Скидка 30%",
		short = "−30%",
		detail = "Следующая покупка в магазине за монеты дешевле на 30%",
		chance = 16,
		color = Color3.fromRGB(88, 206, 138),
	},
	{
		id = "trail",
		name = "Случайный след",
		short = "След",
		detail = "След, которого ещё нет. Редкий приз",
		chance = 7,
		color = Color3.fromRGB(86, 186, 255),
	},
	{
		id = "perk",
		name = "Случайная плюшка",
		short = "Плюшка",
		detail = "Плюшка навсегда. Самый редкий приз",
		chance = 5,
		color = Color3.fromRGB(255, 112, 168),
	},
}

Wheel.SPIN_COINS = 2500
Wheel.SPIN_ROBUX = 15
Wheel.PRODUCT_KEY = "wheel"

function Wheel.sectors(): { Sector }
	return SECTORS
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
