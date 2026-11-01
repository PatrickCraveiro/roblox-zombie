-- Progresso de longo prazo do jogador (o que fica salvo entre as partidas):
--
--   Cargos de aura: o jogador sobe de cargo com os PONTOS ganhos em todas as partidas somadas
--   (gastar na loja não diminui). O cargo aparece em cima do nome e dá uma aura em volta do
--   personagem (efeitos em client/AuraController; "Aura" é o nome do efeito lá).
--   Pra mudar nomes ou quantos pontos cada cargo pede, é só editar a lista.
--
--   Próxima arma do Arsenal: a mais barata que o jogador ainda não liberou com moedas.

local Weapons = require(script.Parent.Weapons)

local Progression = {}

export type Rank = {
	Name: string,
	Points: number, -- pontos totais (somando todas as partidas) pra chegar no cargo
	Color: Color3,
	Aura: string,
	Description: string, -- como é a aura (aparece na Galeria das Auras do lobby)
}

-- Um jogador médio faz uns 17 mil pontos numa partida até a rodada 10 (~85 mil por hora)
Progression.Ranks = {
	{ Name = "Iniciante", Points = 0, Color = Color3.fromRGB(150, 220, 120), Aura = "Leaves", Description = "folhinhas voando em volta" },
	{ Name = "Café com Leite", Points = 20_000, Color = Color3.fromRGB(230, 205, 165), Aura = "Dust", Description = "poeirinha nos pés" },
	{ Name = "Espanta-Zumbi", Points = 75_000, Color = Color3.fromRGB(140, 255, 90), Aura = "Bubbles", Description = "bolhas verdes subindo" },
	{ Name = "Zé Bala", Points = 200_000, Color = Color3.fromRGB(255, 150, 40), Aura = "Sparks", Description = "faíscas saindo do chão" },
	{ Name = "Mira Laser", Points = 500_000, Color = Color3.fromRGB(80, 190, 255), Aura = "Orbit", Description = "bolas de luz em órbita" },
	{ Name = "Pesadelo dos Zumbis", Points = 1_200_000, Color = Color3.fromRGB(185, 100, 255), Aura = "Shadow", Description = "fumaça roxa sombria" },
	{ Name = "Raio Ambulante", Points = 2_500_000, Color = Color3.fromRGB(255, 230, 50), Aura = "Lightning", Description = "raios amarelos em volta" },
	{ Name = "Lenda do Bairro", Points = 5_000_000, Color = Color3.fromRGB(90, 220, 255), Aura = "BlueFire", Description = "fogo azul e purpurina" },
	{ Name = "Matador", Points = 10_000_000, Color = Color3.fromRGB(255, 45, 45), Aura = "RedAura", Description = "aura vermelha fortíssima" },
} :: { Rank }

-- Índice do cargo (na lista acima) de quem tem esses pontos
function Progression.rankIndex(points: number): number
	local index = 1
	for i, rank in Progression.Ranks do
		if points >= rank.Points then
			index = i
		end
	end
	return index
end

-- 1234567 -> "1.234.567"
function Progression.format(value: number): string
	local digits = string.reverse(tostring(math.floor(math.max(value, 0))))
	local grouped = string.reverse((string.gsub(digits, "(%d%d%d)", "%1.")))
	if string.sub(grouped, 1, 1) == "." then
		grouped = string.sub(grouped, 2)
	end
	return grouped
end

-- Arma mais barata do Arsenal que ainda não foi liberada (nil se já liberou todas)
function Progression.nextWeapon(owned: { [string]: boolean }): (string?, number)
	local bestId, bestPrice = nil, math.huge
	for id, def in Weapons do
		local price = def.CoinPrice
		if not def.Pass and price and price > 0 and not owned[id] and price < bestPrice then
			bestId, bestPrice = id, price
		end
	end
	return bestId, bestPrice
end

-- "SMG,Shotgun" -> { SMG = true, Shotgun = true } (formato do atributo OwnedWeapons)
function Progression.parseOwned(text: string?): { [string]: boolean }
	local owned = {}
	for id in string.gmatch(text or "", "[^,]+") do
		owned[id] = true
	end
	return owned
end

return Progression
