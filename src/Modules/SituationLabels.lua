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

local function ApplyValues(outfits, showValues)
	local scrollBox = TransmogFrame.OutfitCollection.OutfitList.ScrollBox
	for _, outfit in ipairs(outfits) do
		local elementData = scrollBox:FindElementDataByPredicate(function(data)
			return data.outfitID == outfit.outfitID
		end)
		if elementData then
			local summary = {}
			for _, categoryName in ipairs(outfit.situationCategories or {}) do
				local outfitValues = showValues and values[outfit.outfitID]
				summary[#summary + 1] = outfitValues and outfitValues[categoryName] or categoryName
			end
			elementData.situationCategories = summary
		end
	end

	scrollBox:ForEachFrame(function(frame)
		local elementData = frame:GetElementData()
		local categories = elementData and elementData.situationCategories or {}
		local text = table.concat(categories, TRANSMOG_SITUATION_CATEGORY_LIST_SEPARATOR)
		local content = frame.OutfitButton.TextContent
		content.SituationInfo:SetShown(text ~= "")
		content.SituationInfo:SetText(text)
		content:Layout()
	end)
end

local function CacheValues()
	if not Enabled() or reading or not TransmogFrame:IsShown() then return end
	if C_TransmogOutfitInfo.HasPendingOutfitSituations() or C_TransmogOutfitInfo.HasPendingOutfitTransmogs() then return end

	local outfits = C_TransmogOutfitInfo.GetOutfitsInfo()
	if not outfits or #outfits == 0 then return end

	values = values or GetStoredValues() or {}
	local missing = {}
	for _, outfit in ipairs(outfits) do
		if not values[outfit.outfitID] then
			if #(outfit.situationCategories or {}) == 0 then
				values[outfit.outfitID] = {}
			else
				missing[#missing + 1] = outfit
			end
		end
	end
	if #missing == 0 then
		ApplyValues(outfits, true)
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
			ApplyValues(outfits, true)
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
	if Enabled() then
		CacheValues()
	else
		ApplyValues(C_TransmogOutfitInfo.GetOutfitsInfo() or {}, false)
	end
end

local installed = false
local function Install()
	if installed then return end
	if not TransmogFrame or not TransmogFrame.OutfitCollection then
		C_Timer.After(0.5, Install)
		return
	end

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
		ApplyValues(C_TransmogOutfitInfo.GetOutfitsInfo() or {}, true)
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
	if TransmogFrame and TransmogFrame:IsShown() then
		ApplyValues(C_TransmogOutfitInfo.GetOutfitsInfo() or {}, false)
	end
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
