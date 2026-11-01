-- Efeitos visuais e sonoros: tiros locais, tiros dos outros jogadores e gore.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared:WaitForChild("Weapons"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local Effects = {}

local WAVE_COLOR = Color3.fromRGB(90, 255, 120)

local folder: Folder? = nil

-- Os efeitos ficam dentro da câmera: são locais e não atrapalham os raycasts
local function getFolder(): Folder
	local camera = Workspace.CurrentCamera
	if not folder or folder.Parent ~= camera then
		folder = Instance.new("Folder")
		folder.Name = "Effects"
		folder.Parent = camera
	end
	return folder :: Folder
end

local function newPart(size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = getFolder()
	return part
end

local function fadeAndDestroy(part: BasePart, duration: number, goal: { [string]: any }?)
	local properties = goal or {}
	properties.Transparency = 1
	local tween = TweenService:Create(part, TweenInfo.new(duration), properties)
	tween.Completed:Once(function()
		part:Destroy()
	end)
	tween:Play()
end

local function randomVector(): Vector3
	return Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
end

function Effects.tracer(from: Vector3, to: Vector3, color: Color3?)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local part = newPart(
		Vector3.new(0.06, 0.06, length),
		CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2),
		color or Color3.fromRGB(255, 220, 150),
		Enum.Material.Neon
	)
	part.Transparency = 0.4
	fadeAndDestroy(part, 0.08)
end

function Effects.muzzleFlash(muzzle: Attachment)
	local flash = newPart(
		Vector3.new(0.35, 0.35, 0.5),
		muzzle.WorldCFrame * CFrame.Angles(0, 0, math.random() * math.pi),
		Color3.fromRGB(255, 200, 90),
		Enum.Material.Neon
	)
	flash.Transparency = 0.2
	fadeAndDestroy(flash, 0.05, { Size = flash.Size * 1.6 })

	local light = muzzle:FindFirstChild("Flash") :: PointLight?
	if light then
		light.Enabled = true
		task.delay(0.05, function()
			light.Enabled = false
		end)
	end
end

function Effects.impact(position: Vector3, normal: Vector3)
	local mark = newPart(
		Vector3.new(0.3, 0.3, 0.05),
		CFrame.lookAt(position + normal * 0.02, position + normal),
		Color3.fromRGB(30, 30, 30)
	)
	fadeAndDestroy(mark, 1.5)

	for _ = 1, 3 do
		local spark = newPart(Vector3.one * 0.08, CFrame.new(position), Color3.fromRGB(255, 200, 100), Enum.Material.Neon)
		local direction = (normal + randomVector()).Unit
		fadeAndDestroy(spark, 0.2, { CFrame = CFrame.new(position + direction * 1.2) })
	end
end

function Effects.blood(position: Vector3, normal: Vector3)
	for _ = 1, 5 do
		local drop = newPart(Vector3.one * (0.1 + math.random() * 0.15), CFrame.new(position), Color3.fromRGB(110, 0, 0))
		local direction = (normal + randomVector() * 1.5).Unit
		local target = position + direction * (1 + math.random()) - Vector3.new(0, 0.8, 0)
		fadeAndDestroy(drop, 0.35, { CFrame = CFrame.new(target), Size = Vector3.one * 0.02 })
	end
end

-- Explosão de sangue (membro arrancado / cabeça)
function Effects.gore(position: Vector3)
	for _ = 1, 14 do
		local drop = newPart(Vector3.one * (0.15 + math.random() * 0.25), CFrame.new(position), Color3.fromRGB(100, 0, 0))
		local direction = (Vector3.yAxis + randomVector() * 2).Unit
		local target = position + direction * (2 + math.random() * 2) - Vector3.new(0, 1.5, 0)
		fadeAndDestroy(drop, 0.5, { CFrame = CFrame.new(target), Size = Vector3.one * 0.05 })
	end
end

function Effects.init()
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")

	-- Tiro de outro jogador: som 3D saindo da arma dele + clarão
	Remotes:WaitForChild("ShotFired").OnClientEvent:Connect(function(shooter: Player, weaponId: string)
		local def = Weapons[weaponId]
		local character = shooter and shooter.Character
		local weaponModel = character and character:FindFirstChild("WeaponModel")
		local handle = weaponModel and weaponModel:FindFirstChild("Handle")
		if not def or not handle then
			return
		end
		Sounds.play(def.FireSound, handle, def.FireVolume, (def.FirePitch or 1) * Sounds.randomPitch(0.08))
		local muzzle = handle:FindFirstChild("Muzzle") :: Attachment?
		if muzzle then
			Effects.muzzleFlash(muzzle)
		end
	end)

	Remotes:WaitForChild("DamageNumber").OnClientEvent:Connect(Effects.damageNumber)

	-- Membro arrancado, cabeça explodindo ou onda do micro-ondas de outro jogador
	Remotes:WaitForChild("Gore").OnClientEvent:Connect(function(kind: string, position: Vector3, ...)
		if kind == "Wave" then
			local direction, range, halfAngle, color = ...
			Effects.wave(position, direction, range, halfAngle, color)
			return
		elseif kind == "Confetti" then
			Effects.confetti(position)
			Sounds.playAt(Sounds.Ids.BoxReady, position, 0.7, 1.4 + math.random() * 0.3)
			return
		elseif kind == "Embers" then
			Effects.embers(position)
			Sounds.playAt(Sounds.Ids.Explosion, position, 0.35, 1.6 + math.random() * 0.3)
			return
		elseif kind == "Arc" then
			local points = position :: any -- a lista de pontos por onde o raio passou
			if typeof(points) == "table" and #points > 1 then
				Effects.arc(points)
				Sounds.playAt(Sounds.Ids.Explosion, points[#points], 0.4, 2)
			end
			return
		end
		Effects.gore(position)
		local soundId = if kind == "Head" then Sounds.Ids.Headshot else Sounds.Ids.LimbSever
		Sounds.playAt(soundId, position, 0.8, Sounds.randomPitch(0.15))
	end)
end

-- Número de dano subindo de onde o tiro pegou (bonecos de teste)
function Effects.damageNumber(position: Vector3, amount: number, headshot: boolean)
	local anchor = newPart(Vector3.one * 0.1, CFrame.new(position + Vector3.new(math.random() - 0.5, 0.5, math.random() - 0.5)), Color3.new(), nil)
	anchor.Transparency = 1

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 40)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = if headshot then Color3.fromRGB(255, 220, 60) else Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.2
	label.Text = tostring(math.floor(amount + 0.5)) .. (if headshot then "!" else "")
	label.Parent = billboard
	if headshot then
		billboard.Size = UDim2.fromOffset(150, 50)
	end

	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { CFrame = anchor.CFrame + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.9, function()
		anchor:Destroy()
	end)
end

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 80, 160),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(80, 220, 255),
	Color3.fromRGB(120, 255, 120),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 140, 60),
}

-- Canhão de Confete: o zumbi que morre explode numa chuva de papelzinho colorido
function Effects.confetti(position: Vector3)
	for _ = 1, 28 do
		local color = CONFETTI_COLORS[math.random(#CONFETTI_COLORS)]
		local piece = newPart(Vector3.new(0.35, 0.05, 0.25), CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6), color, Enum.Material.Neon)
		local direction = (Vector3.yAxis * 1.5 + randomVector() * 2).Unit
		local goal = CFrame.new(position + direction * (3 + math.random() * 4) - Vector3.new(0, 2, 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		fadeAndDestroy(piece, 1.2 + math.random() * 0.4, { CFrame = goal })
	end
end

-- Metralhadora Dragão: o zumbi que morre vira brasa (faíscas laranjas subindo e um clarão)
function Effects.embers(position: Vector3)
	for _ = 1, 18 do
		local color = Color3.fromRGB(255, math.random(60, 180), 20)
		local spark = newPart(Vector3.one * (0.15 + math.random() * 0.2), CFrame.new(position + randomVector()), color, Enum.Material.Neon)
		local goal = CFrame.new(position + Vector3.new(0, 3 + math.random() * 4, 0) + randomVector() * 3)
		fadeAndDestroy(spark, 0.8 + math.random() * 0.6, { CFrame = goal, Size = Vector3.one * 0.05 })
	end
	local glow = newPart(Vector3.one * 0.1, CFrame.new(position), Color3.fromRGB(255, 120, 30))
	glow.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 30)
	light.Range = 12
	light.Brightness = 4
	light.Parent = glow
	TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	task.delay(0.55, glow.Destroy, glow)
end

-- Corrente Elétrica: um raio amarelo em zigue-zague passando pelos pontos (zumbi a zumbi)
function Effects.arc(points: { Vector3 })
	for index = 1, #points - 1 do
		local from, to = points[index], points[index + 1]
		local previous = from
		local segments = 5
		for step = 1, segments do
			local target = from:Lerp(to, step / segments)
			if step < segments then
				target += randomVector() * 1.6
			end
			local length = (target - previous).Magnitude
			if length > 0.05 then
				local bolt = newPart(Vector3.new(0.18, 0.18, length), CFrame.lookAt(previous, target) * CFrame.new(0, 0, -length / 2), Color3.fromRGB(255, 240, 120), Enum.Material.Neon)
				fadeAndDestroy(bolt, 0.25)
			end
			previous = target
		end
	end
end

-- Onda do micro-ondas: um leque de "paredes" de energia saindo do jogador e sumindo.
-- halfAngle = meia-abertura do leque em graus
function Effects.wave(origin: Vector3, look: Vector3, range: number, halfAngle: number, color: Color3?)
	local flat = look * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.01 then
		return
	end
	flat = flat.Unit
	local waveColor = color or WAVE_COLOR
	local center = origin - Vector3.new(0, 1.5, 0)
	local count = math.max(5, math.floor(halfAngle * 2 / 12))
	local step = math.rad(halfAngle * 2) / count

	for index = 0, count - 1 do
		local angle = -math.rad(halfAngle) + step * (index + 0.5)
		local direction = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(flat)
		local function panelAt(radius: number): (CFrame, Vector3)
			local position = center + direction * radius
			local width = 2 * radius * math.sin(step / 2) * 1.1
			return CFrame.lookAt(position, position + direction), Vector3.new(width, 5, 0.2)
		end
		local startCFrame, startSize = panelAt(2)
		local endCFrame, endSize = panelAt(range)
		local panel = newPart(startSize, startCFrame, waveColor, Enum.Material.Neon)
		panel.Transparency = 0.35
		fadeAndDestroy(panel, 0.35, { CFrame = endCFrame, Size = endSize })
	end

	-- clarão
	local glow = newPart(Vector3.one * 0.1, CFrame.new(center + flat * 4), waveColor)
	glow.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = waveColor
	light.Range = math.min(range, 60)
	light.Brightness = 5
	light.Parent = glow
	TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()
	task.delay(0.45, glow.Destroy, glow)

	Sounds.playAt(Sounds.Ids.Explosion, center + flat * 2, 0.6, Sounds.randomPitch(0.1))
end

return Effects
