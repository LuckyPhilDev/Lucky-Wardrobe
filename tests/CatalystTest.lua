-- Covers the chain from an item in the bags to the piece the catalyst would turn
-- it into: which items count, which sources come back, and every way the answer
-- can be unavailable without becoming a wrong answer.

local addon = {
	Profile = { MarkCatalysablePieces = true },
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

_G.UnitClass = function() return "Warrior", "WARRIOR", 1 end
_G.NUM_BAG_SLOTS = 4
_G.INVSLOT_FIRST_EQUIPPED, _G.INVSLOT_LAST_EQUIPPED = 1, 19

local HELM = "|Hitem:1|h[Season Helm]|h"
local JUNK = "|Hitem:2|h[Junk]|h"
local CHEST = "|Hitem:3|h[Worn Chest]|h"
local KNOWN = "|Hitem:4|h[Already Known]|h"
local OTHER_SEASON = "|Hitem:5|h[Last Season Gloves]|h"
local OLD_SEASON = "|Hitem:6|h[Older Season Legs]|h"

local HELM_SLOT, CHEST_SLOT, HAND_SLOT, LEG_SLOT = 1, 5, 10, 7

-- What Transmog Upgrade Master says about each item. Only the fields this addon
-- reads are filled in; the real answer carries several more.
local CATALYST = {
	[HELM] = { canCatalyse = true, catalystAppearanceMissing = true,
		contextData = { seasonID = 26, tier = 3, slot = HELM_SLOT } },
	[JUNK] = { canCatalyse = false },
	[CHEST] = { canCatalyse = true, catalystAppearanceMissing = true,
		contextData = { seasonID = 26, tier = 3, slot = CHEST_SLOT } },
	-- Catalysable, but the appearance it makes is one the player already has.
	[KNOWN] = { canCatalyse = true, catalystAppearanceMissing = false,
		contextData = { seasonID = 26, tier = 3, slot = HAND_SLOT } },
	-- An older season, which catalyses into that season's set rather than this one's.
	[OTHER_SEASON] = { canCatalyse = true, catalystAppearanceMissing = true,
		contextData = { seasonID = 25, tier = 3, slot = LEG_SLOT } },
	-- Older still: a season described only by the catalyst's own items.
	[OLD_SEASON] = { canCatalyse = true, catalystAppearanceMissing = true,
		contextData = { seasonID = 24, tier = 3, slot = LEG_SLOT } },
}

local bags = { [0] = { HELM, JUNK } }
local equipped = { [CHEST_SLOT] = CHEST }

_G.C_Container = {
	GetContainerNumSlots = function(bag) return bags[bag] and #bags[bag] or 0 end,
	GetContainerItemLink = function(bag, slot) return bags[bag] and bags[bag][slot] or nil end,
}
_G.GetInventoryItemLink = function(_, slot) return equipped[slot] end

-- Tier 3 of season 26 is set 700, and of season 25 is set 600. Season 24 is old
-- enough that it is listed only as the catalyst's own items, one per slot, which
-- is how every season before the last few is described.
local SETS = { [26] = { [1] = 500, [3] = 700 }, [25] = { [3] = 600 } }
local CATALYST_ITEMS = { [24] = { [1] = { [LEG_SLOT] = 8800 } } }
local ITEM_SOURCE_IDS = { [8800] = { [1] = 81, [3] = 83 } }

_G.TransmogUpgradeMaster = {
	catalystItems = CATALYST_ITEMS,
	GetSetsForClass = function(_, classID, seasonID)
		assert(classID == 1, "the player's class should be the one asked about")
		return SETS[seasonID]
	end,
	GetSourceIDsForItemID = function(_, itemID) return ITEM_SOURCE_IDS[itemID] end,
}

local COLLECTED_SOURCES = {}
_G.C_TransmogCollection = {
	GetSourceInfo = function(sourceID)
		return { sourceID = sourceID, isCollected = COLLECTED_SOURCES[sourceID] or false }
	end,
}

local SOURCES = {
	[700] = {
		[HELM_SLOT] = { { sourceID = 71, isCollected = false } },
		-- Two versions of the slot, one of which is already known. The catalyst
		-- teaches an appearance, so a version already collected is not news.
		[CHEST_SLOT] = { { sourceID = 75, isCollected = false }, { sourceID = 76, isCollected = true } },
		[HAND_SLOT] = { { sourceID = 77, isCollected = false } },
	},
	[600] = { [LEG_SLOT] = { { sourceID = 63, isCollected = false } } },
}

-- A source reached through the catalyst item table still belongs to a set as far
-- as Blizzard is concerned, which is what the row count is built from.
local SETS_BY_SOURCE = { [83] = 650 }

_G.C_TransmogSets = {
	GetSourcesForSlot = function(setID, slot) return SOURCES[setID] and SOURCES[setID][slot] or {} end,
	GetSetsContainingSourceID = function(sourceID)
		if SETS_BY_SOURCE[sourceID] then return { SETS_BY_SOURCE[sourceID] } end
		for setID, slots in pairs(SOURCES) do
			for _, sources in pairs(slots) do
				for _, source in ipairs(sources) do
					if source.sourceID == sourceID then return { setID } end
				end
			end
		end
		return {}
	end,
}

local warm = true
_G.TransmogUpgradeMaster_API = {
	IsCacheWarmedUp = function() return warm, warm and 1 or 0.5 end,
	GetAppearanceMissingData = function(itemLink) return CATALYST[itemLink] or {} end,
	IsAppearanceMissing = function(itemLink)
		local data = CATALYST[itemLink] or {}
		return data.canCatalyse, data.canUpgrade, data.catalystAppearanceMissing
	end,
}

local realPrint = print
assert(loadfile("src/Modules/Catalyst.lua"))("LuckyTest", addon)
local Catalyst = addon.Catalyst

local function Targets()
	Catalyst:ForgetHeldTargets()
	return Catalyst:GetHeldTargets()
end

-- A held item that would catalyse into a piece resolves to that piece's source,
-- from the bags and from what is worn alike.
local targets = Targets()
assert(targets.bySource[71] == HELM, "the bagged helm should map to the set's helm source")
assert(targets.bySource[75] == CHEST, "worn gear should count the same as bagged gear")
assert(targets.items == 2, "two held items should have mapped, got " .. targets.items)

-- The version of the slot already collected is not something to point at.
assert(targets.bySource[76] == nil, "a collected source should not be marked")

-- Catalysable but teaching nothing already known stays out.
assert(targets.bySource[77] == nil, "an appearance already known should not be marked")

-- The count per set is what the row tooltip reports.
assert(targets.bySet[700] == 2, "both pieces belong to set 700")

-- An item from an older season catalyses into that season's set, not this one's.
bags[0] = { OTHER_SEASON }
equipped = {}
targets = Targets()
assert(targets.bySource[63] == OTHER_SEASON, "an older season should resolve to its own set")
assert(targets.bySet[600] == 1)
assert(targets.bySet[700] == nil, "the current season's set should not be claimed")

-- A season too old to be listed as a set is described only by the catalyst's own
-- items, one per slot, and those carry their sources directly. Transmog Upgrade
-- Master answers yes for these the same as any other, so a piece it vouches for
-- has to be found through that table rather than going unmarked.
bags[0] = { OLD_SEASON }
targets = Targets()
assert(targets.bySource[83] == OLD_SEASON,
	"a season listed only as catalyst items should still resolve to its piece")
assert(targets.bySet[650] == 1, "the piece should still be counted against its set")
assert(targets.items == 1)

-- The tier picks which source out of that item, the same as it picks the set.
assert(targets.bySource[81] == nil, "the wrong tier's source was marked")

-- Already collected is already collected, whichever table found it.
COLLECTED_SOURCES[83] = true
assert(next(Targets().bySource) == nil, "a collected source reached this way was marked")
COLLECTED_SOURCES[83] = false

-- An item nothing can be made of contributes nothing.
bags[0] = { JUNK }
targets = Targets()
assert(next(targets.bySource) == nil and targets.items == 0)

bags[0] = { HELM }
equipped = { [CHEST_SLOT] = CHEST }

-- The answer is held onto until something says what is carried has changed, since
-- it costs a lookup per item in the bags.
local first = Catalyst:GetHeldTargets()
assert(Catalyst:GetHeldTargets() == first, "the scan should not repeat itself")
Catalyst:ForgetHeldTargets()
assert(Catalyst:GetHeldTargets() ~= first, "forgetting should force a fresh scan")

-- While the cache is still loading the answer is nothing rather than a wrong
-- something, and it is not remembered, so the next ask tries again.
warm = false
targets = Targets()
assert(next(targets.bySource) == nil, "answered from a cache that was still loading")
warm = true
assert(Catalyst:GetHeldTargets().bySource[71] == HELM, "an empty answer should not have been cached")

-- Without the addon there is nothing to ask and nothing is claimed.
local api = _G.TransmogUpgradeMaster_API
_G.TransmogUpgradeMaster_API = nil
assert(not Catalyst:IsAvailable())
assert(next(Targets().bySource) == nil, "claimed a catalyst target with no catalyst data")
assert(not Catalyst:WouldTeachAppearance(HELM))
assert(Catalyst:Inspect(HELM).available == false)
_G.TransmogUpgradeMaster_API = api
assert(Catalyst:IsAvailable())

-- The set table is the half of this that was never promised to stay put. When it
-- moves, the pieces go unmarked; the yes-or-no the alerts run on is untouched.
local tum = _G.TransmogUpgradeMaster
_G.TransmogUpgradeMaster = nil
assert(next(Targets().bySource) == nil, "marked a piece without knowing which set it belongs to")
assert(Catalyst:WouldTeachAppearance(HELM), "the alert should not need the set table")

_G.TransmogUpgradeMaster = { GetSetsForClass = function() error("moved") end }
assert(next(Targets().bySource) == nil, "a set lookup that threw should mark nothing")
assert(Catalyst:WouldTeachAppearance(HELM))
_G.TransmogUpgradeMaster = tum

-- A lookup that throws is an answer that cannot be trusted, not a yes.
_G.TransmogUpgradeMaster_API.GetAppearanceMissingData = function() error("boom") end
assert(next(Targets().bySource) == nil, "a lookup that threw was treated as a target")

_G.TransmogUpgradeMaster_API.IsAppearanceMissing = function() error("boom") end
assert(not Catalyst:WouldTeachAppearance(HELM), "a lookup that threw was treated as a yes")

-- Transmog Upgrade Master answers nil for canCatalyse only where it could not
-- read the item at all, and false where it read it and the answer is no. The
-- report has to keep them apart: one says ask again later, the other says the
-- item is understood and simply does not qualify.
_G.TransmogUpgradeMaster_API = {
	IsCacheWarmedUp = function() return true, 1 end,
	IsAppearanceMissing = function() return nil, nil, nil end,
}
local unread = Catalyst:Inspect("|Hitem:900|h[Unread]|h")
assert(unread.ok, "a clean call should report ok")
assert(unread.canCatalyse == nil, "an item TUM could not read should stay nil")

_G.TransmogUpgradeMaster_API.IsAppearanceMissing = function() return false, false, nil end
local answered = Catalyst:Inspect("|Hitem:901|h[Answered]|h")
assert(answered.canCatalyse == false,
	"an item TUM read and rejected should report false, not nil")
assert(answered.canUpgrade == false, "canUpgrade should survive being false too")

-- A catalysable item reports what it can do, and the missing flag comes through.
_G.TransmogUpgradeMaster_API.IsAppearanceMissing = function() return true, false, true end
local inspected = Catalyst:Inspect("|Hitem:902|h[Catalysable]|h")
assert(inspected.canCatalyse == true and inspected.catalystMissing == true)

-- A link built from an item ID alone carries no bonus IDs, which is the whole
-- reason nothing can be decided about it. The real thing carries several.
_G.TransmogUpgradeMaster_API.IsAppearanceMissing = function() return false, false, nil end
assert(Catalyst:Inspect("|Hitem:195515|h[Sash]|h").bonusIDs == 0,
	"a bare link should report no bonus IDs")

local realLink = "|cffa335ee|Hitem:195515::::::::80:264::14:3:8836:8840:8902:1:28:2462:::|h[Sash]|h|r"
assert(Catalyst:Inspect(realLink).bonusIDs == 3,
	"a real item link should report the bonus IDs it carries")

-- A call that throws keeps its error where the report can show it, rather than
-- reading as an item that answered no.
_G.TransmogUpgradeMaster_API.IsAppearanceMissing = function() error("boom", 0) end
local failed = Catalyst:Inspect("|Hitem:903|h[Broken]|h")
assert(not failed.ok, "a throwing call should not report ok")
assert(tostring(failed.err):find("boom", 1, true), "the error should be kept")
_G.TransmogUpgradeMaster_API = nil

realPrint("CatalystTest passed")
