-------------------------------------------------------------------------------
--                         GearScore2 Runtime Helpers                         --
-------------------------------------------------------------------------------

local GS = _G.GS2
local C = GS and GS.Constants or {}
local State = GS and GS.State or {}

local GS_SPEC_LABEL_OVERRIDES = {
	BEASTMASTERY = "Beast Mastery",
	MAGE_FROST = "Frost",
	DRUID_RESTORATION = "Restoration",
}

function GS_FormatNumber(value)
	value = tonumber(value) or 0
	if value == floor(value) then
		return tostring(value)
	end
	return string.format("%.2f", value)
end

function GS_GetSpecLabel(specKey)
	if not specKey then
		return "Unknown"
	end
	if GS_SPEC_LABEL_OVERRIDES[specKey] then
		return GS_SPEC_LABEL_OVERRIDES[specKey]
	end
	local words = {}
	for word in string.gmatch(string.lower(string.gsub(specKey, "_", " ")), "%S+") do
		words[#words + 1] = string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2)
	end
	return #words > 0 and table.concat(words, " ") or specKey
end

function GS_DebugInspect(message)
	if not State.DebugInspectEnabled then
		return
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99GS2 Debug|r " .. tostring(message))
end

function GS_ReportResolutionIssue(issue)
	if not issue then
		return
	end
	local key = table.concat({
		tostring(issue.kind or "unknown"),
		tostring(issue.itemLink or issue.itemName or "?"),
		tostring(issue.slotId or 0),
		tostring(issue.gemIndex or 0),
		tostring(issue.gemId or issue.enchantId or 0),
		tostring(issue.unitName or "item"),
	}, "|")
	if State.ResolutionIssueKeys[key] then
		return
	end
	State.ResolutionIssueKeys[key] = true
	State.ResolutionIssues[#State.ResolutionIssues + 1] = issue
	State.ResolutionIssuesVersion = (State.ResolutionIssuesVersion or 0) + 1
end

function GS_BuildResolutionIssueReport()
	local lines = {
		"GearScore2 unresolved data report",
		"Entries: " .. tostring(#State.ResolutionIssues),
		"",
	}
	for index = 1, #State.ResolutionIssues do
		local issue = State.ResolutionIssues[index]
		lines[#lines + 1] = "[" .. tostring(index) .. "] kind=" .. tostring(issue.kind or "unknown")
		lines[#lines + 1] = "unit=" .. tostring(issue.unitName or "n/a") .. " class=" .. tostring(issue.classToken or "n/a") .. " spec=" .. tostring(issue.specKey or "n/a")
		lines[#lines + 1] = "slotId=" .. tostring(issue.slotId or 0) .. " item=" .. tostring(issue.itemName or "?")
		lines[#lines + 1] = "itemLink=" .. tostring(issue.itemLink or "n/a")
		if issue.gemIndex then
			lines[#lines + 1] = "gemIndex=" .. tostring(issue.gemIndex) .. " gemId=" .. tostring(issue.gemId or 0) .. " gemName=" .. tostring(issue.gemName or "n/a")
			lines[#lines + 1] = "gemLink=" .. tostring(issue.gemLink or "n/a")
		end
		if issue.enchantId then
			lines[#lines + 1] = "enchantId=" .. tostring(issue.enchantId)
		end
		lines[#lines + 1] = "details=" .. tostring(issue.details or "n/a")
		lines[#lines + 1] = ""
	end
	return table.concat(lines, "\n")
end

function GS_AppendExplainLine(lines, text)
	lines[#lines + 1] = text
end

function GS_GetDisplayStatKey(statKey)
	return (GS.StatDisplayKeys and GS.StatDisplayKeys[statKey]) or statKey
end

function GS_TouchCacheEntry(entry)
	if entry then
		entry.lastAccessAt = GetTime()
	end
	return entry
end

function GS_TrimCache(cache, countKey, trimTo)
	local count = State[countKey] or 0
	if count <= trimTo then
		return
	end
	local entries = {}
	for key, entry in pairs(cache) do
		entries[#entries + 1] = {
			key = key,
			lastAccessAt = (entry and (entry.lastAccessAt or entry.cachedAt)) or 0,
		}
	end
	table.sort(entries, function(a, b) return a.lastAccessAt < b.lastAccessAt end)
	local removeCount = count - trimTo
	for index = 1, removeCount do
		local cacheKey = entries[index] and entries[index].key
		if cacheKey and cache[cacheKey] ~= nil then
			cache[cacheKey] = nil
			count = count - 1
		end
	end
	State[countKey] = count
end

function GS_StoreCacheEntry(cache, key, entry, countKey, maxEntries, trimTo)
	if not cache or not key or not entry then
		return entry
	end
	if cache[key] == nil then
		State[countKey] = (State[countKey] or 0) + 1
	end
	entry.cachedAt = entry.cachedAt or GetTime()
	entry.lastAccessAt = GetTime()
	cache[key] = entry
	if (State[countKey] or 0) > maxEntries then
		GS_TrimCache(cache, countKey, trimTo)
	end
	return entry
end

function GS_RemoveCacheEntry(cache, key, countKey)
	if not cache or key == nil or cache[key] == nil then
		return false
	end
	cache[key] = nil
	if countKey then
		State[countKey] = max(0, (State[countKey] or 0) - 1)
	end
	return true
end

function GS_AddStats(target, source)
	if not target or not source then
		return target
	end
	for stat, value in pairs(source) do
		value = tonumber(value) or 0
		if value ~= 0 then
			target[stat] = (target[stat] or 0) + value
		end
	end
	return target
end

function GS_BuildTopStats(stats, weights)
	local entries = {}
	if not stats or not weights then
		return entries
	end
	for stat, value in pairs(stats) do
		local weight = weights[stat]
		if weight and value and value ~= 0 then
			entries[#entries + 1] = { stat = stat, value = value, weight = weight, score = value * weight }
		end
	end
	table.sort(entries, function(a, b) return a.score > b.score end)
	return entries
end
