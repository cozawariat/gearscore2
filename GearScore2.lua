-------------------------------------------------------------------------------
--                               GearScore2                                  --
-------------------------------------------------------------------------------

local floor, pairs, ipairs, select, tonumber, tostring = floor, pairs, ipairs, select, tonumber, tostring
local GetTime, UnitName, UnitGUID, UnitClass, UnitIsPlayer = GetTime, UnitName, UnitGUID, UnitClass, UnitIsPlayer
local UnitIsUnit, CanInspect, NotifyInspect, ClearInspectPlayer = UnitIsUnit, CanInspect, NotifyInspect, ClearInspectPlayer
local GetInventoryItemLink, GetItemInfo, GetItemStats, GetItemGem = GetInventoryItemLink, GetItemInfo, GetItemStats, GetItemGem
local GetTalentTabInfo, GetMouseFocus, IsEquippableItem = GetTalentTabInfo, GetMouseFocus, IsEquippableItem
local IsControlKeyDown = IsControlKeyDown

local GS_PlayerIsInCombat = false
local GS_SCAN_TEXT = "|cffaaaaaaScanning...|r"
local GS_INSPECT_THROTTLE = 0.35
local GS_RECENT_WINDOW = 1.5
local GS_ACTIVE_TIMEOUT = 2.5
local GS_CACHE_TTL = 180
local GS_FRESH_TTL = 15
local GS_READY_DELAY = 0.15
local GS_READY_RETRY_LIMIT = 4
local GS_MIN_INSPECT_ITEMS = 8
local GS_FORCE_POLL_DELAY = 0.20

GS_Settings = GS2_Settings or GS_Settings

local GS_InspectQueue, GS_InspectCache, GS_ItemCache, GS_ParsedLinkCache = {}, {}, {}, {}
local GS_InspectState = { active = nil, lastInspectAt = 0, queued = {}, recent = {} }
local GS_GetTooltipUnit
local GS_RefreshTooltip
local GS_ExplainTooltip
local GS_ExplainState = { owner = nil, itemLink = nil, itemSlot = nil }

local GS_STAT_KEYS = {
	ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_STAMINA_SHORT = "STA",
	ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI", ITEM_MOD_ATTACK_POWER_SHORT = "AP",
	ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP", ITEM_MOD_SPELL_POWER_SHORT = "SP", ITEM_MOD_HIT_RATING_SHORT = "HIT",
	ITEM_MOD_CRIT_RATING_SHORT = "CRIT", ITEM_MOD_HASTE_RATING_SHORT = "HASTE", ITEM_MOD_RESILIENCE_RATING_SHORT = "RESILIENCE",
	ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ARP", ITEM_MOD_EXPERTISE_RATING_SHORT = "EXPERTISE",
	ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEFENSE", ITEM_MOD_DODGE_RATING_SHORT = "DODGE", ITEM_MOD_PARRY_RATING_SHORT = "PARRY",
	ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK", ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVALUE", ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
}

local GS_ITEM_SLOTS = {
	INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
	INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11,
	INVTYPE_TRINKET = 13, INVTYPE_CLOAK = 15, INVTYPE_WEAPON = 16, INVTYPE_SHIELD = 17, INVTYPE_2HWEAPON = 16,
	INVTYPE_WEAPONMAINHAND = 16, INVTYPE_WEAPONOFFHAND = 17, INVTYPE_HOLDABLE = 17, INVTYPE_RANGED = 18,
	INVTYPE_THROWN = 18, INVTYPE_RANGEDRIGHT = 18, INVTYPE_RELIC = 18,
}

local function GS_ResolveUnitByGUID(guid)
	if not guid then return nil end
	local candidates = {
		"mouseover", "target", "focus",
		"party1", "party2", "party3", "party4",
		"raid1", "raid2", "raid3", "raid4", "raid5", "raid6", "raid7", "raid8", "raid9", "raid10",
		"raid11", "raid12", "raid13", "raid14", "raid15", "raid16", "raid17", "raid18", "raid19", "raid20",
		"raid21", "raid22", "raid23", "raid24", "raid25", "raid26", "raid27", "raid28", "raid29", "raid30",
		"raid31", "raid32", "raid33", "raid34", "raid35", "raid36", "raid37", "raid38", "raid39", "raid40",
	}
	for index = 1, #candidates do
		local unit = candidates[index]
		if UnitGUID(unit) == guid then return unit end
	end

	local _, tooltipUnit = GS_GetTooltipUnit()
	if tooltipUnit and UnitGUID(tooltipUnit) == guid then return tooltipUnit end
end

GS_GetTooltipUnit = function()
	local _, unit = GameTooltip:GetUnit()
	if unit and UnitName(unit) then return UnitName(unit), unit end
	if UnitName("mouseover") then return UnitName("mouseover"), "mouseover" end
	if ElvUI or ShadowUF or VuhDo then
		local frame = GetMouseFocus()
		local customUnit = frame and (frame.unit or frame.raidid)
		if customUnit and UnitName(customUnit) then return UnitName(customUnit), customUnit end
	end
end

local function GS_ParseItemLink(itemLink)
	if not itemLink then return nil end
	local cached = GS_ParsedLinkCache[itemLink]
	if cached then return cached end
	local linkData = string.match(itemLink, "item[%-?%d:]+")
	if not linkData then return nil end
	local values = {}
	for value in string.gmatch(linkData, "([^:]+)") do values[#values + 1] = tonumber(value) or 0 end
	cached = { enchantId = values[3] or 0 }
	GS_ParsedLinkCache[itemLink] = cached
	return cached
end

local function GS_GetNormalizedStats(itemLink)
	local stats, sockets = {}, 0
	local raw = GetItemStats(itemLink)
	if not raw then return stats, sockets end
	for key, value in pairs(raw) do
		if GS_SocketStatKeys[key] then
			sockets = sockets + (tonumber(value) or 0)
		else
			local short = GS_STAT_KEYS[key] or GS_StatAliases[key]
			if short then stats[short] = (stats[short] or 0) + (tonumber(value) or 0) end
		end
	end
	return stats, sockets
end

local function GS_DetectSpec(classToken, inspect)
	local order = GS_ClassSpecOrder[classToken]
	if not order then return GS_ClassDefaults[classToken] end
	local bestPoints, bestSpec = -1, GS_ClassDefaults[classToken]
	for tab = 1, 3 do
		local _, _, _, _, points = GetTalentTabInfo(tab, inspect, false)
		if points and points > bestPoints then bestPoints, bestSpec = points, (order[tab] or bestSpec) end
	end
	return bestSpec
end

local function GS_GetProfile(classToken, specKey)
	specKey = (specKey and GS_SpecProfiles[specKey]) and specKey or GS_ClassDefaults[classToken]
	return GS_SpecProfiles[specKey], specKey
end

local function GS_ScoreStats(stats, weights)
	local total = 0
	if not stats or not weights then return total end
	for stat, value in pairs(stats) do if weights[stat] then total = total + value * weights[stat] end end
	return total
end

local function GS_FormatNumber(value)
	value = tonumber(value) or 0
	if value == floor(value) then
		return tostring(value)
	end
	return string.format("%.2f", value)
end

local function GS_AppendExplainLine(lines, text)
	lines[#lines + 1] = text
end

local function GS_BuildTopStats(stats, weights)
	local entries = {}
	if not stats or not weights then return entries end
	for stat, value in pairs(stats) do
		local weight = weights[stat]
		if weight and value and value ~= 0 then
			entries[#entries + 1] = { stat = stat, value = value, weight = weight, score = value * weight }
		end
	end
	table.sort(entries, function(a, b) return a.score > b.score end)
	return entries
end

local function GS_CalculateLegacyBase(itemLink)
	if not itemLink then return 0, 0, nil, nil, nil, nil, 0, nil, 1, nil end
	local qualityScale, scale = 1, 1.8618
	local itemName, _, itemRarity, itemLevel, _, _, itemSubType, _, itemEquipLoc = GetItemInfo(itemLink)
	if not itemName or not itemRarity or not itemLevel or not itemEquipLoc then return 0, 0, nil, nil, nil, nil, 0, nil, 1, itemSubType end
	if itemRarity == 5 then qualityScale, itemRarity = 1.3, 4 elseif itemRarity == 1 or itemRarity == 0 then qualityScale, itemRarity = 0.005, 2 end
	if itemRarity == 7 then itemRarity, itemLevel = 3, 187.05 end
	if GS_ItemTypes[itemEquipLoc] then
		local tableRef = itemLevel > 120 and GS_Formula.A or GS_Formula.B
		if itemRarity >= 2 and itemRarity <= 4 then
			local red, green, blue = GearScore_GetQuality((floor(((itemLevel - tableRef[itemRarity].A) / tableRef[itemRarity].B) * scale)) * 11.25)
			local score = floor(((itemLevel - tableRef[itemRarity].A) / tableRef[itemRarity].B) * GS_ItemTypes[itemEquipLoc].SlotMOD * scale * qualityScale)
			if itemLevel == 187.05 then itemLevel = 0 end
			if score < 0 then score, red, green, blue = 0, GearScore_GetQuality(1) end
			return score, itemLevel, GS_ItemTypes[itemEquipLoc].ItemSlot, red, green, blue, 0, itemEquipLoc, 1, itemSubType
		end
	end
	return -1, itemLevel or 0, 50, 1, 1, 1, 0, itemEquipLoc, 1, itemSubType
end

local function GS_GetItemData(itemLink)
	if not itemLink then return nil end
	local cached = GS_ItemCache[itemLink]
	if cached then return cached end
	local itemName, _, itemRarity, itemLevel, _, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(itemLink)
	if not itemName or not itemEquipLoc then return nil end
	local legacyBase = GS_CalculateLegacyBase(itemLink)
	local parsed = GS_ParseItemLink(itemLink) or { enchantId = 0 }
	local stats, socketCount = GS_GetNormalizedStats(itemLink)
	local gemStats, gemCount = {}, 0
	for index = 1, 4 do
		local gemName = GetItemGem(itemLink, index)
		if gemName then
			gemCount = gemCount + 1
			local gemLink = select(2, GetItemGem(itemLink, index))
			if gemLink then gemStats[index] = select(1, GS_GetNormalizedStats(gemLink)) end
		end
	end
	cached = {
		link = itemLink, name = itemName, rarity = itemRarity, level = itemLevel or 0, type = itemType, subType = itemSubType,
		equipLoc = itemEquipLoc, slot = GS_ITEM_SLOTS[itemEquipLoc] or 0, legacyBase = legacyBase > 0 and legacyBase or 0,
		stats = stats, socketCount = socketCount, gemCount = gemCount, gemStats = gemStats, enchantId = parsed.enchantId or 0,
		hasEnchant = (parsed.enchantId or 0) > 0, resilience = stats.RESILIENCE or 0, armorRank = GS_ArmorClassOrder[itemSubType],
	}
	GS_ItemCache[itemLink] = cached
	return cached
end

local function GS_IsItemCompatible(item, classToken, profile)
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

local function GS_GetEnchantValue(item, mode)
	local enchant = GS_EnchantValues[item.enchantId]
	if enchant then return mode == "PVP" and (enchant.PVP or enchant.PVE or 0) or (enchant.PVE or enchant.PVP or 0) end
	if item.hasEnchant then return 20 end
	return 0
end

local function GS_ScoreItem(item, classToken, specKey, wantExplain)
	local profile, resolvedSpecKey = GS_GetProfile(classToken, specKey)
	local compatible = GS_IsItemCompatible(item, classToken, profile)
	local explain = nil
	if wantExplain then
		explain = {
			classToken = classToken,
			specKey = resolvedSpecKey,
			compatible = compatible,
			legacyBase = item.legacyBase,
			pve = { base = item.legacyBase, parts = {}, statEntries = GS_BuildTopStats(item.stats, profile and profile.pve or nil), final = 0 },
			pvp = { base = item.legacyBase, parts = {}, statEntries = GS_BuildTopStats(item.stats, profile and profile.pvp or nil), final = 0 },
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
			local gemPveBonus = floor(gemPveRaw * 0.35)
			local gemPvpBonus = floor(gemPvpRaw * 0.35)
			pveScore = pveScore + gemPveBonus
			pvpScore = pvpScore + gemPvpBonus
			if explain then
				explain.pve.parts[#explain.pve.parts + 1] = { label = "Gem " .. index, formula = "(" .. GS_FormatNumber(gemPveRaw) .. " * 0.35)", delta = gemPveBonus }
				explain.pvp.parts[#explain.pvp.parts + 1] = { label = "Gem " .. index, formula = "(" .. GS_FormatNumber(gemPvpRaw) .. " * 0.35)", delta = gemPvpBonus }
			end
		end
	end
	if item.socketCount > item.gemCount then
		local missing = item.socketCount - item.gemCount
		local pvePenalty = floor(item.legacyBase * 0.08 * missing)
		local pvpPenalty = floor(item.legacyBase * 0.07 * missing)
		pveScore = pveScore - pvePenalty
		pvpScore = pvpScore - pvpPenalty
		if explain then
			explain.flags[#explain.flags + 1] = item.gemCount .. "/" .. item.socketCount .. " socketow obsadzonych"
			explain.pve.parts[#explain.pve.parts + 1] = { label = "Brakujace gemy", formula = "(" .. item.legacyBase .. " * 0.08 * " .. missing .. ")", delta = -pvePenalty }
			explain.pvp.parts[#explain.pvp.parts + 1] = { label = "Brakujace gemy", formula = "(" .. item.legacyBase .. " * 0.07 * " .. missing .. ")", delta = -pvpPenalty }
		end
	end
	if GS_EnchantSlots[item.equipLoc] then
		if item.hasEnchant then
			local pveEnchant = GS_GetEnchantValue(item, "PVE")
			local pvpEnchant = GS_GetEnchantValue(item, "PVP")
			pveScore = pveScore + pveEnchant
			pvpScore = pvpScore + pvpEnchant
			if explain then
				explain.pve.parts[#explain.pve.parts + 1] = { label = "Enchant", formula = "lookup(" .. (item.enchantId or 0) .. ")", delta = pveEnchant }
				explain.pvp.parts[#explain.pvp.parts + 1] = { label = "Enchant", formula = "lookup(" .. (item.enchantId or 0) .. ")", delta = pvpEnchant }
			end
		else
			local pvePenalty = floor(item.legacyBase * 0.10)
			local pvpPenalty = floor(item.legacyBase * 0.08)
			pveScore = pveScore - pvePenalty
			pvpScore = pvpScore - pvpPenalty
			if explain then
				explain.flags[#explain.flags + 1] = "Brak enchantu na enchantowalnym slocie"
				explain.pve.parts[#explain.pve.parts + 1] = { label = "Brak enchantu", formula = "(" .. item.legacyBase .. " * 0.10)", delta = -pvePenalty }
				explain.pvp.parts[#explain.pvp.parts + 1] = { label = "Brak enchantu", formula = "(" .. item.legacyBase .. " * 0.08)", delta = -pvpPenalty }
			end
		end
	end
	if item.resilience > 0 then
		local pvePenalty = floor(item.resilience * 0.30)
		local pvpBonus = floor(item.resilience * 0.45)
		pveScore = pveScore - pvePenalty
		pvpScore = pvpScore + pvpBonus
		if explain then
			explain.flags[#explain.flags + 1] = "Resilience: " .. item.resilience
			explain.pve.parts[#explain.pve.parts + 1] = { label = "Kara za resilience", formula = "(" .. item.resilience .. " * 0.30)", delta = -pvePenalty }
			explain.pvp.parts[#explain.pvp.parts + 1] = { label = "Bonus za resilience", formula = "(" .. item.resilience .. " * 0.45)", delta = pvpBonus }
		end
	end

	pveScore = pveScore > 0 and pveScore or 0
	pvpScore = pvpScore > 0 and pvpScore or 0
	if explain then
		explain.pve.final = pveScore
		explain.pvp.final = pvpScore
	end
	return pveScore, pvpScore, explain
end

local function GS_GetHunterLegacy(slotId, item)
	if slotId == 16 then return floor(item.legacyBase * 0.3164) end
	if slotId == 18 and (item.equipLoc == "INVTYPE_RANGEDRIGHT" or item.equipLoc == "INVTYPE_RANGED") then return floor(item.legacyBase * 5.3224) end
	return item.legacyBase
end

local function GS_CollectSnapshot(unit, inspect)
	local name, guid = UnitName(unit), UnitGUID(unit)
	local _, classToken = UnitClass(unit)
	if not name or not guid or not classToken then return nil end
	local specKey = GS_DetectSpec(classToken, inspect)
	local items, fingerprint, levelTotal, itemCount = {}, { guid, classToken, specKey }, 0, 0
	for slotId = 1, 18 do
		if slotId ~= 4 then
			local itemLink = GetInventoryItemLink(unit, slotId)
			fingerprint[#fingerprint + 1] = itemLink or ""
			if itemLink then
				local item = GS_GetItemData(itemLink)
				if item then
					local legacy = classToken == "HUNTER" and GS_GetHunterLegacy(slotId, item) or item.legacyBase
					items[#items + 1] = { slotId = slotId, item = item, legacy = legacy }
					levelTotal, itemCount = levelTotal + (item.level or 0), itemCount + 1
				end
			end
		end
	end
	return { name = name, guid = guid, classToken = classToken, specKey = specKey, items = items, itemCount = itemCount, fingerprint = table.concat(fingerprint, "|"), average = itemCount > 0 and floor(levelTotal / itemCount) or 0 }
end

local function GS_BuildRecord(snapshot)
	local cached = GS_InspectCache[snapshot.guid]
	if cached and cached.fingerprint == snapshot.fingerprint and cached.expiresAt > GetTime() then return cached end
	local gs2, legacy, pvp, detailLinks = 0, 0, 0, {}
	for index = 1, #snapshot.items do
		local entry = snapshot.items[index]
		local itemGS2, itemPVP = GS_ScoreItem(entry.item, snapshot.classToken, snapshot.specKey)
		gs2, legacy, pvp = gs2 + itemGS2, legacy + entry.legacy, pvp + itemPVP
		detailLinks[entry.slotId] = entry.item.link
	end
	cached = { guid = snapshot.guid, name = snapshot.name, classToken = snapshot.classToken, specKey = snapshot.specKey, fingerprint = snapshot.fingerprint, average = snapshot.average, gs2 = floor(gs2), legacy = floor(legacy), pvp = floor(pvp), detailLinks = detailLinks, expiresAt = GetTime() + GS_CACHE_TTL, freshUntil = GetTime() + GS_FRESH_TTL }
	GS_InspectCache[snapshot.guid] = cached
	return cached
end

local function GS_GetRecord(unit)
	local guid = UnitGUID(unit)
	if not guid then return nil end
	local cached = GS_InspectCache[guid]
	if cached and cached.expiresAt > GetTime() then return cached end
	if UnitIsUnit(unit, "player") then
		local snapshot = GS_CollectSnapshot("player", false)
		if snapshot then return GS_BuildRecord(snapshot) end
	end
end

local function GS_AddScoreLines(tooltip, record)
	local r, g, b = GearScore_GetQuality(record.gs2)
	tooltip:AddDoubleLine("GearScore2", tostring(record.gs2), r, g, b, r, g, b)
	r, g, b = GearScore_GetQuality(record.legacy)
	tooltip:AddDoubleLine("Legacy GearScore", tostring(record.legacy), r, g, b, r, g, b)
	r, g, b = GearScore_GetQuality(record.pvp)
	tooltip:AddDoubleLine("PvP GearScore", tostring(record.pvp), r, g, b, r, g, b)
	if GS_Settings["Level"] == 1 then tooltip:AddDoubleLine("Average iLevel", tostring(record.average or 0), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8) end
end

local function GS_HideExplainTooltip()
	if GS_ExplainTooltip and GS_ExplainTooltip:IsShown() then
		GS_ExplainTooltip:Hide()
	end
	GS_ExplainState.owner = nil
	GS_ExplainState.itemLink = nil
	GS_ExplainState.itemSlot = nil
end

local function GS_AddExplainPart(tooltip, title, part, positiveColor)
	local color = positiveColor or { 0.75, 0.95, 0.75 }
	local negativeColor = { 0.95, 0.70, 0.70 }
	local r, g, b = unpack(part.delta >= 0 and color or negativeColor)
	local sign = part.delta >= 0 and "+" or ""
	tooltip:AddDoubleLine(title, sign .. tostring(part.delta), r, g, b, r, g, b)
	tooltip:AddLine("  " .. part.formula, 0.70, 0.70, 0.70, true)
end

local function GS_RenderExplainTooltip(ownerTooltip, itemLink)
	if not GS_ExplainTooltip or not ownerTooltip or not itemLink then
		GS_HideExplainTooltip()
		return
	end
	if GS_PlayerIsInCombat or not IsControlKeyDown() then
		GS_HideExplainTooltip()
		return
	end
	local _, classToken = UnitClass("player")
	local item = GS_GetItemData(itemLink)
	if not item then
		GS_HideExplainTooltip()
		return
	end
	local gs2, pvp, explain = GS_ScoreItem(item, classToken, GS_ClassDefaults[classToken], true)
	if not explain then
		GS_HideExplainTooltip()
		return
	end

	GS_ExplainTooltip:SetOwner(ownerTooltip, "ANCHOR_NONE")
	GS_ExplainTooltip:ClearAllPoints()
	GS_ExplainTooltip:SetPoint("TOPLEFT", ownerTooltip, "TOPRIGHT", 12, 0)
	GS_ExplainTooltip:ClearLines()
	GS_ExplainTooltip:AddLine(item.name or "GearScore2 Explain", 1, 0.82, 0)
	GS_ExplainTooltip:AddDoubleLine("GearScore2", tostring(gs2), 0.85, 0.95, 0.85, 0.85, 0.95, 0.85)
	GS_ExplainTooltip:AddDoubleLine("Legacy GearScore", tostring(item.legacyBase), 0.80, 0.80, 0.80, 0.80, 0.80, 0.80)
	GS_ExplainTooltip:AddDoubleLine("PvP GearScore", tostring(pvp), 0.95, 0.75, 0.45, 0.95, 0.75, 0.45)
	GS_ExplainTooltip:AddLine(" ")
	GS_ExplainTooltip:AddLine("Legacy", 0.95, 0.82, 0.18)
	GS_ExplainTooltip:AddLine("  Legacy = iLevel/slot base = " .. tostring(item.legacyBase), 0.85, 0.85, 0.85, true)
	GS_ExplainTooltip:AddLine(" ")
	GS_ExplainTooltip:AddLine("GearScore2", 0.80, 1.00, 0.80)
	GS_ExplainTooltip:AddLine("  GearScore2 = base + bonuses - penalties", 0.85, 0.85, 0.85, true)
	for index = 1, #explain.pve.parts do
		GS_AddExplainPart(GS_ExplainTooltip, "  " .. explain.pve.parts[index].label, explain.pve.parts[index])
	end
	GS_ExplainTooltip:AddDoubleLine("  Final result", tostring(explain.pve.final), 0.80, 1.00, 0.80, 0.80, 1.00, 0.80)
	GS_ExplainTooltip:AddLine(" ")
	GS_ExplainTooltip:AddLine("PvP GearScore", 1.00, 0.82, 0.58)
	GS_ExplainTooltip:AddLine("  PvP = base + PvP bonuses - PvE penalties", 0.85, 0.85, 0.85, true)
	for index = 1, #explain.pvp.parts do
		GS_AddExplainPart(GS_ExplainTooltip, "  " .. explain.pvp.parts[index].label, explain.pvp.parts[index], { 1.00, 0.82, 0.58 })
	end
	GS_ExplainTooltip:AddDoubleLine("  Final result", tostring(explain.pvp.final), 1.00, 0.82, 0.58, 1.00, 0.82, 0.58)
	if #explain.flags > 0 then
		GS_ExplainTooltip:AddLine(" ")
		GS_ExplainTooltip:AddLine("Flags", 1.00, 0.60, 0.60)
		for index = 1, #explain.flags do
			GS_ExplainTooltip:AddLine("  - " .. explain.flags[index], 0.95, 0.78, 0.78, true)
		end
	end
	if explain.pve.statEntries and #explain.pve.statEntries > 0 then
		GS_ExplainTooltip:AddLine(" ")
		GS_ExplainTooltip:AddLine("Top PvE stats", 0.72, 0.92, 1.00)
		for index = 1, math.min(4, #explain.pve.statEntries) do
			local entry = explain.pve.statEntries[index]
			GS_ExplainTooltip:AddLine("  " .. entry.stat .. ": " .. entry.value .. " * " .. GS_FormatNumber(entry.weight) .. " = " .. GS_FormatNumber(entry.score), 0.75, 0.88, 0.98, true)
		end
	end
	if explain.pvp.statEntries and #explain.pvp.statEntries > 0 then
		GS_ExplainTooltip:AddLine(" ")
		GS_ExplainTooltip:AddLine("Top PvP stats", 0.72, 0.92, 1.00)
		for index = 1, math.min(4, #explain.pvp.statEntries) do
			local entry = explain.pvp.statEntries[index]
			GS_ExplainTooltip:AddLine("  " .. entry.stat .. ": " .. entry.value .. " * " .. GS_FormatNumber(entry.weight) .. " = " .. GS_FormatNumber(entry.score), 0.75, 0.88, 0.98, true)
		end
	end
	GS_ExplainTooltip:Show()
	GS_ExplainState.owner = ownerTooltip
	GS_ExplainState.itemLink = itemLink
end

local function GS_AddItemLines(tooltip, itemLink)
	if not itemLink or not IsEquippableItem(itemLink) then return end
	local _, classToken = UnitClass("player")
	local item = GS_GetItemData(itemLink)
	if not item then return end
	local gs2, pvp = GS_ScoreItem(item, classToken, GS_ClassDefaults[classToken])
	local r, g, b = GearScore_GetQuality(gs2)
	tooltip:AddDoubleLine("GearScore2", tostring(gs2), r, g, b, r, g, b)
	tooltip:AddDoubleLine("Legacy GearScore", tostring(item.legacyBase), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
	tooltip:AddDoubleLine("PvP GearScore", tostring(pvp), 0.95, 0.55, 0.25, 0.95, 0.55, 0.25)
	if GS_Settings["Level"] == 1 then tooltip:AddLine("iLevel " .. tostring(item.level or 0), 0.65, 0.65, 0.65) end
	GS_RenderExplainTooltip(tooltip, itemLink)
end

local function GS_QueueInspect(unit)
	local guid, now = UnitGUID(unit), GetTime()
	if not guid or UnitIsUnit(unit, "player") or GS_InspectState.queued[guid] then return end
	if GS_InspectState.active and GS_InspectState.active.guid == guid then return end
	if GS_InspectState.recent[guid] and (now - GS_InspectState.recent[guid]) < GS_RECENT_WINDOW then return end
	GS_InspectState.queued[guid] = true
	GS_InspectQueue[#GS_InspectQueue + 1] = { guid = guid, unit = unit, queuedAt = now }
end

local function GS_ProcessInspectQueue()
	local now, active = GetTime(), GS_InspectState.active
	if GS_ExplainState.owner and GS_ExplainState.itemLink then
		if GS_PlayerIsInCombat or not IsControlKeyDown() or not GS_ExplainState.owner:IsShown() then
			GS_HideExplainTooltip()
		elseif not GS_ExplainTooltip:IsShown() then
			GS_RenderExplainTooltip(GS_ExplainState.owner, GS_ExplainState.itemLink)
		end
	end
	if active and ((active.readyAt and now >= active.readyAt) or ((not active.readyAt) and active.pollAt and now >= active.pollAt)) then
		local inspectUnit = UnitGUID(active.unit) == active.guid and active.unit or GS_ResolveUnitByGUID(active.guid)
		local snapshot = inspectUnit and GS_CollectSnapshot(inspectUnit, true) or nil
		local itemCount = snapshot and snapshot.itemCount or 0
		if snapshot and (itemCount >= GS_MIN_INSPECT_ITEMS or active.readyRetries >= GS_READY_RETRY_LIMIT) then
			GS_BuildRecord(snapshot)
			ClearInspectPlayer()
			GS_InspectState.active = nil
			GS_RefreshTooltip(active.guid)
			return
		end
		if active.readyRetries >= GS_READY_RETRY_LIMIT then
			ClearInspectPlayer()
			GS_InspectState.active = nil
			GS_RefreshTooltip(active.guid)
			return
		end
		active.readyRetries = active.readyRetries + 1
		active.readyAt = now + GS_READY_DELAY
		active.pollAt = now + GS_READY_DELAY
		return
	end
	if active and (now - active.startedAt) > GS_ACTIVE_TIMEOUT then ClearInspectPlayer() GS_InspectState.active = nil end
	if GS_InspectState.active or (now - GS_InspectState.lastInspectAt) < GS_INSPECT_THROTTLE then return end
	while #GS_InspectQueue > 0 do
		local request = table.remove(GS_InspectQueue, 1)
		GS_InspectState.queued[request.guid] = nil
		if request.unit and UnitGUID(request.unit) == request.guid and CanInspect(request.unit) and UnitIsPlayer(request.unit) then
			NotifyInspect(request.unit)
			GS_InspectState.active = { guid = request.guid, unit = request.unit, startedAt = now, pollAt = now + GS_FORCE_POLL_DELAY, readyRetries = 0 }
			GS_InspectState.recent[request.guid], GS_InspectState.lastInspectAt = now, now
			return
		end
	end
end

GS_RefreshTooltip = function(guid)
	if not GameTooltip:IsShown() then return end
	local _, unit = GameTooltip:GetUnit()
	if unit and UnitGUID(unit) == guid then GameTooltip:SetUnit(unit) end
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

function GearScore_GetItemScore(itemLink) return GS_CalculateLegacyBase(itemLink) end
function GearScore_GetScore(_, target) local record = GS_GetRecord(target or "player") return record and record.gs2 or 0, record and record.average or 0 end

function GearScore_SetDetails(tooltip, name)
	local _, unit = GameTooltip:GetUnit()
	local record = unit and GS_GetRecord(unit)
	if not record or not name or UnitName(unit) ~= name then return end
	for slotId, itemLink in pairs(record.detailLinks) do
		local item = GS_GetItemData(itemLink)
		if item then
			local gs2, pvp = GS_ScoreItem(item, record.classToken, record.specKey)
			local itemName, _, itemRarity = GetItemInfo(itemLink)
			if itemName then
				local color = GS_Rarity[itemRarity or 1] or GS_Rarity[1]
				local suffix = GS_Settings["Level"] == 1 and (" (iLevel " .. tostring(item.level or 0) .. ")") or ""
				tooltip:AddDoubleLine("[" .. itemName .. "]", "GS2 " .. tostring(gs2) .. " / L " .. tostring(item.legacyBase) .. " / P " .. tostring(pvp) .. suffix, color.Red, color.Green, color.Blue, 0.85, 0.85, 0.85)
			end
		end
	end
end

function GearScore_HookSetUnit()
	if GS_PlayerIsInCombat or (InspectFrame and InspectFrame:IsShown()) or (Examiner and Examiner:IsShown()) then return end
	GS_HideExplainTooltip()
	local name, unit = GS_GetTooltipUnit()
	if not name or not unit or not UnitIsPlayer(unit) or (GS_Settings["Player"] ~= 1 and GS_Settings["Player"] ~= 2) then return end
	local record = GS_GetRecord(unit)
	if record then
		GS_AddScoreLines(GameTooltip, record)
		if GS_Settings["Compare"] == 1 then
			local mine = GS_GetRecord("player")
			if mine then
				local diff = mine.gs2 - record.gs2
				if diff > 0 then GameTooltip:AddDoubleLine("Your GearScore2", tostring(mine.gs2) .. " (+" .. tostring(diff) .. ")", 0, 1, 0, 0, 1, 0)
				elseif diff < 0 then GameTooltip:AddDoubleLine("Your GearScore2", tostring(mine.gs2) .. " (" .. tostring(diff) .. ")", 1, 0, 0, 1, 0, 0)
				else GameTooltip:AddDoubleLine("Your GearScore2", tostring(mine.gs2) .. " (+0)", 0, 1, 1, 0, 1, 1) end
			end
		end
		if GS_Settings["Special"] == 1 and GS_Special[name] then GameTooltip:AddLine(GS_Special[GS_Special[name].Type], 1, 0, 0) end
	else
		GameTooltip:AddLine(GS_SCAN_TEXT, 0.95, 0.82, 0.18)
		if ((not GS_Settings["MustTarget"]) or UnitIsUnit("target", unit)) and CanInspect(unit) then GS_QueueInspect(unit) end
	end
end

function GearScore_HookSetItem() if not GS_PlayerIsInCombat then local _, link = GameTooltip:GetItem() GS_AddItemLines(GameTooltip, link) else GS_HideExplainTooltip() end end
function GearScore_HookRefItem() if not GS_PlayerIsInCombat then local _, link = ItemRefTooltip:GetItem() GS_AddItemLines(ItemRefTooltip, link) else GS_HideExplainTooltip() end end
function GearScore_HookCompareItem() if not GS_PlayerIsInCombat then local _, link = ShoppingTooltip1:GetItem() GS_AddItemLines(ShoppingTooltip1, link) else GS_HideExplainTooltip() end end
function GearScore_HookCompareItem2() if not GS_PlayerIsInCombat then local _, link = ShoppingTooltip2:GetItem() GS_AddItemLines(ShoppingTooltip2, link) else GS_HideExplainTooltip() end end

function GearScore_OnEnter(frame, itemSlot, argument)
	local original = GearScore_Original_SetInventoryItem(frame, itemSlot, argument)
	local record = GS_GetRecord("player")
	if record and record.detailLinks[itemSlot] then GS_AddItemLines(GameTooltip, record.detailLinks[itemSlot]) else GS_HideExplainTooltip() end
	return original
end

local function GS_UpdatePaperDoll()
	if GS_PlayerIsInCombat then return end
	local record = GS_GetRecord("player")
	if not record then return end
	local r, g, b = GearScore_GetQuality(record.gs2)
	PersonalGearScore:SetText(tostring(record.gs2)) PersonalGearScore:SetTextColor(r, g, b, 1)
	LegacyGearScoreText:SetText(tostring(record.legacy)) LegacyGearScoreText:SetTextColor(0.8, 0.8, 0.8, 1)
	PvPGearScoreText:SetText(tostring(record.pvp)) PvPGearScoreText:SetTextColor(0.95, 0.55, 0.25, 1)
end

function GS_MANSET(command)
	command = strlower(command or "")
	if command == "" or command == "options" or command == "option" or command == "help" then for i, v in ipairs(GS_CommandList) do print(v) end return end
	if command == "show" or command == "player" then GS_Settings["Player"] = GS_ShowSwitch[GS_Settings["Player"]] print((GS_Settings["Player"] == 1 or GS_Settings["Player"] == 2) and "Player Scores: On" or "Player Scores: Off") return end
	if command == "item" then GS_Settings["Item"] = GS_ItemSwitch[GS_Settings["Item"]] print((GS_Settings["Item"] == 1 or GS_Settings["Item"] == 3) and "Item Scores: On" or "Item Scores: Off") return end
	if command == "level" then GS_Settings["Level"] = GS_Settings["Level"] * -1 print(GS_Settings["Level"] == 1 and "Item Levels: On" or "Item Levels: Off") return end
	if command == "compare" then GS_Settings["Compare"] = GS_Settings["Compare"] * -1 print(GS_Settings["Compare"] == 1 and "Comparisons: On" or "Comparisons: Off") return end
	print("GearScore2: Unknown command. Type '/gs' for a list of options")
end

local function GS_OnEvent(_, event, ...)
	if event == "PLAYER_REGEN_ENABLED" then GS_PlayerIsInCombat = false return end
	if event == "PLAYER_REGEN_DISABLED" then GS_PlayerIsInCombat = true return end
	if event == "PLAYER_EQUIPMENT_CHANGED" then GS_InspectCache[UnitGUID("player")] = nil GS_UpdatePaperDoll() return end
	if event == "UNIT_INVENTORY_CHANGED" then local unit = ... if unit and UnitGUID(unit) then GS_InspectCache[UnitGUID(unit)] = nil end return end
	if event == "INSPECT_READY" then
		local guid = ...
		if GS_InspectState.active and GS_InspectState.active.guid == guid then
			GS_InspectState.active.readyAt = GetTime() + GS_READY_DELAY
			GS_InspectState.active.pollAt = GS_InspectState.active.readyAt
			GS_InspectState.active.readyRetries = 0
		end
		return
	end
	if event == "ADDON_LOADED" then
		local addonName = ...
		if addonName ~= "GearScore2" then return end
		if not GS2_Settings then
			GS2_Settings = GS_Settings or GS_DefaultSettings
		end
		GS_Settings = GS2_Settings
		if not GS_Data then GS_Data = {} end
		if not GS_Data[GetRealmName()] then GS_Data[GetRealmName()] = { ["Players"] = {} } end
		for key, value in pairs(GS_DefaultSettings) do if GS2_Settings[key] == nil then GS2_Settings[key] = value end end
		GS2_Settings["IncludeEnchants"] = true
		GS_UpdatePaperDoll()
	end
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", GS_ProcessInspectQueue)

local frame = CreateFrame("Frame", "GearScore", UIParent)
frame:SetScript("OnEvent", GS_OnEvent)
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("INSPECT_READY")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")

GS_ExplainTooltip = CreateFrame("GameTooltip", "GS2ExplainTooltip", UIParent, "GameTooltipTemplate")
GS_ExplainTooltip:SetFrameStrata("TOOLTIP")
GS_ExplainTooltip:SetClampedToScreen(true)

GameTooltip:HookScript("OnTooltipSetUnit", GearScore_HookSetUnit)
GameTooltip:HookScript("OnTooltipSetItem", GearScore_HookSetItem)
ShoppingTooltip1:HookScript("OnTooltipSetItem", GearScore_HookCompareItem)
ShoppingTooltip2:HookScript("OnTooltipSetItem", GearScore_HookCompareItem2)
ItemRefTooltip:HookScript("OnTooltipSetItem", GearScore_HookRefItem)
GameTooltip:HookScript("OnHide", GS_HideExplainTooltip)
ShoppingTooltip1:HookScript("OnHide", GS_HideExplainTooltip)
ShoppingTooltip2:HookScript("OnHide", GS_HideExplainTooltip)
ItemRefTooltip:HookScript("OnHide", GS_HideExplainTooltip)
PaperDollFrame:HookScript("OnShow", GS_UpdatePaperDoll)

PaperDollFrame:CreateFontString("PersonalGearScore")
PaperDollFrame:CreateFontString("GearScore2Label")
PaperDollFrame:CreateFontString("LegacyGearScoreText")
PaperDollFrame:CreateFontString("LegacyGearScoreLabel")
PaperDollFrame:CreateFontString("PvPGearScoreText")
PaperDollFrame:CreateFontString("PvPGearScoreLabel")

PersonalGearScore:SetFont("Fonts\\FRIZQT__.TTF", 12) PersonalGearScore:SetText("0") PersonalGearScore:SetPoint("BOTTOMLEFT", PaperDollFrame, "TOPLEFT", 72, -248) PersonalGearScore:Show()
GearScore2Label:SetFont("Fonts\\FRIZQT__.TTF", 12) GearScore2Label:SetText("GearScore2") GearScore2Label:SetPoint("BOTTOMLEFT", PaperDollFrame, "TOPLEFT", 72, -260) GearScore2Label:Show()
LegacyGearScoreText:SetFont("Fonts\\FRIZQT__.TTF", 12) LegacyGearScoreText:SetText("0") LegacyGearScoreText:SetPoint("BOTTOMLEFT", PaperDollFrame, "TOPLEFT", 152, -248) LegacyGearScoreText:Show()
LegacyGearScoreLabel:SetFont("Fonts\\FRIZQT__.TTF", 12) LegacyGearScoreLabel:SetText("Legacy") LegacyGearScoreLabel:SetPoint("BOTTOMLEFT", PaperDollFrame, "TOPLEFT", 152, -260) LegacyGearScoreLabel:Show()
PvPGearScoreText:SetFont("Fonts\\FRIZQT__.TTF", 12) PvPGearScoreText:SetText("0") PvPGearScoreText:SetPoint("BOTTOMLEFT", PaperDollFrame, "TOPLEFT", 232, -248) PvPGearScoreText:Show()
PvPGearScoreLabel:SetFont("Fonts\\FRIZQT__.TTF", 12) PvPGearScoreLabel:SetText("PvP") PvPGearScoreLabel:SetPoint("BOTTOMLEFT", PaperDollFrame, "TOPLEFT", 232, -260) PvPGearScoreLabel:Show()

GearScore_Original_SetInventoryItem = GameTooltip.SetInventoryItem
GameTooltip.SetInventoryItem = GearScore_OnEnter

SlashCmdList["MY2SCRIPT"] = GS_MANSET
SLASH_MY2SCRIPT1 = "/gset"
SLASH_MY2SCRIPT2 = "/gs"
SLASH_MY2SCRIPT3 = "/gearscore"
