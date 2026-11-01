-- Passes pagos (Premium.luau): confere quem tem cada passe quando entra, abre a janela de compra
-- da Roblox e libera na hora quando a pessoa compra. Quem tem o passe ganha o atributo dele
-- (ex: "PassArsenal" = true).
--
-- Vitrines no mapa: partes com a tag "PremiumStand" e o atributo "Pass" (ex: "Arsenal") ganham
-- o botão de comprar (a do lobby fica perto de onde os jogadores nascem).

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Premium = require(ReplicatedStorage.Shared.Premium)

local Remotes = ReplicatedStorage.Remotes

local PremiumService = {}

-- Libera o passe (e, se for pacote, os passes que vêm dentro dele)
local function grant(player: Player, pass: Premium.Pass)
	player:SetAttribute(pass.Attribute, true)
	for _, key in pass.Includes or {} do
		local included = Premium.Passes[key]
		if included then
			player:SetAttribute(included.Attribute, true)
		end
	end
end

local function checkOwnership(player: Player)
	for _, pass in Premium.Passes do
		local owns = false
		if RunService:IsStudio() and Premium.StudioOwnsAll then
			owns = true
		elseif pass.Id > 0 then
			local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			owns = ok and result == true
		end
		if owns then
			grant(player, pass)
		end
	end
end

function PremiumService.owns(player: Player, key: string): boolean
	local pass = Premium.Passes[key]
	return pass ~= nil and player:GetAttribute(pass.Attribute) == true
end

-- Abre a janela de compra do passe (se a pessoa ainda não tem)
function PremiumService.prompt(player: Player, key: string)
	local pass = Premium.Passes[key]
	if not pass then
		return
	end
	if PremiumService.owns(player, key) then
		Remotes.Notify:FireClient(player, `Você já tem o {pass.Name}!`)
		return
	end
	if pass.Id <= 0 then
		Remotes.Notify:FireClient(player, `{pass.Name}: em breve na loja`)
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.Id)
end

local function setupStand(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local key = instance:GetAttribute("Pass")
	local pass = if typeof(key) == "string" then Premium.Passes[key] else nil
	if not pass then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Comprar " .. pass.Name
	prompt.ObjectText = "Passe premium"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = instance
	prompt.Triggered:Connect(function(player)
		PremiumService.prompt(player, key :: string)
	end)
end

function PremiumService.init()
	Players.PlayerAdded:Connect(checkOwnership)
	for _, player in Players:GetPlayers() do
		task.spawn(checkOwnership, player)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, pass in Premium.Passes do
			if pass.Id == passId then
				grant(player, pass)
				Remotes.Announce:FireClient(player, `{string.upper(pass.Name)} DESBLOQUEADO!`, "Obrigado pelo apoio! Procure a parede dourada nas fases")
			end
		end
	end)

	CollectionService:GetInstanceAddedSignal("PremiumStand"):Connect(setupStand)
	for _, instance in CollectionService:GetTagged("PremiumStand") do
		setupStand(instance)
	end
end

return PremiumService
