-- Aparência dos zumbis: monta vários modelos diferentes (pele, corpo, roupa, cabelo,
-- postura) no início do servidor, pra horda não parecer um monte de clones.
--
-- Roupas, cabelos e o corpo de zumbi são itens do catálogo feitos pela própria Roblox.
-- NPC não precisa ter comprado o item. Pra trocar, pegue o ID na página do item no catálogo.

local Players = game:GetService("Players")

local ZombieAppearance = {}

local VARIANT_COUNT = 8
local BUILD_TIMEOUT = 20

-- Peles: tons de verde/cinza podre
local SKIN_COLORS = {
	Color3.fromRGB(85, 130, 70), -- verde estilo Minecraft
	Color3.fromRGB(110, 125, 75), -- verde-oliva podre
	Color3.fromRGB(140, 155, 130), -- cinza esverdeado pálido
	Color3.fromRGB(70, 95, 60), -- musgo escuro
	Color3.fromRGB(120, 135, 140), -- azulado de cadáver
}

-- Cores de roupa suja (no corpo de zumbi da Roblox a roupa faz parte do modelo 3D)
local CLOTH_COLORS = {
	Color3.fromRGB(75, 62, 50),
	Color3.fromRGB(50, 55, 70),
	Color3.fromRGB(90, 40, 35),
	Color3.fromRGB(60, 60, 60),
	Color3.fromRGB(95, 85, 60),
}

-- Cor base das pernas por baixo da calça (aparece quando a perna é arrancada)
local PANTS_COLORS = {
	Color3.fromRGB(40, 50, 75),
	Color3.fromRGB(35, 35, 38),
	Color3.fromRGB(70, 60, 45),
}

-- Pacote "Zombie" oficial da Roblox (bundle 291): tronco, braços e pernas com roupa rasgada
local ZOMBIE_BODY = {
	Torso = 37754511,
	RightArm = 37754562,
	LeftArm = 37754607,
	LeftLeg = 37754646,
	RightLeg = 37754710,
}

local SHIRTS = {
	144076358, -- Blue and Black Motorcycle Shirt
	398635081, -- Blue Plaid Shirt
	144076436, -- Grey Striped Shirt with Denim Jacket
	382537702, -- Teal Shirt
	3670737444, -- Roblox Shirt - Simple Pattern
}

local PANTS = {
	398635338, -- Ripped Skater Pants
	144076760, -- Dark Green Jeans
	382537569, -- Black Jeans
	382538503, -- Black Jeans with Sneakers
	382537806, -- Jean Shorts
}

local HAIRS = {
	26658141, -- Messy Hair
	188003563, -- Brown Hair Dude
	3814450142, -- Black Spiked Hair
	147193065, -- Brunette Shocked Hair
	62719569, -- Extreme Brown Hair
	12730109, -- Mad Scientist Hair
	81688919, -- Auburn Messy Bun
	3814481268, -- Straight Auburn Hair
}

local function pick<T>(list: { T }): T
	return list[math.random(#list)]
end

local function chance(probability: number): boolean
	return math.random() < probability
end

local function randomDescription(): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	local skin = pick(SKIN_COLORS)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin

	if chance(0.5) then
		-- corpo de zumbi da Roblox: a "roupa" é a cor do tronco e das pernas
		description.Torso = ZOMBIE_BODY.Torso
		description.RightArm = ZOMBIE_BODY.RightArm
		description.LeftArm = ZOMBIE_BODY.LeftArm
		description.LeftLeg = ZOMBIE_BODY.LeftLeg
		description.RightLeg = ZOMBIE_BODY.RightLeg
		description.TorsoColor = pick(CLOTH_COLORS)
		local legs = pick(CLOTH_COLORS)
		description.LeftLegColor = legs
		description.RightLegColor = legs
	else
		-- corpo normal com roupa do catálogo (às vezes sem camisa)
		description.TorsoColor = skin
		local legs = pick(PANTS_COLORS)
		description.LeftLegColor = legs
		description.RightLegColor = legs
		if chance(0.8) then
			description.Shirt = pick(SHIRTS)
		end
		description.Pants = pick(PANTS)
	end

	if chance(0.6) then
		description.HairAccessory = tostring(pick(HAIRS))
	end

	-- um pouco mais altos e magros que o normal, cada um de um jeito
	description.HeightScale = 0.98 + math.random() * 0.12
	description.WidthScale = 0.88 + math.random() * 0.1
	description.DepthScale = 0.9 + math.random() * 0.1

	return description
end

local function newFacePart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	return part
end

-- Tira o rosto sorridente padrão e coloca olhos brilhando + boca aberta com dentes
local function addFace(model: Model)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local face = head:FindFirstChildOfClass("Decal")
	if face then
		face:Destroy()
	end

	local front = -head.Size.Z / 2
	local features = {}
	for _, side in { -1, 1 } do
		table.insert(features, {
			part = newFacePart("Eye", Vector3.new(0.2, 0.12, 0.05), Color3.fromRGB(255, 40, 20), Enum.Material.Neon),
			offset = CFrame.new(side * 0.22, 0.12, front),
		})
	end
	table.insert(features, {
		part = newFacePart("Mouth", Vector3.new(0.42, 0.16, 0.05), Color3.fromRGB(30, 5, 5), Enum.Material.SmoothPlastic),
		offset = CFrame.new(0, -0.24, front),
	})
	for _, x in { -0.12, 0.04, 0.14 } do
		table.insert(features, {
			part = newFacePart("Tooth", Vector3.new(0.06, 0.07, 0.06), Color3.fromRGB(200, 190, 150), Enum.Material.SmoothPlastic),
			offset = CFrame.new(x, -0.19, front - 0.01),
		})
	end

	for _, feature in features do
		local part = feature.part
		part.CFrame = head.CFrame * feature.offset
		local weld = Instance.new("Weld")
		weld.Part0 = head
		weld.Part1 = part
		weld.C0 = feature.offset
		weld.Parent = part
		part.Parent = model
	end
end

-- Corcunda: tronco caído pra frente e cabeça torta
local function addPosture(model: Model)
	local upperTorso = model:FindFirstChild("UpperTorso")
	local waist = upperTorso and upperTorso:FindFirstChild("Waist")
	if waist and waist:IsA("Motor6D") then
		waist.C0 *= CFrame.Angles(math.rad(-(10 + math.random() * 12)), 0, 0)
	end
	local head = model:FindFirstChild("Head")
	local neck = head and head:FindFirstChild("Neck")
	if neck and neck:IsA("Motor6D") then
		neck.C0 *= CFrame.Angles(math.rad(8), 0, math.rad(math.random(-15, 15)))
	end
end

local function buildVariant(description: HumanoidDescription): Model
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = "Zombie"

	-- NPC não precisa dos scripts padrão de personagem
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	-- o ZombieService mexe no HipHeight na mão quando o zumbi perde as pernas
	humanoid.AutomaticScalingEnabled = false
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end

	addFace(model)
	addPosture(model)

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Zombies"
			-- cabelo não pode "segurar" a bala: o tiro tem que atravessar e pegar na cabeça
			if descendant:FindFirstAncestorOfClass("Accessory") then
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.Massless = true
			end
		end
	end

	return model
end

-- Monta os modelos em paralelo (cada um carrega itens do catálogo)
function ZombieAppearance.buildVariants(): { Model }
	local variants: { Model } = {}
	local pending = VARIANT_COUNT

	for _ = 1, VARIANT_COUNT do
		task.spawn(function()
			local ok, result = pcall(buildVariant, randomDescription())
			if ok then
				table.insert(variants, result)
			else
				warn(`[ZombieAppearance] Falha ao montar um zumbi: {result}`)
			end
			pending -= 1
		end)
	end

	local started = os.clock()
	while pending > 0 and os.clock() - started < BUILD_TIMEOUT do
		task.wait(0.1)
	end

	-- se o catálogo falhar de vez, monta um zumbi básico sem itens
	if #variants == 0 then
		local description = Instance.new("HumanoidDescription")
		local skin = SKIN_COLORS[1]
		description.HeadColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.TorsoColor = CLOTH_COLORS[1]
		description.LeftLegColor = PANTS_COLORS[1]
		description.RightLegColor = PANTS_COLORS[1]
		local ok, result = pcall(buildVariant, description)
		if ok then
			table.insert(variants, result)
		end
	end

	return variants
end

return ZombieAppearance
