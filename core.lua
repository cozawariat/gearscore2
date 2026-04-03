-------------------------------------------------------------------------------
--                              GearScore2 Core                              --
-------------------------------------------------------------------------------

local GS = _G.GS2 or {}
_G.GS2 = GS

GS.Settings = GS2_Settings or GS.Settings
GS_Settings = GS.Settings or GS_Settings
GS.Settings = GS_Settings

GS.Constants = GS.Constants or {
	SCAN_TEXT = "|cffaaaaaaScanning...|r",
	MOUSEOVER_INSPECT_DELAY = 0.25,
	INSPECT_THROTTLE = 0.35,
	RECENT_WINDOW = 1.5,
	ACTIVE_TIMEOUT = 3.0,
	SCAN_TIMEOUT = 3.0,
	CACHE_TTL = 180,
	FRESH_TTL = 15,
	READY_DELAY = 0.15,
	READY_RETRY_LIMIT = 4,
	MIN_INSPECT_ITEMS = 8,
	FORCE_POLL_DELAY = 0.20,
	TALENT_SPEC_WAIT = 1.0,
	GEM_SCALE = 0.35,
	ENCHANT_SCALE = 0.35,
	PVE_RESILIENCE_RATE = 0.0015,
	PVP_RESILIENCE_RATE = 0.0020,
	PVE_RESILIENCE_FLOOR = 0.70,
	PVP_RESILIENCE_CAP = 1.35,
	GS2_STAT_SCALE = 0.12,
	CAP_BONUS_ANCHOR_LOW_GS2 = 4000,
	CAP_BONUS_ANCHOR_HIGH_GS2 = 5000,
	CAP_BONUS_ANCHOR_LOW_BONUS = 180,
	CAP_BONUS_ANCHOR_HIGH_BONUS = 90,
	CAP_BONUS_MIN = 20,
	CAP_BONUS_MAX = 250,
	CAP_BUFF_MARKER = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12|t",
	ITEM_CACHE_MAX = 800,
	ITEM_CACHE_TRIM_TO = 600,
	PARSED_LINK_CACHE_MAX = 1200,
	PARSED_LINK_CACHE_TRIM_TO = 900,
}
local C = GS.Constants

GS.State = GS.State or {
	PlayerIsInCombat = false,
	InspectQueue = {},
	InspectCache = {},
	ItemCache = {},
	ItemCacheCount = 0,
	ParsedLinkCache = {},
	ParsedLinkCacheCount = 0,
	InspectState = { active = nil, lastInspectAt = 0, queued = {}, recent = {}, hoverGuid = nil, hoverStartedAt = 0 },
	ExplainState = { owner = nil, itemLink = nil, itemSlot = nil },
	TooltipInventoryContext = { unit = nil, slot = nil, guid = nil },
	DebugInspectEnabled = false,
	RuntimeDisabledByConflict = false,
	ConflictWarningShown = false,
	ConflictPopupShown = false,
	OriginalSetInventoryItem = nil,
	ConflictingAddonName = nil,
	ResolutionIssues = {},
	ResolutionIssueKeys = {},
	ResolutionIssuesVersion = 0,
	ResolutionIssuesFrame = nil,
}
local State = GS.State
GS.UI = GS.UI or {}
local UIState = GS.UI

GS.ConflictAddons = GS.ConflictAddons or {
	"GearScore",
	"GearScoreLite",
	"GearScoreLite_Reborn",
	"GearScoreLiteReborn",
	"GearScoreLite-Reborn",
}
local GS_ConflictAddons = GS.ConflictAddons

GS.StatKeys = GS.StatKeys or {
	ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_STAMINA_SHORT = "STA",
	ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI", ITEM_MOD_ATTACK_POWER_SHORT = "AP",
	ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP", ITEM_MOD_SPELL_POWER_SHORT = "SP", ITEM_MOD_HIT_RATING_SHORT = "HIT",
	ITEM_MOD_CRIT_RATING_SHORT = "CRIT", ITEM_MOD_HASTE_RATING_SHORT = "HASTE", ITEM_MOD_RESILIENCE_RATING_SHORT = "RESILIENCE",
	ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ARP", ITEM_MOD_EXPERTISE_RATING_SHORT = "EXPERTISE",
	ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEFENSE", ITEM_MOD_DODGE_RATING_SHORT = "DODGE", ITEM_MOD_PARRY_RATING_SHORT = "PARRY",
	ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK", ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVALUE", ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
}
local GS_STAT_KEYS = GS.StatKeys

GS.StatDisplayKeys = GS.StatDisplayKeys or {
	RESILIENCE = "RESIL",
	EXPERTISE = "EXP",
	DEFENSE = "DEF",
	BLOCKVALUE = "BV",
}
local GS_STAT_DISPLAY_KEYS = GS.StatDisplayKeys

GS.ItemSlots = GS.ItemSlots or {
	INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
	INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11,
	INVTYPE_TRINKET = 13, INVTYPE_CLOAK = 15, INVTYPE_WEAPON = 16, INVTYPE_SHIELD = 17, INVTYPE_2HWEAPON = 16,
	INVTYPE_WEAPONMAINHAND = 16, INVTYPE_WEAPONOFFHAND = 17, INVTYPE_HOLDABLE = 17, INVTYPE_RANGED = 18,
	INVTYPE_THROWN = 18, INVTYPE_RANGEDRIGHT = 18, INVTYPE_RELIC = 18,
}
local GS_ITEM_SLOTS = GS.ItemSlots

local GS_SCAN_TEXT = C.SCAN_TEXT
local GS_MOUSEOVER_INSPECT_DELAY = C.MOUSEOVER_INSPECT_DELAY
local GS_INSPECT_THROTTLE = C.INSPECT_THROTTLE
local GS_RECENT_WINDOW = C.RECENT_WINDOW
local GS_ACTIVE_TIMEOUT = C.ACTIVE_TIMEOUT
local GS_SCAN_TIMEOUT = C.SCAN_TIMEOUT
local GS_CACHE_TTL = C.CACHE_TTL
local GS_FRESH_TTL = C.FRESH_TTL
local GS_READY_DELAY = C.READY_DELAY
local GS_READY_RETRY_LIMIT = C.READY_RETRY_LIMIT
local GS_MIN_INSPECT_ITEMS = C.MIN_INSPECT_ITEMS
local GS_FORCE_POLL_DELAY = C.FORCE_POLL_DELAY
local GS_TALENT_SPEC_WAIT = C.TALENT_SPEC_WAIT
local GS_GEM_SCALE = C.GEM_SCALE
local GS_ENCHANT_SCALE = C.ENCHANT_SCALE
local GS_PVE_RESILIENCE_RATE = C.PVE_RESILIENCE_RATE
local GS_PVP_RESILIENCE_RATE = C.PVP_RESILIENCE_RATE
local GS_PVE_RESILIENCE_FLOOR = C.PVE_RESILIENCE_FLOOR
local GS_PVP_RESILIENCE_CAP = C.PVP_RESILIENCE_CAP
local GS_GS2_STAT_SCALE = C.GS2_STAT_SCALE
local GS_CAP_BONUS_ANCHOR_LOW_GS2 = C.CAP_BONUS_ANCHOR_LOW_GS2
local GS_CAP_BONUS_ANCHOR_HIGH_GS2 = C.CAP_BONUS_ANCHOR_HIGH_GS2
local GS_CAP_BONUS_ANCHOR_LOW_BONUS = C.CAP_BONUS_ANCHOR_LOW_BONUS
local GS_CAP_BONUS_ANCHOR_HIGH_BONUS = C.CAP_BONUS_ANCHOR_HIGH_BONUS
local GS_CAP_BONUS_MIN = C.CAP_BONUS_MIN
local GS_CAP_BONUS_MAX = C.CAP_BONUS_MAX
local GS_CAP_BUFF_MARKER = C.CAP_BUFF_MARKER
local GS_ITEM_CACHE_MAX = C.ITEM_CACHE_MAX
local GS_ITEM_CACHE_TRIM_TO = C.ITEM_CACHE_TRIM_TO
local GS_PARSED_LINK_CACHE_MAX = C.PARSED_LINK_CACHE_MAX
local GS_PARSED_LINK_CACHE_TRIM_TO = C.PARSED_LINK_CACHE_TRIM_TO
local GS_InspectQueue = State.InspectQueue
local GS_InspectCache = State.InspectCache
local GS_ItemCache = State.ItemCache
local GS_ParsedLinkCache = State.ParsedLinkCache
local GS_InspectState = State.InspectState
local GS_ExplainState = State.ExplainState
local GS_TooltipInventoryContext = State.TooltipInventoryContext
local GS_ResolutionIssues = State.ResolutionIssues
local GS_ResolutionIssueKeys = State.ResolutionIssueKeys

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
	if specKey == "BEASTMASTERY" then
		return "Beast Mastery"
	end
	if specKey == "MAGE_FROST" then
		return "Frost"
	end
	if specKey == "DRUID_RESTORATION" then
		return "Restoration"
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
	if GS_ResolutionIssueKeys[key] then
		return
	end
	GS_ResolutionIssueKeys[key] = true
	GS_ResolutionIssues[#GS_ResolutionIssues + 1] = issue
	State.ResolutionIssuesVersion = (State.ResolutionIssuesVersion or 0) + 1
end

function GS_BuildResolutionIssueReport()
	local lines = {
		"GearScore2 unresolved data report",
		"Entries: " .. tostring(#GS_ResolutionIssues),
		"",
	}
	for index = 1, #GS_ResolutionIssues do
		local issue = GS_ResolutionIssues[index]
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
	return GS_STAT_DISPLAY_KEYS[statKey] or statKey
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

function GS_FindConflictingAddon(loadedAddonName)
	local loadedMap = {}
	if loadedAddonName then
		loadedMap[loadedAddonName] = true
	end
	if IsAddOnLoaded then
		for index = 1, #GS_ConflictAddons do
			local addonName = GS_ConflictAddons[index]
			if addonName ~= "GearScore2" and IsAddOnLoaded(addonName) then
				loadedMap[addonName] = true
			end
		end
	end
	for index = 1, #GS_ConflictAddons do
		local addonName = GS_ConflictAddons[index]
		if loadedMap[addonName] then
			return addonName
		end
	end
end

function GS_HasConflict()
	return State.RuntimeDisabledByConflict
end

function GS_EnableConflictMode(conflictName)
	State.RuntimeDisabledByConflict = true
	State.ConflictingAddonName = conflictName
	if not State.ConflictWarningShown and DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff5555GearScore2|r disabled its GearScore-compatible hooks because it detected a conflicting addon: |cffffff00" .. tostring(conflictName or "GearScore family") .. "|r. Use only one GearScore-family addon at a time.")
		State.ConflictWarningShown = true
	end
	if not State.ConflictPopupShown and StaticPopup_Show then
		StaticPopup_Show("GS2_CONFLICT_ADDON", tostring(conflictName or "Unknown addon"), nil, conflictName)
		State.ConflictPopupShown = true
	end
end

StaticPopupDialogs["GS2_CONFLICT_ADDON"] = {
	text = "GearScore2 detected a conflict with addon:\n\n%s\n\nDo you want to disable it and reload the UI?",
	button1 = "Disable and Reload",
	button2 = "Keep Both",
	OnAccept = function(self, conflictName)
		if conflictName and DisableAddOn then
			DisableAddOn(conflictName)
		end
		if ReloadUI then
			ReloadUI()
		end
	end,
	OnCancel = function()
		return
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = STATICPOPUP_NUMDIALOGS,
}

function GS_InstallCompatibilityAliases()
	if GS_HasConflict() then
		return
	end
	_G.GearScore_GetQuality = GS2_GetQuality
	_G.GearScore_GetItemScore = GS2_GetItemScore
	_G.GearScore_GetScore = GS2_GetScore
	_G.GearScore_SetDetails = GS2_SetDetails
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

UIState.TickerFrame = UIState.TickerFrame or CreateFrame("Frame")
UIState.TickerFrame:SetScript("OnUpdate", function()
	if GS_ProcessInspectQueue then
		GS_ProcessInspectQueue()
	end
end)

UIState.MainFrame = UIState.MainFrame or CreateFrame("Frame", "GearScore2Frame", UIParent)
UIState.MainFrame:SetScript("OnEvent", function(_, event, ...)
	if GS_OnEvent then
		GS_OnEvent(_, event, ...)
	end
end)
