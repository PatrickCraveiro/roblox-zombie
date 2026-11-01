-- Passes pagos (Game Pass) do jogo.
--
-- Pra vender de verdade: crie cada passe no Creator Hub (create.roblox.com → seu jogo →
-- Monetização → Passes), com imagem e preço em Robux, e cole o número (ID) do passe aqui.
-- Enquanto o ID for 0 ninguém consegue comprar fora do Studio.
--
-- StudioOwnsAll = true: no Studio todo mundo é tratado como dono dos passes, pra testar as
-- armas premium na partida. Pra testar a janela de compra no Studio (compra de mentira, não
-- gasta Robux), coloque o ID do passe e mude pra false.

local Premium = {}

export type Pass = {
	Id: number,
	Name: string,
	Description: string,
	Attribute: string, -- atributo do jogador quando ele tem o passe
}

Premium.Passes = {
	Arsenal = {
		Id = 0,
		Name = "Arsenal Lendário",
		Description = "3 armas exclusivas, mais fortes e com mais munição",
		Attribute = "PassArsenal",
	},
} :: { [string]: Pass }

Premium.StudioOwnsAll = true

return Premium
