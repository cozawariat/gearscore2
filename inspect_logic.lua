-------------------------------------------------------------------------------
--                         GearScoreAI Inspect Logic                         --
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
	for index = 1, #candidates do
		local unit = candidates[index]
		if UnitGUID(unit) == guid then return unit end
	end
	local _, tooltipUnit = GS_GetTooltipUnit()
	if tooltipUnit and UnitGUID(tooltipUnit) == guid then return tooltipUnit end
end

function GS_DetectSpec(unit, classToken, inspect)
	local order = GS_ClassSpecOrder[classToken]
	if not order then return GS_ClassDefaults[classToken], not inspect end
	local numTabs = GetNumTalentTabs and GetNumTalentTabs(inspect, false) or 3
	if not numTabs or numTabs < 1 then
		numTabs = 3
	end
	local bestPoints, bestSpec, sawPointValue = -1, nil, false
	for tab = 1, numTabs do
		local _, _, _, _, points = GetTalentTabInfo(tab, inspect, false)
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
	local specKey, specResolved = GS_DetectSpec(unit, classToken, inspect)
	local specSource = specResolved and "live" or "none"
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
		capAdjustedGs2, capBreakdown, capStats = GS_ApplyCharacterCaps(snapshot)
		gs2 = gs2 + (capAdjustedGs2 or 0)
		if snapshot.specSource == "live" then
			GS_InspectState.lastConfirmedSpecByGuid[snapshot.guid] = snapshot.specKey
		end
	end
	local specLabel = snapshot.specKey and GS_GetSpecLabel(snapshot.specKey) or "Unknown"
	local scanStatusText = snapshot.specResolved and specLabel or "Spec unknown"
	if snapshot.specResolved and snapshot.specSource == "cached" then
		scanStatusText = specLabel .. " [CACHED]"
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
	GS_InspectState.queued[guid] = true
	GS_InspectQueue[#GS_InspectQueue + 1] = { guid = guid, unit = unit, queuedAt = now }
end

function GS_RefreshTooltip(guid)
	if not GameTooltip:IsShown() then return end
	if GS_TooltipInventoryContext.guid and GS_TooltipInventoryContext.guid == guid and GS_TooltipInventoryContext.unit and GS_TooltipInventoryContext.slot then
		GearScore_Original_SetInventoryItem(GameTooltip, GS_TooltipInventoryContext.unit, GS_TooltipInventoryContext.slot)
		return
	end
	local _, unit = GameTooltip:GetUnit()
	if unit and UnitGUID(unit) == guid then GameTooltip:SetUnit(unit) end
end

function GS_ProcessInspectQueue()
	local now, active = GetTime(), GS_InspectState.active
	if active and ((active.readyAt and now >= active.readyAt) or ((not active.readyAt) and active.pollAt and now >= active.pollAt)) then
		local inspectUnit = UnitGUID(active.unit) == active.guid and active.unit or GS_ResolveUnitByGUID(active.guid)
		local snapshot = inspectUnit and GS_CollectSnapshot(inspectUnit, true) or nil
		local itemCount = snapshot and snapshot.itemCount or 0
		local timedOut = (now - active.startedAt) >= GS_SCAN_TIMEOUT
		if snapshot and snapshot.specResolved and itemCount >= GS_MIN_INSPECT_ITEMS then
			GS_FinalizeSnapshotSpec(snapshot, snapshot.specKey, "live", false)
			GS_BuildRecord(snapshot)
			ClearInspectPlayer()
			GS_InspectState.active = nil
			GS_RefreshTooltip(active.guid)
			return
		end
		if timedOut then
			if snapshot then
				if snapshot.specResolved and snapshot.specKey then
					GS_FinalizeSnapshotSpec(snapshot, snapshot.specKey, "live", true)
				else
					local cachedSpec = GS_InspectState.lastConfirmedSpecByGuid[active.guid]
					if cachedSpec then
						GS_FinalizeSnapshotSpec(snapshot, cachedSpec, "cached", true)
					else
						GS_FinalizeSnapshotSpec(snapshot, nil, "none", true)
					end
				end
				GS_BuildRecord(snapshot)
			end
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
			GS_InspectState.active = { guid = request.guid, unit = request.unit, startedAt = now, pollAt = now + GS_FORCE_POLL_DELAY, readyRetries = 0, specResolvedAt = nil, timedOut = false }
			GS_InspectState.recent[request.guid], GS_InspectState.lastInspectAt = now, now
			return
		end
	end
end

function GearScore_GetScore(_, target)
	local record = GS_GetRecord(target or "player")
	return record and record.gs2 or 0, record and record.average or 0
end
