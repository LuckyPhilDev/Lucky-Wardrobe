-- The address that lands in the popup is the whole feature, so these go through
-- the popup rather than at the string building underneath it.

local addon = { Profile = { WowheadLinks = true } }
local locale = "enUS"
local shiftDown = true
local sources = {}

_G.LibStub = function(name)
	if name == "AceAddon-3.0" then
		return { GetAddon = function() return addon end }
	end
	return { GetLocale = function()
		return setmetatable({}, { __index = function(_, key) return key end })
	end }
end

_G.StaticPopupDialogs = {}
_G.CLOSE = "Close"
_G.format = string.format
_G.GetLocale = function() return locale end
_G.IsShiftKeyDown = function() return shiftDown end
_G.C_TransmogCollection = { GetSourceInfo = function(sourceID) return sources[sourceID] end }

local popupsShown = 0
_G.StaticPopup_Show = function() popupsShown = popupsShown + 1 end

assert(loadfile("src/Modules/WowheadLink.lua"))("LuckyTest")

local WowheadLink = addon.WowheadLink
local popup = StaticPopupDialogs["LUCKYS_BETTER_WARDROBE_WOWHEAD_LINK"]

local function FakeEditBox()
	local editBox = { text = "" }
	function editBox:SetText(value) self.text = value end
	function editBox:GetText() return self.text end
	function editBox:HighlightText() end
	function editBox:SetFocus() end
	return editBox
end

local function ShowPopup()
	local editBox = FakeEditBox()
	popup.OnShow({ GetEditBox = function() return editBox end })
	return editBox
end

local HELM_SOURCE, ITEMLESS_SOURCE = 10, 11
sources[HELM_SOURCE] = { itemID = 5678 }
sources[ITEMLESS_SOURCE] = {}

-- Only shift-right-click is claimed, and turning the feature off hands even that
-- back to whatever the player had it doing.
assert(WowheadLink:HandlesClick("RightButton"))
assert(not WowheadLink:HandlesClick("LeftButton"))

shiftDown = false
assert(not WowheadLink:HandlesClick("RightButton"))
shiftDown = true

addon.Profile.WowheadLinks = false
assert(not WowheadLink:HandlesClick("RightButton"))
addon.Profile.WowheadLinks = true

assert(WowheadLink:ShowForSource(HELM_SOURCE))
assert(ShowPopup():GetText() == "https://www.wowhead.com/item=5678")

-- Someone playing in German wants the German page.
locale = "deDE"
assert(WowheadLink:ShowForSource(HELM_SOURCE))
assert(ShowPopup():GetText() == "https://de.wowhead.com/item=5678")

-- Wowhead has no Taiwanese site, so those fall back to the English one.
locale = "zhTW"
assert(WowheadLink:ShowForSource(HELM_SOURCE))
assert(ShowPopup():GetText() == "https://www.wowhead.com/item=5678")
locale = "enUS"

-- Nothing to look up means no popup rather than an address to nowhere.
local before = popupsShown
assert(not WowheadLink:ShowForSource(ITEMLESS_SOURCE))
assert(not WowheadLink:ShowForSource(nil))
assert(popupsShown == before)

-- The box is a copy target, so typing in it does not change what gets copied.
assert(WowheadLink:ShowForSource(HELM_SOURCE))
local editBox = ShowPopup()
editBox:SetText("nonsense")
popup.EditBoxOnTextChanged(editBox)
assert(editBox:GetText() == "https://www.wowhead.com/item=5678")

local function Model(appearanceInfo, source)
	return {
		GetAppearanceInfo = function() return appearanceInfo end,
		GetSourceInfoForTracking = function() return source end,
	}
end

assert(WowheadLink:ShowForAppearanceModel(Model({ visualID = 1 }, { sourceID = HELM_SOURCE })))
assert(ShowPopup():GetText() == "https://www.wowhead.com/item=5678")

-- Hide Helm and its siblings are not items, and illusions come back sourceless.
before = popupsShown
assert(not WowheadLink:ShowForAppearanceModel(Model({ visualID = 0, isHideVisual = true }, { sourceID = HELM_SOURCE })))
assert(not WowheadLink:ShowForAppearanceModel(Model({ visualID = 2 }, nil)))
assert(popupsShown == before)

print("WowheadLinkTest passed")
