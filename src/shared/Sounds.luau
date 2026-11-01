-- IDs de som num lugar só + funções pra tocar.
-- Os áudios são da biblioteca oficial de efeitos da Roblox (conta "ProSoundEffects"),
-- liberados pra qualquer jogo. Pra trocar: Caixa de ferramentas > Áudio, copie o ID.
-- Os sons de tiro de cada arma ficam em Weapons.luau (FireSound).

local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Weapons = require(script.Parent.Weapons)

local Sounds = {}

Sounds.Ids = {
	Reload = "rbxassetid://9113104176",
	ZombieHit = "rbxassetid://9113518748",
	LimbSever = "rbxassetid://9116485156",
	Headshot = "rbxassetid://9116485127",
	Explosion = "rbxassetid://9119236749",
	DoorOpen = "rbxassetid://9125686089", -- porta de aço subindo
	BoxRoll = "rbxassetid://9117040377", -- caixinha de música enquanto sorteia
	BoxReady = "rbxassetid://9116394545",
	Upgrade = "rbxassetid://9116422213", -- máquina de upgrade turbinando a arma
	ZombieAttack = "rbxassetid://9114629787", -- rosnado curto no golpe
	PlayerHurt = "rbxassetid://9113486872", -- pancada no jogador
	PlankTear = "rbxassetid://9120801590", -- zumbi arrancando tábua da barricada
	PlankRepair = "rbxassetid://9114756156", -- martelada pregando a tábua de volta
}

-- Gemidos que os zumbis soltam enquanto andam (sorteia um, com tom variado)
Sounds.ZombieGroans = {
	"rbxassetid://9116967287", -- Monster Vocals 1
	"rbxassetid://9116967303", -- Monster Vocals 2
	"rbxassetid://9116965959", -- Monster Vocals 14
	"rbxassetid://9114624345", -- Goblin Growl 1
	"rbxassetid://9114624494", -- Goblin Growl 3
	"rbxassetid://9114629771", -- Deep Growling Voice 37
}

-- Variação aleatória de tom pra repetição não soar robótica
function Sounds.randomPitch(variation: number): number
	return 1 + (math.random() - 0.5) * variation
end

-- Toca um som e apaga quando acabar.
-- parent = BasePart/Attachment pra som 3D (posicional); nil = som 2D (sem posição).
-- maxDistance = até onde dá pra ouvir o som 3D (padrão 300)
function Sounds.play(soundId: string, parent: Instance?, volume: number?, pitch: number?, maxDistance: number?): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = maxDistance or 300
	sound.Parent = parent or SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(10, sound.Destroy, sound) -- garantia caso o áudio não carregue
	sound:Play()
	return sound
end

-- Som 3D num ponto do mundo
function Sounds.playAt(soundId: string, position: Vector3, volume: number?, pitch: number?): Sound
	local attachment = Instance.new("Attachment")
	attachment.Position = position -- o Terrain fica na origem, então posição local = mundo
	attachment.Parent = Workspace.Terrain
	local sound = Sounds.play(soundId, attachment, volume, pitch)
	sound.Destroying:Once(function()
		attachment:Destroy()
	end)
	return sound
end

-- Todos os IDs (pra pré-carregar e o primeiro tiro não sair mudo)
function Sounds.allIds(): { string }
	local ids = {}
	for _, id in Sounds.Ids do
		table.insert(ids, id)
	end
	for _, id in Sounds.ZombieGroans do
		table.insert(ids, id)
	end
	for _, def in Weapons do
		table.insert(ids, def.FireSound)
	end
	return ids
end

return Sounds
