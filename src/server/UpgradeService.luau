-- Máquina de Upgrade: turbina a arma que está na mão do jogador. Ela fica vermelha, o dano
-- e a munição (pente e reserva) dobram e a munição enche. Cada arma só turbina uma vez.
-- Algumas armas têm upgrade especial (tabela "Upgrade" em Weapons.luau, ex: a pistola).
--
-- Qualquer BasePart com a tag "UpgradeMachine" vira uma máquina (o visual pronto está em
-- MapKit.upgradeMachine). Atributo opcional "Price" (padrão Config.UpgradePrice; 0 = grátis).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local WeaponStats = require(ReplicatedStorage.Shared.WeaponStats)
local PointsService = require(script.Parent.PointsService)
local WeaponService = require(script.Parent.WeaponService)

local Remotes = ReplicatedStorage.Remotes

local UpgradeService = {}

-- Chuva de faíscas vermelhas saindo da máquina
local function createBurst(part: BasePart): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 60, 40), Color3.fromRGB(255, 200, 80))
	emitter.LightEmission = 1
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Size = NumberSequence.new(0.35, 0)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Parent = part
	return emitter
end

local function setupMachine(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local price = instance:GetAttribute("Price")
	if typeof(price) ~= "number" then
		price = Config.UpgradePrice
	end
	local cost = price :: number

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Turbinar arma da mão"
	prompt.ObjectText = if cost == 0 then "Grátis" else `{cost} pts`
	prompt.HoldDuration = if cost > 0 then 0.6 else 0 -- segurar E: evita gastar sem querer
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = instance

	local burst = createBurst(instance)

	prompt.Triggered:Connect(function(player)
		local weaponId, upgraded = WeaponService.getEquipped(player)
		if not weaponId then
			return
		end
		if upgraded then
			Remotes.Notify:FireClient(player, "Essa arma já está turbinada")
			return
		end
		if cost > 0 and not PointsService.spend(player, cost) then
			Remotes.Notify:FireClient(player, "Pontos insuficientes")
			return
		end
		if not WeaponService.upgradeEquipped(player) then
			return
		end

		Sounds.play(Sounds.Ids.Upgrade, instance, 1)
		burst:Emit(50)
		local stats = WeaponStats.get(weaponId, true) :: any
		Remotes.Announce:FireClient(player, `{string.upper(stats.Name)}!`, WeaponStats.upgradeDescription(weaponId))
	end)
end

function UpgradeService.init()
	CollectionService:GetInstanceAddedSignal("UpgradeMachine"):Connect(setupMachine)
	for _, instance in CollectionService:GetTagged("UpgradeMachine") do
		setupMachine(instance)
	end
end

return UpgradeService
