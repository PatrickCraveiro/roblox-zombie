-- Partidas. O jogador fica no lobby; quando um grupo entra num portal, começa a partida
-- naquela fase: preparar -> rodadas -> fim de jogo -> todo mundo volta pro lobby.
--
-- Estado pros clientes:
--   atributos no ReplicatedStorage: GameState, Round, ZombiesRemaining, Countdown
--   atributo no jogador: InMatch (true = está na partida)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BarricadeService = require(script.Parent.BarricadeService)
local BoxService = require(script.Parent.BoxService)
local DoorService = require(script.Parent.DoorService)
local MapService = require(script.Parent.MapService)
local PointsService = require(script.Parent.PointsService)
local RankingService = require(script.Parent.RankingService)
local ShopService = require(script.Parent.ShopService)
local WeaponService = require(script.Parent.WeaponService)
local ZombieService = require(script.Parent.ZombieService)

local Remotes = ReplicatedStorage.Remotes

local RoundService = {}

local LOBBY_RESPAWN_DELAY = 3

local gameState = "Lobby"
local currentMap: string? = nil
local matchPlayers: { [Player]: boolean } = {}
local matchToken = 0 -- muda quando a partida acaba, pra parar os loops antigos

local function setState(state: string)
	gameState = state
	ReplicatedStorage:SetAttribute("GameState", state)
end

local function setRound(round: number)
	ReplicatedStorage:SetAttribute("Round", round)
end

local function setRemaining(count: number)
	ReplicatedStorage:SetAttribute("ZombiesRemaining", count)
end

-- Anúncio grande só pra quem está na partida
local function announce(title: string, subtitle: string?)
	for player in matchPlayers do
		Remotes.Announce:FireClient(player, title, subtitle)
	end
end

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function countAlive(): number
	local count = 0
	for player in matchPlayers do
		if isAlive(player) then
			count += 1
		end
	end
	return count
end

local function countPlayers(): number
	local count = 0
	for _ in matchPlayers do
		count += 1
	end
	return count
end

-- Cria o personagem e põe ele no lugar certo
local function spawnAt(player: Player, cframe: CFrame)
	-- com StreamingEnabled, garante que o lugar já carregou no cliente antes de mover
	pcall(player.RequestStreamAroundAsync, player, cframe.Position, 5)
	local ok, err = pcall(player.LoadCharacter, player)
	if not ok then
		warn(`[RoundService] Falha ao spawnar {player.Name}: {err}`)
		return
	end
	local character = player.Character
	if character then
		character:PivotTo(cframe + Vector3.new(0, 3, 0))
	end
end

local function spawnInLobby(player: Player)
	spawnAt(player, MapService.getLobbySpawn())
end

local function spawnInMap(player: Player)
	spawnAt(player, MapService.getMapSpawn())
end

local function addToMatch(player: Player)
	matchPlayers[player] = true
	player:SetAttribute("InMatch", true)
	-- começa do zero (e sem as armas grátis do Treinamento)
	PointsService.reset(player)
	WeaponService.reset(player)
	ShopService.resetPlayer(player)
end

local function respawnDead()
	for player in matchPlayers do
		if not isAlive(player) then
			task.spawn(spawnInMap, player)
		end
	end
end

-- Retorna true se alguém sobreviveu à rodada
local function runRound(round: number, token: number): boolean
	local total = Config.zombieCount(round, countPlayers())
	local spawned, killed = 0, 0
	setRemaining(total)

	local connection = ZombieService.Died.Event:Connect(function()
		killed += 1
		setRemaining(math.max(total - killed, 0))
	end)

	local survived = true
	while killed < total do
		if token ~= matchToken or countAlive() == 0 then
			survived = false
			break
		end
		if spawned < total and ZombieService.aliveCount() < Config.MaxZombiesAlive then
			if ZombieService.spawn(round) then
				spawned += 1
			end
			task.wait(Config.spawnInterval(round))
		else
			task.wait(0.25)
		end
	end

	connection:Disconnect()
	return survived
end

local function endMatch()
	matchToken += 1
	ZombieService.clear()
	BoxService.hide()

	local players = matchPlayers
	matchPlayers = {}
	for player in players do
		RankingService.recordMatch(player, PointsService.getMatchStats(player))
		player:SetAttribute("InMatch", false)
		ShopService.resetPlayer(player)
		if player.Parent then
			task.spawn(spawnInLobby, player)
		end
	end

	MapService.deactivate()
	currentMap = nil
	setRound(0)
	setRemaining(0)
	setState("Lobby")
end

local function runMatch(token: number)
	setState("Intermission")
	for seconds = Config.IntermissionTime, 1, -1 do
		if token ~= matchToken then
			return
		end
		ReplicatedStorage:SetAttribute("Countdown", seconds)
		task.wait(1)
	end

	local round = 0
	while token == matchToken do
		round += 1
		setRound(round)
		setState("Round")
		announce("RODADA " .. round)
		respawnDead()

		if not runRound(round, token) then
			break
		end

		setState("Break")
		announce("RODADA " .. round .. " CONCLUIDA", `Próxima rodada em {Config.TimeBetweenRounds}s`)
		respawnDead() -- quem morreu volta no intervalo
		task.wait(Config.TimeBetweenRounds)
	end
	if token ~= matchToken then
		return
	end

	setState("GameOver")
	announce("FIM DE JOGO", `Vocês chegaram à rodada {round}`)
	task.wait(Config.GameOverTime)
	if token == matchToken then
		endMatch()
	end
end

function RoundService.isRunning(): boolean
	return currentMap ~= nil
end

function RoundService.getMapId(): string?
	return currentMap
end

-- Dá pra entrar na partida em andamento? (não no finalzinho)
function RoundService.canJoin(): boolean
	return currentMap ~= nil and gameState ~= "GameOver"
end

function RoundService.startMatch(mapId: string, players: { Player })
	if currentMap or #players == 0 then
		return
	end
	if not MapService.activate(mapId) then
		return
	end
	matchToken += 1
	local token = matchToken
	currentMap = mapId
	setRound(0)
	setRemaining(0)

	-- prepara a fase; se algo falhar, avisa no Output mas a partida começa mesmo assim
	for name, prepare in {
		Zumbis = ZombieService.clear,
		Portas = DoorService.reset,
		Caixa = BoxService.reset,
		Barricadas = BarricadeService.reset,
	} do
		local ok, err = pcall(prepare)
		if not ok then
			warn(`[RoundService] Erro preparando {name}: {err}`)
		end
	end

	for _, player in players do
		addToMatch(player)
		task.spawn(spawnInMap, player)
	end
	task.spawn(runMatch, token)
end

function RoundService.joinMatch(player: Player)
	if not RoundService.canJoin() or matchPlayers[player] then
		return
	end
	addToMatch(player)
	spawnInMap(player)
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("InMatch", false)

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.MaxHealth = Config.PlayerMaxHealth
		humanoid.Health = Config.PlayerMaxHealth
		humanoid.WalkSpeed = Config.WalkSpeed

		-- morreu fora da partida (caiu, resetou): volta pro lobby
		humanoid.Died:Connect(function()
			if not matchPlayers[player] then
				task.delay(LOBBY_RESPAWN_DELAY, function()
					if player.Parent and not matchPlayers[player] and player.Character == character then
						spawnInLobby(player)
					end
				end)
			end
		end)
	end)

	task.spawn(spawnInLobby, player)
end

function RoundService.init()
	Players.CharacterAutoLoads = false
	setState("Lobby")

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		if matchPlayers[player] then
			-- saiu no meio da partida: o que ele fez até ali entra no ranking
			RankingService.recordMatch(player, PointsService.getMatchStats(player))
			matchPlayers[player] = nil
			-- todo mundo da partida saiu do jogo: encerra
			if currentMap and next(matchPlayers) == nil then
				endMatch()
			end
		end
	end)
end

return RoundService
