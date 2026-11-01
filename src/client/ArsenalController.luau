-- Janela do Arsenal (lobby): todas as armas com o modelo 3D, o preço em moedas e o botão pra
-- liberar ou escolher com qual começar a partida. As VIP abrem a loja do passe.
-- Abre pelo botão "OpenArsenal" da banca do lobby. O servidor (PlayerDataService) confere tudo;
-- aqui só mostra o que está nos atributos do jogador (Coins, OwnedWeapons, EquippedWeapon).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Premium = require(Shared:WaitForChild("Premium"))
local WeaponModels = require(Shared:WaitForChild("WeaponModels"))
local Weapons = require(Shared:WaitForChild("Weapons"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local ArsenalController = {}

local MAX_DISTANCE = 16 -- se afastar da banca fecha a janela
local GOLD = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(60, 200, 100)
local BLUE = Color3.fromRGB(60, 130, 230)
local GRAY = Color3.fromRGB(90, 90, 95)

local gui: ScreenGui
local grid: ScrollingFrame
local coinsLabel: TextLabel
local messageLabel: TextLabel
local openedAt: BasePart? = nil
local cards: { [string]: { status: TextLabel, button: TextButton, stroke: UIStroke } } = {}

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

-- Ordem: pistola, depois as de moeda do mais barato pro mais caro, e as VIP no fim
local function weaponOrder(): { string }
	local ids = {}
	for id, def in Weapons do
		if def.CoinPrice or def.Pass then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local defA, defB = Weapons[a], Weapons[b]
		local vipA, vipB = defA.Pass ~= nil, defB.Pass ~= nil
		if vipA ~= vipB then
			return vipB
		end
		return (defA.CoinPrice or defA.Price) < (defB.CoinPrice or defB.Price)
	end)
	return ids
end

local function ownsPass(passKey: string): boolean
	local pass = Premium.Passes[passKey]
	return pass ~= nil and player:GetAttribute(pass.Attribute) == true
end

local function isOwned(id: string): boolean
	local def = Weapons[id]
	if def.Pass then
		return ownsPass(def.Pass)
	end
	if id == Config.StartingWeapon then
		return true
	end
	local owned = player:GetAttribute("OwnedWeapons")
	return typeof(owned) == "string" and table.find(string.split(owned, ","), id) ~= nil
end

-- Atualiza moedas e o botão de cada carta
local function refresh()
	if not gui then
		return
	end
	local coins = player:GetAttribute("Coins") or 0
	coinsLabel.Text = `MOEDAS: {coins}`
	local equipped = player:GetAttribute("EquippedWeapon") or Config.StartingWeapon
	for id, card in cards do
		local def = Weapons[id]
		local owned = isOwned(id)
		if id == equipped then
			card.status.Text = "COMEÇA COM ELA"
			card.button.Text = "EQUIPADA"
			card.button.BackgroundColor3 = GREEN
			card.stroke.Color = GREEN
		elseif owned then
			card.status.Text = if def.Pass then "VIP liberada" else "Liberada"
			card.button.Text = "EQUIPAR"
			card.button.BackgroundColor3 = BLUE
			card.stroke.Color = if def.Pass then GOLD else Color3.fromRGB(70, 70, 80)
		elseif def.Pass then
			card.status.Text = "★ " .. (Premium.Passes[def.Pass] and Premium.Passes[def.Pass].Name or "VIP")
			card.button.Text = "SÓ VIP"
			card.button.BackgroundColor3 = GOLD
			card.stroke.Color = GOLD
		else
			local price = def.CoinPrice or 0
			card.status.Text = `{price} moedas`
			card.button.Text = "LIBERAR"
			card.button.BackgroundColor3 = if coins >= price then GREEN:Lerp(BLUE, 0.3) else GRAY
			card.stroke.Color = Color3.fromRGB(70, 70, 80)
		end
	end
end

local function showMessage(text: string)
	messageLabel.Text = text
end

local function onCardPressed(id: string)
	local def = Weapons[id]
	local equipped = player:GetAttribute("EquippedWeapon") or Config.StartingWeapon
	if id == equipped then
		return
	end
	local action = if isOwned(id) then "equip" elseif def.Pass then "vip" else "buy"
	local ok, result, message = pcall(function()
		return Remotes:WaitForChild("ArsenalAction"):InvokeServer(action, id)
	end)
	if ok and typeof(message) == "string" and message ~= "" then
		showMessage(message)
	elseif not ok then
		showMessage("Não deu certo, tente de novo")
	end
	refresh()
end

-- Modelo 3D da arma, de lado, dentro da carta
local function preview(id: string, parent: Instance)
	local viewport = make("ViewportFrame", {
		Size = UDim2.new(1, -12, 0, 72),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = Color3.fromRGB(30, 32, 40),
		BackgroundTransparency = 0.2,
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, -1),
	}, parent)
	local model = WeaponModels.build(id, true)
	model:PivotTo(CFrame.Angles(0, math.rad(-90), 0)) -- cano pra direita
	model.Parent = viewport
	local camera = make("Camera", { FieldOfView = 30 }, viewport)
	viewport.CurrentCamera = camera
	local bounds, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	camera.CFrame = CFrame.lookAt(bounds.Position + Vector3.new(0, radius * 0.3, radius / math.tan(math.rad(15)) * 0.75), bounds.Position)
end

local function build()
	gui = make("ScreenGui", {
		Name = "Arsenal",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		Enabled = false,
		DisplayOrder = 5,
	}, player:WaitForChild("PlayerGui"))

	local panel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(760, 500),
		BackgroundColor3 = Color3.fromRGB(18, 20, 26),
		BackgroundTransparency = 0.05,
		Active = true, -- clique no painel não vira tiro
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)
	make("UIStroke", { Color = GREEN, Thickness = 3 }, panel)

	make("TextLabel", {
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(0.6, 0, 0, 40),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(120, 255, 150),
		Text = "ARSENAL",
	}, panel)
	coinsLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -70, 0, 16),
		Size = UDim2.fromOffset(260, 32),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = GOLD,
	}, panel)
	make("TextLabel", {
		Position = UDim2.fromOffset(20, 52),
		Size = UDim2.new(1, -40, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(190, 190, 200),
		Text = "Ganhe moedas jogando (abates, headshots e rodadas). A arma EQUIPADA é a que você leva pra partida.",
	}, panel)

	-- fechar (Modal solta o mouse da primeira pessoa enquanto a janela está aberta)
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Color3.fromRGB(180, 40, 40),
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "X",
		Modal = true,
	}, panel)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, close)
	close.Activated:Connect(function()
		ArsenalController.close()
	end)

	grid = make("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 82),
		Size = UDim2.new(1, -32, 1, -128),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, panel)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(170, 150),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)

	messageLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -40, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = GOLD,
		Text = "",
	}, panel)

	for order, id in weaponOrder() do
		local def = Weapons[id]
		local card = make("Frame", {
			LayoutOrder = order,
			BackgroundColor3 = Color3.fromRGB(38, 40, 50),
		}, grid)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, card)
		local stroke = make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(70, 70, 80) }, card)
		preview(id, card)
		make("TextLabel", {
			Position = UDim2.fromOffset(6, 80),
			Size = UDim2.new(1, -12, 0, 20),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextColor3 = if def.Pass then GOLD else Color3.new(1, 1, 1),
			Text = string.upper(def.Name),
		}, card)
		local status = make("TextLabel", {
			Position = UDim2.fromOffset(6, 100),
			Size = UDim2.new(1, -12, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextScaled = true,
			TextColor3 = Color3.fromRGB(200, 200, 210),
		}, card)
		local button = make("TextButton", {
			Position = UDim2.new(0, 8, 1, -30),
			Size = UDim2.new(1, -16, 0, 24),
			Font = Enum.Font.GothamBlack,
			TextSize = 15,
			TextColor3 = Color3.new(1, 1, 1),
			AutoButtonColor = true,
		}, card)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
		button.Activated:Connect(function()
			onCardPressed(id)
		end)
		cards[id] = { status = status, button = button, stroke = stroke }
	end
end

function ArsenalController.open(at: BasePart?)
	if player:GetAttribute("InMatch") then
		return
	end
	openedAt = at
	messageLabel.Text = ""
	refresh()
	gui.Enabled = true
	player:SetAttribute("UiOpen", true) -- (local) a arma não atira com a janela aberta
	UserInputService.MouseIconEnabled = true
end

function ArsenalController.close()
	gui.Enabled = false
	openedAt = nil
	player:SetAttribute("UiOpen", nil)
	UserInputService.MouseIconEnabled = false
end

function ArsenalController.init()
	build()
	for _, attribute in { "Coins", "OwnedWeapons", "EquippedWeapon" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	for _, pass in Premium.Passes do
		player:GetAttributeChangedSignal(pass.Attribute):Connect(refresh)
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "OpenArsenal" then
			ArsenalController.open(prompt.Parent :: BasePart?)
		end
	end)

	-- fecha sozinha se o jogador se afastar da banca, entrar numa partida ou apertar Esc/Backspace
	RunService.Heartbeat:Connect(function()
		if not gui.Enabled then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local tooFar = openedAt ~= nil and root ~= nil and (root.Position - openedAt.Position).Magnitude > MAX_DISTANCE
		if tooFar or player:GetAttribute("InMatch") then
			ArsenalController.close()
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if gui.Enabled and (input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Q) then
			ArsenalController.close()
		end
	end)
end

return ArsenalController
