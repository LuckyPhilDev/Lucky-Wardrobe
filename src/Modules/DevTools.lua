-- Lucky's Better Wardrobe: developer probes for Blizzard's transmog Situations API.
-- Not user facing. These commands exist to establish what C_TransmogOutfitInfo will
-- let an addon read, stage and commit before any Situations feature is designed.
local addonName, addon = ...
addon = LibStub("AceAddon-3.0"):GetAddon(addonName)

local DevTools = {}
addon.DevTools = DevTools

local snapshot
local blockedEvents = {}
local watching = false

local function Print(fmt, ...)
	local text = select("#", ...) > 0 and fmt:format(...) or fmt
	print(addon.PREFIX .. " " .. text)
end

local IsSecret = issecretvalue or function() return false end

-- A secret value cannot be inspected, stored in saved variables, or passed back into
-- the API from tainted code, so it is the difference between a copyable option and an
-- opaque handle. Everything here reports secrecy rather than tripping over it.
local function DescribeValue(value)
	if IsSecret(value) then
		return "|cffff5555<secret>|r"
	end

	local valueType = type(value)
	if valueType ~= "table" then
		return ("%s(%s)"):format(valueType, tostring(value))
	end

	local parts = {}
	for key, inner in pairs(value) do
		parts[#parts + 1] = ("%s=%s"):format(tostring(key),
			IsSecret(inner) and "|cffff5555<secret>|r" or tostring(inner))
	end
	table.sort(parts)
	return "{" .. table.concat(parts, ", ") .. "}"
end

-- Returns whether the option, or any field inside it, is a secret value.
local function OptionIsSecret(option)
	if IsSecret(option) then
		return true
	end
	if type(option) ~= "table" then
		return false
	end
	for key, value in pairs(option) do
		if IsSecret(key) or IsSecret(value) then
			return true
		end
	end
	return false
end

local function GetSchema()
	local ok, schema = pcall(C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions)
	if not ok then
		return nil, tostring(schema)
	end
	if type(schema) ~= "table" then
		return nil, "returned " .. type(schema)
	end
	return schema
end

-- Options are nested in groups purely for menu dividers. Flattening gives each option
-- a stable index within its category so the slash commands can address one.
local function FlattenCategory(category)
	local options = {}
	for _, group in ipairs(category.groupData or {}) do
		for _, option in ipairs(group.optionData or {}) do
			options[#options + 1] = option
		end
	end
	return options
end

local function ReadSelections(schema)
	local selections = {}
	for categoryIndex, category in ipairs(schema) do
		local names = {}
		for optionIndex, option in ipairs(FlattenCategory(category)) do
			if C_TransmogOutfitInfo.GetOutfitSituation(option.option) then
				names[#names + 1] = option.name
				selections[("%d.%d"):format(categoryIndex, optionIndex)] = true
			end
		end
		selections[categoryIndex] = names
	end
	return selections
end

local function PrintContext()
	local frameShown = TransmogFrame and TransmogFrame:IsShown()
	Print("Context: transmog frame %s, viewed outfit %s, active outfit %s, situations %s",
		frameShown and "open" or "closed",
		tostring(C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()),
		tostring(C_TransmogOutfitInfo.GetActiveOutfitID()),
		C_TransmogOutfitInfo.GetOutfitSituationsEnabled() and "enabled" or "disabled")

	local pendingSituations = C_TransmogOutfitInfo.HasPendingOutfitSituations()
	local pendingTransmogs = C_TransmogOutfitInfo.HasPendingOutfitTransmogs()
	if pendingSituations or pendingTransmogs then
		Print("Pending: situations=%s transmogs=%s", tostring(pendingSituations), tostring(pendingTransmogs))
	end
end

---------------------------------------------------------------------------
-- Blocked action tracking
---------------------------------------------------------------------------

local blockedFrame = CreateFrame("Frame")
blockedFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
blockedFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
blockedFrame:SetScript("OnEvent", function(_, event, blamedAddon, func)
	local entry = {
		time = GetTime(),
		text = ("%s: %s -> %s"):format(event, tostring(blamedAddon), tostring(func)),
	}
	blockedEvents[#blockedEvents + 1] = entry
	if #blockedEvents > 20 then
		table.remove(blockedEvents, 1)
	end
	if watching then
		Print("|cffff5555%s|r", entry.text)
	end
end)

local function BlockedSince(timestamp)
	local hits = {}
	for _, entry in ipairs(blockedEvents) do
		if entry.time >= timestamp then
			hits[#hits + 1] = entry.text
		end
	end
	return hits
end

---------------------------------------------------------------------------
-- Event watching
---------------------------------------------------------------------------

local WATCH_EVENTS = {
	"VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED",
	"VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH",
	"TRANSMOG_OUTFITS_CHANGED",
	"TRANSMOG_DISPLAYED_OUTFIT_CHANGED",
}

local watchFrame = CreateFrame("Frame")
watchFrame:SetScript("OnEvent", function(_, event, ...)
	local args = {}
	for i = 1, select("#", ...) do
		args[i] = DescribeValue((select(i, ...)))
	end
	Print("|cff88ccff%s|r %s", event, table.concat(args, " "))
end)

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------

local commands = {}

commands.api = function()
	local names = {
		"GetUISituationCategoriesAndOptions", "GetOutfitSituation", "UpdatePendingSituation",
		"HasPendingOutfitSituations", "CommitPendingSituations", "ClearAllPendingSituations",
		"ResetOutfitSituations", "GetOutfitSituationsEnabled", "SetOutfitSituationsEnabled",
		"GetOutfitsInfo", "GetCurrentlyViewedOutfitID", "ChangeViewedOutfit",
		"GetActiveOutfitID", "ChangeDisplayedOutfit", "IsLockedOutfit",
		"GetOutfitInfo", "GetOutfitInfoByName", "GetOutfitInfoByPlayerFacingIndex",
	}

	Print("C_TransmogOutfitInfo situation surface:")
	for _, name in ipairs(names) do
		local func = C_TransmogOutfitInfo[name]
		local isSecure, taint = issecurevariable(C_TransmogOutfitInfo, name)
		Print("  %s: %s%s", name,
			func and "present" or "|cffff5555MISSING|r",
			isSecure and "" or (" |cffffcc00tainted by %s|r"):format(tostring(taint)))
	end

	Print("Trigger enum: %s", DescribeValue(Enum.TransmogSituationTrigger))
	Print("issecretvalue available: %s", tostring(issecretvalue ~= nil))
end

commands.schema = function()
	local schema, err = GetSchema()
	if not schema then
		Print("|cffff5555GetUISituationCategoriesAndOptions failed: %s|r", err)
		return
	end

	PrintContext()
	Print("%d situation categories:", #schema)
	for categoryIndex, category in ipairs(schema) do
		Print("|cffffd100[%d] %s|r trigger=%s radio=%s", categoryIndex, tostring(category.name),
			tostring(category.triggerID), tostring(category.isRadioButton))
		if category.description then
			Print("     %s", category.description)
		end
		for optionIndex, option in ipairs(FlattenCategory(category)) do
			Print("     %d.%d %s  option=%s", categoryIndex, optionIndex,
				tostring(option.name), DescribeValue(option.option))
		end
	end
end

commands.read = function()
	local schema, err = GetSchema()
	if not schema then
		Print("|cffff5555No schema: %s|r", err)
		return
	end

	PrintContext()
	local selections = ReadSelections(schema)
	for categoryIndex, category in ipairs(schema) do
		local names = selections[categoryIndex]
		Print("[%d] %s: %s", categoryIndex, tostring(category.name),
			#names > 0 and table.concat(names, ", ") or "|cff888888(none)|r")
	end
end

commands.outfits = function()
	local outfits = C_TransmogOutfitInfo.GetOutfitsInfo()
	if not outfits then
		Print("|cffff5555GetOutfitsInfo returned nil|r")
		return
	end

	PrintContext()
	Print("%d outfits:", #outfits)
	for _, info in ipairs(outfits) do
		local categories = info.situationCategories
		local summary = "|cff888888(no situations)|r"
		if type(categories) == "table" and #categories > 0 then
			summary = table.concat(categories, " / ")
		end
		Print("  [%s] %s  locked=%s  %s", tostring(info.outfitID), tostring(info.name),
			tostring(C_TransmogOutfitInfo.IsLockedOutfit(info.outfitID)), summary)
	end
end

-- Walks every outfit through ChangeViewedOutfit to see whether per-outfit selections
-- can be read without the player clicking each one. Restores the original outfit.
commands.readall = function()
	local schema, err = GetSchema()
	if not schema then
		Print("|cffff5555No schema: %s|r", err)
		return
	end

	if C_TransmogOutfitInfo.HasPendingOutfitSituations() or C_TransmogOutfitInfo.HasPendingOutfitTransmogs() then
		Print("|cffff5555Pending changes exist. Run /bwdev clear first.|r")
		return
	end

	local outfits = C_TransmogOutfitInfo.GetOutfitsInfo()
	if not outfits or #outfits == 0 then
		Print("|cffff5555No outfits.|r")
		return
	end

	local original = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
	Print("Reading %d outfits (viewed outfit will move, restoring to %s at the end).",
		#outfits, tostring(original))

	local index = 0
	local function Step()
		index = index + 1
		local info = outfits[index]
		if not info then
			C_TransmogOutfitInfo.ChangeViewedOutfit(original)
			Print("Done. Restored viewed outfit %s.", tostring(original))
			return
		end

		local ok, changeErr = pcall(C_TransmogOutfitInfo.ChangeViewedOutfit, info.outfitID)
		if not ok then
			Print("|cffff5555ChangeViewedOutfit(%s) errored: %s|r", tostring(info.outfitID), tostring(changeErr))
			C_TransmogOutfitInfo.ChangeViewedOutfit(original)
			return
		end

		C_Timer.After(0.25, function()
			local viewed = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
			local selections = ReadSelections(schema)
			local parts = {}
			for categoryIndex, category in ipairs(schema) do
				local names = selections[categoryIndex]
				if #names > 0 then
					parts[#parts + 1] = ("%s=%s"):format(category.name, table.concat(names, "+"))
				end
			end
			Print("  [%s] %s viewed=%s %s", tostring(info.outfitID), tostring(info.name), tostring(viewed),
				#parts > 0 and table.concat(parts, "  ") or "|cff888888(none)|r")
			Step()
		end)
	end

	Step()
end

commands.set = function(categoryArg, optionArg, valueArg)
	local categoryIndex = tonumber(categoryArg)
	local optionIndex = tonumber(optionArg)
	if not categoryIndex or not optionIndex then
		Print("Usage: /bwdev set <category> <option> [on|off]  (indices from /bwdev schema)")
		return
	end

	local schema, err = GetSchema()
	if not schema then
		Print("|cffff5555No schema: %s|r", err)
		return
	end

	local category = schema[categoryIndex]
	local option = category and FlattenCategory(category)[optionIndex]
	if not option then
		Print("|cffff5555No such option %d.%d|r", categoryIndex, optionIndex)
		return
	end

	local current = C_TransmogOutfitInfo.GetOutfitSituation(option.option)
	local target
	if valueArg == "on" then
		target = true
	elseif valueArg == "off" then
		target = false
	else
		target = not current
	end

	local started = GetTime()
	local ok, updateErr = pcall(C_TransmogOutfitInfo.UpdatePendingSituation, option.option, target)
	Print("UpdatePendingSituation(%s, %s): %s", tostring(option.name), tostring(target),
		ok and "no error" or ("|cffff5555" .. tostring(updateErr) .. "|r"))
	Print("  was %s, now reads %s, pending=%s", tostring(current),
		tostring(C_TransmogOutfitInfo.GetOutfitSituation(option.option)),
		tostring(C_TransmogOutfitInfo.HasPendingOutfitSituations()))

	for _, text in ipairs(BlockedSince(started)) do
		Print("|cffff5555  %s|r", text)
	end
end

commands.commit = function()
	local started = GetTime()
	local ok, err = pcall(C_TransmogOutfitInfo.CommitPendingSituations)
	Print("CommitPendingSituations: %s", ok and "no error" or ("|cffff5555" .. tostring(err) .. "|r"))
	Print("  pending now %s", tostring(C_TransmogOutfitInfo.HasPendingOutfitSituations()))
	for _, text in ipairs(BlockedSince(started)) do
		Print("|cffff5555  %s|r", text)
	end
end

commands.clear = function()
	C_TransmogOutfitInfo.ClearAllPendingSituations()
	Print("Cleared pending situations. pending=%s", tostring(C_TransmogOutfitInfo.HasPendingOutfitSituations()))
end

commands.reset = function(confirmArg)
	if confirmArg ~= "confirm" then
		Print("ResetOutfitSituations wipes the viewed outfit's situation settings. Run: /bwdev reset confirm")
		return
	end
	local ok, err = pcall(C_TransmogOutfitInfo.ResetOutfitSituations)
	Print("ResetOutfitSituations: %s", ok and "no error" or ("|cffff5555" .. tostring(err) .. "|r"))
end

commands.enabled = function(valueArg)
	if valueArg == "on" or valueArg == "off" then
		local started = GetTime()
		local ok, err = pcall(C_TransmogOutfitInfo.SetOutfitSituationsEnabled, valueArg == "on")
		Print("SetOutfitSituationsEnabled(%s): %s", valueArg,
			ok and "no error" or ("|cffff5555" .. tostring(err) .. "|r"))
		for _, text in ipairs(BlockedSince(started)) do
			Print("|cffff5555  %s|r", text)
		end
	end
	Print("GetOutfitSituationsEnabled = %s", tostring(C_TransmogOutfitInfo.GetOutfitSituationsEnabled()))
end

commands.copy = function()
	local schema, err = GetSchema()
	if not schema then
		Print("|cffff5555No schema: %s|r", err)
		return
	end

	local selections = ReadSelections(schema)
	snapshot = {
		outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID(),
		keys = {},
		labels = {},
	}

	for categoryIndex, category in ipairs(schema) do
		for optionIndex in ipairs(FlattenCategory(category)) do
			local key = ("%d.%d"):format(categoryIndex, optionIndex)
			snapshot.keys[key] = selections[key] and true or false
		end
		local names = selections[categoryIndex]
		if #names > 0 then
			snapshot.labels[#snapshot.labels + 1] = ("%s=%s"):format(category.name, table.concat(names, "+"))
		end
	end

	Print("Copied situations from outfit %s: %s", tostring(snapshot.outfitID),
		#snapshot.labels > 0 and table.concat(snapshot.labels, "  ") or "|cff888888(none)|r")
end

commands.paste = function(commitArg)
	if not snapshot then
		Print("|cffff5555Nothing copied. Run /bwdev copy first.|r")
		return
	end

	local schema, err = GetSchema()
	if not schema then
		Print("|cffff5555No schema: %s|r", err)
		return
	end

	local viewed = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
	local started = GetTime()
	local clears, sets = {}, {}

	for categoryIndex, category in ipairs(schema) do
		for optionIndex, option in ipairs(FlattenCategory(category)) do
			local key = ("%d.%d"):format(categoryIndex, optionIndex)
			local desired = snapshot.keys[key] and true or false
			if C_TransmogOutfitInfo.GetOutfitSituation(option.option) ~= desired then
				local target = desired and sets or clears
				target[#target + 1] = option.option
			end
		end
	end

	-- Deselect first so radio categories do not fight over a single selection.
	local changes = 0
	for _, list in ipairs({ clears, sets }) do
		for _, option in ipairs(list) do
			local ok, updateErr = pcall(C_TransmogOutfitInfo.UpdatePendingSituation, option, list == sets)
			if ok then
				changes = changes + 1
			else
				Print("|cffff5555UpdatePendingSituation failed: %s|r", tostring(updateErr))
			end
		end
	end

	Print("Pasted %d changes onto outfit %s (from %s). pending=%s", changes, tostring(viewed),
		tostring(snapshot.outfitID), tostring(C_TransmogOutfitInfo.HasPendingOutfitSituations()))

	if commitArg == "commit" then
		commands.commit()
	else
		Print("Not committed. Run /bwdev commit, or /bwdev clear to discard.")
	end

	for _, text in ipairs(BlockedSince(started)) do
		Print("|cffff5555  %s|r", text)
	end
end

commands.watch = function(valueArg)
	watching = valueArg ~= "off"
	if watching then
		FrameUtil.RegisterFrameForEvents(watchFrame, WATCH_EVENTS)
		Print("Watching situation events and blocked actions. /bwdev watch off to stop.")
	else
		FrameUtil.UnregisterFrameForEvents(watchFrame, WATCH_EVENTS)
		Print("Stopped watching.")
	end
end

commands.blocked = function()
	if #blockedEvents == 0 then
		Print("No blocked or forbidden actions recorded this session.")
		return
	end
	Print("Recent blocked actions:")
	for _, entry in ipairs(blockedEvents) do
		Print("  [%.1f] %s", entry.time, entry.text)
	end
end

-- End to end viability check: schema, per-outfit read, staged write from a deferred
-- (non hardware event) call path, and cross-outfit read. Leaves no pending changes.
commands.probe = function()
	local started = GetTime()
	local results = {}
	local function Record(label, ok, detail)
		results[#results + 1] = ("%s %s%s"):format(ok and "|cff55ff55PASS|r" or "|cffff5555FAIL|r",
			label, detail and (" - " .. detail) or "")
	end

	PrintContext()

	local schema, err = GetSchema()
	if not schema then
		Record("read schema", false, err)
		Print(results[1])
		return
	end

	local optionCount = 0
	for _, category in ipairs(schema) do
		optionCount = optionCount + #FlattenCategory(category)
	end
	Record("read schema", true, ("%d categories, %d options"):format(#schema, optionCount))

	local outfits = C_TransmogOutfitInfo.GetOutfitsInfo() or {}
	Record("list outfits", #outfits > 0, ("%d outfits"):format(#outfits))

	local hasSummaryText = false
	for _, info in ipairs(outfits) do
		if type(info.situationCategories) == "table" and #info.situationCategories > 0 then
			hasSummaryText = true
			break
		end
	end
	Record("outfit list carries situation summary text", hasSummaryText,
		hasSummaryText and "readable without switching outfits" or "no outfit has situations set")

	local selections = ReadSelections(schema)
	local selectedCount = 0
	for key in pairs(selections) do
		if type(key) == "string" then
			selectedCount = selectedCount + 1
		end
	end
	Record("read viewed outfit selections", true, ("%d selected options"):format(selectedCount))

	-- Decides whether a copy/paste feature can serialise selections, or has to
	-- re-resolve options from the live schema every time.
	local secretOptions = 0
	for _, category in ipairs(schema) do
		for _, option in ipairs(FlattenCategory(category)) do
			if OptionIsSecret(option.option) then
				secretOptions = secretOptions + 1
			end
		end
	end
	Record("option structs are plain values", secretOptions == 0,
		secretOptions == 0 and "serialisable to saved variables"
			or ("%d of %d options are secret"):format(secretOptions, optionCount))

	local function Finish()
		Print("--- Situations viability probe ---")
		for _, line in ipairs(results) do
			Print(line)
		end
		local blocked = BlockedSince(started)
		if #blocked > 0 then
			Print("|cffff5555Blocked actions during probe:|r")
			for _, text in ipairs(blocked) do
				Print("  " .. text)
			end
		else
			Print("No blocked or forbidden actions during probe.")
		end
	end

	local function ProbeCrossOutfitRead()
		local original = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
		local target
		for _, info in ipairs(outfits) do
			if info.outfitID ~= original then
				target = info.outfitID
				break
			end
		end

		if not target then
			Record("switch viewed outfit from addon code", false, "only one outfit to test with")
			Finish()
			return
		end

		C_Timer.After(0, function()
			local ok, changeErr = pcall(C_TransmogOutfitInfo.ChangeViewedOutfit, target)
			if not ok then
				Record("switch viewed outfit from addon code", false, tostring(changeErr))
				Finish()
				return
			end

			C_Timer.After(0.3, function()
				local viewed = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
				Record("switch viewed outfit from addon code", viewed == target,
					("asked for %s, got %s"):format(tostring(target), tostring(viewed)))

				local otherSelections = ReadSelections(schema)
				local otherCount = 0
				for key in pairs(otherSelections) do
					if type(key) == "string" then
						otherCount = otherCount + 1
					end
				end
				Record("read a different outfit's selections", viewed == target,
					("%d selected options on outfit %s"):format(otherCount, tostring(viewed)))

				C_TransmogOutfitInfo.ChangeViewedOutfit(original)
				C_Timer.After(0.3, Finish)
			end)
		end)
	end

	if C_TransmogOutfitInfo.HasPendingOutfitSituations() or C_TransmogOutfitInfo.HasPendingOutfitTransmogs() then
		Record("stage a pending change", false, "skipped, pending changes already exist")
		ProbeCrossOutfitRead()
		return
	end

	local testOption
	for _, category in ipairs(schema) do
		local options = FlattenCategory(category)
		if options[1] then
			testOption = options[1]
			break
		end
	end

	if not testOption then
		Record("stage a pending change", false, "no options in schema")
		ProbeCrossOutfitRead()
		return
	end

	-- Deferred so the call carries no hardware event, which is where a protected
	-- API would refuse an addon.
	C_Timer.After(0, function()
		local current = C_TransmogOutfitInfo.GetOutfitSituation(testOption.option)
		local ok, updateErr = pcall(C_TransmogOutfitInfo.UpdatePendingSituation, testOption.option, not current)
		local pending = C_TransmogOutfitInfo.HasPendingOutfitSituations()
		Record("stage a pending change with no hardware event", ok and pending,
			ok and (("%s -> %s, pending=%s"):format(tostring(testOption.name), tostring(not current), tostring(pending)))
				or tostring(updateErr))

		C_TransmogOutfitInfo.ClearAllPendingSituations()
		Record("discard pending change", not C_TransmogOutfitInfo.HasPendingOutfitSituations())
		ProbeCrossOutfitRead()
	end)
end

local function SourceCategoryNames()
	local names = {}
	for key, id in pairs(addon.Filter) do
		names[id] = key
	end
	return names
end

local LIST_LIMIT = 40

-- Lists every visible set in one category with the raw fields the classifier had
-- to work with, which is the only way to see why a set landed where it did.
local function ListCategory(categoryName)
	local names = SourceCategoryNames()
	local categoryID
	for id, key in pairs(names) do
		if key:lower() == categoryName then categoryID = id end
	end

	if not categoryID then
		local keys = {}
		for _, key in pairs(names) do keys[#keys + 1] = key:lower() end
		table.sort(keys)
		Print("|cffff5555Unknown category '%s'.|r Try: %s", categoryName, table.concat(keys, ", "))
		return
	end

	local matches = {}
	for _, data in ipairs(addon.SetsDataProvider:GetBaseSets() or {}) do
		if (data.filter or addon.Filter.MISC) == categoryID then
			matches[#matches + 1] = data
		end
	end

	-- Blizzard's own count, deliberately: this file does not shadow C_TransmogSets,
	-- and only the unshadowed API is usable at classify time, when the addon's own
	-- variant grouping has not been built yet.
	local function VariantCount(setID)
		local baseSetID = C_TransmogSets.GetBaseSetID(setID) or setID
		local variants = C_TransmogSets.GetVariantSets(baseSetID)
		return variants and #variants or 0
	end

	Print("%s (id %d): %d visible sets", names[categoryID], categoryID, #matches)
	for index, data in ipairs(matches) do
		if index > LIST_LIMIT then
			Print("  ... %d more, narrow the list with the other filters", #matches - LIST_LIMIT)
			break
		end

		Print("  %d %s | label=%s | desc=%s | variants=%d | xpac=%s patch=%s limited=%s class=%s",
			data.setID, tostring(data.name), tostring(data.label), tostring(data.description),
			VariantCount(data.setID),
			tostring(data.expansionID), tostring(data.patchID), tostring(data.limitedTimeSet),
			tostring(data.classMask))
	end

	-- Raid tier comes in difficulties, so the spread here is what says whether a
	-- variant count could replace naming exceptions one by one.
	local variantCounts = {}
	for _, data in ipairs(matches) do
		local count = VariantCount(data.setID)
		variantCounts[count] = (variantCounts[count] or 0) + 1
	end

	local counts = {}
	for count in pairs(variantCounts) do counts[#counts + 1] = count end
	table.sort(counts)

	Print("Variant counts in %s:", names[categoryID])
	for _, count in ipairs(counts) do
		Print("  %d variants: %d sets", count, variantCounts[count])
	end

	-- The classifier leans on description, so its spread across a category is the
	-- signal for whether that category can be split up any further.
	local descriptions = {}
	for _, data in ipairs(matches) do
		local key = tostring(data.description)
		descriptions[key] = (descriptions[key] or 0) + 1
	end

	local distinct = {}
	for description in pairs(descriptions) do distinct[#distinct + 1] = description end
	table.sort(distinct)

	Print("Distinct descriptions in %s: %d", names[categoryID], #distinct)
	for _, description in ipairs(distinct) do
		Print("  %s x%d", description, descriptions[description])
	end
end

-- Reports why sets are on screen: which source checkboxes the current tab has,
-- what each is set to, and which category every visible set falls into.
commands.sources = function(categoryName)
	local tab = BetterWardrobeCollectionFrame and BetterWardrobeCollectionFrame.selectedCollectionTab
	if not tab then
		Print("|cffff5555Open the Collections Journal first.|r")
		return
	end

	if categoryName then
		ListCategory(categoryName)
		return
	end

	local filterSelection = addon.Filters.Base.filterSelection
	local tabSources = addon.Globals.GetSourceFiltersForTab(tab)
	local names = SourceCategoryNames()

	Print("Source checkboxes on tab %d:", tab)
	local hasCheckbox = {}
	for _, source in ipairs(tabSources) do
		hasCheckbox[source.id] = true
		Print("  [%s] %s (%s, id %d)", filterSelection[source.id] ~= false and "x" or " ",
			source.label, names[source.id] or "?", source.id)
	end

	if not tabSources[1] then
		Print("  none")
	end

	local sets = addon.SetsDataProvider:GetBaseSets() or {}
	local counts, unfilterable = {}, false
	for _, data in ipairs(sets) do
		local id = data.filter or addon.Filter.MISC
		counts[id] = (counts[id] or 0) + 1
		if not hasCheckbox[id] then unfilterable = true end
	end

	local ids = {}
	for id in pairs(counts) do ids[#ids + 1] = id end
	table.sort(ids)

	Print("Visible sets: %d", #sets)
	for _, id in ipairs(ids) do
		Print("  %s (id %d): %d%s", names[id] or "?", id, counts[id],
			hasCheckbox[id] and "" or " |cffff5555no checkbox on this tab, cannot be filtered out|r")
	end

	if unfilterable then
		Print("|cffff5555Categories flagged above survive Uncheck All.|r")
	end
end

--- Reports what the instance scan sees: the names it matches drop data against,
--- and every set it found, so a miss can be told from a name that didn't match.
commands.instance = function()
	local instance = addon.SetCompletion:GetCurrentInstance()
	if not instance then
		Print("|cffff5555Not in a dungeon or raid.|r")
		return
	end

	Print("Instance: %s", instance.name)
	Print("  journal name: %s", instance.journalName or "|cffff5555none, only the map name can match|r")
	Print("  difficulty:   %s", instance.difficulty or "unknown")
	Print("  max missing:  %d", addon.Profile.InstanceSetsMaxMissing)

	local started = debugprofilestop()
	local matches, stats = addon.SetCompletion:Scan(instance)
	Print("Sets found: %d in %.0f ms", #matches, debugprofilestop() - started)

	-- Where the sets went. A scan that finds nothing is either filtering them out
	-- or looking up pieces that carry no drop data, and these separate the two.
	Print("  sets scanned:       %d", stats.sets)
	Print("  skipped, category:  %d", stats.skippedCategory)
	Print("  skipped, this tier: %d%s", stats.skippedCurrentTier,
		addon.Profile.IncludeCurrentTier and " (the current tier is set to show)" or "")
	Print("  skipped, over limit:%d", stats.overLimit)
	Print("  candidates:         %d", stats.candidates)
	Print("  pieces looked up:   %d", stats.lookups)
	Print("  pieces with drops:  %d%s", stats.sourcesWithDrops,
		stats.lookups > 0 and stats.sourcesWithDrops == 0
			and " |cffff5555no piece has any drop data at all|r" or "")
	Print("  pieces matched by the set's source: %d", stats.fromSetSource)

	local auto = addon.SetCompletion:GetAutoOpenState()
	Print("Auto open: setting %s, panel %s, %s",
		auto.enabled and "on" or "|cffff5555off|r",
		auto.panelBuilt and (auto.panelShown and "shown" or "built but hidden") or "never built",
		auto.alreadyShownFor and ("already opened for " .. auto.alreadyShownFor)
			or "not yet opened here")

	local seen = {}
	for name in pairs(stats.instanceNames) do seen[#seen + 1] = name end
	table.sort(seen)
	if #seen > 0 then
		Print("  instances named by that drop data: %s", table.concat(seen, ", "))
	end

	for _, match in ipairs(matches) do
		Print("  %s (%d/%d), %d here, %d elsewhere%s", match.name or "?", match.collected,
			match.total, #match.here, match.remaining, match.isExtraSet and " [extra]" or "")
		for _, piece in ipairs(match.here) do
			Print("      %s from %s%s", piece.name or "?",
				piece.encounter or "|cff8a7e6athe set's source, no boss named|r",
				piece.difficultyNote and (" |cffff5555(" .. piece.difficultyNote .. ")|r") or "")
		end
	end
end

--- Replays walking into the instance, so the panel and its glide can be watched
--- again without zoning out and back.
commands.replay = function()
	if not addon.SetCompletion:GetCurrentInstance() then
		Print("|cffff5555Not in a dungeon or raid.|r")
		return
	end

	local shown = addon.SetCompletion:ReplayEntry()
	if shown then
		Print("Replayed the entry, panel is open.")
		return
	end

	local auto = addon.SetCompletion:GetAutoOpenState()
	Print("Replayed the entry, panel stayed closed: %s.",
		not auto.enabled and "|cffff5555the setting is off|r" or "nothing here finishes a set")
end

--- Fakes a drop so the alerts can be heard without waiting for a boss to oblige.
--- Item links cannot be passed here: the slash handler splits on spaces and
--- lowercases, which mangles them, so an item is named by ID.
commands.alert = function(itemArg)
	local catalystSource = addon.LootAlerts:IsCatalystSourceAvailable()
	Print("Catalyst data: %s", catalystSource and "Transmog Upgrade Master is loaded"
		or "|cffff5555none, catalyst alerts stay silent|r")
	Print("Alerts: set pieces %s, catalyst %s",
		addon.Profile.AlertSetPieceLoot and "on" or "|cffff5555off|r",
		addon.Profile.AlertCatalystLoot and "on" or "|cffff5555off|r")

	local itemID = tonumber(itemArg)
	-- A raid set exists once per difficulty and the versions share item IDs, so a
	-- link built from an item ID alone resolves to whichever came first. Carrying
	-- the panel's own source alongside is what makes the fake drop stand for the
	-- piece on screen rather than its Normal-difficulty twin.
	local panelSourceID
	if not itemID then
		-- Prefer a piece from the instance the player is standing in, so the panel
		-- is on screen to light up. Anything else tracked will do outside one.
		local instance = addon.SetCompletion:GetCurrentInstance()
		if instance then
			for _, match in ipairs(addon.SetCompletion:Scan(instance)) do
				for _, piece in ipairs(match.pieces or {}) do
					if piece.availableHere and piece.itemID then
						itemID, panelSourceID = piece.itemID, piece.sourceID
						Print("Using %s from %s, which drops here.",
							tostring(piece.name or itemID), tostring(match.name))
						break
					end
				end
				if itemID then break end
			end
		end
	end

	if not itemID then
		local wanted = addon.SetCompletion:GetWantedPieces()
		for sourceID, match in pairs(wanted.bySource) do
			local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
			if sourceInfo and sourceInfo.itemID then
				itemID = sourceInfo.itemID
				Print("Using %s from %s.", tostring(sourceInfo.name or itemID),
					tostring(match.name))
				break
			end
		end
	end

	if not itemID then
		Print("|cffff5555No set is close enough to completion to have a piece to fake.|r")
		Print("Name an item instead: /bwdev alert <itemID>")
		return
	end

	local itemLink = select(2, C_Item.GetItemInfo(itemID))
	if not itemLink then
		-- Uncached, so stand in a link the alert path can still read an ID out of.
		itemLink = ("|Hitem:%d|h[%d]|h"):format(itemID, itemID)
		Print("Item %d is not cached yet, using a bare link.", itemID)
	end

	local visualID, linkSourceID = C_TransmogCollection.GetItemInfo(itemLink)
	if panelSourceID and linkSourceID and panelSourceID ~= linkSourceID then
		Print("  the bare link reads as source %s, the panel's piece is %s; using the panel's.",
			tostring(linkSourceID), tostring(panelSourceID))
	end

	local sourceID = panelSourceID or linkSourceID
	local outcome, match = addon.LootAlerts:SimulateLoot(itemLink, panelSourceID)
	if outcome == "set" then
		Print("|cff69db7cAlerted: finishes %s.|r", tostring(match and match.name))

		-- The highlight is a separate step from the alert and can fail on its own,
		-- so it reports separately too.
		local lit, haloes, panelShown = addon.SetCompletion:GetFlashState(sourceID)
		local mechanism = addon.SetCompletion:GetGlowMechanism()
		Print("  source %s (visual %s): flagged %s, panel open %s",
			tostring(sourceID), tostring(visualID), tostring(lit), tostring(panelShown))
		Print("  glow: %s%s", mechanism,
			mechanism == "halo" and " |cffff5555(no Blizzard template built, using the fallback)|r"
				or "")
		if not panelShown then
			Print("  |cffff5555The panel is closed, so there is nothing to light up.|r")
		elseif mechanism == "halo" and haloes == 0 then
			Print("  |cffff5555Flagged but nothing lit: the piece is not one the panel is drawing.|r")
		end
	elseif outcome == "catalyst" then
		Print("|cff69db7cAlerted: catalysing it would teach an appearance.|r")
	elseif outcome == "nothing" then
		Print("No alert: nothing tracked wants it, and the catalyst would not help.")
	else
		Print("|cffff5555The loot line was not recognised as the player's own.|r")
	end
end

--- Fakes a catalysable drop. Finding a real one means asking about the items the
--- player is actually carrying, since only a current-season piece of the right
--- slot and armour type qualifies and no rule of thumb picks one reliably.
-- The copy in the player's bags is the item as they hold it, bonus IDs and all.
-- An item ID on its own names the base item, which carries no season and no
-- upgrade track, so the catalyst answer for it is always no.
local function FindLinkInBags(itemID)
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
			local link = C_Container.GetContainerItemLink(bag, slot)
			if link and tonumber(link:match("item:(%d+)")) == itemID then
				return link
			end
		end
	end
end

commands.catalyst = function(itemArg)
	local itemID = tonumber(itemArg)
	local itemLink, origin

	if itemID then
		itemLink, origin = FindLinkInBags(itemID), "the copy in your bags"
		if not itemLink then
			itemLink, origin = select(2, C_Item.GetItemInfo(itemID)), "the item cache"
		end
		if not itemLink then
			itemLink = ("|Hitem:%d|h[%d]|h"):format(itemID, itemID)
			origin = "a bare link, the item is not cached"
		end
	else
		Print("Searching your bags for something the catalyst would improve...")
		for bag = 0, NUM_BAG_SLOTS do
			for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
				local link = C_Container.GetContainerItemLink(bag, slot)
				local found = link and addon.LootAlerts:InspectCatalyst(link)
				if found and found.canCatalyse and found.catalystMissing then
					itemLink, origin = link, "your bags"
					break
				end
			end
			if itemLink then break end
		end
	end

	if not itemLink then
		Print("|cffff5555Nothing in your bags would teach an appearance if catalysed.|r")
		Print("Name one instead: /bwdev catalyst <itemID>")
		return
	end

	local report = addon.LootAlerts:InspectCatalyst(itemLink)
	Print("Catalyst check on %s, from %s", itemLink, origin)
	if not report.available then
		Print("  |cffff5555Transmog Upgrade Master is not loaded, so there is nothing to ask.|r")
		return
	end

	-- A perfect answer still says nothing with the alert turned off, which looks
	-- exactly like the answer having been no.
	Print("  catalyst alerts: %s", addon.Profile.AlertCatalystLoot and "on"
		or "|cffff5555off, so nothing will speak whatever the answer is|r")

	Print("  cache warm: %s (%.0f%%)", tostring(report.warm), (report.progress or 0) * 100)
	if not report.ok then
		Print("  |cffff5555lookup failed: %s|r", tostring(report.err))
		return
	end

	if report.bonusIDs == 0 then
		Print("  |cffff5555No bonus IDs on this link, so it carries no season and no upgrade")
		Print("  track. The answer below is about the base item, not one you own.|r")
	end

	Print("  canCatalyse: %s  canUpgrade: %s  catalystAppearanceMissing: %s",
		tostring(report.canCatalyse), tostring(report.canUpgrade), tostring(report.catalystMissing))

	local context = report.context
	Print("  season: %s  tier: %s  bonus IDs: %d",
		tostring(context and context.seasonID), tostring(context and context.tier),
		report.bonusIDs or 0)

	-- nil and false are different refusals and want different things done next.
	if report.canCatalyse == nil then
		Print("  |cffff5555Never read: the item data is not cached. Ask again in a moment.|r")
	elseif report.canCatalyse == false then
		Print("  Read and rejected: the catalyst does not apply to this item.")
	end

	local outcome = addon.LootAlerts:SimulateLoot(itemLink)
	Print(outcome == "catalyst" and "|cff69db7cAlerted as catalysable.|r"
		or ("No catalyst alert: %s"):format(tostring(outcome)))
end

local SETINFO_LIMIT = 3

--- Everything the instance scan reads about one named set, so a set that never
--- reaches the list can be followed through each test it has to pass.
commands.setinfo = function(search)
	if not search then
		Print("|cffff5555Usage: /bwdev setinfo <part of a set name>|r")
		return
	end

	local names = SourceCategoryNames()
	local found = 0
	for setID, setData in pairs(addon.GetFullSets() or {}) do
		if setData.name and setData.name:lower():find(search, 1, true) then
			found = found + 1
			if found <= SETINFO_LIMIT then
				Print("%s (setID %d) [%s]", setData.name, setID, setData.setType or "?")
				Print("  category: %s  tab: %s  description: %s",
					names[setData.filter] or ("? (" .. tostring(setData.filter) .. ")"),
					tostring(setData.tab), tostring(setData.description))
				-- The label is what the journal groups sets under, and for a content
				-- reward that grouping tends to be the content itself.
				Print("  label: %s  note: %s  customGroups: %s",
					tostring(setData.label), tostring(setData.note), tostring(setData.customGroups))

				local blizzard = C_TransmogSets.GetSetInfo(setID)
				if blizzard then
					Print("  Blizzard label: %s  expansion: %s  patch: %s",
						tostring(blizzard.label), tostring(blizzard.expansionID),
						tostring(blizzard.patchID))
				end

				local appearances = addon.C_TransmogSets.GetSetPrimaryAppearances(setID) or {}
				local missing = 0
				for _, appearance in ipairs(appearances) do
					if not appearance.collected then missing = missing + 1 end
				end
				Print("  pieces: %d, missing %d (limit is %d)", #appearances, missing,
					addon.Profile.InstanceSetsMaxMissing)

				for _, appearance in ipairs(appearances) do
					if not appearance.collected then
						local sourceID = appearance.appearanceID
						local info = C_TransmogCollection.GetSourceInfo(sourceID)
						Print("    [%d] %s  sourceType=%s item=%s", sourceID,
							info and info.name or "?",
							info and tostring(info.sourceType) or "?",
							info and tostring(info.itemID) or "?")

						local drops = C_TransmogCollection.GetAppearanceSourceDrops(sourceID) or {}
						if #drops == 0 then
							Print("        drops: |cffff5555none|r")
						end
						for _, drop in ipairs(drops) do
							Print("        drops: %s / %s  [%s]", tostring(drop.instance),
								tostring(drop.encounter),
								drop.difficulties and table.concat(drop.difficulties, ", ") or "")
						end
					end
				end
			end
		end
	end

	if found == 0 then
		Print("|cffff5555No set name contains '%s'.|r", search)
	elseif found > SETINFO_LIMIT then
		Print("...and %d more, narrow the search.", found - SETINFO_LIMIT)
	end
end

local LOOT_LIMIT = 30

--- What the Encounter Journal says drops here, and what each entry resolves to in
--- the wardrobe. Tier has no drop data of its own because the token drops, not the
--- piece, so the question is whether the journal hands back the class item instead.
--- Selecting an instance and filtering loot is global state the open journal shares,
--- so both are put back afterwards.
commands.loot = function(search)
	local uiMapID = C_Map.GetBestMapForUnit("player")
	local journalInstanceID = uiMapID and EJ_GetInstanceForMap(uiMapID)
	if not journalInstanceID or journalInstanceID == 0 then
		Print("|cffff5555No Encounter Journal instance for this map.|r")
		return
	end

	-- Several of these are defined by Blizzard_EncounterJournal rather than the C
	-- API, so they don't exist until something has opened the journal once.
	if not C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal") then
		C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
		Print("Loaded Blizzard_EncounterJournal.")
	end

	-- The EJ_ globals have been moving into C_EncounterJournal patch by patch, so
	-- which of them this client still has is the first thing worth knowing.
	local api = {
		EJ_GetCurrentInstance = EJ_GetCurrentInstance,
		EJ_SelectInstance = EJ_SelectInstance,
		EJ_SetDifficulty = EJ_SetDifficulty,
		EJ_SetLootFilter = EJ_SetLootFilter,
		EJ_GetLootFilter = EJ_GetLootFilter,
		EJ_GetNumLoot = EJ_GetNumLoot,
	}

	local names = {}
	for name in pairs(api) do names[#names + 1] = name end
	table.sort(names)

	local missingAPI = {}
	for _, name in ipairs(names) do
		if not api[name] then missingAPI[#missingAPI + 1] = name end
	end
	Print("Journal API missing: %s", #missingAPI > 0
		and ("|cffff5555" .. table.concat(missingAPI, ", ") .. "|r") or "nothing")

	local journal = C_EncounterJournal or {}
	local getLoot = journal.GetLootInfoByIndex
	local getNumLoot = api.EJ_GetNumLoot or journal.GetNumLoot
	if not getLoot or not getNumLoot or not api.EJ_SelectInstance then
		Print("|cffff5555Cannot read loot without SelectInstance, GetNumLoot and GetLootInfoByIndex.|r")
		return
	end

	local previousInstance = api.EJ_GetCurrentInstance and api.EJ_GetCurrentInstance()
	local previousClass, previousSpec
	if api.EJ_GetLootFilter then previousClass, previousSpec = api.EJ_GetLootFilter() end

	local _, _, difficultyID = GetInstanceInfo()
	local _, _, classID = UnitClass("player")

	api.EJ_SelectInstance(journalInstanceID)
	if api.EJ_SetDifficulty and difficultyID then api.EJ_SetDifficulty(difficultyID) end
	if api.EJ_SetLootFilter then api.EJ_SetLootFilter(classID, 0) end

	local total = getNumLoot() or 0
	Print("Journal instance %d, difficulty %s, loot filtered to class %d: %d entries",
		journalInstanceID, tostring(difficultyID), classID, total)
	if total == 0 then
		Print("|cffff5555No loot data. Open the Encounter Journal on this instance once, then retry.|r")
	end

	-- An entry with no appearance of its own is the shape a tier token takes: it is
	-- listed as loot, but the wardrobe knows nothing about it until it is traded in.
	local shown, withSource, noSource = 0, 0, 0
	for index = 1, total do
		local info = getLoot(index)
		local name = info and info.name or "?"
		if info and (not search or name:lower():find(search, 1, true)) then
			local _, sourceID = C_TransmogCollection.GetItemInfo(info.itemID)
			if sourceID then withSource = withSource + 1 else noSource = noSource + 1 end

			shown = shown + 1
			-- Everything that resolves is ordinary gear; the ones that don't are the
			-- interesting half, so they are what gets shown when the list is long.
			if shown <= LOOT_LIMIT or not sourceID then
				Print("  item=%s source=%s slot=%s armor=%s  %s", tostring(info.itemID),
					sourceID and tostring(sourceID) or "|cffff5555none|r",
					tostring(info.slot), tostring(info.armorType), name)
			end
		end
	end

	Print("Matched %d entries: %d resolved to a source, %d did not.", shown, withSource, noSource)
	if shown > LOOT_LIMIT then
		Print("...%d more not shown.", shown - LOOT_LIMIT)
	end

	if api.EJ_SetLootFilter then
		api.EJ_SetLootFilter(previousClass or 0, previousSpec or 0)
	end
	if previousInstance and previousInstance > 0 then
		api.EJ_SelectInstance(previousInstance)
	end
end

commands.help = function()
	Print("Dev commands (/bwdev):")
	Print("  sources          source checkboxes and the category of every visible set")
	Print("  sources <name>   list the visible sets in one category with their raw fields")
	Print("  instance         what the instance set scan sees where you are standing")
	Print("  replay           open the panel again as if you had just walked in")
	Print("  alert [itemID]   fake a drop, defaulting to a piece that drops where you are")
	Print("  catalyst [itemID] fake a catalysable drop, defaulting to one from your bags")
	Print("  setinfo <name>   one set's pieces and the drop data behind each of them")
	Print("  loot [name]      what the Encounter Journal says drops here, with sources")
	Print("Situations:")
	Print("  probe            end to end viability check, leaves nothing pending")
	Print("  api              which C_TransmogOutfitInfo functions exist and their taint state")
	Print("  schema           situation categories and options, with indices for 'set'")
	Print("  read             selected options on the currently viewed outfit")
	Print("  outfits          all outfits and their situation summary text")
	Print("  readall          step through every outfit and read its selections")
	Print("  set <c> <o> [on|off]   stage one option change")
	Print("  commit           commit staged situation changes")
	Print("  clear            discard staged changes")
	Print("  reset confirm    reset the viewed outfit's situations")
	Print("  enabled [on|off] read or set the master situations toggle")
	Print("  copy             snapshot the viewed outfit's selections")
	Print("  paste [commit]   apply the snapshot to the viewed outfit")
	Print("  watch [off]      log situation events and blocked actions")
	Print("  blocked          replay recorded blocked or forbidden actions")
end

DevTools.commands = commands

-- Commands that don't touch the Situations API, so they still run on a client
-- that doesn't have it.
local SITUATION_FREE_COMMANDS = {
	help = true,
	sources = true,
	instance = true,
	replay = true,
	alert = true,
	catalyst = true,
	setinfo = true,
	loot = true,
}

SLASH_LUCKYBWDEV1 = "/bwdev"
SlashCmdList["LUCKYBWDEV"] = function(input)
	local args = {}
	for word in tostring(input or ""):gmatch("%S+") do
		args[#args + 1] = word:lower()
	end

	local commandName = args[1] or "help"
	if not C_TransmogOutfitInfo and not SITUATION_FREE_COMMANDS[commandName] then
		Print("|cffff5555C_TransmogOutfitInfo is not available on this client.|r")
		return
	end

	local command = commands[commandName]
	if not command then
		Print("|cffff5555Unknown command '%s'.|r", tostring(args[1]))
		commands.help()
		return
	end

	command(args[2], args[3], args[4])
end
