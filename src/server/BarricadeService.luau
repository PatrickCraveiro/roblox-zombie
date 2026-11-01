-- Barricadas: as entradas dos zumbis (paredes quebradas, vitrines, portas dos fundos) tampadas
-- com tábuas. O zumbi nasce do lado de fora, vem até a barricada e arranca uma tábua por vez;
-- quando não sobra nenhuma, ele entra. Qualquer jogador perto do buraco (do lado de dentro)
-- segura E pra ir pregando tábuas de volta (BarricadeController no cliente pede, o servidor
-- confere distância e tempo) e ganha uns pontinhos.
--
-- O modelo ganha os atributos "Planks" e "MaxPlanks" (pro cliente saber quantas tábuas tem).
-- Os tiros ignoram a barricada inteira (o WeaponController tira ela do raycast).
--
-- No mapa, cada barricada é um Model com a tag "Barricade" (pronto em MapKit.barricade):
--   Opening        - parte invisível no vão; a frente dela (LookVector) aponta pra dentro
--   Plank1..PlankN - as tábuas, na posição "pregada"
--   ZombieSpawn    - onde os zumbis dessa entrada nascem (do lado de fora)
--
-- O vão barra os jogadores sempre (ninguém sai do mapa por ali) e os zumbis só enquanto
-- tiver pelo menos uma tábua.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local PointsService = require(script.Parent.PointsService)

local Remotes = ReplicatedStorage.Remotes

local BarricadeService = {}

-- grupo de colisão do vão sem tábuas: barra os jogadores, deixa os zumbis passarem
local PASSAGE_GROUP = "ZombiePassage"

type Plank = {
	part: BasePart,
	nailed: CFrame,
	present: boolean,
}

export type Barricade = {
	model: Model,
	opening: BasePart,
	planks: { Plank },
	center: Vector3, -- centro do vão no chão, no meio da parede
	inward: Vector3, -- aponta pra dentro do mapa
	halfThickness: number,
	outsidePoint: Vector3, -- onde o zumbi fica pra arrancar as tábuas
	insidePoint: Vector3, -- pra onde ele vai depois de passar
	lastRepair: { [Player]: number },
}

local barricades: { [Model]: Barricade } = {}

local function plankCount(barricade: Barricade): number
	local count = 0
	for _, plank in barricade.planks do
		if plank.present then
			count += 1
		end
	end
	return count
end

local function refresh(barricade: Barricade)
	local count = plankCount(barricade)
	barricade.opening.CollisionGroup = if count > 0 then "Default" else PASSAGE_GROUP
	barricade.model:SetAttribute("Planks", count)
end

-- Prega (present = true) ou arranca uma tábua. animate = false: muda na hora (começo da partida)
local function setPlank(barricade: Barricade, plank: Plank, present: boolean, animate: boolean)
	plank.present = present
	local part = plank.part
	if present then
		part.Transparency = 0
		part.CanCollide = true
		if animate then
			-- vem de dentro (da mão do jogador) até o lugar dela
			part.CFrame = plank.nailed + barricade.inward * 1.5
			TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = plank.nailed }):Play()
		else
			part.CFrame = plank.nailed
		end
	else
		part.CanCollide = false
		if animate then
			-- o zumbi puxa pra fora: a tábua voa, cai e some
			local goal = (plank.nailed - barricade.inward * 3.5 - Vector3.new(0, 2, 0)) * CFrame.Angles(math.rad(math.random(-60, 60)), 0, math.rad(math.random(-40, 40)))
			TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = goal, Transparency = 1 }):Play()
		else
			part.Transparency = 1
		end
	end
end

local function repair(barricade: Barricade, player: Player)
	local now = os.clock()
	-- um pouco de folga no tempo por causa da latência
	if now - (barricade.lastRepair[player] or 0) < Config.BarricadeRepairCooldown * 0.8 then
		return
	end
	-- prega de baixo pra cima
	for _, plank in barricade.planks do
		if not plank.present then
			barricade.lastRepair[player] = now
			setPlank(barricade, plank, true, true)
			Sounds.play(Sounds.Ids.PlankRepair, barricade.opening, 0.8, Sounds.randomPitch(0.15), 80)
			if player:GetAttribute("InMatch") == true then
				PointsService.add(player, Config.PointsPerBarricadeRepair)
			end
			refresh(barricade)
			return
		end
	end
end

local function setupBarricade(model: Instance)
	if not model:IsA("Model") or barricades[model] then
		return
	end
	local opening = model:FindFirstChild("Opening")
	if not opening or not opening:IsA("BasePart") then
		warn(`[Barricade] "{model:GetFullName()}" precisa de uma parte "Opening"`)
		return
	end

	local planks: { Plank } = {}
	for index = 1, 100 do
		local part = model:FindFirstChild("Plank" .. index)
		if not part or not part:IsA("BasePart") then
			break
		end
		table.insert(planks, { part = part, nailed = part.CFrame, present = true })
	end

	local inward = opening.CFrame.LookVector
	local halfThickness = opening.Size.Z / 2
	local center = opening.Position - Vector3.new(0, opening.Size.Y / 2, 0)

	local barricade: Barricade = {
		model = model,
		opening = opening,
		planks = planks,
		center = center,
		inward = inward,
		halfThickness = halfThickness,
		outsidePoint = center - inward * (halfThickness + 1.8),
		insidePoint = center + inward * (halfThickness + 4),
		lastRepair = setmetatable({}, { __mode = "k" }) :: any,
	}
	barricades[model] = barricade
	model:SetAttribute("MaxPlanks", #planks)
	refresh(barricade)
end

-- O cliente pede pra pregar uma tábua (jogador segurando E perto do buraco)
local function onRepairRequest(player: Player, model: any)
	local barricade = if typeof(model) == "Instance" then barricades[model :: Model] else nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not barricade or not humanoid or humanoid.Health <= 0 or not root then
		return
	end
	-- tem que estar do lado de dentro e perto (com folga pra latência)
	local distance = ((root.Position - barricade.center) * Vector3.new(1, 0, 1)).Magnitude
	if BarricadeService.depthInside(barricade, root.Position) <= 0 or distance > Config.BarricadeRepairRange + 3 then
		return
	end
	repair(barricade, player)
end

function BarricadeService.init()
	for _, group in { "Zombies", PASSAGE_GROUP } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(PASSAGE_GROUP, "Zombies", false)

	CollectionService:GetInstanceAddedSignal("Barricade"):Connect(setupBarricade)
	for _, model in CollectionService:GetTagged("Barricade") do
		setupBarricade(model)
	end
	Remotes.RepairBarricade.OnServerEvent:Connect(onRepairRequest)
end

-- Barricada da entrada onde fica esse spawn (nil = spawn solto, sem barricada)
function BarricadeService.forSpawn(spawnPart: Instance): Barricade?
	local parent = spawnPart.Parent
	return if parent and parent:IsA("Model") then barricades[parent] else nil
end

function BarricadeService.plankCount(barricade: Barricade): number
	return plankCount(barricade)
end

-- Quanto a posição já entrou pra dentro do mapa, a partir do meio da parede (negativo = fora)
function BarricadeService.depthInside(barricade: Barricade, position: Vector3): number
	local offset = (position - barricade.center) * Vector3.new(1, 0, 1)
	return offset:Dot(barricade.inward)
end

-- Um zumbi arranca uma tábua (a de cima primeiro). Retorna false se não tinha nenhuma
function BarricadeService.tear(barricade: Barricade): boolean
	for index = #barricade.planks, 1, -1 do
		local plank = barricade.planks[index]
		if plank.present then
			setPlank(barricade, plank, false, true)
			Sounds.play(Sounds.Ids.PlankTear, barricade.opening, 0.8, Sounds.randomPitch(0.2), 90)
			refresh(barricade)
			return true
		end
	end
	return false
end

-- Começo de cada partida: todas as tábuas no lugar
function BarricadeService.reset()
	for _, barricade in barricades do
		for _, plank in barricade.planks do
			setPlank(barricade, plank, true, false)
		end
		table.clear(barricade.lastRepair)
		refresh(barricade)
	end
end

return BarricadeService
