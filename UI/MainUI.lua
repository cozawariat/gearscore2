-------------------------------------------------------------------------------
--                               GearScore2 UI                                --
-------------------------------------------------------------------------------

local GS = _G.GS2
local State = GS and GS.State or {}
local UIState = GS and GS.UI or {}
local C = GS and GS.Constants or {}
local Data = GS and GS.Data or {}
local Tables = Data.Tables or {}
local GS_InspectCache = State.InspectCache or {}
local GS_InspectState = State.InspectState or { active = nil, lastInspectAt = 0, queued = {}, recent = {}, hoverGuid = nil, hoverStartedAt = 0 }
local GS_TooltipInventoryContext = State.TooltipInventoryContext or { unit = nil, slot = nil, guid = nil }
local GS_MainFrame = UIState.MainFrame
local GS_SCAN_TEXT = C.SCAN_TEXT or "|cffaaaaaaScanning...|r"
local GS_READY_DELAY = C.READY_DELAY or 0.15
local GS_COMMAND_LIST = Tables.CommandList or {}
local GS_DEFAULT_SETTINGS = Tables.DefaultSettings or {}

function GS2_OnEnter(frame, itemSlot, argument)
	local unit, slot = itemSlot, argument
	if type(unit) == "string" and type(slot) == "number" then
		GS_TooltipInventoryContext.unit = unit
		GS_TooltipInventoryContext.slot = slot
		GS_TooltipInventoryContext.guid = UnitGUID(unit)
	else
		GS_TooltipInventoryContext.unit = nil
		GS_TooltipInventoryContext.slot = nil
		GS_TooltipInventoryContext.guid = nil
	end
	return GS_OriginalSetInventoryItem(frame, itemSlot, argument)
end

function GS_UpdatePaperDoll()
	if State.PlayerIsInCombat then return end
	GS_GetRecord("player")
end

local function GS_CreateResolutionIssuesFrame()
	if State.ResolutionIssuesFrame then
		return State.ResolutionIssuesFrame
	end
	local frame = CreateFrame("Frame", "GS2ResolutionIssuesFrame", UIParent)
	frame:SetWidth(760)
	frame:SetHeight(460)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 }
	})

	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)
	title:SetText("GearScore2 Unresolved Data Report")

	local subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	subtitle:SetWidth(720)
	subtitle:SetJustifyH("LEFT")
	subtitle:SetText("Copy these entries when GS2 withholds a result because gem/enchant stat data could not be resolved safely.")

	local scrollFrame = CreateFrame("ScrollFrame", "GS2ResolutionIssuesScrollFrame", frame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -62)
	scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 52)

	local editBox = CreateFrame("EditBox", "GS2ResolutionIssuesEditBox", scrollFrame)
	editBox:SetMultiLine(true)
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetAutoFocus(false)
	editBox:SetWidth(690)
	editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
	editBox:SetScript("OnTextChanged", function(self)
		scrollFrame:UpdateScrollChildRect()
	end)
	editBox:SetScript("OnCursorChanged", function(self, x, y, w, h)
		scrollFrame:SetVerticalScroll(y)
	end)
	scrollFrame:SetScrollChild(editBox)
	frame.editBox = editBox

	local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	closeButton:SetWidth(100)
	closeButton:SetHeight(24)
	closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
	closeButton:SetText("Close")
	closeButton:SetScript("OnClick", function() frame:Hide() end)

	local refreshButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	refreshButton:SetWidth(100)
	refreshButton:SetHeight(24)
	refreshButton:SetPoint("RIGHT", closeButton, "LEFT", -8, 0)
	refreshButton:SetText("Refresh")
	refreshButton:SetScript("OnClick", function()
		local report = GS_BuildResolutionIssueReport()
		editBox:SetText(report)
		editBox:HighlightText(0, 0)
	end)

	local selectAllButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	selectAllButton:SetWidth(100)
	selectAllButton:SetHeight(24)
	selectAllButton:SetPoint("RIGHT", refreshButton, "LEFT", -8, 0)
	selectAllButton:SetText("Select All")
	selectAllButton:SetScript("OnClick", function()
		editBox:SetFocus()
		editBox:HighlightText()
	end)

	frame:Hide()
	State.ResolutionIssuesFrame = frame
	return frame
end

function GS_ShowResolutionIssuesFrame()
	local frame = GS_CreateResolutionIssuesFrame()
	local report = GS_BuildResolutionIssueReport()
	frame.editBox:SetText(report)
	frame.editBox:SetFocus()
	frame.editBox:HighlightText()
	frame:Show()
end

local function GS_ParseDebugSlotToken(token)
	token = strlower(tostring(token or ""))
	if token == "shoulder" or token == "shoulders" then return 3 end
	if token == "head" then return 1 end
	if token == "chest" then return 5 end
	if token == "hands" or token == "gloves" then return 10 end
	if token == "legs" then return 7 end
	if token == "wrist" or token == "bracers" then return 9 end
	if token == "cloak" or token == "back" then return 15 end
	if token == "mainhand" or token == "mh" or token == "weapon" then return 16 end
	if token == "offhand" or token == "oh" then return 17 end
	if token == "ranged" then return 18 end
	local numeric = tonumber(token)
	if numeric and numeric >= 1 and numeric <= 18 then
		return numeric
	end
end

local function GS_GetDebugUnit()
	if InspectFrame and InspectFrame.unit and UnitExists(InspectFrame.unit) then
		return InspectFrame.unit
	end
	local _, tooltipUnit = GS_GetTooltipUnit()
	if tooltipUnit and UnitExists(tooltipUnit) then
		return tooltipUnit
	end
	if UnitExists("target") and UnitIsPlayer("target") then
		return "target"
	end
	if UnitExists("mouseover") and UnitIsPlayer("mouseover") then
		return "mouseover"
	end
	return "player"
end

local function GS_PrintExplainParts(prefix, parts)
	if not parts then
		return
	end
	for index = 1, #parts do
		local part = parts[index]
		print(prefix .. " " .. tostring(part.label) .. " => " .. tostring(part.delta) .. " [" .. tostring(part.formula) .. "]")
	end
end

local GS_DEBUG_SLOT_LABELS = {
	[1] = "Head",
	[2] = "Neck",
	[3] = "Shoulder",
	[5] = "Chest",
	[6] = "Waist",
	[7] = "Legs",
	[8] = "Feet",
	[9] = "Wrist",
	[10] = "Hands",
	[11] = "Finger1",
	[12] = "Finger2",
	[13] = "Trinket1",
	[14] = "Trinket2",
	[15] = "Back",
	[16] = "MainHand",
	[17] = "OffHand",
	[18] = "Ranged",
}

local function GS_GetDebugSlotLabel(slotId)
	return GS_DEBUG_SLOT_LABELS[slotId] or ("Slot" .. tostring(slotId or "?"))
end

local function GS_GetSortedDetailSlots(detailLinks)
	local slotIds = {}
	for slotId in pairs(detailLinks or {}) do
		slotIds[#slotIds + 1] = slotId
	end
	table.sort(slotIds)
	return slotIds
end

function GS_DebugSlotScore(slotToken)
	local slotId = GS_ParseDebugSlotToken(slotToken)
	if not slotId then
		print("GearScore2: Use '/gs2 debugslot 3' or '/gs2 debugslot shoulder'.")
		return
	end
	local unit = GS_GetDebugUnit()
	if not unit or not UnitExists(unit) then
		print("GearScore2: No valid unit to debug.")
		return
	end
	local record = GS_GetRecord(unit) or GS_GetScanRecord(UnitGUID(unit))
	if not record then
		if not UnitIsUnit(unit, "player") then
			GS_QueueInspect(unit)
		end
		print("GearScore2: No cached record yet for " .. tostring(UnitName(unit) or unit) .. ". Inspect the character and retry in a moment.")
		return
	end
	if not record.specKey then
		if not UnitIsUnit(unit, "player") then
			GS_QueueInspect(unit)
		end
		print("GearScore2: Spec/item scan not ready for " .. tostring(UnitName(unit) or unit) .. ". Current state: " .. tostring(record.scanStatusText or "unknown"))
		return
	end
	local itemLink = record.detailLinks and record.detailLinks[slotId] or GetInventoryItemLink(unit, slotId)
	if not itemLink then
		print("GearScore2: No item found in slot " .. tostring(slotId) .. " for " .. tostring(UnitName(unit) or unit) .. ".")
		return
	end
	local item = GS_GetItemData(itemLink)
	if not item then
		print("GearScore2: Could not build item data for slot " .. tostring(slotId) .. ".")
		return
	end
	local gs2, pvp, explain = GS_ScoreItem(item, record.classToken or select(2, UnitClass(unit)), record.specKey, true)
	local enchantInfo = GS_GetEnchantInfo(item)
	print("GS2 Debug Slot " .. tostring(slotId) .. " | Unit: " .. tostring(UnitName(unit) or unit) .. " | Spec: " .. tostring(record.specLabel or GS_GetSpecLabel(record.specKey)))
	if record.offSpec then
		print("GS2 Debug Inspect Context: off-spec=true | betterFit=" .. tostring(record.offSpecBetterSpecLabel or record.offSpecBetterSpecKey or "?") .. " | betterFitGS2=" .. tostring(record.offSpecBetterGs2 or "?") .. " | reason=" .. tostring(record.offSpecReason or "unknown"))
	end
	print("GS2 Debug Item: " .. tostring(item.name) .. " | enchantId=" .. tostring(item.enchantId or 0) .. " | hasEnchant=" .. tostring(item.hasEnchant))
	if enchantInfo then
		print("GS2 Debug Enchant: kind=" .. tostring(enchantInfo.kind) .. " | label=" .. tostring(enchantInfo.label or "?"))
		if enchantInfo.stats then
			for stat, value in pairs(enchantInfo.stats) do
				print("GS2 Debug Enchant Stat: " .. tostring(stat) .. "=" .. tostring(value))
			end
		end
	else
		print("GS2 Debug Enchant: none/unknown")
	end
	print("GS2 Debug Result: Legacy=" .. tostring(item.legacyBase) .. " | GS2=" .. tostring(gs2) .. " | PvP=" .. tostring(pvp))
	if explain then
		print("GS2 Debug PvE base before multiplier: " .. tostring(explain.pve.preMultiplier or explain.pve.base or 0) .. " | multiplier=" .. tostring(explain.pve.multiplier or 1) .. " | final=" .. tostring(explain.pve.final or gs2))
		GS_PrintExplainParts("GS2 Debug PvE Part:", explain.pve.parts)
		if explain.pve.flags and #explain.pve.flags > 0 then
			for index = 1, #explain.pve.flags do
				print("GS2 Debug PvE Flag: " .. tostring(explain.pve.flags[index]))
			end
		end
		if explain.flags and #explain.flags > 0 then
			for index = 1, #explain.flags do
				print("GS2 Debug Flag: " .. tostring(explain.flags[index]))
			end
		end
	end
end

function GS_DebugCharacterScore()
	local unit = GS_GetDebugUnit()
	if not unit or not UnitExists(unit) then
		print("GearScore2: No valid unit to debug.")
		return
	end
	local record = GS_GetRecord(unit) or GS_GetScanRecord(UnitGUID(unit))
	if not record then
		if not UnitIsUnit(unit, "player") then
			GS_QueueInspect(unit)
		end
		print("GearScore2: No cached record yet for " .. tostring(UnitName(unit) or unit) .. ". Inspect the character and retry in a moment.")
		return
	end
	if not record.specKey then
		if not UnitIsUnit(unit, "player") then
			GS_QueueInspect(unit)
		end
		print("GearScore2: Spec/item scan not ready for " .. tostring(UnitName(unit) or unit) .. ". Current state: " .. tostring(record.scanStatusText or "unknown"))
		return
	end

	local unitName = UnitName(unit) or unit
	local classToken = record.classToken or select(2, UnitClass(unit))
	local slotIds = GS_GetSortedDetailSlots(record.detailLinks)
	local slotGs2Total, slotLegacyTotal, slotPvpTotal = 0, 0, 0
	local unresolvedSlots = 0

	print("GS2 Debug Character | Unit: " .. tostring(unitName) .. " | Spec: " .. tostring(record.specLabel or GS_GetSpecLabel(record.specKey)) .. " | source=" .. tostring(record.specSource or "unknown"))
	print("GS2 Debug Character Result: GS2=" .. tostring(record.gs2 or "nil") .. " | Legacy=" .. tostring(record.legacy or "nil") .. " | PvP=" .. tostring(record.pvp or "nil") .. " | Avg=" .. tostring(record.average or 0))

	if record.offSpec then
		print("GS2 Debug Character Offspec: true | betterFit=" .. tostring(record.offSpecBetterSpecLabel or record.offSpecBetterSpecKey or "?") .. " | betterFitGS2=" .. tostring(record.offSpecBetterGs2 or "?") .. " | reason=" .. tostring(record.offSpecReason or "unknown"))
	end

	if record.capBreakdown then
		print("GS2 Debug Character Caps: " .. tostring(record.capBreakdown.summary or "n/a") .. " | bonus=" .. tostring(record.capAdjustedGs2 or 0) .. " | progress=" .. GS_FormatNumber((record.capBreakdown.overallProgress or 0) * 100) .. "%")
	end

	for index = 1, #slotIds do
		local slotId = slotIds[index]
		local itemLink = record.detailLinks[slotId]
		local item = itemLink and GS_GetItemData(itemLink) or nil
		if item then
			local itemGs2, itemPvp = GS_ScoreItem(item, classToken, record.specKey)
			local label = GS_GetDebugSlotLabel(slotId)
			if itemGs2 == nil or itemPvp == nil then
				unresolvedSlots = unresolvedSlots + 1
				print("GS2 Debug Char Slot " .. tostring(slotId) .. " (" .. label .. "): " .. tostring(item.name) .. " | unresolved")
			else
				slotGs2Total = slotGs2Total + itemGs2
				slotLegacyTotal = slotLegacyTotal + (item.legacyBase or 0)
				slotPvpTotal = slotPvpTotal + itemPvp
				print(
					"GS2 Debug Char Slot " .. tostring(slotId) .. " (" .. label .. "): "
					.. tostring(item.name)
					.. " | GS2=" .. tostring(itemGs2)
					.. " | Legacy=" .. tostring(item.legacyBase or 0)
					.. " | PvP=" .. tostring(itemPvp)
					.. " | enchantId=" .. tostring(item.enchantId or 0)
					.. " | gems=" .. tostring(item.gemCount or 0)
				)
			end
		else
			unresolvedSlots = unresolvedSlots + 1
			print("GS2 Debug Char Slot " .. tostring(slotId) .. " (" .. GS_GetDebugSlotLabel(slotId) .. "): item data unresolved")
		end
	end

	print(
		"GS2 Debug Character Totals: slotGS2=" .. tostring(slotGs2Total)
		.. " | capBonus=" .. tostring(record.capAdjustedGs2 or 0)
		.. " | finalGS2=" .. tostring(record.gs2 or "nil")
		.. " | slotLegacy=" .. tostring(slotLegacyTotal)
		.. " | finalLegacy=" .. tostring(record.legacy or "nil")
		.. " | slotPvP=" .. tostring(slotPvpTotal)
		.. " | finalPvP=" .. tostring(record.pvp or "nil")
		.. " | unresolvedSlots=" .. tostring(unresolvedSlots)
	)
end

function GS_MANSET(command)
	local raw = command or ""
	local normalized = strlower(raw)
	local commandWord, argument = string.match(normalized, "^(%S+)%s*(.-)$")
	commandWord = commandWord or ""
	if commandWord == "" or commandWord == "settings" then if GS_ToggleOptionsPanel then GS_ToggleOptionsPanel() end return end
	if commandWord == "options" or commandWord == "option" or commandWord == "help" then
		for i, v in ipairs(GS_COMMAND_LIST) do print(v) end
		print("/gs2 debuginspect")
		print("/gs2 debugchar")
		print("/gs2 debugslot 3")
		print("/gs2 issues")
		return
	end
	if commandWord == "debuginspect" then State.DebugInspectEnabled = not State.DebugInspectEnabled print("GS2 Inspect Debug: " .. (State.DebugInspectEnabled and "On" or "Off")) return end
	if commandWord == "debugchar" then GS_DebugCharacterScore() return end
	if commandWord == "debugslot" then GS_DebugSlotScore(argument) return end
	if commandWord == "issues" then GS_ShowResolutionIssuesFrame() return end
	print("GearScore2: Unknown command. Use '/gs2 settings', '/gs2 debuginspect', '/gs2 debugchar', '/gs2 debugslot 3', or '/gs2 issues'.")
end

function GS_OnEvent(_, event, ...)
	if event == "PLAYER_REGEN_ENABLED" then State.PlayerIsInCombat = false return end
	if event == "PLAYER_REGEN_DISABLED" then State.PlayerIsInCombat = true return end
	if event == "PLAYER_EQUIPMENT_CHANGED" then GS_RemoveCacheEntry(GS_InspectCache, UnitGUID("player"), "InspectCacheCount") GS_UpdatePaperDoll() return end
	if event == "UNIT_INVENTORY_CHANGED" then local unit = ... if unit and UnitGUID(unit) then GS_RemoveCacheEntry(GS_InspectCache, UnitGUID(unit), "InspectCacheCount") end return end
	if event == "UNIT_AURA" then local unit = ... if unit and UnitGUID(unit) then GS_RemoveCacheEntry(GS_InspectCache, UnitGUID(unit), "InspectCacheCount") if UnitIsUnit(unit, "player") then GS_UpdatePaperDoll() end end return end
	if event == "MODIFIER_STATE_CHANGED" then
		local key, pressed = ...
		if key == "LCTRL" or key == "RCTRL" then
			if pressed == 1 then
				if GameTooltip:IsShown() then GS_TryShowExplainFromOwner(GameTooltip) end
				if ShoppingTooltip1:IsShown() then GS_TryShowExplainFromOwner(ShoppingTooltip1) end
				if ShoppingTooltip2:IsShown() then GS_TryShowExplainFromOwner(ShoppingTooltip2) end
				if ItemRefTooltip:IsShown() then GS_TryShowExplainFromOwner(ItemRefTooltip) end
			else
				GS_HideExplainTooltip()
			end
		end
		return
	end
	if event == "INSPECT_READY" then
		local guid = ...
		if GS_InspectState.active and GS_InspectState.active.guid == guid then
			GS_DebugInspect("INSPECT_READY guid=" .. tostring(guid))
			GS_InspectState.active.specResolvedAt = GetTime()
			GS_InspectState.active.readyAt = GetTime() + GS_READY_DELAY
			GS_InspectState.active.pollAt = GS_InspectState.active.readyAt
			GS_InspectState.active.readyRetries = 0
		end
		return
	end
	if event == "INSPECT_TALENT_READY" then
		local guid = ...
		if GS_InspectState.active and GS_InspectState.active.guid == guid then
			GS_DebugInspect("INSPECT_TALENT_READY guid=" .. tostring(guid))
			GS_InspectState.active.talentReady = true
			GS_InspectState.active.readyAt = GetTime() + GS_READY_DELAY
			GS_InspectState.active.pollAt = GS_InspectState.active.readyAt
			GS_InspectState.active.readyRetries = 0
		end
		return
	end
	if event == "ADDON_LOADED" then
		local addonName = ...
		local conflictingAddon = GS_FindConflictingAddon(addonName)
		if conflictingAddon then
			GS_EnableConflictMode(conflictingAddon)
		end
		if addonName ~= "GearScore2" then return end
		if not GS2_Settings then
			GS2_Settings = GS_Settings or GS_DEFAULT_SETTINGS
		end
		GS_Settings = GS2_Settings
		if GS then
			GS.Settings = GS_Settings
		end
		if not GS_Data then GS_Data = {} end
		if not GS_Data[GetRealmName()] then GS_Data[GetRealmName()] = { ["Players"] = {} } end
		for key, value in pairs(GS_DEFAULT_SETTINGS) do if GS2_Settings[key] == nil then GS2_Settings[key] = value end end
		GS2_Settings["IncludeEnchants"] = true
		if GS_InitializeSettings then
			GS_InitializeSettings()
		end
		GS_InstallCompatibilityAliases()
		GS_UpdatePaperDoll()
	end
end

GS_MainFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
GS_MainFrame:RegisterEvent("ADDON_LOADED")
GS_MainFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
GS_MainFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
GS_MainFrame:RegisterEvent("INSPECT_READY")
GS_MainFrame:RegisterEvent("INSPECT_TALENT_READY")
GS_MainFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
GS_MainFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
GS_MainFrame:RegisterEvent("UNIT_AURA")

GS_ExplainTooltip = UIState.ExplainTooltip or CreateFrame("GameTooltip", "GS2ExplainTooltip", UIParent, "GameTooltipTemplate")
UIState.ExplainTooltip = GS_ExplainTooltip
GS_ExplainTooltip:SetFrameStrata("TOOLTIP")
GS_ExplainTooltip:SetClampedToScreen(true)
GS_ExplainTooltip:EnableMouse(false)
GS_ExplainTooltip:SetOwner(UIParent, "ANCHOR_NONE")
GS_ExplainTooltip:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -220)
GS_ExplainTooltip:SetScale(1)
if GS_ApplyExplainTooltipSkin then
	GS_ApplyExplainTooltipSkin()
end

GameTooltip:HookScript("OnTooltipSetUnit", GS2_HookSetUnit)
GameTooltip:HookScript("OnTooltipSetItem", GS2_HookSetItem)
ShoppingTooltip1:HookScript("OnTooltipSetItem", GS2_HookCompareItem)
ShoppingTooltip2:HookScript("OnTooltipSetItem", GS2_HookCompareItem2)
ItemRefTooltip:HookScript("OnTooltipSetItem", GS2_HookRefItem)

GS_OriginalSetInventoryItem = State.OriginalSetInventoryItem or GameTooltip.SetInventoryItem
State.OriginalSetInventoryItem = GS_OriginalSetInventoryItem
GameTooltip.SetInventoryItem = GS2_OnEnter

SlashCmdList["GS2SCRIPT"] = GS_MANSET
SLASH_GS2SCRIPT1 = "/gs2"
SLASH_GS2SCRIPT2 = "/gearscore2"
SLASH_GS2SCRIPT3 = "/gset"
