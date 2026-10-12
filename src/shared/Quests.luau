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
		name = "Run the parkour",
		detail = "Reach the end of the course",
		goal = 1,
		coins = 1500,
	},
	{
		id = "win",
		kind = "wins",
		name = "Win a match",
		detail = "Win one game",
		goal = 1,
		coins = 2000,
	},
	{
		id = "wins2",
		kind = "wins",
		name = "Two wins",
		detail = "Win two matches",
		goal = 2,
		coins = 3500,
	},
	{
		id = "shields",
		kind = "shields",
		name = "Three shields",
		detail = "Pick up shields in the arenas",
		goal = 3,
		coins = 1200,
	},
	{
		id = "dashes",
		kind = "dashes",
		name = "Three dashes",
		detail = "Pick up dash bolts",
		goal = 3,
		coins = 1200,
	},
	{
		id = "coins",
		kind = "coins",
		name = "Arena coins",
		detail = "Collect coins in matches",
		goal = 8,
		coins = 1000,
	},
}

local PASS: { PassDef } = {
	{
		id = "bp_parkour",
		kind = "parkour",
		name = "Course master",
		detail = "Finish the parkour 3 times",
		goal = 3,
		reward = "Random skin",
		grant = "skin",
	},
	{
		id = "bp_wins",
		kind = "wins",
		name = "Win streak",
		detail = "Win 8 matches",
		goal = 8,
		reward = "Random trail",
		grant = "trail",
	},
	{
		id = "bp_shields",
		kind = "shields",
		name = "Shield wall",
		detail = "Collect 15 shields",
		goal = 15,
		reward = "Pocket Dome forever",
		grant = "perk_shield",
	},
	{
		id = "bp_dashes",
		kind = "dashes",
		name = "Endless spark",
		detail = "Collect 15 dashes",
		goal = 15,
		reward = "Tailwind forever",
		grant = "perk_speed",
	},
	{
		id = "bp_crown",
		kind = "wins",
		name = "Lobby crown",
		detail = "Win 12 matches",
		goal = 12,
		reward = "Random perk forever",
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
