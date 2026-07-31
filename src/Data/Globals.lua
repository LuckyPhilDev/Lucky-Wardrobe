local addonName, addon = ...
addon = LibStub("AceAddon-3.0"):NewAddon(addon, addonName, "AceEvent-3.0", "AceConsole-3.0", "AceHook-3.0", "AceSerializer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local Globals = {}

addon.Globals = Globals

addon.Globals.SET_OFFSET = 20000

Globals.ARMOR_MASK = {
	CLOTH = 400,
	LEATHER = 3592,
	MAIL = 68,
	PLATE = 35,
}
--/dump GetSpellDescription(298886)
-- ID, Mask, Armor
Globals.CLASS_INFO = {
	DEATHKNIGHT = {6,32,"PLATE"},
	DEMONHUNTER = {12, 2048, "LEATHER"},
	DRUID = {11, 1024,"LEATHER"},
	HUNTER = {3, 4, "MAIL"},
	MAGE = {8, 128, "CLOTH"},
	MONK = {10, 512, "LEATHER"},
	PALADIN = {2, 2,"PLATE"},
	PRIEST = {5, 16, "CLOTH"},
	ROGUE = {4, 8, "LEATHER"},
	SHAMAN = {7, 64, "MAIL"},
	WARLOCK = {9, 256, "CLOTH"},
	WARRIOR = {1, 1, "PLATE"},
	EVOKER =  {13, 4096, "MAIL"},
}


--bit.band(400, 16)
Globals.CLASS_MASK_TO_ID = {}


for i, data in pairs(Globals.CLASS_INFO) do
	Globals.CLASS_MASK_TO_ID[data[2]] = data[1]
end


local PlateMasks =  {1, 2, 32, 35, 0}
local MailMasks =  {4, 64, 68, 0, 4096, 4164}
local LeatherMasks = {8, 512, 1024, 2048, 3592, 0}
local ClothMaks = {16, 128, 256, 400, 0}
Globals.CLASS_MASK = {
		[1] = PlateMasks, -- Warrior - Plate Wearer
		[2] = PlateMasks, -- Paladin - Plate Wearer
		[3] = MailMasks,    -- Hunter - Mail Wearer
		[4] = LeatherMasks, -- Rogue - Leather Wearer
		[5] = ClothMaks, -- Priest - Cloth Wearer
		[6] = PlateMasks, -- Death Knight - Plate Wearer
		[7] = MailMasks,    -- Shaman - Mail Wearer
		[8] = ClothMaks, -- Mage - Cloth Wearer
		[9] = ClothMaks, -- Warlock - Cloth Wearer
		[10] = LeatherMasks, -- Monk - Leather Wearer
		[11] = LeatherMasks, -- Druid - Leather Wearer
		[12] = LeatherMasks, -- Demon Hunter - Leather Wearer
		[13] = MailMasks,    -- Evoker = Mail Wearer

}
Globals.CLASS_NAMES = {
		[1] = {"Warrior","WARRIOR"},
		[2] = {"Paladin","PALADIN"},
		[4] = {"Hunter","HUNTER"},
		[8] = {"Rogue","ROGUE"},
		[16] = {"Priest","PRIEST"},
		[32] = {"Death Knight","DEATHKNIGHT"},
		[64] = {"Shaman","SHAMAN"},
		[128] = {"Mage","MAGE"},
		[256] = {"Warlock","WARLOCK"},
		[512]  = {"Monk","MONK"},
		[1024] = {"Druid","DRUID"},
		[2048] = {"Demon Hunter","DEMONHUNTER"},
		[4096] = {"Evoker", "EVOKER"},
}

Globals.ClassToMask = {
		[1] = 1,
		[2] = 2,
		[3] = 4,
		[4] = 8,
		[5] = 16,
		[6] = 32,
		[7] = 64,
		[8] = 128,
		[9] = 256,
		[10] = 512,
		[11] = 1024,
		[12] = 2048,
		[13] = 4096,
}

Globals.ClassArmorType = {
	[1]  = 4,   
	[2]  = 4,   
	[3]  = 3,
	[4]  = 2, 
	[5]  = 1,
	[6]  = 4, 
	[7]  = 3,
	[8]  = 1,
	[9]  = 1,
	[10] = 2,
	[11] = 2,
	[12] = 2,
	[13] = 3,
}

Globals.ClassArmorMask = {
		[1]  = {0, 1, 35},
		[2]  = {0, 2, 35},
		[3]  = {0, 4, 68, 4164},
		[4]  = {0, 8, 3592},
		[5]  = {0, 16, 400},
		[6]  = {0, 32, 35},
		[7]  = {0, 64, 68, 4164},
		[8]  = {0, 128, 400},
		[9]  = {0, 256, 400},
		[10] = {0, 512, 3592},
		[11] = {0, 1024, 3592},
		[12] = {0, 2048, 3592},
		[13] = {0, 4096, 68, 4164},
}

--[[

bit.band( 3592,1024)
bit.bor( 3592,1024)
bit.band(1,35)

DEATHKNIGHT
a137006
a137007

a212612 -DEMONHUNTER
a212613

HUNTER
]?a137015[Aspect of the Wild]?a137016[Trueshot]?a137017[Aspect of the Eagle]


]]--
Globals.ARMOR_TYPE = {"CLOTH", "LEATHER", "MAIL", "PLATE"}
Globals.ARMOR_TYPE_ID = {["CLOTH"] = 1, ["LEATHER"]=2, ["MAIL"]=3, ["PLATE"]=4}


Globals.ARMOR_CLASSES = {}
for type in pairs(Globals.ARMOR_MASK ) do
	Globals.ARMOR_CLASSES[type] = {}
end
for class, data in pairs(Globals.CLASS_INFO) do
	local id = data[2]
	local type = data[3]
	Globals.ARMOR_CLASSES[type][id] = true
end

Globals.locationDropDown = {
	
	[2] = INVTYPE_HEAD,
	--[2] = 134112, neck
	[4] = INVTYPE_SHOULDER,
	--[4] = 168659, shirt
	[16] = INVTYPE_CLOAK,
	[6] = INVTYPE_CHEST,
	[7] = INVTYPE_WAIST,
	[8] = INVTYPE_LEGS,-- pants
	[9] = INVTYPE_FEET,
	[10] = INVTYPE_WRIST,  --wrist
	[11] = INVTYPE_HAND,
	[21] = INVTYPE_ROBE,--handr
}


Globals.INVENTORY_SLOT_NAMES = {
	[1]  = "HEADSLOT",
	[3]  = "SHOULDERSLOT",
	[4]  = "SHIRTSLOT",
	[5]  = "CHESTSLOT",
	[6]  = "WAISTSLOT",
	[7]  = "LEGSSLOT",
	[8]  = "FEETSLOT",
	[9]  = "WRISTSLOT",
	[10] = "HANDSSLOT",
	[15] = "BACKSLOT",
	[16] = "MAINHANDSLOT",
	[17] = "SECONDARYHANDSLOT",
	[18] = "MAINHANDSLOT",
	[19] = "TABARDSLOT",

			 
	
	["HEADSLOT"]          = 1,
	["SHOULDERSLOT"]      = 3,
	["SHIRTSLOT"]         = 4,
	["CHESTSLOT"]         = 5,
	["WAISTSLOT"]         = 6,
	["LEGSSLOT"]          = 7,
	["FEETSLOT"]          = 8,
	["WRISTSLOT"]         = 9,
	["HANDSSLOT"]         = 10,
	["BACKSLOT"]          = 15,
	["MAINHANDSLOT"]      = 16,
	["SECONDARYHANDSLOT"] = 17,
	["TABARDSLOT"]        = 19,

	["INVTYPE_HEAD"] =            1,
	["INVTYPE_NECK"] =            2,
	["INVTYPE_SHOULDER"] =        3,
	["INVTYPE_BODY"] =            4,
	["INVTYPE_CHEST"] =           5,
	["INVTYPE_ROBE"] =            5,
	["INVTYPE_WAIST"] =          6,
	["INVTYPE_LEGS"] =           7,
	["INVTYPE_FEET"] =            8,
	["INVTYPE_WRIST"] =           9,
	["INVTYPE_HAND"] =            10,
	["INVTYPE_CLOAK"] =           15,
	["INVTYPE_WEAPON"] =          16,
	["INVTYPE_SHIELD"] =          17,
	["INVTYPE_2HWEAPON"] =        16,
	["INVTYPE_WEAPONMAINHAND"] =  16,
	["INVTYPE_WEAPONOFFHAND"] =   17,
	["INVTYPE_HOLDABLE"] =        17,
	["INVTYPE_RANGED"] =          16,
	["INVTYPE_THROWN"] =          16,
	["INVTYPE_RANGEDRIGHT"] =     16,
	["INVTYPE_RELIC"] =           17,
	["INVTYPE_TABARD"] =          19,
}



Globals.CATEGORYID_TO_NAME = {
		[Enum.TransmogCollectionType.Head] = "HEADSLOT",
		[Enum.TransmogCollectionType.Shoulder] = "SHOULDERSLOT",
		[Enum.TransmogCollectionType.Back] = "BACKSLOT",
		[Enum.TransmogCollectionType.Chest] = "CHESTSLOT",
		[Enum.TransmogCollectionType.Shirt] = "SHIRTSLOT",
		[Enum.TransmogCollectionType.Tabard] = "TABARDSLOT",
		[Enum.TransmogCollectionType.Wrist] = "WRISTSLOT",
		[Enum.TransmogCollectionType.Hands] = "HANDSSLOT",
		[Enum.TransmogCollectionType.Waist] = "WAISTSLOT",
		[Enum.TransmogCollectionType.Legs] = "LEGSSLOT",
		[Enum.TransmogCollectionType.Feet] = "FEETSLOT",
		[Enum.TransmogCollectionType.Wand] = "MAINHANDSLOT",
		[Enum.TransmogCollectionType.OneHAxe] = "MAINHANDSLOT",
		[Enum.TransmogCollectionType.OneHSword] = "MAINHANDSLOT",
		[Enum.TransmogCollectionType.OneHMace] = "MAINHANDSLOT",
		[Enum.TransmogCollectionType.Dagger] = "MAINHANDSLOT",
		[Enum.TransmogCollectionType.Fist] = "MAINHANDSLOT",
		[Enum.TransmogCollectionType.TwoHAxe] = "MAINHANDSLOT",
		[Enum.TransmogCollectionType.TwoHSword] = "MAINHANDSLOT",
		[Enum.TransmogCollectionType.TwoHMace] = "MAINHANDSLOT",
		[Enum.TransmogCollectionType.Staff] = "MAINHANDSLOT",
		[Enum.TransmogCollectionType.Polearm] = "MAINHANDSLOT",
		[Enum.TransmogCollectionType.Bow] = "MAINHANDSLOT",
		[Enum.TransmogCollectionType.Gun] = "MAINHANDSLOT",
		[Enum.TransmogCollectionType.Crossbow] = "MAINHANDSLOT",
		[Enum.TransmogCollectionType.Warglaives] = "MAINHANDSLOT",
		[Enum.TransmogCollectionType.Paired] = "MAINHANDSLOT",
		[Enum.TransmogCollectionType.Shield] = "SECONDARYHANDSLOT",
		[Enum.TransmogCollectionType.Holdable] = "SECONDARYHANDSLOT",
}

Globals.slots = {
	"HeadSlot",
	"ShoulderSlot",
	"BackSlot",
	"ChestSlot",
	"ShirtSlot",
	"TabardSlot",
	"WristSlot",
	"HandsSlot",
	"WaistSlot",
	"LegsSlot",
	"FeetSlot",
	"MainHandSlot",
	"SecondaryHandSlot",
};



Globals.tooltip_slots = {
	INVTYPE_HEAD = 0,
	INVTYPE_SHOULDER = 0,
	INVTYPE_CLOAK = 3.4,
	INVTYPE_CHEST = 0,
	INVTYPE_BODY = 0,
	INVTYPE_ROBE = 0,
	INVTYPE_SHIRT = 0,
	INVTYPE_TABARD = 0,
	INVTYPE_WRIST = 0,
	INVTYPE_2HWEAPON = 1.6,
	INVTYPE_WEAPON = 1.6,
	INVTYPE_WEAPONMAINHAND = 1.6,
	INVTYPE_WEAPONOFFHAND = -0.7,
	INVTYPE_SHIELD = -0.7,
	INVTYPE_HOLDABLE = -0.7,
	INVTYPE_RANGED = 1.6,
	INVTYPE_RANGEDRIGHT = 1.6,
	INVTYPE_THROWN = 1.6,
	INVTYPE_HAND = 0,
	INVTYPE_WAIST = 0,
	INVTYPE_LEGS = 0,
	INVTYPE_FEET = 0,
};

Globals.mods = {
	Shift = IsShiftKeyDown,
	Ctrl = IsControlKeyDown,
	Alt = IsAltKeyDown,
};



Globals.BASE_SET_BUTTON_HEIGHT = 46
Globals.VARIANT_SET_BUTTON_HEIGHT = 20
Globals.SET_PROGRESS_BAR_MAX_WIDTH = 204
Globals.IN_PROGRESS_FONT_COLOR = CreateColor(0.251, 0.753, 0.251)
Globals.IN_PROGRESS_FONT_COLOR_CODE = "|cff40c040"
Globals.COLLECTION_LIST_WIDTH = 260

Globals.EmptyArmor = {
	[1] = 134110,
	--[2] = 134112, neck
	[3] = 134112,
	[4] = 142503, --shirt
	[5] = 168659,
	[6] = 143539,
	[7] = 216696, --pants
	[8] = 168664,
	[9] = 168665, --wrist
	[10] = 158329, --handr
	[15] = 134111, --cloak
	[19] = 142504, --tabgaard
}

Globals.DEFAULT = 1
Globals.APPEARANCE = 2
Globals.ALPHABETIC = 3
Globals.ITEM_SOURCE = 6
Globals.EXPANSION = 5
Globals.COLOR = 4

Globals.TAB_ITEMS = 1
Globals.TAB_SETS = 2
Globals.TAB_EXTRASETS = 3
Globals.TAB_SAVED_SETS = 4

Globals.colors = {
	["red"] = {255, 0, 0},
	["crimson"] = {255, 0, 63},
	["maroon"] = {128, 0, 0},
	["pink"] = {255, 192, 203},
	["lavender"] = {230, 230, 250},
	["purple"] = {128, 0, 128},
	["indigo"] = {75, 0, 130},
	
	["blue"] = {0, 0, 255},
	["teal"] = {0, 128, 128},
	["cyan"] = {0, 255, 255},
	
	["green"] = {0, 255, 0},
	["yellow"] = {255, 255, 0},
	["gold"] = {255, 215, 0},
	["orange"] = {255, 128, 0},
	["brown"] = {128, 64, 0},
	
	["black"] = {0, 0, 0},
	["gray"] = {128, 128, 128},
	["grey"] = {128, 128, 128},
	["silver"] = {192, 192, 192},
	["white"] = {255, 255, 255},
}

-- Source category stored on every set as `filter`. The source checkboxes index
-- filter state by these IDs, so they must stay stable: append new categories
-- rather than renumbering existing ones.
addon.Filter = {
["TRASH"] = 1,
["MISC"] = 2,
["CLASSIC"] = 3,
["QUEST"] = 4,
["DUNGEON"] = 5,
["GARRISON"] = 6,
["ISLAND"] = 7,
["WARFRONT"] = 8,
["TPOST"] = 9,
["HOLIDAY"] = 10,
["RECOLOR"] = 11,
["RAID"] = 12,
["COVENANT"] = 13,
["PVP"] = 14,
["HERITAGE"] = 15,
["COSMETIC"] = 16,
}

Globals.BASE_SETS_TAB = 2
Globals.EXTRA_SETS_TAB = 3

local BASE = Globals.BASE_SETS_TAB
local EXTRA = Globals.EXTRA_SETS_TAB

-- Order of the Sources submenu, and the tabs each category can actually appear
-- on. Every category a tab's sets can be classified as must be listed for that
-- tab: an unlisted category has no checkbox, so Uncheck All cannot clear it and
-- its sets stay on screen when the user has asked for nothing. PvP overlaps
-- Blizzard's own PvE/PvP toggle above this submenu, and is listed anyway for
-- that reason.
Globals.SourceFilters = {
	{id = addon.Filter.RAID, label = L["Raid Set"], tabs = {[BASE] = true}},
	{id = addon.Filter.PVP, label = L["PvP"], tabs = {[BASE] = true}},
	{id = addon.Filter.COVENANT, label = L["Covenants"], tabs = {[BASE] = true}},
	{id = addon.Filter.HERITAGE, label = L["Heritage"], tabs = {[BASE] = true}},
	{id = addon.Filter.COSMETIC, label = L["Cosmetic"], tabs = {[BASE] = true}},
	{id = addon.Filter.CLASSIC, label = L["Classic Set"], tabs = {[EXTRA] = true}},
	{id = addon.Filter.QUEST, label = L["Quest Set"], tabs = {[EXTRA] = true}},
	{id = addon.Filter.DUNGEON, label = L["Dungeon Set"], tabs = {[BASE] = true, [EXTRA] = true}},
	{id = addon.Filter.RECOLOR, label = L["Recolor"], tabs = {[EXTRA] = true}},
	{id = addon.Filter.GARRISON, label = L["Garrison"], tabs = {[EXTRA] = true}},
	{id = addon.Filter.ISLAND, label = L["Island Expedition"], tabs = {[EXTRA] = true}},
	{id = addon.Filter.WARFRONT, label = L["Warfronts"], tabs = {[EXTRA] = true}},
	{id = addon.Filter.HOLIDAY, label = L["Holiday"], tabs = {[EXTRA] = true}},
	{id = addon.Filter.TPOST, label = L["Trading Post"], tabs = {[BASE] = true, [EXTRA] = true}},
	{id = addon.Filter.MISC, label = L["MISC"], tabs = {[BASE] = true, [EXTRA] = true}},
	{id = addon.Filter.TRASH, label = L["Trash"], tabs = {[EXTRA] = true}},
}

function Globals.GetSourceFiltersForTab(tab)
	local sources = {}
	for _, source in ipairs(Globals.SourceFilters) do
		if source.tabs[tab] then
			table.insert(sources, source)
		end
	end
	return sources
end

Globals.TRADING_POST_LABEL = "Trading Post" --BATTLE_PET_SOURCE_12
Globals.IN_GAME_SHOP_LABEL = "In-Game Shop" --BATTLE_PET_SOURCE_10

local COVENANT_SETID_MIN, COVENANT_SETID_MAX = 2015, 2221
local pvpSets, challengeSets

-- Descriptions Blizzard gives PvP sets. The static PvP set ID list goes stale
-- every season, so the description is what catches sets from the current one.
Globals.PvPSetDescriptions = {
	["Honor"] = true,
	["Combatant"] = true,
	["Combatant I"] = true,
	["Warfront"] = true,
	["Aspirant"] = true,
	["Gladiator"] = true,
	["Elite"] = true,
}

-- Raid tier sets describe themselves by difficulty, and nothing else does: every
-- other kind of set puts its colour, its content type or its event in that field.
-- That makes the difficulty the one reliable marker of an actual raid set.
-- Blizzard's globals keep this working outside English, with the English values
-- kept as a fallback in case a global is ever renamed.
Globals.RaidDifficulties = {
	["Normal"] = true,
	["Heroic"] = true,
	["Mythic"] = true,
	["Raid Finder"] = true,
}

for _, difficulty in ipairs({ PLAYER_DIFFICULTY1, PLAYER_DIFFICULTY2, PLAYER_DIFFICULTY3, PLAYER_DIFFICULTY6 }) do
	if difficulty then
		Globals.RaidDifficulties[difficulty] = true
	end
end

-- Wrath era tier puts the difficulty inside the raid size, as in "10 Player
-- (Normal)", so the difficulty is matched within the description as well as
-- against the whole of it. Only the bracketed form counts, so a description that
-- merely contains the word is not mistaken for a difficulty.
function Globals.IsRaidDifficulty(description)
	if description == nil then return false end
	if Globals.RaidDifficulties[description] then return true end

	for difficulty in pairs(Globals.RaidDifficulties) do
		if string.find(description, "(" .. difficulty .. ")", 1, true) then return true end
	end

	return false
end

local function SetIDLookup(idList)
	local lookup = {}
	for _, setID in ipairs(idList) do
		lookup[setID] = true
	end
	return lookup
end

-- Plain find: the hyphen in "In-Game Shop" is a pattern quantifier, so a pattern
-- search never matches the labels we're looking for.
local function IsShopText(text)
	if text == nil then return false end
	return string.find(text, Globals.IN_GAME_SHOP_LABEL, 1, true) ~= nil
		or string.find(text, Globals.TRADING_POST_LABEL, 1, true) ~= nil
end

-- Source category for a Blizzard set. Extra sets carry their category in the set
-- data; Blizzard sets have to be placed by what the game tells us about them.
-- Only a set that names a raid difficulty counts as Raid. Treating "has any
-- description at all" as Raid swept in colour variants, event sets and anything
-- else the earlier tests missed, which was most of the category.
-- Everything unrecognised lands in Misc rather than being guessed at.
-- The MiscSets lookups are built on first use: MISC.lua loads after this file.
function Globals.GetBlizzardSetFilter(data)
	pvpSets = pvpSets or SetIDLookup(addon.MiscSets.PVP_SETID)
	challengeSets = challengeSets or SetIDLookup(addon.MiscSets.CHALLENGE_SETID)

	if pvpSets[data.setID] or (data.description and Globals.PvPSetDescriptions[data.description]) then
		return addon.Filter.PVP
	elseif data.setID >= COVENANT_SETID_MIN and data.setID <= COVENANT_SETID_MAX then
		return addon.Filter.COVENANT
	elseif addon.MiscSets.TRADINGPOST_SETS[data.setID] or IsShopText(data.label) or IsShopText(data.description) then
		return addon.Filter.TPOST
	elseif addon.MiscSets.HeritageSets[data.setID] then
		return addon.Filter.HERITAGE
	elseif challengeSets[data.setID] then
		return addon.Filter.DUNGEON
	elseif Globals.IsRaidDifficulty(data.description)
		and not (data.label and addon.MiscSets.NON_RAID_LABELS[data.label]) then
		return addon.Filter.RAID
	elseif data.classMask == 0 then
		-- Wearable by every class, which is what the outfit collections are: the
		-- colour variants of Petalweave, the Villager Collection and the like.
		-- Content rewards keep the armour type or class they drop for, so this
		-- separates the cosmetic sets from them without reading any text.
		return addon.Filter.COSMETIC
	end

	return addon.Filter.MISC
end
