--!strict
-- Музыка лобби, музыка матча и первая кнопка бокового меню.
-- Треки из официального каталога Roblox (DistroKid), их можно использовать в игре.
-- В матче у каждого игрока свой случайный трек, лобби звучит отдельно.

local Hub = require(script.Parent:WaitForChild("Hub"))
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local AssetService = game:GetService("AssetService")

local player = Players.LocalPlayer

local FACE_ON = Color3.fromRGB(70, 214, 122)
local LIP_ON = Color3.fromRGB(28, 148, 74)
local FACE_OFF = Color3.fromRGB(236, 82, 86)
local LIP_OFF = Color3.fromRGB(176, 42, 52)
local LIP = 5
local SIZE = 48

local sound = Instance.new("Sound")
sound.Name = "LobbyMusic"
sound.SoundId = "rbxassetid://101966987527807" -- Back On Track, DistroKid
sound.Looped = true
sound.Volume = 0.32
sound.Parent = SoundService

local click = Instance.new("Sound")
click.Name = "MenuClick"
click.SoundId = "rbxasset://sounds/button.wav"
click.Volume = 0.45
click.Parent = SoundService

-- Весёлый бразильский фонк: беговой темп, у каждого игрока свой трек на матч.
local MATCH_IDS = {
	95131770144654, -- AURA
	129098116998483, -- TOMA FUNK PHONK
	139959590610806, -- FUNK FESTA
	140521045204459, -- BATE FORTE
	138682744064257, -- MONTAGEM SOMBRIA
	136221009150327, -- MONTAGEM DRIFT ETERNO
	74455323029168, -- IMPÉRIO DA NOITE
	98545708617486, -- Rio Rage
	137032467545645, -- Montagem Brazilian Funk
	134547920512637, -- MONTAGEM FUNK
	112853692569087, -- MONTAGEM RYA
	85735197482652, -- DRIFT NIGHT PHONK
	140158652733698, -- Bouncy Trap House
	140504265985079, -- Football Edit
	82787763368776, -- Choir Before Impact
}

local matchSound = Instance.new("Sound")
matchSound.Name = "MatchMusic"
matchSound.Looped = true
matchSound.Volume = 0.38
matchSound.Parent = SoundService

local rng = Random.new()
local lastTrack = 0
local matchPicked = false
local muted = false

local function pickTrack(): string
	local index = rng:NextInteger(1, #MATCH_IDS)
	if index == lastTrack then
		index = index % #MATCH_IDS + 1
	end
	lastTrack = index
	return "rbxassetid://" .. tostring(MATCH_IDS[index])
end

local function sdEllipse(px: number, py: number, cx: number, cy: number, rx: number, ry: number, rot: number): number
	local dx, dy = px - cx, py - cy
	local c, s = math.cos(rot), math.sin(rot)
	local x = c * dx + s * dy
	local y = -s * dx + c * dy
	local k = math.sqrt((x / rx) ^ 2 + (y / ry) ^ 2)
	if k < 1e-4 then
		return math.min(rx, ry)
	end
	return (1 - k) * math.min(rx, ry)
end

local function sdCapsule(px: number, py: number, ax: number, ay: number, bx: number, by: number, radius: number): number
	local abx, aby = bx - ax, by - ay
	local t = math.clamp(((px - ax) * abx + (py - ay) * aby) / (abx * abx + aby * aby), 0, 1)
	local qx, qy = ax + abx * t - px, ay + aby * t - py
	return radius - math.sqrt(qx * qx + qy * qy)
end

local function sdFlag(px: number, py: number): number
	local x0, y0 = 68, 30
	local x1, y1 = 108, 22
	local x2, y2 = 82, 58
	local best = 1e9
	for i = 0, 28 do
		local t = i / 28
		local u = 1 - t
		local x = u * u * x0 + 2 * u * t * x1 + t * t * x2
		local y = u * u * y0 + 2 * u * t * y1 + t * t * y2
		local dx, dy = px - x, py - y
		local d = math.sqrt(dx * dx + dy * dy)
		if d < best then
			best = d
		end
	end
	return 6.2 - best
end

local function plainMark(name: string, text: string, px: number): TextLabel
	local mark = Instance.new("TextLabel")
	mark.Name = name
	mark.BackgroundTransparency = 1
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromScale(0.5, 0.48)
	mark.Size = UDim2.fromOffset(px, px)
	mark.Font = Enum.Font.GothamBlack
	mark.TextSize = px - 4
	mark.TextColor3 = Color3.new(1, 1, 1)
	mark.Text = text
	mark.Active = false
	return mark
end

local function noteIcon(): GuiObject
	local n = 128
	local ok, editable = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(n, n) })
	end)
	if not ok or editable == nil then
		return plainMark("Note", "♪", 36)
	end
	local pixels = buffer.create(n * n * 4)
	for y = 0, n - 1 do
		for x = 0, n - 1 do
			local cover = 0
			for _, ox in { 0.25, 0.75 } do
				for _, oy in { 0.25, 0.75 } do
					local px, py = 64 + (x + ox - 64) / 1.08, 65 + (y + oy - 65) / 1.08
					local head = sdEllipse(px, py, 50, 94, 20, 14, -0.4)
					local stem = sdCapsule(px, py, 68, 86, 68, 30, 6.2)
					local flag = sdFlag(px, py)
					local d = math.max(head, stem, flag)
					cover += math.clamp(d + 0.7, 0, 1)
				end
			end
			local offset = (y * n + x) * 4
			buffer.writeu8(pixels, offset, 255)
			buffer.writeu8(pixels, offset + 1, 255)
			buffer.writeu8(pixels, offset + 2, 255)
			buffer.writeu8(pixels, offset + 3, math.floor(cover / 4 * 255 + 0.5))
		end
	end
	editable:WritePixelsBuffer(Vector2.zero, Vector2.new(n, n), pixels)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Note"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(36, 36)
	icon.ImageContent = Content.fromObject(editable)
	icon.Active = false
	return icon
end

local gui = Instance.new("ScreenGui")
gui.Name = "ColorPartyMusic"
gui.ResetOnSpawn = false
gui.DisplayOrder = 40
gui.Parent = player:WaitForChild("PlayerGui")

local menu = Instance.new("Frame")
menu.Name = "Menu"
menu.BackgroundTransparency = 1
menu.Position = UDim2.fromOffset(14, 14)
menu.Size = UDim2.fromOffset(SIZE, 360)
menu.Active = false
menu.Parent = gui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = menu
menu.Size = UDim2.fromOffset(SIZE * 2 + 10, SIZE + LIP)

local slot = Instance.new("Frame")
slot.Name = "Music"
slot.LayoutOrder = 1
slot.Size = UDim2.fromOffset(SIZE, SIZE + LIP)
slot.BackgroundTransparency = 1
slot.Active = false
slot.Parent = menu

local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.AnchorPoint = Vector2.new(0.5, 1)
shadow.Position = UDim2.new(0.5, 0, 1, 2)
shadow.Size = UDim2.fromOffset(SIZE - 12, 10)
shadow.BackgroundColor3 = Color3.new(0, 0, 0)
shadow.BackgroundTransparency = 0.78
shadow.BorderSizePixel = 0
shadow.Active = false
shadow.Parent = slot
local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(1, 0)
shadowCorner.Parent = shadow

local lip = Instance.new("Frame")
lip.Name = "Lip"
lip.Position = UDim2.fromOffset(0, LIP)
lip.Size = UDim2.fromOffset(SIZE, SIZE)
lip.BackgroundColor3 = LIP_ON
lip.BorderSizePixel = 0
lip.Active = false
lip.Parent = slot
local lipCorner = Instance.new("UICorner")
lipCorner.CornerRadius = UDim.new(0, 14)
lipCorner.Parent = lip

local face = Instance.new("TextButton")
face.Name = "Face"
face.Size = UDim2.fromOffset(SIZE, SIZE)
face.BackgroundColor3 = FACE_ON
face.AutoButtonColor = false
face.Text = ""
face.BorderSizePixel = 0
face.ZIndex = 2
face.Parent = slot
local faceCorner = Instance.new("UICorner")
faceCorner.CornerRadius = UDim.new(0, 14)
faceCorner.Parent = face

local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.42, Color3.fromRGB(246, 246, 246)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(188, 188, 188)),
})
gradient.Parent = face

local stroke = Instance.new("UIStroke")
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Color = Color3.fromRGB(255, 255, 255)
stroke.Thickness = 1.5
stroke.Transparency = 0.4
stroke.Parent = face

local gloss = Instance.new("Frame")
gloss.Name = "Gloss"
gloss.Position = UDim2.fromOffset(9, 6)
gloss.Size = UDim2.new(1, -18, 0, 8)
gloss.BackgroundColor3 = Color3.new(1, 1, 1)
gloss.BackgroundTransparency = 0.68
gloss.BorderSizePixel = 0
gloss.Active = false
gloss.ZIndex = 3
gloss.Parent = face
local glossCorner = Instance.new("UICorner")
glossCorner.CornerRadius = UDim.new(1, 0)
glossCorner.Parent = gloss

local icon = noteIcon()
icon.ZIndex = 4
icon.Parent = face

local scale = Instance.new("UIScale")
scale.Parent = slot

local pressTween = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local hoverTween = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function sink(down: boolean)
	TweenService:Create(face, pressTween, {
		Position = UDim2.fromOffset(0, if down then LIP else 0),
	}):Play()
end

local function paint()
	local on = not muted
	face.BackgroundColor3 = if on then FACE_ON else FACE_OFF
	lip.BackgroundColor3 = if on then LIP_ON else LIP_OFF
end

local function inLobby(): boolean
	return player:GetAttribute("InMatch") == nil
end

-- Play() всегда начинает трек с нуля. После паузы нужно Resume(),
-- и отдельно вернуть позицию: иначе повторное включение сбрасывает песню.
local function hold(playing: Sound)
	if not playing.IsPlaying then
		return
	end
	local at = playing.TimePosition
	playing:Pause()
	playing.TimePosition = at
end

local function carryOn(playing: Sound)
	if playing.IsPlaying then
		return
	end
	local at = playing.TimePosition
	playing:Resume()
	if at > 0.05 and playing.TimePosition < 0.05 then
		playing.TimePosition = at
	end
end

local function apply()
	paint()
	local lobby = inLobby()
	if muted then
		hold(sound)
		hold(matchSound)
		return
	end
	if lobby then
		if matchSound.IsPlaying or matchPicked then
			matchSound:Stop()
			matchPicked = false
		end
		carryOn(sound)
	else
		hold(sound)
		if not matchPicked then
			matchSound.SoundId = pickTrack()
			matchSound.TimePosition = 0
			matchPicked = true
			matchSound:Play()
		else
			carryOn(matchSound)
		end
	end
end

face.MouseEnter:Connect(function()
	TweenService:Create(scale, hoverTween, { Scale = 1.05 }):Play()
end)

face.MouseLeave:Connect(function()
	sink(false)
	TweenService:Create(scale, hoverTween, { Scale = 1 }):Play()
end)

face.MouseButton1Down:Connect(function()
	sink(true)
end)

face.MouseButton1Up:Connect(function()
	sink(false)
end)

face.Activated:Connect(function()
	muted = not muted
	click.TimePosition = 0
	click:Play()
	apply()
end)

player:GetAttributeChangedSignal("InMatch"):Connect(apply)
apply()

local bagSlot = Instance.new("Frame")
bagSlot.Name = "Inventory"
bagSlot.LayoutOrder = 2
bagSlot.Size = UDim2.fromOffset(SIZE, SIZE + LIP)
bagSlot.BackgroundTransparency = 1
bagSlot.Active = false
bagSlot.Parent = menu

local bagLip = Instance.new("Frame")
bagLip.Position = UDim2.fromOffset(0, LIP)
bagLip.Size = UDim2.fromOffset(SIZE, SIZE)
bagLip.BackgroundColor3 = Color3.fromRGB(168, 112, 36)
bagLip.BorderSizePixel = 0
bagLip.Active = false
bagLip.Parent = bagSlot
local bagLipCorner = Instance.new("UICorner")
bagLipCorner.CornerRadius = UDim.new(0, 14)
bagLipCorner.Parent = bagLip

local bag = Instance.new("TextButton")
bag.Name = "Face"
bag.Size = UDim2.fromOffset(SIZE, SIZE)
bag.BackgroundColor3 = Color3.fromRGB(255, 196, 92)
bag.AutoButtonColor = false
bag.Text = ""
bag.BorderSizePixel = 0
bag.ZIndex = 2
bag.Parent = bagSlot
local bagCorner = Instance.new("UICorner")
bagCorner.CornerRadius = UDim.new(0, 14)
bagCorner.Parent = bag

local function sdRoundBox(px: number, py: number, cx: number, cy: number, hw: number, hh: number, radius: number): number
	local qx = math.abs(px - cx) - hw + radius
	local qy = math.abs(py - cy) - hh + radius
	local ox = math.max(qx, 0)
	local oy = math.max(qy, 0)
	return radius - (math.sqrt(ox * ox + oy * oy) + math.min(math.max(qx, qy), 0))
end

local function bagIcon(): GuiObject
	local n = 128
	local ok, editable = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(n, n) })
	end)
	if not ok or editable == nil then
		return plainMark("Bag", "[]", 36)
	end
	local pixels = buffer.create(n * n * 4)
	for y = 0, n - 1 do
		for x = 0, n - 1 do
			local cover = 0
			for _, ox in { 0.25, 0.75 } do
				for _, oy in { 0.25, 0.75 } do
					local px, py = 64 + (x + ox - 64) / 1.08, 65 + (y + oy - 65) / 1.08
					local body = sdRoundBox(px, py, 64, 76, 33, 33, 15)
					local pocket = sdRoundBox(px, py, 64, 90, 15, 10, 5)
					local handle = sdCapsule(px, py, 42, 34, 86, 34, 11)
					local hole = sdCapsule(px, py, 52, 34, 76, 34, 4.2)
					local strapL = sdCapsule(px, py, 40, 42, 40, 58, 6)
					local strapR = sdCapsule(px, py, 88, 42, 88, 58, 6)
					local d = math.max(body, handle, strapL, strapR)
					d = math.min(d, -hole, -pocket)
					cover += math.clamp(d + 0.7, 0, 1)
				end
			end
			local offset = (y * n + x) * 4
			buffer.writeu8(pixels, offset, 255)
			buffer.writeu8(pixels, offset + 1, 255)
			buffer.writeu8(pixels, offset + 2, 255)
			buffer.writeu8(pixels, offset + 3, math.floor(cover / 4 * 255 + 0.5))
		end
	end
	editable:WritePixelsBuffer(Vector2.zero, Vector2.new(n, n), pixels)
	local icon = Instance.new("ImageLabel")
	icon.Name = "Bag"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(36, 36)
	icon.ImageContent = Content.fromObject(editable)
	icon.Active = false
	icon.ZIndex = 4
	return icon
end

bag.BackgroundColor3 = Color3.fromRGB(232, 156, 64)
bagLip.BackgroundColor3 = Color3.fromRGB(168, 96, 32)
local bagGradient = Instance.new("UIGradient")
bagGradient.Rotation = 90
bagGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.42, Color3.fromRGB(246, 246, 246)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(188, 188, 188)),
})
bagGradient.Parent = bag
local bagStroke = Instance.new("UIStroke")
bagStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
bagStroke.Color = Color3.fromRGB(255, 255, 255)
bagStroke.Thickness = 1.5
bagStroke.Transparency = 0.4
bagStroke.Parent = bag
local bagGloss = Instance.new("Frame")
bagGloss.Position = UDim2.fromOffset(9, 6)
bagGloss.Size = UDim2.new(1, -18, 0, 8)
bagGloss.BackgroundColor3 = Color3.new(1, 1, 1)
bagGloss.BackgroundTransparency = 0.68
bagGloss.BorderSizePixel = 0
bagGloss.Active = false
bagGloss.ZIndex = 3
bagGloss.Parent = bag
local bagGlossCorner = Instance.new("UICorner")
bagGlossCorner.CornerRadius = UDim.new(1, 0)
bagGlossCorner.Parent = bagGloss
bagIcon().Parent = bag

local bagScale = Instance.new("UIScale")
bagScale.Parent = bagSlot

bag.MouseEnter:Connect(function()
	TweenService:Create(bagScale, hoverTween, { Scale = 1.05 }):Play()
end)
bag.MouseLeave:Connect(function()
	TweenService:Create(bag, pressTween, { Position = UDim2.fromOffset(0, 0) }):Play()
	TweenService:Create(bagScale, hoverTween, { Scale = 1 }):Play()
end)
bag.MouseButton1Down:Connect(function()
	TweenService:Create(bag, pressTween, { Position = UDim2.fromOffset(0, LIP) }):Play()
end)
bag.MouseButton1Up:Connect(function()
	TweenService:Create(bag, pressTween, { Position = UDim2.fromOffset(0, 0) }):Play()
end)
bag.Activated:Connect(function()
	click.TimePosition = 0
	click:Play()
	if player:GetAttribute("InMatch") ~= nil then
		return
	end
	if Hub.current() == "inventory" then
		Hub.close()
	else
		Hub.show("inventory")
	end
end)

local function showBag()
	bagSlot.Visible = player:GetAttribute("InMatch") == nil
end
player:GetAttributeChangedSignal("InMatch"):Connect(showBag)
showBag()

return {}
