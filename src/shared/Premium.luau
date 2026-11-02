-- Passes pagos (Game Pass) do jogo: um por arma VIP, o pacote "Arsenal Lendário" com todas as
-- armas (mais barato que comprar separado) e o "Moedas em Dobro".
--
-- Pra vender de verdade: crie cada passe no Creator Hub (create.roblox.com → seu jogo →
-- Monetização → Passes), com imagem e o preço em Robux de "Robux" abaixo, e cole o número (ID)
-- do passe em "Id". Enquanto o ID for 0 ninguém consegue comprar fora do Studio.
--
-- StudioOwnsAll = true: no Studio todo mundo é tratado como dono dos passes, pra testar as
-- armas VIP na partida. Pra testar a janela de compra no Studio (compra de mentira, não gasta
-- Robux), coloque os IDs e mude pra false.

local Premium = {}

export type Pass = {
	Id: number,
	Name: string,
	Description: string,
	Robux: number, -- preço (só pra mostrar no jogo; o preço de verdade é o do Creator Hub)
	Attribute: string, -- atributo do jogador quando ele tem o passe
	Includes: { string }?, -- pacote: libera também esses outros passes
}

Premium.Passes = {
	Arsenal = {
		Id = 2063912053,
		Name = "Arsenal Lendário",
		Description = "As 5 armas VIP de uma vez, bem mais barato que separado",
		Robux = 999,
		Attribute = "PassArsenal",
		Includes = { "Confetti", "Freeze", "Chain", "Dragon", "Hurricane" },
	},
	Confetti = {
		Id = 2064311042,
		Name = "Canhão de Confete",
		Description = "Escopeta VIP: o zumbi explode em confete",
		Robux = 199,
		Attribute = "PassConfetti",
	},
	Freeze = {
		Id = 2063878115,
		Name = "Raio Congelante",
		Description = "Automática VIP que congela os zumbis",
		Robux = 249,
		Attribute = "PassFreeze",
	},
	Chain = {
		Id = 2063960184,
		Name = "Corrente Elétrica",
		Description = "O raio pula de zumbi em zumbi",
		Robux = 299,
		Attribute = "PassChain",
	},
	Dragon = {
		Id = 2063992003,
		Name = "Metralhadora Dragão",
		Description = "2000 balas no pente e tiros de fogo",
		Robux = 399,
		Attribute = "PassDragon",
	},
	Hurricane = {
		Id = 2064388490,
		Name = "Canhão Furacão",
		Description = "Vendaval que mata tudo na frente e arremessa os zumbis",
		Robux = 499,
		Attribute = "PassHurricane",
	},
	-- não é arma: dobra as moedas de toda partida (fica fora do pacote de armas)
	DoubleCoins = {
		Id = 2064504391,
		Name = "Moedas em Dobro",
		Description = "Ganhe o dobro de moedas em toda partida, pra sempre",
		Robux = 149,
		Attribute = "PassDoubleCoins",
	},
} :: { [string]: Pass }

Premium.StudioOwnsAll = true

return Premium
