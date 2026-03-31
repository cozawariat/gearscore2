-------------------------------------------------------------------------------
--                          GearScoreAI Item Logic                           --
-------------------------------------------------------------------------------

function GS_ParseItemLink(itemLink)
	if not itemLink then return nil end
	local cached = GS_ParsedLinkCache[itemLink]
	if cached then return cached end
	local linkData = string.match(itemLink, "item[%-?%d:]+")
	if not linkData then return nil end
	local values = {}
	for value in string.gmatch(linkData, "([^:]+)") do values[#values + 1] = tonumber(value) or 0 end
	cached = {
		enchantId = values[3] or 0,
		gemIds = {
			values[4] or 0,
			values[5] or 0,
			values[6] or 0,
			values[7] or 0,
		},
	}
	GS_ParsedLinkCache[itemLink] = cached
	return cached
end

function GS_IsEmptyStats(stats)
	if not stats then return true end
	for _, value in pairs(stats) do
		if value and value ~= 0 then
			return false
		end
	end
	return true
end

function GS_GetGemFallbackStats(gemName, gemId)
	if not gemName then return nil end
	local _, _, quality = GetItemInfo(gemId)
	local amount = (quality == 4 and 20) or 16
	if string.find(gemName, "Rigid", 1, true) then return { HIT = amount } end
	if string.find(gemName, "Delicate", 1, true) then return { AGI = amount } end
	if string.find(gemName, "Bold", 1, true) then return { STR = amount } end
	if string.find(gemName, "Bright", 1, true) then return { INT = amount } end
	if string.find(gemName, "Solid", 1, true) then return { STA = amount } end
	if string.find(gemName, "Runed", 1, true) then return { SP = amount * 1.15 } end
	if string.find(gemName, "Quick", 1, true) then return { HASTE = amount } end
	if string.find(gemName, "Smooth", 1, true) then return { CRIT = amount } end
	if string.find(gemName, "Fractured", 1, true) then return { ARP = amount } end
	if string.find(gemName, "Precise", 1, true) then return { EXPERTISE = amount } end
	return nil
end

function GS_GetNormalizedStats(itemLink)
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

function GS_CalculateLegacyBase(itemLink)
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

function GS_GetItemData(itemLink)
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
		local gemId = parsed.gemIds and parsed.gemIds[index] or 0
		if gemId and gemId > 0 then
			gemCount = gemCount + 1
			local gemName, gemLink = GetItemGem(itemLink, index)
			local resolvedGemLink = gemLink or select(2, GetItemInfo(gemId)) or ("item:" .. gemId)
			local normalized = select(1, GS_GetNormalizedStats(resolvedGemLink))
			if GS_IsEmptyStats(normalized) then
				normalized = GS_GetGemFallbackStats(gemName, gemId) or normalized
			end
			gemStats[index] = normalized
		else
			local gemName, gemLink = GetItemGem(itemLink, index)
			if gemName then
				gemCount = gemCount + 1
				local normalized = gemLink and select(1, GS_GetNormalizedStats(gemLink)) or nil
				if GS_IsEmptyStats(normalized) then
					normalized = GS_GetGemFallbackStats(gemName, gemId) or normalized
				end
				gemStats[index] = normalized
			end
		end
	end
	local enchantInfo = GS_EnchantValues[parsed.enchantId or 0]
	cached = {
		link = itemLink, name = itemName, rarity = itemRarity, level = itemLevel or 0, type = itemType, subType = itemSubType,
		equipLoc = itemEquipLoc, slot = GS_ITEM_SLOTS[itemEquipLoc] or 0, legacyBase = legacyBase > 0 and legacyBase or 0,
		stats = stats, socketCount = socketCount, gemCount = gemCount, gemStats = gemStats, enchantId = parsed.enchantId or 0,
		hasEnchant = (parsed.enchantId or 0) > 0, enchantInfo = enchantInfo, resilience = stats.RESILIENCE or 0, armorRank = GS_ArmorClassOrder[itemSubType],
	}
	GS_ItemCache[itemLink] = cached
	return cached
end

function GS_GetEnchantInfo(item)
	if not item then return nil end
	return item.enchantInfo or GS_EnchantValues[item.enchantId]
end

function GS_GetEnchantStats(item)
	local info = GS_GetEnchantInfo(item)
	return info and info.stats or nil
end
