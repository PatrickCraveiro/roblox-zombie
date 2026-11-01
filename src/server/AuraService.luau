-- Galeria das Auras (lobby): em cada pedestal com a tag "AuraPedestal" (atributo AuraRank) fica
-- um manequim com a aura daquele cargo, pra todo mundo ver o que dá pra ganhar jogando.
-- O manequim ganha a tag "AuraMannequin" e o cliente (AuraController) põe a aura e o título.
-- O botão "AuraPrompt" do pedestal escolhe essa aura pra usar (se o jogador já tem o cargo).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)

local Remotes = ReplicatedStorage.Remotes

local AuraService = {}

local STATUE_COLOR = Color3.fromRGB(205, 205, 212)

local function buildMannequin(pedestal: Instance)
	local rank = pedestal:GetAttribute("AuraRank")
	if not pedestal:IsA("BasePart") or typeof(rank) ~= "number" then
		return
	end

	local prompt = pedestal:FindFirstChild("AuraPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player)
			local _, message = PlayerDataService.chooseRank(player, rank)
			Remotes.Notify:FireClient(player, message)
		end)
	end

	-- boneco liso, todo da mesma cor, como uma estátua
	local description = Instance.new("HumanoidDescription")
	for _, key in { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" } do
		(description :: any)[key] = STATUE_COLOR
	end
	local ok, result = pcall(Players.CreateHumanoidModelFromDescription, Players, description, Enum.HumanoidRigType.R15)
	if not ok then
		warn(`[AuraService] Não deu pra criar o manequim do cargo {rank}: {result}`)
		return
	end
	local model = result :: Model
	model.Name = "AuraMannequin"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- chega inteiro no cliente
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end

	-- em pé em cima do pedestal, olhando pra frente dele
	local rootHeight = if humanoid and root then humanoid.HipHeight + root.Size.Y / 2 else 3
	model:PivotTo(pedestal.CFrame * CFrame.new(0, pedestal.Size.Y / 2 + rootHeight, 0))
	model:SetAttribute("AuraRank", rank)
	model:AddTag("AuraMannequin")
	model.Parent = pedestal.Parent
end

function AuraService.init()
	CollectionService:GetInstanceAddedSignal("AuraPedestal"):Connect(function(pedestal)
		task.spawn(buildMannequin, pedestal)
	end)
	for _, pedestal in CollectionService:GetTagged("AuraPedestal") do
		task.spawn(buildMannequin, pedestal)
	end
end

return AuraService
