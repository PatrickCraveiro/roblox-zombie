-- Ponto de entrada do cliente.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ambience = require(Shared:WaitForChild("Ambience"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local ArsenalController = require(script.ArsenalController)
local AuraController = require(script.AuraController)
local BarricadeController = require(script.BarricadeController)
local Effects = require(script.Effects)
local HudController = require(script.HudController)
local MobileControls = require(script.MobileControls)
local WeaponController = require(script.WeaponController)

-- pré-carrega os sons pra o primeiro tiro não sair mudo
-- (precisa ser objeto Sound: um ID solto em texto é carregado como imagem e dá erro)
task.spawn(function()
	local sounds = {}
	for _, id in Sounds.allIds() do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		table.insert(sounds, sound)
	end
	ContentProvider:PreloadAsync(sounds)
	for _, sound in sounds do
		sound:Destroy()
	end
end)

-- iluminação: tarde clara no lobby, noite na partida
local player = Players.LocalPlayer
local function updateAmbience()
	Ambience.apply(if player:GetAttribute("InMatch") then "Match" else "Lobby")
end
player:GetAttributeChangedSignal("InMatch"):Connect(updateAmbience)
task.spawn(updateAmbience)

HudController.init()
Effects.init()
WeaponController.init(HudController)
BarricadeController.init(HudController)
ArsenalController.init()
AuraController.init()
MobileControls.init(WeaponController, BarricadeController, HudController)
