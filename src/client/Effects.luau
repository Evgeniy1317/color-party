--!strict
-- Звуки и экранные вспышки. Используются встроенные звуки Roblox (rbxasset),
-- поэтому работают всегда, без загрузки из каталога.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Effects = {}

local SOUNDS = {
	tick = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5 },
	go = { id = "rbxasset://sounds/switch3.wav", volume = 0.6 },
	drop = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.7 },
	fake = { id = "rbxasset://sounds/flashbulb.wav", volume = 0.8 },
	out = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.6 },
	win = { id = "rbxasset://sounds/victory.wav", volume = 0.7 },
	click = { id = "rbxasset://sounds/button.wav", volume = 0.5 },
	coin = { id = "rbxassetid://130201387574815", volume = 0.75 },
	bonus = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.6 },
	fall = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.5 },
}

local sounds: { [string]: Sound } = {}

local function sound(name: string): Sound?
	local def = SOUNDS[name]
	if not def then
		return nil
	end
	local existing = sounds[name]
	if existing then
		return existing
	end
	local s = Instance.new("Sound")
	s.Name = "CP_" .. name
	s.SoundId = def.id
	s.Volume = def.volume
	s.Parent = SoundService
	sounds[name] = s
	return s
end

function Effects.play(name: string, pitch: number?)
	local s = sound(name)
	if not s then
		return
	end
	s.PlaybackSpeed = pitch or 1
	s:Play()
end

-- Экранная вспышка ----------------------------------------------------------

local flashGui: ScreenGui? = nil
local flashFrame: Frame? = nil

local function ensureFlash(): Frame
	if flashFrame then
		return flashFrame
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "ColorPartyFlash"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Edge"
	stroke.Thickness = 0
	stroke.Color = Color3.fromRGB(255, 70, 70)
	stroke.Transparency = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	flashGui = gui
	flashFrame = frame
	return frame
end

function Effects.flash(color: Color3, strength: number, duration: number)
	local frame = ensureFlash()
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1 - strength
	TweenService:Create(frame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

-- Красная рамка тревоги (обманка).
function Effects.alertBorder(duration: number)
	local frame = ensureFlash()
	local stroke = frame:FindFirstChild("Edge") :: UIStroke
	stroke.Thickness = 26
	stroke.Transparency = 0.1
	TweenService:Create(stroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1, Thickness = 0 }):Play()
end

-- Короткая тряска экрана: смещение всех ScreenGui через камеру не трогаем,
-- вместо этого качаем переданный фрейм.
function Effects.shake(frame: GuiObject, amplitude: number, duration: number)
	local origin = frame.Position
	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < duration do
			local k = 1 - (os.clock() - start) / duration
			frame.Position = origin + UDim2.fromOffset((math.random() - 0.5) * 2 * amplitude * k, (math.random() - 0.5) * 2 * amplitude * k)
			task.wait()
		end
		frame.Position = origin
	end)
end

return Effects
