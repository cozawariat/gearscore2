-------------------------------------------------------------------------------
--                           GearScore2 Score Logic                           --
-------------------------------------------------------------------------------

local GS = _G.GS2
local C = GS and GS.Constants or {}
local Data = GS and GS.Data or {}
local Tables = Data.Tables or {}
local GS_CLASS_SPEC_ORDER = Tables.ClassSpecOrder or {}
local GS_SPEC_PROFILES = Tables.SpecProfiles or {}
local GS_CLASS_DEFAULTS = Tables.ClassDefaults or {}
local GS_CAP_PROFILES = Tables.CapProfiles or {}
local GS_PERMANENT_CAP_RACIALS = Tables.PermanentCapRacials or {}
local GS_LIVE_CAP_BUFFS = Tables.LiveCapBuffs or {}
local GS_RATING_CONVERSIONS = Tables.RatingConversions or {}
local GS_ARMOR_CLASS_ORDER = Tables.ArmorClassOrder or {}
local GS_ENCHANT_SLOTS = Tables.EnchantSlots or {}
local GS_QUALITY = Tables.Quality or {}
local GS_GEM_SCALE = C.GEM_SCALE or 0.35
local GS_ENCHANT_SCALE = C.ENCHANT_SCALE or 0.35
local GS_INCOMPATIBLE_PVE_BONUS_SCALE = C.INCOMPATIBLE_PVE_BONUS_SCALE or 0.15
local GS_PVE_RESILIENCE_RATE = C.PVE_RESILIENCE_RATE or 0.0015
local GS_PVP_RESILIENCE_RATE = C.PVP_RESILIENCE_RATE or 0.0020
local GS_PVE_RESILIENCE_FLOOR = C.PVE_RESILIENCE_FLOOR or 0.70
local GS_PVP_RESILIENCE_CAP = C.PVP_RESILIENCE_CAP or 1.35
local GS_GS2_STAT_SCALE = C.GS2_STAT_SCALE or 0.12
local GS_CAP_BONUS_ANCHOR_LOW_GS2 = C.CAP_BONUS_ANCHOR_LOW_GS2 or 4000
local GS_CAP_BONUS_ANCHOR_HIGH_GS2 = C.CAP_BONUS_ANCHOR_HIGH_GS2 or 5000
local GS_CAP_BONUS_ANCHOR_LOW_BONUS = C.CAP_BONUS_ANCHOR_LOW_BONUS or 180
local GS_CAP_BONUS_ANCHOR_HIGH_BONUS = C.CAP_BONUS_ANCHOR_HIGH_BONUS or 90
local GS_CAP_BONUS_MIN = C.CAP_BONUS_MIN or 20
local GS_CAP_BONUS_MAX = C.CAP_BONUS_MAX or 250

local GS_GENERIC_TREE_PROFILE_DEFAULTS = {
	FERAL = "DRUID_FERAL_DPS",
}

function GS_GetClassSpecCandidates(classToken)
	local candidates = {}
	local order = GS_CLASS_SPEC_ORDER and GS_CLASS_SPEC_ORDER[classToken] or nil
	if not order then
		return candidates
	end
	for index = 1, #order do
		local specKey = order[index]
		if classToken == "DRUID" and specKey == "DRUID_FERAL_DPS" then
			candidates[#candidates + 1] = "DRUID_FERAL_DPS"
			candidates[#candidates + 1] = "DRUID_FERAL_TANK"
		elseif GS_SPEC_PROFILES[specKey] then
			candidates[#candidates + 1] = specKey
		end
	end
	return candidates
end

function GS_GetProfile(classToken, specKey)
	local resolvedSpecKey = specKey
	if resolvedSpecKey and not GS_SPEC_PROFILES[resolvedSpecKey] then
		resolvedSpecKey = nil
	end
	if not resolvedSpecKey and specKey and GS_GENERIC_TREE_PROFILE_DEFAULTS[specKey] and GS_SPEC_PROFILES[GS_GENERIC_TREE_PROFILE_DEFAULTS[specKey]] then
		resolvedSpecKey = GS_GENERIC_TREE_PROFILE_DEFAULTS[specKey]
	end
	resolvedSpecKey = resolvedSpecKey or GS_CLASS_DEFAULTS[classToken]
	return GS_SPEC_PROFILES[resolvedSpecKey], resolvedSpecKey
end

function GS_GetSlotMultiplier(profile, slotId, itemLevel)
	if not profile or not profile.gs2SlotCurves or not slotId then
		return 1
	end
	local curve = profile.gs2SlotCurves[slotId]
	if not curve then
		return 1
	end
	local ilvlStart = tonumber(curve.ilvlStart or 0) or 0
	local ilvlEnd = tonumber(curve.ilvlEnd or ilvlStart) or ilvlStart
	local multiplierHigh = tonumber(curve.multiplierHigh or 1) or 1
	local level = tonumber(itemLevel or 0) or 0
	if level <= ilvlStart or ilvlEnd <= ilvlStart then
		return 1
	end
	if level >= ilvlEnd then
		return multiplierHigh
	end
	local progress = (level - ilvlStart) / (ilvlEnd - ilvlStart)
	return 1 - ((1 - multiplierHigh) * progress)
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

function GS_CreateCapContext(unit)
	return {
		meleeHitBonus = 0,
		spellHitBonus = 0,
		targetSpellHitBonus = 0,
		expertiseBonus = 0,
		defenseSkillBonus = 0,
		arpBonus = 0,
		liveMeleeHitBonus = 0,
		liveSpellHitBonus = 0,
		liveTargetSpellHitBonus = 0,
		liveExpertiseBonus = 0,
		liveDefenseSkillBonus = 0,
		liveArpBonus = 0,
		unit = unit,
	}
end

function GS_AddToCapContext(context, key, amount)
	if not context or not key then
		return
	end
	context[key] = (context[key] or 0) + (amount or 0)
end

function GS_GetBaseCapContext(specKey)
	local capProfile = GS_CAP_PROFILES[specKey]
	local context = GS_CreateCapContext(nil)
	if capProfile and capProfile.pools then
		for _, pool in pairs(capProfile.pools) do
			context.meleeHitBonus = max(context.meleeHitBonus, pool.meleeHitBonus or 0)
			context.spellHitBonus = max(context.spellHitBonus, pool.spellHitBonus or 0)
			context.expertiseBonus = max(context.expertiseBonus, pool.expertiseBonus or 0)
			context.defenseSkillBonus = max(context.defenseSkillBonus, pool.defenseSkillBonus or 0)
			context.arpBonus = max(context.arpBonus, pool.arpBonus or 0)
		end
	end
	return context
end

function GS_GetCapWeaponSubTypes(snapshot)
	local subTypes = {}
	if not snapshot or not snapshot.items then
		return subTypes
	end
	for index = 1, #snapshot.items do
		local item = snapshot.items[index].item
		local slotId = snapshot.items[index].slotId
		if item and (slotId == 16 or slotId == 17) then
			subTypes[string.upper(tostring(item.subType or ""))] = true
		end
	end
	return subTypes
end

function GS_GetRacialCapContext(snapshot)
	local context = GS_CreateCapContext(snapshot and snapshot.unit or nil)
	local raceToken = snapshot and snapshot.raceToken and string.upper(tostring(snapshot.raceToken)) or nil
	local racial = raceToken and GS_PERMANENT_CAP_RACIALS and GS_PERMANENT_CAP_RACIALS[raceToken] or nil
	if not racial then
		return context
	end
	local weaponSubTypes = GS_GetCapWeaponSubTypes(snapshot)
	local expertise = racial.EXPERTISE
	if expertise and expertise.subTypes then
		for subType in pairs(weaponSubTypes) do
			if expertise.subTypes[subType] then
				context.expertiseBonus = expertise.bonus or 0
				break
			end
		end
	end
	return context
end

function GS_GetTemporaryCapContext(unit)
	local context = GS_CreateCapContext(unit)
	if unit and UnitExists(unit) and UnitIsVisible(unit) then
		for index = 1, #(GS_LIVE_CAP_BUFFS.HELPFUL or {}) do
			local aura = GS_LIVE_CAP_BUFFS.HELPFUL[index]
			local auraName = GS_GetAuraNameFromId(aura.spellId)
			if auraName and GS_UnitHasAuraByName(unit, "HELPFUL", auraName) then
				GS_AddToCapContext(context, "liveMeleeHitBonus", aura.meleeHitBonus or 0)
				GS_AddToCapContext(context, "liveSpellHitBonus", aura.spellHitBonus or 0)
				GS_AddToCapContext(context, "liveExpertiseBonus", aura.expertiseBonus or 0)
				GS_AddToCapContext(context, "liveDefenseSkillBonus", aura.defenseSkillBonus or 0)
				GS_AddToCapContext(context, "liveArpBonus", aura.arpBonus or 0)
			end
		end
	end
	if unit and UnitIsUnit(unit, "player") and UnitExists("target") then
		for index = 1, #(GS_LIVE_CAP_BUFFS.HARMFUL or {}) do
			local aura = GS_LIVE_CAP_BUFFS.HARMFUL[index]
			local auraName = GS_GetAuraNameFromId(aura.spellId)
			if auraName and GS_UnitHasAuraByName("target", "HARMFUL", auraName) then
				GS_AddToCapContext(context, "liveTargetSpellHitBonus", aura.targetSpellHitBonus or 0)
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
		return max(0, (segment.threshold - (context.meleeHitBonus or 0)) * GS_RATING_CONVERSIONS.MELEE_HIT)
	end
	if segment.mode == "SPELL_HIT_PERCENT" then
		return max(0, (segment.threshold - (context.spellHitBonus or 0) - (context.targetSpellHitBonus or 0)) * GS_RATING_CONVERSIONS.SPELL_HIT)
	end
	if segment.mode == "EXPERTISE_POINTS" then
		return max(0, (segment.threshold - (context.expertiseBonus or 0)) * GS_RATING_CONVERSIONS.EXPERTISE)
	end
	if segment.mode == "DEFENSE_SKILL" then
		return max(0, (segment.threshold - 400 - (context.defenseSkillBonus or 0)) * GS_RATING_CONVERSIONS.DEFENSE)
	end
	return max(0, segment.threshold or 0)
end

function GS_IsRoguePoisonCapSpec(specKey)
	return specKey == "ROGUE_ASSASSINATION" or specKey == "ROGUE_COMBAT" or specKey == "ROGUE_SUBTLETY"
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
	if not targetSegment and poolStat == "SPELL_HIT" then
		targetSegment = GS_FindCapSegment(pool, "SPELL_HIT_PERCENT")
	elseif not targetSegment and poolStat == "HIT" then
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
		return 400 + floor(((statValue or 0) / GS_RATING_CONVERSIONS.DEFENSE) + (context.defenseSkillBonus or 0) + 0.5), targetSegment and targetSegment.threshold or 540, false
	end
	if poolStat == "EXPERTISE" then
		return floor(((statValue or 0) / GS_RATING_CONVERSIONS.EXPERTISE) + (context.expertiseBonus or 0) + 0.5), targetSegment and targetSegment.threshold or 26, false
	end
	if (poolStat == "HIT" or poolStat == "SPELL_HIT") and targetSegment and targetSegment.mode == "SPELL_HIT_PERCENT" then
		return ((statValue or 0) / GS_RATING_CONVERSIONS.SPELL_HIT) + (context.spellHitBonus or 0) + (context.targetSpellHitBonus or 0), targetSegment.threshold or 17, false
	end
	if poolStat == "HIT" and targetSegment and targetSegment.mode == "MELEE_HIT_PERCENT" then
		return ((statValue or 0) / GS_RATING_CONVERSIONS.MELEE_HIT) + (context.meleeHitBonus or 0), targetSegment.threshold or 8, false
	end
	if poolStat == "ARP" then
		return floor((statValue or 0) + (context.arpBonus or 0) + 0.5), floor((resolvedThreshold or 0) + 0.5), true
	end
	return floor((statValue or 0) + 0.5), floor((resolvedThreshold or 0) + 0.5), true
end

function GS_GetCapPoolContextBonus(poolStat, targetSegment, context)
	if not context then
		return 0
	end
	if poolStat == "SPELL_HIT" or (poolStat == "HIT" and targetSegment and targetSegment.mode == "SPELL_HIT_PERCENT") then
		return (context.spellHitBonus or 0) + (context.targetSpellHitBonus or 0)
	end
	if poolStat == "HIT" and targetSegment and targetSegment.mode == "MELEE_HIT_PERCENT" then
		return context.meleeHitBonus or 0
	end
	if poolStat == "EXPERTISE" then
		return context.expertiseBonus or 0
	end
	if poolStat == "DEFENSE" then
		return context.defenseSkillBonus or 0
	end
	if poolStat == "ARP" then
		return context.arpBonus or 0
	end
	return 0
end

function GS_GetCapPoolTemporaryBonus(poolStat, targetSegment, context)
	return GS_GetCapPoolContextBonus(poolStat, targetSegment, context)
end

function GS_DidCapPoolUseLiveBuffs(poolStat, targetSegment, context)
	if not targetSegment or not context then
		return false
	end
	if targetSegment.mode == "MELEE_HIT_PERCENT" then
		return (context.liveMeleeHitBonus or 0) > 0
	end
	if targetSegment.mode == "SPELL_HIT_PERCENT" then
		return ((context.liveSpellHitBonus or 0) > 0) or ((context.liveTargetSpellHitBonus or 0) > 0)
	end
	if targetSegment.mode == "EXPERTISE_POINTS" then
		return (context.liveExpertiseBonus or 0) > 0
	end
	if targetSegment.mode == "DEFENSE_SKILL" then
		return (context.liveDefenseSkillBonus or 0) > 0
	end
	if poolStat == "ARP" then
		return (context.liveArpBonus or 0) > 0
	end
	return false
end

function GS_GetCapPoolStatValue(poolStat, totalStats)
	if not totalStats then
		return 0
	end
	if poolStat == "SPELL_HIT" then
		return totalStats.HIT or 0
	end
	return totalStats[poolStat] or 0
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
	local current, target, ratingSummary = GS_GetCapPoolDisplay(poolStat, statValue, targetSegment, resolvedThreshold, context)
	local progress = (target or 0) > 0 and min(max((current or 0) / target, 0), 1) or 0
	local contextBonus = GS_GetCapPoolContextBonus(poolStat, targetSegment, context)
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
		contextBonus = contextBonus,
		capped = progress >= 1,
		usedLiveBuffs = GS_DidCapPoolUseLiveBuffs(poolStat, targetSegment, context),
		bonusGs2 = 0,
	}
end

function GS_ApplyTemporaryCapInfo(poolBreakdown, statValue, temporaryContext)
	if not poolBreakdown then
		return
	end
	local poolStat = poolBreakdown.stat
	local targetSegment = poolBreakdown.targetSegment
	local targetThreshold = poolBreakdown.targetThreshold
	local infoContext = temporaryContext or GS_CreateCapContext(nil)
	local displayCurrent, displayTarget = GS_GetCapPoolDisplay(poolStat, statValue, targetSegment, targetThreshold, infoContext)
	poolBreakdown.temporaryContextBonus = GS_GetCapPoolTemporaryBonus(poolStat, targetSegment, temporaryContext)
	poolBreakdown.displayCurrent = displayCurrent
	poolBreakdown.displayTarget = displayTarget
	poolBreakdown.usedLiveBuffs = GS_DidCapPoolUseLiveBuffs(poolStat, targetSegment, temporaryContext)
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
	local capProfile = GS_CAP_PROFILES[snapshot.specKey]
	local profile = snapshot.classToken and select(1, GS_GetProfile(snapshot.classToken, snapshot.specKey)) or GS_SPEC_PROFILES[snapshot.specKey]
	local totalStats = GS_CollectSnapshotStats(snapshot)
	if not capProfile or not profile or not profile.pve then
		return 0, nil, totalStats
	end
	local permanentContext = GS_GetBaseCapContext(snapshot.specKey)
	local racialContext = GS_GetRacialCapContext(snapshot)
	for key, value in pairs(racialContext) do
		if type(value) == "number" and value ~= 0 then
			GS_AddToCapContext(permanentContext, key, value)
		end
	end
	local temporaryContext = GS_GetTemporaryCapContext(snapshot.unit)
	local breakdown = { pools = {}, summary = nil, context = permanentContext, permanentContext = permanentContext, temporaryContext = temporaryContext, preCapGs2 = preCapGs2 or 0 }
	local order = capProfile.order or {}
	for index = 1, #order do
		local stat = order[index]
		local pool = capProfile.pools and capProfile.pools[stat]
		local baseWeight = profile.pve[stat] or (stat == "SPELL_HIT" and profile.pve.HIT) or nil
		local statValue = GS_GetCapPoolStatValue(stat, totalStats)
		if pool and baseWeight and statValue > 0 then
			local poolBreakdown = GS_ApplyCapPool(stat, statValue, baseWeight, pool, permanentContext, snapshot.specKey)
			poolBreakdown.permanentContextBonus = poolBreakdown.contextBonus or 0
			GS_ApplyTemporaryCapInfo(poolBreakdown, statValue, temporaryContext)
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

GS_RangedHelperClassBySubtype = {
	WAND = { MAGE = true, PRIEST = true, WARLOCK = true },
	BOW = { HUNTER = true, ROGUE = true, WARRIOR = true },
	GUN = { HUNTER = true, ROGUE = true, WARRIOR = true },
	CROSSBOW = { HUNTER = true, ROGUE = true, WARRIOR = true },
	THROWN = { ROGUE = true, WARRIOR = true },
	LIBRAM = { PALADIN = true },
	LIBRAMS = { PALADIN = true },
	TOTEM = { SHAMAN = true },
	TOTEMS = { SHAMAN = true },
	IDOL = { DRUID = true },
	IDOLS = { DRUID = true },
	SIGIL = { DEATHKNIGHT = true },
	SIGILS = { DEATHKNIGHT = true },
}

function GS_IsRangedHelperCompatible(item, classToken, profile)
	if not item or not classToken then
		return false
	end
	if profile and profile.ranged and (item.equipLoc == "INVTYPE_RANGED" or item.equipLoc == "INVTYPE_RANGEDRIGHT" or item.equipLoc == "INVTYPE_THROWN") then
		return true
	end
	local subType = string.upper(tostring(item.subType or ""))
	local allowedClasses = GS_RangedHelperClassBySubtype[subType]
	if not allowedClasses then
		return false
	end
	if item.equipLoc == "INVTYPE_RELIC" then
		return allowedClasses[classToken] == true
	end
	if item.equipLoc == "INVTYPE_RANGED" or item.equipLoc == "INVTYPE_RANGEDRIGHT" or item.equipLoc == "INVTYPE_THROWN" then
		return allowedClasses[classToken] == true
	end
	return false
end

function GS_GetRoleSignatureKind(item)
	if not item then
		return nil
	end
	local stats = item.stats or {}
	local hasTank = (stats.DEFENSE or 0) > 0 or (stats.DODGE or 0) > 0 or (stats.PARRY or 0) > 0 or (stats.BLOCK or 0) > 0 or (stats.BLOCKVALUE or 0) > 0 or item.equipLoc == "INVTYPE_SHIELD"
	local hasHealer = (stats.MP5 or 0) > 0 or (stats.SPI or 0) > 0
	local hasCaster = (stats.SP or 0) > 0 or (stats.INT or 0) > 0
	local hasPhysical = (stats.STR or 0) > 0 or (stats.AGI or 0) > 0 or (stats.AP or 0) > 0 or (stats.RAP or 0) > 0 or (stats.ARP or 0) > 0 or (stats.EXPERTISE or 0) > 0
	local hasRanged = (stats.RAP or 0) > 0 or item.equipLoc == "INVTYPE_RANGED" or item.equipLoc == "INVTYPE_RANGEDRIGHT" or item.equipLoc == "INVTYPE_THROWN"

	if hasTank then
		return "TANK"
	end
	if hasHealer and hasCaster and not hasPhysical then
		return "HEALER"
	end
	if hasCaster and not hasPhysical then
		return "CASTER"
	end
	if hasRanged then
		return "RANGED"
	end
	if hasPhysical then
		return "MELEE"
	end
	return nil
end

local function GS_ShouldIgnoreArmorDowngrade(classToken, profile)
	if profile and profile.allowLowerArmor then
		return true
	end
	if classToken ~= "DRUID" or not profile then
		return false
	end
	return profile.role == "CASTER" or profile.role == "HEALER"
end

function GS_IsItemCompatible(item, classToken, profile)
	if not item or not profile or item.slot == 0 then return false end
	local stats = item.stats or {}
	local roleSignature = GS_GetRoleSignatureKind(item)
	local allowHybridCasterItems = profile.hybridCasterItems and true or false
	if GS_ARMOR_CLASS_ORDER[profile.armor] and item.armorRank and item.slot ~= 15 and item.slot ~= 2 and item.slot ~= 11 and item.slot ~= 13 then
		if item.armorRank < GS_ARMOR_CLASS_ORDER[profile.armor] and not GS_ShouldIgnoreArmorDowngrade(classToken, profile) then return false end
	end
	if item.equipLoc == "INVTYPE_SHIELD" and not profile.shield then return false end
	if item.equipLoc == "INVTYPE_WEAPONOFFHAND" and not profile.dualwield then return false end
	if item.equipLoc == "INVTYPE_HOLDABLE" and profile.role ~= "CASTER" and profile.role ~= "HEALER" then return false end
	if item.equipLoc == "INVTYPE_RELIC" and not GS_IsRangedHelperCompatible(item, classToken, profile) then return false end
	if (item.equipLoc == "INVTYPE_RANGED" or item.equipLoc == "INVTYPE_RANGEDRIGHT" or item.equipLoc == "INVTYPE_THROWN") and not GS_IsRangedHelperCompatible(item, classToken, profile) then return false end
	if classToken == "HUNTER" and (item.equipLoc == "INVTYPE_SHIELD" or item.equipLoc == "INVTYPE_HOLDABLE") then return false end
	if (profile.role == "CASTER" or profile.role == "HEALER") and (stats.STR or 0) > 0 and (stats.SP or 0) == 0 and (stats.INT or 0) == 0 then return false end
	if (profile.role == "MELEE" or profile.role == "RANGED") and (stats.SP or 0) > 0 and (stats.STR or 0) == 0 and (stats.AGI or 0) == 0 and (stats.AP or 0) == 0 and (stats.RAP or 0) == 0 and not allowHybridCasterItems then return false end
	if profile.role == "TANK" and roleSignature == "CASTER" then return false end
	if profile.role == "TANK" and roleSignature == "HEALER" then return false end
	if (profile.role == "CASTER" or profile.role == "HEALER") and (roleSignature == "MELEE" or roleSignature == "RANGED") and (stats.SP or 0) == 0 and (stats.INT or 0) == 0 then return false end
	if (profile.role == "MELEE" or profile.role == "RANGED") and (roleSignature == "CASTER" or roleSignature == "HEALER") and (stats.STR or 0) == 0 and (stats.AGI or 0) == 0 and (stats.AP or 0) == 0 and (stats.RAP or 0) == 0 and not allowHybridCasterItems then return false end
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
	if item and item.unresolvedData then
		if explain then
			explain.flags[#explain.flags + 1] = "Item score withheld: unresolved gem/enchant stat data"
			explain.pve.final = nil
			explain.pvp.final = nil
		end
		return nil, nil, explain
	end
	local pveScore, pvpScore = item.legacyBase, item.legacyBase
	local pveScale = profile.gs2Scale or 1
	local slotMultiplier = GS_GetSlotMultiplier(profile, item.slot, item.level)
	local compatibilityPenaltyScale = compatible and 1 or GS_INCOMPATIBLE_PVE_BONUS_SCALE
	local pveBonusBucket = 0
	local pveStatRaw = GS_ScoreStats(item.stats, profile.pve)
	local pvpStatRaw = GS_ScoreStats(item.stats, profile.pvp)
	local pveStatBonus = floor(pveStatRaw * GS_GS2_STAT_SCALE)
	local pvpStatBonus = floor(pvpStatRaw * GS_GS2_STAT_SCALE)
	pveBonusBucket = pveBonusBucket + pveStatBonus
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
			pveBonusBucket = pveBonusBucket + gemPveBonus
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
	if GS_ENCHANT_SLOTS[item.equipLoc] then
		if item.hasEnchant then
			local enchantInfo = GS_GetEnchantInfo(item)
			local enchantStats = enchantInfo and enchantInfo.stats or nil
			local pveEnchantRaw = GS_ScoreStats(enchantStats, profile.pve)
			local pvpEnchantRaw = GS_ScoreStats(enchantStats, profile.pvp)
			local pveEnchant = pveEnchantRaw > 0 and floor(pveEnchantRaw * GS_ENCHANT_SCALE) or 0
			local pvpEnchant = pvpEnchantRaw > 0 and floor(pvpEnchantRaw * GS_ENCHANT_SCALE) or 0
			pveBonusBucket = pveBonusBucket + pveEnchant
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
	local pveScaledBonus = pveBonusBucket > 0 and floor(pveBonusBucket * pveScale * compatibilityPenaltyScale) or 0
	pveScore = pveScore + pveScaledBonus
	if explain and (pveScaledBonus ~= pveBonusBucket or pveScale ~= 1 or not compatible) then
		local penaltySuffix = compatible and "" or (" * " .. GS_FormatNumber(GS_INCOMPATIBLE_PVE_BONUS_SCALE))
		explain.pve.parts[#explain.pve.parts + 1] = { label = "Spec scale", formula = "floor(" .. pveBonusBucket .. " * " .. GS_FormatNumber(pveScale) .. penaltySuffix .. ")", delta = pveScaledBonus - pveBonusBucket }
		if not compatible then
			explain.flags[#explain.flags + 1] = "Item penalized: offspec / incompatible armor type / incompatible weapon type"
		end
	end
	local pveBaseScore = pveScore > 0 and pveScore or 0
	local pvpBaseScore = pvpScore > 0 and pvpScore or 0
	local pveMultiplier = GS_GetResilienceMultiplier(item.resilience, "PVE")
	local pvpMultiplier = GS_GetResilienceMultiplier(item.resilience, "PVP")
	pveScore = floor(pveBaseScore * pveMultiplier)
	pvpScore = floor(pvpBaseScore * pvpMultiplier)
	local pvePreSlotScore = pveScore
	if slotMultiplier ~= 1 then
		pveScore = floor(pveScore * slotMultiplier)
	end
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
		if slotMultiplier ~= 1 then
			explain.pve.parts[#explain.pve.parts + 1] = { label = "Slot multiplier", formula = "floor(" .. pvePreSlotScore .. " * " .. GS_FormatNumber(slotMultiplier) .. ")", delta = pveScore - pvePreSlotScore }
		end
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

function GS2_GetQuality(score)
	if score > 5999 then score = 5999 end
	if not score then return 0, 0, 0, "Trash" end
	for i = 0, 6 do
		if score > i * 1000 and score <= ((i + 1) * 1000) then
			local red = GS_QUALITY[(i + 1) * 1000].Red.A + (((score - GS_QUALITY[(i + 1) * 1000].Red.B) * GS_QUALITY[(i + 1) * 1000].Red.C) * GS_QUALITY[(i + 1) * 1000].Red.D)
			local blue = GS_QUALITY[(i + 1) * 1000].Green.A + (((score - GS_QUALITY[(i + 1) * 1000].Green.B) * GS_QUALITY[(i + 1) * 1000].Green.C) * GS_QUALITY[(i + 1) * 1000].Green.D)
			local green = GS_QUALITY[(i + 1) * 1000].Blue.A + (((score - GS_QUALITY[(i + 1) * 1000].Blue.B) * GS_QUALITY[(i + 1) * 1000].Blue.C) * GS_QUALITY[(i + 1) * 1000].Blue.D)
			return red, green, blue, GS_QUALITY[(i + 1) * 1000].Description
		end
	end
	return 0.1, 0.1, 0.1
end

function GS2_GetItemScore(itemLink)
	return GS_CalculateLegacyBase(itemLink)
end
