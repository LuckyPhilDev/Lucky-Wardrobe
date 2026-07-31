local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local values
local reading = false
local restoring = false

-- Fallback only: each scan step normally advances the moment
-- VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED confirms the new outfit is live.
local stepTimeout = 0.1
local pendingStep

local function WaitForSituations(run)
	local step = { run = run }
	pendingStep = step
	C_Timer.After(stepTimeout, function()
		if pendingStep == step then
			pendingStep = nil
			step.run()
		end
	end)
end

local function AdvanceScan()
	local step = pendingStep
	if not step then return end
	pendingStep = nil
	step.run()
end

local BAR_WIDTH = 360
local BAR_INSET = 2

local scanOverlay

local function CreateScanOverlay()
	local frame = CreateFrame("Frame", "LuckysBetterWardrobe_SituationScanOverlay", TransmogFrame)
	frame:SetAllPoints(TransmogFrame)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:EnableMouse(true)
	frame:EnableMouseWheel(true)
	frame:Hide()

	local shade = frame:CreateTexture(nil, "BACKGROUND")
	shade:SetAllPoints()
	shade:SetColorTexture(0, 0, 0, 0.65)

	local panel = LuckyUI.CreatePanel(nil, frame, 440, 170)
	panel:SetPoint("CENTER")

	local title = panel:CreateFontString(nil, "OVERLAY")
	title:SetFont(LuckyUI.TITLE_FONT, 18)
	title:SetTextColor(unpack(LuckyUI.C.goldPrimary))
	title:SetPoint("TOP", 0, -20)
	title:SetText(L["Reading Outfit Situations"])

	local message = panel:CreateFontString(nil, "OVERLAY")
	message:SetFont(LuckyUI.BODY_FONT, 13)
	message:SetTextColor(unpack(LuckyUI.C.textLight))
	message:SetPoint("TOP", title, "BOTTOM", 0, -12)
	message:SetWidth(400)
	message:SetJustifyH("CENTER")
	message:SetText(L["Each outfit is being opened to read its situation values. Please wait, using the wardrobe now will interrupt the scan."])

	local track = CreateFrame("Frame", nil, panel, "BackdropTemplate")
	track:SetSize(BAR_WIDTH, 16)
	track:SetPoint("BOTTOM", 0, 46)
	track:SetBackdrop(LuckyUI.Backdrop)
	track:SetBackdropColor(unpack(LuckyUI.C.bgInput))
	track:SetBackdropBorderColor(unpack(LuckyUI.C.borderDark))

	local fill = track:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("TOPLEFT", BAR_INSET, -BAR_INSET)
	fill:SetPoint("BOTTOMLEFT", BAR_INSET, BAR_INSET)
	fill:SetColorTexture(unpack(LuckyUI.C.goldAccent))

	local count = panel:CreateFontString(nil, "OVERLAY")
	count:SetFont(LuckyUI.BODY_FONT, 12)
	count:SetTextColor(unpack(LuckyUI.C.textMuted))
	count:SetPoint("BOTTOM", 0, 22)

	function frame:SetProgress(done, total)
		local usable = BAR_WIDTH - BAR_INSET * 2
		fill:SetWidth(math.max(1, usable * (done / math.max(total, 1))))
		count:SetText(L["%d of %d outfits"]:format(done, total))
	end

	return frame
end

local function ShowScanOverlay(total)
	scanOverlay = scanOverlay or CreateScanOverlay()
	scanOverlay:SetProgress(0, total)
	scanOverlay:Show()
end

local function SetScanProgress(done, total)
	if scanOverlay then scanOverlay:SetProgress(done, total) end
end

local function HideScanOverlay()
	if scanOverlay then scanOverlay:Hide() end
end

local function Enabled()
	return not addon.Profile or addon.Profile.ShowSituationValues ~= false
end

local function TooltipsEnabled()
	return not addon.Profile or addon.Profile.ShowSituationTooltips ~= false
end

local function GetStoredValues()
	if not addon.chardb then return end
	addon.chardb.char.SituationLabels = addon.chardb.char.SituationLabels or {}
	return addon.chardb.char.SituationLabels
end

local function SaveValues()
	local storedValues = GetStoredValues()
	if storedValues then addon.chardb.char.SituationLabels = values end
end

local function ReadValues()
	local result = {}
	for _, category in ipairs(C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions() or {}) do
		local selected = {}
		for _, group in ipairs(category.groupData or {}) do
			for _, option in ipairs(group.optionData or {}) do
				if C_TransmogOutfitInfo.GetOutfitSituation(option.option) then
					selected[#selected + 1] = option.name
				end
			end
		end
		result[category.name] = table.concat(selected, "+")
	end
	return result
end

local function SelectedValues(outfitID, categoryName)
	if not Enabled() then return end
	values = values or GetStoredValues()
	local outfitValues = values and values[outfitID]
	local categoryValues = outfitValues and outfitValues[categoryName]
	if categoryValues ~= "" then return categoryValues end
end

-- The outfit list rebuilds its element data from the API on every refresh, so the
-- override has to be reapplied per entry rather than stored on the element data.
local function SituationText(elementData)
	local summary = {}
	local details = {}
	for _, categoryName in ipairs(elementData.situationCategories or {}) do
		local categoryValues = SelectedValues(elementData.outfitID, categoryName)
		summary[#summary + 1] = categoryValues or categoryName
		details[#details + 1] = { name = categoryName, values = categoryValues }
	end
	elementData.situationDetails = details
	return table.concat(summary, TRANSMOG_SITUATION_CATEGORY_LIST_SEPARATOR)
end

local function ApplyEntry(entry, elementData)
	elementData = elementData or entry:GetElementData()
	if not elementData then return end

	local text = SituationText(elementData)
	local content = entry.OutfitButton.TextContent
	content.SituationInfo:SetShown(text ~= "")
	content.SituationInfo:SetText(text)
	content:Layout()
end

local function ApplyValues()
	if not TransmogFrame or not TransmogFrame.OutfitCollection then return end
	TransmogFrame.OutfitCollection.OutfitList.ScrollBox:ForEachFrame(ApplyEntry)
end

local function ReadableValues(text)
	return (text:gsub("%+", ", "))
end

local function TooltipLine(detail)
	if not detail.values then return detail.name end

	local label = GRAY_FONT_COLOR:WrapTextInColorCode(detail.name .. ":")
	return ("%s %s"):format(label, ReadableValues(detail.values))
end

local function TooltipDetails(elementData)
	if elementData.situationDetails then return elementData.situationDetails end

	local details = {}
	for _, categoryName in ipairs(elementData.situationCategories or {}) do
		details[#details + 1] = { name = categoryName }
	end
	return details
end

local function ShowSituationTooltip(entry)
	if not TooltipsEnabled() then return end

	local elementData = entry:GetElementData()
	if not elementData or not entry.OutfitButton.TextContent.SituationInfo:IsShown() then return end

	GameTooltip:SetOwner(entry.OutfitButton, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", entry.OutfitButton, "TOPRIGHT", 4, 0)
	GameTooltip_SetTitle(GameTooltip, elementData.name)
	for _, detail in ipairs(TooltipDetails(elementData)) do
		GameTooltip_AddHighlightLine(GameTooltip, TooltipLine(detail))
	end
	GameTooltip:Show()
end

local function InstallSituationTooltip(entry)
	if entry.luckySituationTooltip then return end
	entry.luckySituationTooltip = true

	entry.OutfitButton:HookScript("OnEnter", function() ShowSituationTooltip(entry) end)
	entry.OutfitButton:HookScript("OnLeave", GameTooltip_Hide)
end

local function CacheValues()
	if not Enabled() or reading or not TransmogFrame:IsShown() then return end
	if C_TransmogOutfitInfo.HasPendingOutfitSituations() or C_TransmogOutfitInfo.HasPendingOutfitTransmogs() then return end

	local outfits = C_TransmogOutfitInfo.GetOutfitsInfo()
	if not outfits or #outfits == 0 then return end

	values = values or GetStoredValues() or {}
	local viewedOutfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
	local missing = {}
	for _, outfit in ipairs(outfits) do
		if not values[outfit.outfitID] then
			if #(outfit.situationCategories or {}) == 0 then
				values[outfit.outfitID] = {}
			elseif outfit.outfitID == viewedOutfitID then
				values[outfit.outfitID] = ReadValues()
			else
				missing[#missing + 1] = outfit
			end
		end
	end
	if #missing == 0 then
		ApplyValues()
		SaveValues()
		return
	end

	reading = true
	ShowScanOverlay(#missing)
	local originalOutfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
	local index = 0
	local function Finish()
		pendingStep = nil
		restoring = true
		C_TransmogOutfitInfo.ChangeViewedOutfit(originalOutfitID)
		if Enabled() then
			ApplyValues()
			SaveValues()
		end
		reading = false
		HideScanOverlay()
		C_Timer.After(0.25, function() restoring = false end)
	end
	local function Next()
		if not Enabled() then
			Finish()
			return
		end
		index = index + 1
		local outfit = missing[index]
		if not outfit then
			Finish()
			return
		end

		SetScanProgress(index - 1, #missing)
		WaitForSituations(function()
			values[outfit.outfitID] = ReadValues()
			Next()
		end)
		C_TransmogOutfitInfo.ChangeViewedOutfit(outfit.outfitID)
	end
	Next()
end

function addon:RefreshSituationLabels()
	if not TransmogFrame or not TransmogFrame:IsShown() then return end
	ApplyValues()
	if Enabled() then CacheValues() end
end

local installed = false
local function Install()
	if installed then return end
	if not TransmogFrame or not TransmogFrame.OutfitCollection then
		C_Timer.After(0.5, Install)
		return
	end

	hooksecurefunc(TransmogOutfitEntryMixin, "Init", function(entry, elementData)
		InstallSituationTooltip(entry)
		ApplyEntry(entry, elementData)
	end)

	TransmogFrame:HookScript("OnShow", function()
		C_Timer.After(0, CacheValues)
	end)
	installed = true
	if TransmogFrame:IsShown() then CacheValues() end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("TRANSMOG_OUTFITS_CHANGED")
eventFrame:RegisterEvent("VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event)
	if reading then
		if event == "VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED" then AdvanceScan() end
		return
	end
	if restoring then return end
	if event == "VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED" and values and Enabled() then
		values[C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()] = ReadValues()
		SaveValues()
		ApplyValues()
	elseif TransmogFrame:IsShown() then
		CacheValues()
	end
end)

local function CountValues()
	local total = 0
	for _ in pairs(values or {}) do total = total + 1 end
	return total
end

local function WipeValues()
	if reading then
		print(addon.PREFIX .. " situation labels: still reading, try again once the scan finishes")
		return
	end

	values = {}
	SaveValues()
	if TransmogFrame and TransmogFrame:IsShown() then ApplyValues() end
	print(addon.PREFIX .. " situation labels: cache wiped, run /bwlabels scan to rescan")
end

SLASH_LUCKYBWLABELS1 = "/bwlabels"
SlashCmdList.LUCKYBWLABELS = function(msg)
	local command, argument = strsplit(" ", strtrim(msg or ""):lower())
	if command == "wipe" then
		WipeValues()
	elseif command == "scan" then
		CacheValues()
	elseif command == "delay" then
		stepTimeout = math.max(0, tonumber(argument) or stepTimeout)
		print(addon.PREFIX .. (" situation labels: step fallback %.2fs"):format(stepTimeout))
	else
		local state = reading and "reading" or values and "ready" or "waiting"
		print(addon.PREFIX .. (" situation labels: %s, %d cached"):format(state, CountValues()))
	end
end

C_Timer.After(0, Install)
