-- Says something when what just dropped matters to a set you are close to
-- finishing: either the appearance itself, or an item the catalyst could turn
-- into one. Not tied to instances, because gear that finishes a set drops in the
-- open world and from quests as readily as it does off a boss.
local addonName, addon = ...
addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local LootAlerts = {}
addon.LootAlerts = LootAlerts

-- Two of the game's own toasts, so the alerts sound like the game rather than
-- like an addon. The bigger one is for the piece itself, since that is the rarer
-- and more actionable moment; catalyst gear is commonplace by comparison.
local DIRECT_SOUND = "UI_LEGENDARY_LOOT_TOAST"
local CATALYST_SOUND = "UI_EPICLOOT_TOAST"

-- One loot event can arrive more than once for the same item, and a full clear
-- produces a lot of them, so the same item stays quiet for a while after it speaks.
local REPEAT_SILENCE_SECONDS = 20
local lastAlertAt = {}

-- Which way an alert speaks is the player's to choose: a full clear produces a
-- lot of chat, and plenty of people play muted. Both are gated here so every
-- alert honours the choice without repeating it.
local function Play(soundName)
	if not addon.Profile.AlertWithSound then return end

	local soundKit = SOUNDKIT and SOUNDKIT[soundName]
	if soundKit then
		LuckySound:PlayKit(soundKit)
	end
end

local function Announce(message)
	if not addon.Profile.AlertWithChat then return end

	print(("%s %s"):format(addon.PREFIX, message))
end

-- Blizzard's loot lines are format strings, so the only reliable way to tell the
-- player's own loot from the group's is to match against those same strings.
local selfPatterns
local function IsSelfLoot(message)
	if not selfPatterns then
		selfPatterns = {}
		for _, template in ipairs({ LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE,
			LOOT_ITEM_PUSHED_SELF, LOOT_ITEM_PUSHED_SELF_MULTIPLE }) do
			if template then
				selfPatterns[#selfPatterns + 1] = "^" .. template:gsub("%%%d?$?s", ".+"):gsub("%%%d?$?d", "%%d+")
			end
		end
	end

	for _, pattern in ipairs(selfPatterns) do
		if message:match(pattern) then return true end
	end
	return false
end

--- The set a dropped item would finish, and the piece of it that was matched, or
--- nil if it finishes nothing tracked. The piece is what the panel lights up.
-- knownSourceID exists for simulated drops. A real item link carries the bonus
-- IDs that say which version of a piece it is, so it resolves to the right source
-- on its own; a link built from a bare item ID resolves to the default one, which
-- for a raid set is whichever difficulty came first.
local function WantedBy(itemLink, knownSourceID)
	local visualID, sourceID = C_TransmogCollection.GetItemInfo(itemLink)
	sourceID = knownSourceID or sourceID
	if not sourceID and not visualID then return nil end

	local wanted = addon.SetCompletion:GetWantedPieces()
	if sourceID and wanted.bySource[sourceID] then
		return wanted.bySource[sourceID], sourceID
	end

	-- A lookalike teaches the same appearance, so the set's own piece is the one
	-- to light up, not the item that happened to drop.
	local match = visualID and wanted.byVisual[visualID]
	return match, match and wanted.sourceByVisual[visualID] or nil
end

--- What this drop does for the set, which is the difference between a piece
--- worth bagging and a run worth staying for.
-- The piece that just dropped is still counted among the missing ones, because
-- the alert only fires while the collection says it is missing. So the set is
-- finished when it was the last one left.
local function SetPieceMessage(itemLink, match)
	local setName = match.name or UNKNOWN
	local remaining = #(match.missing or {}) - 1
	if remaining < 1 then
		return L["%s finishes %s"]:format(itemLink, setName)
	end

	return L["%s is a piece of %s, %d still missing"]:format(itemLink, setName, remaining)
end

-- Why an item did or didn't speak, which is what a caller testing this needs to
-- know and what the alert itself has no way of saying out loud.
local function Alert(itemLink, knownSourceID)
	local now = GetTime()
	if lastAlertAt[itemLink] and now - lastAlertAt[itemLink] < REPEAT_SILENCE_SECONDS then
		return "silenced"
	end

	-- The piece itself outranks a way of making one, so only the better of the
	-- two ever speaks for a given item.
	if addon.Profile.AlertSetPieceLoot then
		local match, sourceID = WantedBy(itemLink, knownSourceID)
		if match then
			lastAlertAt[itemLink] = now
			Announce(SetPieceMessage(itemLink, match))
			Play(DIRECT_SOUND)
			addon.SetCompletion:FlashPiece(sourceID)
			return "set", match
		end
	end

	if addon.Profile.AlertCatalystLoot and addon.Catalyst:WouldTeachAppearance(itemLink) then
		lastAlertAt[itemLink] = now
		Announce(L["%s can be catalysed into an appearance you are missing"]:format(itemLink))
		Play(CATALYST_SOUND)
		return "catalyst"
	end

	return "nothing"
end

local function HandleLootMessage(message, knownSourceID)
	if not message or not IsSelfLoot(message) then return nil end

	local outcome, match
	for itemLink in message:gmatch("|Hitem:.-|h.-|h") do
		outcome, match = Alert(itemLink, knownSourceID)
	end
	return outcome, match
end

--- Run an item through the whole loot path, message parsing included, so what is
--- tested is what a real drop does rather than a shortcut past most of it. The
--- repeat silence is lifted first, since firing the same item twice on purpose is
--- the entire point of asking.
function LootAlerts:SimulateLoot(itemLink, knownSourceID)
	lastAlertAt[itemLink] = nil
	return HandleLootMessage(LOOT_ITEM_SELF:format(itemLink), knownSourceID)
end

function addon:InitLootAlerts()
	local events = CreateFrame("Frame")
	events:RegisterEvent("CHAT_MSG_LOOT")
	events:SetScript("OnEvent", function(_, _, message)
		HandleLootMessage(message)
	end)
end
