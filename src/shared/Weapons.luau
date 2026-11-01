-- Definições das armas. Pra criar uma arma nova, adicione uma entrada aqui
-- e um visual em WeaponModels (senão ela usa o visual da pistola).
--
-- Caixa Surpresa: sai qualquer arma com BoxWeight (todas menos a pistola inicial e as premium).
-- Armas com BoxOnly só existem na caixa (não devem ser colocadas na parede).
--
-- Upgrade (Máquina de Upgrade): por padrão a arma fica vermelha, com dano e munição dobrados
-- (Config). A tabela opcional "Upgrade" troca o que quiser na versão turbinada, com os valores
-- finais (ex: Damage = 400 é o dano da turbinada) e mais:
--   Name        - nome da turbinada (padrão: nome + " TURBO")
--   Color       - cor da arma turbinada (padrão: vermelho)
--   Description - texto que aparece ao turbinar
-- Pra ler os atributos certos (normal ou turbinada), use WeaponStats.get.

export type UpgradeDef = { [string]: any }

export type WeaponDef = {
	Name: string,
	Damage: number,
	HeadshotMultiplier: number,
	FireRate: number, -- segundos entre tiros
	Automatic: boolean,
	MagSize: number,
	MaxReserve: number,
	ReloadTime: number,
	Range: number,
	Spread: number, -- dispersão em graus atirando sem mirar
	AimSpread: number, -- dispersão mirando (botão direito)
	Pellets: number, -- projéteis por tiro (escopeta > 1)
	Recoil: number, -- coice da câmera em graus
	Price: number, -- preço na parede
	FireSound: string, -- som do tiro (ID de áudio). Use arquivos curtos (~1s): os longos
	-- costumam ter barulho antes do disparo e o som sai atrasado
	FireVolume: number,
	FirePitch: number?, -- tom do tiro (padrão 1; menor = mais grave/pesado)
	Pierce: number?, -- quantos zumbis cada bala atravessa (padrão 1)
	WaveAngle: number?, -- se tiver, a arma solta uma onda em leque (meia-abertura em graus)
	-- que acerta tudo até "Range" studs na frente (e quem estiver colado em volta)
	Knockback: number?, -- força com que a onda empurra os zumbis
	AimFov: number?, -- zoom ao mirar (padrão 55; menor = mais zoom)
	Scope: boolean?, -- mirando, esconde a arma e mostra a lente da luneta
	BoxWeight: number?, -- chance relativa de sair na Caixa Surpresa (sem = nunca sai)
	BoxOnly: boolean?, -- só sai na caixa (não tem na parede)
	Pass: string?, -- arma premium: precisa desse passe (Premium.luau) pra comprar na parede dourada
	TracerColors: { Color3 }?, -- cores do rastro do tiro (sorteia uma por bala)
	KillEffect: string?, -- "Confetti": o zumbi que morre explode em confete
	FreezeTime: number?, -- cada acerto congela o zumbi por esses segundos
	ChainJumps: number?, -- o raio pula pra até N zumbis perto de quem levou o tiro
	ChainRadius: number?, -- distância máxima de cada pulo
	ChainFalloff: number?, -- dano de cada pulo = dano do anterior x isso
	Upgrade: UpgradeDef?, -- versão turbinada especial (ver o topo do arquivo)
}

local Weapons: { [string]: WeaponDef } = {
	-- ===== Parede =====

	Pistol = {
		Name = "Pistola",
		Damage = 35,
		HeadshotMultiplier = 3,
		FireRate = 0.15,
		Automatic = false,
		MagSize = 8,
		MaxReserve = 80,
		ReloadTime = 1.5,
		Range = 250,
		Spread = 1.5,
		AimSpread = 0.3,
		Pellets = 1,
		Recoil = 2.5,
		Price = 300,
		FireSound = "rbxassetid://9117399569",
		FireVolume = 0.6,
		-- a surpresa do jogo: quem turbinar a pistola fraquinha ganha a arma mais forte de todas
		Upgrade = {
			Name = "Pistola Lendária",
			Description = "Surpresa! A arma mais fraca virou a mais forte do jogo",
			Color = Color3.fromRGB(255, 200, 40), -- dourada
			Damage = 400,
			HeadshotMultiplier = 2.5,
			FireRate = 0.1,
			Automatic = true,
			MagSize = 40,
			MaxReserve = 400,
			ReloadTime = 1.2,
			Spread = 1,
			AimSpread = 0.1,
			Recoil = 1.2,
			Pierce = 6,
			FirePitch = 0.75,
		},
	},

	SMG = {
		Name = "Submetralhadora",
		Damage = 28,
		HeadshotMultiplier = 2.5,
		FireRate = 0.075,
		Automatic = true,
		MagSize = 30,
		MaxReserve = 180,
		ReloadTime = 2.2,
		Range = 180,
		Spread = 3,
		AimSpread = 1,
		Pellets = 1,
		Recoil = 1.2,
		Price = 1000,
		BoxWeight = 30,
		FireSound = "rbxassetid://9113180934",
		FireVolume = 0.45,
	},

	Revolver = {
		Name = "Revólver",
		Damage = 110,
		HeadshotMultiplier = 2.5,
		FireRate = 0.4,
		Automatic = false,
		MagSize = 6,
		MaxReserve = 48,
		ReloadTime = 2.4,
		Range = 300,
		Spread = 1,
		AimSpread = 0.2,
		Pellets = 1,
		Recoil = 6,
		Price = 1250,
		BoxWeight = 30,
		FireSound = "rbxassetid://9118163044",
		FireVolume = 0.65,
	},

	Shotgun = {
		Name = "Escopeta",
		Damage = 30,
		HeadshotMultiplier = 1.5,
		FireRate = 0.8,
		Automatic = false,
		MagSize = 6,
		MaxReserve = 42,
		ReloadTime = 3,
		Range = 60,
		Spread = 7,
		AimSpread = 5,
		Pellets = 8,
		Recoil = 6,
		Price = 1500,
		BoxWeight = 30,
		FireSound = "rbxassetid://9112913564",
		FireVolume = 0.7,
	},

	Rifle = {
		Name = "Fuzil",
		Damage = 60,
		HeadshotMultiplier = 2.5,
		FireRate = 0.11,
		Automatic = true,
		MagSize = 30,
		MaxReserve = 210,
		ReloadTime = 2.5,
		Range = 400,
		Spread = 2.5,
		AimSpread = 0.4,
		Pellets = 1,
		Recoil = 1.8,
		Price = 2000,
		BoxWeight = 25,
		FireSound = "rbxassetid://9113180776",
		FireVolume = 0.5,
	},

	Sniper = {
		Name = "Rifle de Precisão",
		Damage = 300,
		HeadshotMultiplier = 3,
		FireRate = 1.2,
		Automatic = false,
		MagSize = 5,
		MaxReserve = 40,
		ReloadTime = 3,
		Range = 600,
		Spread = 6, -- sem mirar é ruim de propósito
		AimSpread = 0,
		Pellets = 1,
		Recoil = 8,
		Price = 2500,
		BoxWeight = 20,
		FireSound = "rbxassetid://9118162552", -- revólver, mais grave
		FireVolume = 0.75,
		FirePitch = 0.8,
		Pierce = 3,
		AimFov = 25,
		Scope = true,
	},

	AutoShotgun = {
		Name = "Escopeta Automática",
		Damage = 35,
		HeadshotMultiplier = 1.5,
		FireRate = 0.25,
		Automatic = true,
		MagSize = 12,
		MaxReserve = 72,
		ReloadTime = 3.2,
		Range = 60,
		Spread = 6.5,
		AimSpread = 5,
		Pellets = 8,
		Recoil = 4,
		Price = 3000,
		BoxWeight = 20,
		FireSound = "rbxassetid://9112913483",
		FireVolume = 0.6,
	},

	LMG = {
		Name = "Metralhadora",
		Damage = 75,
		HeadshotMultiplier = 2.5,
		FireRate = 0.09,
		Automatic = true,
		MagSize = 100,
		MaxReserve = 400,
		ReloadTime = 5,
		Range = 350,
		Spread = 3.5,
		AimSpread = 1.2,
		Pellets = 1,
		Recoil = 1.5,
		Price = 3500,
		BoxWeight = 15,
		FireSound = "rbxassetid://9116341553",
		FireVolume = 0.5,
	},

	-- ===== Só na Caixa Surpresa =====

	DoubleBarrel = {
		Name = "Cano Duplo",
		Damage = 70,
		HeadshotMultiplier = 1.5,
		FireRate = 0.25,
		Automatic = false,
		MagSize = 2,
		MaxReserve = 40,
		ReloadTime = 2.5,
		Range = 50,
		Spread = 8,
		AimSpread = 6,
		Pellets = 10,
		Recoil = 9,
		Price = 0,
		FireSound = "rbxassetid://9112913305",
		FireVolume = 0.75,
		FirePitch = 0.9,
		BoxWeight = 30,
		BoxOnly = true,
	},

	BattleRifle = {
		Name = "Fuzil de Batalha",
		Damage = 150,
		HeadshotMultiplier = 2.5,
		FireRate = 0.2,
		Automatic = false,
		MagSize = 20,
		MaxReserve = 160,
		ReloadTime = 2.8,
		Range = 450,
		Spread = 1.5,
		AimSpread = 0.2,
		Pellets = 1,
		Recoil = 3.5,
		Price = 0,
		FireSound = "rbxassetid://9113181145",
		FireVolume = 0.55,
		FirePitch = 0.9,
		Pierce = 2,
		BoxWeight = 30,
		BoxOnly = true,
	},

	Crossbow = {
		Name = "Besta",
		Damage = 500,
		HeadshotMultiplier = 2,
		FireRate = 1.4,
		Automatic = false,
		MagSize = 1,
		MaxReserve = 30,
		ReloadTime = 1.6,
		Range = 400,
		Spread = 0.5,
		AimSpread = 0,
		Pellets = 1,
		Recoil = 3,
		Price = 0,
		FireSound = "rbxassetid://9114001369",
		FireVolume = 0.7,
		Pierce = 6, -- a flecha atravessa a fila inteira
		AimFov = 40,
		BoxWeight = 20,
		BoxOnly = true,
	},

	Minigun = {
		Name = "Metralhadora Giratória",
		Damage = 90,
		HeadshotMultiplier = 2,
		FireRate = 0.045,
		Automatic = true,
		MagSize = 200,
		MaxReserve = 400,
		ReloadTime = 6,
		Range = 300,
		Spread = 4,
		AimSpread = 3,
		Pellets = 1,
		Recoil = 0.8,
		Price = 0,
		FireSound = "rbxassetid://9116341721",
		FireVolume = 0.4,
		FirePitch = 1.15,
		BoxWeight = 12,
		BoxOnly = true,
	},

	-- Arma de emergência pra quando ficar encurralado: uma onda em leque que mata e empurra
	-- todos os zumbis da frente (e os colados em você)
	Microwave = {
		Name = "Micro-ondas Portátil",
		Damage = 1500,
		HeadshotMultiplier = 1,
		FireRate = 1,
		Automatic = false,
		MagSize = 5,
		MaxReserve = 30,
		ReloadTime = 2.5,
		Range = 30, -- alcance da onda
		Spread = 0,
		AimSpread = 0,
		Pellets = 1,
		Recoil = 6,
		Price = 0,
		FireSound = "rbxassetid://9114277757",
		FireVolume = 0.8,
		WaveAngle = 60, -- leque de 120° na frente
		Knockback = 70,
		BoxWeight = 8,
		BoxOnly = true,
		Upgrade = {
			Description = "Onda maior, mais aberta e que empurra mais longe",
			Range = 45,
			WaveAngle = 80,
			Knockback = 100,
		},
	},

	-- ===== Arsenal Lendário (premium: passe "Arsenal") =====
	-- Ficam na parede dourada de cada fase (custam pontos, mas só pra quem tem o passe) e no
	-- Treinamento de graça pra todo mundo experimentar. Não saem na Caixa Surpresa.

	ConfettiCannon = {
		Name = "Canhão de Confete",
		Damage = 70,
		HeadshotMultiplier = 1.5,
		FireRate = 0.3,
		Automatic = false,
		MagSize = 16,
		MaxReserve = 160,
		ReloadTime = 2,
		Range = 80,
		Spread = 6,
		AimSpread = 4,
		Pellets = 10,
		Pierce = 2,
		Recoil = 4,
		Price = 2500,
		FireSound = "rbxassetid://9112913054",
		FireVolume = 0.7,
		FirePitch = 1.25,
		Pass = "Arsenal",
		KillEffect = "Confetti",
		TracerColors = {
			Color3.fromRGB(255, 80, 160),
			Color3.fromRGB(255, 220, 60),
			Color3.fromRGB(80, 220, 255),
			Color3.fromRGB(120, 255, 120),
			Color3.fromRGB(190, 110, 255),
		},
	},

	FreezeRay = {
		Name = "Raio Congelante",
		Damage = 65,
		HeadshotMultiplier = 2,
		FireRate = 0.08,
		Automatic = true,
		MagSize = 80,
		MaxReserve = 480,
		ReloadTime = 2,
		Range = 200,
		Spread = 1,
		AimSpread = 0.3,
		Pellets = 1,
		Recoil = 0.6,
		Price = 3000,
		FireSound = "rbxassetid://9114277757",
		FireVolume = 0.35,
		FirePitch = 1.8,
		Pass = "Arsenal",
		FreezeTime = 1.5,
		TracerColors = { Color3.fromRGB(150, 240, 255) },
	},

	ChainLightning = {
		Name = "Corrente Elétrica",
		Damage = 220,
		HeadshotMultiplier = 2,
		FireRate = 0.25,
		Automatic = false,
		MagSize = 24,
		MaxReserve = 240,
		ReloadTime = 2.2,
		Range = 220,
		Spread = 0.6,
		AimSpread = 0.1,
		Pellets = 1,
		Recoil = 2.5,
		Price = 3500,
		FireSound = "rbxassetid://9114277757",
		FireVolume = 0.7,
		FirePitch = 0.75,
		Pass = "Arsenal",
		ChainJumps = 3,
		ChainRadius = 18,
		ChainFalloff = 0.8,
		TracerColors = { Color3.fromRGB(255, 240, 120) },
	},
}

return Weapons
