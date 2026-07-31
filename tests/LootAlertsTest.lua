-- Covers what decides an alert: whose loot it is, whether the item finishes a
-- tracked set, which way the alert speaks, and what happens when the catalyst
-- source is absent.

local addon = {
	Profile = {
		AlertSetPieceLoot = true,
		AlertCatalystLoot = true,
		AlertWithSound = true,
		AlertWithChat = true,
	},
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

_G.UNKNOWN = "Unknown"
_G.LOOT_ITEM_SELF = "You receive loot: %s."
_G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
_G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."

local played = {}
_G.SOUNDKIT = { UI_LEGENDARY_LOOT_TOAST = 1, UI_EPICLOOT_TOAST = 2 }
_G.LuckySound = { PlayKit = function(_, kit) played[#played + 1] = kit end }

-- The module announces through print, so the real one is kept to report with.
local realPrint = print
local printed = {}
_G.print = function(text) printed[#printed + 1] = text end

local clock = 1000
_G.GetTime = function() return clock end

-- sourceID 10 finishes a tracked set; 20 is an item nothing wants.
local ITEMS = {
	["|Hitem:100|h[Wanted]|h"] = { visualID = 500, sourceID = 10 },
	["|Hitem:200|h[Ignored]|h"] = { visualID = 600, sourceID = 20 },
	["|Hitem:300|h[Lookalike]|h"] = { visualID = 500, sourceID = 30 },
}

_G.C_TransmogCollection = {
	GetItemInfo = function(itemLink)
		local entry = ITEMS[itemLink]
		if not entry then return nil, nil end
		return entry.visualID, entry.sourceID
	end,
}

-- The set sourceID 10 belongs to. Its own piece is still counted among the
-- missing, which is what the real scan reports while the piece is uncollected.
local trackedSet = { name = "Tracked Set", total = 5, missing = { 10 } }

local flashed = {}
addon.SetCompletion = {
	GetWantedPieces = function()
		return {
			bySource = { [10] = trackedSet },
			byVisual = { [500] = trackedSet },
			sourceByVisual = { [500] = 10 },
		}
	end,
	FlashPiece = function(_, sourceID) flashed[#flashed + 1] = sourceID end,
}

local registered
_G.CreateFrame = function()
	return {
		RegisterEvent = function() end,
		SetScript = function(_, _, handler) registered = handler end,
	}
end

assert(loadfile("src/Modules/LootAlerts.lua"))("LuckyTest", addon)
addon:InitLootAlerts()
assert(registered, "the loot handler was never registered")

local function Loot(message)
	played, printed, flashed = {}, {}, {}
	clock = clock + 100
	registered(nil, "CHAT_MSG_LOOT", message)
end

-- The player's own loot speaks, in both the "receive loot" and "receive item" forms.
Loot("You receive loot: |Hitem:100|h[Wanted]|h.")
assert(#played == 1 and played[1] == SOUNDKIT.UI_LEGENDARY_LOOT_TOAST)
assert(#printed == 1 and printed[1]:find("Tracked Set", 1, true))

Loot("You receive item: |Hitem:100|h[Wanted]|h.")
assert(#played == 1, "the pushed-item form should alert too")

Loot("You receive loot: |Hitem:100|h[Wanted]|hx2.")
assert(#played == 1, "the multiple form should alert too")

-- Someone else's loot is not the player's business.
Loot("Grazzik receives loot: |Hitem:100|h[Wanted]|h.")
assert(#played == 0, "another player's loot alerted")

-- An item no tracked set wants stays quiet.
Loot("You receive loot: |Hitem:200|h[Ignored]|h.")
assert(#played == 0, "an untracked item alerted")

-- A different item teaching the same appearance still finishes the set, and the
-- panel lights up the set's own piece rather than the item that happened to drop.
Loot("You receive loot: |Hitem:300|h[Lookalike]|h.")
assert(#played == 1, "a lookalike teaching the same appearance should alert")
assert(flashed[1] == 10, "the set's piece should be the one flashed")

-- The piece itself flashes where it is the thing that dropped.
Loot("You receive loot: |Hitem:100|h[Wanted]|h.")
assert(flashed[1] == 10)

-- The last piece left says the set is finished.
Loot("You receive loot: |Hitem:100|h[Wanted]|h.")
assert(printed[1]:find("finishes", 1, true), "the last piece should report a finished set")

-- With more still to find it counts what is left instead, and does not count the
-- piece that just dropped among them.
trackedSet.missing = { 10, 11, 12 }
Loot("You receive loot: |Hitem:100|h[Wanted]|h.")
assert(printed[1]:find("2 still missing", 1, true),
	"the alert should count what is left after this drop, got: " .. tostring(printed[1]))
assert(not printed[1]:find("finishes", 1, true), "an unfinished set should not claim a finish")
trackedSet.missing = { 10 }

-- The same item arriving twice in quick succession only speaks once. Past the
-- silence first, so the pair starts from a clean slate rather than a spent one.
clock = clock + 100
played, printed = {}, {}
registered(nil, "CHAT_MSG_LOOT", "You receive loot: |Hitem:100|h[Wanted]|h.")
registered(nil, "CHAT_MSG_LOOT", "You receive loot: |Hitem:100|h[Wanted]|h.")
assert(#played == 1, "a repeated loot line alerted twice")

-- Turning the alert off silences it.
addon.Profile.AlertSetPieceLoot = false
Loot("You receive loot: |Hitem:100|h[Wanted]|h.")
assert(#played == 0, "the setting did not silence the alert")
addon.Profile.AlertSetPieceLoot = true

-- Each way of speaking can be turned off without taking the other with it, and
-- the panel highlight is not one of them: it belongs to the piece, not the noise.
addon.Profile.AlertWithChat = false
Loot("You receive loot: |Hitem:100|h[Wanted]|h.")
assert(#played == 1 and #printed == 0, "the chat line should be the only thing silenced")
assert(flashed[1] == 10, "the highlight should survive a silenced chat line")
addon.Profile.AlertWithChat = true

addon.Profile.AlertWithSound = false
Loot("You receive loot: |Hitem:100|h[Wanted]|h.")
assert(#printed == 1 and #played == 0, "the sound should be the only thing silenced")
addon.Profile.AlertWithSound = true

-- Without Transmog Upgrade Master there is no way to know what the catalyst
-- makes, so the catalyst alert stays silent rather than guessing.
assert(not addon.LootAlerts:IsCatalystSourceAvailable())
Loot("You receive loot: |Hitem:200|h[Ignored]|h.")
assert(#played == 0, "a catalyst alert fired with no source of catalyst data")

-- With it present, an item it vouches for alerts with the quieter sound.
_G.TransmogUpgradeMaster_API = {
	IsCacheWarmedUp = function() return true end,
	IsAppearanceMissing = function() return true, false, true end,
}
assert(addon.LootAlerts:IsCatalystSourceAvailable())
Loot("You receive loot: |Hitem:200|h[Ignored]|h.")
assert(#played == 1 and played[1] == SOUNDKIT.UI_EPICLOOT_TOAST)

-- A piece of the set outranks a way of making one, so only one sound plays.
Loot("You receive loot: |Hitem:100|h[Wanted]|h.")
assert(#played == 1 and played[1] == SOUNDKIT.UI_LEGENDARY_LOOT_TOAST)

-- While its cache is still loading it answers nil, which must not read as "no".
_G.TransmogUpgradeMaster_API.IsCacheWarmedUp = function() return false end
Loot("You receive loot: |Hitem:200|h[Ignored]|h.")
assert(#played == 0, "alerted on an answer the cache could not yet give")

-- Simulating a drop goes through the same parsing and reports what it decided,
-- and lifts the repeat silence so the same item can be fired again on purpose.
_G.TransmogUpgradeMaster_API = nil
played, printed = {}, {}
local outcome, match = addon.LootAlerts:SimulateLoot("|Hitem:100|h[Wanted]|h")
assert(outcome == "set" and match.name == "Tracked Set")
assert(#played == 1)

played = {}
outcome = addon.LootAlerts:SimulateLoot("|Hitem:100|h[Wanted]|h")
assert(outcome == "set" and #played == 1, "a repeat simulation should not be silenced")

outcome = addon.LootAlerts:SimulateLoot("|Hitem:200|h[Ignored]|h")
assert(outcome == "nothing")

-- A raid set's difficulties share item IDs, so a link built from an ID alone
-- resolves to the wrong one. A caller that already knows which piece it means
-- says so, and that wins over what the link reads as.
flashed = {}
outcome = addon.LootAlerts:SimulateLoot("|Hitem:200|h[Ignored]|h", 10)
assert(outcome == "set", "the known source should have been used over the link's")
assert(flashed[1] == 10, "the known source should be the one flashed")

-- Transmog Upgrade Master answers nil for canCatalyse only where it could not
-- read the item at all, and false where it read it and the answer is no. The
-- report has to keep them apart: one says ask again later, the other says the
-- item is understood and simply does not qualify.
_G.TransmogUpgradeMaster_API = {
	IsCacheWarmedUp = function() return true, 1 end,
	IsAppearanceMissing = function() return nil, nil, nil end,
}
local unread = addon.LootAlerts:InspectCatalyst("|Hitem:900|h[Unread]|h")
assert(unread.ok, "a clean call should report ok")
assert(unread.canCatalyse == nil, "an item TUM could not read should stay nil")

_G.TransmogUpgradeMaster_API.IsAppearanceMissing = function() return false, false, nil end
local answered = addon.LootAlerts:InspectCatalyst("|Hitem:901|h[Answered]|h")
assert(answered.canCatalyse == false,
	"an item TUM read and rejected should report false, not nil")
assert(answered.canUpgrade == false, "canUpgrade should survive being false too")

-- A catalysable item reports what it can do, and the missing flag comes through.
_G.TransmogUpgradeMaster_API.IsAppearanceMissing = function() return true, false, true end
local catalysable = addon.LootAlerts:InspectCatalyst("|Hitem:902|h[Catalysable]|h")
assert(catalysable.canCatalyse == true and catalysable.catalystMissing == true)

-- A link built from an item ID alone carries no bonus IDs, which is the whole
-- reason nothing can be decided about it. The real thing carries several.
_G.TransmogUpgradeMaster_API.IsAppearanceMissing = function() return false, false, nil end
assert(addon.LootAlerts:InspectCatalyst("|Hitem:195515|h[Sash]|h").bonusIDs == 0,
	"a bare link should report no bonus IDs")

local realLink = "|cffa335ee|Hitem:195515::::::::80:264::14:3:8836:8840:8902:1:28:2462:::|h[Sash]|h|r"
assert(addon.LootAlerts:InspectCatalyst(realLink).bonusIDs == 3,
	"a real item link should report the bonus IDs it carries")

-- A call that throws keeps its error where the report can show it, rather than
-- reading as an item that answered no.
_G.TransmogUpgradeMaster_API.IsAppearanceMissing = function() error("boom", 0) end
local failed = addon.LootAlerts:InspectCatalyst("|Hitem:903|h[Broken]|h")
assert(not failed.ok, "a throwing call should not report ok")
assert(tostring(failed.err):find("boom", 1, true), "the error should be kept")
_G.TransmogUpgradeMaster_API = nil

realPrint("LootAlertsTest passed")
