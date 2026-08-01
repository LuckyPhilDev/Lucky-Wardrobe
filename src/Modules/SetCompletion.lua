-- Sets you are close to completing whose missing pieces drop in the instance
-- you're standing in.
local addonName, addon = ...
addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local SetCompletion = {}
addon.SetCompletion = SetCompletion

local APPEARANCES_TAB = 5
local INSTANCE_TYPES = { party = true, raid = true }

-- Sets from these sources are bought, earned or handed out, never dropped by a
-- boss, so no amount of clearing an instance finishes one. Skipping them before
-- the drop lookups is what keeps a scan to a handful of sets. Misc and Trash
-- stay in: they are where anything unclassified lands.
local NON_DROP_SOURCES = {
	[addon.Filter.PVP] = true,
	[addon.Filter.TPOST] = true,
	[addon.Filter.HOLIDAY] = true,
	[addon.Filter.GARRISON] = true,
	[addon.Filter.ISLAND] = true,
	[addon.Filter.WARFRONT] = true,
	[addon.Filter.COVENANT] = true,
	[addon.Filter.HERITAGE] = true,
	[addon.Filter.COSMETIC] = true,
	[addon.Filter.QUEST] = true,
}

--- Whether a set belongs to the tier the game is currently on.
-- A set's patchID and the client's interface number are the same kind of number,
-- so dropping the build digits off both leaves the content patch: a 12.0.7
-- client and a set from 12.0.0 are both 1200. Sets carrying no patchID at all,
-- which is most of the curated extra ones, are never current.
local function ContentPatch(version)
	version = tonumber(version)
	return version and math.floor(version / 100) or nil
end

local currentPatch
local function IsCurrentTier(setData)
	if not currentPatch then
		currentPatch = ContentPatch(select(4, GetBuildInfo()))
	end
	return currentPatch ~= nil and ContentPatch(setData.patchID) == currentPatch
end

-- Drop lookups are the expensive half of a scan and an appearance never moves
-- between bosses, so results last the session.
local dropCache = {}

local function GetDrops(sourceID)
	local drops = dropCache[sourceID]
	if not drops then
		drops = C_TransmogCollection.GetAppearanceSourceDrops(sourceID) or {}
		dropCache[sourceID] = drops
	end
	return drops
end

--- The instance the player is in, or nil anywhere else.
-- Drop data names instances the way the Encounter Journal does, which is not
-- always what the map is called, so both names are carried and either may match.
function SetCompletion:GetCurrentInstance()
	local inInstance, instanceType = IsInInstance()
	if not inInstance or not INSTANCE_TYPES[instanceType] then return nil end

	local name, _, _, difficultyName = GetInstanceInfo()
	local journalName
	local uiMapID = C_Map.GetBestMapForUnit("player")
	local journalInstanceID = uiMapID and EJ_GetInstanceForMap(uiMapID)
	if journalInstanceID and journalInstanceID > 0 then
		journalName = EJ_GetInstanceInfo(journalInstanceID)
	end

	return {
		name = name,
		journalName = journalName,
		difficulty = difficultyName,
	}
end

local function IsThisInstance(instance, dropInstanceName)
	if not dropInstanceName then return false end
	return dropInstanceName == instance.name or dropInstanceName == instance.journalName
end

-- The two sides name a difficulty differently often enough that equality alone
-- reports a piece as out of reach when it isn't: the journal says "Mythic" where
-- the group is on a "Mythic Keystone", and "Heroic" where the raid is "25 Player
-- (Heroic)". Either name containing the other is the same difficulty.
local function SameDifficulty(a, b)
	if not a or not b then return false end
	if a == b then return true end
	return string.find(a, b, 1, true) ~= nil or string.find(b, a, 1, true) ~= nil
end

-- A drop with no difficulties listed is available on all of them. Anything else
-- is reported, so a piece that is here but out of reach on this difficulty says so.
local function DifficultyNote(instance, difficulties)
	if not difficulties or #difficulties == 0 then return nil end

	for _, difficulty in ipairs(difficulties) do
		if SameDifficulty(difficulty, instance.difficulty) then return nil end
	end

	return table.concat(difficulties, ", ")
end

-- A raid set names its difficulty where other sets put a colour or an event, so
-- the difficulty of a set matched by its source is the difficulty it describes.
-- Only a description that actually names one counts: anything else says nothing
-- about difficulty and must not be reported as though it did.
local function VariantDifficultyNote(instance, variant)
	if not variant or not addon.Globals.IsRaidDifficulty(variant) then return nil end
	if SameDifficulty(variant, instance.difficulty) then return nil end

	return variant
end

--- Where a missing piece comes from in this instance, or nil if it drops elsewhere.
local function FindDropHere(instance, sourceID)
	for _, drop in ipairs(GetDrops(sourceID)) do
		if IsThisInstance(instance, drop.instance) then
			return {
				encounter = drop.encounter,
				difficultyNote = DifficultyNote(instance, drop.difficulties),
			}
		end
	end
end

local function PieceName(sourceID)
	local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
	return sourceInfo and sourceInfo.name
end

--- Uncollected sources of a set, and how many pieces it holds in total.
-- Extra sets carry the collected state they were built with, which is a snapshot
-- taken well before the player walked in here and started looting. A piece can
-- only ever go from missing to collected, so re-reading the ones it calls missing
-- is enough to bring the count up to date, and re-reading the rest would be waste.
local function GetMissingSources(setID, isExtraSet)
	local appearances = addon.C_TransmogSets.GetSetPrimaryAppearances(setID)
	if not appearances then return nil, 0 end

	local missing, total = {}, 0
	for _, appearance in ipairs(appearances) do
		total = total + 1
		-- Named appearanceID, holds a sourceID. Blizzard's field, left as it comes.
		local sourceID = appearance.appearanceID
		local collected = appearance.collected
		if not collected and isExtraSet then
			local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
			collected = sourceInfo and sourceInfo.isCollected
		end

		if not collected then
			missing[#missing + 1] = sourceID
		end
	end

	return missing, total
end

--- Sets close enough to completion to be worth a drop lookup.
-- Cheap: it reads only the collected counts the set data already carries. Every
-- set left standing here pays for a lookup per missing piece, which is why the
-- limit is applied before that and not after.
local function CollectCandidates(maxMissing, stats)
	local candidates = {}

	-- A set from the tier being raided now gets finished by playing, so being told
	-- about it every pull is nagging rather than news. Hearing about it anyway is
	-- a choice someone can make, not the starting point.
	local skipCurrentTier = not addon.Profile.IncludeCurrentTier

	for setID, setData in pairs(addon.GetFullSets() or {}) do
		local isExtraSet = setData.setType ~= "Blizzard"
		stats.sets = stats.sets + 1
		if NON_DROP_SOURCES[setData.filter] then
			stats.skippedCategory = stats.skippedCategory + 1
		elseif skipCurrentTier and IsCurrentTier(setData) then
			stats.skippedCurrentTier = stats.skippedCurrentTier + 1
		else
			local missing, total = GetMissingSources(setID, isExtraSet)
			if missing and #missing > maxMissing then
				stats.overLimit = stats.overLimit + 1
			end
			if missing and #missing > 0 and #missing <= maxMissing then
				candidates[#candidates + 1] = {
					setID = setID,
					name = setData.name,
					-- Where the set comes from, and which version of it this is. The
					-- journal groups sets by the first and tells them apart by the
					-- second, so a raid set carries its raid and its difficulty.
					source = setData.label,
					variant = setData.description,
					isExtraSet = isExtraSet,
					total = total,
					collected = total - #missing,
					missing = missing,
				}
			end
		end
	end

	return candidates
end

--- Every piece of a set in the order the wardrobe shows them, collected or not.
-- Icons come from GetItemInfoInstant, which reads the client's own item database
-- rather than the cache the item's name needs, so an icon is there on the first
-- draw where a name is not.
-- Which pieces are currently drawing attention to themselves. Kept out here
-- rather than on the piece because the panel rebuilds its data on every redraw.
local flashUntil = {}

local function FlashSeconds()
	return addon.Profile.InstanceSetsFlashSeconds
end

local function IsFlashing(sourceID)
	local expiry = flashUntil[sourceID]
	return expiry ~= nil and expiry > GetTime()
end

-- Everywhere a piece is known to drop, this instance's bosses first, so hovering
-- one still to find answers "where do I get this" rather than only "is it here".
local function DropLocations(instance, sourceID)
	local locations = {}
	for _, drop in ipairs(GetDrops(sourceID)) do
		locations[#locations + 1] = {
			instance = drop.instance,
			encounter = drop.encounter,
			difficulties = drop.difficulties and table.concat(drop.difficulties, ", ") or nil,
			isHere = IsThisInstance(instance, drop.instance),
		}
	end

	table.sort(locations, function(a, b)
		if a.isHere ~= b.isHere then return a.isHere end
		return (a.instance or "") < (b.instance or "")
	end)
	return locations
end

-- What the player is carrying that the catalyst would turn into a piece, keyed by
-- source. Read once per scan rather than per set, since the answer costs a lookup
-- per item in the bags and does not change while a scan is running.
local function CatalysableSources()
	if not addon.Profile.MarkCatalysablePieces then return {} end
	return addon.Catalyst:GetHeldTargets().bySource
end

--- Every piece of the set, and how many of them the player holds the makings of.
local function BuildPieceList(instance, setID, hereBySource, catalysable)
	local pieces, catalysableCount = {}, 0
	for _, appearance in ipairs(addon.C_TransmogSets.GetSetPrimaryAppearances(setID) or {}) do
		local sourceID = appearance.appearanceID
		local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
		local itemID = sourceInfo and sourceInfo.itemID
		local drop = hereBySource[sourceID]
		-- Stored state can only ever be behind, never ahead, so either source
		-- saying collected means collected.
		local collected = (appearance.collected or (sourceInfo and sourceInfo.isCollected)) and true or false
		local heldFor = not collected and catalysable[sourceID] or nil
		if heldFor then catalysableCount = catalysableCount + 1 end

		pieces[#pieces + 1] = {
			sourceID = sourceID,
			itemID = itemID,
			icon = itemID and select(5, C_Item.GetItemInfoInstant(itemID)) or nil,
			name = sourceInfo and sourceInfo.name,
			collected = collected,
			availableHere = drop ~= nil,
			flashing = IsFlashing(sourceID),
			-- The item that would become this piece, for a piece the player has not
			-- collected but already holds the makings of.
			catalysable = heldFor,
			hereInstance = drop and instance.name,
			encounter = drop and drop.encounter,
			difficultyNote = drop and drop.difficultyNote,
			-- Only a piece still to find needs somewhere to come from.
			drops = not collected and DropLocations(instance, sourceID) or nil,
			sortOrder = sourceInfo and EJ_GetInvTypeSortOrder(sourceInfo.invType) or 99,
		}
	end

	table.sort(pieces, function(a, b)
		if a.sortOrder ~= b.sortOrder then return a.sortOrder < b.sortOrder end
		return (a.itemID or 0) < (b.itemID or 0)
	end)
	return pieces, catalysableCount
end

local function NewStats()
	return { sets = 0, skippedCategory = 0, skippedCurrentTier = 0, overLimit = 0,
		candidates = 0, lookups = 0, sourcesWithDrops = 0, fromSetSource = 0,
		wrongDifficulty = 0, instanceNames = {} }
end

local function CompareMatches(a, b)
	if a.remaining ~= b.remaining then return a.remaining < b.remaining end
	if #a.here ~= #b.here then return #a.here > #b.here end
	if a.total ~= b.total then return a.total > b.total end
	return (a.name or "") < (b.name or "")
end

--- Every set with a missing piece that drops in this instance, closest first.
-- The second return is what each stage of the scan saw, which is the only way to
-- tell a set that was filtered out from one whose pieces carry no drop data.
function SetCompletion:Scan(instance, maxMissing)
	local stats = NewStats()
	if not instance then return {}, stats end
	maxMissing = maxMissing or addon.Profile.InstanceSetsMaxMissing

	local matches = {}
	local candidates = CollectCandidates(maxMissing, stats)
	stats.candidates = #candidates
	local catalysable = CatalysableSources()

	for _, candidate in ipairs(candidates) do
		-- Tier pieces are not drops. They are made from a token or the catalyst, so
		-- nothing in the drop data ties one to the raid it comes from. What does tie
		-- them is the set's own source, which is the raid's name. A set that names
		-- this instance therefore has every missing piece here, boss unknown.
		local wholeSetIsHere = IsThisInstance(instance, candidate.source)

		-- A raid's set exists once per difficulty, and only the one matching the
		-- run is obtainable, so the others are not sets you can finish here. They
		-- are dropped rather than flagged: three near-identical rows for the same
		-- set, two of them unobtainable, is noise however well labelled.
		if wholeSetIsHere and VariantDifficultyNote(instance, candidate.variant) then
			wholeSetIsHere = false
			stats.wrongDifficulty = stats.wrongDifficulty + 1
		end

		local here, hereBySource = {}, {}
		for _, sourceID in ipairs(candidate.missing) do
			stats.lookups = stats.lookups + 1
			local drops = GetDrops(sourceID)
			if #drops > 0 then
				stats.sourcesWithDrops = stats.sourcesWithDrops + 1
				for _, drop in ipairs(drops) do
					stats.instanceNames[drop.instance or "?"] = true
				end
			end

			-- Drop data is preferred wherever it exists, because it names the boss.
			local drop = FindDropHere(instance, sourceID)
			if not drop and wholeSetIsHere then
				drop = {}
				stats.fromSetSource = stats.fromSetSource + 1
			end

			if drop then
				drop.name = PieceName(sourceID)
				drop.sourceID = sourceID
				here[#here + 1] = drop
				hereBySource[sourceID] = drop
			end
		end

		if #here > 0 then
			candidate.here = here
			candidate.remaining = #candidate.missing - #here
			candidate.pieces, candidate.catalysable =
				BuildPieceList(instance, candidate.setID, hereBySource, catalysable)
			candidate.missing = nil
			matches[#matches + 1] = candidate
		end
	end

	table.sort(matches, CompareMatches)
	return matches, stats
end

-- Scanning every set is too much to repeat for each item that drops, and the
-- answer only changes when the collection does.
local wantedCache, wantedCacheLimit

--- Every piece still missing from a set within the limit, wherever that set comes
--- from. Unlike the scan this has nothing to do with where the player is standing:
--- gear that finishes a set drops in the open world and from quests too.
function SetCompletion:GetWantedPieces(maxMissing)
	maxMissing = maxMissing or addon.Profile.InstanceSetsMaxMissing
	if wantedCache and wantedCacheLimit == maxMissing then return wantedCache end

	local bySource, byVisual, sourceByVisual = {}, {}, {}
	for _, candidate in ipairs(CollectCandidates(maxMissing, NewStats())) do
		for _, sourceID in ipairs(candidate.missing) do
			bySource[sourceID] = candidate
			-- A lookalike teaches the same appearance, so the visual matches too,
			-- and the set's own piece is remembered alongside it.
			local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
			if sourceInfo and sourceInfo.visualID then
				byVisual[sourceInfo.visualID] = candidate
				sourceByVisual[sourceInfo.visualID] = sourceID
			end
		end
	end

	wantedCache = { bySource = bySource, byVisual = byVisual, sourceByVisual = sourceByVisual }
	wantedCacheLimit = maxMissing
	return wantedCache
end

function SetCompletion:ForgetWantedPieces()
	wantedCache = nil
end


-- ---------------------------------------------------------------------------
-- Panel
-- ---------------------------------------------------------------------------

-- The panel arrives at reading size and then gets out of the way. Both states are
-- the same window at two scales rather than two layouts, so the icons and text
-- shrink together and nothing has to be measured twice.
local TUCKED_SCALE = 0.7
local GLIDE_SECONDS = 0.7

-- How long it holds the middle of the screen before tucking itself away. Zero
-- means it never takes the middle at all and opens tucked.
local function DwellSeconds()
	return addon.Profile.InstanceSetsDwellSeconds
end

-- The quality border stands 2px proud on each side, so the gap has to clear both
-- of them before it separates anything: at 4 the borders of two collected pieces
-- met in the middle.
local ICON_SIZE, ICON_GAP = 40, 8
-- Half the icon reads as a stamp on the piece. Much smaller and it is a smudge at
-- this size; much larger and it is the piece that looks like the decoration.
local BADGE_SIZE = ICON_SIZE * 0.5
local MAX_ICONS = 14
local PADDING = 10
local HEADER_HEIGHT, SUBTITLE_HEIGHT = 32, 22
local TITLE_HEIGHT = 18
local ROW_HEIGHT = TITLE_HEIGHT + ICON_SIZE + 12
local MIN_COLUMNS = 6

-- Past this the window would be taller than it is useful; the rest are counted
-- off in a line rather than turning the panel into something to scroll.
local MAX_ROWS = 8

local panel

-- Blizzard's proc glow: the effect an action button shows when a spell lights up.
-- The template behind it has been renamed more than once, so each name is tried
-- until one builds. The panel's own halo stands in if none of them does, which
-- keeps the highlight working rather than making it a bet on a template name.
local GLOW_TEMPLATES = { "ActionBarButtonSpellActivationAlert", "ActionButtonSpellAlertTemplate" }

-- Which of them answered, for the dev command to report.
local glowMechanism = "halo"

-- The fallback haloes currently on screen, rebuilt with the rows. Driven from the
-- panel's own OnUpdate rather than an animation object, so the pulse is one
-- arithmetic step in a loop that already runs and cannot quietly fail to start.
local glowingIcons = {}
local glowPhase = 0

function SetCompletion:GetGlowMechanism()
	return glowMechanism
end

local function AttachProcGlow(icon)
	for _, template in ipairs(GLOW_TEMPLATES) do
		local ok, alert = pcall(CreateFrame, "Frame", nil, icon, template)
		if ok and alert then
			-- Blizzard draws the alert about a fifth wider than the button it sits on.
			local overhang = ICON_SIZE * 0.2
			alert:SetPoint("TOPLEFT", -overhang, overhang)
			alert:SetPoint("BOTTOMRIGHT", overhang, -overhang)
			alert:Hide()
			glowMechanism = template
			return alert
		end
	end
	return nil
end

-- The looping animation is the one worth having, since the highlight has to hold
-- attention for several seconds rather than announce itself once. Names differ by
-- template, so the best available is played and the rest ignored.
local PROC_ANIMATIONS = { "ProcLoop", "ProcStartAnim", "animIn" }

local function PlayProcGlow(alert)
	alert:Show()
	for _, name in ipairs(PROC_ANIMATIONS) do
		local animation = alert[name]
		if animation and animation.Play then
			pcall(animation.Play, animation)
			return
		end
	end
end

local function StopProcGlow(alert)
	for _, name in ipairs(PROC_ANIMATIONS) do
		local animation = alert[name]
		if animation and animation.Stop then
			pcall(animation.Stop, animation)
		end
	end
	alert:Hide()
end

-- Quality needs the item's data, which arrives from the server, so early on there
-- may be none. The border falls back to the panel's own gold rather than waiting.
local function QualityColor(itemID)
	local quality = itemID and (C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemID)
		or select(3, C_Item.GetItemInfo(itemID)))
	local color = quality and ITEM_QUALITY_COLORS[quality]
	if color then
		return color.r, color.g, color.b
	end
	return LuckyUI.C.goldAccent[1], LuckyUI.C.goldAccent[2], LuckyUI.C.goldAccent[3]
end

-- The game's own catalyst mark, so a stamped piece reads the way the catalyst's
-- own window does. Checked rather than assumed: an atlas that has been renamed
-- draws nothing at all, and a blank corner is worse than no stamp.
local CATALYST_ATLAS = "CreationCatalyst-32x32"

local hasCatalystAtlas
local function CatalystAtlasExists()
	if hasCatalystAtlas == nil then
		hasCatalystAtlas = C_Texture.GetAtlasInfo(CATALYST_ATLAS) ~= nil
	end
	return hasCatalystAtlas
end

-- Colour means one thing only: a piece the player has. Those keep their art and
-- take a quality border, the way an owned appearance is framed in the journal.
-- Everything still to find is greyed out, and the two kinds of missing piece are
-- told apart by weight rather than hue, since a second colour reads as a second
-- meaning and the hover text says which is which.
-- A piece the player already holds the makings of is a third thing to say, and it
-- is said with a corner stamp for the same reason: the piece is still missing and
-- still reads as missing, with a mark on it rather than a colour of its own.
local function StyleIcon(button, piece)
	button.texture:SetTexture(piece.icon or QUESTION_MARK_ICON)
	button.texture:SetDesaturated(not piece.collected)
	button.catalyst:SetShown(piece.catalysable ~= nil and CatalystAtlasExists())

	-- Something that just dropped is the one thing on the panel worth looking at,
	-- so it says so loudly and briefly rather than joining the greyscale.
	if piece.flashing then
		if button.procGlow then
			PlayProcGlow(button.procGlow)
		else
			button.glow:SetAlpha(0.8)
			button.glow:Show()
			glowingIcons[#glowingIcons + 1] = button.glow
		end
	elseif button.procGlow then
		StopProcGlow(button.procGlow)
	else
		button.glow:Hide()
	end

	if piece.collected then
		button.texture:SetVertexColor(1, 1, 1)
		button.texture:SetAlpha(1)
		button.border:SetColorTexture(QualityColor(piece.itemID))
		button.border:Show()
	elseif piece.availableHere then
		button.texture:SetVertexColor(0.75, 0.75, 0.75)
		button.texture:SetAlpha(1)
		button.border:Hide()
	else
		button.texture:SetVertexColor(0.5, 0.5, 0.5)
		button.texture:SetAlpha(0.45)
		button.border:Hide()
	end
end

-- A long-running dungeon set can drop from a dozen bosses across as many places;
-- past a handful the list stops being an answer and becomes a wall.
local MAX_DROP_LINES = 6

-- The journal's own appearance tooltip, which is what names the bosses. Reusing
-- it means a piece reads here exactly as it does in the collections tab, and the
-- source lines stay right without this file knowing how they are built.
local function SetJournalTooltip(piece)
	if not (CollectionWardrobeUtil and CollectionWardrobeUtil.SetAppearanceTooltip) then
		return false
	end

	local sourceInfo = C_TransmogCollection.GetSourceInfo(piece.sourceID)
	local visualID = sourceInfo and sourceInfo.visualID
	if not visualID then return false end

	return pcall(function()
		local categoryID = addon.GetItemCategory(visualID)
		local sources = CollectionWardrobeUtil.GetSortedAppearanceSourcesForClass(visualID,
			C_TransmogCollection.GetClassFilter(), categoryID, addon.GetTransmogLocation(piece.itemID))

		CollectionWardrobeUtil.SetAppearanceTooltip(GameTooltip, {
			sources = sources,
			primarySourceID = piece.sourceID,
			selectedIndex = nil,
			showUseError = false,
			inLegionArtifactCategory = TransmogUtil.IsCategoryLegionArtifact(categoryID),
			subheaderString = nil,
			warningString = nil,
			showTrackingInfo = false,
			slotType = nil,
		})
	end)
end

-- Where the journal's tooltip cannot be built, the drop data this scan already
-- gathered still answers the question, just without the journal's presentation.
local function AddOwnDropLines(piece)
	GameTooltip:AddLine(piece.name or UNKNOWN, 1, 0.82, 0)
	GameTooltip:AddLine(piece.collected and TRANSMOGRIFY_TOOLTIP_APPEARANCE_KNOWN
		or TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN,
		piece.collected and 0.41 or 1, piece.collected and 0.86 or 0.42,
		piece.collected and 0.49 or 0.42)

	local drops = piece.drops or {}
	if #drops == 0 then return end

	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L["Drops from"], 1, 0.82, 0)
	for index, drop in ipairs(drops) do
		if index > MAX_DROP_LINES then
			GameTooltip:AddLine(L["and %d more"]:format(#drops - MAX_DROP_LINES), 0.54, 0.49, 0.42)
			break
		end

		local text = drop.encounter or UNKNOWN
		if not drop.isHere then
			text = WARDROBE_TOOLTIP_ENCOUNTER_SOURCE:format(text, drop.instance or UNKNOWN)
		end
		if drop.difficulties then
			text = ("%s (%s)"):format(text, drop.difficulties)
		end

		if drop.isHere then
			GameTooltip:AddLine(text, 0.41, 0.86, 0.49)
		else
			GameTooltip:AddLine(text, 0.54, 0.49, 0.42)
		end
	end
end

local function ShowPieceTooltip(anchor, piece)
	GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")

	if not SetJournalTooltip(piece) then
		AddOwnDropLines(piece)
	end

	-- The journal's tooltip lists every source equally, because anywhere else that
	-- is all it can say. Standing in one of those places is the whole point here,
	-- so which of them is underfoot gets called out on the end.
	if not piece.collected and piece.availableHere then
		GameTooltip:AddLine(" ")
		local here = piece.encounter
			and WARDROBE_TOOLTIP_ENCOUNTER_SOURCE:format(piece.encounter, piece.hereInstance or UNKNOWN)
			or L["Comes from this instance"]
		GameTooltip:AddLine(here, 0.41, 0.86, 0.49)
		if piece.difficultyNote then
			GameTooltip:AddLine(L["Drops on %s"]:format(piece.difficultyNote), 1, 0.42, 0.42)
		end
	end

	-- The stamp says a piece is halfway yours. Only the hover can say what would
	-- finish the job, and naming the item is the difference between knowing that
	-- and going looking through the bags for it.
	if piece.catalysable then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["The catalyst would make this from"], 1, 0.82, 0)
		GameTooltip:AddLine(piece.catalysable, 0.91, 0.86, 0.78)
	end

	GameTooltip:Show()
end

local function ShowRowTooltip(row, match)
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(match.name or UNKNOWN, 1, 0.82, 0)
	local subtitle = match.variant or match.source
	if subtitle then
		GameTooltip:AddLine(subtitle, 0.54, 0.49, 0.42)
	end
	GameTooltip:AddLine(L["Collected: %d of %d"]:format(match.collected, match.total), 0.91, 0.86, 0.78)
	GameTooltip:AddLine(" ")

	-- Item names arrive from the server, so early on there may be none to show.
	-- A row of "Unknown" says less than nothing; the count above already carries
	-- the meaning, and the names fill in on the redraw once the data lands.
	for _, piece in ipairs(match.here) do
		if piece.name then
			local text = piece.name
			if piece.encounter then
				text = WARDROBE_TOOLTIP_ENCOUNTER_SOURCE:format(text, piece.encounter)
			end
			GameTooltip:AddLine(text, 0.41, 0.86, 0.49)
			if piece.difficultyNote then
				GameTooltip:AddLine("   " .. L["Drops on %s"]:format(piece.difficultyNote), 1, 0.42, 0.42)
			end
		end
	end

	if match.remaining > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Still missing %d pieces from elsewhere"]:format(match.remaining), 0.54, 0.49, 0.42)
	end

	if match.catalysable and match.catalysable > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["%d you could catalyse from what you are carrying"]:format(match.catalysable),
			1, 0.82, 0)
	end

	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L["Click: Show this set in your appearances"], 0.54, 0.49, 0.42)
	GameTooltip:Show()
end

-- The journal keeps extra sets on their own tab, so a set has to be shown on the
-- tab that owns it.
local function ShowSetInJournal(match)
	if not BetterWardrobeCollectionFrame then return end

	if not CollectionsJournal or not CollectionsJournal:IsShown() then
		ToggleCollectionsJournal(APPEARANCES_TAB)
	end

	local tab = match.isExtraSet and addon.Globals.EXTRA_SETS_TAB or addon.Globals.BASE_SETS_TAB
	local ok, err = pcall(function()
		BetterWardrobeCollectionFrame:SetTab(tab)
		BetterWardrobeCollectionFrame.SetsCollectionFrame:SelectSet(match.setID)
	end)

	if not ok then
		addon.DevLog(("Could not open set %s in the journal. %s"):format(tostring(match.setID), tostring(err)))
	end
end

local function CreateRow(parent, index)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", PADDING, -(HEADER_HEIGHT + SUBTITLE_HEIGHT + (index - 1) * ROW_HEIGHT))
	row:SetPoint("RIGHT", parent, "RIGHT", -PADDING, 0)
	row:EnableMouse(true)

	local highlight = row:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(LuckyUI.C.goldAccent[1], LuckyUI.C.goldAccent[2],
		LuckyUI.C.goldAccent[3], 0.10)

	row.count = row:CreateFontString(nil, "OVERLAY")
	row.count:SetFont(LuckyUI.BODY_FONT, 13)
	row.count:SetTextColor(LuckyUI.C.textLight[1], LuckyUI.C.textLight[2], LuckyUI.C.textLight[3])
	row.count:SetPoint("TOPRIGHT", 0, -2)

	row.name = row:CreateFontString(nil, "OVERLAY")
	row.name:SetFont(LuckyUI.BODY_FONT, 13)
	row.name:SetTextColor(LuckyUI.C.textGold[1], LuckyUI.C.textGold[2], LuckyUI.C.textGold[3])
	row.name:SetPoint("TOPLEFT", 0, -2)
	row.name:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)

	-- Enough icons for the biggest set, built once and shown as each row needs.
	row.icons = {}
	for iconIndex = 1, MAX_ICONS do
		local icon = CreateFrame("Frame", nil, row)
		icon:SetSize(ICON_SIZE, ICON_SIZE)
		icon:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT",
			(iconIndex - 1) * (ICON_SIZE + ICON_GAP), -4)

		-- Behind everything and wider still, so what shows is a halo around the
		-- piece rather than a wash over its art.
		icon.glow = icon:CreateTexture(nil, "BACKGROUND", nil, -1)
		icon.glow:SetPoint("TOPLEFT", -7, 7)
		icon.glow:SetPoint("BOTTOMRIGHT", 7, -7)
		icon.glow:SetColorTexture(1, 0.82, 0)
		icon.glow:SetBlendMode("ADD")
		icon.glow:Hide()

		icon.procGlow = AttachProcGlow(icon)

		-- Drawn behind the art and slightly larger, so only its edge shows.
		icon.border = icon:CreateTexture(nil, "BACKGROUND")
		icon.border:SetPoint("TOPLEFT", -2, 2)
		icon.border:SetPoint("BOTTOMRIGHT", 2, -2)
		icon.border:Hide()

		icon.texture = icon:CreateTexture(nil, "ARTWORK")
		icon.texture:SetAllPoints()
		icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

		-- Over the corner of the art rather than inside it, so the stamp is legible
		-- at this size without covering the piece it is describing.
		icon.catalyst = icon:CreateTexture(nil, "OVERLAY")
		icon.catalyst:SetSize(BADGE_SIZE, BADGE_SIZE)
		icon.catalyst:SetPoint("BOTTOMRIGHT", 3, -3)
		icon.catalyst:SetAtlas(CATALYST_ATLAS)
		icon.catalyst:Hide()

		-- Each piece answers for itself on hover, which is the only place there is
		-- room to name the bosses that drop it.
		icon:EnableMouse(true)
		icon:SetScript("OnEnter", function(self)
			if self.piece then ShowPieceTooltip(self, self.piece) end
		end)
		icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
		icon:SetScript("OnMouseUp", function(self)
			if self.match then ShowSetInJournal(self.match) end
		end)

		icon:Hide()
		row.icons[iconIndex] = icon
	end

	row:SetScript("OnEnter", function(self)
		if self.match then ShowRowTooltip(self, self.match) end
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row:SetScript("OnMouseUp", function(self)
		if self.match then ShowSetInJournal(self.match) end
	end)
	row:Hide()

	return row
end

local function UpdateRow(row, match)
	row.match = match
	row.name:SetText(match.name or "")
	row.count:SetText(("%d/%d"):format(match.collected, match.total))

	local pieces = match.pieces or {}
	for index, icon in ipairs(row.icons) do
		local piece = pieces[index]
		if piece then
			icon.piece = piece
			icon.match = match
			StyleIcon(icon, piece)
			icon:Show()
		else
			icon.piece = nil
			icon:Hide()
		end
	end
end

--- Size the window to what it is showing, so there is no empty half to it.
local function LayoutPanel(frame, matches)
	-- The rows are about to be refilled, so whatever was glowing before this is
	-- no longer what is on screen.
	wipe(glowingIcons)

	local columns = MIN_COLUMNS
	for _, match in ipairs(matches) do
		columns = math.max(columns, math.min(#(match.pieces or {}), MAX_ICONS))
	end

	local rows = math.min(#matches, MAX_ROWS)
	local overflow = #matches - rows
	local width = PADDING * 2 + columns * (ICON_SIZE + ICON_GAP) - ICON_GAP
	local height = HEADER_HEIGHT + SUBTITLE_HEIGHT + rows * ROW_HEIGHT + PADDING

	if #matches == 0 then
		height = HEADER_HEIGHT + SUBTITLE_HEIGHT + 40
	elseif overflow > 0 then
		height = height + TITLE_HEIGHT
	end

	frame:SetSize(width, height)

	for index = 1, math.max(rows, #frame.rows) do
		local row = frame.rows[index]
		if not row and index <= rows then
			row = CreateRow(frame, index)
			frame.rows[index] = row
		end

		if row then
			if matches[index] and index <= rows then
				UpdateRow(row, matches[index])
				row:Show()
			else
				row.match = nil
				row:Hide()
			end
		end
	end

	frame.overflow:SetShown(overflow > 0)
	if overflow > 0 then
		frame.overflow:SetText(L["and %d more"]:format(overflow))
	end
end

-- Positions are kept in UIParent's coordinates, not the frame's, because the two
-- states are at different scales and SetPoint offsets are read in the frame's own
-- scale. Converting on the way in and out keeps one meaning for a saved position.
local function TuckedPosition()
	local saved = addon.Profile.InstanceSetsPosition
	if type(saved) == "table" and saved.x and saved.y then
		return saved.x, saved.y
	end
	return 16, -16
end

local function Ease(t)
	return t * t * (3 - 2 * t)
end

local function BuildPanel()
	local frame = LuckyUI.CreatePanel("LuckysBetterWardrobeInstanceSets", UIParent, 100, 100)
	frame:SetFrameStrata("HIGH")
	frame:Hide()
	frame.rows = {}

	local header = LuckyUI.CreateHeader(frame, L["Finish a Set Here"])

	-- Sits inboard of the close button the header already owns, matching its size
	-- so the two read as a pair.
	local sizeButton = CreateFrame("Button", nil, header)
	sizeButton:SetSize(20, 20)
	sizeButton:SetPoint("RIGHT", -32, 0)

	local sizeBg = sizeButton:CreateTexture(nil, "BACKGROUND")
	sizeBg:SetAllPoints()
	sizeBg:SetColorTexture(LuckyUI.C.goldMuted[1], LuckyUI.C.goldMuted[2], LuckyUI.C.goldMuted[3], 0.8)

	local sizeGlyph = sizeButton:CreateFontString(nil, "OVERLAY")
	sizeGlyph:SetFont(LuckyUI.BODY_FONT, 13, "OUTLINE")
	sizeGlyph:SetTextColor(1, 1, 1)
	sizeGlyph:SetPoint("CENTER", 0, 1)

	sizeButton:SetScript("OnEnter", function()
		sizeBg:SetColorTexture(LuckyUI.C.goldAccent[1], LuckyUI.C.goldAccent[2], LuckyUI.C.goldAccent[3], 1)
		GameTooltip:SetOwner(sizeButton, "ANCHOR_BOTTOM")
		GameTooltip:SetText(frame.expanded and L["Shrink the window"] or L["Expand the window"])
		GameTooltip:Show()
	end)
	sizeButton:SetScript("OnLeave", function()
		sizeBg:SetColorTexture(LuckyUI.C.goldMuted[1], LuckyUI.C.goldMuted[2], LuckyUI.C.goldMuted[3], 0.8)
		GameTooltip:Hide()
	end)
	sizeButton:SetScript("OnClick", function() frame:ToggleSize() end)

	function frame:UpdateSizeButton(scale)
		self.expanded = scale > (1 + TUCKED_SCALE) / 2
		sizeGlyph:SetText(self.expanded and "-" or "+")
	end

	function frame:PlaceAt(x, y, scale)
		scale = scale or self:GetScale()
		self:SetScale(scale)
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x / scale, y / scale)
		self:UpdateSizeButton(scale)
	end

	function frame:GetPlacement()
		local scale = self:GetScale()
		return self:GetLeft() * scale, self:GetTop() * scale - UIParent:GetHeight(), scale
	end

	-- Dragging places the window deliberately, so it ends any glide still running
	-- and the spot chosen becomes where it tucks from then on.
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		self.glide = nil
		self.userPlaced = true
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local x, y = self:GetPlacement()
		addon.Profile.InstanceSetsPosition = { x = x, y = y }
	end)

	function frame:GlideTo(toX, toY, toScale)
		local fromX, fromY, fromScale = self:GetPlacement()
		self.glide = {
			elapsed = 0,
			fromX = fromX, fromY = fromY, fromScale = fromScale,
			toX = toX, toY = toY, toScale = toScale,
		}
	end

	function frame:GlideToTucked()
		local toX, toY = TuckedPosition()
		self:GlideTo(toX, toY, TUCKED_SCALE)
	end

	-- Grows from where it sits rather than recentring, so the window stays where
	-- the player last put it and only gets bigger.
	function frame:ToggleSize()
		local x, y, scale = self:GetPlacement()
		local expanded = scale > (1 + TUCKED_SCALE) / 2

		-- Sizing it by hand is a decision, so the automatic tuck stops second
		-- guessing it for the rest of this visit.
		self.userPlaced = true
		self:GlideTo(x, y, expanded and TUCKED_SCALE or 1)
	end

	frame:SetScript("OnUpdate", function(self, elapsed)
		if #glowingIcons > 0 then
			glowPhase = glowPhase + elapsed
			local alpha = 0.3 + 0.55 * (0.5 + 0.5 * math.sin(glowPhase * 5))
			for _, glow in ipairs(glowingIcons) do
				glow:SetAlpha(alpha)
			end
		end

		local glide = self.glide
		if not glide then return end

		glide.elapsed = glide.elapsed + elapsed
		local progress = math.min(glide.elapsed / GLIDE_SECONDS, 1)
		local t = Ease(progress)
		self:PlaceAt(
			glide.fromX + (glide.toX - glide.fromX) * t,
			glide.fromY + (glide.toY - glide.fromY) * t,
			glide.fromScale + (glide.toScale - glide.fromScale) * t)

		if progress >= 1 then
			self.glide = nil
		end
	end)

	frame.subtitle = frame:CreateFontString(nil, "OVERLAY")
	frame.subtitle:SetFont(LuckyUI.BODY_FONT, 11)
	frame.subtitle:SetTextColor(LuckyUI.C.textMuted[1], LuckyUI.C.textMuted[2], LuckyUI.C.textMuted[3])
	frame.subtitle:SetPoint("TOPLEFT", PADDING, -(HEADER_HEIGHT + 4))
	frame.subtitle:SetPoint("TOPRIGHT", -PADDING, -(HEADER_HEIGHT + 4))
	frame.subtitle:SetJustifyH("LEFT")

	frame.empty = frame:CreateFontString(nil, "OVERLAY")
	frame.empty:SetFont(LuckyUI.BODY_FONT, 12)
	frame.empty:SetTextColor(LuckyUI.C.textMuted[1], LuckyUI.C.textMuted[2], LuckyUI.C.textMuted[3])
	frame.empty:SetPoint("TOPLEFT", PADDING, -(HEADER_HEIGHT + SUBTITLE_HEIGHT))
	frame.empty:SetText(L["Nothing here finishes a set."])
	frame.empty:Hide()

	frame.overflow = frame:CreateFontString(nil, "OVERLAY")
	frame.overflow:SetFont(LuckyUI.BODY_FONT, 11)
	frame.overflow:SetTextColor(LuckyUI.C.textMuted[1], LuckyUI.C.textMuted[2], LuckyUI.C.textMuted[3])
	frame.overflow:SetPoint("BOTTOMLEFT", PADDING, PADDING - 2)
	frame.overflow:Hide()

	tinsert(UISpecialFrames, frame:GetName())
	return frame
end

local function EnsurePanel()
	if not panel then
		panel = BuildPanel()
	end
	return panel
end

-- An item's name comes from the server, so the first draw after walking in has
-- icons but no names. Asking for the data and redrawing once it lands is what
-- turns a tooltip full of blanks into one worth reading.
local namesPending
local function RequestPieceNames(matches)
	if namesPending then return end

	local waiting = false
	for _, match in ipairs(matches) do
		for _, piece in ipairs(match.pieces or {}) do
			if piece.itemID and not piece.name then
				C_Item.RequestLoadItemDataByID(piece.itemID)
				waiting = true
			end
		end
	end

	if not waiting then return end
	namesPending = true
	C_Timer.After(1, function()
		namesPending = false
		if panel and panel:IsShown() then
			SetCompletion:Draw()
		end
	end)
end

--- Rescan the current instance and fill the panel, without showing it.
-- Returns how many sets matched, and nil outside an instance.
function SetCompletion:Draw()
	local instance = self:GetCurrentInstance()
	if not instance then return nil end

	local matches = self:Scan(instance)
	local frame = EnsurePanel()

	frame.subtitle:SetText(instance.difficulty
		and ("%s, %s"):format(instance.name, instance.difficulty)
		or instance.name)
	frame.empty:SetShown(#matches == 0)
	LayoutPanel(frame, matches)
	RequestPieceNames(matches)

	return #matches
end

--- Take account of something that changed what belongs on the list, without
--- waiting to walk into the next instance. A setting about the raid you are
--- standing in gets changed from inside it as often as anywhere else.
function SetCompletion:Refresh()
	self:ForgetWantedPieces()
	if panel and panel:IsShown() then
		self:Draw()
	end
end

--- Redraw for something that changed outside the collection, like the bags. The
--- set data is untouched by that, so only what is on screen is rebuilt.
function SetCompletion:RedrawIfShown()
	if panel and panel:IsShown() then
		self:Draw()
	end
end

--- Draw attention to a piece that has just dropped. Redraws so the panel picks it
--- up, and once more when its moment is over so it settles back down on its own.
function SetCompletion:FlashPiece(sourceID)
	if not sourceID then
		addon.DevLog("FlashPiece called with no source, nothing to light up")
		return
	end

	local seconds = FlashSeconds()
	flashUntil[sourceID] = GetTime() + seconds
	if not (panel and panel:IsShown()) then
		addon.DevLog(("Flagged source %d, but the panel is not open to show it")
			:format(sourceID))
		return
	end

	self:Draw()
	addon.DevLog(("Flashing source %d for %ds"):format(sourceID, seconds))

	C_Timer.After(seconds + 0.1, function()
		if panel and panel:IsShown() then
			self:Draw()
		end
	end)
end

--- Whether a piece is currently lit, and how many haloes are on screen. The dev
--- command needs this to tell "never flagged" from "flagged but not drawn".
function SetCompletion:GetFlashState(sourceID)
	return IsFlashing(sourceID), #glowingIcons, panel ~= nil and panel:IsShown()
end

--- Put the window back where it starts, for a drag that left it somewhere it
--- cannot be reached from.
function SetCompletion:ResetPosition()
	addon.Profile.InstanceSetsPosition = {}
	if not panel then return end

	panel.userPlaced = nil
	panel.glide = nil
	local x, y = TuckedPosition()
	panel:PlaceAt(x, y, TUCKED_SCALE)
end

--- Show at reading size, then move aside on its own.
function SetCompletion:ShowExpanded()
	local frame = EnsurePanel()
	-- A fresh arrival presents itself afresh, so choices made about the window
	-- last time round do not suppress this one.
	frame.userPlaced = nil

	local dwell = DwellSeconds()
	if dwell <= 0 then
		local x, y = TuckedPosition()
		frame:PlaceAt(x, y, TUCKED_SCALE)
		frame:Show()
		return
	end

	frame:PlaceAt((UIParent:GetWidth() - frame:GetWidth()) / 2,
		-(UIParent:GetHeight() - frame:GetHeight()) / 2, 1)
	frame:Show()

	C_Timer.After(dwell, function()
		-- Anything the player has done since, closing it or dragging it somewhere
		-- of their own, outranks a tidying-away decided seconds ago.
		if frame:IsShown() and not frame.glide and not frame.userPlaced then
			frame:GlideToTucked()
		end
	end)
end

--- Open the panel on demand, wherever the player is.
function SetCompletion:Toggle()
	if panel and panel:IsShown() then
		panel:Hide()
		return
	end

	if not self:Draw() then
		print(("%s %s"):format(addon.PREFIX, L["You are not in a dungeon or raid."]))
		return
	end

	-- Asked for by hand, so it opens where it was left rather than taking the
	-- screen and sliding away again.
	local x, y = TuckedPosition()
	panel:PlaceAt(x, y, TUCKED_SCALE)
	panel:Show()
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

-- The instance the panel last opened for, so releasing and running back in
-- doesn't reopen a panel the player has closed.
local shownForInstance
local refreshPending

local function InstanceKey(instance)
	return instance and ("%s|%s"):format(instance.name or "", instance.difficulty or "")
end

local function ScanOnEntry()
	local instance = SetCompletion:GetCurrentInstance()
	if not instance then
		shownForInstance = nil
		if panel then panel:Hide() end
		return
	end

	if not addon.Profile.ShowInstanceSets then
		addon.DevLog("Instance scan skipped, the setting is off")
		return
	end

	local key = InstanceKey(instance)
	if key == shownForInstance then return end

	-- Building the panel is the one part of this that can fail, and a failure
	-- must not be recorded as a successful showing: that would suppress every
	-- retry for as long as the player stayed in the instance.
	local ok, found = pcall(function() return SetCompletion:Draw() or 0 end)
	if not ok then
		geterrorhandler()(("Lucky's Better Wardrobe: instance set list failed. %s"):format(tostring(found)))
		return
	end

	shownForInstance = key
	addon.DevLog(("Instance scan of %s found %d sets"):format(instance.name, found))
	if found > 0 then
		SetCompletion:ShowExpanded()
	end
end

-- Collecting a piece changes the counts on screen, and clearing an instance
-- fires this many times over, so the redraw waits for the run of them to finish.
local function QueueRefresh()
	if refreshPending or not (panel and panel:IsShown()) then return end

	refreshPending = true
	C_Timer.After(1, function()
		refreshPending = false
		if panel:IsShown() then
			SetCompletion:Draw()
		end
	end)
end

--- Do again exactly what walking in does, without walking back out first.
-- Everything that makes an entry a one-off is cleared: the record of having
-- already opened here, and the marks that say the player has since moved or
-- dismissed the window.
function SetCompletion:ReplayEntry()
	shownForInstance = nil
	if panel then
		panel:Hide()
		panel.glide = nil
		panel.userPlaced = nil
	end

	ScanOnEntry()
	return panel ~= nil and panel:IsShown()
end

--- Why the panel is or isn't on screen, which the scan result alone cannot say.
function SetCompletion:GetAutoOpenState()
	return {
		enabled = addon.Profile.ShowInstanceSets and true or false,
		alreadyShownFor = shownForInstance,
		panelBuilt = panel ~= nil,
		panelShown = panel ~= nil and panel:IsShown(),
	}
end

function addon:InitSetCompletion()
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterEvent("TRANSMOG_COLLECTION_SOURCE_ADDED")
	events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_ENTERING_WORLD" then
			-- Set data is rebuilt on load and the loading screen is still up, so
			-- the scan waits for both rather than reading a half-built list.
			C_Timer.After(2, ScanOnEntry)
		else
			-- What is missing has changed, so anything derived from it is stale.
			SetCompletion:ForgetWantedPieces()
			QueueRefresh()
		end
	end)
end
