--!strict
-- Общие настройки Color Party: цвета, тайминги, арены, экономика.
-- Используется и сервером, и клиентом.

local RunService = game:GetService("RunService")

local Config = {}

-- Матчмейкинг -------------------------------------------------------------
Config.MAX_PLAYERS_PER_MATCH = 10
Config.MIN_PLAYERS = if RunService:IsStudio() then 1 else 2 -- в Studio можно тестировать одному
Config.QUEUE_WAIT = 20 -- секунд ожидания, если очередь неполная
Config.QUEUE_WAIT_BUSY = 10 -- если на сервере много людей
Config.BUSY_SERVER_PLAYERS = 25

-- Арены -------------------------------------------------------------------
-- Слот 0 виден из окна лобби (окно смотрит в +Z). Остальные расставлены
-- дальше и по бокам, чтобы из окна была видна глубина «города арен».
Config.ARENA_SLOTS = {
	Vector3.new(0, 48, 240),
	Vector3.new(-190, 60, 640),
	Vector3.new(190, 60, 640),
	Vector3.new(-430, 48, 330),
	Vector3.new(430, 48, 330),
	Vector3.new(0, 76, 1040),
}

Config.ARENA = {
	UPPER_RADIUS = 42,
	LOWER_RADIUS = 46,
	FLOOR_GAP = 45, -- расстояние между этажами
	TILE = 8, -- базовая плита
	TILE_GAP = 0.7, -- зазор между плитами (видно пустоту под ареной)
	TILE_THICKNESS = 1.1,
	SPAWN_RADIUS = 30,
	FALL_LIMIT = 40, -- насколько ниже нижнего этажа считаем «улетел»
}

-- Цвета -------------------------------------------------------------------
export type ColorDef = { id: string, name: string, color: Color3 }

local COLORS: { ColorDef } = {
	{ id = "red", name = "КРАСНЫЙ", color = Color3.fromRGB(236, 72, 78) },
	{ id = "coral", name = "КОРАЛЛОВЫЙ", color = Color3.fromRGB(255, 132, 108) },
	{ id = "orange", name = "ОРАНЖЕВЫЙ", color = Color3.fromRGB(255, 158, 52) },
	{ id = "yellow", name = "ЖЁЛТЫЙ", color = Color3.fromRGB(255, 214, 64) },
	{ id = "lime", name = "ЛАЙМ", color = Color3.fromRGB(186, 232, 72) },
	{ id = "green", name = "ЗЕЛЁНЫЙ", color = Color3.fromRGB(84, 200, 108) },
	{ id = "mint", name = "МЯТНЫЙ", color = Color3.fromRGB(110, 226, 190) },
	{ id = "cyan", name = "БИРЮЗОВЫЙ", color = Color3.fromRGB(72, 210, 230) },
	{ id = "sky", name = "ГОЛУБОЙ", color = Color3.fromRGB(104, 176, 255) },
	{ id = "blue", name = "СИНИЙ", color = Color3.fromRGB(72, 108, 236) },
	{ id = "indigo", name = "ИНДИГО", color = Color3.fromRGB(112, 84, 214) },
	{ id = "purple", name = "ФИОЛЕТОВЫЙ", color = Color3.fromRGB(164, 96, 232) },
	{ id = "magenta", name = "ПУРПУРНЫЙ", color = Color3.fromRGB(226, 84, 200) },
	{ id = "pink", name = "РОЗОВЫЙ", color = Color3.fromRGB(255, 140, 196) },
	{ id = "white", name = "БЕЛЫЙ", color = Color3.fromRGB(246, 246, 250) },
	{ id = "black", name = "ЧЁРНЫЙ", color = Color3.fromRGB(46, 44, 56) },
}
Config.COLORS = COLORS
Config.COLORS_PER_MATCH = 10

local byId: { [string]: ColorDef } = {}
for _, def in COLORS do
	byId[def.id] = def
end
Config.COLOR_BY_ID = byId

-- Раунды ------------------------------------------------------------------
Config.MAX_ROUNDS = 25
Config.PREPARE_TIME = 3
Config.DROP_TIME = 2.6
Config.RESULTS_TIME = 6
Config.LIVES = 2

function Config.roundTime(round: number): number
	if round <= 5 then
		return 7
	elseif round <= 10 then
		return 5
	elseif round <= 15 then
		return 3
	end
	return 2
end

Config.TARGET_FRACTION = { 0.12, 0.18 } -- доля плит целевого цвета
Config.FAKE_FROM_ROUND = 8
Config.FAKE_CHANCE = 0.2
Config.FAKE_BEFORE_END = 1.5
Config.EXCLUDE_EVERY = 6 -- раунд «любой цвет, кроме…»
Config.DOUBLE_FROM_ROUND = 12
Config.DOUBLE_CHANCE = 0.25
Config.SHRINK_FROM_ROUND = 10
Config.SHRINK_COUNT = { 4, 6 }
Config.COINS_ON_FIELD = { 3, 4 }
Config.COIN_VALUE = 3
Config.BONUS_FROM_ROUND = 4
Config.BONUS_CHANCE = 0.14

-- Экономика ---------------------------------------------------------------
Config.ECONOMY = {
	ROUND_SURVIVED = 5,
	STREAK_STEP = 0.1,
	TOP3 = 50,
	WIN = 150,
	PER_ELIMINATED_BEFORE = 10,
	CROWN_SECONDS = 300,
}

return Config
