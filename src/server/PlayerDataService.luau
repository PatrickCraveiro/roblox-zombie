-- Dados salvos de cada jogador (DataStore da Roblox): moedas, armas liberadas no Arsenal do
-- lobby, a arma escolhida pra começar a partida, os pontos somados de todas as partidas (que dão
-- o cargo de aura, ver Progression.luau) e o dia do último bônus diário.
--
-- O cliente lê pelos atributos do jogador:
--   Coins (número), OwnedWeapons (ids separados por vírgula), EquippedWeapon (id),
--   TotalPoints (número) e Rank (índice do cargo em Progression.Ranks)
-- e pede pra comprar/equipar pelo RemoteFunction "ArsenalAction".
--
-- Se o DataStore não responder (ex: Studio sem acesso às APIs), o jogador joga normal, mas o
-- progresso dessa sessão não é salvo (pra não apagar o que já estava na nuvem).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local PremiumService = require(script.Parent.PremiumService)

local Remotes = ReplicatedStorage.Remotes

local PlayerDataService = {}

local STORE_NAME = "PlayerData_v1"

type Profile = {
	coins: number,
	owned: { [string]: boolean },
	equipped: string,
	totalPoints: number, -- pontos ganhos em todas as partidas (não diminui gastando)
	bonusDay: number, -- dia em que já ganhou o bônus da 1ª partida
	canSave: boolean,
}

export type MatchReward = {
	coins: number,
	bonuses: { string }, -- bônus que entraram (pra mostrar pro jogador)
	rankUp: number?, -- subiu pra esse cargo
	nextHint: string?, -- "Faltam 50 moedas pra Escopeta"
}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

local function getStore(): DataStore?
	if not store then
		local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
		store = if ok then result else nil
	end
	return store
end

-- Atualiza os atributos que o cliente lê
local function publish(player: Player, profile: Profile)
	local owned = {}
	for id in profile.owned do
		table.insert(owned, id)
	end
	table.sort(owned)
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("OwnedWeapons", table.concat(owned, ","))
	player:SetAttribute("EquippedWeapon", profile.equipped)
	player:SetAttribute("TotalPoints", profile.totalPoints)
	player:SetAttribute("Rank", Progression.rankIndex(profile.totalPoints))
end

-- Número do dia no horário de Brasília (o bônus diário vira à meia-noite daqui)
local function today(): number
	return math.floor((os.time() - 3 * 3600) / 86400)
end

local function readNumber(data: any, key: string): number
	return if typeof(data) == "table" and typeof(data[key]) == "number" then data[key] else 0
end

local function save(player: Player)
	local profile = profiles[player]
	local dataStore = getStore()
	if not profile or not profile.canSave or not dataStore or player.UserId <= 0 then
		return
	end
	local owned = {}
	for id in profile.owned do
		table.insert(owned, id)
	end
	local data = {
		coins = profile.coins,
		owned = owned,
		equipped = profile.equipped,
		totalPoints = profile.totalPoints,
		bonusDay = profile.bonusDay,
	}
	local ok, err = pcall(function()
		(dataStore :: DataStore):SetAsync(tostring(player.UserId), data)
	end)
	if not ok then
		warn(`[PlayerData] Não deu pra salvar {player.Name}: {err}`)
	end
end

local function load(player: Player)
	local data, canSave = nil, false
	local dataStore = getStore()
	if dataStore and player.UserId > 0 then
		local ok, result = pcall(function()
			return (dataStore :: DataStore):GetAsync(tostring(player.UserId))
		end)
		if ok then
			data, canSave = result, true
		else
			warn(`[PlayerData] Não deu pra carregar {player.Name} (o progresso desta sessão não será salvo): {result}`)
		end
	end

	local profile: Profile = {
		coins = readNumber(data, "coins"),
		owned = { [Config.StartingWeapon] = true },
		equipped = Config.StartingWeapon,
		totalPoints = readNumber(data, "totalPoints"),
		bonusDay = readNumber(data, "bonusDay"),
		canSave = canSave,
	}
	if typeof(data) == "table" then
		for _, id in data.owned or {} do
			if Weapons[id] then
				profile.owned[id] = true
			end
		end
		if typeof(data.equipped) == "string" and Weapons[data.equipped] then
			profile.equipped = data.equipped
		end
	end
	if player.Parent then
		profiles[player] = profile
		publish(player, profile)
	end
end

-- Pode começar a partida com essa arma? (liberada com moedas, ou VIP com o passe)
local function canEquip(player: Player, profile: Profile, weaponId: string): boolean
	local def = Weapons[weaponId]
	if not def then
		return false
	end
	if def.Pass then
		return PremiumService.owns(player, def.Pass)
	end
	return profile.owned[weaponId] == true
end

-- Pedidos do Arsenal (cliente): "buy" (liberar com moedas), "equip" (arma inicial), "vip" (loja do
-- passe da arma) e "pass" (loja de um passe que não é arma, ex: "DoubleCoins")
local function onArsenalAction(player: Player, action: any, weaponId: any): (boolean, string)
	if action == "pass" then
		if typeof(weaponId) == "string" then
			PremiumService.prompt(player, weaponId)
		end
		return true, ""
	end
	local profile = profiles[player]
	local def = if typeof(weaponId) == "string" then Weapons[weaponId] else nil
	if not profile or not def then
		return false, "Arma inválida"
	end

	if action == "buy" then
		if def.Pass then
			PremiumService.prompt(player, def.Pass)
			return false, "Arma VIP: só com o passe"
		end
		if profile.owned[weaponId] then
			return false, "Você já tem essa arma"
		end
		local price = def.CoinPrice
		if not price then
			return false, "Essa arma não está à venda"
		end
		if profile.coins < price then
			return false, `Faltam {price - profile.coins} moedas`
		end
		profile.coins -= price
		profile.owned[weaponId] = true
		profile.equipped = weaponId -- já deixa equipada
		publish(player, profile)
		task.spawn(save, player)
		return true, `{def.Name} liberada!`
	elseif action == "equip" then
		if not canEquip(player, profile, weaponId) then
			return false, "Libere essa arma primeiro"
		end
		profile.equipped = weaponId
		publish(player, profile)
		task.spawn(save, player)
		return true, `Você vai começar com: {def.Name}`
	elseif action == "vip" then
		if def.Pass then
			PremiumService.prompt(player, def.Pass)
		end
		return true, ""
	end
	return false, "Ação inválida"
end

-- Arma com que o jogador começa a partida (a escolhida no Arsenal, se ainda puder usar)
function PlayerDataService.getStartingWeapon(player: Player): string
	local profile = profiles[player]
	if profile and canEquip(player, profile, profile.equipped) then
		return profile.equipped
	end
	return Config.StartingWeapon
end

-- Fim da partida: dá as moedas (com os bônus) e soma os pontos pro cargo de aura
function PlayerDataService.finishMatch(player: Player, baseCoins: number, points: number, inGroup: boolean): MatchReward?
	local profile = profiles[player]
	if not profile then
		return nil
	end

	local coins = baseCoins
	local bonuses = {}
	if baseCoins > 0 then
		if profile.bonusDay ~= today() then
			profile.bonusDay = today()
			coins *= Config.DailyBonusMultiplier
			table.insert(bonuses, `1ª partida do dia x{Config.DailyBonusMultiplier}`)
		end
		if PremiumService.owns(player, "DoubleCoins") then
			coins *= Config.DoubleCoinsMultiplier
			table.insert(bonuses, `VIP x{Config.DoubleCoinsMultiplier}`)
		end
		if inGroup then
			coins *= Config.GroupBonusMultiplier
			table.insert(bonuses, `em grupo +{math.floor((Config.GroupBonusMultiplier - 1) * 100 + 0.5)}%`)
		end
	end
	coins = math.floor(coins)

	local oldRank = Progression.rankIndex(profile.totalPoints)
	profile.coins += coins
	profile.totalPoints += math.max(math.floor(points), 0)
	local newRank = Progression.rankIndex(profile.totalPoints)
	publish(player, profile)
	task.spawn(save, player)

	local hint = nil
	local nextId, price = Progression.nextWeapon(profile.owned)
	if nextId then
		local name = Weapons[nextId].Name
		hint = if profile.coins >= price
			then `Já dá pra liberar: {name}!`
			else `Faltam {Progression.format(price - profile.coins)} moedas pra {name}`
	end

	return {
		coins = coins,
		bonuses = bonuses,
		rankUp = if newRank > oldRank then newRank else nil,
		nextHint = hint,
	}
end

function PlayerDataService.init()
	Remotes.ArsenalAction.OnServerInvoke = onArsenalAction

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- deixa os outros scripts darem as moedas da partida antes de salvar
		task.defer(function()
			save(player)
			profiles[player] = nil
		end)
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)
end

return PlayerDataService
