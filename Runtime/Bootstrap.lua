-------------------------------------------------------------------------------
--                              GearScore2 Core                              --
-------------------------------------------------------------------------------

local GS = _G.GS2 or {}
_G.GS2 = GS

GS.Settings = GS2_Settings or GS.Settings or GS_Settings
GS_Settings = GS.Settings

GS.Data = GS.Data or {}
GS.Data.Tables = GS.Data.Tables or {}
GS.Data.Enchants = GS.Data.Enchants or {}
GS.Data.Gems = GS.Data.Gems or {}

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
	OFFSPEC_MIN_RATIO = 0.05,
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

GS.StatKeys = GS.StatKeys or {
	ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_STAMINA_SHORT = "STA",
	ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI", ITEM_MOD_ATTACK_POWER_SHORT = "AP",
	ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP", ITEM_MOD_SPELL_POWER_SHORT = "SP", ITEM_MOD_HIT_RATING_SHORT = "HIT",
	ITEM_MOD_CRIT_RATING_SHORT = "CRIT", ITEM_MOD_HASTE_RATING_SHORT = "HASTE", ITEM_MOD_RESILIENCE_RATING_SHORT = "RESILIENCE",
	ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ARP", ITEM_MOD_EXPERTISE_RATING_SHORT = "EXPERTISE",
	ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEFENSE", ITEM_MOD_DODGE_RATING_SHORT = "DODGE", ITEM_MOD_PARRY_RATING_SHORT = "PARRY",
	ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK", ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVALUE", ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
}

GS.StatDisplayKeys = GS.StatDisplayKeys or {
	RESILIENCE = "RESIL",
	EXPERTISE = "EXP",
	DEFENSE = "DEF",
	BLOCKVALUE = "BV",
}

GS.ItemSlots = GS.ItemSlots or {
	INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
	INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11,
	INVTYPE_TRINKET = 13, INVTYPE_CLOAK = 15, INVTYPE_WEAPON = 16, INVTYPE_SHIELD = 17, INVTYPE_2HWEAPON = 16,
	INVTYPE_WEAPONMAINHAND = 16, INVTYPE_WEAPONOFFHAND = 17, INVTYPE_HOLDABLE = 17, INVTYPE_RANGED = 18,
	INVTYPE_THROWN = 18, INVTYPE_RANGEDRIGHT = 18, INVTYPE_RELIC = 18,
}

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
