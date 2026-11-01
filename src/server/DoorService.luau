-- Portas pagas (portas de aço de enrolar) e áreas do mapa.
--
-- No Studio, a porta é uma BasePart com a tag "Door" e os atributos:
--   Price (número) - quanto custa abrir
--   Zones (texto)  - área(s) que a porta libera, separadas por vírgula. Ex: "Hortifruti"
--   Label (texto)  - nome que aparece pro jogador. Ex: "Hortifruti"
--   OpenFrom (Vector3, opcional) - porta de um lado só: só abre quem estiver do lado pra onde
--                  esse vetor aponta (o outro lado mostra "só abre pelo outro lado")
-- A face da frente e a de trás da parte mostram o preço.
--
-- Spawns de zumbi (tag "ZombieSpawn") com o atributo "Zone" só funcionam depois que
-- alguma porta libera essa área. Spawn sem "Zone" funciona sempre (área inicial).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)
local PointsService = require(script.Parent.PointsService)

local Remotes = ReplicatedStorage.Remotes

local DoorService = {}

type Door = {
	part: BasePart,
	prompt: ProximityPrompt,
	labels: { SurfaceGui },
	closedCFrame: CFrame,
	transparency: number,
	open: boolean,
}

local doors: { Door } = {}
local openZones: { [string]: boolean } = {}

local function parseZones(text: string): { string }
	local zones = {}
	for zone in string.gmatch(text, "[^,]+") do
		table.insert(zones, (string.gsub(zone, "^%s*(.-)%s*$", "%1")))
	end
	return zones
end

-- Liga/desliga os spawns de acordo com as áreas abertas
local function refreshSpawns()
	for _, spawnPart in CollectionService:GetTagged("ZombieSpawn") do
		local zone = spawnPart:GetAttribute("Zone")
		if typeof(zone) == "string" then
			spawnPart:SetAttribute("Active", openZones[zone] == true)
		end
	end
end

local function setVisible(door: Door, visible: boolean)
	door.part.Transparency = if visible then door.transparency else 1
	door.part.CanCollide = visible
	door.part.CanQuery = visible
	for _, label in door.labels do
		label.Enabled = visible
	end
end

local function createLabel(part: BasePart, face: Enum.NormalId, label: string, price: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = part

	local text = Instance.new("TextLabel")
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.45)
	text.Size = UDim2.fromScale(0.8, 0.35)
	text.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	text.BackgroundTransparency = 0.25
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 210, 60)
	text.Text = if price < 0 then string.upper(label) else string.format("%s\n%d PTS", string.upper(label), price)
	text.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = text

	return gui
end

local function openDoor(door: Door)
	door.open = true
	door.prompt.Enabled = false
	door.part.CanCollide = false -- a passagem libera na hora; a animação é só visual
	Sounds.play(Sounds.Ids.DoorOpen, door.part, 0.8)

	-- a porta de enrolar sobe pra dentro do teto e some
	local raised = door.closedCFrame + Vector3.new(0, door.part.Size.Y, 0)
	local tween = TweenService:Create(door.part, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = raised })
	tween.Completed:Once(function()
		if door.open then
			setVisible(door, false)
		end
	end)
	tween:Play()
end

local function closeDoor(door: Door)
	door.open = false
	door.part.CFrame = door.closedCFrame
	setVisible(door, true)
	door.prompt.Enabled = true
end

local function setupDoor(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local price = instance:GetAttribute("Price")
	local zonesText = instance:GetAttribute("Zones")
	if typeof(price) ~= "number" or typeof(zonesText) ~= "string" then
		warn(`[DoorService] "{instance:GetFullName()}" precisa dos atributos Price (número) e Zones (texto)`)
		return
	end
	local label = instance:GetAttribute("Label")
	local labelText = if typeof(label) == "string" then label else zonesText

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Abrir passagem"
	prompt.ObjectText = string.format("%s  |  %d pts", labelText, price)
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = instance

	-- porta de um lado só: o lado errado mostra o aviso em vez do preço
	local openFrom = instance:GetAttribute("OpenFrom")
	local oneWay = typeof(openFrom) == "Vector3"
	local function faceLabel(face: Enum.NormalId): SurfaceGui
		local normal = instance.CFrame:VectorToWorldSpace(Vector3.fromNormalId(face))
		if oneWay and normal:Dot(openFrom) < 0 then
			return createLabel(instance, face, `{labelText}\nSÓ ABRE PELO OUTRO LADO`, -1)
		end
		return createLabel(instance, face, labelText, price)
	end

	local door: Door = {
		part = instance,
		prompt = prompt,
		labels = {
			faceLabel(Enum.NormalId.Front),
			faceLabel(Enum.NormalId.Back),
		},
		closedCFrame = instance.CFrame,
		transparency = instance.Transparency,
		open = false,
	}
	table.insert(doors, door)

	prompt.Triggered:Connect(function(player)
		if door.open then
			return
		end
		if oneWay then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or (root.Position - instance.Position):Dot(openFrom) <= 0 then
				Remotes.Notify:FireClient(player, "Essa porta só abre pelo outro lado")
				return
			end
		end
		if not PointsService.spend(player, price) then
			Remotes.Notify:FireClient(player, "Pontos insuficientes")
			return
		end
		openDoor(door)
		for _, zone in parseZones(zonesText) do
			openZones[zone] = true
		end
		refreshSpawns()
		-- avisa só quem está na partida (o pessoal do lobby não precisa saber)
		for _, other in Players:GetPlayers() do
			if other:GetAttribute("InMatch") then
				Remotes.Notify:FireClient(other, `{player.DisplayName} abriu: {labelText}`)
			end
		end
	end)
end

function DoorService.init()
	CollectionService:GetInstanceAddedSignal("Door"):Connect(setupDoor)
	for _, instance in CollectionService:GetTagged("Door") do
		setupDoor(instance)
	end
	DoorService.reset()
end

-- Fecha tudo de novo (começo de cada partida)
function DoorService.reset()
	for _, door in doors do
		closeDoor(door)
	end
	table.clear(openZones)
	refreshSpawns()
end

return DoorService
