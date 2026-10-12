--!strict
-- Точка входа клиента Color Party: интерфейс готовности, HUD матча,
-- камера-трансляция и эффекты.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function start(name: string)
	local ok, err = pcall(function()
		require(script:WaitForChild(name))
	end)
	if not ok then
		warn("[ColorParty] " .. name .. " не запустился: " .. tostring(err))
	end
end

pcall(function()
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale")).install()
end)

start("Effects")
start("SpectatorCam")
start("ReadyUI")
start("RoundHUD")
start("LobbyMusic")
start("SkinShopUI")
start("WheelUI")
start("LeaderboardUI")
start("QuestUI")
start("InventoryUI")
start("Perks")
