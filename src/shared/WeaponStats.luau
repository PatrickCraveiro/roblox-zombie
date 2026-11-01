-- Atributos de uma arma já levando em conta o upgrade da Máquina de Upgrade.
-- Turbinada: dano e munição multiplicados (Config) e, se a arma tiver a tabela "Upgrade"
-- em Weapons.luau, os valores dela por cima (é assim que a pistola vira a Pistola Lendária).

local Config = require(script.Parent.Config)
local Weapons = require(script.Parent.Weapons)

local WeaponStats = {}

local DEFAULT_UPGRADE_COLOR = Color3.fromRGB(255, 40, 40)

local upgradedCache: { [string]: Weapons.WeaponDef } = {}

function WeaponStats.get(weaponId: string, upgraded: boolean?): Weapons.WeaponDef?
	local def = Weapons[weaponId]
	if not def or not upgraded then
		return def
	end
	local cached = upgradedCache[weaponId]
	if cached then
		return cached
	end

	local stats = table.clone(def) :: any
	stats.Name = def.Name .. " TURBO"
	stats.Damage = def.Damage * Config.UpgradeDamageMultiplier
	stats.MagSize = def.MagSize * Config.UpgradeAmmoMultiplier
	stats.MaxReserve = def.MaxReserve * Config.UpgradeAmmoMultiplier
	stats.FirePitch = (def.FirePitch or 1) * 0.88 -- turbinada soa mais grave
	if def.Upgrade then
		for key, value in def.Upgrade do
			stats[key] = value
		end
	end
	upgradedCache[weaponId] = stats
	return stats
end

-- Cor da versão turbinada (vermelho, ou a cor especial da arma)
function WeaponStats.upgradeColor(weaponId: string): Color3
	local def = Weapons[weaponId]
	local color = def and def.Upgrade and def.Upgrade.Color
	return if typeof(color) == "Color3" then color else DEFAULT_UPGRADE_COLOR
end

-- Texto que aparece quando a arma é turbinada
function WeaponStats.upgradeDescription(weaponId: string): string
	local def = Weapons[weaponId]
	local text = def and def.Upgrade and def.Upgrade.Description
	if typeof(text) == "string" then
		return text
	end
	return `Dano x{Config.UpgradeDamageMultiplier}  •  Munição x{Config.UpgradeAmmoMultiplier}  •  Munição cheia`
end

return WeaponStats
