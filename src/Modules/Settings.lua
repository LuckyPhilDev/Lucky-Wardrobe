-- Lucky's Better Wardrobe: native settings panel (LuckyRichSettings).
-- Replaces the old Ace3 options UI. Reads/writes the AceDB profile directly.
local addonName = ...
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

function addon:BuildSettingsPanel()
    if self.settingsPanel then return end

    local Profile = self.Profile
    local panel = LuckySettings:NewRichPanel("Lucky's Better Wardrobe", {
        addonFolder = "LuckysBetterWardrobe",
        imagesRoot  = "Images",
    })
    self.settingsPanel = panel

    SLASH_LUCKYBW1 = "/bw"
    SLASH_LUCKYBW2 = "/betterwardrobe"
    -- Hiding the minimap button is a supported choice, and shift-clicking it was
    -- the only way to open the set list by hand. Anything unrecognised opens
    -- settings, which is where someone typing a half-remembered command wants to
    -- end up anyway.
    SlashCmdList["LUCKYBW"] = function(input)
        if (input or ""):match("^%s*(%S*)"):lower() == "sets" then
            addon.SetCompletion:Toggle()
        else
            panel:Open()
        end
    end

    ---------------------------------------------------------------------------
    -- General
    ---------------------------------------------------------------------------
    do
        local g = panel:Group(L["General Options"])

        g:Toggle({
            label   = L["Ignore Class Restriction Filter"],
            desc    = "Show sets and appearances your class normally cannot use.",
            checked = Profile.IgnoreClassRestrictions,
            onToggle = function(v)
                Profile.IgnoreClassRestrictions = v
                addon.Init:InitDB()
            end,
        })

        g:Toggle({
            label   = L["Minimap Button"],
            desc    = L["Shows a Lucky's Better Wardrobe button on the minimap. Left-click it to open your appearances, right-click for these settings."],
            checked = not Profile.MinimapButton.hide,
            onToggle = function(v) addon:SetMinimapButtonShown(v) end,
        })

        g:Toggle({
            label   = L["Dev Mode"],
            desc    = "Development logging and diagnostics. Has no visible effect for regular users.",
            checked = Profile.DevMode,
            onToggle = function(v) Profile.DevMode = v end,
        })

        g:BottomSection(L["Version Info"])
        g:BottomLabel({
            label = "Lucky's Better Wardrobe",
            value = "v" .. (C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"),
        })
        g:BottomLabel({
            label = "Lucky's Utils",
            value = "v" .. (C_AddOns.GetAddOnMetadata("Luckys_Utils", "Version") or "?"),
        })
        LuckyPromo:AddToRichGroup(g, addonName)
    end

    ---------------------------------------------------------------------------
    -- Transmog Window
    ---------------------------------------------------------------------------
    do
        local g = panel:Group(L["Transmog Window"])

        g:Toggle({
            label   = L["Keep Active Transmog Tab"],
            desc    = "Keeps whichever tab you're on when switching outfits at the transmog NPC, instead of jumping back to Items. Clicking a slot still opens Items.",
            checked = Profile.KeepTransmogTab,
            onToggle = function(v) Profile.KeepTransmogTab = v end,
        })

        g:Toggle({
            label     = L["Show Situation Values"],
            desc      = L["Shows the selected situation values on outfit entries instead of just the category names."],
            image     = "transmog-window/show-situation-values",
            imageSize = { 571, 222 },
            checked   = Profile.ShowSituationValues,
            onToggle  = function(v)
                Profile.ShowSituationValues = v
                addon:RefreshSituationLabels()
            end,
        })

        g:Toggle({
            label     = L["Show Situation Tooltips"],
            desc      = L["Shows an outfit's full situation list, with the values selected in each category, in a tooltip when you hover it."],
            image     = "transmog-window/show-situation-tooltips",
            imageSize = { 558, 140 },
            checked   = Profile.ShowSituationTooltips,
            onToggle  = function(v)
                Profile.ShowSituationTooltips = v
                addon:RefreshSituationLabels()
            end,
        })
    end

    ---------------------------------------------------------------------------
    -- Tooltips
    ---------------------------------------------------------------------------
    do
        local g = panel:Group(L["Tooltips"])

        g:Toggle({
            label   = L["Show Appearance Status"],
            desc    = L["Adds a line to item tooltips showing whether you have already collected that item's appearance."],
            checked = Profile.ShowOwnedItemTooltips,
            onToggle = function(v) Profile.ShowOwnedItemTooltips = v end,
        })

        g:Toggle({
            label   = L["Show Set Membership"],
            desc    = L["Lists the sets an item belongs to, with how many pieces of each you have collected."],
            checked = Profile.ShowSetTooltips,
            onToggle = function(v) Profile.ShowSetTooltips = v end,
        })

        g:Toggle({
            label   = L["Show Model Preview"],
            desc    = L["Shows a model wearing the item beside its tooltip."],
            checked = Profile.TooltipPreview_Show,
            onToggle = function(v) Profile.TooltipPreview_Show = v end,
        })
    end

    ---------------------------------------------------------------------------
    -- Set Tracker
    --
    -- The instance list and the loot alerts are two sides of one feature and
    -- share the threshold that decides what counts as close to finishing, so the
    -- threshold leads and neither side owns it.
    ---------------------------------------------------------------------------
    do
        local g = panel:Group(L["Set Tracker"])

        g:Section(L["What to Track"])

        g:Slider({
            label     = L["Pieces Missing At Most"],
            desc      = L["How incomplete a set can be and still count as one you are close to finishing. At 3, a set you are missing four or more pieces of is left out of the instance list and never alerts."],
            min       = 1,
            max       = 8,
            value     = Profile.InstanceSetsMaxMissing,
            onChanged = function(v)
                Profile.InstanceSetsMaxMissing = v
                addon.SetCompletion:Refresh()
            end,
        })

        g:Toggle({
            label    = L["Include the Current Tier"],
            desc     = L["Sets from the tier you are raiding now are left out, on the grounds that you will finish those by turning up. Turn this on to hear about them anyway. Older sets you have gone back for are never affected."],
            checked  = Profile.IncludeCurrentTier,
            onToggle = function(v)
                Profile.IncludeCurrentTier = v
                addon.SetCompletion:Refresh()
            end,
        })

        local catalystAvailable = addon.Catalyst and addon.Catalyst:IsAvailable()

        g:Toggle({
            label    = L["Mark Pieces You Could Catalyse"],
            desc     = L["Stamps a catalyst mark on a piece you are missing when you are already carrying something the catalyst would turn into it. Hover the piece to see which item."],
            requires = { addon = "TransmogUpgradeMaster" },
            disabled = not catalystAvailable,
            checked  = Profile.MarkCatalysablePieces,
            onToggle = function(v)
                Profile.MarkCatalysablePieces = v
                addon.SetCompletion:Refresh()
            end,
        })

        g:Section(L["In Dungeons and Raids"])

        g:Toggle({
            label    = L["Open the List Automatically"],
            desc     = L["Opens a list when you enter a dungeon or raid of the sets you are close to completing whose missing pieces drop there. Type /bw sets, use a keybinding, or shift-click the minimap button to open it any time, whether this is on or off."],
            checked  = Profile.ShowInstanceSets,
            onToggle = function(v) Profile.ShowInstanceSets = v end,
        })

        g:Slider({
            label     = L["Move Aside After"],
            desc      = L["How long the list holds the middle of the screen before it shrinks into the corner. At 0 it opens in the corner and never takes the middle."],
            parent    = L["Open the List Automatically"],
            min       = 0,
            max       = 15,
            suffix    = "s",
            value     = Profile.InstanceSetsDwellSeconds,
            onChanged = function(v) Profile.InstanceSetsDwellSeconds = v end,
        })

        g:Button({
            label   = L["Reset Window Position"],
            desc    = L["Puts the list back in the top-left corner, for a drag that left it somewhere you cannot reach."],
            onClick = function() addon.SetCompletion:ResetPosition() end,
        })

        g:Section(L["When You Loot"])

        g:Toggle({
            label    = L["Alert on Set Pieces"],
            desc     = L["Speaks up when you loot a piece of a set you are close to finishing, wherever you are."],
            checked  = Profile.AlertSetPieceLoot,
            onToggle = function(v) Profile.AlertSetPieceLoot = v end,
        })

        g:Toggle({
            label    = L["Alert on Catalyst Upgrades"],
            desc     = L["Speaks up, more quietly, when you loot something the catalyst could turn into an appearance you are missing."],
            requires = { addon = "TransmogUpgradeMaster" },
            disabled = not catalystAvailable,
            checked  = Profile.AlertCatalystLoot,
            onToggle = function(v) Profile.AlertCatalystLoot = v end,
        })

        g:MultiSelect({
            label     = L["Alert With"],
            desc      = L["How an alert reaches you. A long clear puts a lot of lines in chat, and the sound alone carries just as well."],
            options   = {
                { key = "AlertWithSound", label = L["Sound"] },
                { key = "AlertWithChat",  label = L["Chat message"] },
            },
            isChecked = function(key) return Profile[key] and true or false end,
            onToggle  = function(key, checked) Profile[key] = checked end,
        })
    end

    panel:Finalize()
end
