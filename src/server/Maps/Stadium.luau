-- Mapa "Estádio Gol de Placa": estádio de futebol abandonado, com um gramado enorme no meio.
-- Montado por código quando o servidor inicia (ver MapService). Planta em docs/mapa-estadio.md.
--
--   x: -128   -88                                     88   128
--      ┌────────────── ARQUIBANCADA NORTE ───────────────┐ z = -104
--      ├─porta─┬──── alambrado (portão pro gramado) ┬─porta─┤ z = -60
--      │VESTIÁ-│                                    │VESTIÁ-│
--      │RIO DA │            GRAMADO                 │RIO VI-│
--      │ CASA  │                                    │SITANTE│
--      ├─porta─┴─atalho──────┬CAMAROTES┬────────────┴─porta─┤ z = 60
--      │        ENTRADA (catracas e lanchonete)             │
--      └────────────────────────────────────────────────────┘ z = 104
--
-- Caminho: Entrada -> Vestiário (750) -> Arquibancada (1000) -> Gramado (1250) -> Camarotes (1500).
-- Das catracas não dá pra ir direto pro gramado: o atalho (500) só abre pelo lado do gramado.

local CollectionService = game:GetService("CollectionService")

local MapKit = require(script.Parent.MapKit)

local box = MapKit.box
local block = MapKit.block
local folder = MapKit.folder
local writeOn = MapKit.writeOn
local MAT = MapKit.MAT

local WALL = 2 -- espessura das paredes
local HEIGHT = 14 -- altura das paredes (os prédios têm teto nessa altura)
local DOOR_WIDTH, DOOR_HEIGHT = 12, 10
local BARRICADE_WIDTH, BARRICADE_HEIGHT = 6, 7

-- Linhas da planta
local XO, XI = 128, 88 -- parede de fora e parede do gramado (dos dois lados, ±)
local ZN, ZC, ZS, ZF = -104, -60, 60, 104 -- fundo, alambrado, parede sul do gramado, fachada
local STEPS_Z = -78 -- onde começam os degraus da arquibancada (antes disso é o corredor)
local BOX_X, BOX_Z = 30, 76 -- camarotes: x -30..30, z 60..76
local PITCH_X, PITCH_Z = 72, 50 -- linhas do campo (metade do comprimento e da largura)

local rng = Random.new(1950)

local COLOR = {
	Concrete = Color3.fromRGB(175, 172, 165),
	Dark = Color3.fromRGB(35, 35, 40),
	White = Color3.fromRGB(240, 240, 240),
	Black = Color3.fromRGB(15, 15, 15),
	Green = Color3.fromRGB(0, 140, 60),
	Yellow = Color3.fromRGB(255, 210, 0),
	Blue = Color3.fromRGB(30, 90, 200),
	Red = Color3.fromRGB(200, 25, 25),
	Wood = Color3.fromRGB(130, 90, 55),
	Grass = Color3.fromRGB(45, 120, 45),
	GrassLight = Color3.fromRGB(60, 140, 55),
	Tiles = Color3.fromRGB(200, 220, 230),
}

-- Entradas dos zumbis (barricadas). As paredes que passam por elas já saem com o vão aberto.
-- Os túneis dos cantos do gramado têm barricada própria (ver tunnel).
local BARRICADES = {
	{ x = -60, z = ZF, inward = -Vector3.zAxis, style = "Door" },
	{ x = 60, z = ZF, inward = -Vector3.zAxis, style = "Door" },
	{ x = -XO, z = 82, inward = Vector3.xAxis, style = "Wall" },
	{ x = -XO, z = 20, inward = Vector3.xAxis, style = "Glass", zone = "VestiarioCasa" },
	{ x = -XO, z = -20, inward = Vector3.xAxis, style = "Wall", zone = "VestiarioCasa" },
	{ x = XO, z = 20, inward = -Vector3.xAxis, style = "Glass", zone = "VestiarioVisitante" },
	{ x = XO, z = -20, inward = -Vector3.xAxis, style = "Wall", zone = "VestiarioVisitante" },
	{ x = -XO, z = -68, inward = Vector3.xAxis, style = "Door", zone = "Arquibancada" },
	{ x = XO, z = -68, inward = -Vector3.xAxis, style = "Door", zone = "Arquibancada" },
}

-- ===================== Peças =====================

-- Parede reta entre dois pontos. Abre sozinha os vãos das barricadas que caem nela e os
-- vãos de porta pedidos em "doorsAt" (posições ao longo da parede)
local function wall(parent: Instance, x1: number, z1: number, x2: number, z2: number, height: number, color: Color3?, mat: Enum.Material?, doorsAt: { number }?, props: { [string]: any }?)
	local alongX = math.abs(x2 - x1) >= math.abs(z2 - z1)
	local line = if alongX then z1 else x1
	local from = if alongX then math.min(x1, x2) else math.min(z1, z2)
	local to = if alongX then math.max(x1, x2) else math.max(z1, z2)

	local gaps = {}
	for _, barricade in BARRICADES do
		local onLine = if alongX then math.abs(barricade.inward.Z) > 0.5 and math.abs(barricade.z - line) < 0.5 else math.abs(barricade.inward.X) > 0.5 and math.abs(barricade.x - line) < 0.5
		local at = if alongX then barricade.x else barricade.z
		if onLine and at > from and at < to then
			table.insert(gaps, { at = at, half = BARRICADE_WIDTH / 2, top = BARRICADE_HEIGHT })
		end
	end
	for _, at in doorsAt or {} do
		table.insert(gaps, { at = at, half = DOOR_WIDTH / 2, top = DOOR_HEIGHT })
	end
	table.sort(gaps, function(a, b)
		return a.at < b.at
	end)

	local function piece(a: number, b: number, bottom: number, top: number)
		local length, tall = b - a, top - bottom
		if length < 0.05 or tall < 0.05 then
			return
		end
		local size = if alongX then Vector3.new(length, tall, WALL) else Vector3.new(WALL, tall, length)
		local center = if alongX then Vector3.new((a + b) / 2, bottom + tall / 2, line) else Vector3.new(line, bottom + tall / 2, (a + b) / 2)
		box(parent, "Wall", size, CFrame.new(center), color or COLOR.Concrete, mat or Enum.Material.Concrete, props)
	end
	local cursor = from
	for _, gap in gaps do
		piece(cursor, gap.at - gap.half, 0, height)
		piece(gap.at - gap.half, gap.at + gap.half, gap.top, height)
		cursor = gap.at + gap.half
	end
	piece(cursor, to, 0, height)
end

-- Porta paga (ver DoorService). openFrom = porta de um lado só
local function door(parent: Instance, x: number, z: number, zones: string, price: number, label: string, openFrom: Vector3?)
	local part = box(parent, "Door", Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, 1), CFrame.new(x, DOOR_HEIGHT / 2, z), Color3.fromRGB(120, 125, 130), Enum.Material.CorrodedMetal)
	part:SetAttribute("Price", price)
	part:SetAttribute("Zones", zones)
	part:SetAttribute("Label", label)
	if openFrom then
		part:SetAttribute("OpenFrom", openFrom)
	end
	CollectionService:AddTag(part, "Door")
end

local function floor(parent: Instance, xA: number, zA: number, xB: number, zB: number, color: Color3, mat: Enum.Material, lift: number?)
	box(parent, "Floor", Vector3.new(xB - xA, 1, zB - zA), CFrame.new((xA + xB) / 2, -0.5 + (lift or 0), (zA + zB) / 2), color, mat)
end

local function roof(parent: Instance, xA: number, zA: number, xB: number, zB: number)
	box(parent, "Roof", Vector3.new(xB - xA + 2, 1, zB - zA + 2), CFrame.new((xA + xB) / 2, HEIGHT + 0.5, (zA + zB) / 2), Color3.fromRGB(60, 60, 65))
end

-- Arma na parede: (x, z) na face da parede, "inward" pra dentro da sala
local function wallBuy(parent: Instance, weaponId: string, x: number, z: number, inward: Vector3)
	local position = Vector3.new(x, 5.5, z) + inward * 0.25
	MapKit.wallBuy(parent, weaponId, CFrame.lookAt(position, position + inward))
end

-- Lugar possível da Caixa Surpresa (um por área)
local function boxSpot(parent: Instance, x: number, z: number, facing: Vector3, area: string)
	local position = Vector3.new(x, 0.1, z)
	local part = box(parent, "BoxSpot", Vector3.new(6, 0.2, 3), CFrame.lookAt(position, position + facing), COLOR.Black, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	part:SetAttribute("Area", area)
	CollectionService:AddTag(part, "BoxSpot")
end

local function playerSpawn(parent: Instance, x: number, z: number)
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "PlayerSpawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(5, 1, 5)
	spawnLocation.CFrame = CFrame.new(x, 0.5, z)
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = parent
end

-- Luminárias no teto em grade (algumas piscam)
local function lights(parent: Instance, xA: number, zA: number, xB: number, zB: number, color: Color3)
	local countX, countZ = math.max(1, math.floor((xB - xA) / 22)), math.max(1, math.floor((zB - zA) / 22))
	for i = 1, countX do
		for j = 1, countZ do
			local x, z = xA + (i - 0.5) * (xB - xA) / countX, zA + (j - 0.5) * (zB - zA) / countZ
			local lamp = box(parent, "CeilingLight", Vector3.new(4, 0.3, 1.2), CFrame.new(x, HEIGHT - 0.15, z), color, Enum.Material.Neon, { CastShadow = false })
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 30
			light.Brightness = 1
			light.Parent = lamp
			if rng:NextNumber() < 0.25 then
				CollectionService:AddTag(lamp, "Flicker")
			end
		end
	end
end

-- Placa com texto, virada pra "facing"
local function sign(parent: Instance, position: Vector3, facing: Vector3, size: Vector2, text: string, background: Color3, textColor: Color3)
	local part = box(parent, "Sign", Vector3.new(size.X, size.Y, 0.3), CFrame.lookAt(position, position + facing), background, nil, { CanCollide = false })
	writeOn(part, Enum.NormalId.Front, text, textColor, nil, 40)
	return part
end

-- Faixa branca pintada no gramado (de um ponto a outro)
local function line(parent: Instance, x1: number, z1: number, x2: number, z2: number)
	local length = math.max(math.abs(x2 - x1), math.abs(z2 - z1))
	local size = if math.abs(x2 - x1) > math.abs(z2 - z1) then Vector3.new(length + 0.5, 0.06, 0.5) else Vector3.new(0.5, 0.06, length + 0.5)
	box(parent, "Line", size, CFrame.new((x1 + x2) / 2, 0.03, (z1 + z2) / 2), COLOR.White, nil, { CanCollide = false, CanQuery = false })
end

local ROTATE_UP = CFrame.Angles(0, 0, math.rad(90)) -- cilindro em pé

-- ===================== Áreas =====================

local function buildStructure(parent: Instance)
	floor(parent, -XO, ZS, XO, ZF, Color3.fromRGB(150, 148, 142), Enum.Material.Concrete) -- Entrada
	floor(parent, -XO, ZN, XO, ZC, Color3.fromRGB(130, 130, 125), Enum.Material.Concrete) -- Arquibancada
	floor(parent, -XO, ZC, -XI, ZS, Color3.fromRGB(215, 215, 210), MAT.Tiles) -- Vestiário da casa
	floor(parent, XI, ZC, XO, ZS, Color3.fromRGB(215, 215, 210), MAT.Tiles) -- Vestiário visitante

	-- paredes de fora
	wall(parent, -XO - 1, ZF, XO + 1, ZF, 16)
	wall(parent, -XO - 1, ZN, XO + 1, ZN, 18)
	wall(parent, -XO, ZN, -XO, ZF, HEIGHT)
	wall(parent, XO, ZN, XO, ZF, HEIGHT)

	-- vestiários: parede do gramado e as pontas com as portas
	for _, side in { -1, 1 } do
		wall(parent, side * XI, ZC, side * XI, ZS, HEIGHT)
		wall(parent, side * XO, ZC, side * XI, ZC, HEIGHT, nil, nil, { side * 108 })
		wall(parent, side * XO, ZS, side * XI, ZS, HEIGHT, nil, nil, { side * 108 })
		roof(parent, math.min(side * XO, side * XI), ZC, math.max(side * XO, side * XI), ZS)
	end

	-- alambrado entre a arquibancada e o gramado (dá pra ver o campo), com o portão no meio
	wall(parent, -XI, ZC, XI, ZC, 12, Color3.fromRGB(60, 65, 70), Enum.Material.DiamondPlate, { 0 }, { Transparency = 0.6 })
	for x = -XI, XI, 8 do
		if math.abs(x) > DOOR_WIDTH / 2 + 0.5 then
			block(parent, "FencePost", Vector3.new(0.5, 12.6, 0.5), x, ZC, COLOR.Dark, Enum.Material.Metal)
		end
	end

	-- parede sul do gramado (Entrada e camarotes) e as salas dos camarotes
	wall(parent, -XI, ZS, -BOX_X, ZS, HEIGHT, nil, nil, { -60 })
	wall(parent, BOX_X, ZS, XI, ZS, HEIGHT)
	wall(parent, -BOX_X, ZS, -BOX_X, BOX_Z, HEIGHT)
	wall(parent, BOX_X, ZS, BOX_X, BOX_Z, HEIGHT)
	wall(parent, -BOX_X, BOX_Z, BOX_X, BOX_Z, HEIGHT)
	roof(parent, -XO, ZS, XO, ZF)

	-- Portas pagas
	door(parent, -108, ZS, "VestiarioCasa", 750, "Vestiário da Casa")
	door(parent, 108, ZS, "VestiarioVisitante", 750, "Vestiário Visitante")
	door(parent, -108, ZC, "Arquibancada", 1000, "Arquibancada Norte")
	door(parent, 108, ZC, "Arquibancada", 1000, "Arquibancada Norte")
	door(parent, 0, ZC, "Gramado", 1250, "Gramado")
	door(parent, 0, ZS, "Camarotes", 1500, "Camarotes")
	-- atalho de volta pras catracas: só abre de dentro do gramado (que fica pro -Z)
	door(parent, -60, ZS, "Atalho", 500, "Atalho pras Catracas", -Vector3.zAxis)
end

-- Entrada: catracas, lanchonete e o começo da partida
local function buildEntrada(parent: Instance)
	-- catracas (dá pra passar entre elas)
	for x = -48, 48, 8 do
		block(parent, "Turnstile", Vector3.new(1, 3, 1.4), x, 92, Color3.fromRGB(150, 150, 155), Enum.Material.Metal)
		block(parent, "TurnstileTop", Vector3.new(1.2, 0.3, 1.6), x, 92, COLOR.Dark, nil, nil, 3)
		box(parent, "TurnstileArm", Vector3.new(2.6, 0.2, 0.2), CFrame.new(x + 1.8, 2.4, 92), Color3.fromRGB(200, 200, 205), Enum.Material.Metal, { CanCollide = false })
	end
	sign(parent, Vector3.new(0, 11, 92), Vector3.zAxis, Vector2.new(20, 2.4), "CATRACAS", COLOR.Dark, COLOR.Yellow)
	sign(parent, Vector3.new(0, 11, ZF - 1.2), -Vector3.zAxis, Vector2.new(50, 3), "BEM-VINDO AO ESTÁDIO GOL DE PLACA", COLOR.Green, COLOR.Yellow)

	-- lanchonete encostada na fachada
	block(parent, "SnackCounter", Vector3.new(30, 3.4, 2.4), -97, 97.5, COLOR.Red)
	block(parent, "SnackCounterTop", Vector3.new(30.4, 0.3, 2.8), -97, 97.5, COLOR.White, nil, nil, 3.4)
	sign(parent, Vector3.new(-97, 9, ZF - 1.2), -Vector3.zAxis, Vector2.new(26, 4), "LANCHONETE\nCACHORRO-QUENTE R$ 8  •  PIPOCA R$ 5  •  REFRI R$ 6", COLOR.Black, COLOR.Yellow)
	block(parent, "PopcornMachine", Vector3.new(2, 2.4, 1.6), -108, 97.5, Color3.fromRGB(220, 230, 235), Enum.Material.Glass, { Transparency = 0.4 }, 3.7)
	block(parent, "Popcorn", Vector3.new(1.6, 1, 1.2), -108, 97.5, Color3.fromRGB(255, 230, 140), nil, nil, 3.8)
	block(parent, "SodaFountain", Vector3.new(3, 2.2, 1.4), -88, 97.5, COLOR.Dark, Enum.Material.Metal, nil, 3.7)
	-- carrinho de cachorro-quente com guarda-sol
	block(parent, "HotDogCart", Vector3.new(5, 3, 2.5), -72, 84, COLOR.Yellow)
	block(parent, "UmbrellaPole", Vector3.new(0.3, 4, 0.3), -72, 84, COLOR.White, nil, nil, 3)
	box(parent, "Umbrella", Vector3.new(0.3, 7, 7), CFrame.new(-72, 7.1, 84) * ROTATE_UP, COLOR.Red, nil, { Shape = Enum.PartType.Cylinder })
	-- mesinhas
	for _, position in { Vector2.new(-110, 87), Vector2.new(-96, 85), Vector2.new(-84, 88) } do
		box(parent, "Table", Vector3.new(0.3, 3, 3), CFrame.new(position.X, 2.6, position.Y) * ROTATE_UP, COLOR.White, nil, { Shape = Enum.PartType.Cylinder })
		block(parent, "TableLeg", Vector3.new(0.3, 2.5, 0.3), position.X, position.Y, COLOR.Dark)
		for _, offset in { Vector2.new(2.3, 0), Vector2.new(-2.3, 0) } do
			block(parent, "Chair", Vector3.new(1.4, 1.6, 1.4), position.X + offset.X, position.Y + offset.Y, COLOR.Red)
		end
	end

	wallBuy(parent, "Pistol", -40, ZF - 1, -Vector3.zAxis)
	wallBuy(parent, "SMG", 40, ZF - 1, -Vector3.zAxis)

	-- quiosque do Colete, encostado na parede dos camarotes
	local armorPosition = Vector3.new(-BOX_X - 2.3, 0, 68)
	MapKit.shopStand(parent, CFrame.lookAt(armorPosition, armorPosition - Vector3.xAxis), "Armor")

	boxSpot(parent, 80, 80, -Vector3.xAxis, "Entrada")
	playerSpawn(parent, -10, 82)
	playerSpawn(parent, 10, 82)
	lights(parent, -XO, ZS, XO, ZF, Color3.fromRGB(235, 240, 255))
end

-- Vestiário (side = -1 casa, à esquerda; 1 visitante, à direita): armários, bancos, camisas,
-- chuveiros, lousa tática, maca e saco de bolas
local function buildLockerRoom(parent: Instance, side: number, color: Color3, title: string)
	local inner = side * (XI + WALL / 2) -- face da parede do gramado (do lado do vestiário)
	local into = Vector3.new(side, 0, 0) -- de lá pra dentro da sala
	local dark = color:Lerp(COLOR.Black, 0.4)

	-- armários com número e um banco comprido na frente
	for index = 0, 15 do
		local z = 10 + index * 2.9
		local position = Vector3.new(inner + side * 0.8, 3.6, z)
		local locker = box(parent, "Locker", Vector3.new(2.6, 7.2, 1.6), CFrame.lookAt(position, position + into), dark, Enum.Material.Metal)
		writeOn(locker, Enum.NormalId.Front, tostring(index + 1), COLOR.White, nil, 40)
		-- camisa pendurada em alguns armários
		if index % 4 == 1 then
			local shirt = box(parent, "Shirt", Vector3.new(1.8, 2, 0.2), CFrame.lookAt(position + into * 0.95 + Vector3.new(0, 0.8, 0), position + into * 2), color)
			writeOn(shirt, Enum.NormalId.Front, tostring(({ 10, 9, 7, 1 })[math.floor(index / 4) + 1]), COLOR.White, nil, 40)
			for _, offset in { -1.1, 1.1 } do
				box(parent, "Sleeve", Vector3.new(0.7, 0.7, 0.2), shirt.CFrame * CFrame.new(offset, 0.6, 0), color)
			end
		end
	end
	box(parent, "Bench", Vector3.new(1.6, 0.4, 44), CFrame.new(inner + side * 4.5, 1.6, 32), COLOR.Wood, Enum.Material.WoodPlanks)
	for _, z in { 12, 32, 52 } do
		block(parent, "BenchLeg", Vector3.new(1.2, 1.4, 0.4), inner + side * 4.5, z, COLOR.Dark)
	end
	sign(parent, Vector3.new(inner + side * 0.2, 10.5, 32), into, Vector2.new(26, 2.6), title, color, COLOR.White)

	-- chuveiros: piso azulejado, divisórias, duchas (duas pingando) e toalhas
	floor(parent, math.min(inner, inner + side * 14), ZC + 1, math.max(inner, inner + side * 14), -32, COLOR.Tiles, MAT.Tiles, 0.05)
	for k = 0, 4 do
		local z = -58 + k * 6
		box(parent, "ShowerWall", Vector3.new(3, 6.5, 0.3), CFrame.new(inner + side * 1.5, 3.25, z), COLOR.White, MAT.Tiles)
	end
	for k = 0, 3 do
		local z = -55 + k * 6
		block(parent, "ShowerPipe", Vector3.new(0.25, 3, 0.25), inner + side * 0.3, z, Color3.fromRGB(170, 170, 175), Enum.Material.Metal, nil, 6.5)
		box(parent, "ShowerArm", Vector3.new(1, 0.2, 0.2), CFrame.new(inner + side * 0.8, 9.3, z), Color3.fromRGB(170, 170, 175), Enum.Material.Metal)
		local head = box(parent, "ShowerHead", Vector3.new(0.25, 1.1, 1.1), CFrame.new(inner + side * 1.3, 9.1, z) * ROTATE_UP, Color3.fromRGB(200, 200, 205), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
		if k % 2 == 0 then
			local water = Instance.new("ParticleEmitter")
			water.Color = ColorSequence.new(Color3.fromRGB(180, 220, 255))
			water.Transparency = NumberSequence.new(0.4)
			water.Size = NumberSequence.new(0.12)
			water.Rate = 40
			water.Lifetime = NumberRange.new(0.8)
			water.Speed = NumberRange.new(10)
			water.SpreadAngle = Vector2.new(10, 10)
			water.EmissionDirection = Enum.NormalId.Left -- o cilindro está deitado de lado: Left aponta pro chão
			water.Parent = head
		end
		box(parent, "Drain", Vector3.new(0.05, 0.8, 0.8), CFrame.new(inner + side * 2, 0.07, z) * ROTATE_UP, COLOR.Dark, nil, { Shape = Enum.PartType.Cylinder, CanCollide = false })
		box(parent, "Towel", Vector3.new(0.2, 1.8, 1.1), CFrame.new(inner + side * 0.2, 5, z + 2.2), ({ COLOR.Red, COLOR.Yellow, COLOR.Blue, COLOR.White })[k + 1], Enum.Material.Fabric, { CanCollide = false })
	end
	sign(parent, Vector3.new(inner + side * 0.2, 11, -46), into, Vector2.new(14, 2.2), "CHUVEIROS", Color3.fromRGB(40, 110, 160), COLOR.White)

	-- lousa tática na parede do fundo (perto da porta)
	local board = sign(parent, Vector3.new(side * 96, 6, ZS - 1.2), -Vector3.zAxis, Vector2.new(6, 3.6), "X   O   X\n    →\nO   X   O", Color3.fromRGB(30, 90, 50), COLOR.White)
	board.Name = "TacticsBoard"
	-- maca de massagem
	block(parent, "MassageTable", Vector3.new(2.6, 2.4, 6), inner + side * 6, -15, COLOR.White)
	block(parent, "Pillow", Vector3.new(2, 0.4, 1), inner + side * 6, -17.6, color, nil, nil, 2.4)
	-- saco de bolas
	block(parent, "BallBag", Vector3.new(3, 3, 3), inner + side * 3, 4, COLOR.White, nil, { Transparency = 0.7, CanCollide = false })
	for k = 0, 4 do
		box(parent, "Ball", Vector3.one * 1.1, CFrame.new(inner + side * (2.4 + (k % 2)), 0.6 + math.floor(k / 2) * 0.9, 3.4 + (k % 3) * 0.6), COLOR.White, nil, { Shape = Enum.PartType.Ball })
	end
	-- bebedouro
	block(parent, "WaterCooler", Vector3.new(1.4, 3, 1.4), inner + side * 1.2, 0, COLOR.White)
	block(parent, "WaterJug", Vector3.new(1.2, 1.6, 1.2), inner + side * 1.2, 0, Color3.fromRGB(120, 180, 230), Enum.Material.Glass, { Transparency = 0.3 }, 3)

	lights(parent, math.min(side * XO, side * XI), ZC, math.max(side * XO, side * XI), ZS, Color3.fromRGB(230, 240, 255))
end

-- Arquibancada norte: corredor plano na frente e os degraus coloridos subindo até o fundo
local function buildStands(parent: Instance)
	local rows = 9
	local depth = (STEPS_Z - ZN) / rows
	local seatColors = { COLOR.Green, COLOR.Yellow, COLOR.Blue }
	for row = 0, rows - 1 do
		local front = STEPS_Z - row * depth
		local height = (row + 1) * 1.3
		box(parent, "Step", Vector3.new(2 * XO, height, depth), CFrame.new(0, height / 2, front - depth / 2), COLOR.Concrete, Enum.Material.Concrete)
		box(parent, "Seats", Vector3.new(2 * XO - 4, 0.7, 0.9), CFrame.new(0, height + 0.35, front - 0.6), seatColors[row % 3 + 1])
	end
	-- cabine de imprensa lá em cima e faixas da torcida
	local top = rows * 1.3
	box(parent, "PressBox", Vector3.new(24, 5, 5), CFrame.new(0, top + 2.5, ZN + 3), Color3.fromRGB(140, 170, 190), Enum.Material.Glass, { Transparency = 0.3 })
	sign(parent, Vector3.new(0, top + 6, ZN + 0.7), Vector3.zAxis, Vector2.new(10, 1.6), "IMPRENSA", COLOR.Dark, COLOR.White)
	for index, text in { "VAMOS, TIME!", "É CAMPEÃO!", "RUMO AO TÍTULO!", "GOL DE PLACA!" } do
		local x = ({ -80, -40, 40, 80 })[index]
		sign(parent, Vector3.new(x, top + 2.5, ZN + 1.2), Vector3.zAxis, Vector2.new(22, 2.6), text, if index % 2 == 0 then COLOR.Yellow else COLOR.Green, if index % 2 == 0 then COLOR.Green else COLOR.White)
	end

	-- armas presas no alambrado (viradas pro corredor) e o resto da área
	for _, info in { { "Rifle", -50 }, { "Sniper", 50 } } do
		local position = Vector3.new(info[2], 5.5, ZC - WALL / 2 - 0.25)
		MapKit.wallBuy(parent, info[1], CFrame.lookAt(position, position - Vector3.zAxis))
	end
	local fastPosition = Vector3.new(-24, 0, STEPS_Z + 1.3)
	MapKit.shopStand(parent, CFrame.lookAt(fastPosition, fastPosition + Vector3.zAxis), "FastHands")
	sign(parent, Vector3.new(0, 11, ZC - 1.2), -Vector3.zAxis, Vector2.new(20, 2.4), "SETOR NORTE", COLOR.Dark, COLOR.Yellow)
	boxSpot(parent, 24, -70, Vector3.zAxis, "Arquibancada")
end

-- Túnel num canto do gramado: sala fechada com a barricada virada pro campo (os zumbis do
-- gramado nascem lá dentro). side = -1 (oeste) ou 1 (leste)
local function tunnel(parent: Instance, side: number)
	local frontX = side * 76
	local zA, zB = 44, ZS
	local center = (zA + zB) / 2
	local tunnelHeight = 9
	local half = BARRICADE_WIDTH / 2
	for _, segment in { { zA, center - half, 0 }, { center + half, zB, 0 }, { center - half, center + half, BARRICADE_HEIGHT } } do
		local length, bottom = segment[2] - segment[1], segment[3]
		box(parent, "TunnelWall", Vector3.new(WALL, tunnelHeight - bottom, length), CFrame.new(frontX, bottom + (tunnelHeight - bottom) / 2, (segment[1] + segment[2]) / 2), COLOR.Dark, Enum.Material.Concrete)
	end
	local backX = side * XI
	box(parent, "TunnelWall", Vector3.new(math.abs(backX - frontX), tunnelHeight, WALL), CFrame.new((frontX + backX) / 2, tunnelHeight / 2, zA), COLOR.Dark, Enum.Material.Concrete)
	box(parent, "TunnelRoof", Vector3.new(math.abs(backX - frontX) + 2, 1, zB - zA + 2), CFrame.new((frontX + backX) / 2, tunnelHeight + 0.5, (zA + zB) / 2), COLOR.Dark)
	sign(parent, Vector3.new(frontX - side * 1.2, tunnelHeight - 1, center), Vector3.new(-side, 0, 0), Vector2.new(8, 1.2), "TÚNEL", COLOR.Black, COLOR.Red)
	local base = Vector3.new(frontX, 0, center)
	MapKit.barricade(parent, CFrame.lookAt(base, base - Vector3.new(side, 0, 0)), BARRICADE_WIDTH, BARRICADE_HEIGHT, WALL, "Door", "Gramado", COLOR.Dark)
end

-- Gramado: listras, linhas do campo, gols com rede, bandeirinhas, bancos de reservas, placar,
-- refletores e os túneis dos cantos
local function buildPitch(parent: Instance)
	local bands = 11
	local bandWidth = 2 * XI / bands
	for index = 0, bands - 1 do
		local x = -XI + (index + 0.5) * bandWidth
		box(parent, "Grass", Vector3.new(bandWidth, 1, ZS - ZC), CFrame.new(x, -0.5, 0), if index % 2 == 0 then COLOR.Grass else COLOR.GrassLight, Enum.Material.Grass)
	end

	-- linhas: borda, meio de campo, círculo central, grandes áreas e pequenas áreas
	line(parent, -PITCH_X, -PITCH_Z, PITCH_X, -PITCH_Z)
	line(parent, -PITCH_X, PITCH_Z, PITCH_X, PITCH_Z)
	line(parent, -PITCH_X, -PITCH_Z, -PITCH_X, PITCH_Z)
	line(parent, PITCH_X, -PITCH_Z, PITCH_X, PITCH_Z)
	line(parent, 0, -PITCH_Z, 0, PITCH_Z)
	box(parent, "CenterCircle", Vector3.new(0.04, 30.5, 30.5), CFrame.new(0, 0.02, 0) * ROTATE_UP, COLOR.White, nil, { Shape = Enum.PartType.Cylinder, CanCollide = false, CanQuery = false })
	box(parent, "CenterCircleInside", Vector3.new(0.05, 29.5, 29.5), CFrame.new(0, 0.03, 0) * ROTATE_UP, COLOR.Grass, Enum.Material.Grass, { Shape = Enum.PartType.Cylinder, CanCollide = false, CanQuery = false })
	for _, side in { -1, 1 } do
		local goalLine = side * PITCH_X
		for _, area in { { 26, 32 }, { 9, 14 } } do
			local inner = goalLine - side * area[1]
			line(parent, inner, -area[2], inner, area[2])
			line(parent, goalLine, -area[2], inner, -area[2])
			line(parent, goalLine, area[2], inner, area[2])
		end
		box(parent, "PenaltySpot", Vector3.new(0.06, 1, 1), CFrame.new(goalLine - side * 17, 0.04, 0) * ROTATE_UP, COLOR.White, nil, { Shape = Enum.PartType.Cylinder, CanCollide = false, CanQuery = false })

		-- gol com rede
		for _, z in { -6, 6 } do
			block(parent, "GoalPost", Vector3.new(0.4, 6, 0.4), goalLine, z, COLOR.White)
		end
		block(parent, "Crossbar", Vector3.new(0.4, 0.4, 12.4), goalLine, 0, COLOR.White, nil, nil, 6)
		local net = { Transparency = 0.55, CanQuery = false }
		block(parent, "Net", Vector3.new(0.1, 6, 12), goalLine + side * 3, 0, COLOR.White, Enum.Material.Fabric, net)
		box(parent, "Net", Vector3.new(3, 0.1, 12), CFrame.new(goalLine + side * 1.5, 6, 0), COLOR.White, Enum.Material.Fabric, net)
		for _, z in { -6, 6 } do
			block(parent, "Net", Vector3.new(3, 6, 0.1), goalLine + side * 1.5, z, COLOR.White, Enum.Material.Fabric, net)
		end

		-- bandeirinhas de escanteio
		for _, z in { -PITCH_Z, PITCH_Z } do
			block(parent, "CornerFlagPole", Vector3.new(0.2, 4, 0.2), goalLine, z, COLOR.White, nil, { CanCollide = false })
			block(parent, "CornerFlag", Vector3.new(0.1, 1, 1.4), goalLine, z + 0.7, COLOR.Red, nil, { CanCollide = false }, 3)
		end

		-- banco de reservas (do lado da parede sul) e túnel no canto
		local benchX = side * 30
		box(parent, "DugoutSeat", Vector3.new(10, 0.6, 1.6), CFrame.new(benchX, 1.6, ZS - 2.5), if side < 0 then COLOR.Green else COLOR.Blue)
		box(parent, "DugoutBack", Vector3.new(10, 2.2, 0.3), CFrame.new(benchX, 2.6, ZS - 1.5), COLOR.Dark)
		box(parent, "DugoutRoof", Vector3.new(10.6, 0.2, 4), CFrame.new(benchX, 5, ZS - 3), Color3.fromRGB(180, 210, 230), Enum.Material.Glass, { Transparency = 0.4 })
		for _, dx in { -5.2, 5.2 } do
			box(parent, "DugoutSide", Vector3.new(0.2, 4, 3.6), CFrame.new(benchX + dx, 3, ZS - 3), Color3.fromRGB(180, 210, 230), Enum.Material.Glass, { Transparency = 0.4 })
		end
		tunnel(parent, side)
	end

	-- placar eletrônico em cima da parede sul, virado pro campo
	for _, x in { -16, 16 } do
		block(parent, "ScoreboardPost", Vector3.new(1, 6, 1), x, ZS, COLOR.Dark, Enum.Material.Metal, nil, HEIGHT)
	end
	local scoreboard = box(parent, "Scoreboard", Vector3.new(40, 8, 1), CFrame.new(0, HEIGHT + 10, ZS), COLOR.Black)
	writeOn(scoreboard, Enum.NormalId.Front, "CASA  0  x  0  VISITANTE", COLOR.Yellow)

	-- refletores nas quatro pontas (luz de verdade vem dos pontos de luz no alto)
	for _, corner in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) } do
		local x, z = corner.X * XI, corner.Y * (if corner.Y < 0 then -ZC else ZS)
		block(parent, "FloodlightPole", Vector3.new(1.5, 26, 1.5), x, z, COLOR.Dark, Enum.Material.Metal, nil, HEIGHT)
		local bankPosition = Vector3.new(x, HEIGHT + 28, z)
		local bank = box(parent, "Floodlights", Vector3.new(10, 5, 1), CFrame.lookAt(bankPosition, Vector3.new(0, 0, 0)), COLOR.White, Enum.Material.Neon)
		local spot = Instance.new("SpotLight")
		spot.Angle = 70
		spot.Range = 60
		spot.Brightness = 3
		spot.Parent = bank
		if corner.X > 0 and corner.Y > 0 then
			CollectionService:AddTag(bank, "Flicker")
		end
	end
	for _, x in { -60, -20, 20, 60 } do
		for _, z in { -40, 0, 40, -70 } do
			if z ~= -70 or math.abs(x) < 50 then
				local lamp = box(parent, "PitchLight", Vector3.one, CFrame.new(x, 24, z), COLOR.White, nil, { Transparency = 1, CanCollide = false, CanQuery = false })
				local light = Instance.new("PointLight")
				light.Range = 60
				light.Brightness = 1.2
				light.Parent = lamp
			end
		end
	end

	wallBuy(parent, "AutoShotgun", -XI + 1, 20, Vector3.xAxis)
	boxSpot(parent, 40, -30, -Vector3.xAxis, "Gramado")
end

-- Camarotes: sala VIP de frente pro campo (vidro), com a Máquina de Upgrade
local function buildCamarotes(parent: Instance)
	floor(parent, -BOX_X + 1, ZS + 1, BOX_X - 1, BOX_Z - 1, Color3.fromRGB(130, 30, 35), MapKit.material("Carpet", Enum.Material.Fabric), 0.05)
	-- parede de vidro pro gramado, com a porta no meio
	for _, side in { -1, 1 } do
		local a, b = side * DOOR_WIDTH / 2, side * BOX_X
		local cx, length = (a + b) / 2, math.abs(b - a)
		box(parent, "Wall", Vector3.new(length, 3, WALL), CFrame.new(cx, 1.5, ZS), COLOR.Concrete, Enum.Material.Concrete)
		box(parent, "BoxGlass", Vector3.new(length, 7, 0.4), CFrame.new(cx, 6.5, ZS), Color3.fromRGB(150, 180, 200), Enum.Material.Glass, { Transparency = 0.5 })
		box(parent, "Wall", Vector3.new(length, HEIGHT - 10, WALL), CFrame.new(cx, 12, ZS), COLOR.Concrete, Enum.Material.Concrete)
	end
	box(parent, "Wall", Vector3.new(DOOR_WIDTH, HEIGHT - DOOR_HEIGHT, WALL), CFrame.new(0, (HEIGHT + DOOR_HEIGHT) / 2, ZS), COLOR.Concrete, Enum.Material.Concrete)

	-- sofás de frente pro vidro, mesinha, TV e frigobar
	for _, x in { -22, -12 } do
		box(parent, "SofaSeat", Vector3.new(8, 1.2, 2.6), CFrame.new(x, 1.2, 66), COLOR.Red, Enum.Material.Fabric)
		box(parent, "SofaBack", Vector3.new(8, 2.4, 0.6), CFrame.new(x, 2.4, 67.3), COLOR.Red, Enum.Material.Fabric)
		for _, dx in { -4, 4 } do
			box(parent, "SofaArm", Vector3.new(0.6, 1.8, 2.6), CFrame.new(x + dx, 1.5, 66), Color3.fromRGB(150, 20, 25), Enum.Material.Fabric)
		end
	end
	block(parent, "CoffeeTable", Vector3.new(6, 1.2, 2), -17, 62.6, Color3.fromRGB(180, 210, 225), Enum.Material.Glass, { Transparency = 0.3 })
	local tv = box(parent, "TV", Vector3.new(0.3, 3.4, 6), CFrame.new(-BOX_X + 1.2, 6, 70), COLOR.Black)
	writeOn(tv, Enum.NormalId.Right, "AO VIVO", COLOR.Red, nil, 40)
	block(parent, "MiniFridge", Vector3.new(2, 3, 2), -27, 74, COLOR.White)

	wallBuy(parent, "LMG", -12, BOX_Z - 1, -Vector3.zAxis)
	local chancePosition = Vector3.new(12, 0, BOX_Z - 2.3)
	MapKit.shopStand(parent, CFrame.lookAt(chancePosition, chancePosition - Vector3.zAxis), "SecondChance")
	-- o objetivo do fim do mapa
	local machinePosition = Vector3.new(BOX_X - 3.6, 0, 68)
	MapKit.upgradeMachine(parent, CFrame.lookAt(machinePosition, machinePosition - Vector3.xAxis))
	sign(parent, Vector3.new(0, 12, BOX_Z - 1.2), -Vector3.zAxis, Vector2.new(20, 2.4), "CAMAROTE VIP", COLOR.Yellow, COLOR.Red)

	boxSpot(parent, 0, 71, -Vector3.zAxis, "Camarotes")
	lights(parent, -BOX_X, ZS, BOX_X, BOX_Z, Color3.fromRGB(255, 230, 190))
end

local function buildVisitorExtras(parent: Instance)
	wallBuy(parent, "Revolver", XO - 1, 0, -Vector3.xAxis)
	local ammoPosition = Vector3.new(XO - 2.3, 0, 45)
	MapKit.shopStand(parent, CFrame.lookAt(ammoPosition, ammoPosition - Vector3.xAxis), "Ammo")
	boxSpot(parent, 110, -8, Vector3.xAxis, "Vestiário Visitante")
end

local function buildHomeExtras(parent: Instance)
	wallBuy(parent, "Shotgun", -XO + 1, 0, Vector3.xAxis)
	boxSpot(parent, -110, -8, -Vector3.xAxis, "Vestiário da Casa")
end

local function buildBarricades(parent: Instance)
	for _, info in BARRICADES do
		local base = Vector3.new(info.x, 0, info.z)
		MapKit.barricade(parent, CFrame.lookAt(base, base + info.inward), BARRICADE_WIDTH, BARRICADE_HEIGHT, WALL, info.style, info.zone, COLOR.Concrete)
	end
end

local function buildOutside(parent: Instance)
	box(parent, "Ground", Vector3.new(800, 1, 800), CFrame.new(0, -0.7, 0), Color3.fromRGB(28, 36, 26), Enum.Material.Grass)
end

return function(): Model
	local map = Instance.new("Model")
	map.Name = "Estadio"

	buildStructure(folder(map, "Estrutura"))
	buildEntrada(folder(map, "Entrada"))
	local home = folder(map, "VestiarioCasa")
	buildLockerRoom(home, -1, COLOR.Green, "VESTIÁRIO DA CASA")
	buildHomeExtras(home)
	local visitor = folder(map, "VestiarioVisitante")
	buildLockerRoom(visitor, 1, COLOR.Blue, "VESTIÁRIO VISITANTE")
	buildVisitorExtras(visitor)
	buildStands(folder(map, "Arquibancada"))
	buildPitch(folder(map, "Gramado"))
	buildCamarotes(folder(map, "Camarotes"))
	buildBarricades(folder(map, "Barricadas"))
	buildOutside(folder(map, "Fora"))

	return map
end
