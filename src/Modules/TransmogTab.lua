-- Keeps the active tab at the transmog NPC on programmatic refreshes (outfit
-- switch, model reload) while letting a manual slot click fall through to the
-- Items tab as stock does.
-- TransmogFrame.WardrobeCollection:UpdateSlot always resets to Items via
-- SetToItemsTab(). SelectSlot's forceRefresh arg tells the two cases apart: a
-- user slot click passes false, a refresh (RefreshSelectedSlot) passes true.
-- The tab is polled between frames so the user's last tab is known before any
-- in-frame reset clobbers it, then restored only on forceRefresh.
local addonName, addon = ...

local hooked = false
local userTab
local watcher

local function InstallHooks()
	if hooked then return end
	local wc = TransmogFrame and TransmogFrame.WardrobeCollection
	if not wc or not wc.TabHeaders or type(wc.SetTab) ~= "function" then return end
	if type(TransmogFrame.SelectSlot) ~= "function" then return end

	local tabHeaders = wc.TabHeaders

	watcher = CreateFrame("Frame")
	watcher:SetScript("OnUpdate", function()
		userTab = tabHeaders.selectedTabID or userTab
	end)

	hooksecurefunc(TransmogFrame, "SelectSlot", function(_, _, forceRefresh)
		if not forceRefresh or not addon.Profile.KeepTransmogTab then return end
		if not userTab or tabHeaders.selectedTabID == userTab then return end
		wc:SetTab(userTab)
	end)

	hooked = true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("TRANSMOGRIFY_OPEN")
eventFrame:RegisterEvent("TRANSMOGRIFY_CLOSE")
eventFrame:SetScript("OnEvent", function(_, event)
	userTab = nil
	if event == "TRANSMOGRIFY_OPEN" then
		if watcher then watcher:Show() end
		C_Timer.After(0.1, InstallHooks)
	elseif watcher then
		watcher:Hide()
	end
end)
