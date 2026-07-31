-- Minimap button: opens the Appearances collection, right-click for settings.
local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local APPEARANCES_TAB = 5

function addon:CreateMinimapButton()
	if self.minimapButton then return end

	self.minimapButton = LuckyMinimap:Create({
		name         = "LuckysBetterWardrobeMinimapButton",
		icon         = "Interface\\GossipFrame\\transmogrifyGossipIcon.blp",
		dbKey        = "MinimapButton",
		db           = self.Profile,
		defaultAngle = 194,
		onClick = function(_, mouseBtn)
			if mouseBtn == "RightButton" then
				addon.settingsPanel:Open()
			elseif IsShiftKeyDown() then
				addon.SetCompletion:Toggle()
			else
				ToggleCollectionsJournal(APPEARANCES_TAB)
			end
		end,
		tooltip = function(tt)
			tt:AddLine(LuckyUI.WC.goldPrimary .. "Lucky's Better Wardrobe" .. LuckyUI.WC.reset)
			tt:AddLine(" ")
			tt:AddLine(L["Left-click: Open appearances"], 0.91, 0.86, 0.78)
			tt:AddLine(L["Shift-click: Sets you can finish here"], 0.91, 0.86, 0.78)
			tt:AddLine(L["Right-click: Open settings"], 0.91, 0.86, 0.78)
			tt:AddLine(L["Drag: Move button"], 0.54, 0.49, 0.42)
		end,
	})
end

--- Show or hide the button and remember the choice, even if the button itself
--- failed to build.
function addon:SetMinimapButtonShown(show)
	self.Profile.MinimapButton.hide = not show
	if self.minimapButton then
		self.minimapButton:SetShown_Persisted(show)
	end
end
