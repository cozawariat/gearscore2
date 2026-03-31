-------------------------------------------------------------------------------
--                         GearScoreAI Tooltip Logic                         --
-------------------------------------------------------------------------------

function GS_AddScoreLines(tooltip, record)
	local specText = record and record.scanStatusText or "Spec unknown"
	if record and record.specResolved and record.specSource == "cached" then
		specText = record.specLabel and (record.specLabel .. " [CACHED]") or specText
	elseif record and record.specResolved then
		specText = record.specLabel or specText
	elseif record and not record.scanExpired then
		specText = "Scanning..."
	end
	tooltip:AddDoubleLine("Spec", specText, 0.85, 0.9, 1, 0.85, 0.9, 1)
	if record.gs2Available and record.gs2 ~= nil then
		local r, g, b = GearScore_GetQuality(record.gs2)
		tooltip:AddDoubleLine("GearScore2", tostring(record.gs2), r, g, b, r, g, b)
	end
	local r, g, b
	r, g, b = GearScore_GetQuality(record.legacy)
	tooltip:AddDoubleLine("Legacy GearScore", tostring(record.legacy), r, g, b, r, g, b)
	if record.pvp ~= nil then
		r, g, b = GearScore_GetQuality(record.pvp)
		tooltip:AddDoubleLine("PvP GearScore", tostring(record.pvp), r, g, b, r, g, b)
	end
	if GS_Settings["Level"] == 1 then tooltip:AddDoubleLine("Average iLevel", tostring(record.average or 0), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8) end
	if record.capBreakdown and record.capBreakdown.summary and record.gs2Available then
		tooltip:AddLine("GS2 Caps: " .. record.capBreakdown.summary, 0.75, 0.9, 1, true)
	end
	if not record.gs2Available and record.scanExpired then
		tooltip:AddLine("GS2 unavailable: spec scan timed out.", 1, 0.55, 0.55, true)
	end
end

function GS_HideExplainTooltip()
	if GS_ExplainTooltip and GS_ExplainTooltip:IsShown() then
		GS_ExplainTooltip:Hide()
	end
	GS_ExplainState.owner = nil
	GS_ExplainState.itemLink = nil
	GS_ExplainState.itemSlot = nil
end

function GS_GetTooltipRecordForItem(tooltip, itemLink)
	local unit = nil
	if tooltip == GameTooltip and GS_TooltipInventoryContext.unit and GS_TooltipInventoryContext.slot then
		unit = GS_TooltipInventoryContext.unit
		local record = GS_GetRecord(unit) or GS_GetScanRecord(GS_TooltipInventoryContext.guid)
		if record and record.detailLinks and record.detailLinks[GS_TooltipInventoryContext.slot] == itemLink then
			return record, unit, GS_TooltipInventoryContext.slot
		end
		if record and not record.detailLinks then
			return record, unit, GS_TooltipInventoryContext.slot
		end
	end
	local _, tooltipUnit = tooltip:GetUnit()
	if tooltipUnit and UnitIsPlayer(tooltipUnit) then
		unit = tooltipUnit
		local record = GS_GetRecord(unit) or GS_GetScanRecord(UnitGUID(unit))
		if record and record.detailLinks then
			for slotId, link in pairs(record.detailLinks) do
				if link == itemLink then
					return record, unit, slotId
				end
			end
		elseif record then
			return record, unit, nil
		end
	end
	return nil, unit, nil
end

function GS_GetTooltipItemContext(tooltip, itemLink)
	local record, unit, slotId = GS_GetTooltipRecordForItem(tooltip, itemLink)
	if unit and not UnitIsUnit(unit, "player") and CanInspect(unit) then
		if not record or not record.gs2Available then
			GS_QueueInspect(unit)
		end
	end
	if record and unit and UnitIsPlayer(unit) then
		return {
			record = record,
			unit = unit,
			slotId = slotId,
			classToken = record.classToken or select(2, UnitClass(unit)),
			specKey = record.specKey,
			specLabel = record.specLabel,
			specSource = record.specSource,
			gs2Available = record.gs2Available,
			scanning = not record.specResolved and not record.scanExpired,
		}
	end
	local playerRecord = GS_GetRecord("player")
	local _, classToken = UnitClass("player")
	return {
		record = playerRecord,
		unit = "player",
		slotId = slotId,
		classToken = classToken,
		specKey = playerRecord and playerRecord.specKey or GS_ClassDefaults[classToken],
		specLabel = playerRecord and playerRecord.specLabel or GS_GetSpecLabel(GS_ClassDefaults[classToken]),
		specSource = playerRecord and playerRecord.specSource or "live",
		gs2Available = true,
		scanning = false,
	}
end

function GS_AddExplainPart(tooltip, title, part, r, g, b)
	local sign = part.delta >= 0 and "+" or ""
	tooltip:AddDoubleLine(title, sign .. tostring(part.delta), r, g, b, r, g, b)
	tooltip:AddLine("  " .. part.formula, 0.72, 0.72, 0.72, true)
end

function GS_PositionExplainTooltip(ownerTooltip)
	GS_ExplainTooltip:ClearAllPoints()
	if ownerTooltip and ownerTooltip:GetCenter() then
		local uiCenter = UIParent:GetCenter() or 0
		local ownerCenter = ownerTooltip:GetCenter() or 0
		if ownerCenter >= uiCenter then
			GS_ExplainTooltip:SetPoint("TOPRIGHT", ownerTooltip, "TOPLEFT", -18, 0)
		else
			GS_ExplainTooltip:SetPoint("TOPLEFT", ownerTooltip, "TOPRIGHT", 18, 0)
		end
	else
		GS_ExplainTooltip:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -220)
	end
end

function GS_BeginExplainTooltip()
	if not GS_ExplainTooltip then
		return
	end
	GS_ExplainTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	GS_ExplainTooltip:ClearLines()
end

function GS_RenderExplainTooltip(ownerTooltip, itemLink)
	if not GS_ExplainTooltip or not ownerTooltip or not itemLink then
		return
	end
	GS_ExplainState.owner = ownerTooltip
	GS_ExplainState.itemLink = itemLink
	if GS_PlayerIsInCombat or not IsControlKeyDown() then
		if GS_ExplainTooltip:IsShown() then
			GS_ExplainTooltip:Hide()
		end
		return
	end
	local item = GS_GetItemData(itemLink)
	if not item then
		return
	end
	local context = GS_GetTooltipItemContext(ownerTooltip, itemLink)
	if not context or context.scanning or not context.gs2Available or not context.specKey then
		if GS_ExplainTooltip:IsShown() then
			GS_ExplainTooltip:Hide()
		end
		return
	end
	local gs2, pvp, explain = GS_ScoreItem(item, context.classToken, context.specKey, true)
	if not explain then
		return
	end

	GS_BeginExplainTooltip()
	GS_PositionExplainTooltip(ownerTooltip)
	GS_ExplainTooltip:AddLine(item.name or "GearScoreAI Explain", 1, 0.82, 0.18)
	if context.specSource == "cached" then
		GS_ExplainTooltip:AddDoubleLine("Spec context", (context.specLabel or GS_GetSpecLabel(context.specKey)) .. " [CACHED]", 0.85, 0.9, 1, 0.85, 0.9, 1)
	else
		GS_ExplainTooltip:AddDoubleLine("Spec context", context.specLabel or GS_GetSpecLabel(context.specKey), 0.85, 0.9, 1, 0.85, 0.9, 1)
	end
	GS_ExplainTooltip:AddDoubleLine("GearScore2", tostring(gs2), 0.25, 0.95, 0.35, 0.25, 0.95, 0.35)
	GS_ExplainTooltip:AddDoubleLine("Legacy GearScore", tostring(item.legacyBase), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
	GS_ExplainTooltip:AddDoubleLine("PvP GearScore", tostring(pvp), 0.95, 0.55, 0.25, 0.95, 0.55, 0.25)
	GS_ExplainTooltip:AddLine(" ")
	GS_ExplainTooltip:AddLine("Legacy", 0.95, 0.82, 0.18)
	GS_ExplainTooltip:AddLine("Legacy = iLevel/slot base = " .. tostring(item.legacyBase), 0.88, 0.88, 0.88, true)
	GS_ExplainTooltip:AddLine(" ")
	GS_ExplainTooltip:AddLine("GearScore2", 0.25, 0.95, 0.35)
	GS_ExplainTooltip:AddLine("GearScore2 = floor((legacy + stats + gems + enchant) * multiplierPvE)", 0.88, 0.88, 0.88, true)
	for index = 1, #explain.pve.parts do
		GS_AddExplainPart(GS_ExplainTooltip, explain.pve.parts[index].label, explain.pve.parts[index], 0.25, 0.95, 0.35)
	end
	GS_ExplainTooltip:AddDoubleLine("Base before multiplier", tostring(explain.pve.preMultiplier or explain.pve.base or 0), 0.75, 0.95, 0.75, 0.75, 0.95, 0.75)
	GS_ExplainTooltip:AddDoubleLine("PvE resilience multiplier", "x" .. GS_FormatNumber(explain.pve.multiplier or 1), 0.25, 0.95, 0.35, 0.25, 0.95, 0.35)
	GS_ExplainTooltip:AddDoubleLine("Final result", tostring(explain.pve.final), 0.25, 0.95, 0.35, 0.25, 0.95, 0.35)
	GS_ExplainTooltip:AddLine(" ")
	GS_ExplainTooltip:AddLine("PvP GearScore", 0.95, 0.55, 0.25)
	GS_ExplainTooltip:AddLine("PvP = floor((legacy + stats + gems + enchant) * multiplierPvP)", 0.88, 0.88, 0.88, true)
	for index = 1, #explain.pvp.parts do
		GS_AddExplainPart(GS_ExplainTooltip, explain.pvp.parts[index].label, explain.pvp.parts[index], 0.95, 0.55, 0.25)
	end
	GS_ExplainTooltip:AddDoubleLine("Base before multiplier", tostring(explain.pvp.preMultiplier or explain.pvp.base or 0), 1, 0.8, 0.45, 1, 0.8, 0.45)
	GS_ExplainTooltip:AddDoubleLine("PvP resilience multiplier", "x" .. GS_FormatNumber(explain.pvp.multiplier or 1), 0.95, 0.55, 0.25, 0.95, 0.55, 0.25)
	GS_ExplainTooltip:AddDoubleLine("Final result", tostring(explain.pvp.final), 0.95, 0.55, 0.25, 0.95, 0.55, 0.25)
	if #explain.flags > 0 then
		GS_ExplainTooltip:AddLine(" ")
		GS_ExplainTooltip:AddLine("Flags", 1, 0.35, 0.35)
		for index = 1, #explain.flags do
			GS_ExplainTooltip:AddLine(" - " .. explain.flags[index], 1, 0.55, 0.55, true)
		end
	end
	if explain.pve.statEntries and #explain.pve.statEntries > 0 then
		GS_ExplainTooltip:AddLine(" ")
		GS_ExplainTooltip:AddLine("Top PvE stats", 0.45, 0.85, 1)
		for index = 1, math.min(4, #explain.pve.statEntries) do
			local entry = explain.pve.statEntries[index]
			GS_ExplainTooltip:AddLine("  " .. entry.stat .. ": " .. entry.value .. " * " .. GS_FormatNumber(entry.weight) .. " = " .. GS_FormatNumber(entry.score), 0.78, 0.92, 1, true)
		end
	end
	if explain.pvp.statEntries and #explain.pvp.statEntries > 0 then
		GS_ExplainTooltip:AddLine(" ")
		GS_ExplainTooltip:AddLine("Top PvP stats", 1, 0.72, 0.35)
		for index = 1, math.min(4, #explain.pvp.statEntries) do
			local entry = explain.pvp.statEntries[index]
			GS_ExplainTooltip:AddLine("  " .. entry.stat .. ": " .. entry.value .. " * " .. GS_FormatNumber(entry.weight) .. " = " .. GS_FormatNumber(entry.score), 1, 0.85, 0.6, true)
		end
	end
	GS_ExplainTooltip:Show()
end

function GS_TryShowExplainFromOwner(ownerTooltip)
	if not ownerTooltip or not ownerTooltip:IsShown() then
		return
	end
	local _, itemLink = ownerTooltip:GetItem()
	if itemLink and IsEquippableItem(itemLink) then
		GS_RenderExplainTooltip(ownerTooltip, itemLink)
	end
end

function GS_AddItemLines(tooltip, itemLink)
	if not itemLink or not IsEquippableItem(itemLink) then return end
	local item = GS_GetItemData(itemLink)
	if not item then return end
	local context = GS_GetTooltipItemContext(tooltip, itemLink)
	if context and context.scanning then
		tooltip:AddLine(GS_SCAN_TEXT, 0.95, 0.82, 0.18)
		GS_HideExplainTooltip()
		return
	end
	if context and (not context.gs2Available or not context.specKey) then
		tooltip:AddDoubleLine("Spec", "Unknown", 1, 0.65, 0.65, 1, 0.65, 0.65)
		tooltip:AddDoubleLine("Legacy GearScore", tostring(item.legacyBase), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
		if GS_Settings["Level"] == 1 then tooltip:AddLine("iLevel " .. tostring(item.level or 0), 0.65, 0.65, 0.65) end
		GS_HideExplainTooltip()
		return
	end
	local gs2, pvp = GS_ScoreItem(item, context.classToken, context.specKey)
	local r, g, b = GearScore_GetQuality(gs2)
	if context.specSource == "cached" then
		tooltip:AddDoubleLine("Spec", (context.specLabel or GS_GetSpecLabel(context.specKey)) .. " [CACHED]", 0.85, 0.9, 1, 0.85, 0.9, 1)
	elseif context and context.unit and not UnitIsUnit(context.unit, "player") then
		tooltip:AddDoubleLine("Spec", context.specLabel or GS_GetSpecLabel(context.specKey), 0.85, 0.9, 1, 0.85, 0.9, 1)
	end
	tooltip:AddDoubleLine("GearScore2", tostring(gs2), r, g, b, r, g, b)
	tooltip:AddDoubleLine("Legacy GearScore", tostring(item.legacyBase), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
	tooltip:AddDoubleLine("PvP GearScore", tostring(pvp), 0.95, 0.55, 0.25, 0.95, 0.55, 0.25)
	if GS_Settings["Level"] == 1 then tooltip:AddLine("iLevel " .. tostring(item.level or 0), 0.65, 0.65, 0.65) end
	GS_RenderExplainTooltip(tooltip, itemLink)
end

function GearScore_SetDetails(tooltip, name)
	local _, unit = GameTooltip:GetUnit()
	local record = unit and GS_GetRecord(unit)
	if not record or not name or UnitName(unit) ~= name then return end
	for slotId, itemLink in pairs(record.detailLinks) do
		local item = GS_GetItemData(itemLink)
		if item then
			local itemName, _, itemRarity = GetItemInfo(itemLink)
			if itemName then
				local color = GS_Rarity[itemRarity or 1] or GS_Rarity[1]
				local suffix = GS_Settings["Level"] == 1 and (" (iLevel " .. tostring(item.level or 0) .. ")") or ""
				if record.gs2Available and record.specKey then
					local gs2, pvp = GS_ScoreItem(item, record.classToken, record.specKey)
					tooltip:AddDoubleLine("[" .. itemName .. "]", "GS2 " .. tostring(gs2) .. " / L " .. tostring(item.legacyBase) .. " / P " .. tostring(pvp) .. suffix, color.Red, color.Green, color.Blue, 0.85, 0.85, 0.85)
				else
					tooltip:AddDoubleLine("[" .. itemName .. "]", "L " .. tostring(item.legacyBase) .. suffix, color.Red, color.Green, color.Blue, 0.85, 0.85, 0.85)
				end
			end
		end
	end
end

function GearScore_HookSetUnit()
	if GS_PlayerIsInCombat then return end
	GS_HideExplainTooltip()
	local name, unit = GS_GetTooltipUnit()
	if not name or not unit or not UnitIsPlayer(unit) or (GS_Settings["Player"] ~= 1 and GS_Settings["Player"] ~= 2) then return end
	local record = GS_GetRecord(unit)
	if record then
		if not record.gs2Available and not UnitIsUnit(unit, "player") and CanInspect(unit) then
			GS_QueueInspect(unit)
		end
		GS_AddScoreLines(GameTooltip, record)
		if GS_Settings["Compare"] == 1 and record.gs2Available then
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

function GearScore_HookSetItem()
	if not GS_PlayerIsInCombat then local _, link = GameTooltip:GetItem() GS_AddItemLines(GameTooltip, link) else GS_HideExplainTooltip() end
end

function GearScore_HookRefItem()
	if not GS_PlayerIsInCombat then local _, link = ItemRefTooltip:GetItem() GS_AddItemLines(ItemRefTooltip, link) else GS_HideExplainTooltip() end
end

function GearScore_HookCompareItem()
	if not GS_PlayerIsInCombat then local _, link = ShoppingTooltip1:GetItem() GS_AddItemLines(ShoppingTooltip1, link) else GS_HideExplainTooltip() end
end

function GearScore_HookCompareItem2()
	if not GS_PlayerIsInCombat then local _, link = ShoppingTooltip2:GetItem() GS_AddItemLines(ShoppingTooltip2, link) else GS_HideExplainTooltip() end
end
