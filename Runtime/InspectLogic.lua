-------------------------------------------------------------------------------
--                          GearScore2 Inspect Logic                          --
-------------------------------------------------------------------------------

local GS = _G.GS2
local State = GS and GS.State or {}
local C = GS and GS.Constants or {}
local Data = GS and GS.Data or {}
local Tables = Data.Tables or {}
local GS_CLASS_SPEC_ORDER = Tables.ClassSpecOrder or {}
local GS_CLASS_DEFAULTS = Tables.ClassDefaults or {}
local GS_SPEC_PROFILES = Tables.SpecProfiles or {}
local GS_SCAN_TEXT = C.SCAN_TEXT or "|cffaaaaaaScanning...|r"
local GS_MOUSEOVER_INSPECT_DELAY = C.MOUSEOVER_INSPECT_DELAY or 0.25
local GS_INSPECT_THROTTLE = C.INSPECT_THROTTLE or 0.35
local GS_RECENT_WINDOW = C.RECENT_WINDOW or 1.5
local GS_ACTIVE_TIMEOUT = C.ACTIVE_TIMEOUT or 3.0
local GS_SCAN_TIMEOUT = C.SCAN_TIMEOUT or 3.0
local GS_CACHE_TTL = C.CACHE_TTL or 180
local GS_FRESH_TTL = C.FRESH_TTL or 15
local GS_INSPECT_CACHE_MAX = C.INSPECT_CACHE_MAX or 300
local GS_INSPECT_CACHE_TRIM_TO = C.INSPECT_CACHE_TRIM_TO or 220
local GS_READY_DELAY = C.READY_DELAY or 0.15
local GS_MIN_INSPECT_ITEMS = C.MIN_INSPECT_ITEMS or 8
local GS_FORCE_POLL_DELAY = C.FORCE_POLL_DELAY or 0.20
local GS_TALENT_SPEC_WAIT = C.TALENT_SPEC_WAIT or 1.0
local GS_OFFSPEC_MIN_RATIO = C.OFFSPEC_MIN_RATIO or 0.05
local GS_InspectQueue = State.InspectQueue or {}
local GS_InspectCache = State.InspectCache or {}
local GS_InspectState = State.InspectState or { active = nil, lastInspectAt = 0, queued = {}, recent = {}, hoverGuid = nil, hoverStartedAt = 0 }
local GS_TooltipInventoryContext = State.TooltipInventoryContext or { unit = nil, slot = nil, guid = nil }

local function GS_GetLiveInspectCacheRecord(guid)
	if not guid then
		return nil
	end
	local cached = GS_InspectCache[guid]
	if not cached then
		return nil
	end
	if cached.expiresAt and cached.expiresAt > GetTime() then
		return GS_TouchCacheEntry(cached)
	end
	GS_RemoveCacheEntry(GS_InspectCache, guid, "InspectCacheCount")
	return nil
end

function GS_GetTooltipUnit()
	local _, unit = GameTooltip:GetUnit()
	if unit and UnitName(unit) then return UnitName(unit), unit end
	if UnitName("mouseover") then return UnitName("mouseover"), "mouseover" end
	if ElvUI or ShadowUF or VuhDo then
		local frame = GetMouseFocus()
		local customUnit = frame and (frame.unit or frame.raidid)
		if customUnit and UnitName(customUnit) then return UnitName(customUnit), customUnit end
	end
end

function GS_ResolveUnitByGUID(guid)
	if not guid then return nil end
	local candidates = {
		"mouseover", "target", "focus",
		"party1", "party2", "party3", "party4",
		"raid1", "raid2", "raid3", "raid4", "raid5", "raid6", "raid7", "raid8", "raid9", "raid10",
		"raid11", "raid12", "raid13", "raid14", "raid15", "raid16", "raid17", "raid18", "raid19", "raid20",
		"raid21", "raid22", "raid23", "raid24", "raid25", "raid26", "raid27", "raid28", "raid29", "raid30",
		"raid31", "raid32", "raid33", "raid34", "raid35", "raid36", "raid37", "raid38", "raid39", "raid40",
	}
	if InspectFrame and InspectFrame.unit then
		candidates[#candidates + 1] = InspectFrame.unit
	end
	if Examiner and Examiner.unit then
		candidates[#candidates + 1] = Examiner.unit
	end
	for index = 1, #candidates do
		local unit = candidates[index]
		if UnitGUID(unit) == guid then return unit end
	end
	local _, tooltipUnit = GS_GetTooltipUnit()
	if tooltipUnit and UnitGUID(tooltipUnit) == guid then return tooltipUnit end
end

function GS_IsStableInspectUnit(unit)
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return false
	end
	if UnitIsUnit(unit, "mouseover") then
		local _, tooltipUnit = GS_GetTooltipUnit()
		if tooltipUnit and UnitGUID(tooltipUnit) == UnitGUID(unit) then
			return true
		end
	end
	if UnitIsUnit(unit, "target") or UnitIsUnit(unit, "focus") then
		return true
	end
	if string.find(unit, "^party%d$") or string.find(unit, "^raid%d+$") then
		return true
	end
	if InspectFrame and InspectFrame.unit and UnitIsUnit(unit, InspectFrame.unit) then
		return true
	end
	if Examiner and Examiner.unit and UnitIsUnit(unit, Examiner.unit) then
		return true
	end
	return false
end

function GS_CanInspectUnitByPolicy(unit)
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then
		return false
	end
	if not CanInspect(unit) then
		return false
	end
	local playerFaction = UnitFactionGroup("player")
	local unitFaction = UnitFactionGroup(unit)
	if playerFaction and unitFaction and playerFaction ~= unitFaction then
		return GetZonePVPInfo() == "sanctuary"
	end
	return true
end

function GS_DetectSpec(unit, classToken, inspect, talentsReady)
	local order = GS_CLASS_SPEC_ORDER[classToken]
	if not order then return GS_CLASS_DEFAULTS[classToken], not inspect end
	local talentGroup = GetActiveTalentGroup and GetActiveTalentGroup(inspect) or nil
	local numTabs = GetNumTalentTabs and GetNumTalentTabs(inspect, false) or 3
	if not numTabs or numTabs < 1 then
		numTabs = 3
	end
	local bestPoints, bestSpec, sawPointValue = -1, nil, false
	local debugTabs = {}
	for tab = 1, numTabs do
		local _, _, points = GetTalentTabInfo(tab, inspect, nil, talentGroup)
		debugTabs[#debugTabs + 1] = tostring(points)
		if points ~= nil then
			sawPointValue = true
			if points > bestPoints then
				bestPoints, bestSpec = points, (order[tab] or bestSpec)
			elseif not bestSpec then
				bestSpec = order[tab] or bestSpec
			end
		end
	end
	if inspect then
		GS_DebugInspect("tabs for " .. (UnitName(unit) or "?") .. ": [" .. table.concat(debugTabs, ", ") .. "] best=" .. tostring(bestSpec) .. " bestPoints=" .. tostring(bestPoints) .. " talentReady=" .. tostring(talentsReady) .. " talentGroup=" .. tostring(talentGroup))
	end
	if inspect then
		if sawPointValue and bestSpec then
			return bestSpec, true
		end
		return nil, false
	end
	return bestSpec or GS_CLASS_DEFAULTS[classToken], true
end

function GS_CollectSnapshot(unit, inspect)
	local name, guid = UnitName(unit), UnitGUID(unit)
	local _, classToken = UnitClass(unit)
	local _, raceToken = UnitRace(unit)
	if not name or not guid or not classToken then return nil end
	local specKey, specResolved, specSource = nil, false, "none"
	if not inspect then
		specKey, specResolved = GS_DetectSpec(unit, classToken, false, false)
		specSource = specResolved and "live" or "none"
	end
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
	return {
		name = name,
		guid = guid,
		unit = unit,
		classToken = classToken,
		raceToken = raceToken and string.upper(string.gsub(raceToken, "[%s_]", "")) or nil,
		specKey = specKey,
		specResolved = specResolved and specKey ~= nil,
		specSource = specSource,
		scanExpired = false,
		items = items,
		itemCount = itemCount,
		fingerprint = table.concat(fingerprint, "|"),
		average = itemCount > 0 and floor(levelTotal / itemCount) or 0,
	}
end

function GS_FinalizeSnapshotSpec(snapshot, specKey, specSource, scanExpired)
	if not snapshot then
		return nil
	end
	snapshot.specKey = specKey
	snapshot.specResolved = specKey ~= nil and specSource ~= "none"
	snapshot.specSource = specSource or (snapshot.specResolved and "live" or "none")
	snapshot.scanExpired = scanExpired and true or false
	return snapshot
end

function GS_GetSnapshotSpecScore(snapshot, specKey)
	if not snapshot or not snapshot.classToken or not snapshot.items or not specKey or not GS_SPEC_PROFILES[specKey] then
		return nil
	end
	local total = 0
	for itemIndex = 1, #snapshot.items do
		local entry = snapshot.items[itemIndex]
		local itemGS2 = GS_ScoreItem(entry.item, snapshot.classToken, specKey)
		if itemGS2 == nil then
			return nil
		end
		total = total + itemGS2
	end
	local capAdjustedGs2 = GS_ApplyCharacterCaps({ unit = snapshot.unit, specKey = specKey, raceToken = snapshot.raceToken, items = snapshot.items }, total)
	return total + (capAdjustedGs2 or 0)
end

local function GS_GetCandidateSignatureFloor(role, itemCount)
	itemCount = tonumber(itemCount) or 0
	if role == "TANK" then
		return 2
	end
	if role == "HEALER" then
		return max(3, floor(itemCount * 0.18))
	end
	if role == "CASTER" then
		return max(4, floor(itemCount * 0.25))
	end
	return max(4, floor(itemCount * 0.25))
end

function GS_GetSnapshotSpecDiagnostics(snapshot, specKey)
	if not snapshot or not snapshot.classToken or not snapshot.items or not specKey or not GS_SPEC_PROFILES[specKey] then
		return nil
	end
	local profile = GS_SPEC_PROFILES[specKey]
	local compatibleItems, matchedItems, signatureItems = 0, 0, 0
	local positiveSlots, signatureSlots = {}, {}
	local totalBeforeCaps, legacyTotal = 0, 0
	for itemIndex = 1, #snapshot.items do
		local entry = snapshot.items[itemIndex]
		local item = entry.item
		if GS_IsItemCompatible(item, snapshot.classToken, profile) then
			local itemGS2 = GS_ScoreItem(item, snapshot.classToken, specKey)
			if itemGS2 == nil then
				return nil
			end
			compatibleItems = compatibleItems + 1
			legacyTotal = legacyTotal + (entry.legacy or 0)
			totalBeforeCaps = totalBeforeCaps + itemGS2

			local rawScore = GS_ScoreStats(item and item.stats, profile.pve)
			local gemScore = 0
			if item and item.gemStats then
				for gemIndex = 1, 4 do
					gemScore = gemScore + GS_ScoreStats(item.gemStats[gemIndex], profile.pve)
				end
			end
			local enchantScore = GS_ScoreStats(GS_GetEnchantStats(item), profile.pve)
			if rawScore > 0 or gemScore > 0 or enchantScore > 0 then
				matchedItems = matchedItems + 1
				positiveSlots[#positiveSlots + 1] = tostring(entry.slotId)
			end
			if GS_GetRoleSignatureKind(item) == profile.role then
				signatureItems = signatureItems + 1
				signatureSlots[#signatureSlots + 1] = tostring(entry.slotId)
			end
		end
	end
	local capBonus = GS_ApplyCharacterCaps({ unit = snapshot.unit, specKey = specKey, raceToken = snapshot.raceToken, items = snapshot.items }, totalBeforeCaps) or 0
	return {
		specKey = specKey,
		specLabel = GS_GetSpecLabel(specKey),
		role = profile.role,
		itemCount = #snapshot.items,
		compatibleItems = compatibleItems,
		matchedItems = matchedItems,
		signatureItems = signatureItems,
		legacyTotal = legacyTotal,
		totalBeforeCaps = totalBeforeCaps,
		capBonus = capBonus,
		total = totalBeforeCaps + capBonus,
		positiveSlots = positiveSlots,
		signatureSlots = signatureSlots,
	}
end

local function GS_IsPlausibleOffSpecCandidate(snapshot, diagnostics)
	if not snapshot or not diagnostics then
		return false, "no diagnostics"
	end
	local itemCount = diagnostics.itemCount or (#snapshot.items or 0)
	local requiredMatchedItems = max(4, floor(itemCount * 0.35))
	local requiredSignatureItems = GS_GetCandidateSignatureFloor(diagnostics.role, itemCount)
	if diagnostics.compatibleItems < max(6, floor(itemCount * 0.6)) then
		return false, "too few compatible items"
	end
	if diagnostics.matchedItems < requiredMatchedItems then
		return false, "too few matched items"
	end
	if diagnostics.role == "TANK" or diagnostics.role == "HEALER" or diagnostics.role == "CASTER" then
		if diagnostics.signatureItems < requiredSignatureItems then
			return false, "insufficient role signature"
		end
	end
	return true, "plausible"
end

local function GS_GetOffSpecReason(activeDiagnostics, alternateDiagnostics)
	if not activeDiagnostics or not alternateDiagnostics then
		return "unknown"
	end
	if (alternateDiagnostics.compatibleItems or 0) > (activeDiagnostics.compatibleItems or 0) then
		return "item acceptance"
	end
	return "weight overlap"
end

function GS_GetBestSnapshotSpec(snapshot, excludedSpecKey)
	if not snapshot or not snapshot.classToken or not snapshot.items then
		return nil, nil, nil
	end
	local candidates = GS_CLASS_SPEC_ORDER[snapshot.classToken]
	if not candidates or #candidates == 0 then
		return nil, nil, nil
	end
	local bestSpec, bestScore, bestDiagnostics = nil, nil, nil
	for index = 1, #candidates do
		local candidateSpec = candidates[index]
		if candidateSpec ~= excludedSpecKey and GS_SPEC_PROFILES[candidateSpec] then
			local diagnostics = GS_GetSnapshotSpecDiagnostics(snapshot, candidateSpec)
			local plausible, plausibilityReason = GS_IsPlausibleOffSpecCandidate(snapshot, diagnostics)
			local total = diagnostics and diagnostics.total or nil
			GS_DebugInspect("infer candidate " .. tostring(candidateSpec) .. " total=" .. tostring(total) .. " compatible=" .. tostring(diagnostics and diagnostics.compatibleItems or 0) .. "/" .. tostring(diagnostics and diagnostics.itemCount or 0) .. " matched=" .. tostring(diagnostics and diagnostics.matchedItems or 0) .. " signature=" .. tostring(diagnostics and diagnostics.signatureItems or 0) .. " plausible=" .. tostring(plausible) .. " reason=" .. tostring(plausibilityReason) .. " for " .. tostring(snapshot.name))
			if plausible and total and (not bestScore or total > bestScore) then
				bestScore = total
				bestSpec = candidateSpec
				bestDiagnostics = diagnostics
			end
		end
	end
	return bestSpec, bestScore, bestDiagnostics
end

function GS_InferSpecFromSnapshot(snapshot)
	local bestSpec, bestScore = GS_GetBestSnapshotSpec(snapshot, nil)
	return bestSpec, bestScore
end

local function GS_IsMeaningfulOffSpecUpgrade(activeGs2, betterGs2)
	activeGs2 = tonumber(activeGs2)
	betterGs2 = tonumber(betterGs2)
	if not activeGs2 or not betterGs2 then
		return false
	end
	return betterGs2 > (activeGs2 * (1 + GS_OFFSPEC_MIN_RATIO))
end

function GS_GetScanRecord(guid)
	if not guid then
		return nil
	end
	local cached = GS_GetLiveInspectCacheRecord(guid)
	if cached then
		return cached
	end
	local active = GS_InspectState.active
	if active and active.guid == guid then
		return {
			guid = guid,
			specResolved = false,
			specSource = "none",
			scanExpired = false,
			gs2Available = false,
			scanStatusText = GS_SCAN_TEXT,
		}
	end
	if GS_InspectState.queued[guid] then
		return {
			guid = guid,
			specResolved = false,
			specSource = "none",
			scanExpired = false,
			gs2Available = false,
			scanStatusText = GS_SCAN_TEXT,
		}
	end
end

function GS_BuildRecord(snapshot)
	local cached = GS_GetLiveInspectCacheRecord(snapshot.guid)
	if cached and cached.fingerprint == snapshot.fingerprint and cached.specKey == snapshot.specKey and cached.specSource == (snapshot.specSource or "none") then
		return cached
	end
	local gs2, legacy, pvp, detailLinks = 0, 0, 0, {}
	local unresolvedData = false
	for index = 1, #snapshot.items do
		local entry = snapshot.items[index]
		local itemGS2, itemPVP = 0, nil
		if snapshot.specResolved and snapshot.specKey then
			itemGS2, itemPVP = GS_ScoreItem(entry.item, snapshot.classToken, snapshot.specKey)
			if itemGS2 == nil or itemPVP == nil then
				unresolvedData = true
			else
				gs2 = gs2 + itemGS2
				pvp = (pvp or 0) + itemPVP
			end
		end
		legacy = legacy + entry.legacy
		detailLinks[entry.slotId] = entry.item.link
	end
	local capAdjustedGs2, capBreakdown, capStats = 0, nil, nil
	if snapshot.specResolved and snapshot.specKey and not unresolvedData then
		capAdjustedGs2, capBreakdown, capStats = GS_ApplyCharacterCaps(snapshot, gs2)
		gs2 = gs2 + (capAdjustedGs2 or 0)
	end
	local offSpec = false
	local offSpecBetterSpecKey, offSpecBetterSpecLabel, offSpecBetterGs2, offSpecReason = nil, nil, nil, nil
	local specLabel = snapshot.specKey and GS_GetSpecLabel(snapshot.specKey) or "Unknown"
	local scanStatusText = snapshot.specResolved and specLabel or "Spec unknown"
	if unresolvedData then
		scanStatusText = "GS2 unavailable"
	elseif snapshot.specResolved and snapshot.specSource == "inspect" and snapshot.specKey and gs2 ~= nil then
		local activeDiagnostics = GS_GetSnapshotSpecDiagnostics(snapshot, snapshot.specKey)
		local betterSpecKey, betterGs2, betterDiagnostics = GS_GetBestSnapshotSpec(snapshot, snapshot.specKey)
		if activeDiagnostics and betterDiagnostics then
			local deltaPct = (gs2 > 0 and betterGs2) and (((betterGs2 - gs2) / gs2) * 100) or 0
			local reason = GS_GetOffSpecReason(activeDiagnostics, betterDiagnostics)
			GS_DebugInspect("offspec compare " .. tostring(snapshot.name) .. " active=" .. tostring(snapshot.specKey) .. " activeGs2=" .. tostring(floor(gs2)) .. " alt=" .. tostring(betterSpecKey) .. " altGs2=" .. tostring(betterGs2 and floor(betterGs2) or nil) .. " deltaPct=" .. string.format("%.2f", deltaPct) .. " reason=" .. tostring(reason) .. " activeMatched=" .. tostring(activeDiagnostics.matchedItems) .. " altMatched=" .. tostring(betterDiagnostics.matchedItems) .. " activeCompatible=" .. tostring(activeDiagnostics.compatibleItems) .. " altCompatible=" .. tostring(betterDiagnostics.compatibleItems))
			if State.DebugInspectEnabled and #betterDiagnostics.positiveSlots > 0 then
				GS_DebugInspect("offspec alt positive slots=" .. table.concat(betterDiagnostics.positiveSlots, ",") .. " signature slots=" .. table.concat(betterDiagnostics.signatureSlots, ","))
			end
		end
		if betterSpecKey and betterGs2 and GS_IsMeaningfulOffSpecUpgrade(gs2, betterGs2) then
			offSpec = true
			offSpecBetterSpecKey = betterSpecKey
			offSpecBetterSpecLabel = GS_GetSpecLabel(betterSpecKey)
			offSpecBetterGs2 = floor(betterGs2)
			offSpecReason = GS_GetOffSpecReason(activeDiagnostics, betterDiagnostics)
		end
	end
	if snapshot.specResolved then
		if snapshot.specSource == "inferred" then
			scanStatusText = specLabel .. " [INFERRED]"
		elseif offSpec and offSpecBetterSpecLabel then
			scanStatusText = specLabel .. " (! " .. offSpecBetterSpecLabel .. ")"
		else
			scanStatusText = specLabel
		end
	end
	cached = {
		guid = snapshot.guid,
		name = snapshot.name,
		classToken = snapshot.classToken,
		specKey = snapshot.specKey,
		specLabel = specLabel,
		specResolved = snapshot.specResolved and true or false,
		specSource = snapshot.specSource or "none",
		scanExpired = snapshot.scanExpired and true or false,
		gs2Available = snapshot.specResolved and snapshot.specKey ~= nil and not unresolvedData,
		scanStatusText = scanStatusText,
		offSpec = offSpec,
		offSpecBetterSpecKey = offSpecBetterSpecKey,
		offSpecBetterSpecLabel = offSpecBetterSpecLabel,
		offSpecBetterGs2 = offSpecBetterGs2,
		offSpecReason = offSpecReason,
		fingerprint = snapshot.fingerprint,
		average = snapshot.average,
		gs2 = (snapshot.specResolved and not unresolvedData) and floor(gs2) or nil,
		legacy = floor(legacy),
		pvp = (snapshot.specResolved and not unresolvedData) and floor(pvp or 0) or nil,
		capAdjustedGs2 = capAdjustedGs2 or 0,
		capBreakdown = capBreakdown,
		capStats = capStats,
		detailLinks = detailLinks,
		unresolvedData = unresolvedData,
		expiresAt = GetTime() + GS_CACHE_TTL,
		freshUntil = GetTime() + GS_FRESH_TTL,
	}
	return GS_StoreCacheEntry(GS_InspectCache, snapshot.guid, cached, "InspectCacheCount", GS_INSPECT_CACHE_MAX, GS_INSPECT_CACHE_TRIM_TO)
end

function GS_GetRecord(unit)
	local guid = UnitGUID(unit)
	if not guid then return nil end
	local cached = GS_GetLiveInspectCacheRecord(guid)
	if cached then return cached end
	if UnitIsUnit(unit, "player") then
		local snapshot = GS_CollectSnapshot("player", false)
		if snapshot then return GS_BuildRecord(snapshot) end
	end
end

function GS_QueueInspect(unit)
	local guid, now = UnitGUID(unit), GetTime()
	if not guid or UnitIsUnit(unit, "player") or GS_InspectState.queued[guid] then return end
	if GS_InspectState.active and GS_InspectState.active.guid == guid then return end
	if GS_InspectState.recent[guid] and (now - GS_InspectState.recent[guid]) < GS_RECENT_WINDOW then return end
	if not GS_CanInspectUnitByPolicy(unit) then return end
	if not GS_IsStableInspectUnit(unit) then
		GS_DebugInspect("skip unstable inspect unit " .. tostring(unit) .. " name=" .. tostring(UnitName(unit)))
		return
	end
	if UnitIsUnit(unit, "mouseover") then
		if GS_InspectState.hoverGuid ~= guid then
			GS_InspectState.hoverGuid = guid
			GS_InspectState.hoverStartedAt = now
			GS_DebugInspect("defer mouseover inspect " .. (UnitName(unit) or "?") .. " guid=" .. tostring(guid) .. " delay=" .. tostring(GS_MOUSEOVER_INSPECT_DELAY))
			return
		end
	else
		if GS_InspectState.hoverGuid == guid then
			GS_InspectState.hoverGuid = nil
			GS_InspectState.hoverStartedAt = 0
		end
	end
	GS_DebugInspect("queue inspect " .. (UnitName(unit) or "?") .. " guid=" .. tostring(guid))
	GS_InspectState.queued[guid] = true
	GS_InspectQueue[#GS_InspectQueue + 1] = { guid = guid, unit = unit, queuedAt = now }
end

function GS_RefreshTooltip(guid)
	if not GameTooltip:IsShown() then return end
	if GS_TooltipInventoryContext.guid and GS_TooltipInventoryContext.guid == guid and GS_TooltipInventoryContext.unit and GS_TooltipInventoryContext.slot then
		GS_OriginalSetInventoryItem(GameTooltip, GS_TooltipInventoryContext.unit, GS_TooltipInventoryContext.slot)
		return
	end
	local _, unit = GameTooltip:GetUnit()
	if unit and UnitGUID(unit) == guid then GameTooltip:SetUnit(unit) end
	local _, tooltipUnit = GS_GetTooltipUnit()
	if tooltipUnit and UnitGUID(tooltipUnit) == guid then GameTooltip:SetUnit(tooltipUnit) end
end

function GS_IsExternalInspectOpen()
	return (InspectFrame and InspectFrame:IsShown()) or (Examiner and Examiner:IsShown())
end

function GS_ClearInspectIfSafe()
	if not GS_IsExternalInspectOpen() then
		ClearInspectPlayer()
	end
end

function GS_ProcessInspectQueue()
	local now, active = GetTime(), GS_InspectState.active
	if GS_InspectState.hoverGuid then
		local hoverUnit = GS_ResolveUnitByGUID(GS_InspectState.hoverGuid)
		if not hoverUnit or not UnitExists(hoverUnit) or UnitGUID(hoverUnit) ~= GS_InspectState.hoverGuid or not UnitIsPlayer(hoverUnit) then
			GS_InspectState.hoverGuid = nil
			GS_InspectState.hoverStartedAt = 0
		elseif not GS_InspectState.queued[GS_InspectState.hoverGuid]
			and (not GS_InspectState.active or GS_InspectState.active.guid ~= GS_InspectState.hoverGuid)
			and (not GS_InspectState.recent[GS_InspectState.hoverGuid] or (now - GS_InspectState.recent[GS_InspectState.hoverGuid]) >= GS_RECENT_WINDOW)
			and (now - (GS_InspectState.hoverStartedAt or now)) >= GS_MOUSEOVER_INSPECT_DELAY then
			GS_DebugInspect("queue mouseover inspect " .. (UnitName(hoverUnit) or "?") .. " guid=" .. tostring(GS_InspectState.hoverGuid))
			GS_InspectState.queued[GS_InspectState.hoverGuid] = true
			GS_InspectQueue[#GS_InspectQueue + 1] = { guid = GS_InspectState.hoverGuid, unit = hoverUnit, queuedAt = now }
			GS_InspectState.hoverGuid = nil
			GS_InspectState.hoverStartedAt = 0
		end
	end
	if active and ((active.readyAt and now >= active.readyAt) or ((not active.readyAt) and active.pollAt and now >= active.pollAt)) then
		local inspectUnit = UnitGUID(active.unit) == active.guid and active.unit or GS_ResolveUnitByGUID(active.guid)
		local snapshot = inspectUnit and GS_CollectSnapshot(inspectUnit, true) or nil
		local itemCount = snapshot and snapshot.itemCount or 0
		local inspectSpec, inspectSpecResolved = nil, false
		if snapshot and inspectUnit then
			inspectSpec, inspectSpecResolved = GS_DetectSpec(inspectUnit, snapshot.classToken, true, active.talentReady)
		end
		if snapshot then
			GS_DebugInspect("poll " .. tostring(snapshot.name) .. " items=" .. tostring(itemCount) .. " timedOut=" .. tostring((now - active.startedAt) >= GS_SCAN_TIMEOUT) .. " inspectSpec=" .. tostring(inspectSpec))
		else
			GS_DebugInspect("poll failed: no snapshot for guid=" .. tostring(active.guid))
		end
		if snapshot and itemCount >= GS_MIN_INSPECT_ITEMS then
			if inspectSpecResolved and inspectSpec then
				GS_FinalizeSnapshotSpec(snapshot, inspectSpec, "inspect", false)
				GS_DebugInspect("finalize inspect " .. tostring(snapshot.name) .. " spec=" .. tostring(inspectSpec))
			elseif now >= (active.inferAt or active.startedAt) then
				local inferredSpec = GS_InferSpecFromSnapshot(snapshot)
				if inferredSpec then
					GS_FinalizeSnapshotSpec(snapshot, inferredSpec, "inferred", false)
					GS_DebugInspect("finalize inferred " .. tostring(snapshot.name) .. " spec=" .. tostring(inferredSpec))
				else
					GS_FinalizeSnapshotSpec(snapshot, nil, "none", false)
					GS_DebugInspect("finalize none " .. tostring(snapshot.name))
				end
			else
				active.readyRetries = active.readyRetries + 1
				active.readyAt = now + GS_READY_DELAY
				active.pollAt = now + GS_READY_DELAY
				return
			end
			GS_BuildRecord(snapshot)
			GS_ClearInspectIfSafe()
			GS_InspectState.active = nil
			GS_RefreshTooltip(active.guid)
			return
		end
		if (now - active.startedAt) >= GS_SCAN_TIMEOUT then
			if snapshot then
				if inspectSpecResolved and inspectSpec then
					GS_FinalizeSnapshotSpec(snapshot, inspectSpec, "inspect", true)
					GS_DebugInspect("timeout finalize inspect " .. tostring(snapshot.name) .. " spec=" .. tostring(inspectSpec))
				else
					local inferredSpec = GS_InferSpecFromSnapshot(snapshot)
					if inferredSpec then
						GS_FinalizeSnapshotSpec(snapshot, inferredSpec, "inferred", true)
						GS_DebugInspect("timeout finalize inferred " .. tostring(snapshot.name) .. " spec=" .. tostring(inferredSpec))
					else
						GS_FinalizeSnapshotSpec(snapshot, nil, "none", true)
						GS_DebugInspect("timeout finalize none " .. tostring(snapshot.name))
					end
				end
				GS_BuildRecord(snapshot)
			end
			GS_ClearInspectIfSafe()
			GS_InspectState.active = nil
			GS_RefreshTooltip(active.guid)
			return
		end
		active.readyRetries = active.readyRetries + 1
		active.readyAt = now + GS_READY_DELAY
		active.pollAt = now + GS_READY_DELAY
		return
	end
	if active and (now - active.startedAt) > GS_ACTIVE_TIMEOUT then GS_ClearInspectIfSafe() GS_InspectState.active = nil end
	if GS_InspectState.active or (now - GS_InspectState.lastInspectAt) < GS_INSPECT_THROTTLE then return end
	while #GS_InspectQueue > 0 do
		local request = table.remove(GS_InspectQueue, 1)
		GS_InspectState.queued[request.guid] = nil
		local dispatchUnit = GS_ResolveUnitByGUID(request.guid) or request.unit
		if dispatchUnit and UnitGUID(dispatchUnit) == request.guid and GS_CanInspectUnitByPolicy(dispatchUnit) then
			GS_DebugInspect("NotifyInspect " .. (UnitName(dispatchUnit) or "?") .. " guid=" .. tostring(request.guid))
			NotifyInspect(dispatchUnit)
			GS_InspectState.active = { guid = request.guid, unit = dispatchUnit, startedAt = now, inferAt = now + GS_TALENT_SPEC_WAIT, pollAt = now + GS_FORCE_POLL_DELAY, readyRetries = 0, specResolvedAt = nil, talentReady = false, timedOut = false }
			GS_InspectState.recent[request.guid], GS_InspectState.lastInspectAt = now, now
			return
		end
	end
end

function GS2_GetScore(_, target)
	local record = GS_GetRecord(target or "player")
	return record and record.gs2 or 0, record and record.average or 0
end
