-- Inventário de armas de cada jogador (o servidor é quem manda na munição)
-- e validação dos tiros que o cliente manda.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local WeaponStats = require(ReplicatedStorage.Shared.WeaponStats)
local PointsService = require(script.Parent.PointsService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ZombieService = require(script.Parent.ZombieService)

local Remotes = ReplicatedStorage.Remotes

local WeaponService = {}

type Slot = {
	id: string,
	mag: number,
	reserve: number,
	upgraded: boolean?, -- turbinada na Máquina de Upgrade
}

type Inventory = {
	slots: { Slot },
	equipped: number,
	reloading: boolean,
	reloadToken: number,
	lastFire: number,
}

local inventories: { [Player]: Inventory } = {}

-- Onda (micro-ondas): quem estiver colado no jogador leva mesmo fora do leque
local WAVE_CLOSE_RADIUS = 7

local waveParams = RaycastParams.new()
waveParams.FilterType = Enum.RaycastFilterType.Exclude

-- Atributos da arma do slot (normal ou turbinada)
local function slotStats(slot: Slot): Weapons.WeaponDef
	return WeaponStats.get(slot.id, slot.upgraded) :: Weapons.WeaponDef
end

-- Mão Rápida (loja): recarrega e atira mais rápido
local function hasFastHands(player: Player): boolean
	return player:GetAttribute("PerkFastHands") == true
end

local function newSlot(weaponId: string, upgraded: boolean?): Slot
	local stats = WeaponStats.get(weaponId, upgraded) :: Weapons.WeaponDef
	return { id = weaponId, mag = stats.MagSize, reserve = stats.MaxReserve, upgraded = upgraded }
end

local function serialize(inventory: Inventory)
	return {
		slots = inventory.slots,
		equipped = inventory.equipped,
		reloading = inventory.reloading,
	}
end

local function sendInventory(player: Player)
	local inventory = inventories[player]
	if inventory then
		Remotes.InventoryUpdate:FireClient(player, serialize(inventory))
	end
end

local function cancelReload(inventory: Inventory)
	inventory.reloading = false
	inventory.reloadToken += 1
end

local function resetInventory(player: Player)
	local old = inventories[player]
	if old then
		cancelReload(old)
	end
	inventories[player] = {
		slots = { newSlot(PlayerDataService.getStartingWeapon(player)) }, -- a escolhida no Arsenal (ou a pistola)
		equipped = 1,
		reloading = false,
		reloadToken = 0,
		lastFire = 0,
	}
end

-- Arma na mão do personagem (o que os outros jogadores veem)
local function updateWorldModel(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("WeaponModel")
	if old then
		old:Destroy()
	end

	local inventory = inventories[player]
	local slot = inventory and inventory.slots[inventory.equipped]
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not slot or not hand then
		return
	end

	local model = WeaponModels.build(slot.id, false, slot.upgraded)
	model.Name = "WeaponModel"

	local grip = hand:FindFirstChild("RightGripAttachment") :: Attachment?
	local weld = Instance.new("Weld")
	weld.Part0 = hand :: BasePart
	weld.Part1 = model.PrimaryPart
	weld.C0 = if grip then grip.CFrame else CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
	weld.Parent = model.PrimaryPart

	model.Parent = character
end

-- Onda em leque na frente do jogador (micro-ondas). Acerta e empurra os zumbis do leque e os
-- colados em volta, menos os que estão atrás de parede
local function fireWave(player: Player, def: Weapons.WeaponDef, origin: Vector3, aimPoint: Vector3, color: Color3?, hitZombie: (Model, number, BasePart) -> ())
	local direction = (aimPoint - origin) * Vector3.new(1, 0, 1)
	if direction.Magnitude < 0.1 then
		return
	end
	direction = direction.Unit
	local minDot = math.cos(math.rad(def.WaveAngle :: number))

	local ignore: { Instance } = {}
	for _, name in { "Zombies", "Gibs" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	for _, barricade in CollectionService:GetTagged("Barricade") do
		table.insert(ignore, barricade)
	end
	waveParams.FilterDescendantsInstances = ignore

	for _, found in ZombieService.getZombiesInRadius(origin, def.Range) do
		local offset = found.root.Position - origin
		local flat = offset * Vector3.new(1, 0, 1)
		local inFan = flat.Magnitude > 0.1 and flat.Unit:Dot(direction) >= minDot
		local touching = flat.Magnitude <= WAVE_CLOSE_RADIUS
		if (inFan or touching) and math.abs(offset.Y) < 12 and not Workspace:Raycast(origin, offset, waveParams) then
			hitZombie(found.model, def.Damage, found.root)
			ZombieService.knockback(found.model, if flat.Magnitude > 0.1 then flat.Unit else direction, def.Knockback or 0)
		end
	end

	-- os outros jogadores veem a onda (quem atirou já viu na hora, no próprio cliente)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.Gore:FireClient(other, "Wave", origin, direction, def.Range, def.WaveAngle, color)
		end
	end
end

local function onFire(player: Player, origin: any, hits: any)
	local inventory = inventories[player]
	local slot = inventory and inventory.slots[inventory.equipped]
	local def = slot and slotStats(slot)
	if not inventory or not slot or not def then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not head then
		return
	end

	if inventory.reloading then
		return
	end
	if slot.mag <= 0 then
		sendInventory(player) -- cliente e servidor discordaram da munição: ressincroniza
		return
	end
	local now = os.clock()
	local fireRate = def.FireRate * (if hasFastHands(player) then Config.FastHandsFireRateMultiplier else 1)
	if now - inventory.lastFire < fireRate * 0.75 then -- tolerância pra latência
		return
	end
	inventory.lastFire = now
	slot.mag -= 1

	if typeof(origin) ~= "Vector3" or (origin - head.Position).Magnitude > 8 then
		return
	end
	if typeof(hits) ~= "table" then
		return
	end

	-- os outros jogadores ouvem o tiro (quem atirou já tocou o som localmente)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.ShotFired:FireClient(other, player, slot.id)
		end
	end

	-- pontos por acerto: uma vez por zumbi por tiro (senão a escopeta vira máquina de pontos)
	local zombiesHit = {}
	local earnsPoints = player:GetAttribute("InMatch") == true -- no lobby (bonecos de teste) não ganha ponto
	local function applyDamage(zombie: Model, damage: number, part: BasePart)
		local damaged, killed = ZombieService.damage(zombie, damage, player, part)
		if damaged and not killed and earnsPoints and not zombiesHit[zombie] then
			zombiesHit[zombie] = true
			PointsService.add(player, Config.PointsPerHit)
		end
		-- efeitos das armas especiais (Arsenal Lendário)
		if damaged and killed and def.KillEffect then
			Remotes.Gore:FireAllClients(def.KillEffect, part.Position)
		elseif damaged and not killed and def.FreezeTime then
			ZombieService.freeze(zombie, def.FreezeTime)
		end
	end

	-- Corrente Elétrica: depois do acerto, o raio pula pros zumbis mais perto (cada pulo mais fraco)
	local function chainLightning(firstZombie: Model, firstPosition: Vector3)
		local struck = { [firstZombie] = true }
		local points = { firstPosition }
		local current, damage = firstPosition, def.Damage
		for _ = 1, def.ChainJumps or 0 do
			damage *= def.ChainFalloff or 0.8
			local nearest, nearestDistance = nil, math.huge
			for _, found in ZombieService.getZombiesInRadius(current, def.ChainRadius or 16) do
				if not struck[found.model] and found.distance < nearestDistance then
					nearest, nearestDistance = found, found.distance
				end
			end
			if not nearest then
				break
			end
			struck[nearest.model] = true
			current = nearest.root.Position
			table.insert(points, current)
			applyDamage(nearest.model, damage, nearest.root)
		end
		if #points > 1 then
			Remotes.Gore:FireAllClients("Arc", points)
		end
	end

	-- Onda: o cliente só manda pra onde estava mirando
	if def.WaveAngle then
		local hit = hits[1]
		local aimPoint = typeof(hit) == "table" and hit.position
		if typeof(aimPoint) == "Vector3" then
			local color = if slot.upgraded then WeaponStats.upgradeColor(slot.id) elseif def.TracerColors then def.TracerColors[1] else nil
			fireWave(player, def, origin, aimPoint, color, applyDamage)
		end
		return
	end

	-- Tiro normal: cada bala pode atravessar até "Pierce" zumbis
	local maxHits = def.Pellets * (def.Pierce or 1)
	for index = 1, math.min(#hits, maxHits) do
		local hit = hits[index]
		if typeof(hit) ~= "table" then
			continue
		end
		local part, position = hit.part, hit.position
		if typeof(part) ~= "Instance" or not part:IsA("BasePart") or typeof(position) ~= "Vector3" then
			continue
		end

		local zombie = ZombieService.getZombieFromPart(part)
		if not zombie then
			continue
		end
		-- checagens básicas contra trapaça (com folga pra latência)
		if (position - origin).Magnitude > def.Range + 5 then
			continue
		end
		if (position - part.Position).Magnitude > part.Size.Magnitude + 6 then
			continue
		end

		local headshot = part.Name == "Head"
		applyDamage(zombie, def.Damage * (if headshot then def.HeadshotMultiplier else 1), part)
		if def.ChainJumps then
			chainLightning(zombie, position)
		end
	end
end

local function onReload(player: Player)
	local inventory = inventories[player]
	local slot = inventory and inventory.slots[inventory.equipped]
	local def = slot and slotStats(slot)
	if not inventory or not slot or not def or inventory.reloading then
		return
	end
	local magSize = def.MagSize
	if slot.mag >= magSize or slot.reserve <= 0 then
		sendInventory(player)
		return
	end

	inventory.reloading = true
	inventory.reloadToken += 1
	local token = inventory.reloadToken

	-- um pouco mais rápido que o cliente pra compensar a latência
	local reloadTime = def.ReloadTime * (if hasFastHands(player) then Config.FastHandsReloadMultiplier else 1)
	task.delay(math.max(reloadTime - 0.15, 0.1), function()
		if inventories[player] ~= inventory or inventory.reloadToken ~= token then
			return
		end
		inventory.reloading = false
		local amount = math.min(magSize - slot.mag, slot.reserve)
		slot.mag += amount
		slot.reserve -= amount
		sendInventory(player)
	end)
end

local function onEquip(player: Player, index: any)
	local inventory = inventories[player]
	if not inventory or typeof(index) ~= "number" or not inventory.slots[index] or inventory.equipped == index then
		return
	end
	inventory.equipped = index
	cancelReload(inventory)
	updateWorldModel(player)
	sendInventory(player)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	-- morreu: perde as armas e volta só com a inicial
	humanoid.Died:Connect(function()
		resetInventory(player)
	end)
	updateWorldModel(player)
	sendInventory(player)
end

local function setupPlayer(player: Player)
	if inventories[player] then
		return
	end
	resetInventory(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	-- se o visual do avatar trocar as partes do corpo, solda a arma de novo
	player.CharacterAppearanceLoaded:Connect(function()
		updateWorldModel(player)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function WeaponService.init()
	Remotes.WeaponFire.OnServerEvent:Connect(onFire)
	Remotes.WeaponReload.OnServerEvent:Connect(onReload)
	Remotes.WeaponEquip.OnServerEvent:Connect(onEquip)
	Remotes.GetInventory.OnServerInvoke = function(player: Player)
		local inventory = inventories[player]
		return if inventory then serialize(inventory) else nil
	end

	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
	end)
end

function WeaponService.reset(player: Player)
	resetInventory(player)
	updateWorldModel(player)
	sendInventory(player)
end

function WeaponService.findSlot(player: Player, weaponId: string): number?
	local inventory = inventories[player]
	if not inventory then
		return nil
	end
	for index, slot in inventory.slots do
		if slot.id == weaponId then
			return index
		end
	end
	return nil
end

-- Dá a arma (ou recarrega a munição se já tiver). Com os slots cheios, troca a arma da mão.
function WeaponService.giveWeapon(player: Player, weaponId: string)
	local inventory = inventories[player]
	if not inventory or not Weapons[weaponId] then
		return
	end

	-- já tem a arma: só enche a munição (e continua turbinada, se for)
	local slotIndex = WeaponService.findSlot(player, weaponId)
	local upgraded = if slotIndex then inventory.slots[slotIndex].upgraded else nil
	if not slotIndex then
		slotIndex = if #inventory.slots < Config.MaxWeaponSlots then #inventory.slots + 1 else inventory.equipped
	end

	inventory.slots[slotIndex :: number] = newSlot(weaponId, upgraded)
	inventory.equipped = slotIndex :: number
	cancelReload(inventory)
	updateWorldModel(player)
	sendInventory(player)
end

-- Enche pente e munição reserva da arma na mão (continua turbinada, se for).
-- Retorna false se não tem arma ou ela já está cheia
function WeaponService.refillEquipped(player: Player): boolean
	local inventory = inventories[player]
	local slot = inventory and inventory.slots[inventory.equipped]
	if not inventory or not slot then
		return false
	end
	local def = slotStats(slot)
	if slot.mag >= def.MagSize and slot.reserve >= def.MaxReserve then
		return false
	end
	inventory.slots[inventory.equipped] = newSlot(slot.id, slot.upgraded)
	cancelReload(inventory)
	sendInventory(player)
	return true
end

-- Arma que está na mão: (id, turbinada?). nil se não tiver arma
function WeaponService.getEquipped(player: Player): (string?, boolean)
	local inventory = inventories[player]
	local slot = inventory and inventory.slots[inventory.equipped]
	if not slot then
		return nil, false
	end
	return slot.id, slot.upgraded == true
end

-- Turbina a arma da mão: dano e munição dobrados (ver Config) e munição cheia
function WeaponService.upgradeEquipped(player: Player): boolean
	local inventory = inventories[player]
	local slot = inventory and inventory.slots[inventory.equipped]
	if not inventory or not slot or slot.upgraded then
		return false
	end
	inventory.slots[inventory.equipped] = newSlot(slot.id, true)
	cancelReload(inventory)
	updateWorldModel(player)
	sendInventory(player)
	return true
end

return WeaponService
