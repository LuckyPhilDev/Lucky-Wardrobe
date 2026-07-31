local addon = {}

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

assert(loadfile("src/Data/Globals.lua"))("LuckyTest", addon)

local Globals = addon.Globals
local Filter = addon.Filter

addon.MiscSets = {
	PVP_SETID = { 13, 1019 },
	CHALLENGE_SETID = { 1436 },
	TRADINGPOST_SETS = { [2320] = "Formal" },
	HeritageSets = { [1522] = 28 },
	NON_RAID_LABELS = {
		["Darkmoon Faire"] = true,
		["Time's Keeper"] = true,
		["Legion: Assaults"] = true,
	},
}

-- Every category has a distinct ID, so no two sources share a checkbox.
local seen = {}
for key, id in pairs(Filter) do
	assert(type(id) == "number", key .. " is not a number")
	assert(not seen[id], key .. " collides with " .. tostring(seen[id]) .. " on ID " .. id)
	seen[id] = key
end

-- Both set tabs offer sources, and every entry is a real category.
local baseSources = Globals.GetSourceFiltersForTab(Globals.BASE_SETS_TAB)
local extraSources = Globals.GetSourceFiltersForTab(Globals.EXTRA_SETS_TAB)
assert(#baseSources > 0)
assert(#extraSources > 0)

local function HasSource(sources, id)
	for _, source in ipairs(sources) do
		if source.id == id then return true end
	end
	return false
end

for _, sources in ipairs({ baseSources, extraSources }) do
	for _, source in ipairs(sources) do
		assert(seen[source.id], "source " .. tostring(source.label) .. " has an unknown ID")
		assert(source.label and source.label ~= "", "source " .. source.id .. " has no label")
	end
end

-- Recolor sets used to share ID 0 with Raid and Covenant, which hid them from
-- the Extra tab entirely. They now have their own checkbox.
assert(HasSource(extraSources, Filter.RECOLOR))
assert(Filter.RECOLOR ~= Filter.RAID and Filter.RECOLOR ~= Filter.COVENANT)

-- Categories only appear on a tab whose sets can actually carry them.
assert(HasSource(baseSources, Filter.RAID))
assert(not HasSource(extraSources, Filter.RAID))
assert(HasSource(extraSources, Filter.QUEST))
assert(not HasSource(baseSources, Filter.QUEST))
assert(HasSource(baseSources, Filter.TPOST) and HasSource(extraSources, Filter.TPOST))

local function FilterFor(data)
	return Globals.GetBlizzardSetFilter(data)
end

assert(FilterFor({ setID = 13, description = "Gladiator" }) == Filter.PVP)
assert(FilterFor({ setID = 2015 }) == Filter.COVENANT)
assert(FilterFor({ setID = 2221 }) == Filter.COVENANT)
assert(FilterFor({ setID = 2222, description = "Mythic" }) == Filter.RAID)
assert(FilterFor({ setID = 2320 }) == Filter.TPOST)
assert(FilterFor({ setID = 9001, label = "Trading Post" }) == Filter.TPOST)
assert(FilterFor({ setID = 9002, description = "In-Game Shop - Shadowbane" }) == Filter.TPOST)
assert(FilterFor({ setID = 1522, description = "Highmountain" }) == Filter.HERITAGE)
assert(FilterFor({ setID = 1436, description = "Challenge Mode" }) == Filter.DUNGEON)
assert(FilterFor({ setID = 9003, description = "Heroic" }) == Filter.RAID)
assert(FilterFor({ setID = 9004 }) == Filter.MISC)

-- PvP wins over the covenant range, which overlaps it.
assert(FilterFor({ setID = 1019 }) == Filter.PVP)

-- Real sets from a live collection, which is where the Raid category was found
-- to be catching most of the Sets tab. Only a raid difficulty counts as Raid.
local function AssertClassifies(expected, name, data)
	local actual = FilterFor(data)
	assert(actual == expected,
		("%s: expected %s, got %s"):format(name, seen[expected], seen[actual] or "nil"))
end

AssertClassifies(Filter.RAID, "Fangs of the Vermillion Forge",
	{ setID = 2864, label = "Aberrus, the Shadowed Crucible", description = "Normal" })
AssertClassifies(Filter.RAID, "Way of Ra-den's Chosen",
	{ setID = 5441, label = "The Voidspire", description = "Raid Finder" })

AssertClassifies(Filter.PVP, "Galactic Aspirant's Leather Armor",
	{ setID = 5470, label = "Midnight Season 1", description = "Aspirant" })

-- Content rewards keep the class or armour type they drop for, so they stay Misc.
AssertClassifies(Filter.MISC, "Garb of the Insatiable Vision",
	{ setID = 4364, label = "Horrific Visions Revisited", description = "Horrific Visions Revisited", classMask = 3592 })
AssertClassifies(Filter.MISC, "Eternal Battlegear of the August Acolyte",
	{ setID = 3861, label = "WoW's 20th Anniversary", description = "WoW Anniversary", classMask = 512 })
AssertClassifies(Filter.MISC, "Grotto Garb",
	{ setID = 5627, label = "Tangled Raiment", description = "Dungeons", classMask = 3592 })
AssertClassifies(Filter.MISC, "Osseoclad's Wear",
	{ setID = 5547, label = "Harandar Gear", description = "Delves", classMask = 3592 })

-- A colour variant that is still class armour belongs with the content rewards,
-- which is why the split reads the class mask rather than the description.
AssertClassifies(Filter.MISC, "Response Team's Leather Armor",
	{ setID = 5709, label = "Reponse Team's Armor", description = "Black", classMask = 3592 })

-- Wearable by every class, so these are the outfit collections.
AssertClassifies(Filter.COSMETIC, "Righteous Lawbringer",
	{ setID = 5695, label = "Badlands Justice", description = "White", classMask = 0 })
AssertClassifies(Filter.COSMETIC, "Squall Braced Attire",
	{ setID = 4519, label = "Rainy Day Collection", description = "Blue", classMask = 0 })
AssertClassifies(Filter.COSMETIC, "Voidstrider Raiment",
	{ setID = 5164, label = "Dragonhawk Rider", description = "Void", classMask = 0 })

-- An all-class raid set is still a raid set: difficulty is checked first.
AssertClassifies(Filter.RAID, "all-class raid set",
	{ setID = 9005, description = "Mythic", classMask = 0 })

-- Wrath tier names its difficulty inside the raid size.
AssertClassifies(Filter.RAID, "Wrath 10 player tier",
	{ setID = 9007, label = "Ulduar", description = "10 Player (Normal)", classMask = 128 })
AssertClassifies(Filter.RAID, "Wrath 25 player heroic tier",
	{ setID = 9008, label = "Icecrown Citadel", description = "25 Player (Heroic)", classMask = 128 })

-- Classic and TBC tier carry no variants at all, which is why variant count
-- cannot stand in for the difficulty test.
AssertClassifies(Filter.RAID, "Arcanist Regalia",
	{ setID = 910, label = "Molten Core", description = "Normal", classMask = 128 })

-- Excluded by label, not set ID: these families exist once per armour type, so
-- the IDs differ per class while the label is shared. Both of these pairs are
-- the same set on a Monk and on a Mage.
AssertClassifies(Filter.MISC, "Wildheart Raiment",
	{ setID = 1426, label = "Darkmoon Faire", description = "Normal", classMask = 3592 })
AssertClassifies(Filter.MISC, "Vestments of the Devout",
	{ setID = 359, label = "Darkmoon Faire", description = "Normal", classMask = 400 })
AssertClassifies(Filter.MISC, "Riftscarred Vestments",
	{ setID = 1459, label = "Time's Keeper", description = "Normal", classMask = 3592 })
AssertClassifies(Filter.MISC, "Chronoscryer's Finery",
	{ setID = 1457, label = "Time's Keeper", description = "Normal", classMask = 400 })
AssertClassifies(Filter.MISC, "Netherfiend Battlegear",
	{ setID = 4399, label = "Legion: Assaults", description = "Normal", classMask = 3592 })
AssertClassifies(Filter.MISC, "Vileweave Vestments",
	{ setID = 4330, label = "Legion: Assaults", description = "Normal", classMask = 400 })

-- A description that merely contains a difficulty word is not a difficulty.
AssertClassifies(Filter.MISC, "description containing a difficulty word",
	{ setID = 9009, label = "Some Collection", description = "Normal Wear", classMask = 512 })

-- A missing class mask is not evidence of anything, so it stays Misc.
AssertClassifies(Filter.MISC, "set with no class mask", { setID = 9006 })

-- One input per branch of the classifier, so the checks below cover every
-- category a Blizzard set can actually come out as.
local classifierBranches = {
	{ name = "PvP by ID", data = { setID = 13, description = "Normal" } },
	{ name = "PvP by description", data = { setID = 9101, description = "Gladiator" } },
	{ name = "covenant", data = { setID = 2015, description = "Normal" } },
	{ name = "trading post", data = { setID = 2320, description = "Normal" } },
	{ name = "heritage", data = { setID = 1522, description = "Normal" } },
	{ name = "challenge mode", data = { setID = 1436, description = "Normal" } },
	{ name = "raid difficulty", data = { setID = 9102, description = "Heroic" } },
	{ name = "cosmetic", data = { setID = 9103, description = "Blue", classMask = 0 } },
	{ name = "unrecognised", data = { setID = 9104, description = "Delves", classMask = 512 } },
	{ name = "no description", data = { setID = 9105 } },
}

-- Every category a Blizzard set can be classified as needs a checkbox on the Sets
-- tab. One without a checkbox cannot be cleared by Uncheck All, so its sets stay
-- on screen when the user has unticked everything.
local branchCategories = {}
for _, branch in ipairs(classifierBranches) do
	local id = FilterFor(branch.data)
	assert(HasSource(baseSources, id),
		branch.name .. " classified as " .. (seen[id] or "nil") .. ", which has no checkbox on the Sets tab")
	branchCategories[id] = true
end

-- Including PvP, which overlaps Blizzard's own toggle but must still be clearable.
assert(HasSource(baseSources, Filter.PVP))

-- The branches really do reach every category the Sets tab offers, so the menu
-- has no checkbox that could never match a set.
for _, source in ipairs(baseSources) do
	assert(branchCategories[source.id],
		"the Sets tab offers " .. seen[source.id] .. " but no set can be classified as it")
end

-- Unchecking every source on a tab must leave nothing on screen. This mirrors the
-- menu's Uncheck All, which only clears the categories that tab lists, and the
-- filter predicate in FilterSets.
-- Sets are wrapped so that "no category at all" is representable: a plain list
-- cannot hold a nil, and that is the case worth covering.
local function CountVisibleAfterUncheckAll(tabSources, sets)
	local filterSelection = {}
	for _, source in ipairs(Globals.SourceFilters) do
		filterSelection[source.id] = true
	end
	for _, source in ipairs(tabSources) do
		filterSelection[source.id] = false
	end

	local visible = 0
	for _, set in ipairs(sets) do
		if filterSelection[set.category or Filter.MISC] ~= false then
			visible = visible + 1
		end
	end
	return visible
end

local blizzardSets = { { category = nil } } -- a set carrying no category at all
for _, branch in ipairs(classifierBranches) do
	blizzardSets[#blizzardSets + 1] = { category = FilterFor(branch.data) }
end
assert(#blizzardSets == #classifierBranches + 1)

assert(CountVisibleAfterUncheckAll(baseSources, blizzardSets) == 0,
	"unchecking every source on the Sets tab still leaves sets visible")

-- The shipped extra sets must only use categories the Extra tab offers. A set
-- tagged with a category that has no checkbox is a set nobody can ever see.
addon.ArmorSets = {}
for _, armorType in ipairs({ "CLOTH", "LEATHER", "MAIL", "PLATE", "COSMETIC" }) do
	assert(loadfile("src/Data/" .. armorType .. ".lua"))("LuckyTest", addon)
end

local extraHasSource = {}
for _, source in ipairs(extraSources) do extraHasSource[source.id] = true end

local checked = 0
for armorType, sets in pairs(addon.ArmorSets) do
	for setID, data in pairs(sets) do
		if data.filter ~= nil then
			assert(extraHasSource[data.filter],
				armorType .. " set " .. setID .. " uses category " .. data.filter .. ", which has no checkbox")
			checked = checked + 1
		end
	end
end
assert(checked > 1000, "expected the full extra set data, only saw " .. checked)

print("SourceFiltersTest passed")
