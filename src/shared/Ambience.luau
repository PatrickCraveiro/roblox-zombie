-- Iluminação do jogo: fim de tarde claro no lobby e noite (dá pra enxergar) nas fases.
-- O servidor aplica a do lobby ao iniciar; cada cliente troca sozinho ao entrar/sair da
-- partida (iluminação mudada no cliente vale só pra aquele jogador).
-- Pra deixar mais claro/escuro: Brightness, Ambient e OutdoorAmbient de cada preset.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Ambience = {}

Ambience.Presets = {
	Lobby = {
		lighting = {
			ClockTime = 15.5,
			Brightness = 2.5,
			Ambient = Color3.fromRGB(110, 110, 120),
			OutdoorAmbient = Color3.fromRGB(140, 140, 150),
			EnvironmentDiffuseScale = 1,
			EnvironmentSpecularScale = 1,
			ExposureCompensation = 0,
			GlobalShadows = true,
		},
		atmosphere = {
			Density = 0.25,
			Offset = 0.2,
			Color = Color3.fromRGB(199, 199, 199),
			Decay = Color3.fromRGB(106, 112, 125),
			Glare = 0,
			Haze = 0,
		},
		colorCorrection = {
			Saturation = 0.1,
			Contrast = 0.05,
			Brightness = 0,
			TintColor = Color3.fromRGB(255, 255, 255),
		},
	},
	Match = {
		lighting = {
			ClockTime = 0.3,
			Brightness = 1,
			Ambient = Color3.fromRGB(60, 60, 75),
			OutdoorAmbient = Color3.fromRGB(80, 80, 100),
			EnvironmentDiffuseScale = 0.4,
			EnvironmentSpecularScale = 0.4,
			ExposureCompensation = 0.3,
			GlobalShadows = true,
		},
		atmosphere = {
			Density = 0.35,
			Offset = 0.1,
			Color = Color3.fromRGB(55, 60, 75),
			Decay = Color3.fromRGB(30, 32, 42),
			Glare = 0,
			Haze = 1.2,
		},
		colorCorrection = {
			Saturation = -0.15,
			Contrast = 0.1,
			Brightness = 0.04,
			TintColor = Color3.fromRGB(230, 235, 255),
		},
	},
}

-- O servidor cria os efeitos (e todo mundo recebe); o cliente espera os do servidor
-- chegarem, porque criar outro aqui duplicaria o efeito
local function findEffect(className: string, name: string): Instance?
	local effect = Lighting:FindFirstChild(name)
	if effect and effect:IsA(className) then
		return effect
	end
	if RunService:IsServer() then
		local created = Lighting:FindFirstChildOfClass(className) or Instance.new(className)
		created.Name = name
		created.Parent = Lighting
		return created
	end
	local found = Lighting:WaitForChild(name, 5)
	return if found and found:IsA(className) then found else nil
end

local function setAll(instance: Instance?, properties: { [string]: any })
	if not instance then
		return
	end
	for key, value in properties do
		(instance :: any)[key] = value
	end
end

-- No cliente pode esperar uns segundos pelos efeitos: chame fora do caminho principal
function Ambience.apply(presetName: string)
	local preset = Ambience.Presets[presetName]
	if not preset then
		warn(`[Ambience] Preset desconhecido: {presetName}`)
		return
	end
	setAll(Lighting, preset.lighting)
	setAll(findEffect("Atmosphere", "Atmosphere"), preset.atmosphere)
	setAll(findEffect("ColorCorrectionEffect", "AmbienceColor"), preset.colorCorrection)
end

return Ambience
