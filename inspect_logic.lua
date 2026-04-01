-------------------------------------------------------------------------------
--                          GearScore2 Inspect Logic                          --
-------------------------------------------------------------------------------

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
	local order = GS_ClassSpecOrder[classToken]
	if not order then return GS_ClassDefaults[classToken], not inspect end
	local numTabs = GetNumTalentTabs and GetNumTalentTabs(inspect, false) or 3
	if not numTabs or numTabs < 1 then
		numTabs = 3
	end
	local bestPoints, bestSpec, sawPointValue = -1, nil, false
	local debugTabs = {}
	for tab = 1, numTabs do
		local _, _, _, _, points = GetTalentTabInfo(tab, inspect, false)
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
		GS_DebugInspect("tabs for " .. (UnitName(unit) or "?") .. ": [" .. table.concat(debugTabs, ", ") .. "] best=" .. tostring(bestSpec) .. " bestPoints=" .. tostring(bestPoints) .. " talentReady=" .. tostring(talentsReady))
	end
	if inspect then
		if sawPointValue and bestSpec then
			return bestSpec, true
		end
		return nil, false
	end
	return bestSpec or GS_ClassDefaults[classToken], true
end

function GS_CollectSnapshot(unit, inspect)
	local name, guid = UnitName(unit), UnitGUID(unit)
	local _, classToken = UnitClass(unit)
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

function GS_InferSpecFromSnapshot(snapshot)
	if not snapshot or not snapshot.classToken or not snapshot.items then
		return nil, nil
	end
	local candidates = GS_ClassSpecOrder[snapshot.classToken]
	if not candidates or #candidates == 0 then
		return nil, nil
	end
	local bestSpec, bestScore = nil, nil
	for index = 1, #candidates do
		local candidateSpec = candidates[index]
		if GS_SpecProfiles[candidateSpec] then
			local total = 0
			for itemIndex = 1, #snapshot.items do
				local entry = snapshot.items[itemIndex]
				local itemGS2 = GS_ScoreItem(entry.item, snapshot.classToken, candidateSpec)
				total = total + (itemGS2 or 0)
			end
			local capAdjustedGs2 = GS_ApplyCharacterCaps({ unit = snapshot.unit, specKey = candidateSpec, items = snapshot.items }, total)
			total = total + (capAdjustedGs2 or 0)
			GS_DebugInspect("infer candidate " .. tostring(candidateSpec) .. " total=" .. tostring(total) .. " for " .. tostring(snapshot.name))
			if not bestScore or total > bestScore then
				bestScore = total
				bestSpec = candidateSpec
			end
		end
	end
	return bestSpec, bestScore
end

function GS_GetScanRecord(guid)
	if not guid then
		return nil
	end
	local cached = GS_InspectCache[guid]
	if cached and cached.expiresAt > GetTime() then
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
	local cached = GS_InspectCache[snapshot.guid]
	if cached and cached.fingerprint == snapshot.fingerprint and cached.expiresAt > GetTime() and cached.specKey == snapshot.specKey and cached.specSource == (snapshot.specSource or "none") and cached.gs2Available == (snapshot.specResolved and snapshot.specKey ~= nil) then
		return cached
	end
	local gs2, legacy, pvp, detailLinks = 0, 0, 0, {}
	for index = 1, #snapshot.items do
		local entry = snapshot.items[index]
		local itemGS2, itemPVP = 0, nil
		if snapshot.specResolved and snapshot.specKey then
			itemGS2, itemPVP = GS_ScoreItem(entry.item, snapshot.classToken, snapshot.specKey)
			gs2 = gs2 + itemGS2
			pvp = (pvp or 0) + itemPVP
		end
		legacy = legacy + entry.legacy
		detailLinks[entry.slotId] = entry.item.link
	end
	local capAdjustedGs2, capBreakdown, capStats = 0, nil, nil
	if snapshot.specResolved and snapshot.specKey then
		capAdjustedGs2, capBreakdown, capStats = GS_ApplyCharacterCaps(snapshot, gs2)
		gs2 = gs2 + (capAdjustedGs2 or 0)
	end
	local specLabel = snapshot.specKey and GS_GetSpecLabel(snapshot.specKey) or "Unknown"
	local scanStatusText = snapshot.specResolved and specLabel or "Spec unknown"
	cached = {
		guid = snapshot.guid,
		name = snapshot.name,
		classToken = snapshot.classToken,
		specKey = snapshot.specKey,
		specLabel = specLabel,
		specResolved = snapshot.specResolved and true or false,
		specSource = snapshot.specSource or "none",
		scanExpired = snapshot.scanExpired and true or false,
		gs2Available = snapshot.specResolved and snapshot.specKey ~= nil,
		scanStatusText = scanStatusText,
		fingerprint = snapshot.fingerprint,
		average = snapshot.average,
		gs2 = snapshot.specResolved and floor(gs2) or nil,
		legacy = floor(legacy),
		pvp = snapshot.specResolved and floor(pvp or 0) or nil,
		capAdjustedGs2 = capAdjustedGs2 or 0,
		capBreakdown = capBreakdown,
		capStats = capStats,
		detailLinks = detailLinks,
		expiresAt = GetTime() + GS_CACHE_TTL,
		freshUntil = GetTime() + GS_FRESH_TTL,
	}
	GS_InspectCache[snapshot.guid] = cached
	return cached
end

function GS_GetRecord(unit)
	local guid = UnitGUID(unit)
	if not guid then return nil end
	local cached = GS_InspectCache[guid]
	if cached and cached.expiresAt > GetTime() then return cached end
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
		if snapshot then
			GS_DebugInspect("poll " .. tostring(snapshot.name) .. " items=" .. tostring(itemCount) .. " timedOut=" .. tostring((now - active.startedAt) >= GS_SCAN_TIMEOUT))
		else
			GS_DebugInspect("poll failed: no snapshot for guid=" .. tostring(active.guid))
		end
		if snapshot and itemCount >= GS_MIN_INSPECT_ITEMS then
			local inferredSpec = GS_InferSpecFromSnapshot(snapshot)
			if inferredSpec then
				GS_FinalizeSnapshotSpec(snapshot, inferredSpec, "inferred", false)
				GS_DebugInspect("finalize inferred " .. tostring(snapshot.name) .. " spec=" .. tostring(inferredSpec))
			else
				GS_FinalizeSnapshotSpec(snapshot, nil, "none", false)
				GS_DebugInspect("finalize none " .. tostring(snapshot.name))
			end
			GS_BuildRecord(snapshot)
			GS_ClearInspectIfSafe()
			GS_InspectState.active = nil
			GS_RefreshTooltip(active.guid)
			return
		end
		if (now - active.startedAt) >= GS_SCAN_TIMEOUT then
			if snapshot then
				local inferredSpec = GS_InferSpecFromSnapshot(snapshot)
				if inferredSpec then
					GS_FinalizeSnapshotSpec(snapshot, inferredSpec, "inferred", true)
					GS_DebugInspect("timeout finalize inferred " .. tostring(snapshot.name) .. " spec=" .. tostring(inferredSpec))
				else
					GS_FinalizeSnapshotSpec(snapshot, nil, "none", true)
					GS_DebugInspect("timeout finalize none " .. tostring(snapshot.name))
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
			GS_InspectState.active = { guid = request.guid, unit = dispatchUnit, startedAt = now, pollAt = now + GS_FORCE_POLL_DELAY, readyRetries = 0, specResolvedAt = nil, talentReady = false, timedOut = false }
			GS_InspectState.recent[request.guid], GS_InspectState.lastInspectAt = now, now
			return
		end
	end
end

function GS2_GetScore(_, target)
	local record = GS_GetRecord(target or "player")
	return record and record.gs2 or 0, record and record.average or 0
end
