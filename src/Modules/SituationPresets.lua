local addonName = ...
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local SituationPresets = {}
addon.SituationPresets = SituationPresets

local OPTION_FIELDS = { "situationID", "specID", "loadoutID", "equipmentSetID" }

local function GetOptionKey(option)
	local values = {}
	for index, field in ipairs(OPTION_FIELDS) do
		values[index] = option[field] or 0
	end
	return table.concat(values, ":")
end

local function ForEachOption(callback)
	for _, category in ipairs(C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions() or {}) do
		for _, group in ipairs(category.groupData or {}) do
			for _, option in ipairs(group.optionData or {}) do
				callback(option)
			end
		end
	end
end

local function CaptureSelections()
	local selections = {}
	ForEachOption(function(option)
		if C_TransmogOutfitInfo.GetOutfitSituation(option.option) then
			selections[GetOptionKey(option.option)] = true
		end
	end)
	return selections
end

local function GetPresetNames()
	local names = {}
	for name in pairs(addon.Profile.SituationPresets) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

function SituationPresets:UpdateLoadButton()
	if self.loadButton then
		self.loadButton:SetEnabled(next(addon.Profile.SituationPresets) ~= nil)
	end
end

function SituationPresets:Save(name, overwrite)
	name = strtrim(name)
	if name == "" then return end
	if not overwrite and addon.Profile.SituationPresets[name] then
		StaticPopup_Show("LUCKYS_BETTER_WARDROBE_REPLACE_SITUATION", nil, nil, name)
		return false
	end

	addon.Profile.SituationPresets[name] = { selections = CaptureSelections() }
	self:UpdateLoadButton()
	return true
end

function SituationPresets:Delete(name)
	addon.Profile.SituationPresets[name] = nil
	self:UpdateLoadButton()
end

function SituationPresets:Apply(preset, situationsFrame)
	if not C_TransmogOutfitInfo.GetOutfitSituationsEnabled() then
		C_TransmogOutfitInfo.SetOutfitSituationsEnabled(true)
	end

	-- Clear first so mutually exclusive options never compete while staging.
	ForEachOption(function(option)
		if C_TransmogOutfitInfo.GetOutfitSituation(option.option) and not preset.selections[GetOptionKey(option.option)] then
			C_TransmogOutfitInfo.UpdatePendingSituation(option.option, false)
		end
	end)
	ForEachOption(function(option)
		if preset.selections[GetOptionKey(option.option)] and not C_TransmogOutfitInfo.GetOutfitSituation(option.option) then
			C_TransmogOutfitInfo.UpdatePendingSituation(option.option, true)
		end
	end)
	C_TransmogOutfitInfo.CommitPendingSituations()
	situationsFrame:Refresh()
end

StaticPopupDialogs["LUCKYS_BETTER_WARDROBE_SAVE_SITUATION"] = {
	preferredIndex = 3,
	text = L["Save Situation"],
	button1 = SAVE,
	button2 = CANCEL,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	hasEditBox = 1,
	maxLetters = 31,
	OnAccept = function(dialog)
		SituationPresets:Save(dialog:GetEditBox():GetText())
	end,
	OnShow = function(dialog)
		dialog:GetButton1():Disable()
		dialog:GetEditBox():SetFocus()
	end,
	OnHide = function(dialog)
		dialog:GetEditBox():SetText("")
	end,
	EditBoxOnEnterPressed = function(editBox)
		if editBox:GetParent():GetButton1():IsEnabled() then
			StaticPopup_OnClick(editBox:GetParent(), 1)
		end
	end,
	EditBoxOnTextChanged = function(editBox)
		editBox:GetParent():GetButton1():SetEnabled(strtrim(editBox:GetText()) ~= "")
	end,
	EditBoxOnEscapePressed = function(editBox)
		editBox:GetParent():Hide()
	end,
}

StaticPopupDialogs["LUCKYS_BETTER_WARDROBE_REPLACE_SITUATION"] = {
	preferredIndex = 3,
	text = L["Replace Saved Situation"],
	button1 = YES,
	button2 = NO,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function(_dialog, name)
		SituationPresets:Save(name, true)
	end,
}

StaticPopupDialogs["LUCKYS_BETTER_WARDROBE_DELETE_SITUATION"] = {
	preferredIndex = 3,
	text = L["Delete saved situation \"%s\"? This cannot be undone."],
	button1 = YES,
	button2 = NO,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function(_dialog, name)
		SituationPresets:Delete(name)
	end,
}

function addon:InitSituationPresets()
	local situationsFrame = TransmogFrame.WardrobeCollection.TabContent.SituationsFrame
	if SituationPresets.loadButton or not situationsFrame then return end

	local loadButton = CreateFrame("Button", nil, situationsFrame, "SquareIconButtonTemplate")
	loadButton:SetSize(30, 30)
	loadButton.Icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
	loadButton.Icon:SetSize(18, 18)
	loadButton.tooltipText = L["Load Situation"]
	loadButton:SetPoint("BOTTOMRIGHT", situationsFrame.Situations, "TOPRIGHT", 0, 10)
	loadButton:SetScript("OnClick", function()
		MenuUtil.CreateContextMenu(loadButton, function(_owner, rootDescription)
			for _, name in ipairs(GetPresetNames()) do
				local preset = addon.Profile.SituationPresets[name]
				local presetButton = rootDescription:CreateButton(name, function()
					SituationPresets:Apply(preset, situationsFrame)
				end)
				presetButton:AddInitializer(function(menuButton, _description, menu)
					local deleteButton = MenuTemplates.AttachBasicButton(menuButton)
					deleteButton:SetPoint("RIGHT", menuButton, "RIGHT", -3, 0)
					local deleteIcon = deleteButton:AttachTexture()
					deleteIcon:SetAllPoints()
					deleteIcon:SetTexture(MenuVariants.CancelButtonTexture)
					deleteButton:SetScript("OnClick", function()
						StaticPopup_Show("LUCKYS_BETTER_WARDROBE_DELETE_SITUATION", name, nil, name)
						menu:Close()
					end)
					MenuUtil.HookTooltipScripts(deleteButton, function(tooltip)
						tooltip:SetText(L["Delete Saved Situation"])
					end)
				end)
			end
		end)
	end)

	local saveButton = CreateFrame("Button", nil, situationsFrame, "SquareIconButtonTemplate")
	saveButton:SetSize(30, 30)
	saveButton.Icon:SetTexture("Interface\\Icons\\INV_Scroll_03")
	saveButton.Icon:SetSize(18, 18)
	saveButton.tooltipText = L["Save Current Situation"]
	saveButton:SetPoint("RIGHT", loadButton, "LEFT", -4, 0)
	saveButton:SetScript("OnClick", function()
		StaticPopup_Show("LUCKYS_BETTER_WARDROBE_SAVE_SITUATION")
	end)

	SituationPresets.loadButton = loadButton
	SituationPresets:UpdateLoadButton()
end
