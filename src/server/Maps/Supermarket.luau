-- Mapa "Supermercado Fim de Feira": loop em volta de um miolo fechado, com portas pagas,
-- armas melhores (e mais caras) no fundo e a Caixa Surpresa num lugar sorteado.
-- Montado por código quando o servidor inicia (ver MapService).
--
-- Pra editar o mapa no Studio: na barra de comando (fora do modo de teste), rode
--   require(game.ServerScriptService.Server.Maps.Supermarket)().Parent = workspace
-- e salve o place. Se existir um "Supermercado" no Workspace, o jogo usa ele em vez de gerar.
--
-- Planta (vista de cima; a frente da loja fica embaixo, no +Z):
--
--   x: -96         -32          32          96
--      ┌───────────┬───────────┬───────────┐ z = -84
--      │ AÇOUGUE E │  CÂMARA   │  ESTOQUE  │
--      │  PADARIA  │   FRIA    │           │
--      ├───────────┼───────────┼───────────┤ z = -28
--      │HORTIFRUTI │ (fechado) │   DOCA    │
--      ├───────────┴───────────┼───────────┤ z = 28
--      │   ENTRADA E CAIXAS    │ESTACIONAM.│
--      └───────────────────────┴───────────┘ z = 84
--
-- Portas (o loop fecha no fundo, entre a Câmara Fria e o Estoque):
--   Entrada -> Hortifruti 750 -> Açougue 1000 -> Câmara Fria 1250 -> Estoque (1000)
--   Entrada -> Estacionamento 750 -> Doca 1000 -> Estoque 1500
-- No Estoque (o fim dos dois caminhos) fica a Máquina de Upgrade.

local CollectionService = game:GetService("CollectionService")

local MapKit = require(script.Parent.MapKit)

local STORE_NAME = "SUPERMERCADO FIM DE FEIRA"

local WALL_HEIGHT = 20
local WALL_THICKNESS = 2
local DOOR_WIDTH = 12
local DOOR_HEIGHT = 10
local FENCE_HEIGHT = 12

-- Linhas da grade da planta
local X0, X1, X2, X3 = -96, -32, 32, 96
local Z0, Z1, Z2, Z3 = -84, -28, 28, 84

-- Entradas dos zumbis (barricadas com tábuas). (x, z) fica na linha do meio da parede e
-- "inward" aponta pra dentro da loja. As paredes que passam por elas já saem com o vão aberto.
-- Os zumbis nascem do lado de fora; "zone" = área que precisa estar aberta (nil = sempre).
local BARRICADE_WIDTH, BARRICADE_HEIGHT = 6, 7
local FENCE_COLOR = Color3.fromRGB(130, 130, 125)
local BARRICADES = {
	-- Entrada: vitrines quebradas na fachada e um buraco na parede da esquerda
	{ x = -56, z = Z3, inward = -Vector3.zAxis, style = "Glass" },
	{ x = 10, z = Z3, inward = -Vector3.zAxis, style = "Glass" },
	{ x = X0, z = 76, inward = Vector3.xAxis, style = "Wall" },
	{ x = X0, z = -18, inward = Vector3.xAxis, style = "Wall", zone = "Hortifruti" },
	{ x = X0, z = 18, inward = Vector3.xAxis, style = "Wall", zone = "Hortifruti" },
	{ x = -90, z = Z0, inward = Vector3.zAxis, style = "Door", zone = "Acougue" },
	{ x = X0, z = -72, inward = Vector3.xAxis, style = "Wall", zone = "Acougue" },
	-- Câmara Fria: os zumbis saem do miolo fechado da loja
	{ x = -18, z = Z1, inward = -Vector3.zAxis, style = "Wall", zone = "CamaraFria" },
	{ x = 18, z = Z1, inward = -Vector3.zAxis, style = "Wall", zone = "CamaraFria" },
	{ x = 56, z = Z0, inward = Vector3.zAxis, style = "Door", zone = "Estoque" },
	{ x = 72, z = Z0, inward = Vector3.zAxis, style = "Door", zone = "Estoque" },
	{ x = X3, z = 0, inward = -Vector3.xAxis, style = "Door", zone = "Doca" },
	{ x = X3, z = 24, inward = -Vector3.xAxis, style = "Wall", zone = "Doca" },
	{ x = 42, z = Z3, inward = -Vector3.zAxis, style = "Wall", zone = "Estacionamento", color = FENCE_COLOR },
	{ x = X3, z = 50, inward = -Vector3.xAxis, style = "Wall", zone = "Estacionamento", color = FENCE_COLOR },
}

local rng = Random.new(2026) -- sempre o mesmo "aleatório": o mapa sai igual toda vez

local MAT = MapKit.MAT

local COLOR = {
	Wall = Color3.fromRGB(205, 200, 188),
	Exterior = Color3.fromRGB(150, 62, 48),
	Ceiling = Color3.fromRGB(60, 60, 65),
	Metal = Color3.fromRGB(150, 150, 155),
	DarkMetal = Color3.fromRGB(45, 45, 50),
	Wood = Color3.fromRGB(120, 85, 50),
	Cardboard = Color3.fromRGB(170, 130, 85),
	Black = Color3.fromRGB(10, 10, 10),
	White = Color3.fromRGB(235, 235, 235),
	Yellow = Color3.fromRGB(255, 215, 40),
	Red = Color3.fromRGB(200, 25, 25),
	SignGreen = Color3.fromRGB(20, 110, 50),
}

local PRODUCT_COLORS = {
	Color3.fromRGB(210, 40, 40),
	Color3.fromRGB(240, 200, 40),
	Color3.fromRGB(40, 90, 200),
	Color3.fromRGB(50, 160, 70),
	Color3.fromRGB(240, 130, 30),
	Color3.fromRGB(235, 235, 235),
	Color3.fromRGB(130, 50, 160),
}
local GREENS = { Color3.fromRGB(60, 150, 50), Color3.fromRGB(110, 180, 60), Color3.fromRGB(40, 110, 40) }
local BREADS = { Color3.fromRGB(190, 140, 70), Color3.fromRGB(160, 105, 50), Color3.fromRGB(215, 175, 110) }
local FROZEN = { Color3.fromRGB(220, 235, 245), Color3.fromRGB(120, 170, 220), Color3.fromRGB(200, 60, 60) }
local FRUITS = {
	Color3.fromRGB(200, 30, 30),
	Color3.fromRGB(245, 140, 20),
	Color3.fromRGB(240, 215, 40),
	Color3.fromRGB(90, 170, 40),
	Color3.fromRGB(110, 40, 90),
}
local FRUIT_NAMES = { "MAÇÃ", "LARANJA", "BANANA", "LIMÃO", "UVA" } -- na mesma ordem das cores

-- Preços de mentirinha pras etiquetas e cartazes
local PRICES = { "1,99", "2,49", "3,29", "3,99", "4,59", "5,99", "6,49", "7,99", "8,90", "9,99", "12,90", "15,90" }
-- Categoria de cada corredor da Entrada (na ordem das gôndolas)
local AISLES = { "MERCEARIA", "BISCOITOS E DOCES", "BEBIDAS", "LIMPEZA", "HIGIENE", "CAFÉ DA MANHÃ" }
local PALLET_LABELS = { "FRÁGIL", "ARROZ 5KG", "FEIJÃO", "ÓLEO", "AÇÚCAR", "LEITE", "MACARRÃO" }

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local box = MapKit.box
local block = MapKit.block
local folder = MapKit.folder
local writeOn = MapKit.writeOn

local function floor(parent: Instance, xA: number, zA: number, xB: number, zB: number, color: Color3, mat: Enum.Material)
	box(parent, "Floor", Vector3.new(xB - xA, 1, zB - zA), CFrame.new((xA + xB) / 2, -0.5, (zA + zB) / 2), color, mat)
end

-- Um bloco reto de parede (alinhado a X ou Z) entre dois pontos, de yBottom até yTop
local function wallBlock(parent: Instance, name: string, x1: number, z1: number, x2: number, z2: number, yBottom: number, yTop: number, thickness: number, color: Color3, mat: Enum.Material, props: { [string]: any }?)
	local alongX = math.abs(x2 - x1) >= math.abs(z2 - z1)
	local length = if alongX then math.abs(x2 - x1) else math.abs(z2 - z1)
	local height = yTop - yBottom
	if length < 0.05 or height < 0.05 then
		return
	end
	local size = if alongX then Vector3.new(length, height, thickness) else Vector3.new(thickness, height, length)
	box(parent, name, size, CFrame.new((x1 + x2) / 2, yBottom + height / 2, (z1 + z2) / 2), color, mat, props)
end

-- Parede reta que já abre o vão das barricadas que caem nela (o pedaço de cima do vão fica)
local function cutWall(parent: Instance, name: string, x1: number, z1: number, x2: number, z2: number, yBottom: number, yTop: number, thickness: number, color: Color3, mat: Enum.Material, props: { [string]: any }?)
	local alongX = math.abs(x2 - x1) >= math.abs(z2 - z1)
	local line = if alongX then z1 else x1
	local from = if alongX then math.min(x1, x2) else math.min(z1, z2)
	local to = if alongX then math.max(x1, x2) else math.max(z1, z2)

	local cuts = {}
	if yBottom < BARRICADE_HEIGHT then
		for _, barricade in BARRICADES do
			local onLine = if alongX then math.abs(barricade.inward.Z) > 0.5 and math.abs(barricade.z - line) < 0.5 else math.abs(barricade.inward.X) > 0.5 and math.abs(barricade.x - line) < 0.5
			local at = if alongX then barricade.x else barricade.z
			if onLine and at > from and at < to then
				table.insert(cuts, at)
			end
		end
		table.sort(cuts)
	end

	local function piece(a: number, b: number, bottom: number, top: number)
		if alongX then
			wallBlock(parent, name, a, line, b, line, bottom, top, thickness, color, mat, props)
		else
			wallBlock(parent, name, line, a, line, b, bottom, top, thickness, color, mat, props)
		end
	end
	local cursor = from
	local half = BARRICADE_WIDTH / 2
	for _, at in cuts do
		piece(cursor, at - half, yBottom, yTop)
		piece(at - half, at + half, math.max(yBottom, BARRICADE_HEIGHT), yTop)
		cursor = at + half
	end
	piece(cursor, to, yBottom, yTop)
end

-- Parede comum (reboco) entre dois pontos, de yBottom até yTop
local function wall(parent: Instance, x1: number, z1: number, x2: number, z2: number, yBottom: number, yTop: number, color: Color3?, mat: Enum.Material?)
	cutWall(parent, "Wall", x1, z1, x2, z2, yBottom, yTop, WALL_THICKNESS, color or COLOR.Wall, mat or MAT.Plaster)
end

-- Parede com um vão de porta centrado em "doorAt" (coordenada ao longo da parede)
local function wallWithOpening(parent: Instance, x1: number, z1: number, x2: number, z2: number, doorAt: number, color: Color3?, mat: Enum.Material?)
	local half = DOOR_WIDTH / 2
	if math.abs(x2 - x1) >= math.abs(z2 - z1) then
		local a, b = math.min(x1, x2), math.max(x1, x2)
		wall(parent, a, z1, doorAt - half, z1, 0, WALL_HEIGHT, color, mat)
		wall(parent, doorAt + half, z1, b, z1, 0, WALL_HEIGHT, color, mat)
		wall(parent, doorAt - half, z1, doorAt + half, z1, DOOR_HEIGHT, WALL_HEIGHT, color, mat)
	else
		local a, b = math.min(z1, z2), math.max(z1, z2)
		wall(parent, x1, a, x1, doorAt - half, 0, WALL_HEIGHT, color, mat)
		wall(parent, x1, doorAt + half, x1, b, 0, WALL_HEIGHT, color, mat)
		wall(parent, x1, doorAt - half, x1, doorAt + half, DOOR_HEIGHT, WALL_HEIGHT, color, mat)
	end
end

-- Porta de aço paga, no vão da parede (ver DoorService)
local function door(parent: Instance, x: number, z: number, alongX: boolean, zones: string, price: number, label: string)
	local rotation = if alongX then CFrame.identity else CFrame.Angles(0, math.rad(90), 0)
	local part = box(parent, "Door", Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, 1), CFrame.new(x, DOOR_HEIGHT / 2, z) * rotation, Color3.fromRGB(125, 125, 130), Enum.Material.CorrodedMetal)
	part:SetAttribute("Price", price)
	part:SetAttribute("Zones", zones)
	part:SetAttribute("Label", label)
	CollectionService:AddTag(part, "Door")
end

-- Arma na parede. (x, z) é um ponto na face da parede; "inward" aponta pra dentro da sala
local function wallBuy(parent: Instance, weaponId: string, x: number, z: number, inward: Vector3)
	local position = Vector3.new(x, 5.5, z) + inward * 0.25
	MapKit.wallBuy(parent, weaponId, CFrame.lookAt(position, position + inward))
end

-- Entradas dos zumbis (lista BARRICADES lá em cima): tábuas no vão e o spawn do lado de fora
local function buildBarricades(parent: Instance)
	for _, info in BARRICADES do
		local base = Vector3.new(info.x, 0, info.z)
		MapKit.barricade(parent, CFrame.lookAt(base, base + info.inward), BARRICADE_WIDTH, BARRICADE_HEIGHT, WALL_THICKNESS, info.style, info.zone, info.color or COLOR.Wall)
	end
end

-- Lugar possível da Caixa Surpresa (um por área; a partida sorteia um só e ela fica lá).
-- "facing" = pra onde a frente da caixa aponta; "area" = nome que aparece no aviso
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

-- Luminária no teto (algumas piscam: tag "Flicker", ver MapService)
local function ceilingLight(parent: Instance, x: number, z: number, color: Color3, brightness: number)
	local lamp = box(parent, "CeilingLight", Vector3.new(4, 0.3, 1.2), CFrame.new(x, WALL_HEIGHT - 0.15, z), color, Enum.Material.Neon, { CastShadow = false })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 34
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = lamp
	if rng:NextNumber() < 0.25 then
		CollectionService:AddTag(lamp, "Flicker")
	end
end

local function lightGrid(parent: Instance, xA: number, zA: number, xB: number, zB: number, color: Color3, brightness: number)
	local countX = math.max(1, math.floor((xB - xA) / 24))
	local countZ = math.max(1, math.floor((zB - zA) / 24))
	for i = 1, countX do
		for j = 1, countZ do
			ceilingLight(parent, xA + (i - 0.5) * (xB - xA) / countX, zA + (j - 0.5) * (zB - zA) / countZ, color, brightness)
		end
	end
end

-- Placa pendurada no teto, com o texto dos dois lados
local function hangingSign(parent: Instance, x: number, z: number, width: number, text: string, background: Color3, textColor: Color3, alongX: boolean)
	local rotation = if alongX then CFrame.identity else CFrame.Angles(0, math.rad(90), 0)
	local signPart = box(parent, "Sign", Vector3.new(width, 3, 0.4), CFrame.new(x, 15.5, z) * rotation, background)
	writeOn(signPart, Enum.NormalId.Front, text, textColor)
	writeOn(signPart, Enum.NormalId.Back, text, textColor)
	for _, side in { -1, 1 } do
		box(parent, "SignChain", Vector3.new(0.12, 2.8, 0.12), CFrame.new(x, 18.4, z) * rotation * CFrame.new(side * width * 0.4, 0, 0), COLOR.DarkMetal, Enum.Material.Metal, { CanCollide = false })
	end
end

-- ===================== Detalhes de mercado: preços, cartazes e produtos =====================

local BAG_MATERIAL = MapKit.material("Foil", Enum.Material.SmoothPlastic)
local CHALK = Color3.fromRGB(28, 45, 35) -- lousa verde-escura dos preços

local function randomPrice(): string
	return "R$ " .. pick(PRICES)
end

-- Etiqueta amarela de preço; o texto fica virado pra "facing"
local function priceTag(parent: Instance, position: Vector3, facing: Vector3, text: string, width: number?)
	local tag = box(parent, "PriceTag", Vector3.new(width or 1, 0.45, 0.05), CFrame.lookAt(position, position + facing), COLOR.Yellow, nil, {
		CanCollide = false,
		CanQuery = false,
	})
	writeOn(tag, Enum.NormalId.Front, text, COLOR.Black, nil, 100)
end

-- Lousa de preços (ou cartaz) virada pra "facing"; twoSided = escreve atrás também
local function chalkboard(parent: Instance, position: Vector3, facing: Vector3, size: Vector2, text: string, twoSided: boolean?, background: Color3?, textColor: Color3?)
	local board = box(parent, "PriceBoard", Vector3.new(size.X, size.Y, 0.2), CFrame.lookAt(position, position + facing), background or CHALK, nil, { CanCollide = false })
	writeOn(board, Enum.NormalId.Front, text, textColor or COLOR.White, nil, 40)
	if twoSided then
		writeOn(board, Enum.NormalId.Back, text, textColor or COLOR.White, nil, 40)
	end
end

-- Faixa grande de propaganda na parede, virada pra "facing"
local function banner(parent: Instance, position: Vector3, facing: Vector3, size: Vector2, text: string, background: Color3, textColor: Color3)
	local part = box(parent, "Banner", Vector3.new(size.X, size.Y, 0.2), CFrame.lookAt(position, position + facing), background, nil, { CanCollide = false })
	writeOn(part, Enum.NormalId.Front, text, textColor)
end

-- Pirâmide de fardos de promoção com a placa em cima (a placa fica virada pra "facing")
local function promoPyramid(parent: Instance, x: number, z: number, facing: Vector3, color: Color3, text: string)
	local base = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z) + facing)
	for layer = 0, 4 do
		local count = 5 - layer
		for index = 1, count do
			for row = 0, 1 do
				local packCFrame = base * CFrame.new((index - (count + 1) / 2) * 1.45, 0.45 + layer * 0.92, (row - 0.5) * 1.15)
				box(parent, "Pack", Vector3.new(1.4, 0.9, 1.1), packCFrame, color:Lerp(COLOR.White, rng:NextNumber(0, 0.15)), BAG_MATERIAL)
			end
		end
	end
	local sign = box(parent, "PromoSign", Vector3.new(4, 1.6, 0.2), base * CFrame.new(0, 5.45, 0), COLOR.Yellow, nil, { CanCollide = false })
	writeOn(sign, Enum.NormalId.Front, text, COLOR.Red, nil, 40)
	writeOn(sign, Enum.NormalId.Back, text, COLOR.Red, nil, 40)
end

-- Enche um trecho de prateleira com um tipo só de produto (como nas lojas de verdade).
-- "at" = meio do trecho, em cima da prateleira, com o X local ao longo dela
local function stockShelf(parent: Instance, at: CFrame, length: number, palette: { Color3 }, kinds: { string })
	local kind = pick(kinds)
	local color = pick(palette)
	local width = if kind == "Box" then 0.9 elseif kind == "Bag" then 1.05 elseif kind == "Veg" then 0.85 else 0.6
	local count = math.max(1, math.floor(length / (width + 0.1)))
	local spacing = length / count
	for index = 1, count do
		local spot = at * CFrame.new(-length / 2 + (index - 0.5) * spacing, 0, 0)
		local shade = color:Lerp(COLOR.White, rng:NextNumber(0, 0.15))
		if kind == "Box" then -- caixa (cereal, biscoito, congelado)
			local height = rng:NextNumber(1.2, 1.55)
			box(parent, "Product", Vector3.new(width, height, 0.7), spot * CFrame.new(0, height / 2, 0), shade, MAT.Cardboard)
		elseif kind == "Bag" then -- pacote (salgadinho, pão de forma)
			box(parent, "Product", Vector3.new(width, 1.1, 0.6), spot * CFrame.new(0, 0.55, 0) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, 0), shade, BAG_MATERIAL)
		elseif kind == "Bottle" then -- garrafa
			box(parent, "Product", Vector3.new(1.35, 0.5, 0.5), spot * CFrame.new(0, 0.675, 0) * CFrame.Angles(0, 0, math.rad(90)), shade, nil, { Shape = Enum.PartType.Cylinder })
		elseif kind == "Veg" then -- verdura (alface, repolho)
			box(parent, "Product", Vector3.one * 0.85, spot * CFrame.new(0, 0.42, 0), shade, Enum.Material.Grass, { Shape = Enum.PartType.Ball })
		else -- latas, empilhadas de duas
			for level = 0, 1 do
				box(parent, "Product", Vector3.new(0.75, 0.55, 0.55), spot * CFrame.new(0, 0.375 + level * 0.77, 0) * CFrame.Angles(0, 0, math.rad(90)), shade, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
			end
		end
	end
end

-- Prateleira comprida com produtos e etiquetas de preço. alongX: comprimento no eixo X.
-- sides: lados que têm produto (-1 / 1 no eixo perpendicular; os dois = gôndola dupla)
-- kinds: tipos de produto (padrão: caixas, garrafas, latas e pacotes)
local function shelving(parent: Instance, x: number, z: number, length: number, alongX: boolean, sides: { number }, palette: { Color3 }, kinds: { string }?)
	local function place(name: string, offset: number, y: number, along: number, across: number, height: number, color: Color3, mat: Enum.Material?)
		local size = if alongX then Vector3.new(along, height, across) else Vector3.new(across, height, along)
		local position = if alongX then Vector3.new(x, y + height / 2, z + offset) else Vector3.new(x + offset, y + height / 2, z)
		box(parent, name, size, CFrame.new(position), color, mat)
	end
	-- ponto na prateleira: "offset" pro lado (perpendicular), "alongOffset" ao longo dela
	local function spot(offset: number, alongOffset: number, y: number): Vector3
		return if alongX then Vector3.new(x + alongOffset, y, z + offset) else Vector3.new(x + offset, y, z + alongOffset)
	end
	local alongRotation = if alongX then CFrame.identity else CFrame.Angles(0, math.rad(90), 0)

	place("ShelfBase", 0, 0, length, 3.4, 0.6, COLOR.DarkMetal)
	place("ShelfBack", 0, 0, length, 0.3, 7.2, COLOR.Metal, Enum.Material.Metal)
	local segments = math.max(1, math.floor(length / 4))
	local segmentLength = length / segments
	for _, side in sides do
		local outward = if alongX then Vector3.new(0, 0, side) else Vector3.new(side, 0, 0)
		for level = 1, 3 do
			local y = level * 2.1 - 0.6
			place("Shelf", side * 0.85, y, length, 1.4, 0.15, COLOR.Metal, Enum.Material.Metal)
			for segment = 1, segments do
				local alongOffset = -length / 2 + (segment - 0.5) * segmentLength
				stockShelf(parent, CFrame.new(spot(side * 0.85, alongOffset, y + 0.15)) * alongRotation, segmentLength - 0.3, palette, kinds or { "Box", "Bottle", "Can", "Bag" })
				-- etiqueta de preço na beirada da prateleira do meio
				if level == 2 then
					priceTag(parent, spot(side * 1.58, alongOffset, y + 0.075), outward, randomPrice())
				end
			end
		end
	end
end

local function checkout(parent: Instance, x: number, z: number, number: number)
	block(parent, "Checkout", Vector3.new(2.6, 3.2, 10), x, z, Color3.fromRGB(215, 215, 220))
	block(parent, "Belt", Vector3.new(2.2, 0.1, 6), x, z - 1.5, COLOR.Black, MAT.Rubber, nil, 3.2)
	block(parent, "Register", Vector3.new(1.6, 1.2, 1.4), x, z + 3.2, COLOR.DarkMetal, nil, nil, 3.2)
	block(parent, "LanePole", Vector3.new(0.3, 7, 0.3), x + 1.1, z + 4.6, COLOR.Metal, Enum.Material.Metal, nil, 3.2)
	local laneSign = block(parent, "LaneSign", Vector3.new(1.4, 1.4, 0.4), x + 1.1, z + 4.6, COLOR.Red, nil, nil, 10.2)
	writeOn(laneSign, Enum.NormalId.Front, tostring(number), COLOR.White)
	writeOn(laneSign, Enum.NormalId.Back, tostring(number), COLOR.White)

	-- telinha do caixa (virada pra quem chega na fila)
	local screenPosition = Vector3.new(x, 4.75, z + 2.45)
	local screen = box(parent, "RegisterScreen", Vector3.new(1.2, 0.7, 0.1), CFrame.lookAt(screenPosition, screenPosition - Vector3.zAxis), Color3.fromRGB(10, 25, 15), nil, { CanCollide = false })
	writeOn(screen, Enum.NormalId.Front, "R$ 0,00", Color3.fromRGB(90, 255, 120), nil, 100)

	-- display de doces do lado do caixa
	local rackX = x - 1.95
	block(parent, "CandyRack", Vector3.new(0.9, 3.4, 2), rackX, z + 1, COLOR.DarkMetal, Enum.Material.Metal)
	for level = 0, 2 do
		for slot = -1, 1 do
			block(parent, "Candy", Vector3.new(0.3, 0.5, 0.5), rackX - 0.5, z + 1 + slot * 0.6, pick(PRODUCT_COLORS), nil, { CanCollide = false }, 0.9 + level * 0.95)
		end
	end
end

local cart = MapKit.cart

local function fruitStand(parent: Instance, x: number, z: number)
	block(parent, "Stand", Vector3.new(8, 2.6, 5), x, z, COLOR.Wood, Enum.Material.WoodPlanks)

	-- lousa com o nome e o preço da fruta principal, em cima da banca
	local featured = rng:NextInteger(1, #FRUITS)
	chalkboard(parent, Vector3.new(x, 5, z), Vector3.zAxis, Vector2.new(3.6, 1.2), `{FRUIT_NAMES[featured]}\n{randomPrice()}/kg`, true)
	for _, dx in { -1.7, 1.7 } do
		block(parent, "SignPost", Vector3.new(0.12, 1.8, 0.12), x + dx, z, COLOR.Wood, nil, { CanCollide = false }, 2.6)
	end

	for i = 0, 3 do
		for j = 0, 1 do
			local cx, cz = x - 3 + i * 2, z - 1.2 + j * 2.4
			local color = if i == 0 and j == 0 then FRUITS[featured] else pick(FRUITS)
			block(parent, "Crate", Vector3.new(1.9, 0.6, 2.3), cx, cz, Color3.fromRGB(150, 110, 65), Enum.Material.WoodPlanks, nil, 2.6)
			for _ = 1, 3 do
				box(parent, "Fruit", Vector3.one * 0.8, CFrame.new(cx + rng:NextNumber(-0.5, 0.5), 3.55, cz + rng:NextNumber(-0.6, 0.6)), color, nil, { Shape = Enum.PartType.Ball })
			end
		end
	end
end

-- Carcaça pendurada no teto por uma corrente (fica acima da cabeça, não bloqueia)
local function carcass(parent: Instance, x: number, z: number)
	block(parent, "Chain", Vector3.new(0.15, 9, 0.15), x, z, COLOR.DarkMetal, Enum.Material.Metal, { CanCollide = false }, 11)
	block(parent, "Carcass", Vector3.new(1.8, 4.5, 1.2), x, z, Color3.fromRGB(150, 60, 60), nil, nil, 6.5)
	block(parent, "Fat", Vector3.new(1.9, 1, 1.3), x, z, Color3.fromRGB(225, 205, 185), nil, nil, 9.5)
end

local function oven(parent: Instance, x: number, z: number, inward: Vector3)
	local center = Vector3.new(x, 3.5, z)
	local frame = CFrame.lookAt(center, center + inward)
	local body = box(parent, "Oven", Vector3.new(6, 7, 4), frame, Color3.fromRGB(110, 110, 115), Enum.Material.Metal)
	box(parent, "OvenWindow", Vector3.new(4, 2, 0.1), frame * CFrame.new(0, 0.5, -2.05), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 130, 50)
	glow.Range = 12
	glow.Brightness = 1.5
	glow.Parent = body
end

local function palletRack(parent: Instance, x: number, zA: number, zB: number)
	local length = zB - zA
	local cz = (zA + zB) / 2
	for _, rz in { zA, cz, zB } do
		for _, dx in { -1.8, 1.8 } do
			block(parent, "Upright", Vector3.new(0.5, 15, 0.5), x + dx, rz, Color3.fromRGB(40, 70, 160), Enum.Material.Metal)
		end
	end
	for _, y in { 0.3, 5, 10 } do
		for _, dx in { -1.8, 1.8 } do
			block(parent, "Beam", Vector3.new(0.4, 0.5, length), x + dx, cz, Color3.fromRGB(230, 120, 30), Enum.Material.Metal, nil, y)
		end
		block(parent, "Deck", Vector3.new(4, 0.2, length), x, cz, COLOR.Wood, Enum.Material.WoodPlanks, nil, y + 0.5)
		local count = math.floor(length / 3.2)
		for i = 1, count do
			if rng:NextNumber() < 0.8 then
				local height = rng:NextNumber(1.8, 3.6)
				block(parent, "Box", Vector3.new(3, height, 2.6), x + rng:NextNumber(-0.3, 0.3), zA + (i - 0.5) * length / count, COLOR.Cardboard, MAT.Cardboard, nil, y + 0.7)
			end
		end
	end
end

local function pallet(parent: Instance, x: number, z: number, loaded: boolean)
	block(parent, "Pallet", Vector3.new(4, 0.5, 4), x, z, COLOR.Wood, Enum.Material.WoodPlanks)
	if loaded then
		local load = block(parent, "PalletLoad", Vector3.new(3.6, rng:NextNumber(2, 4), 3.6), x, z, COLOR.Cardboard, MAT.Cardboard, nil, 0.5)
		local label = pick(PALLET_LABELS)
		writeOn(load, Enum.NormalId.Front, label, Color3.fromRGB(40, 30, 20))
		writeOn(load, Enum.NormalId.Right, label, Color3.fromRGB(40, 30, 20))
	end
end

local function forklift(parent: Instance, x: number, z: number, yaw: number)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local yellow = Color3.fromRGB(235, 180, 30)
	box(parent, "ForkliftBody", Vector3.new(4, 3, 6), base * CFrame.new(0, 2, 0.5), yellow, Enum.Material.Metal)
	box(parent, "ForkliftWeight", Vector3.new(4, 2, 1.5), base * CFrame.new(0, 2.5, 4), COLOR.DarkMetal, Enum.Material.Metal)
	box(parent, "ForkliftSeat", Vector3.new(2, 1, 2), base * CFrame.new(0, 4, 1.5), COLOR.Black)
	for _, offset in { Vector3.new(-1.8, 5.5, -0.8), Vector3.new(1.8, 5.5, -0.8), Vector3.new(-1.8, 5.5, 3), Vector3.new(1.8, 5.5, 3) } do
		box(parent, "ForkliftPost", Vector3.new(0.25, 4, 0.25), base * CFrame.new(offset), COLOR.Black)
	end
	box(parent, "ForkliftRoof", Vector3.new(4, 0.2, 4.2), base * CFrame.new(0, 7.6, 1.1), COLOR.Black)
	box(parent, "ForkliftMast", Vector3.new(3, 8, 0.4), base * CFrame.new(0, 4.5, -2.7), COLOR.DarkMetal, Enum.Material.Metal)
	for _, dx in { -0.9, 0.9 } do
		box(parent, "Fork", Vector3.new(0.4, 0.2, 4), base * CFrame.new(dx, 0.5, -4.8), COLOR.DarkMetal, Enum.Material.Metal)
	end
	for _, offset in { Vector3.new(-2.1, 0.8, -1.5), Vector3.new(2.1, 0.8, -1.5), Vector3.new(-2.1, 0.8, 2.6), Vector3.new(2.1, 0.8, 2.6) } do
		box(parent, "Wheel", Vector3.new(0.8, 1.6, 1.6), base * CFrame.new(offset), COLOR.Black, nil, { Shape = Enum.PartType.Cylinder })
	end
end

local function car(parent: Instance, x: number, z: number, yaw: number, color: Color3, burning: boolean)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local body = box(parent, "CarBody", Vector3.new(6, 2.2, 12), base * CFrame.new(0, 1.9, 0), color, Enum.Material.Metal)
	box(parent, "CarCabin", Vector3.new(5.4, 2, 6), base * CFrame.new(0, 4, 0.8), Color3.fromRGB(20, 22, 28), Enum.Material.Glass, { Transparency = 0.15 })
	for _, offset in { Vector3.new(-3, 1, -3.8), Vector3.new(3, 1, -3.8), Vector3.new(-3, 1, 3.8), Vector3.new(3, 1, 3.8) } do
		box(parent, "Wheel", Vector3.new(1, 2, 2), base * CFrame.new(offset), COLOR.Black, nil, { Shape = Enum.PartType.Cylinder })
	end
	if burning then
		local fire = Instance.new("Fire")
		fire.Size = 7
		fire.Heat = 12
		fire.Parent = body
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 140, 50)
		glow.Range = 30
		glow.Brightness = 2
		glow.Parent = body
	end
end

local function truck(parent: Instance, x: number, z: number)
	local base = CFrame.new(x, 0, z)
	box(parent, "TruckCargo", Vector3.new(8, 9, 16), base * CFrame.new(0, 6, 2), Color3.fromRGB(220, 220, 215), Enum.Material.Metal)
	box(parent, "TruckStripe", Vector3.new(8.1, 1.2, 16.1), base * CFrame.new(0, 5, 2), COLOR.SignGreen)
	box(parent, "TruckCab", Vector3.new(8, 6, 5), base * CFrame.new(0, 4.5, -8.5), Color3.fromRGB(180, 40, 35), Enum.Material.Metal)
	box(parent, "Windshield", Vector3.new(7, 2.4, 0.2), base * CFrame.new(0, 6, -11.05), Color3.fromRGB(20, 22, 28), Enum.Material.Glass)
	for _, offset in { Vector3.new(-4.1, 1.2, -8), Vector3.new(4.1, 1.2, -8), Vector3.new(-4.1, 1.2, 5), Vector3.new(4.1, 1.2, 5), Vector3.new(-4.1, 1.2, 8), Vector3.new(4.1, 1.2, 8) } do
		box(parent, "Wheel", Vector3.new(1.2, 2.4, 2.4), base * CFrame.new(offset), COLOR.Black, nil, { Shape = Enum.PartType.Cylinder })
	end
end

local function lampPost(parent: Instance, x: number, z: number)
	block(parent, "LampPost", Vector3.new(0.6, 16, 0.6), x, z, COLOR.DarkMetal, Enum.Material.Metal)
	local head = block(parent, "LampHead", Vector3.new(3, 0.6, 1.4), x, z, Color3.fromRGB(255, 170, 90), Enum.Material.Neon, nil, 16)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 80)
	light.Range = 55
	light.Brightness = 1.6
	light.Shadows = true
	light.Parent = head
end

-- ===================== Partes do mapa =====================

local function buildStructure(parent: Instance)
	-- Pisos
	floor(parent, X0, Z2, X2, Z3, Color3.fromRGB(215, 215, 210), MAT.Tiles) -- Entrada
	floor(parent, X2, Z2, X3, Z3, Color3.fromRGB(45, 45, 48), MAT.Asphalt) -- Estacionamento
	floor(parent, X0, Z1, X1, Z2, Color3.fromRGB(200, 215, 195), MAT.Tiles) -- Hortifruti
	floor(parent, X1, Z1, X2, Z2, Color3.fromRGB(90, 90, 90), Enum.Material.Concrete) -- miolo fechado
	floor(parent, X2, Z1, X3, Z2, Color3.fromRGB(120, 120, 115), Enum.Material.Concrete) -- Doca
	floor(parent, X0, Z0, X1, Z1, Color3.fromRGB(220, 200, 195), MAT.Tiles) -- Açougue
	floor(parent, X1, Z0, X2, Z1, Color3.fromRGB(150, 175, 195), Enum.Material.DiamondPlate) -- Câmara Fria
	floor(parent, X2, Z0, X3, Z1, Color3.fromRGB(110, 110, 105), Enum.Material.Concrete) -- Estoque

	-- Paredes externas da loja
	wall(parent, X0 - 1, Z0, X3 + 1, Z0, 0, WALL_HEIGHT) -- fundo
	wall(parent, X0, Z0, X0, Z3, 0, WALL_HEIGHT) -- esquerda
	wall(parent, X3, Z0, X3, Z2, 0, WALL_HEIGHT) -- direita (Estoque e Doca)

	-- Fachada de vidro da Entrada
	wall(parent, X0 - 1, Z3, X2 + 1, Z3, 0, 3)
	wall(parent, X0 - 1, Z3, X2 + 1, Z3, 14, WALL_HEIGHT)
	cutWall(parent, "Vitrine", X0 - 1, Z3, X2 + 1, Z3, 3, 14, 0.6, Color3.fromRGB(140, 160, 170), Enum.Material.Glass, { Transparency = 0.55 })
	for x = X0 + 16, X2 - 16, 16 do
		block(parent, "Pillar", Vector3.new(2, 11, 2.4), x, Z3, COLOR.Wall, MAT.Plaster, nil, 3)
	end

	-- Muro do estacionamento com arame farpado
	-- alambrado: mureta + tela (dá pra ver o estacionamento de fora, mas não dá pra sair)
	for _, line in { { X3, Z2, X3, Z3 + 1 }, { X2, Z3, X3, Z3 } } do
		local x1, z1, x2, z2 = line[1], line[2], line[3], line[4]
		cutWall(parent, "FenceBase", x1, z1, x2, z2, 0, 1.2, WALL_THICKNESS, FENCE_COLOR, Enum.Material.Concrete)
		cutWall(parent, "FenceMesh", x1, z1, x2, z2, 1.2, FENCE_HEIGHT, 0.3, Color3.fromRGB(60, 65, 70), Enum.Material.DiamondPlate, { Transparency = 0.65 })
		-- postes a cada 8 studs (menos onde tem barricada)
		local alongX = math.abs(x2 - x1) > math.abs(z2 - z1)
		local from, to = if alongX then math.min(x1, x2) else math.min(z1, z2), if alongX then math.max(x1, x2) else math.max(z1, z2)
		for at = from, to, 8 do
			local nearHole = false
			for _, barricade in BARRICADES do
				local holeAt = if alongX then barricade.x else barricade.z
				local holeLine = if alongX then barricade.z else barricade.x
				if math.abs(holeLine - (if alongX then z1 else x1)) < 0.5 and math.abs(holeAt - at) < BARRICADE_WIDTH / 2 + 0.6 then
					nearHole = true
				end
			end
			if not nearHole then
				block(parent, "FencePost", Vector3.new(0.5, FENCE_HEIGHT + 0.6, 0.5), if alongX then at else x1, if alongX then z1 else at, COLOR.DarkMetal, Enum.Material.Metal)
			end
		end
	end
	for _, y in { FENCE_HEIGHT + 0.3, FENCE_HEIGHT + 0.8 } do
		box(parent, "Wire", Vector3.new(0.15, 0.15, Z3 - Z2), CFrame.new(X3, y, (Z2 + Z3) / 2), COLOR.DarkMetal, Enum.Material.Metal, { CanCollide = false })
		box(parent, "Wire", Vector3.new(X3 - X2, 0.15, 0.15), CFrame.new((X2 + X3) / 2, y, Z3), COLOR.DarkMetal, Enum.Material.Metal, { CanCollide = false })
	end

	-- Paredes internas (com os vãos das portas)
	wallWithOpening(parent, X0, Z2, X1, Z2, -64) -- Entrada | Hortifruti
	wall(parent, X1, Z2, X2, Z2, 0, WALL_HEIGHT) -- Entrada | miolo
	wallWithOpening(parent, X2, Z2, X3, Z2, 64, COLOR.Exterior, Enum.Material.Brick) -- Estacionamento | Doca
	wallWithOpening(parent, X0, Z1, X1, Z1, -64) -- Hortifruti | Açougue
	wall(parent, X1, Z1, X2, Z1, 0, WALL_HEIGHT) -- miolo | Câmara Fria
	wallWithOpening(parent, X2, Z1, X3, Z1, 64) -- Doca | Estoque
	wall(parent, X1, Z1, X1, Z2, 0, WALL_HEIGHT) -- Hortifruti | miolo
	wallWithOpening(parent, X1, Z0, X1, Z1, -56) -- Açougue | Câmara Fria
	wall(parent, X2, Z1, X2, Z2, 0, WALL_HEIGHT) -- miolo | Doca
	wallWithOpening(parent, X2, Z0, X2, Z1, -56) -- Câmara Fria | Estoque
	wallWithOpening(parent, X2, Z2, X2, Z3, 56, COLOR.Exterior, Enum.Material.Brick) -- Entrada | Estacionamento

	-- Teto (o estacionamento fica a céu aberto)
	box(parent, "Ceiling", Vector3.new(X2 - X0 + 2, 1, Z3 - Z0 + 2), CFrame.new((X0 + X2) / 2, WALL_HEIGHT + 0.5, (Z0 + Z3) / 2), COLOR.Ceiling)
	box(parent, "Ceiling", Vector3.new(X3 - X2 + 1, 1, Z2 - Z0 + 2), CFrame.new((X2 + 1 + X3 + 1) / 2, WALL_HEIGHT + 0.5, (Z0 + Z2) / 2), COLOR.Ceiling)

	-- Portas pagas
	door(parent, -64, Z2, true, "Hortifruti", 750, "Hortifruti")
	door(parent, X2, 56, false, "Estacionamento", 750, "Estacionamento")
	door(parent, -64, Z1, true, "Acougue", 1000, "Açougue e Padaria")
	door(parent, 64, Z2, true, "Doca", 1000, "Doca de Carga")
	door(parent, X1, -56, false, "CamaraFria", 1250, "Câmara Fria")
	door(parent, 64, Z1, true, "Estoque", 1500, "Estoque")
	door(parent, X2, -56, false, "CamaraFria,Estoque", 1000, "Corredor dos Fundos")
end

local function buildEntrada(parent: Instance)
	-- Gôndolas (corredores de produtos), com a placa do corredor e a oferta na ponta
	for index, x in { -86, -48, -36, -24, -12, 0 } do
		shelving(parent, x, 43, 18, false, { -1, 1 }, PRODUCT_COLORS)
		local offer = box(parent, "Oferta", Vector3.new(3.2, 1.6, 0.2), CFrame.new(x, 8.6, 52.2), COLOR.Yellow)
		writeOn(offer, Enum.NormalId.Back, `OFERTA!\n{randomPrice()}`, COLOR.Red)
		hangingSign(parent, x, 43, 8, `{index}  {AISLES[index]}`, Color3.fromRGB(40, 90, 170), COLOR.White, true)
	end

	-- Promoções no meio da loja
	promoPyramid(parent, -72, 40, Vector3.zAxis, Color3.fromRGB(200, 30, 30), "REFRI\nLEVE 3 PAGUE 2!")
	promoPyramid(parent, -60, 47, Vector3.zAxis, Color3.fromRGB(70, 150, 220), "ÁGUA 6 UN.\nR$ 9,90")

	-- Faixas de propaganda nas paredes
	banner(parent, Vector3.new(X0 + 1.15, 12, 61), Vector3.xAxis, Vector2.new(16, 4), "O MENOR PREÇO DA CIDADE!", COLOR.Red, COLOR.Yellow)
	banner(parent, Vector3.new(-10, 12, Z2 + 1.15), Vector3.zAxis, Vector2.new(26, 4), "TUDO FRESQUINHO TODO DIA", COLOR.SignGreen, COLOR.White)

	-- Pilha de cestinhas perto da porta
	for level = 0, 5 do
		block(parent, "Basket", Vector3.new(1.8, 0.45, 2.4), -6, 79, COLOR.Red, nil, nil, level * 0.32)
	end
	chalkboard(parent, Vector3.new(-6, 2.8, 80.3), Vector3.zAxis * -1, Vector2.new(2, 0.6), "CESTAS", false, COLOR.Yellow, COLOR.Red)

	-- Quiosque da loja: Colete Blindado
	local armorPosition = Vector3.new(X0 + 2.3, 0, 60)
	MapKit.shopStand(parent, CFrame.lookAt(armorPosition, armorPosition + Vector3.xAxis), "Armor")

	-- Caixas
	for index, x in { -86, -74, -62, -50, -38 } do
		checkout(parent, x, 68, index)
	end

	-- Carrinhos largados
	cart(parent, -20, 78, 0.4)
	cart(parent, -14, 77, -0.2)
	cart(parent, 6, 70, 1.3)
	cart(parent, -84, 55, 2.6)
	cart(parent, 14, 46, -0.9)

	-- Portas de vidro da entrada, barricadas
	box(parent, "EntranceDoors", Vector3.new(16, 10, 0.4), CFrame.new(-18, 5, Z3 - 1), Color3.fromRGB(30, 35, 40), Enum.Material.Glass, { Transparency = 0.3 })
	for index, angle in { 20, -15, 10, -25 } do
		box(parent, "Barricade", Vector3.new(17, 0.8, 0.3), CFrame.new(-18, 1.5 + index * 1.8, Z3 - 1.5) * CFrame.Angles(0, 0, math.rad(angle)), COLOR.Wood, Enum.Material.WoodPlanks)
	end

	hangingSign(parent, -40, 57, 34, STORE_NAME, COLOR.SignGreen, COLOR.Yellow, true)

	wallBuy(parent, "SMG", X0 + 1, 44, Vector3.xAxis)
	wallBuy(parent, "Pistol", X2 - 1, 36, -Vector3.xAxis)

	-- parede dourada: Arsenal Lendário (premium; quem não tem o passe vê a loja dele)
	for index, id in { "ConfettiCannon", "FreezeRay", "ChainLightning" } do
		wallBuy(parent, id, -37 + index * 10, Z2 + 1, Vector3.zAxis)
	end
	chalkboard(parent, Vector3.new(-17, 8.7, Z2 + 1.15), Vector3.zAxis, Vector2.new(28, 1.4), "★ ARSENAL LENDÁRIO ★", false, Color3.fromRGB(40, 30, 10), Color3.fromRGB(255, 205, 50))


	boxSpot(parent, 20, 40, -Vector3.xAxis, "Entrada")
	playerSpawn(parent, -70, 58)
	playerSpawn(parent, -60, 58)

	lightGrid(parent, X0, Z2, X2, Z3, Color3.fromRGB(235, 240, 255), 1)
end

local function buildHortifruti(parent: Instance)
	for _, position in { Vector2.new(-76, -12), Vector2.new(-76, 10), Vector2.new(-52, -12), Vector2.new(-52, 10) } do
		fruitStand(parent, position.X, position.Y)
	end
	-- balcão refrigerado de verduras encostado na parede do miolo
	shelving(parent, X1 - 2.7, 0, 36, false, { -1 }, GREENS, { "Veg" })

	-- caixote de melancias
	block(parent, "MelonBin", Vector3.new(5, 2, 3.4), -44, -21, COLOR.Wood, Enum.Material.WoodPlanks)
	for index = 0, 5 do
		local mx, mz = -45.8 + (index % 3) * 1.8, -21.8 + math.floor(index / 3) * 1.6
		box(parent, "Melon", Vector3.new(1.6, 1.3, 1.3), CFrame.new(mx, 2.5, mz) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromRGB(40, 110, 45), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball })
	end
	chalkboard(parent, Vector3.new(-44, 4.4, -19.2), Vector3.zAxis, Vector2.new(3.4, 1), `MELANCIA\n{randomPrice()}/kg`)

	-- balança
	block(parent, "ScaleCounter", Vector3.new(4, 3, 2), -52, 22, COLOR.White)
	block(parent, "Scale", Vector3.new(1.6, 0.4, 1.4), -52, 22, COLOR.Metal, Enum.Material.Metal, nil, 3)
	local scaleScreen = block(parent, "ScaleScreen", Vector3.new(1.2, 0.6, 0.15), -52, 22.6, Color3.fromRGB(10, 25, 15), nil, { CanCollide = false }, 3.4)
	writeOn(scaleScreen, Enum.NormalId.Front, "0,000 kg", Color3.fromRGB(90, 255, 120), nil, 100)
	chalkboard(parent, Vector3.new(-52, 5.3, 22.2), -Vector3.zAxis, Vector2.new(3, 0.8), "BALANÇA", true, Color3.fromRGB(40, 130, 50))

	banner(parent, Vector3.new(X0 + 1.15, 12.5, 0), Vector3.xAxis, Vector2.new(16, 3), "FRUTAS FRESQUINHAS", Color3.fromRGB(40, 130, 50), COLOR.Yellow)

	hangingSign(parent, -64, -1, 16, "HORTIFRUTI", Color3.fromRGB(40, 130, 50), COLOR.White, true)
	wallBuy(parent, "Shotgun", X0 + 1, 0, Vector3.xAxis)
	boxSpot(parent, -64, -1, Vector3.zAxis, "Hortifruti")

	lightGrid(parent, X0, Z1, X1, Z2, Color3.fromRGB(235, 255, 230), 1)
end

local function buildAcougue(parent: Instance)
	-- balcão de carnes com vitrine
	block(parent, "MeatCounter", Vector3.new(32, 3, 3), -64, -79, COLOR.White)
	block(parent, "MeatGlass", Vector3.new(32, 1.6, 2.6), -64, -79, Color3.fromRGB(180, 210, 220), Enum.Material.Glass, { Transparency = 0.6 }, 3)
	for i = 1, 12 do
		block(parent, "Meat", Vector3.new(1.6, 0.4, 1.2), -80 + i * 2.5 - 1, -79 + rng:NextNumber(-0.4, 0.4), Color3.fromRGB(170, 40, 45), nil, nil, 3)
	end
	local butcherSign = block(parent, "Sign", Vector3.new(16, 3, 0.4), -64, Z0 + 1.3, COLOR.Red, nil, nil, 11)
	writeOn(butcherSign, Enum.NormalId.Back, "AÇOUGUE", COLOR.White)

	-- tabela de preços das carnes na parede e etiquetas na vitrine
	chalkboard(parent, Vector3.new(-64, 7.5, Z0 + 1.15), Vector3.zAxis, Vector2.new(18, 3), "PICANHA R$ 69,90/kg     ALCATRA R$ 44,90/kg\nFRANGO R$ 15,90/kg     LINGUIÇA R$ 22,90/kg")
	for x = -78, -50, 4 do
		priceTag(parent, Vector3.new(x, 2, -77.45), Vector3.zAxis, `{randomPrice()}/kg`, 1.4)
	end

	-- confeitaria: vitrine de bolos
	block(parent, "CakeCounter", Vector3.new(6, 2.6, 2.5), -74, -52, COLOR.White)
	block(parent, "CakeGlass", Vector3.new(6, 1.6, 2.5), -74, -52, Color3.fromRGB(190, 215, 225), Enum.Material.Glass, { Transparency = 0.6 }, 2.6)
	for index, color in { Color3.fromRGB(90, 50, 30), Color3.fromRGB(240, 150, 170), Color3.fromRGB(245, 240, 225) } do
		box(parent, "Cake", Vector3.new(0.8, 1.4, 1.4), CFrame.new(-76 + (index - 1) * 2, 3, -52) * CFrame.Angles(0, 0, math.rad(90)), color, nil, { Shape = Enum.PartType.Cylinder })
	end
	priceTag(parent, Vector3.new(-74, 1.8, -50.73), Vector3.zAxis, "BOLO R$ 25,00", 2.2)

	for _, x in { -88, -82, -76, -52, -46, -40 } do
		carcass(parent, x, -68)
	end

	-- padaria
	oven(parent, X0 + 3, -58, Vector3.xAxis)
	oven(parent, X0 + 3, -46, Vector3.xAxis)
	local bakerySign = box(parent, "Sign", Vector3.new(0.4, 3, 14), CFrame.new(X0 + 1.3, 12.5, -52), Color3.fromRGB(150, 90, 40))
	writeOn(bakerySign, Enum.NormalId.Right, "PADARIA", COLOR.White)
	shelving(parent, -80, -36, 14, true, { -1, 1 }, BREADS, { "Bag", "Box" })
	chalkboard(parent, Vector3.new(-80, 8.4, -36), Vector3.zAxis, Vector2.new(6, 1.2), "PÃO FRANCÊS R$ 14,90/kg", true)

	wallBuy(parent, "Rifle", -44, Z1 - 1, -Vector3.zAxis)
	boxSpot(parent, -40, -79, Vector3.zAxis, "Açougue")

	lightGrid(parent, X0, Z0, X1, Z1, Color3.fromRGB(255, 225, 215), 1)
end

local function buildCamaraFria(parent: Instance)
	-- freezers encostados no fundo (com espaço no meio pra arma da parede)
	shelving(parent, -16, Z0 + 2.7, 18, true, { 1 }, FROZEN, { "Box", "Bag" })
	shelving(parent, 16, Z0 + 2.7, 18, true, { 1 }, FROZEN, { "Box", "Bag" })
	for _, x in { -16, 16 } do
		chalkboard(parent, Vector3.new(x, 9, Z0 + 1.15), Vector3.zAxis, Vector2.new(14, 2), "CONGELADOS", false, Color3.fromRGB(40, 90, 160))
	end

	-- freezer horizontal de sorvete (tampa de vidro com os potes dentro)
	local chestCenter = Vector3.new(0, 0, -50)
	block(parent, "IceCreamChest", Vector3.new(8, 1.9, 3), chestCenter.X, chestCenter.Z, COLOR.White)
	for _, info in { { Vector3.new(8, 0.7, 0.2), Vector3.new(0, 0, 1.4) }, { Vector3.new(8, 0.7, 0.2), Vector3.new(0, 0, -1.4) }, { Vector3.new(0.2, 0.7, 3), Vector3.new(3.9, 0, 0) }, { Vector3.new(0.2, 0.7, 3), Vector3.new(-3.9, 0, 0) } } do
		block(parent, "ChestRim", info[1], chestCenter.X + info[2].X, chestCenter.Z + info[2].Z, COLOR.White, nil, nil, 1.9)
	end
	for index = 0, 9 do
		local tubX, tubZ = -3 + (index % 5) * 1.5, -50.6 + math.floor(index / 5) * 1.2
		block(parent, "IceCream", Vector3.new(1.1, 0.5, 0.9), tubX, tubZ, pick(FROZEN):Lerp(pick(FRUITS), 0.5), nil, nil, 1.9)
	end
	block(parent, "ChestLid", Vector3.new(8, 0.1, 3), chestCenter.X, chestCenter.Z, Color3.fromRGB(190, 225, 240), Enum.Material.Glass, { Transparency = 0.5 }, 2.6)
	priceTag(parent, Vector3.new(0, 1.2, -51.53), -Vector3.zAxis, "SORVETE R$ 19,90", 2.4)
	priceTag(parent, Vector3.new(0, 1.2, -48.47), Vector3.zAxis, "SORVETE R$ 19,90", 2.4)

	-- Quiosque da loja: Segunda Chance (encostado na parede do miolo)
	local chancePosition = Vector3.new(0, 0, Z1 - 2.3)
	MapKit.shopStand(parent, CFrame.lookAt(chancePosition, chancePosition - Vector3.zAxis), "SecondChance")

	for _, x in { -20, -10, 10, 20 } do
		for _, z in { -74, -64, -40 } do
			carcass(parent, x, z)
		end
	end

	-- blocos de gelo pelos cantos
	for _, info in { { -28, -33, 3 }, { -25, -33, 2 }, { 28, -80, 3 }, { 27, -33, 2.5 } } do
		block(parent, "Ice", Vector3.one * info[3], info[1], info[2], Color3.fromRGB(190, 225, 255), Enum.Material.Ice, { Transparency = 0.2 })
	end

	-- cortinas de plástico nas duas portas
	for _, x in { X1 + 1.6, X2 - 1.6 } do
		for i = 0, 11 do
			box(parent, "CurtainStrip", Vector3.new(0.05, 9.6, 0.9), CFrame.new(x, DOOR_HEIGHT / 2 + 0.2, -56 - DOOR_WIDTH / 2 + 0.5 + i), COLOR.White, Enum.Material.SmoothPlastic, {
				Transparency = 0.55,
				CanCollide = false,
				CanQuery = false,
			})
		end
	end

	hangingSign(parent, 0, -56, 18, "CÂMARA FRIA", Color3.fromRGB(40, 90, 160), COLOR.White, false)
	wallBuy(parent, "AutoShotgun", 0, Z0 + 1, Vector3.zAxis)
	boxSpot(parent, 0, -66, Vector3.zAxis, "Câmara Fria")

	lightGrid(parent, X1, Z0, X2, Z1, Color3.fromRGB(160, 200, 255), 0.8)
end

local function buildEstoque(parent: Instance)
	for _, x in { 48, 64, 80 } do
		palletRack(parent, x, -80, -62)
	end
	pallet(parent, 44, -40, false)
	pallet(parent, 52, -34, true)
	pallet(parent, 86, -44, true)
	pallet(parent, 76, -36, true)
	forklift(parent, 62, -46, math.rad(30))

	wallBuy(parent, "LMG", X3 - 1, -50, -Vector3.xAxis)

	-- o objetivo do fim do mapa: a Máquina de Upgrade, encostada na parede da Doca
	local machinePosition = Vector3.new(86, 0, Z1 - 4)
	MapKit.upgradeMachine(parent, CFrame.lookAt(machinePosition, machinePosition - Vector3.zAxis))

	boxSpot(parent, 90, -66, -Vector3.xAxis, "Estoque")

	lightGrid(parent, X2, Z0, X3, Z1, Color3.fromRGB(255, 225, 170), 0.8)
end

local function buildDoca(parent: Instance)
	truck(parent, 84, 0)
	-- portas de carga (decoração) na parede da direita
	for _, z in { -14, 14 } do
		box(parent, "LoadingDoor", Vector3.new(0.3, 12, 14), CFrame.new(X3 - 1.15, 6, z), Color3.fromRGB(100, 105, 110), Enum.Material.CorrodedMetal)
	end
	pallet(parent, 44, 14, false)
	pallet(parent, 50, -16, true)
	pallet(parent, 40, -6, true)

	wallBuy(parent, "Sniper", X2 + 1, -8, Vector3.xAxis)
	boxSpot(parent, 36, 18, Vector3.xAxis, "Doca")

	-- faixa zebrada no chão perto das portas de carga e uns cones
	for index = 0, 25 do
		local stripeColor = if index % 2 == 0 then COLOR.Yellow else COLOR.Black
		block(parent, "HazardStripe", Vector3.new(0.8, 0.05, 2), X3 - 3.5, Z1 + 1 + index * 2, stripeColor, nil, { CanCollide = false, CanQuery = false })
	end
	for _, position in { Vector2.new(78, -15), Vector2.new(77, 13), Vector2.new(89, 15), Vector2.new(74, -4) } do
		block(parent, "Cone", Vector3.new(1, 1.6, 1), position.X, position.Y, Color3.fromRGB(240, 110, 20), nil, { CanCollide = false })
		block(parent, "ConeStripe", Vector3.new(1.05, 0.25, 1.05), position.X, position.Y, COLOR.White, nil, { CanCollide = false }, 0.9)
	end

	-- placa em cima da porta do Estoque
	chalkboard(parent, Vector3.new(64, 11.5, Z1 + 1.15), Vector3.zAxis, Vector2.new(12, 1.6), "SOMENTE FUNCIONÁRIOS", false, COLOR.Red)

	-- Quiosque da loja: Munição (qualquer arma, até da caixa)
	local ammoPosition = Vector3.new(X2 + 2.3, 0, 6)
	MapKit.shopStand(parent, CFrame.lookAt(ammoPosition, ammoPosition + Vector3.xAxis), "Ammo")

	lightGrid(parent, X2, Z1, X3, Z2, Color3.fromRGB(255, 235, 200), 0.9)
end

local function buildEstacionamento(parent: Instance)
	-- vagas
	for _, x in { 66, 76, 86 } do
		block(parent, "ParkingLine", Vector3.new(0.3, 0.05, 10), x, 75, COLOR.White)
	end
	car(parent, 71, 75, 0, Color3.fromRGB(140, 40, 40), false)
	car(parent, 81, 74, 0.1, Color3.fromRGB(40, 60, 120), true)

	-- estacionamento de fora (o resto do supermercado), visto através do alambrado.
	-- As frentes das barricadas do alambrado ficam livres pros zumbis passarem.
	box(parent, "OutsideLot", Vector3.new(108, 0.9, 40), CFrame.new(86, -0.45, Z3 + 21), Color3.fromRGB(45, 45, 48), MAT.Asphalt)
	box(parent, "OutsideLot", Vector3.new(44, 0.9, 61), CFrame.new(X3 + 22, -0.45, Z2 + 26.5), Color3.fromRGB(45, 45, 48), MAT.Asphalt)
	for x = 52, 132, 10 do
		block(parent, "ParkingLine", Vector3.new(0.3, 0.05, 10), x, Z3 + 20, COLOR.White)
	end
	for z = 30, 80, 10 do
		if math.abs(z - 50) > 6 then
			block(parent, "ParkingLine", Vector3.new(10, 0.05, 0.3), X3 + 22, z, COLOR.White)
		end
	end
	for _, info in {
		{ 57, Z3 + 20, 0, Color3.fromRGB(200, 200, 195) },
		{ 87, Z3 + 21, 0.05, Color3.fromRGB(30, 30, 35) },
		{ 117, Z3 + 20, -0.04, Color3.fromRGB(150, 30, 30) },
		{ X3 + 22, 35, math.rad(90), Color3.fromRGB(40, 110, 60) },
		{ X3 + 22, 65, math.rad(90), Color3.fromRGB(220, 180, 40) },
	} do
		car(parent, info[1], info[2], info[3], info[4], false)
	end
	lampPost(parent, 100, Z3 + 32)
	lampPost(parent, X3 + 34, 50)

	lampPost(parent, 48, 72)
	lampPost(parent, 90, 40)

	-- portão de entrada do estacionamento (fechado)
	box(parent, "Gate", Vector3.new(12, 10, 0.4), CFrame.new(56, 5, Z3 - 1.3), COLOR.DarkMetal, Enum.Material.DiamondPlate)

	-- letreiro da loja na parede de fora
	local storeSign = box(parent, "StoreSign", Vector3.new(0.6, 4, 34), CFrame.new(X2 + 1.4, 15.5, 66), COLOR.SignGreen)
	writeOn(storeSign, Enum.NormalId.Right, STORE_NAME, COLOR.Yellow)

	wallBuy(parent, "Revolver", X2 + 1, 40, Vector3.xAxis)
	boxSpot(parent, 62, 50, -Vector3.xAxis, "Estacionamento")

	-- caçamba de lixo e placa de vaga
	block(parent, "Dumpster", Vector3.new(6, 3.6, 4), 90, 66, Color3.fromRGB(40, 90, 50), Enum.Material.Metal)
	box(parent, "DumpsterLid", Vector3.new(6.2, 0.2, 4.2), CFrame.new(90, 3.8, 66) * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	block(parent, "SignPole", Vector3.new(0.2, 5, 0.2), 61, 80, COLOR.Metal, Enum.Material.Metal)
	chalkboard(parent, Vector3.new(61, 5.6, 80), -Vector3.zAxis, Vector2.new(2.4, 1.8), "VAGA\nIDOSO", true, Color3.fromRGB(30, 80, 170))

	-- Quiosque da loja: Mão Rápida (encostado na parede da Doca)
	local fastPosition = Vector3.new(82, 0, Z2 + 2.3)
	MapKit.shopStand(parent, CFrame.lookAt(fastPosition, fastPosition + Vector3.zAxis), "FastHands")
end

-- Chão de fora e um morro com luzinhas de casas ao longe (vista do estacionamento)
local function buildOutside(parent: Instance)
	box(parent, "Ground", Vector3.new(900, 1, 900), CFrame.new(0, -0.7, 0), Color3.fromRGB(28, 36, 26), Enum.Material.Grass)

	local steps = {
		{ size = Vector3.new(60, 40, 260), center = Vector3.new(230, 20, 20) },
		{ size = Vector3.new(60, 70, 200), center = Vector3.new(270, 35, 30) },
		{ size = Vector3.new(60, 100, 130), center = Vector3.new(310, 50, 40) },
	}
	for _, step in steps do
		box(parent, "Morro", step.size, CFrame.new(step.center), Color3.fromRGB(18, 24, 20), Enum.Material.Grass, { CastShadow = false })
		local faceX = step.center.X - step.size.X / 2 - 0.3
		for _ = 1, 24 do
			local y = rng:NextNumber(math.max(22, step.center.Y - step.size.Y / 2 + 4), step.center.Y + step.size.Y / 2 - 2)
			local z = rng:NextNumber(step.center.Z - step.size.Z / 2 + 5, step.center.Z + step.size.Z / 2 - 5)
			local color = if rng:NextNumber() < 0.7 then Color3.fromRGB(255, 200, 110) else Color3.fromRGB(200, 220, 255)
			box(parent, "HouseLight", Vector3.new(0.4, 1, 1.4), CFrame.new(faceX, y, z), color, Enum.Material.Neon, { CanCollide = false, CastShadow = false })
		end
	end
end

return function(): Model
	local map = Instance.new("Model")
	map.Name = "Supermercado"

	buildStructure(folder(map, "Estrutura"))
	buildEntrada(folder(map, "Entrada"))
	buildHortifruti(folder(map, "Hortifruti"))
	buildAcougue(folder(map, "Acougue"))
	buildCamaraFria(folder(map, "CamaraFria"))
	buildEstoque(folder(map, "Estoque"))
	buildDoca(folder(map, "Doca"))
	buildEstacionamento(folder(map, "Estacionamento"))
	buildBarricades(folder(map, "Barricadas"))
	buildOutside(folder(map, "Fora"))

	return map
end
