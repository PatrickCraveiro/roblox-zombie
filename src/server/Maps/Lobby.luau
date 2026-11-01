-- Lobby: praça onde os jogadores nascem, com a fachada de cada fase (parou na porta, vai pro
-- jogo) e o prédio do Treinamento (todas as armas de graça + zumbis de treino), onde se entra
-- andando. Montado em volta da origem; o MapService move pro lugar dele no mundo.
--
-- Tags usadas:
--   MapPortal      - região da porta da fase (atributo MapId); o modelo tem a placa "PortalSign"
--                    (LobbyService)
--   AutoDoor       - folhas das portas automáticas (AutoDoorService)
--   DummySpot      - lugar de um zumbi de treino (atributo Round = vida igual à dessa rodada)
--   UpgradeMachine - Máquina de Upgrade grátis do Treinamento (ver MapKit.upgradeMachine)
--   LobbySpawn     - onde os jogadores nascem

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local MapKit = require(script.Parent.MapKit)

local box = MapKit.box
local block = MapKit.block
local folder = MapKit.folder
local writeOn = MapKit.writeOn
local tag = MapKit.tag
local MAT = MapKit.MAT

export type MapInfo = {
	id: string,
	name: string,
	description: string,
	facade: string?, -- "Store" (supermercado) ou "Stadium"
	lobbyX: number?, -- onde a fachada fica na praça
}

-- Limites da praça
local MIN_X, MAX_X = -150, 190
local MIN_Z, MAX_Z = -100, 90

-- Fachadas das fases (lado de cima da praça)
local STORE_FRONT_Z = -62

-- Treinamento (lado esquerdo da praça)
local RANGE_MIN_X, RANGE_MAX_X = -150, -50
local RANGE_MIN_Z, RANGE_MAX_Z = -30, 60
local FIRING_LINE_X = -60

local COLOR = {
	Pavement = Color3.fromRGB(120, 118, 112),
	Hedge = Color3.fromRGB(35, 70, 35),
	Concrete = Color3.fromRGB(150, 150, 145),
	DarkMetal = Color3.fromRGB(40, 40, 45),
	White = Color3.fromRGB(240, 240, 240),
	Yellow = Color3.fromRGB(255, 215, 40),
	Wood = Color3.fromRGB(120, 85, 50),
	Leaves = Color3.fromRGB(45, 95, 45),
	StoreWall = Color3.fromRGB(235, 228, 210),
	StoreGreen = Color3.fromRGB(20, 110, 50),
	Glass = Color3.fromRGB(120, 170, 190),
	Window = Color3.fromRGB(40, 60, 75),
	Red = Color3.fromRGB(200, 25, 25),
}

local PRODUCT_COLORS = {
	Color3.fromRGB(210, 40, 40),
	Color3.fromRGB(240, 200, 40),
	Color3.fromRGB(40, 90, 200),
	Color3.fromRGB(50, 160, 70),
	Color3.fromRGB(240, 130, 30),
	Color3.fromRGB(235, 235, 235),
}

local ROTATE_UP = CFrame.Angles(0, 0, math.rad(90)) -- deixa um cilindro em pé

local function lampPost(parent: Instance, x: number, z: number)
	block(parent, "LampPost", Vector3.new(0.6, 14, 0.6), x, z, COLOR.DarkMetal, Enum.Material.Metal)
	local head = block(parent, "LampHead", Vector3.new(1.6, 1, 1.6), x, z, Color3.fromRGB(255, 210, 150), Enum.Material.Neon, nil, 14)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 140)
	light.Range = 45
	light.Brightness = 1.4
	light.Parent = head
end

local function bench(parent: Instance, x: number, z: number, yaw: number)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	box(parent, "BenchSeat", Vector3.new(6, 0.4, 2), base * CFrame.new(0, 1.6, 0), COLOR.Wood, Enum.Material.WoodPlanks)
	box(parent, "BenchBack", Vector3.new(6, 1.6, 0.3), base * CFrame.new(0, 2.6, 0.9), COLOR.Wood, Enum.Material.WoodPlanks)
	for _, dx in { -2.6, 2.6 } do
		box(parent, "BenchLeg", Vector3.new(0.3, 1.4, 1.8), base * CFrame.new(dx, 0.7, 0), COLOR.DarkMetal, Enum.Material.Metal)
	end
end

local function tree(parent: Instance, x: number, z: number, height: number)
	box(parent, "Trunk", Vector3.new(height, 1.2, 1.2), CFrame.new(x, height / 2, z) * ROTATE_UP, Color3.fromRGB(80, 55, 35), Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
	box(parent, "Leaves", Vector3.one * 9, CFrame.new(x, height + 2, z), COLOR.Leaves, Enum.Material.Grass, { Shape = Enum.PartType.Ball })
	box(parent, "Leaves", Vector3.one * 6, CFrame.new(x + 2.5, height - 0.5, z + 1.5), COLOR.Leaves, Enum.Material.Grass, { Shape = Enum.PartType.Ball })
end

-- Placa da fase: nome, descrição e uma linha de status (o LobbyService atualiza)
local function portalSign(sign: BasePart, face: Enum.NormalId, map: MapInfo)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.Parent = sign

	local function line(name: string, y: number, height: number, text: string, color: Color3, font: Enum.Font)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Position = UDim2.fromScale(0.05, y)
		label.Size = UDim2.fromScale(0.9, height)
		label.BackgroundTransparency = 1
		label.Font = font
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		label.Parent = gui
	end
	line("Title", 0.05, 0.35, string.upper(map.name), COLOR.White, Enum.Font.GothamBlack)
	line("Description", 0.42, 0.18, map.description, Color3.fromRGB(200, 200, 200), Enum.Font.GothamMedium)
	line("Status", 0.65, 0.28, "Pare na porta pra jogar", COLOR.Yellow, Enum.Font.GothamBold)
end

-- Fachada de supermercado com porta de vidro automática. A porta (tapete + entrada) é o
-- "portal" da fase: quem parar ali entra na contagem e vai pro jogo.
local function storefront(parent: Instance, map: MapInfo, x: number, frontZ: number)
	local model = Instance.new("Model")
	model.Name = "Portal_" .. map.id
	model.Parent = parent

	local width, height, depth = 64, 18, 36
	local doorWidth, doorHeight, vestibule = 12, 10, 8
	local sideWidth = (width - doorWidth) / 2
	local innerZ = frontZ - vestibule -- fundo da entrada
	local backZ = frontZ - depth

	-- prédio: bloco de trás + frente com o vão da entrada
	box(model, "Building", Vector3.new(width, height, innerZ - backZ), CFrame.new(x, height / 2, (innerZ + backZ) / 2), COLOR.StoreWall, MAT.Plaster)
	for _, side in { -1, 1 } do
		local sideX = x + side * (doorWidth + sideWidth) / 2
		box(model, "Facade", Vector3.new(sideWidth, height, vestibule), CFrame.new(sideX, height / 2, frontZ - vestibule / 2), COLOR.StoreWall, MAT.Plaster)
		box(model, "BaseStripe", Vector3.new(sideWidth, 1.5, 0.3), CFrame.new(sideX, 0.75, frontZ + 0.15), COLOR.StoreGreen)

		-- vitrine com cartazes de oferta
		box(model, "ShopWindow", Vector3.new(sideWidth - 6, 7, 0.2), CFrame.new(sideX, 5.5, frontZ + 0.1), COLOR.Window, Enum.Material.Glass, { Reflectance = 0.15 })
		for index, text in { "OFERTA!", "PROMOÇÃO" } do
			local poster = box(model, "Poster", Vector3.new(4.5, 3, 0.1), CFrame.new(sideX + (index * 2 - 3) * 5, 6, frontZ + 0.25), COLOR.Yellow)
			writeOn(poster, Enum.NormalId.Back, text, COLOR.Red)
		end
	end
	box(model, "Facade", Vector3.new(doorWidth, height - doorHeight, vestibule), CFrame.new(x, (height + doorHeight) / 2, frontZ - vestibule / 2), COLOR.StoreWall, MAT.Plaster)
	box(model, "TopStripe", Vector3.new(width + 0.4, 1.2, 0.4), CFrame.new(x, height - 0.6, frontZ + 0.2), COLOR.StoreGreen)

	-- letreiro e toldo
	local sign = box(model, "StoreSign", Vector3.new(44, 4.5, 0.6), CFrame.new(x, 14.25, frontZ + 0.3), COLOR.StoreGreen)
	writeOn(sign, Enum.NormalId.Back, string.upper(map.name), COLOR.Yellow)
	box(model, "Awning", Vector3.new(doorWidth + 8, 0.6, 6), CFrame.new(x, doorHeight + 0.8, frontZ + 3), COLOR.StoreGreen)
	box(model, "AwningEdge", Vector3.new(doorWidth + 8, 0.9, 0.3), CFrame.new(x, doorHeight + 0.8, frontZ + 6), COLOR.Yellow)

	-- moldura e porta de vidro de correr (abre sozinha quando alguém chega perto)
	box(model, "DoorFrame", Vector3.new(doorWidth + 1, 0.5, 0.6), CFrame.new(x, doorHeight - 0.05, frontZ), COLOR.DarkMetal, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		box(model, "DoorFrame", Vector3.new(0.5, doorHeight, 0.6), CFrame.new(x + side * (doorWidth / 2 + 0.25), doorHeight / 2, frontZ), COLOR.DarkMetal, Enum.Material.Metal)
		local panel = box(model, "GlassDoor", Vector3.new(doorWidth / 2, doorHeight - 0.3, 0.3), CFrame.new(x + side * doorWidth / 4, (doorHeight - 0.3) / 2, frontZ - 0.5), COLOR.Glass, Enum.Material.Glass, {
			Transparency = 0.45,
		})
		panel:SetAttribute("OpenOffset", Vector3.new(side * (doorWidth / 2 - 0.4), 0, 0))
		panel:SetAttribute("SensorRadius", 11)
		tag(panel, "AutoDoor")
	end

	-- entrada: piso, luz e uma prateleira lá no fundo (dá pra ver quando a porta abre)
	box(model, "EntranceFloor", Vector3.new(doorWidth, 0.1, vestibule), CFrame.new(x, 0.05, frontZ - vestibule / 2), Color3.fromRGB(215, 215, 210), MAT.Tiles)
	local ceilingLight = box(model, "EntranceLight", Vector3.new(4, 0.2, 2), CFrame.new(x, doorHeight - 0.15, frontZ - vestibule / 2), COLOR.White, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 16
	light.Brightness = 2
	light.Parent = ceilingLight
	local shelfZ = innerZ + 1
	box(model, "Shelf", Vector3.new(doorWidth - 1, 7, 2), CFrame.new(x, 3.5, shelfZ), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
	for row = 0, 2 do
		for column = 0, 4 do
			local color = PRODUCT_COLORS[(row * 5 + column) % #PRODUCT_COLORS + 1]
			box(model, "Product", Vector3.new(1.6, 1.4, 0.8), CFrame.new(x - 4 + column * 2, 1.3 + row * 2.2, shelfZ + 1.1), color)
		end
	end

	-- tapete na frente da porta
	local mat = box(model, "DoorMat", Vector3.new(doorWidth, 0.12, 6), CFrame.new(x, 0.06, frontZ + 3.5), Color3.fromRGB(45, 45, 48), MAT.Rubber)
	writeOn(mat, Enum.NormalId.Top, "PARE AQUI PRA JOGAR", COLOR.Yellow)

	-- região da porta (tapete + entrada): quem estiver aqui dentro entra na contagem
	local zoneStart, zoneEnd = innerZ, frontZ + 7
	local pad = box(model, "Pad", Vector3.new(doorWidth, 8, zoneEnd - zoneStart), CFrame.new(x, 4, (zoneStart + zoneEnd) / 2), COLOR.Yellow, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	pad:SetAttribute("MapId", map.id)
	tag(pad, "MapPortal")

	-- totem ao lado da porta com o status (contagem, partida rolando...)
	local totemX, totemZ = x + doorWidth / 2 + 10, frontZ + 10
	block(model, "TotemPost", Vector3.new(0.6, 3, 0.6), totemX, totemZ, COLOR.DarkMetal, Enum.Material.Metal)
	local totem = block(model, "PortalSign", Vector3.new(10, 6, 0.5), totemX, totemZ, Color3.fromRGB(20, 20, 24), nil, nil, 3)
	portalSign(totem, Enum.NormalId.Back, map)
	portalSign(totem, Enum.NormalId.Front, map)

	-- carrinhos largados do lado de fora
	local cartX = x - doorWidth / 2 - 6
	MapKit.cart(model, cartX, frontZ + 6, 0.2)
	MapKit.cart(model, cartX - 3.2, frontZ + 6.4, 0.1)
	MapKit.cart(model, cartX - 9, frontZ + 9, -0.6)
end

-- Fachada de estádio: o portão de grade abre sozinho quando alguém chega e o tapete na frente
-- dele é a porta da fase (igual à do supermercado)
local function stadiumFacade(parent: Instance, map: MapInfo, x: number, frontZ: number)
	local model = Instance.new("Model")
	model.Name = "Portal_" .. map.id
	model.Parent = parent
	local width, height, depth = 76, 22, 36
	local green, yellow = Color3.fromRGB(0, 140, 60), Color3.fromRGB(255, 210, 0)
	local dark = Color3.fromRGB(35, 35, 40)

	box(model, "StadiumWall", Vector3.new(width, height, depth), CFrame.new(x, height / 2, frontZ - depth / 2), Color3.fromRGB(205, 205, 200), Enum.Material.Concrete)
	box(model, "GreenBand", Vector3.new(width + 0.4, 2, 0.3), CFrame.new(x, height - 3, frontZ + 0.15), green)
	box(model, "YellowBand", Vector3.new(width + 0.4, 1, 0.3), CFrame.new(x, height - 1.5, frontZ + 0.15), yellow)

	-- arcos escuros na fachada (o meio fica pro portão)
	for index = 0, 7 do
		local archX = x - width / 2 + 6 + index * (width - 12) / 7
		if math.abs(archX - x) > 9 then
			box(model, "Arch", Vector3.new(5, 8, 0.2), CFrame.new(archX, 5, frontZ + 0.1), dark)
			box(model, "ArchTop", Vector3.new(0.2, 5, 5), CFrame.new(archX, 9, frontZ + 0.1) * CFrame.Angles(0, math.rad(90), 0), dark, nil, { Shape = Enum.PartType.Cylinder })
		end
	end

	-- letreiro e portão de grade (duas folhas que correm pros lados)
	local sign = box(model, "StadiumSign", Vector3.new(40, 4.5, 0.6), CFrame.new(x, 14, frontZ + 0.3), dark)
	writeOn(sign, Enum.NormalId.Back, string.upper(map.name), yellow)
	box(model, "Gate", Vector3.new(14, 10, 0.2), CFrame.new(x, 5, frontZ + 0.1), Color3.fromRGB(15, 15, 18))
	for _, side in { -1, 1 } do
		local leaf = box(model, "GateLeaf", Vector3.new(7, 10, 0.3), CFrame.new(x + side * 3.5, 5, frontZ + 0.4), Color3.fromRGB(90, 95, 100), Enum.Material.DiamondPlate, { Transparency = 0.3 })
		leaf:SetAttribute("OpenOffset", Vector3.new(side * 6.6, 0, 0))
		leaf:SetAttribute("SensorRadius", 12)
		tag(leaf, "AutoDoor")
	end

	-- tapete, região da porta (quem para ali entra na contagem) e o totem com o status
	local mat = box(model, "DoorMat", Vector3.new(14, 0.12, 7), CFrame.new(x, 0.06, frontZ + 4), dark, MAT.Rubber)
	writeOn(mat, Enum.NormalId.Top, "PARE AQUI PRA JOGAR", yellow)
	local pad = box(model, "Pad", Vector3.new(14, 8, 9), CFrame.new(x, 4, frontZ + 4.5), yellow, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	pad:SetAttribute("MapId", map.id)
	tag(pad, "MapPortal")
	local totemX, totemZ = x + 18, frontZ + 12
	block(model, "TotemPost", Vector3.new(0.6, 3, 0.6), totemX, totemZ, dark, Enum.Material.Metal)
	local totem = block(model, "PortalSign", Vector3.new(10, 6, 0.5), totemX, totemZ, Color3.fromRGB(20, 20, 24), nil, nil, 3)
	portalSign(totem, Enum.NormalId.Back, map)
	portalSign(totem, Enum.NormalId.Front, map)

	-- bola gigante em cima da fachada
	local ballCenter = Vector3.new(x, height + 3.2, frontZ - 4)
	box(model, "Ball", Vector3.one * 6.5, CFrame.new(ballCenter), COLOR.White, nil, { Shape = Enum.PartType.Ball })
	for _, direction in { Vector3.new(0, 0, 1), Vector3.new(0.8, 0.3, 0.5), Vector3.new(-0.8, 0.3, 0.5), Vector3.new(0, 1, 0), Vector3.new(0.5, 0.6, -0.6), Vector3.new(-0.5, 0.6, -0.6) } do
		box(model, "BallPatch", Vector3.one * 1.9, CFrame.new(ballCenter + direction.Unit * 2.55), Color3.fromRGB(20, 20, 20), nil, { Shape = Enum.PartType.Ball })
	end

	-- refletores nos cantos (dá pra ver de longe)
	for _, side in { -1, 1 } do
		local poleX, poleZ = x + side * (width / 2 + 4), frontZ - 4
		block(model, "FloodlightPole", Vector3.new(1.2, 46, 1.2), poleX, poleZ, dark, Enum.Material.Metal)
		local lights = box(model, "Floodlights", Vector3.new(8, 4, 1), CFrame.new(poleX, 47, poleZ) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(240, 245, 255), Enum.Material.Neon)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Back
		spot.Angle = 70
		spot.Range = 60
		spot.Brightness = 2
		spot.Parent = lights
	end

	-- bilheteria e bandeiras
	local boothX = x - width / 2 + 10
	block(model, "TicketBooth", Vector3.new(6, 5, 4), boothX, frontZ + 6, green)
	local boothSign = block(model, "BoothSign", Vector3.new(6.4, 1.2, 0.3), boothX, frontZ + 8.15, yellow, nil, nil, 5.2)
	writeOn(boothSign, Enum.NormalId.Back, "BILHETERIA", green)
	block(model, "BoothWindow", Vector3.new(3, 1.6, 0.1), boothX, frontZ + 8.05, Color3.fromRGB(40, 60, 75), Enum.Material.Glass, nil, 2.2)
	for _, side in { -1, 1 } do
		local flagX = x + side * 11
		block(model, "FlagPole", Vector3.new(0.3, 14, 0.3), flagX, frontZ + 4, COLOR.White, Enum.Material.Metal)
		block(model, "Flag", Vector3.new(4, 2.6, 0.1), flagX + side * 2.1, frontZ + 4, if side < 0 then green else yellow, nil, { CanCollide = false }, 10.8)
	end
end

-- Quadro do ranking (o RankingService preenche as listas "List_<Best|Total>_<stat>" e o "Status")
local function rankingBoard(parent: Instance, position: Vector3, facing: Vector3)
	local width, height = 34, 15
	local base = CFrame.lookAt(position, position + facing)
	for _, x in { -width / 2 + 1, width / 2 - 1 } do
		box(parent, "RankingPost", Vector3.new(0.8, height + 2, 0.8), base * CFrame.new(x, (height + 2) / 2, 0.6), COLOR.DarkMetal, Enum.Material.Metal)
	end
	local board = box(parent, "RankingBoard", Vector3.new(width, height, 0.6), base * CFrame.new(0, 2 + height / 2, 0), Color3.fromRGB(18, 22, 30))
	tag(board, "RankingBoard")
	box(parent, "RankingFrame", Vector3.new(width + 0.6, 0.6, 0.8), base * CFrame.new(0, 2 + height + 0.3, 0), COLOR.Yellow, Enum.Material.Neon)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	local function label(name: string, x: number, y: number, w: number, h: number, text: string, color: Color3, font: Enum.Font, alignLeft: boolean?)
		local textLabel = Instance.new("TextLabel")
		textLabel.Name = name
		textLabel.Position = UDim2.fromScale(x, y)
		textLabel.Size = UDim2.fromScale(w, h)
		textLabel.BackgroundTransparency = 1
		textLabel.TextScaled = true
		textLabel.RichText = true
		textLabel.Font = font
		textLabel.TextColor3 = color
		textLabel.Text = text
		textLabel.TextXAlignment = if alignLeft then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
		textLabel.TextYAlignment = if alignLeft then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center
		textLabel.Parent = gui
	end

	label("Title", 0.02, 0.02, 0.96, 0.11, "RANKING DOS SOBREVIVENTES", COLOR.Yellow, Enum.Font.GothamBlack)
	local columns = { { "Kills", "ABATES" }, { "Headshots", "HEADSHOTS" }, { "Points", "PONTOS" } }
	for sectionIndex, section in { { "Best", "RECORDE EM UMA PARTIDA" }, { "Total", "TOTAL GERAL" } } do
		local sectionX = 0.02 + (sectionIndex - 1) * 0.5
		label("Section", sectionX, 0.15, 0.46, 0.08, section[2], if sectionIndex == 1 then Color3.fromRGB(255, 120, 90) else Color3.fromRGB(110, 200, 255), Enum.Font.GothamBlack)
		for columnIndex, column in columns do
			local columnX = sectionX + (columnIndex - 1) * (0.46 / 3)
			label("Header", columnX, 0.25, 0.46 / 3, 0.06, column[2], COLOR.White, Enum.Font.GothamBold)
			label(`List_{section[1]}_{column[1]}`, columnX + 0.005, 0.33, 0.46 / 3 - 0.01, 0.56, "carregando...", Color3.fromRGB(220, 220, 220), Enum.Font.GothamMedium, true)
		end
	end
	label("Status", 0.02, 0.91, 0.96, 0.06, "carregando o ranking...", Color3.fromRGB(150, 150, 160), Enum.Font.Gotham)

	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1
	light.Parent = board
end

local function buildPlaza(parent: Instance, maps: { MapInfo })
	local width, depth = MAX_X - MIN_X, MAX_Z - MIN_Z
	local centerX, centerZ = (MIN_X + MAX_X) / 2, (MIN_Z + MAX_Z) / 2
	box(parent, "Ground", Vector3.new(600, 1, 600), CFrame.new(centerX, -0.7, centerZ), Color3.fromRGB(30, 45, 30), Enum.Material.Grass)
	box(parent, "Plaza", Vector3.new(width, 1, depth), CFrame.new(centerX, -0.5, centerZ), COLOR.Pavement, MAT.Asphalt)

	-- cerca viva em volta
	for _, info in {
		{ Vector3.new(width + 3, 6, 3), Vector3.new(centerX, 3, MIN_Z - 1.5) },
		{ Vector3.new(width + 3, 6, 3), Vector3.new(centerX, 3, MAX_Z + 1.5) },
		{ Vector3.new(3, 6, depth + 3), Vector3.new(MIN_X - 1.5, 3, centerZ) },
		{ Vector3.new(3, 6, depth + 3), Vector3.new(MAX_X + 1.5, 3, centerZ) },
	} do
		box(parent, "Hedge", info[1], CFrame.new(info[2]), COLOR.Hedge, Enum.Material.Grass)
	end

	-- onde os jogadores nascem (olhando pro supermercado)
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "LobbySpawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(10, 0.4, 10)
	spawnLocation.CFrame = CFrame.new(30, 0.2, 55)
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Color = Color3.fromRGB(200, 200, 210)
	spawnLocation.Transparency = 0.5
	spawnLocation.Duration = 0
	spawnLocation.Neutral = true
	spawnLocation.Parent = parent
	tag(spawnLocation, "LobbySpawn")
	for _, decal in spawnLocation:GetChildren() do
		decal:Destroy()
	end

	-- uma fachada por fase, cada uma no seu lugar da praça
	for index, map in maps do
		local x = map.lobbyX or (30 + (index - 1) * 110)
		if map.facade == "Stadium" then
			stadiumFacade(parent, map, x, STORE_FRONT_Z)
		else
			storefront(parent, map, x, STORE_FRONT_Z)
		end
	end

	-- quadro do ranking, à direita de quem nasce (fora dos caminhos), virado pro spawn
	local rankingPosition = Vector3.new(78, 0, 52)
	rankingBoard(parent, rankingPosition, (Vector3.new(30, 0, 55) - rankingPosition).Unit)

	-- placa de boas-vindas ao lado do spawn
	local welcomePosition = Vector3.new(-10, 4, 48)
	local welcome = box(parent, "WelcomeBoard", Vector3.new(14, 7, 0.4), CFrame.lookAt(welcomePosition, Vector3.new(30, 4, 55)), Color3.fromRGB(25, 25, 30))
	writeOn(welcome, Enum.NormalId.Front, "PRA JOGAR: pare na porta de uma fase\n(Supermercado ou Estádio)\n\nTREINAMENTO (prédio à esquerda):\nteste todas as armas nos zumbis de treino", COLOR.White)
	block(parent, "WelcomePost", Vector3.new(0.5, 1, 0.5), welcomePosition.X, welcomePosition.Z, COLOR.DarkMetal)

	for _, position in { Vector2.new(85, 60), Vector2.new(85, -30), Vector2.new(-25, -70), Vector2.new(-25, 70), Vector2.new(30, 80), Vector2.new(90, -85) } do
		lampPost(parent, position.X, position.Y)
	end
	bench(parent, 70, 75, 0)
	bench(parent, 100, 20, math.rad(90))
	bench(parent, 100, -10, math.rad(90))
	bench(parent, -10, 80, 0)
	for _, info in { { -30, 85, 14 }, { 105, 82, 16 }, { 175, 82, 15 }, { -40, -92, 13 }, { 78, -92, 14 } } do
		tree(parent, info[1], info[2], info[3])
	end
end

-- Placa grande escrita só de um lado
local function wallSign(parent: Instance, text: string, cframe: CFrame, width: number, color: Color3)
	local sign = box(parent, "Sign", Vector3.new(width, 2.5, 0.3), cframe, Color3.fromRGB(25, 25, 30))
	writeOn(sign, Enum.NormalId.Front, text, color)
end

-- ===== Treinamento: estande de tiro fechado, com porta automática virada pra praça =====

local TRAINING_HEIGHT = 14
local TRAINING_DOOR_WIDTH, TRAINING_DOOR_HEIGHT = 12, 10
local LANES = { -12, 6, 24, 42 } -- centro (z) de cada pista; um zumbi de treino no fim de cada uma
local LANE_ROUNDS = { 1, 5, 10, 20 } -- o zumbi de cada pista tem a vida dos zumbis dessa rodada
local LANE_WIDTH = 18
local DUMMY_X = -125

local RANGE_CENTER_X = (RANGE_MIN_X + RANGE_MAX_X) / 2
local RANGE_CENTER_Z = (RANGE_MIN_Z + RANGE_MAX_Z) / 2
local RANGE_LENGTH = RANGE_MAX_X - RANGE_MIN_X
local RANGE_WIDTH = RANGE_MAX_Z - RANGE_MIN_Z

-- Piso, paredes, teto, a frente com a porta automática e os acabamentos de dentro
local function trainingStructure(parent: Instance)
	local height = TRAINING_HEIGHT
	local centerZ = RANGE_CENTER_Z

	-- piso: concreto no estande, emborrachado azul na área de quem atira
	local rangeLength = FIRING_LINE_X - RANGE_MIN_X
	box(parent, "RangeFloor", Vector3.new(rangeLength, 0.1, RANGE_WIDTH), CFrame.new(RANGE_MIN_X + rangeLength / 2, 0.05, centerZ), Color3.fromRGB(80, 80, 82), Enum.Material.Concrete)
	local playerLength = RANGE_MAX_X - FIRING_LINE_X
	box(parent, "PlayerFloor", Vector3.new(playerLength, 0.1, RANGE_WIDTH), CFrame.new(FIRING_LINE_X + playerLength / 2, 0.1, centerZ), Color3.fromRGB(45, 60, 90), MAT.Rubber)

	-- paredes, fundo e teto
	box(parent, "RangeWall", Vector3.new(RANGE_LENGTH, height, 2), CFrame.new(RANGE_CENTER_X, height / 2, RANGE_MIN_Z - 1), COLOR.Concrete, Enum.Material.Concrete)
	box(parent, "RangeWall", Vector3.new(RANGE_LENGTH, height, 2), CFrame.new(RANGE_CENTER_X, height / 2, RANGE_MAX_Z + 1), COLOR.Concrete, Enum.Material.Concrete)
	box(parent, "Backstop", Vector3.new(2, height, RANGE_WIDTH + 4), CFrame.new(RANGE_MIN_X - 1, height / 2, centerZ), Color3.fromRGB(70, 55, 40), Enum.Material.WoodPlanks)
	box(parent, "Roof", Vector3.new(RANGE_LENGTH + 4, 1, RANGE_WIDTH + 4), CFrame.new(RANGE_CENTER_X, height + 0.5, centerZ), Color3.fromRGB(60, 60, 65), Enum.Material.Metal)

	-- frente com a porta de correr (abre sozinha quando alguém chega perto, de dentro ou de fora)
	local doorWidth, doorHeight = TRAINING_DOOR_WIDTH, TRAINING_DOOR_HEIGHT
	local wallX = RANGE_MAX_X + 1
	local wallStart, wallEnd = RANGE_MIN_Z - 2, RANGE_MAX_Z + 2
	local doorStart, doorEnd = centerZ - doorWidth / 2, centerZ + doorWidth / 2
	box(parent, "FrontWall", Vector3.new(2, height, doorStart - wallStart), CFrame.new(wallX, height / 2, (wallStart + doorStart) / 2), COLOR.Concrete, Enum.Material.Concrete)
	box(parent, "FrontWall", Vector3.new(2, height, wallEnd - doorEnd), CFrame.new(wallX, height / 2, (doorEnd + wallEnd) / 2), COLOR.Concrete, Enum.Material.Concrete)
	box(parent, "FrontWall", Vector3.new(2, height - doorHeight, doorWidth), CFrame.new(wallX, (height + doorHeight) / 2, centerZ), COLOR.Concrete, Enum.Material.Concrete)
	for _, side in { -1, 1 } do
		local panel = box(parent, "TrainingDoor", Vector3.new(0.6, doorHeight, doorWidth / 2), CFrame.new(wallX, doorHeight / 2, centerZ + side * doorWidth / 4), Color3.fromRGB(70, 90, 110), Enum.Material.DiamondPlate)
		panel:SetAttribute("OpenOffset", Vector3.new(0, 0, side * (doorWidth / 2 - 0.4)))
		panel:SetAttribute("SensorRadius", 12)
		tag(panel, "AutoDoor")
	end

	-- paredes de dentro: faixa escura embaixo e painéis acústicos em cima
	for _, info in { { RANGE_MIN_Z, 1 }, { RANGE_MAX_Z, -1 } } do
		local wallZ, inward = info[1], info[2]
		box(parent, "Wainscot", Vector3.new(RANGE_LENGTH, 2.5, 0.1), CFrame.new(RANGE_CENTER_X, 1.25, wallZ + inward * 0.05), Color3.fromRGB(55, 65, 80))
		for x = RANGE_MIN_X + 4, RANGE_MAX_X - 4, 5 do
			box(parent, "AcousticPanel", Vector3.new(4, 2, 0.3), CFrame.new(x, 12, wallZ + inward * 0.15), Color3.fromRGB(45, 45, 52), Enum.Material.Fabric)
		end
	end

	-- telão em cima da porta, do lado de dentro
	local screen = box(parent, "InfoScreen", Vector3.new(0.3, 3.2, 20), CFrame.new(RANGE_MAX_X - 0.15, height - 2, centerZ), Color3.fromRGB(15, 25, 45))
	writeOn(screen, Enum.NormalId.Left, "TREINAMENTO\nTeste as armas  •  Turbine na máquina  •  Veja o dano de cada tiro", Color3.fromRGB(120, 220, 255))
end

-- Linha de tiro: faixa zebrada no chão, cabines (divisórias + balcão) e o número de cada pista
local function trainingFiringLine(parent: Instance)
	local stripe = 2
	for index = 0, math.floor(RANGE_WIDTH / stripe) - 1 do
		local z = RANGE_MIN_Z + (index + 0.5) * stripe
		local color = if index % 2 == 0 then COLOR.Yellow else Color3.fromRGB(20, 20, 20)
		box(parent, "FiringLine", Vector3.new(1, 0.06, stripe), CFrame.new(FIRING_LINE_X - 0.5, 0.13, z), color)
	end

	-- divisórias entre as pistas (curtinhas, pra deixar livre o corredor que vem da porta)
	for index = 0, #LANES do
		local z = LANES[1] - LANE_WIDTH / 2 + index * LANE_WIDTH
		box(parent, "BoothWall", Vector3.new(3, 4.5, 0.4), CFrame.new(FIRING_LINE_X + 1.5, 2.25, z), Color3.fromRGB(60, 75, 95), Enum.Material.Metal)
		box(parent, "BoothWallTop", Vector3.new(3, 0.3, 0.6), CFrame.new(FIRING_LINE_X + 1.5, 4.6, z), COLOR.Yellow)
	end

	for number, z in LANES do
		-- balcão da cabine
		box(parent, "BoothCounter", Vector3.new(1.4, 0.3, 7), CFrame.new(FIRING_LINE_X + 0.7, 3.35, z), COLOR.Wood, Enum.Material.WoodPlanks)
		for _, dz in { -3, 3 } do
			box(parent, "CounterLeg", Vector3.new(0.3, 3.1, 0.3), CFrame.new(FIRING_LINE_X + 0.7, 1.65, z + dz), COLOR.DarkMetal, Enum.Material.Metal)
		end

		-- número pintado no chão (de frente pra quem está na linha de tiro)
		local floorPosition = Vector3.new(FIRING_LINE_X - 4, 0.13, z)
		local floorNumber = box(parent, "LaneNumber", Vector3.new(4, 0.05, 4), CFrame.lookAt(floorPosition, floorPosition - Vector3.xAxis), COLOR.White, nil, {
			Transparency = 1,
			CanCollide = false,
		})
		writeOn(floorNumber, Enum.NormalId.Top, tostring(number), COLOR.White)

		-- placa pendurada no teto
		local sign = box(parent, "LaneSign", Vector3.new(0.3, 2, 2.4), CFrame.new(FIRING_LINE_X - 2, 11, z), COLOR.Red)
		writeOn(sign, Enum.NormalId.Right, tostring(number), COLOR.White)
		writeOn(sign, Enum.NormalId.Left, tostring(number), COLOR.White)
		for _, dz in { -0.9, 0.9 } do
			box(parent, "SignRod", Vector3.new(0.1, 2, 0.1), CFrame.new(FIRING_LINE_X - 2, 13, z + dz), COLOR.DarkMetal, Enum.Material.Metal)
		end
	end
end

-- Fundo do estande: alvos redondos atrás de cada zumbi de treino e uma barreira de sacos de areia
local function trainingTargets(parent: Instance)
	local rings = {
		{ 5, COLOR.White },
		{ 4, Color3.fromRGB(25, 25, 25) },
		{ 3, COLOR.White },
		{ 2, COLOR.Red },
		{ 0.9, COLOR.Yellow },
	}
	for _, z in LANES do
		for index, ring in rings do
			local diameter, color = ring[1], ring[2]
			box(parent, "Target", Vector3.new(0.05, diameter, diameter), CFrame.new(RANGE_MIN_X + 0.03 + index * 0.03, 5.5, z), color, nil, {
				Shape = Enum.PartType.Cylinder,
				CanCollide = false,
			})
		end
	end

	for layer = 0, 1 do
		local z = RANGE_MIN_Z + 1.5 + layer * 1.5
		while z < RANGE_MAX_Z - 1.5 do
			box(parent, "Sandbag", Vector3.new(2.2, 1, 3), CFrame.new(RANGE_MIN_X + 1.3, 0.6 + layer * 0.95, z), Color3.fromRGB(170, 150, 105), Enum.Material.Fabric)
			z += 3.1
		end
	end

	-- explicação dos zumbis de treino, em cima dos alvos
	local explanationPosition = Vector3.new(RANGE_MIN_X + 0.2, 11, RANGE_CENTER_Z)
	wallSign(
		parent,
		"ZUMBIS DE TREINO: cada um tem a vida de um zumbi da rodada escrita em cima dele",
		CFrame.lookAt(explanationPosition, explanationPosition + Vector3.xAxis),
		70,
		COLOR.Yellow
	)
end

-- Teto: vigas de aço, um trilho por pista (como os de levar o alvo) e as luzes
local function trainingCeiling(parent: Instance)
	local height = TRAINING_HEIGHT
	for _, x in { -67.5, -92.5, -117.5, -142.5 } do
		box(parent, "CeilingBeam", Vector3.new(1, 0.8, RANGE_WIDTH + 4), CFrame.new(x, height - 0.4, RANGE_CENTER_Z), Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
	end
	local railStart, railEnd = FIRING_LINE_X - 3, DUMMY_X - 15
	for _, z in LANES do
		box(parent, "TargetRail", Vector3.new(railStart - railEnd, 0.2, 0.3), CFrame.new((railStart + railEnd) / 2, height - 0.9, z), COLOR.DarkMetal, Enum.Material.Metal)
	end

	for _, position in {
		Vector2.new(-55, 15),
		Vector2.new(-80, -20),
		Vector2.new(-80, 50),
		Vector2.new(-105, 15),
		Vector2.new(-130, -20),
		Vector2.new(-130, 50),
	} do
		local lamp = block(parent, "RangeLight", Vector3.new(3, 0.4, 1), position.X, position.Y, Color3.fromRGB(240, 245, 255), Enum.Material.Neon, nil, height - 0.4)
		local light = Instance.new("PointLight")
		light.Range = 40
		light.Brightness = 1.6
		light.Parent = lamp
	end
end

-- Armas de graça nas paredes e a Máquina de Upgrade grátis
local function trainingArmory(parent: Instance)
	local wallIds, boxIds = {}, {}
	for id, def in Weapons do
		table.insert(if def.BoxOnly then boxIds else wallIds, id)
	end
	table.sort(wallIds, function(a, b)
		return Weapons[a].Price < Weapons[b].Price
	end)
	table.sort(boxIds, function(a, b)
		return (Weapons[a].BoxWeight :: number) > (Weapons[b].BoxWeight :: number)
	end)

	local function weaponRow(ids: { string }, z: number, inward: Vector3, title: string, color: Color3)
		for index, id in ids do
			local position = Vector3.new(FIRING_LINE_X + 2 - index * 8, 5.5, z) + inward * 0.25
			MapKit.wallBuy(parent, id, CFrame.lookAt(position, position + inward), 0)
		end
		local signPosition = Vector3.new(FIRING_LINE_X + 2 - (#ids + 1) * 4, 9.5, z) + inward * 0.2
		wallSign(parent, title, CFrame.lookAt(signPosition, signPosition + inward), #ids * 8 - 2, color)
	end
	weaponRow(wallIds, RANGE_MAX_Z, -Vector3.zAxis, "ARMAS DE PAREDE", COLOR.White)
	weaponRow(boxIds, RANGE_MIN_Z, Vector3.zAxis, "SÓ NA CAIXA SURPRESA", COLOR.Yellow)

	local machinePosition = Vector3.new(FIRING_LINE_X + 5, 0, RANGE_MIN_Z + 2.5)
	MapKit.upgradeMachine(parent, CFrame.lookAt(machinePosition, machinePosition + Vector3.zAxis), 0)
end

-- Zumbis de treino: um no fim de cada pista, com a vida da rodada escrita em cima
local function trainingDummies(parent: Instance)
	for index, z in LANES do
		local round = LANE_ROUNDS[index]
		local position = Vector3.new(DUMMY_X, 0.1, z)
		local spot = box(parent, "DummySpot", Vector3.new(4, 0.2, 4), CFrame.lookAt(position, position + Vector3.xAxis), Color3.fromRGB(150, 30, 30), Enum.Material.Neon, {
			CanCollide = false,
			CanQuery = false,
		})
		spot:SetAttribute("Round", round)
		tag(spot, "DummySpot")

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(170, 50)
		billboard.StudsOffset = Vector3.new(0, 8, 0)
		billboard.MaxDistance = 90
		billboard.Parent = spot
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = COLOR.White
		label.TextStrokeTransparency = 0.3
		label.Text = `ZUMBI DA RODADA {round}\n{Config.zombieHealth(round)} de vida`
		label.Parent = billboard
	end
end

-- Lado de fora: letreiro, faixa vermelha no alto, luzes da porta, cartaz e uns caixotes e barris
local function trainingExterior(parent: Instance)
	local height = TRAINING_HEIGHT
	local centerZ = RANGE_CENTER_Z
	local faceX = RANGE_MAX_X + 2 -- face de fora da parede da frente
	local doorEnd = centerZ + TRAINING_DOOR_WIDTH / 2

	local entranceSign = box(parent, "EntranceSign", Vector3.new(0.4, 3, 22), CFrame.new(faceX + 0.2, height - 2, centerZ), Color3.fromRGB(150, 25, 25))
	writeOn(entranceSign, Enum.NormalId.Right, "TREINAMENTO", COLOR.White)
	box(parent, "TopBand", Vector3.new(0.3, 1, RANGE_WIDTH + 4), CFrame.new(faceX + 0.15, height + 0.5, centerZ), COLOR.Red)

	local infoSign = box(parent, "InfoSign", Vector3.new(0.3, 2.6, 9), CFrame.new(faceX + 0.15, 5, doorEnd + 6), Color3.fromRGB(25, 25, 30))
	writeOn(infoSign, Enum.NormalId.Right, "TESTE TODAS AS ARMAS\nNOS ZUMBIS DE TREINO", COLOR.Yellow)
	local poster = box(parent, "Poster", Vector3.new(0.2, 3, 7), CFrame.new(faceX + 0.1, 6, centerZ - 25), COLOR.Yellow)
	writeOn(poster, Enum.NormalId.Right, "ZUMBIS DE TREINO\nNÃO MORDEM!", COLOR.Red)

	-- arandelas dos lados da porta
	for _, side in { -1, 1 } do
		local sconce = box(parent, "Sconce", Vector3.new(0.4, 1, 0.6), CFrame.new(faceX + 0.2, 8, centerZ + side * (TRAINING_DOOR_WIDTH / 2 + 2)), Color3.fromRGB(255, 220, 160), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 150)
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = sconce
	end

	-- caixotes de munição e barris encostados na parede
	block(parent, "Crate", Vector3.new(3, 3, 3), faceX + 2, doorEnd + 16, COLOR.Wood, Enum.Material.WoodPlanks)
	block(parent, "Crate", Vector3.new(3, 3, 3), faceX + 2, doorEnd + 19.2, COLOR.Wood, Enum.Material.WoodPlanks)
	box(parent, "Crate", Vector3.new(3, 3, 3), CFrame.new(faceX + 2, 4.5, doorEnd + 17.6) * CFrame.Angles(0, math.rad(20), 0), COLOR.Wood, Enum.Material.WoodPlanks)
	for index, color in { Color3.fromRGB(180, 40, 40), Color3.fromRGB(40, 80, 160) } do
		local barrelZ = centerZ - TRAINING_DOOR_WIDTH / 2 - 8 - index * 2.6
		box(parent, "Barrel", Vector3.new(4, 2.4, 2.4), CFrame.new(faceX + 1.6, 2, barrelZ) * ROTATE_UP, color, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	end
end

local function buildTraining(parent: Instance)
	trainingStructure(parent)
	trainingFiringLine(parent)
	trainingTargets(parent)
	trainingCeiling(parent)
	trainingArmory(parent)
	trainingDummies(parent)
	trainingExterior(parent)
end

return function(maps: { MapInfo }): Model
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	buildPlaza(folder(lobby, "Praca"), maps)
	buildTraining(folder(lobby, "Treinamento"))
	lobby.WorldPivot = CFrame.identity
	return lobby
end
