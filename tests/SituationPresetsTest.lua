local selected = {
	["3:0:0:0"] = true,
	["13:0:0:0"] = true,
}

local options = {
	{
		groupData = {
			{ optionData = {
				{ option = { situationID = 3, specID = 0, loadoutID = 0, equipmentSetID = 0 } },
				{ option = { situationID = 4, specID = 0, loadoutID = 0, equipmentSetID = 0 } },
			} },
		},
	},
	{
		groupData = {
			{ optionData = {
				{ option = { situationID = 13, specID = 0, loadoutID = 0, equipmentSetID = 0 } },
			} },
		},
	},
}

local function OptionKey(option)
	return table.concat({ option.situationID, option.specID, option.loadoutID, option.equipmentSetID }, ":")
end

_G.LibStub = function(name)
	if name == "AceAddon-3.0" then
		return { GetAddon = function() return _G.TestAddon end }
	end
	return { GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end }
end
local addon = { Profile = { SituationPresets = {} } }
_G.TestAddon = addon
_G.StaticPopupDialogs = {}
_G.SAVE, _G.CANCEL, _G.YES, _G.NO = "Save", "Cancel", "Yes", "No"
_G.strtrim = function(value) return value:match("^%s*(.-)%s*$") end
local shownPopup
local calls = {}
local situationsEnabled = false
_G.StaticPopup_Show = function(name, _, _, data)
	shownPopup = { name = name, data = data }
end
_G.C_TransmogOutfitInfo = {
	GetUISituationCategoriesAndOptions = function() return options end,
	GetOutfitSituationsEnabled = function() return situationsEnabled end,
	SetOutfitSituationsEnabled = function(value)
		calls[#calls + 1] = "enable"
		situationsEnabled = value
	end,
	GetOutfitSituation = function(option) return selected[OptionKey(option)] end,
	UpdatePendingSituation = function(option, value)
		calls[#calls + 1] = "update"
		selected[OptionKey(option)] = value
	end,
	CommitPendingSituations = function() calls[#calls + 1] = "commit" end,
}

assert(loadfile("src/Modules/SituationPresets.lua"))("LuckyTest", _G.TestAddon)

local loadEnabled
addon.SituationPresets.loadButton = {
	SetEnabled = function(_, enabled) loadEnabled = enabled end,
}
addon.SituationPresets:UpdateLoadButton()
assert(not loadEnabled)

addon.SituationPresets:Save("Rest Area")
assert(addon.Profile.SituationPresets["Rest Area"].selections["3:0:0:0"])
assert(not addon.Profile.SituationPresets["Rest Area"].selections["4:0:0:0"])
assert(loadEnabled)

selected["3:0:0:0"] = false
selected["4:0:0:0"] = true
assert(not addon.SituationPresets:Save("Rest Area"))
assert(shownPopup.name == "LUCKYS_BETTER_WARDROBE_REPLACE_SITUATION")
assert(addon.Profile.SituationPresets["Rest Area"].selections["3:0:0:0"])

local refreshed = false
addon.SituationPresets:Apply(addon.Profile.SituationPresets["Rest Area"], {
	Refresh = function() refreshed = true end,
})

assert(selected["3:0:0:0"])
assert(not selected["4:0:0:0"])
assert(situationsEnabled)
assert(refreshed)
assert(table.concat(calls, ",") == "enable,update,update,commit")

StaticPopupDialogs["LUCKYS_BETTER_WARDROBE_DELETE_SITUATION"].OnAccept(nil, "Rest Area")
assert(not addon.Profile.SituationPresets["Rest Area"])
assert(not loadEnabled)
