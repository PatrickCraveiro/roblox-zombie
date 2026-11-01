-- Armas em primeira pessoa: modelo preso na câmera, tiro, mira, recarga,
-- troca de arma e corrida. O cliente faz o raycast e o servidor valida.
--
-- Controles: botão esquerdo atira, direito mira, R recarrega,
-- 1/2 ou rodinha troca de arma, Shift corre.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WeaponModels = require(Shared:WaitForChild("WeaponModels"))
local WeaponStats = require(Shared:WaitForChild("WeaponStats"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local WeaponController = {}

local HOLD_ANIMATION_ID = "rbxassetid://507768375" -- pose padrão de segurar ferramenta (R15)
local BASE_FOV = 70
local AIM_FOV = 55
local HIP_OFFSET = CFrame.new(0.55, -0.7, -1.4)
local SPRINT_OFFSET = CFrame.new(0.3, -0.9, -1.2) * CFrame.Angles(math.rad(-15), math.rad(50), math.rad(10))

type Slot = { id: string, mag: number, reserve: number, upgraded: boolean? }

local hud
local inventory: { slots: { Slot }, equipped: number } = { slots = {}, equipped = 1 }
local humanoid: Humanoid? = nil

local viewmodel: Model? = nil
local viewmodelId: string? = nil
local aimOffset = CFrame.new(0, -0.6, -1.1)

local triggerHeld = false
local aimHeld = false
local sprintHeld = false
local sprinting = false
local reloading = false
local scopeVisible = false
local reloadToken = 0
local lastShot = 0
local equipReadyAt = 0

-- valores da animação procedural da arma
local aimBlend = 0
local sprintBlend = 0
local reloadBlend = 0
local equipBlend = 0
local kick = 0
local recoilTarget = 0
local recoilCurrent = 0
local recoilApplied = 0
local swayX, swayY = 0, 0
local bobTime = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function approach(current: number, target: number, speed: number, dt: number): number
	return current + (target - current) * math.min(speed * dt, 1)
end

local function currentSlot(): Slot?
	return inventory.slots[inventory.equipped]
end

-- Atributos da arma da mão (já com o upgrade, se for turbinada)
local function currentDef()
	local slot = currentSlot()
	return if slot then WeaponStats.get(slot.id, slot.upgraded) else nil
end

local function isAlive(): boolean
	return humanoid ~= nil and humanoid.Health > 0
end

-- Mão Rápida (loja): recarrega e atira mais rápido
local function hasFastHands(): boolean
	return player:GetAttribute("PerkFastHands") == true
end

local function refreshHud()
	local slot, def = currentSlot(), currentDef()
	if not slot or not def then
		hud.setWeapon("", nil, nil)
		hud.setHint("")
		return
	end

	local low = slot.mag <= math.ceil(def.MagSize * 0.25)
	-- turbinada: cor do upgrade; premium (Arsenal Lendário): dourado
	local color = if slot.upgraded then WeaponStats.upgradeColor(slot.id) elseif def.Pass then Color3.fromRGB(255, 200, 40) else nil
	hud.setWeapon(def.Name, slot.mag, slot.reserve, low, color)
	if reloading then
		hud.setHint("RECARREGANDO...")
	elseif slot.mag == 0 and slot.reserve == 0 then
		hud.setHint("SEM MUNIÇÃO")
	elseif low and slot.reserve > 0 then
		hud.setHint("[R] RECARREGAR")
	else
		hud.setHint("")
	end
end

local function setScoped(scoped: boolean)
	scopeVisible = scoped
	hud.setScope(scoped)
	if viewmodel then
		for _, part in viewmodel:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = if scoped then 1 else 0
			end
		end
	end
end

local function destroyViewmodel()
	if viewmodel then
		viewmodel:Destroy()
	end
	viewmodel, viewmodelId = nil, nil
	if scopeVisible then
		setScoped(false)
	end
end

-- Garante que o modelo na câmera é o da arma equipada (e troca pro vermelho quando turbina)
local function updateViewmodel()
	local slot = currentSlot()
	local id = if slot and isAlive() then slot.id else nil
	local key = if slot and id and slot.upgraded then id .. ":turbo" else id
	if key == viewmodelId then
		return
	end
	destroyViewmodel()
	if slot and id then
		viewmodel = WeaponModels.build(id, true, slot.upgraded)
		viewmodelId = key
		aimOffset = CFrame.new(0, -WeaponModels.getSightHeight(id) - 0.08, -1.1)
		viewmodel.Parent = Workspace.CurrentCamera
		equipBlend = 1
		equipReadyAt = os.clock() + 0.35
	end
end

local function getMuzzle(): Attachment?
	local root = viewmodel and viewmodel.PrimaryPart
	return if root then root:FindFirstChild("Muzzle") :: Attachment? else nil
end

local function cancelReload()
	reloading = false
	reloadToken += 1
end

local function startReload()
	local slot, def = currentSlot(), currentDef()
	if not slot or not def or reloading or not isAlive() then
		return
	end
	local fullMag = def.MagSize
	if slot.mag >= fullMag or slot.reserve <= 0 then
		return
	end

	reloading = true
	reloadToken += 1
	local token = reloadToken
	Remotes.WeaponReload:FireServer()
	refreshHud()

	-- tira o pente... e coloca o novo um pouco antes de terminar
	local reloadTime = def.ReloadTime * (if hasFastHands() then Config.FastHandsReloadMultiplier else 1)
	Sounds.play(Sounds.Ids.Reload, nil, 0.6)
	task.delay(math.max(reloadTime - 0.4, 0.1), function()
		if token == reloadToken then
			Sounds.play(Sounds.Ids.Reload, nil, 0.6, 1.2)
		end
	end)

	task.delay(reloadTime, function()
		if token ~= reloadToken then
			return
		end
		reloading = false
		local amount = math.min(fullMag - slot.mag, slot.reserve)
		slot.mag += amount
		slot.reserve -= amount
		refreshHud()
	end)
end

local function spreadDirection(direction: Vector3, degrees: number): Vector3
	if degrees <= 0 then
		return direction
	end
	local angle = math.random() * math.pi * 2
	local radius = math.rad(degrees) * math.sqrt(math.random())
	return (CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(0, 0, angle) * CFrame.Angles(radius, 0, 0)).LookVector
end

-- Modelo do zumbi dono da parte atingida (ou nil se não for zumbi)
local function getZombieModel(instance: Instance): Model?
	local zombies = Workspace:FindFirstChild("Zombies")
	if not zombies or not instance:IsDescendantOf(zombies) then
		return nil
	end
	local current = instance
	while current.Parent ~= zombies do
		current = current.Parent :: Instance
	end
	return current :: Model
end

-- Raycast que atravessa a HumanoidRootPart (caixa invisível no meio do zumbi),
-- senão ela "rouba" os tiros nas pernas e no zumbi rastejando
local function castBullet(origin: Vector3, direction: Vector3, ignore: { Instance }): RaycastResult?
	local filter = table.clone(ignore)
	for _ = 1, 4 do
		rayParams.FilterDescendantsInstances = filter
		local result = Workspace:Raycast(origin, direction, rayParams)
		if result and result.Instance.Name == "HumanoidRootPart" then
			table.insert(filter, result.Instance)
		else
			return result
		end
	end
	return nil
end

local function fire()
	local slot, def = currentSlot(), currentDef()
	if not slot or not def or not isAlive() then
		return
	end
	local now = os.clock()
	local fireRate = def.FireRate * (if hasFastHands() then Config.FastHandsFireRateMultiplier else 1)
	if reloading or sprinting or now < equipReadyAt or now - lastShot < fireRate then
		return
	end
	if slot.mag <= 0 then
		startReload()
		return
	end
	lastShot = now
	slot.mag -= 1

	local camera = Workspace.CurrentCamera
	local origin = camera.CFrame.Position
	local spread = def.Spread + (def.AimSpread - def.Spread) * aimBlend

	-- tiro atravessa os outros jogadores e os pedaços de zumbi no chão
	local ignore: { Instance } = { camera }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local gibs = Workspace:FindFirstChild("Gibs")
	if gibs then
		table.insert(ignore, gibs)
	end
	-- e as barricadas: elas seguram os zumbis, não os tiros
	for _, barricade in CollectionService:GetTagged("Barricade") do
		table.insert(ignore, barricade)
	end

	local muzzle = getMuzzle()
	local muzzlePosition = if muzzle then muzzle.WorldPosition else origin
	local hits = {}
	local zombieHits = 0
	local tracerColor = if slot.upgraded then WeaponStats.upgradeColor(slot.id) else nil

	if def.WaveAngle then
		-- onda: o servidor acha os zumbis do leque; aqui só mostra a onda na hora
		local look = camera.CFrame.LookVector
		table.insert(hits, { position = origin + look * def.Range })
		Effects.wave(origin, look, def.Range, def.WaveAngle, tracerColor)
	else
		for _ = 1, def.Pellets do
			local direction = spreadDirection(camera.CFrame.LookVector, spread) * def.Range
			local pelletIgnore = table.clone(ignore)
			local endPosition = origin + direction

			-- cada bala pode atravessar até "Pierce" zumbis antes de parar
			for _ = 1, def.Pierce or 1 do
				local result = castBullet(origin, direction, pelletIgnore)
				if not result then
					break
				end
				endPosition = result.Position

				local zombie = getZombieModel(result.Instance)
				if not zombie then
					Effects.impact(result.Position, result.Normal)
					break
				end
				table.insert(hits, { part = result.Instance, position = result.Position })
				zombieHits += 1
				Effects.blood(result.Position, result.Normal)
				table.insert(pelletIgnore, zombie)
			end

			local colors = def.TracerColors
			Effects.tracer(muzzlePosition, endPosition, tracerColor or (if colors then colors[math.random(#colors)] else nil))
		end
	end

	if muzzle then
		Effects.muzzleFlash(muzzle)
	end
	Sounds.play(def.FireSound, nil, def.FireVolume, (def.FirePitch or 1) * Sounds.randomPitch(0.06))
	if zombieHits > 0 then
		hud.showHitmarker()
		Sounds.play(Sounds.Ids.ZombieHit, nil, 0.4, Sounds.randomPitch(0.15))
	end
	kick = 1
	recoilTarget += math.rad(def.Recoil) * (1 - aimBlend * 0.4)

	Remotes.WeaponFire:FireServer(origin, hits)
	refreshHud()

	if slot.mag == 0 then
		startReload()
	end
end

local function equip(index: number)
	if index == inventory.equipped or not inventory.slots[index] or not isAlive() then
		return
	end
	inventory.equipped = index
	cancelReload()
	Remotes.WeaponEquip:FireServer(index)
	updateViewmodel()
	refreshHud()
end

local function applyInventory(data: any)
	if typeof(data) ~= "table" then
		return
	end
	inventory = data
	if not data.reloading then
		cancelReload()
	end
	updateViewmodel()
	refreshHud()
end

local function onRenderStep(dt: number)
	local camera = Workspace.CurrentCamera
	local def = currentDef()
	local alive = isAlive()

	-- correr (não dá pra atirar nem mirar correndo)
	local moving = alive and (humanoid :: Humanoid).MoveDirection.Magnitude > 0.1
	sprinting = alive and sprintHeld and moving and not aimHeld and not triggerHeld
	if alive then
		(humanoid :: Humanoid).WalkSpeed = if sprinting then Config.SprintSpeed else Config.WalkSpeed
	end

	local aiming = alive and aimHeld and not sprinting and not reloading
	aimBlend = approach(aimBlend, if aiming then 1 else 0, 14, dt)
	sprintBlend = approach(sprintBlend, if sprinting then 1 else 0, 10, dt)
	reloadBlend = approach(reloadBlend, if reloading then 1 else 0, 10, dt)
	equipBlend = approach(equipBlend, 0, 9, dt)
	kick = approach(kick, 0, 18, dt)

	if alive and triggerHeld and def and def.Automatic then
		fire()
	end

	-- coice da câmera: sobe no tiro e volta sozinho
	recoilTarget = approach(recoilTarget, 0, 8, dt)
	recoilCurrent = approach(recoilCurrent, recoilTarget, 25, dt)
	local recoilDelta = recoilCurrent - recoilApplied
	recoilApplied = recoilCurrent
	camera.CFrame *= CFrame.Angles(recoilDelta, 0, 0)

	-- cada arma pode ter seu zoom; quanto mais zoom, mais devagar o mouse
	local aimFov = if def and def.AimFov then def.AimFov else AIM_FOV
	camera.FieldOfView = BASE_FOV + (aimFov - BASE_FOV) * aimBlend + 6 * sprintBlend
	UserInputService.MouseDeltaSensitivity = 1 - (1 - aimFov / BASE_FOV) * aimBlend
	hud.setCrosshairVisible(alive and aimBlend < 0.5 and sprintBlend < 0.5)

	-- luneta: mirando com arma de luneta, esconde a arma e mostra a lente
	local scoped = def ~= nil and def.Scope == true and aimBlend > 0.85
	if scoped ~= scopeVisible then
		setScoped(scoped)
	end

	if not viewmodel then
		return
	end

	-- a arma "atrasa" um pouco quando a câmera gira
	local mouseDelta = UserInputService:GetMouseDelta()
	swayX = approach(swayX, math.clamp(mouseDelta.X * 0.003, -0.08, 0.08), 10, dt)
	swayY = approach(swayY, math.clamp(mouseDelta.Y * 0.003, -0.08, 0.08), 10, dt)

	-- balanço ao andar
	local rootPart = if alive then (humanoid :: Humanoid).RootPart else nil
	local speed = if rootPart then (rootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude else 0
	bobTime += dt * speed * 0.55
	local bobAmount = math.min(speed / 16, 1.5) * (1 - aimBlend * 0.85)
	local bob = CFrame.new(math.sin(bobTime) * 0.04 * bobAmount, -math.abs(math.cos(bobTime)) * 0.04 * bobAmount, 0)

	local base = HIP_OFFSET:Lerp(aimOffset, aimBlend):Lerp(SPRINT_OFFSET, sprintBlend)
	local cframe = camera.CFrame
		* base
		* bob
		* CFrame.Angles(swayY, swayX, swayX * 0.5)
		* CFrame.new(0, -equipBlend * 1.2 - reloadBlend * 0.35, kick * 0.15)
		* CFrame.Angles(math.rad(kick * 4) - reloadBlend * 0.5, 0, reloadBlend * 0.5)
	viewmodel:PivotTo(cframe)
end

local function onInputBegan(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprintHeld = true
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		triggerHeld = true
		sprinting = false
		fire()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		aimHeld = true
	elseif input.KeyCode == Enum.KeyCode.R then
		startReload()
	elseif input.KeyCode == Enum.KeyCode.One then
		equip(1)
	elseif input.KeyCode == Enum.KeyCode.Two then
		equip(2)
	end
end

local function onInputEnded(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		triggerHeld = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		aimHeld = false
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		sprintHeld = false
	end
end

local function onInputChanged(input: InputObject, processed: boolean)
	if processed then
		return
	end
	local count = #inventory.slots
	if input.UserInputType == Enum.UserInputType.MouseWheel and count > 1 then
		equip(inventory.equipped % count + 1)
	end
end

local function onCharacterAdded(newCharacter: Model)
	local newHumanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	humanoid = newHumanoid
	triggerHeld, aimHeld = false, false
	cancelReload()

	newHumanoid.Died:Connect(function()
		triggerHeld = false
		cancelReload()
		destroyViewmodel()
		refreshHud()
	end)

	-- pose de segurar a arma (é o que os outros jogadores veem)
	local animator = newHumanoid:WaitForChild("Animator") :: Animator
	local animation = Instance.new("Animation")
	animation.AnimationId = HOLD_ANIMATION_ID
	local ok, track = pcall(animator.LoadAnimation, animator, animation)
	if ok then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play()
	end

	updateViewmodel()
	refreshHud()
end

function WeaponController.init(hudController)
	hud = hudController

	-- primeira pessoa com a arma em todo lugar (lobby e partida)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	UserInputService.MouseIconEnabled = false

	Remotes:WaitForChild("InventoryUpdate").OnClientEvent:Connect(applyInventory)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	UserInputService.InputChanged:Connect(onInputChanged)
	-- roda logo depois da câmera, pra arma acompanhar o frame certo
	RunService:BindToRenderStep("WeaponController", Enum.RenderPriority.Camera.Value + 1, onRenderStep)

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	task.spawn(function()
		local ok, data = pcall(function()
			return Remotes:WaitForChild("GetInventory"):InvokeServer()
		end)
		if ok then
			applyInventory(data)
		end
	end)
end

return WeaponController
