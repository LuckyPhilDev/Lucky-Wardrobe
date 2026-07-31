-- Lucky's Better Wardrobe: native settings panel (LuckyRichSettings).
-- Replaces the old Ace3 options UI. Reads/writes the AceDB profile directly.
local addonName = ...
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

function addon:BuildSettingsPanel()
    if self.settingsPanel then return end

    local Profile = self.Profile
    local panel = LuckySettings:NewRichPanel("Lucky's Better Wardrobe")
    self.settingsPanel = panel

    SLASH_LUCKYBW1 = "/bw"
    SLASH_LUCKYBW2 = "/betterwardrobe"
    SlashCmdList["LUCKYBW"] = function() panel:Open() end

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
            label   = L["Keep Active Transmog Tab"],
            desc    = "Keeps whichever tab you're on when switching outfits at the transmog NPC, instead of jumping back to Items. Clicking a slot still opens Items.",
            checked = Profile.KeepTransmogTab,
            onToggle = function(v) Profile.KeepTransmogTab = v end,
        })

        g:Toggle({
            label   = L["Show Situation Values"],
            desc    = L["Shows the selected situation values on outfit entries instead of just the category names."],
            checked = Profile.ShowSituationValues,
            onToggle = function(v)
                Profile.ShowSituationValues = v
                addon:RefreshSituationLabels()
            end,
        })

        g:Toggle({
            label   = L["Show Situation Tooltips"],
            desc    = L["Shows an outfit's full situation list in a tooltip when you hover it."],
            checked = Profile.ShowSituationTooltips,
            onToggle = function(v) Profile.ShowSituationTooltips = v end,
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

    panel:Finalize()
end
