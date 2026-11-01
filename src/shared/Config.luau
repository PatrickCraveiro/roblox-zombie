-- Configurações gerais do jogo. Quase todo o balanceamento fica aqui.

local Config = {}

-- Jogador
Config.StartingPoints = 500
Config.PlayerMaxHealth = 100
Config.WalkSpeed = 14
Config.SprintSpeed = 22
Config.HealthRegenDelay = 3 -- segundos sem levar dano até começar a regenerar
Config.HealthRegenPerSecond = 35

-- Armas
Config.StartingWeapon = "Pistol"
Config.MaxWeaponSlots = 2

-- Máquina de Upgrade (no fim do mapa): turbina a arma da mão
Config.UpgradePrice = 5000
Config.UpgradeDamageMultiplier = 2
Config.UpgradeAmmoMultiplier = 2 -- pente e munição reserva

-- Moedas: ganhas jogando (salvas pra sempre), gastas no Arsenal do lobby pra liberar armas e
-- escolher com qual começar a partida (preço de cada arma: CoinPrice em Weapons.luau)
Config.CoinsPerKill = 1
Config.CoinsPerHeadshot = 1
Config.CoinsPerRound = 10 -- por rodada que a partida alcançou
-- Bônus (multiplicam juntos): a 1ª partida do dia (horário de Brasília) vale em dobro, jogar
-- com mais alguém na partida dá +20% e o passe VIP "Moedas em Dobro" dobra sempre
Config.DailyBonusMultiplier = 2
Config.GroupBonusMultiplier = 1.2
Config.DoubleCoinsMultiplier = 2

-- Melhorias da loja (itens e preços em Shop.luau)
Config.ArmorHealthMultiplier = 2 -- Colete Blindado: vida máxima x2
Config.FastHandsReloadMultiplier = 0.5 -- Mão Rápida: recarga leva metade do tempo
Config.FastHandsFireRateMultiplier = 0.75 -- Mão Rápida: intervalo entre tiros x0.75 (~33% mais tiros)
Config.SecondChanceInvulnerableTime = 2 -- segundos sem levar dano depois de levantar
Config.SecondChancePushRadius = 16 -- zumbis até essa distância são empurrados quando você levanta

-- Caixa Surpresa
Config.BoxPrice = 950
Config.BoxRollTime = 4 -- segundos girando as armas
Config.BoxTakeTime = 10 -- segundos pra pegar a arma antes da caixa fechar

-- Pontos
-- (zumbis morrem com poucos tiros, então a morte vale mais pra não demorar a juntar pontos)
Config.PointsPerHit = 10
Config.PointsPerKill = 70
Config.HeadshotBonus = 50 -- a mais quando o abate é com tiro na cabeça (conta no placar "Headshots")

-- Rodadas
Config.IntermissionTime = 10 -- contagem antes da primeira rodada
Config.TimeBetweenRounds = 10
Config.GameOverTime = 10
Config.MaxZombiesAlive = 16 -- limite de zumbis vivos ao mesmo tempo

-- Zumbis (dificuldade pensada pra criança: zumbi lento, morre fácil e bate fraco)
Config.ZombieDamage = 25 -- 4 golpes pra derrubar o jogador
Config.ZombieAttackRange = 4.5
Config.ZombieAttackCooldown = 1.5

-- Barricadas (entradas dos zumbis tampadas com tábuas)
Config.BarricadePlanks = 6 -- máximo de tábuas em cada entrada
Config.BarricadeTearTime = 1.5 -- segundos que um zumbi leva pra arrancar cada tábua
Config.BarricadeRepairCooldown = 0.6 -- segurando E: segundos entre uma tábua e outra
Config.BarricadeRepairRange = 10 -- distância (studs) do buraco pra conseguir pregar
Config.PointsPerBarricadeRepair = 10

-- Desmembramento
Config.LimbHealthFraction = 0.3 -- dano acumulado num membro (fração da vida máxima) pra arrancar
Config.OneLegSpeedMultiplier = 0.5 -- sem uma perna: manca
Config.CrawlSpeedMultiplier = 0.35 -- sem as duas: rasteja

-- Rodada 1: 5 zumbis | 5: 15 | 10: 33 | 20: 83 (com mais jogadores, +50% por jogador)
function Config.zombieCount(round: number, playerCount: number): number
	local base = 5 + (round - 1) * 2 + math.floor(round * round * 0.1)
	local perPlayer = 1 + 0.5 * (math.max(playerCount, 1) - 1)
	return math.floor(base * perPlayer)
end

-- Rodada 1: 60 (2 tiros de pistola) | 5: 180 | 10: 330 | 20: 649
function Config.zombieHealth(round: number): number
	if round <= 10 then
		return 60 + (round - 1) * 30
	end
	return math.floor(330 * 1.07 ^ (round - 10))
end

-- Rodada 1: 6,5 | 5: 8,5 | 10: 11 | máximo 12. O jogador anda a 14: sempre dá pra fugir
function Config.zombieSpeed(round: number): number
	local speed = math.min(6 + round * 0.5, 12)
	return speed + (math.random() - 0.5) -- variação pra não andarem todos iguais
end

function Config.spawnInterval(round: number): number
	return math.max(2.5 - round * 0.1, 0.8)
end

return Config
