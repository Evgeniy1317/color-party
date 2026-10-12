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
	{ id = "sakura", name = "Sakura", category = "female", price = 12000, blurb = "Light hair and sakura petals", asset = 125685551242959 },
	{ id = "hoodie", name = "Hoodie", category = "female", price = 8000, blurb = "Pink hoodie and dark jeans", asset = 112633262552629 },
	{ id = "gothic", name = "Gothic", category = "female", price = 18000, blurb = "Hat, ribbons, and a dark outfit", asset = 72363006872822 },
	{ id = "night", name = "Night", category = "female", price = 15000, blurb = "Black hair and horns", asset = 129459713841790 },
	{ id = "neko", name = "Neko", category = "female", price = 14000, blurb = "Cat ears and a black outfit", asset = 17545998689 },
	{ id = "city", name = "Jacket", category = "male", price = 11000, blurb = "City jacket and sneakers", asset = 14957799952 },
	{ id = "summer", name = "Summer", category = "female", price = 13000, blurb = "Teal jacket and grey jeans", asset = 104635170766402 },
	{ id = "specs", name = "Glasses", category = "unisex", price = 15000, blurb = "Black suit and round glasses", asset = 128135767367443 },
	{ id = "dood", name = "Visor", category = "male", price = 18000, blurb = "Blue jacket, visor, and a bag", asset = 10979055843 },
	{ id = "emerald", name = "Emerald", category = "unisex", price = 17000, blurb = "Green armor", asset = 8175455331 },
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
