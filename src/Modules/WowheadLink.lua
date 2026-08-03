-- Shift-right-clicking an appearance hands back its Wowhead address. The game
-- has no clipboard API, so the address arrives in a popup with its text already
-- selected, ready for Ctrl+C.
local addonName = ...
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local WowheadLink = {}
addon.WowheadLink = WowheadLink

local POPUP = "LUCKYS_BETTER_WARDROBE_WOWHEAD_LINK"

-- Wowhead runs a site per language, and the English page is no use to someone
-- playing in German.
local SUBDOMAIN_BY_LOCALE = {
	deDE = "de",
	esES = "es",
	esMX = "es",
	frFR = "fr",
	itIT = "it",
	koKR = "ko",
	ptBR = "pt",
	ruRU = "ru",
	zhCN = "cn",
}

-- The edit box is a copy target rather than an input, so it is held at the
-- address that was put in it.
local shownURL

StaticPopupDialogs[POPUP] = {
	preferredIndex = 3,
	text = L["Press Ctrl+C to copy this address, then paste it into your browser."],
	button1 = CLOSE,
	hasEditBox = 1,
	editBoxWidth = 260,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnShow = function(dialog)
		local editBox = dialog:GetEditBox()
		editBox:SetText(shownURL or "")
		editBox:HighlightText()
		editBox:SetFocus()
	end,
	EditBoxOnTextChanged = function(editBox)
		local url = shownURL or ""
		if editBox:GetText() ~= url then
			editBox:SetText(url)
			editBox:HighlightText()
		end
	end,
	EditBoxOnEnterPressed = function(editBox)
		editBox:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(editBox)
		editBox:GetParent():Hide()
	end,
}

function WowheadLink:ShowForItem(itemID)
	if not itemID then
		return false
	end

	local subdomain = SUBDOMAIN_BY_LOCALE[GetLocale()] or "www"
	shownURL = format("https://%s.wowhead.com/item=%d", subdomain, itemID)
	StaticPopup_Show(POPUP)
	return true
end

function WowheadLink:ShowForSource(sourceID)
	local sourceInfo = sourceID and C_TransmogCollection.GetSourceInfo(sourceID)
	return self:ShowForItem(sourceInfo and sourceInfo.itemID)
end

-- An appearance several items share links to whichever of them the tooltip is
-- showing, which is the one the player is looking at.
function WowheadLink:ShowForAppearanceModel(model)
	local appearanceInfo = model:GetAppearanceInfo()
	if not appearanceInfo or appearanceInfo.isHideVisual then
		return false
	end

	local source = model:GetSourceInfoForTracking()
	return self:ShowForSource(source and source.sourceID)
end
