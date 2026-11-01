-- Lobby: a porta de cada fase (parou nela, entra na fila) e os zumbis de treino do Treinamento.
--
-- Portas das fases (parte com a tag "MapPortal" = região na frente da porta): sem partida
-- rolando, a porta com gente começa uma contagem; quem estiver nela quando zerar entra na
-- partida. Com partida rolando, parar na porta da fase atual coloca o jogador direto nela.
--
-- Quem está numa porta recebe o atributo "PortalStatus" (texto que o HUD mostra no meio da
-- tela, com a contagem). Fora da porta o atributo some.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapService = require(script.Parent.MapService)
local RoundService = require(script.Parent.RoundService)
local ZombieService = require(script.Parent.ZombieService)

local LobbyService = {}

local START_COUNTDOWN = 5
local UPDATE_INTERVAL = 0.25
local DUMMY_RESPAWN_DELAY = 3

type Portal = {
	pad: BasePart,
	mapId: string,
	mapName: string,
	statusLabels: { TextLabel },
}

local portals: { Portal } = {}
local countingPortal: Portal? = nil
local countdownEndsAt = 0

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root :: BasePart
	end
	return nil
end

-- Quem está dentro da região da porta (a caixa da parte, com folga em cima)
local function playersOnPad(pad: BasePart): { Player }
	local list = {}
	local half = pad.Size / 2
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		if root and not player:GetAttribute("InMatch") then
			local offset = pad.CFrame:PointToObjectSpace(root.Position)
			if math.abs(offset.X) <= half.X and math.abs(offset.Z) <= half.Z and offset.Y > -half.Y - 2 and offset.Y < half.Y + 6 then
				table.insert(list, player)
			end
		end
	end
	return list
end

local function setStatus(portal: Portal, text: string)
	for _, label in portal.statusLabels do
		if label.Text ~= text then
			label.Text = text
		end
	end
end

-- Texto no meio da tela de quem está em cima de um portal (nil = não mostra nada)
local function applyPlayerStatus(status: { [Player]: string })
	for _, player in Players:GetPlayers() do
		local text = status[player]
		if player:GetAttribute("PortalStatus") ~= text then
			player:SetAttribute("PortalStatus", text)
		end
	end
end

local function plural(count: number): string
	return if count == 1 then "1 jogador" else `{count} jogadores`
end

local function updatePortals()
	local status: { [Player]: string } = {}

	-- Partida rolando: só o portal da fase atual aceita gente
	if RoundService.isRunning() then
		countingPortal = nil
		local activeMap = RoundService.getMapId()
		for _, portal in portals do
			local onPad = playersOnPad(portal.pad)
			if portal.mapId ~= activeMap then
				setStatus(portal, "Espere a partida atual terminar")
				for _, player in onPad do
					status[player] = "Já tem uma partida rolando em outra fase\nEspere ela terminar"
				end
			elseif not RoundService.canJoin() then
				setStatus(portal, "Partida terminando...")
				for _, player in onPad do
					status[player] = "A partida está terminando\nEspere um pouco"
				end
			else
				setStatus(portal, "PARTIDA ROLANDO - pare na porta pra entrar")
				for _, player in onPad do
					status[player] = `Entrando em {string.upper(portal.mapName)}...`
					task.spawn(RoundService.joinMatch, player)
				end
			end
		end
		applyPlayerStatus(status)
		return
	end

	-- Sem partida: o portal com gente conta até começar
	local waiting: { [Portal]: { Player } } = {}
	local busiest: Portal? = nil
	for _, portal in portals do
		waiting[portal] = playersOnPad(portal.pad)
		if #waiting[portal] > 0 and (not busiest or #waiting[portal] > #waiting[busiest]) then
			busiest = portal
		end
	end

	if countingPortal and #waiting[countingPortal] == 0 then
		countingPortal = nil -- todo mundo saiu da porta: cancela
	end
	if not countingPortal and busiest then
		countingPortal = busiest
		countdownEndsAt = os.clock() + START_COUNTDOWN
	end

	for _, portal in portals do
		local onPad = waiting[portal]
		if portal == countingPortal then
			local seconds = math.max(0, math.ceil(countdownEndsAt - os.clock()))
			setStatus(portal, `Começa em {seconds}s - {plural(#onPad)}`)
			for _, player in onPad do
				status[player] = `{string.upper(portal.mapName)}\nComeça em {seconds}s  •  {plural(#onPad)} na porta`
			end
		elseif countingPortal then
			setStatus(portal, "Outra fase vai começar")
			for _, player in onPad do
				status[player] = `{countingPortal.mapName} vai começar\nVá pra porta dela pra jogar junto`
			end
		else
			setStatus(portal, "Pare na porta pra jogar")
		end
	end
	applyPlayerStatus(status)

	if countingPortal and os.clock() >= countdownEndsAt then
		local portal = countingPortal
		countingPortal = nil
		print(`[LobbyService] Começando "{portal.mapId}" com {plural(#waiting[portal])}`)
		RoundService.startMatch(portal.mapId, waiting[portal])
	end
end

-- Boneco de teste: zumbi parado com a vida de uma rodada; morreu, volta em alguns segundos
local function spawnDummy(spot: BasePart)
	local round = spot:GetAttribute("Round")
	local health = Config.zombieHealth(if typeof(round) == "number" then round else 1)
	ZombieService.spawnDummy(spot.CFrame, health, function()
		task.delay(DUMMY_RESPAWN_DELAY, spawnDummy, spot)
	end)
end

local function setupPortal(pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	local mapId = pad:GetAttribute("MapId")
	local info = typeof(mapId) == "string" and MapService.getMapInfo(mapId)
	if not info then
		warn(`[LobbyService] Portal "{pad:GetFullName()}" com MapId desconhecido: {mapId}`)
		return
	end

	local labels = {}
	local sign = pad.Parent and pad.Parent:FindFirstChild("PortalSign")
	if sign then
		for _, descendant in sign:GetDescendants() do
			if descendant:IsA("TextLabel") and descendant.Name == "Status" then
				table.insert(labels, descendant)
			end
		end
	end
	table.insert(portals, { pad = pad, mapId = mapId :: string, mapName = info.name, statusLabels = labels })
end

function LobbyService.init()
	for _, pad in CollectionService:GetTagged("MapPortal") do
		setupPortal(pad)
	end
	print(`[LobbyService] {#portals} portais prontos`)

	-- o loop dos portais roda antes dos bonecos: se algo der errado neles, os portais funcionam
	task.spawn(function()
		while true do
			-- um erro (ex: ao começar a partida) aparece no Output mas não trava o lobby
			local ok, err = pcall(updatePortals)
			if not ok then
				warn(`[LobbyService] Erro nos portais: {err}`)
			end
			task.wait(UPDATE_INTERVAL)
		end
	end)

	for _, spot in CollectionService:GetTagged("DummySpot") do
		if spot:IsA("BasePart") then
			local ok, err = pcall(spawnDummy, spot)
			if not ok then
				warn(`[LobbyService] Erro ao criar boneco de teste: {err}`)
			end
		end
	end
end

return LobbyService
