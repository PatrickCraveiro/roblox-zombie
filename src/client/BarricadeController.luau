-- Pregar tábuas nas barricadas: perto de um buraco (do lado de dentro, olhando mais ou menos pra
-- ele), segurar E vai pregando uma tábua atrás da outra. Uma dica aparece na tela quando dá.
-- O servidor (BarricadeService) confere a distância e o tempo entre as tábuas.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local BarricadeController = {}

local UPDATE_INTERVAL = 0.1
local MIN_LOOK_DOT = 0 -- 0 = basta o buraco não estar atrás de você

local hud
local repairRemote: RemoteEvent? = nil
local holding = false
local lastSent = 0

-- Barricada que dá pra consertar agora (a mais perto) e quantas tábuas ela tem
local function findBarricade(): (Model?, number, number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil, 0, 0
	end
	local look = Workspace.CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.01 then
		return nil, 0, 0
	end
	look = look.Unit

	local best: Model?, bestPlanks, bestMax = nil, 0, 0
	local bestDistance = math.huge
	for _, model in CollectionService:GetTagged("Barricade") do
		local opening = model:FindFirstChild("Opening")
		local planks, maxPlanks = model:GetAttribute("Planks"), model:GetAttribute("MaxPlanks")
		if not opening or not opening:IsA("BasePart") or not model:IsDescendantOf(Workspace) then
			continue
		end
		if typeof(planks) ~= "number" or typeof(maxPlanks) ~= "number" or planks >= maxPlanks then
			continue
		end
		-- perto e do lado de dentro
		local offset = (root.Position - opening.Position) * Vector3.new(1, 0, 1)
		local distance = offset.Magnitude
		if distance > Config.BarricadeRepairRange or offset:Dot(opening.CFrame.LookVector) <= 0 then
			continue
		end
		-- olhando pro buraco
		if distance > 1 and look:Dot(-offset.Unit) < MIN_LOOK_DOT then
			continue
		end
		if distance < bestDistance then
			best, bestPlanks, bestMax, bestDistance = model :: Model, planks, maxPlanks, distance
		end
	end
	return best, bestPlanks, bestMax
end

local function update()
	local barricade, planks, maxPlanks = findBarricade()
	if not barricade then
		hud.setActionHint("")
		return
	end
	hud.setActionHint(`Segure [E] pra pregar tábuas   {planks}/{maxPlanks}`)
	if holding and repairRemote and os.clock() - lastSent >= Config.BarricadeRepairCooldown then
		lastSent = os.clock()
		repairRemote:FireServer(barricade)
	end
end

function BarricadeController.init(hudController)
	hud = hudController
	task.spawn(function()
		repairRemote = Remotes:WaitForChild("RepairBarricade") :: RemoteEvent
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.E then
			holding = true
			update() -- a primeira tábua sai na hora
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.E then
			holding = false
		end
	end)

	task.spawn(function()
		while true do
			update()
			task.wait(UPDATE_INTERVAL)
		end
	end)
end

return BarricadeController
