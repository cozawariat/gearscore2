-------------------------------------------------------------------------------
--                     GearScore2 Compatibility / Conflict                    --
-------------------------------------------------------------------------------

local GS = _G.GS2
local State = GS and GS.State or {}

function GS_FindConflictingAddon(loadedAddonName)
	local loadedMap = {}
	if loadedAddonName then
		loadedMap[loadedAddonName] = true
	end
	if IsAddOnLoaded then
		for index = 1, #(GS.ConflictAddons or {}) do
			local addonName = GS.ConflictAddons[index]
			if addonName ~= "GearScore2" and IsAddOnLoaded(addonName) then
				loadedMap[addonName] = true
			end
		end
	end
	for index = 1, #(GS.ConflictAddons or {}) do
		local addonName = GS.ConflictAddons[index]
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
