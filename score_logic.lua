-------------------------------------------------------------------------------
--                          GearScoreAI Score Logic                          --
-------------------------------------------------------------------------------

function GS_GetProfile(classToken, specKey)
	specKey = (specKey and GS_SpecProfiles[specKey]) and specKey or GS_ClassDefaults[classToken]
	return GS_SpecProfiles[specKey], specKey
end

function GS_GetAuraNameFromId(spellId)
	local name = spellId and GetSpellInfo(spellId)
	return name
end

function GS_UnitHasAuraByName(unit, filter, auraName)
	if not unit or not auraName or not UnitExists(unit) then
		return false
	end
	for index = 1, 40 do
		local name = UnitAura(unit, index, filter)
		if not name then
			break
		end
		if name == auraName then
			return true
		end
	end
	return false
end

function GS_GetCapContext(unit, specKey)
	local capProfile = GS_CapProfiles[specKey]
	local context = { meleeHitBonus = 0, spellHitBonus = 0, targetSpellHitBonus = 0, expertiseBonus = 0, defenseSkillBonus = 0, unit = unit }
	if capProfile and capProfile.pools then
		for _, pool in pairs(capProfile.pools) do
			context.meleeHitBonus = max(context.meleeHitBonus, pool.meleeHitBonus or 0)
			context.spellHitBonus = max(context.spellHitBonus, pool.spellHitBonus or 0)
			context.expertiseBonus = max(context.expertiseBonus, pool.expertiseBonus or 0)
			context.defenseSkillBonus = max(context.defenseSkillBonus, pool.defenseSkillBonus or 0)
		end
	end
	if unit and UnitExists(unit) and UnitIsVisible(unit) then
		for index = 1, #(GS_LiveCapBuffs.HELPFUL or {}) do
			local aura = GS_LiveCapBuffs.HELPFUL[index]
			local auraName = GS_GetAuraNameFromId(aura.spellId)
			if auraName and GS_UnitHasAuraByName(unit, "HELPFUL", auraName) then
				context.meleeHitBonus = context.meleeHitBonus + (aura.meleeHitBonus or 0)
				context.spellHitBonus = context.spellHitBonus + (aura.spellHitBonus or 0)
				context.expertiseBonus = context.expertiseBonus + (aura.expertiseBonus or 0)
				context.defenseSkillBonus = context.defenseSkillBonus + (aura.defenseSkillBonus or 0)
			end
		end
	end
	if unit and UnitIsUnit(unit, "player") and UnitExists("target") then
		for index = 1, #(GS_LiveCapBuffs.HARMFUL or {}) do
			local aura = GS_LiveCapBuffs.HARMFUL[index]
			local auraName = GS_GetAuraNameFromId(aura.spellId)
			if auraName and GS_UnitHasAuraByName("target", "HARMFUL", auraName) then
				context.targetSpellHitBonus = context.targetSpellHitBonus + (aura.targetSpellHitBonus or 0)
			end
		end
	end
	return context
end

function GS_CollectSnapshotStats(snapshot)
	local totals = {}
	if not snapshot or not snapshot.items then
		return totals
	end
	for index = 1, #snapshot.items do
		local item = snapshot.items[index].item
		GS_AddStats(totals, item and item.stats)
		if item and item.gemStats then
			for gemIndex = 1, 4 do
				GS_AddStats(totals, item.gemStats[gemIndex])
			end
		end
		if item then
			GS_AddStats(totals, GS_GetEnchantStats(item))
		end
	end
	return totals
end

function GS_ResolveCapThreshold(segment, context)
	if not segment then
		return 0
	end
	if segment.mode == "MELEE_HIT_PERCENT" then
		return max(0, (segment.threshold - (context.meleeHitBonus or 0)) * GS_RatingConversions.MELEE_HIT)
	end
	if segment.mode == "SPELL_HIT_PERCENT" then
		return max(0, (segment.threshold - (context.spellHitBonus or 0) - (context.targetSpellHitBonus or 0)) * GS_RatingConversions.SPELL_HIT)
	end
	if segment.mode == "EXPERTISE_POINTS" then
		return max(0, (segment.threshold - (context.expertiseBonus or 0)) * GS_RatingConversions.EXPERTISE)
	end
	if segment.mode == "DEFENSE_SKILL" then
		return max(0, (segment.threshold - 400 - (context.defenseSkillBonus or 0)) * GS_RatingConversions.DEFENSE)
	end
	return max(0, segment.threshold or 0)
end

function GS_IsRoguePoisonCapSpec(specKey)
	return specKey == "ASSASSINATION" or specKey == "COMBAT" or specKey == "SUBTLETY"
end

function GS_FindCapSegment(pool, mode)
	if not pool or not pool.segments then
		return nil
	end
	for index = 1, #pool.segments do
		local segment = pool.segments[index]
		if segment.mode == mode then
			return segment
		end
	end
	return nil
end

function GS_GetCapProgressTarget(poolStat, pool, context, specKey)
	local targetSegment = nil
	if pool and pool.progressMode then
		targetSegment = GS_FindCapSegment(pool, pool.progressMode)
	end
	if not targetSegment and poolStat == "HIT" then
		if GS_IsRoguePoisonCapSpec(specKey) then
			targetSegment = GS_FindCapSegment(pool, "SPELL_HIT_PERCENT")
		else
			targetSegment = GS_FindCapSegment(pool, "MELEE_HIT_PERCENT") or GS_FindCapSegment(pool, "SPELL_HIT_PERCENT")
		end
	elseif not targetSegment and poolStat == "EXPERTISE" then
		targetSegment = GS_FindCapSegment(pool, "EXPERTISE_POINTS")
	elseif not targetSegment and poolStat == "DEFENSE" then
		targetSegment = GS_FindCapSegment(pool, "DEFENSE_SKILL")
	elseif not targetSegment and poolStat == "ARP" then
		targetSegment = GS_FindCapSegment(pool, "RATING")
	end
	if not targetSegment and pool and pool.segments and pool.segments[1] then
		targetSegment = pool.segments[1]
	end
	local resolvedThreshold = GS_ResolveCapThreshold(targetSegment, context)
	return targetSegment, resolvedThreshold
end

function GS_GetCapPoolDisplay(poolStat, statValue, targetSegment, resolvedThreshold, context)
	if poolStat == "DEFENSE" then
		return 400 + floor(((statValue or 0) / GS_RatingConversions.DEFENSE) + (context.defenseSkillBonus or 0) + 0.5), targetSegment and targetSegment.threshold or 540, false
	end
	if poolStat == "EXPERTISE" then
		return floor(((statValue or 0) / GS_RatingConversions.EXPERTISE) + (context.expertiseBonus or 0) + 0.5), targetSegment and targetSegment.threshold or 26, false
	end
	if poolStat == "HIT" and targetSegment and targetSegment.mode == "SPELL_HIT_PERCENT" then
		return ((statValue or 0) / GS_RatingConversions.SPELL_HIT) + (context.spellHitBonus or 0) + (context.targetSpellHitBonus or 0), targetSegment.threshold or 17, false
	end
	if poolStat == "HIT" and targetSegment and targetSegment.mode == "MELEE_HIT_PERCENT" then
		return ((statValue or 0) / GS_RatingConversions.MELEE_HIT) + (context.meleeHitBonus or 0), targetSegment.threshold or 8, false
	end
	return floor((statValue or 0) + 0.5), floor((resolvedThreshold or 0) + 0.5), true
end

function GS_GetMaxCapBonus(preCapGs2)
	local gs2Value = tonumber(preCapGs2) or 0
	if gs2Value <= 0 then
		return 0
	end
	local lowGs = max(GS_CAP_BONUS_ANCHOR_LOW_GS2 or 4000, 1)
	local highGs = max(GS_CAP_BONUS_ANCHOR_HIGH_GS2 or 5000, lowGs + 1)
	local lowBonus = GS_CAP_BONUS_ANCHOR_LOW_BONUS or 200
	local highBonus = GS_CAP_BONUS_ANCHOR_HIGH_BONUS or 100
	local ratio = (math.log(gs2Value) - math.log(lowGs)) / (math.log(highGs) - math.log(lowGs))
	local rawBonus = lowBonus + ((highBonus - lowBonus) * ratio)
	local rounded = floor(rawBonus + 0.5)
	return min(GS_CAP_BONUS_MAX or 300, max(GS_CAP_BONUS_MIN or 25, rounded))
end

function GS_ApplyCapPool(poolStat, statValue, baseWeight, pool, context, specKey)
	local targetSegment, resolvedThreshold = GS_GetCapProgressTarget(poolStat, pool, context, specKey)
	local progress = resolvedThreshold > 0 and min(max((statValue or 0) / resolvedThreshold, 0), 1) or 0
	local current, target, ratingSummary = GS_GetCapPoolDisplay(poolStat, statValue, targetSegment, resolvedThreshold, context)
	return {
		stat = poolStat,
		summary = pool.summary or poolStat,
		rawValue = statValue or 0,
		baseWeight = baseWeight or 0,
		progress = progress,
		current = current,
		target = target,
		targetSegment = targetSegment,
		targetThreshold = resolvedThreshold,
		ratingSummary = ratingSummary,
		capped = progress >= 1,
		bonusGs2 = 0,
	}
end

function GS_AssignCapPoolBonuses(capBreakdown, totalBonus)
	if not capBreakdown or not capBreakdown.pools then
		return
	end
	local progressTotal, lastPositiveIndex = 0, nil
	for index = 1, #capBreakdown.pools do
		local progress = capBreakdown.pools[index].progress or 0
		if progress > 0 then
			progressTotal = progressTotal + progress
			lastPositiveIndex = index
		end
	end
	local remaining = totalBonus or 0
	for index = 1, #capBreakdown.pools do
		local pool = capBreakdown.pools[index]
		local progress = pool.progress or 0
		local bonus = 0
		if progress > 0 and progressTotal > 0 and (totalBonus or 0) > 0 then
			if index == lastPositiveIndex then
				bonus = remaining
			else
				bonus = floor((totalBonus or 0) * (progress / progressTotal))
				remaining = remaining - bonus
			end
		end
		pool.bonusGs2 = bonus
	end
end

function GS_FormatCapSummary(capBreakdown)
	if not capBreakdown or not capBreakdown.pools then
		return nil
	end
	local parts = {}
	for index = 1, #capBreakdown.pools do
		local pool = capBreakdown.pools[index]
		if (pool.progress or 0) > 0 and (pool.bonusGs2 or 0) >= 0 then
			local label = pool.summary
			if pool.capped then
				label = label .. " capped"
			else
				label = label .. " " .. tostring(floor((pool.progress or 0) * 100 + 0.5)) .. "%"
			end
			parts[#parts + 1] = label .. " (+" .. tostring(pool.bonusGs2 or 0) .. " GS2)"
		end
	end
	return #parts > 0 and table.concat(parts, ", ") or nil
end

function GS_ApplyCharacterCaps(snapshot, preCapGs2)
	if not snapshot or not snapshot.specKey then
		return 0, nil, nil
	end
	local capProfile = GS_CapProfiles[snapshot.specKey]
	local profile = GS_SpecProfiles[snapshot.specKey]
	local totalStats = GS_CollectSnapshotStats(snapshot)
	if not capProfile or not profile or not profile.pve then
		return 0, nil, totalStats
	end
	local context = GS_GetCapContext(snapshot.unit, snapshot.specKey)
	local breakdown = { pools = {}, summary = nil, context = context, preCapGs2 = preCapGs2 or 0 }
	local order = capProfile.order or {}
	for index = 1, #order do
		local stat = order[index]
		local pool = capProfile.pools and capProfile.pools[stat]
		local baseWeight = profile.pve[stat]
		local statValue = totalStats[stat] or 0
		if pool and baseWeight and statValue > 0 then
			local poolBreakdown = GS_ApplyCapPool(stat, statValue, baseWeight, pool, context, snapshot.specKey)
			breakdown.pools[#breakdown.pools + 1] = poolBreakdown
		end
	end
	local progressTotal = 0
	for index = 1, #breakdown.pools do
		progressTotal = progressTotal + (breakdown.pools[index].progress or 0)
	end
	breakdown.overallProgress = #breakdown.pools > 0 and (progressTotal / #breakdown.pools) or 0
	breakdown.maxBonus = GS_GetMaxCapBonus(preCapGs2 or 0)
	breakdown.deltaGs2 = floor((breakdown.maxBonus or 0) * (breakdown.overallProgress or 0))
	GS_AssignCapPoolBonuses(breakdown, breakdown.deltaGs2)
	breakdown.summary = GS_FormatCapSummary(breakdown)
	return breakdown.deltaGs2, breakdown, totalStats
end

function GS_ScoreStats(stats, weights)
	local total = 0
	if not stats or not weights then return total end
	for stat, value in pairs(stats) do if weights[stat] then total = total + value * weights[stat] end end
	return total
end

GS_ExplainIgnoredStats = {
	STA = true,
}

function GS_ShouldFlagStats(stats, weights)
	if not stats then
		return false
	end
	local hasMatched, hasNonIgnoredMiss = false, false
	for stat, value in pairs(stats) do
		if (value or 0) > 0 then
			if weights and weights[stat] then
				hasMatched = true
			elseif not GS_ExplainIgnoredStats[stat] then
				hasNonIgnoredMiss = true
			end
		end
	end
	return hasNonIgnoredMiss and not hasMatched
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
			pve = { base = item.legacyBase, preMultiplier = item.legacyBase, multiplier = 1, parts = {}, statEntries = GS_BuildTopStats(item.stats, profile and profile.pve or nil), flags = {}, final = 0 },
			pvp = { base = item.legacyBase, preMultiplier = item.legacyBase, multiplier = 1, parts = {}, statEntries = GS_BuildTopStats(item.stats, profile and profile.pvp or nil), flags = {}, final = 0 },
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
	local pveStatBonus = floor(pveStatRaw * GS_GS2_STAT_SCALE)
	local pvpStatBonus = floor(pvpStatRaw * GS_GS2_STAT_SCALE)
	pveScore = pveScore + pveStatBonus
	pvpScore = pvpScore + pvpStatBonus
	if explain then
		explain.pve.parts[#explain.pve.parts + 1] = { label = "Matched stats", formula = "(" .. GS_FormatNumber(pveStatRaw) .. " * " .. GS_FormatNumber(GS_GS2_STAT_SCALE) .. ")", delta = pveStatBonus }
		explain.pvp.parts[#explain.pvp.parts + 1] = { label = "Matched PvP stats", formula = "(" .. GS_FormatNumber(pvpStatRaw) .. " * " .. GS_FormatNumber(GS_GS2_STAT_SCALE) .. ")", delta = pvpStatBonus }
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
				local pveFlag = GS_ShouldFlagStats(item.gemStats[index], profile.pve)
				local pvpFlag = GS_ShouldFlagStats(item.gemStats[index], profile.pvp)
				explain.pve.parts[#explain.pve.parts + 1] = { label = "Gem " .. index, formula = pveFormula, delta = gemPveBonus }
				explain.pvp.parts[#explain.pvp.parts + 1] = { label = "Gem " .. index, formula = pvpFormula, delta = gemPvpBonus }
				if pveFlag then explain.pve.flags[#explain.pve.flags + 1] = "Gem " .. index .. ": gem stats do not match profile " .. resolvedSpecKey end
				if pvpFlag then explain.pvp.flags[#explain.pvp.flags + 1] = "Gem " .. index .. ": gem stats do not match profile " .. resolvedSpecKey end
			end
		elseif explain and item.socketCount >= index then
			explain.pve.parts[#explain.pve.parts + 1] = { label = "Gem " .. index, formula = "(empty socket => +0)", delta = 0 }
			explain.pvp.parts[#explain.pvp.parts + 1] = { label = "Gem " .. index, formula = "(empty socket => +0)", delta = 0 }
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
					local pveFlag = GS_ShouldFlagStats(enchantStats, profile.pve)
					local pvpFlag = GS_ShouldFlagStats(enchantStats, profile.pvp)
					pveFormula = pveEnchantRaw > 0 and ("(" .. GS_FormatNumber(pveEnchantRaw) .. " * " .. GS_FormatNumber(GS_ENCHANT_SCALE) .. ")") or ("(" .. GS_FormatNumber(pveEnchantRaw) .. " <= 0 => +0)")
					pvpFormula = pvpEnchantRaw > 0 and ("(" .. GS_FormatNumber(pvpEnchantRaw) .. " * " .. GS_FormatNumber(GS_ENCHANT_SCALE) .. ")") or ("(" .. GS_FormatNumber(pvpEnchantRaw) .. " <= 0 => +0)")
					if pveFlag then explain.pve.flags[#explain.pve.flags + 1] = "Enchant: stats do not match profile " .. resolvedSpecKey end
					if pvpFlag then explain.pvp.flags[#explain.pvp.flags + 1] = "Enchant: stats do not match profile " .. resolvedSpecKey end
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
		if (item.resilience or 0) > 0 then
			explain.flags[#explain.flags + 1] = "Resilience: " .. (item.resilience or 0)
		end
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
