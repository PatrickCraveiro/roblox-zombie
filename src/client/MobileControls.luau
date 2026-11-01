-- Controles de toque (celular e tablet): botões no lado direito da tela pra atirar, mirar,
-- recarregar, trocar de arma, correr e pregar tábuas. Andar é o analógico da Roblox (lado
-- esquerdo) e girar a câmera é arrastar o dedo na tela; segurando o TIRO, arrastar o mesmo dedo
-- também gira a câmera (dá pra atirar e mirar ao mesmo tempo).
--
-- Os botões aparecem quando a pessoa toca na tela e somem se ela usar teclado ou controle.
-- MIRA e CORRER ligam/desligam com um toque; TIRO e PREGAR funcionam enquanto segura.
-- Pra testar no Studio: aba Testar → Dispositivo → escolha um celular e aperte Play.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local MobileControls = {}

local DRAG_SENSITIVITY = 0.006 -- giro da câmera por pixel arrastado no TIRO (menos com zoom)
local SMALL_SCREEN_SCALE = 0.6 -- celular pequeno: botões menores e mais perto do canto
local MIN_BUTTON = 48 -- menor tamanho de botão (dedo)

-- Centro de cada botão (distância do canto de baixo à direita) e tamanho, na tela grande.
-- Ficam em volta do botão de pulo da Roblox, sem encostar nele.
local LAYOUT = {
	{ id = "Fire", text = "TIRO", color = Color3.fromRGB(205, 40, 40), x = 250, y = 170, size = 110 },
	{ id = "Aim", text = "MIRA", color = Color3.fromRGB(50, 110, 200), x = 150, y = 290, size = 75 },
	{ id = "Reload", text = "RECARGA", color = Color3.fromRGB(60, 60, 70), x = 340, y = 70, size = 65 },
	{ id = "Swap", text = "TROCAR", color = Color3.fromRGB(60, 60, 70), x = 60, y = 290, size = 65 },
	{ id = "Sprint", text = "CORRER", color = Color3.fromRGB(60, 60, 70), x = 370, y = 200, size = 65 },
	{ id = "Repair", text = "PREGAR", color = Color3.fromRGB(150, 100, 45), x = 250, y = 310, size = 75 },
}
local LIT_COLOR = Color3.fromRGB(255, 200, 40) -- botão ligado (MIRA/CORRER) ou apertado

local weapons
local barricades
local hud

local gui: ScreenGui
local buttons: { [string]: { button: TextButton, color: Color3 } } = {}
local active = false
local fireInput: InputObject? = nil -- dedo que está segurando o TIRO
local repairInput: InputObject? = nil
local dragDelta = Vector2.zero

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function setLit(id: string, lit: boolean)
	local entry = buttons[id]
	if entry then
		entry.button.BackgroundColor3 = if lit then LIT_COLOR else entry.color
	end
end

local function makeButton(info, scale: number): TextButton
	local size = math.max(info.size * scale, MIN_BUTTON)
	local button = Instance.new("TextButton")
	button.Name = info.id
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.new(1, -info.x * scale, 1, -info.y * scale)
	button.Size = UDim2.fromOffset(size, size)
	button.BackgroundColor3 = info.color
	button.BackgroundTransparency = 0.3
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBlack
	button.Text = info.text
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = button
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0.2, 0)
	end
	padding.Parent = button

	buttons[info.id] = { button = button, color = info.color }
	return button
end

local function releaseAll()
	if fireInput then
		fireInput = nil
		weapons.setTrigger(false)
	end
	if repairInput then
		repairInput = nil
		barricades.setHolding(false)
	end
	dragDelta = Vector2.zero
end

-- Monta (ou remonta, se a tela mudar de tamanho) os botões
local function build()
	releaseAll()
	for _, entry in buttons do
		entry.button:Destroy()
	end
	table.clear(buttons)

	local viewport = Workspace.CurrentCamera.ViewportSize
	local scale = if math.min(viewport.X, viewport.Y) <= 500 then SMALL_SCREEN_SCALE else 1
	for _, info in LAYOUT do
		makeButton(info, scale)
	end

	buttons.Fire.button.InputBegan:Connect(function(input)
		if isPress(input) and not fireInput then
			fireInput = input
			weapons.setTrigger(true)
		end
	end)
	buttons.Repair.button.InputBegan:Connect(function(input)
		if isPress(input) and not repairInput then
			repairInput = input
			barricades.setHolding(true)
		end
	end)
	buttons.Aim.button.InputBegan:Connect(function(input)
		if isPress(input) then
			weapons.toggleAim()
		end
	end)
	buttons.Sprint.button.InputBegan:Connect(function(input)
		if isPress(input) then
			weapons.toggleSprint()
		end
	end)
	buttons.Reload.button.InputBegan:Connect(function(input)
		if isPress(input) then
			weapons.reload()
		end
	end)
	buttons.Swap.button.InputBegan:Connect(function(input)
		if isPress(input) then
			weapons.nextWeapon()
		end
	end)
end

local function setActive(enabled: boolean)
	if active == enabled then
		return
	end
	active = enabled
	releaseAll()
	gui.Enabled = enabled
	weapons.setTouchMode(enabled)
	barricades.setTouchMode(enabled)
	hud.setTouchLayout(enabled)
end

-- Arrastar o dedo que segura o TIRO gira a câmera (roda antes da câmera da Roblox, que continua
-- a partir de onde a gente deixou)
local function applyDrag()
	if dragDelta.Magnitude == 0 then
		return
	end
	local camera = Workspace.CurrentCamera
	local delta = dragDelta * DRAG_SENSITIVITY * camera.FieldOfView / 70
	dragDelta = Vector2.zero

	local current = camera.CFrame
	local yaw = CFrame.Angles(0, -delta.X, 0)
	local rotation = yaw * current.Rotation * CFrame.Angles(-delta.Y, 0, 0)
	if math.abs(rotation.LookVector.Y) > 0.97 then
		rotation = yaw * current.Rotation -- não deixa virar de cabeça pra baixo
	end
	camera.CFrame = CFrame.new(current.Position) * rotation
end

-- Acende MIRA/CORRER quando estão ligados e mostra TROCAR/PREGAR só quando dá pra usar
local function updateButtons()
	if not active then
		return
	end
	gui.Enabled = not player:GetAttribute("UiOpen") -- janela do Arsenal aberta: some
	local state = weapons.getState()
	setLit("Aim", state.aiming)
	setLit("Sprint", state.sprinting)
	setLit("Fire", fireInput ~= nil)
	setLit("Repair", repairInput ~= nil)
	buttons.Swap.button.Visible = state.weaponCount > 1
	buttons.Repair.button.Visible = barricades.isAvailable() or repairInput ~= nil
end

function MobileControls.init(weaponController, barricadeController, hudController)
	weapons, barricades, hud = weaponController, barricadeController, hudController

	gui = Instance.new("ScreenGui")
	gui.Name = "TouchControls"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 2
	gui.Parent = player:WaitForChild("PlayerGui")
	build()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(build)

	-- soltou o dedo (mesmo fora do botão)
	UserInputService.InputEnded:Connect(function(input)
		if input == fireInput then
			fireInput = nil
			weapons.setTrigger(false)
		elseif input == repairInput then
			repairInput = nil
			barricades.setHolding(false)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input == fireInput and input.UserInputType == Enum.UserInputType.Touch then
			dragDelta += Vector2.new(input.Delta.X, input.Delta.Y)
		end
	end)
	RunService:BindToRenderStep("TouchCameraDrag", Enum.RenderPriority.Camera.Value - 1, applyDrag)
	RunService.Heartbeat:Connect(updateButtons)

	-- aparece com toque; some com teclado ou controle de videogame
	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		if inputType == Enum.UserInputType.Touch then
			setActive(true)
		elseif inputType == Enum.UserInputType.Keyboard or string.find(inputType.Name, "Gamepad") then
			setActive(false)
		end
	end)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		setActive(true)
	end
end

return MobileControls
