--!strict
-- Два языка. По умолчанию английский. Русский — если локаль игрока начинается с ru.
-- Новые надписи добавляй сюда парой en/ru и показывай через Locale.t или Locale.fmt.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Locale = {}

type Row = { en: string, ru: string }

local ROWS: { Row } = {
	{ en = "Inventory", ru = "Инвентарь" },
	{ en = "Shop", ru = "Магазин" },
	{ en = "Wheel", ru = "Колесо" },
	{ en = "Quests", ru = "Квесты" },
	{ en = "My stuff", ru = "Мои вещи" },
	{ en = "Only what you already bought", ru = "Здесь только то, что уже куплено" },
	{ en = "Nothing yet. Open the Shop tab", ru = "Пока пусто. Открой вкладку «Магазин»" },
	{ en = "Skins", ru = "Скины" },
	{ en = "Perks", ru = "Плюшки" },
	{ en = "Trails", ru = "Следы" },
	{ en = "No skins yet", ru = "Скинов пока нет" },
	{ en = "You can get them in the shop", ru = "Их можно взять в магазине" },
	{ en = "No perks yet", ru = "Плюшек пока нет" },
	{ en = "Match and forever perks are in the shop", ru = "Разовые и вечные лежат в магазине" },
	{ en = "No trails yet", ru = "Следов пока нет" },
	{ en = "Equipped", ru = "Надет" },
	{ en = "Owned", ru = "Куплен" },
	{ en = "Forever", ru = "Навсегда" },
	{ en = "For a match: %d", ru = "На матч: %d" },
	{ en = "Forever, plus %d for a match", ru = "Навсегда, ещё на матч: %d" },
	{ en = "Free", ru = "Бесплатно" },
	{ en = "Tap Take, then do it", ru = "Нажми «Взять», потом сделай" },
	{ en = "Battle Pass", ru = "Батл-пасс" },
	{ en = "Battle Pass — big prizes", ru = "Батл-пасс — крутые призы" },
	{ en = "Battle Pass unlocked", ru = "Батл-пасс открыт" },
	{ en = "Buy  %d R$", ru = "Купить  %d R$" },
	{ en = "Unlocked", ru = "Открыт" },
	{ en = "Loading quests…", ru = "Задания загружаются…" },
	{ en = "Take", ru = "Взять" },
	{ en = "Claim", ru = "Забрать" },
	{ en = "Done", ru = "Готово" },
	{ en = "Locked", ru = "Закрыто" },
	{ en = "Doing", ru = "Делаю" },
	{ en = "%d of %d", ru = "%d из %d" },
	{ en = "Prize: ", ru = "Приз: " },
	{ en = "Wheel of Fortune", ru = "Колесо фортуны" },
	{ en = "One free spin a day. Then coins or Robux.", ru = "Один раз в день бесплатно. Дальше за монеты или робуксы." },
	{ en = "Spinning...", ru = "Крутится..." },
	{ en = "Tomorrow", ru = "Завтра" },
	{ en = "Prize", ru = "Приз" },
	{ en = "Prizes", ru = "Призы" },
	{ en = "Leaders", ru = "Лидеры" },
	{ en = "Match wins", ru = "Победы в матчах" },
	{ en = "No wins yet", ru = "Пока нет побед" },
	{ en = "%d win", ru = "%d победа" },
	{ en = "%d wins", ru = "%d победы" },
	{ en = "%d wins.", ru = "%d побед" },
	{ en = "READY", ru = "ГОТОВ" },
	{ en = "FINDING ARENA", ru = "ИЩЕМ АРЕНУ" },
	{ en = "CANCEL", ru = "ОТМЕНА" },
	{ en = "Auto-ready", ru = "Авто-готов" },
	{ en = "Party", ru = "Пати" },
	{ en = "Watch arena", ru = "Смотреть арену" },
	{ en = "Invite a friend", ru = "Пригласить друга" },
	{ en = "leader", ru = "лидер" },
	{ en = "You", ru = "Ты" },
	{ en = "Arenas are open", ru = "Арены свободны" },
	{ en = "In queue: %d / %d", ru = "В очереди: %d / %d" },
	{ en = "Party of %d · no queue", ru = "Пати из %d · без очереди" },
	{ en = "Looking for a free arena", ru = "Ищем свободную арену" },
	{ en = "Party  ·  %d", ru = "Пати  ·  %d" },
	{ en = "  ·  leader", ru = "  ·  лидер" },
	{ en = "Tap Invite a friend. They get a Roblox notification, join this server, and land in the party.", ru = "Нажми «Пригласить друга». Ему придёт уведомление Roblox, он зайдёт на этот сервер и сразу попадёт в пати." },
	{ en = "%s invites you to a party", ru = "%s зовёт в пати" },
	{ en = "ROUND %d", ru = "РАУНД %d" },
	{ en = "EXCEPT: %s", ru = "КРОМЕ: %s" },
	{ en = "Stand on ANY other color!", ru = "Встань на ЛЮБОЙ другой цвет!" },
	{ en = "Either color works", ru = "Подойдёт любой из двух цветов" },
	{ en = "Stand on this color!", ru = "Встань на этот цвет!" },
	{ en = "Streak ×%.1f", ru = "Серия ×%.1f" },
	{ en = "DRAW", ru = "НИЧЬЯ" },
	{ en = "WINNERS", ru = "ПОБЕДИТЕЛИ" },
	{ en = "WINNER", ru = "ПОБЕДИТЕЛЬ" },
	{ en = "MATCH OVER", ru = "МАТЧ ОКОНЧЕН" },
	{ en = "  %d.  %s   ·   rounds: %d", ru = "  %d.  %s   ·   раундов: %d" },
	{ en = "Players %d", ru = "Игроков %d" },
	{ en = "Left %d / %d", ru = "Осталось %d / %d" },
	{ en = "COLOR CHANGE!", ru = "СМЕНА ЦВЕТА!" },
	{ en = "Tiles are falling…", ru = "Плиты падают…" },
	{ en = "SPECTATING", ru = "ТРАНСЛЯЦИЯ" },
	{ en = "Back  [X]", ru = "Назад  [X]" },
	{ en = "SPECTATING  ·  ARENA %d  ·  %s", ru = "ТРАНСЛЯЦИЯ  ·  АРЕНА %d  ·  %s" },
	{ en = "Search", ru = "Поиск" },
	{ en = "All", ru = "Все" },
	{ en = "Female", ru = "Женские" },
	{ en = "Male", ru = "Мужские" },
	{ en = "Unisex", ru = "Общие" },
	{ en = "Tap a card — the character shows on the left before you buy", ru = "Нажми на карточку — персонаж появится слева до покупки" },
	{ en = "Model isn't in the game yet", ru = "Модель ещё не в игре" },
	{ en = "Stored for a match: %d", ru = "В запасе на матч: %d" },
	{ en = "%d%% off your next coin purchase", ru = "Скидка %d%% на следующую покупку за монеты" },
	{ en = "1 match", ru = "1 матч" },
	{ en = "Bought", ru = "Куплено" },
	{ en = "Equip", ru = "Надеть" },
	{ en = "Wearing", ru = "Надето" },
	{ en = "Open", ru = "Открыть" },
	{ en = "Spin", ru = "Крутить" },
	{ en = "Ready for a match", ru = "Готов к матчу" },
	{ en = "Arena board", ru = "Табло арен" },
	{ en = "Watch arenas", ru = "Смотреть арены" },
	{ en = "Spyglass", ru = "Подзорная труба" },
	{ en = "WHO'S PLAYING", ru = "КТО СЕЙЧАС ИГРАЕТ" },
	{ en = "ARENA", ru = "АРЕНА" },
	{ en = "PLAYERS", ru = "ИГРОКИ" },
	{ en = "Ready    %d / %d", ru = "Готовы к матчу    %d / %d" },
	{ en = "WAITING FOR PLAYERS", ru = "ОЖИДАНИЕ ИГРОКОВ" },
	{ en = "Press READY in the lobby to play", ru = "Нажми ГОТОВ в лобби, чтобы сыграть" },
	{ en = "GET READY", ru = "ПРИГОТОВЬТЕСЬ" },
	{ en = "Players: %d", ru = "Игроков: %d" },
	{ en = "Round %d · stand on ANY other color", ru = "Раунд %d · встань на ЛЮБОЙ другой цвет" },
	{ en = "%s or %s", ru = "%s или %s" },
	{ en = "Round %d · two colors", ru = "Раунд %d · два цвета" },
	{ en = "Round %d · stand on this color!", ru = "Раунд %d · встань на этот цвет!" },
	{ en = "WINNER: %s", ru = "ПОБЕДИТЕЛЬ: %s" },
	{ en = "WINNERS: %d", ru = "ПОБЕДИТЕЛИ: %d" },
	{ en = "Rounds played: %d", ru = "Раундов сыграно: %d" },
	{ en = "Shop is only in the lobby", ru = "Магазин только в лобби" },
	{ en = "Done: %s", ru = "Готово: %s" },
	{ en = "Not enough coins", ru = "Не хватает монет" },
	{ en = "Bought: %s", ru = "Куплено: %s" },
	{ en = "Already forever: %s", ru = "Уже навсегда: %s" },
	{ en = "For 1 match: %s", ru = "На 1 матч: %s" },
	{ en = "Buy it first", ru = "Сначала купи" },
	{ en = "Equipped: %s", ru = "Надето: %s" },
	{ en = "Skin taken off", ru = "Скин снят" },
	{ en = "Trail taken off", ru = "След снят" },
	{ en = "Already owned: %s", ru = "Уже есть: %s" },
	{ en = "For 1 match with Robux: %s", ru = "На 1 матч за робуксы: %s" },
	{ en = "Bought with Robux: %s", ru = "Куплено за робуксы: %s" },
	{ en = "Quest taken", ru = "Задание взято" },
	{ en = "Reward: %s coins", ru = "Награда: %s монет" },
	{ en = "Unlock the Battle Pass first", ru = "Сначала открой батл-пасс" },
	{ en = "Battle Pass is already open", ru = "Батл-пасс уже открыт" },
	{ en = "Robux: create a Developer Product for 300 R$ and put its id in Shop under battlepass", ru = "Робуксы: создай Developer Product на 300 R$ и впиши id в Shop под ключом battlepass" },
	{ en = "Wheel is only in the lobby", ru = "Колесо только в лобби" },
	{ en = "The wheel is still spinning", ru = "Колесо ещё крутится" },
	{ en = "The free spin was already used today", ru = "Бесплатный спин уже был сегодня" },
	{ en = "You can't spin like that", ru = "Так крутить нельзя" },
	{ en = "Friend already left", ru = "Друг уже вышел" },
	{ en = "Someone is already in a match", ru = "Кто-то уже в матче" },
	{ en = "Party is full", ru = "Пати полное" },
	{ en = "Waiting until the whole party leaves the match", ru = "Ждём, пока вся пати выйдет из матча" },
	{ en = "Arenas were not found", ru = "Арены не найдены" },
	{ en = "That player is already in a match", ru = "Игрок уже в матче" },
	{ en = "Only the leader can invite", ru = "Приглашает только лидер" },
	{ en = "Already in the party", ru = "Уже в пати" },
	{ en = "Invite sent", ru = "Приглашение отправлено" },
	{ en = "That invite is no longer valid", ru = "Приглашение уже не действует" },
	{ en = "Your friend already left the server", ru = "Друг уже вышел с сервера" },
	{ en = "You are in a party with %s", ru = "Ты в пати с %s" },
	{ en = "%s joined the party", ru = "%s теперь в пати" },
	{ en = "Server is full. If your friend is already playing, press Join them", ru = "Сервер полный. Если друг уже играет, нажми «К нему»" },
	{ en = "Friend invites open in a published game", ru = "Приглашение друзей откроется в опубликованной игре" },
	{ en = "Couldn't open the invite", ru = "Не удалось открыть приглашение" },
	{ en = "Come play Color Party with me", ru = "Заходи в Color Party, сыграем вместе" },
	{ en = "Friend", ru = "Друг" },
	{ en = "Leave the match first", ru = "Сначала выйди из матча" },
	{ en = "Your friend is no longer on another server", ru = "Друг уже не на другом сервере" },
	{ en = "Couldn't join your friend", ru = "Не удалось перейти к другу" },
	{ en = "The leader removed you from the party", ru = "Лидер убрал тебя из пати" },
	{ en = "Join them", ru = "К нему" },
	{ en = "Leave", ru = "Выйти" },
	{ en = "Kick", ru = "Убрать" },
	{ en = "%s coins", ru = "%s монет" },
	{ en = "Run the parkour", ru = "Пройти паркур" },
	{ en = "Reach the end of the course", ru = "Доберись до финиша полосы" },
	{ en = "Win a match", ru = "Победа в матче" },
	{ en = "Win one game", ru = "Выиграй одну игру" },
	{ en = "Two wins", ru = "Две победы" },
	{ en = "Win two matches", ru = "Выиграй два матча" },
	{ en = "Three shields", ru = "Три щита" },
	{ en = "Pick up shields in the arenas", ru = "Подбери щиты на аренах" },
	{ en = "Three dashes", ru = "Три ускорителя" },
	{ en = "Pick up dash bolts", ru = "Подбери молнии ускорения" },
	{ en = "Arena coins", ru = "Монеты с арены" },
	{ en = "Collect coins in matches", ru = "Собери монеты в матчах" },
	{ en = "Course master", ru = "Мастер полосы" },
	{ en = "Finish the parkour 3 times", ru = "Пройди паркур 3 раза" },
	{ en = "Random skin", ru = "Случайный скин" },
	{ en = "Win streak", ru = "Серия побед" },
	{ en = "Win 8 matches", ru = "Выиграй 8 матчей" },
	{ en = "Random trail", ru = "Случайный след" },
	{ en = "Shield wall", ru = "Стена щитов" },
	{ en = "Collect 15 shields", ru = "Собери 15 щитов" },
	{ en = "Pocket Dome forever", ru = "Карманный купол навсегда" },
	{ en = "Endless spark", ru = "Искра без конца" },
	{ en = "Collect 15 dashes", ru = "Собери 15 ускорителей" },
	{ en = "Tailwind forever", ru = "Попутный ветер навсегда" },
	{ en = "Lobby crown", ru = "Корона лобби" },
	{ en = "Win 12 matches", ru = "Выиграй 12 матчей" },
	{ en = "Random perk forever", ru = "Случайная плюшка навсегда" },
	{ en = "Cat Jump", ru = "Прыжок кота" },
	{ en = "Pocket Dome", ru = "Карманный купол" },
	{ en = "Spark", ru = "Искра" },
	{ en = "Ninth Life", ru = "Девятая жизнь" },
	{ en = "Tailwind", ru = "Попутный ветер" },
	{ en = "Coin Magnet", ru = "Монетный магнит" },
	{ en = "Second Wind", ru = "Второе дыхание" },
	{ en = "Thunder Strike", ru = "Громовой удар" },
	{ en = "Salute", ru = "Салют" },
	{ en = "Rainbow Trail", ru = "Радужный след" },
	{ en = "Fire Trail", ru = "Огненный след" },
	{ en = "Ice Trail", ru = "Ледяной след" },
	{ en = "Gold Trail", ru = "Золотой след" },
	{ en = "Toxic Trail", ru = "Ядовитый след" },
	{ en = "Candy Trail", ru = "Конфетный след" },
	{ en = "Storm Trail", ru = "Грозовой след" },
	{ en = "Sakura", ru = "Сакура" },
	{ en = "Light hair and sakura petals", ru = "Светлые волосы и лепестки сакуры" },
	{ en = "Hoodie", ru = "Худи" },
	{ en = "Pink hoodie and dark jeans", ru = "Розовое худи и тёмные джинсы" },
	{ en = "Gothic", ru = "Готика" },
	{ en = "Hat, ribbons, and a dark outfit", ru = "Шляпа, ленты и тёмный наряд" },
	{ en = "Night", ru = "Ночь" },
	{ en = "Black hair and horns", ru = "Чёрные волосы и рога" },
	{ en = "Neko", ru = "Кошка" },
	{ en = "Cat ears and a black outfit", ru = "Кошачьи уши и чёрный наряд" },
	{ en = "Jacket", ru = "Куртка" },
	{ en = "City jacket and sneakers", ru = "Городская куртка и кроссовки" },
	{ en = "Summer", ru = "Лето" },
	{ en = "Teal jacket and grey jeans", ru = "Бирюзовая куртка и серые джинсы" },
	{ en = "Glasses", ru = "Очки" },
	{ en = "Black suit and round glasses", ru = "Чёрный костюм и круглые очки" },
	{ en = "Visor", ru = "Козырёк" },
	{ en = "Blue jacket, visor, and a bag", ru = "Синяя куртка, козырёк и сумка" },
	{ en = "Emerald", ru = "Изумруд" },
	{ en = "Green armor", ru = "Зелёные латы" },
	{ en = "1,500 coins", ru = "1 500 монет" },
	{ en = "One coin for your balance", ru = "Одна монета на счёт" },
	{ en = "Random perk", ru = "Случайная плюшка" },
	{ en = "Perk", ru = "Плюшка" },
	{ en = "A forever perk. The rarest prize", ru = "Плюшка навсегда. Самый редкий приз" },
	{ en = "4,000 coins", ru = "4 000 монет" },
	{ en = "A small pile of coins", ru = "Небольшая пачка монет" },
	{ en = "Trail", ru = "След" },
	{ en = "A trail you don't have yet. Rare prize", ru = "След, которого ещё нет. Редкий приз" },
	{ en = "Match effect", ru = "Эффект на матч" },
	{ en = "Match", ru = "Матч" },
	{ en = "A random perk for one match, then it fades", ru = "Случайная плюшка на один матч, потом гаснет" },
	{ en = "Skin", ru = "Скин" },
	{ en = "A skin you don't have yet. Question mark on the mannequin", ru = "Скин, которого ещё нет. На манекене знак вопроса" },
	{ en = "30% off", ru = "Скидка 30%" },
	{ en = "Your next coin shop purchase is 30% cheaper", ru = "Следующая покупка в магазине за монеты дешевле на 30%" },
	{ en = "12,000 coins", ru = "12 000 монет" },
	{ en = "A big stack of coins", ru = "Большая стопка монет" },
	{ en = "RED", ru = "КРАСНЫЙ" },
	{ en = "CRIMSON", ru = "АЛЫЙ" },
	{ en = "CORAL", ru = "КОРАЛЛ" },
	{ en = "ORANGE", ru = "ОРАНЖЕВЫЙ" },
	{ en = "AMBER", ru = "ЯНТАРЬ" },
	{ en = "YELLOW", ru = "ЖЁЛТЫЙ" },
	{ en = "GOLD", ru = "ЗОЛОТОЙ" },
	{ en = "LIME", ru = "ЛАЙМ" },
	{ en = "CHARTREUSE", ru = "САЛАТ" },
	{ en = "GREEN", ru = "ЗЕЛЁНЫЙ" },
	{ en = "EMERALD", ru = "ИЗУМРУД" },
	{ en = "MINT", ru = "МЯТА" },
	{ en = "TEAL", ru = "МОРСКОЙ" },
	{ en = "CYAN", ru = "БИРЮЗА" },
	{ en = "SKY", ru = "ГОЛУБОЙ" },
	{ en = "AZURE", ru = "ЛАЗУРЬ" },
	{ en = "BLUE", ru = "СИНИЙ" },
	{ en = "COBALT", ru = "КОБАЛЬТ" },
	{ en = "INDIGO", ru = "ИНДИГО" },
	{ en = "VIOLET", ru = "ФИАЛКА" },
	{ en = "PURPLE", ru = "ФИОЛЕТ" },
	{ en = "MAGENTA", ru = "ПУРПУР" },
	{ en = "FUCHSIA", ru = "ФУКСИЯ" },
	{ en = "PINK", ru = "РОЗОВЫЙ" },
	{ en = "ROSE", ru = "РОЗА" },
	{ en = "PEACH", ru = "ПЕРСИК" },
	{ en = "VERMILION", ru = "КИНОВАРЬ" },
	{ en = "TANGERINE", ru = "МАНДАРИН" },
	{ en = "SUNFLOWER", ru = "ПОДСОЛНУХ" },
	{ en = "LEMON", ru = "ЛИМОН" },
	{ en = "NEON", ru = "НЕОН" },
	{ en = "APPLE", ru = "ЯБЛОКО" },
	{ en = "SPRING", ru = "ВЕСНА" },
	{ en = "JADE", ru = "НЕФРИТ" },
	{ en = "AQUA", ru = "АКВА" },
	{ en = "ICE", ru = "ЛЁД" },
	{ en = "CERULEAN", ru = "ЛАЗУРНЫЙ" },
	{ en = "ROYAL", ru = "КОРОЛЕВСКИЙ" },
	{ en = "PERIWINKLE", ru = "БАРВИНОК" },
	{ en = "LILAC", ru = "СИРЕНЬ" },
	{ en = "ORCHID", ru = "ОРХИДЕЯ" },
	{ en = "PLUM", ru = "СЛИВА" },
	{ en = "HOT PINK", ru = "ЯРКО-РОЗОВЫЙ" },
	{ en = "WATERMELON", ru = "АРБУЗ" },
	{ en = "WHITE", ru = "БЕЛЫЙ" },
	{ en = "BLACK", ru = "ЧЁРНЫЙ" },
	{ en = "Yes", ru = "Да" },
	{ en = "No", ru = "Нет" },
	{ en = "Leave the party", ru = "Выйти из пати" },
	{ en = "Friends on other servers", ru = "Друзья на других серверах" },
	{ en = "Looking for friends in game...", ru = "Ищем друзей в игре..." },
	{ en = "People already in this lobby", ru = "Кто уже в этом лобби" },
	{ en = "Invite", ru = "Звать" },
	{ en = "Every arena is full — waiting for one", ru = "Все арены заняты — ждём свободную" },
	{ en = "Matches running: %d of %d", ru = "Идёт матчей: %d из %d" },
	{ en = "  ·  starting in %d s", ru = "  ·  старт через %d с" },
	{ en = "match on", ru = "идёт матч" },
	{ en = "waiting for players", ru = "ожидание игроков" },
	{ en = "Player", ru = "Игрок" },
	{ en = "  ·  you", ru = "  ·  ты" },
	{ en = "1 of %d%%", ru = "из %d%%" },
	{ en = "LIFE LOST", ru = "МИНУС ЖИЗНЬ" },
	{ en = "You're on the lower floor. One more fall and you're out!", ru = "Ты на нижнем этаже. Ещё одно падение — вылет!" },
	{ en = "Returning to the lobby…", ru = "Возвращение в лобби…" },
	{ en = "Players: %d  ·  stand on the card color before the timer ends", ru = "Игроков: %d  ·  встань на цвет с карточки до конца таймера" },
	{ en = "ANYTHING BUT %s", ru = "ЛЮБОЙ, КРОМЕ %s" },
	{ en = "Don't stand on that color!", ru = "Не стой на этом цвете!" },
	{ en = "TWO COLORS", ru = "ДВА ЦВЕТА" },
	{ en = "Either of the two works", ru = "Подойдёт любой из двух" },
	{ en = "Now you need: %s", ru = "Теперь нужен: %s" },
	{ en = "YOU'RE OUT", ru = "ТЫ ВЫБЫЛ" },
	{ en = "Place: %d  ·  watch the match or press X", ru = "Место: %d  ·  смотри матч до конца или нажми X" },
	{ en = "Dash", ru = "Рывок" },
	{ en = "Shield", ru = "Щит" },
	{ en = "A shield is on the arena — pick it up", ru = "На арене щит — подбери его" },
	{ en = "A dash is on the arena — pick up the bolt", ru = "На арене рывок — подбери молнию" },
	{ en = "Arena is shrinking! Tiles gone: %d", ru = "Арена сжимается! Исчезло плит: %d" },
	{ en = "%s left the match  Left: %d", ru = "%s покинул матч  Осталось: %d" },
	{ en = "%s is out!  Left: %d", ru = "%s выбыл!  Осталось: %d" },
	{ en = "%s dropped to the lower floor!", ru = "%s упал на нижний этаж!" },
	{ en = "Match starting! Players: %d", ru = "Матч начинается! Игроков: %d" },
	{ en = "%s wins!", ru = "%s побеждает!" },
	{ en = "Match over!", ru = "Матч окончен!" },
	{ en = "%s clings to a ninth life!", ru = "%s цепляется за девятую жизнь!" },
	{ en = "%s is back!", ru = "%s воскрес!" },
	{ en = "Coins are already on your balance", ru = "Монеты уже на счету" },
	{ en = "Every skin is already yours, so this is coins instead", ru = "Все скины уже есть, вместо скина — монеты" },
	{ en = "The skin is equipped. It's in the shop, on the Skins tab", ru = "Скин надет. Он в магазине, во вкладке скинов" },
	{ en = "Every perk is already forever, so this is coins instead", ru = "Все плюшки уже навсегда, вместо эффекта — монеты" },
	{ en = "A one-match charge is already in the shop, on the perk icon", ru = "Заряд на один матч уже в магазине, на иконке плюшки" },
	{ en = "Every trail is already yours, so this is coins instead", ru = "Все следы уже есть, вместо следа — монеты" },
	{ en = "The trail is equipped. It's in the shop, on the Trails tab", ru = "След надет. Он в магазине, во вкладке «Следы»" },
	{ en = "Every perk is already forever, so this prize is coins", ru = "Все плюшки уже навсегда, вместо приза — монеты" },
	{ en = "The perk is already in the shop and turned on", ru = "Плюшка уже в магазине и включена" },
	{ en = "Paid with Robux. %s", ru = "Оплачено робуксами. %s" },
	{ en = "6,000 coins", ru = "6 000 монет" },
	{ en = "20,000 coins — you already have every skin", ru = "20 000 монет — все скины уже есть" },
	{ en = "Skin: %s", ru = "Скин: %s" },
	{ en = "12,000 coins — you already have every trail", ru = "12 000 монет — все следы уже есть" },
	{ en = "Trail: %s", ru = "След: %s" },
	{ en = "15,000 coins — you already have that perk", ru = "15 000 монет — плюшка уже есть" },
	{ en = "Perk: %s", ru = "Плюшка: %s" },
	{ en = "25,000 coins — you already have every perk", ru = "25 000 монет — все плюшки уже есть" },
	{ en = "Robux: create a Developer Product and put its id in Shop under %s. Price %d R$", ru = "Робуксы: создай Developer Product и впиши id в Shop под ключом %s. Цена %d R$" },
	{ en = "Robux: create a Developer Product and put its id in Shop.luau. Price %d R$", ru = "Робуксы: создай Developer Product и впиши id в Shop.luau. Цена %d R$" },
	{ en = "Robux: create a Developer Product and put its id in Shop under wheel. Price %d R$", ru = "Робуксы: создай Developer Product и впиши id в Shop под ключом wheel. Цена %d R$" },
	{ en = "Wheel\nof fortune", ru = "Колесо\nфортуны" },
	{ en = "Win", ru = "Победа" },
	{ en = "Streak", ru = "Серия" },
	{ en = "Coins", ru = "Монеты" },
	{ en = "Claimed", ru = "Забрано" },
	{ en = "Reward", ru = "Награда" },
	{ en = "A second jump in the air, in the lobby and in a match", ru = "Второй прыжок в воздухе, в лобби и в матче" },
	{ en = "You start every match with a shield", ru = "Каждый матч начинаешь со щитом" },
	{ en = "Press Q in a match: a short save from a fall", ru = "Клавиша Q в матче: короткое спасение от падения" },
	{ en = "One extra life in every match", ru = "На одну жизнь больше в каждом матче" },
	{ en = "You run noticeably faster", ru = "Бежишь заметно быстрее" },
	{ en = "Arena coins pay twice as much", ru = "Монетки на арене приносят вдвое больше" },
	{ en = "Once a match you return after being eliminated", ru = "Один раз за матч возвращаешься на арену после выбывания" },
	{ en = "Lightning crashes where you get eliminated", ru = "В месте смерти бьёт молния с грохотом" },
	{ en = "When you win, a big salute bursts over the arena", ru = "Когда побеждаешь, над ареной вспыхивает большой салют" },
	{ en = "A rainbow follows you", ru = "За спиной тянется радуга" },
	{ en = "A burning tail", ru = "Горящий хвост" },
	{ en = "A cold blue trail", ru = "Холодный голубой шлейф" },
	{ en = "Soft gold", ru = "Мягкое золото" },
	{ en = "Acid green", ru = "Кислотно-зелёный" },
	{ en = "Pink and white", ru = "Розовый и белый" },
	{ en = "Purple lightning", ru = "Фиолетовые молнии" },
	{ en = "LAVA", ru = "ЛАВА" },
	{ en = "COLOR PARTY  ·  ARENA %d", ru = "COLOR PARTY  ·  АРЕНА %d" },
	{ en = "JUMP", ru = "ПРЫЖОК" },
	{ en = "REWARD", ru = "НАГРАДА" },
	{ en = "BACK TO LOBBY", ru = "НАЗАД В ЛОББИ" },
	{ en = "Couldn't load your save. Join again in a moment.", ru = "Не удалось загрузить сохранение. Зайди ещё раз через минуту." },
	{ en = "Your save is still open on another server. Wait a moment and join again.", ru = "Сохранение ещё открыто на другом сервере. Подожди немного и зайди снова." },
}

local INDEX: { [string]: Row } = {}
for _, row in ROWS do
	INDEX[row.en] = row
	if row.ru ~= row.en then
		INDEX[row.ru] = row
	end
end

local function codeOf(localeId: string?): string
	if typeof(localeId) ~= "string" then
		return "en"
	end
	local lower = string.lower(localeId)
	if string.sub(lower, 1, 2) == "ru" then
		return "ru"
	end
	return "en"
end

function Locale.code(localeId: string?): string
	return codeOf(localeId)
end

function Locale.language(): string
	if RunService:IsClient() then
		local player = Players.LocalPlayer
		if player then
			return codeOf(player.LocaleId)
		end
	end
	return "en"
end

function Locale.forPlayer(player: Player, phrase: string, ...: any): string
	local row = INDEX[phrase]
	local pattern = if row then row[codeOf(player.LocaleId)] else phrase
	if select("#", ...) > 0 then
		return string.format(pattern, ...)
	end
	return pattern
end

function Locale.t(phrase: string): string
	local row = INDEX[phrase]
	if not row then
		return phrase
	end
	return row[Locale.language()]
end

function Locale.fmt(phrase: string, ...: any): string
	return string.format(Locale.t(phrase), ...)
end

function Locale.wins(amount: number): string
	local n = math.max(0, math.floor(amount))
	if Locale.language() ~= "ru" then
		return string.format(if n == 1 then "%d win" else "%d wins", n)
	end
	local n10 = n % 10
	local n100 = n % 100
	local word = "побед"
	if n10 == 1 and n100 ~= 11 then
		word = "победа"
	elseif n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14) then
		word = "победы"
	end
	return tostring(n) .. " " .. word
end

function Locale.translate(text: string): string
	if text == "" then
		return text
	end
	local row = INDEX[text]
	if row then
		return row[Locale.language()]
	end
	local partyArena = string.match(text, "^COLOR PARTY  ·  ARENA (%d+)$") or string.match(text, "^COLOR PARTY  ·  АРЕНА (%d+)$")
	if partyArena then
		return Locale.fmt("COLOR PARTY  ·  ARENA %d", tonumber(partyArena) or 0)
	end
	local arena = string.match(text, "^Arena%s+(%d+)$") or string.match(text, "^Арена%s+(%d+)$")
	if arena then
		return (if Locale.language() == "ru" then "Арена  " else "Arena  ") .. arena
	end
	local readyA, readyB = string.match(text, "^Ready%s+(%d+)%s*/%s*(%d+)$")
	if not readyA then
		readyA, readyB = string.match(text, "^Готовы к матчу%s+(%d+)%s*/%s*(%d+)$")
	end
	if readyA and readyB then
		return Locale.fmt("Ready    %d / %d", tonumber(readyA) or 0, tonumber(readyB) or 0)
	end
	local except = string.match(text, "^EXCEPT: (.+)$") or string.match(text, "^КРОМЕ: (.+)$")
	if except then
		return Locale.fmt("EXCEPT: %s", Locale.t(except))
	end
	local roundAny = string.match(text, "^Round (%d+) · stand on ANY other color$")
		or string.match(text, "^Раунд (%d+) · встань на ЛЮБОЙ другой цвет$")
	if roundAny then
		return Locale.fmt("Round %d · stand on ANY other color", tonumber(roundAny) or 0)
	end
	local roundTwo = string.match(text, "^Round (%d+) · two colors$") or string.match(text, "^Раунд (%d+) · два цвета$")
	if roundTwo then
		return Locale.fmt("Round %d · two colors", tonumber(roundTwo) or 0)
	end
	local roundThis = string.match(text, "^Round (%d+) · stand on this color!$")
		or string.match(text, "^Раунд (%d+) · встань на этот цвет!$")
	if roundThis then
		return Locale.fmt("Round %d · stand on this color!", tonumber(roundThis) or 0)
	end
	local leftName, rightName = string.match(text, "^(.+) or (.+)$")
	if not leftName then
		leftName, rightName = string.match(text, "^(.+) или (.+)$")
	end
	if leftName and rightName and INDEX[leftName] and INDEX[rightName] then
		return Locale.fmt("%s or %s", Locale.t(leftName), Locale.t(rightName))
	end
	local playersN = string.match(text, "^Players: (%d+)$") or string.match(text, "^Игроков: (%d+)$")
	if playersN then
		return Locale.fmt("Players: %d", tonumber(playersN) or 0)
	end
	local winnerName = string.match(text, "^WINNER: (.+)$") or string.match(text, "^ПОБЕДИТЕЛЬ: (.+)$")
	if winnerName then
		return Locale.fmt("WINNER: %s", winnerName)
	end
	local winnersN = string.match(text, "^WINNERS: (%d+)$") or string.match(text, "^ПОБЕДИТЕЛИ: (%d+)$")
	if winnersN then
		return Locale.fmt("WINNERS: %d", tonumber(winnersN) or 0)
	end
	local roundsN = string.match(text, "^Rounds played: (%d+)$") or string.match(text, "^Раундов сыграно: (%d+)$")
	if roundsN then
		return Locale.fmt("Rounds played: %d", tonumber(roundsN) or 0)
	end
	local shrinkN = string.match(text, "^Arena is shrinking! Tiles gone: (%d+)$")
		or string.match(text, "^Арена сжимается! Исчезло плит: (%d+)$")
	if shrinkN then
		return Locale.fmt("Arena is shrinking! Tiles gone: %d", tonumber(shrinkN) or 0)
	end
	local leftWho, leftN = string.match(text, "^(.+) left the match  Left: (%d+)$")
	if not leftWho then
		leftWho, leftN = string.match(text, "^(.+) покинул матч  Осталось: (%d+)$")
	end
	if leftWho and leftN then
		return Locale.fmt("%s left the match  Left: %d", leftWho, tonumber(leftN) or 0)
	end
	local outWho, outN = string.match(text, "^(.+) is out!  Left: (%d+)$")
	if not outWho then
		outWho, outN = string.match(text, "^(.+) выбыл!  Осталось: (%d+)$")
	end
	if outWho and outN then
		return Locale.fmt("%s is out!  Left: %d", outWho, tonumber(outN) or 0)
	end
	local fellWho = string.match(text, "^(.+) dropped to the lower floor!$") or string.match(text, "^(.+) упал на нижний этаж!$")
	if fellWho then
		return Locale.fmt("%s dropped to the lower floor!", fellWho)
	end
	local startN = string.match(text, "^Match starting! Players: (%d+)$") or string.match(text, "^Матч начинается! Игроков: (%d+)$")
	if startN then
		return Locale.fmt("Match starting! Players: %d", tonumber(startN) or 0)
	end
	local winWho = string.match(text, "^(.+) wins!$") or string.match(text, "^(.+) побеждает!$")
	if winWho then
		return Locale.fmt("%s wins!", winWho)
	end
	local lifeWho = string.match(text, "^(.+) clings to a ninth life!$") or string.match(text, "^(.+) цепляется за девятую жизнь!$")
	if lifeWho then
		return Locale.fmt("%s clings to a ninth life!", lifeWho)
	end
	local backWho = string.match(text, "^(.+) is back!$") or string.match(text, "^(.+) воскрес!$")
	if backWho then
		return Locale.fmt("%s is back!", backWho)
	end
	local coinAmount = string.match(text, "^(%d[%d ]*) coins$") or string.match(text, "^(%d[%d ]*) монет$")
	if coinAmount then
		return Locale.fmt("%s coins", coinAmount)
	end
	local rewardCoins = string.match(text, "^Reward: (.+) coins$") or string.match(text, "^Награда: (.+) монет$")
	if rewardCoins then
		return Locale.fmt("Reward: %s coins", rewardCoins)
	end
	local skinName = string.match(text, "^Skin: (.+)$") or string.match(text, "^Скин: (.+)$")
	if skinName then
		return Locale.fmt("Skin: %s", Locale.t(skinName))
	end
	local trailName = string.match(text, "^Trail: (.+)$") or string.match(text, "^След: (.+)$")
	if trailName then
		return Locale.fmt("Trail: %s", Locale.t(trailName))
	end
	local perkName = string.match(text, "^Perk: (.+)$") or string.match(text, "^Плюшка: (.+)$")
	if perkName then
		return Locale.fmt("Perk: %s", Locale.t(perkName))
	end
	return text
end

local painting = false

local function paintOne(inst: Instance)
	if painting then
		return
	end
	painting = true
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		local nextText = Locale.translate(inst.Text)
		if nextText ~= inst.Text then
			inst.Text = nextText
		end
		if inst:IsA("TextBox") then
			local nextHolder = Locale.translate(inst.PlaceholderText)
			if nextHolder ~= inst.PlaceholderText then
				inst.PlaceholderText = nextHolder
			end
		end
	elseif inst:IsA("ProximityPrompt") then
		local objectText = Locale.translate(inst.ObjectText)
		local actionText = Locale.translate(inst.ActionText)
		if objectText ~= inst.ObjectText then
			inst.ObjectText = objectText
		end
		if actionText ~= inst.ActionText then
			inst.ActionText = actionText
		end
	end
	painting = false
end

function Locale.install()
	if not RunService:IsClient() then
		return
	end
	local function hook(inst: Instance)
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") or inst:IsA("ProximityPrompt") then
			paintOne(inst)
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				inst:GetPropertyChangedSignal("Text"):Connect(function()
					paintOne(inst)
				end)
			elseif inst:IsA("ProximityPrompt") then
				inst:GetPropertyChangedSignal("ObjectText"):Connect(function()
					paintOne(inst)
				end)
				inst:GetPropertyChangedSignal("ActionText"):Connect(function()
					paintOne(inst)
				end)
			end
		end
	end
	for _, inst in workspace:GetDescendants() do
		hook(inst)
	end
	workspace.DescendantAdded:Connect(hook)
end

return Locale
