-- Cria os zumbis, cuida da IA (perseguir/atacar), do desmembramento e de quando eles morrem.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local BarricadeService = require(script.Parent.BarricadeService)
local PointsService = require(script.Parent.PointsService)
local ZombieAppearance = require(script.Parent.ZombieAppearance)

local Remotes = ReplicatedStorage.Remotes

local ZombieService = {}

-- Animações da própria Roblox (podem ser usadas em qualquer jogo)
local ANIMATION_IDS = {
	Idle = "rbxassetid://616158929", -- pacote "Zombie"
	Walk = "rbxassetid://616168032", -- pacote "Zombie"
	Run = "rbxassetid://616163682", -- pacote "Zombie"
	Crawl = "rbxassetid://913384386", -- nado padrão do R15: com o corpo deitado, vira o rastejar
	Attack = "rbxassetid://522635514", -- golpe padrão de ferramenta do R15
}

-- Membros que podem ser arrancados e as partes de cada um (a primeira é a que liga no corpo)
local LIMBS = {
	LeftLeg = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" },
	RightLeg = { "RightUpperLeg", "RightLowerLeg", "RightFoot" },
	LeftArm = { "LeftUpperArm", "LeftLowerArm", "LeftHand" },
	RightArm = { "RightUpperArm", "RightLowerArm", "RightHand" },
}

local PART_TO_LIMB: { [string]: string } = {}
for limbName, partNames in LIMBS do
	for _, partName in partNames do
		PART_TO_LIMB[partName] = limbName
	end
end

local THINK_INTERVAL = 0.15
local REPATH_INTERVAL = 1
local WAYPOINT_REACHED = 3
local SPAWN_MIN_PLAYER_DISTANCE = 12
local SPAWN_MAX_PLAYER_DISTANCE = 110
local RUN_ANIMATION_SPEED = 13 -- a partir dessa velocidade o zumbi corre em vez de andar
local CRAWL_PITCH = math.rad(-72) -- quanto o tronco tomba pra frente ao rastejar (+ a corcunda)
local LIMP_LEAN = 0.12 -- inclinação (radianos) pro lado da perna que falta
local GIB_LIFETIME = 6
local GROAN_MIN_INTERVAL = 5 -- segundos entre gemidos de um zumbi (5 a 11)
local GROAN_EXTRA_INTERVAL = 6

type Target = {
	humanoid: Humanoid,
	root: BasePart,
}

type ZombieState = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	rootJoint: Motor6D?, -- junta da cintura (HumanoidRootPart -> LowerTorso)
	rootC0: CFrame,
	baseSpeed: number,
	lastAttack: number,
	lastHitBy: Player?,
	headshot: boolean,
	limbDamage: { [string]: number },
	severed: { [string]: boolean },
	crawling: boolean,
	tracks: { [string]: AnimationTrack },
	currentTrack: AnimationTrack?,
	moveTrack: AnimationTrack?,
	idleTrack: AnimationTrack?,
	moveBaseSpeed: number,
	lastSpeed: number,
	isDummy: boolean, -- boneco de teste do lobby: parado, não conta na rodada nem dá pontos
	onRemoved: (() -> ())?,
	nextGroanAt: number,
	frozenUntil: number?, -- Raio Congelante: parado até esse momento
	frozenColors: { [BasePart]: Color3 }?, -- cores de antes do gelo (pra voltar)
}

local zombiesFolder: Folder
local gibsFolder: Folder
local templates: { Model } = {}
local active: { [Model]: ZombieState } = {}
local activeCount = 0
local warnedNoSpawns = false

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude

-- Dispara (com o modelo do zumbi) sempre que um zumbi sai do jogo: morto ou caiu do mapa
ZombieService.Died = Instance.new("BindableEvent")

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- Congelado pelo Raio Congelante? (fica parado: não anda, não bate, não arranca tábua)
local function isFrozen(state: ZombieState): boolean
	return state.frozenUntil ~= nil and os.clock() < state.frozenUntil
end

local function loadTracks(humanoid: Humanoid): { [string]: AnimationTrack }
	local animator = humanoid:FindFirstChildOfClass("Animator") :: Animator
	local tracks = {}
	for name, id in ANIMATION_IDS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		if ok then
			track.Looped = name ~= "Attack"
			tracks[name] = track
		end
	end
	if tracks.Attack then
		tracks.Attack.Priority = Enum.AnimationPriority.Action
	end
	return tracks
end

-- Toca a animação certa pra velocidade atual (andando ou parado)
local function playMovement(state: ZombieState)
	if isFrozen(state) then
		return -- congelado: a animação fica parada
	end
	local moving = state.lastSpeed > 0.5
	local track = if moving then state.moveTrack else state.idleTrack
	if state.currentTrack ~= track then
		if state.currentTrack then
			state.currentTrack:Stop(0.2)
		end
		state.currentTrack = track
		if track then
			track:Play(0.2)
		end
	end
	if not track then
		return
	end
	if moving then
		track:AdjustSpeed(math.clamp(state.lastSpeed / state.moveBaseSpeed, 0.4, 1.8))
	elseif track == state.moveTrack then
		track:AdjustSpeed(0.2) -- rastejando parado: só mexe devagar
	else
		track:AdjustSpeed(1)
	end
end

-- Escolhe as animações de acordo com o corpo do zumbi (anda, corre ou rasteja)
local function refreshAnimations(state: ZombieState)
	local tracks = state.tracks
	if state.crawling then
		state.moveTrack, state.idleTrack, state.moveBaseSpeed = tracks.Crawl, tracks.Crawl, 5
	elseif state.humanoid.WalkSpeed >= RUN_ANIMATION_SPEED then
		state.moveTrack, state.idleTrack, state.moveBaseSpeed = tracks.Run, tracks.Idle, 16
	else
		state.moveTrack, state.idleTrack, state.moveBaseSpeed = tracks.Walk, tracks.Idle, 9
	end
	playMovement(state)
end

-- Muda a pose da cintura (mancando/rastejando). Protegido: se a junta recusar, o zumbi só
-- fica sem a pose, mas o tiro e o resto continuam funcionando (e o motivo vai pro Output)
local warnedPose = false
local function setRootPose(state: ZombieState, c0: CFrame)
	local rootJoint = state.rootJoint
	if not rootJoint then
		return
	end
	local ok, err = pcall(function()
		rootJoint.C0 = c0
	end)
	if not ok and not warnedPose then
		warnedPose = true
		warn(`[ZombieService] Não deu pra mudar a pose do zumbi ({rootJoint.ClassName}): {err}`)
	end
end

-- Ajusta velocidade e postura depois de perder uma perna
local function updateMobility(state: ZombieState)
	local humanoid = state.humanoid
	local lostLeft = state.severed.LeftLeg == true
	local lostRight = state.severed.RightLeg == true

	if lostLeft and lostRight then
		if state.crawling then
			return
		end
		state.crawling = true
		humanoid.WalkSpeed = math.max(state.baseSpeed * Config.CrawlSpeedMultiplier, 3)

		-- Deita o corpo: tomba o tronco pra frente pela junta da cintura e baixa o
		-- quadril até a barriga ficar rente ao chão.
		-- Altura da junta acima do chão = HipHeight + metade da HumanoidRootPart + C0.Y
		if state.rootJoint then
			local torso = state.model:FindFirstChild("UpperTorso") :: BasePart?
			local targetHeight = (if torso then torso.Size.Z else 1) / 2 + 0.15
			local hipHeight = targetHeight - state.root.Size.Y / 2 - state.rootC0.Y
			local lift = 0
			if hipHeight < 0 then
				lift = -hipHeight
				hipHeight = 0
			end
			humanoid.HipHeight = hipHeight
			setRootPose(state, state.rootC0 * CFrame.new(0, lift, 0) * CFrame.Angles(CRAWL_PITCH, 0, 0))
		end
	elseif lostLeft or lostRight then
		humanoid.WalkSpeed = state.baseSpeed * Config.OneLegSpeedMultiplier
		setRootPose(state, state.rootC0 * CFrame.Angles(0, 0, if lostLeft then LIMP_LEAN else -LIMP_LEAN))
	end

	refreshAnimations(state)
end

local function severLimb(state: ZombieState, limbName: string)
	state.severed[limbName] = true

	local parts: { BasePart } = {}
	for _, partName in LIMBS[limbName] do
		local part = state.model:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	if #parts == 0 then
		return
	end

	-- Solta o membro: apaga toda junta/constraint que liga uma parte do membro a uma parte
	-- de fora. Procurar por tipo (e não pelo nome "LeftHip" etc.) funciona tanto com Motor6D
	-- quanto com o sistema novo de juntas da Roblox. As juntas internas (joelho, tornozelo)
	-- ficam, então o membro cai inteiro.
	local inLimb: { [Instance]: boolean } = {}
	for _, part in parts do
		inLimb[part] = true
	end
	for _, descendant in state.model:GetDescendants() do
		local a: Instance?, b: Instance? = nil, nil
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			a, b = (descendant :: any).Part0, (descendant :: any).Part1
		elseif descendant:IsA("Constraint") then
			local attachment0, attachment1 = descendant.Attachment0, descendant.Attachment1
			a = attachment0 and attachment0.Parent
			b = attachment1 and attachment1.Parent
		end
		if a and b and (inLimb[a] == true) ~= (inLimb[b] == true) then
			descendant:Destroy()
		end
	end

	-- O pedaço sai do zumbi. Fica num grupo de colisão que não bate nos zumbis:
	-- antes ele nascia encaixado no corpo e a física arremessava o zumbi longe.
	local gib = Instance.new("Model")
	gib.Name = limbName
	for _, part in parts do
		part.CanCollide = true
		part.CollisionGroup = "Gibs"
		part.Parent = gib
	end
	gib.Parent = gibsFolder

	-- arremessa o membro pra longe do corpo (só se ele soltou mesmo, senão jogaria o zumbi)
	local base = parts[1]
	if base.AssemblyRootPart ~= state.root then
		if base:CanSetNetworkOwnership() then
			base:SetNetworkOwner(nil)
		end
		local outward = (base.Position - state.root.Position) * Vector3.new(1, 0, 1)
		if outward.Magnitude < 0.1 then
			outward = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
		end
		base:ApplyImpulse((outward.Unit * 8 + Vector3.new(0, 8, 0)) * base.AssemblyMass)
	else
		warn(`[ZombieService] O membro {limbName} não soltou do corpo`)
	end

	Remotes.Gore:FireAllClients("Limb", base.Position)
	task.delay(GIB_LIFETIME, function()
		gib:Destroy()
	end)

	updateMobility(state)
end

-- Tiro na cabeça que mata: a cabeça explode
local function popHead(state: ZombieState)
	local head = state.model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	Remotes.Gore:FireAllClients("Head", head.Position)
	-- some junto: rosto (olhos, boca, dentes) e cabelo
	for _, child in state.model:GetChildren() do
		if child.Name == "Eye" or child.Name == "Mouth" or child.Name == "Tooth" or child:IsA("Accessory") then
			child:Destroy()
		end
	end
	head:Destroy()
end

-- Zumbis só se importam com quem está na partida (não com quem está no lobby)
local function inMatch(player: Player): boolean
	return player:GetAttribute("InMatch") == true
end

local function getAliveRoots(): { BasePart }
	local roots = {}
	for _, player in Players:GetPlayers() do
		if not inMatch(player) then
			continue
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			table.insert(roots, root :: BasePart)
		end
	end
	return roots
end

-- Prefere spawns nem colados nem longe demais dos jogadores; se não tiver, qualquer um longe
-- o bastante; em último caso, qualquer spawn ativo.
local function pickSpawn(): BasePart?
	local valid, notTooClose, ideal = {}, {}, {}
	local roots = getAliveRoots()

	for _, spawnPart in CollectionService:GetTagged("ZombieSpawn") do
		-- atributo "Active" = false desliga o spawn (área do mapa ainda trancada)
		if spawnPart:IsA("BasePart") and spawnPart:IsDescendantOf(Workspace) and spawnPart:GetAttribute("Active") ~= false then
			table.insert(valid, spawnPart)
			local nearest = math.huge
			for _, root in roots do
				nearest = math.min(nearest, (root.Position - spawnPart.Position).Magnitude)
			end
			if nearest >= SPAWN_MIN_PLAYER_DISTANCE then
				table.insert(notTooClose, spawnPart)
				if nearest <= SPAWN_MAX_PLAYER_DISTANCE then
					table.insert(ideal, spawnPart)
				end
			end
		end
	end

	local pool = if #ideal > 0 then ideal elseif #notTooClose > 0 then notTooClose else valid
	if #pool == 0 then
		return nil
	end
	return pool[math.random(#pool)]
end

-- Jogador vivo mais perto + lista de personagens (pra ignorar nos raycasts)
local function findTarget(position: Vector3): (Target?, { Instance })
	local best: Target? = nil
	local bestDistance = math.huge
	local characters = {}

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(characters, character)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and root and humanoid.Health > 0 and inMatch(player) then
				local distance = (root.Position - position).Magnitude
				if distance < bestDistance then
					best = { humanoid = humanoid, root = root }
					bestDistance = distance
				end
			end
		end
	end

	return best, characters
end

-- Dá pra ir em linha reta? (nada no caminho na altura do corpo nem perto do chão)
local function canWalkStraight(from: Vector3, to: Vector3, lowRayDrop: number, ignore: { Instance }): boolean
	if math.abs(to.Y - from.Y) > 4 then
		return false
	end
	losParams.FilterDescendantsInstances = ignore
	local offset = to - from
	if Workspace:Raycast(from, offset, losParams) then
		return false
	end
	local low = Vector3.new(0, -lowRayDrop, 0)
	return Workspace:Raycast(from + low, offset, losParams) == nil
end

-- Segunda Chance (loja): o golpe que derrubaria o jogador levanta ele de novo, com a vida
-- cheia, uns segundos sem levar dano e os zumbis em volta empurrados pra longe
local function useSecondChance(victim: Player, target: Target)
	victim:SetAttribute("PerkSecondChance", nil)
	victim:SetAttribute("Invulnerable", true)
	task.delay(Config.SecondChanceInvulnerableTime, function()
		victim:SetAttribute("Invulnerable", nil)
	end)
	target.humanoid.Health = target.humanoid.MaxHealth

	for model, state in active do
		local offset = (state.root.Position - target.root.Position) * Vector3.new(1, 0, 1)
		if not state.isDummy and offset.Magnitude <= Config.SecondChancePushRadius and offset.Magnitude > 0.01 then
			ZombieService.knockback(model, offset.Unit, 70)
		end
	end
	Sounds.play(Sounds.Ids.Upgrade, target.root, 1, 1.2)
	Remotes.Gore:FireAllClients("Wave", target.root.Position, target.root.CFrame.LookVector, Config.SecondChancePushRadius, 180, Color3.fromRGB(255, 80, 80))
	Remotes.Announce:FireClient(victim, "SEGUNDA CHANCE!", "Você levantou de novo")
end

-- Dano de zumbi num jogador (com a seta de onde veio o golpe)
local function hurtPlayer(target: Target, amount: number, from: Vector3)
	local victim = Players:GetPlayerFromCharacter(target.humanoid.Parent)
	if victim and victim:GetAttribute("Invulnerable") then
		return
	end
	if victim and target.humanoid.Health - amount <= 0 and victim:GetAttribute("PerkSecondChance") == true then
		useSecondChance(victim, target)
		return
	end
	target.humanoid:TakeDamage(amount)
	if victim then
		Remotes.HitDirection:FireClient(victim, from)
	end
end

local function tryAttack(state: ZombieState, target: Target)
	if isFrozen(state) then
		return
	end
	local now = os.clock()
	if now - state.lastAttack < Config.ZombieAttackCooldown then
		return
	end
	state.lastAttack = now
	if state.tracks.Attack then
		state.tracks.Attack:Play(0.1)
	end
	Sounds.play(Sounds.Ids.ZombieAttack, state.root, 0.8, Sounds.randomPitch(0.25), 80)

	-- o dano sai um pouco depois do início do golpe: dá pra desviar
	task.delay(0.3, function()
		if state.humanoid.Health <= 0 or target.humanoid.Health <= 0 or isFrozen(state) then
			return
		end
		if (target.root.Position - state.root.Position).Magnitude <= Config.ZombieAttackRange + 1.5 then
			hurtPlayer(target, Config.ZombieDamage, state.root.Position)
		end
	end)
end

local ICE_COLOR = Color3.fromRGB(150, 220, 255)

local function unfreeze(state: ZombieState)
	if not state.frozenColors then
		return
	end
	for part, color in state.frozenColors do
		part.Color = color
	end
	state.frozenColors = nil
	for _, track in state.tracks do
		track:AdjustSpeed(1)
	end
	playMovement(state)
end

-- Raio Congelante: o zumbi fica azul de gelo e parado (não anda, não bate, não arranca tábua)
function ZombieService.freeze(model: Model, seconds: number)
	local state = active[model]
	if not state or state.humanoid.Health <= 0 then
		return
	end
	state.frozenUntil = math.max(state.frozenUntil or 0, os.clock() + seconds)
	if not state.frozenColors then
		local colors = {}
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				colors[part] = part.Color
				part.Color = part.Color:Lerp(ICE_COLOR, 0.65)
			end
		end
		state.frozenColors = colors
		for _, track in state.tracks do
			track:AdjustSpeed(0)
		end
		state.humanoid:MoveTo(state.root.Position)
	end
	task.delay(seconds + 0.05, function()
		if not isFrozen(state) then
			unfreeze(state)
		end
	end)
end

-- Gemido de vez em quando (cada zumbi no seu tempo, com tom sorteado)
local function maybeGroan(state: ZombieState)
	if os.clock() < state.nextGroanAt then
		return
	end
	state.nextGroanAt = os.clock() + GROAN_MIN_INTERVAL + math.random() * GROAN_EXTRA_INTERVAL
	local head = state.model:FindFirstChild("Head") or state.root
	local id = Sounds.ZombieGroans[math.random(#Sounds.ZombieGroans)]
	Sounds.play(id, head, 0.55, 0.85 + math.random() * 0.3, 70)
end

-- Zumbi que nasceu do lado de fora: vai até a barricada, arranca uma tábua por vez e passa pra
-- dentro. Termina quando ele já entrou (ou morreu). Quem estiver colado na barricada apanha.
local function breakIn(state: ZombieState, barricade: BarricadeService.Barricade)
	local humanoid, root = state.humanoid, state.root
	-- cada zumbi para num pedacinho diferente da frente da barricada
	local sideways = barricade.inward:Cross(Vector3.yAxis)
	local standAt = barricade.outsidePoint + sideways * ((math.random() - 0.5) * 3)
	local nextTear = math.huge

	while active[state.model] and humanoid.Health > 0 and root.Parent do
		task.wait(THINK_INTERVAL)
		maybeGroan(state)
		if isFrozen(state) then
			humanoid:MoveTo(root.Position)
			continue
		end

		local depth = BarricadeService.depthInside(barricade, root.Position)
		if depth > barricade.halfThickness + 2.5 then
			return -- entrou
		end
		if depth > 0 or BarricadeService.plankCount(barricade) == 0 then
			-- sem tábua (ou já no meio do vão): passa pra dentro
			humanoid:MoveTo(barricade.insidePoint)
			nextTear = math.huge
			continue
		end
		if flatDistance(root.Position, standAt) > 2 then
			humanoid:MoveTo(standAt)
			nextTear = math.huge
			continue
		end

		-- na frente da barricada: bate em quem estiver do outro lado ou arranca a próxima tábua
		humanoid:MoveTo(root.Position)
		if nextTear == math.huge then
			nextTear = os.clock() + Config.BarricadeTearTime * 0.6
		end
		local target = findTarget(root.Position)
		if target and (target.root.Position - root.Position).Magnitude <= Config.ZombieAttackRange then
			tryAttack(state, target)
		elseif os.clock() >= nextTear then
			nextTear = os.clock() + Config.BarricadeTearTime
			if state.tracks.Attack then
				state.tracks.Attack:Play(0.1)
			end
			BarricadeService.tear(barricade)
		end
	end
end

local function removeZombie(model: Model)
	local state = active[model]
	if not state then
		return
	end
	active[model] = nil

	if not state.isDummy then
		activeCount -= 1
		local killer = state.lastHitBy
		if killer and killer.Parent and state.humanoid.Health <= 0 then
			PointsService.add(killer, Config.PointsPerKill)
			PointsService.addKill(killer)
			if state.headshot then
				PointsService.addHeadshot(killer)
			end
		end
	end

	for _, track in state.tracks do
		track:Stop()
	end
	-- o corpo não bloqueia mais tiros
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanQuery = false
		end
	end

	if state.isDummy then
		if state.onRemoved then
			state.onRemoved()
		end
	else
		ZombieService.Died:Fire(model)
	end
	task.delay(3, function()
		model:Destroy()
	end)
end

local function runAI(state: ZombieState, barricade: BarricadeService.Barricade?)
	-- primeiro entra pela barricada (se nasceu do lado de fora), depois sai caçando
	if barricade then
		breakIn(state, barricade)
	end

	local model, humanoid, root = state.model, state.humanoid, state.root
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 4,
	})
	local waypoints: { PathWaypoint }? = nil
	local waypointIndex = 1
	local lastRepath = 0
	local lastPosition = root.Position
	local stuckTime = 0

	while active[model] and humanoid.Health > 0 and root.Parent do
		local dt = task.wait(THINK_INTERVAL)
		maybeGroan(state)
		if isFrozen(state) then
			humanoid:MoveTo(root.Position)
			continue
		end
		local target, ignore = findTarget(root.Position)

		if not target then
			humanoid:MoveTo(root.Position)
			waypoints = nil
			continue
		end

		table.insert(ignore, zombiesFolder)
		table.insert(ignore, gibsFolder)
		local targetPosition = target.root.Position
		local distance = (targetPosition - root.Position).Magnitude
		-- raio de baixo passa 1 stud acima do chão (funciona em pé e rastejando)
		local lowRayDrop = humanoid.HipHeight + root.Size.Y / 2 - 1

		if distance <= Config.ZombieAttackRange then
			humanoid:MoveTo(targetPosition)
			tryAttack(state, target)
			waypoints = nil
		elseif canWalkStraight(root.Position, targetPosition, lowRayDrop, ignore) then
			humanoid:MoveTo(targetPosition)
			waypoints = nil
		else
			-- tem obstáculo: usa pathfinding (recalcula de tempos em tempos porque o alvo se mexe)
			if not waypoints or os.clock() - lastRepath > REPATH_INTERVAL then
				lastRepath = os.clock()
				local ok = pcall(path.ComputeAsync, path, root.Position, targetPosition)
				if ok and path.Status == Enum.PathStatus.Success then
					waypoints = path:GetWaypoints()
					waypointIndex = 2
				else
					waypoints = nil
				end
			end

			if waypoints then
				local waypoint = waypoints[waypointIndex]
				while waypoint and flatDistance(waypoint.Position, root.Position) < WAYPOINT_REACHED do
					waypointIndex += 1
					waypoint = waypoints[waypointIndex]
				end
				if waypoint then
					if waypoint.Action == Enum.PathWaypointAction.Jump then
						humanoid.Jump = true
					end
					humanoid:MoveTo(waypoint.Position)
				else
					waypoints = nil
				end
			else
				humanoid:MoveTo(targetPosition) -- sem caminho: tenta ir reto mesmo
			end
		end

		-- Preso? Se quase não andou, pula e força recalcular o caminho
		local moved = flatDistance(root.Position, lastPosition)
		lastPosition = root.Position
		if distance > Config.ZombieAttackRange and moved < humanoid.WalkSpeed * dt * 0.2 then
			stuckTime += dt
			if stuckTime > 1 then
				humanoid.Jump = true
				waypoints = nil
				stuckTime = 0
			end
		else
			stuckTime = 0
		end
	end

	-- cobre o caso do zumbi sumir sem morrer (ex: caiu do mapa)
	removeZombie(model)
end

function ZombieService.init()
	zombiesFolder = Instance.new("Folder")
	zombiesFolder.Name = "Zombies"
	zombiesFolder.Parent = Workspace

	gibsFolder = Instance.new("Folder")
	gibsFolder.Name = "Gibs"
	gibsFolder.Parent = Workspace

	-- pedaços arrancados batem no chão e nos jogadores, mas não nos zumbis
	for _, group in { "Zombies", "Gibs" } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable("Gibs", "Zombies", false)

	templates = ZombieAppearance.buildVariants()
	assert(#templates > 0, "[ZombieService] Não foi possível criar nenhum modelo de zumbi")
	print(`[ZombieService] {#templates} modelos de zumbi prontos`)

	local templateFolder = Instance.new("Folder")
	templateFolder.Name = "ZombieTemplates"
	templateFolder.Parent = ServerStorage
	for _, template in templates do
		template.Parent = templateFolder
	end
end

-- Cria um zumbi (com um dos visuais sorteados) parado no lugar indicado
local function createZombie(pivot: CFrame, health: number, walkSpeed: number, isDummy: boolean): ZombieState
	local model = templates[math.random(#templates)]:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local lowerTorso = model:FindFirstChild("LowerTorso")
	local rootJoint = lowerTorso and lowerTorso:FindFirstChild("Root") :: Motor6D?

	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = walkSpeed
	if isDummy then
		model:SetAttribute("Dummy", true)
	end

	model:PivotTo(pivot)
	model.Parent = zombiesFolder
	root:SetNetworkOwner(nil) -- servidor controla a física: movimento consistente pra todo mundo

	local state: ZombieState = {
		model = model,
		humanoid = humanoid,
		root = root,
		rootJoint = rootJoint,
		rootC0 = if rootJoint then rootJoint.C0 else CFrame.identity,
		baseSpeed = humanoid.WalkSpeed,
		lastAttack = 0,
		lastHitBy = nil,
		headshot = false,
		limbDamage = {},
		severed = {},
		crawling = false,
		tracks = loadTracks(humanoid),
		currentTrack = nil,
		moveTrack = nil,
		idleTrack = nil,
		moveBaseSpeed = 9,
		lastSpeed = 0,
		isDummy = isDummy,
		onRemoved = nil,
		nextGroanAt = os.clock() + 0.5 + math.random() * 5,
	}
	active[model] = state
	if not isDummy then
		activeCount += 1
	end

	refreshAnimations(state)
	humanoid.Running:Connect(function(speed)
		state.lastSpeed = speed
		playMovement(state)
	end)
	humanoid.Died:Connect(function()
		removeZombie(model)
	end)

	return state
end

-- Zumbi da partida: nasce num spawn ativo (do lado de fora de uma barricada, se o spawn for
-- de uma), entra e sai caçando
function ZombieService.spawn(round: number): Model?
	local spawnPart = pickSpawn()
	if not spawnPart then
		if not warnedNoSpawns then
			warnedNoSpawns = true
			warn("[ZombieService] Nenhuma parte com a tag 'ZombieSpawn' no mapa!")
		end
		return nil
	end

	local barricade = BarricadeService.forSpawn(spawnPart)
	local position = spawnPart.Position + Vector3.new(0, 3, 0)
	local pivot = if barricade
		then CFrame.lookAt(position, position + barricade.inward) -- já olhando pra barricada
		else CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local state = createZombie(pivot, Config.zombieHealth(round), Config.zombieSpeed(round), false)
	task.spawn(runAI, state, barricade)
	return state.model
end

-- Boneco de teste: zumbi parado, virado pra frente da parte "spot". onRemoved roda quando ele morre
function ZombieService.spawnDummy(spot: CFrame, health: number, onRemoved: () -> ()): Model
	local pivot = spot.Rotation + spot.Position + Vector3.new(0, 3, 0)
	local state = createZombie(pivot, health, 0, true)
	state.onRemoved = onRemoved
	return state.model
end

-- Acha o zumbi (vivo) dono de uma parte atingida por um tiro
function ZombieService.getZombieFromPart(part: Instance): Model?
	local current: Instance? = part
	while current and current.Parent ~= zombiesFolder do
		current = current.Parent
	end
	if current and active[current :: Model] then
		return current :: Model
	end
	return nil
end

-- Aplica dano numa parte do zumbi. Retorna (causouDano, matou)
function ZombieService.damage(model: Model, amount: number, attacker: Player, hitPart: BasePart): (boolean, boolean)
	local state = active[model]
	if not state or state.humanoid.Health <= 0 then
		return false, false
	end

	local headshot = hitPart.Name == "Head"
	state.lastHitBy = attacker
	state.headshot = headshot
	state.humanoid:TakeDamage(amount)
	local killed = state.humanoid.Health <= 0

	-- dano acumulado no membro: passou do limite, ele cai
	local limbName = PART_TO_LIMB[hitPart.Name]
	if limbName and not killed and not state.severed[limbName] then
		local limbDamage = (state.limbDamage[limbName] or 0) + amount
		state.limbDamage[limbName] = limbDamage
		if limbDamage >= state.humanoid.MaxHealth * Config.LimbHealthFraction then
			severLimb(state, limbName)
		end
	end

	if killed and headshot then
		popHead(state)
	end

	-- nos bonecos de teste, quem atirou vê o número do dano
	if state.isDummy then
		Remotes.DamageNumber:FireClient(attacker, hitPart.Position, amount, headshot)
	end

	return true, killed
end

-- Empurra o zumbi pra longe (onda do micro-ondas). Funciona no vivo e no que acabou de
-- morrer (aí o corpo sai voando). O vivo fica um instante sem controle, senão ele "freia"
function ZombieService.knockback(model: Model, direction: Vector3, strength: number)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or strength <= 0 or direction.Magnitude < 0.01 then
		return
	end
	local push = direction.Unit * strength + Vector3.new(0, strength * 0.35, 0)
	if humanoid.Health > 0 then
		humanoid.PlatformStand = true
		task.delay(0.7, function()
			if humanoid.Parent and humanoid.Health > 0 then
				humanoid.PlatformStand = false
			end
		end)
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored then
			part.AssemblyLinearVelocity = push
		end
	end
end

-- Zumbis vivos dentro de um raio (pra explosões). Retorna { modelo, parte central, distância }
function ZombieService.getZombiesInRadius(position: Vector3, radius: number): { { model: Model, root: BasePart, distance: number } }
	local found = {}
	for model, state in active do
		if state.humanoid.Health > 0 then
			local distance = (state.root.Position - position).Magnitude
			if distance <= radius then
				table.insert(found, { model = model, root = state.root, distance = distance })
			end
		end
	end
	return found
end

function ZombieService.aliveCount(): number
	return activeCount
end

-- Apaga os zumbis da partida (os bonecos de teste do lobby ficam)
function ZombieService.clear()
	for model, state in active do
		if not state.isDummy then
			active[model] = nil
		end
	end
	activeCount = 0
	for _, child in zombiesFolder:GetChildren() do
		if not child:GetAttribute("Dummy") then
			child:Destroy()
		end
	end
	gibsFolder:ClearAllChildren()
end

return ZombieService
