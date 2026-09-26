--!strict
-- Анимация декора арен на сервере: орбиты сфер, покачивание экранов,
-- вращение монет. Список статичного декора собирается один раз.

local RunService = game:GetService("RunService")

local ArenaFx = {}

type Entry = { part: BasePart, base: CFrame, spin: number?, center: Vector3?, bob: number? }

local entries: { Entry } = {}
local dynamicBases: { [BasePart]: CFrame } = {}
local arenas: Folder? = nil

local function register(part: BasePart)
	local spin = part:GetAttribute("Spin")
	local bob = part:GetAttribute("Bob")
	if typeof(spin) ~= "number" and typeof(bob) ~= "number" then
		return
	end
	table.insert(entries, {
		part = part,
		base = part.CFrame,
		spin = if typeof(spin) == "number" then spin else nil,
		center = part:GetAttribute("SpinCenter") :: Vector3?,
		bob = if typeof(bob) == "number" then bob else nil,
	})
end

local function animate(part: BasePart, base: CFrame, elapsed: number, spin: number?, center: Vector3?, bob: number?)
	local cf = base
	if spin then
		local yaw = math.rad(spin * elapsed)
		if center then
			cf = CFrame.new(center) * CFrame.Angles(0, yaw, 0) * (CFrame.new(center):Inverse() * base)
		else
			cf = CFrame.new(base.Position) * CFrame.Angles(0, yaw, 0) * (base - base.Position)
		end
	end
	if bob then
		cf = cf + Vector3.new(0, math.sin(elapsed * bob + base.Position.X * 0.1) * 0.6, 0)
	end
	part.CFrame = cf
end

function ArenaFx.init(arenasFolder: Folder)
	arenas = arenasFolder
	for _, arena in arenasFolder:GetChildren() do
		local decor = arena:FindFirstChild("Decor")
		if decor then
			for _, part in decor:GetChildren() do
				if part:IsA("BasePart") then
					register(part)
				end
			end
		end
		local screen = arena:FindFirstChild("Screen")
		if screen and screen:IsA("BasePart") then
			register(screen)
		end
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		for _, entry in entries do
			if entry.part.Parent then
				animate(entry.part, entry.base, elapsed, entry.spin, entry.center, entry.bob)
			end
		end
		-- Динамические подбираемые предметы (монеты, бонусы).
		if arenas then
			for _, arena in arenas:GetChildren() do
				local pickups = arena:FindFirstChild("Pickups")
				if not pickups then
					continue
				end
				for _, item in pickups:GetChildren() do
					if not item:IsA("BasePart") then
						continue
					end
					local base = dynamicBases[item]
					if not base then
						base = item.CFrame
						dynamicBases[item] = base
					end
					local spin = item:GetAttribute("Spin")
					local bob = item:GetAttribute("Bob")
					animate(item, base, elapsed, if typeof(spin) == "number" then spin else nil, nil, if typeof(bob) == "number" then bob else nil)
				end
			end
		end
		for item in dynamicBases do
			if not item.Parent then
				dynamicBases[item] = nil
			end
		end
	end)
end

return ArenaFx
