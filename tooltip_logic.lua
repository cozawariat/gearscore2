-------------------------------------------------------------------------------
--                         GearScoreAI Tooltip Logic                         --
-------------------------------------------------------------------------------

function GS_AddScoreLines(tooltip, record)
	local r, g, b = GearScore_GetQuality(record.gs2)
	tooltip:AddDoubleLine("GearScore2", tostring(record.gs2), r, g, b, r, g, b)
	r, g, b = GearScore_GetQuality(record.legacy)
	tooltip:AddDoubleLine("Legacy GearScore", tostring(record.legacy), r, g, b, r, g, b)
	r, g, b = GearScore_GetQuality(record.pvp)
	tooltip:AddDoubleLine("PvP GearScore", tostring(record.pvp), r, g, b, r, g, b)
	if GS_Settings["Level"] == 1 then tooltip:AddDoubleLine("Average iLevel", tostring(record.average or 0), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8) end
end

function GS_HideExplainTooltip()
	if GS_ExplainTooltip and GS_ExplainTooltip:IsShown() then
		GS_ExplainTooltip:Hide()
	end
	GS_ExplainState.owner = nil
	GS_ExplainState.itemLink = nil
	GS_ExplainState.itemSlot = nil
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
	local _, classToken = UnitClass("player")
	local playerRecord = GS_GetRecord("player")
	local specKey = playerRecord and playerRecord.specKey or GS_ClassDefaults[classToken]
	local item = GS_GetItemData(itemLink)
	if not item then
		return
	end
	local gs2, pvp, explain = GS_ScoreItem(item, classToken, specKey, true)
	if not explain then
		return
	end

	GS_BeginExplainTooltip()
	GS_PositionExplainTooltip(ownerTooltip)
	GS_ExplainTooltip:AddLine(item.name or "GearScoreAI Explain", 1, 0.82, 0.18)
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
	local _, classToken = UnitClass("player")
	local playerRecord = GS_GetRecord("player")
	local specKey = playerRecord and playerRecord.specKey or GS_ClassDefaults[classToken]
	local item = GS_GetItemData(itemLink)
	if not item then return end
	local gs2, pvp = GS_ScoreItem(item, classToken, specKey)
	local r, g, b = GearScore_GetQuality(gs2)
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

function GearScore_HookSetItem()
	if not GS_PlayerIsInCombat then local _, link = GameTooltip:GetItem() GS_AddItemLines(GameTooltip, link) end
end

function GearScore_HookRefItem()
	if not GS_PlayerIsInCombat then local _, link = ItemRefTooltip:GetItem() GS_AddItemLines(ItemRefTooltip, link) end
end

function GearScore_HookCompareItem()
	if not GS_PlayerIsInCombat then local _, link = ShoppingTooltip1:GetItem() GS_AddItemLines(ShoppingTooltip1, link) end
end

function GearScore_HookCompareItem2()
	if not GS_PlayerIsInCombat then local _, link = ShoppingTooltip2:GetItem() GS_AddItemLines(ShoppingTooltip2, link) end
end
