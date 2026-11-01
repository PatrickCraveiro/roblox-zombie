-- Armas compráveis na parede. Qualquer BasePart com a tag "WallBuy" e o atributo
-- "WeaponId" vira um ponto de compra. Atributo opcional "Price" muda o preço.
-- A arma aparece em 3D na frente da placa (face Front), com nome e preço numa faixa embaixo.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Premium = require(ReplicatedStorage.Shared.Premium)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local PointsService = require(script.Parent.PointsService)
local PremiumService = require(script.Parent.PremiumService)
local WeaponService = require(script.Parent.WeaponService)

local Remotes = ReplicatedStorage.Remotes

local WallBuyService = {}

local LABEL_HEIGHT = 0.28 -- faixa do nome/preço (fração da altura da placa)
local FRAME_COLOR = Color3.fromRGB(255, 200, 40)

-- Moldura amarela e a faixa de baixo com nome e preço (arma premium ganha a estrelinha)
local function createLabel(part: BasePart, title: string, price: number, premium: boolean)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = FRAME_COLOR
	stroke.Thickness = 6
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = UDim2.fromScale(0, 1)
	label.Size = UDim2.fromScale(1, LABEL_HEIGHT)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(240, 240, 230)
	label.RichText = true
	local priceText = if price == 0 then "GRÁTIS" else `{price} pts`
	label.Text = `{if premium then "★ " else ""}{string.upper(title)}  <font color="#FFC828">{priceText}</font>`
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.Parent = label
end

-- A arma em 3D presa na placa: deitada de lado, com o cano pra direita de quem olha,
-- do maior tamanho que couber em cima da faixa do nome
local function mountWeapon(part: BasePart, weaponId: string)
	local model = WeaponModels.build(weaponId, true)
	model.Name = "WallWeapon_" .. weaponId

	local areaHeight = part.Size.Y * (1 - LABEL_HEIGHT)
	local areaCenter = part.CFrame * CFrame.new(0, part.Size.Y / 2 - areaHeight / 2, -part.Size.Z / 2)

	-- tamanho original: comprimento no Z da arma, altura no Y
	local _, size = model:GetBoundingBox()
	local scale = math.min(part.Size.X * 0.85 / size.Z, areaHeight * 0.8 / size.Y)
	model:ScaleTo(scale)
	model:PivotTo(areaCenter * CFrame.Angles(0, math.rad(90), 0))

	-- centraliza a arma na área e encosta ela na placa
	local bounds, scaledSize = model:GetBoundingBox()
	local target = areaCenter * CFrame.new(0, 0, -scaledSize.X / 2 - 0.05)
	model:PivotTo(model:GetPivot() + (target.Position - bounds.Position))
	model.Parent = part.Parent

	-- luzinha pra arma aparecer mesmo no escuro
	local light = Instance.new("PointLight")
	light.Range = 7
	light.Brightness = 1
	light.Shadows = false
	light.Parent = part
end

local function setupWallBuy(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local weaponId = instance:GetAttribute("WeaponId")
	local def = if typeof(weaponId) == "string" then Weapons[weaponId] else nil
	if not def then
		warn(`[WallBuy] "{instance:GetFullName()}" tem WeaponId inválido: {weaponId}`)
		return
	end

	local price = instance:GetAttribute("Price") or def.Price
	local ammoPrice = math.floor(price / 2)

	createLabel(instance, def.Name, price, def.Pass ~= nil)
	mountWeapon(instance, weaponId)

	-- arma premium na parede (com preço): só compra quem tem o passe
	local passName = if def.Pass and price > 0 and Premium.Passes[def.Pass] then Premium.Passes[def.Pass].Name else nil

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = (if price == 0 then "Pegar " else "Comprar ") .. def.Name
	prompt.ObjectText = if price == 0
		then (if def.Pass then "Grátis pra testar (premium)" else "Grátis")
		elseif passName then string.format("%d pts  |  ★ %s", price, passName)
		else string.format("%d pts  |  munição: %d pts", price, ammoPrice)
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = instance

	prompt.Triggered:Connect(function(player)
		if passName and not PremiumService.owns(player, def.Pass :: string) then
			PremiumService.prompt(player, def.Pass :: string) -- mostra a loja do passe
			return
		end
		local owned = WeaponService.findSlot(player, weaponId) ~= nil
		local cost = if owned then ammoPrice else price
		if PointsService.spend(player, cost) then
			WeaponService.giveWeapon(player, weaponId)
		else
			Remotes.Notify:FireClient(player, "Pontos insuficientes")
		end
	end)
end

function WallBuyService.init()
	CollectionService:GetInstanceAddedSignal("WallBuy"):Connect(setupWallBuy)
	for _, instance in CollectionService:GetTagged("WallBuy") do
		setupWallBuy(instance)
	end
end

return WallBuyService
