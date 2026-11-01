-- Loja de melhorias: quiosques no mapa (parte com a tag "ShopItem" e o atributo "ItemId",
-- visual pronto em MapKit.shopStand). Os itens estão em Shop.luau:
--   Armor        - Colete Blindado: vida máxima em dobro
--   FastHands    - Mão Rápida: recarga e cadência mais rápidas (WeaponService/WeaponController)
--   SecondChance - Segunda Chance: levanta de novo uma vez (ZombieService)
--   Ammo         - Munição: enche a arma da mão, qualquer uma (até da caixa)
-- As melhorias são atributos no jogador e somem quando ele cai ou a partida acaba.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local PointsService = require(script.Parent.PointsService)
local WeaponService = require(script.Parent.WeaponService)

local Remotes = ReplicatedStorage.Remotes

local ShopService = {}

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if humanoid and humanoid.Health > 0 then humanoid else nil
end

-- Efeito na hora da compra (o resto é só o atributo, que os outros scripts leem)
local function applyPerk(player: Player, itemId: string)
	if itemId == "Armor" then
		local humanoid = getHumanoid(player)
		if humanoid then
			humanoid.MaxHealth = Config.PlayerMaxHealth * Config.ArmorHealthMultiplier
			humanoid.Health = humanoid.MaxHealth
		end
	end
end

local function buy(player: Player, itemId: string, part: BasePart)
	local item = Shop[itemId]
	if not item or not getHumanoid(player) then
		return
	end

	if item.Attribute then
		if player:GetAttribute(item.Attribute) == true then
			Remotes.Notify:FireClient(player, `Você já tem: {item.Name}`)
			return
		end
		if not PointsService.spend(player, item.Price) then
			Remotes.Notify:FireClient(player, "Pontos insuficientes")
			return
		end
		player:SetAttribute(item.Attribute, true)
		applyPerk(player, itemId)
		Remotes.Announce:FireClient(player, string.upper(item.Name), item.Description)
	elseif itemId == "Ammo" then
		if PointsService.get(player) < item.Price then
			Remotes.Notify:FireClient(player, "Pontos insuficientes")
			return
		end
		-- refillEquipped não mexe em nada se a arma já estiver cheia
		if not WeaponService.refillEquipped(player) then
			Remotes.Notify:FireClient(player, "Sua arma já está com a munição cheia")
			return
		end
		PointsService.spend(player, item.Price)
	end
	Sounds.play(Sounds.Ids.Upgrade, part, 0.8, 1.1)
end

local function setupStand(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local itemId = instance:GetAttribute("ItemId")
	local item = if typeof(itemId) == "string" then Shop[itemId] else nil
	if not item then
		warn(`[Shop] "{instance:GetFullName()}" tem ItemId inválido: {itemId}`)
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Comprar " .. item.Name
	prompt.ObjectText = `{item.Price} pts`
	prompt.HoldDuration = 0.4 -- segurar um pouquinho: evita gastar sem querer
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = instance
	prompt.Triggered:Connect(function(player)
		buy(player, itemId :: string, instance)
	end)
end

-- Tira todas as melhorias (caiu, entrou ou saiu de uma partida)
function ShopService.resetPlayer(player: Player)
	for _, item in Shop do
		if item.Attribute then
			player:SetAttribute(item.Attribute, nil)
		end
	end
	player:SetAttribute("Invulnerable", nil)
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.MaxHealth = Config.PlayerMaxHealth
		humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth)
	end
end

function ShopService.init()
	CollectionService:GetInstanceAddedSignal("ShopItem"):Connect(setupStand)
	for _, instance in CollectionService:GetTagged("ShopItem") do
		setupStand(instance)
	end

	-- caiu: perde as melhorias
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				ShopService.resetPlayer(player)
			end)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return ShopService
