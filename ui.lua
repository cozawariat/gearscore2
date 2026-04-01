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
	GS_GetRecord("player")
end

function GS_MANSET(command)
	command = strlower(command or "")
	if command == "" or command == "settings" then if GS_ToggleOptionsPanel then GS_ToggleOptionsPanel() end return end
	if command == "options" or command == "option" or command == "help" then for i, v in ipairs(GS_CommandList) do print(v) end return end
	if command == "debuginspect" then GS_DebugInspectEnabled = not GS_DebugInspectEnabled print("GS2 Inspect Debug: " .. (GS_DebugInspectEnabled and "On" or "Off")) return end
	print("GearScore2: Unknown command. Use '/gs2 settings' or '/gs2 debuginspect'.")
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

GS_OriginalSetInventoryItem = GameTooltip.SetInventoryItem
GameTooltip.SetInventoryItem = GS2_OnEnter

SlashCmdList["GS2SCRIPT"] = GS_MANSET
SLASH_GS2SCRIPT1 = "/gs2"
SLASH_GS2SCRIPT2 = "/gearscore2"
SLASH_GS2SCRIPT3 = "/gset"
