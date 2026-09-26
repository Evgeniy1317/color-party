--!strict
-- Правила раунда: какой цвет показать, какой режим (обычный, обманка,
-- исключение, двойной), сколько времени дать и как раскрасить поле.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type Rule = {
	mode: string, -- normal | fake | exclude | double
	targets: { string }, -- цвета, на которых безопасно (для exclude — все, кроме excluded)
	shown: { string }, -- что показать на карточке в начале
	fakeTo: string?, -- на какой цвет переключится карточка (mode == fake)
	excluded: string?, -- запрещённый цвет (mode == exclude)
	time: number,
	assign: { { id: string, fraction: number, spread: boolean } },
	fillers: { string },
	hubId: string,
}

local RoundRules = {}

local function pick(rng: Random, list: { string }, exclude: { [string]: boolean }?): string
	local candidates = {}
	for _, id in list do
		if not exclude or not exclude[id] then
			table.insert(candidates, id)
		end
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

local function without(list: { string }, banned: { [string]: boolean }): { string }
	local result = {}
	for _, id in list do
		if not banned[id] then
			table.insert(result, id)
		end
	end
	return result
end

-- Выбирает палитру матча: COLORS_PER_MATCH случайных цветов из общего пула.
function RoundRules.matchPalette(rng: Random): { string }
	local ids = {}
	for _, def in Config.COLORS do
		table.insert(ids, def.id)
	end
	for n = #ids, 2, -1 do
		local m = rng:NextInteger(1, n)
		ids[n], ids[m] = ids[m], ids[n]
	end
	local chosen = {}
	for i = 1, math.min(Config.COLORS_PER_MATCH, #ids) do
		chosen[i] = ids[i]
	end
	return chosen
end

function RoundRules.pick(round: number, palette: { string }, rng: Random, lastTarget: string?): Rule
	local time = Config.roundTime(round)
	local avoid: { [string]: boolean } = {}
	if lastTarget then
		avoid[lastTarget] = true
	end
	local fracLo, fracHi = Config.TARGET_FRACTION[1], Config.TARGET_FRACTION[2]
	local fraction = fracLo + (fracHi - fracLo) * rng:NextNumber()

	-- Режим «любой цвет, кроме…» — раз в EXCLUDE_EVERY раундов, начиная с 6-го.
	if round >= Config.EXCLUDE_EVERY and round % Config.EXCLUDE_EVERY == 0 then
		local excluded = pick(rng, palette, avoid)
		local banned = { [excluded] = true }
		local safe = without(palette, banned)
		return {
			mode = "exclude",
			targets = safe,
			shown = { excluded },
			excluded = excluded,
			time = time + 1, -- чуть больше времени: надо понять, где НЕ стоять
			assign = { { id = excluded, fraction = 0.42, spread = true } },
			fillers = safe,
			hubId = excluded,
		}
	end

	-- Двойной цвет: две цели, но каждой мало.
	if round >= Config.DOUBLE_FROM_ROUND and rng:NextNumber() < Config.DOUBLE_CHANCE then
		local a = pick(rng, palette, avoid)
		avoid[a] = true
		local b = pick(rng, palette, avoid)
		local banned = { [a] = true, [b] = true }
		return {
			mode = "double",
			targets = { a, b },
			shown = { a, b },
			time = time,
			assign = {
				{ id = a, fraction = 0.065, spread = true },
				{ id = b, fraction = 0.065, spread = true },
			},
			fillers = without(palette, banned),
			hubId = pick(rng, without(palette, banned)),
		}
	end

	-- Обманка: карточка меняет цвет за FAKE_BEFORE_END секунд до конца.
	if round >= Config.FAKE_FROM_ROUND and rng:NextNumber() < Config.FAKE_CHANCE then
		local shown = pick(rng, palette, avoid)
		avoid[shown] = true
		local real = pick(rng, palette, avoid)
		local banned = { [shown] = true, [real] = true }
		return {
			mode = "fake",
			targets = { real },
			shown = { shown },
			fakeTo = real,
			time = time,
			assign = {
				{ id = shown, fraction = fraction, spread = true },
				{ id = real, fraction = fraction, spread = true },
			},
			fillers = without(palette, banned),
			hubId = shown, -- центр манит «ложным» цветом
		}
	end

	local target = pick(rng, palette, avoid)
	local banned = { [target] = true }
	local fillers = without(palette, banned)
	return {
		mode = "normal",
		targets = { target },
		shown = { target },
		time = time,
		assign = { { id = target, fraction = fraction, spread = true } },
		fillers = fillers,
		hubId = pick(rng, fillers),
	}
end

function RoundRules.shrinkCount(round: number, rng: Random): number
	if round < Config.SHRINK_FROM_ROUND then
		return 0
	end
	return rng:NextInteger(Config.SHRINK_COUNT[1], Config.SHRINK_COUNT[2])
end

function RoundRules.isSafe(rule: Rule, colorId: string?, isHub: boolean): boolean
	if not colorId or colorId == "" or isHub then
		return false
	end
	return table.find(rule.targets, colorId) ~= nil
end

return RoundRules
