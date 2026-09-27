--!strict
-- Общие настройки Color Party: цвета, тайминги, арены, экономика.
-- Используется и сервером, и клиентом.

local RunService = game:GetService("RunService")

local Config = {}

-- Матчмейкинг -------------------------------------------------------------
Config.MAX_PLAYERS_PER_MATCH = 5
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
	-- Половина стороны квадрата. Нижний этаж шире, чтобы падение с верхнего
	-- всегда попадало на пол, а не в пустоту за краем.
	UPPER_RADIUS = 100, -- кратно плите 10, иначе по краю остаётся щель
	LOWER_RADIUS = 120,
	FLOOR_GAP = 52, -- расстояние между этажами
	TILE = 10, -- базовая плита
	TILE_GAP = 0, -- плиты стыкуются вплотную
	TILE_THICKNESS = 1.2,
	SPAWN_RADIUS = 62,
	FALL_LIMIT = 40, -- насколько ниже нижнего этажа считаем «улетел»
}

-- Цвета -------------------------------------------------------------------
export type ColorDef = { id: string, name: string, color: Color3 }

local COLORS: { ColorDef } = {
	{ id = "red", name = "КРАСНЫЙ", color = Color3.fromRGB(235, 55, 62) },
	{ id = "crimson", name = "АЛЫЙ", color = Color3.fromRGB(196, 28, 58) },
	{ id = "coral", name = "КОРАЛЛ", color = Color3.fromRGB(255, 112, 92) },
	{ id = "orange", name = "ОРАНЖЕВЫЙ", color = Color3.fromRGB(255, 140, 28) },
	{ id = "amber", name = "ЯНТАРЬ", color = Color3.fromRGB(255, 176, 42) },
	{ id = "yellow", name = "ЖЁЛТЫЙ", color = Color3.fromRGB(255, 214, 36) },
	{ id = "gold", name = "ЗОЛОТОЙ", color = Color3.fromRGB(232, 176, 28) },
	{ id = "lime", name = "ЛАЙМ", color = Color3.fromRGB(168, 230, 42) },
	{ id = "chartreuse", name = "САЛАТ", color = Color3.fromRGB(124, 214, 48) },
	{ id = "green", name = "ЗЕЛЁНЫЙ", color = Color3.fromRGB(42, 196, 86) },
	{ id = "emerald", name = "ИЗУМРУД", color = Color3.fromRGB(16, 168, 120) },
	{ id = "mint", name = "МЯТА", color = Color3.fromRGB(72, 230, 176) },
	{ id = "teal", name = "МОРСКОЙ", color = Color3.fromRGB(18, 176, 176) },
	{ id = "cyan", name = "БИРЮЗА", color = Color3.fromRGB(36, 214, 232) },
	{ id = "sky", name = "ГОЛУБОЙ", color = Color3.fromRGB(72, 168, 255) },
	{ id = "azure", name = "ЛАЗУРЬ", color = Color3.fromRGB(28, 132, 245) },
	{ id = "blue", name = "СИНИЙ", color = Color3.fromRGB(52, 86, 235) },
	{ id = "cobalt", name = "КОБАЛЬТ", color = Color3.fromRGB(36, 58, 196) },
	{ id = "indigo", name = "ИНДИГО", color = Color3.fromRGB(92, 64, 214) },
	{ id = "violet", name = "ФИАЛКА", color = Color3.fromRGB(138, 72, 232) },
	{ id = "purple", name = "ФИОЛЕТ", color = Color3.fromRGB(168, 64, 220) },
	{ id = "magenta", name = "ПУРПУР", color = Color3.fromRGB(226, 48, 186) },
	{ id = "fuchsia", name = "ФУКСИЯ", color = Color3.fromRGB(255, 64, 168) },
	{ id = "pink", name = "РОЗОВЫЙ", color = Color3.fromRGB(255, 120, 186) },
	{ id = "rose", name = "РОЗА", color = Color3.fromRGB(255, 92, 140) },
	{ id = "peach", name = "ПЕРСИК", color = Color3.fromRGB(255, 168, 128) },
	{ id = "vermilion", name = "КИНОВАРЬ", color = Color3.fromRGB(255, 69, 12) },
	{ id = "tangerine", name = "МАНДАРИН", color = Color3.fromRGB(255, 102, 0) },
	{ id = "sunflower", name = "ПОДСОЛНУХ", color = Color3.fromRGB(255, 196, 0) },
	{ id = "lemon", name = "ЛИМОН", color = Color3.fromRGB(255, 244, 79) },
	{ id = "neon", name = "НЕОН", color = Color3.fromRGB(57, 255, 20) },
	{ id = "apple", name = "ЯБЛОКО", color = Color3.fromRGB(76, 217, 50) },
	{ id = "spring", name = "ВЕСНА", color = Color3.fromRGB(0, 255, 128) },
	{ id = "jade", name = "НЕФРИТ", color = Color3.fromRGB(0, 196, 140) },
	{ id = "aqua", name = "АКВА", color = Color3.fromRGB(0, 255, 204) },
	{ id = "ice", name = "ЛЁД", color = Color3.fromRGB(140, 240, 255) },
	{ id = "cerulean", name = "ЛАЗУРНЫЙ", color = Color3.fromRGB(0, 148, 255) },
	{ id = "royal", name = "КОРОЛЕВСКИЙ", color = Color3.fromRGB(36, 64, 255) },
	{ id = "periwinkle", name = "БАРВИНОК", color = Color3.fromRGB(150, 150, 255) },
	{ id = "lilac", name = "СИРЕНЬ", color = Color3.fromRGB(196, 140, 255) },
	{ id = "orchid", name = "ОРХИДЕЯ", color = Color3.fromRGB(204, 92, 255) },
	{ id = "plum", name = "СЛИВА", color = Color3.fromRGB(156, 32, 196) },
	{ id = "hotpink", name = "ЯРКО-РОЗОВЫЙ", color = Color3.fromRGB(255, 20, 147) },
	{ id = "watermelon", name = "АРБУЗ", color = Color3.fromRGB(255, 71, 102) },
	{ id = "white", name = "БЕЛЫЙ", color = Color3.fromRGB(246, 246, 252) },
	{ id = "black", name = "ЧЁРНЫЙ", color = Color3.fromRGB(38, 36, 48) },
}
Config.COLORS = COLORS
Config.COLORS_PER_MATCH = 8

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

Config.TARGET_FRACTION = { 0.42, 0.50 } -- доля плит, которые остаются в раунде
Config.FAKE_FROM_ROUND = 8
Config.FAKE_CHANCE = 0.2
Config.FAKE_BEFORE_END = 1.5
Config.EXCLUDE_EVERY = 6 -- раунд «любой цвет, кроме…»
Config.DOUBLE_FROM_ROUND = 12
Config.DOUBLE_CHANCE = 0.25
Config.SHRINK_FROM_ROUND = 10
Config.SHRINK_COUNT = { 4, 6 }
Config.COINS_ON_FIELD = { 4, 6 }
Config.COIN_VALUE = 3
Config.BONUS_FROM_ROUND = 1
Config.BONUS_CHANCE = 1

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
