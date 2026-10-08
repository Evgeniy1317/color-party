--!strict
-- Бесплатные задания дня и платный батл-пасс.

local Quests = {}

export type Kind = "parkour" | "wins" | "shields" | "dashes" | "coins"
export type Grant = "skin" | "trail" | "perk_shield" | "perk_speed" | "perk"

export type DailyDef = {
	id: string,
	kind: Kind,
	name: string,
	detail: string,
	goal: number,
	coins: number,
}

export type PassDef = {
	id: string,
	kind: Kind,
	name: string,
	detail: string,
	goal: number,
	reward: string,
	grant: Grant,
}

Quests.PASS_PRICE = 300
Quests.PRODUCT_KEY = "battlepass"

local DAILY: { DailyDef } = {
	{
		id = "parkour",
		kind = "parkour",
		name = "Пройти паркур",
		detail = "Доберись до финиша полосы",
		goal = 1,
		coins = 1500,
	},
	{
		id = "win",
		kind = "wins",
		name = "Победа в матче",
		detail = "Выиграй одну игру",
		goal = 1,
		coins = 2000,
	},
	{
		id = "wins2",
		kind = "wins",
		name = "Две победы",
		detail = "Выиграй два матча",
		goal = 2,
		coins = 3500,
	},
	{
		id = "shields",
		kind = "shields",
		name = "Три щита",
		detail = "Подбери щиты на аренах",
		goal = 3,
		coins = 1200,
	},
	{
		id = "dashes",
		kind = "dashes",
		name = "Три ускорителя",
		detail = "Подбери молнии ускорения",
		goal = 3,
		coins = 1200,
	},
	{
		id = "coins",
		kind = "coins",
		name = "Монеты с арены",
		detail = "Собери монеты в матчах",
		goal = 8,
		coins = 1000,
	},
}

local PASS: { PassDef } = {
	{
		id = "bp_parkour",
		kind = "parkour",
		name = "Мастер полосы",
		detail = "Пройди паркур 3 раза",
		goal = 3,
		reward = "Случайный скин",
		grant = "skin",
	},
	{
		id = "bp_wins",
		kind = "wins",
		name = "Серия побед",
		detail = "Выиграй 8 матчей",
		goal = 8,
		reward = "Случайный след",
		grant = "trail",
	},
	{
		id = "bp_shields",
		kind = "shields",
		name = "Стена щитов",
		detail = "Собери 15 щитов",
		goal = 15,
		reward = "Карманный купол навсегда",
		grant = "perk_shield",
	},
	{
		id = "bp_dashes",
		kind = "dashes",
		name = "Искра без конца",
		detail = "Собери 15 ускорителей",
		goal = 15,
		reward = "Попутный ветер навсегда",
		grant = "perk_speed",
	},
	{
		id = "bp_crown",
		kind = "wins",
		name = "Корона лобби",
		detail = "Выиграй 12 матчей",
		goal = 12,
		reward = "Случайная плюшка навсегда",
		grant = "perk",
	},
}

function Quests.dailyById(id: string): DailyDef?
	for _, quest in DAILY do
		if quest.id == id then
			return quest
		end
	end
	return nil
end

function Quests.passById(id: string): PassDef?
	for _, quest in PASS do
		if quest.id == id then
			return quest
		end
	end
	return nil
end

function Quests.passList(): { PassDef }
	return PASS
end

function Quests.roll(userId: number, day: number): { DailyDef }
	local rng = Random.new((userId % 100000) * 17 + day * 131)
	local pool: { DailyDef } = {}
	for index, quest in DAILY do
		pool[index] = quest
	end
	for index = #pool, 2, -1 do
		local swap = rng:NextInteger(1, index)
		pool[index], pool[swap] = pool[swap], pool[index]
	end
	local picked: { DailyDef } = {}
	local used: { [string]: boolean } = {}
	for _, quest in pool do
		if not used[quest.kind] then
			used[quest.kind] = true
			table.insert(picked, quest)
			if #picked == 3 then
				break
			end
		end
	end
	return picked
end

return Quests
