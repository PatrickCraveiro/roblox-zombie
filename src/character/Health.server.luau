-- Substitui o script de regeneração padrão da Roblox (por isso o nome "Health").
-- A vida volta rápido depois de alguns segundos sem levar dano.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

local lastHealth = humanoid.Health
local lastDamageTime = 0

humanoid.HealthChanged:Connect(function(health)
	if health < lastHealth then
		lastDamageTime = os.clock()
	end
	lastHealth = health
end)

while humanoid.Health > 0 do
	local dt = task.wait(0.1)
	if humanoid.Health < humanoid.MaxHealth and os.clock() - lastDamageTime >= Config.HealthRegenDelay then
		humanoid.Health = math.min(humanoid.Health + Config.HealthRegenPerSecond * dt, humanoid.MaxHealth)
	end
end
