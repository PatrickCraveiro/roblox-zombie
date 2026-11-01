-- Mapas do jogo. O lobby fica sempre no Workspace; as fases ficam guardadas no ServerStorage
-- e só a fase da partida atual vai pro Workspace (assim os spawns, portas e a caixa de uma
-- fase não se misturam com os da outra).
--
-- Cada fase é montada por código na hora que o servidor inicia (pasta Maps). Se já existir
-- um modelo com o mesmo nome no Workspace (ex: "Supermercado" editado no Studio), ele é usado.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ambience = require(ReplicatedStorage.Shared.Ambience)

local Maps = script.Parent.Maps
local buildLobby = require(Maps.Lobby)

local MapService = {}

local LOBBY_ORIGIN = CFrame.new(0, 0, 3000) -- longe das fases (que ficam em volta da origem)

-- Fases que ganham uma fachada (com porta pro jogo) no lobby, na ordem
MapService.Maps = {
	{
		id = "Supermercado",
		name = "Supermercado Fim de Feira",
		description = "Portas pagas, Caixa Surpresa e armas melhores no fundo",
		build = require(Maps.Supermarket),
		facade = "Store", -- como a entrada aparece no lobby
		lobbyX = 30, -- onde a entrada fica na praça do lobby
	},
	{
		id = "Estadio",
		name = "Estádio Gol de Placa",
		description = "Gramado enorme, vestiários e camarotes",
		build = require(Maps.Stadium),
		facade = "Stadium",
		lobbyX = 140,
	},
}

local storage: Folder
local models: { [string]: Model } = {}
local activeId: string? = nil
local lobbySpawn: BasePart

-- Lâmpadas com a tag "Flicker" piscam de vez em quando
local function startFlicker(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local light = part:FindFirstChildWhichIsA("Light")
	local material = part.Material
	task.spawn(function()
		while part.Parent do
			task.wait(2 + math.random() * 8)
			for _ = 1, math.random(2, 5) do
				if light then
					light.Enabled = false
				end
				part.Material = Enum.Material.SmoothPlastic
				task.wait(0.04 + math.random() * 0.12)
				if light then
					light.Enabled = true
				end
				part.Material = material
				task.wait(0.04 + math.random() * 0.15)
			end
		end
	end)
end

function MapService.init()
	-- todo mundo começa no lobby; o cliente troca pra noite ao entrar na partida
	Ambience.apply("Lobby")

	-- o chão quadriculado padrão atrapalharia as fases (que ficam na origem)
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	storage = Instance.new("Folder")
	storage.Name = "Maps"
	storage.Parent = ServerStorage

	for _, info in MapService.Maps do
		local model = Workspace:FindFirstChild(info.id)
		if model and model:IsA("Model") then
			print(`[MapService] Usando o mapa "{info.id}" que já está no Workspace`)
		else
			model = info.build()
		end
		model.Name = info.id
		model.Parent = storage
		models[info.id] = model
	end

	local lobby = buildLobby(MapService.Maps)
	lobby:PivotTo(LOBBY_ORIGIN)
	lobby.Parent = Workspace

	-- só o spawn do lobby fica ligado; nas fases a gente posiciona o jogador na mão
	for _, container in { Workspace, storage } do
		for _, spawnLocation in container:GetDescendants() do
			if spawnLocation:IsA("SpawnLocation") then
				spawnLocation.Enabled = spawnLocation:HasTag("LobbySpawn")
			end
		end
	end
	lobbySpawn = CollectionService:GetTagged("LobbySpawn")[1] :: BasePart

	CollectionService:GetInstanceAddedSignal("Flicker"):Connect(startFlicker)
	for _, part in CollectionService:GetTagged("Flicker") do
		startFlicker(part)
	end
end

function MapService.getMapInfo(mapId: string)
	for _, info in MapService.Maps do
		if info.id == mapId then
			return info
		end
	end
	return nil
end

-- Coloca a fase no mundo (só uma por vez)
function MapService.activate(mapId: string): Model?
	MapService.deactivate()
	local model = models[mapId]
	if not model then
		warn(`[MapService] Fase desconhecida: {mapId}`)
		return nil
	end
	model.Parent = Workspace
	activeId = mapId
	return model
end

function MapService.deactivate()
	if activeId then
		models[activeId].Parent = storage
		activeId = nil
	end
end

function MapService.getLobbySpawn(): CFrame
	return lobbySpawn.CFrame
end

-- Um dos pontos de nascimento da fase ativa (SpawnLocations dentro do modelo)
function MapService.getMapSpawn(): CFrame
	local model = activeId and models[activeId]
	if model then
		local spawns = {}
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("SpawnLocation") then
				table.insert(spawns, descendant)
			end
		end
		if #spawns > 0 then
			return spawns[math.random(#spawns)].CFrame
		end
	end
	return CFrame.new(0, 5, 0)
end

return MapService
