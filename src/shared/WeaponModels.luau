-- Monta os modelos das armas com Parts simples (sem precisar de assets).
-- Origem do modelo = empunhadura (onde a mão segura). Frente da arma = -Z, cima = +Y.
-- Mais pra frente dá pra trocar por modelos de verdade do Toolbox.

local WeaponStats = require(script.Parent.WeaponStats)

local WeaponModels = {}

local BLACK = Color3.fromRGB(18, 18, 20)
local DARK = Color3.fromRGB(28, 28, 32)
local METAL = Color3.fromRGB(62, 62, 68)
local WOOD = Color3.fromRGB(100, 65, 38)

local OLIVE = Color3.fromRGB(55, 60, 45)
local WHITE = Color3.fromRGB(220, 220, 215)
local GLOW_GREEN = Color3.fromRGB(90, 255, 120)

-- cano/peças redondas: cilindro da Roblox fica deitado no eixo X, então gira 90° pra apontar em -Z
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0)

type PartSpec = {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
}

-- Canos em círculo (metralhadora giratória)
local function barrelRing(center: Vector3, radius: number, count: number, length: number, thickness: number): { PartSpec }
	local specs = {}
	for index = 1, count do
		local angle = index / count * math.pi * 2
		table.insert(specs, {
			name = "Barrel" .. index,
			size = Vector3.new(length, thickness, thickness),
			cframe = CFrame.new(center + Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)) * ALONG_Z,
			color = METAL,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		})
	end
	return specs
end

local function join(...: { PartSpec }): { PartSpec }
	local result = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #result + 1, result)
	end
	return result
end

type Style = {
	muzzle: Vector3, -- posição da ponta do cano
	sightHeight: number, -- altura do topo da arma (usado pra mirar)
	parts: { PartSpec },
}

local STYLES: { [string]: Style } = {
	Pistol = {
		muzzle = Vector3.new(0, 0.47, -0.97),
		sightHeight = 0.65,
		parts = {
			-- empunhadura inclinada pra trás, com a base do pente embaixo
			{ name = "Grip", size = Vector3.new(0.22, 0.62, 0.34), cframe = CFrame.new(0, -0.02, 0.08) * CFrame.Angles(math.rad(-12), 0, 0), color = BLACK },
			{ name = "MagBase", size = Vector3.new(0.24, 0.06, 0.36), cframe = CFrame.new(0, -0.34, 0.15) * CFrame.Angles(math.rad(-12), 0, 0), color = DARK },
			-- armação de baixo + ferrolho (a parte de cima que corre pra trás)
			{ name = "Frame", size = Vector3.new(0.2, 0.16, 0.95), cframe = CFrame.new(0, 0.27, -0.32), color = BLACK },
			{ name = "Slide", size = Vector3.new(0.24, 0.24, 1.15), cframe = CFrame.new(0, 0.47, -0.3), color = DARK, material = Enum.Material.Metal },
			{ name = "Barrel", size = Vector3.new(0.1, 0.13, 0.13), cframe = CFrame.new(0, 0.47, -0.9) * ALONG_Z, color = METAL, material = Enum.Material.Metal, shape = Enum.PartType.Cylinder },
			-- miras
			{ name = "FrontSight", size = Vector3.new(0.05, 0.06, 0.06), cframe = CFrame.new(0, 0.62, -0.82), color = BLACK },
			{ name = "RearSight", size = Vector3.new(0.18, 0.06, 0.06), cframe = CFrame.new(0, 0.62, 0.2), color = BLACK },
			-- guarda-mato e gatilho
			{ name = "GuardBottom", size = Vector3.new(0.08, 0.04, 0.34), cframe = CFrame.new(0, 0.1, -0.33), color = BLACK },
			{ name = "GuardFront", size = Vector3.new(0.08, 0.16, 0.04), cframe = CFrame.new(0, 0.17, -0.5), color = BLACK },
			{ name = "Trigger", size = Vector3.new(0.04, 0.12, 0.04), cframe = CFrame.new(0, 0.17, -0.24) * CFrame.Angles(math.rad(15), 0, 0), color = METAL },
		},
	},

	SMG = {
		muzzle = Vector3.new(0, 0.45, -1.62),
		sightHeight = 0.6,
		parts = {
			{ name = "Grip", size = Vector3.new(0.22, 0.55, 0.3), cframe = CFrame.new(0, 0, 0), color = DARK },
			{ name = "Body", size = Vector3.new(0.3, 0.4, 1.4), cframe = CFrame.new(0, 0.4, -0.3), color = METAL, material = Enum.Material.Metal },
			{ name = "Barrel", size = Vector3.new(0.14, 0.14, 0.6), cframe = CFrame.new(0, 0.45, -1.3), color = DARK },
			{ name = "Mag", size = Vector3.new(0.18, 0.7, 0.25), cframe = CFrame.new(0, -0.05, -0.65), color = DARK },
			{ name = "Stock", size = Vector3.new(0.15, 0.25, 0.7), cframe = CFrame.new(0, 0.3, 0.7), color = DARK },
		},
	},

	Shotgun = {
		muzzle = Vector3.new(0, 0.48, -2.42),
		sightHeight = 0.58,
		parts = {
			{ name = "Grip", size = Vector3.new(0.22, 0.5, 0.3), cframe = CFrame.new(0, 0, 0), color = WOOD, material = Enum.Material.Wood },
			{ name = "Body", size = Vector3.new(0.3, 0.35, 1.2), cframe = CFrame.new(0, 0.38, -0.3), color = METAL, material = Enum.Material.Metal },
			{ name = "Barrel", size = Vector3.new(0.18, 0.18, 1.6), cframe = CFrame.new(0, 0.48, -1.6), color = DARK, material = Enum.Material.Metal },
			{ name = "Pump", size = Vector3.new(0.26, 0.22, 0.6), cframe = CFrame.new(0, 0.28, -1.4), color = WOOD, material = Enum.Material.Wood },
			{ name = "Stock", size = Vector3.new(0.22, 0.4, 1.0), cframe = CFrame.new(0, 0.2, 0.9), color = WOOD, material = Enum.Material.Wood },
		},
	},

	Rifle = {
		muzzle = Vector3.new(0, 0.48, -2.22),
		sightHeight = 0.78,
		parts = {
			{ name = "Grip", size = Vector3.new(0.22, 0.55, 0.3), cframe = CFrame.new(0, 0, 0), color = DARK },
			{ name = "Body", size = Vector3.new(0.3, 0.42, 1.6), cframe = CFrame.new(0, 0.42, -0.4), color = METAL, material = Enum.Material.Metal },
			{ name = "Barrel", size = Vector3.new(0.14, 0.14, 1.0), cframe = CFrame.new(0, 0.48, -1.7), color = DARK },
			{ name = "Mag", size = Vector3.new(0.2, 0.8, 0.3), cframe = CFrame.new(0, -0.1, -0.8) * CFrame.Angles(math.rad(15), 0, 0), color = DARK },
			{ name = "Stock", size = Vector3.new(0.2, 0.45, 1.0), cframe = CFrame.new(0, 0.3, 0.9), color = DARK },
			{ name = "Sight", size = Vector3.new(0.1, 0.15, 0.3), cframe = CFrame.new(0, 0.7, -0.3), color = DARK },
		},
	},

	Revolver = {
		muzzle = Vector3.new(0, 0.5, -1.27),
		sightHeight = 0.63,
		parts = {
			{ name = "Grip", size = Vector3.new(0.22, 0.6, 0.3), cframe = CFrame.new(0, -0.02, 0.1) * CFrame.Angles(math.rad(-15), 0, 0), color = WOOD, material = Enum.Material.Wood },
			{ name = "Frame", size = Vector3.new(0.2, 0.3, 0.55), cframe = CFrame.new(0, 0.35, -0.1), color = BLACK, material = Enum.Material.Metal },
			{ name = "Cylinder", size = Vector3.new(0.42, 0.36, 0.36), cframe = CFrame.new(0, 0.4, -0.3) * ALONG_Z, color = METAL, material = Enum.Material.Metal, shape = Enum.PartType.Cylinder },
			{ name = "Barrel", size = Vector3.new(0.8, 0.12, 0.12), cframe = CFrame.new(0, 0.5, -0.85) * ALONG_Z, color = BLACK, material = Enum.Material.Metal, shape = Enum.PartType.Cylinder },
			{ name = "Underlug", size = Vector3.new(0.12, 0.1, 0.6), cframe = CFrame.new(0, 0.39, -0.85), color = BLACK },
			{ name = "Hammer", size = Vector3.new(0.06, 0.12, 0.1), cframe = CFrame.new(0, 0.55, 0.15), color = BLACK },
			{ name = "FrontSight", size = Vector3.new(0.04, 0.06, 0.06), cframe = CFrame.new(0, 0.59, -1.2), color = BLACK },
			{ name = "Guard", size = Vector3.new(0.06, 0.04, 0.25), cframe = CFrame.new(0, 0.12, -0.1), color = BLACK },
			{ name = "Trigger", size = Vector3.new(0.04, 0.1, 0.04), cframe = CFrame.new(0, 0.18, -0.05), color = METAL },
		},
	},

	Sniper = {
		muzzle = Vector3.new(0, 0.45, -3.12),
		sightHeight = 0.7, -- olho no centro da luneta
		parts = {
			{ name = "Grip", size = Vector3.new(0.22, 0.5, 0.3), cframe = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-10), 0, 0), color = OLIVE },
			{ name = "Stock", size = Vector3.new(0.22, 0.5, 1.2), cframe = CFrame.new(0, 0.25, 0.85), color = OLIVE },
			{ name = "Body", size = Vector3.new(0.26, 0.3, 1.2), cframe = CFrame.new(0, 0.42, -0.4), color = BLACK, material = Enum.Material.Metal },
			{ name = "Forend", size = Vector3.new(0.26, 0.24, 1.0), cframe = CFrame.new(0, 0.32, -1.4), color = OLIVE },
			{ name = "Barrel", size = Vector3.new(1.6, 0.12, 0.12), cframe = CFrame.new(0, 0.45, -2.3) * ALONG_Z, color = METAL, material = Enum.Material.Metal, shape = Enum.PartType.Cylinder },
			{ name = "Scope", size = Vector3.new(1.1, 0.2, 0.2), cframe = CFrame.new(0, 0.78, -0.45) * ALONG_Z, color = BLACK, material = Enum.Material.Metal, shape = Enum.PartType.Cylinder },
			{ name = "RingFront", size = Vector3.new(0.1, 0.18, 0.1), cframe = CFrame.new(0, 0.62, -0.75), color = BLACK },
			{ name = "RingBack", size = Vector3.new(0.1, 0.18, 0.1), cframe = CFrame.new(0, 0.62, -0.15), color = BLACK },
			{ name = "Bolt", size = Vector3.new(0.25, 0.06, 0.06), cframe = CFrame.new(0.17, 0.45, 0.05), color = METAL },
			{ name = "Mag", size = Vector3.new(0.18, 0.25, 0.3), cframe = CFrame.new(0, 0.18, -0.45), color = BLACK },
		},
	},

	AutoShotgun = {
		muzzle = Vector3.new(0, 0.5, -1.97),
		sightHeight = 0.7,
		parts = {
			{ name = "Grip", size = Vector3.new(0.22, 0.5, 0.3), cframe = CFrame.new(0, 0, 0), color = BLACK },
			{ name = "Body", size = Vector3.new(0.32, 0.45, 1.3), cframe = CFrame.new(0, 0.42, -0.35), color = BLACK, material = Enum.Material.Metal },
			{ name = "Drum", size = Vector3.new(0.3, 0.6, 0.6), cframe = CFrame.new(0, 0.02, -0.75), color = DARK, shape = Enum.PartType.Cylinder },
			{ name = "Barrel", size = Vector3.new(1.0, 0.18, 0.18), cframe = CFrame.new(0, 0.5, -1.45) * ALONG_Z, color = METAL, material = Enum.Material.Metal, shape = Enum.PartType.Cylinder },
			{ name = "Handguard", size = Vector3.new(0.28, 0.2, 0.6), cframe = CFrame.new(0, 0.32, -1.25), color = BLACK },
			{ name = "Stock", size = Vector3.new(0.2, 0.42, 0.9), cframe = CFrame.new(0, 0.28, 0.8), color = BLACK },
			{ name = "Rail", size = Vector3.new(0.08, 0.06, 1.0), cframe = CFrame.new(0, 0.67, -0.4), color = DARK },
		},
	},

	LMG = {
		muzzle = Vector3.new(0, 0.5, -2.82),
		sightHeight = 0.74,
		parts = {
			{ name = "Grip", size = Vector3.new(0.22, 0.55, 0.3), cframe = CFrame.new(0, 0, 0), color = DARK },
			{ name = "Body", size = Vector3.new(0.36, 0.5, 1.6), cframe = CFrame.new(0, 0.45, -0.4), color = BLACK, material = Enum.Material.Metal },
			{ name = "AmmoBox", size = Vector3.new(0.4, 0.5, 0.5), cframe = CFrame.new(-0.32, 0.2, -0.5), color = OLIVE },
			{ name = "Shroud", size = Vector3.new(1.2, 0.26, 0.26), cframe = CFrame.new(0, 0.5, -1.8) * ALONG_Z, color = DARK, material = Enum.Material.Metal, shape = Enum.PartType.Cylinder },
			{ name = "Barrel", size = Vector3.new(0.4, 0.12, 0.12), cframe = CFrame.new(0, 0.5, -2.6) * ALONG_Z, color = METAL, material = Enum.Material.Metal, shape = Enum.PartType.Cylinder },
			{ name = "BipodLeft", size = Vector3.new(0.05, 0.05, 0.7), cframe = CFrame.new(-0.1, 0.32, -1.9), color = BLACK },
			{ name = "BipodRight", size = Vector3.new(0.05, 0.05, 0.7), cframe = CFrame.new(0.1, 0.32, -1.9), color = BLACK },
			{ name = "Stock", size = Vector3.new(0.24, 0.5, 1.0), cframe = CFrame.new(0, 0.35, 0.85), color = BLACK },
			{ name = "RearSight", size = Vector3.new(0.12, 0.08, 0.08), cframe = CFrame.new(0, 0.74, 0.2), color = BLACK },
			{ name = "FrontSight", size = Vector3.new(0.04, 0.12, 0.06), cframe = CFrame.new(0, 0.68, -2.2), color = BLACK },
		},
	},

	DoubleBarrel = {
		muzzle = Vector3.new(0, 0.42, -2.27),
		sightHeight = 0.5,
		parts = {
			{ name = "Grip", size = Vector3.new(0.2, 0.42, 0.4), cframe = CFrame.new(0, 0.05, 0.1) * CFrame.Angles(math.rad(-20), 0, 0), color = WOOD, material = Enum.Material.Wood },
			{ name = "Stock", size = Vector3.new(0.24, 0.45, 1.1), cframe = CFrame.new(0, 0.15, 0.85) * CFrame.Angles(math.rad(-6), 0, 0), color = WOOD, material = Enum.Material.Wood },
			{ name = "Receiver", size = Vector3.new(0.3, 0.3, 0.5), cframe = CFrame.new(0, 0.35, -0.2), color = METAL, material = Enum.Material.Metal },
			{ name = "BarrelLeft", size = Vector3.new(1.8, 0.16, 0.16), cframe = CFrame.new(-0.08, 0.42, -1.35) * ALONG_Z, color = BLACK, material = Enum.Material.Metal, shape = Enum.PartType.Cylinder },
			{ name = "BarrelRight", size = Vector3.new(1.8, 0.16, 0.16), cframe = CFrame.new(0.08, 0.42, -1.35) * ALONG_Z, color = BLACK, material = Enum.Material.Metal, shape = Enum.PartType.Cylinder },
			{ name = "Forend", size = Vector3.new(0.28, 0.16, 0.7), cframe = CFrame.new(0, 0.28, -0.8), color = WOOD, material = Enum.Material.Wood },
		},
	},

	BattleRifle = {
		muzzle = Vector3.new(0, 0.48, -2.72),
		sightHeight = 0.72,
		parts = {
			{ name = "Grip", size = Vector3.new(0.22, 0.55, 0.3), cframe = CFrame.new(0, 0, 0), color = DARK },
			{ name = "Body", size = Vector3.new(0.3, 0.45, 1.5), cframe = CFrame.new(0, 0.42, -0.4), color = BLACK, material = Enum.Material.Metal },
			{ name = "Handguard", size = Vector3.new(0.32, 0.32, 0.9), cframe = CFrame.new(0, 0.42, -1.5), color = WOOD, material = Enum.Material.Wood },
			{ name = "Barrel", size = Vector3.new(0.8, 0.13, 0.13), cframe = CFrame.new(0, 0.48, -2.3) * ALONG_Z, color = METAL, material = Enum.Material.Metal, shape = Enum.PartType.Cylinder },
			{ name = "Mag", size = Vector3.new(0.2, 0.6, 0.3), cframe = CFrame.new(0, -0.02, -0.75), color = DARK },
			{ name = "Stock", size = Vector3.new(0.22, 0.5, 1.1), cframe = CFrame.new(0, 0.3, 0.9), color = WOOD, material = Enum.Material.Wood },
			{ name = "RearSight", size = Vector3.new(0.14, 0.1, 0.08), cframe = CFrame.new(0, 0.7, 0.15), color = BLACK },
			{ name = "FrontSight", size = Vector3.new(0.05, 0.12, 0.06), cframe = CFrame.new(0, 0.66, -2.0), color = BLACK },
		},
	},

	Crossbow = {
		muzzle = Vector3.new(0, 0.55, -1.52),
		sightHeight = 0.65,
		parts = {
			{ name = "Grip", size = Vector3.new(0.2, 0.5, 0.3), cframe = CFrame.new(0, 0, 0), color = DARK },
			{ name = "Body", size = Vector3.new(0.24, 0.3, 2.0), cframe = CFrame.new(0, 0.35, -0.3), color = WOOD, material = Enum.Material.Wood },
			-- braços do arco, inclinados pra trás
			{ name = "LimbLeft", size = Vector3.new(1.0, 0.08, 0.15), cframe = CFrame.new(-0.48, 0.4, -1.15) * CFrame.Angles(0, math.rad(15), 0), color = DARK },
			{ name = "LimbRight", size = Vector3.new(1.0, 0.08, 0.15), cframe = CFrame.new(0.48, 0.4, -1.15) * CFrame.Angles(0, math.rad(-15), 0), color = DARK },
			{ name = "String", size = Vector3.new(1.85, 0.03, 0.03), cframe = CFrame.new(0, 0.42, -0.98), color = Color3.fromRGB(200, 200, 190) },
			{ name = "Bolt", size = Vector3.new(1.2, 0.06, 0.06), cframe = CFrame.new(0, 0.55, -0.9) * ALONG_Z, color = Color3.fromRGB(150, 40, 30), shape = Enum.PartType.Cylinder },
			{ name = "BoltTip", size = Vector3.new(0.1, 0.1, 0.12), cframe = CFrame.new(0, 0.55, -1.52), color = METAL, material = Enum.Material.Metal },
			{ name = "RearSight", size = Vector3.new(0.12, 0.1, 0.06), cframe = CFrame.new(0, 0.6, 0.3), color = BLACK },
		},
	},

	Minigun = {
		muzzle = Vector3.new(0, 0.35, -2.42),
		sightHeight = 0.62,
		parts = join({
			{ name = "Grip", size = Vector3.new(0.22, 0.5, 0.3), cframe = CFrame.new(0, 0, 0), color = DARK },
			{ name = "Body", size = Vector3.new(0.5, 0.55, 1.0), cframe = CFrame.new(0, 0.35, -0.3), color = DARK, material = Enum.Material.Metal },
			{ name = "ClampBack", size = Vector3.new(0.08, 0.42, 0.42), cframe = CFrame.new(0, 0.35, -1.0) * ALONG_Z, color = BLACK, shape = Enum.PartType.Cylinder },
			{ name = "ClampFront", size = Vector3.new(0.08, 0.42, 0.42), cframe = CFrame.new(0, 0.35, -2.3) * ALONG_Z, color = BLACK, shape = Enum.PartType.Cylinder },
			{ name = "AmmoBox", size = Vector3.new(0.4, 0.4, 0.5), cframe = CFrame.new(-0.42, 0.25, -0.3), color = OLIVE },
			{ name = "TopHandle", size = Vector3.new(0.1, 0.25, 0.5), cframe = CFrame.new(0, 0.75, -0.3), color = BLACK },
		}, barrelRing(Vector3.new(0, 0.35, -1.6), 0.14, 6, 1.6, 0.08)),
	},

	Microwave = {
		muzzle = Vector3.new(0, 0.55, -1.42),
		sightHeight = 0.85,
		parts = {
			{ name = "Grip", size = Vector3.new(0.22, 0.5, 0.3), cframe = CFrame.new(0, 0, 0), color = DARK },
			{ name = "Body", size = Vector3.new(0.8, 0.6, 1.1), cframe = CFrame.new(0, 0.55, -0.5), color = WHITE },
			-- janelinha do lado esquerdo (o lado que você vê), com o brilho verde lá dentro
			{ name = "WindowFrame", size = Vector3.new(0.02, 0.4, 0.64), cframe = CFrame.new(-0.405, 0.58, -0.6), color = Color3.fromRGB(20, 20, 25) },
			{ name = "Glow", size = Vector3.new(0.01, 0.32, 0.54), cframe = CFrame.new(-0.418, 0.58, -0.6), color = GLOW_GREEN, material = Enum.Material.Neon },
			{ name = "Keypad", size = Vector3.new(0.02, 0.4, 0.22), cframe = CFrame.new(-0.41, 0.55, -0.12), color = DARK },
			{ name = "Emitter", size = Vector3.new(0.3, 0.3, 0.3), cframe = CFrame.new(0, 0.55, -1.2) * ALONG_Z, color = METAL, material = Enum.Material.Metal, shape = Enum.PartType.Cylinder },
			{ name = "EmitterTip", size = Vector3.new(0.06, 0.32, 0.32), cframe = CFrame.new(0, 0.55, -1.38) * ALONG_Z, color = GLOW_GREEN, material = Enum.Material.Neon, shape = Enum.PartType.Cylinder },
		},
	},
}

local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, anchored: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = anchored
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	return part
end

-- Arma turbinada: tudo puxado pra cor do upgrade (o que é escuro fica escuro, o claro fica vivo)
local function upgradeTint(color: Color3, tint: Color3): Color3
	local hue, saturation = tint:ToHSV()
	local _, _, value = color:ToHSV()
	return Color3.fromHSV(hue, saturation, math.clamp(0.3 + value * 0.9, 0, 1))
end

-- anchored = true pro modelo em primeira pessoa (preso na câmera),
-- false pro modelo soldado na mão do personagem.
-- upgraded = true pra arma turbinada na Máquina de Upgrade (vermelha ou a cor especial dela)
function WeaponModels.build(weaponId: string, anchored: boolean, upgraded: boolean?): Model
	local style = STYLES[weaponId] or STYLES.Pistol
	local tint = if upgraded then WeaponStats.upgradeColor(weaponId) else nil

	local model = Instance.new("Model")
	model.Name = weaponId

	local root = newPart("Handle", Vector3.new(0.2, 0.2, 0.2), CFrame.identity, DARK, anchored)
	root.Transparency = 1
	root.Parent = model
	model.PrimaryPart = root

	for _, spec in style.parts do
		local part = newPart(spec.name, spec.size, spec.cframe, if tint then upgradeTint(spec.color, tint) else spec.color, anchored)
		part.Material = spec.material or Enum.Material.SmoothPlastic
		if spec.shape then
			part.Shape = spec.shape
		end

		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = part
		weld.C0 = spec.cframe
		weld.Parent = part

		part.Parent = model
	end

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = style.muzzle
	muzzle.Parent = root

	local flash = Instance.new("PointLight")
	flash.Name = "Flash"
	flash.Color = Color3.fromRGB(255, 190, 90)
	flash.Range = 14
	flash.Brightness = 4
	flash.Shadows = false
	flash.Enabled = false
	flash.Parent = muzzle

	return model
end

function WeaponModels.getSightHeight(weaponId: string): number
	return (STYLES[weaponId] or STYLES.Pistol).sightHeight
end

return WeaponModels
