-------------------------------------------------------------------------------
--                           GearScore2 Item Logic                            --
-------------------------------------------------------------------------------

function GS_ParseItemLink(itemLink)
	if not itemLink then return nil end
	local cached = GS_ParsedLinkCache[itemLink]
	if cached then return GS_TouchCacheEntry(cached) end
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
	return GS_StoreCacheEntry(GS_ParsedLinkCache, itemLink, cached, "GS_ParsedLinkCacheCount", GS_PARSED_LINK_CACHE_MAX, GS_PARSED_LINK_CACHE_TRIM_TO)
end

function GS_GetItemIdFromLink(itemLink)
	if not itemLink then return nil end
	local itemId = string.match(itemLink, "item:(%-?%d+)")
	return tonumber(itemId)
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
			local red, green, blue = GS2_GetQuality((floor(((itemLevel - tableRef[itemRarity].A) / tableRef[itemRarity].B) * scale)) * 11.25)
			local score = floor(((itemLevel - tableRef[itemRarity].A) / tableRef[itemRarity].B) * GS_ItemTypes[itemEquipLoc].SlotMOD * scale * qualityScale)
			if itemLevel == 187.05 then itemLevel = 0 end
			if score < 0 then score, red, green, blue = 0, GS2_GetQuality(1) end
			return score, itemLevel, GS_ItemTypes[itemEquipLoc].ItemSlot, red, green, blue, 0, itemEquipLoc, 1, itemSubType
		end
	end
	return -1, itemLevel or 0, 50, 1, 1, 1, 0, itemEquipLoc, 1, itemSubType
end

function GS_GetItemData(itemLink)
	if not itemLink then return nil end
	local cached = GS_ItemCache[itemLink]
	if cached then return GS_TouchCacheEntry(cached) end
	local itemName, _, itemRarity, itemLevel, _, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(itemLink)
	if not itemName or not itemEquipLoc then return nil end
	local legacyBase = GS_CalculateLegacyBase(itemLink)
	local parsed = GS_ParseItemLink(itemLink) or { enchantId = 0 }
	local stats, socketCount = GS_GetNormalizedStats(itemLink)
	local gemStats, gemCount, unresolvedData, unresolvedReasons = {}, 0, false, {}
	for index = 1, 4 do
		local gemId = parsed.gemIds and parsed.gemIds[index] or 0
		if gemId and gemId > 0 then
			gemCount = gemCount + 1
			local gemName, gemLink = GetItemGem(itemLink, index)
			local gemItemId = GS_GetItemIdFromLink(gemLink)
			local gemItemInfo = gemItemId and GS_GemItems and GS_GemItems[gemItemId] or nil
			local gemInfo = GS_GemValues and GS_GemValues[gemId] or gemItemInfo
			local normalized = gemInfo and gemInfo.stats or nil
			if not gemInfo then
				unresolvedData = true
				unresolvedReasons[#unresolvedReasons + 1] = "gem:" .. tostring(index)
				GS_ReportResolutionIssue({
					kind = "gem-stats-unresolved",
					itemName = itemName,
					itemLink = itemLink,
					slotId = GS_ITEM_SLOTS[itemEquipLoc] or 0,
					gemIndex = index,
					gemId = gemId,
					gemName = gemName,
					gemLink = gemLink or ("item:" .. gemId),
					details = "Gem enchant ID is present on the item link but no runtime gem data was resolved.",
				})
			end
			gemStats[index] = normalized
		else
			local gemName, gemLink = GetItemGem(itemLink, index)
			if gemName then
				gemCount = gemCount + 1
				local gemItemId = GS_GetItemIdFromLink(gemLink)
				local gemItemInfo = gemItemId and GS_GemItems and GS_GemItems[gemItemId] or nil
				if gemItemInfo and gemItemInfo.stats then
					gemStats[index] = gemItemInfo.stats
				else
					unresolvedData = true
					unresolvedReasons[#unresolvedReasons + 1] = "gem:" .. tostring(index)
					GS_ReportResolutionIssue({
						kind = "gem-id-missing",
						itemName = itemName,
						itemLink = itemLink,
						slotId = GS_ITEM_SLOTS[itemEquipLoc] or 0,
						gemIndex = index,
						gemId = gemId,
						gemName = gemName,
						gemLink = gemLink,
						details = "Gem is present in the socket but no gem enchant ID was parsed from the item link and no item-based gem data was resolved.",
					})
				end
			end
		end
	end
	local enchantInfo = GS_EnchantValues[parsed.enchantId or 0]
	if (parsed.enchantId or 0) > 0 and not enchantInfo and GS_EnchantSlots[itemEquipLoc] then
		unresolvedData = true
		unresolvedReasons[#unresolvedReasons + 1] = "enchant"
		GS_ReportResolutionIssue({
			kind = "enchant-stats-unresolved",
			itemName = itemName,
			itemLink = itemLink,
			slotId = GS_ITEM_SLOTS[itemEquipLoc] or 0,
			enchantId = parsed.enchantId or 0,
			details = "Enchant ID is present on an enchantable slot but no runtime enchant data was resolved.",
		})
	end
	cached = {
		link = itemLink, name = itemName, rarity = itemRarity, level = itemLevel or 0, type = itemType, subType = itemSubType,
		equipLoc = itemEquipLoc, slot = GS_ITEM_SLOTS[itemEquipLoc] or 0, legacyBase = legacyBase > 0 and legacyBase or 0,
		stats = stats, socketCount = socketCount, gemCount = gemCount, gemStats = gemStats, enchantId = parsed.enchantId or 0,
		hasEnchant = (parsed.enchantId or 0) > 0, enchantInfo = enchantInfo, resilience = stats.RESILIENCE or 0, armorRank = GS_ArmorClassOrder[itemSubType],
		unresolvedData = unresolvedData, unresolvedReasons = unresolvedReasons,
	}
	return GS_StoreCacheEntry(GS_ItemCache, itemLink, cached, "GS_ItemCacheCount", GS_ITEM_CACHE_MAX, GS_ITEM_CACHE_TRIM_TO)
end

function GS_GetEnchantInfo(item)
	if not item then return nil end
	return item.enchantInfo or GS_EnchantValues[item.enchantId]
end

function GS_GetEnchantStats(item)
	local info = GS_GetEnchantInfo(item)
	return info and info.stats or nil
end
