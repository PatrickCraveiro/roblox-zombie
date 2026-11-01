-- Itens da loja de melhorias (quiosques espalhados pelo mapa, ver MapKit.shopStand).
-- As melhorias ficam com o jogador até ele cair; a Segunda Chance some quando é usada.
-- Os efeitos (quanto de vida, de velocidade...) ficam em Config.luau.

export type ShopItem = {
	Name: string,
	Description: string, -- aparece no quiosque
	Price: number,
	Color: Color3, -- cor do quiosque e do selo no HUD
	Attribute: string?, -- atributo do jogador enquanto tem a melhoria (nil = compra na hora, ex: munição)
	Short: string?, -- nome curtinho pro selo no HUD
}

local Shop: { [string]: ShopItem } = {
	Armor = {
		Name = "Colete Blindado",
		Description = "Aguenta o dobro de golpes",
		Price = 2500,
		Color = Color3.fromRGB(60, 110, 200),
		Attribute = "PerkArmor",
		Short = "COLETE",
	},
	FastHands = {
		Name = "Mão Rápida",
		Description = "Recarrega 2x mais rápido e atira mais rápido",
		Price = 3000,
		Color = Color3.fromRGB(240, 170, 20),
		Attribute = "PerkFastHands",
		Short = "MÃO RÁPIDA",
	},
	SecondChance = {
		Name = "Segunda Chance",
		Description = "Se cair, levanta de novo (1 vez)",
		Price = 4000,
		Color = Color3.fromRGB(220, 40, 50),
		Attribute = "PerkSecondChance",
		Short = "2ª CHANCE",
	},
	Ammo = {
		Name = "Munição",
		Description = "Enche a munição da arma na mão (qualquer arma, até da caixa)",
		Price = 2000,
		Color = Color3.fromRGB(80, 120, 60),
	},
}

return Shop
