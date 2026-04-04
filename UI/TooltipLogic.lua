-------------------------------------------------------------------------------
--                          GearScore2 Tooltip Logic                          --
-------------------------------------------------------------------------------

local GS = _G.GS2
local State = GS and GS.State or {}
local C = GS and GS.Constants or {}
local Data = GS and GS.Data or {}
local Tables = Data.Tables or {}
local GS_RATING_CONVERSIONS = Tables.RatingConversions or {}
local GS_CLASS_DEFAULTS = Tables.ClassDefaults or {}
local GS_RARITY = Tables.Rarity or {}
local GS_SCAN_TEXT = C.SCAN_TEXT or "|cffaaaaaaScanning...|r"
local GS_ExplainState = State.ExplainState or { owner = nil, itemLink = nil, itemSlot = nil }
local GS_TooltipInventoryContext = State.TooltipInventoryContext or { unit = nil, slot = nil, guid = nil }

function GS_TooltipHasLine(tooltip, text)
	if not tooltip or not tooltip.GetName or not text then
		return false
	end
	local tooltipName = tooltip:GetName()
	if not tooltipName then
		return false
	end
	for index = 1, tooltip:NumLines() or 0 do
		local leftRegion = _G[tooltipName .. "TextLeft" .. index]
		if leftRegion and leftRegion:GetText() == text then
			return true
		end
	end
	return false
end

function GS_AddInspectPausedLine(tooltip)
	if not tooltip or GS_TooltipHasLine(tooltip, "GearScore is paused in Inspect mode") then
		return
	end
	tooltip:AddLine("GearScore is paused in Inspect mode", 0.95, 0.82, 0.18, true)
end

function GS_GetCapStatAbbrev(pool)
	local stat = pool and pool.stat or nil
	if stat == "HIT" and pool and pool.targetSegment and pool.targetSegment.mode == "SPELL_HIT_PERCENT" then return "SPHIT" end
	if stat == "HIT" then return "HIT" end
	if stat == "SPELL_HIT" then return "SPHIT" end
	if stat == "DEFENSE" then return "DEF" end
	if stat == "EXPERTISE" then return "EXP" end
	if stat == "ARP" then return "ARP" end
	return stat or "CAP"
end

function GS_FormatCapStatDetail(pool)
	if not pool then
		return ""
	end
	local rawValue = tostring(floor((pool.rawValue or 0) + 0.5))
	local permanentBonus = max(0, pool.permanentContextBonus or pool.contextBonus or 0)
	local temporaryBonus = max(0, pool.temporaryContextBonus or 0)
	local bonusSuffix = ""
	if permanentBonus > 0 then
		bonusSuffix = "+" .. GS_FormatNumber(permanentBonus)
	end
	if temporaryBonus > 0 then
		bonusSuffix = bonusSuffix .. "|cff9acd32+" .. GS_FormatNumber(temporaryBonus) .. "|r"
	end
	if pool.stat == "HIT" and pool.targetSegment and pool.targetSegment.mode == "SPELL_HIT_PERCENT" then
		local hitPercent = (pool.rawValue or 0) / (GS_RATING_CONVERSIONS.SPELL_HIT or 26.231992)
		return rawValue .. " (" .. GS_FormatNumber(hitPercent) .. "%" .. bonusSuffix .. ")"
	end
	if pool.stat == "HIT" then
		local hitPercent = (pool.rawValue or 0) / (GS_RATING_CONVERSIONS.MELEE_HIT or 32.78998947)
		return rawValue .. " (" .. GS_FormatNumber(hitPercent) .. "%" .. bonusSuffix .. ")"
	end
	if pool.stat == "SPELL_HIT" then
		local hitPercent = (pool.rawValue or 0) / (GS_RATING_CONVERSIONS.SPELL_HIT or 26.231992)
		return rawValue .. " (" .. GS_FormatNumber(hitPercent) .. "%" .. bonusSuffix .. ")"
	end
	if pool.stat == "DEFENSE" then
		local defenseSkill = 400 + floor(((pool.rawValue or 0) / (GS_RATING_CONVERSIONS.DEFENSE or 4.9185)) + permanentBonus)
		local detail = rawValue .. " (" .. tostring(defenseSkill) .. ")"
		if bonusSuffix ~= "" then
			detail = detail .. " " .. bonusSuffix
		end
		return detail
	end
	if pool.stat == "EXPERTISE" then
		local expertisePoints = floor(((pool.rawValue or 0) / (GS_RATING_CONVERSIONS.EXPERTISE or 8.196)) + permanentBonus)
		local detail = rawValue .. " (" .. tostring(expertisePoints) .. ")"
		if bonusSuffix ~= "" then
			detail = detail .. " " .. bonusSuffix
		end
		return detail
	end
	if bonusSuffix ~= "" then
		return rawValue .. " (" .. bonusSuffix .. ")"
	end
	return rawValue
end

function GS_GetCapLineLabel(pool)
	if not pool then
		return "CAP"
	end
	local icon = pool.capped and "|TInterface\\Buttons\\UI-CheckBox-Check:14:14:0:0:64:64:4:60:4:60|t " or ""
	return icon .. GS_GetCapStatAbbrev(pool) .. ": " .. GS_FormatCapStatDetail(pool)
end

function GS_AddCharacterCapLines(tooltip, capBreakdown)
	if not tooltip or not capBreakdown or not capBreakdown.pools then
		return
	end
	local hasAny = false
	for index = 1, #capBreakdown.pools do
		local pool = capBreakdown.pools[index]
		if pool and (pool.progress or 0) > 0 then
			if not hasAny then
				tooltip:AddLine("GS2 Caps:", 0.75, 0.9, 1)
				hasAny = true
			end
			local label = GS_GetCapLineLabel(pool)
			tooltip:AddDoubleLine("  " .. label, "+" .. tostring(pool.bonusGs2 or 0), 0.75, 0.9, 1, 0.75, 0.9, 1)
		end
	end
end

function GS_AddScoreLines(tooltip, record)
	if GS_TooltipHasLine(tooltip, "Spec") or GS_TooltipHasLine(tooltip, "GearScore2") then
		return
	end
	local showCharacterSpec = not GS_Settings or GS_Settings["showCharacterSpec"]
	local specText = record and record.scanStatusText or "Spec unknown"
	if record and record.specResolved then
		if record.offSpec and record.specLabel then
			specText = record.specLabel
		else
			specText = record.scanStatusText or record.specLabel or specText
		end
	elseif record and not record.scanExpired then
		specText = "Scanning..."
	end
	if showCharacterSpec then
		tooltip:AddDoubleLine("Spec", specText, 0.85, 0.9, 1, 0.85, 0.9, 1)
	end
	local showCharacterGS2 = not GS_Settings or GS_Settings["showCharacterGS2"]
	local showCharacterLegacy = not GS_Settings or GS_Settings["showCharacterLegacy"]
	local showCharacterPvp = not GS_Settings or GS_Settings["showCharacterPvp"]
	local showCharacterAverage = not GS_Settings or GS_Settings["showCharacterAverage"]
	local showCharacterCapSummary = not GS_Settings or GS_Settings["showCharacterCapSummary"]
	if record.gs2Available and record.gs2 ~= nil then
		if showCharacterGS2 then
			if record.specLabel and record.offSpecBetterSpecLabel and record.offSpecBetterGs2 ~= nil then
				local activeR, activeG, activeB = GS2_GetQuality(record.gs2)
				local offR, offG, offB = GS2_GetQuality(record.offSpecBetterGs2)
				tooltip:AddLine("GearScore2", 0.85, 0.9, 1)
				tooltip:AddDoubleLine("  Active: " .. tostring(record.specLabel), tostring(record.gs2), activeR, activeG, activeB, activeR, activeG, activeB)
				tooltip:AddDoubleLine("  Inferred: " .. tostring(record.offSpecBetterSpecLabel), tostring(record.offSpecBetterGs2), offR, offG, offB, offR, offG, offB)
			else
				local r, g, b = GS2_GetQuality(record.gs2)
				tooltip:AddDoubleLine("GearScore2", tostring(record.gs2), r, g, b, r, g, b)
			end
		end
	end
	local r, g, b
	if showCharacterLegacy then
		r, g, b = GS2_GetQuality(record.legacy)
		tooltip:AddDoubleLine("Legacy GearScore", tostring(record.legacy), r, g, b, r, g, b)
	end
	if showCharacterPvp and record.pvp ~= nil then
		r, g, b = GS2_GetQuality(record.pvp)
		tooltip:AddDoubleLine("PvP GearScore", tostring(record.pvp), r, g, b, r, g, b)
	end
	if showCharacterAverage then tooltip:AddDoubleLine("Average iLevel", tostring(record.average or 0), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8) end
	if showCharacterCapSummary and record.capBreakdown and record.gs2Available then
		GS_AddCharacterCapLines(tooltip, record.capBreakdown)
	end
	if record.unresolvedData then
		tooltip:AddLine("GS2 unavailable: unresolved gem/enchant stats. Use /gs2 issues.", 1, 0.55, 0.55, true)
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
	if unit and not UnitIsUnit(unit, "player") and not GS_IsExternalInspectOpen() and GS_CanInspectUnitByPolicy(unit) then
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
	if tooltip == GameTooltip and GS_TooltipInventoryContext.unit and not UnitIsUnit(GS_TooltipInventoryContext.unit, "player") then
		return {
			record = nil,
			unit = GS_TooltipInventoryContext.unit,
			slotId = GS_TooltipInventoryContext.slot,
			classToken = select(2, UnitClass(GS_TooltipInventoryContext.unit)),
			specKey = nil,
			specLabel = nil,
			specSource = "none",
			gs2Available = false,
			scanning = true,
		}
	end
	local playerRecord = GS_GetRecord("player")
	local _, classToken = UnitClass("player")
	return {
		record = playerRecord,
		unit = "player",
		slotId = slotId,
		classToken = classToken,
		specKey = playerRecord and playerRecord.specKey or GS_CLASS_DEFAULTS[classToken],
		specLabel = playerRecord and playerRecord.specLabel or GS_GetSpecLabel(GS_CLASS_DEFAULTS[classToken]),
		specSource = playerRecord and playerRecord.specSource or "live",
		gs2Available = playerRecord and playerRecord.gs2Available or false,
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
	if State.PlayerIsInCombat or not IsControlKeyDown() or (GS_Settings and not GS_Settings["enableExplainTooltip"]) then
		if GS_ExplainTooltip:IsShown() then
			GS_ExplainTooltip:Hide()
		end
		return
	end
	local item = GS_GetItemData(itemLink)
	if not item then
		return
	end
	if item.unresolvedData then
		if GS_ExplainTooltip:IsShown() then
			GS_ExplainTooltip:Hide()
		end
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
	GS_ExplainTooltip:AddLine(item.name or "GearScore2 Explain", 1, 0.82, 0.18)
	GS_ExplainTooltip:AddDoubleLine("Spec context", context.specLabel or GS_GetSpecLabel(context.specKey), 0.85, 0.9, 1, 0.85, 0.9, 1)
	local showExplainHeader = not GS_Settings or GS_Settings["showExplainHeader"]
	local showExplainGS2 = not GS_Settings or GS_Settings["showCharacterGS2"]
	local showExplainLegacyScore = not GS_Settings or GS_Settings["showCharacterLegacy"]
	local showExplainPvpScore = not GS_Settings or GS_Settings["showCharacterPvp"]
	local showExplainLegacy = not GS_Settings or GS_Settings["showExplainLegacy"]
	local showExplainPveFormula = not GS_Settings or GS_Settings["showExplainPveFormula"]
	local showExplainPveParts = not GS_Settings or GS_Settings["showExplainPveParts"]
	local showExplainPveTotals = not GS_Settings or GS_Settings["showExplainPveTotals"]
	local showExplainPvpFormula = not GS_Settings or GS_Settings["showExplainPvpFormula"]
	local showExplainPvpParts = not GS_Settings or GS_Settings["showExplainPvpParts"]
	local showExplainPvpTotals = not GS_Settings or GS_Settings["showExplainPvpTotals"]
	local showExplainFlags = not GS_Settings or GS_Settings["showExplainFlags"]
	local showExplainTopPveStats = not GS_Settings or GS_Settings["showExplainTopPveStats"]
	local showExplainTopPvpStats = not GS_Settings or GS_Settings["showExplainTopPvpStats"]
	local showExplainPvpSectionContent = showExplainPvpFormula or showExplainPvpParts or showExplainPvpTotals
	local hasPveFlags = showExplainFlags and explain.pve.flags and #explain.pve.flags > 0
	local hasPvpFlags = showExplainPvpSectionContent and showExplainFlags and explain.pvp.flags and #explain.pvp.flags > 0
	local hasGeneralFlags = showExplainFlags and #explain.flags > 0
	local showPveSection = showExplainPveFormula or showExplainPveParts or showExplainPveTotals or hasPveFlags
	local showPvpSection = showExplainPvpFormula or showExplainPvpParts or showExplainPvpTotals or hasPvpFlags
	if showExplainHeader then
		if showExplainGS2 then
			GS_ExplainTooltip:AddDoubleLine("GearScore2", tostring(gs2), 0.25, 0.95, 0.35, 0.25, 0.95, 0.35)
		end
		if showExplainLegacyScore then
			GS_ExplainTooltip:AddDoubleLine("Legacy GearScore", tostring(item.legacyBase), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
		end
		if showExplainPvpScore then
			GS_ExplainTooltip:AddDoubleLine("PvP GearScore", tostring(pvp), 0.95, 0.55, 0.25, 0.95, 0.55, 0.25)
		end
		if showExplainGS2 or showExplainLegacyScore or showExplainPvpScore then
			GS_ExplainTooltip:AddLine(" ")
		end
	end
	if showExplainLegacy then
		GS_ExplainTooltip:AddLine("Legacy", 0.95, 0.82, 0.18)
		GS_ExplainTooltip:AddLine("Legacy = iLevel/slot base = " .. tostring(item.legacyBase), 0.88, 0.88, 0.88, true)
		GS_ExplainTooltip:AddLine(" ")
	end
	if showPveSection then
		GS_ExplainTooltip:AddLine("GearScore2", 0.25, 0.95, 0.35)
		if showExplainPveFormula then
			GS_ExplainTooltip:AddLine("GearScore2 = floor((legacy + stats + gems + enchant) * multiplierPvE)", 0.88, 0.88, 0.88, true)
		end
		if showExplainPveParts then
			for index = 1, #explain.pve.parts do
				GS_AddExplainPart(GS_ExplainTooltip, explain.pve.parts[index].label, explain.pve.parts[index], 0.25, 0.95, 0.35)
			end
		end
		if showExplainPveTotals then
			GS_ExplainTooltip:AddDoubleLine("Base before multiplier", tostring(explain.pve.preMultiplier or explain.pve.base or 0), 0.75, 0.95, 0.75, 0.75, 0.95, 0.75)
			GS_ExplainTooltip:AddDoubleLine("PvE resilience multiplier", "x" .. GS_FormatNumber(explain.pve.multiplier or 1), 0.25, 0.95, 0.35, 0.25, 0.95, 0.35)
			GS_ExplainTooltip:AddDoubleLine("Final result", tostring(explain.pve.final), 0.25, 0.95, 0.35, 0.25, 0.95, 0.35)
		end
		if hasPveFlags then
			GS_ExplainTooltip:AddLine("PvE flags", 1, 0.35, 0.35)
			for index = 1, #explain.pve.flags do
				GS_ExplainTooltip:AddLine(" - " .. explain.pve.flags[index], 1, 0.55, 0.55, true)
			end
		end
	end
	if showPvpSection then
		if showPveSection then
			GS_ExplainTooltip:AddLine(" ")
		end
		GS_ExplainTooltip:AddLine("PvP GearScore", 0.95, 0.55, 0.25)
		if showExplainPvpFormula then
			GS_ExplainTooltip:AddLine("PvP = floor((legacy + stats + gems + enchant) * multiplierPvP)", 0.88, 0.88, 0.88, true)
		end
		if showExplainPvpParts then
			for index = 1, #explain.pvp.parts do
				GS_AddExplainPart(GS_ExplainTooltip, explain.pvp.parts[index].label, explain.pvp.parts[index], 0.95, 0.55, 0.25)
			end
		end
		if showExplainPvpTotals then
			GS_ExplainTooltip:AddDoubleLine("Base before multiplier", tostring(explain.pvp.preMultiplier or explain.pvp.base or 0), 1, 0.8, 0.45, 1, 0.8, 0.45)
			GS_ExplainTooltip:AddDoubleLine("PvP resilience multiplier", "x" .. GS_FormatNumber(explain.pvp.multiplier or 1), 0.95, 0.55, 0.25, 0.95, 0.55, 0.25)
			GS_ExplainTooltip:AddDoubleLine("Final result", tostring(explain.pvp.final), 0.95, 0.55, 0.25, 0.95, 0.55, 0.25)
		end
		if hasPvpFlags then
			GS_ExplainTooltip:AddLine("PvP flags", 1, 0.35, 0.35)
			for index = 1, #explain.pvp.flags do
				GS_ExplainTooltip:AddLine(" - " .. explain.pvp.flags[index], 1, 0.55, 0.55, true)
			end
		end
	end
	if hasGeneralFlags then
		GS_ExplainTooltip:AddLine(" ")
		GS_ExplainTooltip:AddLine("General flags", 1, 0.35, 0.35)
		for index = 1, #explain.flags do
			GS_ExplainTooltip:AddLine(" - " .. explain.flags[index], 1, 0.55, 0.55, true)
		end
	end
	if showExplainTopPveStats and explain.pve.statEntries and #explain.pve.statEntries > 0 then
		GS_ExplainTooltip:AddLine(" ")
		GS_ExplainTooltip:AddLine("Top PvE stats", 0.45, 0.85, 1)
		for index = 1, math.min(4, #explain.pve.statEntries) do
			local entry = explain.pve.statEntries[index]
			GS_ExplainTooltip:AddLine("  " .. GS_GetDisplayStatKey(entry.stat) .. ": " .. entry.value .. " * " .. GS_FormatNumber(entry.weight) .. " = " .. GS_FormatNumber(entry.score), 0.78, 0.92, 1, true)
		end
	end
	if showExplainTopPvpStats and explain.pvp.statEntries and #explain.pvp.statEntries > 0 then
		GS_ExplainTooltip:AddLine(" ")
		GS_ExplainTooltip:AddLine("Top PvP stats", 1, 0.72, 0.35)
		for index = 1, math.min(4, #explain.pvp.statEntries) do
			local entry = explain.pvp.statEntries[index]
			GS_ExplainTooltip:AddLine("  " .. GS_GetDisplayStatKey(entry.stat) .. ": " .. entry.value .. " * " .. GS_FormatNumber(entry.weight) .. " = " .. GS_FormatNumber(entry.score), 1, 0.85, 0.6, true)
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

local function GS2_GetItemTooltipQualityColor(score)
	local value = tonumber(score) or 0
	if value >= 500 then
		return 0.94, 0.47, 0.00
	end
	if value >= 400 then
		return 1.00, 0.50, 0.00
	end
	if value >= 300 then
		return 0.69, 0.28, 0.97
	end
	if value >= 200 then
		return 0.00, 0.50, 1.00
	end
	if value >= 100 then
		return 0.12, 1.00, 0.00
	end
	return 0.55, 0.55, 0.55
end

function GS_AddItemLines(tooltip, itemLink)
	if not itemLink or not IsEquippableItem(itemLink) then return end
	local item = GS_GetItemData(itemLink)
	if not item then return end
	if item.unresolvedData then
		tooltip:AddLine("GS2 unavailable: unresolved gem/enchant stats.", 1, 0.55, 0.55, true)
		tooltip:AddLine("Use /gs2 issues to open the copyable report.", 1, 0.72, 0.72, true)
		GS_HideExplainTooltip()
		return
	end
	local context = GS_GetTooltipItemContext(tooltip, itemLink)
	if context and context.scanning then
		tooltip:AddLine(GS_SCAN_TEXT, 0.95, 0.82, 0.18)
		GS_HideExplainTooltip()
		return
	end
	if context and (not context.gs2Available or not context.specKey) then
		tooltip:AddDoubleLine("Spec", "Unknown", 1, 0.65, 0.65, 1, 0.65, 0.65)
		if not GS_Settings or GS_Settings["showItemLegacy"] then
			local lr, lg, lb = GS2_GetItemTooltipQualityColor(item.legacyBase)
			tooltip:AddDoubleLine("Legacy GearScore", tostring(item.legacyBase), lr, lg, lb, lr, lg, lb)
		end
		GS_HideExplainTooltip()
		return
	end
	local gs2, pvp = GS_ScoreItem(item, context.classToken, context.specKey)
	local r, g, b = GS2_GetItemTooltipQualityColor(gs2)
	local lr, lg, lb = GS2_GetItemTooltipQualityColor(item.legacyBase)
	local pr, pg, pb = GS2_GetItemTooltipQualityColor(pvp)
	if context and context.unit and not UnitIsUnit(context.unit, "player") then
		tooltip:AddDoubleLine("Spec", context.specLabel or GS_GetSpecLabel(context.specKey), 0.85, 0.9, 1, 0.85, 0.9, 1)
	end
	if not GS_Settings or GS_Settings["showItemGS2"] then
		tooltip:AddDoubleLine("GearScore2", tostring(gs2), r, g, b, r, g, b)
	end
	if not GS_Settings or GS_Settings["showItemLegacy"] then
		tooltip:AddDoubleLine("Legacy GearScore", tostring(item.legacyBase), lr, lg, lb, lr, lg, lb)
	end
	if not GS_Settings or GS_Settings["showItemPvp"] then
		tooltip:AddDoubleLine("PvP GearScore", tostring(pvp), pr, pg, pb, pr, pg, pb)
	end
	GS_RenderExplainTooltip(tooltip, itemLink)
end

function GS2_SetDetails(tooltip, name)
	local _, unit = GameTooltip:GetUnit()
	local record = unit and GS_GetRecord(unit)
	if not record or not name or UnitName(unit) ~= name then return end
	for slotId, itemLink in pairs(record.detailLinks) do
		local item = GS_GetItemData(itemLink)
		if item then
			local itemName, _, itemRarity = GetItemInfo(itemLink)
			if itemName then
				local color = GS_RARITY[itemRarity or 1] or GS_RARITY[1]
				local suffix = GS_Settings["Level"] == 1 and (" (iLevel " .. tostring(item.level or 0) .. ")") or ""
				if record.gs2Available and record.specKey and not item.unresolvedData then
					local gs2, pvp = GS_ScoreItem(item, record.classToken, record.specKey)
					tooltip:AddDoubleLine("[" .. itemName .. "]", "GS2 " .. tostring(gs2) .. " / L " .. tostring(item.legacyBase) .. " / P " .. tostring(pvp) .. suffix, color.Red, color.Green, color.Blue, 0.85, 0.85, 0.85)
				else
					tooltip:AddDoubleLine("[" .. itemName .. "]", "L " .. tostring(item.legacyBase) .. suffix, color.Red, color.Green, color.Blue, 0.85, 0.85, 0.85)
				end
			end
		end
	end
end

function GS2_HookSetUnit()
	if GS_HasConflict() then return end
	if State.PlayerIsInCombat then return end
	GS_HideExplainTooltip()
	local name, unit = GS_GetTooltipUnit()
	if not name or not unit or not UnitIsPlayer(unit) or (GS_Settings["Player"] ~= 1 and GS_Settings["Player"] ~= 2) then return end
	if GS_IsExternalInspectOpen() and not UnitIsUnit(unit, "player") then
		GS_AddInspectPausedLine(GameTooltip)
		return
	end
	local record = GS_GetRecord(unit)
	if record then
		if not record.gs2Available and not UnitIsUnit(unit, "player") and GS_CanInspectUnitByPolicy(unit) then
			GS_QueueInspect(unit)
		end
		GS_AddScoreLines(GameTooltip, record)
		if (not GS_Settings or GS_Settings["showCharacterCompare"]) and record.gs2Available and not UnitIsUnit(unit, "player") then
			local mine = GS_GetRecord("player")
			if mine then
				local diff = mine.gs2 - record.gs2
				if diff > 0 then GameTooltip:AddDoubleLine("Your GearScore2", tostring(mine.gs2) .. " (+" .. tostring(diff) .. ")", 0, 1, 0, 0, 1, 0)
				elseif diff < 0 then GameTooltip:AddDoubleLine("Your GearScore2", tostring(mine.gs2) .. " (" .. tostring(diff) .. ")", 1, 0, 0, 1, 0, 0)
				else GameTooltip:AddDoubleLine("Your GearScore2", tostring(mine.gs2) .. " (+0)", 0, 1, 1, 0, 1, 1) end
			end
		end
	else
		if GS_CanInspectUnitByPolicy(unit) then
			GameTooltip:AddLine(GS_SCAN_TEXT, 0.95, 0.82, 0.18)
			if (not GS_Settings["MustTarget"]) or UnitIsUnit("target", unit) then GS_QueueInspect(unit) end
		end
	end
end

function GS2_HookSetItem()
	if GS_HasConflict() then return end
	if not State.PlayerIsInCombat then
		local _, link = GameTooltip:GetItem()
		GS_AddItemLines(GameTooltip, link)
	else
		GS_HideExplainTooltip()
	end
end

function GS2_HookRefItem()
	if GS_HasConflict() then return end
	if not State.PlayerIsInCombat then local _, link = ItemRefTooltip:GetItem() GS_AddItemLines(ItemRefTooltip, link) else GS_HideExplainTooltip() end
end

function GS2_HookCompareItem()
	if GS_HasConflict() then return end
	if not State.PlayerIsInCombat then local _, link = ShoppingTooltip1:GetItem() GS_AddItemLines(ShoppingTooltip1, link) else GS_HideExplainTooltip() end
end

function GS2_HookCompareItem2()
	if GS_HasConflict() then return end
	if not State.PlayerIsInCombat then local _, link = ShoppingTooltip2:GetItem() GS_AddItemLines(ShoppingTooltip2, link) else GS_HideExplainTooltip() end
end
