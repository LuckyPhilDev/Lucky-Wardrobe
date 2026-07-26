local addonName, addon = ...
addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local IgnoredSlots = {}
local AppearanceList

BW_RandomizeButtonMixin = {}

function BW_RandomizeButtonMixin:OnEnter()
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("BOTTOM", self, "TOP", 0, 0)
	GameTooltip:SetOwner(self, "ANCHOR_PRESERVE")
	GameTooltip:SetText(L["Click: Randomize Items"])
end


function BW_RandomizeButtonMixin:OnMouseDown()
	self:BuildAppearanceList()
	self:Randomize()
end


local finalselection = {}

local function SetPending(slotID, sourceID)
	local transmogLocation = TransmogUtil.GetTransmogLocation(slotID, Enum.TransmogType.Appearance, false)
	if not transmogLocation then return end

	local displayType = C_TransmogCollection.IsAppearanceHiddenVisual(sourceID) and Enum.TransmogOutfitDisplayType.Hidden or Enum.TransmogOutfitDisplayType.Assigned
	C_TransmogOutfitInfo.SetPendingTransmog(transmogLocation:GetSlot(), transmogLocation:GetType(), Enum.TransmogOutfitSlotOption.None, sourceID, displayType)
end


--Updates the model after all items has been selected so model and pending looks match
local function finalUpdate()
	for slotID, mog in pairs(finalselection)do
		SetPending(slotID, mog)
		finalselection[slotID] = nil
	end
end


function BW_RandomizeButtonMixin:OnMouseUp()
	self.Stop = true
	
	C_Timer.After(1.8, function() finalUpdate() end)
end


local function AddSlotAppearances(slotID, categoryID, transmogLocation)

	if not transmogLocation then return end
	for _, appearance in ipairs(C_TransmogCollection.GetCategoryAppearances(categoryID, transmogLocation)) do
		if appearance.isUsable and appearance.isCollected then
			tinsert(AppearanceList[slotID].visuals, appearance.visualID)
		end
	end
end


local update = false
function BW_RandomizeButtonMixin:BuildAppearanceList()
	if not update and AppearanceList then return end

	AppearanceList = (AppearanceList and wipe(AppearanceList)) or {}
	for _, slotInfo in pairs(TRANSMOG_SLOTS) do
		local transmogLocation = slotInfo.location
		local slot = transmogLocation:GetSlot()

		-- Weapon slots carry a weapon option the randomizer has no way to pick sensibly, so they
		-- are skipped the same way Blizzard's own set matching skips them.
		local isRandomizable = slot and slotInfo.armorCategoryID and transmogLocation:IsAppearance()
			and not transmogLocation:IsSecondary() and not C_TransmogOutfitInfo.IsSlotWeaponSlot(slot)

		if isRandomizable then
			local slotID = transmogLocation:GetSlotID()
			--The category and location are needed again to look a visual's sources up, so keep
			--them with the visuals rather than deriving them back out of an item link.
			AppearanceList[slotID] = { categoryID = slotInfo.armorCategoryID, location = transmogLocation, visuals = {} }

			local slotState = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(slot, transmogLocation:GetType(), Enum.TransmogOutfitSlotOption.None)
			if slotState and slotState.canTransmogrify then
				AddSlotAppearances(slotID, slotInfo.armorCategoryID, transmogLocation)
			end
		end
	end
end


local function RandomizeBySlot(slotID)
	local slotList = AppearanceList[slotID]
	if not slotList or #slotList.visuals == 0 then return end

	local visualID = slotList.visuals[random(#slotList.visuals)]
	local sourceList = C_TransmogCollection.GetAppearanceSources(visualID, slotList.categoryID, slotList.location)
	if not sourceList then return end

	for _, source in pairs(sourceList) do
		if source.isCollected then
			SetPending(slotID, source.sourceID)
			finalselection[slotID] = source.sourceID
			break
		end
	end
end


local function RandomizeAllSlots()
	for slotID, _ in pairs(AppearanceList) do
		if not IgnoredSlots[slotID] then
			RandomizeBySlot(slotID)
		end
	end
end


local throttleValue = 0.1
local currentThrottle = throttleValue
local totalTime = 0
local function RandomizeOnUpdate(self, elapsed)
	totalTime = totalTime + elapsed
	if totalTime >= throttleValue then
		self.RunRandom(self.Slot)
		if self.Stop then
			currentThrottle = currentThrottle * 1.5
			if currentThrottle >= 0.5 then
				self:SetScript('OnUpdate', nil)
			end
		end
		
		totalTime = 0
	end
end

function BW_RandomizeButtonMixin:Randomize()
	totalTime = 0
	currentThrottle = throttleValue
	self.Stop = false
	self:SetScript('OnUpdate', RandomizeOnUpdate)

	RandomizeAllSlots()
	self.RunRandom = RandomizeAllSlots
end