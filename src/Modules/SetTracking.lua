-- Shift-click a set to track every appearance you are still missing from it,
-- the way shift-clicking an item on the Items tab tracks that one appearance.
-- Reached from the set list, the set tiles at the transmog NPC, and the
-- individual pieces in the set details pane.
local addonName = ...
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local SetTracking = {}
addon.SetTracking = SetTracking

local APPEARANCE = Enum.ContentTrackingType.Appearance

local function Announce(message)
	print(("%s %s"):format(addon.PREFIX, message))
end

--- Whether a click should track a set instead of doing its usual job.
function SetTracking:WantsTracking(button)
	return addon.Profile.TrackSetsOnShiftClick and button == "LeftButton" and IsShiftKeyDown()
end

-- StartTracking raises a hard Lua error on some untrackable sources, so without
-- the pcall one bad piece would abandon the rest of the set.
local function StartTracking(sourceID)
	local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
	if not (sourceInfo and sourceInfo.playerCanCollect) then
		return Enum.ContentTrackingError.Untrackable
	end

	local ok, err = pcall(C_ContentTracking.StartTracking, APPEARANCE, sourceID)
	if not ok then
		addon.DevLog(("StartTracking failed for source %s. %s"):format(tostring(sourceID), tostring(err)))
		return Enum.ContentTrackingError.Untrackable
	end

	return err
end

-- One appearance can come from a raid drop, a vendor, a quest or the catalyst.
-- When the source a set names cannot be tracked, another source of the same look
-- usually can, so those are worth a try before writing the piece off.
--
-- Returns the tracking error when the piece could not be started at all, or nil
-- once it is tracked. The second return marks a piece another source of the same
-- look already covers, so it is tracked but nothing changed.
local function TrackAppearance(sourceID)
	local err = StartTracking(sourceID)
	if not err then return end

	local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
	local visualID = sourceInfo and sourceInfo.visualID
	local alternates = visualID and C_TransmogCollection.GetAllAppearanceSources(visualID) or {}

	for _, alternateID in ipairs(alternates) do
		if alternateID ~= sourceID then
			if C_ContentTracking.IsTracking(APPEARANCE, alternateID) then return nil, true end
			if not StartTracking(alternateID) then
				addon.DevLog(("Tracked source %d in place of untrackable %d"):format(alternateID, sourceID))
				return
			end
		end
	end

	return err
end

local function IsWorthTracking(appearance)
	return not appearance.collected
		and not C_ContentTracking.IsTracking(APPEARANCE, appearance.appearanceID)
end

--- Tracks every appearance in the list that is not already collected or tracked.
function SetTracking:TrackAppearances(appearances, setName)
	setName = setName or ""

	if not appearances then
		addon.DevLog(("No appearance data for set %s"):format(setName))
		return
	end

	local tracked, skipped, lastError = 0, 0, nil
	for _, appearance in ipairs(appearances) do
		if IsWorthTracking(appearance) then
			local err, alreadyTracked = TrackAppearance(appearance.appearanceID)
			if err then
				skipped = skipped + 1
				lastError = err
			elseif not alreadyTracked then
				tracked = tracked + 1
			end
		end
	end

	if tracked == 0 then
		if lastError then
			ContentTrackingUtil.DisplayTrackingError(lastError)
		else
			Announce(L["Nothing new to track from %s."]:format(setName))
		end
		return
	end

	local message = (tracked == 1 and L["Now tracking %d appearance from %s."]
		or L["Now tracking %d appearances from %s."]):format(tracked, setName)
	if skipped > 0 then
		message = message .. " " .. L["%d could not be tracked."]:format(skipped)
	end

	Announce(message)
	PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
end

function SetTracking:TrackSet(setID)
	local setInfo = addon.C_TransmogSets.GetSetInfo(setID)
	self:TrackAppearances(addon.C_TransmogSets.GetSetPrimaryAppearances(setID), setInfo and setInfo.name)
end

-- A list row carries the base set, but a raid set's Heroic and Mythic variants
-- are separate appearances. Track whichever variant clicking the row would have
-- opened, which is the one the player takes themselves to be clicking. Only
-- Blizzard sets have variants; the addon's own extra sets go as they are.
function SetTracking:TrackSetRow(setID)
	if not setID then return end

	local setData = addon.GetSetInfo(setID)
	local sets = BetterWardrobeCollectionFrame.SetsCollectionFrame
	if sets and setData and setData.setType == "Blizzard" then
		setID = sets:GetDefaultSetIDForBaseSet(setID) or setID
	end

	self:TrackSet(setID)
end

--- A set tile at the transmog NPC, which carries its appearance data with it.
function SetTracking:TrackSetTile(elementData)
	local setID = elementData.setID or (elementData.set and elementData.set.setID)
	local appearances = elementData.sourceData and elementData.sourceData.primaryAppearances
	if not appearances then
		if not setID then return end
		appearances = addon.C_TransmogSets.GetSetPrimaryAppearances(setID)
	end

	local setInfo = setID and addon.C_TransmogSets.GetSetInfo(setID)
	self:TrackAppearances(appearances, elementData.name or (setInfo and setInfo.name))
end

--- A single piece in the set details pane.
function SetTracking:TrackPiece(sourceID, collected)
	local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
	local name = (sourceInfo and sourceInfo.name) or tostring(sourceID)

	if collected or C_ContentTracking.IsTracking(APPEARANCE, sourceID) then
		Announce(L["%s is already collected or being tracked."]:format(name))
		return
	end

	local err, alreadyTracked = TrackAppearance(sourceID)
	if err then
		ContentTrackingUtil.DisplayTrackingError(err)
		return
	end

	if alreadyTracked then
		Announce(L["%s is already collected or being tracked."]:format(name))
		return
	end

	Announce(L["Now tracking %s."]:format(name))
	PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
end
