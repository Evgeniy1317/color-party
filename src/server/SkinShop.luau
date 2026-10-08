--!strict
-- Магазин: кнопка E у стойки, покупка за монеты или робуксы, скины, плюшки и следы.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(script.Parent:WaitForChild("Economy"))
local Matchmaker = require(script.Parent:WaitForChild("Matchmaker"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Shop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Shop"))
local Skins = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Skins"))

local SkinShop = {}

local originals: { [Player]: HumanoidDescription } = {}

local function pushState(player: Player, notice: string?)
	Economy.pushShop(player, notice)
end

local function syncPerks(player: Player)
	Economy.refreshPerks(player)
end

local function clearFx(character: Model)
	local old = character:FindFirstChild("SkinFx")
	if old then
		old:Destroy()
	end
end

local R6_MOTORS = {
	{ name = "Neck", part0 = "Torso", part1 = "Head", c0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), c1 = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	{ name = "Right Shoulder", part0 = "Torso", part1 = "Right Arm", c0 = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), c1 = CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	{ name = "Left Shoulder", part0 = "Torso", part1 = "Left Arm", c0 = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), c1 = CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
	{ name = "Right Hip", part0 = "Torso", part1 = "Right Leg", c0 = CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), c1 = CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	{ name = "Left Hip", part0 = "Torso", part1 = "Left Leg", c0 = CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), c1 = CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
}

local function partNamed(model: Model, name: string): BasePart?
	local inst = model:FindFirstChild(name)
	if inst and inst:IsA("BasePart") then
		return inst
	end
	return nil
end

local function hasMotor(model: Model, name: string, part1: BasePart): boolean
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") and item.Name == name and item.Part1 == part1 then
			return true
		end
	end
	return false
end

local function ensureR6Motors(model: Model)
	local torso = partNamed(model, "Torso")
	if not torso then
		return
	end
	local hrp = partNamed(model, "HumanoidRootPart")
	if hrp and not hasMotor(model, "RootJoint", torso) then
		local motor = Instance.new("Motor6D")
		motor.Name = "RootJoint"
		motor.Part0 = hrp
		motor.Part1 = torso
		motor.C0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
		motor.C1 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
		motor.Parent = hrp
	end
	for _, spec in R6_MOTORS do
		local part0 = partNamed(model, spec.part0)
		local part1 = partNamed(model, spec.part1)
		if part0 and part1 and not hasMotor(model, spec.name, part1) then
			local motor = Instance.new("Motor6D")
			motor.Name = spec.name
			motor.Part0 = part0
			motor.Part1 = part1
			motor.C0 = spec.c0
			motor.C1 = spec.c1
			motor.Parent = part0
		end
	end
end

local function pullRootHome(model: Model, hrp: BasePart)
	local nearest = math.huge
	local sum = Vector3.zero
	local count = 0
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item ~= hrp then
			nearest = math.min(nearest, (item.Position - hrp.Position).Magnitude)
			sum += item.Position
			count += 1
		end
	end
	if count == 0 or nearest < 12 then
		return
	end
	for _, child in hrp:GetChildren() do
		if child:IsA("JointInstance") or child:IsA("Constraint") then
			child:Destroy()
		end
	end
	hrp.CFrame = CFrame.new(sum / count)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item ~= hrp then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hrp
			weld.Part1 = item
			weld.Parent = hrp
		end
	end
end

local function cleanCopy(template: Model): Model
	local clone = template:Clone()
	local drop = {}
	local topHumanoid = clone:FindFirstChildOfClass("Humanoid")
	for _, item in clone:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Sound") or item:IsA("BillboardGui") or item:IsA("Camera") or item:IsA("Trail") then
			table.insert(drop, item)
		elseif item:IsA("Humanoid") and item ~= topHumanoid then
			local host = item.Parent
			if host and host:IsA("Model") and host ~= clone then
				table.insert(drop, host)
			end
		elseif item:IsA("BasePart") and item.Size.Y < 1 and math.max(item.Size.X, item.Size.Z) > 10 then
			table.insert(drop, item)
		end
	end
	for _, item in drop do
		if item.Parent then
			item:Destroy()
		end
	end
	return clone
end

local function prepareRig(clone: Model, player: Player): (Humanoid?, BasePart?)
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	local hrp = partNamed(clone, "HumanoidRootPart")
	if not humanoid or not hrp then
		return nil, nil
	end
	humanoid.Name = "Humanoid"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.AutomaticScalingEnabled = false
	if humanoid.MaxHealth < 1 then
		humanoid.MaxHealth = 100
	end
	humanoid.Health = humanoid.MaxHealth
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 50
	humanoid.JumpHeight = 7.2
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	humanoid.WalkSpeed = if player:GetAttribute("PerkSpeed") == true then 22 else 16
	if not humanoid:FindFirstChildOfClass("Animator") then
		local animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	for _, item in clone:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = false
			if item == hrp then
				item.Massless = false
				item.CanCollide = false
				item.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
			else
				item.Massless = true
			end
		end
	end
	pullRootHome(clone, hrp)
	ensureR6Motors(clone)
	if not clone:FindFirstChild("Torso") and not clone:FindFirstChild("LowerTorso") and humanoid.HipHeight < 0.2 then
		local bottom = math.huge
		for _, item in clone:GetDescendants() do
			if item:IsA("BasePart") and item ~= hrp then
				bottom = math.min(bottom, item.Position.Y - item.Size.Y * 0.5)
			end
		end
		if bottom < math.huge then
			humanoid.HipHeight = math.clamp(hrp.Position.Y - bottom, 1, 4)
		end
	end
	clone.PrimaryPart = hrp
	return humanoid, hrp
end

local function wearModel(player: Player)
	local id = Economy.equippedSkin(player)
	local template = if id ~= "" then Skins.model(id) else nil
	local current = player.Character
	if not template or not current or current:GetAttribute("SkinId") == id then
		return
	end
	if not template:FindFirstChild("HumanoidRootPart") or not template:FindFirstChildOfClass("Humanoid") then
		return
	end
	local clone = cleanCopy(template)
	local humanoid, hrp = prepareRig(clone, player)
	if not humanoid or not hrp then
		clone:Destroy()
		return
	end
	local previous = current
	clone.Name = player.Name
	clone:SetAttribute("SkinId", id)
	clone:PivotTo(previous:GetPivot())
	clone.Parent = workspace
	player.Character = clone
	task.defer(function()
		if hrp.Parent and not hrp.Anchored then
			pcall(function()
				hrp:SetNetworkOwner(player)
			end)
		end
		if previous.Parent and previous ~= clone then
			previous:Destroy()
		end
		if humanoid.Parent then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

local function applyEquipped(player: Player, _character: Model)
	wearModel(player)
end

local function restoreAvatar(player: Player)
	player:LoadCharacter()
end

local function applyTrail(player: Player, character: Model)
	local old = character:FindFirstChild("ShopTrail")
	if old then
		old:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		for _, name in { "Top", "Bottom" } do
			local extra = root:FindFirstChild(name)
			if extra then
				extra:Destroy()
			end
		end
	end
	local stray = {}
	for _, child in character:GetDescendants() do
		if child:IsA("Trail") and child.Name ~= "DashTrail" then
			table.insert(stray, child)
		end
	end
	for _, child in stray do
		child:Destroy()
	end
	local item = Shop.get(Economy.equippedTrail(player))
	if not item or item.kind ~= "trail" or not item.colors or not root or not root:IsA("BasePart") then
		character:SetAttribute("TrailId", "")
		return
	end
	character:SetAttribute("TrailId", item.id)
	local folder = Instance.new("Folder")
	folder.Name = "ShopTrail"
	folder.Parent = character
	local top = Instance.new("Attachment")
	top.Name = "Top"
	top.Position = Vector3.new(0, 1.15, 0.55)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "Bottom"
	bottom.Position = Vector3.new(0, -1.15, 0.55)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "Ribbon"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 2
	trail.MinLength = 0.02
	trail.FaceCamera = true
	trail.LightEmission = 0.7
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.2),
		NumberSequenceKeypoint.new(1, 0.55),
	})
	local keys = {}
	for index, color in item.colors do
		local at = if #item.colors == 1 then 0 else (index - 1) / (#item.colors - 1)
		table.insert(keys, ColorSequenceKeypoint.new(at, color))
	end
	trail.Color = ColorSequence.new(keys)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.82, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = root
	folder.Destroying:Connect(function()
		if trail.Parent then
			trail:Destroy()
		end
		if top.Parent then
			top:Destroy()
		end
		if bottom.Parent then
			bottom:Destroy()
		end
	end)
end

local function onCharacter(player: Player, character: Model)
	local equippedNow = Economy.equippedSkin(player)
	if equippedNow ~= "" and character:GetAttribute("SkinId") == equippedNow then
		applyTrail(player, character)
		syncPerks(player)
		return
	end
	local done = false
	local conn = player.CharacterAppearanceLoaded:Connect(function(loaded)
		if loaded == character then
			done = true
		end
	end)
	local started = os.clock()
	while character.Parent and not done and os.clock() - started < 8 do
		task.wait(0.05)
	end
	conn:Disconnect()
	if not character.Parent then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and not originals[player] then
		local ok, desc = pcall(function()
			return humanoid:GetAppliedDescription()
		end)
		if ok and desc then
			originals[player] = desc
		end
	end
	local equipped = Economy.equippedSkin(player)
	if equipped ~= "" and character:GetAttribute("SkinId") ~= equipped then
		applyEquipped(player, character)
	end
	applyTrail(player, character)
	syncPerks(player)
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(onCharacter, player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

local function canUseShop(player: Player): boolean
	return player:GetAttribute("InMatch") == nil
end

local function priceOf(id: string): number
	local skin = Skins.get(id)
	local fallback = if skin then skin.price else 0
	return Shop.coins(id, fallback)
end

local function nameOf(id: string): string
	local skin = Skins.get(id)
	if skin then
		return skin.name
	end
	local item = Shop.get(id)
	return if item then item.name else id
end

local function give(player: Player, id: string)
	Economy.grantSkin(player, id)
	local skin = Skins.get(id)
	local item = Shop.get(id)
	if skin then
		Economy.equipSkin(player, id)
		if player.Character then
			applyEquipped(player, player.Character)
		end
	elseif item and item.kind == "trail" then
		Economy.equipTrail(player, id)
		if player.Character then
			applyTrail(player, player.Character)
		end
	end
	syncPerks(player)
end

local function buy(player: Player, id: string)
	if not canUseShop(player) then
		pushState(player, "Магазин только в лобби")
		return
	end
	if not Skins.get(id) and not Shop.get(id) then
		return
	end
	local listPrice = priceOf(id)
	if Economy.ownsSkin(player, id) or listPrice <= 0 then
		give(player, id)
		pushState(player, "Готово: " .. nameOf(id))
		return
	end
	local price = Economy.takeDiscount(player, listPrice)
	if Economy.coins(player) < price then
		pushState(player, "Не хватает монет")
		return
	end
	Economy.addCoins(player, -price, "shop")
	if price < listPrice then
		Economy.spendDiscount(player)
	end
	give(player, id)
	pushState(player, "Куплено: " .. nameOf(id))
end

local function buyOnce(player: Player, id: string)
	if not canUseShop(player) then
		pushState(player, "Магазин только в лобби")
		return
	end
	local item = Shop.get(id)
	if not item or item.kind ~= "perk" then
		return
	end
	if Economy.ownsSkin(player, id) then
		pushState(player, "Уже навсегда: " .. item.name)
		return
	end
	local listPrice = Shop.onceCoins(id)
	if listPrice <= 0 then
		return
	end
	local price = Economy.takeDiscount(player, listPrice)
	if Economy.coins(player) < price then
		pushState(player, "Не хватает монет")
		return
	end
	Economy.addCoins(player, -price, "shop")
	if price < listPrice then
		Economy.spendDiscount(player)
	end
	Economy.addCharge(player, id, 1)
	pushState(player, "На 1 матч: " .. item.name)
end

local function buyRobuxOnce(player: Player, id: string)
	if not canUseShop(player) then
		pushState(player, "Магазин только в лобби")
		return
	end
	local item = Shop.get(id)
	if not item or item.kind ~= "perk" then
		return
	end
	if Economy.ownsSkin(player, id) then
		pushState(player, "Уже навсегда: " .. item.name)
		return
	end
	local productId = Shop.productId(Shop.onceKey(id))
	if productId <= 0 then
		pushState(player, "Робуксы: создай Developer Product и впиши id в Shop под ключом " .. Shop.onceKey(id) .. ". Цена " .. tostring(Shop.onceRobux(id)) .. " R$")
		return
	end
	MarketplaceService:PromptProductPurchase(player, productId)
end

local function equip(player: Player, id: string)
	if not canUseShop(player) then
		pushState(player, "Магазин только в лобби")
		return
	end
	local skin = Skins.get(id)
	local item = Shop.get(id)
	if not skin and not (item and item.kind == "trail") then
		return
	end
	local price = priceOf(id)
	if not Economy.ownsSkin(player, id) and price > 0 then
		pushState(player, "Сначала купи")
		return
	end
	give(player, id)
	pushState(player, "Надето: " .. nameOf(id))
end

local function clear(player: Player)
	if not canUseShop(player) then
		return
	end
	Economy.equipSkin(player, "")
	restoreAvatar(player)
	syncPerks(player)
	pushState(player, "Скин снят")
end

local function clearTrail(player: Player)
	if not canUseShop(player) then
		return
	end
	Economy.equipTrail(player, "")
	if player.Character then
		applyTrail(player, player.Character)
	end
	pushState(player, "След снят")
end

local function buyRobux(player: Player, id: string)
	if not canUseShop(player) then
		pushState(player, "Магазин только в лобби")
		return
	end
	if not Skins.get(id) and not Shop.get(id) then
		return
	end
	if Economy.ownsSkin(player, id) or priceOf(id) <= 0 then
		give(player, id)
		pushState(player, "Уже есть: " .. nameOf(id))
		return
	end
	local productId = Shop.productId(id)
	if productId <= 0 then
		pushState(player, "Робуксы: создай Developer Product и впиши id в Shop.luau. Цена " .. tostring(Shop.robux(id)) .. " R$")
		return
	end
	MarketplaceService:PromptProductPurchase(player, productId)
end

local function attachPrompt()
	local world = workspace:WaitForChild("World", 60)
	if not world then
		return
	end
	local podium = world:WaitForChild("Lobby"):WaitForChild("Podiums"):WaitForChild("Skins", 60)
	if not podium then
		return
	end
	local host = podium:FindFirstChild("Sign") or podium:FindFirstChildWhichIsA("BasePart", true)
	if not host or not host:IsA("BasePart") then
		return
	end
	local existing = podium:FindFirstChild("ShopPrompt", true)
	if existing then
		existing:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Открыть"
	prompt.ObjectText = "Магазин"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = host
end

function SkinShop.grant(player: Player, id: string)
	give(player, id)
end

function SkinShop.init()
	local remote = Remotes.get("Skins")
	remote.OnServerEvent:Connect(function(player, action, id)
		if typeof(action) ~= "string" then
			return
		end
		if action == "state" then
			pushState(player)
		elseif action == "buy" and typeof(id) == "string" then
			buy(player, id)
		elseif action == "buyOnce" and typeof(id) == "string" then
			buyOnce(player, id)
		elseif action == "robuxOnce" and typeof(id) == "string" then
			buyRobuxOnce(player, id)
		elseif action == "equip" and typeof(id) == "string" then
			equip(player, id)
		elseif action == "clear" then
			clear(player)
		elseif action == "clearTrail" then
			clearTrail(player)
		elseif action == "robux" and typeof(id) == "string" then
			buyRobux(player, id)
		elseif action == "dash" then
			Matchmaker.useDash(player)
		end
	end)
	MarketplaceService.ProcessReceipt = function(receipt)
		local itemId = Shop.itemByProduct(receipt.ProductId)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not itemId or not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if not Economy.seenReceipt(player, receipt.PurchaseId) then
			Economy.rememberReceipt(player, receipt.PurchaseId)
			if itemId == "wheel" then
				require(script.Parent:WaitForChild("Wheel")).grantPaid(player)
			elseif itemId == "battlepass" then
				require(script.Parent:WaitForChild("Quests")).grantPass(player)
			elseif string.sub(itemId, -5) == "#once" then
				local perkId = string.sub(itemId, 1, #itemId - 5)
				Economy.addCharge(player, perkId, 1)
				pushState(player, "На 1 матч за робуксы: " .. nameOf(perkId))
			elseif not Economy.ownsSkin(player, itemId) then
				give(player, itemId)
				pushState(player, "Куплено за робуксы: " .. nameOf(itemId))
			else
				pushState(player, "Уже есть: " .. nameOf(itemId))
			end
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	Players.PlayerAdded:Connect(function(player)
		watch(player)
		task.defer(function()
			player:WaitForChild("leaderstats", 10)
			syncPerks(player)
			pushState(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
		task.defer(function()
			syncPerks(player)
			pushState(player)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		originals[player] = nil
	end)
	task.spawn(attachPrompt)
end

return SkinShop
