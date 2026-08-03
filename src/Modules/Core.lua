--	///////////////////////////////////////////////////////////////////////////////////////////
--
--	Better Wardrobe and Collection
--	Author: SLOKnightfall
--	Wardrobe and Collection: Adds additional functionality and sets to the transmog and collection areas
--
--
--	///////////////////////////////////////////////////////////////////////////////////////////
	local CONFIG = ...
	local ADDON, Addon = CONFIG:match('[^_]+'), _G[CONFIG:match('[^_]+')]
local addonName, addon = ...
---addon = LibStub("AceAddon-3.0"):NewAddon(addon, addonName, "AceEvent-3.0", "AceConsole-3.0", "AceHook-3.0")
addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
--_G[addonName] = {}
addon.Frame = LibStub("AceGUI-3.0")
addon.itemSourceID = {}
addon.QueueList = {}
addon.validSetCache = {}
addon.usableSourceCache = {}
addon.UI = {}
addon.Init = {}
addon.Plugins = {}
local newTransmogInfo  = {["latestSource"] = NO_TRANSMOG_SOURCE_ID} --{[99999999] = {[58138] = 10}, }
addon.TRANSMOG_SET_FILTER = {}
_G[addonName] = {}

local playerInv_DB
local Profile
local playerNme
local realmName
local playerClass, classID,_
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant

local screenWidth =  math.floor(UIParent:GetWidth())

addon.PREFIX = "|cff00cc00Lucky's Better Wardrobe:|r"

--- Dev logging via LuckyLog, gated on the Dev Mode setting.
addon.DevLog = LuckyLog:New(addon.PREFIX, function()
	return addon.Profile and addon.Profile.DevMode
end)

-- ponytail: Ace config UI removed. These stay as no-op stubs because DataBase.lua
-- still calls RefreshSubItemData, and AceDB profile callbacks reference the others.
function addon.RefreshSubItemData() end
function addon.RefreshCollectionListData() end
function addon.RefreshOutfitData() end

--ACE Profile Saved Variables Defaults
local defaults = {
	profile = {
		['*'] = true,
		PartialLimit = 4,
		ShowHidden = false,
		TSM_Market = "DBMarket",
		TooltipPreview_Width = 300,
		TooltipPreview_Height = 300,
		ShowItemIDTooltips = false,
		ShowOwnedItemTooltips = true,
		ShowSetTooltips = true,
		TooltipPreview_Show = false,
		TooltipPreview_Anchor = "horizontal",
		TooltipPreviewRotate = false,
		TooltipPreview_Modifier = L["None"],
		TooltipPreview_ZoomItemModifier = L["None"],
		TooltipPreview_SwapModifier = L["None"],
		TooltipPreview_CustomRace = 1,
		TooltipPreview_CustomGender = 0,
		TooltipPreview_DressingDummy = false,
		IgnoreClassRestrictions = false,
		WowheadLinks = true,
		KeepTransmogTab = false,
		TrackSetsOnShiftClick = true,
		ShowSituationValues = true,
		ShowSituationTooltips = true,
		DevMode = false,
		CurrentFactionSets = true,
		ExtraLargeTransmogArea = false,
		ExtraLargeTransmogAreaMax = screenWidth,
		CollectionSetSortMode = "default",
		CollectionSetSortDirection = "ascending",
		SituationPresets = {},
		MinimapButton = {},
		ShowInstanceSets = true,
		InstanceSetsMaxMissing = 3,
		IncludeCurrentTier = false,
		InstanceSetsPosition = {},
		InstanceSetsDwellSeconds = 4,
		AlertSetPieceLoot = true,
		AlertCatalystLoot = TransmogUpgradeMaster_API ~= nil,
		MarkCatalysablePieces = TransmogUpgradeMaster_API ~= nil,
		AlertWithSound = true,
		AlertWithChat = true,
	}
}
local DB_Defaults = {
	char_defaults = {
		profile = {
			item = {},
			set = {},
			extraset = {},
			outfits = {},
			lastTransmogOutfitIDSpec = {},
			listUpdate = false,
		}
	},

	savedsets_defaults = {
		profile = {autoHideSlot = {}, sorting = 1,},
		global = {sets={}, itemsubstitute = {}, outfits = {}, updates = {},},

	},

	collectionList_defaults = {	
		profile = {
			collectionList = {item = {}, set = {}, extraset = {}, name = "CollectionList"},
			selectedCollectionList = 1,
			lists  = {{item = {}, set = {}, extraset = {}, name = "CollectionList"},},
		},
	},

	list_defaults = {
		profile = {item = {}, set = {}, extraset = {}, },
	},

 	itemsub_defaults = {
		profile = {items = {}}
	},

	charSavedOutfits_defaults = {
		char = {			
			item = {},
			set = {},
			extraset = {},
			outfits = {},
			lastTransmogOutfitIDSpec = {},
			listUpdate = false,
		}
	},
	collection_cache_defaults = {
		global = {sets={}, },

	},
}

local firstRun = false
local function UpdateDB()
	local characterDB = LuckysBetterWardrobe_CharacterData
	local listDB = LuckysBetterWardrobe_ListData
	local favoriteDB = listDB.favoritesDB or {}
	local collectionDB = listDB.collectionListDB or {}
	local hiddenDB = listDB.HiddenAppearanceDB or {}
	local outfitDB = listDB.OutfitDB or {}
	--local favoriteDB = self.favoriteListDB
	--local collectionDB = self.collectionListDB

	--Check to see if it is a new install
	if not characterDB or (characterDB and not characterDB.profiles) then firstRun = true; return end
	--Update 1. splt favorites and collection tables from characterDB. Update collections to allow multiple lists  10/27/20

	if listDB.lastUpdte ~= 1 then
	--Populate profile keys
		favoriteDB.profileKeys = CopyTable(characterDB.profileKeys)
		collectionDB.profileKeys = CopyTable(characterDB.profileKeys)
		hiddenDB.profileKeys = CopyTable(characterDB.profileKeys)

		--Create profile table
		favoriteDB.profiles = {}
		collectionDB.profiles = {}
		hiddenDB.profiles = {}

		--local profiles  = self.chardb:GetProfiles()
		--do the first db update to allow multiple lists

		for profile, data in pairs(characterDB.profiles) do
			data.lists = data.lists or {}

			if #data.lists == 0 and data.collectionList then
				local listcopy = CopyTable(data.collectionList)
				listcopy.name = L["Collection List"]
				tinsert(data.lists, listcopy)
			end
			data.collectionList = nil
		end
		
		-- do the second update to split into seperate profiles
		for profile, data in pairs(characterDB.profiles) do
			favoriteDB.profiles[profile] = {}
			if data.favorite_items then
				favoriteDB.profiles[profile].item = CopyTable(data.favorite_items)
				data.favorite_items = nil
			end
			if data.favorite then
				favoriteDB.profiles[profile].extraset = CopyTable(data.favorite)
				data.favorite = nil
			end

			collectionDB.profiles[profile] = {}
			if  data.selectedCollectionList then
				collectionDB.profiles[profile].selectedCollectionList = data.selectedCollectionList
				data.selectedCollectionList = nil
			end

			if data.lists then
				collectionDB.profiles[profile].lists = CopyTable(data.lists)
				data.lists = nil
			end

			hiddenDB.profiles[profile] = {}
			if data.item then
				hiddenDB.profiles[profile].item = CopyTable(data.item)
				data.item = nil
			end

			if data.set then
				hiddenDB.profiles[profile].set = CopyTable(data.set)
				data.set = nil
			end

			if data.extraset then
				hiddenDB.profiles[profile].extraset = CopyTable(data.extraset)
				data.extraset = nil
			end


			--collectionDB.profiles[profile].collectionList = nil
			
			
		end

		outfitDB.profileKeys = {}
		outfitDB.char = {}
		for profile, data in pairs(characterDB.profileKeys) do
			outfitDB.profileKeys[profile] = profile

			if characterDB.profiles[data] then
				outfitDB.char[profile] = {}
				if characterDB.profiles[data].outfits then
					outfitDB.char[profile].outfits = CopyTable(characterDB.profiles[data].outfits)
				end
				if characterDB.profiles[data].lastTransmogOutfitIDSpec then
					outfitDB.char[profile].lastTransmogOutfitIDSpec = CopyTable(characterDB.profiles[data].lastTransmogOutfitIDSpec)
				end
			end
		end

		listDB.lastUpdte = 1
	end
end

---Updates Profile after changes
function addon:RefreshConfig()
	addon.Profile = self.db.profile
	Profile = addon.Profile

	-- ponytail: the class restriction override is withdrawn while its filtering
	-- gets a proper look. Clearing it here also settles profiles that had it on.
	Profile.IgnoreClassRestrictions = false
end

---Updates Profile after changes
function addon:RefreshCharConfig()
	--addon.Profile = self.db.profile
	--Profile = addon.Profile
end

local f = CreateFrame("Frame", nil, UIParent)
f:SetHeight(1)
f:SetWidth(1)
f:SetPoint("TOPLEFT", UIParent, "TOPRIGHT")
f.model = CreateFrame("DressUpModel", nil, UIParent)
--f.model:SetPoint("CENTER", UIParent, "CENTER")
f.model:SetPoint("TOPLEFT", UIParent, "TOPRIGHT")
f.model:SetHeight(1)
f.model:SetWidth(1)
f.model:SetModelScale(1)
f.model:Hide()
f.model:SetAutoDress(false)
f.model:SetUnit("PLAYER")
addon.frame = f

---Ace based addon initilization
function addon:OnInitialize()
	local DB_Defaults = DB_Defaults

	-- One-time migration from BetterWardrobe. The old addon, if installed, loads
	-- first via OptionalDeps, so its saved data is in memory here. Copy it into
	-- our globals only when ours are still empty, then we own the data going forward.
	local function migrate(newName, oldName)
		if _G[newName] == nil and type(_G[oldName]) == "table" then
			_G[newName] = CopyTable(_G[oldName])
		end
	end
	migrate("LuckysBetterWardrobe_Options", "BetterWardrobe_Options")
	migrate("LuckysBetterWardrobe_CharacterData", "BetterWardrobe_CharacterData")
	migrate("LuckysBetterWardrobe_SavedSetData", "BetterWardrobe_SavedSetData")
	migrate("LuckysBetterWardrobe_SubstituteItemData", "BetterWardrobe_SubstituteItemData")
	migrate("LuckysBetterWardrobe_ListData", "BetterWardrobe_ListData")

	LuckysBetterWardrobe_ListData = LuckysBetterWardrobe_ListData or {}
	local listDB = LuckysBetterWardrobe_ListData
	listDB.favoritesDB = listDB.favoritesDB or {}
	listDB.collectionListDB = listDB.collectionListDB or {}
	listDB.HiddenAppearanceDB = listDB.HiddenAppearanceDB or {}
	listDB.OutfitDB = listDB.OutfitDB or {}


--Create all the profiled DB
	self.db = LibStub("AceDB-3.0"):New("LuckysBetterWardrobe_Options", defaults, true)
	self.chardb = LibStub("AceDB-3.0"):New("LuckysBetterWardrobe_CharacterData", DB_Defaults.char_defaults)
	self.setdb = LibStub("AceDB-3.0"):New("LuckysBetterWardrobe_SavedSetData", DB_Defaults.savedsets_defaults)
	self.itemsubdb = LibStub("AceDB-3.0"):New("LuckysBetterWardrobe_SubstituteItemData", DB_Defaults.itemsub_defaults, true)
	self.OutfitDB = LibStub("AceDB-3.0"):New(listDB.OutfitDB, DB_Defaults.charSavedOutfits_defaults)

	self.favoritesDB =  LibStub("AceDB-3.0"):New(listDB.favoritesDB, DB_Defaults.list_defaults)
	self.collectionListDB =  LibStub("AceDB-3.0"):New(listDB.collectionListDB, DB_Defaults.collectionList_defaults)
	self.HiddenAppearanceDB =  LibStub("AceDB-3.0"):New(listDB.HiddenAppearanceDB, DB_Defaults.list_defaults)
	self.char_savedOutfits = LibStub("AceDB-3.0"):New("LuckysBetterWardrobe_SavedOutfitData", charSavedOutfits_defaults, true)

	self.collectionCache = LibStub("AceDB-3.0"):New("LuckysBetterWardrobe_CollectionCache", collection_cache_defaults, true)


	local profile = self.setdb:GetCurrentProfile()
	--self.setdb.global[profile] = self.setdb.char
	addon.SelecteSavedList = false

	self.db.RegisterCallback(addon, "OnProfileChanged", "RefreshConfig")
	self.db.RegisterCallback(addon, "OnProfileCopied", "RefreshConfig")
	self.collectionListDB.RegisterCallback(addon, "OnProfileChanged", "RefreshCollectionListData")
	self.itemsubdb.RegisterCallback(addon, "OnProfileReset", "RefreshSubItemData")	

	self.OutfitDB.char.lastTransmogOutfitIDSpec = {}

	if firstRun then
		listDB.lastUpdte = 1
	end
end

local function ShowConflictDialog()
	local frame = LuckyUI.CreatePanel("LuckysBetterWardrobe_ConflictDialog", UIParent, 380, 190)
	frame:SetPoint("CENTER", 0, 150)
	frame:SetFrameStrata("DIALOG")
	LuckyUI.CreateHeader(frame, "Addon Conflict")

	local label = frame:CreateFontString(nil, "OVERLAY")
	label:SetFont(LuckyUI.BODY_FONT, 14)
	label:SetPoint("TOPLEFT", 16, -45)
	label:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
	label:SetJustifyH("LEFT")
	label:SetWordWrap(true)
	label:SetText("Better Wardrobe is also enabled.")

	local subLabel = frame:CreateFontString(nil, "OVERLAY")
	subLabel:SetFont(LuckyUI.BODY_FONT, 11)
	subLabel:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
	subLabel:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
	subLabel:SetJustifyH("LEFT")
	subLabel:SetTextColor(LuckyUI.C.textMuted[1], LuckyUI.C.textMuted[2], LuckyUI.C.textMuted[3])
	subLabel:SetText("Running both causes errors. Which one would you like to disable?")

	local hintLabel = frame:CreateFontString(nil, "OVERLAY")
	hintLabel:SetFont(LuckyUI.BODY_FONT, 10)
	hintLabel:SetPoint("BOTTOM", frame, "BOTTOM", 0, 16)
	hintLabel:SetTextColor(0.5, 0.5, 0.5)
	hintLabel:SetText("(Disabling reloads your interface)")

	local btnOther = LuckyUI.CreateButton(frame, "Disable Better Wardrobe", 150, 26, "primary")
	btnOther:SetPoint("BOTTOM", frame, "BOTTOM", -64, 40)
	btnOther:SetScript("OnClick", function()
		C_AddOns.DisableAddOn("BetterWardrobe")
		C_UI.Reload()
	end)

	local btnSelf = LuckyUI.CreateButton(frame, "Disable Lucky's", 120, 26, "secondary")
	btnSelf:SetPoint("LEFT", btnOther, "RIGHT", 8, 0)
	btnSelf:SetScript("OnClick", function()
		C_AddOns.DisableAddOn(addonName)
		C_UI.Reload()
	end)

	frame:Show()
end

local function InitFeature(name, init)
	local ok, err = pcall(init)
	if ok then
		addon.DevLog(("%s loaded"):format(name))
	else
		geterrorhandler()(("Lucky's Better Wardrobe: %s failed to load. %s"):format(name, err))
	end
end

local initialize
function addon:OnEnable()
	_,playerClass, classID = UnitClass("player")
	addon:RefreshConfig()

	InitFeature("settings panel", function() addon:BuildSettingsPanel() end)
	InitFeature("minimap button", function() addon:CreateMinimapButton() end)
	addon.Init:InitDB()

	addon:RegisterEvent("TRANSMOG_COLLECTION_SOURCE_REMOVED", "EventHandler")
	addon:RegisterEvent("TRANSMOG_COLLECTION_SOURCE_ADDED", "EventHandler")
	addon:RegisterEvent("PLAYER_ENTERING_WORLD", "EventHandler")

	--Cache any default Blizz Saved Sets
	---addon.StoreBlizzardSets()
	initialize = true

	if not C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
  		C_AddOns.LoadAddOn("Blizzard_Collections")
	end

		if not C_AddOns.IsAddOnLoaded("Blizzard_Transmog") then
  		C_AddOns.LoadAddOn("Blizzard_Transmog")
	end

	C_Timer.After(1, function() addon.Init:LoadModules() end)

	-- Optional features last: a failure here must not cost the vendor and journal UI.
	InitFeature("tooltips", function() addon:InitTooltips() end)
	InitFeature("catalyst", function() addon:InitCatalyst() end)
	InitFeature("instance set completion", function() addon:InitSetCompletion() end)
	InitFeature("loot alerts", function() addon:InitLootAlerts() end)

	if C_AddOns.IsAddOnLoaded("BetterWardrobe") then
		ShowConflictDialog()
	end
	--addon.Init.LoadCollectionListModule()
	--BW_ColectionListFrameTemplate
end

--Hides default collection window when at transmog vendor
local function UpdateTransmogVendor()
	WardrobeCollectionFrame:Hide()


	BetterWardrobeCollectionFrame:Show()
	BetterWardrobeCollectionFrame:SetContainer(WardrobeFrame)

end

--Loads various modules and builds frames once the Blizzard_Collection addon is loaded
function addon.Init:LoadModules()
	--Check to make sure that the addon has completed loading
	if not initialize then
		addon.DevLog("LoadModules: addon not initialized yet, retrying in 0.5s")
		C_Timer.After(0.5, function() addon.Init:LoadModules() end)
		return false
	end

	addon.DevLog("LoadModules: building collection frames")

	--Check to make sure that the Blizzard Frames have completed loading
	if not TransmogFrame then
		--C_Timer.After(0.5, function() addon.Init:LoadModules() end)
		--return false
	end

	-----C_Timer.After(0, function() addon.Init:UpdateWardrobeEnhanced() end)

	local f = CreateFrame("Frame", "BetterWardrobeCollectionFrame", TransmogFrame.WardrobeCollection, "BetterWardrobeCollectionFrameTemplate" )
	-- ponytail: Tier Sets tab temporarily disabled; delete this line to re-enable
	BetterWardrobeCollectionFrameTab4:Hide()
	addon:setFrames()
	addon.Init:InitFilterButtons()
	--Hooks into the colection tabs and sets Better Wardobe when viewing the wardrobe collection
	addon:SecureHook(nil, "CollectionsJournal_UpdateSelectedTab", function(self)
		local selected = CollectionsJournal_GetTab(self)

		-- don't touch the wardrobe frame if it's used by the transmogrifier
		if (WardrobeCollectionFrame:GetParent() == self or not WardrobeCollectionFrame:GetParent():IsShown()) then
			if selected == 5 then
				--HideUIPanel(WardrobeFrame)
				WardrobeCollectionFrame:Hide()
				BetterWardrobeCollectionFrame:Show()

				--BetterWardrobeCollectionFrame:SetContainer(self)
				if addon.ExtendedTransmogSwap then
					addon.ExtendedTransmogSwap:Show()
				end
			else

				--WardrobeCollectionFrame:Hide()
				BetterWardrobeCollectionFrame:Hide()
				if addon.ExtendedTransmogSwap then
					addon.ExtendedTransmogSwap:Hide()
				end
			end
		end
	end)

	--addon.Init:LoadWardrobeModule()


	--[[
	WardrobeFrame:HookScript("OnShow",  function() UpdateTransmogVendor() end)

	addon:SecureHook(WardrobeTransmogFrame, "GetRandomAppearanceID", function(self) BW_TransmogFrameMixin.GetRandomAppearanceID(self) end)
	addon:SecureHook(WardrobeTransmogFrame, "SelectSlotButton", function(self, slotButton, fromOnClick) BW_TransmogFrameMixin.SelectSlotButton(self, slotButton, fromOnClick) end)
	addon:SecureHook(WardrobeTransmogFrame, "EvaluateSecondaryAppearanceCheckbox", function(self) BW_TransmogFrameMixin.EvaluateSecondaryAppearanceCheckbox(self) end)
	addon:SecureHook(WardrobeTransmogFrame, "GetSelectedTransmogLocation", function(self) BW_TransmogFrameMixin.GetSelectedTransmogLocation(self) end)
	----addon:SecureHook(WardrobeTransmogFrame, "Update", function(self) BW_TransmogFrameMixin.Update(self) end)
	addon:SecureHook(WardrobeTransmogFrame, "SetPendingTransmog", function(self,...) BW_TransmogFrameMixin.Update(self,...) end)
	addon:SecureHook(WardrobeTransmogFrame, "GetSlotButton", function(self,...) BW_TransmogFrameMixin.GetSlotButton(self,...) end)
	--addon:SecureHook(WardrobeTransmogFrame, "OnTransmogApplied", function(self,...) BW_TransmogFrameMixin.OnTransmogApplied(self,...) end)
	addon:SecureHook(DressUpFrame, "OnDressModel", function() 	BW_DressingRoomFrameOutfitDropdown:UpdateSaveButton(); end)
]]--

	C_Timer.After(0, function()
		local selected = CollectionsJournal_GetTab(CollectionsJournal)
		BetterWardrobeCollectionFrame:SetShown(selected == 5) 

		if C_AddOns.IsAddOnLoaded("ElvUI") then 
			addon.ApplyElvUISkin()
		end

	end)
end

 function addon:UpdateTabs()
	
	TransmogFrame.WardrobeCollection.TabHeaders:SetTabShown(TransmogFrame.WardrobeCollection.itemsTabID, true);
	TransmogFrame.WardrobeCollection.TabHeaders:SetTabShown(TransmogFrame.WardrobeCollection.setsTabID, false);
	TransmogFrame.WardrobeCollection.TabHeaders:SetTabShown(TransmogFrame.WardrobeCollection.custmSetsTabID, false);
	TransmogFrame.WardrobeCollection.TabHeaders:SetTabShown(TransmogFrame.WardrobeCollection.situationsTabID, false);

	--TransmogFrame.WardrobeCollection.TabHeaders:SetTabShown(TransmogFrame.WardrobeCollection.BW_SetsFrame2TabID, true);
	--TransmogFrame.WardrobeCollection.TabHeaders:SetTabShown(TransmogFrame.WardrobeCollection.extracustomsetsTabID, true);
end

function addon:EventHandler(event, ...)
	if event == "ADDON_LOADED" and ... == "Blizzard_Collections" then
		addon:SendMessage("BW_ADDON_LOADED")
		addon:UnregisterEvent("ADDON_LOADED")

	elseif event == "PLAYER_LOGIN" then

	elseif event == "PLAYER_ENTERING_WORLD" then
		addon:SendMessage("BW_OnPlayerEnterWorld")


		if not C_AddOns.IsAddOnLoaded("Blizzard_TransmogShared") then
  		C_AddOns.LoadAddOn("Blizzard_TransmogShared")

		end

		if not C_AddOns.IsAddOnLoaded("Blizzard_Transmog") then
  		C_AddOns.LoadAddOn("Blizzard_Transmog")

		end


		C_Timer.After(1, function() 
			if not TransmogFrame.WardrobeCollection.TabContent.BW_SetsFrame2 then
				local f = CreateFrame("Frame", nil, TransmogFrame.WardrobeCollection.TabContent,"ExtraSetsFrameTemplate")
				TransmogFrame.WardrobeCollection.TabContent.BW_SetsFrame2 = f
				TransmogFrame.WardrobeCollection.TabHeaders.setsFrame2TabID = TransmogFrame.WardrobeCollection:AddNamedTab(L["Sets"],  TransmogFrame.WardrobeCollection.TabContent.BW_SetsFrame2);
				TransmogFrame.WardrobeCollection.TabContent.BW_SetsFrame2:Init(TransmogFrame.WardrobeCollection)

				local f = CreateFrame("Frame", nil, TransmogFrame.WardrobeCollection.TabContent,"ExtraSetsFrameTemplate")
				TransmogFrame.WardrobeCollection.TabContent.BW_ExtraSetsFrame = f
				TransmogFrame.WardrobeCollection.TabHeaders.extrasetsTabID = TransmogFrame.WardrobeCollection:AddNamedTab(L["Extra Sets"],  TransmogFrame.WardrobeCollection.TabContent.BW_ExtraSetsFrame);
				TransmogFrame.WardrobeCollection.TabContent.BW_ExtraSetsFrame:Init(TransmogFrame.WardrobeCollection)

				-- Tabs sit in registration order, so Blizzard's Custom Sets and Situations
				-- tabs are re-registered here, pointed at their own frames, to land after
				-- Extra Sets. The originals are hidden in UpdateTabs.
				TransmogFrame.WardrobeCollection.TabHeaders.custmSetsTabID2 = TransmogFrame.WardrobeCollection:AddNamedTab(TRANSMOG_TAB_CUSTOM_SETS, TransmogFrame.WardrobeCollection.TabContent.CustomSetsFrame);
				TransmogFrame.WardrobeCollection.TabHeaders.situationsTabID2 = TransmogFrame.WardrobeCollection:AddNamedTab(TRANSMOG_TAB_SITUATIONS, TransmogFrame.WardrobeCollection.TabContent.SituationsFrame);
				InitFeature("situation presets", function() addon:InitSituationPresets() end)

				local f = CreateFrame("Frame", nil, TransmogFrame.WardrobeCollection.TabContent.ItemsFrame.PagedContent,"BW_PagingControlsHorizontalTemplate")
				f:ClearAllPoints()
				f:SetPoint("TOPLEFT", TransmogFrame.WardrobeCollection.TabContent.ItemsFrame.PagedContent, "BOTTOM", -120, 40)
				TransmogFrame.WardrobeCollection.TabContent.ItemsFrame.PagedContent.PagingControls:Hide()
				TransmogFrame.WardrobeCollection.TabContent.ItemsFrame.PagedContent.PagingControls = f

				 self:SecureHookScript(TransmogFrame, "OnShow", function() C_Timer.After(.1, function() addon:UpdateTabs(); end) end)

				addon:CreateButtons()
			end
			addon:UpdateTabs();
		 end)

		----C_Timer.After(1, function() addon:ResetSetsCollectionFrame() end)
		--C_Timer.After(15, function() addon.Init:UpdateCollectedAppearances() end)

	elseif (event == "TRANSMOG_COLLECTION_SOURCE_ADDED") then
		local x = ...
		BetterWardrobeCollectionFrameMixin:OnEvent(event, x)

	elseif (event == "TRANSMOG_COLLECTION_SOURCE_REMOVED") then
		local x = ...
		BetterWardrobeCollectionFrameMixin:OnEvent(event, x)
	end
end

local f = CreateFrame("Frame", nil, UIParent)
f:ClearAllPoints()
f:SetPoint("TOPRIGHT", 100, 100)
f:SetSize(1, 1)
f:Hide()
addon.prisonFrame = f

function LuckysBetterWardrobe_OnAddonCompartmentClick(addonName, buttonName, menuButtonFrame)
      ToggleCollectionsJournal(5)
 end
