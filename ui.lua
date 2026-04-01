-------------------------------------------------------------------------------
--                               GearScore2 UI                                --
-------------------------------------------------------------------------------

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
	if GS_PlayerIsInCombat then return end
	local record = GS_GetRecord("player")
	if not record then return end
	local r, g, b = GS2_GetQuality(record.gs2)
	PersonalGearScore:SetText(tostring(record.gs2)) PersonalGearScore:SetTextColor(r, g, b, 1)
	LegacyGearScoreText:SetText(tostring(record.legacy)) LegacyGearScoreText:SetTextColor(0.8, 0.8, 0.8, 1)
	PvPGearScoreText:SetText(tostring(record.pvp)) PvPGearScoreText:SetTextColor(0.95, 0.55, 0.25, 1)
	CapSummaryText:SetText(record.capBreakdown and record.capBreakdown.summary or "")
	CapSummaryText:SetTextColor(0.72, 0.88, 1, 1)
end

function GS_MANSET(command)
	command = strlower(command or "")
	if command == "" or command == "options" or command == "option" or command == "help" then for i, v in ipairs(GS_CommandList) do print(v) end return end
	if command == "interface" then if GS_OpenInterfaceOptionsCategory then GS_OpenInterfaceOptionsCategory() end return end
	if command == "settings" then if GS_ToggleOptionsPanel then GS_ToggleOptionsPanel() end return end
	if command == "show" or command == "player" then GS_Settings["Player"] = GS_ShowSwitch[GS_Settings["Player"]] print((GS_Settings["Player"] == 1 or GS_Settings["Player"] == 2) and "Player Scores: On" or "Player Scores: Off") return end
	if command == "item" then GS_Settings["Item"] = GS_ItemSwitch[GS_Settings["Item"]] print((GS_Settings["Item"] == 1 or GS_Settings["Item"] == 3) and "Item Scores: On" or "Item Scores: Off") return end
	if command == "level" then GS_Settings["Level"] = GS_Settings["Level"] * -1 print(GS_Settings["Level"] == 1 and "Item Levels: On" or "Item Levels: Off") return end
	if command == "debuginspect" then GS_DebugInspectEnabled = not GS_DebugInspectEnabled print("GS2 Inspect Debug: " .. (GS_DebugInspectEnabled and "On" or "Off")) return end
	print("GearScore2: Unknown command. Type '/gs2' for a list of options")
end

function GS_OnEvent(_, event, ...)
	if event == "PLAYER_REGEN_ENABLED" then GS_PlayerIsInCombat = false return end
	if event == "PLAYER_REGEN_DISABLED" then GS_PlayerIsInCombat = true return end
	if event == "PLAYER_EQUIPMENT_CHANGED" then GS_InspectCache[UnitGUID("player")] = nil GS_UpdatePaperDoll() return end
	if event == "UNIT_INVENTORY_CHANGED" then local unit = ... if unit and UnitGUID(unit) then GS_InspectCache[UnitGUID(unit)] = nil end return end
	if event == "UNIT_AURA" then local unit = ... if unit and UnitGUID(unit) then GS_InspectCache[UnitGUID(unit)] = nil if UnitIsUnit(unit, "player") then GS_UpdatePaperDoll() end end return end
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
			GS2_Settings = GS_Settings or GS_DefaultSettings
		end
		GS_Settings = GS2_Settings
		if not GS_Data then GS_Data = {} end
		if not GS_Data[GetRealmName()] then GS_Data[GetRealmName()] = { ["Players"] = {} } end
		for key, value in pairs(GS_DefaultSettings) do if GS2_Settings[key] == nil then GS2_Settings[key] = value end end
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

GS_ExplainTooltip = CreateFrame("GameTooltip", "GS2ExplainTooltip", UIParent, "GameTooltipTemplate")
GS_ExplainTooltip:SetFrameStrata("TOOLTIP")
GS_ExplainTooltip:SetClampedToScreen(true)
GS_ExplainTooltip:EnableMouse(false)
GS_ExplainTooltip:SetOwner(UIParent, "ANCHOR_NONE")
GS_ExplainTooltip:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -220)
GS_ExplainTooltip:SetScale(1)

GameTooltip:HookScript("OnTooltipSetUnit", GS2_HookSetUnit)
GameTooltip:HookScript("OnTooltipSetItem", GS2_HookSetItem)
ShoppingTooltip1:HookScript("OnTooltipSetItem", GS2_HookCompareItem)
ShoppingTooltip2:HookScript("OnTooltipSetItem", GS2_HookCompareItem2)
ItemRefTooltip:HookScript("OnTooltipSetItem", GS2_HookRefItem)
PaperDollFrame:HookScript("OnShow", GS_UpdatePaperDoll)

PaperDollFrame:CreateFontString("PersonalGearScore")
PaperDollFrame:CreateFontString("GearScore2Label")
PaperDollFrame:CreateFontString("LegacyGearScoreText")
PaperDollFrame:CreateFontString("LegacyGearScoreLabel")
PaperDollFrame:CreateFontString("PvPGearScoreText")
PaperDollFrame:CreateFontString("PvPGearScoreLabel")
PaperDollFrame:CreateFontString("CapSummaryText")

PersonalGearScore:SetFont("Fonts\\FRIZQT__.TTF", 12) PersonalGearScore:SetText("0") PersonalGearScore:SetPoint("BOTTOMLEFT", PaperDollFrame, "TOPLEFT", 72, -248) PersonalGearScore:Show()
GearScore2Label:SetFont("Fonts\\FRIZQT__.TTF", 12) GearScore2Label:SetText("GearScore2") GearScore2Label:SetPoint("BOTTOMLEFT", PaperDollFrame, "TOPLEFT", 72, -260) GearScore2Label:Show()
LegacyGearScoreText:SetFont("Fonts\\FRIZQT__.TTF", 12) LegacyGearScoreText:SetText("0") LegacyGearScoreText:SetPoint("BOTTOMLEFT", PaperDollFrame, "TOPLEFT", 152, -248) LegacyGearScoreText:Show()
LegacyGearScoreLabel:SetFont("Fonts\\FRIZQT__.TTF", 12) LegacyGearScoreLabel:SetText("Legacy") LegacyGearScoreLabel:SetPoint("BOTTOMLEFT", PaperDollFrame, "TOPLEFT", 152, -260) LegacyGearScoreLabel:Show()
PvPGearScoreText:SetFont("Fonts\\FRIZQT__.TTF", 12) PvPGearScoreText:SetText("0") PvPGearScoreText:SetPoint("BOTTOMLEFT", PaperDollFrame, "TOPLEFT", 232, -248) PvPGearScoreText:Show()
PvPGearScoreLabel:SetFont("Fonts\\FRIZQT__.TTF", 12) PvPGearScoreLabel:SetText("PvP") PvPGearScoreLabel:SetPoint("BOTTOMLEFT", PaperDollFrame, "TOPLEFT", 232, -260) PvPGearScoreLabel:Show()
CapSummaryText:SetFont("Fonts\\FRIZQT__.TTF", 11) CapSummaryText:SetText("") CapSummaryText:SetPoint("TOPLEFT", PaperDollFrame, "TOPLEFT", 72, -62) CapSummaryText:SetWidth(220) CapSummaryText:SetJustifyH("LEFT") CapSummaryText:Show()

GS_OriginalSetInventoryItem = GameTooltip.SetInventoryItem
GameTooltip.SetInventoryItem = GS2_OnEnter

SlashCmdList["GS2SCRIPT"] = GS_MANSET
SLASH_GS2SCRIPT1 = "/gs2"
SLASH_GS2SCRIPT2 = "/gearscore2"
SLASH_GS2SCRIPT3 = "/gset"
