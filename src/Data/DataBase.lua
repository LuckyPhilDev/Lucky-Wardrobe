local addonName, addon = ...
addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
addon.ArmorSets = addon.ArmorSets or {}
local ItemDB = {}
local Globals = addon.Globals

local SAVED_SET_OFFSET = 500000
addon.Globals.SAVED_SET_OFFSET = SAVED_SET_OFFSET

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local _, playerClass, classID = UnitClass("player")
--local role = GetFilteredRole()
local CLASS_INFO = Globals.CLASS_INFO
local SET_OFFSET = addon.Globals.SET_OFFSET


local CLASS_NAMES_LOCALIZED = {}
--FillLocalizedClassList(CLASS_NAMES_LOCALIZED) --Fills a table with localized class names, callable with localization-independent class IDs

local ARMOR_MASK = Globals.ARMOR_MASK
local EmptyArmor = Globals.EmptyArmor
local subitemlist = {}
local hiddenSet ={
	["setID"] =  0 ,
	["name"] =  "Hidden",
	["items"] = { 134110, 134112, 168659, 168665, 158329, 143539, 168664, 198608 },
	
	["expansionID"] =  1,
	["filter"] =  1,
	["recolor"] =  false,
	["minLevel"] =  1,
	["uiOrder"] = 100,
	["isClass"] = true,
	--["itemTransmogInfo"] = {}  --TODO Populate
}
local ALT_SET_DATA = {}
 SET_INDEX = {}
local ArmorDB = {}
local collectedAppearances = {}

local extraSetCount = 0
local extraSetCollectedCount = 0


local function GetFactionID(faction)
	if type(faction) == "number" then
		return faction		
	end

	if faction == "Horde" then
		return  2-- 64
	elseif faction == "Alliance" then
		return 1--4
	end
end


local armorMask = {400, 3592, 68, 35}
local WowSets = {{}, {}, {}, {}, {}}
WowSets["CLOTH"] = WowSets[1]
WowSets["LEATHER"] = WowSets[2]
WowSets["MAIL"] = WowSets[3]
WowSets["PLATE"] = WowSets[4]
WowSets["COSMETIC"] = WowSets[5]

local baseList = {}
addon.BaseList = baseList
local baseListLabels = {}
addon.BaseListLabels = baseListLabels
local baseIDs = {}
addon.BaseIDs = baseIDs
local variantSets = {};
addon.VariantSets = variantSets
local variantIDs = {};
addon.VariantIDs = variantIDs
local fullList = {}
addon.fullList = fullList


local function AddVariant(set, baseSetID)
	variantSets[baseSetID] = variantSets[baseSetID] or {};
	set.baseSetID = baseSetID;
	tinsert(variantSets[baseSetID], set)

	fullList[set.setID] = set
	variantIDs[set.setID] = baseSetID;
end

local function AddVariantToBaseSet(set, newBaseID)
	variantSets[baseSetID] = variantSets[baseSetID] or {};
	
	local baseID = set.baseSetID;
	--if not baseID then baseID = set.setID; end
	
	if variantSets[baseID] then
		for i=1,#variantSets[baseID] do
			tinsert(variantSets[newBaseID], variantSets[baseID][i]);
			variantIDs[variantSets[baseID][i].setID] = newBaseID;
			variantSets[baseID][i].baseSetID = newBaseID;
		end
	end

	if variantSets[set.setID] then
		for i=1,#variantSets[set.setID] do
			tinsert(variantSets[newBaseID], variantSets[set.setID][i]);
			variantIDs[variantSets[set.setID][i].setID] = newBaseID;
			variantSets[set.setID][i].baseSetID = newBaseID;
		end
	end
	
	set.baseSetID = newBaseID;
	variantSets[baseID] = nil;
	variantSets[set.setID] = nil;
end

local function UseSet(data)
	local dropdownClass = C_TransmogSets.GetTransmogSetsClassFilter();
	local selectedArmorType = dropdownClass or playerClass;
	local ClassArmor = addon.Globals.ClassArmorMask[selectedArmorType];
	local correctClass = false
	local _,_,playerRace = UnitRace('player');
	local playerFaction, _ = UnitFactionGroup('player')
	local correctFaction = false
	local ClassArmorTypeMask = addon.Globals.CLASS_MASK[tonumber(selectedArmorType)]
	local correctHeratiage = false
	local heritageSets = addon.MiscSets.HeritageSets


	--wierd artifact sets that were added
	if data.setID >= 4575 and data.setID <= 5094  then
		return false
	end

	if heritageSets[data.setID] and heritageSets[data.setID] == playerRace  then
		correctHeratiage = true;
		correctFaction = true;
		correctClass = true;
	elseif not heritageSets[data.setID] then
		correctHeratiage = true;
	end

	if data.classMask and (data.classMask == 0 or data.classMask == 16383) then
		correctClass = true;
	else
		if data.setType == "Blizzard" then
			if not addon.Profile.IgnoreClassRestrictions then 

				for i = 1, #ClassArmor do
					if data.classMask == ClassArmor[i] then
						correctClass = true;
						break;
					end
				end
			else
				for i = 1, #ClassArmorTypeMask do
					if data.classMask == ClassArmorTypeMask[i] then
						correctClass = true;
						break;
					end
				end
			end
		else
			if not addon.Profile.IgnoreClassRestrictions then 
				local classInfo = CLASS_INFO[playerClass]
				local className = (classMask and GetClassInfo(classMask)) or nil
				correctClass = data.classMask == classInfo[1] or not data.classMask
			else
				correctClass = true
			end
		end
	end

	if addon.Profile.CurrentFactionSets and (data.requiredFaction and GetFactionID(data.requiredFaction) == GetFactionID(playerFaction) or data.requiredFaction == nil) 
		or not addon.Profile.CurrentFactionSets then
			correctFaction =  true
	end

--if true then return true end

	--local search = addon:SearchSets(data)
	if correctFaction
	and correctClass 
	and correctHeratiage
	--and search
	then
		return true
	else
		return false;
	end
end

-- Gets all the Blizzard sets, filters out any sets shown in the base set tab and adds them to the apropriate ArmorDB
function BuildBlizzSets()
	addon.SetsDataProvider:ClearSets();
	addon:ClearCache()

	local initSpecialSet, initTradingPostSet
	local tradingPostGlobalString = Globals.TRADING_POST_LABEL;

	local allSets = C_TransmogSets.GetAllSets()
	for i, data in ipairs(allSets) do
		data.setType = "Blizzard"
		if not (data.name == "PH") and UseSet(data) then
			data.expansionID  = data.expansionID + 1
			data.BuildBlizzSets = true
			data.setType = "Blizzard"

			if data.classMask == 16383 then
				 data.classMask = 0
			elseif data.classMask == 4164 then
				data.classMask = 68
			elseif data.classMask == 2048 then
					data.classMask = 3592
			elseif data.classMask == 256 then
					data.classMask = 400
			elseif data.classMask == 32 then
				data.classMask = 35
			end


			if data.classMask and Globals.CLASS_MASK_TO_ID[data.classMask] then 
				data.classID = Globals.CLASS_MASK_TO_ID[data.classMask]
				data.className, data.classTag = GetClassInfo(data.classID);
			end
		
			data.tab = 2
			data.filter = Globals.GetBlizzardSetFilter(data)

				--Fix set description
				if addon.MiscSets.CustomDesc[data.setID] then
					data.description = addon.MiscSets.CustomDesc[data.setID];
				end

			--Combine special cases
			if addon.Profile.CombineSpecial and data.classMask == 0 and addon.MiscSets.SPECIAL_SETS[data.setID] then
				data.note = data.label;
				data.label = SPECIAL;

				if not initSpecialSet then
					initSpecialSet = data.setID;
					baseIDs[data.setID] = data;
					baseListLabels[data.label] = data.setID; 
					table.insert(baseList, data);
					AddVariant(data, data.setID);

				else
					data.baseSetID = initSpecialSet;
					AddVariant(data, initSpecialSet);
					if data.favorite then
						if baseSet and not baseSet.favoriteSetID then
							baseSet.favoriteSetID = data.setID;
						end
					end
				end

			elseif addon.Profile.CombineTradingPost and data.label == tradingPostGlobalString  then --or addon.MiscSets.TRADINGPOST_SETS[data.setID]  then -- or addon.MiscSets.TRADINGPOST_SETS[data.setID] then
					if not initTradingPostSet then
						initTradingPostSet = data.setID;
						baseIDs[data.setID] = data;

						baseListLabels[data.label] = data.setID;
						table.insert(baseList,data);

						AddVariant(data, data.setID);
					else
						data.baseSetID = initTradingPostSet;
						AddVariant(data, initTradingPostSet);
						if data.favorite then
							local baseSet = BetterWardrobeSetsDataProviderMixin:GetSetByID(initTradingPostSet);
							if not baseSet.favoriteSetID then
								baseSet.favoriteSetID = data.setID;
							end
						end
					end
			else
				
				if (not data.description) then
					if addon.Globals.CLASS_NAMES[data.classMask] then
						data.description = addon.Globals.CLASS_NAMES[data.classMask][1];
					else
						data.description = data.name;
					end
				end
				
				if addon.Globals.CLASS_NAMES[data.classMask] then
					--=data.description = addon:GetClassColor(data.classMask, data.description);
				end

				if addon.MiscSets.REMIX_SETS[tonumber(data.setID)] then
					data.customGroups = data.label.."-"..data.name
					data.label = "Mists of Pandaria: Remix"
				end

				if addon.MiscSets.customGroups[tonumber(data.setID)] then
					data.customGroups = addon.MiscSets.customGroups[tonumber(data.setID)]
				end				

				if data.label == tradingPostGlobalString then
					data.customGroups = data.name
				end				
			
				local subSet = false;
				local subSetBaseID;
				SET_INDEX[data.setID] = data
				fullList[data.setID] = data



				if data.customGroups and baseListLabels[data.customGroups] then
					subSet = true;
					subSetBaseID = baseListLabels[data.customGroups]
				
				elseif not data.customGroups and data.label and baseListLabels[data.label] then
					subSet = true;
					subSetBaseID = baseListLabels[data.label]
				end
			
				if subSet then
					if data.favorite then
						----if not baseIDs[subSetBaseID].favoriteSetID then
						----	baseIDs[subSetBaseID].favoriteSetID = data.setID;
						----end
					end

					AddVariant(data, subSetBaseID);
					data.baseSetID = subSetBaseID;
				else
					baseIDs[data.setID] = data;

					if data.customGroups then
						baseListLabels[data.customGroups] = data.setID;

					elseif data.label then
						baseListLabels[data.label] = data.setID;
					end

					table.insert(baseList, data);
					AddVariant(data, data.setID);
				end
			end
		end
	end
end


local function getClassMask(mask)
	for i, d in pairs(addon.Globals.CLASS_INFO) do 

		if mask == d[2] then return d[1] end
	end
end

local UIID_Counter = {1,1150,2000,3390,4580,6200,8000,10110,11000,12000}

local function OpposingFaction(faction)
	local faction = UnitFactionGroup("player")
	if faction == "Horde" then
		return "Alliance", "Stormwind", 1 -- "Kul Tiras",
	elseif faction == "Alliance" then
		return "Horde", "Orgrimmar", 2 -- "Zandalar",
	end
end

addon.ArmorSetModCache = {}
do
	local function BuildArmorDB()
		addon.SetsDataProvider:ClearSets();
		local playerFaction, _ = UnitFactionGroup('player')
		local buildID = (select(4, GetBuildInfo()))
		BuildBlizzSets()

		--@debug@
			--addon:AddTestSets()
		--@end-debug@


		local dropdownclass = C_TransmogSets.GetTransmogSetsClassFilter();
		local at = Globals.ClassArmorType[dropdownclass]
		local ty = Globals.ARMOR_TYPE[at]
			armorType = ty or addon.Globals.CLASS_INFO[playerClass][3]
			ArmorDB[armorType] = {}
			local armorSetdata = {addon.ArmorSets[armorType], addon.ArmorSets["COSMETIC"]}
		for armorType, data in ipairs(armorSetdata) do
			ArmorDB[armorType] = {}

			for id, data in pairs(data) do
				--print(UseSet(data))
				if (data.requiredFaction and data.requiredFaction == GetFactionID(playerFaction) or data.requiredFaction == nil) and 
					--(not data.BuildBlizzSets and (data.filter ~= 5 and data.filter ~= 7 and data.filter ~= 11)) and  UseSet(data) then 
					(not data.BuildBlizzSets ) and  UseSet(data) then 

					--data.isHeritageArmor = string.find(data.name, "Heritage")

					local classInfo = CLASS_INFO[playerClass]
					local classMask = getClassMask(data.classMask)
					local class =  (data.classMask)
					local className = (classMask and GetClassInfo(classMask)) or nil
					
					data.isClass = data.classMask == classInfo[1] or not data.classMask
					--local class = (data.classMask and data.classMask == 0) or (data.classMask and bit.band(data.classMask, classInfo[2])  == classInfo[2]) or not data.classMask
					data.className = data.classMask and GetClassInfo(data.classMask)

					data["name"] = L[data["name"]]
					data.oldnote = data.label

					if not data.note then
						local note = "NOTE_"..(data.label or 0)
						data.note = note

						data.label = L[note] or ""
					end

					--local baseItem = data.items[1]
					----local visualID, sourceID = addon.GetItemSource(baseItem)
					----data.itemAppearance = addon.ItemAppearance[visualID]
					data.armorType = armorType
					data.setType = "ExtraSet"
					data.oldID = data.setID
					data.tab = 3

					local newID = 10000 + id

					data.setID = newID

					data.newStatus = false


					data.itemData = data.itemData or {}

					data.validForCharacter = true;


					--for slotID, itemData in pairs(data.itemData) do
					--	local appearanceID = itemData[3]
						--if appearanceID  then --and data.sources[item] and data.sources[item] ~= 0 then 
							--local appearanceID = data.sources[item]
						--	ItemDB[appearanceID] = ItemDB[appearanceID] or {}
						--	ItemDB[appearanceID][newID] = data
					--	end
					--end

					local subSet = false;
					local subSetBaseID;
					local subName = gsub(data.name, " %(Recolor%)", "")
					if data.note == data.note == "NOTE_119" or data.note == "NOTE_120" or data.note == "NOTE_121" or data.note == "NOTE_123"   then
						data.customGroups = data.label
					elseif data.note == "NOTE_44" or data.note == "NOTE_45" then
						data.customGroups =  data.label.."-"..subName--data.armorType

					elseif addon.MiscSets.customGroups[tonumber(data.setID)] then
						data.customGroups = addon.MiscSets.customGroups[tonumber(data.setID)]
					elseif data.custom then
						data.customGroups = data.custom --or data.label.."-"..subName--data.armorType
					end

					if data.customGroups and baseListLabels[data.customGroups]  then
						subSet = true;
						subSetBaseID = baseListLabels[data.customGroups]
					--elseif data.name ~= subName then
						--subSet = true;

						--data.tab = 2
						--subSetBaseID = baseListLabels[subName]
					elseif not data.customGroups and data.label and baseListLabels[data.label] then

					--elseif data.label and baseListLabels[data.label] then
						subSet = true;
						subSetBaseID = baseListLabels[data.label]
					end

				--print(data.name)
					
					if subSet then
						AddVariant(data, subSetBaseID);
						data.baseSetID = subSetBaseID;

					else
						baseIDs[data.setID] = data;

						data.baseSetID = data.setID;


						if data.customGroups then
							baseListLabels[data.customGroups] = data.setID;

						elseif data.name then
							baseListLabels[data.label] = data.setID;
						end

						--baseListLabels[data.label] = data.setID;

						table.insert(baseList, data);
						AddVariant(data, data.setID);
					end
					data.sources = {}

					data.newStatus = false
					local isCollected = true
					for i, itemData in pairs(data.itemData) do
						if subitemlist[item] then 
							local replacementID = subitemlist[item]
							local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(replacementID)
							local sources = C_TransmogCollection.GetAppearanceSources(appearanceID)
							WardrobeCollectionFrame_SortSources(sources)
							setData["items"][index] = replacementID
							setData.sources[item] = nil
							setData.sources[replacementID] = appearanceID
						else
							local info = C_TransmogCollection.GetSourceInfo(itemData[2])
							data.sources[itemData[2]] = info.isCollected
							if isCollected then isCollected = info.isCollected end
						end
					end
					data.isCollected = isCollected
					if isCollected then
						extraSetCollectedCount = extraSetCollectedCount + 1
					end
					data.uiOrder = UIID_Counter[data.expansionID] -- id * 100
					SET_INDEX[newID] = data
					ArmorDB[armorType][newID] = data

					extraSetCount = extraSetCount + 1

				end
			end
		end
		--print(extraSetCount)
		--addon.ArmorSets = nil
	end


function addon:GetCollectedExtraSetCount()
	return extraSetCollectedCount, extraSetCount
end

	function addon.IsSetItem(itemLink)
		if not itemLink then return end

		local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemLink)
		if not ItemDB[appearanceID] then 
			return nil 
		else
			return ItemDB[appearanceID]
		end
	end


	function addon.HasSubItem(sourceID)
		if subitemlist[sourceID] then
			local sourceInfo = C_TransmogCollection.GetSourceInfo(subitemlist[sourceID])
			--print("found")
			return subitemlist[sourceID]
		end
	end

	local function buildSetSubstitutions()
		wipe(subitemlist)
		subitemlist = subitemlist or {}
		if not addon.itemsubdb.profile.items then return end

		for itemID, sub_data in pairs(addon.itemsubdb.profile.items) do
			local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemID)
			--print(sourceID)
			local appearanceID2, sourceID2 = C_TransmogCollection.GetItemInfo(sub_data.subID)
			--print(sourceID)

			subitemlist[sourceID] = sourceID2
			--[[local _, visualID, _, _, _, itemLink = C_TransmogCollection.GetAppearanceSourceInfo(appearanceID)	
			local sources = (itemLink and C_TransmogCollection.GetAppearanceSources(appearanceID, addon.GetItemCategory(appearanceID), addon.GetTransmogLocation(itemLink)) )
			if sources then 
				for i, data in ipairs(sources) do
					subitemlist[data.itemID] = sub_data.subID
				end
			end
			subitemlist[itemID] = sub_data.subID
			]]--
		end
	end 


	function addon.Init:UpdateCollectedAppearances()
		for i = FIRST_TRANSMOG_COLLECTION_WEAPON_TYPE, LAST_TRANSMOG_COLLECTION_WEAPON_TYPE - 1 do
			local location = TransmogUtil.GetTransmogLocation(addon.Globals.CATEGORYID_TO_NAME[i], Enum.TransmogType.Appearance, false)
			local appearances = C_TransmogCollection.GetCategoryAppearances(i, location)
			for _, appearance in pairs(appearances) do
				local sources = C_TransmogCollection.GetAppearanceSources(appearance.visualID, i, location)
				for _, source in pairs(sources) do
					if source.isCollected then
						collectedAppearances[appearance.visualID] = true
						break
					end
				end
			end
		end
	end

	function addon.Init:InitDB()
		addon:ClearCache()
		--buildSetSubstitutions()

		BuildArmorDB()
		--addon.Init:BuildDB()
		addon.BuildClassArtifactAppearanceList()
		--addon.GetSavedList()
	end
	
	function addon.Init:BuildDB()
		addon.SetsDataProvider:ClearSets();
		--buildSetSubstitutions()
		local armorSet = ArmorDB[addon.selectedArmorType] or ArmorDB[CLASS_INFO[playerClass][3]]
		--wipe(SET_INDEX)
		--Add Hidden Set
		------SET_INDEX[0] = hiddenSet
		BuildArmorDB()
		addon.BuildClassArtifactAppearanceList()
		addon.GetSavedList()
	end

	function addon.Init:BuildAltDB()
		addon.ClearSourceDB()
		buildSetSubstitutions()
		local armorSet = ArmorDB[addon.selectedArmorType]
		--wipe(SET_INDEX)
		addArmor(armorSet, SET_DATA)
		addArmor(ArmorDB["COSMETIC"], SET_DATA)
		--Add Hidden Set
		--ALT_SET_INDEX[0] = hiddenSet
		--tinsert(SET_DATA, hiddenSet)
		--addon.BuildClassArtifactAppearanceList()
	end

	function addon:ClearCache()
		wipe(addon.ArmorSetModCache)
		wipe(SET_INDEX)
		wipe(fullList)
		-----addon.ClearArtifactData()
		addon.SavedSetCache =  nil

		wipe(baseListLabels)
		wipe(baseList)
		wipe(baseIDs)
		wipe(variantSets)
		wipe(variantIDs)
	end

	function addon.GetBaseList()
		if addon.refreshData then 
			addon.Init:BuildDB()
			addon.refreshData = false
		end
		return baseIDs
	end

	local MAX_DEFAULT_OUTFITS = C_TransmogCollection.GetNumMaxCustomSets() --(25

	function addon:GetBlizzID(outfitID)

		return outfitID - SET_OFFSET

	end

	local profileCache = {}
	local savedSetID = SET_OFFSET+1000

	local function loadAltsSavedSets(profile)
		if not addon.setdb.global.sets[profile] then return {} end

		if not profileCache[profile] then 
			local FullList = CopyTable(addon.setdb.global.sets[profile])
			--FullList = addon.setdb.global.sets[addon.SelecteSavedList]
			for i, data in ipairs(FullList) do
				data.setType = "SavedExtra"
				savedSetID = savedSetID + 1
				data.outfitID = savedSetID
				data.label = L["Saved Set"]

				if data.sources  then
					for index, sourceID in pairs(data.sources) do 
						--local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
						data[index] =  sourceID
					--	if sourceInfo and sourceInfo.invType then  
						--	local appearanceID = sourceInfo.visualID
							--local itemID = sourceInfo.itemID
							--local itemMod = sourceInfo.itemModID
						--	local sourceID = sourceInfo.sourceID
							--data.itemData = data.itemData or {} 
							--data.itemData[index] = {"'"..itemID..":"..itemMod.."'", sourceID, appearanceID}
						--end
					end
					data.sources = nil
				else
					--data.sources = {}
						for i=1, 19 do
							--data.sources[i] = data[i] or 0
						end
				end
			end

			if addon.OutfitDB.sv.char[profile] and addon.OutfitDB.sv.char[profile].outfits  then 
				local extendeSets = CopyTable(addon.OutfitDB.sv.char[profile].outfits)

				if extendeSets then 
					for i, data in ipairs(extendeSets) do
				----data.setType = "SavedExtra"
				--savedSetID = savedSetID + 1
				--data.outfitID = savedSetID
				----data.label = L["Saved Set"]
						tinsert(FullList, data)
					end
				end
			end

			profileCache[profile] =  FullList
		end

		return profileCache[profile]
	end

	function addon.GetOutfits(character)
		local name = UnitName("player")
		local realm = GetRealmName()
		local profile = addon.SelecteSavedList 
		local FullList = {}
		local savedOutfits
		if addon.SelecteSavedList and not character then 
			FullList = loadAltsSavedSets(profile)
		else
			--Blizzard Sets
			local outfits = C_TransmogCollection.GetCustomSets(); --C_TransmogCollection.GetOutfits();
			local baseID = 0
			for i, outfitID in ipairs(outfits) do
				local data = {}
				local name, icon = C_TransmogCollection.GetCustomSetInfo(outfitID);
				data.setType = "SavedBlizzard"
				data.index = i

				data.outfitID = outfitID + SET_OFFSET

				data.name = name
				data.icon = icon
				data.label = L["Saved Set"]
				FullList[i] = data
				data.validForCharacter = true
			end

			--Extended Sets
			if addon.OutfitDB.char.outfits then 
				for i, data in ipairs(addon.OutfitDB.char.outfits) do
					data.outfitID = MAX_DEFAULT_OUTFITS + i + SAVED_SET_OFFSET

					data.index = i
					data.name = addon.OutfitDB.char.outfits[i].name
					local sourceInfo
					data.setType = "SavedExtra"
					data.label= L["Extended Saved Set"]
				data.validForCharacter = true

					--data.itemData should hold the most current set data
					if data.itemData and #data.itemData ~= 0 then
						for i=1, 19 do
							local source
							local setInfo = data.itemData[i]
							if setInfo then
								data[i] = setInfo[2]
							else 
								data[i] = 0
							end
						end

					elseif (not data.itemData or #data.itemData == 0) then
						if data.itemTransmogInfoList then
							for i=1, 19 do
								local source = (data.itemTransmogInfoList[i] and data.itemTransmogInfoList[i].appearanceID) or 0
								local illusionID = (data.itemTransmogInfoList[i] and data.itemTransmogInfoList[i].illusionID) or 0
								local offShoulder = (data.itemTransmogInfoList[i] and data.itemTransmogInfoList[i].secondaryAppearanceID) or 0
								data[i] = source

								if i == 3 then
									data.offShoulder = offShoulder
								elseif i == 16 then
									data.mainHandEnchant  = illusionID
								elseif i == 17 then
									data.offHandEnchant  = illusionID
								end
							end
							data.sources = nil
							data.itemTransmogInfoList = nil
							data.items = nil
							data.validForCharacter = true
							data.icon = icon

						elseif data.sources and  #data.sources ~= 0 then
							for item_data, source_data in pairs(data.sources) do 
								--print(source_data)
								--itemlink, appearance pairs
								if string.find(item_data, "item:") then 
									local _, sourceID = C_TransmogCollection.GetItemInfo(item_data)
									sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)

								--itemID, appearance/source pairs.  Checking for both to catch all possible saved types
								else
									local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(item_data)
									if appearanceID and appearanceID == source_data then 
									elseif appearanceID then 
										for itemMod = 1, 10 do
											appearanceID, sourceID = C_TransmogCollection.GetItemInfo(item_data, itemMod)
											if appearanceID == source_data then 
												break
											end
										end
									end

									sourceInfo = sourceID and C_TransmogCollection.GetSourceInfo(sourceID)
									--value returned info and the itemID matches, so its was an appearanceID
									if sourceInfo and sourceInfo.itemID == item_data then 

									else
									--value returned info and the itemID matches, so its was an sourceID
										sourceInfo = C_TransmogCollection.GetSourceInfo(source_data)
										if sourceInfo and sourceInfo.itemID == item_data then 
										else
											sourceInfo = nil
										end
									end
								end

								if sourceInfo and sourceInfo.invType then  
									local slot = C_Transmog.GetSlotForInventoryType(sourceInfo.invType);
									local sourceID = sourceInfo.sourceID
									data[slot] = sourceID
								end
							end
						end
					end

					--Clear older junk
					data.sources = nil
					data.itemTransmogInfoList = nil
					data.items = nil
					data.itemData = nil
			
					tinsert(FullList, data)
				end
			end
		
		end


		return FullList
	end



	function addon.IsDefaultSet(outfitID)
		local savedSets = addon.GetSavedList()
		for i, data in ipairs(savedSets) do
			if data.setID == outfitID and data.setType == "SavedBlizzard" then 
				return true
			end
		end
		return false
		--local MAX_DEFAULT_OUTFITS = C_TransmogCollection.GetNumMaxOutfits()
		----return outfitID < MAX_DEFAULT_OUTFITS  -- #C_TransmogCollection.GetOutfits()--MAX_DEFAULT_OUTFITS 
	end

	function addon.GetSetType(outfitID)

			if outfitID >= SET_OFFSET and outfitID < (SET_OFFSET + MAX_DEFAULT_OUTFITS) then return "SavedBlizzard" end


			local setData = addon.GetSetInfo(outfitID)
		return setData and setData.setType or nil
	end


	function addon.StoreBlizzardSets()
		local BlizzardSavedSets = {}
		local outfits = C_TransmogCollection.GetCustomSets();
		for i, outfitID in ipairs(outfits) do
			local data = {}
			local name, icon = C_TransmogCollection.GetCustomSetInfo(outfitID);
			data.index = i
			data.outfitID = outfitID
			data.name = name
			data.icon = icon

			local outfitItemTransmogInfoList = C_TransmogCollection.GetCustomSetItemTransmogInfoList(outfitID);
			data.sources = {}
			for i, list_data in pairs(outfitItemTransmogInfoList) do
				data.sources[i] = list_data.appearanceID or 0
			end
			tinsert(BlizzardSavedSets, data)
		end

		addon.setdb.global.sets[addon.setdb:GetCurrentProfile()] = BlizzardSavedSets
		return BlizzardSavedSets
	end


	function addon.GetSavedList()
		--if not addon.savedSetCache then 
			local savedOutfits = addon.GetOutfits()
			local list = {}
			SET_INDEX = SET_INDEX or {}
			fullList = fullList or {}
			for index, data in ipairs(savedOutfits) do
				local info = {}
				info.items = data.items or {}
				info.sources = data.sources or {}
				info.collected = true
				info.name = data.name
				info.setType = data.setType
				info.label = data.label
				info.description = ""
				info.expansionID = 1
				info.favorite = false
				info.hiddenUntilCollected = false
				info.limitedTimeSet = false
				info.patchID = 0
				info.setID = data.setID or (data.outfitID)
				info.uiOrder = data.uiOrder or (data.index * 100)
				info.icon = data.icon
				info.isClass = true
				info.mainShoulder = data[3] or 0
				info.offShoulder = data.offShoulder or 0
				info.itemTransmogInfoList = data.itemTransmogInfoList
				info.validForCharacter = true

				info.mainHandEnchant = data.mainHandEnchant
				info.offHandEnchant = data.offHandEnchant

				info.itemData = data.itemData
				info.baseSetID = info.setID;
				info.savedSet = true

				if data.setType == "SavedBlizzard" then 

					 outfitItemTransmogInfoList = C_TransmogCollection.GetCustomSetItemTransmogInfoList(data.outfitID - SET_OFFSET);

					info.sources = {}
					for i, infoList in pairs(outfitItemTransmogInfoList) do
						info.sources[i] = infoList.appearanceID
					end

				elseif data.setType == "SavedExtra" then
					local ItemTransmogInfoList = {}
					info.sources = info.sources or {}
					for slotID = 1, 19 do
						local sourceID = data[slotID]
						info.sources[slotID] = 0
						if sourceID  and sourceID ~= NO_TRANSMOG_SOURCE_ID and sourceID ~= 0 then 
							 sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
									
							if sourceInfo and sourceInfo.invType then 
								local slot = C_Transmog.GetSlotForInventoryType(sourceInfo.invType);
								local appearanceID = sourceInfo.visualID
								local itemID = sourceInfo.itemID
								local itemMod = sourceInfo.itemModID
								info.itemData = info.itemData or {}
								info.itemData[slot] = {"'"..itemID..":"..itemMod.."'", sourceID, appearanceID}
								info.sources[slotID] = sourceInfo.sourceID
							end
						end
						--end

							--[[local illusionID
																					if slotID == 16 then 
																						illusionID = data["mainHandEnchant"] or 0
																					elseif slotID == 17 then 
																						illusionID = data["offHandEnchant"] or 0
																					else
																						illusionID = 0
																					end
																					ItemTransmogInfoList[slotID] = ItemUtil.CreateItemTransmogInfo(data[slotID] or 0, 0, illusionID);]]
					end







					----info.sources = C_TransmogCollection.GetOutfitSources(data.outfitID)
				--elseif  #info.sources == 0 then 
					--for i = 1, 19 do  ----was 16?
						--info.sources[i] = data[i] or 0
					--end
				--end



--[[

									--converts setdata to new info lists
					if not data.itemTransmogInfoList then 
						local outfitData = {}
						outfitData["outfitID"] = data.outfitID
						outfitData["name"] = data.name
						outfitData["set"] = data.set
						outfitData["icon"] = data.icon
						outfitData["index"] = data.index

						local ItemTransmogInfoList = {}
						--for dataIndex, sourceID in ipairs(data) do
						for i = 1, 19  do
							local illusionID
							if i == 16 then 
								illusionID = data["mainHandEnchant"]
							elseif i == 17 then 
								illusionID = data["offHandEnchant"]
							else
								illusionID = 0
							end
							ItemTransmogInfoList[i] = ItemUtil.CreateItemTransmogInfo(data[i] or 0, 0, illusionID);
							----outfit = outfitData

						end
						--ItemTransmogInfoList["Clear"] = nil 
						--ItemTransmogInfoList["IsEqual"] = nil 
						--ItemTransmogInfoList["Init"] = nil 
						outfitData["ItemTransmogInfoList"] = ItemTransmogInfoList

						--addon.OutfitDB.char.outfits[data.index] = outfitData
						--data = outfitData
						--outfitData["ItemTransmogInfoList"] = ItemTransmogInfoList
					end]]

					--info.itemTransmogInfoList = data.itemTransmogInfoList
				end

				baseIDs[info.setID] =  info;
				table.insert(baseList, info);

				SET_INDEX[info.setID] = info
				fullList[info.setID] = info
				tinsert(list, info)
			end
			
			addon.SavedSetCache = list
	--	end
		return addon.SavedSetCache
	end

--[[
				{
					77497, -- [1]
					nil, -- [2]
					94136, -- [3]
					84536, -- [4]
					54411, -- [5]
					4307, -- [6]
					45096, -- [7]
					10642, -- [8]
					25667, -- [9]
					53708, -- [10]
					nil, -- [11]
					nil, -- [12]
					nil, -- [13]
					nil, -- [14]
					22804, -- [15]
					0, -- [16]
					["outfitID"] = 21,
					["index"] = 1,
					["name"] = "5-554",
					["set"] = "extra",
					[19] = 35448,
					["mainHandEnchant"] = 0,
					["icon"] = 1130280,
					["offHandEnchant"] = 0,]]


	--[[function addon.AddSet(setData)
				local id = setData[1]
		
				local info = {}
				info.classMask = setData[4] --class
				info.collected = false 	
				info.description = ""
				info.expansionID	= ""
				info.favorite = ""
				info.hiddenUntilCollected = false
				info.label = ""
				info.limitedTimeSet = false
				info.name = setData[2]--name
				info.patchID = ""
				info.requiredFaction = setData[5]--faction
				info.setID = id
				info.uiOrder = ""
				info.items = setData[3]--items
		
				setInfo[id] = info
				tinsert(baseList, setInfo[id])
			end]]


	function addon.GetSetInfo(setID)
			local atTransmogrifier = C_Transmog.IsAtTransmogNPC()
		--if atTransmogrifier then 
			return fullList[setID]
		--else
			--return SET_INDEX[setID]
		--end

	end

	function addon.GetSets()
		local atTransmogrifier = C_Transmog.IsAtTransmogNPC()
		--if atTransmogrifier then 
			return fullList
		--else
			--return SET_INDEX
		--end
	end 

	function addon.GetFullSets()

	return 	fullList
end
	function addon.SetItemSubstitute(itemID, subID)
		itemID = tonumber(itemID)
		subID = tonumber(subID)

		if type(itemID) ~= "number" or type(subID) ~= "number" then 
			BetterWardrobeOutfitManager:ShowPopup("BETTER_WARDROBE_SUBITEM_INVALID_POPUP")
			return false 
		end
		local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant
		local _, _, _, itemEquipLoc1 = GetItemInfoInstant(itemID) 
		local _, _, _, itemEquipLoc2 = GetItemInfoInstant(subID) 

		if itemEquipLoc1 ~= itemEquipLoc2 then 
			BetterWardrobeOutfitManager:ShowPopup("BETTER_WARDROBE_SUBITEM_WRONG_LOCATION_POPUP")
			return false 
		else
			local GetItemInfo = C_Item and C_Item.GetItemInfo
			local itemName1, link1 = GetItemInfo(tonumber(itemID))
			local itemName2, link2 = GetItemInfo(tonumber(subID))

			--local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemID|itemString [, itemModID])
			addon.itemsubdb.profile.items[itemID] = {["subID"] = subID, ["itemLink"] = link1, ["subLink"] = link2}

			local item = Item:CreateFromItemID(itemID)
			item:ContinueOnItemLoad(function()
				addon.itemsubdb.profile.items[itemID].itemLink = item:GetItemLink()
				addon.RefreshSubItemData()
			end)

			local item2 = Item:CreateFromItemID(subID)
			item2:ContinueOnItemLoad(function()
				addon.itemsubdb.profile.items[itemID].subLink = item2:GetItemLink()
				addon.RefreshSubItemData()
			end)

			addon:ClearCache()
			addon.SetsDataProvider:ClearSets()

			addon.Init:BuildDB()

			if BetterWardrobeCollectionFrame.SetsCollectionFrame:IsShown() then  --0--TODO FIX
				BetterWardrobeCollectionFrame.SetsCollectionFrame:Refresh()
				BetterWardrobeCollectionFrame.SetsCollectionFrame:OnSearchUpdate()
			end
			addon.RefreshSubItemData()
		end
	end

	function addon:RemoveItemSubstitute(itemID)
		if not itemID  then
			return false
		end
		--local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemID|itemString [, itemModID])
		local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(tonumber(itemID))
		local sources = C_TransmogCollection.GetAllAppearanceSources(appearanceID)
		--local sources = C_TransmogCollection.GetAppearanceSources(appearanceID)

		for i, source_ID in ipairs(sources) do
			local info = C_TransmogCollection.GetSourceInfo(source_ID)
			addon.itemsubdb.profile.items[info.itemID] = nil
		end


			addon:ClearCache()
			addon.SetsDataProvider:ClearSets()

			addon.Init:BuildDB()
			addon.GetBaseList()
			if BetterWardrobeCollectionFrame.SetsCollectionFrame:IsShown() then  --0--TODO FIX
				BetterWardrobeCollectionFrame.SetsCollectionFrame:Refresh()
				BetterWardrobeCollectionFrame.SetsCollectionFrame:OnSearchUpdate()
			end
			addon.RefreshSubItemData()



		addon:ClearCache()

		addon.Init:BuildDB()
		addon.GetBaseList()
		addon.RefreshSubItemData()
		addon.RefreshLists()
	end

	function addon.GetItemSource(itemID, itemMod)

		if addon.ArmorSetModCache[itemID] and addon.ArmorSetModCache[itemID][itemMod] then return addon.ArmorSetModCache[itemID][itemMod][1], addon.ArmorSetModCache[itemID][itemMod][2] end
			local itemSource
			local visualID, sourceID
			local f =  addon.frame
			if itemMod then
				visualID, sourceID = C_TransmogCollection.GetItemInfo(itemID, itemMod)
			else
				visualID, sourceID = C_TransmogCollection.GetItemInfo(itemID)
			end

			if not sourceID then
				local itemlink = "item:"..itemID..":0"
				f.model:Show()
				f.model:Undress()
				f.model:TryOn(itemlink)
				local  TransmogInfoList = f.model:GetItemTransmogInfoList()
				for i = 1, 19 do
					local source = 10000---- f.model:GetSlotTransmogSources(i)
					if source ~= 0 then
						--addon.itemSourceID[itemID] = source
						sourceID = source
						break
					end
				end
			end

			if not sourceID then 
				visualID, sourceID = C_TransmogCollection.GetItemInfo(itemID, 0)
			end

		--[[		if sourceID and itemMod then
							addon.modArmor[itemID] = addon.modArmor[itemID] or {}
							addon.modArmor[itemID][itemMod] = sourceID
						end]]
			if sourceID and itemMod then 
				addon.ArmorSetModCache[itemID] = addon.ArmorSetModCache[itemID]  or {}
				addon.ArmorSetModCache[itemID][itemMod] = {visualID, sourceID}
			end

			f.model:Hide()
		return visualID ,sourceID
	end

	-- 12.0.7 removed C_TransmogSets.GetSetSources. Callers still want its sourceID -> collected
	-- map, so rebuild it from the primary appearance list that survived.
	function addon.GetSetSources(setID)
		local sources = {}
		for _, appearance in ipairs(addon.C_TransmogSets.GetSetPrimaryAppearances(setID) or {}) do
			sources[appearance.appearanceID] = appearance.collected
		end
		return sources
	end

	function addon:IsCollected(visualID)
		return collectedAppearances[visualID]
	end
end

StaticPopupDialogs["BETTER_WARDROBE_SUBITEM_WRONG_LOCATION_POPUP"] = {
	preferredIndex = 3,
	text = "Item Locations Do Not Match",
	button1 = OKAY,
	button2 = CANCEL,
	OnShow = function(dialog, data)

	end,
	OnAccept = function(dialog, data)
	end,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
}

StaticPopupDialogs["BETTER_WARDROBE_SUBITEM_INVALID_POPUP"] = {
	preferredIndex = 3,
	text = "Sub Item is",
	button1 = OKAY,
	button2 = CANCEL,
	OnShow = function(dialog, data)

	end,
	OnAccept = function(dialog, data)
	end,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
}

	local SetSwaps = {}
	function addon.HasSubItem(setID)
				return SetSwaps[setID]
	end --SetSwaps[setID][itemFrame.sourceID] then

	function addon.GetSubItem(sourceID, setID)
		local newSource = subitemlist[sourceID]
		if newSource then
			SetSwaps[setID] = SetSwaps[setID] or {}
			SetSwaps[setID][newSource] = true
			return subitemlist[sourceID]
		end
	end
