-- Pontos, abates e headshots de cada jogador (aparecem na lista de jogadores via leaderstats).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PointsService = {}

local function getStat(player: Player, name: string): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(name)
	return stat :: IntValue?
end

local function setupPlayer(player: Player)
	if player:FindFirstChild("leaderstats") then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	-- Colunas da lista de jogadores: Abates | Headshots | Pontos. A lista da Roblox ordena pelo
	-- "Priority" (maior primeiro) e, empatando, pela ordem de criação: os dois batem aqui.
	for index, info in { { "Abates", 0 }, { "Headshots", 0 }, { "Pontos", Config.StartingPoints } } do
		local stat = Instance.new("IntValue")
		stat.Name = info[1]
		stat.Value = info[2]
		local priority = Instance.new("NumberValue")
		priority.Name = "Priority"
		priority.Value = 10 - index
		priority.Parent = stat
		stat.Parent = leaderstats
	end

	leaderstats.Parent = player
end

function PointsService.init()
	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

function PointsService.get(player: Player): number
	local points = getStat(player, "Pontos")
	return if points then points.Value else 0
end

function PointsService.add(player: Player, amount: number)
	local points = getStat(player, "Pontos")
	if points then
		points.Value += amount
	end
end

function PointsService.spend(player: Player, amount: number): boolean
	local points = getStat(player, "Pontos")
	if not points or points.Value < amount then
		return false
	end
	points.Value -= amount
	return true
end

function PointsService.addKill(player: Player)
	local kills = getStat(player, "Abates")
	if kills then
		kills.Value += 1
	end
end

-- Abate com tiro na cabeça: conta no placar e dá o bônus
function PointsService.addHeadshot(player: Player)
	local headshots = getStat(player, "Headshots")
	if headshots then
		headshots.Value += 1
	end
	PointsService.add(player, Config.HeadshotBonus)
end

function PointsService.reset(player: Player)
	local points = getStat(player, "Pontos")
	if points then
		points.Value = Config.StartingPoints
	end
	for _, name in { "Abates", "Headshots" } do
		local stat = getStat(player, name)
		if stat then
			stat.Value = 0
		end
	end
end

return PointsService
