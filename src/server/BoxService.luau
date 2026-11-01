-- Caixa Surpresa: paga e sai uma arma aleatória (qualquer arma com BoxWeight em Weapons.luau:
-- todas menos a pistola inicial; as BoxOnly só existem aqui). Só quem pagou pode pegar.
--
-- A caixa aparece num ponto sorteado a cada partida: partes com a tag "BoxSpot"
-- (a frente da caixa fica virada pro -Z da parte, que deve ficar no chão).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local PointsService = require(script.Parent.PointsService)
local WeaponService = require(script.Parent.WeaponService)

local Remotes = ReplicatedStorage.Remotes

local BoxService = {}

local BOX_SIZE = Vector3.new(6, 3, 3)
local LID_OPEN_ANGLE = math.rad(105)
local DISPLAY_SCALE = 1.4

local model: Model? = nil
local base: Part
local lid: Part
local glow: PointLight
local prompt: ProximityPrompt

local state = "Idle" -- Idle | Rolling | Ready
local token = 0 -- muda a cada uso/reset, pra cancelar animações antigas
local display: Model? = nil

local function cardboard(): Enum.Material
	local ok, material = pcall(function()
		return (Enum.Material :: any).Cardboard
	end)
	return if ok and material then material else Enum.Material.SmoothPlastic
end

local function newPart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function addQuestionMarks(part: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0 -- os "?" brilham mesmo no escuro
	gui.Parent = part

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 220, 60)
	text.Text = "? CAIXA SURPRESA ?"
	text.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.25, 0)
	padding.PaddingBottom = UDim.new(0.25, 0)
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.Parent = text
end

local function lidCFrame(openAmount: number): CFrame
	-- dobradiça na borda de trás de cima da caixa
	local hinge = base.CFrame * CFrame.new(0, BOX_SIZE.Y / 2, BOX_SIZE.Z / 2)
	return hinge * CFrame.Angles(LID_OPEN_ANGLE * openAmount, 0, 0) * CFrame.new(0, 0.2, -BOX_SIZE.Z / 2)
end

local function setLid(open: boolean)
	TweenService:Create(lid, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = lidCFrame(if open then 1 else 0),
	}):Play()
	-- sempre acesa; aberta brilha bem mais
	glow.Brightness = if open then 4 else 1.5
	glow.Range = if open then 22 else 14
end

local function buildBox()
	local box = Instance.new("Model")
	box.Name = "CaixaSurpresa"

	base = newPart("Box", BOX_SIZE, Color3.fromRGB(165, 125, 75), cardboard())
	base.Parent = box
	addQuestionMarks(base, Enum.NormalId.Front)
	addQuestionMarks(base, Enum.NormalId.Back)

	lid = newPart("Lid", Vector3.new(BOX_SIZE.X + 0.2, 0.4, BOX_SIZE.Z + 0.2), Color3.fromRGB(150, 110, 65), cardboard())
	lid.Parent = box
	-- fita adesiva no meio da tampa (solta e soldada, acompanha a tampa abrindo)
	local tape = newPart("Tape", Vector3.new(BOX_SIZE.X + 0.25, 0.42, 0.6), Color3.fromRGB(200, 170, 110), Enum.Material.SmoothPlastic)
	tape.Anchored = false
	tape.Massless = true
	tape.CanCollide = false
	tape.Parent = box
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = lid
	weld.Part1 = tape
	weld.Parent = tape

	glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 210, 120)
	glow.Range = 14
	glow.Brightness = 1.5
	glow.Parent = base

	-- destaque (é a coisa mais procurada do jogo): facho de luz dourada subindo até o teto
	-- e faíscas saindo da caixa, pra dar pra achar de longe
	local beamBottom = Instance.new("Attachment")
	beamBottom.Position = Vector3.new(0, BOX_SIZE.Y / 2, 0)
	beamBottom.Parent = base
	local beamTop = Instance.new("Attachment")
	beamTop.Position = Vector3.new(0, BOX_SIZE.Y / 2 + 16, 0)
	beamTop.Parent = base
	local beam = Instance.new("Beam")
	beam.Attachment0 = beamBottom
	beam.Attachment1 = beamTop
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 215, 90))
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0 = 3.5
	beam.Width1 = 1.5
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	beam.Parent = base

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 220, 100))
	sparkles.LightEmission = 1
	sparkles.Rate = 14
	sparkles.Lifetime = NumberRange.new(1.5, 2.5)
	sparkles.Speed = NumberRange.new(3, 6)
	sparkles.SpreadAngle = Vector2.new(25, 25)
	sparkles.Size = NumberSequence.new(0.35, 0)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Parent = base

	prompt = Instance.new("ProximityPrompt")
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	box.PrimaryPart = base
	model = box
	return box
end

local function setIdlePrompt()
	prompt.Enabled = true
	prompt.ActionText = "Caixa Surpresa"
	prompt.ObjectText = `{Config.BoxPrice} pts`
end

local function clearDisplay()
	if display then
		display:Destroy()
		display = nil
	end
end

-- Mostra uma arma flutuando em cima da caixa, de lado pra todo mundo ver
local function showWeapon(weaponId: string, height: number)
	clearDisplay()
	local weapon = WeaponModels.build(weaponId, true)
	weapon:ScaleTo(DISPLAY_SCALE)
	weapon:PivotTo(base.CFrame * CFrame.new(0, height, 0) * CFrame.Angles(0, math.rad(90), 0))
	weapon.Parent = model
	display = weapon
end

local function boxWeaponIds(): { string }
	local ids = {}
	for id, def in Weapons do
		if def.BoxWeight then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

-- Sorteio ponderado pela BoxWeight, sem repetir arma que o jogador já tem
local function pickWeapon(player: Player): string
	local pool, total = {}, 0
	for _, id in boxWeaponIds() do
		if not WeaponService.findSlot(player, id) then
			table.insert(pool, id)
			total += Weapons[id].BoxWeight :: number
		end
	end
	if #pool == 0 then
		pool = boxWeaponIds()
		total = 0
		for _, id in pool do
			total += Weapons[id].BoxWeight :: number
		end
	end

	local roll = math.random() * total
	for _, id in pool do
		roll -= Weapons[id].BoxWeight :: number
		if roll <= 0 then
			return id
		end
	end
	return pool[#pool]
end

local function closeBox()
	clearDisplay()
	setLid(false)
	state = "Idle"
	setIdlePrompt()
end

local function roll(player: Player)
	token += 1
	local myToken = token
	state = "Rolling"
	prompt.Enabled = false
	setLid(true)
	Sounds.play(Sounds.Ids.BoxRoll, base, 0.7)

	-- as armas vão trocando cada vez mais devagar enquanto sobem
	local ids = boxWeaponIds()
	local started = os.clock()
	while os.clock() - started < Config.BoxRollTime do
		if token ~= myToken then
			return
		end
		local progress = (os.clock() - started) / Config.BoxRollTime
		showWeapon(ids[math.random(#ids)], 0.5 + progress * 2.5)
		task.wait(0.07 + progress * 0.3)
	end
	if token ~= myToken then
		return
	end

	local weaponId = pickWeapon(player)
	local def = Weapons[weaponId]
	showWeapon(weaponId, 3)
	Sounds.play(Sounds.Ids.BoxReady, base, 0.8)

	state = "Ready"
	prompt.ActionText = "Pegar " .. def.Name
	prompt.ObjectText = player.DisplayName
	prompt.Enabled = true

	-- pega antes do tempo acabar, senão a arma afunda e a caixa fecha
	local readyAt = os.clock()
	while state == "Ready" and token == myToken do
		local elapsed = os.clock() - readyAt
		if elapsed >= Config.BoxTakeTime then
			closeBox()
			return
		end
		if display then
			display:PivotTo(base.CFrame * CFrame.new(0, 3 - elapsed / Config.BoxTakeTime * 2.5, 0) * CFrame.Angles(0, math.rad(90), 0))
		end
		task.wait(0.1)
	end
end

local function onTriggered(player: Player)
	if state == "Idle" then
		if not PointsService.spend(player, Config.BoxPrice) then
			Remotes.Notify:FireClient(player, "Pontos insuficientes")
			return
		end
		BoxService.owner = player
		task.spawn(roll, player)
	elseif state == "Ready" then
		if player ~= BoxService.owner then
			Remotes.Notify:FireClient(player, "Essa arma é de outro jogador")
			return
		end
		local weaponId = display and display.Name
		if weaponId then
			WeaponService.giveWeapon(player, weaponId)
		end
		token += 1
		closeBox()
	end
end

BoxService.owner = nil :: Player?

function BoxService.init()
	buildBox()
	prompt.Triggered:Connect(onTriggered)
end

-- Fim da partida: a caixa some (cancela qualquer sorteio rolando)
function BoxService.hide()
	token += 1
	BoxService.owner = nil
	clearDisplay()
	state = "Idle"
	if model then
		model.Parent = nil
	end
end

-- Começo de cada partida (com a fase já no Workspace): caixa fechada num ponto sorteado
function BoxService.reset()
	token += 1
	BoxService.owner = nil
	clearDisplay()

	local spots = {}
	for _, spot in CollectionService:GetTagged("BoxSpot") do
		if spot:IsA("BasePart") and spot:IsDescendantOf(Workspace) then
			table.insert(spots, spot)
		end
	end
	if #spots == 0 then
		warn("[BoxService] Nenhuma parte com a tag 'BoxSpot' no mapa; a Caixa Surpresa fica escondida")
		if model then
			model.Parent = nil
		end
		return
	end
	if model then
		model.Parent = Workspace
	end

	-- um lugar por área do mapa; sorteia um e a caixa fica lá a partida toda
	local spot = spots[math.random(#spots)]
	base.CFrame = spot.CFrame * CFrame.new(0, spot.Size.Y / 2 + BOX_SIZE.Y / 2, 0)

	-- avisa onde ela apareceu (depois que todo mundo já entrou na partida)
	local area = spot:GetAttribute("Area")
	if typeof(area) == "string" then
		task.delay(6, function()
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("InMatch") == true then
					Remotes.Notify:FireClient(player, `Caixa Surpresa: {area}`)
				end
			end
		end)
	end
	lid.CFrame = lidCFrame(0)
	glow.Brightness = 1.5
	glow.Range = 14
	state = "Idle"
	setIdlePrompt()
end

return BoxService
