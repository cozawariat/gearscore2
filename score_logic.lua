-------------------------------------------------------------------------------
--                          GearScoreAI Score Logic                          --
-------------------------------------------------------------------------------

function GS_GetProfile(classToken, specKey)
	specKey = (specKey and GS_SpecProfiles[specKey]) and specKey or GS_ClassDefaults[classToken]
	return GS_SpecProfiles[specKey], specKey
end

function GS_ScoreStats(stats, weights)
	local total = 0
	if not stats or not weights then return total end
	for stat, value in pairs(stats) do if weights[stat] then total = total + value * weights[stat] end end
	return total
end

function GS_GetResilienceMultiplier(resilience, mode)
	resilience = tonumber(resilience) or 0
	if resilience <= 0 then
		return 1
	end
	if mode == "PVP" then
		return min(GS_PVP_RESILIENCE_CAP, 1 + (resilience * GS_PVP_RESILIENCE_RATE))
	end
	return max(GS_PVE_RESILIENCE_FLOOR, 1 - (resilience * GS_PVE_RESILIENCE_RATE))
end

function GS_IsItemCompatible(item, classToken, profile)
	if not item or not profile or item.slot == 0 then return false end
	if GS_ArmorClassOrder[profile.armor] and item.armorRank and item.slot ~= 15 and item.slot ~= 2 and item.slot ~= 11 and item.slot ~= 13 then
		if item.armorRank < GS_ArmorClassOrder[profile.armor] then return false end
	end
	if item.equipLoc == "INVTYPE_SHIELD" and not profile.shield then return false end
	if item.equipLoc == "INVTYPE_HOLDABLE" and profile.role ~= "CASTER" and profile.role ~= "HEALER" then return false end
	if (item.equipLoc == "INVTYPE_RANGED" or item.equipLoc == "INVTYPE_RANGEDRIGHT" or item.equipLoc == "INVTYPE_THROWN") and not profile.ranged then return false end
	if classToken == "HUNTER" and (item.equipLoc == "INVTYPE_SHIELD" or item.equipLoc == "INVTYPE_HOLDABLE") then return false end
	if (profile.role == "CASTER" or profile.role == "HEALER") and (item.stats.STR or 0) > 0 and (item.stats.SP or 0) == 0 and (item.stats.INT or 0) == 0 then return false end
	if (profile.role == "MELEE" or profile.role == "RANGED") and (item.stats.SP or 0) > 0 and (item.stats.STR or 0) == 0 and (item.stats.AGI or 0) == 0 and (item.stats.AP or 0) == 0 and (item.stats.RAP or 0) == 0 then return false end
	return true
end

function GS_ScoreItem(item, classToken, specKey, wantExplain)
	local profile, resolvedSpecKey = GS_GetProfile(classToken, specKey)
	local compatible = GS_IsItemCompatible(item, classToken, profile)
	local explain = nil
	if wantExplain then
		explain = {
			classToken = classToken,
			specKey = resolvedSpecKey,
			compatible = compatible,
			legacyBase = item.legacyBase,
			pve = { base = item.legacyBase, preMultiplier = item.legacyBase, multiplier = 1, parts = {}, statEntries = GS_BuildTopStats(item.stats, profile and profile.pve or nil), final = 0 },
			pvp = { base = item.legacyBase, preMultiplier = item.legacyBase, multiplier = 1, parts = {}, statEntries = GS_BuildTopStats(item.stats, profile and profile.pvp or nil), final = 0 },
			flags = {},
			itemName = item.name,
		}
	end
	if not compatible then
		if explain then
			explain.flags[#explain.flags + 1] = "Item rejected: offspec / incompatible armor type / incompatible weapon type"
			explain.pve.final = 0
			explain.pvp.final = 0
		end
		return 0, 0, explain
	end

	local pveScore, pvpScore = item.legacyBase, item.legacyBase
	local pveStatRaw = GS_ScoreStats(item.stats, profile.pve)
	local pvpStatRaw = GS_ScoreStats(item.stats, profile.pvp)
	local pveStatBonus = floor(pveStatRaw * 0.12)
	local pvpStatBonus = floor(pvpStatRaw * 0.12)
	pveScore = pveScore + pveStatBonus
	pvpScore = pvpScore + pvpStatBonus
	if explain then
		explain.pve.parts[#explain.pve.parts + 1] = { label = "Matched stats", formula = "(" .. GS_FormatNumber(pveStatRaw) .. " * 0.12)", delta = pveStatBonus }
		explain.pvp.parts[#explain.pvp.parts + 1] = { label = "Matched PvP stats", formula = "(" .. GS_FormatNumber(pvpStatRaw) .. " * 0.12)", delta = pvpStatBonus }
	end

	for index = 1, 4 do
		if item.gemStats[index] then
			local gemPveRaw = GS_ScoreStats(item.gemStats[index], profile.pve)
			local gemPvpRaw = GS_ScoreStats(item.gemStats[index], profile.pvp)
			local gemPveBonus = gemPveRaw > 0 and floor(gemPveRaw * GS_GEM_SCALE) or 0
			local gemPvpBonus = gemPvpRaw > 0 and floor(gemPvpRaw * GS_GEM_SCALE) or 0
			pveScore = pveScore + gemPveBonus
			pvpScore = pvpScore + gemPvpBonus
			if explain then
				local pveFormula = gemPveRaw > 0 and ("(" .. GS_FormatNumber(gemPveRaw) .. " * " .. GS_FormatNumber(GS_GEM_SCALE) .. ")") or ("(" .. GS_FormatNumber(gemPveRaw) .. " <= 0 => +0)")
				local pvpFormula = gemPvpRaw > 0 and ("(" .. GS_FormatNumber(gemPvpRaw) .. " * " .. GS_FormatNumber(GS_GEM_SCALE) .. ")") or ("(" .. GS_FormatNumber(gemPvpRaw) .. " <= 0 => +0)")
				explain.pve.parts[#explain.pve.parts + 1] = { label = "Gem " .. index, formula = pveFormula, delta = gemPveBonus }
				explain.pvp.parts[#explain.pvp.parts + 1] = { label = "Gem " .. index, formula = pvpFormula, delta = gemPvpBonus }
				if gemPveRaw <= 0 then explain.flags[#explain.flags + 1] = "Gem " .. index .. ": gem stats do not match profile " .. resolvedSpecKey .. " (PvE)" end
				if gemPvpRaw <= 0 then explain.flags[#explain.flags + 1] = "Gem " .. index .. ": gem stats do not match profile " .. resolvedSpecKey .. " (PvP)" end
			end
		elseif explain and item.socketCount >= index then
			explain.pve.parts[#explain.pve.parts + 1] = { label = "Gem " .. index, formula = "(pusty socket => +0)", delta = 0 }
			explain.pvp.parts[#explain.pvp.parts + 1] = { label = "Gem " .. index, formula = "(pusty socket => +0)", delta = 0 }
		end
	end
	if GS_EnchantSlots[item.equipLoc] then
		if item.hasEnchant then
			local enchantInfo = GS_GetEnchantInfo(item)
			local enchantStats = enchantInfo and enchantInfo.stats or nil
			local pveEnchantRaw = GS_ScoreStats(enchantStats, profile.pve)
			local pvpEnchantRaw = GS_ScoreStats(enchantStats, profile.pvp)
			local pveEnchant = pveEnchantRaw > 0 and floor(pveEnchantRaw * GS_ENCHANT_SCALE) or 0
			local pvpEnchant = pvpEnchantRaw > 0 and floor(pvpEnchantRaw * GS_ENCHANT_SCALE) or 0
			pveScore = pveScore + pveEnchant
			pvpScore = pvpScore + pvpEnchant
			if explain then
				local pveFormula, pvpFormula
				if enchantInfo and enchantInfo.kind == "stats" and enchantStats then
					pveFormula = pveEnchantRaw > 0 and ("(" .. GS_FormatNumber(pveEnchantRaw) .. " * " .. GS_FormatNumber(GS_ENCHANT_SCALE) .. ")") or ("(" .. GS_FormatNumber(pveEnchantRaw) .. " <= 0 => +0)")
					pvpFormula = pvpEnchantRaw > 0 and ("(" .. GS_FormatNumber(pvpEnchantRaw) .. " * " .. GS_FormatNumber(GS_ENCHANT_SCALE) .. ")") or ("(" .. GS_FormatNumber(pvpEnchantRaw) .. " <= 0 => +0)")
					if pveEnchantRaw <= 0 then explain.flags[#explain.flags + 1] = "Enchant: stats do not match profile " .. resolvedSpecKey .. " (PvE)" end
					if pvpEnchantRaw <= 0 then explain.flags[#explain.flags + 1] = "Enchant: stats do not match profile " .. resolvedSpecKey .. " (PvP)" end
				elseif enchantInfo and enchantInfo.kind == "special" then
					pveFormula = "(special effect => +0)"
					pvpFormula = "(special effect => +0)"
					explain.flags[#explain.flags + 1] = "Enchant " .. (item.enchantId or 0) .. ": special effect, not statically scored"
				else
					pveFormula = "(unknown enchant => +0)"
					pvpFormula = "(unknown enchant => +0)"
					explain.flags[#explain.flags + 1] = "Enchant " .. (item.enchantId or 0) .. ": unknown stat lookup"
				end
				explain.pve.parts[#explain.pve.parts + 1] = { label = "Enchant", formula = pveFormula, delta = pveEnchant }
				explain.pvp.parts[#explain.pvp.parts + 1] = { label = "Enchant", formula = pvpFormula, delta = pvpEnchant }
			end
		elseif explain then
			explain.pve.parts[#explain.pve.parts + 1] = { label = "Enchant", formula = "(missing enchant => +0)", delta = 0 }
			explain.pvp.parts[#explain.pvp.parts + 1] = { label = "Enchant", formula = "(missing enchant => +0)", delta = 0 }
		end
	end
	local pveBaseScore = pveScore > 0 and pveScore or 0
	local pvpBaseScore = pvpScore > 0 and pvpScore or 0
	local pveMultiplier = GS_GetResilienceMultiplier(item.resilience, "PVE")
	local pvpMultiplier = GS_GetResilienceMultiplier(item.resilience, "PVP")
	pveScore = floor(pveBaseScore * pveMultiplier)
	pvpScore = floor(pvpBaseScore * pvpMultiplier)
	if explain then
		explain.pve.preMultiplier = pveBaseScore
		explain.pvp.preMultiplier = pvpBaseScore
		explain.pve.multiplier = pveMultiplier
		explain.pvp.multiplier = pvpMultiplier
		explain.flags[#explain.flags + 1] = "Resilience: " .. (item.resilience or 0)
		explain.pve.parts[#explain.pve.parts + 1] = { label = "PvE resilience multiplier", formula = "max(" .. GS_FormatNumber(GS_PVE_RESILIENCE_FLOOR) .. ", 1 - (" .. item.resilience .. " * " .. GS_FormatNumber(GS_PVE_RESILIENCE_RATE) .. "))", delta = pveScore - pveBaseScore }
		explain.pvp.parts[#explain.pvp.parts + 1] = { label = "PvP resilience multiplier", formula = "min(" .. GS_FormatNumber(GS_PVP_RESILIENCE_CAP) .. ", 1 + (" .. item.resilience .. " * " .. GS_FormatNumber(GS_PVP_RESILIENCE_RATE) .. "))", delta = pvpScore - pvpBaseScore }
		explain.pve.final = pveScore
		explain.pvp.final = pvpScore
	end
	return pveScore, pvpScore, explain
end

function GS_GetHunterLegacy(slotId, item)
	if slotId == 16 then return floor(item.legacyBase * 0.3164) end
	if slotId == 18 and (item.equipLoc == "INVTYPE_RANGEDRIGHT" or item.equipLoc == "INVTYPE_RANGED") then return floor(item.legacyBase * 5.3224) end
	return item.legacyBase
end

function GearScore_GetQuality(score)
	if score > 5999 then score = 5999 end
	if not score then return 0, 0, 0, "Trash" end
	for i = 0, 6 do
		if score > i * 1000 and score <= ((i + 1) * 1000) then
			local red = GS_Quality[(i + 1) * 1000].Red.A + (((score - GS_Quality[(i + 1) * 1000].Red.B) * GS_Quality[(i + 1) * 1000].Red.C) * GS_Quality[(i + 1) * 1000].Red.D)
			local blue = GS_Quality[(i + 1) * 1000].Green.A + (((score - GS_Quality[(i + 1) * 1000].Green.B) * GS_Quality[(i + 1) * 1000].Green.C) * GS_Quality[(i + 1) * 1000].Green.D)
			local green = GS_Quality[(i + 1) * 1000].Blue.A + (((score - GS_Quality[(i + 1) * 1000].Blue.B) * GS_Quality[(i + 1) * 1000].Blue.C) * GS_Quality[(i + 1) * 1000].Blue.D)
			return red, green, blue, GS_Quality[(i + 1) * 1000].Description
		end
	end
	return 0.1, 0.1, 0.1
end

function GearScore_GetItemScore(itemLink)
	return GS_CalculateLegacyBase(itemLink)
end
