-------------------------------------------------------------------------------
--                          GearScore2 Settings UI                            --
-------------------------------------------------------------------------------

GS_OptionsBindings = {}
GS_InterfaceOptionsPanel = nil
GS_MinimapButton = nil

GS_OptionsSections = {
	{
		title = "Character Tooltip",
		items = {
			{ key = "showCharacterGS2", label = "Show GearScore2" },
			{ key = "showCharacterLegacy", label = "Show Legacy GearScore" },
			{ key = "showCharacterPvp", label = "Show PvP GearScore" },
			{ key = "showCharacterAverage", label = "Show Average iLevel" },
			{ key = "showCharacterCapSummary", label = "Show cap summary" },
			{ key = "showCharacterCompare", label = "Show compare line" },
		},
	},
	{
		title = "Item Tooltip",
		items = {
			{ key = "showItemGS2", label = "Show GearScore2" },
			{ key = "showItemLegacy", label = "Show Legacy GearScore" },
			{ key = "showItemPvp", label = "Show PvP GearScore" },
			{ key = "showItemLevel", label = "Show item iLevel" },
		},
	},
	{
		title = "Explain Tooltip",
		items = {
			{ key = "enableExplainTooltip", label = "Enable explain tooltip on CTRL" },
			{ key = "showExplainHeader", label = "Show summary header" },
			{ key = "showExplainFlags", label = "Show flags" },
		},
	},
	{
		title = "Explain Tooltip - Legacy",
		items = {
			{ key = "showExplainLegacy", label = "Show legacy section" },
		},
	},
	{
		title = "Explain Tooltip - PvE",
		items = {
			{ key = "showExplainPveFormula", label = "Show PvE formula line" },
			{ key = "showExplainPveParts", label = "Show PvE parts list" },
			{ key = "showExplainPveTotals", label = "Show PvE totals and multiplier" },
			{ key = "showExplainTopPveStats", label = "Show top PvE stats" },
		},
	},
	{
		title = "Explain Tooltip - PvP",
		items = {
			{ key = "showExplainPvpFormula", label = "Show PvP formula line" },
			{ key = "showExplainPvpParts", label = "Show PvP parts list" },
			{ key = "showExplainPvpTotals", label = "Show PvP totals and multiplier" },
			{ key = "showExplainTopPvpStats", label = "Show top PvP stats" },
		},
	},
	{
		title = "Minimap Button",
		items = {
			{ key = "showMinimapButton", label = "Show minimap button" },
		},
	},
}

local function GS_CopyDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if target[key] == nil then
			target[key] = value
		end
	end
end

local function GS_RegisterSettingControl(key, control)
	if not GS_OptionsBindings[key] then
		GS_OptionsBindings[key] = {}
	end
	GS_OptionsBindings[key][#GS_OptionsBindings[key] + 1] = control
end

local function GS_RefreshTooltipFrame(tooltip)
	if not tooltip or not tooltip.IsShown or not tooltip:IsShown() then
		return
	end
	local _, itemLink = tooltip:GetItem()
	if itemLink then
		tooltip:SetHyperlink(itemLink)
		return
	end
	local _, unit = tooltip:GetUnit()
	if unit then
		tooltip:SetUnit(unit)
	end
end

function GS_RefreshVisibleTooltips()
	GS_RefreshTooltipFrame(GameTooltip)
	GS_RefreshTooltipFrame(ItemRefTooltip)
	GS_RefreshTooltipFrame(ShoppingTooltip1)
	GS_RefreshTooltipFrame(ShoppingTooltip2)
	if not GS_Settings or not GS_Settings["enableExplainTooltip"] then
		GS_HideExplainTooltip()
	elseif GS_ExplainState and GS_ExplainState.owner and GS_ExplainState.itemLink and GS_ExplainState.owner:IsShown() then
		GS_RenderExplainTooltip(GS_ExplainState.owner, GS_ExplainState.itemLink)
	end
end

local function GS_ApplyMinimapButtonPosition()
	if not GS_MinimapButton then
		return
	end
	local angle = tonumber(GS_Settings and GS_Settings["minimapAngle"]) or 225
	local radians = math.rad(angle)
	local radius = (Minimap:GetWidth() / 2) + 8
	GS_MinimapButton:ClearAllPoints()
	GS_MinimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

function GS_ApplyMinimapButtonVisibility()
	if not GS_MinimapButton or not GS_Settings then
		return
	end
	if GS_Settings["showMinimapButton"] then
		GS_MinimapButton:Show()
		GS_ApplyMinimapButtonPosition()
	else
		GS_MinimapButton:Hide()
	end
end

function GS_RefreshOptionsUI()
	if not GS_Settings then
		return
	end
	for key, controls in pairs(GS_OptionsBindings) do
		local enabled = GS_Settings[key] and true or false
		for index = 1, #controls do
			controls[index]:SetChecked(enabled and 1 or nil)
		end
	end
	GS_ApplyMinimapButtonVisibility()
end

local function GS_OnSettingChanged(key, enabled)
	GS_Settings[key] = enabled and true or false
	GS_RefreshOptionsUI()
	GS_UpdatePaperDoll()
	GS_RefreshVisibleTooltips()
end

local function GS_CreateCheckbox(parent, key, label, anchor, offsetY, offsetX, textWidth)
	local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", offsetX or 0, offsetY)
	checkbox:SetScale(0.85)
	checkbox.text = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 4, 1)
	checkbox.text:SetWidth(textWidth or 160)
	checkbox.text:SetJustifyH("LEFT")
	checkbox.text:SetText(label)
	checkbox:SetScript("OnClick", function(self)
		GS_OnSettingChanged(key, self:GetChecked() and true or false)
	end)
	GS_RegisterSettingControl(key, checkbox)
	return checkbox
end

local function GS_CreateSectionHeader(parent, text, anchor, offsetY)
	local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
	header:SetText(text)
	return header
end

local function GS_BuildOptionsContent(hostFrame, viewportWidth, topInset, bottomInset)
	local hostName = hostFrame and hostFrame:GetName()
	local scrollFrameName = hostName and (hostName .. "ScrollFrame") or nil
	local contentName = hostName and (hostName .. "ScrollChild") or nil
	local scrollFrame = CreateFrame("ScrollFrame", scrollFrameName, hostFrame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", hostFrame, "TOPLEFT", 16, topInset or -48)
	scrollFrame:SetPoint("BOTTOMRIGHT", hostFrame, "BOTTOMRIGHT", -30, bottomInset or 16)

	local content = CreateFrame("Frame", contentName, scrollFrame)
	content:SetWidth(viewportWidth)
	content:SetHeight(900)
	scrollFrame:SetScrollChild(content)

	local anchor = content
	local columnGap = 18
	local columnWidth = floor((viewportWidth - columnGap) / 2)
	local columnOffset = columnWidth + columnGap
	local columnTextWidth = columnWidth - 38
	local header = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
	header:SetWidth(viewportWidth - 12)
	header:SetJustifyH("LEFT")
	header:SetText("Configure which score lines and explain sections GearScore2 displays. Changes apply immediately.")
	anchor = header

	for sectionIndex = 1, #GS_OptionsSections do
		local section = GS_OptionsSections[sectionIndex]
		local title = GS_CreateSectionHeader(content, section.title, anchor, -18)
		local rowAnchor = title
		local sectionBottom = title
		for itemIndex = 1, #section.items, 2 do
			local leftOption = section.items[itemIndex]
			local rightOption = section.items[itemIndex + 1]
			local leftCheckbox = GS_CreateCheckbox(content, leftOption.key, leftOption.label, rowAnchor, -8, 0, columnTextWidth)
			if rightOption then
				GS_CreateCheckbox(content, rightOption.key, rightOption.label, rowAnchor, -8, columnOffset + columnGap, columnTextWidth)
			end
			rowAnchor = leftCheckbox
			sectionBottom = leftCheckbox
		end
		anchor = sectionBottom
	end

	local footer = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	footer:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -18)
	footer:SetWidth(viewportWidth - 12)
	footer:SetJustifyH("LEFT")
	footer:SetText("Tip: drag the minimap button to move it. Use /gs2 interface to jump to the Blizzard Interface Options page.")

	content:SetHeight(860)
	return scrollFrame, content
end

local function GS_CreateInterfaceOptionsPanel()
	if GS_InterfaceOptionsPanel then
		return GS_InterfaceOptionsPanel
	end

	local panel = CreateFrame("Frame", "GS2InterfaceOptionsPanel", UIParent)
	panel.name = "GearScore2"

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
	title:SetText("GearScore2")

	local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	subtitle:SetText("Native settings for tooltip output, explain sections, and the minimap button.")

	GS_BuildOptionsContent(panel, 400, -56, 16)

	panel.refresh = GS_RefreshOptionsUI
	panel:SetScript("OnShow", GS_RefreshOptionsUI)

	InterfaceOptions_AddCategory(panel)
	GS_InterfaceOptionsPanel = panel
	return panel
end

local function GS_UpdateMinimapButtonDrag(self)
	local mx, my = Minimap:GetCenter()
	local cursorX, cursorY = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	local dx, dy, angle
	cursorX = cursorX / scale
	cursorY = cursorY / scale
	dx = cursorX - mx
	dy = cursorY - my
	if dx == 0 then
		angle = dy >= 0 and 90 or -90
	else
		angle = math.deg(math.atan(dy / dx))
		if dx < 0 then
			angle = angle + 180
		end
	end
	if angle < 0 then
		angle = angle + 360
	end
	GS_Settings["minimapAngle"] = angle
	GS_ApplyMinimapButtonPosition()
end

local function GS_CreateMinimapButton()
	if GS_MinimapButton then
		return GS_MinimapButton
	end

	local button = CreateFrame("Button", "GS2MinimapButton", Minimap)
	button:SetWidth(32)
	button:SetHeight(32)
	button:SetFrameStrata("MEDIUM")
	button:SetMovable(true)
	button:RegisterForClicks("LeftButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetWidth(53)
	overlay:SetHeight(53)
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetPoint("TOPLEFT")

	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetWidth(20)
	icon:SetHeight(20)
	icon:SetPoint("CENTER", 0, 1)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
	button.icon = icon

	button:SetScript("OnClick", function()
		GS_OpenInterfaceOptionsCategory()
	end)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", GS_UpdateMinimapButtonDrag)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		GS_ApplyMinimapButtonPosition()
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("GearScore2", 0.82, 0.92, 1.0)
		GameTooltip:AddLine("Left-click to open Interface Options.", 0.9, 0.9, 0.9)
		GameTooltip:AddLine("Drag to move around the minimap.", 0.9, 0.9, 0.9)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	GS_MinimapButton = button
	GS_ApplyMinimapButtonVisibility()
	return button
end

function GS_OpenOptionsPanel()
	GS_OpenInterfaceOptionsCategory()
end

function GS_ToggleOptionsPanel()
	GS_OpenInterfaceOptionsCategory()
end

function GS_OpenInterfaceOptionsCategory()
	local panel = GS_CreateInterfaceOptionsPanel()
	InterfaceOptionsFrame_OpenToCategory(panel)
	InterfaceOptionsFrame_OpenToCategory(panel)
	GS_RefreshOptionsUI()
end

function GS_InitializeSettings()
	if type(GS2_Settings) ~= "table" then
		GS2_Settings = {}
	end
	GS_CopyDefaults(GS2_Settings, GS_DefaultSettings)
	GS_Settings = GS2_Settings
	GS_CreateInterfaceOptionsPanel()
	GS_CreateMinimapButton()
	GS_RefreshOptionsUI()
end
