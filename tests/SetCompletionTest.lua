-- Covers the instance scan: which sets qualify, which pieces count as dropping
-- here, and the order they come back in. The panel is not exercised; everything
-- below the UI split is.

local addon = {
	-- Everything below the tier block wants to see every set that qualifies,
	-- including the current tier's, which is left out by default.
	Profile = { InstanceSetsMaxMissing = 3, IncludeCurrentTier = true },
	Globals = { BASE_SETS_TAB = 2, EXTRA_SETS_TAB = 3 },
	PREFIX = "test",
	DevLog = function() end,
}

_G.LibStub = function(name)
	if name == "AceAddon-3.0" then
		return { NewAddon = function(_, target) return target end, GetAddon = function() return addon end }
	end
	return { GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end }
end
_G.Enum = setmetatable({}, { __index = function(enum, key)
	local values = setmetatable({}, { __index = function() return 0 end })
	rawset(enum, key, values)
	return values
end })
_G.CreateColor = function(...) return { ... } end
_G.EJ_GetInvTypeSortOrder = function() return 1 end
_G.C_Item = {
	GetItemInfoInstant = function(itemID) return itemID, nil, nil, nil, "icon" .. itemID end,
	RequestLoadItemDataByID = function() end,
}
_G.CreateFrame = function() return setmetatable({}, { __index = function() return function() end end }) end
_G.UISpecialFrames = {}
-- A 12.0.7 client, so the tier being played right now is anything from 12.0.
_G.GetBuildInfo = function() return "12.0.7", "60000", "Jan 1 2026", 120007 end
_G.UNKNOWN = "Unknown"
_G.C_Timer = { After = function() end }
_G.LuckyUI = {
	C = setmetatable({}, { __index = function() return { 0, 0, 0 } end }),
	WC = setmetatable({}, { __index = function() return "" end }),
	BODY_FONT = "font",
	CreatePanel = function() return _G.CreateFrame() end,
	CreateHeader = function() end,
	EnableDrag = function() end,
	CreateScrollList = function() return _G.CreateFrame() end,
}

assert(loadfile("src/Data/Globals.lua"))("LuckyTest", addon)

-- Two sets a boss can drop, one bought with honour, keyed the way the addon's
-- own set list is.
local SETS = {
	[100] = { setID = 100, name = "Nearly There", filter = addon.Filter.RAID, setType = "Blizzard",
		description = "Heroic", patchID = 120000 },
	[101] = { setID = 101, name = "Half Done", filter = addon.Filter.DUNGEON, setType = "Blizzard",
		patchID = 110200 },
	[102] = { setID = 102, name = "Honour Set", filter = addon.Filter.PVP, setType = "Blizzard" },
	[103] = { setID = 103, name = "Elsewhere", filter = addon.Filter.RAID, setType = "Blizzard" },
	[104] = { setID = 104, name = "Old Dungeon Set", filter = addon.Filter.CLASSIC, setType = "ExtraSet" },
	[105] = { setID = 105, name = "Finished", filter = addon.Filter.RAID, setType = "Blizzard" },
	[106] = { setID = 106, name = "Long Way Off", filter = addon.Filter.RAID, setType = "Blizzard" },
	-- Tier: made from a token, so no piece of it has drop data of its own. The
	-- set's source is the only thing tying it to the raid it comes from.
	-- Its patch is ahead of the client's, which is what an unreleased tier sitting
	-- in the data looks like. Not the tier being played, so never the current one.
	[107] = { setID = 107, name = "Tier This Difficulty", filter = addon.Filter.RAID,
		setType = "Blizzard", label = "The Vault", description = "Normal", patchID = 120100 },
	[108] = { setID = 108, name = "Tier Other Difficulty", filter = addon.Filter.RAID,
		setType = "Blizzard", label = "The Vault", description = "Mythic" },
	[109] = { setID = 109, name = "Tier Elsewhere", filter = addon.Filter.RAID,
		setType = "Blizzard", label = "A Different Raid", description = "Normal" },
	-- A family name rather than a place, which is what an extra set carries. It
	-- must not match an instance, and its pieces have real drop data anyway.
	[110] = { setID = 110, name = "Family Named Set", filter = addon.Filter.DUNGEON,
		setType = "Blizzard", label = "Warlords Dungeon Set" },
	-- Both: the set names this raid and one piece also has drop data.
	[111] = { setID = 111, name = "Named And Dropped", filter = addon.Filter.RAID,
		setType = "Blizzard", label = "The Vault", description = "Normal" },
}

-- sourceID -> collected
local APPEARANCES = {
	[100] = { [1] = true, [2] = true, [3] = true, [4] = false },
	[101] = { [5] = true, [6] = false, [7] = false, [8] = false },
	[102] = { [9] = false },
	[103] = { [10] = true, [11] = false },
	[104] = { [12] = false, [13] = false },
	[105] = { [14] = true, [15] = true },
	[106] = { [16] = false, [17] = false, [18] = false, [19] = false, [20] = false },
	[107] = { [21] = true, [22] = false, [23] = false },
	[108] = { [24] = true, [25] = false },
	[109] = { [26] = true, [27] = false },
	[110] = { [28] = true, [29] = false },
	[111] = { [30] = true, [31] = false, [32] = false },
}

local DROPS = {
	[4]  = { { instance = "The Vault", encounter = "The Warden", difficulties = {} } },
	[6]  = { { instance = "The Vault", encounter = "The Warden", difficulties = { "Heroic" } } },
	[7]  = { { instance = "The Vault", encounter = "The Gatekeeper", difficulties = {} } },
	[8]  = { { instance = "Somewhere Else", encounter = "A Boss", difficulties = {} } },
	[9]  = { { instance = "The Vault", encounter = "The Warden", difficulties = {} } },
	[11] = { { instance = "Somewhere Else", encounter = "A Boss", difficulties = {} } },
	-- Named as the Encounter Journal has it, not as the map is called.
	[12] = { { instance = "The Vault of Old", encounter = "The Warden", difficulties = {} } },
	[13] = { { instance = "The Vault of Old", encounter = "The Gatekeeper", difficulties = {} } },
	[16] = { { instance = "The Vault", encounter = "The Warden", difficulties = {} } },
	[17] = { { instance = "The Vault", encounter = "The Gatekeeper", difficulties = {} } },
	-- The extra set's pieces drop for real, in a dungeon that is not this one.
	[29] = { { instance = "Upper Blackrock Spire", encounter = "Kyrak", difficulties = {} } },
	[31] = { { instance = "The Vault", encounter = "The Warden", difficulties = {} } },
}

-- Appearances the player owns right now, which for an extra set is not what the
-- set data it was built with still says.
COLLECTED_NOW = {}

local dropLookups, lookedUp = 0, {}

addon.GetFullSets = function() return SETS end
addon.C_TransmogSets = {
	GetSetPrimaryAppearances = function(setID)
		local sources = APPEARANCES[setID]
		if not sources then return nil end

		local appearances = {}
		for sourceID, collected in pairs(sources) do
			appearances[#appearances + 1] = { appearanceID = sourceID, collected = collected }
		end
		table.sort(appearances, function(a, b) return a.appearanceID < b.appearanceID end)
		return appearances
	end,
}
_G.C_TransmogCollection = {
	GetAppearanceSourceDrops = function(sourceID)
		dropLookups = dropLookups + 1
		lookedUp[sourceID] = true
		return DROPS[sourceID]
	end,
	-- What an extra set's stored collected state is re-read against, and where the
	-- item behind a piece comes from.
	GetSourceInfo = function(sourceID)
		return {
			name = "Piece " .. sourceID,
			itemID = 1000 + sourceID,
			invType = "INVTYPE_CHEST",
			isCollected = COLLECTED_NOW[sourceID] or false,
		}
	end,
}

local playerDifficulty = "Normal"
local inInstance, instanceType = true, "raid"
_G.IsInInstance = function() return inInstance, instanceType end
_G.GetInstanceInfo = function() return "The Vault", "raid", 0, playerDifficulty end
_G.C_Map = { GetBestMapForUnit = function() return 42 end }
_G.EJ_GetInstanceForMap = function() return 7 end
_G.EJ_GetInstanceInfo = function() return "The Vault of Old" end

assert(loadfile("src/Modules/SetCompletion.lua"))("LuckyTest", addon)
local SetCompletion = addon.SetCompletion

-- The instance is only reported inside a dungeon or raid.
local instance = SetCompletion:GetCurrentInstance()
assert(instance.name == "The Vault")
assert(instance.journalName == "The Vault of Old")
assert(instance.difficulty == "Normal")

inInstance, instanceType = false, "none"
assert(SetCompletion:GetCurrentInstance() == nil)
inInstance, instanceType = true, "party"
assert(SetCompletion:GetCurrentInstance() ~= nil, "dungeons count as well as raids")
inInstance, instanceType = true, "pvp"
assert(SetCompletion:GetCurrentInstance() == nil, "battlegrounds are not instances for this")
inInstance, instanceType = true, "raid"

local matches = SetCompletion:Scan(instance)

local byName = {}
for _, match in ipairs(matches) do byName[match.name] = match end

-- A set whose last piece drops here comes back, and knows it is finished by it.
assert(byName["Nearly There"], "the set one piece short of done is missing")
assert(byName["Nearly There"].remaining == 0)
assert(byName["Nearly There"].collected == 3 and byName["Nearly There"].total == 4)

-- Three of four pieces missing, two of them here, so one is left over.
assert(byName["Half Done"], "a set within the missing-piece limit is missing")
assert(#byName["Half Done"].here == 2)
assert(byName["Half Done"].remaining == 1)

-- The Encounter Journal's name for the instance matches as well as the map's.
assert(byName["Old Dungeon Set"], "a set named by its journal instance did not match")
assert(byName["Old Dungeon Set"].isExtraSet)
assert(byName["Old Dungeon Set"].remaining == 0)

-- PvP sets are never boss drops, so the scan does not pay for a lookup on one,
-- even though this one's piece has drop data that would have matched.
assert(not byName["Honour Set"], "a PvP set was listed")
assert(DROPS[9][1].instance == "The Vault")
assert(not lookedUp[9], "a PvP set cost a drop lookup")

-- Sets past the missing-piece limit are skipped before the lookups too.
assert(not byName["Long Way Off"], "a set past the limit was listed")
assert(not lookedUp[16], "a set past the limit cost a drop lookup")

-- Nothing to show for a set that drops nowhere near here, or one already done.
assert(not byName["Elsewhere"], "a set with no pieces here was listed")
assert(not byName["Finished"], "a completed set was listed")
assert(#matches == 5)

-- Closest to done first, and a set that finishes here beats one that does not.
assert(matches[1].remaining == 0)
assert(matches[#matches].name == "Half Done")

-- A piece behind a difficulty this run isn't on still counts, and says so.
local halfDone = byName["Half Done"]
local notes = {}
for _, piece in ipairs(halfDone.here) do notes[piece.name] = piece.difficultyNote end
assert(notes["Piece 6"] == "Heroic", "a piece needing another difficulty said nothing")
assert(notes["Piece 7"] == nil, "a piece with no difficulty restriction was flagged")

playerDifficulty = "Heroic"
local onHeroic = SetCompletion:Scan(SetCompletion:GetCurrentInstance())
for _, match in ipairs(onHeroic) do
	if match.name == "Half Done" then
		for _, piece in ipairs(match.here) do
			assert(piece.difficultyNote == nil, "a Heroic piece was flagged while on Heroic")
		end
	end
end
playerDifficulty = "Normal"

-- The limit is what keeps the scan cheap, so it has to bite before the lookups.
dropLookups = 0
-- One piece short: only the boss drop. The three sets that are equally close all
-- belong to another raid, another difficulty, or another place entirely.
local tight = SetCompletion:Scan(instance, 1)
assert(#tight == 1 and tight[1].name == "Nearly There")
assert(dropLookups == 0, "results are cached, so a rescan re-reads nothing")

-- Tier has no drop data at all, so the set naming this raid is what puts it on
-- the list, with every missing piece counted as here and no boss to name.
local tier = byName["Tier This Difficulty"]
assert(tier, "a set whose source names this instance was missing")
assert(#tier.here == 2 and tier.remaining == 0)
for _, piece in ipairs(tier.here) do
	assert(piece.encounter == nil, "a piece with no drop data claimed a boss")
	assert(piece.difficultyNote == nil, "the difficulty matched and was flagged anyway")
end

-- The same set exists once per difficulty and only this run's version can be
-- finished here, so the others are left off rather than listed with a caveat.
assert(not byName["Tier Other Difficulty"], "a set for another difficulty was listed")

-- A set naming a different raid stays off the list.
assert(not byName["Tier Elsewhere"], "a set naming another raid was listed")

-- A label that names a family rather than a place must not match an instance,
-- and this one's piece drops somewhere else entirely.
assert(not byName["Family Named Set"], "a set named after a family matched an instance")

-- Drop data wins where it exists, because only it can name the boss. The rest of
-- the set still comes along on the strength of the set's source.
local both = byName["Named And Dropped"]
assert(both and #both.here == 2 and both.remaining == 0)
local named, unnamed = 0, 0
for _, piece in ipairs(both.here) do
	if piece.encounter == "The Warden" then named = named + 1 else unnamed = unnamed + 1 end
end
assert(named == 1 and unnamed == 1, "the piece with drop data should have kept its boss")

-- The icon row shows the whole set, not just what is missing, so every piece is
-- listed with what it needs to be drawn and which of the three states it is in.
local iconRow = byName["Half Done"]
assert(#iconRow.pieces == 4, "the row should cover the whole set, collected included")
local collected, availableHere, elsewhere = 0, 0, 0
for _, piece in ipairs(iconRow.pieces) do
	assert(piece.icon, "a piece has no icon to draw")
	assert(piece.itemID, "a piece has no item to read an icon from")
	if piece.collected then collected = collected + 1
	elseif piece.availableHere then availableHere = availableHere + 1
	else elsewhere = elsewhere + 1 end
end
assert(collected == 1 and availableHere == 2 and elsewhere == 1)

-- A piece still to find carries everywhere it drops, so hovering it can name the
-- bosses. A piece already collected carries none, because there is nothing to ask.
for _, piece in ipairs(iconRow.pieces) do
	if piece.collected then
		assert(piece.drops == nil, "a collected piece was given drop locations")
	else
		assert(piece.drops, "a missing piece has nowhere to come from")
	end
end

-- This instance's bosses come first, so the useful line is the one at the top.
local elsewherePiece
for _, piece in ipairs(iconRow.pieces) do
	if not piece.collected and not piece.availableHere then elsewherePiece = piece end
end
assert(elsewherePiece and elsewherePiece.drops[1].instance == "Somewhere Else")
assert(elsewherePiece.drops[1].isHere == false)

local herePiece
for _, piece in ipairs(iconRow.pieces) do
	if piece.availableHere and piece.drops then herePiece = piece end
end
assert(herePiece and herePiece.drops[1].isHere, "the boss in this instance should sort first")
assert(herePiece.drops[1].encounter)

-- Tier has no drop data, so its missing pieces have an empty list rather than a
-- wrong one, and the tooltip falls back to naming the instance.
local tierPiece
for _, piece in ipairs(byName["Tier This Difficulty"].pieces) do
	if not piece.collected then tierPiece = piece end
end
assert(tierPiece and #tierPiece.drops == 0 and tierPiece.availableHere)

-- Raising the limit brings in the set that was too far off before.
local generous = SetCompletion:Scan(instance, 8)
assert(#generous == 6)
assert(generous[#generous].name == "Long Way Off")

-- An extra set's stored state predates this run, so a piece looted since counts
-- as collected however out of date the set data is.
COLLECTED_NOW[12] = true
local afterLooting = SetCompletion:Scan(instance)
local oldDungeonSet
for _, match in ipairs(afterLooting) do
	if match.name == "Old Dungeon Set" then oldDungeonSet = match end
end
assert(oldDungeonSet, "the extra set should still have a piece to find here")
assert(oldDungeonSet.collected == 1 and oldDungeonSet.total == 2)
assert(#oldDungeonSet.here == 1)

-- Blizzard sets report their own collected state, so it is taken as given.
COLLECTED_NOW[4] = true
local blizzardStillListed = false
for _, match in ipairs(SetCompletion:Scan(instance)) do
	if match.name == "Nearly There" then blizzardStillListed = true end
end
assert(blizzardStillListed, "a Blizzard set was re-read against the wrong source of truth")
COLLECTED_NOW[4] = nil

-- Once the last piece is in, the set drops off the list entirely.
COLLECTED_NOW[13] = true
for _, match in ipairs(SetCompletion:Scan(instance)) do
	assert(match.name ~= "Old Dungeon Set", "a finished extra set was still listed")
end
COLLECTED_NOW[12], COLLECTED_NOW[13] = nil, nil

-- Difficulty names don't match across the two sides, so neither spelling of the
-- same difficulty should be reported as out of reach.
playerDifficulty = "Mythic Keystone"
local keystoneNote
for _, match in ipairs(SetCompletion:Scan(SetCompletion:GetCurrentInstance(), 3)) do
	if match.name == "Half Done" then
		for _, piece in ipairs(match.here) do
			if piece.name == "Piece 6" then keystoneNote = piece.difficultyNote end
		end
	end
end
assert(keystoneNote == "Heroic", "a Heroic piece should be flagged on a Mythic key")

playerDifficulty = "25 Player (Heroic)"
for _, match in ipairs(SetCompletion:Scan(SetCompletion:GetCurrentInstance(), 3)) do
	if match.name == "Half Done" then
		for _, piece in ipairs(match.here) do
			assert(piece.difficultyNote == nil,
				"a Heroic piece was flagged while in a 25 Player (Heroic) raid")
		end
	end
end
playerDifficulty = "Normal"

-- A set from the tier being raided now gets finished by turning up, so it is left
-- off unless asked for. Only that tier goes: an older set is still worth a trip
-- back, and a set whose patch has not shipped is not the tier anyone is playing.
addon.Profile.IncludeCurrentTier = false
local ignoringTier = {}
local tierStats
do
	local found, stats = SetCompletion:Scan(instance)
	tierStats = stats
	for _, match in ipairs(found) do ignoringTier[match.name] = true end
end

assert(not ignoringTier["Nearly There"], "a set from the current tier was listed")
assert(tierStats.skippedCurrentTier == 1, "the scan should report what the tier filter took")
assert(ignoringTier["Half Done"], "a set from an older patch should survive the tier filter")
assert(ignoringTier["Tier This Difficulty"], "a set from an unreleased patch is not this tier")
assert(ignoringTier["Old Dungeon Set"], "a set carrying no patch at all should survive")

-- Nothing but the profile decides this, so asking for the tier brings it back.
addon.Profile.IncludeCurrentTier = true
assert(#SetCompletion:Scan(instance) == 5, "asking for the current tier should bring it back")

print("SetCompletionTest passed")
