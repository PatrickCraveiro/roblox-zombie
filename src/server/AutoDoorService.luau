-- Portas automáticas: abrem sozinhas quando alguém chega perto e fecham quando todo mundo sai.
-- No lobby: a porta de vidro do supermercado e a porta do Treinamento.
--
-- Cada folha da porta é uma BasePart com a tag "AutoDoor" e os atributos:
--   OpenOffset (Vector3)            - quanto a folha anda pra abrir (no espaço da própria parte)
--   SensorRadius (número, opcional) - distância que faz a porta abrir (padrão 10)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local AutoDoorService = {}

local CHECK_INTERVAL = 0.2
local MOVE_INFO = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type Door = {
	part: BasePart,
	closed: CFrame,
	open: CFrame,
	radius: number,
	isOpen: boolean,
}

local doors: { Door } = {}

local function someoneNear(position: Vector3, radius: number): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - position).Magnitude <= radius then
			return true
		end
	end
	return false
end

local function setupDoor(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local offset = instance:GetAttribute("OpenOffset")
	if typeof(offset) ~= "Vector3" then
		warn(`[AutoDoor] "{instance:GetFullName()}" precisa do atributo OpenOffset (Vector3)`)
		return
	end
	local radius = instance:GetAttribute("SensorRadius")
	table.insert(doors, {
		part = instance,
		closed = instance.CFrame,
		open = instance.CFrame * CFrame.new(offset),
		radius = if typeof(radius) == "number" then radius else 10,
		isOpen = false,
	})
end

local function update()
	for _, door in doors do
		if not door.part.Parent then
			continue
		end
		local shouldOpen = someoneNear(door.closed.Position, door.radius)
		if shouldOpen ~= door.isOpen then
			door.isOpen = shouldOpen
			TweenService:Create(door.part, MOVE_INFO, { CFrame = if shouldOpen then door.open else door.closed }):Play()
		end
	end
end

function AutoDoorService.init()
	CollectionService:GetInstanceAddedSignal("AutoDoor"):Connect(setupDoor)
	for _, instance in CollectionService:GetTagged("AutoDoor") do
		setupDoor(instance)
	end

	task.spawn(function()
		while true do
			update()
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return AutoDoorService
