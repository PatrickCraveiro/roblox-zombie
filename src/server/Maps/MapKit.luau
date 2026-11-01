-- Funções de construção usadas pelos mapas (partes, placas, materiais...).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Shop = require(ReplicatedStorage.Shared.Shop)

local MapKit = {}

-- Materiais novos podem não existir em versões antigas: usa um substituto
function MapKit.material(name: string, fallback: Enum.Material): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and value then value else fallback
end

MapKit.MAT = {
	Tiles = MapKit.material("CeramicTiles", Enum.Material.Marble),
	Asphalt = MapKit.material("Asphalt", Enum.Material.Concrete),
	Cardboard = MapKit.material("Cardboard", Enum.Material.SmoothPlastic),
	Plaster = MapKit.material("Plaster", Enum.Material.SmoothPlastic),
	Rubber = MapKit.material("Rubber", Enum.Material.SmoothPlastic),
}

function MapKit.box(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, mat: Enum.Material?, props: { [string]: any }?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = mat or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- Parte apoiada: (x, z) é o centro e "y" é a altura da base (0 = chão)
function MapKit.block(parent: Instance, name: string, size: Vector3, x: number, z: number, color: Color3, mat: Enum.Material?, props: { [string]: any }?, y: number?): Part
	return MapKit.box(parent, name, size, CFrame.new(x, (y or 0) + size.Y / 2, z), color, mat, props)
end

function MapKit.folder(parent: Instance, name: string): Folder
	local newFolder = Instance.new("Folder")
	newFolder.Name = name
	newFolder.Parent = parent
	return newFolder
end

-- Texto escrito numa face da parte. Retorna o TextLabel (pra dar pra mudar o texto depois).
-- pixelsPerStud: resolução (padrão 25; use mais em peças pequenas, ex: etiqueta de preço)
function MapKit.writeOn(part: BasePart, face: Enum.NormalId, text: string, textColor: Color3, background: Color3?, pixelsPerStud: number?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 25
	gui.LightInfluence = 0.3
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if background then 0 else 1
	label.BackgroundColor3 = background or Color3.new(0, 0, 0)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.Parent = label

	return label
end

function MapKit.tag(instance: Instance, tagName: string): Instance
	instance:AddTag(tagName)
	return instance
end

-- Placa de arma na parede: o WallBuyService prende a arma em 3D, o nome e o preço nela.
-- A frente da placa fica pro LookVector do cframe. price nil = preço normal da arma
function MapKit.wallBuy(parent: Instance, weaponId: string, cframe: CFrame, price: number?): Part
	local part = MapKit.box(parent, "WallBuy_" .. weaponId, Vector3.new(7, 4, 0.4), cframe, Color3.fromRGB(210, 205, 190), nil, { CanCollide = false })
	part:SetAttribute("WeaponId", weaponId)
	if price then
		part:SetAttribute("Price", price)
	end
	MapKit.tag(part, "WallBuy")
	return part
end

-- Barricada (entrada dos zumbis): vão na parede tampado com tábuas, o lugar onde os zumbis
-- nascem (do lado de fora) e o acabamento do vão. O BarricadeService cuida do resto.
--   base      - centro do vão no chão, no meio da parede, com o LookVector apontando pra DENTRO
--   style     - "Wall" (parede quebrada), "Glass" (vitrine quebrada) ou "Door" (porta arrombada)
--   zone      - área que precisa estar aberta pros zumbis nascerem ali (nil = sempre)
--   wallColor - cor da parede (pros pedaços quebrados)
-- A parede em si precisa ter o vão (width x height) aberto: quem monta o mapa corta.
function MapKit.barricade(parent: Instance, base: CFrame, width: number, height: number, thickness: number, style: string, zone: string?, wallColor: Color3?): Model
	local model = Instance.new("Model")
	model.Name = "Barricade"
	model.Parent = parent
	local rng = Random.new(math.floor(base.Position.X * 7 + base.Position.Z * 13))
	local noCollide = { CanCollide = false, CanQuery = false, CanTouch = false }

	-- parte invisível no vão: o BarricadeService faz ela barrar os jogadores sempre e os
	-- zumbis só enquanto tiver tábua. (Os tiros atravessam a barricada inteira porque o
	-- WeaponController tira ela do raycast; CanQuery não adianta em parte com colisão.)
	local opening = MapKit.box(model, "Opening", Vector3.new(width, height, thickness), base * CFrame.new(0, height / 2, 0), Color3.new(0, 0, 0), nil, {
		Transparency = 1,
		CanTouch = false,
	})
	model.PrimaryPart = opening

	-- tábuas pregadas do lado de dentro, meio tortas
	local count = Config.BarricadePlanks
	local wood = Color3.fromRGB(130, 95, 58)
	for index = 1, count do
		local y = 0.9 + (index - 1) * (height - 1.8) / math.max(count - 1, 1)
		local tilt = math.rad(rng:NextNumber(3, 9)) * (if index % 2 == 0 then 1 else -1)
		local shade = wood:Lerp(Color3.fromRGB(90, 62, 38), rng:NextNumber())
		MapKit.box(model, "Plank" .. index, Vector3.new(width + 1.4, 0.75, 0.25), base * CFrame.new(0, y, -(thickness / 2 + 0.2)) * CFrame.Angles(0, 0, tilt), shade, Enum.Material.WoodPlanks)
	end

	-- os zumbis nascem lá fora, na frente do vão
	local spawnPart = MapKit.box(model, "ZombieSpawn", Vector3.new(4, 0.2, 4), base * CFrame.new(0, 0.1, thickness / 2 + 8), Color3.new(0, 0, 0), nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	if zone then
		spawnPart:SetAttribute("Zone", zone)
	end
	MapKit.tag(spawnPart, "ZombieSpawn")

	-- acabamento do vão
	if style == "Door" then
		local frameColor = Color3.fromRGB(70, 55, 40)
		for _, side in { -1, 1 } do
			MapKit.box(model, "DoorFrame", Vector3.new(0.5, height + 0.5, thickness + 0.4), base * CFrame.new(side * (width / 2 + 0.25), (height + 0.5) / 2, 0), frameColor, Enum.Material.WoodPlanks)
		end
		MapKit.box(model, "DoorFrame", Vector3.new(width + 1, 0.5, thickness + 0.4), base * CFrame.new(0, height + 0.25, 0), frameColor, Enum.Material.WoodPlanks)
		-- a porta arrombada caída do lado de fora
		local doorCFrame = base * CFrame.new(rng:NextNumber(-1, 1), 0.35, thickness / 2 + height / 2 + 0.5) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0) * CFrame.Angles(math.rad(6), 0, 0)
		MapKit.box(model, "BrokenDoor", Vector3.new(width - 0.5, 0.3, height - 0.8), doorCFrame, Color3.fromRGB(110, 115, 120), Enum.Material.CorrodedMetal, noCollide)
	elseif style == "Glass" then
		-- cacos pendurados na borda de cima e espalhados pelo chão
		local glass = Color3.fromRGB(150, 175, 185)
		for _ = 1, 6 do
			local shardHeight = rng:NextNumber(0.6, 1.8)
			local shard = MapKit.box(model, "GlassShard", Vector3.new(rng:NextNumber(0.5, 1.3), shardHeight, 0.1), base * CFrame.new(rng:NextNumber(-width / 2, width / 2), height - shardHeight * 0.3, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.6, 0.6)), glass, Enum.Material.Glass, noCollide)
			shard.Transparency = 0.45
		end
		for _ = 1, 10 do
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local shard = MapKit.box(model, "GlassShard", Vector3.new(rng:NextNumber(0.3, 0.9), 0.05, rng:NextNumber(0.3, 0.8)), base * CFrame.new(rng:NextNumber(-width / 2 - 1, width / 2 + 1), 0.05, side * rng:NextNumber(thickness / 2 + 0.3, thickness / 2 + 3)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), glass, Enum.Material.Glass, noCollide)
			shard.Transparency = 0.3
		end
	else
		-- parede quebrada: pedaços tortos na borda do vão (dos dois lados) e entulho no chão
		local chunkColor = (wallColor or Color3.fromRGB(205, 200, 188)):Lerp(Color3.new(0, 0, 0), 0.2)
		for _, face in { -1, 1 } do
			for _ = 1, 6 do
				local edge = rng:NextInteger(1, 3)
				local x = if edge == 1 then -width / 2 elseif edge == 2 then width / 2 else rng:NextNumber(-width / 2, width / 2)
				local y = if edge == 3 then height else rng:NextNumber(0.6, height)
				local chunkSize = rng:NextNumber(0.6, 1.4)
				local chunkCFrame = base * CFrame.new(x, y, face * (thickness / 2 + 0.1)) * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi))
				MapKit.box(model, "Rubble", Vector3.new(chunkSize, chunkSize * 0.8, 0.5), chunkCFrame, chunkColor, nil, noCollide)
			end
		end
		for _ = 1, 7 do
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local debrisSize = rng:NextNumber(0.4, 1)
			local debrisCFrame = base * CFrame.new(rng:NextNumber(-width / 2 - 1, width / 2 + 1), debrisSize * 0.3, side * rng:NextNumber(thickness / 2 + 0.5, thickness / 2 + 3)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0)
			MapKit.box(model, "Debris", Vector3.new(debrisSize, debrisSize * 0.6, debrisSize), debrisCFrame, chunkColor, nil, noCollide)
		end
	end

	MapKit.tag(model, "Barricade")
	return model
end

-- Quiosque da loja de melhorias (o ShopService põe o botão de comprar). "cframe" = centro da
-- base no chão, com a frente virada pro LookVector. itemId = chave em Shop.luau
function MapKit.shopStand(parent: Instance, cframe: CFrame, itemId: string): Part
	local item = Shop[itemId]
	local model = Instance.new("Model")
	model.Name = "Loja_" .. itemId
	model.Parent = parent
	local dark = item.Color:Lerp(Color3.new(0, 0, 0), 0.45)
	local noCollide = { CanCollide = false }

	-- balcão (é nele que fica o botão de comprar)
	local counter = MapKit.box(model, "Counter", Vector3.new(5, 3.2, 2.4), cframe * CFrame.new(0, 1.6, 0), dark)
	counter:SetAttribute("ItemId", itemId)
	MapKit.tag(counter, "ShopItem")
	MapKit.box(model, "CounterStripe", Vector3.new(5.05, 0.3, 0.1), cframe * CFrame.new(0, 2.8, -1.22), item.Color, Enum.Material.Neon)
	MapKit.box(model, "CounterTop", Vector3.new(5.3, 0.2, 2.7), cframe * CFrame.new(0, 3.3, 0), Color3.fromRGB(235, 235, 230))

	-- placa atrás do balcão com nome, descrição e preço
	for _, x in { -2.6, 2.6 } do
		MapKit.box(model, "SignPost", Vector3.new(0.3, 5.6, 0.3), cframe * CFrame.new(x, 6, 1.1), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
	end
	local sign = MapKit.box(model, "Sign", Vector3.new(5.6, 3.4, 0.3), cframe * CFrame.new(0, 7.1, 1.1), Color3.fromRGB(20, 20, 24))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	for _, line in {
		{ 0.04, 0.36, string.upper(item.Name), item.Color, Enum.Font.GothamBlack },
		{ 0.42, 0.28, item.Description, Color3.fromRGB(230, 230, 230), Enum.Font.GothamMedium },
		{ 0.72, 0.24, `{item.Price} PTS`, Color3.fromRGB(255, 215, 40), Enum.Font.GothamBold },
	} do
		local label = Instance.new("TextLabel")
		label.Position = UDim2.fromScale(0.05, line[1])
		label.Size = UDim2.fromScale(0.9, line[2])
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.TextWrapped = true
		label.Text = line[3]
		label.TextColor3 = line[4]
		label.Font = line[5]
		label.Parent = gui
	end
	local light = Instance.new("PointLight")
	light.Color = item.Color
	light.Range = 12
	light.Brightness = 1.2
	light.Parent = sign

	-- o "produto" em cima do balcão
	local top = cframe * CFrame.new(0, 3.4, 0)
	if itemId == "Armor" then
		MapKit.box(model, "Vest", Vector3.new(1.7, 1.9, 0.7), top * CFrame.new(0, 0.95, 0), item.Color, Enum.Material.Fabric, noCollide)
		MapKit.box(model, "VestPlate", Vector3.new(1.2, 1.1, 0.1), top * CFrame.new(0, 1.05, -0.38), dark, Enum.Material.Metal, noCollide)
		for _, x in { -0.55, 0.55 } do
			MapKit.box(model, "VestStrap", Vector3.new(0.4, 0.35, 0.75), top * CFrame.new(x, 2.05, 0), dark, Enum.Material.Fabric, noCollide)
		end
	elseif itemId == "FastHands" then
		-- raio em zigue-zague
		for index, info in { { -0.25, 1.9, 25 }, { 0.15, 1.15, -30 }, { -0.1, 0.45, 25 } } do
			MapKit.box(model, "Bolt" .. index, Vector3.new(0.45, 1.1, 0.3), top * CFrame.new(info[1], info[2], 0) * CFrame.Angles(0, 0, math.rad(info[3])), item.Color, Enum.Material.Neon, noCollide)
		end
	elseif itemId == "SecondChance" then
		-- maleta de primeiros socorros
		MapKit.box(model, "AidKit", Vector3.new(1.8, 1.3, 0.9), top * CFrame.new(0, 0.65, 0), Color3.fromRGB(240, 240, 240), nil, noCollide)
		MapKit.box(model, "Cross", Vector3.new(0.9, 0.28, 0.05), top * CFrame.new(0, 0.7, -0.47), item.Color, Enum.Material.Neon, noCollide)
		MapKit.box(model, "Cross", Vector3.new(0.28, 0.9, 0.05), top * CFrame.new(0, 0.7, -0.47), item.Color, Enum.Material.Neon, noCollide)
		MapKit.box(model, "Handle", Vector3.new(0.7, 0.15, 0.2), top * CFrame.new(0, 1.4, 0), Color3.fromRGB(40, 40, 45), nil, noCollide)
	elseif itemId == "Ammo" then
		-- caixas de munição e umas balas em pé
		MapKit.box(model, "AmmoBox", Vector3.new(1.3, 0.8, 0.8), top * CFrame.new(-0.7, 0.4, 0.2), Color3.fromRGB(85, 95, 55), nil, noCollide)
		MapKit.box(model, "AmmoBox", Vector3.new(1.3, 0.8, 0.8), top * CFrame.new(-0.6, 1.2, 0.2) * CFrame.Angles(0, 0.2, 0), Color3.fromRGB(85, 95, 55), nil, noCollide)
		for index = 0, 4 do
			MapKit.box(model, "Bullet", Vector3.new(0.7, 0.22, 0.22), top * CFrame.new(0.6 + index * 0.28, 0.35, -0.3) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(215, 170, 60), Enum.Material.Metal, {
				CanCollide = false,
				Shape = Enum.PartType.Cylinder,
			})
		end
	end

	return counter
end

-- Carrinho de supermercado. (x, z) no chão; yaw = rotação em radianos
function MapKit.cart(parent: Instance, x: number, z: number, yaw: number)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local metal = Color3.fromRGB(150, 150, 155)
	MapKit.box(parent, "CartBasket", Vector3.new(2.4, 1.8, 3.6), base * CFrame.new(0, 2.2, 0), Color3.fromRGB(190, 190, 195), Enum.Material.Metal, { Transparency = 0.35 })
	MapKit.box(parent, "CartHandle", Vector3.new(2.4, 0.2, 0.2), base * CFrame.new(0, 3.3, 1.9), Color3.fromRGB(200, 25, 25))
	MapKit.box(parent, "CartFrame", Vector3.new(2, 0.15, 3.4), base * CFrame.new(0, 0.6, 0), metal, Enum.Material.Metal)
	for _, offset in { Vector3.new(-0.9, 0.25, -1.5), Vector3.new(0.9, 0.25, -1.5), Vector3.new(-0.9, 0.25, 1.5), Vector3.new(0.9, 0.25, 1.5) } do
		MapKit.box(parent, "CartWheel", Vector3.new(0.3, 0.5, 0.5), base * CFrame.new(offset), Color3.fromRGB(10, 10, 10), nil, { Shape = Enum.PartType.Cylinder })
	end
end

-- Máquina de Upgrade (o UpgradeService coloca o botão de usar). "cframe" = centro da base
-- no chão, com a frente da máquina virada pro LookVector. price nil = preço padrão (Config)
function MapKit.upgradeMachine(parent: Instance, cframe: CFrame, price: number?): Part
	local model = Instance.new("Model")
	model.Name = "MaquinaDeUpgrade"
	model.Parent = parent

	local red = Color3.fromRGB(255, 40, 40)
	local body = MapKit.box(model, "Body", Vector3.new(7, 7, 4), cframe * CFrame.new(0, 4.1, 0), Color3.fromRGB(45, 18, 18), Enum.Material.DiamondPlate)
	MapKit.box(model, "Base", Vector3.new(8, 0.6, 5), cframe * CFrame.new(0, 0.3, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
	-- moldura de neon vermelho na frente
	for _, x in { -3.3, 3.3 } do
		MapKit.box(model, "Neon", Vector3.new(0.3, 6.6, 0.2), cframe * CFrame.new(x, 4.1, -2.05), red, Enum.Material.Neon)
	end
	MapKit.box(model, "Neon", Vector3.new(6.9, 0.3, 0.2), cframe * CFrame.new(0, 7.45, -2.05), red, Enum.Material.Neon)
	-- abertura onde a arma entra (brilhando por dentro)
	MapKit.box(model, "Slot", Vector3.new(4.4, 1.6, 0.1), cframe * CFrame.new(0, 4.6, -2.06), Color3.fromRGB(10, 10, 10))
	local glow = MapKit.box(model, "SlotGlow", Vector3.new(3.8, 0.4, 0.1), cframe * CFrame.new(0, 4.6, -2.1), Color3.fromRGB(255, 90, 60), Enum.Material.Neon)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 120, 60))
	sparks.LightEmission = 1
	sparks.Rate = 4
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.Speed = NumberRange.new(3, 6)
	sparks.SpreadAngle = Vector2.new(40, 40)
	sparks.Size = NumberSequence.new(0.15, 0)
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Parent = glow

	-- preço embaixo da abertura e letreiro em cima
	local plate = MapKit.box(model, "PricePlate", Vector3.new(5, 1.4, 0.1), cframe * CFrame.new(0, 2.5, -2.06), Color3.fromRGB(20, 20, 22))
	MapKit.writeOn(plate, Enum.NormalId.Front, if price == 0 then "GRÁTIS" else `{price or Config.UpgradePrice} PTS`, Color3.fromRGB(255, 220, 60))
	local sign = MapKit.box(model, "Sign", Vector3.new(9, 2.2, 0.5), cframe * CFrame.new(0, 9, -1), Color3.fromRGB(150, 20, 20))
	MapKit.writeOn(sign, Enum.NormalId.Front, "MÁQUINA DE UPGRADE", Color3.fromRGB(255, 255, 255))
	for _, x in { -3.5, 3.5 } do
		MapKit.box(model, "SignPost", Vector3.new(0.3, 1.2, 0.3), cframe * CFrame.new(x, 8.1, -1), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
	end

	local light = Instance.new("PointLight")
	light.Color = red
	light.Range = 16
	light.Brightness = 2
	light.Parent = glow

	if price then
		body:SetAttribute("Price", price)
	end
	MapKit.tag(body, "UpgradeMachine")
	return body
end

return MapKit
