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

-- Parede de vidro ao longo de X (mureta verde, vidrão e concreto em cima), com vãos de porta.
-- Dá pra ver através, mas não passar (nem atirar)
local function glassWall(parent: Instance, xA: number, xB: number, z: number, doorsAt: { number }?)
	local function segment(a: number, b: number)
		if b - a < 0.05 then
			return
		end
		local cx, length = (a + b) / 2, b - a
		box(parent, "GlassBase", Vector3.new(length, 2.5, WALL), CFrame.new(cx, 1.25, z), COLOR.Green, Enum.Material.Concrete)
		box(parent, "BigGlass", Vector3.new(length, 8.5, 0.4), CFrame.new(cx, 6.75, z), Color3.fromRGB(160, 190, 210), Enum.Material.Glass, { Transparency = 0.55 })
		box(parent, "Wall", Vector3.new(length, HEIGHT - 11, WALL), CFrame.new(cx, 12.5, z), COLOR.Concrete, Enum.Material.Concrete)
	end
	local doors = table.clone(doorsAt or {})
	table.sort(doors)
	local cursor = xA
	for _, at in doors do
		segment(cursor, at - DOOR_WIDTH / 2)
		box(parent, "Wall", Vector3.new(DOOR_WIDTH, HEIGHT - DOOR_HEIGHT, WALL), CFrame.new(at, (HEIGHT + DOOR_HEIGHT) / 2, z), COLOR.Concrete, Enum.Material.Concrete)
		cursor = at + DOOR_WIDTH / 2
	end
	segment(cursor, xB)
	-- montantes do vidro
	for x = xA + 8, xB - 4, 8 do
		local nearDoor = false
		for _, at in doors do
			nearDoor = nearDoor or math.abs(x - at) < DOOR_WIDTH / 2 + 0.5
		end
		if not nearDoor then
			box(parent, "Mullion", Vector3.new(0.4, 8.5, 0.6), CFrame.new(x, 6.75, z), COLOR.Dark, Enum.Material.Metal)
		end
	end
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

-- Luminárias no teto em grade (algumas piscam). As luzes da Roblox atravessam paredes e somam:
-- por isso são fracas, e "skip(x, z)" pula as que cairiam em cima de outra sala
local function lights(parent: Instance, xA: number, zA: number, xB: number, zB: number, color: Color3, brightness: number?, skip: ((number, number) -> boolean)?)
	local countX, countZ = math.max(1, math.floor((xB - xA) / 22)), math.max(1, math.floor((zB - zA) / 22))
	for i = 1, countX do
		for j = 1, countZ do
			local x, z = xA + (i - 0.5) * (xB - xA) / countX, zA + (j - 0.5) * (zB - zA) / countZ
			if skip and skip(x, z) then
				continue
			end
			local lamp = box(parent, "CeilingLight", Vector3.new(4, 0.3, 1.2), CFrame.new(x, HEIGHT - 0.15, z), color, Enum.Material.Neon, { CastShadow = false })
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 30
			light.Brightness = brightness or 0.7
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
	floor(parent, -XO, ZS, XO, ZF, Color3.fromRGB(215, 208, 190), MAT.Tiles) -- Entrada
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

	-- parede sul do gramado: vidro (do saguão das catracas já dá pra ver o campo) e os camarotes
	glassWall(parent, -XI, -BOX_X, ZS, { -60 })
	glassWall(parent, BOX_X, XI, ZS)
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
	local decor = { CanCollide = false, CanQuery = false }

	-- catracas de verdade: gabinete de inox, tampo de vidro, leitor de ingresso com luz (verde =
	-- liberada, vermelha = fechada) e o braço; pórtico verde em cima com a luz de cada passagem
	box(parent, "Walkway", Vector3.new(122, 0.06, 8), CFrame.new(0, 0.03, 92), COLOR.Green, nil, decor)
	for k = 0, 11 do
		local x = -55 + k * 10
		local open = k % 4 ~= 3
		local signal = if open then Color3.fromRGB(60, 255, 90) else COLOR.Red
		block(parent, "Turnstile", Vector3.new(1.4, 3.2, 3), x, 92, Color3.fromRGB(205, 205, 210), Enum.Material.Metal)
		block(parent, "TurnstileTop", Vector3.new(1.5, 0.15, 3.1), x, 92, Color3.fromRGB(20, 40, 70), Enum.Material.Glass, nil, 3.2)
		block(parent, "TicketReader", Vector3.new(0.6, 0.35, 0.8), x, 93, COLOR.Black, nil, nil, 3.35)
		block(parent, "ReaderLight", Vector3.new(0.3, 0.1, 0.3), x, 93, signal, Enum.Material.Neon, decor, 3.7)
		box(parent, "TurnstileHub", Vector3.new(0.5, 0.7, 0.7), CFrame.new(x + 0.95, 2.5, 92), Color3.fromRGB(170, 170, 175), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
		box(parent, "TurnstileArm", Vector3.new(2.6, 0.18, 0.18), CFrame.new(x + 2.4, 2.5, 92), Color3.fromRGB(220, 220, 225), Enum.Material.Metal, { CanCollide = false })
		if k < 11 then
			block(parent, "LaneLight", Vector3.new(1.2, 1.2, 0.3), x + 5, 92, signal, Enum.Material.Neon, decor, 8.3)
		end
	end
	for _, x in { -62, 62 } do
		block(parent, "GantryPost", Vector3.new(1.4, 9.5, 1.4), x, 92, COLOR.Green, Enum.Material.Metal)
	end
	block(parent, "GantryBeam", Vector3.new(126, 1.4, 1.4), 0, 92, COLOR.Green, Enum.Material.Metal, nil, 9.5)
	local gantrySign = box(parent, "GantrySign", Vector3.new(44, 2.6, 0.4), CFrame.new(0, 12.2, 92), COLOR.Yellow, nil, decor)
	writeOn(gantrySign, Enum.NormalId.Front, "ACESSO AO ESTÁDIO", COLOR.Green, nil, 40)
	writeOn(gantrySign, Enum.NormalId.Back, "ACESSO AO ESTÁDIO", COLOR.Green, nil, 40)
	sign(parent, Vector3.new(0, 11, ZF - 1.2), -Vector3.zAxis, Vector2.new(50, 3), "BEM-VINDO AO ESTÁDIO GOL DE PLACA", COLOR.Green, COLOR.Yellow)

	-- escudo pintado no chão do saguão
	box(parent, "EmblemRing", Vector3.new(0.05, 14, 14), CFrame.new(0, 0.03, 82) * ROTATE_UP, COLOR.Yellow, nil, { CanCollide = false, CanQuery = false, Shape = Enum.PartType.Cylinder })
	box(parent, "Emblem", Vector3.new(0.06, 12, 12), CFrame.new(0, 0.04, 82) * ROTATE_UP, COLOR.Green, nil, { CanCollide = false, CanQuery = false, Shape = Enum.PartType.Cylinder })
	local emblemText = box(parent, "EmblemText", Vector3.new(10, 0.05, 4), CFrame.lookAt(Vector3.new(0, 0.09, 82), Vector3.new(0, 0.09, 70)), COLOR.White, nil, { Transparency = 1, CanCollide = false, CanQuery = false })
	writeOn(emblemText, Enum.NormalId.Top, "GOL DE PLACA", COLOR.Yellow)

	-- parede da fachada pintada (faixa verde e amarela), sem tampar os portões das barricadas
	for _, range in { { -127, -63 }, { -57, 57 }, { 63, 127 } } do
		local cx, length = (range[1] + range[2]) / 2, range[2] - range[1]
		box(parent, "WallPaint", Vector3.new(length, 3, 0.2), CFrame.new(cx, 1.5, ZF - 1.1), COLOR.Green, nil, decor)
		box(parent, "WallStripe", Vector3.new(length, 0.5, 0.2), CFrame.new(cx, 3.25, ZF - 1.1), COLOR.Yellow, nil, decor)
	end

	-- bilheteria: três guichês na fachada
	for index, x in { 78, 90, 102 } do
		box(parent, "TicketWindow", Vector3.new(6, 3.5, 0.2), CFrame.new(x, 6, ZF - 1.1), Color3.fromRGB(150, 185, 205), Enum.Material.Glass, { Transparency = 0.3, CanCollide = false })
		box(parent, "TicketLedge", Vector3.new(7, 0.3, 1.2), CFrame.new(x, 3.65, ZF - 1.6), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
		sign(parent, Vector3.new(x, 8.6, ZF - 1.2), -Vector3.zAxis, Vector2.new(5, 1), `GUICHÊ {index}`, COLOR.Dark, COLOR.White)
	end
	sign(parent, Vector3.new(90, 11, ZF - 1.2), -Vector3.zAxis, Vector2.new(30, 2.4), "BILHETERIA", COLOR.Yellow, COLOR.Green)

	-- loja do torcedor: balcão com cachecóis e uma arara de camisas
	block(parent, "ShopCounter", Vector3.new(10, 3.2, 2.4), 88, 76.5, COLOR.Green)
	for index = 0, 2 do
		box(parent, "Scarf", Vector3.new(2.6, 0.2, 0.6), CFrame.new(84.5 + index * 3.5, 3.3, 76.5) * CFrame.Angles(0, 0.3, 0), if index % 2 == 0 then COLOR.Yellow else COLOR.Green, Enum.Material.Fabric, decor)
	end
	for _, x in { 83.5, 92.5 } do
		block(parent, "RackPost", Vector3.new(0.2, 7, 0.2), x, 72.5, COLOR.Dark, Enum.Material.Metal)
	end
	block(parent, "ClothesRail", Vector3.new(9.2, 0.2, 0.2), 88, 72.5, COLOR.Dark, Enum.Material.Metal, nil, 7)
	for index = 0, 3 do
		local shirtColor = if index % 2 == 0 then COLOR.Green else COLOR.Yellow
		local shirt = box(parent, "Jersey", Vector3.new(1.8, 2.2, 0.2), CFrame.new(84.5 + index * 2.4, 5.6, 72.5), shirtColor, Enum.Material.Fabric, decor)
		writeOn(shirt, Enum.NormalId.Back, tostring(({ 10, 9, 7, 11 })[index + 1]), if index % 2 == 0 then COLOR.Yellow else COLOR.Green, nil, 40)
	end
	sign(parent, Vector3.new(88, 9.5, 72.3), Vector3.zAxis, Vector2.new(12, 1.8), "LOJA DO TORCEDOR", COLOR.Yellow, COLOR.Green)

	-- taça numa vitrine
	block(parent, "TrophyStand", Vector3.new(3, 3, 3), 45, 80, Color3.fromRGB(70, 45, 30), Enum.Material.Wood)
	block(parent, "TrophyGlass", Vector3.new(3, 4, 3), 45, 80, Color3.fromRGB(200, 225, 240), Enum.Material.Glass, { Transparency = 0.7 }, 3)
	local gold = Color3.fromRGB(240, 190, 50)
	for _, piece in { { 0.4, 1.2, 3.2 }, { 1, 0.4, 3.6 }, { 1.4, 1.4, 4.6 } } do
		box(parent, "Trophy", Vector3.new(piece[1], piece[2], piece[2]), CFrame.new(45, piece[3] + piece[1] / 2, 80) * ROTATE_UP, gold, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, Reflectance = 0.3 })
	end
	sign(parent, Vector3.new(45, 1.5, 81.65), Vector3.zAxis, Vector2.new(2.6, 0.8), "CAMPEÃO 1950", gold, COLOR.Black)

	-- bandeirinhas atravessando o saguão
	box(parent, "BuntingRope", Vector3.new(240, 0.08, 0.08), CFrame.new(0, 12.8, 86), COLOR.White, nil, decor)
	for index = 0, 29 do
		box(parent, "Bunting", Vector3.new(1.4, 1.4, 0.05), CFrame.new(-116 + index * 8, 12.1, 86) * CFrame.Angles(0, 0, math.rad(45)), if index % 2 == 0 then COLOR.Green else COLOR.Yellow, nil, decor)
	end

	-- mirante: bancos de frente pro vidro pra ver o campo
	for _, x in { -80, -45, 45, 70 } do
		box(parent, "ViewBench", Vector3.new(6, 0.4, 1.6), CFrame.new(x, 1.6, 64), COLOR.Wood, Enum.Material.WoodPlanks)
		for _, dx in { -2.5, 2.5 } do
			block(parent, "ViewBenchLeg", Vector3.new(0.4, 1.4, 1.4), x + dx, 64, COLOR.Dark)
		end
	end

	-- cartazes dos ídolos na parede de fora dos camarotes
	for index, text in { "CRAQUE DA\nGALERA", "NOSSO ÍDOLO\nCAMISA 10" } do
		local x = if index == 1 then -18 else 18
		sign(parent, Vector3.new(x, 6, BOX_Z + 1.2), Vector3.zAxis, Vector2.new(8, 5), text, if index == 1 then COLOR.Green else COLOR.Yellow, if index == 1 then COLOR.Yellow else COLOR.Green)
	end
	sign(parent, Vector3.new(0, 11, BOX_Z + 1.2), Vector3.zAxis, Vector2.new(22, 2.4), "CAMAROTES VIP", COLOR.Dark, COLOR.Yellow)

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

	-- parede dourada: Arsenal Lendário (premium; quem não tem o passe vê a loja dele)
	for index, id in { "ConfettiCannon", "FreezeRay", "ChainLightning" } do
		wallBuy(parent, id, -24 + index * 12, ZF - 1, -Vector3.zAxis)
	end
	sign(parent, Vector3.new(0, 8.4, ZF - 1.2), -Vector3.zAxis, Vector2.new(32, 1.2), "★ ARSENAL LENDÁRIO ★", Color3.fromRGB(40, 30, 10), Color3.fromRGB(255, 205, 50))

	-- quiosque do Colete, encostado na parede dos camarotes
	local armorPosition = Vector3.new(-BOX_X - 2.3, 0, 68)
	MapKit.shopStand(parent, CFrame.lookAt(armorPosition, armorPosition - Vector3.xAxis), "Armor")

	boxSpot(parent, 80, 80, -Vector3.xAxis, "Entrada")
	playerSpawn(parent, -10, 82)
	playerSpawn(parent, 10, 82)
	-- (sem lâmpadas em cima dos camarotes: eles têm as deles)
	lights(parent, -XO, ZS, XO, ZF, Color3.fromRGB(235, 235, 245), 0.7, function(x, z)
		return math.abs(x) < BOX_X + 4 and z < BOX_Z + 4
	end)
end

-- Banheiro do vestiário, encostado na parede de fora: dois cômodos de paredes altas (chuveiros e
-- sanitários), cada um com uma porta pro corredor do vestiário
local function buildBathroom(parent: Instance, side: number, color: Color3)
	local outer = side * (XO - WALL / 2) -- face de dentro da parede de fora
	local divider = side * 112 -- parede que separa o banheiro do corredor
	local zA, zMid, zB = -52, -38, -24
	local tile = Color3.fromRGB(205, 212, 218) -- azulejo claro, mas não branco puro (estoura com a luz)
	local metal = Color3.fromRGB(180, 180, 185)
	local decor = { CanCollide = false, CanQuery = false }
	local function x(d: number): number -- "d" studs da parede de fora pra dentro
		return outer - side * d
	end
	local function slab(name: string, xA: number, xB: number, z1: number, z2: number, bottom: number, top: number, c: Color3, mat: Enum.Material?)
		box(parent, name, Vector3.new(math.abs(xB - xA), top - bottom, math.abs(z2 - z1)), CFrame.new((xA + xB) / 2, (bottom + top) / 2, (z1 + z2) / 2), c, mat or MAT.Tiles)
	end

	floor(parent, math.min(outer, divider), zA, math.max(outer, divider), zB, Color3.fromRGB(170, 205, 225), MAT.Tiles, 0.05)
	-- paredes: norte, meio e sul (de azulejo) e a divisória pro corredor com as duas portas
	for _, z in { zA, zMid, zB } do
		slab("BathWall", side * XO, divider, z - 0.5, z + 0.5, 0, HEIGHT, tile)
	end
	for _, segment in { { zA, -47.5, 0 }, { -42.5, -33.5, 0 }, { -28.5, zB, 0 }, { -47.5, -42.5, 8 }, { -33.5, -28.5, 8 } } do
		slab("BathWall", divider - 0.5, divider + 0.5, segment[1], segment[2], segment[3], HEIGHT, tile)
	end
	-- faixa da cor do time e placas em cima das portas (do lado do corredor)
	slab("BathStripe", divider - side * 0.6, divider - side * 0.5, zA, zB, 8.5, 9.2, color, Enum.Material.SmoothPlastic)
	for _, info in { { -45, "CHUVEIROS" }, { -31, "SANITÁRIOS" } } do
		sign(parent, Vector3.new(divider - side * 0.7, 10.3, info[1]), Vector3.new(-side, 0, 0), Vector2.new(6, 1.4), info[2], Color3.fromRGB(40, 110, 160), COLOR.White)
	end

	-- CHUVEIROS: três boxes encostados na parede norte, duas duchas pingando, ralos e toalhas
	for d = 5, 10, 5 do
		slab("ShowerStall", x(d) - 0.15, x(d) + 0.15, zA + 0.5, zA + 5.5, 0, 7, tile)
	end
	for index, d in { 2.5, 7.5, 12.5 } do
		local headZ = zA + 1.4
		block(parent, "ShowerPipe", Vector3.new(0.25, 3, 0.25), x(d), zA + 0.7, metal, Enum.Material.Metal, nil, 6.5)
		box(parent, "ShowerArm", Vector3.new(0.2, 0.2, 1), CFrame.new(x(d), 9.3, zA + 1), metal, Enum.Material.Metal)
		local head = box(parent, "ShowerHead", Vector3.new(0.25, 1.1, 1.1), CFrame.new(x(d), 9.1, headZ) * ROTATE_UP, Color3.fromRGB(205, 205, 210), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
		if index ~= 2 then
			local water = Instance.new("ParticleEmitter")
			water.Color = ColorSequence.new(Color3.fromRGB(180, 220, 255))
			water.Transparency = NumberSequence.new(0.4)
			water.Size = NumberSequence.new(0.12)
			water.Rate = 40
			water.Lifetime = NumberRange.new(0.8)
			water.Speed = NumberRange.new(10)
			water.SpreadAngle = Vector2.new(10, 10)
			water.EmissionDirection = Enum.NormalId.Left -- o cilindro está deitado: Left aponta pro chão
			water.Parent = head
		end
		block(parent, "ShowerTap", Vector3.new(0.6, 0.6, 0.3), x(d), zA + 0.65, metal, Enum.Material.Metal, decor, 4.2)
		box(parent, "Drain", Vector3.new(0.05, 0.8, 0.8), CFrame.new(x(d), 0.09, zA + 3) * ROTATE_UP, COLOR.Dark, nil, { Shape = Enum.PartType.Cylinder, CanCollide = false })
		box(parent, "Towel", Vector3.new(1.2, 1.8, 0.2), CFrame.new(x(d), 5, zMid - 0.65), ({ COLOR.Red, COLOR.Yellow, color })[index], Enum.Material.Fabric, decor)
	end
	slab("ShowerBench", x(4.5), x(10.5), zMid - 3.2, zMid - 1.8, 1.4, 1.8, COLOR.Wood, Enum.Material.WoodPlanks)

	-- SANITÁRIOS: três cabines encostadas na parede de fora (com vaso e porta, uma entreaberta)
	-- e as pias com espelho na parede do meio
	for _, z in { -33.3, -28.6 } do
		slab("ToiletStall", x(0), x(5), z - 0.15, z + 0.15, 0, 7, color:Lerp(COLOR.White, 0.5), Enum.Material.SmoothPlastic)
	end
	for index, z in { -35.65, -30.95, -26.3 } do
		slab("ToiletTank", x(0), x(0.8), z - 0.9, z + 0.9, 2, 3.8, COLOR.White, Enum.Material.SmoothPlastic)
		box(parent, "Toilet", Vector3.new(1.4, 1.6, 1.6), CFrame.new(x(1.8), 0.7, z) * ROTATE_UP, COLOR.White, nil, { Shape = Enum.PartType.Cylinder })
		local hinge = CFrame.new(x(5), 3.5, z + 2) * CFrame.Angles(0, if index == 2 then side * math.rad(-40) else 0, 0)
		box(parent, "StallDoor", Vector3.new(0.2, 6, 4), hinge * CFrame.new(0, 0, -2), color:Lerp(COLOR.White, 0.3), Enum.Material.SmoothPlastic, decor)
	end
	slab("SinkCounter", x(8), x(14), zMid + 0.5, zMid + 2.1, 2.8, 3.2, Color3.fromRGB(60, 60, 65), Enum.Material.Marble)
	for _, d in { 9.5, 12.5 } do
		box(parent, "Sink", Vector3.new(0.3, 1.2, 1.2), CFrame.new(x(d), 3.25, zMid + 1.3) * ROTATE_UP, COLOR.White, nil, { Shape = Enum.PartType.Cylinder })
		block(parent, "Faucet", Vector3.new(0.2, 0.6, 0.2), x(d), zMid + 0.75, metal, Enum.Material.Metal, decor, 3.2)
	end
	box(parent, "Mirror", Vector3.new(math.abs(x(14) - x(8)) - 0.4, 3, 0.1), CFrame.new(x(11), 6.3, zMid + 0.56), Color3.fromRGB(190, 200, 205), Enum.Material.Glass, { Reflectance = 0.6, CanCollide = false })
	block(parent, "TowelDispenser", Vector3.new(1, 1.4, 0.5), x(14.3), zMid + 0.75, COLOR.White, nil, decor, 4.5)

	-- uma luz em cada cômodo
	for _, z in { (zA + zMid) / 2, (zMid + zB) / 2 } do
		local lamp = box(parent, "CeilingLight", Vector3.new(3, 0.3, 1.2), CFrame.new(x(7.5), HEIGHT - 0.15, z), Color3.fromRGB(240, 245, 255), Enum.Material.Neon, { CastShadow = false })
		local light = Instance.new("PointLight")
		light.Range = 16
		light.Brightness = 0.6
		light.Parent = lamp
	end
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

	buildBathroom(parent, side, color)

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

	lights(parent, math.min(side * XO, side * XI), ZC, math.max(side * XO, side * XI), ZS, Color3.fromRGB(230, 240, 255), 0.6)
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
	lights(parent, -BOX_X, ZS, BOX_X, BOX_Z, Color3.fromRGB(255, 225, 180), 0.5)
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
