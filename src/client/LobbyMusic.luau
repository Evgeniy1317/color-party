--!strict
-- Музыка лобби и первая кнопка бокового меню.
-- Трек из официального каталога Roblox (DistroKid), его можно использовать в игре.

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
sound.SoundId = "rbxassetid://131191443172456" -- Festinha da Alegria
sound.Looped = true
sound.Volume = 0.4
sound.Parent = SoundService

local click = Instance.new("Sound")
click.Name = "MenuClick"
click.SoundId = "rbxasset://sounds/button.wav"
click.Volume = 0.45
click.Parent = SoundService

local muted = false

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
	local x0, y0 = 64, 24
	local x1, y1 = 112, 20
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
	return 5.6 - best
end

local function noteIcon(): ImageLabel
	local n = 128
	local editable = AssetService:CreateEditableImage({ Size = Vector2.new(n, n) })
	local pixels = buffer.create(n * n * 4)
	for y = 0, n - 1 do
		for x = 0, n - 1 do
			local cover = 0
			for _, ox in { 0.25, 0.75 } do
				for _, oy in { 0.25, 0.75 } do
					local px, py = x + ox, y + oy
					local head = sdEllipse(px, py, 50, 92, 20, 14.5, -0.45)
					local stem = sdCapsule(px, py, 64, 84, 64, 24, 5)
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
	icon.Position = UDim2.fromScale(0.5, 0.52)
	icon.Size = UDim2.fromOffset(30, 30)
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
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = menu

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

local function apply()
	paint()
	local lobby = inLobby()
	gui.Enabled = lobby
	if muted or not lobby then
		if sound.IsPlaying then
			sound:Pause()
		end
	elseif not sound.IsPlaying then
		sound:Play()
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

return {}
