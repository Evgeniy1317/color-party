--!strict
-- Скины из тулбокса. Модели лежат в ReplicatedStorage.SkinModels.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skins = {}

export type Category = "male" | "female" | "unisex"

export type Skin = {
	id: string,
	name: string,
	category: Category,
	price: number,
	blurb: string,
	asset: number,
}

local LIST: { Skin } = {
	{ id = "sakura", name = "Сакура", category = "female", price = 12000, blurb = "Светлые волосы и лепестки сакуры", asset = 125685551242959 },
	{ id = "hoodie", name = "Худи", category = "female", price = 8000, blurb = "Розовое худи и тёмные джинсы", asset = 112633262552629 },
	{ id = "gothic", name = "Готика", category = "female", price = 18000, blurb = "Шляпа, ленты и тёмный наряд", asset = 72363006872822 },
	{ id = "night", name = "Ночь", category = "female", price = 15000, blurb = "Чёрные волосы и рога", asset = 129459713841790 },
	{ id = "neko", name = "Кошка", category = "female", price = 14000, blurb = "Кошачьи уши и чёрный наряд", asset = 17545998689 },
	{ id = "city", name = "Куртка", category = "male", price = 11000, blurb = "Городская куртка и кроссовки", asset = 14957799952 },
	{ id = "summer", name = "Лето", category = "female", price = 13000, blurb = "Бирюзовая куртка и серые джинсы", asset = 104635170766402 },
	{ id = "specs", name = "Очки", category = "unisex", price = 15000, blurb = "Чёрный костюм и круглые очки", asset = 128135767367443 },
	{ id = "dood", name = "Козырёк", category = "male", price = 18000, blurb = "Синяя куртка, козырёк и сумка", asset = 10979055843 },
	{ id = "emerald", name = "Изумруд", category = "unisex", price = 17000, blurb = "Зелёные латы", asset = 8175455331 },
}

local BY_ID: { [string]: Skin } = {}
for _, skin in LIST do
	BY_ID[skin.id] = skin
end

function Skins.all(): { Skin }
	return LIST
end

function Skins.get(id: string): Skin?
	return BY_ID[id]
end

function Skins.model(id: string): Model?
	if not BY_ID[id] then
		return nil
	end
	local folder = ReplicatedStorage:FindFirstChild("SkinModels")
	local model = folder and folder:FindFirstChild(id)
	if model and model:IsA("Model") then
		return model
	end
	return nil
end

return Skins
