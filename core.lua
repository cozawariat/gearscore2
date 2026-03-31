-------------------------------------------------------------------------------
--                             GearScoreAI Core                              --
-------------------------------------------------------------------------------

GS_Settings = GS2_Settings or GS_Settings

GS_PlayerIsInCombat = false
GS_SCAN_TEXT = "|cffaaaaaaScanning...|r"
GS_INSPECT_THROTTLE = 0.35
GS_RECENT_WINDOW = 1.5
GS_ACTIVE_TIMEOUT = 3.0
GS_SCAN_TIMEOUT = 3.0
GS_CACHE_TTL = 180
GS_FRESH_TTL = 15
GS_READY_DELAY = 0.15
GS_READY_RETRY_LIMIT = 4
GS_MIN_INSPECT_ITEMS = 8
GS_FORCE_POLL_DELAY = 0.20
GS_GEM_SCALE = 0.35
GS_ENCHANT_SCALE = 0.35
GS_PVE_RESILIENCE_RATE = 0.0015
GS_PVP_RESILIENCE_RATE = 0.0020
GS_PVE_RESILIENCE_FLOOR = 0.70
GS_PVP_RESILIENCE_CAP = 1.35
GS_GS2_STAT_SCALE = 0.12

GS_InspectQueue = {}
GS_InspectCache = {}
GS_ItemCache = {}
GS_ParsedLinkCache = {}
GS_InspectState = { active = nil, lastInspectAt = 0, queued = {}, recent = {}, lastConfirmedSpecByGuid = {} }
GS_ExplainState = { owner = nil, itemLink = nil, itemSlot = nil }
GS_TooltipInventoryContext = { unit = nil, slot = nil, guid = nil }
GS_DebugInspectEnabled = false

GS_STAT_KEYS = {
	ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_STAMINA_SHORT = "STA",
	ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI", ITEM_MOD_ATTACK_POWER_SHORT = "AP",
	ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP", ITEM_MOD_SPELL_POWER_SHORT = "SP", ITEM_MOD_HIT_RATING_SHORT = "HIT",
	ITEM_MOD_CRIT_RATING_SHORT = "CRIT", ITEM_MOD_HASTE_RATING_SHORT = "HASTE", ITEM_MOD_RESILIENCE_RATING_SHORT = "RESILIENCE",
	ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ARP", ITEM_MOD_EXPERTISE_RATING_SHORT = "EXPERTISE",
	ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEFENSE", ITEM_MOD_DODGE_RATING_SHORT = "DODGE", ITEM_MOD_PARRY_RATING_SHORT = "PARRY",
	ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK", ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVALUE", ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
}

GS_ITEM_SLOTS = {
	INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
	INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11,
	INVTYPE_TRINKET = 13, INVTYPE_CLOAK = 15, INVTYPE_WEAPON = 16, INVTYPE_SHIELD = 17, INVTYPE_2HWEAPON = 16,
	INVTYPE_WEAPONMAINHAND = 16, INVTYPE_WEAPONOFFHAND = 17, INVTYPE_HOLDABLE = 17, INVTYPE_RANGED = 18,
	INVTYPE_THROWN = 18, INVTYPE_RANGEDRIGHT = 18, INVTYPE_RELIC = 18,
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
	if not GS_DebugInspectEnabled then
		return
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99GS2 Debug|r " .. tostring(message))
end

function GS_AppendExplainLine(lines, text)
	lines[#lines + 1] = text
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

GS_TickerFrame = CreateFrame("Frame")
GS_TickerFrame:SetScript("OnUpdate", function()
	if GS_ProcessInspectQueue then
		GS_ProcessInspectQueue()
	end
end)

GS_MainFrame = CreateFrame("Frame", "GearScore", UIParent)
GS_MainFrame:SetScript("OnEvent", function(_, event, ...)
	if GS_OnEvent then
		GS_OnEvent(_, event, ...)
	end
end)
