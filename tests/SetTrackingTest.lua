-- Covers what a shift-click tracks: which pieces of a set are worth starting on,
-- what happens to a piece whose named source refuses, and how the row, the
-- transmog NPC tile and a single piece each reach the same tracking.

local addon = {
	Profile = { TrackSetsOnShiftClick = true },
	PREFIX = "test",
	DevLog = function() end,
}

_G.LibStub = function(name)
	if name == "AceAddon-3.0" then
		return { NewAddon = function(_, target) return target end, GetAddon = function() return addon end }
	end
	return { GetLocale = function()
		return setmetatable({}, { __index = function(_, key) return key end })
	end }
end

_G.Enum = {
	ContentTrackingType = { Appearance = 1 },
	ContentTrackingError = { Untrackable = 2 },
}
_G.SOUNDKIT = { UI_TRANSMOG_ITEM_CLICK = 1 }
_G.PlaySound = function() end

local shiftDown = true
_G.IsShiftKeyDown = function() return shiftDown end

local printed = {}
local realPrint = print
_G.print = function(text) printed[#printed + 1] = text end

local trackingErrors = {}
_G.ContentTrackingUtil = {
	DisplayTrackingError = function(err) trackingErrors[#trackingErrors + 1] = err end,
}

-- Sources 1 to 4 are a four-piece set. 2 is already collected. 3 cannot be
-- tracked from the source the set names, but shares its look with 30, which can.
-- 4 is not collectable by this character at all.
local SOURCES = {
	[1] = { name = "Helm", visualID = 100, playerCanCollect = true },
	[2] = { name = "Chest", visualID = 200, playerCanCollect = true },
	[3] = { name = "Gloves", visualID = 300, playerCanCollect = true },
	[4] = { name = "Boots", visualID = 400, playerCanCollect = false },
	[30] = { name = "Gloves (vendor)", visualID = 300, playerCanCollect = true },
}

local REFUSED = { [3] = true }
local ALTERNATES = { [300] = { 3, 30 } }

_G.C_TransmogCollection = {
	GetSourceInfo = function(sourceID) return SOURCES[sourceID] end,
	GetAllAppearanceSources = function(visualID) return ALTERNATES[visualID] end,
}

local tracking = {}
_G.C_ContentTracking = {
	IsTracking = function(_, sourceID) return tracking[sourceID] or false end,
	StartTracking = function(_, sourceID)
		-- The real one raises rather than returning for some sources, which is the
		-- case the module has to survive to finish the rest of a set.
		if REFUSED[sourceID] then error("cannot track " .. sourceID) end
		tracking[sourceID] = true
	end,
}

local SET = {
	[10] = { name = "Normal Set", setType = "Blizzard", appearances = { 1, 2, 3, 4 } },
	[11] = { name = "Mythic Set", setType = "Blizzard", appearances = { 1 } },
	[20] = { name = "Curated Set", setType = "Extra", appearances = { 3 } },
}
local COLLECTED = { [2] = true }

addon.GetSetInfo = function(setID) return SET[setID] end

addon.C_TransmogSets = {
	GetSetInfo = function(setID) return SET[setID] end,
	GetSetPrimaryAppearances = function(setID)
		local set = SET[setID]
		if not set then return nil end

		local appearances = {}
		for _, sourceID in ipairs(set.appearances) do
			appearances[#appearances + 1] = { appearanceID = sourceID, collected = COLLECTED[sourceID] or false }
		end
		return appearances
	end,
}

-- The list row hands over a base set; the frame decides which variant that row
-- would actually have opened.
local defaultVariant = 10
_G.BetterWardrobeCollectionFrame = {
	selectedCollectionTab = 2,
	SetsCollectionFrame = {
		GetDefaultSetIDForBaseSet = function() return defaultVariant end,
	},
}

assert(loadfile("src/Modules/SetTracking.lua"))("LuckyTest", addon)
local SetTracking = addon.SetTracking

local function Reset()
	tracking, printed, trackingErrors = {}, {}, {}
end

-- The locale stub answers with the key, so a message arrives as that key with its
-- placeholders filled in.
local function Said(text)
	return printed[1] and printed[1]:find(text, 1, true) ~= nil
end

-- Only a shift plus the left button, and only while the setting is on.
assert(SetTracking:WantsTracking("LeftButton"))
assert(not SetTracking:WantsTracking("RightButton"))
shiftDown = false
assert(not SetTracking:WantsTracking("LeftButton"))
shiftDown = true
addon.Profile.TrackSetsOnShiftClick = false
assert(not SetTracking:WantsTracking("LeftButton"))
addon.Profile.TrackSetsOnShiftClick = true

-- A whole set: the collected piece is left alone, the refused piece falls
-- through to the other source of the same look, and the uncollectable one is
-- reported as skipped rather than stopping the rest.
Reset()
SetTracking:TrackSetRow(10)
assert(tracking[1], "the missing piece should be tracked")
assert(not tracking[2], "an already collected piece should be left alone")
assert(tracking[30], "the alternate source should have been used")
assert(not tracking[4], "an uncollectable piece cannot be tracked")
assert(#printed == 1 and Said("Now tracking 2 appearances from Normal Set."))
assert(Said("1 could not be tracked."), "the skipped piece should be reported")

-- A row on a Blizzard set tracks the variant that row opens, not the base.
Reset()
defaultVariant = 11
SetTracking:TrackSetRow(10)
assert(tracking[1] and not tracking[30], "only the variant's own piece should be tracked")
assert(Said("Now tracking 1 appearance from Mythic Set."))

-- Running it again finds nothing left to start.
Reset()
tracking[1] = true
SetTracking:TrackSetRow(10)
assert(#printed == 1 and Said("Nothing new to track from Mythic Set."))
defaultVariant = 10

-- A piece already covered by another source of the same look is not counted as
-- newly tracked, so a second pass over the set says so rather than claiming work.
Reset()
tracking[1], tracking[30] = true, true
SetTracking:TrackSetRow(10)
assert(not Said("Now tracking"), "nothing changed, so nothing should be announced as tracked")
assert(trackingErrors[1] == Enum.ContentTrackingError.Untrackable,
	"the piece this character cannot collect is still the reason nothing happened")

-- The addon's own sets have no variants, so their rows go as they are.
Reset()
defaultVariant = 11
SetTracking:TrackSetRow(20)
assert(tracking[30], "an extra set should not have been rerouted to a Blizzard variant")
assert(Said("Now tracking 1 appearance from Curated Set."))
defaultVariant = 10

-- A tile at the transmog NPC carries its own appearance list, and uses it.
Reset()
SetTracking:TrackSetTile({
	setID = 10,
	name = "Tile Set",
	sourceData = { primaryAppearances = { { appearanceID = 1, collected = false } } },
})
assert(tracking[1] and not tracking[30], "only the tile's own appearances should be tracked")
assert(Said("Now tracking 1 appearance from Tile Set."))

-- A tile with no appearance data of its own falls back to the set's.
Reset()
SetTracking:TrackSetTile({ set = { setID = 10 } })
assert(tracking[1] and tracking[30])

-- A single piece, and one that is already collected.
Reset()
SetTracking:TrackPiece(1, false)
assert(tracking[1] and #printed == 1 and Said("Now tracking Helm."))

Reset()
SetTracking:TrackPiece(2, true)
assert(not tracking[2] and Said("Chest is already collected or being tracked."))

-- A piece with nowhere left to try reports the game's own error rather than
-- claiming success.
Reset()
SetTracking:TrackPiece(4, false)
assert(#printed == 0 and trackingErrors[1] == Enum.ContentTrackingError.Untrackable)

realPrint("SetTrackingTest passed")
