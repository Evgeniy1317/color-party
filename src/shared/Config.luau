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
	-- Дальний ряд: пати не ждёт, пока освободится одна из ближних арен.
	Vector3.new(-460, 70, 1320),
	Vector3.new(460, 70, 1320),
	Vector3.new(0, 94, 1600),
	Vector3.new(-860, 52, 700),
	Vector3.new(860, 52, 700),
	Vector3.new(0, 80, 2060),
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
	{ id = "red", name = "RED", color = Color3.fromRGB(235, 55, 62) },
	{ id = "crimson", name = "CRIMSON", color = Color3.fromRGB(196, 28, 58) },
	{ id = "coral", name = "CORAL", color = Color3.fromRGB(255, 112, 92) },
	{ id = "orange", name = "ORANGE", color = Color3.fromRGB(255, 140, 28) },
	{ id = "amber", name = "AMBER", color = Color3.fromRGB(255, 176, 42) },
	{ id = "yellow", name = "YELLOW", color = Color3.fromRGB(255, 214, 36) },
	{ id = "gold", name = "GOLD", color = Color3.fromRGB(232, 176, 28) },
	{ id = "lime", name = "LIME", color = Color3.fromRGB(168, 230, 42) },
	{ id = "chartreuse", name = "CHARTREUSE", color = Color3.fromRGB(124, 214, 48) },
	{ id = "green", name = "GREEN", color = Color3.fromRGB(42, 196, 86) },
	{ id = "emerald", name = "EMERALD", color = Color3.fromRGB(16, 168, 120) },
	{ id = "mint", name = "MINT", color = Color3.fromRGB(72, 230, 176) },
	{ id = "teal", name = "TEAL", color = Color3.fromRGB(18, 176, 176) },
	{ id = "cyan", name = "CYAN", color = Color3.fromRGB(36, 214, 232) },
	{ id = "sky", name = "SKY", color = Color3.fromRGB(72, 168, 255) },
	{ id = "azure", name = "AZURE", color = Color3.fromRGB(28, 132, 245) },
	{ id = "blue", name = "BLUE", color = Color3.fromRGB(52, 86, 235) },
	{ id = "cobalt", name = "COBALT", color = Color3.fromRGB(36, 58, 196) },
	{ id = "indigo", name = "INDIGO", color = Color3.fromRGB(92, 64, 214) },
	{ id = "violet", name = "VIOLET", color = Color3.fromRGB(138, 72, 232) },
	{ id = "purple", name = "PURPLE", color = Color3.fromRGB(168, 64, 220) },
	{ id = "magenta", name = "MAGENTA", color = Color3.fromRGB(226, 48, 186) },
	{ id = "fuchsia", name = "FUCHSIA", color = Color3.fromRGB(255, 64, 168) },
	{ id = "pink", name = "PINK", color = Color3.fromRGB(255, 120, 186) },
	{ id = "rose", name = "ROSE", color = Color3.fromRGB(255, 92, 140) },
	{ id = "peach", name = "PEACH", color = Color3.fromRGB(255, 168, 128) },
	{ id = "vermilion", name = "VERMILION", color = Color3.fromRGB(255, 69, 12) },
	{ id = "tangerine", name = "TANGERINE", color = Color3.fromRGB(255, 102, 0) },
	{ id = "sunflower", name = "SUNFLOWER", color = Color3.fromRGB(255, 196, 0) },
	{ id = "lemon", name = "LEMON", color = Color3.fromRGB(255, 244, 79) },
	{ id = "neon", name = "NEON", color = Color3.fromRGB(57, 255, 20) },
	{ id = "apple", name = "APPLE", color = Color3.fromRGB(76, 217, 50) },
	{ id = "spring", name = "SPRING", color = Color3.fromRGB(0, 255, 128) },
	{ id = "jade", name = "JADE", color = Color3.fromRGB(0, 196, 140) },
	{ id = "aqua", name = "AQUA", color = Color3.fromRGB(0, 255, 204) },
	{ id = "ice", name = "ICE", color = Color3.fromRGB(140, 240, 255) },
	{ id = "cerulean", name = "CERULEAN", color = Color3.fromRGB(0, 148, 255) },
	{ id = "royal", name = "ROYAL", color = Color3.fromRGB(36, 64, 255) },
	{ id = "periwinkle", name = "PERIWINKLE", color = Color3.fromRGB(150, 150, 255) },
	{ id = "lilac", name = "LILAC", color = Color3.fromRGB(196, 140, 255) },
	{ id = "orchid", name = "ORCHID", color = Color3.fromRGB(204, 92, 255) },
	{ id = "plum", name = "PLUM", color = Color3.fromRGB(156, 32, 196) },
	{ id = "hotpink", name = "HOT PINK", color = Color3.fromRGB(255, 20, 147) },
	{ id = "watermelon", name = "WATERMELON", color = Color3.fromRGB(255, 71, 102) },
	{ id = "white", name = "WHITE", color = Color3.fromRGB(246, 246, 252) },
	{ id = "black", name = "BLACK", color = Color3.fromRGB(38, 36, 48) },
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

Config.TARGET_FRACTION = { 0.28, 0.34 } -- доля плит, которые остаются в раунде
Config.FAKE_FROM_ROUND = 8
Config.FAKE_CHANCE = 0.2
Config.FAKE_BEFORE_END = 1.5
Config.EXCLUDE_EVERY = 6 -- раунд «любой цвет, кроме…»
Config.DOUBLE_FROM_ROUND = 12
Config.DOUBLE_CHANCE = 0.25
Config.SHRINK_FROM_ROUND = 10
Config.SHRINK_COUNT = { 4, 6 }
Config.COINS_ON_FIELD = { 4, 6 }
Config.COIN_VALUE = 10
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
