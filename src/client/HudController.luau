-- Interface na tela: rodada, pontos, munição, mira, avisos e tela de morte.
-- Tudo criado por código pra ficar versionado junto com o resto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Progression = require(Shared:WaitForChild("Progression"))
local Shop = require(Shared:WaitForChild("Shop"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Weapons = require(Shared:WaitForChild("Weapons"))

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local HudController = {}

local BLOOD_RED = Color3.fromRGB(180, 20, 20)
local WHITE = Color3.fromRGB(240, 240, 240)
local GOLD = Color3.fromRGB(255, 220, 120)

local gui: ScreenGui
local roundLabel: TextLabel
local remainingLabel: TextLabel
local pointsLabel: TextLabel
local weaponLabel: TextLabel
local ammoLabel: TextLabel
local hintLabel: TextLabel
local actionHintLabel: TextLabel
local headshotLabel: TextLabel
local titleLabel: TextLabel
local subtitleLabel: TextLabel
local toastLabel: TextLabel
local lobbyHintLabel: TextLabel
local coinsLabel: TextLabel
local progressLabel: TextLabel
local portalLabel: TextLabel
local damageOverlay: Frame
local perksFrame: Frame
local crosshair: Frame
local hitmarker: Frame
local scopeFrame: Frame
local deathScreen: Frame

local announceToken = 0
local toastToken = 0
local hitToken = 0
local modeChangedAt = 0

-- Setas de dano: apontam pra onde o zumbi estava quando bateu (mesmo se você virar)
local HIT_ARROW_RADIUS = 130 -- distância do meio da tela, em pixels
local HIT_ARROW_TIME = 1.2
local HIT_ARROW_COLOR = Color3.fromRGB(230, 20, 20)

type HitArrow = { frame: Frame, position: Vector3, startedAt: number }
local hitArrows: { HitArrow } = {}

local function inMatch(): boolean
	return player:GetAttribute("InMatch") == true
end

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function makeText(props: { [string]: any }, parent: Instance): TextLabel
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		Text = "",
	}, parent)
	for key, value in props do
		(label :: any)[key] = value
	end
	-- contorno pra dar pra ler em qualquer fundo
	make("UIStroke", { Thickness = 1.5, Transparency = 0.3 }, label)
	return label
end

local function fadeText(label: TextLabel, transparency: number, duration: number)
	local info = TweenInfo.new(duration)
	TweenService:Create(label, info, { TextTransparency = transparency }):Play()
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, info, { Transparency = math.max(transparency, 0.3) }):Play()
	end
end

local function build()
	gui = make("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	damageOverlay = make("Frame", {
		Name = "Damage",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(150, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, gui)

	-- Canto inferior esquerdo: rodada
	roundLabel = makeText({
		Name = "Round",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 40, 1, -20),
		Size = UDim2.fromOffset(300, 110),
		Font = Enum.Font.Creepster,
		TextSize = 110,
		TextColor3 = BLOOD_RED,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, gui)
	remainingLabel = makeText({
		Name = "Remaining",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 44, 1, -135),
		Size = UDim2.fromOffset(300, 24),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, gui)

	-- Selos das melhorias compradas na loja (em cima da rodada)
	perksFrame = make("Frame", {
		Name = "Perks",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 44, 1, -165),
		Size = UDim2.fromOffset(500, 26),
		BackgroundTransparency = 1,
	}, gui)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, perksFrame)

	-- Canto inferior direito: pontos, arma e munição
	pointsLabel = makeText({
		Name = "Points",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -40, 1, -130),
		Size = UDim2.fromOffset(250, 40),
		TextSize = 34,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, gui)
	weaponLabel = makeText({
		Name = "Weapon",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -40, 1, -85),
		Size = UDim2.fromOffset(300, 22),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, gui)
	ammoLabel = makeText({
		Name = "Ammo",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -40, 1, -30),
		Size = UDim2.fromOffset(300, 50),
		TextSize = 44,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, gui)

	-- Mira
	crosshair = make("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
	}, gui)
	for _, direction in { Vector2.new(0, -1), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(1, 0) } do
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, direction.X * 12, 0.5, direction.Y * 12),
			Size = if direction.X ~= 0 then UDim2.fromOffset(10, 2) else UDim2.fromOffset(2, 10),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		}, crosshair)
	end

	-- Marcador de acerto (o "X" no meio da tela)
	hitmarker = make("Frame", {
		Name = "Hitmarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	for _, info in { { -1, -1, 45 }, { 1, -1, -45 }, { -1, 1, -45 }, { 1, 1, 45 } } do
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, info[1] * 9, 0.5, info[2] * 9),
			Size = UDim2.fromOffset(9, 2),
			Rotation = info[3],
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		}, hitmarker)
	end

	-- Luneta: círculo transparente e tudo em volta preto (uma borda gigante num círculo)
	scopeFrame = make("Frame", {
		Name = "Scope",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
	}, gui)
	local lens = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.85, 0.85),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, scopeFrame)
	make("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }, lens)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, lens)
	make("UIStroke", { Thickness = 2000, Color = Color3.new(0, 0, 0) }, lens)
	for _, size in { UDim2.new(1, 0, 0, 2), UDim2.new(0, 2, 1, 0) } do
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = size,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, lens)
	end

	hintLabel = makeText({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 40),
		Size = UDim2.fromOffset(400, 30),
		TextSize = 20,
	}, gui)

	-- Ação disponível perto (ex: pregar tábua na barricada)
	actionHintLabel = makeText({
		Name = "ActionHint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 75),
		Size = UDim2.fromOffset(600, 28),
		TextSize = 22,
		TextColor3 = GOLD,
	}, gui)

	-- "HEADSHOT!" em cima da mira quando mata com tiro na cabeça
	headshotLabel = makeText({
		Name = "Headshot",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.5, -45),
		Size = UDim2.fromOffset(500, 44),
		Font = Enum.Font.GothamBlack,
		TextSize = 34,
		TextColor3 = Color3.fromRGB(255, 200, 40),
		TextTransparency = 1,
	}, gui)

	-- Dica no topo da tela enquanto está no lobby
	lobbyHintLabel = makeText({
		Name = "LobbyHint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(800, 26),
		TextSize = 20,
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Text = "LOBBY  •  Pare na porta de uma fase pra jogar  •  Treinamento no prédio à esquerda",
	}, gui)

	-- moedas (ganhas jogando, gastas no Arsenal do lobby)
	coinsLabel = makeText({
		Name = "Coins",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(400, 30),
		TextSize = 24,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 200, 40),
	}, gui)

	-- embaixo das moedas: próxima arma do Arsenal e o cargo de aura
	progressLabel = makeText({
		Name = "Progress",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.fromOffset(800, 44),
		TextSize = 18,
		RichText = true,
		TextColor3 = Color3.fromRGB(230, 230, 235),
	}, gui)

	-- Contagem do portal (aparece enquanto o jogador está em cima de um)
	portalLabel = makeText({
		Name = "Portal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(900, 80),
		TextSize = 34,
		TextColor3 = GOLD,
		Font = Enum.Font.GothamBlack,
	}, gui)

	toastLabel = makeText({
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.62, 0),
		Size = UDim2.fromOffset(600, 28),
		TextSize = 22,
		TextColor3 = Color3.fromRGB(255, 120, 120),
	}, gui)

	-- Tela de morte
	deathScreen = make("Frame", {
		Name = "Death",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 5,
	}, gui)
	makeText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(800, 90),
		Font = Enum.Font.Creepster,
		TextSize = 80,
		TextColor3 = BLOOD_RED,
		Text = "MORTO",
		ZIndex = 6,
	}, deathScreen)
	makeText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.45, 60),
		Size = UDim2.fromOffset(800, 30),
		TextSize = 22,
		Text = "Você volta no fim da rodada",
		ZIndex = 6,
	}, deathScreen)

	-- Anúncios grandes (por cima de tudo)
	titleLabel = makeText({
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(900, 100),
		Font = Enum.Font.Creepster,
		TextSize = 90,
		TextColor3 = BLOOD_RED,
		TextTransparency = 1,
		ZIndex = 10,
	}, gui)
	subtitleLabel = makeText({
		Name = "Subtitle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.3, 65),
		Size = UDim2.fromOffset(900, 60),
		TextSize = 24,
		TextTransparency = 1,
		ZIndex = 10,
	}, gui)
end

local function announce(title: string, subtitle: string?, duration: number?)
	announceToken += 1
	local token = announceToken
	titleLabel.Text = title
	subtitleLabel.Text = subtitle or ""
	fadeText(titleLabel, 0, 0.3)
	fadeText(subtitleLabel, 0, 0.3)
	task.delay(duration or 3, function()
		if token == announceToken then
			fadeText(titleLabel, 1, 0.6)
			fadeText(subtitleLabel, 1, 0.6)
		end
	end)
end

local function popPoints(delta: number)
	local label = makeText({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -200, 1, -135),
		Size = UDim2.fromOffset(100, 30),
		TextSize = 22,
		TextColor3 = if delta > 0 then GOLD else Color3.fromRGB(255, 90, 90),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = (if delta > 0 then "+" else "") .. delta,
	}, gui)
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, {
		Position = label.Position + UDim2.fromOffset(math.random(-40, 0), -50),
	}):Play()
	fadeText(label, 1, 0.8)
	task.delay(0.8, function()
		label:Destroy()
	end)
end

local function trackPoints()
	local leaderstats = player:WaitForChild("leaderstats")
	local points = leaderstats:WaitForChild("Pontos") :: IntValue
	local last = points.Value
	pointsLabel.Text = tostring(last)
	points.Changed:Connect(function(value)
		local delta = value - last
		last = value
		pointsLabel.Text = tostring(value)
		-- logo depois de entrar na partida os pontos são zerados: não mostra esse "pulo"
		if delta ~= 0 and inMatch() and os.clock() - modeChangedAt > 1 then
			popPoints(delta)
		end
	end)
end

local headshotToken = 0

local function showHeadshot()
	headshotToken += 1
	local token = headshotToken
	headshotLabel.Text = `HEADSHOT!  +{Config.HeadshotBonus}`
	headshotLabel.TextSize = 44
	fadeText(headshotLabel, 0, 0.1)
	TweenService:Create(headshotLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back), { TextSize = 34 }):Play()
	task.delay(1, function()
		if token == headshotToken then
			fadeText(headshotLabel, 1, 0.4)
		end
	end)
end

-- Um selo colorido por melhoria que o jogador tem (somem quando ele perde)
local function trackPerks()
	local order = 0
	for _, item in Shop do
		local attribute = item.Attribute
		if not attribute then
			continue
		end
		order += 1
		local badge = makeText({
			Name = attribute,
			LayoutOrder = order,
			Size = UDim2.fromOffset(110, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0.15,
			BackgroundColor3 = item.Color,
			TextSize = 15,
			Font = Enum.Font.GothamBlack,
			Text = item.Short or item.Name,
			Visible = false,
		}, perksFrame)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, badge)
		make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, badge)
		local function update()
			badge.Visible = player:GetAttribute(attribute) == true
		end
		player:GetAttributeChangedSignal(attribute):Connect(update)
		update()
	end
end

local function trackHeadshots()
	local headshots = player:WaitForChild("leaderstats"):WaitForChild("Headshots") :: IntValue
	local last = headshots.Value
	headshots.Changed:Connect(function(value)
		local increased = value > last
		last = value
		if increased and inMatch() then
			showHeadshot()
		end
	end)
end

-- Arma e munição aparecem sempre; rodada e pontos só na partida; no lobby, a dica no topo
local function applyMode()
	modeChangedAt = os.clock()
	local playing = inMatch()

	roundLabel.Visible = playing
	remainingLabel.Visible = playing
	pointsLabel.Visible = playing
	lobbyHintLabel.Visible = not playing
	coinsLabel.Visible = not playing
	progressLabel.Visible = not playing

	if not playing then
		deathScreen.Visible = false
		damageOverlay.BackgroundTransparency = 1
	end
end

local function trackGameState()
	local function updateRound()
		local round = ReplicatedStorage:GetAttribute("Round") or 0
		roundLabel.Text = if round > 0 then tostring(round) else ""
	end
	local function updateRemaining()
		local state = ReplicatedStorage:GetAttribute("GameState")
		local remaining = ReplicatedStorage:GetAttribute("ZombiesRemaining") or 0
		remainingLabel.Text = if state == "Round" then `Zumbis restantes: {remaining}` else ""
	end
	local function updateCountdown()
		if inMatch() and ReplicatedStorage:GetAttribute("GameState") == "Intermission" then
			local seconds = ReplicatedStorage:GetAttribute("Countdown") or 0
			announce("PREPARE-SE", `Começa em {seconds}`, 1.5)
		end
	end

	ReplicatedStorage:GetAttributeChangedSignal("Round"):Connect(updateRound)
	ReplicatedStorage:GetAttributeChangedSignal("ZombiesRemaining"):Connect(updateRemaining)
	ReplicatedStorage:GetAttributeChangedSignal("GameState"):Connect(updateRemaining)
	ReplicatedStorage:GetAttributeChangedSignal("Countdown"):Connect(updateCountdown)
	updateRound()
	updateRemaining()
end

local function trackCharacter(character: Model)
	deathScreen.Visible = false
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local lastHealth = humanoid.Health

	local function updateHealth(health: number)
		local missing = 1 - math.clamp(health / humanoid.MaxHealth, 0, 1)
		local target = 1 - missing * 0.45
		if health < lastHealth then
			-- piscada vermelha ao levar dano
			damageOverlay.BackgroundTransparency = math.max(target - 0.3, 0.2)
			TweenService:Create(damageOverlay, TweenInfo.new(0.4), { BackgroundTransparency = target }):Play()
		else
			damageOverlay.BackgroundTransparency = target
		end
		lastHealth = health
	end

	humanoid.HealthChanged:Connect(updateHealth)
	updateHealth(humanoid.Health)
	humanoid.Died:Connect(function()
		damageOverlay.BackgroundTransparency = 1
		deathScreen.Visible = inMatch()
	end)
end

-- color = cor do nome (arma turbinada); nil = branco
function HudController.setWeapon(name: string, mag: number?, reserve: number?, low: boolean?, color: Color3?)
	weaponLabel.Text = string.upper(name)
	weaponLabel.TextColor3 = color or WHITE
	if mag and reserve then
		local magColor = if low then "#FF4040" else "#F0F0F0"
		ammoLabel.Text = string.format('<font color="%s">%d</font><font size="24" color="#B4B4B4"> / %d</font>', magColor, mag, reserve)
	else
		ammoLabel.Text = ""
	end
end

function HudController.setHint(text: string)
	hintLabel.Text = text
end

function HudController.setActionHint(text: string)
	if actionHintLabel.Text ~= text then
		actionHintLabel.Text = text
	end
end

function HudController.setCrosshairVisible(visible: boolean)
	crosshair.Visible = visible
end

function HudController.setScope(visible: boolean)
	scopeFrame.Visible = visible
end

function HudController.showHitmarker()
	hitToken += 1
	local token = hitToken
	hitmarker.Visible = true
	task.delay(0.12, function()
		if token == hitToken then
			hitmarker.Visible = false
		end
	end)
end

-- Seta vermelha (^) em volta da mira, apontando pra "position" (onde estava o zumbi)
function HudController.showHitDirection(position: Vector3)
	local frame = make("Frame", {
		Name = "HitArrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(70, 40),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, gui)
	-- duas barras inclinadas formando a ponta da seta
	for _, side in { -1, 1 } do
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, side * 14, 0.5, 0),
			Size = UDim2.fromOffset(36, 8),
			Rotation = side * 35,
			BackgroundColor3 = HIT_ARROW_COLOR,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, frame)
	end
	table.insert(hitArrows, { frame = frame, position = position, startedAt = os.clock() })
end

local function updateHitArrows()
	if #hitArrows == 0 then
		return
	end
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	for index = #hitArrows, 1, -1 do
		local arrow = hitArrows[index]
		local age = now - arrow.startedAt
		if age >= HIT_ARROW_TIME then
			arrow.frame:Destroy()
			table.remove(hitArrows, index)
			continue
		end
		-- ângulo do zumbi visto de cima: 0 = na frente, positivo = à direita, 180 = atrás
		local offset = camera.CFrame:PointToObjectSpace(arrow.position)
		local angle = math.atan2(offset.X, -offset.Z)
		arrow.frame.Position = UDim2.new(0.5, math.sin(angle) * HIT_ARROW_RADIUS, 0.5, -math.cos(angle) * HIT_ARROW_RADIUS)
		arrow.frame.Rotation = math.deg(angle)
		-- some devagar no último meio segundo
		local fade = math.clamp((age - (HIT_ARROW_TIME - 0.5)) / 0.5, 0, 1)
		for _, bar in arrow.frame:GetChildren() do
			(bar :: Frame).BackgroundTransparency = fade
		end
	end
end

function HudController.notify(text: string)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	task.delay(2, function()
		if token == toastToken then
			toastLabel.Text = ""
		end
	end)
end

function HudController.init()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	build()
	trackGameState()
	task.spawn(trackPoints)
	task.spawn(trackHeadshots)
	trackPerks()

	player:GetAttributeChangedSignal("InMatch"):Connect(applyMode)
	local function updateProgress()
		local coins = player:GetAttribute("Coins") or 0
		coinsLabel.Text = `MOEDAS: {Progression.format(coins)}`

		local nextId, price = Progression.nextWeapon(Progression.parseOwned(player:GetAttribute("OwnedWeapons")))
		local weaponLine = if not nextId
			then "Você liberou todas as armas do Arsenal!"
			elseif coins >= price then `Já dá pra liberar: <b>{Weapons[nextId].Name}</b> (no Arsenal)`
			else `Próxima arma: <b>{Weapons[nextId].Name}</b> (faltam {Progression.format(price - coins)} moedas)`

		local points = player:GetAttribute("TotalPoints") or 0
		local index = Progression.rankIndex(points)
		local rank, nextRank = Progression.Ranks[index], Progression.Ranks[index + 1]
		local nextText = if nextRank
			then `  →  próximo: {nextRank.Name} (faltam {Progression.format(nextRank.Points - points)} pts)`
			else "  (cargo máximo!)"
		local rankLine = `Cargo: <font color="#{rank.Color:ToHex()}"><b>{rank.Name}</b></font>{nextText}`
		progressLabel.Text = weaponLine .. "\n" .. rankLine
	end
	for _, attribute in { "Coins", "OwnedWeapons", "TotalPoints" } do
		player:GetAttributeChangedSignal(attribute):Connect(updateProgress)
	end
	updateProgress()
	applyMode()

	local function updatePortal()
		local status = player:GetAttribute("PortalStatus")
		portalLabel.Text = if typeof(status) == "string" then status else ""
	end
	player:GetAttributeChangedSignal("PortalStatus"):Connect(updatePortal)
	updatePortal()

	player.CharacterAdded:Connect(trackCharacter)
	if player.Character then
		task.spawn(trackCharacter, player.Character)
	end

	Remotes:WaitForChild("Announce").OnClientEvent:Connect(function(title, subtitle, duration)
		announce(title, subtitle, if typeof(duration) == "number" then duration else nil)
	end)
	Remotes:WaitForChild("Notify").OnClientEvent:Connect(HudController.notify)

	-- levou um golpe: seta vermelha + som de pancada
	RunService.RenderStepped:Connect(updateHitArrows)
	task.spawn(function()
		Remotes:WaitForChild("HitDirection").OnClientEvent:Connect(function(position: Vector3)
			if typeof(position) == "Vector3" then
				HudController.showHitDirection(position)
				Sounds.play(Sounds.Ids.PlayerHurt, nil, 0.7, Sounds.randomPitch(0.2))
			end
		end)
	end)
end

return HudController
