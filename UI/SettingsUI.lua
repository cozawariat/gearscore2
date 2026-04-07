-------------------------------------------------------------------------------
--                          GearScore2 Settings UI                            --
-------------------------------------------------------------------------------

local GS = _G.GS2
local State = GS and GS.State or {}
local Data = GS and GS.Data or {}
local Tables = Data.Tables or {}
GS.SettingsUI = GS.SettingsUI or {
	OptionsBindings = {},
	InterfaceOptionsPanel = nil,
	MinimapButton = nil,
	TabButtons = {},
	TabFrames = {},
	ActiveTabKey = nil,
}
local SettingsUI = GS.SettingsUI
local GS_OptionsBindings = SettingsUI.OptionsBindings
local GS_InterfaceOptionsPanel = SettingsUI.InterfaceOptionsPanel
local GS_MinimapButton = SettingsUI.MinimapButton
local GS_ExplainState = State.ExplainState or { owner = nil, itemLink = nil, itemSlot = nil }
local GS_DEFAULT_SETTINGS = Tables.DefaultSettings or {}
local GS_TabButtons = SettingsUI.TabButtons
local GS_TabFrames = SettingsUI.TabFrames

local GS_OptionsTabs = {
	{
		key = "general",
		title = "General",
		description = "General addon settings, reset tools, and quick tips.",
		sections = {
			{
				title = "Interface",
				items = {
					{ key = "showMinimapButton", label = "Show minimap button" },
				},
			},
		},
	},
	{
		key = "character",
		title = "Character Tooltip",
		description = "Choose which lines appear on player and inspect tooltips.",
		sections = {
			{
				title = "Character Tooltip",
				items = {
					{ key = "showCharacterGS2", label = "Show GearScore2" },
					{ key = "showCharacterLegacy", label = "Show Legacy GearScore" },
					{ key = "showCharacterPvp", label = "Show PvP GearScore" },
					{ key = "showCharacterAverage", label = "Show Average iLevel" },
					{ key = "showCharacterSpec", label = "Show specialization" },
					{ key = "showCharacterInferred", label = "Show inferred" },
					{ key = "hideCharacterInferredUnderThreshold", label = "Hide inferred if score difference is < 5%" },
					{ key = "showCharacterCapSummary", label = "Show cap summary" },
					{ key = "showCharacterCompare", label = "Show compare line" },
				},
			},
		},
	},
	{
		key = "item",
		title = "Item Tooltip",
		description = "Control which item score families show on item tooltips.",
		sections = {
			{
				title = "Item Tooltip",
				items = {
					{ key = "showItemGS2", label = "Show GearScore2" },
					{ key = "showItemLegacy", label = "Show Legacy GearScore" },
					{ key = "showItemPvp", label = "Show PvP GearScore" },
				},
			},
		},
	},
	{
		key = "explain",
		title = "Explain Tooltip",
		description = "Configure the CTRL explain tooltip and its detail blocks.",
		sections = {
			{
				title = "Explain Tooltip",
				items = {
					{ key = "enableExplainTooltip", label = "Enable explain tooltip on CTRL" },
					{ key = "alwaysShowExplainTooltip", label = "Always show (no CTRL required)" },
					{ key = "showExplainHeader", label = "Show summary header" },
					{ key = "showExplainFlags", label = "Show flags" },
					{ key = "showExplainZeroComponents", label = "Show zero-score components" },
					{ key = "hideExplainNeutralResilienceMultiplier", label = "Hide resilience multiplier when it does not change the result" },
				},
			},
			{
				title = "Legacy",
				items = {
					{ key = "showExplainLegacy", label = "Show legacy section" },
				},
			},
			{
				title = "PvE",
				items = {
					{ key = "showExplainPveFormula", label = "Show PvE formula line" },
					{ key = "showExplainPveParts", label = "Show PvE parts list" },
					{ key = "showExplainPveTotals", label = "Show PvE totals and multiplier" },
					{ key = "showExplainTopPveStats", label = "Show top PvE stats" },
				},
			},
			{
				title = "PvP",
				items = {
					{ key = "showExplainPvpFormula", label = "Show PvP formula line" },
					{ key = "showExplainPvpParts", label = "Show PvP parts list" },
					{ key = "showExplainPvpTotals", label = "Show PvP totals and multiplier" },
					{ key = "showExplainTopPvpStats", label = "Show top PvP stats" },
				},
			},
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
	local inferredEnabled = GS_Settings["showCharacterInferred"] and true or false
	local inferredThresholdControls = GS_OptionsBindings["hideCharacterInferredUnderThreshold"] or {}
	for index = 1, #inferredThresholdControls do
		local control = inferredThresholdControls[index]
		if inferredEnabled then
			control:Enable()
			control:SetAlpha(1)
			if control.text then
				control.text:SetTextColor(1, 0.82, 0)
			end
		else
			control:Disable()
			control:SetAlpha(0.6)
			if control.text then
				control.text:SetTextColor(0.5, 0.5, 0.5)
			end
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

local function GS_ResetSettingsToDefaults()
	if not GS_Settings then
		return
	end
	for key in pairs(GS_Settings) do
		if GS_DEFAULT_SETTINGS[key] == nil then
			GS_Settings[key] = nil
		end
	end
	for key, value in pairs(GS_DEFAULT_SETTINGS) do
		GS_Settings[key] = value
	end
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

local function GS_CreateActionButton(parent, text, anchor, offsetY, width, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetWidth(width or 180)
	button:SetHeight(22)
	button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, offsetY)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

local function GS_BuildTabContent(hostFrame, tab, viewportWidth)
	local panelName = GS_InterfaceOptionsPanel and GS_InterfaceOptionsPanel:GetName() or "GS2InterfaceOptionsPanel"
	local tabPrefix = panelName .. tab.key:gsub("^%l", string.upper)
	local scrollFrame = CreateFrame("ScrollFrame", tabPrefix .. "ScrollFrame", hostFrame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", hostFrame, "TOPLEFT", 0, 0)
	scrollFrame:SetPoint("BOTTOMRIGHT", hostFrame, "BOTTOMRIGHT", 0, 0)

	local content = CreateFrame("Frame", tabPrefix .. "ScrollChild", scrollFrame)
	content:SetWidth(viewportWidth)
	content:SetHeight(900)
	scrollFrame:SetScrollChild(content)

	local anchor = content
	local columnGap = 18
	local columnWidth = floor((viewportWidth - columnGap) / 2)
	local columnOffset = columnWidth + columnGap
	local columnTextWidth = columnWidth - 38
	local estimatedHeight = 64
	local header = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
	header:SetWidth(viewportWidth - 12)
	header:SetJustifyH("LEFT")
	header:SetText(tab.description or "Configure which score lines and explain sections GearScore2 displays. Changes apply immediately.")
	anchor = header

	for sectionIndex = 1, #(tab.sections or {}) do
		local section = tab.sections[sectionIndex]
		local rowCount = math.ceil(#section.items / 2)
		estimatedHeight = estimatedHeight + 34 + (rowCount * 26)
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

	if tab.key == "general" then
		local resetHeader = GS_CreateSectionHeader(content, "Maintenance", anchor, -18)
		local resetNote = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		resetNote:SetPoint("TOPLEFT", resetHeader, "BOTTOMLEFT", 4, -10)
		resetNote:SetWidth(viewportWidth - 24)
		resetNote:SetJustifyH("LEFT")
		resetNote:SetText("Reset all GearScore2 settings back to their default values.")
		local resetButton = GS_CreateActionButton(content, "Reset to Defaults", resetNote, -12, 150, GS_ResetSettingsToDefaults)
		anchor = resetButton
		estimatedHeight = estimatedHeight + 92
	end

	local footer = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	footer:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -18)
	footer:SetWidth(viewportWidth - 12)
	footer:SetJustifyH("LEFT")
	footer:SetText("Tip: drag the minimap button to move it. Use /gs2 settings to open the GearScore2 settings panel.")

	content:SetHeight(math.max(420, estimatedHeight + 60))
	return scrollFrame, content
end

local function GS_SelectOptionsTab(tabKey)
	SettingsUI.ActiveTabKey = tabKey
	for index = 1, #GS_TabButtons do
		local button = GS_TabButtons[index]
		local selected = button.tabKey == tabKey
		button:SetButtonState(selected and "PUSHED" or "NORMAL")
		if selected then
			button:Disable()
		else
			button:Enable()
		end
	end
	for key, frame in pairs(GS_TabFrames) do
		if key == tabKey then
			frame:Show()
		else
			frame:Hide()
		end
	end
end

local function GS_CreateOptionsTabs(panel)
	local tabsAnchor = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	tabsAnchor:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -56)
	tabsAnchor:SetText("Tabs")

	local firstButton
	local previousButton
	for index = 1, #GS_OptionsTabs do
		local tab = GS_OptionsTabs[index]
		local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		if tab.key == "general" then
			button:SetWidth(72)
		elseif tab.key == "character" then
			button:SetWidth(96)
		elseif tab.key == "item" then
			button:SetWidth(86)
		else
			button:SetWidth(96)
		end
		button:SetHeight(22)
		button.tabKey = tab.key
		button:SetText(tab.title)
		if previousButton then
			button:SetPoint("LEFT", previousButton, "RIGHT", 8, 0)
		else
			button:SetPoint("TOPLEFT", tabsAnchor, "BOTTOMLEFT", 0, -8)
			firstButton = button
		end
		button:SetScript("OnClick", function(self)
			GS_SelectOptionsTab(self.tabKey)
		end)
		GS_TabButtons[#GS_TabButtons + 1] = button
		previousButton = button
	end

	local container = CreateFrame("Frame", nil, panel)
	container:SetPoint("TOPLEFT", firstButton, "BOTTOMLEFT", 0, -12)
	container:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 16)

	for index = 1, #GS_OptionsTabs do
		local tab = GS_OptionsTabs[index]
		local panelName = panel:GetName() or "GS2InterfaceOptionsPanel"
		local frame = CreateFrame("Frame", panelName .. tab.key:gsub("^%l", string.upper) .. "Tab", container)
		frame:SetAllPoints(container)
		GS_BuildTabContent(frame, tab, 400)
		frame:Hide()
		GS_TabFrames[tab.key] = frame
	end

	GS_SelectOptionsTab(SettingsUI.ActiveTabKey or GS_OptionsTabs[1].key)
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
	subtitle:SetText("Native settings for tooltip output, organized into General, Character, Item, and Explain tabs.")

	GS_CreateOptionsTabs(panel)

	panel.refresh = GS_RefreshOptionsUI
	panel:SetScript("OnShow", GS_RefreshOptionsUI)

	InterfaceOptions_AddCategory(panel)
	GS_InterfaceOptionsPanel = panel
	SettingsUI.InterfaceOptionsPanel = panel
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
	SettingsUI.MinimapButton = button
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
	GS_CopyDefaults(GS2_Settings, GS_DEFAULT_SETTINGS)
	GS_Settings = GS2_Settings
	GS.Settings = GS_Settings
	GS_CreateInterfaceOptionsPanel()
	GS_CreateMinimapButton()
	GS_RefreshOptionsUI()
end
