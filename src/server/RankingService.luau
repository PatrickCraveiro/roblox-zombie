-- Ranking salvo na nuvem da Roblox (OrderedDataStore): quem mais matou, quem mais deu headshot
-- e quem mais fez pontos, de dois jeitos:
--   Best  - recorde em uma partida só (guarda o maior valor de cada jogador)
--   Total - soma de todas as partidas
-- O quadro do lobby (parte com a tag "RankingBoard") mostra os 5 melhores de cada lista.
--
-- No Studio o DataStore só funciona com o jogo publicado e com "Enable Studio Access to API
-- Services" ligado (Game Settings > Security). Sem isso o quadro avisa que está indisponível.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RankingService = {}

local VERSION = "v1" -- trocar zera o ranking (cria listas novas)
-- testes no Studio vão pra listas separadas (não aparecem no ranking do jogo publicado)
local SUFFIX = if RunService:IsStudio() then "_Studio" else ""
local TOP = 5
local REFRESH_INTERVAL = 90 -- segundos entre atualizações do quadro (limite de leituras da Roblox)
local MIN_REFRESH_GAP = 65

RankingService.Stats = { "Kills", "Headshots", "Points" }
RankingService.Scopes = { "Best", "Total" }

type Entry = { name: string, value: number }

local stores: { [string]: OrderedDataStore } = {}
local names: { [number]: string } = {}
local pendingWrites = 0
local dirty = true
local lastRefresh = -math.huge

local function getStore(scope: string, stat: string): OrderedDataStore
	local storeName = `Ranking_{scope}_{stat}_{VERSION}{SUFFIX}`
	if not stores[storeName] then
		stores[storeName] = DataStoreService:GetOrderedDataStore(storeName)
	end
	return stores[storeName]
end

local function getName(userId: number): string
	if not names[userId] then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		names[userId] = if ok and name then name else `Jogador {userId}`
	end
	return names[userId]
end

-- Escreve no quadro do lobby: listas (scope -> stat -> entradas) ou uma mensagem de status
local function updateBoards(lists: { [string]: { [string]: { Entry } } }?, status: string)
	for _, board in CollectionService:GetTagged("RankingBoard") do
		for _, label in board:GetDescendants() do
			if not label:IsA("TextLabel") then
				continue
			end
			if label.Name == "Status" then
				label.Text = status
			elseif lists and string.sub(label.Name, 1, 5) == "List_" then
				local scope, stat = string.match(label.Name, "^List_(%a+)_(%a+)$")
				local entries = scope and lists[scope] and lists[scope][stat]
				if entries then
					local lines = {}
					for position, entry in entries do
						table.insert(lines, `{position}. {entry.name}  <b>{entry.value}</b>`)
					end
					label.Text = if #lines > 0 then table.concat(lines, "\n") else "ninguém ainda"
				end
			end
		end
	end
end

-- Lê os 5 melhores de cada lista e atualiza o quadro
function RankingService.refresh()
	lastRefresh = os.clock()
	dirty = false
	local lists = {}
	for _, scope in RankingService.Scopes do
		lists[scope] = {}
		for _, stat in RankingService.Stats do
			local ok, result = pcall(function()
				local page = getStore(scope, stat):GetSortedAsync(false, TOP):GetCurrentPage()
				local entries: { Entry } = {}
				for _, item in page do
					table.insert(entries, { name = getName(tonumber(item.key) :: number), value = item.value })
				end
				return entries
			end)
			if not ok then
				updateBoards(nil, "Ranking indisponível agora (no Studio: publique o jogo e ligue o acesso às APIs)")
				warn(`[Ranking] Não deu pra ler o ranking: {result}`)
				return
			end
			lists[scope][stat] = result
		end
	end
	updateBoards(lists, `Atualizado às {os.date("%H:%M")}`)
end

-- Guarda o que o jogador fez numa partida (chamado quando a partida acaba ou ele sai no meio)
function RankingService.recordMatch(player: Player, stats: { [string]: number })
	local userId = player.UserId
	if userId <= 0 then
		return -- jogador de teste do Studio (servidor local) não tem conta
	end
	names[userId] = player.Name
	local key = tostring(userId)
	for _, stat in RankingService.Stats do
		local value = math.floor(stats[stat] or 0)
		if value <= 0 then
			continue
		end
		pendingWrites += 2
		task.spawn(function()
			local ok, err = pcall(function()
				getStore("Total", stat):IncrementAsync(key, value)
			end)
			if not ok then
				warn(`[Ranking] Não deu pra salvar o total: {err}`)
			end
			pendingWrites -= 1
		end)
		task.spawn(function()
			local ok, err = pcall(function()
				getStore("Best", stat):UpdateAsync(key, function(old)
					if typeof(old) == "number" and old >= value then
						return nil -- o recorde antigo é maior: não muda nada
					end
					return value
				end)
			end)
			if not ok then
				warn(`[Ranking] Não deu pra salvar o recorde: {err}`)
			end
			pendingWrites -= 1
		end)
	end
	dirty = true
end

function RankingService.init()
	task.spawn(function()
		task.wait(3)
		while true do
			local sinceLast = os.clock() - lastRefresh
			if (dirty and sinceLast >= MIN_REFRESH_GAP) or sinceLast >= REFRESH_INTERVAL then
				RankingService.refresh()
			end
			task.wait(5)
		end
	end)

	-- servidor fechando: espera os salvamentos que estão no caminho terminarem
	game:BindToClose(function()
		local deadline = os.clock() + 20
		while pendingWrites > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return RankingService
