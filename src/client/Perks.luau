--!strict
-- Купленные плюшки на клиенте: второй прыжок, рывок на Q,
-- и для надетого скина — камера и шаг ног.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local usedAirJump = false
local skinToken = 0

local R15_MOTION = {
	idle = "rbxassetid://507766388",
	walk = "rbxassetid://507777826",
	run = "rbxassetid://913376220",
	jump = "rbxassetid://507765000",
	fall = "rbxassetid://507767968",
}
local R6_MOTION = {
	idle = "rbxassetid://180435571",
	walk = "rbxassetid://180426354",
	run = "rbxassetid://180426354",
	jump = "rbxassetid://125750702",
	fall = "rbxassetid://180436148",
}
local SWING: { [string]: number } = {
	["Left Hip"] = 1,
	["Right Hip"] = -1,
	["Left Shoulder"] = -0.55,
	["Right Shoulder"] = 0.55,
}

local function humanoid(): Humanoid?
	local character = player.Character
	local found = character and character:FindFirstChildOfClass("Humanoid")
	if found and found:IsA("Humanoid") then
		return found
	end
	return nil
end

local function followCamera(character: Model, humanoid: Humanoid)
	task.spawn(function()
		for _ = 1, 12 do
			if not character.Parent or player.Character ~= character then
				return
			end
			local camera = workspace.CurrentCamera
			if camera and camera.CameraSubject ~= humanoid then
				camera.CameraType = Enum.CameraType.Custom
				camera.CameraSubject = humanoid
			end
			task.wait(0.15)
		end
	end)
end

local function loadTrack(animator: Animator, character: Model, id: string, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack?
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	animation.Parent = character
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		return nil
	end
	track.Priority = priority
	track.Looped = looped
	return track
end

local function playRigMotion(character: Model, humanoid: Humanoid, token: number)
	local existing = humanoid:FindFirstChildOfClass("Animator")
	local animator: Animator
	if existing and existing:IsA("Animator") then
		animator = existing
	else
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local ids = if humanoid.RigType == Enum.HumanoidRigType.R6 then R6_MOTION else R15_MOTION
	local idle = loadTrack(animator, character, ids.idle, Enum.AnimationPriority.Idle, true)
	local walk = loadTrack(animator, character, ids.walk, Enum.AnimationPriority.Movement, true)
	local run = loadTrack(animator, character, ids.run, Enum.AnimationPriority.Movement, true)
	local jump = loadTrack(animator, character, ids.jump, Enum.AnimationPriority.Action, false)
	local fall = loadTrack(animator, character, ids.fall, Enum.AnimationPriority.Action, true)
	if idle then
		idle:Play(0.15)
	end
	local moving = "idle"
	local function setMoving(name: string)
		if token ~= skinToken or moving == name then
			return
		end
		moving = name
		if idle then
			idle:Stop(0.15)
		end
		if walk then
			walk:Stop(0.15)
		end
		if run then
			run:Stop(0.15)
		end
		local nextTrack = if name == "run" then run elseif name == "walk" then walk else idle
		if nextTrack then
			nextTrack:Play(0.15)
		end
	end
	humanoid.Running:Connect(function(speed)
		if token ~= skinToken then
			return
		end
		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
			return
		end
		if speed > 18 then
			setMoving("run")
		elseif speed > 0.5 then
			setMoving("walk")
			if walk then
				walk:AdjustSpeed(math.clamp(speed / 14, 0.65, 1.5))
			end
		else
			setMoving("idle")
		end
	end)
	humanoid.StateChanged:Connect(function(_, state)
		if token ~= skinToken then
			return
		end
		if state == Enum.HumanoidStateType.Jumping and jump then
			jump:Play(0.05)
		elseif state == Enum.HumanoidStateType.Freefall and fall then
			if idle then
				idle:Stop(0.1)
			end
			if walk then
				walk:Stop(0.1)
			end
			if run then
				run:Stop(0.1)
			end
			fall:Play(0.1)
			moving = "fall"
		elseif state == Enum.HumanoidStateType.Landed then
			if fall then
				fall:Stop(0.1)
			end
			moving = ""
			local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
			if speed > 18 then
				setMoving("run")
			elseif speed > 0.5 then
				setMoving("walk")
			else
				setMoving("idle")
			end
		end
	end)
end

local function playSwing(character: Model, humanoid: Humanoid, token: number)
	type Swing = { motor: Motor6D, dir: number }
	local motors: { Swing } = {}
	for _, item in character:GetDescendants() do
		local dir = if item:IsA("Motor6D") then SWING[item.Name] else nil
		if item:IsA("Motor6D") and dir then
			table.insert(motors, { motor = item, dir = dir })
		end
	end
	if #motors == 0 then
		return
	end
	local phase = 0
	local amount = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		if token ~= skinToken or not character.Parent then
			connection:Disconnect()
			return
		end
		local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
		local goal = if speed > 0.5 then 1 else 0
		amount += (goal - amount) * math.min(dt * 8, 1)
		phase += dt * math.clamp(speed / 7, 0, 2.2) * 7
		for _, item in motors do
			item.motor.Transform = CFrame.Angles(math.sin(phase) * item.dir * 0.65 * amount, 0, 0)
		end
	end)
end

local function bindSkin(character: Model)
	local started = os.clock()
	while character.Parent and character:GetAttribute("SkinId") == nil and os.clock() - started < 2 do
		task.wait(0.05)
	end
	local skinId = character:GetAttribute("SkinId")
	if not character.Parent or typeof(skinId) ~= "string" or skinId == "" or player.Character ~= character then
		return
	end
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or not humanoid:IsA("Humanoid") then
		humanoid = character:FindFirstChildOfClass("Humanoid")
	end
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	skinToken += 1
	local token = skinToken
	followCamera(character, humanoid)
	if character:GetAttribute("SkinSwing") == true then
		playSwing(character, humanoid, token)
	else
		playRigMotion(character, humanoid, token)
	end
end

local function watch(character: Model)
	task.spawn(bindSkin, character)
	local found = character:WaitForChild("Humanoid", 8)
	if not found or not found:IsA("Humanoid") then
		return
	end
	usedAirJump = false
	found.StateChanged:Connect(function(_, state)
		if state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics then
			usedAirJump = false
		end
	end)
end

if player.Character then
	task.spawn(watch, player.Character)
end
player.CharacterAdded:Connect(watch)

UserInputService.JumpRequest:Connect(function()
	if player:GetAttribute("PerkDoubleJump") ~= true or usedAirJump then
		return
	end
	local found = humanoid()
	if not found or found:GetState() ~= Enum.HumanoidStateType.Freefall then
		return
	end
	usedAirJump = true
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local power = if found.UseJumpPower then found.JumpPower else math.sqrt(2 * workspace.Gravity * found.JumpHeight)
		root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, power, root.AssemblyLinearVelocity.Z)
	end
	found:ChangeState(Enum.HumanoidStateType.Jumping)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.Q then
		return
	end
	if player:GetAttribute("InMatch") == nil or player:GetAttribute("PerkDash") ~= true then
		return
	end
	Remotes.get("Skins"):FireServer("dash")
end)

return {}
