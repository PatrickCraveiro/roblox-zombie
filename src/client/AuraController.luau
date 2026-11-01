-- Cargos de aura (Progression.Ranks): em cima de cada jogador aparece o cargo e o nome, e em
-- volta do personagem fica a aura do cargo. Vale também pros manequins da Galeria das Auras do
-- lobby (tag "AuraMannequin", atributo AuraRank), que mostram quanto falta pra você chegar lá;
-- o botão E de cada pedestal escolhe qual aura usar (entre os cargos que você já tem).
--
-- Tudo aqui é efeito local (cada cliente desenha as auras de todo mundo). No seu personagem o
-- nome não aparece (primeira pessoa) e a aura sai dos pés e mais fraquinha, pra não atrapalhar
-- a mira.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Progression = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Progression"))

local player = Players.LocalPlayer

local AuraController = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local WHITE = Color3.fromRGB(245, 245, 245)

type Orbiter = { part: BasePart, radius: number, height: number, speed: number, angle: number, phase: number }

type Aura = {
	model: Model,
	root: BasePart,
	rank: number,
	isOwn: boolean,
	footOffset: number, -- do centro do corpo até o chão
	body: BasePart, -- caixa invisível em volta do corpo (as partículas saem dela)
	feet: BasePart, -- placa invisível nos pés
	orbiters: { Orbiter },
	light: PointLight?,
	bolts: boolean, -- raios em volta (Raio Ambulante)
	nextBolt: number,
	progress: TextLabel?, -- manequim: "faltam X pts"
	instances: { Instance }, -- tudo que precisa apagar quando a aura sai
}

local auras: { [Model]: Aura } = {}
local effectsFolder: Folder

local function range(min: number, max: number): NumberRange
	return NumberRange.new(min, max)
end

local function colors(first: Color3, last: Color3?): ColorSequence
	return ColorSequence.new(first, last or first)
end

-- parte invisível (ou não) que não colide, não leva tiro e não faz sombra
local function newPart(aura: Aura, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Material = Enum.Material.Neon
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = effectsFolder
	table.insert(aura.instances, part)
	return part
end

local function emitter(aura: Aura, parent: BasePart, props: { [string]: any }): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.LockedToPart = false
	for key, value in props do
		(particles :: any)[key] = value
	end
	if aura.isOwn then
		-- no seu personagem: menos partículas e mais baixas
		particles.Rate *= 0.5
		particles.Lifetime = range(particles.Lifetime.Min * 0.6, particles.Lifetime.Max * 0.6)
	end
	particles.Parent = parent
	return particles
end

local function addLight(aura: Aura, color: Color3, lightRange: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = lightRange
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = aura.body
	aura.light = light
end

local function addTrail(part: BasePart, color: Color3)
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.18, 0)
	top.Parent = part
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -0.18, 0)
	bottom.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = colors(color)
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.35
	trail.FaceCamera = true
	trail.Parent = part
end

-- coisas girando em volta do corpo (alturas relativas ao centro do corpo)
local function addOrbiters(aura: Aura, heights: { number }, radius: number, speed: number, make: (index: number) -> BasePart)
	for index, height in heights do
		table.insert(aura.orbiters, {
			part = make(index),
			radius = radius,
			height = height,
			speed = speed,
			angle = (index - 1) * math.pi * 2 / #heights,
			phase = math.random() * math.pi * 2,
		})
	end
end

-- Um raio em zigue-zague entre dois pontos em volta do corpo, que some num piscar
local function spawnBolt(aura: Aura)
	local center = aura.root.Position
	local radius = if aura.isOwn then 2.6 else 1.9
	local minY, maxY = -aura.footOffset + 0.4, if aura.isOwn then 0 else 2.2
	local function around(angle: number): Vector3
		return center + Vector3.new(math.cos(angle) * radius, minY + math.random() * (maxY - minY), math.sin(angle) * radius)
	end
	local startAngle = math.random() * math.pi * 2
	local from, to = around(startAngle), around(startAngle + (math.random() - 0.5) * 2.4)

	local last = from
	for index = 1, 4 do
		local point = if index == 4
			then to
			else from:Lerp(to, index / 4) + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
		local length = (point - last).Magnitude
		if length > 0.05 then
			local segment = Instance.new("Part")
			segment.Anchored = true
			segment.CanCollide = false
			segment.CanQuery = false
			segment.CanTouch = false
			segment.CastShadow = false
			segment.Material = Enum.Material.Neon
			segment.Color = Color3.fromRGB(255, 235, 90)
			segment.Size = Vector3.new(0.12, 0.12, length)
			segment.CFrame = CFrame.lookAt((last + point) / 2, point)
			segment.Parent = effectsFolder
			task.delay(0.09, segment.Destroy, segment)
		end
		last = point
	end
	if aura.light then
		aura.light.Brightness = 1 + math.random() * 2.5
	end
end

-- Cada aura (o nome vem de Progression.Ranks). "source" é de onde saem as partículas: o corpo
-- inteiro, ou só os pés no seu personagem.
local BUILDERS: { [string]: (aura: Aura, source: BasePart) -> () } = {
	Leaves = function(aura)
		local greens = { Color3.fromRGB(90, 170, 60), Color3.fromRGB(140, 195, 70), Color3.fromRGB(70, 140, 50) }
		addOrbiters(aura, { -1.6, -0.6, 0.4 }, 2.4, 0.9, function(index)
			return newPart(aura, { Size = Vector3.new(0.6, 0.05, 0.35), Color = greens[index], Transparency = 0, Material = Enum.Material.SmoothPlastic })
		end)
	end,

	Dust = function(aura)
		emitter(aura, aura.feet, {
			Texture = SMOKE,
			Color = colors(Color3.fromRGB(230, 210, 175)),
			Size = NumberSequence.new(0.5, 1.4),
			Transparency = NumberSequence.new(0.55, 1),
			Lifetime = range(1.2, 1.8),
			Rate = 6,
			Speed = range(0.3, 0.8),
			SpreadAngle = Vector2.new(40, 40),
			Rotation = range(0, 360),
			RotSpeed = range(-40, 40),
		})
	end,

	Bubbles = function(aura)
		emitter(aura, aura.feet, {
			Texture = SPARKLE,
			Color = colors(Color3.fromRGB(150, 255, 90)),
			LightEmission = 0.6,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(0.5, 0.45),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Transparency = NumberSequence.new(0.1, 0.6),
			Lifetime = range(1, 1.6),
			Rate = 10,
			Speed = range(1.5, 2.5),
			SpreadAngle = Vector2.new(10, 10),
		})
	end,

	Sparks = function(aura)
		emitter(aura, aura.feet, {
			Texture = SPARKLE,
			Color = colors(Color3.fromRGB(255, 210, 90), Color3.fromRGB(255, 90, 20)),
			LightEmission = 1,
			Size = NumberSequence.new(0.3, 0),
			Lifetime = range(0.4, 0.8),
			Rate = 22,
			Speed = range(5, 8),
			SpreadAngle = Vector2.new(25, 25),
			Acceleration = Vector3.new(0, -22, 0),
		})
		addLight(aura, Color3.fromRGB(255, 140, 40), 8, 0.8)
	end,

	Orbit = function(aura, source)
		local blue = Color3.fromRGB(80, 190, 255)
		addOrbiters(aura, { -1, 0.2, -1, 0.2 }, 2.5, 3, function()
			local ball = newPart(aura, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45, Color = blue, Transparency = 0 })
			addTrail(ball, blue)
			return ball
		end)
		emitter(aura, source, {
			Texture = SPARKLE,
			Color = colors(blue),
			LightEmission = 1,
			Size = NumberSequence.new(0.25, 0),
			Lifetime = range(1, 1.5),
			Rate = 6,
			Speed = range(0.5, 1),
			SpreadAngle = Vector2.new(180, 180),
		})
		addLight(aura, blue, 8, 0.8)
	end,

	Shadow = function(aura, source)
		local purple = Color3.fromRGB(150, 70, 230)
		emitter(aura, source, {
			Texture = SMOKE,
			Color = colors(purple, Color3.fromRGB(60, 20, 110)),
			LightEmission = 0.3,
			Size = NumberSequence.new(1.2, 2.8),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = range(1.4, 2.2),
			Rate = 14,
			Speed = range(0.4, 1),
			SpreadAngle = Vector2.new(180, 180),
			Rotation = range(0, 360),
			RotSpeed = range(-30, 30),
		})
		emitter(aura, aura.feet, {
			Texture = SPARKLE,
			Color = colors(Color3.fromRGB(200, 130, 255)),
			LightEmission = 1,
			Size = NumberSequence.new(0.3, 0),
			Lifetime = range(0.8, 1.2),
			Rate = 8,
			Speed = range(1, 2),
			SpreadAngle = Vector2.new(30, 30),
		})
		addLight(aura, purple, 10, 1)
	end,

	Lightning = function(aura, source)
		local yellow = Color3.fromRGB(255, 230, 60)
		aura.bolts = true
		emitter(aura, source, {
			Texture = SPARKLE,
			Color = colors(yellow),
			LightEmission = 1,
			Size = NumberSequence.new(0.35, 0),
			Lifetime = range(0.3, 0.6),
			Rate = 12,
			Speed = range(1, 3),
			SpreadAngle = Vector2.new(180, 180),
		})
		addLight(aura, yellow, 10, 1.5)
	end,

	BlueFire = function(aura, source)
		emitter(aura, source, {
			Texture = FIRE,
			Color = colors(Color3.fromRGB(120, 230, 255), Color3.fromRGB(30, 80, 255)),
			LightEmission = 1,
			Size = NumberSequence.new(1.3, 0.2),
			Transparency = NumberSequence.new(0.25, 1),
			Lifetime = range(0.6, 1),
			Rate = 28,
			Speed = range(2, 4),
			SpreadAngle = Vector2.new(10, 10),
			Rotation = range(0, 360),
			RotSpeed = range(-90, 90),
		})
		emitter(aura, source, {
			Texture = SPARKLE,
			Color = colors(Color3.fromRGB(255, 215, 80)),
			LightEmission = 1,
			Size = NumberSequence.new(0.3, 0),
			Lifetime = range(0.8, 1.4),
			Rate = 10,
			Speed = range(1, 2.5),
			SpreadAngle = Vector2.new(60, 60),
		})
		addLight(aura, Color3.fromRGB(80, 170, 255), 12, 1.6)
	end,

	RedAura = function(aura, source)
		local red = Color3.fromRGB(255, 40, 40)
		emitter(aura, source, {
			Texture = FIRE,
			Color = colors(Color3.fromRGB(255, 70, 40), Color3.fromRGB(160, 0, 0)),
			LightEmission = 0.9,
			Size = NumberSequence.new(2, 0.4),
			Transparency = NumberSequence.new(0.2, 1),
			Lifetime = range(0.6, 1.1),
			Rate = 45,
			Speed = range(2.5, 5),
			SpreadAngle = Vector2.new(12, 12),
			Rotation = range(0, 360),
			RotSpeed = range(-120, 120),
		})
		emitter(aura, aura.feet, {
			Texture = SMOKE,
			Color = colors(Color3.fromRGB(120, 0, 0), Color3.fromRGB(40, 0, 0)),
			Size = NumberSequence.new(1.5, 3.5),
			Transparency = NumberSequence.new(0.4, 1),
			Lifetime = range(1.2, 2),
			Rate = 10,
			Speed = range(0.5, 1.2),
			SpreadAngle = Vector2.new(60, 60),
			Rotation = range(0, 360),
			RotSpeed = range(-30, 30),
		})
		emitter(aura, source, {
			Texture = SPARKLE,
			Color = colors(Color3.fromRGB(255, 120, 90)),
			LightEmission = 1,
			Size = NumberSequence.new(0.35, 0),
			Lifetime = range(0.5, 1),
			Rate = 18,
			Speed = range(3, 6),
			SpreadAngle = Vector2.new(180, 180),
		})
		addLight(aura, red, 16, 2.5)
		if not aura.isOwn then
			-- contorno vermelho no corpo (só nos outros: no seu atrapalharia a visão)
			local highlight = Instance.new("Highlight")
			highlight.Adornee = aura.model
			highlight.FillColor = red
			highlight.FillTransparency = 0.8
			highlight.OutlineColor = red
			highlight.OutlineTransparency = 0.2
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Parent = effectsFolder
			table.insert(aura.instances, highlight)
		end
	end,
}

local function textLine(parent: Instance, y: number, height: number, text: string, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromScale(0, y)
	label.Size = UDim2.fromScale(1, height)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = font
	label.TextColor3 = color
	label.Text = text
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Transparency = 0.2
	stroke.Parent = label
	return label
end

-- Cargo (colorido) em cima e o nome (ou, no manequim, quanto falta) embaixo
local function addTitle(aura: Aura, rank: Progression.Rank, bottomText: string): TextLabel?
	local head = aura.model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "AuraTitle"
	gui.Adornee = head
	gui.Size = UDim2.new(8, 0, 1.8, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = effectsFolder
	table.insert(aura.instances, gui)

	textLine(gui, 0, 0.55, rank.Name, rank.Color, Enum.Font.GothamBlack)
	return textLine(gui, 0.58, 0.42, bottomText, WHITE, Enum.Font.GothamBold)
end

-- Manequim: "USANDO AGORA", "VOCÊ JÁ TEM!" ou quantos pontos faltam pra você chegar nesse cargo
local function updateProgress(aura: Aura)
	local label = aura.progress
	if not label then
		return
	end
	local rank = Progression.Ranks[aura.rank]
	local points = player:GetAttribute("TotalPoints") or 0
	if aura.rank == player:GetAttribute("Rank") then
		label.Text = "USANDO AGORA"
		label.TextColor3 = Color3.fromRGB(255, 215, 60)
	elseif aura.rank <= Progression.unlockedRank(points) then
		label.Text = "VOCÊ JÁ TEM! (E pra usar)"
		label.TextColor3 = Color3.fromRGB(120, 255, 140)
	else
		label.Text = `faltam {Progression.format(rank.Points - points)} pts`
		label.TextColor3 = WHITE
	end
end

local function removeAura(model: Model)
	local aura = auras[model]
	if not aura then
		return
	end
	auras[model] = nil
	for _, instance in aura.instances do
		instance:Destroy()
	end
end

-- Põe (ou troca) a aura do cargo no personagem/manequim
local function applyAura(model: Model, rankIndex: number, name: string?, isOwn: boolean)
	removeAura(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	rankIndex = math.clamp(rankIndex, 1, #Progression.Ranks)
	local rank = Progression.Ranks[rankIndex]
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- o nome vai no título
	end

	local aura: Aura = {
		model = model,
		root = root,
		rank = rankIndex,
		isOwn = isOwn,
		footOffset = if humanoid then humanoid.HipHeight + root.Size.Y / 2 else 3,
		body = nil :: any,
		feet = nil :: any,
		orbiters = {},
		light = nil,
		bolts = false,
		nextBolt = 0,
		progress = nil,
		instances = {},
	}
	aura.body = newPart(aura, { Name = "AuraBody", Size = Vector3.new(3, 4.4, 3) })
	aura.feet = newPart(aura, { Name = "AuraFeet", Size = Vector3.new(3.4, 0.2, 3.4) })
	auras[model] = aura

	local builder = BUILDERS[rank.Aura]
	if builder then
		builder(aura, if isOwn then aura.feet else aura.body)
	end
	if not name then
		-- manequim da galeria
		aura.progress = addTitle(aura, rank, "")
		updateProgress(aura)
	elseif not isOwn then
		addTitle(aura, rank, name)
	end
end

-- Segue o corpo a cada quadro: partes das partículas, órbitas e raios
local function update(dt: number)
	local now = os.clock()
	for model, aura in auras do
		if not aura.root:IsDescendantOf(Workspace) then
			removeAura(model) -- personagem sumiu (a varredura põe de novo se ele voltar)
			continue
		end
		local center = aura.root.Position
		aura.body.CFrame = CFrame.new(center)
		aura.feet.CFrame = CFrame.new(center - Vector3.new(0, aura.footOffset - 0.1, 0))
		for _, orbiter in aura.orbiters do
			orbiter.angle += orbiter.speed * dt
			local offset = Vector3.new(
				math.cos(orbiter.angle) * orbiter.radius,
				orbiter.height + math.sin(now * 2 + orbiter.phase) * 0.25,
				math.sin(orbiter.angle) * orbiter.radius
			)
			orbiter.part.CFrame = CFrame.new(center + offset) * CFrame.Angles(now * 1.7 + orbiter.phase, orbiter.angle, now)
		end
		if aura.bolts and now >= aura.nextBolt then
			aura.nextBolt = now + (if aura.isOwn then 0.25 + math.random() * 0.4 else 0.08 + math.random() * 0.25)
			spawnBolt(aura)
		end
	end
end

-- Confere os personagens de todo mundo (nasceu de novo, mudou de cargo, voltou pro alcance)
local function sweepPlayers()
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not humanoid or not root or not character:FindFirstChild("Head") then
			continue
		end
		local aura = auras[character]
		if humanoid.Health <= 0 then
			removeAura(character)
		else
			local rank = other:GetAttribute("Rank") or 1
			if not aura or aura.rank ~= rank or aura.root ~= root then
				applyAura(character, rank, other.DisplayName, other == player)
			end
		end
	end
end

-- Texto do botão de cada pedestal da galeria (só pra você): usar, usando ou quanto falta
local function updatePrompts()
	local points = player:GetAttribute("TotalPoints") or 0
	local current = player:GetAttribute("Rank")
	for _, pedestal in CollectionService:GetTagged("AuraPedestal") do
		local prompt = pedestal:FindFirstChild("AuraPrompt")
		local index = pedestal:GetAttribute("AuraRank")
		local rank = if typeof(index) == "number" then Progression.Ranks[index] else nil
		if prompt and prompt:IsA("ProximityPrompt") and rank then
			prompt.ObjectText = rank.Name
			prompt.ActionText = if index == current
				then "Usando agora"
				elseif index <= Progression.unlockedRank(points) then "Usar esta aura"
				else `Faltam {Progression.format(rank.Points - points)} pts`
		end
	end
end

local function setupMannequin(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	task.spawn(function()
		instance:WaitForChild("HumanoidRootPart", 10)
		if instance.Parent then
			applyAura(instance, instance:GetAttribute("AuraRank") or 1, nil, false)
		end
	end)
end

function AuraController.init()
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "AuraEffects"
	effectsFolder.Parent = Workspace

	RunService.RenderStepped:Connect(update)
	task.spawn(function()
		while true do
			sweepPlayers()
			task.wait(0.5)
		end
	end)
	Players.PlayerRemoving:Connect(function(other)
		if other.Character then
			removeAura(other.Character)
		end
	end)

	CollectionService:GetInstanceAddedSignal("AuraMannequin"):Connect(setupMannequin)
	CollectionService:GetInstanceRemovedSignal("AuraMannequin"):Connect(function(instance)
		if instance:IsA("Model") then
			removeAura(instance)
		end
	end)
	for _, instance in CollectionService:GetTagged("AuraMannequin") do
		setupMannequin(instance)
	end

	-- os manequins e os botões dos pedestais mostram o que você tem: atualiza quando muda
	local function updateGallery()
		for _, aura in auras do
			updateProgress(aura)
		end
		updatePrompts()
	end
	player:GetAttributeChangedSignal("TotalPoints"):Connect(updateGallery)
	player:GetAttributeChangedSignal("Rank"):Connect(updateGallery)
	CollectionService:GetInstanceAddedSignal("AuraPedestal"):Connect(updatePrompts)
	updatePrompts()
end

return AuraController
